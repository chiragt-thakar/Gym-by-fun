import { randomInt, randomUUID } from 'node:crypto';

import type { Redis } from 'ioredis';

import type { AppContext } from '../../context.js';
import { randomToken, safeEqual, sha256 } from '../../lib/crypto.js';
import { forbidden, notFound } from '../../lib/errors.js';
import { isReplayable, otherRole, type PairMessage, type PairRole } from './schema.js';

/**
 * Device pairing: one player's phone (host) and one other screen (peer).
 *
 * Everything lives in Redis with a TTL, so a session ends by itself and
 * any instance of the service can serve either device:
 *
 *   pair:code:<CODE>      → session id       (5 min, single use)
 *   pair:s:<id>           → hash: userId, hostHash, peerHash, createdAt
 *   pair:seq:<id>:<role>  → last sequence number delivered to <role>
 *   pair:log:<id>:<role>  → the last LOG_SIZE replayable envelopes for <role>
 *   pair:on:<id>:<role>   → presence (refreshed while <role> is connected)
 *   pair:ch:<id>:<role>   → pub/sub channel for live delivery to <role>
 *
 * Tokens are random, shown to a device once and stored only as SHA-256.
 */

export const CODE_TTL_S = 5 * 60;
export const SESSION_TTL_S = 2 * 60 * 60;
export const PRESENCE_TTL_S = 40;
export const LOG_SIZE = 64;

const CODE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I
const CODE_LENGTH = 6;

/** What is delivered to a device: the message plus its place in the stream. */
export interface Envelope {
  seq: number;
  from: PairRole;
  at: number;
  msg: PairMessage | { t: 'end' } | { t: 'joined' };
}

const k = {
  code: (code: string) => `pair:code:${code}`,
  session: (id: string) => `pair:s:${id}`,
  seq: (id: string, to: PairRole) => `pair:seq:${id}:${to}`,
  log: (id: string, to: PairRole) => `pair:log:${id}:${to}`,
  presence: (id: string, role: PairRole) => `pair:on:${id}:${role}`,
  channel: (id: string, to: PairRole) => `pair:ch:${id}:${to}`,
};

export const pairChannel = k.channel;

function newCode(): string {
  let s = '';
  for (let i = 0; i < CODE_LENGTH; i++) s += CODE_ALPHABET[randomInt(0, CODE_ALPHABET.length)];
  return s;
}

/** Upper-cases and strips separators, so "abc-def" and "ABCDEF" match. */
export function normaliseCode(raw: string): string {
  return raw.toUpperCase().replace(/[^A-Z0-9]/g, '');
}

export interface CreatedSession {
  sessionId: string;
  code: string;
  token: string;
  expiresInS: number;
}

/** The signed-in player's device opens a session and gets a code to show. */
export async function createSession(ctx: AppContext, userId: string): Promise<CreatedSession> {
  const sessionId = randomUUID();
  const token = randomToken();
  // A code collision is unlikely (32^6); retry rather than overwrite.
  let code = '';
  for (let attempt = 0; attempt < 5; attempt++) {
    const candidate = newCode();
    const set = await ctx.redis.set(k.code(candidate), sessionId, 'EX', CODE_TTL_S, 'NX');
    if (set === 'OK') {
      code = candidate;
      break;
    }
  }
  if (!code) throw new Error('could not allocate a pairing code');
  await ctx.redis
    .multi()
    .hset(k.session(sessionId), { userId, hostHash: sha256(token), peerHash: '', createdAt: String(ctx.now().getTime()) })
    .expire(k.session(sessionId), SESSION_TTL_S)
    .exec();
  return { sessionId, code, token, expiresInS: CODE_TTL_S };
}

export interface JoinedSession {
  sessionId: string;
  token: string;
}

/**
 * The second device joins with the code. The code is consumed atomically:
 * it works exactly once, so a code read over someone's shoulder is useless
 * after the real join.
 */
export async function joinSession(ctx: AppContext, rawCode: string): Promise<JoinedSession> {
  const code = normaliseCode(rawCode);
  if (code.length !== CODE_LENGTH) throw notFound('pair_code_invalid');
  const sessionId = await ctx.redis.getdel(k.code(code));
  if (!sessionId) throw notFound('pair_code_invalid');
  if (!(await ctx.redis.exists(k.session(sessionId)))) throw notFound('pair_code_invalid');
  const token = randomToken();
  await ctx.redis.hset(k.session(sessionId), { peerHash: sha256(token) });
  await deliver(ctx, sessionId, 'peer', { t: 'joined' });
  return { sessionId, token };
}

/** Which device a token belongs to. Throws 404 / 403; never says which. */
export async function authorise(ctx: AppContext, sessionId: string, token: string | undefined): Promise<PairRole> {
  if (!/^[0-9a-f-]{36}$/.test(sessionId)) throw notFound('pair_session_not_found');
  const s = await ctx.redis.hgetall(k.session(sessionId));
  const hostHash = s.hostHash;
  const peerHash = s.peerHash;
  if (!hostHash) throw notFound('pair_session_not_found');
  if (!token) throw forbidden('pair_token_invalid');
  const hash = sha256(token);
  if (safeEqual(hash, hostHash)) return 'host';
  if (peerHash && safeEqual(hash, peerHash)) return 'peer';
  throw forbidden('pair_token_invalid');
}

/**
 * Sends one message from [from] to the other device: numbers it, keeps it
 * for replay (unless it is a latest-value signal) and publishes it.
 */
async function deliver(ctx: AppContext, sessionId: string, from: PairRole, msg: Envelope['msg']): Promise<number> {
  const to = otherRole(from);
  const seq = await ctx.redis.incr(k.seq(sessionId, to));
  const envelope: Envelope = { seq, from, at: ctx.now().getTime(), msg };
  const json = JSON.stringify(envelope);
  const replay = msg.t === 'end' || msg.t === 'joined' || isReplayable(msg);
  const tx = ctx.redis.multi();
  if (replay) {
    tx.rpush(k.log(sessionId, to), json).ltrim(k.log(sessionId, to), -LOG_SIZE, -1).expire(k.log(sessionId, to), SESSION_TTL_S);
  }
  tx.expire(k.seq(sessionId, to), SESSION_TTL_S).expire(k.session(sessionId), SESSION_TTL_S).publish(k.channel(sessionId, to), json);
  await tx.exec();
  return seq;
}

/** Relays a validated batch. Returns the last sequence number assigned. */
export async function send(ctx: AppContext, sessionId: string, from: PairRole, messages: PairMessage[]): Promise<number> {
  let seq = 0;
  for (const m of messages) seq = await deliver(ctx, sessionId, from, m);
  return seq;
}

/**
 * What [role] missed: every kept envelope with a sequence number above
 * [afterSeq], in order. Used when a device reconnects.
 */
export async function replay(ctx: AppContext, sessionId: string, role: PairRole, afterSeq: number): Promise<Envelope[]> {
  const raw = await ctx.redis.lrange(k.log(sessionId, role), 0, -1);
  const out: Envelope[] = [];
  for (const r of raw) {
    const e = JSON.parse(r) as Envelope;
    if (e.seq > afterSeq) out.push(e);
  }
  return out;
}

export async function markPresent(redis: Redis, sessionId: string, role: PairRole): Promise<void> {
  await redis.set(k.presence(sessionId, role), '1', 'EX', PRESENCE_TTL_S);
}

export async function markAbsent(redis: Redis, sessionId: string, role: PairRole): Promise<void> {
  await redis.del(k.presence(sessionId, role));
}

export async function status(ctx: AppContext, sessionId: string): Promise<{ paired: boolean; hostOnline: boolean; peerOnline: boolean }> {
  const [peerHash, host, peer] = await Promise.all([
    ctx.redis.hget(k.session(sessionId), 'peerHash'),
    ctx.redis.exists(k.presence(sessionId, 'host')),
    ctx.redis.exists(k.presence(sessionId, 'peer')),
  ]);
  return { paired: Boolean(peerHash), hostOnline: host === 1, peerOnline: peer === 1 };
}

/** Ends the session for both devices and removes every trace of it. */
export async function endSession(ctx: AppContext, sessionId: string, by: PairRole): Promise<void> {
  const end = JSON.stringify({ seq: 0, from: by, at: ctx.now().getTime(), msg: { t: 'end' } } satisfies Envelope);
  await ctx.redis
    .multi()
    .publish(k.channel(sessionId, 'host'), end)
    .publish(k.channel(sessionId, 'peer'), end)
    .del(
      k.session(sessionId),
      k.seq(sessionId, 'host'),
      k.seq(sessionId, 'peer'),
      k.log(sessionId, 'host'),
      k.log(sessionId, 'peer'),
      k.presence(sessionId, 'host'),
      k.presence(sessionId, 'peer'),
    )
    .exec();
}

/**
 * Live delivery inside one process: a single Redis subscriber connection
 * fans messages out to the streams open on this instance, however many
 * sessions there are.
 */
export class PairingHub {
  private sub: Redis | null = null;
  private readonly listeners = new Map<string, Set<(json: string) => void>>();

  constructor(private readonly redis: Redis) {}

  private connection(): Redis {
    if (!this.sub) {
      const sub = this.redis.duplicate();
      sub.on('message', (channel: string, json: string) => {
        const set = this.listeners.get(channel);
        if (set) for (const fn of set) fn(json);
      });
      this.sub = sub;
    }
    return this.sub;
  }

  /** Starts listening; resolves once subscribed. Returns the unsubscribe. */
  async listen(channel: string, fn: (json: string) => void): Promise<() => Promise<void>> {
    let set = this.listeners.get(channel);
    if (!set) {
      set = new Set();
      this.listeners.set(channel, set);
      await this.connection().subscribe(channel);
    }
    set.add(fn);
    return async () => {
      const current = this.listeners.get(channel);
      if (!current) return;
      current.delete(fn);
      if (current.size === 0) {
        this.listeners.delete(channel);
        await this.sub?.unsubscribe(channel).catch(() => undefined);
      }
    };
  }

  close(): void {
    this.listeners.clear();
    this.sub?.disconnect();
    this.sub = null;
  }
}
