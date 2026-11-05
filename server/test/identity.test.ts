import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { nextPhone, setup, signUp, type TestApp } from './helpers.js';

let t: TestApp;
beforeAll(async () => {
  t = await setup();
});
afterAll(async () => t.close());

describe('phone OTP sign-in', () => {
  it('signs up an adult and returns tokens', async () => {
    const phone = nextPhone();
    const start = await t.app.inject({ method: 'POST', url: '/v1/auth/otp/start', payload: { phone } });
    expect(start.statusCode).toBe(202);
    const code = t.sms.at(-1)!.code;
    const r = await t.app.inject({ method: 'POST', url: '/v1/auth/otp/verify', payload: { phone, code, ageConfirmed: true } });
    expect(r.statusCode).toBe(200);
    const body = r.json();
    expect(body.isNew).toBe(true);
    expect(body.accessToken).toBeTruthy();
    expect(body.user.phone).toMatch(/^\+91\*{6}\d{4}$/);
    // Phone is stored encrypted, never in clear.
    const row = await t.ctx.db.selectFrom('users').selectAll().where('id', '=', body.user.id).executeTakeFirstOrThrow();
    expect(row.phone_enc).not.toContain(phone.slice(3));
    expect(t.ctx.pii.decrypt(row.phone_enc!)).toBe(phone);
  });

  it('refuses a new account without the 18+ confirmation', async () => {
    const phone = nextPhone();
    await t.app.inject({ method: 'POST', url: '/v1/auth/otp/start', payload: { phone } });
    const r = await t.app.inject({ method: 'POST', url: '/v1/auth/otp/verify', payload: { phone, code: t.sms.at(-1)!.code } });
    expect(r.statusCode).toBe(400);
    expect(r.json().error).toBe('age_confirmation_required');
  });

  it('rejects a wrong code and locks after 5 attempts', async () => {
    const phone = nextPhone();
    await t.app.inject({ method: 'POST', url: '/v1/auth/otp/start', payload: { phone } });
    const good = t.sms.at(-1)!.code;
    const bad = good === '000000' ? '111111' : '000000';
    for (let i = 0; i < 5; i++) {
      const r = await t.app.inject({ method: 'POST', url: '/v1/auth/otp/verify', payload: { phone, code: bad, ageConfirmed: true } });
      expect(r.statusCode).toBe(401);
    }
    const r = await t.app.inject({ method: 'POST', url: '/v1/auth/otp/verify', payload: { phone, code: good, ageConfirmed: true } });
    expect(r.statusCode).toBe(429);
  });

  it('expires codes after 5 minutes', async () => {
    const phone = nextPhone();
    await t.app.inject({ method: 'POST', url: '/v1/auth/otp/start', payload: { phone } });
    const code = t.sms.at(-1)!.code;
    const was = t.clock.now;
    t.clock.now = new Date(was.getTime() + 6 * 60_000);
    const r = await t.app.inject({ method: 'POST', url: '/v1/auth/otp/verify', payload: { phone, code, ageConfirmed: true } });
    t.clock.now = was;
    expect(r.json().error).toBe('otp_expired');
  });

  it('rate-limits OTP requests per phone', async () => {
    const phone = nextPhone();
    const codes = [];
    for (let i = 0; i < 4; i++) codes.push((await t.app.inject({ method: 'POST', url: '/v1/auth/otp/start', payload: { phone } })).statusCode);
    expect(codes).toEqual([202, 202, 202, 429]);
  });

  it('only accepts Indian mobile numbers', async () => {
    const r = await t.app.inject({ method: 'POST', url: '/v1/auth/otp/start', payload: { phone: '+1555123456' } });
    expect(r.statusCode).toBe(400);
  });
});

describe('Google sign-in', () => {
  it('creates once and signs in again', async () => {
    const a = await t.app.inject({ method: 'POST', url: '/v1/auth/google', payload: { idToken: 'google:sub-123', ageConfirmed: true } });
    expect(a.json().isNew).toBe(true);
    expect(a.json().user.name).toBe('Asha Patel');
    const b = await t.app.inject({ method: 'POST', url: '/v1/auth/google', payload: { idToken: 'google:sub-123' } });
    expect(b.json().isNew).toBe(false);
    const bad = await t.app.inject({ method: 'POST', url: '/v1/auth/google', payload: { idToken: 'forged-token-xyz' } });
    expect(bad.statusCode).toBe(401);
  });
});

describe('tokens', () => {
  it('rotates refresh tokens and revokes the family on reuse', async () => {
    const u = await signUp(t);
    const r1 = await t.app.inject({ method: 'POST', url: '/v1/auth/refresh', payload: { refreshToken: u.refreshToken } });
    expect(r1.statusCode).toBe(200);
    const next = r1.json().refreshToken;
    // Replaying the old token = theft: everything in the family dies.
    const replay = await t.app.inject({ method: 'POST', url: '/v1/auth/refresh', payload: { refreshToken: u.refreshToken } });
    expect(replay.json().error).toBe('refresh_reused');
    const after = await t.app.inject({ method: 'POST', url: '/v1/auth/refresh', payload: { refreshToken: next } });
    expect(after.statusCode).toBe(401);
  });

  it('rejects missing or forged access tokens', async () => {
    expect((await t.app.inject({ method: 'GET', url: '/v1/me' })).statusCode).toBe(401);
    expect((await t.app.inject({ method: 'GET', url: '/v1/me', headers: { authorization: 'Bearer abc.def.ghi' } })).statusCode).toBe(401);
  });
});

describe('account, consent, export, deletion', () => {
  it('updates profile and language', async () => {
    const u = await signUp(t);
    const r = await t.app.inject({ method: 'PATCH', url: '/v1/me', headers: u.auth, payload: { language: 'gu' } });
    expect(r.json().language).toBe('gu');
  });

  it('grants and withdraws consent per purpose', async () => {
    const u = await signUp(t);
    await t.app.inject({ method: 'PUT', url: '/v1/me/consents', headers: u.auth, payload: { consents: [{ purpose: 'analytics', granted: true }] } });
    await t.app.inject({ method: 'PUT', url: '/v1/me/consents', headers: u.auth, payload: { consents: [{ purpose: 'analytics', granted: false }] } });
    const r = await t.app.inject({ method: 'GET', url: '/v1/me/consents', headers: u.auth });
    const c = r.json().consents;
    expect(c.find((x: { purpose: string }) => x.purpose === 'account').withdrawnAt).toBeNull();
    expect(c.find((x: { purpose: string }) => x.purpose === 'analytics').withdrawnAt).not.toBeNull();
  });

  it('exports all data and never includes images', async () => {
    const u = await signUp(t);
    const r = await t.app.inject({ method: 'GET', url: '/v1/me/export', headers: u.auth });
    expect(r.statusCode).toBe(200);
    const body = r.json();
    expect(body.user.id).toBe(u.userId);
    expect(body.note).toMatch(/never stores camera images/);
  });

  it('deletes the account: scrubs identifiers and blocks access', async () => {
    const u = await signUp(t);
    const r = await t.app.inject({ method: 'DELETE', url: '/v1/me', headers: u.auth });
    expect(r.statusCode).toBe(202);
    const row = await t.ctx.db.selectFrom('users').selectAll().where('id', '=', u.userId).executeTakeFirstOrThrow();
    expect(row.phone_enc).toBeNull();
    expect(row.phone_hash).toBeNull();
    expect((await t.app.inject({ method: 'GET', url: '/v1/me', headers: u.auth })).statusCode).toBe(401);
    expect((await t.app.inject({ method: 'POST', url: '/v1/auth/refresh', payload: { refreshToken: u.refreshToken } })).statusCode).toBe(401);
  });
});
