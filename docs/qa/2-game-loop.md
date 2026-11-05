# QA 2 — Run loop review (game loop, pause/resume, checkpoint, tracking, HUD, audio)

Scope: `app/lib/screens/quest_screen.dart`, `app/lib/game/forest_game.dart`,
`app/lib/services/pose_service.dart`, `app/lib/services/voice.dart`,
`packages/game_director/lib/src/run_engine.dart`, `director.dart`.
Method: code review with the run loop traced by hand. No code changed. No temporary tests were left behind.

## Q2-1 — High — Double "Resume" starts the camera twice, leaking a watchdog timer and a frame subscription
- File: `app/lib/screens/quest_screen.dart:291-299`, `app/lib/services/pose_service.dart:163-189`
- Repro: pause a run, then tap Resume twice quickly (or tap it again while the permission check or camera start is still waiting).
- Expected: one camera start, one frame subscription, one watchdog.
- Actual: `_resume` has no in-flight guard, because `_paused` stays true until after the `await`. Both calls run `session.start()`. The second call overwrites `_sub` and `_watchdog`, so the first `Timer.periodic` and the first `source.frames` subscription are never cancelled, even by `stop()` or `dispose()`. Every frame then goes through `_onFrame` twice. The engine gets duplicate events, so one lean moves two lanes and reps count twice. The leak repeats on every later pause and resume.
- Fix: add a `_resuming` flag in `_resume`, the same way `_runBegun` guards `_beginRun`. Also make `MotionSession.start` idempotent: return early if `_sub != null`, or cancel the old `_sub` and `_watchdog` first.

## Q2-2 — High — A squat or raised arms held at pause stays "held" after resume (free clears)
- File: `packages/game_director/lib/src/run_engine.dart:204-217`, `quest_screen.dart:280-299`, `pose_service.dart:166-168`
- Repro: squat (`MoveStarted(squat)` sets `ducking = true`), tap Pause, then Resume. `start()` builds a fresh `MotionEngine`, which never sends `MoveEnded(squat)`.
- Expected: pausing clears transient move state, as `TrackingPaused` and `restartFromCheckpoint` already do.
- Actual: `RunEngine.ducking` (and `armsUp`) stays true. Every later beam (or gate) clears with no movement until the player happens to finish another squat. The skeleton is also drawn ducking.
- Fix: when the run pauses, feed the engine a loss. For example, `_game.engine.input(TrackingPaused(..))` in `_pause`, or have `MotionSession.stop()` emit `TrackingPaused` when tracking was not already paused. That clears `ducking` and `armsUp` and starts the reaction window (see Q2-3).

## Q2-3 — Medium — Resume gives no reaction window if tracking was green at pause
- File: `run_engine.dart:303-310`, `quest_screen.dart:291-299`
- Repro: pause while tracking is green and an encounter's cue has already played. The player walks to the phone, taps Resume and steps back.
- Expected: rule 5. The player gets at least `_reactionMs` of tracked play before an arrival is judged.
- Actual: the engine never saw a loss (`_lastLostWall` is unchanged), and `stop()` only sets `_resumeOnStart` when tracking was already paused. `resumeEngine()` restarts the clock at once, so an arrival less than 800 ms of wall time after resume is judged, and a beam or block can cost a heart. Whether the fresh `MotionEngine` reports red until the player is back in position depends on motion_core and was not checked. If it reports green, the hit happens.
- Fix: the same as Q2-2. Treat pause as a tracking loss inside `RunEngine` so the existing forgiveness logic covers it.

## Q2-4 — Medium — Going to background while Resume is starting the camera leaves the run unpaused
- File: `quest_screen.dart:280-282`, `quest_screen.dart:291-299`
- Repro: tap Resume, then press Home before the camera finishes starting.
- Expected: the run stays paused, as `_beginRun` handles at lines 219-222.
- Actual: `_pause()` returns early because `_paused` is still true during the `await`. Then `_resume` calls `resumeEngine()` and sets `_paused = false` while the app is in the background. On return the Paused overlay is gone, the camera may be unbound, and the clock runs as soon as frames resume.
- Fix: after `await _startCamera()`, re-check `WidgetsBinding.instance.lifecycleState`. If it is not `resumed`, stop the session and stay paused. Or record a pause request that arrived while a resume was in flight.

## Q2-5 — Medium — The checkpoint offer keeps the camera running with no time limit, and its tracking events are lost
- File: `quest_screen.dart:228-234`, `run_engine.dart:201`
- Repro: lose all hearts after the checkpoint and leave the "Out of hearts" card up.
- Expected: the camera stops while the game waits for a choice (privacy and battery), like Pause.
- Actual: only `game.pauseEngine()` is called, so CameraX and the pose model keep running. Meanwhile `RunEngine.input` drops every event because `finished == true`, including `TrackingPaused` and `TrackingResumed`. After "Continue", the HUD `trackingIssue` banner and the engine's light can disagree with reality. `restartFromCheckpoint` forces green, and `setLight` then ignores amber while the engine is red.
- Fix: call `_session?.stop()` when showing the offer and `_startCamera()` in `_continueFromCheckpoint`. Clear `hud.trackingIssue` on restart.

## Q2-6 — Low — The hint banner expires on the level clock and is stale after a checkpoint restart
- File: `app/lib/game/forest_game.dart:149`, `forest_game.dart:191`
- Repro A: get a hint while tracking turns amber or red. The level clock slows or stops, so the hint stays for much longer than 2.2 s of wall time.
- Repro B: fail about 20 s after the checkpoint, just after a hint. Continue restarts with `clockMs = cp.startMs`, but `_hintUntilMs` still holds the later time. If the checkpoint segment has no hint of its own, the old hint stays on screen for about 20 s.
- Expected: the hint shows for about 2.2 s of wall time and never carries over from the failed attempt.
- Fix: track the hint deadline in wall time (sum of `dt`). Reset `_hintUntilMs` and the hint when the engine restarts.

## Q2-7 — Low/Medium — Tracking voice lines bypass the throttle, and a stall can send duplicate "lost" events
- File: `quest_screen.dart:389`, `forest_game.dart:203-211`, `pose_service.dart:196-201`, `pose_service.dart:235-243`
- Repro: stand at the frame edge so tracking flickers red and green. Or let frames stall while the engine also pauses itself.
- Expected: one cue and one spoken line per real state change, with a minimum gap between them.
- Actual: `sayKey` always passes `force: true`, so the 1.2 s throttle in `Voice.say` never applies. Each flicker plays `tracking.wav` and cuts off TTS with "step back" or "tracking back". The watchdog `TrackingPaused` and the engine's own `TrackingPaused` both reach the game, so both play. Forced tracking lines also cut off encounter hints, which are not forced.
- Fix: in `ForestGame._handle`, skip a `TrackingHint` whose issue matches the current HUD state. Rate-limit tracking speech (for example, at most once every 3 s per issue). Only force speech for lines that must be heard.

## Q2-8 — Medium — The director's feasibility shift can push a damaging encounter into a breather segment (or past the checkpoint start)
- File: `packages/game_director/lib/src/director.dart:123-146`
- Repro: place a beam or block whose `atMs` is just before a breather segment, right after another encounter whose recovery time ends inside the breather. Step 2 checks `segmentAt(spec.atMs)`, but step 4 then moves `at` to `earliestNext`, which falls inside the breather.
- Expected: breathers never carry anything that can hurt (step 2's own comment).
- Actual: the breather check runs on the time before the shift, so a damaging encounter can arrive during a breather.
- Fix: compute `at` first, then apply the breather filter to `level.segmentAt(at)`. Add a director test for this case.

## Q2-9 — Low — "Finish run" on the checkpoint card can run twice and crash on `_checkpointOffer!`
- File: `quest_screen.dart:443`, `quest_screen.dart:239-249`
- Repro: double-tap "Finish run", or tap it in the same frame as "Continue".
- Expected: the run finishes once.
- Actual: `_finishRun` has no re-entrancy guard. The second tap evaluates `_checkpointOffer!` after it has been set to null, which throws. In the other order, it calls `session.stop()` and `setState` twice.
- Fix: capture `r` once (`final r = _checkpointOffer; if (r == null) return;`) and guard `_finishRun` with a flag, the way `_completed` guards `_complete`.

## Q2-10 — Low — `durationS` counts pause, checkpoint-card and cool-down time
- File: `quest_screen.dart:332-335`
- Repro: pause for 10 minutes mid-run, then finish.
- Expected: the session length reflects play, or at least excludes idle pause time (`RunResult.activeMs` already exists).
- Actual: `DateTime.now() - _startedAt`, measured after the cool-down, includes all paused time. The reported duration and activity are inflated, and capped at 3600 s.
- Fix: derive the duration from `activeMs` plus the warm-up and cool-down time actually done, or subtract the time spent paused.

## Checked and found OK
- `RunEngine` cue order stays sorted: `_warnAt` gives warn times that rise with arrival time, so the in-order cue loop never delays a cue.
- A large frame time is clamped to 100 ms. Encounters that resolve in one burst after a jump are forgiven, because each cue's wall time equals the current wall time.
- `restartFromCheckpoint` cannot refill hearts twice, and the checkpoint heart bonus is not granted again.
- `RunFinished` cannot fire twice: `finished` is set in `_finish`, and `advance` and `input` return early afterwards.
- `ForestGame.dispose` is idempotent and releases the HUD notifier and the subscription. `QuestScreen.dispose` drops the game, so repeated runs do not keep old engines alive, apart from the leak in Q2-1.

## How to verify fixes
- Q2-1: a widget or unit test with a fake `PoseSource`. Call `start()` twice and check that one frame produces one event and that `stop()` leaves no live timers (use `fake_async` and check `pendingTimers`).
- Q2-2 and Q2-3: a `RunEngine` test. Send `MoveStarted(squat)`, apply the new pause hook, then advance to a beam arrival. Expect `forgiven` or `hit`, not `cleared`.
- Q2-8: a `Director` test with a breather that starts inside the previous encounter's recovery window.

✅ Fixed: Q2-1 — `MotionSession.start` is idempotent (returns true while running; overlapping calls share one in-flight start) and cancels any old subscription/watchdog before subscribing; `stop`/`dispose` cancel both; `_resume` has a `_resuming` guard. Test: `app_logic_test.dart` "a second start while running or starting is a no-op (Q2-1)".
✅ Fixed: Q2-2 + Q2-3 — `_pause` feeds the RunEngine `TrackingPaused(noPerson)` (clears `ducking`/`armsUp`, records the loss), `_resume` feeds `TrackingResumed` after the camera restarts, so the reaction window applies. Test: `run_engine_test.dart` "a pause fed as a tracking loss clears a held squat (Q2-2, Q2-3)".
✅ Fixed: Q2-9 — `_finishRun` takes a nullable result and is guarded by `_finishing`; the button no longer uses `_checkpointOffer!`.
✅ Fixed: Q2-4 — after the camera starts in `_resume`, a non-`resumed` lifecycle state stops the session and the run stays paused.
