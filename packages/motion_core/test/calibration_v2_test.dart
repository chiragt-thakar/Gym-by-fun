import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:test/test.dart';

PoseFrame hide(PoseFrame f, Iterable<int> indices, [double v = 0.1]) {
  final set = indices.toSet();
  return f.withLandmarks([
    for (var i = 0; i < f.landmarks.length; i++)
      set.contains(i) ? f.landmarks[i].copyWith(visibility: v) : f.landmarks[i]
  ]);
}

const feet = [27, 28, 29, 30, 31, 32];

/// Feeds a standing body for [ms] from time [from]; returns the next time.
int stand(Calibrator c, SyntheticBody body, int from, int ms,
    {bool hideFeet = false}) {
  var t = from;
  for (; t < from + ms; t += 33) {
    final f = PoseFrame(
        timestampMs: t,
        landmarks: body.pose(),
        imageWidth: 480,
        imageHeight: 640);
    c.add(hideFeet ? hide(f, feet) : f);
  }
  return t;
}

void main() {
  group('quality report', () {
    test('a clean guided calibration is graded good and stored', () {
      final s = SyntheticSession(SyntheticBody(height: 0.6, seed: 2));
      final c = Calibrator();
      final smoother = LandmarkSmoother();
      for (final f in s.calibrationFrames()) {
        c.add(smoother.smooth(f));
      }
      expect(c.step, CalibrationStep.done);
      final r = c.report;
      expect(r.grade, CalibrationGrade.good, reason: '$r');
      expect(r.shouldRetry, isFalse);
      expect(c.conditions, isEmpty);
      final p = c.build();
      expect(p.quality, r.score);
      expect(p.version, CalibrationProfile.currentVersion);
      expect(p.feetVisible, isTrue);
    });

    test('measures the body, not just the range', () {
      final s = SyntheticSession(SyntheticBody(height: 0.6, seed: 2));
      final p = s.calibrate();
      const h = 0.6;
      expect(p.shoulderWidth, closeTo(0.22 * h, 0.01));
      expect(p.hipWidth, closeTo(0.14 * h, 0.01));
      expect(p.standingThighSpan, closeTo(0.25 * h, 0.01));
      expect(p.squatThighDepth, closeTo(0.17 * h, 0.02));
      expect(p.bodyHeight, closeTo(0.94 * h, 0.02));
      expect(p.standingAnkleY, closeTo(0.93 - 0.04 * h, 0.01));
      expect(p.cameraRoll.abs(), lessThan(3));
      expect(p.armLength, greaterThan(0.2 * h));
    });

    test('skipped steps lower the score and are named', () {
      final c = Calibrator();
      stand(c, SyntheticBody(noise: 0), 0, 2300);
      while (c.step != CalibrationStep.done) {
        c.skip();
      }
      final r = c.report;
      expect(r.issues, {CalibrationIssue.stepsSkipped});
      expect(r.grade, CalibrationGrade.fair);
      expect(r.score, closeTo(0.55, 1e-9));
    });

    test('hidden feet and skipped steps make it poor: retry is advised', () {
      final c = Calibrator();
      stand(c, SyntheticBody(noise: 0), 0, 2300, hideFeet: true);
      expect(c.conditions, contains(CalibrationIssue.feetHidden));
      while (c.step != CalibrationStep.done) {
        c.skip();
      }
      final r = c.report;
      expect(r.issues, containsAll(
          [CalibrationIssue.feetHidden, CalibrationIssue.stepsSkipped]));
      expect(r.grade, CalibrationGrade.poor);
      expect(r.shouldRetry, isTrue);
      final p = c.build();
      expect(p.feetVisible, isFalse);
      // Leg span estimated from the thighs (knee about half-way down).
      expect(p.standingLegSpan, closeTo(p.standingThighSpan * 2, 1e-9));
    });

    test('a dim room is flagged while it is happening and in the report',
        () {
      final c = Calibrator();
      final body = SyntheticBody(noise: 0);
      for (var t = 0; t < 2300; t += 33) {
        final f = PoseFrame(timestampMs: t, landmarks: body.pose());
        // Everything faint, but still above the usable threshold.
        c.add(f.withLandmarks(
            [for (final l in f.landmarks) l.copyWith(visibility: 0.55)]));
      }
      expect(c.conditions, contains(CalibrationIssue.lowLight));
      expect(c.report.issues, contains(CalibrationIssue.lowLight));
    });

    test('a slow camera is flagged', () {
      final c = Calibrator();
      final body = SyntheticBody(noise: 0);
      for (var t = 0; t < 3000; t += 100) {
        c.add(PoseFrame(timestampMs: t, landmarks: body.pose()));
      }
      expect(c.conditions, contains(CalibrationIssue.lowFrameRate));
      expect(c.report.issues, contains(CalibrationIssue.lowFrameRate));
    });

    test('a player who keeps shifting is flagged as unsteady', () {
      final c = Calibrator(stillMs: 100000);
      final a = SyntheticBody(noise: 0), b = SyntheticBody(noise: 0, centerX: 0.6);
      var t = 0;
      for (var round = 0; round < 4; round++) {
        t = stand(c, round.isEven ? a : b, t, 500);
      }
      expect(c.conditions, contains(CalibrationIssue.unsteady));
    });
  });

  group('robust measurement', () {
    test('one wild frame at the bottom of a squat does not bend the depth',
        () {
      final body = SyntheticBody(noise: 0);
      final c = Calibrator();
      var t = stand(c, body, 0, 2300);
      c.skip(); // arms
      var spiked = false;
      void hold(double squat, int ms) {
        for (final end = t + ms; t < end; t += 33) {
          var lm = body.pose(squat: squat);
          if (squat == 1 && !spiked && t > end - 200) {
            // The hips jump a tenth of the image down for one frame.
            spiked = true;
            lm = [
              for (var i = 0; i < lm.length; i++)
                i == Lm.leftHip || i == Lm.rightHip
                    ? lm[i].copyWith(y: lm[i].y + 0.1)
                    : lm[i]
            ];
          }
          c.add(PoseFrame(timestampMs: t, landmarks: lm));
        }
      }

      for (var i = 0; i < 2; i++) {
        hold(1, 600);
        hold(0, 500);
      }
      expect(spiked, isTrue);
      expect(c.step, CalibrationStep.leanLeft);
      c.skip();
      c.skip();
      expect(c.build().squatDepth, closeTo(0.20 * body.height, 0.005));
    });

    test('a lean is its held level, not its single largest frame', () {
      final body = SyntheticBody(noise: 0);
      final c = Calibrator();
      var t = stand(c, body, 0, 2300);
      c.skip(); // arms
      c.skip(); // squats
      expect(c.step, CalibrationStep.leanLeft);
      var n = 0;
      for (final end = t + 700; t < end; t += 33) {
        // One frame overshoots wildly.
        final lean = n++ == 5 ? -3.0 : -1.0;
        c.add(PoseFrame(timestampMs: t, landmarks: body.pose(lean: lean)));
      }
      expect(c.step, CalibrationStep.leanRight);
      c.skip();
      expect(c.build().leanRangeLeft, closeTo(0.12 * body.height, 0.005));
    });
  });

  group('body-relative profile', () {
    test('rebase keeps the range in body units', () {
      final p = SyntheticSession(SyntheticBody(seed: 2)).calibrate();
      final q = p.rebase(torso: p.standingTorso * 1.5, hipX: 0.3, hipY: 0.5);
      expect(q.standingTorso, closeTo(p.standingTorso * 1.5, 1e-12));
      expect(q.squatDepthTorso, closeTo(p.squatDepthTorso, 1e-12));
      expect(q.leanRangeLeftTorso, closeTo(p.leanRangeLeftTorso, 1e-12));
      expect(q.leanRangeRightTorso, closeTo(p.leanRangeRightTorso, 1e-12));
      expect(q.legSpanTorso, closeTo(p.legSpanTorso, 1e-12));
      expect(q.shoulderWidthTorso, closeTo(p.shoulderWidthTorso, 1e-12));
      expect(q.armLengthTorso, closeTo(p.armLengthTorso, 1e-12));
      expect(q.standingHipX, 0.3);
      expect(q.standingHipY, 0.5);
      expect(q.standingAnkleY, closeTo(0.5 + q.standingLegSpan, 1e-12));
      // The reach keeps its height above the hips, in body units.
      expect((q.standingHipY - q.reachY) / q.standingTorso,
          closeTo((p.standingHipY - p.reachY) / p.standingTorso, 1e-12));
    });

    test('quick re-calibration moves the profile without re-measuring range',
        () {
      final base = SyntheticSession(SyntheticBody(height: 0.6, seed: 2))
          .calibrate();
      // Same person, now closer and off to one side.
      final near =
          SyntheticBody(noise: 0, height: 0.75, footY: 0.95, centerX: 0.4);
      final c = Calibrator(base: base);
      expect(c.quick, isTrue);
      stand(c, near, 0, 2300);
      expect(c.step, CalibrationStep.done);
      final p = c.build();
      expect(p.standingTorso, closeTo(0.30 * 0.75, 0.005));
      expect(p.standingHipX, closeTo(0.4, 0.005));
      expect(p.squatDepthTorso, closeTo(base.squatDepthTorso, 1e-9));
      expect(p.leanRangeLeftTorso, closeTo(base.leanRangeLeftTorso, 1e-9));
      expect(p.quality, lessThanOrEqualTo(base.quality));
      // It now matches where the player actually stands.
      final standing = BodyFeatures.from(
          PoseFrame(timestampMs: 0, landmarks: near.pose()));
      expect(base.hasDrifted(standing), isTrue);
      expect(p.hasDrifted(standing), isFalse);
    });
  });

  group('versioned persistence', () {
    const v1 = <String, dynamic>{
      'standingLegSpan': 0.30,
      'standingTorso': 0.18,
      'standingHipX': 0.5,
      'standingHipY': 0.55,
      'standingLeanOffset': 0.0,
      'squatDepth': 0.08,
      'leanRangeLeft': 0.05,
      'leanRangeRight': 0.06,
      'reachY': 0.2,
      'sideStepRange': 0.11,
    };

    test('a version 1 profile loads with population proportions', () {
      final p = CalibrationProfile.fromJson(v1);
      expect(p.version, 1);
      expect(p.sideStepRange, 0.11);
      expect(p.standingThighSpan, closeTo(0.15, 1e-12));
      expect(p.squatThighDepth, closeTo(0.08 * 0.85, 1e-12));
      expect(p.shoulderWidth, closeTo(0.18 * 0.75, 1e-12));
      expect(p.standingAnkleY, closeTo(0.85, 1e-12));
      expect(p.quality, 0);
      expect(p.feetVisible, isTrue);
    });

    test('the current version round-trips every field', () {
      final p = SyntheticSession(SyntheticBody(seed: 2)).calibrate();
      final j = p.toJson();
      expect(j['v'], CalibrationProfile.currentVersion);
      expect(j.values.every((v) => v is num), isTrue,
          reason: 'the server stores a string → number map');
      expect(CalibrationProfile.fromJson(Map<String, dynamic>.from(j)).toJson(),
          j);
    });

    test('unknown keys from a newer version are ignored', () {
      final p = CalibrationProfile.fromJson({...v1, 'v': 9, 'future': 1.5});
      expect(p.version, 9);
      expect(p.squatDepth, 0.08);
    });

    test('a damaged profile is refused, not half-loaded', () {
      expect(() => CalibrationProfile.fromJson({...v1}..remove('squatDepth')),
          throwsFormatException);
      expect(() => CalibrationProfile.fromJson({...v1, 'standingTorso': 0}),
          throwsFormatException);
      expect(() => CalibrationProfile.fromJson({...v1, 'reachY': 'high'}),
          throwsFormatException);
      expect(
          () => CalibrationProfile.fromJson(
              {...v1, 'squatDepth': double.nan}),
          throwsFormatException);
    });
  });
}
