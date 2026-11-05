# Architecture

Everything that touches video runs on the phone; the cloud stores only
results, gyms and payments.

```
 PHONE                                                     SERVER (one TypeScript service)
 ┌──────────────────────────────────────────────┐          ┌──────────────────────────────────┐
 │ native/pose_bridge (Kotlin)                  │          │ Fastify /v1                      │
 │  CameraX front cam ─▶ MediaPipe Pose (lite)  │          │  identity  OTP, Google, tokens,  │
 │  latest frame only, mirrored, pixels freed   │          │            consent, export, delete│
 │        │ 33 landmarks (EventChannel)         │          │  progress  sessions, XP, streaks │
 │        ▼                                     │          │  gyms      codes, crew, quests   │
 │ packages/motion_core (pure Dart)             │  HTTPS   │  billing   entitlements, webhooks│
 │  QualityGate → OneEuro → Features →          │ ───────▶ │  content   level manifest        │
 │  Squat/Lean/RaiseArms state machines         │ summaries│  reports   Monday WhatsApp (BullMQ)
 │        │ MoveStarted/Held/Ended, Paused      │   only   │                                  │
 │        ▼                                     │          │ PostgreSQL · Redis · BullMQ      │
 │ packages/game_director (pure Dart)           │          └──────────────────────────────────┘
 │  Director (plan) · Pacer · RunEngine (rules) │
 │        │ RunEvents                           │
 │        ▼                                     │
 │ app/ (Flutter + Flame) render, audio, HUD    │
 │  offline session queue ──────────────────────┼──▶ POST /v1/sessions (idempotent clientId)
 └──────────────────────────────────────────────┘
```

## Stable decisions

| Decision | Why |
|---|---|
| Flutter + Flame, Android first | One codebase for game, menus and (later) payments. |
| Own thin Kotlin plugin for MediaPipe | Control over resolution, frame dropping and delegate; community plugins are unverified. |
| Only landmarks cross into Dart | Frames through Flutter cap Android near 24 fps; privacy. |
| Latest frame only | `STRATEGY_KEEP_ONLY_LATEST` + drop while busy; no queue, bounded latency. |
| Selfie coordinates | Bridge rotates upright and mirrors, so player's left = smaller x everywhere. |
| motion_core and game_director are pure Dart | Deterministic, replay-testable on every commit; engine-agnostic (TV/console later). |
| Recognisers are state machines with hysteresis | Separate start/end thresholds, confirm frames, cooldowns; no flicker. |
| Leg span (hip→ankle) measures squat depth | Unaffected by phone tilt; a forward bend does not change it. |
| Quality gate uses torso-based body size | A squat shrinks the bounding box; it must not read as "too far". |
| Tracking pause is debounced (250 ms) and resume needs 300 ms of good frames | Short glitches only turn the dot amber. |
| Director is deterministic, config-driven | Same level + settings ⇒ same plan. No cloud AI in gameplay. |
| RunEngine owns rules; Flame only draws | Simulated runs prove every level finishable at every difficulty. |
| Level content = versioned JSON + JSON Schema | Validated in CI and before publishing; immutable versions served with ETags. |
| Modular monolith, modules call in-process | One deployable; split a module out only when it must scale alone. |
| One entitlement check (`entitlements` table) | Play (RevenueCat) and gym codes merge; server decides Premium. |
| Offline-first sessions | Local JSON queue; batched idempotent upload. |
| Calendar in IST | Streaks and weeks follow the player's day in India. |

## Repository layout

See [AGENTS.md](../AGENTS.md#layout).

## Data model

18 tables (see `server/src/db/migrations.ts`): users, refresh_tokens,
otp_challenges, consents, devices, calibrations, sessions, session_moves,
progress, pain_reports, gyms, gym_codes, memberships, trainer_quests,
crew_scores, entitlements, billing_events, content_versions, report_runs.
**No table ever stores video or images.**

## API (REST, `/v1`)

| Area | Endpoints |
|---|---|
| Auth | `POST /auth/otp/start`, `POST /auth/otp/verify`, `POST /auth/google`, `POST /auth/refresh` |
| Account | `GET/PATCH/DELETE /me`, `GET /me/export`, `GET/PUT /me/consents`, `POST /me/pain-reports` |
| Play | `POST /devices`, `GET/PUT /me/calibration`, `POST /sessions` (batched), `GET /progress`, `GET /content/manifest`, `GET /content/levels/:id` |
| Gyms | `POST /gyms/join`, `DELETE /gyms/membership`, `GET /gyms/mine`, `GET /crews/:gymId/board` |
| Payments | `GET /entitlements`, `POST /webhooks/revenuecat`, `POST /webhooks/razorpay` |
| Gym admin | `POST /admin/gyms`, `POST /admin/gyms/:id/codes`, `GET /admin/gyms/:id/poster`, `POST /admin/gyms/:id/quests`, `GET /admin/gyms/:id/report`, `POST /admin/content/levels` |
| Trainers | `GET /trainer/:gymId?key=…` (web page), `POST /trainer/:gymId/quests?key=…` |
