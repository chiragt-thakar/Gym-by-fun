import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { AppContext } from '../../context.js';
import type { ConsentPurpose } from '../../db/schema.js';
import { requireUser } from '../../lib/auth.js';
import { keyedHash, otpCode, safeEqual } from '../../lib/crypto.js';
import { badRequest, tooMany, unauthorized } from '../../lib/errors.js';
import { allow } from '../../lib/rate-limit.js';
import { parse } from '../../lib/validate.js';
import { issueTokens, revokeAllForUser, rotateRefresh } from './tokens.js';

/** Current consent text versions. Bump when the wording changes. */
export const CONSENT_VERSIONS: Record<ConsentPurpose, number> = {
  account: 1,
  gym_sharing: 1,
  analytics: 1,
  calibration_backup: 1,
};

const phoneSchema = z.string().regex(/^\+91[6-9]\d{9}$/, 'Indian mobile number in +91 format');
const OTP_TTL_MS = 5 * 60 * 1000;
const OTP_MAX_ATTEMPTS = 5;

export async function grantConsent(ctx: AppContext, userId: string, purpose: ConsentPurpose) {
  const active = await ctx.db
    .selectFrom('consents')
    .select('id')
    .where('user_id', '=', userId)
    .where('purpose', '=', purpose)
    .where('withdrawn_at', 'is', null)
    .executeTakeFirst();
  if (active) return;
  await ctx.db
    .insertInto('consents')
    .values({ user_id: userId, purpose, version: CONSENT_VERSIONS[purpose], granted_at: ctx.now() })
    .execute();
}

export async function withdrawConsent(ctx: AppContext, userId: string, purpose: ConsentPurpose) {
  await ctx.db
    .updateTable('consents')
    .set({ withdrawn_at: ctx.now() })
    .where('user_id', '=', userId)
    .where('purpose', '=', purpose)
    .where('withdrawn_at', 'is', null)
    .execute();
}

export async function hasConsent(ctx: AppContext, userId: string, purpose: ConsentPurpose) {
  const r = await ctx.db
    .selectFrom('consents')
    .select('id')
    .where('user_id', '=', userId)
    .where('purpose', '=', purpose)
    .where('withdrawn_at', 'is', null)
    .executeTakeFirst();
  return !!r;
}

async function publicUser(ctx: AppContext, userId: string) {
  const u = await ctx.db.selectFrom('users').selectAll().where('id', '=', userId).executeTakeFirstOrThrow();
  return {
    id: u.id,
    name: u.name,
    language: u.language,
    phone: u.phone_enc ? maskPhone(ctx.pii.decrypt(u.phone_enc)) : null,
    google: !!u.google_sub,
    createdAt: u.created_at,
  };
}

const maskPhone = (p: string) => `${p.slice(0, 3)}******${p.slice(-4)}`;

export async function identityRoutes(app: FastifyInstance, ctx: AppContext) {
  const pepper = ctx.config.PII_HASH_PEPPER;
  const auth = requireUser(ctx);

  app.post('/auth/otp/start', async (req, reply) => {
    const { phone } = parse(z.object({ phone: phoneSchema }), req.body);
    const ph = keyedHash(pepper, phone);
    // Rate limits: per phone and per client IP.
    if (!(await allow(ctx.redis, `otp:phone:${ph}`, 3, 600))) throw tooMany('otp_rate_limited');
    if (!(await allow(ctx.redis, `otp:ip:${req.ip}`, 10, 3600))) throw tooMany('otp_rate_limited');
    const code = otpCode();
    await ctx.db
      .insertInto('otp_challenges')
      .values({ phone_hash: ph, code_hash: keyedHash(pepper, `${ph}:${code}`), expires_at: new Date(ctx.now().getTime() + OTP_TTL_MS) })
      .execute();
    await ctx.providers.sms.sendOtp(phone, code);
    return reply.code(202).send({ sent: true, expiresIn: OTP_TTL_MS / 1000 });
  });

  app.post('/auth/otp/verify', async (req) => {
    const body = parse(
      z.object({ phone: phoneSchema, code: z.string().regex(/^\d{6}$/), ageConfirmed: z.boolean().optional(), language: z.enum(['en', 'hi', 'gu']).optional() }),
      req.body,
    );
    const ph = keyedHash(pepper, body.phone);
    const ch = await ctx.db
      .selectFrom('otp_challenges')
      .selectAll()
      .where('phone_hash', '=', ph)
      .where('consumed_at', 'is', null)
      .orderBy('created_at', 'desc')
      .limit(1)
      .executeTakeFirst();
    if (!ch || new Date(ch.expires_at) <= ctx.now()) throw unauthorized('otp_expired');
    if (ch.attempts >= OTP_MAX_ATTEMPTS) throw tooMany('otp_attempts_exceeded');
    await ctx.db.updateTable('otp_challenges').set({ attempts: ch.attempts + 1 }).where('id', '=', ch.id).execute();
    if (!safeEqual(ch.code_hash, keyedHash(pepper, `${ph}:${body.code}`))) throw unauthorized('otp_invalid');
    await ctx.db.updateTable('otp_challenges').set({ consumed_at: ctx.now() }).where('id', '=', ch.id).execute();

    let user = await ctx.db.selectFrom('users').select(['id', 'deleted_at']).where('phone_hash', '=', ph).executeTakeFirst();
    const isNew = !user;
    if (!user) {
      // Adults only: an account is created only after the 18+ confirmation.
      if (body.ageConfirmed !== true) throw badRequest('age_confirmation_required');
      user = await ctx.db
        .insertInto('users')
        .values({ phone_hash: ph, phone_enc: ctx.pii.encrypt(body.phone), age_confirmed_at: ctx.now(), language: body.language ?? 'en' })
        .returning(['id', 'deleted_at'])
        .executeTakeFirstOrThrow();
      await grantConsent(ctx, user.id, 'account');
    }
    if (user.deleted_at) throw unauthorized('account_deleted');
    return { ...(await issueTokens(ctx, user.id)), isNew, user: await publicUser(ctx, user.id) };
  });

  app.post('/auth/google', async (req) => {
    const body = parse(z.object({ idToken: z.string().min(10), ageConfirmed: z.boolean().optional(), language: z.enum(['en', 'hi', 'gu']).optional() }), req.body);
    const g = await ctx.providers.google.verify(body.idToken);
    if (!g) throw unauthorized('google_invalid');
    let user = await ctx.db.selectFrom('users').select(['id', 'deleted_at']).where('google_sub', '=', g.sub).executeTakeFirst();
    const isNew = !user;
    if (!user) {
      if (body.ageConfirmed !== true) throw badRequest('age_confirmation_required');
      user = await ctx.db
        .insertInto('users')
        .values({ google_sub: g.sub, name: g.name ?? null, age_confirmed_at: ctx.now(), language: body.language ?? 'en' })
        .returning(['id', 'deleted_at'])
        .executeTakeFirstOrThrow();
      await grantConsent(ctx, user.id, 'account');
    }
    if (user.deleted_at) throw unauthorized('account_deleted');
    return { ...(await issueTokens(ctx, user.id)), isNew, user: await publicUser(ctx, user.id) };
  });

  app.post('/auth/refresh', async (req) => {
    const { refreshToken } = parse(z.object({ refreshToken: z.string().min(10) }), req.body);
    return rotateRefresh(ctx, refreshToken);
  });

  app.get('/me', { preHandler: auth }, async (req) => publicUser(ctx, req.userId));

  app.patch('/me', { preHandler: auth }, async (req) => {
    const body = parse(z.object({ name: z.string().trim().min(1).max(40).optional(), language: z.enum(['en', 'hi', 'gu']).optional() }), req.body);
    if (Object.keys(body).length) await ctx.db.updateTable('users').set(body).where('id', '=', req.userId).execute();
    return publicUser(ctx, req.userId);
  });

  app.get('/me/consents', { preHandler: auth }, async (req) => {
    const rows = await ctx.db.selectFrom('consents').selectAll().where('user_id', '=', req.userId).orderBy('granted_at').execute();
    return { consents: rows.map((r) => ({ purpose: r.purpose, version: r.version, grantedAt: r.granted_at, withdrawnAt: r.withdrawn_at })) };
  });

  app.put('/me/consents', { preHandler: auth }, async (req) => {
    const body = parse(
      z.object({ consents: z.array(z.object({ purpose: z.enum(['gym_sharing', 'analytics', 'calibration_backup']), granted: z.boolean() })).min(1) }),
      req.body,
    );
    for (const c of body.consents) {
      if (c.granted) await grantConsent(ctx, req.userId, c.purpose);
      else {
        await withdrawConsent(ctx, req.userId, c.purpose);
        if (c.purpose === 'gym_sharing') {
          await ctx.db.updateTable('memberships').set({ shares_activity: false }).where('user_id', '=', req.userId).execute();
        }
        if (c.purpose === 'calibration_backup') {
          await ctx.db.deleteFrom('calibrations').where('user_id', '=', req.userId).execute();
        }
      }
    }
    return { ok: true };
  });

  /** Data export (DPDP): everything we hold about the player. */
  app.get('/me/export', { preHandler: auth }, async (req) => {
    const id = req.userId;
    const [user, consents, devices, calibrations, sessions, progress, memberships, entitlements, pain] = await Promise.all([
      publicUser(ctx, id),
      ctx.db.selectFrom('consents').selectAll().where('user_id', '=', id).execute(),
      ctx.db.selectFrom('devices').selectAll().where('user_id', '=', id).execute(),
      ctx.db.selectFrom('calibrations').selectAll().where('user_id', '=', id).execute(),
      ctx.db.selectFrom('sessions').selectAll().where('user_id', '=', id).orderBy('started_at').execute(),
      ctx.db.selectFrom('progress').selectAll().where('user_id', '=', id).executeTakeFirst(),
      ctx.db.selectFrom('memberships').selectAll().where('user_id', '=', id).execute(),
      ctx.db.selectFrom('entitlements').selectAll().where('user_id', '=', id).execute(),
      ctx.db.selectFrom('pain_reports').selectAll().where('user_id', '=', id).execute(),
    ]);
    const sessionIds = sessions.map((s) => s.id);
    const moves = sessionIds.length ? await ctx.db.selectFrom('session_moves').selectAll().where('session_id', 'in', sessionIds).execute() : [];
    return {
      exportedAt: ctx.now(),
      note: 'MotionQuest never stores camera images or video. This is all the data held about you.',
      user: { ...user, phone: user.phone },
      consents,
      devices,
      calibrations,
      sessions,
      sessionMoves: moves,
      progress: progress ?? null,
      memberships,
      entitlements,
      painReports: pain,
    };
  });

  /**
   * Account deletion: immediate soft delete (identifiers scrubbed, tokens
   * revoked, gym sharing stopped); a nightly job hard-deletes after the
   * retention window.
   */
  app.delete('/me', { preHandler: auth }, async (req, reply) => {
    const id = req.userId;
    await ctx.db.transaction().execute(async (tx) => {
      await tx
        .updateTable('users')
        .set({ deleted_at: ctx.now(), phone_enc: null, phone_hash: null, google_sub: null, name: null })
        .where('id', '=', id)
        .execute();
      await tx.updateTable('memberships').set({ left_at: ctx.now(), shares_activity: false }).where('user_id', '=', id).where('left_at', 'is', null).execute();
      await tx.deleteFrom('calibrations').where('user_id', '=', id).execute();
      await tx.deleteFrom('crew_scores').where('user_id', '=', id).execute();
      await tx.updateTable('consents').set({ withdrawn_at: ctx.now() }).where('user_id', '=', id).where('withdrawn_at', 'is', null).execute();
    });
    await revokeAllForUser(ctx, id);
    return reply.code(202).send({ deleted: true, hardDeleteAfterDays: ctx.config.DELETION_GRACE_DAYS });
  });
}

/** Hard-deletes accounts past the retention window. Run nightly. */
export async function purgeDeletedAccounts(ctx: AppContext): Promise<number> {
  const cutoff = new Date(ctx.now().getTime() - ctx.config.DELETION_GRACE_DAYS * 86_400_000);
  const r = await ctx.db.deleteFrom('users').where('deleted_at', '<', cutoff).executeTakeFirst();
  return Number(r.numDeletedRows);
}
