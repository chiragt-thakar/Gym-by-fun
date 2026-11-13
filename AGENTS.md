# AGENTS.md — permanent rules for coding agents

Read this file and `docs/progress.md` before doing anything.

## Product in one line
Joynetic: Android-first movement games where the phone's front camera is the
controller and the player's body is the input (an adventure runner and an
arcade of short games). Adults 18+, India first. A game for general fitness —
never a medical product; no medical or weight-loss claims.

The app was called MotionQuest. Identifiers that would break installs, tokens
or links still carry that name on purpose (Android application id and Kotlin
package, platform channel names, the `motionquest://` link scheme, JWT issuer,
job queue, database names, domains). Do not rename them casually.

## Non-negotiable rules
1. Real on-device pose estimation drives the game. No fake sensor events outside test code
   and the developer-only simulated input (`--dart-define=JOYNETIC_INPUT=sim|recorded`),
   which a release build can never construct.
2. Video never leaves the device. Never store or upload camera frames.
3. Process only the latest camera frame. Drop frames; never build a queue.
4. Camera frames stay native. Only landmarks (33 points per body, visibility, timestamp) cross into Dart.
5. A tracking failure never costs the player lives or progress; the game slows down and explains why.
6. A recognised move does nothing on its own; outcomes depend on game state.
7. Level content lives in JSON configs validated by JSON Schema, never hardcoded in Flame components.
8. The workout director is deterministic and config-driven. No cloud LLM in gameplay.
9. Low-impact by default: no jumps unless the player turns them on.
10. Original or properly licensed assets only. Copy nothing from other games.
11. No in-app links or nudges toward payment outside Google Play.

## Layout
| Path | What |
|---|---|
| `app/` | Flutter app: shell (Riverpod, go_router) + Flame game |
| `packages/motion_core/` | Pure Dart tracking engine: body tracker, calibration, drift correction, plug-in detectors (docs/tracking.md) |
| `packages/game_director/` | Pure Dart: level loader, pacing rules, simulator |
| `native/pose_bridge/` | Kotlin Flutter plugin: CameraX + MediaPipe Pose Landmarker |
| `server/` | TypeScript Fastify modular monolith (identity, progress, gyms, billing, content, reports, pairing) |
| `content/levels/` | Level JSON + `content/schema/level.schema.json` |
| `tools/recorder/` | Replay / accuracy-report CLI for landmark recordings |
| `docs/` | architecture, progress, security, game-design, tracking, design |

## Working rules
- Inspect only the files relevant to the task before planning. Modify existing files; don't recreate them.
- No speculative abstractions.
- Tests first for motion_core. Never change a recogniser threshold or a filter constant unless the
  recorded-data tests still pass.
- A game consumes `MotionInput` (events, signals, tracking state). It never reads landmarks, never
  runs its own quality gate or smoother, and adds gestures through `DetectorRegistry`.
- Play continues on any frame whose torso is tracked. A detector checks the landmarks it reads.
- UI uses the `Jn` tokens and shared components (docs/design.md): one volt action per screen,
  aqua only for tracking / success / privacy.
- Stable decisions → `docs/architecture.md`; security controls → `docs/security.md`;
  game rules and thresholds → `docs/game-design.md`; tracking algorithms → `docs/tracking.md`;
  design system and screen map → `docs/design.md`.
- Each task ends with: lint clean, tests passing, `docs/progress.md` updated, a short summary of
  what changed and how to verify it.

## Commands
```bash
# Dart packages
(cd packages/motion_core && dart pub get && dart analyze && dart test)
(cd packages/game_director && dart pub get && dart analyze && dart test)
# Flutter app
(cd app && flutter pub get && flutter analyze && flutter test)
# Server
(cd server && npm ci && npm run lint && npm run typecheck && npm test)
# Content validation
(cd server && npm run content:validate)
# The app without a camera (developer builds only)
(cd app && flutter run --dart-define=JOYNETIC_INPUT=sim)
```
