import type { FastifyInstance } from 'fastify';
import { sql } from 'kysely';
import { z } from 'zod';

import type { AppContext } from '../../context.js';
import { requireUser } from '../../lib/auth.js';
import { badRequest, forbidden } from '../../lib/errors.js';
import { parse } from '../../lib/validate.js';
import { recordCrewEffort } from '../gyms/service.js';
import { hasConsent } from '../identity/routes.js';
import { effortPoints, getProgress, heroLevel, isImplausible, nextStreak, SHIELDS_PER_MONTH, xpFor } from './service.js';

const moveSchema = z.object({
  move: z.enum(['squat', 'leanLeft', 'leanRight', 'raiseArms']),
  attempts: z.number().int().min(0).max(10_000),
  recognised: z.number().int().min(0).max(10_000),
  falseTriggers: z.number().int().min(0).max(10_000),
  avgLatencyMs: z.number().int().min(0).max(10_000).nullish(),
});

const sessionSchema = z.object({
  clientId: z.string().min(8).max(64),
  levelId: z.string().regex(/^w\d+-[a-z0-9-]+$/),
  deviceId: z.string().uuid().nullish(),
  startedAt: z.string().datetime(),
  durationS: z.number().int().min(1).max(3600),
  activeS: z.number().int().min(0).max(3600),
  score: z.number().int().min(0).max(1_000_000),
  difficulty: z.enum(['beginner', 'intermediate', 'advanced']),
  lowImpact: z.boolean(),
  completed: z.boolean(),
  effortRating: z.number().int().min(1).max(5).nullish(),
  moves: z
    .array(moveSchema)
    .max(10)
    .default([])
    .refine((ms) => new Set(ms.map((m) => m.move)).size === ms.length, { message: 'duplicate_move' }),
});

/** Sessions may not start more than a day in the future (client clock skew allowance). */
const MAX_FUTURE_MS = 24 * 60 * 60 * 1000;

export async function progressRoutes(app: FastifyInstance, ctx: AppContext) {
  const auth = requireUser(ctx);

  app.post('/devices', { preHandler: auth }, async (req, reply) => {
    const body = parse(
      z.object({ model: z.string().min(1).max(80), perfTier: z.enum(['upper_mid', 'mid', 'budget']), appVersion: z.string().min(1).max(20) }),
      req.body,
    );
    const d = await ctx.db
      .insertInto('devices')
      .values({ user_id: req.userId, model: body.model, perf_tier: body.perfTier, app_version: body.appVersion })
      .returning('id')
      .executeTakeFirstOrThrow();
    return reply.code(201).send({ id: d.id });
  });

  /** Calibration backup: body measurements leave the phone only with consent. */
  app.put('/me/calibration', { preHandler: auth }, async (req) => {
    if (!(await hasConsent(ctx, req.userId, 'calibration_backup'))) throw forbidden('calibration_backup_not_enabled');
    const body = parse(
      z.object({
        deviceId: z.string().uuid(),
        profile: z.record(z.string(), z.number().finite()).refine((p) => Object.keys(p).length <= 20),
      }),
      req.body,
    );
    const dev = await ctx.db.selectFrom('devices').select('id').where('id', '=', body.deviceId).where('user_id', '=', req.userId).executeTakeFirst();
    if (!dev) throw forbidden('unknown_device');
    const p = body.profile;
    const row = {
      user_id: req.userId,
      device_id: body.deviceId,
      squat_depth: p.squatDepth ?? 0,
      lean_range: ((p.leanRangeLeft ?? 0) + (p.leanRangeRight ?? 0)) / 2,
      reach: p.reachY ?? 0,
      profile: JSON.stringify(p),
      updated_at: ctx.now(),
    };
    await ctx.db
      .insertInto('calibrations')
      .values(row)
      .onConflict((oc) => oc.columns(['user_id', 'device_id']).doUpdateSet(row))
      .execute();
    return { ok: true };
  });

  app.get('/me/calibration', { preHandler: auth }, async (req) => {
    const rows = await ctx.db.selectFrom('calibrations').select(['device_id', 'profile', 'updated_at']).where('user_id', '=', req.userId).execute();
    return { calibrations: rows.map((r) => ({ deviceId: r.device_id, profile: r.profile, updatedAt: r.updated_at })) };
  });

  /**
   * Batched, idempotent session upload from the phone's offline queue.
   * Re-sending the same clientId is a no-op.
   */
  app.post('/sessions', { preHandler: auth }, async (req) => {
    const { sessions } = parse(z.object({ sessions: z.array(sessionSchema).min(1).max(50) }), req.body);
    const accepted: string[] = [];
    const duplicates: string[] = [];
    const flagged: string[] = [];
    // A clientId repeated within one batch is processed once.
    const unique = [...new Map(sessions.map((s) => [s.clientId, s])).values()];
    const ordered = unique.sort((a, b) => a.startedAt.localeCompare(b.startedAt));
    const limit = ctx.now().getTime() + MAX_FUTURE_MS;
    if (sessions.some((s) => new Date(s.startedAt).getTime() > limit)) throw badRequest('started_at_in_future');
    const deviceIds = [...new Set(sessions.map((s) => s.deviceId).filter((d): d is string => !!d))];
    if (deviceIds.length) {
      const own = await ctx.db.selectFrom('devices').select('id').where('user_id', '=', req.userId).where('id', 'in', deviceIds).execute();
      if (own.length !== deviceIds.length) throw badRequest('unknown_device');
    }
    const levelIds = [...new Set(sessions.map((s) => s.levelId))];
    const known = await ctx.db.selectFrom('content_versions').select('level_id').distinct().where('level_id', 'in', levelIds).execute();
    if (known.length !== levelIds.length) throw badRequest('unknown_level');

    for (const s of ordered) {
      const implausible = isImplausible(s);
      const points = implausible ? 0 : effortPoints(s);
      const inserted = await ctx.db.transaction().execute(async (tx) => {
        const row = await tx
          .insertInto('sessions')
          .values({
            client_id: s.clientId,
            user_id: req.userId,
            device_id: s.deviceId ?? null,
            level_id: s.levelId,
            started_at: s.startedAt,
            duration_s: s.durationS,
            active_s: Math.min(s.activeS, s.durationS),
            score: s.score,
            difficulty: s.difficulty,
            low_impact: s.lowImpact,
            completed: s.completed,
            effort_rating: s.effortRating ?? null,
            effort_points: points,
            flagged: implausible,
          })
          .onConflict((oc) => oc.columns(['user_id', 'client_id']).doNothing())
          .returning('id')
          .executeTakeFirst();
        if (!row) return null;
        if (s.moves.length) {
          await tx
            .insertInto('session_moves')
            .values(
              s.moves.map((m) => ({
                session_id: row.id,
                move: m.move,
                attempts: m.attempts,
                recognised: m.recognised,
                false_triggers: m.falseTriggers,
                avg_latency_ms: m.avgLatencyMs ?? null,
              })),
            )
            .execute();
        }
        if (implausible) return row.id;

        const playedAt = new Date(s.startedAt);
        const prev = await tx.selectFrom('progress').selectAll().where('user_id', '=', req.userId).forUpdate().executeTakeFirst();
        const st = nextStreak(
          {
            streak: prev?.streak ?? 0,
            best: prev?.best_streak ?? 0,
            shields: prev?.shields ?? SHIELDS_PER_MONTH,
            shieldsMonth: prev?.shields_month ?? '',
            lastPlayedOn: prev?.last_played_on ?? null,
          },
          playedAt,
        );
        const xp = (prev?.xp ?? 0) + xpFor(s.score, s.completed, s.activeS);
        const worlds = prev?.worlds ?? [1];
        const values = {
          user_id: req.userId,
          xp,
          hero_level: heroLevel(xp),
          worlds: JSON.stringify(worlds),
          streak: st.streak,
          best_streak: st.best,
          shields: st.shields,
          shields_month: st.shieldsMonth,
          last_played_on: st.lastPlayedOn,
          sessions_count: (prev?.sessions_count ?? 0) + 1,
          active_s_total: (prev?.active_s_total ?? 0) + Math.min(s.activeS, s.durationS),
          updated_at: ctx.now(),
        };
        await tx
          .insertInto('progress')
          .values(values)
          .onConflict((oc) => oc.column('user_id').doUpdateSet(values))
          .execute();
        // Same transaction: crew points are never lost after the session commits.
        await recordCrewEffort({ ...ctx, db: tx }, req.userId, playedAt, points);
        return row.id;
      });

      if (!inserted) duplicates.push(s.clientId);
      else if (implausible) flagged.push(s.clientId);
      else accepted.push(s.clientId);
    }
    return { accepted, duplicates, flagged, progress: await getProgress(ctx, req.userId) };
  });

  app.get('/progress', { preHandler: auth }, async (req) => {
    const recent = await ctx.db
      .selectFrom('sessions')
      .select(['client_id', 'level_id', 'started_at', 'score', 'active_s', 'completed', 'difficulty'])
      .where('user_id', '=', req.userId)
      .orderBy('started_at', 'desc')
      .limit(20)
      .execute();
    const bests = await ctx.db
      .selectFrom('sessions')
      .select(['level_id', sql<number>`max(score)`.as('best')])
      .where('user_id', '=', req.userId)
      .where('flagged', '=', false)
      .groupBy('level_id')
      .execute();
    return {
      ...(await getProgress(ctx, req.userId)),
      personalBests: Object.fromEntries(bests.map((b) => [b.level_id, Number(b.best)])),
      recent: recent.map((r) => ({
        clientId: r.client_id,
        levelId: r.level_id,
        startedAt: r.started_at,
        score: r.score,
        activeS: r.active_s,
        completed: r.completed,
        difficulty: r.difficulty,
      })),
    };
  });

  /** Pain or discomfort report from the results screen; reviewed within a week. */
  app.post('/me/pain-reports', { preHandler: auth }, async (req, reply) => {
    const body = parse(
      z.object({
        sessionClientId: z.string().max(64).nullish(),
        area: z.enum(['knees', 'back', 'hips', 'shoulders', 'neck', 'ankles', 'other']),
        note: z.string().max(500).nullish(),
      }),
      req.body,
    );
    await ctx.db
      .insertInto('pain_reports')
      .values({ user_id: req.userId, session_client_id: body.sessionClientId ?? null, area: body.area, note: body.note ?? null })
      .execute();
    req.log.warn({ area: body.area }, 'pain report received — review within 7 days');
    return reply.code(201).send({ ok: true, advice: 'Stop if it hurts. If pain continues, please see a doctor.' });
  });
}
