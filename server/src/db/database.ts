import { Kysely, PostgresDialect } from 'kysely';
import { Migrator } from 'kysely/migration';
import pg from 'pg';

import { migrationProvider } from './migrations.js';
import type { Database } from './schema.js';

export type DB = Kysely<Database>;

// Keep SQL `date` columns as 'YYYY-MM-DD' strings (no timezone surprises).
pg.types.setTypeParser(1082, (v) => v);

export function createDb(url: string): DB {
  return new Kysely<Database>({
    dialect: new PostgresDialect({ pool: new pg.Pool({ connectionString: url, max: 10 }) }),
  });
}

export async function migrateToLatest(db: DB): Promise<void> {
  const migrator = new Migrator({ db, provider: migrationProvider });
  const { error, results } = await migrator.migrateToLatest();
  for (const r of results ?? []) {
    if (r.status === 'Error') throw new Error(`Migration ${r.migrationName} failed`);
  }
  if (error) throw error instanceof Error ? error : new Error(String(error));
}
