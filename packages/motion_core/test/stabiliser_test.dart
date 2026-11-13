import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:test/test.dart';

PoseFrame withLandmark(PoseFrame f, int i, Landmark l) => f.withLandmarks([
      for (var k = 0; k < f.landmarks.length; k++) k == i ? l : f.landmarks[k]
    ]);

void main() {
  test('trusted landmarks are filtered exactly like the One Euro smoother',
      () {
    final s = SyntheticSession(SyntheticBody(seed: 3));
    final frames = s.record([
      const ScriptStep(Action.idle, 500),
      const ScriptStep(Action.squat, 1200),
      const ScriptStep(Action.raiseArms, 1000),
    ]).frames;
    final legacy = LandmarkSmoother();
    final stabiliser = LandmarkStabiliser();
    for (final f in frames) {
      final a = legacy.smooth(f);
      final b = stabiliser.update(f);
      for (final i in Lm.smoothed) {
        expect(b[i].x, a[i].x);
        expect(b[i].y, a[i].y);
      }
      expect(stabiliser.predicted, isEmpty);
    }
  });

  test('removes jitter from a still body', () {
    final body = SyntheticBody(seed: 8, noise: 0.006);
    final stabiliser = LandmarkStabiliser();
    var raw = 0.0, out = 0.0;
    final still = SyntheticBody(noise: 0).pose()[Lm.leftWrist];
    for (var i = 0; i < 300; i++) {
      final f = PoseFrame(timestampMs: i * 33, landmarks: body.pose());
      final o = stabiliser.update(f);
      if (i > 30) {
        raw += (f[Lm.leftWrist].x - still.x).abs();
        out += (o[Lm.leftWrist].x - still.x).abs();
      }
    }
    expect(out, lessThan(raw * 0.6));
  });

  group('a landmark that drops out', () {
    // The right wrist moves steadily to the right, then its visibility
    // collapses and its position becomes garbage.
    late LandmarkStabiliser stabiliser;
    late PoseFrame lastGood;
    const base = 20;
    PoseFrame moving(int i) {
      final f = stickFrame(t: i * 33);
      final w = f[Lm.rightWrist];
      return withLandmark(
          f, Lm.rightWrist, Landmark(w.x + i * 0.01, w.y, 0, 0.95));
    }

    PoseFrame hidden(int i) => withLandmark(stickFrame(t: i * 33),
        Lm.rightWrist, const Landmark(0.02, 0.98, 0, 0.1));

    setUp(() {
      stabiliser = LandmarkStabiliser();
      for (var i = 0; i < base; i++) {
        lastGood = stabiliser.update(moving(i));
      }
    });

    test('coasts on its velocity and is reported as just-trusted', () {
      final o = stabiliser.update(hidden(base));
      final w = o[Lm.rightWrist];
      expect(stabiliser.predicted, [Lm.rightWrist]);
      expect(w.visibility, BodyFeatures.trustVisibility);
      // Kept moving the way it was going; nowhere near the garbage.
      expect(w.x, greaterThan(lastGood[Lm.rightWrist].x));
      expect(w.x, lessThan(lastGood[Lm.rightWrist].x + 0.04));
      expect(w.y, closeTo(lastGood[Lm.rightWrist].y, 0.01));
    });

    test('coasting travel is bounded (the velocity dies away)', () {
      Landmark? w;
      for (var i = base; i < base + 7; i++) {
        w = stabiliser.update(hidden(i))[Lm.rightWrist];
      }
      // 0.3 units/s for at most the 120 ms decay constant.
      expect(w!.x, lessThan(lastGood[Lm.rightWrist].x + 0.3 * 0.12 + 0.005));
    });

    test('after the hold time it is passed through as untrusted', () {
      Landmark? w;
      for (var i = base; i < base + 12; i++) {
        w = stabiliser.update(hidden(i))[Lm.rightWrist];
      }
      expect(w!.visibility, 0.1);
      expect(stabiliser.predicted, isEmpty);
    });

    test('other landmarks are unaffected', () {
      final o = stabiliser.update(hidden(base));
      expect(o[Lm.leftWrist].visibility, 0.95);
      expect(o[Lm.leftWrist].x, closeTo(lastGood[Lm.leftWrist].x, 1e-9));
    });

    test('it is measured again as soon as it returns', () {
      stabiliser.update(hidden(base));
      final o = stabiliser.update(moving(base + 1));
      expect(stabiliser.predicted, isEmpty);
      expect(o[Lm.rightWrist].visibility, 0.95);
    });
  });

  group('whole-body gaps', () {
    test('predict coasts the last body for a short gap only', () {
      final stabiliser = LandmarkStabiliser();
      for (var i = 0; i < 10; i++) {
        stabiliser.update(stickFrame(t: i * 33));
      }
      final gap = PoseFrame(timestampMs: 9 * 33 + 100, landmarks: const []);
      final p = stabiliser.predict(gap);
      expect(p, isNotNull);
      expect(p!.hasPerson, isTrue);
      expect(p.timestampMs, gap.timestampMs);
      expect(p[Lm.nose].x, closeTo(stickFrame()[Lm.nose].x, 1e-6));
      expect(stabiliser.predicted, hasLength(Lm.count));

      final late = PoseFrame(timestampMs: 9 * 33 + 400, landmarks: const []);
      expect(stabiliser.predict(late), isNull);
    });

    test('nothing to predict before the first body or after a reset', () {
      final stabiliser = LandmarkStabiliser();
      final gap = PoseFrame(timestampMs: 50, landmarks: const []);
      expect(stabiliser.predict(gap), isNull);
      stabiliser.update(stickFrame(t: 0));
      expect(stabiliser.predict(gap), isNotNull);
      stabiliser.reset();
      expect(stabiliser.predict(gap), isNull);
    });
  });

  test('non-finite coordinates never reach the output', () {
    final stabiliser = LandmarkStabiliser()..update(stickFrame(t: 0));
    final bad = withLandmark(stickFrame(t: 33), Lm.leftKnee,
        const Landmark(double.nan, double.infinity, 0, 0.9));
    final o = stabiliser.update(bad)[Lm.leftKnee];
    expect(o.x.isFinite, isTrue);
    expect(o.y.isFinite, isTrue);
  });
}
