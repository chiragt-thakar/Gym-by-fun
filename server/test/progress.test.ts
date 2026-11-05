import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { nextStreak } from '../src/modules/progress/service.js';
import { session, setup, signUp, type TestApp } from './helpers.js';

let t: TestApp;
beforeAll(async () => {
  t = await setup();
});
afterAll(async () => t.close());

describe('session upload', () => {
  it('is idempotent on clientId', async () => {
    const u = await signUp(t);
    const s = session();
    const a = await t.app.inject({ method: 'POST', url: '/v1/sessions', headers: u.auth, payload: { sessions: [s] } });
    expect(a.json().accepted).toEqual([s.clientId]);
    const b = await t.app.inject({ method: 'POST', url: '/v1/sessions', headers: u.auth, payload: { sessions: [s] } });
    expect(b.json().duplicates).toEqual([s.clientId]);
    expect(b.json().progress.sessions).toBe(1);
  });

  it('builds XP, hero level and a streak across days', async () => {
    const u = await signUp(t);
    const r = await t.app.inject({
      method: 'POST',
      url: '/v1/sessions',
      headers: u.auth,
      payload: {
        sessions: [
          session({ startedAt: '2026-11-01T05:00:00.000Z' }),
          session({ startedAt: '2026-11-02T05:00:00.000Z' }),
          session({ startedAt: '2026-11-03T05:00:00.000Z' }),
        ],
      },
    });
    const p = r.json().progress;
    expect(p.streak).toBe(3);
    expect(p.xp).toBeGreaterThan(0);
    expect(p.heroLevel).toBeGreaterThanOrEqual(1);
    const g = await t.app.inject({ method: 'GET', url: '/v1/progress', headers: u.auth });
    expect(g.json().personalBests['w1-forest-escape']).toBe(4200);
    expect(g.json().recent).toHaveLength(3);
  });

  it('flags impossible rep rates and keeps them out of progress', async () => {
    const u = await signUp(t);
    const s = session({ activeS: 30, moves: [{ move: 'squat', attempts: 200, recognised: 200, falseTriggers: 0 }] });
    const r = await t.app.inject({ method: 'POST', url: '/v1/sessions', headers: u.auth, payload: { sessions: [s] } });
    expect(r.json().flagged).toEqual([s.clientId]);
    expect(r.json().progress.sessions).toBe(0);
  });

  it('validates payloads', async () => {
    const u = await signUp(t);
    const r = await t.app.inject({ method: 'POST', url: '/v1/sessions', headers: u.auth, payload: { sessions: [session({ difficulty: 'insane' })] } });
    expect(r.statusCode).toBe(400);
  });
});

describe('streak rules', () => {
  const base = { streak: 4, best: 4, shields: 2, shieldsMonth: '2026-11', lastPlayedOn: '2026-11-10' };
  it('same day keeps the streak', () => {
    expect(nextStreak(base, new Date('2026-11-10T12:00:00Z')).streak).toBe(4);
  });
  it('a missed day uses a shield', () => {
    const s = nextStreak(base, new Date('2026-11-12T06:00:00Z'));
    expect(s).toMatchObject({ streak: 5, shields: 1 });
  });
  it('too many missed days restart at 1 without touching best', () => {
    const s = nextStreak(base, new Date('2026-11-20T06:00:00Z'));
    expect(s).toMatchObject({ streak: 1, best: 4 });
  });
  it('shields refill each month', () => {
    const s = nextStreak({ ...base, shields: 0, shieldsMonth: '2026-10', lastPlayedOn: '2026-10-30' }, new Date('2026-11-01T06:00:00Z'));
    expect(s).toMatchObject({ streak: 5, shields: 1 });
  });
  it('uses India time for the calendar day', () => {
    // 20:00 UTC on the 10th is 01:30 IST on the 11th: the next day.
    expect(nextStreak(base, new Date('2026-11-10T20:00:00Z')).streak).toBe(5);
  });
});

describe('calibration backup and pain reports', () => {
  it('needs consent before body measurements leave the phone', async () => {
    const u = await signUp(t);
    const d = await t.app.inject({ method: 'POST', url: '/v1/devices', headers: u.auth, payload: { model: 'Redmi 13C', perfTier: 'budget', appVersion: '0.1.0' } });
    const deviceId = d.json().id;
    const payload = { deviceId, profile: { squatDepth: 0.12, leanRangeLeft: 0.07, leanRangeRight: 0.08, reachY: 0.1 } };
    expect((await t.app.inject({ method: 'PUT', url: '/v1/me/calibration', headers: u.auth, payload })).statusCode).toBe(403);
    await t.app.inject({ method: 'PUT', url: '/v1/me/consents', headers: u.auth, payload: { consents: [{ purpose: 'calibration_backup', granted: true }] } });
    expect((await t.app.inject({ method: 'PUT', url: '/v1/me/calibration', headers: u.auth, payload })).statusCode).toBe(200);
    // Withdrawing consent deletes the backup.
    await t.app.inject({ method: 'PUT', url: '/v1/me/consents', headers: u.auth, payload: { consents: [{ purpose: 'calibration_backup', granted: false }] } });
    const g = await t.app.inject({ method: 'GET', url: '/v1/me/calibration', headers: u.auth });
    expect(g.json().calibrations).toHaveLength(0);
  });

  it('accepts a pain report with safety advice', async () => {
    const u = await signUp(t);
    const r = await t.app.inject({ method: 'POST', url: '/v1/me/pain-reports', headers: u.auth, payload: { area: 'knees', note: 'twinge on squats' } });
    expect(r.statusCode).toBe(201);
    expect(r.json().advice).toMatch(/doctor/);
  });
});
