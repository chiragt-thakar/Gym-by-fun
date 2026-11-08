# Progress

## Gameplay, characters and body guide - 2026-11-09
- Added authored scene identities across all 18 stages: forest, raft-based
  river crossings, ruins, desert, neon rooftops, mountain bridges and festival
  streets. Added config-selected rain/fireflies/sand/stars/snow/petals, a
  destination charge ring and an earned-progress firefly companion. These are
  variants of the existing runner, not seven separate game engines.
- Added optional missions (lights, gates, clear path) in game_director. Targets
  use the actual difficulty's planned encounters; tracking forgiveness protects
  the denominator, checkpoint replays cannot count an encounter twice, and raw
  moves never earn progress. A completed non-tutorial mission earns a persistent
  cosmetic star on the world map. No stage unlock or heart depends on it.
- Settings -> Your explorer offers Kavi the fox, Neela the otter and Tara the
  starbot, using the same original vector art as gameplay. Added animated bent
  limbs, capes/scarves, boots and smoother recognised duck/reach/lane responses.
  Character choices have identical timing, scoring and recognition rules.
- Body guide: outlined, confidence-coloured joints over the native mirror;
  a filled landmark-only body avatar when the mirror is off. Unseen joints are
  omitted; camera pixels remain native. The guide stays under the header during
  play. Improved standing target and short localised action/segment cues, with
  full authored hints kept on the voice path. Reduced motion stops decoration.
- Fixed small-screen layout issues exposed by the expanded tests: long settings
  section titles wrap, warm-up/cool-down can scroll, and mission/guide overlays
  use header space rather than obscuring the explorer. Added EN/HI/GU text.
- Both canonical and bundled levels now carry validated gameplay metadata at
  content version 3. Added server/Dart checks for a beginner mission opportunity.
  No motion recogniser thresholds or native camera pipeline were changed.
- Verification: 200 app tests, 353 director tests, 77 motion tests (synthetic
  replay gate), and 73 server integration tests passed. App/Dart analysis and
  server lint/typecheck clean; all 18 levels validated. Native debug APK built
  successfully. Backend tests used isolated temporary PostgreSQL/Redis instances,
  which were stopped and removed afterward.
- Rendered and visually checked fixture previews: [river](screenshots/gameplay-river.png),
  [neon](screenshots/gameplay-neon.png), [mountain](screenshots/gameplay-mountain.png),
  [body guide](screenshots/gameplay-body-guide.png). No camera image was captured.
  Physical movement feel, native camera alignment and on-device frame rate still
  require a consenting person in front of the camera.
- Installed the updated APK on the authorized Vivo V2348 with `adb install -r`
  (Success), retaining application data and the existing granted camera
  permission. Launching MainActivity returned Status ok and the new app process
  remains alive, with no process-scoped AndroidRuntime/flutter error logs.
  The device keyguard is currently showing, so the user must unlock the phone
  to interact with it; no device authentication was bypassed. No camera image
  or screen capture was taken. Select an explorer in Settings; switch the
  camera mirror off to use the landmark-only body avatar.

## Installed and launched on phone - 2026-11-09
- Updated MotionQuest on the user's authorized Vivo V2348 (Android API 36)
  using `adb install -r` and the newly built debug APK. Installation returned
  Success; existing application data was retained.
- Granted `android.permission.CAMERA` through the authorized ADB connection;
  package inspection confirms `granted=true`.
- Launched `app.motionquest/.MainActivity` with `am start -W`: Status ok;
  Android confirms it as the resumed foreground activity and the app process
  remains running. No camera frames or screenshots were captured.
- Operational installation only; application source is unchanged from the
  validated build above. Physical movement accuracy, latency and battery use
  still require an actual play session.

## Adventure experience implementation - 2026-11-09
- Replaced the oversized daily button/empty server-stat header with an original
  illustrated next-adventure card, real total-time estimate, local save/sync
  status, recent activity calendar and counts, cosmetic keepsake collection,
  and collapsing chapter maps. Added one-run **Gentle today**: existing
  low-impact recogniser profile + beginner director + assist; preferences stay
  unchanged.
- Added optional typed/schema-validated journey metadata to all 18 canonical
  and bundled levels; incremented their immutable content versions. Original
  forest/desert/neon/mountain cover art, authored completion scenes and unique
  keepsakes give the journey continuity without changing encounter layouts.
- Gameplay: contextual clear/duck/dodge/gate feedback, existing flow counter,
  reduced-motion-aware success particles, original fox-hood/scarf detail, and
  a two-row HUD for small phones. No recogniser thresholds changed.
- Hands-free foreground pause/checkpoint confirmation: neutral -> recognised
  arms held 1.2 s -> lower arms -> 3 s fresh, good-frame countdown. Paused
  gameplay ignores menu input and menu moves are not workout telemetry.
  Background stops the camera; foreground never starts gameplay by itself.
  Native stop no longer waits behind Dart stream cancellation. Camera re-entry
  failures can Retry without losing the paused run/checkpoint. Also fixed Voice
  provider-ref access during disposal and inherited asset reads in initState.
- Account/storage fixes: owner-tagged queue, sign-out cleanup with unsynced-run
  warning, account-switch progress/calibration isolation, in-flight token-change
  guards, per-record validation isolation, preserved rejected/corrupt files,
  honest result save errors/Retry and immediate local effort-rating updates.
  Results now capture actual assist/max hearts and exclude manual pause and
  cool-down from uploaded run duration.
- Completed translated settings labels and new player text in English, Hindi
  and Gujarati; native-speaker review remains required. Research inputs,
  product decisions, menu rules and unproven retention hypotheses are in
  [game-design.md](game-design.md); controls in [security.md](security.md).
- Widget previews: [home](screenshots/next-home.png),
  [chapter map](screenshots/next-map.png), [results](screenshots/next-results.png).
  These use test fixture activity, not camera captures or real player results.
- Validation: Flutter analysis clean; 198 app tests, 349 director tests and 77
  motion tests passed, including the synthetic replay accuracy gate. Server
  lint/typecheck clean, all 73 integration tests passed on isolated ephemeral
  PostgreSQL/Redis containers, and all 18 content files validated. Test
  containers were removed afterward. Previews were rendered and inspected.
- The final environment check found the configured Android SDK at the
  non-default `C:\Android\Sdk` path; the earlier default-path check was
  insufficient. No phone is attached (`adb devices` is empty), so native preview
  alignment, on-phone frame rate, battery use and competitive retention remain
  unverified. Existing release/field gates still apply.
- Local Android build passed: `cd app && flutter build apk --debug --no-pub`
  compiled the app and native pose plugin. Installable test artifact:
  `app/build/app/outputs/flutter-apk/app-debug.apk` (debug build, not a Play
  release). No APK was installed on a device in this session.

## UX assessment - 2026-11-09
- Reviewed the onboarding, setup/calibration, home, quest, results, offline
  queue, account settings, stage selection, renderer and saved screenshots.
  This was a source/screenshot review, not an Android playtest; gameplay was
  not changed.
- Confirmed priorities: isolate queued runs and coach history between accounts;
  preserve valid sessions when one upload is rejected; enforce stage access
  inside QuestScreen; replace tap-dependent resume/checkpoint decisions with
  deliberate, state-specific hands-free choices and a framing countdown.
- UX opportunities: show total quest time (including the current 75 s warm-up
  and 60 s cool-down); explain local/sync status; show offline progress instead
  of empty server-only stats; strengthen movement feedback and distinct world
  missions; finish translation of settings labels and error states.
- Verification: all 18 level JSON files passed `npm.cmd run content:validate`;
  `flutter analyze --no-pub` found no issues; all 143 app tests passed with
  `flutter test --no-pub --reporter compact`. Flutter checks required access
  to the SDK cache outside the restricted workspace. Real-phone tracking,
  distance readability and latency remain unverified in this review.

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
- Native bridge and debug APK now also compile locally (2026-11-09); native
  preview, camera behaviour and performance on physical phones remain pending.
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
- Two new free World 1 stages: `w1-firefly-trail` (1-4, gentle reach-heavy replay, 180 s, 67 encounters) and `w1-garba-quest-event` (1-5, Navratri taali rhythm event, 180 s, 74 encounters, neon theme). Garba sits in World 1 until world 0 / event windows exist in the schema. Existing encounter types only; no type more than 3 in a row; breathers orbs only. World 2 now unlocks after Garba Quest. Benefit sentences reuse already-translated ones.
- Render perf pass: ForestPainter allocation-free per frame (cached per-theme paints, reused paths, cached sky shader, binary-search visible window), HUD notifier only on change (progress quantised 1/500), lazy home world map, cached BodyMap/backdrop paints; `app/test/perf_test.dart`. Assets 223.7 KB (levels 82.7 KB, audio 141 KB); cues left at 22.05 kHz mono. See docs/performance.md.
- Two new Premium bridge stages: `w2-oasis-caravan` (2-3, desert, 180 s, 66 encounters) and `w3-neon-night-market` (3-3, neon, 180 s, 66 encounters). Existing encounter types only (laneBlock ≤ 2 lanes, orbs 1 lane), S3 segments, checkpoint 150 s, surprise gates ~46 s and ~134 s ("almost there"), breathers orbs only, no type more than 3 in a row at any difficulty. Benefits reuse translated sentences. World 3 now unlocks after Oasis Caravan; World 4 after Neon Night Market. Verify: `cd server && npm run content:validate`, `cd packages/game_director && dart test`, `cd app && flutter test`.
- Session 3 final: 18 levels / 4 worlds (World 1: 6 stages incl. Garba Quest + Monsoon Meadow; Worlds 2–4: 4 each); play-style warning multiplier wired; small-screen QA (72 cases); server ops + reports tests; docs: api.md, deploy.md, play-store-listing.md, player-guide.md. Tests: motion_core 57, game_director 346, server 64, app 134. Next: the open Round 3 items in docs/review.md, then the roadmap priority list in docs/stages-roadmap.md.

## Tracking & framing UX fix (hands-free setup, frame finder)
Player feedback: (1) calibration needed a tap while standing 2 m away;
(2) the frame looked small and tracking felt fiddly and irritating during
calibration; (3) in game an out-of-frame warning showed no picture, so the
player could not tell how to get back in.
- **Hands-free setup:** after 1.5 s in a good frame a spoken 3 s countdown
  starts and calibration opens by itself; the button is only a shortcut.
- **Calibration:** spoken framing hints with a direction; a 400 ms display
  debounce (no flicker); a fixed layout (nothing jumps); an easier squat
  return (half the minimum depth); a step not finished after 20 s in frame
  uses a gentle default (never stuck).
- **Tracking quality:** 480×640 analysis on every tier (budget phones read
  "too far" at 2–2.5 m before); Full model on upper-mid phones (GPU,
  falls back to Lite); one 3:4 viewport so the outline is drawn at the
  camera's real shape; smoothed skeleton display.
- **See yourself:** an opt-out camera mirror (native `PreviewView`, no pixels
  in Dart, `FLAG_SECURE`) in setup, calibration and the game. New `FrameView`:
  a body-shaped target, red cut edges, amber near edges and a direction arrow.
- **In game:** a mirror picture-in-picture that grows into a frame finder
  when tracking pauses; the screen edge glows when the player drifts toward
  leaving; the voice says which way to move.
- motion_core: `Framing`, `FramingFilter`, `Calibrator.skip()`,
  `stepActiveMs`. Tests: motion_core 77 (replay gate passes), game_director
  349, app 143 (new `framing_ui_test.dart`: setup auto-advance, directional
  hint, calibration auto-default, translations).
- **Verify on a phone (CI APK):** mirror orientation and mirroring match the
  outline on three tiers; the debug screen shows `full` on upper-mid; fps
  with the mirror on; the brief preview re-attach when the in-game PiP first
  appears does not cause a visible pause; screenshots are blocked while the
  mirror shows. Kotlin is compiled only in CI.
