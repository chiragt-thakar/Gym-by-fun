import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { sendWeeklyReports } from '../src/modules/reports/service.js';
import { admin, session, setup, signUp, type TestApp } from './helpers.js';

let t: TestApp;
let gymId: string;
let code: string;
let trainerKey: string;

beforeAll(async () => {
  t = await setup();
  const g = await t.app.inject({
    method: 'POST',
    url: '/v1/admin/gyms',
    headers: admin,
    payload: { name: 'Iron Paradise', city: 'Ahmedabad', colours: { primary: '#d32f2f', secondary: '#212121' }, ownerName: 'Mehul', ownerPhone: '+919825000001' },
  });
  expect(g.statusCode).toBe(201);
  gymId = g.json().id;
  trainerKey = g.json().trainerKey;
  const c = await t.app.inject({ method: 'POST', url: `/v1/admin/gyms/${gymId}/codes`, headers: admin, payload: { maxMembers: 3 } });
  code = c.json().code;
});
afterAll(async () => t.close());

describe('gym admin', () => {
  it('requires the admin key', async () => {
    const r = await t.app.inject({ method: 'POST', url: '/v1/admin/gyms', headers: { 'x-admin-key': 'nope' }, payload: {} });
    expect(r.statusCode).toBe(403);
  });

  it('renders a QR poster', async () => {
    const r = await t.app.inject({ method: 'GET', url: `/v1/admin/gyms/${gymId}/poster?code=${code}`, headers: admin });
    expect(r.headers['content-type']).toContain('image/svg+xml');
    expect(r.body).toContain(code);
    expect(r.body).toContain('Iron Paradise');
  });
});

describe('Gym Crew', () => {
  it('joining with a code gives Premium and gym branding', async () => {
    const u = await signUp(t, 'Kiran Desai');
    const before = await t.app.inject({ method: 'GET', url: '/v1/entitlements', headers: u.auth });
    expect(before.json().premium).toBe(false);
    const j = await t.app.inject({ method: 'POST', url: '/v1/gyms/join', headers: u.auth, payload: { code: code.toLowerCase(), shareActivity: true } });
    expect(j.statusCode).toBe(200);
    expect(j.json().gym.colours.primary).toBe('#d32f2f');
    const after = await t.app.inject({ method: 'GET', url: '/v1/entitlements', headers: u.auth });
    expect(after.json()).toMatchObject({ premium: true, source: 'gym' });
    // Leaving ends gym Premium.
    await t.app.inject({ method: 'DELETE', url: '/v1/gyms/membership', headers: u.auth });
    const gone = await t.app.inject({ method: 'GET', url: '/v1/entitlements', headers: u.auth });
    expect(gone.json().premium).toBe(false);
  });

  it('rejects unknown codes and enforces member limits', async () => {
    const u = await signUp(t);
    expect((await t.app.inject({ method: 'POST', url: '/v1/gyms/join', headers: u.auth, payload: { code: 'NOPE-123456', shareActivity: false } })).statusCode).toBe(404);
    const c = await t.app.inject({ method: 'POST', url: `/v1/admin/gyms/${gymId}/codes`, headers: admin, payload: { maxMembers: 1 } });
    const small = c.json().code;
    const a = await signUp(t);
    expect((await t.app.inject({ method: 'POST', url: '/v1/gyms/join', headers: a.auth, payload: { code: small, shareActivity: false } })).statusCode).toBe(200);
    expect((await t.app.inject({ method: 'POST', url: '/v1/gyms/join', headers: u.auth, payload: { code: small, shareActivity: false } })).json().error).toBe('gym_code_full');
  });

  it('crew board ranks by effort and shows only members who share', async () => {
    const sharer = await signUp(t, 'Priya Mehta');
    const hidden = await signUp(t, 'Secret Person');
    const outsider = await signUp(t);
    const c = await t.app.inject({ method: 'POST', url: `/v1/admin/gyms/${gymId}/codes`, headers: admin, payload: { maxMembers: 50 } });
    const big = c.json().code;
    await t.app.inject({ method: 'POST', url: '/v1/gyms/join', headers: sharer.auth, payload: { code: big, shareActivity: true } });
    await t.app.inject({ method: 'POST', url: '/v1/gyms/join', headers: hidden.auth, payload: { code: big, shareActivity: false } });
    for (const who of [sharer, hidden]) {
      await t.app.inject({ method: 'POST', url: '/v1/sessions', headers: who.auth, payload: { sessions: [session({ startedAt: '2026-11-04T06:00:00.000Z' })] } });
    }
    const b = await t.app.inject({ method: 'GET', url: `/v1/crews/${gymId}/board`, headers: sharer.auth });
    const entries = b.json().entries;
    expect(entries.map((e: { name: string }) => e.name)).toContain('Priya');
    expect(entries.map((e: { name: string }) => e.name)).not.toContain('Secret');
    expect(entries.find((e: { isMe: boolean }) => e.isMe).effortPoints).toBe(60);
    // The board survives a Redis wipe (rebuilt from the weekly snapshot).
    await t.ctx.redis.flushdb();
    const again = await t.app.inject({ method: 'GET', url: `/v1/crews/${gymId}/board`, headers: sharer.auth });
    expect(again.json().entries).toEqual(entries);
    // Non-members can't see it.
    expect((await t.app.inject({ method: 'GET', url: `/v1/crews/${gymId}/board`, headers: outsider.auth })).statusCode).toBe(403);
  });

  it('trainer quests: page, create, and member view', async () => {
    const page = await t.app.inject({ method: 'GET', url: `/v1/trainer/${gymId}?key=${encodeURIComponent(trainerKey)}` });
    expect(page.statusCode).toBe(200);
    expect(page.body).toContain('Iron Paradise');
    expect((await t.app.inject({ method: 'GET', url: `/v1/trainer/${gymId}?key=wrong-key-123` })).statusCode).toBe(403);
    const q = await t.app.inject({
      method: 'POST',
      url: `/v1/trainer/${gymId}/quests?key=${encodeURIComponent(trainerKey)}`,
      payload: { levelId: 'w1-forest-escape', title: 'Sunday rest-day run', dueAt: '2026-11-08T18:00:00.000Z' },
    });
    expect(q.statusCode).toBe(201);
    const m = await signUp(t);
    await t.app.inject({ method: 'POST', url: '/v1/gyms/join', headers: m.auth, payload: { code, shareActivity: true } });
    const mine = await t.app.inject({ method: 'GET', url: '/v1/gyms/mine', headers: m.auth });
    expect(mine.json().quests[0].title).toBe('Sunday rest-day run');
  });

  it('sends the Monday WhatsApp report once per week', async () => {
    // Move to the next Monday; the report covers last week.
    t.clock.now = new Date('2026-11-09T03:30:00Z'); // 09:00 IST Monday
    const r1 = await sendWeeklyReports(t.ctx);
    expect(r1.sent).toBe(1);
    const msg = t.whatsapp.at(-1)!;
    expect(msg.phone).toBe('+919825000001');
    expect(msg.body).toContain('Iron Paradise');
    expect(msg.body).toContain('Priya');
    expect(msg.body).not.toContain('Secret');
    const r2 = await sendWeeklyReports(t.ctx);
    expect(r2.sent).toBe(0);
    const rep = await t.app.inject({ method: 'GET', url: `/v1/admin/gyms/${gymId}/report`, headers: admin });
    expect(rep.json().report.activeMembers).toBeGreaterThanOrEqual(1);
  });
});
