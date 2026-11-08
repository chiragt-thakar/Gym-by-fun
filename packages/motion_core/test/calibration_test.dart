import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:test/test.dart';

void main() {
  test('guided calibration measures the player range', () {
    final body = SyntheticBody(height: 0.6, seed: 2);
    final session = SyntheticSession(body);
    final c = Calibrator();
    final smoother = LandmarkSmoother();
    final steps = <CalibrationStep>{};
    for (final f in session.calibrationFrames()) {
      c.add(smoother.smooth(f));
      steps.add(c.step);
    }
    expect(c.step, CalibrationStep.done);
    expect(steps, containsAll(CalibrationStep.values));
    final p = c.build();
    // Synthetic body: a comfortable squat drops hips by 0.20 H, lean is 0.12 H.
    expect(p.squatDepth, closeTo(0.20 * 0.6, 0.02));
    expect(p.leanRangeLeft, closeTo(0.12 * 0.6, 0.015));
    expect(p.leanRangeRight, closeTo(0.12 * 0.6, 0.015));
    expect(p.standingTorso, closeTo(0.30 * 0.6, 0.01));
  });

  test('a timid calibration is clamped to safe minimums', () {
    final c = Calibrator();
    // Never moves: stays in squats step.
    final body = SyntheticBody(noise: 0);
    for (var t = 0; t < 3000; t += 33) {
      c.add(PoseFrame(timestampMs: t, landmarks: body.pose()));
    }
    expect(c.step, CalibrationStep.armsUp);
    expect(() => c.build(), throwsStateError);
  });

  test('a squat counts even if the player does not stand fully straight', () {
    // Real players rarely return to the exact standing leg span between
    // squats; landmark noise at 2–2.5 m adds to that. Return to 9 % of a
    // comfortable squat must still count.
    final body = SyntheticBody(noise: 0);
    final c = Calibrator();
    var t = 0;
    void hold(double squat, int ms) {
      for (final end = t + ms; t < end; t += 33) {
        c.add(PoseFrame(timestampMs: t, landmarks: body.pose(squat: squat)));
      }
    }

    hold(0, 2200);
    expect(c.step, CalibrationStep.armsUp);
    expect(c.skip(), isTrue);
    for (var i = 0; i < 2; i++) {
      hold(0.8, 500);
      hold(0.09, 500);
    }
    expect(c.squatsDone, 2);
    expect(c.step, CalibrationStep.leanLeft);
  });

  test('neutral cannot be skipped; other steps fall back to gentle defaults',
      () {
    final body = SyntheticBody(noise: 0);
    final c = Calibrator();
    expect(c.skip(), isFalse);
    var t = 0;
    for (; t < 2200; t += 33) {
      c.add(PoseFrame(timestampMs: t, landmarks: body.pose()));
    }
    expect(c.step, CalibrationStep.armsUp);
    while (c.step != CalibrationStep.done) {
      expect(c.skip(), isTrue);
    }
    expect(c.skipped, {
      CalibrationStep.armsUp,
      CalibrationStep.squats,
      CalibrationStep.leanLeft,
      CalibrationStep.leanRight,
    });
    final p = c.build();
    final d = CalibrationProfile.fromStanding(
      PoseFrame(timestampMs: 0, landmarks: body.pose()),
    );
    expect(p.squatDepth, closeTo(d.squatDepth, 0.005));
    expect(p.leanRangeLeft, closeTo(d.leanRangeLeft, 0.005));
    expect(p.leanRangeRight, closeTo(d.leanRangeRight, 0.005));
    expect(p.reachY, closeTo(d.reachY, 0.005));
    expect(p.standingTorso, closeTo(d.standingTorso, 0.005));
  });

  test('a skipped step keeps what was already measured', () {
    final body = SyntheticBody(noise: 0);
    final c = Calibrator();
    var t = 0;
    for (; t < 2200; t += 33) {
      c.add(PoseFrame(timestampMs: t, landmarks: body.pose()));
    }
    c.skip(); // arms
    // One deep squat, then the player gives up on the second.
    for (final s in [0.0, 0.5, 1.0, 0.5, 0.0, 0.6, 1.0]) {
      c.add(PoseFrame(timestampMs: t += 200, landmarks: body.pose(squat: s)));
    }
    expect(c.step, CalibrationStep.squats);
    c.skip();
    c.skip();
    c.skip();
    // Synthetic comfortable squat drops the hips by 0.20 H.
    expect(c.build().squatDepth, closeTo(0.20 * body.height, 0.01));
  });

  test('step time counts only time with frames (out of frame is free)', () {
    final body = SyntheticBody(noise: 0);
    final c = Calibrator(stillMs: 100000); // stay in neutral
    for (var t = 0; t <= 990; t += 33) {
      c.add(PoseFrame(timestampMs: t, landmarks: body.pose()));
    }
    expect(c.stepActiveMs, 990);
    // Ten seconds out of frame (no gated frames) adds at most one gap.
    c.add(PoseFrame(timestampMs: 11000, landmarks: body.pose()));
    expect(c.stepActiveMs, 990 + Calibrator.maxGapMs);
  });

  test('step time restarts on every new step', () {
    final body = SyntheticBody(noise: 0);
    final c = Calibrator();
    for (var t = 0; t < 2300; t += 33) {
      c.add(PoseFrame(timestampMs: t, landmarks: body.pose()));
    }
    expect(c.step, CalibrationStep.armsUp);
    expect(c.stepActiveMs, lessThan(300));
    c.skip();
    expect(c.stepActiveMs, 0);
  });

  test('profile round-trips through JSON', () {
    final p = CalibrationProfile.fromStanding(
        PoseFrame(timestampMs: 0, landmarks: SyntheticBody(noise: 0).pose()));
    final q = CalibrationProfile.fromJson(p.toJson());
    expect(q.toJson(), p.toJson());
  });

  test('drift is detected when the player moves closer', () {
    final far = SyntheticBody(noise: 0, height: 0.55);
    final near = SyntheticBody(noise: 0, height: 0.75);
    final p = CalibrationProfile.fromStanding(
        PoseFrame(timestampMs: 0, landmarks: far.pose()));
    BodyFeatures feat(SyntheticBody b) =>
        BodyFeatures.from(PoseFrame(timestampMs: 0, landmarks: b.pose()));
    expect(p.hasDrifted(feat(far)), isFalse);
    expect(p.hasDrifted(feat(near)), isTrue);
  });
}
