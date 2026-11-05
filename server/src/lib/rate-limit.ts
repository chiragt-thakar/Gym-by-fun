import type { Redis } from 'ioredis';

/** Fixed-window counter in Redis. Returns true if the call is allowed. */
export async function allow(redis: Redis, key: string, limit: number, windowS: number): Promise<boolean> {
  const k = `rl:${key}`;
  const n = await redis.incr(k);
  if (n === 1) await redis.expire(k, windowS);
  return n <= limit;
}
