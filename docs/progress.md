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

- Stages: four new original levels (River Crossing, Guardian Grove, Desert
  Dunes, Sandstorm Temple) in `content/levels/`; stage catalogue with
  unlocking (`app/lib/game/stages.dart`, `Settings.completedLevels`); home
  world map lists worlds and stages; `/quest?level=<id>`; desert theme for
  the procedural painter.
- Coach Kavi, the on-device AI coach: rule-based, deterministic `Coach` in
  `packages/game_director/lib/src/coach.dart` (difficulty/assist suggestion
  with reason, up to 2 form tips from rejection reasons, recap, next goal,
  weekly balance note; 26 tests). App keeps the last 20 run summaries (counts
  only) in SharedPreferences (`app/lib/services/coach_service.dart`), shows a
  Kavi card on results with a "Try <level>" button, speaks the recap; text in
  en/hi/gu in `app/lib/l10n/coach_strings.dart`. Pose service now counts
  rejections by reason. Rules in `docs/game-design.md`.

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

## Performance pass (budget phones)
- motion_core hot path is allocation-light, and a micro-benchmark gate was
  added (< 0.3 ms/frame over 3000 frames).
- `PerfStats` uses ring buffers. `Voice` failures are fully contained.
- The native bridge frees the upright bitmap in `onResult` and on the error path.
- Release builds are ARM-only, and CI builds split-per-ABI release APKs with the
  < 150 MB check.
- See `docs/performance.md` for the budgets and how to measure them on a device.

## Pre-launch review fixes, Bucket A (app + native)
- Frame watchdog in `MotionSession` (rule 5), stream errors pause tracking.
- Quest screen: lifecycle pause, pause button + back → pause overlay
  (Resume / Quit unsaved), camera only during the run, mounted guards,
  start errors shown, checkpoint continue, tutorialDone only on completion.
- Native: `start` always answered once; stop/start race and permission
  re-entrancy fixed (Kotlin not compiled in this environment; build on CI).
- Telemetry: unmeasured per-move fields no longer sent from `moveStats`.

## Pre-launch review fixes, Bucket B (server + packages)
- Billing webhooks: marker + apply in one transaction (`processWebhookOnce`);
  a failed apply is retried successfully; unhandled Razorpay types not recorded.
- `DELETE /me` immediately deletes pain reports, devices, calibrations,
  sessions (+ moves), progress, crew scores; keeps entitlements (anonymised
  billing linkage), withdrawn consents, left memberships until hard delete.
- `/me/export` adds crew scores, sign-in session metadata (no hashes),
  billing linkage; a test fails if a new `user_id` table is not exported.
- `RunEngine`: checkpoint restart resets all transient state and is
  once-per-loss; forgiveness adds a 300 ms pre-cue margin and a wall-clock
  reaction-time rule.

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

## Session 3 (multi-agent)
- 9 stages across 4 playable worlds (Forest, Desert, Neon City, Mountain) with themes and unlocking.
- Coach Kavi: offline rule-based coach (difficulty advice, form tips, recap, goals) in en/hi/gu.
- Forest Lantern UI identity; performance pass (allocation-light motion core, ring buffers, ARM-only split release APKs, bitmap safety).
- Production review (docs/review.md): all 16 findings fixed (watchdog, background pause, pause/quit, checkpoint continue, atomic webhooks, full deletion/export, native start/stop safety).
- Stage info sheet: body map (player-chosen female/male/neutral), trained regions, benefits with guideline sources, disclaimer; Free/Premium badges (nothing locked while PAYMENTS is off).
- docs/stages-roadmap.md: full spec for all remaining worlds, events, moves, bosses, age bands, Free vs Premium, body targets and anti-boredom rules.
- First successful Android APK build in CI (run 11).
- Open: 27 benefit sentences still English-only in hi/gu; native-speaker review of translations; budget-tier body-size threshold to tune with field data.
