import type { AppContext } from '../../context.js';
import { sha256 } from '../../lib/crypto.js';
import { addMonths } from '../../lib/time.js';

export const PREMIUM = 'premium';

export interface Entitlement {
  premium: boolean;
  source: 'play' | 'gym' | 'promo' | null;
  activeUntil: Date | null;
}

/**
 * The single Premium check. Premium is decided here, on the server; the app
 * can never grant itself access.
 */
export async function getEntitlement(ctx: AppContext, userId: string): Promise<Entitlement> {
  const row = await ctx.db
    .selectFrom('entitlements')
    .select(['source', 'active_until'])
    .where('user_id', '=', userId)
    .where('product', '=', PREMIUM)
    .where('active_until', '>', ctx.now())
    .orderBy('active_until', 'desc')
    .executeTakeFirst();
  if (!row) return { premium: false, source: null, activeUntil: null };
  return { premium: true, source: row.source, activeUntil: new Date(row.active_until) };
}

async function upsert(ctx: AppContext, userId: string, source: 'play' | 'gym' | 'promo', ref: string, until: Date) {
  const values = { user_id: userId, source, product: PREMIUM, source_ref: ref, active_until: until, updated_at: ctx.now() };
  await ctx.db
    .insertInto('entitlements')
    .values(values)
    .onConflict((oc) => oc.columns(['user_id', 'source', 'source_ref']).doUpdateSet({ active_until: until, updated_at: ctx.now() }))
    .execute();
}

export async function grantGymEntitlement(ctx: AppContext, userId: string, gymId: string, until: Date) {
  await upsert(ctx, userId, 'gym', gymId, until);
}

export async function revokeGymEntitlement(ctx: AppContext, userId: string, gymId: string) {
  await ctx.db
    .updateTable('entitlements')
    .set({ active_until: ctx.now(), updated_at: ctx.now() })
    .where('user_id', '=', userId)
    .where('source', '=', 'gym')
    .where('source_ref', '=', gymId)
    .execute();
}

export type WebhookStatus = 'applied' | 'ignored' | 'duplicate';

/**
 * Processes a webhook event exactly once. The `billing_events` marker and the
 * change it records are written in one transaction: if `apply` throws, the
 * marker is rolled back too, so the provider's retry is applied rather than
 * reported as a duplicate.
 */
export async function processWebhookOnce(
  ctx: AppContext,
  provider: 'revenuecat' | 'razorpay',
  eventId: string,
  raw: string,
  apply: (txCtx: AppContext) => Promise<'applied' | 'ignored'>,
): Promise<WebhookStatus> {
  return ctx.db.transaction().execute(async (tx) => {
    const r = await tx
      .insertInto('billing_events')
      .values({ provider, event_id: eventId, payload_hash: sha256(raw), processed_at: ctx.now() })
      .onConflict((oc) => oc.columns(['provider', 'event_id']).doNothing())
      .returning('event_id')
      .executeTakeFirst();
    if (!r) return 'duplicate';
    return apply({ ...ctx, db: tx });
  });
}

export interface RevenueCatEvent {
  id: string;
  type: string;
  app_user_id: string;
  product_id?: string;
  expiration_at_ms?: number | null;
  original_transaction_id?: string;
}

const RC_EXTENDS = new Set(['INITIAL_PURCHASE', 'RENEWAL', 'PRODUCT_CHANGE', 'UNCANCELLATION', 'NON_RENEWING_PURCHASE', 'TEMPORARY_ENTITLEMENT_GRANT']);

/**
 * RevenueCat → entitlement. Cancellation keeps access until the period ends
 * (the store already set the expiry); expiration ends it.
 */
export async function applyRevenueCat(ctx: AppContext, e: RevenueCatEvent): Promise<'applied' | 'ignored'> {
  const user = await ctx.db.selectFrom('users').select('id').where('id', '=', e.app_user_id).executeTakeFirst();
  if (!user) return 'ignored';
  const ref = e.original_transaction_id ?? 'play';
  if (RC_EXTENDS.has(e.type) && e.expiration_at_ms) {
    await upsert(ctx, user.id, 'play', ref, new Date(e.expiration_at_ms));
    return 'applied';
  }
  if (e.type === 'EXPIRATION') {
    const until = e.expiration_at_ms ? new Date(Math.min(e.expiration_at_ms, ctx.now().getTime())) : ctx.now();
    await upsert(ctx, user.id, 'play', ref, until);
    return 'applied';
  }
  // CANCELLATION, BILLING_ISSUE, TRANSFER, TEST...: nothing to change now.
  return 'ignored';
}

export interface GymPaymentNotes {
  gym_id?: string;
  plan?: string;
  period?: string;
}

const PLAN_PERIOD_MONTHS: Record<string, number> = { monthly: 1, yearly: 12 };

/** Razorpay (gym licence paid outside the app) → gym licence + members' Premium. */
export async function applyGymPayment(ctx: AppContext, notes: GymPaymentNotes): Promise<'applied' | 'ignored'> {
  if (!notes.gym_id || !/^[0-9a-f-]{36}$/.test(notes.gym_id)) return 'ignored';
  const months = PLAN_PERIOD_MONTHS[notes.period ?? 'yearly'] ?? 12;
  const plan = ['founding', 'starter', 'growth', 'chain'].includes(notes.plan ?? '') ? (notes.plan as 'founding' | 'starter' | 'growth' | 'chain') : 'starter';
  const gym = await ctx.db.selectFrom('gyms').select(['id', 'licence_until']).where('id', '=', notes.gym_id).executeTakeFirst();
  if (!gym) return 'ignored';
  const now = ctx.now();
  const from = new Date(gym.licence_until) > now ? new Date(gym.licence_until) : now;
  const until = addMonths(from, months);
  const write = async (tx: AppContext['db']) => {
    await tx.updateTable('gyms').set({ licence_until: until, status: 'active', plan }).where('id', '=', gym.id).execute();
    await tx
      .updateTable('entitlements')
      .set({ active_until: until, updated_at: now })
      .where('source', '=', 'gym')
      .where('source_ref', '=', gym.id)
      .where('user_id', 'in', tx.selectFrom('memberships').select('user_id').where('gym_id', '=', gym.id).where('left_at', 'is', null))
      .execute();
  };
  // Already inside the webhook transaction? Then join it; otherwise open one.
  if (ctx.db.isTransaction) await write(ctx.db);
  else await ctx.db.transaction().execute(write);
  return 'applied';
}

/** Gym licence prices in rupees, excluding GST (plan: Pricing → Gyms). */
export const GYM_PRICES: Record<string, { monthly?: number; yearly: number }> = {
  founding: { yearly: 7999 },
  starter: { monthly: 999, yearly: 9999 },
  growth: { monthly: 2499, yearly: 24999 },
};
export const GST_RATE = 0.18;

export function gymPriceInPaise(plan: string, period: 'monthly' | 'yearly'): { base: number; gst: number; total: number } | null {
  const p = GYM_PRICES[plan]?.[period];
  if (!p) return null;
  const base = p * 100;
  const gst = Math.round(base * GST_RATE);
  return { base, gst, total: base + gst };
}
