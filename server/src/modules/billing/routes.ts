import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { AppContext } from '../../context.js';
import { requireUser } from '../../lib/auth.js';
import { hmacSha256Hex, safeEqual, sha256 } from '../../lib/crypto.js';
import { badRequest, unauthorized } from '../../lib/errors.js';
import { applyGymPayment, applyRevenueCat, getEntitlement, processWebhookOnce, type GymPaymentNotes } from './service.js';

declare module 'fastify' {
  interface FastifyRequest {
    rawBody?: string;
  }
}

const razorpayEntity = z
  .object({ entity: z.object({ id: z.string().optional(), notes: z.record(z.string(), z.unknown()).optional() }).passthrough().optional() })
  .passthrough();
const razorpaySchema = z.object({ event: z.string().min(1), payload: z.record(z.string(), razorpayEntity).default({}) }).passthrough();

const RAZORPAY_EVENTS = new Set(['payment_link.paid', 'invoice.paid', 'subscription.charged']);

export async function billingRoutes(app: FastifyInstance, ctx: AppContext) {
  app.get('/entitlements', { preHandler: requireUser(ctx) }, async (req) => getEntitlement(ctx, req.userId));

  /** RevenueCat webhook: shared Authorization header configured in RevenueCat. */
  app.post('/webhooks/revenuecat', async (req, reply) => {
    const authz = req.headers.authorization ?? '';
    const expected = `Bearer ${ctx.config.REVENUECAT_WEBHOOK_AUTH}`;
    if (!safeEqual(authz, expected)) throw unauthorized('bad_webhook_auth');
    const body = z
      .object({
        event: z.object({
          id: z.string().min(1),
          type: z.string().min(1),
          app_user_id: z.string().min(1),
          product_id: z.string().optional(),
          expiration_at_ms: z.number().int().positive().max(8.64e15).nullish(),
          original_transaction_id: z.string().optional(),
        }).passthrough(),
      })
      .safeParse(req.body);
    if (!body.success) throw badRequest('bad_payload');
    const e = body.data.event;
    const status = await processWebhookOnce(ctx, 'revenuecat', e.id, req.rawBody ?? JSON.stringify(req.body), (tx) => applyRevenueCat(tx, e));
    req.log.info({ type: e.type, status }, 'revenuecat event');
    return reply.send({ status });
  });

  /** Razorpay webhook: HMAC-SHA256 of the raw body with the webhook secret. */
  app.post('/webhooks/razorpay', async (req, reply) => {
    const sig = req.headers['x-razorpay-signature'];
    const raw = req.rawBody;
    if (typeof sig !== 'string' || !raw) throw unauthorized('bad_signature');
    if (!safeEqual(sig, hmacSha256Hex(ctx.config.RAZORPAY_WEBHOOK_SECRET, raw))) throw unauthorized('bad_signature');
    const parsed = razorpaySchema.safeParse(req.body);
    if (!parsed.success) throw badRequest('bad_payload');
    const body = parsed.data;
    const header = req.headers['x-razorpay-event-id'];
    // Without the header, the raw body hash is the only collision-free id.
    const eventId = typeof header === 'string' && header ? header : `sha256:${sha256(raw)}`;
    // Unhandled event types are not recorded, so they can be replayed once supported.
    if (!RAZORPAY_EVENTS.has(body.event)) return reply.send({ status: 'ignored' });
    const p = body.payload;
    const notes: GymPaymentNotes = p.payment_link?.entity?.notes ?? p.invoice?.entity?.notes ?? p.subscription?.entity?.notes ?? p.payment?.entity?.notes ?? {};
    const status = await processWebhookOnce(ctx, 'razorpay', eventId, raw, (tx) => applyGymPayment(tx, notes));
    req.log.info({ event: body.event, status }, 'razorpay event');
    return reply.send({ status });
  });
}
