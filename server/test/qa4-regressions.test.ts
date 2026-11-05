import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { hmacSha256Hex } from '../src/lib/crypto.js';
import { admin, session, setup, signUp, TEST_ENV, type TestApp } from './helpers.js';

let t: TestApp;
beforeAll(async () => {
  t = await setup();
});
afterAll(async () => t.close());

const UNKNOWN = '6f1c2b8e-4d3a-4f5b-9c7d-1e2f3a4b5c6d';
const post = (auth: Record<string, string>, sessions: unknown[]) => t.app.inject({ method: 'POST', url: '/v1/sessions', headers: auth, payload: { sessions } });
const device = async (auth: Record<string, string>) =>
  (await t.app.inject({ method: 'POST', url: '/v1/devices', headers: auth, payload: { model: 'Pixel', perfTier: 'mid', appVersion: '1.0.0' } })).json().id as string;
const rzp = (body: unknown, eventId?: string) => {
  const raw = JSON.stringify(body);
  const headers: Record<string, string> = { 'content-type': 'application/json', 'x-razorpay-signature': hmacSha256Hex(TEST_ENV.RAZORPAY_WEBHOOK_SECRET, raw) };
  if (eventId) headers['x-razorpay-event-id'] = eventId;
  return t.app.inject({ method: 'POST', url: '/v1/webhooks/razorpay', headers, payload: raw });
};
const rc = (event: Record<string, unknown>) =>
  t.app.inject({ method: 'POST', url: '/v1/webhooks/revenuecat', headers: { authorization: `Bearer ${TEST_ENV.REVENUECAT_WEBHOOK_AUTH}` }, payload: { event } });
const newGym = async () =>
  (
    await t.app.inject({
      method: 'POST',
      url: '/v1/admin/gyms',
      headers: admin,
      payload: { name: 'QA Gym', city: 'Pune', colours: { primary: '#1565c0', secondary: '#ffffff' }, licenceDays: 10 },
    })
  ).json().id as string;

describe('QA4 sessions validation', () => {
  it('Q4-1: duplicate move names are a 400, not a 500', async () => {
    const u = await signUp(t);
    const m = { move: 'squat', attempts: 1, recognised: 1, falseTriggers: 0 };
    expect((await post(u.auth, [session({ moves: [m, m] })])).statusCode).toBe(400);
  });

  it("Q4-2: unknown or another user's deviceId is rejected", async () => {
    const a = await signUp(t);
    const b = await signUp(t);
    const bDev = await device(b.auth);
    expect((await post(a.auth, [session({ deviceId: UNKNOWN })])).statusCode).toBe(400);
    expect((await post(a.auth, [session({ deviceId: bDev })])).statusCode).toBe(400);
    const aDev = await device(a.auth);
    expect((await post(a.auth, [session({ deviceId: aDev })])).statusCode).toBe(200);
  });

  it('Q4-8: future startedAt and unknown levelId are rejected', async () => {
    const u = await signUp(t);
    expect((await post(u.auth, [session({ startedAt: '2031-01-01T00:00:00.000Z' })])).statusCode).toBe(400);
    expect((await post(u.auth, [session({ levelId: 'w9-nope' })])).statusCode).toBe(400);
  });
});

describe('QA4 webhooks', () => {
  it('Q4-3: null body and malformed gym_id do not 500; uppercase uuid is accepted', async () => {
    expect((await rzp(null, 'evt_null')).statusCode).toBe(400);
    const dashes = await rzp({ event: 'payment_link.paid', payload: { payment_link: { entity: { id: 'pl_d', notes: { gym_id: '-'.repeat(36) } } } } }, 'evt_dash');
    expect(dashes.statusCode).toBe(200);
    expect(dashes.json().status).toBe('ignored');
    const gymId = await newGym();
    const upper = await rzp({ event: 'payment_link.paid', payload: { payment_link: { entity: { id: 'pl_u', notes: { gym_id: gymId.toUpperCase(), plan: 'starter' } } } } }, 'evt_upper');
    expect(upper.json().status).toBe('applied');
  });

  it('Q4-4: without an event id header, distinct bodies are not collapsed into one event', async () => {
    expect((await rzp({ event: 'payment_link.paid', payload: { x: {} } })).json().status).toBe('ignored');
    const gymId = await newGym();
    const r = await rzp({ event: 'payment_link.paid', payload: { payment_link: { entity: { notes: { gym_id: gymId } } } } });
    expect(r.json().status).toBe('applied');
  });

  it('Q4-5: non-UUID app_user_id is ignored and huge expiration_at_ms is a 400', async () => {
    const r = await rc({ id: 'rc-anon', type: 'INITIAL_PURCHASE', app_user_id: '$RCAnonymousID:abc', expiration_at_ms: Date.now() + 1e9 });
    expect(r.statusCode).toBe(200);
    expect(r.json().status).toBe('ignored');
    const u = await signUp(t);
    expect((await rc({ id: 'rc-big', type: 'INITIAL_PURCHASE', app_user_id: u.userId, expiration_at_ms: 9e18 })).statusCode).toBe(400);
  });
});

describe('QA4 admin unknown gym', () => {
  it('Q4-6/Q4-7: report and quest creation for an unknown gym are 404', async () => {
    expect((await t.app.inject({ method: 'GET', url: `/v1/admin/gyms/${UNKNOWN}/report`, headers: admin })).statusCode).toBe(404);
    const q = await t.app.inject({
      method: 'POST',
      url: `/v1/admin/gyms/${UNKNOWN}/quests`,
      headers: admin,
      payload: { levelId: 'w1-forest-escape', title: 'Quest', dueAt: '2026-11-20T00:00:00.000Z' },
    });
    expect(q.statusCode).toBe(404);
  });
});

describe('QA4 batch dedupe', () => {
  it('Q4-9: a clientId repeated in one batch is reported once', async () => {
    const u = await signUp(t);
    const s = session();
    const r = (await post(u.auth, [s, s])).json();
    expect(r.accepted).toEqual([s.clientId]);
    expect(r.duplicates).toEqual([]);
  });
});
