import { readdirSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

import { sql } from 'kysely';

import type { AppContext } from '../../context.js';
import { sha256 } from '../../lib/crypto.js';
import { badRequest, conflict } from '../../lib/errors.js';
import { type LevelJson, validateLevel } from './validator.js';

export async function publishLevel(ctx: AppContext, level: unknown) {
  const errors = validateLevel(level);
  if (errors.length) throw badRequest('invalid_level', errors.slice(0, 5).join('; '));
  const l = level as LevelJson;
  const text = JSON.stringify(l);
  const existing = await ctx.db
    .selectFrom('content_versions')
    .select(['sha256'])
    .where('level_id', '=', l.id)
    .where('version', '=', l.version)
    .executeTakeFirst();
  if (existing) {
    if (existing.sha256 === sha256(text)) return { levelId: l.id, version: l.version, unchanged: true };
    throw conflict('version_exists_with_different_content');
  }
  await ctx.db
    .insertInto('content_versions')
    .values({ level_id: l.id, version: l.version, schema_version: l.schemaVersion, json: text, sha256: sha256(text), published_at: ctx.now() })
    .execute();
  return { levelId: l.id, version: l.version, unchanged: false };
}

/** Seeds the database from content/levels on boot (idempotent). */
export async function seedContent(ctx: AppContext, dir = ctx.config.CONTENT_DIR) {
  const abs = resolve(dir);
  for (const f of readdirSync(abs).filter((n) => n.endsWith('.json')).sort()) {
    await publishLevel(ctx, JSON.parse(readFileSync(join(abs, f), 'utf8')));
  }
}

export type LevelAccess = 'free' | 'premium';

/** World 1 is free; every later world needs Premium. */
export const accessForWorld = (world: number): LevelAccess => (world <= 1 ? 'free' : 'premium');

/** Latest version of each level. */
export async function manifest(ctx: AppContext) {
  const rows = await ctx.db
    .selectFrom('content_versions as c')
    .select(['c.level_id', 'c.version', 'c.schema_version', 'c.sha256', 'c.published_at', sql<number | null>`(c.json->>'world')::int`.as('world')])
    .where('c.version', '=', (eb) =>
      eb.selectFrom('content_versions as c2').select(sql<number>`max(c2.version)`.as('v')).whereRef('c2.level_id', '=', 'c.level_id'),
    )
    .orderBy('c.level_id')
    .execute();
  return rows.map((r) => ({
    levelId: r.level_id,
    version: r.version,
    schemaVersion: r.schema_version,
    sha256: r.sha256,
    url: `/v1/content/levels/${r.level_id}?version=${r.version}`,
    publishedAt: r.published_at,
    world: r.world ?? 1,
    access: accessForWorld(r.world ?? 1),
  }));
}
