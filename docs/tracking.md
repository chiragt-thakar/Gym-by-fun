# Tracking engine

How Joynetic turns camera landmarks into game input, and how to build on it.
Code: `packages/motion_core` (pure Dart, no Flutter), `native/pose_bridge`
(camera + pose model), `app/lib/services/pose_service.dart` (the live session).

Nothing in `motion_core` knows about any game. A game consumes a `MotionInput`
(events + signals + tracking state) and never sees a landmark, a pixel, the
camera distance or the player's height.

## Pipeline

```
camera frame (native, never leaves the phone)
  → MediaPipe Pose Landmarker            latest frame only, no queue
  → flat landmark list (33 per body)     the only thing that crosses into Dart
  → BodyTracker
      SubjectLock            which body is the player
      FacingCanonicaliser    "left" is always the player's own left
      QualityGate            good / degraded / bad, with the reason
      LandmarkStabiliser     One Euro filter + confidence gate + gap prediction
      TrackingStateMachine   tracking / degraded / lost / recovering
  → TrackedFrame             what every screen draws and decides on
  → MotionEngine
      BodyFeatures           body measurements of one frame
      detectors              plug-in state machines, in the player's own range
      DriftCorrector         keeps the calibration valid as the player moves
  → MotionEvent (discrete) + MotionSignals (continuous)
```

| Class | File | Job |
|---|---|---|
| `BodyTracker`, `TrackedFrame` | `body_tracker.dart` | The game-agnostic front end. One per camera session. |
| `SubjectLock`, `FacingCanonicaliser` | `subject_lock.dart` | Primary-player lock; left/right convention. |
| `QualityGate`, `FrameQuality` | `quality_gate.dart` | Per-frame grading. Stateless. |
| `LandmarkStabiliser` | `stabiliser.dart` | Filtering, gating, short-gap prediction. |
| `TrackingStateMachine` | `tracking_state.dart` | Debounced state. |
| `Calibrator`, `CalibrationProfile`, `CalibrationReport` | `calibration.dart` | Guided calibration, the body model, its quality. |
| `DriftCorrector` | `drift.dart` | Passive re-positioning of the profile. |
| `Recogniser` (= `MotionDetector`), built-ins | `recognisers.dart`, `extra_recognisers.dart`, `detectors.dart` | Gesture detection. |
| `DetectorRegistry`, `DetectorSpec` | `detectors.dart` | Plug-in registry. |
| `MotionSignals`, `MotionInput` | `signals.dart` | What games consume. |
| `MotionEngine` | `motion_engine.dart` | Wires the above for one session. |

## Why tracking used to drop, and what changed

The old engine paused the game whenever *any one* of nine landmarks (nose,
shoulders, hips, knees, ankles) dipped under 0.5 visibility or came within 1 %
of the image edge for 250 ms. Ankles at 2 m flicker around that level all the
time, and a lean or a squat pushes a wrist, knee or foot to the edge. So moving
"a little" paused the game.

| Root cause | Fix |
|---|---|
| All-or-nothing quality gate | Graded: only the torso (shoulders + hips) is required. Anything else is `degraded` and play continues; each detector checks the landmarks it needs. |
| Squat needed the ankles | With the feet hidden the squat is read from the hip-to-knee span (calibrated too). |
| No memory across frames | A landmark that drops out coasts on its filtered velocity for ≤ 250 ms; a whole-body gap shorter than the pause time is bridged. |
| The same thresholds to pause and to resume | Every transition has its own dwell time (see the state machine). |
| The estimator dropped the body at 0.5 presence/tracking confidence | Lowered to 0.4 natively; our own per-landmark gating does the judging. |
| Calibration was in raw image units at one spot | Every length is a multiple of the torso; the profile is re-positioned automatically when the player ends up nearer, further or elsewhere. |
| Arcade games ran only on "perfect" frames | They run on any frame whose torso is tracked. |
| A passer-by could take over | The player is locked; a body elsewhere is ignored. |
| Raise-arms trusted a wrist that had left the image | An untrusted wrist is not believed; the elbow decides. |

## SubjectLock — one player

The estimator can report several bodies (`maxPoses` > 1, a setting) or, with
one, jump to a bystander when the player is briefly hidden.

- **Locked**: accept the body whose torso centre is within
  `maxJumpTorso + maxSpeedTorsoPerS × gap` torso lengths of the player's last
  position (0.6 + 3.0 × seconds) and whose scale is plausible. With several
  candidates, the nearest wins.
- **Only strangers in view**: the frame is reported person-less. A passer-by
  cannot play, and cannot teach the calibration anything.
- **Player gone for `reacquireAfterMs` (600 ms)**: the most prominent body
  (large, central, visible) becomes the player. This is also how stepping out
  and coming back works — no restart, no re-calibration.

`FacingCanonicaliser`: a pose model labels left/right from what the person in
the image looks like, so depending on where the image is mirrored a player can
arrive with left and right indices exchanged. It watches which shoulder index
sits on which side and swaps every pair when the evidence is sustained (leaky
integrator, hysteresis at ±0.8). After it, landmark "left" is always the
player's own left = smaller x in the selfie frame.

## QualityGate — graded frames

| Level | Meaning | Play |
|---|---|---|
| `good` | Whole body in frame and visible | yes |
| `degraded` | Torso tracked; something else is not ideal (`issue` says what) | yes |
| `bad` | Nobody, or the torso hidden / outside the image / far too small | no |

`issue` is the first thing wrong in a fixed order (`outOfFrame`,
`lowVisibility`, `tooClose`, `tooFar`) so guidance never flickers between
reasons. "Too far" has a slack band (`farSlack` 0.85): a player hovering at the
minimum size is degraded, not paused. Standing height is estimated from the
torso as well as the bounding box, so a squat never reads as "too far".

## LandmarkStabiliser — filter, gate, predict

For each of the 33 landmarks:

1. **Trusted** (visibility ≥ 0.5): One Euro filter on x and y
   (`minCutoff` 1.7 Hz, `beta` 0.3, derivative cut-off 1 Hz). The cut-off rises
   with speed, so a still body is steady and a fast move is not held back.
2. **Not trusted, last trusted ≤ 250 ms ago**: the measurement is ignored and
   the landmark coasts: `p = p₀ + v·τ·(1 − e^(−Δt/τ))`, τ = 120 ms. Travel is
   bounded by `v·τ`, so a prediction cannot run away. It is reported at exactly
   the trust level, and listed in `TrackedFrame.predicted`.
3. **Not trusted for longer**: passed through smoothly with its true low
   visibility. The detector that needs it then declines to act.

A frame with no usable body returns a coasted copy of the last one
(`TrackedFrame.coasted`) for display. **A coasted frame never drives a
detector** and never teaches the calibration.

> **Tuning note.** The filter constants are the ones the replay accuracy gate
> was tuned on, and are unchanged. In normalised coordinates `beta` 0.3 adds
> little cut-off at typical speeds, so fast moves see roughly 80 ms of filter
> lag. A lower-lag candidate is `minCutoff` 1.2, `beta` 4.0. Try it by passing a
> `StabiliserConfig` in `BodyTrackerConfig`, and adopt it only if
> `dart test` (the 90 % recall / < 1 false trigger per minute gate) still
> passes and it feels right on the target phones.

## TrackingStateMachine

```
           unusable ≥ pauseAfter (250 ms)
 tracking ───────────────────────────────▶ lost ◀── unusable ──┐
   ▲   │ imperfect ≥ degradeAfter (400 ms)   │ usable           │
   │   ▼        (or any unusable frame)      ▼                  │
   └ degraded ◀──── usable ≥ resumeAfter (300 ms) ──── recovering
 clean ≥ settle (300 ms)
```

| State | Game | Feedback |
|---|---|---|
| `tracking` | plays | green dot |
| `degraded` | plays | green dot; a quiet "partial view" in diagnostics; the screen edge glows amber only when drifting out sideways |
| `lost` | holds, nothing is lost (rule 5) | the frame finder grows, one spoken direction |
| `recovering` | holds for a short steady spell | "Back in the frame!" |

Time is the frame clock, so the machine is deterministic under replay. The
light is red while holding, amber during a bridged gap, green otherwise.

## Calibration

Guided, hands-free, about 30 s: stand still (2 s), arms up, two squats, lean
left, lean right. `Calibrator` is a state machine; the app feeds it stabilised,
measured frames whose torso is tracked.

**Robust measurement** — every stored value is a statistic over many frames:

| Value | Statistic |
|---|---|
| Standing baseline, torso, shoulder / hip width, thigh span, arm length, camera roll | median over the still window |
| Reach | 10th percentile of the held wrist height |
| Squat depth | median over reps of each rep's bottom; within a rep the single lowest frame is dropped |
| Lean range | 90th percentile of the held shift |

Floors (`minSquatDepthTorso`, `minLeanRangeTorso`) stop a timid calibration from
creating a hair trigger. A step the player cannot finish in 20 s of in-frame
time uses a population default — never a failure.

**The profile (version 2)** holds the range (squat depth, lean each way, reach,
side step), the body model (torso, leg and thigh span, shoulder and hip width,
arm length), the standing position, and the conditions (body height in the
image = camera distance, camera roll, aspect, `feetVisible`, `quality`).
Version 1 profiles load with population proportions for the missing values.
JSON is a flat string → number map (the server's opt-in backup stores exactly
that).

**Body-relative.** Every length is a multiple of `standingTorso`.
`rebase(torso, hipX, hipY, …)` re-expresses the whole profile at another
distance and spot. Detectors divide by profile values, so every measure is a
fraction of the player's own range.

**Quality.** `Calibrator.report` → `CalibrationReport(score 0..1, issues)`.
Starts at 1 and loses points for: unsteady standing, faint landmarks, hidden
feet, too far / too close, low frame rate, a tilted camera, standing side-on,
skipped steps, uneven squats, uneven leans. `good` ≥ 0.75, `fair` ≥ 0.5, else
`poor`. `Calibrator.conditions` names problems while they happen (spoken as one
fix at a time). A poor result is explained and repeated once automatically; a
second poor result is kept, because play must never be blocked by the room the
player has.

**Quick re-calibration.** `Calibrator(base: profile)` runs only the standing
step and rebases `base`: five seconds for a new spot.

**Per-user profiles.** `Settings.player` + `otherPlayers` in the app: each
person who shares the device keeps their own profile.

## DriftCorrector — passive drift correction

It learns only from frames in which the player is demonstrably standing
neutral, judged *without trusting the calibrated scale*: feet and torso
visible, the leg / torso ratio within 10 % of the calibrated standing ratio
(so not squatting or bending), torso upright, body still. Over 1.5 s of that it
takes medians and:

- **scale** differs by more than 6 % → rebase;
- **spot** differs by more than one torso length (0.5 vertically), held 2.5 s
  → rebase (the longer wait keeps a held side step a side step).

Inside the dead band it does nothing, so ordinary play uses exactly what was
calibrated. `MotionEngine.liveCalibration` is the current profile;
`calibration` stays the original.

## Detectors

A detector implements `Recogniser`: `id`, `state`, `measure`, `update`,
`interrupt`, `recalibrate`. Rules every detector follows:

- **Hysteresis**: separate start and end levels.
- **Debounce**: `confirmFrames` consecutive frames, or a hold time.
- **Cooldown** where a repeat would be a double count.
- **Visibility**: check the landmarks you read; when they are not trusted,
  do nothing (or reject once with `notVisible`).
- **Own range**: measure in fractions of the calibrated profile.

| Id | Events | Config | Notes |
|---|---|---|---|
| `squat` | `MoveStarted/Held/Ended`, `RepCompleted`, `MoveRejected` | `MotionThresholds` | Core. Feet-hidden fallback to the thigh span. |
| `lean` | same | `MotionThresholds` | Core. `sideStepLanes` uses the hip shift instead. |
| `raiseArms` | same | `MotionThresholds` | Core. Elbow decides when the wrist is not trusted. |
| `barrierHold` | `ExtraMove…` | `ExtraMoveThresholds` | Opt-in. |
| `sideStep` | `ExtraMove…` | `ExtraMoveThresholds` | Opt-in. |
| `jump` | `GestureEvent` fired / ended | `JumpConfig` | Opt-in (low impact by default). Hips *and* feet rise above a slow standing baseline. |
| `punch` | `GestureEvent` fired, `side` | `PunchConfig` | Arm-extension speed and travel. Image plane by default (`depthWeight` 0). |
| `twist` | `GestureEvent` started / held / ended, `side` | `TwistConfig` | cos θ = seen / calibrated shoulder width; side from shoulder depth. |
| `kneeLift` | `GestureEvent` fired, `side` | `KneeLiftConfig` | Height difference between the knees. |

`SwingRecogniser` and `PoseMatcher` work on `BodyPose` and are used directly by
the games that need them.

### Add a gesture

1. Write the detector (≈ 60 lines) with a typed config class:

```dart
class ClapConfig { const ClapConfig({this.maxGapTorso = 0.25}); final double maxGapTorso; }

class ClapDetector implements Recogniser {
  ClapDetector(this.cal, [this.c = const ClapConfig()]);
  CalibrationProfile cal;
  final ClapConfig c;
  bool _together = false;
  double _measure = 0;

  @override String get id => 'clap';
  @override String get state => _together ? 'together' : 'apart';
  @override double get measure => _measure;
  @override void recalibrate(CalibrationProfile p) => cal = p;

  @override
  void update(BodyFeatures b, List<MotionEvent> out) {
    const v = BodyFeatures.trustVisibility;
    if (b.leftWrist.visibility < v || b.rightWrist.visibility < v) return;
    final gap = landmarkDistance(b.leftWrist, b.rightWrist) / cal.standingTorso;
    _measure = gap;
    if (!_together && gap < c.maxGapTorso) {
      _together = true;
      out.add(GestureEvent('clap', GesturePhase.fired, b.timestampMs));
    } else if (_together && gap > c.maxGapTorso * 2) {   // hysteresis
      _together = false;
    }
  }

  @override void interrupt(int ts, List<MotionEvent> out) => _together = false;
}
```

2. Register it and ask for it:

```dart
final registry = DetectorRegistry.standard()
  ..register('clap', (ctx, cfg) => ClapDetector(ctx.calibration, cfg as ClapConfig? ?? const ClapConfig()));

MotionEngine(calibration: profile, registry: registry,
    detectors: const [DetectorSpec('clap', ClapConfig(maxGapTorso: 0.2))]);
```

3. Test it with exact geometry (`stickFrame`) or a scripted body
   (`SyntheticSession`), as in `test/detectors_test.dart`.

No change to the engine, the events or any other game.

### Add a game

A game takes a `MotionInput`:

```dart
abstract interface class MotionInput {
  Stream<MotionEvent> get events;      // MoveStarted, GestureEvent, TrackingPaused …
  MotionSignals get signals;           // squat, lean, sideStep, armLeft/Right, hipX, hipRise
  TrackingState get trackingState;
}
```

In the app that is a `MotionSession` created with the detectors the game wants:

```dart
MotionSession(source, initialCalibration: profile,
    detectors: const [DetectorSpec(DetectorIds.punch), DetectorSpec(DetectorIds.kneeLift)]);
```

Game rules live in `packages/game_director` (pure Dart, simulated in tests) and
react to events; a recognised move does nothing on its own (rule 6). Hold while
`trackingState` is `lost` or `recovering`; never punish it (rule 5).

## Testing without a camera

| Mode | How | Use |
|---|---|---|
| Unit / replay | `dart test` in `packages/motion_core` | Filters, calibration maths, detectors, state machines, the accuracy gate. |
| Recorded | `tools/recorder` replays landmark recordings; the app's Recorder screen makes them (landmarks only, with consent) | Accuracy on real bodies. |
| Simulated app | `flutter run --dart-define=JOYNETIC_INPUT=sim` | A scripted synthetic body drives every screen, including calibration. |
| Recorded app | `--dart-define=JOYNETIC_INPUT=recorded` | Replays the newest recording saved on the device. |

Simulated input is compiled in only by that flag; a release build always uses
the camera (rule 1).

## Diagnostics overlay

Settings → Tracking → **Diagnostics overlay** shows, over every camera screen:
the skeleton coloured by confidence (teal ≥ 0.8, amber ≥ 0.5, red below; hollow
rings are predicted landmarks), tracking state, frame quality and reason, body
size, predicted count, ignored bystanders, whether left/right is being swapped,
calibration version / quality / live scale / number of drift corrections, fps,
inference and Dart time, delegate, device tier, and every detector's state and
measure. Profile → Tracking diagnostics is the full-page version with an event
log and every plug-in detector switched on.

## Performance and failure handling

- **Latest frame only**: CameraX `STRATEGY_KEEP_ONLY_LATEST`; a frame that
  arrives while inference is busy is closed unprocessed. No queue anywhere.
- **Off the UI thread**: capture, rotation and inference run on one native
  executor; Dart receives a typed double list and does ~tens of microseconds of
  work per frame.
- **Low frame rate**: every threshold that matters is in milliseconds, and the
  filter is time-aware. If the accurate model cannot hold 15 fps the session
  falls back to the light model once.
- **Stalled camera**: no frame for 500 ms → moves end without credit and the
  game holds. No frame for 2.5 s → the camera is restarted (three attempts,
  each wait longer); then `MotionSession.cameraLost` is set for the UI.
- **Camera errors** (in use by another app, disabled, fatal) are reported from
  CameraX and treated as lost tracking; CameraX reopens the camera when it can.

## Things to verify on a phone

These could not be exercised without a device and are the first things to
check: see the "what to test first" list in `docs/progress.md`.
