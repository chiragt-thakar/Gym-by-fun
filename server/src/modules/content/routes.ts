import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { AppContext } from '../../context.js';
import { requireAdmin } from '../../lib/auth.js';
import { notFound } from '../../lib/errors.js';
import { parse } from '../../lib/validate.js';
import { manifest, publishLevel } from './service.js';

export async function contentRoutes(app: FastifyInstance, ctx: AppContext) {
  app.get('/content/manifest', async (_req, reply) => {
    reply.header('cache-control', 'public, max-age=300');
    return { levels: await manifest(ctx) };
  });

  app.get('/content/levels/:id', async (req, reply) => {
    const { id } = parse(z.object({ id: z.string().regex(/^w\d+-[a-z0-9-]+$/) }), req.params);
    const { version } = parse(z.object({ version: z.coerce.number().int().min(1).optional() }), req.query);
    let q = ctx.db.selectFrom('content_versions').select(['json', 'sha256', 'version']).where('level_id', '=', id);
    q = version ? q.where('version', '=', version) : q.orderBy('version', 'desc').limit(1);
    const row = await q.executeTakeFirst();
    if (!row) throw notFound('level_not_found');
    reply.header('etag', `"${row.sha256}"`).header('cache-control', version ? 'public, max-age=31536000, immutable' : 'public, max-age=300');
    return row.json;
  });

  app.post('/admin/content/levels', { preHandler: requireAdmin(ctx) }, async (req, reply) => {
    const r = await publishLevel(ctx, req.body);
    return reply.code(r.unchanged ? 200 : 201).send(r);
  });
}
