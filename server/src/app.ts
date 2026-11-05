import Fastify, { type FastifyInstance } from 'fastify';
import { Redis } from 'ioredis';

import type { Config } from './config.js';
import { type AppContext, makeCipher } from './context.js';
import { createDb, type DB, migrateToLatest } from './db/database.js';
import { HttpError } from './lib/errors.js';
import { defaultProviders, type Providers } from './lib/providers.js';
import { billingRoutes } from './modules/billing/routes.js';
import { contentRoutes } from './modules/content/routes.js';
import { seedContent } from './modules/content/service.js';
import { gymRoutes } from './modules/gyms/routes.js';
import { identityRoutes } from './modules/identity/routes.js';
import { progressRoutes } from './modules/progress/routes.js';

export interface BuildOptions {
  config: Config;
  db?: DB;
  redis?: Redis;
  providers?: Partial<Providers>;
  now?: () => Date;
  logger?: boolean;
  migrate?: boolean;
}

export async function buildApp(opts: BuildOptions): Promise<{ app: FastifyInstance; ctx: AppContext }> {
  const app = Fastify({
    logger: opts.logger === false ? false : { level: opts.config.NODE_ENV === 'production' ? 'info' : 'debug', redact: ['req.headers.authorization', 'req.headers["x-admin-key"]'] },
    trustProxy: true,
    bodyLimit: 512 * 1024,
  });

  // Keep the raw body: webhook signatures are computed over exact bytes.
  app.addContentTypeParser('application/json', { parseAs: 'string' }, (req, body, done) => {
    const text = body as string;
    req.rawBody = text;
    if (!text) return done(null, undefined);
    try {
      done(null, JSON.parse(text));
    } catch {
      done(new HttpError(400, 'invalid_json'), undefined);
    }
  });

  const db = opts.db ?? createDb(opts.config.DATABASE_URL);
  const redis = opts.redis ?? new Redis(opts.config.REDIS_URL, { lazyConnect: false, maxRetriesPerRequest: 3 });
  const ctx: AppContext = {
    config: opts.config,
    db,
    redis,
    providers: { ...defaultProviders(opts.config, app.log), ...opts.providers },
    pii: makeCipher(opts.config),
    now: opts.now ?? (() => new Date()),
  };

  if (opts.migrate !== false) {
    await migrateToLatest(db);
    await seedContent(ctx);
  }

  app.setErrorHandler((err, req, reply) => {
    if (err instanceof HttpError) {
      return reply.code(err.statusCode).send({ error: err.code, message: err.message });
    }
    const status = (err as { statusCode?: number }).statusCode;
    if (status && status < 500) return reply.code(status).send({ error: 'bad_request', message: (err as Error).message });
    req.log.error({ err }, 'unhandled error');
    return reply.code(500).send({ error: 'internal' });
  });

  app.get('/healthz', async () => {
    await ctx.db.selectFrom('content_versions').select('level_id').limit(1).execute();
    return { ok: true };
  });

  await app.register(
    async (v1) => {
      await identityRoutes(v1, ctx);
      await progressRoutes(v1, ctx);
      await gymRoutes(v1, ctx);
      await billingRoutes(v1, ctx);
      await contentRoutes(v1, ctx);
    },
    { prefix: '/v1' },
  );

  app.addHook('onClose', async () => {
    if (!opts.db) await db.destroy();
    if (!opts.redis) redis.disconnect();
  });

  return { app, ctx };
}
