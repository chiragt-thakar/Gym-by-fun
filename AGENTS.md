# AGENTS.md — permanent rules for coding agents

Read this file and `docs/progress.md` before doing anything.

## Product in one line
MotionQuest: an Android-first 2.5D adventure runner where the phone's front camera
is the controller. Adults 18+, India first. A game for general fitness — never a
medical product; no medical or weight-loss claims.

## Non-negotiable rules
1. Real on-device pose estimation drives the game. No fake sensor events outside test code.
2. Video never leaves the device. Never store or upload camera frames.
3. Process only the latest camera frame. Drop frames; never build a queue.
4. Camera frames stay native. Only landmarks (33 points, visibility, timestamp) cross into Dart.
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
| `packages/motion_core/` | Pure Dart: quality gate, One Euro filter, calibration, recognisers |
| `packages/game_director/` | Pure Dart: level loader, pacing rules, simulator |
| `native/pose_bridge/` | Kotlin Flutter plugin: CameraX + MediaPipe Pose Landmarker |
| `server/` | TypeScript Fastify modular monolith (identity, progress, gyms, billing, content, reports) |
| `content/levels/` | Level JSON + `content/schema/level.schema.json` |
| `tools/recorder/` | Replay / accuracy-report CLI for landmark recordings |
| `docs/` | architecture, progress, security, game-design |

## Working rules
- Inspect only the files relevant to the task before planning. Modify existing files; don't recreate them.
- No speculative abstractions.
- Tests first for motion_core. Never change a recogniser threshold unless the recorded-data tests still pass.
- Stable decisions → `docs/architecture.md`; security controls → `docs/security.md`;
  game rules and thresholds → `docs/game-design.md`.
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
```
