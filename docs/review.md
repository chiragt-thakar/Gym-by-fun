# Pre-launch review (2026-11-05)

Harsh senior review ahead of Play Store production. No code was changed.
Findings are grouped into two fix buckets that touch disjoint files, so two
fixers can work in parallel.

- **Bucket A**: `app/**` and `native/**`
- **Bucket B**: `server/**` and `packages/**`

---

## Bucket A: app and native

### A1. Rule 5 broken when frames stop arriving (critical, motion/app)
`app/lib/services/pose_service.dart:154` (`source.frames.listen(_onFrame)`), `:162` (`_engine?.process(f)`)
Tracking loss is only detected inside `MotionEngine.process`, which runs only
when a frame arrives. If frames stop (native error, camera taken by another
app, app backgrounded and CameraX unbound on ON_STOP, the MediaPipe error
listener firing), no `TrackingPaused` is ever emitted. `engine.light` stays
green and `ForestGame.update` keeps advancing the run at full pace, so the
player loses hearts while the camera is dead.
**Fix:** add a frame watchdog in `MotionSession`, a periodic timer that emits
`TrackingPaused(noPerson)` and sets the light to red when nothing has
arrived for about 500 ms, then resumes on the next good frame.

### A2. No app-lifecycle handling: run keeps going in the background (critical, app)
`app/lib/screens/quest_screen.dart:90` (`_QuestState`, no `WidgetsBindingObserver` anywhere in `app/lib`)
Nothing reacts to `AppLifecycleState.paused`/`inactive`. CameraX stops on
the activity's ON_STOP. Meanwhile the warm-up/cool-down `Timer.periodic`
(`quest_screen.dart:392`) and TTS keep running, and on resume the run
carries on with no pause screen. With A1 this means hearts lost during a
phone call. A notification shade pull (`inactive`) does not stop the
camera or the game at all.
**Fix:** make `_QuestState` a `WidgetsBindingObserver`. On paused/inactive,
pause the engine (`game.pauseEngine()`), stop the voice and timers, and call
`session.stop()`. On resume, show a "Ready?" overlay and restart the session.

### A3. Native `start()` never answers on failure, so the loading spinner spins forever (high, native)
`native/pose_bridge/android/src/main/kotlin/app/motionquest/pose_bridge/PosePipeline.kt:60-62`, `:87-89`; `PoseBridgePlugin.kt:116`
If the model fails to load or `bindToLifecycle` throws, only `onError` runs.
That goes to the event sink, which may not even be listening yet. The
`MethodChannel.Result` passed to `p.start { ... }` is never completed, so
`await source.start()` (`pose_service.dart:153`) hangs and `QuestScreen`
stays on `_Phase.loading` with no way out.
**Fix:** pass a failure callback into `PosePipeline.start` and call
`result.error(...)` on both catch paths, exactly once.

### A4. Unhandled exceptions and stream errors in `_prepare` / session (high, app)
`app/lib/screens/quest_screen.dart:136` and `app/lib/services/pose_service.dart:153-154`
- `source.start()` can throw a `PlatformException` (`no_permission`,
  `no_activity`, `no_lifecycle`). This is not caught in `_prepare`, so the
  screen is stuck loading.
- `source.frames.listen(_onFrame)` has no `onError`. Native
  `sink.error("pose_error", ...)` (`PoseBridgePlugin.kt:113`) becomes an
  uncaught async error, which crashes the zone or goes to Crashlytics, and
  the game is never told.

**Fix:** wrap start in try/catch and set `_error`. Add `onError:` to the
listen call that emits `TrackingPaused` and logs the error.

### A5. `setState` after async gaps, and a leaked camera if the user leaves during loading (high, app)
`app/lib/screens/quest_screen.dart:137`, `:152`, `:162`
`_prepare` awaits voice init, asset load and `session.start()`, then calls
`setState` without checking `mounted`. If the user backs out while it
loads, this throws `setState() called after dispose()`. Worse, `dispose()`
already ran with `_session == null`, so the started `MotionSession` (camera +
MediaPipe) is never stopped: the camera keeps running with no UI.
`_onRunFinished` (a post-frame callback) also calls `setState` with no
`mounted` check.
**Fix:** after each await, `if (!mounted) { await session.dispose(); return; }`.
Guard `_onRunFinished` with `mounted`.

### A6. No pause/quit during a run, and Android back exits mid-run (high, UX)
`app/lib/screens/quest_screen.dart:256-330` (`_RunView`), no `PopScope` anywhere in `app/lib`
The run has no pause or quit button. Because navigation uses `context.go`,
the system back gesture closes the app or route abruptly. The session is
not saved and the work is lost silently. Warm-up and cool-down have no skip
either.
**Fix:** add a `PopScope` with a pause sheet (Resume / End run, which saves
a partial result) and a visible pause button in the HUD.

### A7. Camera and inference run for the whole 75 s warm-up (medium, app/privacy/battery)
`app/lib/screens/quest_screen.dart:136-152`
`session.start()` runs before `_Phase.warmup`. The front camera and the GPU
model stay hot through the warm-up even though nothing consumes events. The
camera-in-use indicator is on while the player is told to do arm circles.
This costs battery and heat on budget phones, and it is a privacy optics
issue.
**Fix:** start the session when `_Phase.run` begins (or a few seconds
before). Stop it on the cool-down, which `_onRunFinished` already does.

### A8. Native stop/start race binds the camera after stop (medium, native)
`native/pose_bridge/android/src/main/kotlin/app/motionquest/pose_bridge/PosePipeline.kt:64-90`, `:192-202`
`stop()` can run before the `ProcessCameraProvider` future listener fires,
for example on a fast back or a `start` right after `stop` in
`PoseBridgePlugin.start:102`. The listener then calls
`setAnalyzer(executor, ...)` on an executor that has been shut down, and
`bindToLifecycle` on a pipeline nobody references, so the camera is bound
and orphaned. `landmarker.close()` can also race in-flight `detectAsync`
results, and the `inFlight` bitmap is not recycled on stop.
**Fix:** add an `@Volatile stopped` flag. Check it in the listener before
binding and in `analyze`/`onResult`. Recycle `inFlight` in `stop()`.

### A9. Concurrent `requestPermission` leaves a Dart future hanging (low, native)
`native/pose_bridge/android/src/main/kotlin/app/motionquest/pose_bridge/PoseBridgePlugin.kt:80`
A second call overwrites `pendingPermission`, so the first `Result` is
never answered. `onDetachedFromActivity` also does not complete it.
**Fix:** if one is pending, answer the new call with an error or a shared
result. Complete any pending result with `false` on detach.

### A10. Checkpoint is a dead feature, and the tutorial is marked done even when failed (medium, game logic)
`app/lib/screens/quest_screen.dart:155-164`, `:190`; `app/lib/game/forest_game.dart:161`
The app never calls `RunEngine.restartFromCheckpoint()`. Running out of
hearts after the checkpoint just ends the run, even though the checkpoint
voice and sound promise a save. `_complete` sets `tutorialDone: true` and
`seenTypes: {...EncounterType.values}` after any run, including a tutorial
the player failed, so first-time hints are suppressed forever.
**Fix:** on `RunFinished(completed: false)` with `engine.atCheckpoint`, offer
"Continue from checkpoint". Set `tutorialDone` only when `r.completed`, and
add only the types actually encountered to `seenTypes`.

### A11. Telemetry reports fabricated values (low, app/data integrity)
`app/lib/services/pose_service.dart:183` (`'falseTriggers': 0`), `:184` (session-wide `avgLatencyMs` copied to every move)
Hard-coded or duplicated numbers go to the server as per-move accuracy
stats and would mislead threshold tuning.
**Fix:** omit fields that are not measured (send null) rather than
inventing them.

---

## Bucket B: server and packages

### B1. Webhook marked processed before it is applied, so purchases can be lost (critical, billing)
`server/src/modules/billing/routes.ts:39-43` (RevenueCat), `:58-63` (Razorpay); `server/src/modules/billing/service.ts:54-62`
`markProcessed` inserts into `billing_events` and commits before
`applyRevenueCat` / `applyGymPayment` runs. If the apply step throws (DB
blip, unknown user), the provider gets a 500 and retries. The retry then
hits the conflict and returns `duplicate`, so the entitlement or gym
licence is never granted. Razorpay also records the event before checking
`RAZORPAY_EVENTS` (`:62`), so an event type added later can never be
replayed.
**Fix:** run mark and apply in one `ctx.db.transaction()`, or set
`processed_at` only after a successful apply and treat rows without
`processed_at` as retryable.

### B2. Account deletion leaves health-adjacent and device data for the whole grace window (high, privacy/DPDP)
`server/src/modules/identity/routes.ts:224-237`
The "immediate scrub" deletes calibrations and crew_scores. It keeps
`pain_reports` (body-area pain, the most sensitive data held), `devices`
(device identifiers / push tokens), `sessions` and `session_moves` until the
nightly purge `DELETION_GRACE_DAYS` later. `docs/security.md:13` promises an
immediate scrub. Pain reports linked to a deleted account have no lawful
purpose after deletion.
**Fix:** also delete `pain_reports` and `devices` in the transaction (or
fully anonymise them). Document exactly what stays until the hard delete
in `docs/security.md`.

### B3. Data export is incomplete (high, privacy/DPDP)
`server/src/modules/identity/routes.ts:188-216`
The export claims "all the data held about you" but leaves out
`crew_scores` (deleted on account deletion, so it is clearly per-user data),
`refresh_tokens` session metadata (devices or sign-in times), and
`billing_events` / payment linkage for the user. It also returns raw
`selectAll()` rows, which may include internal columns such as hashes.
**Fix:** add `crew_scores` and a summary of active sign-in sessions, then
review each table in `migrations.ts` that has a `user_id` FK against the
export list. Add a test that fails when a new user-linked table is not
exported.

### B4. Checkpoint restart keeps stale state (medium, game_director)
`packages/game_director/lib/src/run_engine.dart:324-335`
`restartFromCheckpoint` resets hearts and the clock but not `_light`,
`_lastLostClock`, `ducking`, `armsUp`, `_lastRaiseWall`/`_lastSquatEndWall`
(wall-clock based, so they can still count inside the grace window),
`streak` or `_segment`. Two concrete effects: a stale `_lastLostClock` set
after `cp.startMs` forgives every encounter whose `warnMs` it exceeds, and
`_segment` never re-emits `SegmentStarted`/the hint. It is also not
idempotent with `_checkpointDone`, so hearts can be refilled twice.
**Fix:** reset these fields, add tests in `packages/game_director/test` for
restart and then forgiveness. This must land before A10 wires the restart
into the app.

### B5. Forgiveness depends on the level clock, so slow-down can still produce unfair hits (medium, game_director)
`packages/game_director/lib/src/run_engine.dart:237`, `:278-279`
`_lastLostClock` is stamped with the level clock. While the light is
amber, the pacer slows the clock but the player is still judged normally.
A beam that was warned during amber-to-red flicker, with green restored
just before arrival, counts as forgiven only if red happened at or after
`warnMs`. Red at `warnMs - 1` followed by a late recovery produces a hit
with almost no reaction time.
**Fix:** forgive when the player had less than N ms (wall time) of green
tracking between the cue and arrival, not only on a red sample in the
window. Cover it with simulator tests.

---

## Summary

| ID | Sev | Bucket | Area | One-liner |
|---|---|---|---|---|
| A1 | critical | A | app/motion | No frame watchdog; dead camera means hearts lost (rule 5) |
| A2 | critical | A | app | No lifecycle observer; run and timers continue in background |
| A3 | high | A | native | `start` never completes on failure; infinite spinner |
| A4 | high | A | app | Uncaught PlatformException / stream error in session start |
| A5 | high | A | app | setState after dispose; leaked camera if user leaves while loading |
| A6 | high | A | app/UX | No pause/quit; back gesture kills run unsaved |
| A7 | medium | A | app | Camera hot during 75 s warm-up |
| A8 | medium | A | native | stop/start race binds orphan camera, rejected executor |
| A9 | low | A | native | Concurrent permission request leaves a future hanging |
| A10 | medium | A | app/game | Checkpoint never used; tutorialDone set on failed tutorial |
| A11 | low | A | app | Fabricated falseTriggers/latency telemetry |
| B1 | critical | B | server/billing | Webhook deduped before apply, so purchases are lost on retry |
| B2 | high | B | server/privacy | Deletion keeps pain reports and devices for the grace window |
| B3 | high | B | server/privacy | Export missing crew_scores, sign-in sessions and more |
| B4 | medium | B | game_director | restartFromCheckpoint keeps stale forgiveness and segment state |
| B5 | medium | B | game_director | Forgiveness is a single red sample in level-clock time; unfair hits |
