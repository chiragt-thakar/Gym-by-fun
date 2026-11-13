import type { FastifyInstance, FastifyRequest } from 'fastify';

import type { AppContext } from '../../context.js';
import { requireUser } from '../../lib/auth.js';
import { tooMany } from '../../lib/errors.js';
import { allow } from '../../lib/rate-limit.js';
import { parse } from '../../lib/validate.js';
import { joinBody, sendBody } from './schema.js';
import {
  authorise,
  createSession,
  endSession,
  type Envelope,
  joinSession,
  markAbsent,
  markPresent,
  pairChannel,
  PairingHub,
  replay,
  send,
  status,
} from './service.js';

/** The device's session token. A header, never the URL (URLs get logged). */
function tokenOf(req: FastifyRequest): string | undefined {
  const h = req.headers['x-pair-token'];
  return typeof h === 'string' && h.length <= 128 ? h : undefined;
}

const HEARTBEAT_MS = 15_000;

/**
 * Multi-device pairing (`/v1/pair`).
 *
 * Transport: messages go up as small JSON batches (POST) and come down as
 * a Server-Sent Events stream. Both are plain HTTP, so they pass every
 * proxy the REST API already passes and need no new dependency. A device
 * that loses its connection reconnects with the last sequence number it saw
 * and receives what it missed (`Last-Event-ID`).
 */
export async function pairingRoutes(app: FastifyInstance, ctx: AppContext) {
  const auth = requireUser(ctx);
  const hub = new PairingHub(ctx.redis);
  app.addHook('onClose', async () => hub.close());

  /** The player's device opens a session and shows the code. */
  app.post('/pair/sessions', { preHandler: auth }, async (req, reply) => {
    if (!(await allow(ctx.redis, `pair:create:${req.userId}`, 20, 3600))) throw tooMany('pair_rate_limited');
    const s = await createSession(ctx, req.userId);
    return reply.code(201).send({ ...s, role: 'host' });
  });

  /** The second device joins with the code (no account needed). */
  app.post('/pair/join', async (req) => {
    // Codes are short: guessing must be slow.
    if (!(await allow(ctx.redis, `pair:join:${req.ip}`, 10, 600))) throw tooMany('pair_rate_limited');
    const body = parse(joinBody, req.body);
    const s = await joinSession(ctx, body.code);
    return { ...s, role: 'peer' };
  });

  app.get<{ Params: { id: string } }>('/pair/sessions/:id', async (req) => {
    const role = await authorise(ctx, req.params.id, tokenOf(req));
    return { role, ...(await status(ctx, req.params.id)) };
  });

  /**
   * Sends a batch of validated messages to the other device. Devices batch
   * (a few requests a second, up to 32 messages each), so this route has its
   * own per-device limit instead of the API-wide per-IP one.
   */
  app.post<{ Params: { id: string } }>('/pair/sessions/:id/messages', { config: { rateLimit: false } }, async (req) => {
    const role = await authorise(ctx, req.params.id, tokenOf(req));
    if (!(await allow(ctx.redis, `pair:send:${req.params.id}:${role}`, 1200, 60))) throw tooMany('pair_rate_limited');
    const body = parse(sendBody, req.body);
    const seq = await send(ctx, req.params.id, role, body.messages);
    return { seq };
  });

  /** Either device ends the session. */
  app.delete<{ Params: { id: string } }>('/pair/sessions/:id', async (req, reply) => {
    const role = await authorise(ctx, req.params.id, tokenOf(req));
    await endSession(ctx, req.params.id, role);
    return reply.code(204).send();
  });

  /** The stream of messages for this device (Server-Sent Events). */
  app.get<{ Params: { id: string }; Querystring: { after?: string } }>('/pair/sessions/:id/stream', async (req, reply) => {
    const id = req.params.id;
    const role = await authorise(ctx, id, tokenOf(req));
    const last = req.headers['last-event-id'];
    const afterRaw = typeof last === 'string' ? last : req.query.after;
    const after = afterRaw && /^\d{1,15}$/.test(afterRaw) ? Number(afterRaw) : 0;

    reply.hijack();
    const res = reply.raw;
    res.writeHead(200, {
      'content-type': 'text/event-stream; charset=utf-8',
      'cache-control': 'no-cache, no-transform',
      connection: 'keep-alive',
      'x-accel-buffering': 'no',
    });

    let closed = false;
    let delivered = after;
    const write = (e: Envelope) => {
      // seq 0 is the end-of-session notice; everything else is in order.
      if (closed || (e.seq !== 0 && e.seq <= delivered)) return;
      if (e.seq !== 0) delivered = e.seq;
      res.write(`id: ${e.seq}\ndata: ${JSON.stringify(e)}\n\n`);
      if (e.msg.t === 'end') finish();
    };

    // Subscribe first and hold live messages until the replay is written,
    // so nothing can fall between the two.
    const pending: Envelope[] = [];
    let live = false;
    const unsubscribe = await hub.listen(pairChannel(id, role), (json) => {
      const e = JSON.parse(json) as Envelope;
      if (live) write(e);
      else pending.push(e);
    });

    const heartbeat = setInterval(() => {
      if (closed) return;
      res.write(': keep-alive\n\n');
      markPresent(ctx.redis, id, role).catch(() => undefined);
    }, HEARTBEAT_MS);

    function finish() {
      if (closed) return;
      closed = true;
      clearInterval(heartbeat);
      unsubscribe().catch(() => undefined);
      markAbsent(ctx.redis, id, role).catch(() => undefined);
      res.end();
    }
    req.raw.on('close', finish);

    try {
      await markPresent(ctx.redis, id, role);
      for (const e of await replay(ctx, id, role, after)) write(e);
      live = true;
      for (const e of pending) write(e);
    } catch (err) {
      req.log.error({ err }, 'pairing stream failed');
      finish();
    }
  });
}
