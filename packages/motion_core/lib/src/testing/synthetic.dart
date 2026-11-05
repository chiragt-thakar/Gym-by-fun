import 'dart:math' as math;

import '../calibration.dart';
import '../events.dart';
import '../landmarks.dart';
import '../one_euro_filter.dart';
import '../recording.dart';

/// TEST SUPPORT ONLY. A seeded, parametric 2-D body that produces landmark
/// frames for replay tests until real recordings exist. Never wired into the
/// app (non-negotiable rule 1): real on-device pose estimation drives the
/// game. Recordings built here are tagged `meta.synthetic = true`.
class SyntheticBody {
  SyntheticBody({
    this.height = 0.62,
    this.centerX = 0.5,
    this.footY = 0.93,
    this.noise = 0.003,
    this.lowLegVisibility = false,
    int seed = 1,
  }) : _rng = math.Random(seed);

  /// Standing body height as a fraction of image height.
  final double height;
  final double centerX;
  final double footY;

  /// Std-dev of per-coordinate landmark jitter (normalised units).
  final double noise;

  /// Loose clothing (kurta, saree): knee and hip visibility hovers ~0.55–0.75.
  final bool lowLegVisibility;

  final math.Random _rng;

  double _gauss() {
    // Box–Muller.
    final u1 = 1 - _rng.nextDouble(), u2 = _rng.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }

  /// Produces 33 landmarks for a pose.
  ///
  /// [squat] 0..1 of a comfortable squat (hips drop 0.20 H).
  /// [lean] −1..1, a comfortable lean to the player's left/right.
  /// [arms] 0 = by the sides, 1 = both wrists well above the head.
  /// [oneArm] raise only the right arm.
  /// [bend] 0..1 forward bend at the hips (hips stay up).
  /// [step] horizontal hip translation in H units (side step / walking).
  List<Landmark> pose({
    double squat = 0,
    double lean = 0,
    double arms = 0,
    bool oneArm = false,
    double bend = 0,
    double step = 0,
  }) {
    final h = height;
    final cx = centerX + step * h;
    final ankleY = footY - 0.04 * h;
    final kneeY = ankleY - 0.26 * h + 0.03 * h * squat;
    final hipY = ankleY - 0.51 * h + 0.20 * h * squat;
    final torso = 0.30 * h;
    final tilt =
        squat * 0.15 + bend * 0.85; // forward tilt → 2-D foreshortening
    final shY = hipY - torso * (1 - tilt);
    final shX = cx + lean * 0.12 * h;
    final noseY = shY - 0.13 * h * (1 - bend * 0.5);
    final noseX = cx + lean * 0.15 * h;
    final kneeSpread = 0.07 * h + 0.03 * h * squat;

    Landmark wrist(double side, double raise) {
      final downY = hipY + 0.02 * h;
      final upY = noseY - 0.15 * h;
      final y = downY + (upY - downY) * raise;
      final x = shX + side * (0.13 * h - 0.05 * h * raise);
      return Landmark(x, y, 0, 0.95);
    }

    final legVis = lowLegVisibility ? 0.55 + _rng.nextDouble() * 0.2 : 0.95;
    final lm =
        List<Landmark>.filled(Lm.count, const Landmark(0.5, 0.5, 0, 0.3));
    void set(int i, double x, double y, [double v = 0.97]) =>
        lm[i] = Landmark(x, y, 0, v);

    // Selfie view: player's left is smaller x.
    set(Lm.nose, noseX, noseY);
    for (var i = 1; i <= 10; i++) {
      set(i, noseX + (i.isOdd ? -0.02 : 0.02) * h, noseY - 0.01 * h, 0.9);
    }
    set(Lm.leftShoulder, shX - 0.11 * h, shY);
    set(Lm.rightShoulder, shX + 0.11 * h, shY);
    final lw = wrist(-1, oneArm ? 0 : arms);
    final rw = wrist(1, arms);
    lm[Lm.leftWrist] = lw;
    lm[Lm.rightWrist] = rw;
    set(Lm.leftElbow, (shX - 0.11 * h + lw.x) / 2, (shY + lw.y) / 2);
    set(Lm.rightElbow, (shX + 0.11 * h + rw.x) / 2, (shY + rw.y) / 2);
    for (final (i, w) in [
      (17, lw),
      (19, lw),
      (21, lw),
      (18, rw),
      (20, rw),
      (22, rw)
    ]) {
      lm[i] = w;
    }
    set(Lm.leftHip, cx - 0.07 * h, hipY, legVis);
    set(Lm.rightHip, cx + 0.07 * h, hipY, legVis);
    set(Lm.leftKnee, cx - kneeSpread, kneeY, legVis);
    set(Lm.rightKnee, cx + kneeSpread, kneeY, legVis);
    set(Lm.leftAnkle, cx - 0.07 * h, ankleY);
    set(Lm.rightAnkle, cx + 0.07 * h, ankleY);
    for (final i in [29, 31]) {
      set(i, cx - 0.08 * h, ankleY + 0.02 * h);
    }
    for (final i in [30, 32]) {
      set(i, cx + 0.08 * h, ankleY + 0.02 * h);
    }

    if (noise == 0) return lm;
    return [
      for (final l in lm)
        Landmark(
            l.x + _gauss() * noise, l.y + _gauss() * noise, l.z, l.visibility)
    ];
  }
}

/// What the synthetic player does during one action.
enum Action {
  squat,
  leanLeft,
  leanRight,
  raiseArms,
  oneArmRaise,

  // Decoys: none of these may trigger a move.
  shallowDip,
  sway,
  forwardBend,
  armsToChest,
  sideShuffle,
  idle,
}

class ScriptStep {
  const ScriptStep(this.action, this.durationMs, {this.intensity = 1});
  final Action action;
  final int durationMs;
  final double intensity;
}

/// Turns a script of actions into a labelled [LandmarkRecording].
class SyntheticSession {
  SyntheticSession(this.body, {this.fps = 30, this.easeMs = 280, int seed = 7})
      : _rng = math.Random(seed);

  final SyntheticBody body;
  final int fps;
  final int easeMs;
  final math.Random _rng;

  static Move? labelFor(Action a) => switch (a) {
        Action.squat => Move.squat,
        Action.leanLeft => Move.leanLeft,
        Action.leanRight => Move.leanRight,
        Action.raiseArms || Action.oneArmRaise => Move.raiseArms,
        _ => null,
      };

  /// Frames for the guided calibration routine (still, arms up, 2 squats,
  /// lean left, lean right).
  List<PoseFrame> calibrationFrames({int startMs = 0}) => _render([
        const ScriptStep(Action.idle, 2600),
        const ScriptStep(Action.raiseArms, 1400),
        const ScriptStep(Action.idle, 400),
        const ScriptStep(Action.squat, 1400),
        const ScriptStep(Action.idle, 400),
        const ScriptStep(Action.squat, 1400),
        const ScriptStep(Action.idle, 400),
        const ScriptStep(Action.leanLeft, 1400),
        const ScriptStep(Action.idle, 400),
        const ScriptStep(Action.leanRight, 1400),
        const ScriptStep(Action.idle, 600),
      ], startMs, null);

  /// Calibrates with the real [Calibrator] on synthetic calibration frames.
  CalibrationProfile calibrate() {
    final c = Calibrator();
    final smoother = LandmarkSmoother();
    for (final f in calibrationFrames()) {
      c.add(smoother.smooth(f));
    }
    return c.build();
  }

  LandmarkRecording record(List<ScriptStep> script,
      {CalibrationProfile? calibration, Map<String, Object?>? meta}) {
    final labels = <MoveLabel>[];
    final frames = _render(script, 0, labels);
    return LandmarkRecording(
      frames: frames,
      labels: labels,
      calibration: calibration,
      meta: {'synthetic': true, 'fps': fps, ...?meta},
    );
  }

  /// A random mix of real moves and decoys, about [minutes] long.
  List<ScriptStep> randomScript(double minutes, {bool decoys = true}) {
    final steps = <ScriptStep>[const ScriptStep(Action.idle, 1500)];
    var t = 1500;
    const real = [
      Action.squat,
      Action.leanLeft,
      Action.leanRight,
      Action.raiseArms,
    ];
    const fakes = [
      Action.shallowDip,
      Action.sway,
      Action.forwardBend,
      Action.armsToChest,
      Action.sideShuffle,
    ];
    while (t < minutes * 60000) {
      final useDecoy = decoys && _rng.nextDouble() < 0.35;
      final a = useDecoy
          ? fakes[_rng.nextInt(fakes.length)]
          : real[_rng.nextInt(real.length)];
      final d = 900 + _rng.nextInt(900);
      final intensity = useDecoy ? 1.0 : 0.85 + _rng.nextDouble() * 0.3;
      steps
        ..add(ScriptStep(a, d, intensity: intensity))
        ..add(ScriptStep(Action.idle, 500 + _rng.nextInt(1200)));
      t += d + 1100;
    }
    return steps;
  }

  List<PoseFrame> _render(
      List<ScriptStep> script, int startMs, List<MoveLabel>? labels) {
    final frames = <PoseFrame>[];
    final dt = 1000 / fps;
    var t0 = startMs.toDouble();
    for (final s in script) {
      final move = labelFor(s.action);
      if (move != null && labels != null) {
        labels.add(MoveLabel(move, t0.round(), (t0 + s.durationMs).round()));
      }
      for (var t = 0.0; t < s.durationMs; t += dt) {
        final env = _envelope(t, s.durationMs.toDouble()) * s.intensity;
        final jitter = _rng.nextInt(5) - 2;
        final ts = (t0 + t).round() + jitter;
        // Gentle breathing / postural sway on every frame.
        final breath = math.sin((t0 + t) / 900) * 0.04;
        frames.add(PoseFrame(
          timestampMs: ts,
          imageWidth: 480,
          imageHeight: 640,
          landmarks: _poseFor(s.action, env, breath),
        ));
      }
      t0 += s.durationMs;
    }
    return frames;
  }

  double _envelope(double t, double d) {
    final e = math.min(easeMs.toDouble(), d / 3);
    if (t < e) return _smoothstep(t / e);
    if (t > d - e) return _smoothstep((d - t) / e);
    return 1;
  }

  static double _smoothstep(double x) {
    final c = x.clamp(0.0, 1.0);
    return c * c * (3 - 2 * c);
  }

  List<Landmark> _poseFor(Action a, double env, double breath) => switch (a) {
        Action.squat => body.pose(squat: env, lean: breath),
        Action.leanLeft => body.pose(lean: -env),
        Action.leanRight => body.pose(lean: env),
        Action.raiseArms => body.pose(arms: env, lean: breath),
        Action.oneArmRaise => body.pose(arms: env, oneArm: true),
        Action.shallowDip => body.pose(squat: 0.22 * env, lean: breath),
        Action.sway => body.pose(lean: 0.22 * env * (breath >= 0 ? 1 : -1)),
        Action.forwardBend => body.pose(bend: 0.6 * env),
        Action.armsToChest => body.pose(arms: 0.45 * env),
        Action.sideShuffle => body.pose(step: 0.25 * env, lean: breath),
        Action.idle => body.pose(lean: breath),
      };
}
