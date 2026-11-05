# Progress

## Current phase: 0 → 1 (code complete for Phase 0 and the Phase 1 MVP; field gates pending)

### Done
- **motion_core**: quality gate, One Euro smoothing, guided calibration with
  drift check, squat/lean/raise-arms state machines (hysteresis, confirm frames,
  cooldowns, rejection reasons), tracking-pause debouncing, landmark recording
  format, replay accuracy report. 42 tests; the accuracy gate (≥ 90 % per move,
  < 1 false trigger/min) runs on every commit.
- **game_director**: level loader with invariants, deterministic director,
  pacer, run rules engine (hearts, lanes, checkpoint, forgiveness), bot
  simulator. 36 tests incl. Forest Escape finishable at every difficulty ±
  low-impact, and tracking dropouts never costing hearts.
- **content**: Forest Escape JSON + JSON Schema, validated in CI and by the server.
- **native/pose_bridge**: Kotlin CameraX + MediaPipe Pose Landmarker plugin.
- **app**: full Phase 1 flow (onboarding, 18+, readiness, sign-in, setup,
  calibration, tutorial, Daily Quest with warm-up/cool-down, results with
  effort rating and pain report, offline queue, settings with consent/export/
  delete, Gym Crew, debug screen, landmark recorder). 12 tests.
- **server**: identity, progress, gyms (incl. Phase 2 codes, QR poster, crew
  board, trainer page, Monday WhatsApp report), billing (Phase 3 webhooks and
  entitlements), content. 41 integration tests on real PostgreSQL + Redis.
- **CI**: GitHub Actions for all of the above plus a debug APK and size budget;
  runs on `main`, development branches and PRs.
- **Production hardening (server)**: security headers, CORS allow-list, global
  Redis-backed rate limit, `/livez` + `/healthz` readiness, `MIGRATE_ON_BOOT`,
  privacy policy and terms pages, QR `/join` page, Razorpay gym payment links
  (prices + 18 % GST). 46 server tests.
- **Production hardening (app)**: release signing from `key.properties`/CI
  secrets, R8 + resource shrinking with MediaPipe keep rules, QR deep link
  `motionquest://join?code=…` kept through onboarding, all player screens in
  Hindi and Gujarati. 14 app tests.
- **Launch checklist**: [launch-checklist.md](launch-checklist.md).

### Not verified yet (needs real phones / people)
- Synthetic landmark corpus only: record 5+ consenting people (heights,
  kurta/saree/track pants, tube and evening light) with the recorder and add
  the files to `packages/motion_core/test/recordings/`.
- On-device fps, inference time and movement-to-action latency (< 150 ms)
  on budget, mid and upper-mid phones — read them on the debug screen.
- The native bridge and APK are compiled only in CI (the development
  container cannot reach the Android SDK host).
- Playtests (5–10 people), Play closed testing track, crash-free rate.

### Next
1. Build the APK in CI, install on three phone tiers, run the debug screen.
2. Field recordings → tune thresholds only while the replay gate passes.
3. Real art and voice recordings (Hindi/Gujarati voice artist) to replace
   procedural placeholders before public launch.
4. Phase 2 remaining: gym branding assets upload, pilot onboarding of 5 gyms,
   WhatsApp BSP account + template approval.
5. Phase 3 remaining: RevenueCat SDK + paywall rules in the app (after the third
   session or a locked world, never mid-run), Google sign-in and Crashlytics in
   the app (need your Firebase project), World 2, Garba Quest, highlight clips,
   referrals.

## How to verify
```bash
(cd packages/motion_core && dart test)        # accuracy report printed at the end
(cd packages/game_director && dart test)
(cd app && flutter test)
(cd server && npm test)                       # needs Postgres + Redis (docker compose up postgres redis)
(cd tools/recorder && dart run bin/replay.dart <recordings>)
```
On a phone: Settings → Developer → Tracking debug screen shows the skeleton,
recogniser states, fps, inference and capture→event latency.
