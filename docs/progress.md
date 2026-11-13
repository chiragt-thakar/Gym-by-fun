# Progress

## Joynetic: tracking engine v2, pairing backend and redesign - 2026-11-13

**Not built or run.** This machine has no Flutter, Dart, Gradle or Node, so
every change below was written and re-read by hand. Nothing has been compiled,
analysed or tested yet. Run the commands in AGENTS.md first; expect a small
number of compile or lint fixes.

**Renamed to Joynetic** in everything a player sees, in class names and in the
Dart package (`package:joynetic/…`). Deliberately unchanged, because changing
them breaks installs, tokens or links: the Android application id and Kotlin
package (`app.motionquest`), platform channel names, the `motionquest://join`
link scheme, the JWT issuer, the job queue name, database names and the
`motionquest.app` domains. Landmark recordings are written as
`joynetic.landmarks`; the old format name still loads.

**Tracking engine (`packages/motion_core`, see [tracking.md](tracking.md)).**
- Root cause of "tracking drops when I move a little": the quality gate paused
  the game when any one of nine landmarks dipped or neared the image edge.
  Now only the torso is required; everything else is `degraded` and play
  continues, with each detector checking the landmarks it needs.
- New `BodyTracker` front end shared by every screen: `SubjectLock` (primary
  player), `FacingCanonicaliser` (left is always the player's left), graded
  `QualityGate`, `LandmarkStabiliser` (One Euro + confidence gate + ≤ 250 ms
  prediction for all 33 landmarks), `TrackingStateMachine` (tracking / degraded
  / lost / recovering, each transition with its own dwell).
- Calibration v2: robust statistics (medians, percentiles, spike-dropping rep
  bottoms), a body model (limb proportions, camera distance and roll), a
  quality score with named issues, live condition guidance, one automatic
  retry for a poor result, quick re-calibration, versioned JSON (v1 still
  loads), per-player profiles in the app.
- `DriftCorrector`: the profile is re-scaled / re-centred passively when the
  player ends up nearer, further or elsewhere; inside a dead band nothing
  changes.
- Squat works with the feet out of view (thigh-span fallback). Raise-arms no
  longer believes a wrist that has left the image.
- Plug-in `DetectorRegistry` with typed configs; new detectors `jump`, `punch`,
  `twist`, `kneeLift` (all opt-in) and one `GestureEvent` type; `MotionSignals`
  and the `MotionInput` interface for games.
- Tests added (not run): robust statistics, stabiliser, state machine, subject
  lock, body tracker / partial visibility, calibration v2, drift, detectors and
  signals. Existing tests were kept; one app test (frame watchdog) was updated
  because resuming after a stall now waits for a steady spell.

**Native bridge.** Optional multi-person output (`maxPoses`), MediaPipe presence
and tracking confidence 0.5 → 0.4, CameraX camera-state errors reported to Dart,
typed frame list passed through without copying.

**App.** One `BodyTracker` per camera session; screens consume `TrackedFrame`s
instead of running their own gate and smoother. Stalled camera: moves end, the
game holds, the camera is restarted (3 attempts) and then a clear "camera
stopped" state with Retry. Falls back to the light model once if the accurate
one cannot hold 15 fps. Diagnostics overlay (Settings → Tracking). Developer
input without a camera: `--dart-define=JOYNETIC_INPUT=sim` or `=recorded`.

**Backend.** New `pairing` module (`/v1/pair`): single-use codes, hashed
per-device tokens, strict message schemas (events, signals, tracking state, game
control — nothing that could carry landmarks or video), per-direction sequence
numbers with a bounded replay log for reconnection, Redis pub/sub fan-out.
Transport is POST + Server-Sent Events: no new dependency (a WebSocket adapter
needs `@fastify/websocket`, which could not be installed here). The app has no
pairing client yet. Calibration backup accepts v2 profiles (40 keys).

**Redesign (see [design.md](design.md)).** New "Ink & Volt" tokens (`Jn`), with
the old token names aliased so every screen picks them up; pill buttons, new
backdrop, brand mark, trust panel, `StateView` for errors. Rewritten: welcome,
the camera-permission explainer, calibration, Settings → Tracking, error and
camera-stopped states. Restyled through tokens and shared components: home,
games, progress, profile, results, get-ready, pause, HUD. Their layouts were
not rewritten.

**What to test first**
1. `dart analyze && dart test` in `packages/motion_core`, then
   `packages/game_director`; `flutter analyze && flutter test` in `app`;
   `npm run lint && npm run typecheck && npm test` in `server`.
2. The replay accuracy gate (`replay_accuracy_test.dart`) — it must still pass
   unchanged.
3. On a phone, with Settings → Tracking → Diagnostics overlay on: stand so your
   feet are cut off and squat; lean until a hand leaves the frame; step out and
   back in; walk closer mid-game; have someone walk behind you.
4. Left / right: raise your right hand and check the right-hand side responds
   in an arcade game, and whether diagnostics shows "L/R swapped".
5. Calibration in a dim room and with the feet hidden (expect the fix-and-retry
   card).
6. Frame rate with "Other people in the room" on.

**Known risks**
- Unbuilt code (above).
- The MediaPipe confidence change and `maxPoses` 2 are untested on device.
- Left/right canonicalisation is derived from how pose models label a mirrored
  image; if arcade sides were correct before, confirm they still are.
- One Euro constants were kept (the accuracy gate was tuned on them); a
  lower-lag tuning is described in tracking.md and needs the gate plus a device.
- New English strings have no Hindi / Gujarati yet.
- Drift correction re-centres a player who stands more than a torso length off
  their spot for 2.5 s; in side-step lane mode a very large held step would be
  re-centred.

## App v2: new shell, game library and six new games - 2026-11-09
**Shell and UX (owner request: production-grade look, working back button,
separate pages, a game list with previews).**
- New bottom navigation: **Home · Games · Progress · Profile**
  (`StatefulShellRoute`). Android back now pops pages, sends other tabs to
  Home, and on Home asks for a second press before leaving. Deep pages opened
  directly go Home on back instead of closing the app (`BackToHome`).
- Home was split up: greeting, setup reminder, "Continue your adventure",
  Today's pick (same game for everyone each IST day), a 7-day strip with moves
  and minutes from all games, and an "Explore games" carousel. The runner's
  world map moved to its own game page.
- **Games** tab: genre filters and large cards with original preview art.
  **Game page**: hero art, a four-scene preview gallery, how-to steps, movement
  chips, comfort note, level list with locks/stars/badges, options (difficulty,
  level, assist, no-squat welding, party players with an 18+ confirmation), a
  Craftguard trophy shelf, a LUMEN habitat view and a sticky Play bar.
- **Progress** tab (week, 14 days, per-game records, collections) and
  **Profile** tab (explorer, quick settings, body setup, Gym Crew, developer
  tools in dev builds). Design tokens (`Space`, `Txt`) and one UI kit
  (`widgets/ui_kit.dart`); refreshed buttons, cards, chips and type scale.
- New strings in Hindi and Gujarati (`l10n/tr_v2.dart`; long game descriptions
  still fall back to English). Native-speaker review remains required.

**Games (from new-games-plan, new-games-plan-2 and the LUMEN research).**
All six are playable with real on-device pose input, share one play screen and
keep the non-negotiable rules (landmarks only, tracking loss forgiven, rule 6,
JSON content, deterministic engines, no jumps). Rules and numbers are in
[game-design.md](game-design.md#arcade-games-v2-2026-11-09).
- **Craftguard Duels**: 6 original guardians (Baoli Warden, Patang Twins, Brass
  Mayur, Lattoo Titan, Megh Drummer, Night Mail Colossus), 4-count telegraphs,
  Poise → stagger → side pads → Charge, Sparks with Regroup, calm seals.
- **Taal Toofan**: 5 original charted songs, cards land on body zones,
  Light/Groove/Toofan levels, Josh meter → Toofan Time, a band that builds
  from synthesised percussion layers.
- **Mirror Mela**: Bubble Bazaar, Lantern Lane, Marigold Orbit, Baadal's Storm;
  left/right hand shapes, cloud sweeps to duck or lean away from, Mela Rush.
- **Tapeball Tamasha**: Evening Nets, daily Super Over, Three-Over Chase; new
  swing recogniser; leave wides with arms up, block with a guard; dead balls.
- **Pataka Pose**: 18 poses, 4 shows incl. Pass the Pataka (2–6 players);
  hover when the shape cannot be seen; adaptive tolerance.
- **LUMEN: Orbital Architect**: 2 habitats / 7 boards (incl. the worked board
  from the research doc); reach-select, lean-turn, bend-weld (or no-squat);
  restored modules persist.

**Deliberate changes from the written plans.** Tapeball's ball arrives beside
the player in the image plane (bowler on the left) because a ball from the far
end would come from *behind* a player facing the camera. Rang Wall is served by
Pataka Pose (shared pose matcher) instead of a second pose mode. Taal uses
synthesised percussion layers instead of commissioned stems. Not built yet:
landmark highlight clips, two-player Jodi/Duo, Beat Sync and capture
timestamps (M0), festival events, leaderboards/Crew Cup, and server upload of
arcade sessions (kept on the phone for now).

**Verification.** motion_core 101 tests (24 new: body pose, pose matcher,
swing), game_director 385 (32 new: every engine + real-content invariants:
solvable boards, beatable guardians, danceable songs), app 304 (97 new incl.
Android back behaviour, play gate, camera release, and small-screen checks of
every new screen in EN/HI/GU at 1.3× text). App/Dart analysis clean, server
lint/typecheck clean, 18 levels + 6 arcade files validated. Visual previews:
`docs/screenshots/v2-*.png` (illustrations, no camera images).
**Not verified:** real-phone feel, swing/guard/zone reliability with real
bodies and clothing, audio timing on Bluetooth, frame rate on budget phones.
Thresholds for the new gestures are first estimates and need recorded data.
- Dev APK (everything unlocked): `flutter build apk --debug
  --dart-define=DEV_UNLOCK_ALL=true` → `app/build/app/outputs/flutter-apk/app-debug.apk`.

## New game research and explore-first proposal - 2026-11-09
- Added [LUMEN: Orbital Architect research](lumen-orbital-architect-research.md):
  a separate body-controlled orbital restoration puzzle, with an exact worked
  board, state-specific controls, persistent habitat rewards, comfort/accessibility
  limits, proposed content contract and prototype/release acceptance criteria.
- Researched official WHO/NHS guidance, movement-break trials (including a null
  finding), shoulder-fatigue research, exercise motivation and a six-month exergame
  trial. The proposal separates evidence from design hypotheses and makes no
  fitness, medical, weight-loss or retention guarantees for the unbuilt game.
  Existing future-game proposal documents were not used as creative inputs.
- Traced the current router/setup/calibration/tutorial continuation problem and
  specified explore-first navigation: retain the adult eligibility gate, defer
  camera preparation until Play, preserve selected game/stage/pace, safely cancel
  camera sessions and retain progression/entitlement checks. This is a proposal;
  the current app still requires its existing onboarding sequence.
- No application, native, content, dependency or device changes. Both the new
  game and onboarding implementation await the owner's explicit instruction to
  start. Stable architecture/game rules remain unchanged pending that decision.
- Verification: current app analysis clean; all 200 Flutter tests passed.
  Documentation whitespace and the illustrative JSON/worked puzzle were checked.
  These baseline checks do not validate the proposed controls or body benefits;
  physical-control/comfort testing requires consenting human participants.

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
- Updated Joynetic on the user's authorized Vivo V2348 (Android API 36)
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

## Explore first, calibrate at play
Player request: let people look around the app before calibrating; ask for
calibration only when they tap play.
- **Onboarding:** only 18+ and readiness are required (`nextOnboardingStep`).
  The setup intro gets "Skip for now and explore" (first time only, never on
  the way to a run). The tutorial is no longer forced; it still follows
  calibration when no run is waiting.
- **Play gate:** `playGate` in `app/lib/app/router.dart` sends any `/quest` or
  `/tutorial` without a calibration to the new `/get-ready` page with
  `?next=<the run>`. Setup and calibration pass `next` along and open that
  run when done. `safeNext` accepts only in-app play routes.
- **Get-ready page** (`get_ready_screen.dart`): a three-stop trail (space ~1
  min, ticked if done → range ~30 s → the stage tapped), hands-free and
  privacy notes, "Let's set up" / "Start calibration", and "Not now, keep
  exploring". Home shows a tappable reminder card while uncalibrated.
- New strings translated to hi/gu (native-speaker review still open).
- Tests: app 207 (new `play_gate_test.dart`; onboarding/gate/`safeNext` cases
  in `app_logic_test.dart`).
- **Verify on a phone:** fresh install → age → readiness → sign-in (skip) →
  setup intro → "Skip for now and explore" → Home shows the reminder card →
  tap play → get-ready → set up → calibrate → the run starts by itself.

