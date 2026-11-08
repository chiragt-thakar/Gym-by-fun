# Architecture

## Authored gameplay variants and optional missions (2026-11-09)

`LevelGameplay` decodes scene/atmosphere enums, mission kind and a bounded target
fraction from the level JSON. `MissionTracker` lives in game_director and consumes
resolved planned encounters; it never reads the camera or generates motion.
It deduplicates plan indices across checkpoint retries and protects targets for
tracking forgiveness. Mission fields are included in `RunResult` for local result
presentation; the existing server session upload contract remains unchanged.

ForestGame forwards real motion to the existing RunEngine and exposes quantised
HUD state, including the current cue, authored segment and mission counters.
ForestPainter draws the authored scene and selected explorer. The painter is
reused, scratch paths and paints remain cached, and decorative rendering respects
reduced motion. New scene effects require no texture downloads or new dependency.

`FramePainter` reconstructs a landmark-only body avatar when the native mirror
is off, and an outlined skeleton over the mirror when it is on. It is presentation
only: it cannot modify recogniser features, thresholds, camera crop or calibration.
The native mirror remains the sole renderer of camera pixels. New local settings
are `heroLook` and `missionLevels`; unknown/old saves fall back to the fox and no
mission stars. Account changes reset mission progress with completed-stage ids.

## Adventure presentation and local activity (2026-11-09)

`LevelConfig.journey` is optional authored presentation metadata, validated by
the level JSON Schema and Dart parser. All bundled/current levels include it;
their immutable content versions were incremented. Encounters and pacing are
unchanged. `levelCatalogueProvider` loads the bundled metadata once, shared by
home, stage guide and results. `WorldVista` paints static original cover art
inside repaint boundaries. The game paints outcome-driven effects separately
and suppresses particles when reduced motion is requested.

`ReadyGate` in the app service layer confirms foreground pause/checkpoint menu
intent from the real recogniser state and fresh, good frames. It never emits
sensor events. ForestGame blocks gameplay input while manually paused, and
MotionSession excludes menu movements from workout telemetry. The camera is
always stopped on background lifecycle transitions. QuestScreen caches Voice
before disposal rather than accessing Riverpod's widget ref during unmount.
Preparation runs after the first frame so inherited asset bundles can be read
safely. Native capture stop starts concurrently with subscription cancellation,
so a slow event-channel acknowledgement cannot keep the camera running. A
camera re-entry failure offers Retry while preserving the paused engine and
checkpoint; retry still requires readiness confirmation.

The bounded coach history (20 run summaries) supplies recent move/minute totals.
A separate bounded set of 14 local activity dates preserves the weekly calendar
when many runs trim that history. Both clear on sign-out/account change and
local deletion. Completed-level ids supply persistent cosmetic keepsakes; no
second reward ledger can drift from stage completion.

Gentle today is a route-level one-run override using existing motion profiles
and director settings. Results capture the actual run's assist and heart count.
Stage access is checked inside QuestScreen before loading a playable run, as
well as at navigation entry points. Settings remain unchanged by the override.

Everything that touches video runs on the phone; the cloud stores only
results, gyms and payments.

```
 PHONE                                                     SERVER (one TypeScript service)
 ┌──────────────────────────────────────────────┐          ┌──────────────────────────────────┐
 │ native/pose_bridge (Kotlin)                  │          │ Fastify /v1                      │
 │  CameraX front cam ─▶ MediaPipe Pose (L/F)   │          │  identity  OTP, Google, tokens,  │
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
| One 3:4 portrait `ViewPort` for analysis and preview | Analysis is cropped to the shared viewport, so landmark 0..1 coordinates are exactly the preview's box; Dart draws the outline over a 3:4 `FrameView` with no mapping maths. |
| Camera mirror = native `PreviewView` platform view (`motionquest/self_view`) | Opt-out setting (on by default). CameraX `Preview` is bound only when the setting is on; the image goes camera → `PreviewView` (TextureView) → screen. Dart holds no pixels and no texture id. `PreviewView` handles rotation and front-camera mirroring on every device, which a raw texture would not. |
| Analysis 480×640 on every tier | The landmark model runs on a fixed-size crop either way; at 360×480 a player at 2–2.5 m was under the 256 px gate ("too far") on budget phones. |
| Full model on upper-mid phones, Lite elsewhere | Full is steadier at distance; it is tried on the GPU only and falls back to Lite, then to CPU Lite. The tier comes from the setup benchmark (run with Lite). |
| Framing advice + debounce in motion_core (`Framing`, `FramingFilter`) | One tested place turns a gate failure into one direction ("move to your left", "step back"); the 400 ms display debounce keeps text and voice from flickering. The engine's pause/resume timing is unchanged. |
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
