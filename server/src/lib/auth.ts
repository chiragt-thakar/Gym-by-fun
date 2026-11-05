import type { FastifyReply, FastifyRequest } from 'fastify';

import type { AppContext } from '../context.js';
import { verifyAccess } from '../modules/identity/tokens.js';
import { safeEqual } from './crypto.js';
import { forbidden, unauthorized } from './errors.js';

declare module 'fastify' {
  interface FastifyRequest {
    userId: string;
  }
}

export function requireUser(ctx: AppContext) {
  return async (req: FastifyRequest) => {
    const h = req.headers.authorization;
    if (!h?.startsWith('Bearer ')) throw unauthorized();
    const userId = await verifyAccess(ctx, h.slice(7));
    const user = await ctx.db.selectFrom('users').select(['id', 'deleted_at']).where('id', '=', userId).executeTakeFirst();
    if (!user || user.deleted_at) throw unauthorized('account_deleted');
    req.userId = userId;
  };
}

export function requireAdmin(ctx: AppContext) {
  return async (req: FastifyRequest, _reply: FastifyReply) => {
    const key = req.headers['x-admin-key'];
    if (typeof key !== 'string' || !safeEqual(key, ctx.config.ADMIN_API_KEY)) throw forbidden();
  };
}
