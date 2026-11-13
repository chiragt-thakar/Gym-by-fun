import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:test/test.dart';

BodyFeatures feat(SyntheticBody b, int t,
        {double squat = 0, double lean = 0}) =>
    BodyFeatures.from(PoseFrame(
        timestampMs: t, landmarks: b.pose(squat: squat, lean: lean)));

/// Feeds [ms] of one pose; returns the last correction made (if any).
CalibrationProfile? feed(DriftCorrector d, SyntheticBody b, int from, int ms,
    {double squat = 0, double lean = 0}) {
  CalibrationProfile? last;
  for (var t = from; t < from + ms; t += 33) {
    last = d.observe(feat(b, t, squat: squat, lean: lean)) ?? last;
  }
  return last;
}

void main() {
  final far = SyntheticBody(noise: 0, height: 0.55);
  final near = SyntheticBody(noise: 0, height: 0.70, footY: 0.95);
  CalibrationProfile profileOf(SyntheticBody b) =>
      CalibrationProfile.fromStanding(
          PoseFrame(timestampMs: 0, landmarks: b.pose()));

  test('inside the dead band nothing is ever corrected', () {
    final p = profileOf(far);
    final d = DriftCorrector(p);
    // A little closer (3 %) and a little to the side: normal play.
    final close = SyntheticBody(noise: 0, height: 0.566, centerX: 0.53);
    expect(feed(d, close, 0, 10000), isNull);
    expect(d.rebases, 0);
    expect(identical(d.profile, p), isTrue);
  });

  test('moving closer re-scales the profile after a steady spell', () {
    final p = profileOf(far);
    final d = DriftCorrector(p);
    expect(feed(d, near, 0, 1400), isNull, reason: 'not before the dwell');
    final q = feed(d, near, 1400, 400);
    expect(q, isNotNull);
    expect(d.rebases, 1);
    expect(q!.standingTorso, closeTo(0.30 * 0.70, 1e-6));
    expect(q.squatDepthTorso, closeTo(p.squatDepthTorso, 1e-9));
    expect(q.hasDrifted(feat(near, 0)), isFalse);
    // And then it is stable: no further corrections.
    expect(feed(d, near, 1800, 5000), isNull);
    expect(d.rebases, 1);
  });

  test('a held squat or lean is never mistaken for standing closer', () {
    final d = DriftCorrector(profileOf(far));
    expect(feed(d, near, 0, 4000, squat: 1), isNull);
    expect(feed(d, near, 4000, 4000, lean: 1), isNull);
    expect(feed(d, near, 8000, 4000, lean: -1), isNull);
    expect(d.rebases, 0);
  });

  test('movement restarts the dwell', () {
    final d = DriftCorrector(profileOf(far));
    final nearLeft = SyntheticBody(
        noise: 0, height: 0.70, footY: 0.95, centerX: 0.42);
    // Alternating spots every second: never still long enough.
    for (var i = 0; i < 6; i++) {
      expect(feed(d, i.isEven ? near : nearLeft, i * 1000, 1000), isNull);
    }
  });

  test('a new spot is adopted only after the longer dwell', () {
    final here = SyntheticBody(noise: 0);
    final there = SyntheticBody(noise: 0, centerX: 0.75);
    final p = profileOf(here);
    final d = DriftCorrector(p);
    expect(feed(d, there, 0, 2400), isNull);
    final q = feed(d, there, 2400, 300);
    expect(q, isNotNull);
    expect(q!.standingHipX, closeTo(0.75, 1e-9));
    expect(q.standingTorso, closeTo(p.standingTorso, 1e-9));
  });

  test('a side step that is held stays a side step', () {
    final here = SyntheticBody(noise: 0);
    final p = profileOf(here);
    final d = DriftCorrector(p);
    // 0.2 body heights to the side is under one torso length.
    final stepped = SyntheticBody(noise: 0, centerX: 0.5 + 0.2 * here.height);
    expect(feed(d, stepped, 0, 10000), isNull);
  });

  test('hidden feet give no evidence', () {
    final d = DriftCorrector(profileOf(far));
    for (var t = 0; t < 4000; t += 33) {
      final lm = near.pose();
      for (final i in [Lm.leftAnkle, Lm.rightAnkle]) {
        lm[i] = lm[i].copyWith(visibility: 0.1);
      }
      expect(
          d.observe(BodyFeatures.from(
              PoseFrame(timestampMs: t, landmarks: lm))),
          isNull);
    }
  });

  group('in the engine', () {
    const idle = ScriptStep(Action.idle, 2500);
    List<MotionEvent> play({required bool correct}) {
      // Calibrated far away, then played 36 % closer.
      final calibrated =
          SyntheticSession(SyntheticBody(seed: 5, height: 0.5, footY: 0.85))
              .calibrate();
      final s = SyntheticSession(
          SyntheticBody(seed: 6, height: 0.68, footY: 0.95));
      final engine =
          MotionEngine(calibration: calibrated, driftCorrection: correct);
      return runEngine(
          engine,
          s.record([
            idle,
            const ScriptStep(Action.squat, 1500),
            const ScriptStep(Action.idle, 1200),
          ]).frames);
    }

    test('without correction the squat is missed at the new distance', () {
      expect(play(correct: false).whereType<MoveStarted>(), isEmpty);
    });

    test('with correction it is recognised, with no re-calibration', () {
      final e = play(correct: true);
      expect(e.whereType<MoveStarted>().map((s) => s.move), [Move.squat]);
      expect(e.whereType<RepCompleted>(), hasLength(1));
      expect(e.whereType<TrackingPaused>(), isEmpty);
    });

    test('the live calibration follows the player; the original is kept',
        () {
      final calibrated =
          SyntheticSession(SyntheticBody(seed: 5, height: 0.5, footY: 0.85))
              .calibrate();
      final s = SyntheticSession(
          SyntheticBody(seed: 6, height: 0.68, footY: 0.95));
      final engine = MotionEngine(calibration: calibrated);
      runEngine(engine, s.record([idle]).frames);
      expect(identical(engine.calibration, calibrated), isTrue);
      expect(engine.liveCalibration.standingTorso,
          closeTo(0.30 * 0.68, 0.01));
      expect(engine.snapshot.driftRebases, 1);
    });
  });
}
