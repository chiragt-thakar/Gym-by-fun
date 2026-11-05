import type { ColumnType, Generated, Insertable, Selectable } from 'kysely';

type Timestamp = ColumnType<Date, Date | string | undefined, Date | string>;
type Json<T = unknown> = ColumnType<T, string, string>;

/** No table ever stores video or images. */
export interface Database {
  users: UsersTable;
  refresh_tokens: RefreshTokensTable;
  otp_challenges: OtpChallengesTable;
  consents: ConsentsTable;
  devices: DevicesTable;
  calibrations: CalibrationsTable;
  sessions: SessionsTable;
  session_moves: SessionMovesTable;
  progress: ProgressTable;
  pain_reports: PainReportsTable;
  gyms: GymsTable;
  gym_codes: GymCodesTable;
  memberships: MembershipsTable;
  trainer_quests: TrainerQuestsTable;
  crew_scores: CrewScoresTable;
  entitlements: EntitlementsTable;
  billing_events: BillingEventsTable;
  content_versions: ContentVersionsTable;
  report_runs: ReportRunsTable;
}

export interface UsersTable {
  id: Generated<string>;
  phone_enc: string | null;
  phone_hash: string | null;
  google_sub: string | null;
  name: string | null;
  language: Generated<string>;
  age_confirmed_at: Timestamp;
  created_at: Generated<Date>;
  deleted_at: Date | null;
}
export type User = Selectable<UsersTable>;

export interface RefreshTokensTable {
  id: Generated<string>;
  user_id: string;
  family_id: string;
  token_hash: string;
  expires_at: Timestamp;
  revoked_at: Date | null;
  created_at: Generated<Date>;
}

export interface OtpChallengesTable {
  id: Generated<string>;
  phone_hash: string;
  code_hash: string;
  attempts: Generated<number>;
  expires_at: Timestamp;
  consumed_at: Date | null;
  created_at: Generated<Date>;
}

export type ConsentPurpose = 'account' | 'gym_sharing' | 'analytics' | 'calibration_backup';
export interface ConsentsTable {
  id: Generated<string>;
  user_id: string;
  purpose: ConsentPurpose;
  version: number;
  granted_at: Timestamp;
  withdrawn_at: Date | null;
}

export interface DevicesTable {
  id: Generated<string>;
  user_id: string;
  model: string;
  perf_tier: 'upper_mid' | 'mid' | 'budget';
  app_version: string;
  created_at: Generated<Date>;
}

export interface CalibrationsTable {
  user_id: string;
  device_id: string;
  squat_depth: number;
  lean_range: number;
  reach: number;
  profile: Json<Record<string, number>>;
  updated_at: Timestamp;
}

export interface SessionsTable {
  id: Generated<string>;
  client_id: string;
  user_id: string;
  device_id: string | null;
  level_id: string;
  started_at: Timestamp;
  duration_s: number;
  active_s: number;
  score: number;
  difficulty: 'beginner' | 'intermediate' | 'advanced';
  low_impact: boolean;
  completed: boolean;
  effort_rating: number | null;
  effort_points: number;
  flagged: boolean;
  created_at: Generated<Date>;
}
export type Session = Selectable<SessionsTable>;

export interface SessionMovesTable {
  session_id: string;
  move: string;
  attempts: number;
  recognised: number;
  false_triggers: number;
  avg_latency_ms: number | null;
}

export interface ProgressTable {
  user_id: string;
  xp: number;
  hero_level: number;
  worlds: Json<number[]>;
  streak: number;
  best_streak: number;
  shields: number;
  shields_month: string;
  last_played_on: string | null;
  sessions_count: number;
  active_s_total: number;
  updated_at: Timestamp;
}

export interface PainReportsTable {
  id: Generated<string>;
  user_id: string;
  session_client_id: string | null;
  area: string;
  note: string | null;
  created_at: Generated<Date>;
  reviewed_at: Date | null;
}

export interface GymsTable {
  id: Generated<string>;
  name: string;
  city: string;
  logo_url: string | null;
  colours: Json<{ primary: string; secondary: string }>;
  plan: 'pilot' | 'founding' | 'starter' | 'growth' | 'chain';
  status: 'pilot' | 'active' | 'lapsed' | 'cancelled';
  licence_until: Timestamp;
  owner_name: string | null;
  owner_phone_enc: string | null;
  trainer_key_hash: string | null;
  created_at: Generated<Date>;
}
export type Gym = Selectable<GymsTable>;

export interface GymCodesTable {
  code: string;
  gym_id: string;
  max_members: number;
  expires_at: Timestamp;
  created_at: Generated<Date>;
}

export interface MembershipsTable {
  user_id: string;
  gym_id: string;
  joined_at: Timestamp;
  left_at: Date | null;
  shares_activity: boolean;
  code: string;
}

export interface TrainerQuestsTable {
  id: Generated<string>;
  gym_id: string;
  level_id: string;
  title: string;
  due_at: Timestamp;
  created_at: Generated<Date>;
}

export interface CrewScoresTable {
  gym_id: string;
  week: string;
  user_id: string;
  effort_points: number;
  sessions: number;
}

export interface EntitlementsTable {
  id: Generated<string>;
  user_id: string;
  source: 'play' | 'gym' | 'promo';
  product: string;
  source_ref: string;
  active_until: Timestamp;
  updated_at: Timestamp;
}

export interface BillingEventsTable {
  provider: 'revenuecat' | 'razorpay';
  event_id: string;
  payload_hash: string;
  processed_at: Timestamp;
}

export interface ContentVersionsTable {
  level_id: string;
  version: number;
  schema_version: number;
  json: Json<Record<string, unknown>>;
  sha256: string;
  published_at: Timestamp;
}

export interface ReportRunsTable {
  gym_id: string;
  week: string;
  sent_at: Timestamp;
  body: string;
}

export type NewSession = Insertable<SessionsTable>;
