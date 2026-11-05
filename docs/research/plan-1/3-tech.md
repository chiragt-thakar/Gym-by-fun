# 3 — Tech research: move detectability, latency, two non-lane modes (2026-11-05)

Read: motion_core recognisers.dart / extra_recognisers.dart / features.dart / quality_gate.dart / motion_engine.dart,
game_director run_engine.dart / director.dart / level.dart / simulator.dart, app/lib/game/forest_game.dart,
docs/architecture.md, docs/performance.md, docs/qa/5-motion-levels.md, docs/stages-roadmap.md §3. No repo edits.

## 1. What the evidence says (MediaPipe Pose Landmarker / BlazePose, single front camera)
- Accuracy: BlazePose paper PCK@0.2 — Full 84.1, Lite 79.6 (OpenPose 87.8) on AR set; Lite ~31 fps on Pixel 2 CPU (paper, not independently reproduced). We ship Lite (architecture.md). Lite = noticeably worse on extremities (wrists/ankles) — exactly what punch/clap/jog need.
- Latency: no official budget-Android benchmark exists. Flagship self-reports 15–18 ms (S24U/Pixel 8, lite, GPU). GPU delegate is not always faster (mediapipe#6041) — budget Mali/PowerVR often ≈ CPU. Our own gate: inference ≤ 40 ms budget tier, capture→event < 150 ms, ≥ 15 fps budget (performance.md).
- Depth (z): normalised z has no consistent scale; bone lengths drift; same 2-D projection fits several 3-D poses (arXiv 2512.06783, BlazePose-GHUM). => **never threshold absolute z**. Only use *relative* z sign between paired joints (L vs R shoulder) as a tie-breaker, never as the primary signal.
- Motion blur at 15–30 fps: MediaPipe hand/pose degrade badly under blur (metamorphic robustness study: "none robust against motion blur"); 30 fps footage blurs fast limbs (baseball pitch work). Indoor front-cam exposure ≈ 1/30–1/60 s → a 2–3 m/s wrist smears 5–10 cm per frame; landmark lags, jumps, or visibility drops. **Velocity-threshold detection is fragile; end-state (pose reached and held ≥ 1–2 frames) is robust.**
- Latency tolerance: exergame literature cites ≤ 150 ms acceptable for competitive play, exergames tolerate more (arXiv 2507.06669). Kinect dance games judged timing against an error *window*, not an instant.

### Our real pipeline latency (estimate, budget tier)
camera exposure+ISP 30–60 ms + inference 30–40 ms + bridge/One Euro ~5–15 ms + `confirmFrames=2` (1 extra frame: 33 ms @30 fps, 67 ms @15 fps) ≈ **110–180 ms**, jitter ±1 frame (33–67 ms). Note `RunEngine.input` stamps moves with `_wallMs` at *arrival*, so judgements are biased late by the whole pipeline — fine for the runner (grace windows absorb it), wrong for beat timing (see §4.2).

### Geometry at 2–2.5 m
Front cams ~70–80° diag FOV; a 1.7 m adult in portrait fills ~50–65 % of frame height. On budget tier (360×480) body ≈ 240–310 px → forearm ≈ 35–45 px, wrist ≈ 8–12 px. QualityGate `minBodyPixels=256` already forces ≥ 53 % at 480 px. Fine for torso/legs; wrists are marginal → recognise wrists by *zones relative to torso*, never fine angles.

## 2. Detectability verdicts (single front camera, 2–2.5 m, budget phone, Lite model)
| Move | Verdict | Why / signal to use |
|---|---|---|
| Side / lateral / diagonal-out punch | **Reliable** | Arm extends in the image plane: 2-D reach = |wrist−shoulder| / armLength ≥ 0.75 and 2-D elbow angle ≥ 145° are real. End-state detection. |
| Forward punch (toward camera) | **Unreliable as a distinct move** | Pure foreshortening: 2-D reach *shrinks* (~0.2–0.5) — identical to `BarrierHoldRecogniser` (`barrierReachMax 0.55`). z is unscaled. Only usable as "guard→chest-height foreshortened extension within 400 ms" and then it collides with barrier. **Design pads off-axis (≥ 30° out to the side) so every punch is lateral.** Roadmap §3.4 (reach ≥ 0.75) implicitly assumes this — say it explicitly in game-design.md. |
| Guard (hands at face) | **Reliable (static)**, moderate risk | Wrists within 0.45 torso of nose. Hands over face lower nose/eye visibility; use shoulder-centre + 0.9 torso as fallback "face" anchor when nose visibility < 0.5. Must exclude raise-arms (wrist above nose by > 0.15 torso). |
| Jog / march (knee lift) | **Reliable** | Knee y rise vs standing knee y, / thigh length. Cadence 1–2.5 Hz ≪ Nyquist at 15 fps. Count steps over a window; do not judge per-step timing. Needs knees visible (loose trousers/saree lower ankle-knee visibility → emit notVisible). |
| Single knee lift (cued) | **Reliable** | Same measure, ≥ 0.5 of calibrated lift, held 2 frames. |
| Twist (torso rotation) | **Medium** | Shoulder width shrinks ~cos(θ) (≥ 25 % drop at 40°) — magnitude reliable, **direction ambiguous** in 2-D. Direction from (a) wrists crossing body midline (twist with bent arms: right wrist passes left of hip-centre), (b) relative z sign L vs R shoulder as tie-breaker. Cue twists with "elbows out, hands at chest" so the wrist-crossing signal exists. |
| Side step | **Reliable** | Already implemented (`SideStepRecogniser`), hip+feet shift. |
| Clap | **Medium-low** | Contact lasts 50–100 ms → 0–1 frames at 15 fps; hands overlap → wrist swap / low visibility. Detect "wrists within 0.35 torso of each other at chest–head height" on ANY frame inside the window (approach-then-separate). Do not count clap repetitions fast; ≤ 1 clap per beat at ≤ 100 BPM. No microphone (new permission, adds privacy surface). |
| Arms up | Reliable | Existing; fix Q5-7 (400 ms raise missed) and Q5-9 (no wrist visibility check) first. |
| Dance timing (move on beat) | **Medium** | Recognition fine; *timing* only to ±1 frame plus 110–180 ms latency. Needs latency compensation + wide windows (§4.2). |
| Fast combos / speed punches | **No** | Blur + 2-frame confirm. Already a design rule ("controlled, never rapid"). |

## 3. Forgiving-mechanics rules (apply to both new modes)
1. **End-state, not velocity.** Every recogniser fires on a pose reached and held ≥ 2 frames (or 1 frame + max-over-window for clap). Never `dWrist/dt` thresholds.
2. **Windows in ms, judged on capture timestamp** (not arrival): beginner ±400 ms (good ±250), intermediate ±300 (±180), advanced ±250 (±120); assist +200 ms. Never tighter than 2 frames at the *measured* fps: `window ≥ max(spec, 2.5 × frameIntervalMs)`.
3. **Grades not hits.** Rhythm targets never damage (pads, cues): Perfect/Good/OK/Miss → score + streak. Only telegraphed hazards (strike → guard, beam → duck) cost a heart, with ≥ 2.2 s warning (existing `warningMs`).
4. **Any-hand fallback** on beginner/low-impact: wrong hand = OK (not Miss). Matching hand = bonus.
5. **Rule 5 intact:** amber/red tracking → targets in window resolve `forgiven`; music pauses and resumes with a 4-beat count-in (music cannot be slowed like the runner's Pacer without sounding broken).
6. **Rule 6 intact:** a punch with no pad in window does nothing (no score, no penalty).
7. **Silent misses are bugs** (Q5-8): every new recogniser emits `ExtraMoveRejected(notVisible|tooShallow|tooEarly)` so the HUD can say why.
8. **Adaptive density:** if `PerfStats.fps < 20`, the director drops to half-time (targets on every 2nd beat) and widens windows; < 15 fps → existing pause/slow path.
9. **Distance prompt 2.0 m** for these modes (wrists bigger in frame); keep full body in frame for jog/step.

## 4. Two new modes on the current architecture
Mode A **"Pad Dojo"** — stationary boxing-fitness: lateral pads L/R (punch), strikes (guard), low beam (squat), high orb (arms up). Mode B **"Beat Floor"** — rhythm dance on a beat grid: step L/R, knee lift L/R, clap, twist, arms up, march stretches. Neither uses lanes; both share one engine.

### 4.1 motion_core (tests first, rule: no threshold change without replay pass)
- `packages/motion_core/lib/src/events.dart`: extend `ExtraMove` with `punchLeft, punchRight, guard, kneeLeft, kneeRight, clap, twistLeft, twistRight` (keep `Move` untouched so `MotionThresholds.toJson` and runner tuning are unchanged).
- `features.dart` `BodyFeatures`: add `leftKnee, rightKnee, leftHip, rightHip, leftAnkle, rightAnkle` landmarks, `shoulderWidth`, and helpers `reach(side, cal)`, `elbowAngle(side)` (2-D, via atan2 — no allocation), `kneeLift(side, cal)`, `twistRatio(cal) = shoulderWidth / cal.standingShoulderWidth`, `faceAnchor` (nose, or shoulderCentre − 0.9·torso when nose vis < 0.5). Keep hot path allocation-free (performance.md).
- `calibration.dart` `CalibrationProfile`: add `armLengthLeft/Right` ("reach arm out to the side, hold 0.5 s"), `standingKneeYLeft/Right`, `thighLength`, `kneeLiftRange` ("march 4 steps"), `standingShoulderWidth`. Defaults when absent: arm = 1.05·torso (as `armLengthTorso`), thigh = 0.9·torso, kneeLift = 0.35·thigh — so old server calibrations (`GET /me/calibration`) still load.
- New file `packages/motion_core/lib/src/combat_recognisers.dart`:
  - `PunchRecogniser(side)`: armed only if wrist was in guard zone (≤ 0.5 torso of faceAnchor) within last 1000 ms; start = reach ≥ 0.75 (low-impact 0.60) AND elbow ≥ 145° (130°) AND wrist y within shoulder ±0.3 torso, for 2 frames; end/re-arm = wrist back within 0.5 torso of faceAnchor or reach < 0.4; cooldown 500 ms/hand, 350 ms across; peak 0.5–0.75 → tooShallow; wrist above nose → no event (raise); wrist/elbow/shoulder vis < 0.5 → notVisible.
  - `GuardRecogniser`: both wrists ≤ 0.45 torso of faceAnchor, wrist y ≥ nose y − 0.15 torso (not overhead), elbows below wrists; 2 frames start, 150 ms grace end; low-impact one hand. Mutually exclusive with `BarrierHoldRecogniser` (guard zone vs chest band already disjoint via `guardNoseTorso 0.4`).
- New file `packages/motion_core/lib/src/rhythm_recognisers.dart`:
  - `KneeLiftRecogniser`: lift(side) ≥ 0.5 (march 0.30) for 2 frames while other knee < 0.25; re-arm < 0.2; emits kneeLeft/kneeRight started/ended plus a `cadenceSpm` measure (ring buffer of last 8 step timestamps, fixed array). `jog` = sustained alternation; the engine decides, recogniser only reports steps.
  - `ClapRecogniser`: wrist–wrist distance ≤ 0.35 torso and both wrists between hip y and nose y − 0.3 torso on ≥ 1 frame, after both were ≥ 0.6 torso apart within the last 800 ms; re-arm when ≥ 0.6 apart; cooldown 300 ms. Visibility: accept vis ≥ 0.3 here (overlap lowers it) but require the pre-clap open frame at ≥ 0.5.
  - `TwistRecogniser`: twistRatio ≤ 0.78 for 2 frames AND hips stable (hip x shift < 0.25 of step range, else it's a step) AND lean < 0.4; direction = side whose wrist crossed hip-centre x; if neither, sign of (leftShoulder.z − rightShoulder.z) only if |Δz| > 0.1 normalised, else emit started with direction unknown → engine scores "any twist" as OK. Re-arm ratio ≥ 0.9.
- `motion_engine.dart`: add `enablePunch`, `enableGuard`, `enableKnee`, `enableClap`, `enableTwist` like `enableBarrierHold`; app enables only the set a level declares (`level.moves`). Cross-suppression: while `_squat` is down, suppress lean/knee (addresses Q5-10 pattern); while guard held, suppress punch start.
- `ExtraMoveThresholds`: add the numbers above as named fields with a `.lowImpact()` variant; document in docs/game-design.md.

### 4.2 game_director: a new engine, not RunEngine
- New `packages/game_director/lib/src/beat_engine.dart` `BeatEngine` with the RunEngine contract (`input(MotionEvent)`, `advance(dtMs)`, `setLight`, `List<RunEvent>` out, `RunResult` at end) so the app/HUD/session upload are reused. No `lane`; state = active targets in window.
- Clock: `beatMs = 60000 / bpm`; level time from **audio position** (music is master), `clockMs = audioPosMs − offsetMs`.
- **Latency compensation:** judge `delta = (eventCaptureTs − latencyOffsetMs) − target.atMs`. Requires mapping native frame timestamp → engine clock (MotionSession already holds a Stopwatch; pass `PoseFrame.timestampMs` through events — events already carry `ts`). `latencyOffsetMs` default = rolling `PerfStats.pipelineMs` median; optional "clap/step on 8 beats" calibration stores a per-device offset (median of deltas).
- New events: `TargetJudged(atMs, target, grade{perfect,good,ok,miss,forgiven}, points)`; reuse `CuePlayed`, `HintShown`, `TrackingHint`, `HeartsChanged`, `RunFinished`.
- Encounter → required move: `pad{hand,zone}` → punch(hand) (any hand = OK on beginner); `strike` → guard held across arrival ±200 ms (damages); `beam` → squat (reuse squat grace); `orb/high` → raise; `stepCue{dir}`, `kneeCue{side}`, `clapCue`, `twistCue{dir?}` → matching ExtraMove started within window; `marchTrack{durationMs}` → steps counted, score = min(1, steps/(durationMs·targetSpm)) — never damages.
- Director: extend `director.dart` with `BeatDirector.plan()` — deterministic; beginner spacing ≥ max(1000 ms, 2 beats), punches ≥ 700 ms, cap demanding (strike/beam) per `maxDemandingInRow`; half-time thinning when `settings.lowFps`; `MoveTimes.recovery` gets entries for new types (punch 500, guard 600, knee 500, clap 400, twist 700, step = lean 650).
- Rule 5: on amber/red → `forgiven` for targets whose window overlaps loss (+ reuse `_reactionMs` after green); music pauses, resumes with 4-beat count-in.

### 4.3 Level JSON schema v2 (`content/schema/level.schema.json`, `level.dart`)
- `schemaVersion: {"enum":[1,2]}`; top-level `oneOf` branch on schemaVersion so all 18 v1 levels stay valid unchanged.
- v2 adds: `mode: "runner"|"dojo"|"beat"` (required in v2), `moves: [..]` (recognisers to enable; validator checks every encounter's move is listed), `music: {track, bpm (60–140), offsetMs, beatsPerBar}` (required for beat/dojo), `lanes` required only when `mode=runner`.
- Encounter v2: `atS` **or** `atBeat` (number, quantised to 0.5 beat), `type` enum adds `pad, strike, stepCue, kneeCue, clapCue, twistCue, marchTrack`; `hand: left|right|any`, `zone: high|mid` (pads only, off-axis by construction), `dir: left|right`, `durationBeats` (marchTrack), `windowScale` (0.8–1.5, clamps the difficulty window).
- `if/then` per type: pad requires hand; strike requires none; marchTrack requires durationBeats and `mode≠runner`; `lanes` forbidden outside runner.
- Validator (`server` `npm run content:validate`) additions: min spacing per difficulty (beginner ≥ 1000 ms between punches/clap cues), demanding-streak ≤ maxDemandingInRow (fixes Q5-2 class at authoring time), no hazard within 2 beats after marchTrack, and level-similarity check (Q5-1/Q5-4).
- `LevelConfig.fromJson`: branch on schemaVersion; convert `atBeat` → `atMs` at load using bpm/offset so Director/Simulator work in ms.

### 4.4 Simulator / bot testing
- `packages/game_director/lib/src/simulator.dart`: add `simulateBeat(level, settings, BotProfile)`; `BotProfile` gains `latencyMs` (default 150), `timingJitterMs` (seeded Gaussian σ 60/120), `wrongHandEvery`, `missEvery`, `fps` (15/24/30 → quantises event timestamps to frames). Feasibility gates per level × difficulty: `competent` ≥ 90 % Good-or-better; `slow` (latency 200, σ 120, 15 fps) completes with ≥ 1 heart and ≥ 60 % non-miss on beginner; dropout bot never loses a heart (rule 5).
- motion_core `lib/src/testing`: extend `SyntheticBody` with poses guard, punch(side, reach), kneeLift(side), clap, twist(dir); test files `test/combat_recognisers_test.dart`, `test/rhythm_recognisers_test.dart`: 10/15/30 fps, noise σ 0.006–0.015, dropped frames, occlusion → notVisible; decoys: raiseArms ≠ guard ≠ punch, barrier/forward-push ≠ punch, sway ≠ twist, step ≠ twist, squat ≠ knee lift, arms-crossed ≠ clap. Add recorded clips to the replay accuracy gate (`accuracy.dart`, `tools/recorder/`) before tuning: ≥ 20 players × each move, 2 phones (one budget), recall ≥ 0.9, false-trigger ≤ 1 / 2 min idle.
- `perf_benchmark_test.dart`: all recognisers on < 0.3 ms/frame budget (expect ≈ +0.003 ms).

### 4.5 Renderer
- `forest_game.dart` is lane-perspective (`laneX`, `ForestPainter`). Do **not** branch inside it. Rename shell to a mode-agnostic `MotionGame` (or keep `ForestGame` and add a painter interface) that picks `ForestPainter` for runner and new `app/lib/game/dojo_painter.dart` / `beat_painter.dart` by `level.mode`.
- Dojo/Beat visuals: mirrored hero silhouette centre-screen; targets at fixed body-relative screen anchors (L/R high/mid, centre guard, floor arrows for steps, knee markers); **approach ring** shrinking to the target over `warningMs` — visualises the timing window (ring = window), much clearer than depth for timing. Beat pulse on the floor each beat; grade popups. Same perf discipline as ForestPainter: cached Paints per SceneTheme via Expando, static scratch Paths, binary-search visible targets by `arriveMs`, HUD reassigned only on change. New `SceneTheme.arena` / dance-floor theme per roadmap.
- Audio: music becomes the clock → use a player exposing position (flame_audio/audioplayers `getCurrentPosition`), poll each frame and smooth; licensed original tracks as OGG ~1.5–2.5 MB each (APK < 150 MB unaffected; consider on-demand via `/content` later). 

### 4.6 Perf budget (additions on top of performance.md)
| Item | Budget |
|---|---|
| Pose fps for beat/dojo | ≥ 24 target; 20–24 → half-time; < 15 → pause path |
| Extra recognisers (Dart) | ≤ 0.02 ms/frame total, zero allocations per frame |
| Capture → judged event | < 150 ms upper-mid, < 200 ms budget; compensated by `latencyOffsetMs` |
| Painter (budget tier) | ≤ 6 ms/frame; ≤ 24 visible targets; test like `test/perf_test.dart` (600 frames × themes) |
| Audio clock drift | < 20 ms vs engine clock over 3 min (test with fake player) |
| Music assets | ≤ 3 MB per track, OGG mono/stereo 96–128 kbps |
Keep Lite model; do not switch to Full for these modes on budget tier (+latency); consider Full only on upper-mid tier as an A/B with the replay gate.

## 5. Recommended order
1) Fix Q5-7/8/9 (silent misses, wrist vis) — prerequisite. 2) Calibration fields + BodyFeatures helpers. 3) Guard + lateral Punch recognisers with synthetic + recorded tests. 4) BeatEngine + schema v2 + simulator. 5) DojoPainter + 1 level. 6) KneeLift/Clap/Twist + BeatPainter. Ship clap/twist as "any-direction OK" until recorded data proves direction accuracy.

## Sources
- [BlazePose: On-device Real-time Body Pose tracking (arXiv 2006.10204)](https://arxiv.org/pdf/2006.10204) · [ar5iv](https://ar5iv.labs.arxiv.org/html/2006.10204) · [sotaverified summary](https://sotaverified.org/papers/blazepose-on-device-real-time-body-pose)
- [High Fidelity Pose Tracking with MediaPipe BlazePose and TF.js](https://blog.tensorflow.org/2021/05/high-fidelity-pose-tracking-with-mediapipe-blazepose-and-tfjs.html?hl=tr)
- [flutter_pose_detection (flagship lite timings)](https://pub.dev/packages/flutter_pose_detection) · [mediapipe issue #6041 (GPU delegate no speedup)](https://github.com/google-ai-edge/mediapipe/issues/6041)
- [Monocular pose z limitations (arXiv 2512.06783)](https://arxiv.org/pdf/2512.06783) · [Accuracy and Reliability of Monocular 3D Pose](https://thesai.org/Downloads/Volume17No10/Paper_65-Accuracy_and_Reliability_of_Monocular_3D_Pose.pdf) · [BlazePose GHUM (arXiv 2206.11678)](https://arxiv.org/pdf/2206.11678.pdf) · [Telerehab feasibility](https://ouci.dntb.gov.ua/works/40ZpzPp9)
- [Hand pose robustness, motion blur (arXiv 2303.04566)](https://arxiv.org/pdf/2303.04566) · [Mitigating motion blur, baseball pose](https://astro.paperswithcode.com/paper/mitigating-motion-blur-for-robust-3d-baseball) · [EventHands](https://arxiv.org/pdf/2012.06475)
- [Smartphone Exergames with Real-Time Markerless Motion Capture (arXiv 2507.06669)](https://arxiv.org/pdf/2507.06669) · [Dance game timing window patent](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9358456)
- Numbers marked "estimate" (pipeline latency, FOV fill, blur distance) are first-principles and must be confirmed on device via the debug screen (performance.md §How to measure).
