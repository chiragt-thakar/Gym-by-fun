import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { sql } from 'kysely';

import { hmacSha256Hex } from '../src/lib/crypto.js';
import { admin, setup, signUp, TEST_ENV, type TestApp } from './helpers.js';

let t: TestApp;
beforeAll(async () => {
  t = await setup();
});
afterAll(async () => t.close());

const rc = (event: Record<string, unknown>, auth = TEST_ENV.REVENUECAT_WEBHOOK_AUTH) =>
  t.app.inject({ method: 'POST', url: '/v1/webhooks/revenuecat', headers: { authorization: `Bearer ${auth}` }, payload: { event } });

describe('RevenueCat (Play Billing) webhooks', () => {
  it('purchase, renewal, cancellation and expiry drive the entitlement', async () => {
    const u = await signUp(t);
    const ent = async () => (await t.app.inject({ method: 'GET', url: '/v1/entitlements', headers: u.auth })).json();
    const day = 86_400_000;
    const now = t.clock.now.getTime();
    const base = { app_user_id: u.userId, product_id: 'premium_yearly', original_transaction_id: 'GPA.1' };

    expect((await rc({ ...base, id: 'e1', type: 'INITIAL_PURCHASE', expiration_at_ms: now + 7 * day })).json().status).toBe('applied');
    expect(await ent()).toMatchObject({ premium: true, source: 'play' });

    await rc({ ...base, id: 'e2', type: 'RENEWAL', expiration_at_ms: now + 372 * day });
    expect(new Date((await ent()).activeUntil).getTime()).toBe(now + 372 * day);

    // Cancelling keeps access until the paid period ends.
    expect((await rc({ ...base, id: 'e3', type: 'CANCELLATION', expiration_at_ms: now + 372 * day })).json().status).toBe('ignored');
    expect((await ent()).premium).toBe(true);

    await rc({ ...base, id: 'e4', type: 'EXPIRATION', expiration_at_ms: now - 1000 });
    expect((await ent()).premium).toBe(false);
  });

  it('processes each event once', async () => {
    const u = await signUp(t);
    const e = { id: 'dup-1', type: 'INITIAL_PURCHASE', app_user_id: u.userId, expiration_at_ms: t.clock.now.getTime() + 1e9 };
    expect((await rc(e)).json().status).toBe('applied');
    expect((await rc(e)).json().status).toBe('duplicate');
  });

  it('a failed apply leaves no processed marker, so the provider retry is applied', async () => {
    const u = await signUp(t);
    const e = { id: 'retry-1', type: 'INITIAL_PURCHASE', app_user_id: u.userId, original_transaction_id: 'GPA.retry', expiration_at_ms: t.clock.now.getTime() + 1e9 };
    // Make the entitlement write fail (simulated DB blip) until the trigger is dropped below.
    await sql`create or replace function fail_entitlement_once() returns trigger as $$
      begin raise exception 'simulated db blip'; end $$ language plpgsql`.execute(t.ctx.db);
    await sql`create trigger fail_entitlement_once before insert on entitlements for each row execute function fail_entitlement_once()`.execute(t.ctx.db);
    try {
      expect((await rc(e)).statusCode).toBe(500);
      const marker = await t.ctx.db.selectFrom('billing_events').select('event_id').where('event_id', '=', 'retry-1').executeTakeFirst();
      expect(marker).toBeUndefined();
    } finally {
      await sql`drop trigger if exists fail_entitlement_once on entitlements`.execute(t.ctx.db);
    }
    // The retry is applied, and the one after that is a duplicate.
    expect((await rc(e)).json().status).toBe('applied');
    expect((await t.app.inject({ method: 'GET', url: '/v1/entitlements', headers: u.auth })).json().premium).toBe(true);
    expect((await rc(e)).json().status).toBe('duplicate');
  });

  it('rejects a bad authorization header', async () => {
    expect((await rc({ id: 'x', type: 'RENEWAL', app_user_id: 'x' }, 'wrong-auth-value-123')).statusCode).toBe(401);
  });
});

describe('Razorpay (gym licence) webhooks', () => {
  const send = (body: unknown, secret = TEST_ENV.RAZORPAY_WEBHOOK_SECRET, eventId = `evt_${Math.random()}`) => {
    const raw = JSON.stringify(body);
    return t.app.inject({
      method: 'POST',
      url: '/v1/webhooks/razorpay',
      headers: { 'content-type': 'application/json', 'x-razorpay-signature': hmacSha256Hex(secret, raw), 'x-razorpay-event-id': eventId },
      payload: raw,
    });
  };

  it('a paid payment link activates the gym and extends members', async () => {
    const g = await t.app.inject({
      method: 'POST',
      url: '/v1/admin/gyms',
      headers: admin,
      payload: { name: 'Pulse Fitness', city: 'Ahmedabad', colours: { primary: '#1565c0', secondary: '#ffffff' }, licenceDays: 10 },
    });
    const gymId = g.json().id;
    const code = (await t.app.inject({ method: 'POST', url: `/v1/admin/gyms/${gymId}/codes`, headers: admin, payload: {} })).json().code;
    const m = await signUp(t);
    await t.app.inject({ method: 'POST', url: '/v1/gyms/join', headers: m.auth, payload: { code, shareActivity: false } });

    const r = await send({ event: 'payment_link.paid', payload: { payment_link: { entity: { id: 'plink_1', notes: { gym_id: gymId, plan: 'founding', period: 'yearly' } } } } }, undefined, 'evt_pl_1');
    expect(r.json().status).toBe('applied');
    const gym = await t.ctx.db.selectFrom('gyms').selectAll().where('id', '=', gymId).executeTakeFirstOrThrow();
    expect(gym.status).toBe('active');
    expect(gym.plan).toBe('founding');
    const ent = (await t.app.inject({ method: 'GET', url: '/v1/entitlements', headers: m.auth })).json();
    expect(new Date(ent.activeUntil).getTime()).toBe(new Date(gym.licence_until).getTime());
    expect(new Date(ent.activeUntil).getTime() - t.clock.now.getTime()).toBeGreaterThan(360 * 86_400_000);

    // Replays are ignored.
    const again = await send({ event: 'payment_link.paid', payload: {} }, undefined, 'evt_pl_1');
    expect(again.json().status).toBe('duplicate');
  });

  it('does not record unhandled event types, so they can be replayed later', async () => {
    const r = await send({ event: 'refund.created', payload: {} }, undefined, 'evt_unhandled_1');
    expect(r.json().status).toBe('ignored');
    const marker = await t.ctx.db.selectFrom('billing_events').select('event_id').where('event_id', '=', 'evt_unhandled_1').executeTakeFirst();
    expect(marker).toBeUndefined();
  });

  it('rejects a forged signature', async () => {
    const r = await send({ event: 'payment_link.paid', payload: {} }, 'not-the-secret-123');
    expect(r.statusCode).toBe(401);
  });
});
