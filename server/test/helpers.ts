import { randomBytes } from 'node:crypto';

import type { FastifyInstance } from 'fastify';
import { sql } from 'kysely';
import { Redis } from 'ioredis';

import { buildApp } from '../src/app.js';
import { loadConfig } from '../src/config.js';
import type { AppContext } from '../src/context.js';
import { createDb } from '../src/db/database.js';

export const TEST_ENV = {
  NODE_ENV: 'test',
  DATABASE_URL: process.env.TEST_DATABASE_URL ?? 'postgres://postgres@localhost:5432/motionquest_test',
  REDIS_URL: process.env.TEST_REDIS_URL ?? 'redis://localhost:6379/1',
  JWT_SECRET: 'test-secret-test-secret-test-secret-0123',
  PII_ENCRYPTION_KEY: randomBytes(32).toString('base64'),
  PII_HASH_PEPPER: 'test-pepper-0123456789',
  ADMIN_API_KEY: 'admin-key-0123456789abcdef',
  REVENUECAT_WEBHOOK_AUTH: 'rc-auth-0123456789abcdef',
  RAZORPAY_WEBHOOK_SECRET: 'rzp-secret-0123456789',
  CONTENT_DIR: '../content/levels',
};

export const paymentLinkRequests: unknown[] = [];

export interface TestApp {
  app: FastifyInstance;
  ctx: AppContext;
  sms: { phone: string; code: string }[];
  whatsapp: { phone: string; body: string }[];
  clock: { now: Date };
  close: () => Promise<void>;
}

/** Fresh schema + flushed Redis for each test file. Real PostgreSQL, real Redis. */
export async function setup(): Promise<TestApp> {
  const config = loadConfig(TEST_ENV as unknown as NodeJS.ProcessEnv);
  const db = createDb(config.DATABASE_URL);
  await sql`drop schema if exists public cascade`.execute(db);
  await sql`create schema public`.execute(db);
  const redis = new Redis(config.REDIS_URL);
  await redis.flushdb();
  const sms: TestApp['sms'] = [];
  const whatsapp: TestApp['whatsapp'] = [];
  const clock = { now: new Date('2026-11-04T10:00:00Z') }; // a Wednesday
  const { app, ctx } = await buildApp({
    config,
    db,
    redis,
    logger: false,
    now: () => clock.now,
    providers: {
      sms: { sendOtp: async (phone, code) => void sms.push({ phone, code }) },
      whatsapp: { sendText: async (phone, body) => void whatsapp.push({ phone, body }) },
      google: { verify: async (t) => (t.startsWith('google:') ? { sub: t.slice(7), name: 'Asha Patel' } : null) },
      paymentLinks: {
        create: async (r) => {
          paymentLinkRequests.push(r);
          return { id: 'plink_test', shortUrl: 'https://rzp.io/i/test' };
        },
      },
    },
  });
  return {
    app,
    ctx,
    sms,
    whatsapp,
    clock,
    close: async () => {
      await app.close();
      await db.destroy();
      redis.disconnect();
    },
  };
}

let phoneSeq = 0;
export function nextPhone() {
  phoneSeq++;
  return `+9198${String(10000000 + phoneSeq).slice(-8)}`;
}

/** Signs up a fresh player through the real OTP flow. */
export async function signUp(t: TestApp, name = 'Ravi Shah') {
  const phone = nextPhone();
  // Every test request comes from 127.0.0.1; reset the per-IP OTP window.
  await t.ctx.redis.del('rl:otp:ip:127.0.0.1');
  await t.app.inject({ method: 'POST', url: '/v1/auth/otp/start', payload: { phone } });
  const code = t.sms.filter((s) => s.phone === phone).at(-1)!.code;
  const r = await t.app.inject({ method: 'POST', url: '/v1/auth/otp/verify', payload: { phone, code, ageConfirmed: true } });
  const body = r.json();
  const auth = { authorization: `Bearer ${body.accessToken}` };
  await t.app.inject({ method: 'PATCH', url: '/v1/me', headers: auth, payload: { name } });
  return { phone, auth, userId: body.user.id as string, refreshToken: body.refreshToken as string };
}

export const admin = { 'x-admin-key': TEST_ENV.ADMIN_API_KEY };

let clientSeq = 0;
export function session(over: Record<string, unknown> = {}) {
  clientSeq++;
  return {
    clientId: `client-${clientSeq}-${Date.now()}`,
    levelId: 'w1-forest-escape',
    startedAt: '2026-11-04T09:00:00.000Z',
    durationS: 300,
    activeS: 240,
    score: 4200,
    difficulty: 'beginner',
    lowImpact: true,
    completed: true,
    effortRating: 3,
    moves: [
      { move: 'squat', attempts: 12, recognised: 11, falseTriggers: 0, avgLatencyMs: 110 },
      { move: 'raiseArms', attempts: 8, recognised: 8, falseTriggers: 0, avgLatencyMs: 140 },
    ],
    ...over,
  };
}
