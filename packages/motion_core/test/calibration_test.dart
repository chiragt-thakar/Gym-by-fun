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
