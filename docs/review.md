# Pre-launch review (2026-11-05)

Harsh senior review ahead of Play Store production. No code was changed.
Findings are grouped into two fix buckets that touch disjoint files, so two
fixers can work in parallel.

- **Bucket A**: `app/**` and `native/**`
- **Bucket B**: `server/**` and `packages/**`

---

## Bucket A: app and native

### A1. Rule 5 broken when frames stop arriving (critical, motion/app)
✅ Fixed: `MotionSession` watchdog emits one `TrackingPaused(noPerson)` after 500 ms with no frames, `session.light` is red while `stalled`, `TrackingResumed` on the first frame back (tested).
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
✅ Fixed: `_QuestState` is a `WidgetsBindingObserver`; inactive/hidden/paused freezes the game (`pauseEngine`, Flame auto-resume off), stops camera and voice, holds the exercise timer; resume needs the player to tap Resume on the pause overlay.
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
✅ Fixed: `PosePipeline.start` takes `onFailed`; model, provider, bind and rejected-executor failures all answer `result.error("start_failed")`, guarded by an `AtomicBoolean` (not compiled locally).
`native/pose_bridge/android/src/main/kotlin/app/motionquest/pose_bridge/PosePipeline.kt:60-62`, `:87-89`; `PoseBridgePlugin.kt:116`
If the model fails to load or `bindToLifecycle` throws, only `onError` runs.
That goes to the event sink, which may not even be listening yet. The
`MethodChannel.Result` passed to `p.start { ... }` is never completed, so
`await source.start()` (`pose_service.dart:153`) hangs and `QuestScreen`
stays on `_Phase.loading` with no way out.
**Fix:** pass a failure callback into `PosePipeline.start` and call
`result.error(...)` on both catch paths, exactly once.

### A4. Unhandled exceptions and stream errors in `_prepare` / session (high, app)
✅ Fixed: `PlatformException` from start is caught and shown as an error screen; frame stream has `onError` that pauses tracking instead of crashing (tested).
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
✅ Fixed: `mounted` checks after every await; a session started after the widget was disposed is disposed; `_onRunFinished` guarded.
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
✅ Fixed: `PopScope` routes back to the pause overlay; HUD pause button; overlay offers Resume or an explicit "Quit (this run is not saved)".
`app/lib/screens/quest_screen.dart:256-330` (`_RunView`), no `PopScope` anywhere in `app/lib`
The run has no pause or quit button. Because navigation uses `context.go`,
the system back gesture closes the app or route abruptly. The session is
not saved and the work is lost silently. Warm-up and cool-down have no skip
either.
**Fix:** add a `PopScope` with a pause sheet (Resume / End run, which saves
a partial result) and a visible pause button in the HUD.

### A7. Camera and inference run for the whole 75 s warm-up (medium, app/privacy/battery)
✅ Fixed: camera starts only when the run phase begins (after warm-up), stopped at cool-down.
`app/lib/screens/quest_screen.dart:136-152`
`session.start()` runs before `_Phase.warmup`. The front camera and the GPU
model stay hot through the warm-up even though nothing consumes events. The
camera-in-use indicator is on while the player is told to do arm circles.
This costs battery and heat on budget phones, and it is a privacy optics
issue.
**Fix:** start the session when `_Phase.run` begins (or a few seconds
before). Stop it on the cool-down, which `_onRunFinished` already does.

### A8. Native stop/start race binds the camera after stop (medium, native)
✅ Fixed: `@Volatile stopped` checked before binding and in `analyze`/`onResult`; `inFlight` recycled on stop; stop is idempotent (not compiled locally).
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
✅ Fixed: a second concurrent request gets `in_progress`; a pending result completes with `false` on detach.
`native/pose_bridge/android/src/main/kotlin/app/motionquest/pose_bridge/PoseBridgePlugin.kt:80`
A second call overwrites `pendingPermission`, so the first `Result` is
never answered. `onDetachedFromActivity` also does not complete it.
**Fix:** if one is pending, answer the new call with an error or a shared
result. Complete any pending result with `false` on detach.

### A10. Checkpoint is a dead feature, and the tutorial is marked done even when failed (medium, game logic)
✅ Fixed: failing after the checkpoint offers "Continue from checkpoint" (`restartFromCheckpoint`); `tutorialDone` only set on a completed run; `seenTypes` adds only encounters that arrived.
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
✅ Fixed: `moveStats` no longer sends `falseTriggers`/`avgLatencyMs`; `session_queue.dart` still sends `falseTriggers: 0` because the server schema requires it (Bucket B should make it optional).
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

## Bucket B fix status (server + packages)
- ✅ Fixed B1: `processWebhookOnce` records the event and applies it in one transaction; a failed apply leaves no marker so the provider retry succeeds (trigger-based test).
- ✅ Fixed B2: `DELETE /me` immediately deletes pain reports, sessions/moves, progress, devices, calibrations, crew scores; only anonymised billing/consent/membership linkage remains until hard delete (documented in security.md).
- ✅ Fixed B3: export adds crew scores, sign-in session metadata (no hashes) and billing linkage; a test fails if any `user_id` table is missing from the export.
- ✅ Fixed B4: `restartFromCheckpoint` resets light, lost times, move state, grace timers, streak, segment and pacer; allowed once per loss.
- ✅ Fixed B5: forgiveness also covers a loss up to 300 ms before the cue and < 800 ms (1200 ms assist) of play since cue or recovery.

## Round 2 review (new work)

Read-only review of today's additions. Severity: High = crash, wrong outcome, or policy risk; Med = UX dead end or data loss; Low = polish or performance.

| id | sev | file:line | what's wrong | suggested fix |
|---|---|---|---|---|
| R2-1 | High | app/lib/screens/home_screen.dart:44,62 + app/lib/game/stages.dart:180 | Premium gate bypass. When `paymentsEnabled` is on, the lock is only applied in `StageInfoSheet`. Daily Quest pushes `/quest?level=${nextStage()}`, and once World 1 is done that is `w2-desert-dunes`, a Premium stage. QuestScreen accepts any `levelId`. | Give `nextStage` (or QuestScreen) the premium state and skip locked stages; also check the lock in QuestScreen `_prepare`. |
| R2-2 | High | app/lib/screens/quest_screen.dart:239-248, 265-284, 408-424 | Pausing while the checkpoint offer is up stops the camera and sets `_paused`. "Continue from checkpoint" then calls `resumeEngine()` but never restarts the camera or clears `_paused`. The run plays behind the Paused overlay with no pose input, and Resume then calls `_startCamera` mid-run. | In `_continueFromCheckpoint`, if `_paused`, only clear the offer and let `_resume` start the camera and the engine. Otherwise resume as now. |
| R2-3 | Med | app/lib/services/pose_service.dart:236-243 with quest_screen.dart:265-284 | A watchdog stall followed by Pause/Resume leaves the tracking banner on screen for good. `stop()` resets `_stalled` without sending `TrackingResumed`, and `start()` creates a fresh `MotionEngine` that is not paused, so no `TrackingHint(null)` ever reaches the HUD. `trackingIssue` stays set, the "step back" banner stays up and all hints are hidden. `setLight` turns the dot green again, so the banner contradicts the dot. | In `start()` (or `_resume`), send `TrackingResumed` when a stall was active before the stop, or clear `trackingIssue` in `ForestGame` when the engine light goes green. |
| R2-4 | Med | app/lib/screens/quest_screen.dart:266 | `_pause` does nothing while `_phase == loading`, and that includes the camera start between warm-up and the run. If the app goes to the background then, the run starts with `pauseWhenBackgrounded=false`, so it plays unseen with the camera off or stalled. | After `_startCamera` succeeds in `_beginRun`, check `WidgetsBinding.instance.lifecycleState`. If it is not `resumed`, enter the paused state instead of starting. |
| R2-5 | Med | app/lib/screens/quest_screen.dart:633-638, 694-698 | `_ExerciseFlow._begin(len)` can call `onDone` more than once: a double tap on Skip on the last exercise, or Skip racing the timer before the rebuild. In cool-down this runs `_complete` twice, so `sessionsPlayed` goes up by 2 and `/results` is pushed twice. In warm-up it runs `_beginRun` twice, which starts the camera twice. | Add a `_done` flag in `_ExerciseFlowState`, and make `_complete` and `_beginRun` re-entrancy safe. |
| R2-6 | Med | app/lib/screens/results_screen.dart:75-101, 247-254 | The session is queued and Kavi's history recorded only when the player taps Done. If they leave by another route (system back, or the app is killed on the results screen), the run is lost both on the server and in coach history. | Queue the session and record the summary in `initState`, and send the effort rating as a later update, or save on dispose. |
| R2-7 | Med | packages/game_director/lib/src/coach.dart:323-330 + results_screen.dart:310 | After any unfinished run, or a run with 2+ hearts lost, `suggestAssist` is always true. `SessionSummary` does not record whether assist was already on, so a beginner who already has assist on sees a "Try assist" button that changes nothing, after every failed run. | Add `assist` to `RunResult`/`SessionSummary` and set `suggestAssist: !last.assist`. |
| R2-8 | Low | packages/game_director/lib/src/coach.dart:404-414, 417-425 | The "new best" recap and the next score goal compare scores across different stages and difficulties. A long stage makes the short ones look worse, and moving to a new stage gives false "best" or unreachable goals. | Restrict `prevBest` and `best` to the same `levelId`. |
| R2-9 | Low | app/lib/screens/results_screen.dart:48-53 | `maxHearts` is never passed, so it always defaults to 3. That is correct today, since every level has 3 hearts, but it breaks silently if a level config changes the number. | Pass `maxHearts: level.hearts` (add it to `RunResult` or `ResultsData`). |
| R2-10 | Low | app/lib/screens/home_screen.dart:47-48 | `(gym['colours'] as Map)['primary'] as String` plus `int.parse` throws a red screen if the server omits colours or sends a short or invalid hex. | Parse inside a try, fall back to null, and accept only `#RRGGBB`. |
| R2-11 | Low | app/lib/screens/home_screen.dart:175-181 | The `worlds` getter rebuilds the whole world list on every `itemBuilder` call and for `itemCount`. That is a small amount of allocation per scroll frame on budget phones. | Make it a top-level `final worlds = _buildWorlds();` |
| R2-12 | Low | app/lib/screens/stage_info_sheet.dart:134-143 | The locked Play button says "Premium" and does nothing: a dead end with no way to unlock. Keep it inside Play billing (rule 11). | Route it to the in-app Play Billing paywall screen, or say "Unlocks with Premium (Settings)". |

### Areas with no defects found
- **forest_game.dart, visible-encounter window.** The binary search over `arriveMs` and the forward scan that stops at `arriveMs - (warningMs + wideBlockExtraMs) > clock` are correct for a plan sorted by arrival. The per-item `warnMs` check handles mixed lead times. Wide blocks clamp `d` to 1 until they come closer, which is fine.
- **forest_game.dart, HUD throttling.** Quantising progress to 500 steps and assigning only on change are correct. Event-driven assignments (hint, outcome, issue) bypass the check, which is intended.
- **forest_game.dart, lifecycle.** Pausing is owned by QuestScreen (`pauseEngine` and `session.stop`). There are no per-frame allocations in the painter.
- **stage_info.dart and stage_info_sheet.dart wording.** No treat, cure, prevent or weight-loss claims; the disclaimer is present. The sources are real and correctly cited: WHO 2020 guidelines, ACSM's Guidelines 11th ed. (2021), and Garber et al. 2011, the ACSM Position Stand in MSSE. One minor point: "Counts toward weekly activity guidelines" on Moderate stages is fine, but avoid putting it on Light stages.
- **body_map.dart.** Paints and paths are static or cached, `shouldRepaint` is value-based, and the Semantics label carries the meaning without relying on colour.
- **stages.dart.** The unlock order is linear and correct. `nextStage` falls back to Forest Escape. The newly added oasis-caravan and night-market entries have matching `stageInfos` entries, so `infoFor` will not throw. Note that the Garba *event* sits in the main unlock chain: if the event is ever made seasonal or unavailable, it blocks World 2.
- **coach_service.dart.** History is bounded at 20, parsing is wrapped in try, and only counts are stored. Check whether `coach.history.v1` is cleared by the in-app "delete my data" / account-deletion flow (not verified).

**Summary:** 2 High (Premium bypass through Daily Quest; checkpoint offer plus pause leaves the run going behind the overlay with no camera), 5 Med (stuck tracking banner after stall then pause, background start during loading, double `onDone`, results lost unless Done is tapped, "Try assist" offered when assist is already on), 5 Low. The perf rewrite and the health wording look sound.

✅ Fixed: R2-2 — `_continueFromCheckpoint` no longer resumes the engine while paused; it clears the offer and leaves Resume to restart the camera and engine.
✅ Fixed: R2-3 — `MotionSession.stop()` remembers a stall/paused engine; the next `start()` sends `TrackingResumed` (unless the engine is still paused and will send its own), so the HUD banner clears. Test: "stop during a stall then start resumes tracking (R2-3)".
✅ Fixed: R2-4 — after the camera starts in `_beginRun`, a non-`resumed` app lifecycle state pauses the run immediately.
✅ Fixed: R2-5 — `_ExerciseFlow` has a `_done` guard; `_beginRun` and `_complete` are re-entrancy safe (`_runBegun`, `_completed`).

## Round 3 review

Scope: commits `afd0388`..`ebd0de8` (play-style warning multiplier, settings play style / sign out / wipe, R2 fixes, extra recognisers, server request id and shutdown).

| ID | Sev | File:line | What's wrong | Fix |
|---|---|---|---|---|
| R3-1 | High | app/lib/services/session_queue.dart:88-106 | `flush()` reads the queue once, awaits the upload, then writes `all.skip(n)` back. A session `add`ed meanwhile is overwritten and lost. For example, the results screen saves with the effort rating while the home `flush` is running, or `_persist` in initState races the Done `_save`. The write also brings back the stale version without the effort rating. | Serialise queue access with a single in-process lock or future chain. After an upload, re-read the file and remove only the uploaded clientIds. |
| R3-2 | Med | app/lib/services/session_queue.dart:98-101 | Every `ApiException` other than 5xx/401 drops the whole batch of up to 50 sessions. That includes 429 (rate limit), 408 and 403. One bad session or one throttle response throws away 49 valid runs. | Treat 429/408 like 5xx (break and retry later). On a 4xx validation error, bisect or upload one by one, and drop only the rejected session. |
| R3-3 | Med | app/lib/screens/settings_screen.dart:215-231 | Sign out clears tokens only. The offline session queue, Kavi history and `pendingGymCode` stay on the device. If a different person signs in next, `flush()` uploads the previous player's queued runs to the new account. | On sign out, clear the session queue file or tag queued sessions with the user id and drop mismatches. Also offer to clear coach history. |
| R3-4 | Low | app/lib/screens/settings_screen.dart:217-220 + server identity | Sign out never revokes the refresh token on the server. There is no logout endpoint, so a copied refresh token stays valid until it expires. | Add `POST /auth/logout` that revokes the refresh-token family, and call it (best effort) before `tokenStore.clear()`. |
| R3-5 | Med | app/lib/screens/quest_screen.dart:136-138 | R2-1 is only half fixed. `nextStage(premiumLocked:)` skips locked stages, but `QuestScreen._prepare` still accepts any `levelId` without checking `isUnlocked` or the premium lock, so `/quest?level=w2-…` (a deep link or a stale route) plays a locked or Premium stage. | In `_prepare`, if the stage is not `isUnlocked`, or is premium-locked while `paymentsEnabled && !premium`, fall back to `nextStage(...)` or pop with a message. |
| R3-6 | Low | app/lib/screens/settings_screen.dart:207-213 | Delete account: `catch (_) {}` hides every failure (offline, 5xx). The player taps Delete and nothing happens, with no message. If `wipeLocalData` throws after the server delete succeeds, the account is gone but the app still looks signed in. | Show a SnackBar on API failure. Run the wipe, reset and navigation in their own try block after a successful delete. |
| R3-7 | Low | packages/motion_core/lib/src/extra_recognisers.dart:226-258 | SideStep confirm: `_confirm` keeps counting when `dir` flips between left and right on consecutive frames, so a jitter across centre can confirm a step in the last-seen direction. In the held state, a direct left-to-right swing (|f| never drops below `stepEnd`) keeps reporting `stepLeft` held. | Store the pending direction and reset `_confirm` when it changes. In held, end the step if `sign(f)` is opposite to the held direction. |
| R3-8 | Low | app/lib/services/settings.dart:66-67 | The doc comment on `warningMultiplier` still says "for future director use", but the director now uses it. Gentle also turns assist on, so the effective warning is 1.2 × 1.25 = 1.5×. That is not documented in game-design.md next to the 1.0–1.5 clamp. | Update the comment and document the combined lead in game-design.md. |

Clean areas (none found):
- `Director._warnAt`: it keeps the base warning, caps the extension at the previous arrival, and keeps the wide-block extra.
- `RunSettings.warningMultiplier`: clamping and the NaN guard are correct.
- `wipeLocalData`: its key list matches the keys used in the app.
- Coach history `record` replaces by clientId.
- Results `_persist` in initState (R2-6).
- Home header small-screen change.
- BarrierHold recogniser.
- Server `genReqId`: the header is validated by a regex and echoed in `onRequest`.
- `onShutdown`: one close, a second signal forces exit, the timer is unref'd.

### Round 3 fix status
- ✅ Fixed R3-1: session queue access is serialised; after an upload only the uploaded versions are removed (re-read), so concurrent adds/updates are never lost.
- ✅ Fixed R3-2: 429 and 408 are retried later like 5xx instead of dropping the batch.
- Fixed 2026-11-09: R3-3 (locked queue clearing, coach/activity-day clearing,
  pending-code clearing, account ownership and in-flight request isolation),
  R3-5 (direct quest route checks progression and Premium before starting),
  R3-8 (warning multiplier comment and combined 1.5x lead documented).
- Reverified R3-6: the current deletion handler already shows an error snack;
  this review did not introduce that earlier fix.
- R3-2 is now fully addressed: validation failures isolate individual records;
  valid neighbours sync and rejected records stay local for review. Other
  permission/service errors keep the queue for retry.
- Open: R3-4 (server logout endpoint to revoke refresh token), R3-7 (side-step
  confirm reset on direction flip). These were outside the six UX assessment
  findings addressed by the adventure experience update.

## Round 4 checks (verification agents)
- motion_core 57 and game_director 346 tests green; all breathers orbs-only, all hints ≤ 80 chars, checkpoints present, no gap > 60 s.
- ⏳ Open (design): 9 older levels (w1-forest-escape, w1-guardian-grove, w1-river-crossing, w2-desert-dunes, w2-sandstorm-temple, w3-neon-city-chase, w3-neon-city-rooftops, w4-mountain-trail, w4-summit-storm) have 4–6 orbs in a row in their breathers, which conflicts with the "no type > 3 in a row" fun rule. Decide: exempt breathers from the run rule (they are rest beats), or cap breathers at 3 orbs with a non-orb before/after. Then add the fun-rule check (scratchpad funcheck.py logic) as a content test so CI enforces it.
- ✅ Fixed (process): packages/game_director/test/content_rules_test.dart fails CI if two levels share an encounter layout.
- ✅ Fixed (server): OTP attempt counter is atomic, a code is consumed once, verify rate-limited per IP.
- ⏳ Open (server): trainer key is sent as `?key=` and ends up in request logs/proxies — move it to an `x-trainer-key` header and redact it (gyms/routes.ts:151-220).
- ⏳ Open (server): Razorpay webhook body is cast, not zod-parsed (billing/routes.ts:51-57) — parse `event` and `payload.*.entity.notes` like the RevenueCat handler.
