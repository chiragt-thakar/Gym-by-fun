import { randomUUID } from 'node:crypto';

import { SignJWT, jwtVerify } from 'jose';

import type { AppContext } from '../../context.js';
import { randomToken, sha256 } from '../../lib/crypto.js';
import { unauthorized } from '../../lib/errors.js';

export interface TokenPair {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
}

const ISSUER = 'motionquest';

function secret(ctx: AppContext) {
  return new TextEncoder().encode(ctx.config.JWT_SECRET);
}

export async function signAccess(ctx: AppContext, userId: string): Promise<string> {
  const now = Math.floor(ctx.now().getTime() / 1000);
  return new SignJWT({})
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(userId)
    .setIssuer(ISSUER)
    .setIssuedAt(now)
    .setExpirationTime(now + ctx.config.ACCESS_TOKEN_TTL_S)
    .sign(secret(ctx));
}

export async function verifyAccess(ctx: AppContext, token: string): Promise<string> {
  try {
    const { payload } = await jwtVerify(token, secret(ctx), {
      issuer: ISSUER,
      currentDate: ctx.now(),
    });
    if (!payload.sub) throw unauthorized();
    return payload.sub;
  } catch {
    throw unauthorized('invalid_token');
  }
}

/** Issues a new pair. Refresh tokens are opaque, stored hashed, and rotate on use. */
export async function issueTokens(ctx: AppContext, userId: string, familyId: string = randomUUID()): Promise<TokenPair> {
  const refresh = randomToken();
  const expires = new Date(ctx.now().getTime() + ctx.config.REFRESH_TOKEN_TTL_DAYS * 86_400_000);
  await ctx.db
    .insertInto('refresh_tokens')
    .values({ user_id: userId, family_id: familyId, token_hash: sha256(refresh), expires_at: expires })
    .execute();
  return { accessToken: await signAccess(ctx, userId), refreshToken: refresh, expiresIn: ctx.config.ACCESS_TOKEN_TTL_S };
}

/**
 * Rotates a refresh token. Re-use of an already-rotated token means it leaked:
 * the whole family is revoked and the user must sign in again.
 */
export async function rotateRefresh(ctx: AppContext, refresh: string): Promise<TokenPair> {
  const row = await ctx.db
    .selectFrom('refresh_tokens')
    .innerJoin('users', 'users.id', 'refresh_tokens.user_id')
    .select(['refresh_tokens.id', 'refresh_tokens.user_id', 'refresh_tokens.family_id', 'refresh_tokens.revoked_at', 'refresh_tokens.expires_at', 'users.deleted_at'])
    .where('token_hash', '=', sha256(refresh))
    .executeTakeFirst();
  if (!row || row.deleted_at) throw unauthorized('invalid_refresh');
  if (row.revoked_at) {
    await revokeFamily(ctx, row.family_id);
    throw unauthorized('refresh_reused');
  }
  if (new Date(row.expires_at) <= ctx.now()) throw unauthorized('refresh_expired');
  await ctx.db.updateTable('refresh_tokens').set({ revoked_at: ctx.now() }).where('id', '=', row.id).execute();
  return issueTokens(ctx, row.user_id, row.family_id);
}

export async function revokeFamily(ctx: AppContext, familyId: string) {
  await ctx.db
    .updateTable('refresh_tokens')
    .set({ revoked_at: ctx.now() })
    .where('family_id', '=', familyId)
    .where('revoked_at', 'is', null)
    .execute();
}

export async function revokeAllForUser(ctx: AppContext, userId: string) {
  await ctx.db
    .updateTable('refresh_tokens')
    .set({ revoked_at: ctx.now() })
    .where('user_id', '=', userId)
    .where('revoked_at', 'is', null)
    .execute();
}
