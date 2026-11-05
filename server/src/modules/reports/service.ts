import { sql } from 'kysely';

import type { AppContext } from '../../context.js';
import { notFound } from '../../lib/errors.js';
import { addDays, isoWeek, weekStart } from '../../lib/time.js';
import { firstName } from '../gyms/service.js';

export interface WeeklyReport {
  gymId: string;
  gymName: string;
  week: string;
  members: number;
  activeMembers: number;
  sessions: number;
  activeMinutes: number;
  goingQuiet: string[];
  topPlayers: { name: string; effortPoints: number }[];
  quests: { title: string; completedBy: number }[];
}

/**
 * Report for the last full ISO week before `now`. Activity summaries only,
 * and only for members who agreed to share — never body measurements.
 */
export async function buildWeeklyReport(ctx: AppContext, gymId: string, now: Date): Promise<WeeklyReport> {
  const end = weekStart(now);
  const start = addDays(end, -7);
  const priorStart = addDays(start, -14);
  const week = isoWeek(start);
  const gym = await ctx.db.selectFrom('gyms').select(['name']).where('id', '=', gymId).executeTakeFirst();
  if (!gym) throw notFound('gym_not_found');

  const members = await ctx.db
    .selectFrom('memberships')
    .innerJoin('users', 'users.id', 'memberships.user_id')
    .select(['users.id', 'users.name'])
    .where('memberships.gym_id', '=', gymId)
    .where('memberships.left_at', 'is', null)
    .where('memberships.shares_activity', '=', true)
    .where('users.deleted_at', 'is', null)
    .execute();
  const ids = members.map((m) => m.id);
  const name = new Map(members.map((m) => [m.id, firstName(m.name ?? 'Player')]));

  const perUser = ids.length
    ? await ctx.db
        .selectFrom('sessions')
        .select([
          'user_id',
          sql<number>`count(*) filter (where started_at >= ${start} and started_at < ${end})`.as('this_week'),
          sql<number>`count(*) filter (where started_at >= ${priorStart} and started_at < ${start})`.as('before'),
          sql<number>`coalesce(sum(active_s) filter (where started_at >= ${start} and started_at < ${end}), 0)`.as('active_s'),
        ])
        .where('user_id', 'in', ids)
        .where('flagged', '=', false)
        .where('started_at', '>=', priorStart)
        .where('started_at', '<', end)
        .groupBy('user_id')
        .execute()
    : [];

  const active = perUser.filter((u) => Number(u.this_week) > 0);
  const quiet = perUser.filter((u) => Number(u.this_week) === 0 && Number(u.before) > 0);

  const top = await ctx.db
    .selectFrom('crew_scores')
    .select(['user_id', 'effort_points'])
    .where('gym_id', '=', gymId)
    .where('week', '=', week)
    .orderBy('effort_points', 'desc')
    .limit(10)
    .execute();

  const quests = await ctx.db
    .selectFrom('trainer_quests')
    .select(['id', 'title', 'level_id', 'created_at', 'due_at'])
    .where('gym_id', '=', gymId)
    .where('due_at', '>=', start)
    .where('created_at', '<', end)
    .execute();
  const questResults = [];
  for (const q of quests) {
    const done = ids.length
      ? await ctx.db
          .selectFrom('sessions')
          .select(sql<number>`count(distinct user_id)`.as('n'))
          .where('user_id', 'in', ids)
          .where('level_id', '=', q.level_id)
          .where('started_at', '>=', q.created_at)
          .where('started_at', '<=', q.due_at)
          .executeTakeFirstOrThrow()
      : { n: 0 };
    questResults.push({ title: q.title, completedBy: Number(done.n) });
  }

  return {
    gymId,
    gymName: gym.name,
    week,
    members: ids.length,
    activeMembers: active.length,
    sessions: active.reduce((a, u) => a + Number(u.this_week), 0),
    activeMinutes: Math.round(active.reduce((a, u) => a + Number(u.active_s), 0) / 60),
    goingQuiet: quiet.map((u) => name.get(u.user_id)!).filter(Boolean).slice(0, 10),
    topPlayers: top
      .filter((t) => name.has(t.user_id))
      .slice(0, 3)
      .map((t) => ({ name: name.get(t.user_id)!, effortPoints: t.effort_points })),
    quests: questResults,
  };
}

export function formatReport(r: WeeklyReport): string {
  const lines = [
    `*${r.gymName} — MotionQuest weekly report (${r.week})*`,
    '',
    `Active members: ${r.activeMembers} of ${r.members} sharing`,
    `Home sessions: ${r.sessions} · ${r.activeMinutes} active minutes`,
  ];
  if (r.topPlayers.length) {
    lines.push('', '🏆 Top crew this week:');
    r.topPlayers.forEach((p, i) => lines.push(`${i + 1}. ${p.name} — ${p.effortPoints} effort points`));
  }
  if (r.goingQuiet.length) {
    lines.push('', `👋 Going quiet (played before, not this week): ${r.goingQuiet.join(', ')}`);
    lines.push('A friendly message from a trainer goes a long way.');
  }
  for (const q of r.quests) lines.push('', `📋 Quest "${q.title}": completed by ${q.completedBy}`);
  return lines.join('\n');
}

/** Sends every active gym its report once per week. Safe to re-run. */
export async function sendWeeklyReports(ctx: AppContext): Promise<{ sent: number; skipped: number }> {
  const gyms = await ctx.db
    .selectFrom('gyms')
    .select(['id', 'owner_phone_enc'])
    .where('status', 'in', ['pilot', 'active'])
    .where('licence_until', '>', ctx.now())
    .execute();
  let sent = 0;
  let skipped = 0;
  for (const g of gyms) {
    if (!g.owner_phone_enc) {
      skipped++;
      continue;
    }
    const report = await buildWeeklyReport(ctx, g.id, ctx.now());
    const body = formatReport(report);
    const claimed = await ctx.db
      .insertInto('report_runs')
      .values({ gym_id: g.id, week: report.week, sent_at: ctx.now(), body })
      .onConflict((oc) => oc.columns(['gym_id', 'week']).doNothing())
      .returning('gym_id')
      .executeTakeFirst();
    if (!claimed) {
      skipped++;
      continue;
    }
    try {
      await ctx.providers.whatsapp.sendText(ctx.pii.decrypt(g.owner_phone_enc), body);
      sent++;
    } catch (err) {
      // Release the claim so the retry can send it.
      await ctx.db.deleteFrom('report_runs').where('gym_id', '=', g.id).where('week', '=', report.week).execute();
      throw err;
    }
  }
  return { sent, skipped };
}
