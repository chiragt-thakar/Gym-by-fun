import { type Kysely, sql } from 'kysely';
import type { Migration, MigrationProvider } from 'kysely/migration';

const m001_init: Migration = {
  async up(db: Kysely<unknown>) {
    await sql`create extension if not exists pgcrypto`.execute(db);

    await db.schema
      .createTable('users')
      .addColumn('id', 'uuid', (c) => c.primaryKey().defaultTo(sql`gen_random_uuid()`))
      .addColumn('phone_enc', 'text')
      .addColumn('phone_hash', 'text', (c) => c.unique())
      .addColumn('google_sub', 'text', (c) => c.unique())
      .addColumn('name', 'text')
      .addColumn('language', 'text', (c) => c.notNull().defaultTo('en'))
      .addColumn('age_confirmed_at', 'timestamptz', (c) => c.notNull())
      .addColumn('created_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
      .addColumn('deleted_at', 'timestamptz')
      .execute();

    await db.schema
      .createTable('refresh_tokens')
      .addColumn('id', 'uuid', (c) => c.primaryKey().defaultTo(sql`gen_random_uuid()`))
      .addColumn('user_id', 'uuid', (c) => c.notNull().references('users.id').onDelete('cascade'))
      .addColumn('family_id', 'uuid', (c) => c.notNull())
      .addColumn('token_hash', 'text', (c) => c.notNull().unique())
      .addColumn('expires_at', 'timestamptz', (c) => c.notNull())
      .addColumn('revoked_at', 'timestamptz')
      .addColumn('created_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
      .execute();

    await db.schema
      .createTable('otp_challenges')
      .addColumn('id', 'uuid', (c) => c.primaryKey().defaultTo(sql`gen_random_uuid()`))
      .addColumn('phone_hash', 'text', (c) => c.notNull())
      .addColumn('code_hash', 'text', (c) => c.notNull())
      .addColumn('attempts', 'integer', (c) => c.notNull().defaultTo(0))
      .addColumn('expires_at', 'timestamptz', (c) => c.notNull())
      .addColumn('consumed_at', 'timestamptz')
      .addColumn('created_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
      .execute();
    await db.schema.createIndex('otp_phone_idx').on('otp_challenges').column('phone_hash').execute();

    await db.schema
      .createTable('consents')
      .addColumn('id', 'uuid', (c) => c.primaryKey().defaultTo(sql`gen_random_uuid()`))
      .addColumn('user_id', 'uuid', (c) => c.notNull().references('users.id').onDelete('cascade'))
      .addColumn('purpose', 'text', (c) => c.notNull())
      .addColumn('version', 'integer', (c) => c.notNull())
      .addColumn('granted_at', 'timestamptz', (c) => c.notNull())
      .addColumn('withdrawn_at', 'timestamptz')
      .execute();
    await db.schema.createIndex('consents_user_idx').on('consents').columns(['user_id', 'purpose']).execute();

    await db.schema
      .createTable('devices')
      .addColumn('id', 'uuid', (c) => c.primaryKey().defaultTo(sql`gen_random_uuid()`))
      .addColumn('user_id', 'uuid', (c) => c.notNull().references('users.id').onDelete('cascade'))
      .addColumn('model', 'text', (c) => c.notNull())
      .addColumn('perf_tier', 'text', (c) => c.notNull())
      .addColumn('app_version', 'text', (c) => c.notNull())
      .addColumn('created_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
      .execute();

    await db.schema
      .createTable('calibrations')
      .addColumn('user_id', 'uuid', (c) => c.notNull().references('users.id').onDelete('cascade'))
      .addColumn('device_id', 'uuid', (c) => c.notNull().references('devices.id').onDelete('cascade'))
      .addColumn('squat_depth', 'real', (c) => c.notNull())
      .addColumn('lean_range', 'real', (c) => c.notNull())
      .addColumn('reach', 'real', (c) => c.notNull())
      .addColumn('profile', 'jsonb', (c) => c.notNull())
      .addColumn('updated_at', 'timestamptz', (c) => c.notNull())
      .addPrimaryKeyConstraint('calibrations_pk', ['user_id', 'device_id'])
      .execute();

    await db.schema
      .createTable('sessions')
      .addColumn('id', 'uuid', (c) => c.primaryKey().defaultTo(sql`gen_random_uuid()`))
      .addColumn('client_id', 'text', (c) => c.notNull())
      .addColumn('user_id', 'uuid', (c) => c.notNull().references('users.id').onDelete('cascade'))
      .addColumn('device_id', 'uuid', (c) => c.references('devices.id').onDelete('set null'))
      .addColumn('level_id', 'text', (c) => c.notNull())
      .addColumn('started_at', 'timestamptz', (c) => c.notNull())
      .addColumn('duration_s', 'integer', (c) => c.notNull())
      .addColumn('active_s', 'integer', (c) => c.notNull())
      .addColumn('score', 'integer', (c) => c.notNull())
      .addColumn('difficulty', 'text', (c) => c.notNull())
      .addColumn('low_impact', 'boolean', (c) => c.notNull())
      .addColumn('completed', 'boolean', (c) => c.notNull())
      .addColumn('effort_rating', 'integer')
      .addColumn('effort_points', 'integer', (c) => c.notNull())
      .addColumn('flagged', 'boolean', (c) => c.notNull())
      .addColumn('created_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
      .addUniqueConstraint('sessions_client_uq', ['user_id', 'client_id'])
      .execute();
    await db.schema.createIndex('sessions_user_started_idx').on('sessions').columns(['user_id', 'started_at']).execute();

    await db.schema
      .createTable('session_moves')
      .addColumn('session_id', 'uuid', (c) => c.notNull().references('sessions.id').onDelete('cascade'))
      .addColumn('move', 'text', (c) => c.notNull())
      .addColumn('attempts', 'integer', (c) => c.notNull())
      .addColumn('recognised', 'integer', (c) => c.notNull())
      .addColumn('false_triggers', 'integer', (c) => c.notNull())
      .addColumn('avg_latency_ms', 'integer')
      .addPrimaryKeyConstraint('session_moves_pk', ['session_id', 'move'])
      .execute();

    await db.schema
      .createTable('progress')
      .addColumn('user_id', 'uuid', (c) => c.primaryKey().references('users.id').onDelete('cascade'))
      .addColumn('xp', 'integer', (c) => c.notNull())
      .addColumn('hero_level', 'integer', (c) => c.notNull())
      .addColumn('worlds', 'jsonb', (c) => c.notNull())
      .addColumn('streak', 'integer', (c) => c.notNull())
      .addColumn('best_streak', 'integer', (c) => c.notNull())
      .addColumn('shields', 'integer', (c) => c.notNull())
      .addColumn('shields_month', 'text', (c) => c.notNull())
      .addColumn('last_played_on', 'date')
      .addColumn('sessions_count', 'integer', (c) => c.notNull())
      .addColumn('active_s_total', 'integer', (c) => c.notNull())
      .addColumn('updated_at', 'timestamptz', (c) => c.notNull())
      .execute();

    await db.schema
      .createTable('pain_reports')
      .addColumn('id', 'uuid', (c) => c.primaryKey().defaultTo(sql`gen_random_uuid()`))
      .addColumn('user_id', 'uuid', (c) => c.notNull().references('users.id').onDelete('cascade'))
      .addColumn('session_client_id', 'text')
      .addColumn('area', 'text', (c) => c.notNull())
      .addColumn('note', 'text')
      .addColumn('created_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
      .addColumn('reviewed_at', 'timestamptz')
      .execute();

    await db.schema
      .createTable('gyms')
      .addColumn('id', 'uuid', (c) => c.primaryKey().defaultTo(sql`gen_random_uuid()`))
      .addColumn('name', 'text', (c) => c.notNull())
      .addColumn('city', 'text', (c) => c.notNull())
      .addColumn('logo_url', 'text')
      .addColumn('colours', 'jsonb', (c) => c.notNull())
      .addColumn('plan', 'text', (c) => c.notNull())
      .addColumn('status', 'text', (c) => c.notNull())
      .addColumn('licence_until', 'timestamptz', (c) => c.notNull())
      .addColumn('owner_name', 'text')
      .addColumn('owner_phone_enc', 'text')
      .addColumn('trainer_key_hash', 'text')
      .addColumn('created_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
      .execute();

    await db.schema
      .createTable('gym_codes')
      .addColumn('code', 'text', (c) => c.primaryKey())
      .addColumn('gym_id', 'uuid', (c) => c.notNull().references('gyms.id').onDelete('cascade'))
      .addColumn('max_members', 'integer', (c) => c.notNull())
      .addColumn('expires_at', 'timestamptz', (c) => c.notNull())
      .addColumn('created_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
      .execute();

    await db.schema
      .createTable('memberships')
      .addColumn('user_id', 'uuid', (c) => c.notNull().references('users.id').onDelete('cascade'))
      .addColumn('gym_id', 'uuid', (c) => c.notNull().references('gyms.id').onDelete('cascade'))
      .addColumn('joined_at', 'timestamptz', (c) => c.notNull())
      .addColumn('left_at', 'timestamptz')
      .addColumn('shares_activity', 'boolean', (c) => c.notNull())
      .addColumn('code', 'text', (c) => c.notNull())
      .addPrimaryKeyConstraint('memberships_pk', ['user_id', 'gym_id'])
      .execute();

    await db.schema
      .createTable('trainer_quests')
      .addColumn('id', 'uuid', (c) => c.primaryKey().defaultTo(sql`gen_random_uuid()`))
      .addColumn('gym_id', 'uuid', (c) => c.notNull().references('gyms.id').onDelete('cascade'))
      .addColumn('level_id', 'text', (c) => c.notNull())
      .addColumn('title', 'text', (c) => c.notNull())
      .addColumn('due_at', 'timestamptz', (c) => c.notNull())
      .addColumn('created_at', 'timestamptz', (c) => c.notNull().defaultTo(sql`now()`))
      .execute();

    await db.schema
      .createTable('crew_scores')
      .addColumn('gym_id', 'uuid', (c) => c.notNull().references('gyms.id').onDelete('cascade'))
      .addColumn('week', 'text', (c) => c.notNull())
      .addColumn('user_id', 'uuid', (c) => c.notNull().references('users.id').onDelete('cascade'))
      .addColumn('effort_points', 'integer', (c) => c.notNull())
      .addColumn('sessions', 'integer', (c) => c.notNull())
      .addPrimaryKeyConstraint('crew_scores_pk', ['gym_id', 'week', 'user_id'])
      .execute();

    await db.schema
      .createTable('entitlements')
      .addColumn('id', 'uuid', (c) => c.primaryKey().defaultTo(sql`gen_random_uuid()`))
      .addColumn('user_id', 'uuid', (c) => c.notNull().references('users.id').onDelete('cascade'))
      .addColumn('source', 'text', (c) => c.notNull())
      .addColumn('product', 'text', (c) => c.notNull())
      .addColumn('source_ref', 'text', (c) => c.notNull())
      .addColumn('active_until', 'timestamptz', (c) => c.notNull())
      .addColumn('updated_at', 'timestamptz', (c) => c.notNull())
      .addUniqueConstraint('entitlements_uq', ['user_id', 'source', 'source_ref'])
      .execute();

    await db.schema
      .createTable('billing_events')
      .addColumn('provider', 'text', (c) => c.notNull())
      .addColumn('event_id', 'text', (c) => c.notNull())
      .addColumn('payload_hash', 'text', (c) => c.notNull())
      .addColumn('processed_at', 'timestamptz', (c) => c.notNull())
      .addPrimaryKeyConstraint('billing_events_pk', ['provider', 'event_id'])
      .execute();

    await db.schema
      .createTable('content_versions')
      .addColumn('level_id', 'text', (c) => c.notNull())
      .addColumn('version', 'integer', (c) => c.notNull())
      .addColumn('schema_version', 'integer', (c) => c.notNull())
      .addColumn('json', 'jsonb', (c) => c.notNull())
      .addColumn('sha256', 'text', (c) => c.notNull())
      .addColumn('published_at', 'timestamptz', (c) => c.notNull())
      .addPrimaryKeyConstraint('content_versions_pk', ['level_id', 'version'])
      .execute();

    await db.schema
      .createTable('report_runs')
      .addColumn('gym_id', 'uuid', (c) => c.notNull().references('gyms.id').onDelete('cascade'))
      .addColumn('week', 'text', (c) => c.notNull())
      .addColumn('sent_at', 'timestamptz', (c) => c.notNull())
      .addColumn('body', 'text', (c) => c.notNull())
      .addPrimaryKeyConstraint('report_runs_pk', ['gym_id', 'week'])
      .execute();
  },
};

export const migrations: Record<string, Migration> = {
  '001_init': m001_init,
};

export const migrationProvider: MigrationProvider = {
  getMigrations: async () => migrations,
};
