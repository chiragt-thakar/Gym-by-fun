import { z } from 'zod';

/**
 * Messages two paired devices may exchange (e.g. the phone that tracks the
 * player and a bigger screen that shows the game).
 *
 * Only game input and game control cross the server: discrete motion
 * events, the continuous body-relative signals, the tracking state. There
 * is deliberately no message that could carry landmarks, images or video,
 * and every object is strict: unknown fields are rejected, not relayed.
 */

const ts = z.number().int().min(0).max(Number.MAX_SAFE_INTEGER);
const name = z.string().regex(/^[A-Za-z][A-Za-z0-9_-]{0,31}$/);
const side = z.enum(['left', 'right']);
const unit = z.number().finite().min(-10).max(10);

/** A discrete motion event (a move started, a gesture fired …). */
const motionEvent = z
  .object({
    t: z.literal('event'),
    kind: z.enum(['move', 'gesture']),
    name,
    phase: z.enum(['started', 'held', 'ended', 'fired', 'rejected']),
    side: side.optional(),
    strength: z.number().finite().min(0).max(10).optional(),
    heldMs: z.number().int().min(0).max(600_000).optional(),
    ts,
  })
  .strict();

/** The continuous signals, as fractions of the player's own range. */
const signals = z
  .object({
    t: z.literal('signal'),
    ts,
    squat: unit,
    lean: unit,
    sideStep: unit,
    armLeft: unit,
    armRight: unit,
    hipX: unit,
    hipRise: unit,
  })
  .strict();

/** The tracking state, so the display can explain a pause. */
const tracking = z
  .object({
    t: z.literal('tracking'),
    state: z.enum(['tracking', 'degraded', 'lost', 'recovering']),
    issue: z.enum(['noPerson', 'outOfFrame', 'lowVisibility', 'tooFar', 'tooClose']).optional(),
    ts,
  })
  .strict();

/** Game control, from either device. */
const game = z
  .object({
    t: z.literal('game'),
    action: z.enum(['select', 'start', 'pause', 'resume', 'end']),
    gameId: name.optional(),
    stageId: z.string().regex(/^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$/).optional(),
    score: z.number().int().min(0).max(100_000_000).optional(),
  })
  .strict();

export const pairMessage = z.discriminatedUnion('t', [motionEvent, signals, tracking, game]);
export type PairMessage = z.infer<typeof pairMessage>;

/** Signals are a latest-value stream: never replayed after a reconnect. */
export function isReplayable(m: PairMessage): boolean {
  return m.t !== 'signal';
}

export const sendBody = z.object({ messages: z.array(pairMessage).min(1).max(32) }).strict();
export const joinBody = z.object({ code: z.string().min(4).max(12) }).strict();

export type PairRole = 'host' | 'peer';
export const otherRole = (r: PairRole): PairRole => (r === 'host' ? 'peer' : 'host');
