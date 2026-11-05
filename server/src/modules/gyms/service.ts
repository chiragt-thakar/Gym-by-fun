import { sql } from 'kysely';

import type { AppContext } from '../../context.js';
import { conflict, notFound } from '../../lib/errors.js';
import { isoWeek } from '../../lib/time.js';
import { grantGymEntitlement, revokeGymEntitlement } from '../billing/service.js';
import { grantConsent } from '../identity/routes.js';

const boardKey = (gymId: string, week: string) => `crew:${gymId}:${week}`;

export async function activeMembership(ctx: AppContext, userId: string) {
  return ctx.db
    .selectFrom('memberships')
    .innerJoin('gyms', 'gyms.id', 'memberships.gym_id')
    .select(['gyms.id', 'gyms.name', 'gyms.logo_url', 'gyms.colours', 'gyms.status', 'gyms.licence_until', 'memberships.shares_activity', 'memberships.joined_at'])
    .where('memberships.user_id', '=', userId)
    .where('memberships.left_at', 'is', null)
    .executeTakeFirst();
}

export async function joinGym(ctx: AppContext, userId: string, rawCode: string, shareActivity: boolean) {
  const code = rawCode.trim().toUpperCase();
  const row = await ctx.db
    .selectFrom('gym_codes')
    .innerJoin('gyms', 'gyms.id', 'gym_codes.gym_id')
    .select(['gym_codes.code', 'gym_codes.max_members', 'gym_codes.expires_at', 'gyms.id as gym_id', 'gyms.status', 'gyms.licence_until'])
    .where('gym_codes.code', '=', code)
    .executeTakeFirst();
  if (!row) throw notFound('gym_code_unknown');
  const now = ctx.now();
  if (new Date(row.expires_at) <= now) throw conflict('gym_code_expired');
  if (row.status === 'cancelled' || row.status === 'lapsed' || new Date(row.licence_until) <= now) throw conflict('gym_inactive');

  const current = await activeMembership(ctx, userId);
  if (current && current.id !== row.gym_id) throw conflict('already_in_a_gym');

  if (!current) {
    // Member limits stop a code being shared around the city.
    const used = await ctx.db
      .selectFrom('memberships')
      .select(sql<number>`count(*)`.as('n'))
      .where('code', '=', code)
      .where('left_at', 'is', null)
      .executeTakeFirstOrThrow();
    if (Number(used.n) >= row.max_members) throw conflict('gym_code_full');
  }

  await ctx.db
    .insertInto('memberships')
    .values({ user_id: userId, gym_id: row.gym_id, joined_at: now, left_at: null, shares_activity: shareActivity, code })
    .onConflict((oc) => oc.columns(['user_id', 'gym_id']).doUpdateSet({ left_at: null, shares_activity: shareActivity, joined_at: now, code }))
    .execute();
  if (shareActivity) await grantConsent(ctx, userId, 'gym_sharing');
  await grantGymEntitlement(ctx, userId, row.gym_id, new Date(row.licence_until));
  return activeMembership(ctx, userId);
}

export async function leaveGym(ctx: AppContext, userId: string) {
  const m = await activeMembership(ctx, userId);
  if (!m) return false;
  await ctx.db
    .updateTable('memberships')
    .set({ left_at: ctx.now(), shares_activity: false })
    .where('user_id', '=', userId)
    .where('gym_id', '=', m.id)
    .execute();
  await revokeGymEntitlement(ctx, userId, m.id);
  await ctx.redis.zrem(boardKey(m.id, isoWeek(ctx.now())), userId);
  return true;
}

/** Called in-process by the progress module after each accepted session. */
export async function recordCrewEffort(ctx: AppContext, userId: string, playedAt: Date, points: number) {
  const m = await activeMembership(ctx, userId);
  if (!m || !m.shares_activity || points <= 0) return;
  const week = isoWeek(playedAt);
  await ctx.db
    .insertInto('crew_scores')
    .values({ gym_id: m.id, week, user_id: userId, effort_points: points, sessions: 1 })
    .onConflict((oc) =>
      oc.columns(['gym_id', 'week', 'user_id']).doUpdateSet({
        effort_points: sql`crew_scores.effort_points + ${points}`,
        sessions: sql`crew_scores.sessions + 1`,
      }),
    )
    .execute();
  const key = boardKey(m.id, week);
  await ctx.redis.zincrby(key, points, userId);
  await ctx.redis.expire(key, 60 * 60 * 24 * 21);
}

export interface BoardEntry {
  rank: number;
  name: string;
  effortPoints: number;
  isMe: boolean;
}

/** Weekly crew board by effort points. Only members who agreed to share appear. */
export async function crewBoard(ctx: AppContext, gymId: string, week: string, meId?: string): Promise<BoardEntry[]> {
  const key = boardKey(gymId, week);
  let pairs: [string, number][] = [];
  const raw = await ctx.redis.zrevrange(key, 0, 49, 'WITHSCORES');
  if (raw.length) {
    for (let i = 0; i < raw.length; i += 2) pairs.push([raw[i]!, Number(raw[i + 1])]);
  } else {
    // Redis cold (restart, old week): rebuild from the weekly snapshot.
    const rows = await ctx.db
      .selectFrom('crew_scores')
      .select(['user_id', 'effort_points'])
      .where('gym_id', '=', gymId)
      .where('week', '=', week)
      .orderBy('effort_points', 'desc')
      .limit(50)
      .execute();
    pairs = rows.map((r) => [r.user_id, r.effort_points]);
    if (pairs.length) {
      await ctx.redis.zadd(key, ...pairs.flatMap(([u, p]) => [p, u]));
      await ctx.redis.expire(key, 60 * 60 * 24 * 21);
    }
  }
  if (!pairs.length) return [];
  const members = await ctx.db
    .selectFrom('memberships')
    .innerJoin('users', 'users.id', 'memberships.user_id')
    .select(['users.id', 'users.name'])
    .where('memberships.gym_id', '=', gymId)
    .where('memberships.left_at', 'is', null)
    .where('memberships.shares_activity', '=', true)
    .where('users.deleted_at', 'is', null)
    .where(
      'users.id',
      'in',
      pairs.map(([u]) => u),
    )
    .execute();
  const names = new Map(members.map((m) => [m.id, m.name ?? 'Player']));
  return pairs
    .filter(([u]) => names.has(u))
    .map(([u, p], i) => ({ rank: i + 1, name: firstName(names.get(u)!), effortPoints: p, isMe: u === meId }));
}

export const firstName = (n: string) => n.trim().split(/\s+/)[0] ?? n;
