import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { pairMessage } from '../src/modules/pairing/schema.js';
import { type Envelope, pairChannel, PairingHub, replay, SESSION_TTL_S } from '../src/modules/pairing/service.js';
import { setup, signUp, type TestApp } from './helpers.js';

let t: TestApp;
beforeAll(async () => {
  t = await setup();
});
afterAll(async () => t.close());

const event = { t: 'event', kind: 'move', name: 'squat', phase: 'started', ts: 1000 };
const signal = { t: 'signal', ts: 1001, squat: 0.4, lean: -0.1, sideStep: 0, armLeft: 0, armRight: 1, hipX: 0, hipRise: 0 };

async function pair() {
  const u = await signUp(t);
  const created = await t.app.inject({ method: 'POST', url: '/v1/pair/sessions', headers: u.auth });
  expect(created.statusCode).toBe(201);
  const host = created.json() as { sessionId: string; code: string; token: string; role: string };
  await t.ctx.redis.del('rl:pair:join:127.0.0.1');
  const joined = await t.app.inject({ method: 'POST', url: '/v1/pair/join', payload: { code: host.code } });
  expect(joined.statusCode).toBe(200);
  const peer = joined.json() as { sessionId: string; token: string; role: string };
  return { u, host, peer, id: host.sessionId };
}

const post = (id: string, token: string, messages: unknown[]) =>
  t.app.inject({ method: 'POST', url: `/v1/pair/sessions/${id}/messages`, headers: { 'x-pair-token': token }, payload: { messages } });

describe('pairing', () => {
  it('needs an account to open a session', async () => {
    const r = await t.app.inject({ method: 'POST', url: '/v1/pair/sessions' });
    expect(r.statusCode).toBe(401);
  });

  it('pairs two devices with a single-use code', async () => {
    const { host, peer, id } = await pair();
    expect(host.role).toBe('host');
    expect(peer.role).toBe('peer');
    expect(peer.sessionId).toBe(id);
    expect(host.code).toMatch(/^[A-HJ-NP-Z2-9]{6}$/);
    expect(peer.token).not.toBe(host.token);
    // The code is spent.
    await t.ctx.redis.del('rl:pair:join:127.0.0.1');
    const again = await t.app.inject({ method: 'POST', url: '/v1/pair/join', payload: { code: host.code } });
    expect(again.statusCode).toBe(404);
    const s = await t.app.inject({ method: 'GET', url: `/v1/pair/sessions/${id}`, headers: { 'x-pair-token': host.token } });
    expect(s.json()).toMatchObject({ role: 'host', paired: true });
  });

  it('accepts a code typed in lower case with a separator', async () => {
    const u = await signUp(t);
    const host = (await t.app.inject({ method: 'POST', url: '/v1/pair/sessions', headers: u.auth })).json();
    await t.ctx.redis.del('rl:pair:join:127.0.0.1');
    const typed = `${host.code.slice(0, 3)}-${host.code.slice(3)}`.toLowerCase();
    const r = await t.app.inject({ method: 'POST', url: '/v1/pair/join', payload: { code: typed } });
    expect(r.statusCode).toBe(200);
  });

  it('limits code guessing per address', async () => {
    await t.ctx.redis.del('rl:pair:join:127.0.0.1');
    let last = 0;
    for (let i = 0; i < 11; i++) {
      last = (await t.app.inject({ method: 'POST', url: '/v1/pair/join', payload: { code: 'ZZZZZZ' } })).statusCode;
    }
    expect(last).toBe(429);
    await t.ctx.redis.del('rl:pair:join:127.0.0.1');
  });

  it('rejects a missing, wrong or foreign token without saying which', async () => {
    const a = await pair();
    const b = await pair();
    expect((await post(a.id, '', [event])).statusCode).toBe(403);
    expect((await post(a.id, 'not-a-token', [event])).statusCode).toBe(403);
    expect((await post(a.id, b.host.token, [event])).statusCode).toBe(403);
    expect((await post('00000000-0000-0000-0000-000000000000', a.host.token, [event])).statusCode).toBe(404);
    expect((await post('not-a-session', a.host.token, [event])).statusCode).toBe(404);
  });

  it('relays in order and numbers each direction separately', async () => {
    const { host, peer, id } = await pair();
    const r1 = await post(id, host.token, [event, { ...event, phase: 'ended', ts: 1500 }]);
    expect(r1.statusCode).toBe(200);
    // These are messages 1 and 2 for the peer ("joined" went to the host).
    expect(r1.json().seq).toBe(2);
    const r2 = await post(id, peer.token, [{ t: 'game', action: 'start', gameId: 'lumen' }]);
    expect(r2.json().seq).toBe(2);
    const forPeer = await replay(t.ctx, id, 'peer', 0);
    expect(forPeer.map((e) => e.seq)).toEqual([1, 2]);
    expect(forPeer.every((e) => e.from === 'host')).toBe(true);
    expect(forPeer[1]!.msg).toMatchObject({ t: 'event', phase: 'ended' });
    const forHost = await replay(t.ctx, id, 'host', 0);
    expect(forHost.map((e) => e.msg.t)).toEqual(['joined', 'game']);
  });

  it('a reconnecting device gets only what it missed; signals are never replayed', async () => {
    const { host, id } = await pair();
    await post(id, host.token, [event, signal, { t: 'tracking', state: 'lost', issue: 'noPerson', ts: 2000 }]);
    const all = await replay(t.ctx, id, 'peer', 0);
    expect(all.map((e) => e.msg.t)).toEqual(['event', 'tracking']);
    expect(all.map((e) => e.seq)).toEqual([1, 3]);
    expect((await replay(t.ctx, id, 'peer', 1)).map((e) => e.seq)).toEqual([3]);
    expect(await replay(t.ctx, id, 'peer', 3)).toEqual([]);
  });

  it('keeps a bounded replay log', async () => {
    const { host, id } = await pair();
    for (let i = 0; i < 5; i++) {
      await post(id, host.token, Array.from({ length: 32 }, (_, n) => ({ ...event, ts: i * 100 + n })));
    }
    const kept = await replay(t.ctx, id, 'peer', 0);
    expect(kept).toHaveLength(64);
    expect(kept.at(-1)!.seq).toBe(160);
  });

  it('delivers live through the hub', async () => {
    const { host, id } = await pair();
    const hub = new PairingHub(t.ctx.redis);
    const got: Envelope[] = [];
    const stop = await hub.listen(pairChannel(id, 'peer'), (json) => got.push(JSON.parse(json) as Envelope));
    await post(id, host.token, [event, signal]);
    for (let i = 0; i < 50 && got.length < 2; i++) await new Promise((r) => setTimeout(r, 10));
    expect(got.map((e) => e.msg.t)).toEqual(['event', 'signal']);
    await stop();
    hub.close();
  });

  it('ending a session removes it for both devices', async () => {
    const { host, peer, id } = await pair();
    const r = await t.app.inject({ method: 'DELETE', url: `/v1/pair/sessions/${id}`, headers: { 'x-pair-token': peer.token } });
    expect(r.statusCode).toBe(204);
    expect((await post(id, host.token, [event])).statusCode).toBe(404);
    expect(await t.ctx.redis.keys(`pair:*${id}*`)).toEqual([]);
  });

  it('sessions expire by themselves', async () => {
    const { id } = await pair();
    const ttl = await t.ctx.redis.ttl(`pair:s:${id}`);
    expect(ttl).toBeGreaterThan(0);
    expect(ttl).toBeLessThanOrEqual(SESSION_TTL_S);
  });
});

describe('pairing message schema', () => {
  const ok = (m: unknown) => pairMessage.safeParse(m).success;

  it('accepts every documented message', () => {
    expect(ok(event)).toBe(true);
    expect(ok({ t: 'event', kind: 'gesture', name: 'punch', phase: 'fired', side: 'left', strength: 1.4, ts: 5 })).toBe(true);
    expect(ok(signal)).toBe(true);
    expect(ok({ t: 'tracking', state: 'degraded', ts: 9 })).toBe(true);
    expect(ok({ t: 'game', action: 'end', score: 4200 })).toBe(true);
  });

  it('refuses unknown types, unknown fields and anything landmark-shaped', () => {
    expect(ok({ t: 'frame', landmarks: [[0.5, 0.5, 0, 1]] })).toBe(false);
    expect(ok({ ...event, landmarks: [0.5, 0.5] })).toBe(false);
    expect(ok({ ...signal, image: 'data:image/png;base64,AAAA' })).toBe(false);
    expect(ok({ ...event, name: '<script>' })).toBe(false);
    expect(ok({ ...event, phase: 'exploded' })).toBe(false);
    expect(ok({ ...signal, squat: Number.POSITIVE_INFINITY })).toBe(false);
    expect(ok({ ...signal, squat: 1e9 })).toBe(false);
    expect(ok({ ...event, ts: -1 })).toBe(false);
    expect(ok('event')).toBe(false);
  });

  it('the route refuses a bad batch as a whole', async () => {
    const { host, id } = await pair();
    expect((await post(id, host.token, [event, { t: 'frame' }])).statusCode).toBe(400);
    expect((await post(id, host.token, [])).statusCode).toBe(400);
    expect((await post(id, host.token, Array.from({ length: 33 }, () => event))).statusCode).toBe(400);
    expect(await replay(t.ctx, id, 'peer', 0)).toEqual([]);
  });
});
