import type { AppContext } from '../../context.js';
import { daysBetween, istDate, istMonth } from '../../lib/time.js';

export const SHIELDS_PER_MONTH = 2;

/** Fastest believable pace for any World 1 move, in seconds per rep. */
const MIN_SECONDS_PER_REP = 0.6;

export interface SessionMoveInput {
  move: 'squat' | 'leanLeft' | 'leanRight' | 'raiseArms';
  attempts: number;
  recognised: number;
  falseTriggers: number;
  avgLatencyMs?: number | null;
}

export interface SessionInput {
  durationS: number;
  activeS: number;
  completed: boolean;
  moves: SessionMoveInput[];
}

/**
 * Effort points for the crew board: active minutes plus a completion bonus,
 * capped per session, so beginners can compete with regulars. Never raw reps.
 */
export function effortPoints(s: SessionInput): number {
  const active = Math.min(s.activeS, s.durationS);
  const base = Math.round(active / 6); // 10 points per active minute
  return Math.min(100, base + (s.completed ? 20 : 0));
}

/** Light anti-cheat: impossible rep rates are flagged and kept off boards. */
export function isImplausible(s: SessionInput): boolean {
  const reps = s.moves.reduce((a, m) => a + m.recognised, 0);
  if (s.activeS > s.durationS + 5) return true;
  if (s.activeS <= 0) return reps > 0;
  return reps / s.activeS > 1 / MIN_SECONDS_PER_REP;
}

export function heroLevel(xp: number): number {
  return Math.floor(Math.sqrt(xp / 100)) + 1;
}

export function xpFor(score: number, completed: boolean, activeS: number): number {
  return Math.round(score / 20) + Math.round(activeS / 10) + (completed ? 50 : 0);
}

export interface StreakState {
  streak: number;
  best: number;
  shields: number;
  shieldsMonth: string;
  lastPlayedOn: string | null;
}

/**
 * Streaks with two free shields a month. A missed day never removes other
 * progress, and a broken streak simply starts again at 1 — no shaming.
 */
export function nextStreak(s: StreakState, playedAt: Date): StreakState {
  const today = istDate(playedAt);
  const month = istMonth(playedAt);
  let shields = s.shieldsMonth === month ? s.shields : SHIELDS_PER_MONTH;
  let streak = s.streak;
  if (s.lastPlayedOn === null) streak = 1;
  else {
    const gap = daysBetween(s.lastPlayedOn, today);
    if (gap <= 0) return { ...s, shields, shieldsMonth: month, lastPlayedOn: gap < 0 ? s.lastPlayedOn : today };
    if (gap === 1) streak += 1;
    else if (gap - 1 <= shields) {
      shields -= gap - 1;
      streak += 1;
    } else streak = 1;
  }
  return { streak, best: Math.max(s.best, streak), shields, shieldsMonth: month, lastPlayedOn: today };
}

export async function getProgress(ctx: AppContext, userId: string) {
  const p = await ctx.db.selectFrom('progress').selectAll().where('user_id', '=', userId).executeTakeFirst();
  if (!p) {
    return {
      xp: 0,
      heroLevel: 1,
      worlds: [1],
      streak: 0,
      bestStreak: 0,
      shields: SHIELDS_PER_MONTH,
      lastPlayedOn: null,
      sessions: 0,
      activeMinutes: 0,
    };
  }
  const month = istMonth(ctx.now());
  return {
    xp: p.xp,
    heroLevel: p.hero_level,
    worlds: p.worlds,
    streak: p.streak,
    bestStreak: p.best_streak,
    shields: p.shields_month === month ? p.shields : SHIELDS_PER_MONTH,
    lastPlayedOn: p.last_played_on,
    sessions: p.sessions_count,
    activeMinutes: Math.round(p.active_s_total / 60),
  };
}
