# MotionQuest

An Android-first phone game where the **front camera is the controller**. Prop
the phone up, step back 2–2.5 m, and play a 2.5D fantasy adventure runner by
moving your body: squat to duck, lean to change lane, raise your arms to grab
energy. Adults 18+, India first (English, हिंदी, ગુજરાતી).

Two ways in: **Solo Quest** for anyone, and **Gym Crew** — members of a partner
gym join with a gym code and get Premium free; the gym owner gets a Monday
WhatsApp report.

> A game for general fitness, not a medical product. Video never leaves the phone.

## Repository

| Path | What | Tests |
|---|---|---|
| [`packages/motion_core`](packages/motion_core) | Pure Dart motion pipeline: quality gate, One Euro filter, calibration, recognisers, replay accuracy report | `dart test` (incl. the ≥ 90 % accuracy gate) |
| [`packages/game_director`](packages/game_director) | Deterministic director, run rules engine, simulator | `dart test` (every level × difficulty) |
| [`native/pose_bridge`](native/pose_bridge) | Kotlin CameraX + MediaPipe Pose Landmarker plugin | on device |
| [`app`](app) | Flutter + Flame app | `flutter test` |
| [`server`](server) | TypeScript Fastify modular monolith (PostgreSQL, Redis, BullMQ) | `npm test` (real Postgres + Redis) |
| [`content`](content) | Level JSON + JSON Schema | `npm run content:validate` |
| [`tools`](tools) | Landmark replay CLI, sound-cue generator, content sync | |
| [`docs`](docs) | [architecture](docs/architecture.md) · [security](docs/security.md) · [game design](docs/game-design.md) · [progress](docs/progress.md) | |

Coding agents: read [AGENTS.md](AGENTS.md) first.

## Quick start

```bash
# Motion + director packages (needs the Flutter/Dart SDK)
(cd packages/motion_core && dart pub get && dart test)
(cd packages/game_director && dart pub get && dart test)

# Backend
docker compose up -d postgres redis
cp server/.env.example server/.env     # fill in secrets
(cd server && npm ci && npm run dev)   # http://localhost:8080/healthz
# tests: TEST_DATABASE_URL=postgres://postgres:postgres@localhost:5432/motionquest_test npm test
#        (create that database first)

# App on an Android 11+ phone
(cd app && flutter run --dart-define=API_BASE=http://<your-lan-ip>:8080)
```

The pose model (`pose_landmarker_lite.task`, Apache-2.0) is downloaded by
Gradle on the first Android build.
