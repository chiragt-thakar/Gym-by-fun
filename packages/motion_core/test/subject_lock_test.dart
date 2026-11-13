import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:test/test.dart';

/// A second person standing well to the side of the player.
PoseFrame stranger(int t) => stickFrame(t: t, shiftX: 0.3);

PoseFrame both(int t, {required bool strangerFirst}) {
  final a = stickFrame(t: t), b = stranger(t);
  return PoseFrame(
    timestampMs: t,
    imageWidth: 480,
    imageHeight: 640,
    landmarks: strangerFirst ? b.landmarks : a.landmarks,
    others: [strangerFirst ? a.landmarks : b.landmarks],
  );
}

double hipX(PoseFrame f) => (f[Lm.leftHip].x + f[Lm.rightHip].x) / 2;

void main() {
  group('SubjectLock', () {
    test('a single player passes straight through', () {
      final lock = SubjectLock();
      for (var t = 0; t < 1000; t += 33) {
        final f = stickFrame(t: t, shiftX: 0.0005 * t / 33);
        expect(identical(lock.select(f), f), isTrue);
      }
      expect(lock.locked, isTrue);
      expect(lock.rejected, 0);
    });

    test('a body that appears somewhere else is not the player', () {
      final lock = SubjectLock()..select(stickFrame(t: 0));
      final out = lock.select(stranger(33));
      expect(out.hasPerson, isFalse);
      expect(lock.rejected, 1);
      // The player is still who the lock is waiting for.
      expect(lock.select(stickFrame(t: 66)).hasPerson, isTrue);
    });

    test('the player may move fast, just not teleport', () {
      final lock = SubjectLock()..select(stickFrame(t: 0));
      // 0.03 image-heights per frame is a brisk side step.
      for (var i = 1; i <= 8; i++) {
        final f = stickFrame(t: i * 33, shiftX: 0.03 * i);
        expect(lock.select(f).hasPerson, isTrue, reason: 'step $i');
      }
      expect(lock.rejected, 0);
    });

    test('when the player stays gone, whoever is there is adopted', () {
      // The player on the far left, a stranger on the far right: too far
      // apart to be the same person within the hold time.
      final lock = SubjectLock()..select(stickFrame(t: 0, shiftX: -0.25));
      var adoptedAt = -1;
      for (var t = 33; t < 1500; t += 33) {
        if (lock.select(stranger(t)).hasPerson) {
          adoptedAt = t;
          break;
        }
      }
      expect(adoptedAt, greaterThan(600));
      expect(adoptedAt, lessThan(700));
    });

    test('a nearby reappearance after a gap is still the player', () {
      final lock = SubjectLock()..select(stickFrame(t: 0));
      // Hidden for 400 ms, then seen a step to the side.
      final back = lock.select(stickFrame(t: 400, shiftX: 0.15));
      expect(back.hasPerson, isTrue);
      expect(lock.rejected, 0);
    });

    test('with two people in view it keeps following the player', () {
      final lock = SubjectLock()..select(stickFrame(t: 0));
      final player = hipX(stickFrame());
      for (var t = 33; t < 2000; t += 33) {
        final out = lock.select(both(t, strangerFirst: t % 2 == 1));
        expect(hipX(out), closeTo(player, 1e-9));
        expect(out.others, isEmpty);
      }
    });

    test('with nobody locked it takes the more central body', () {
      final lock = SubjectLock();
      final out = lock.select(both(0, strangerFirst: true));
      expect(hipX(out), closeTo(hipX(stickFrame()), 1e-9));
    });

    test('an empty frame releases the lock only after the hold time', () {
      final lock = SubjectLock()..select(stickFrame(t: 0));
      lock.select(PoseFrame(timestampMs: 300, landmarks: const []));
      expect(lock.locked, isTrue);
      lock.select(PoseFrame(timestampMs: 700, landmarks: const []));
      expect(lock.locked, isFalse);
    });

    test('a clock that restarts begins a new track', () {
      final lock = SubjectLock()..select(stickFrame(t: 5000));
      expect(lock.select(stranger(0)).hasPerson, isTrue);
    });
  });

  group('FacingCanonicaliser', () {
    PoseFrame exchanged(int t) {
      final f = stickFrame(t: t);
      final lm = List<Landmark>.of(f.landmarks);
      for (final (l, r) in Lm.pairs) {
        final x = lm[l];
        lm[l] = lm[r];
        lm[r] = x;
      }
      return f.withLandmarks(lm);
    }

    test('leaves a canonical frame alone', () {
      final c = FacingCanonicaliser();
      final f = stickFrame();
      expect(identical(c.apply(f), f), isTrue);
      expect(c.swapping, isFalse);
    });

    test('exchanges left and right when the indices arrive swapped', () {
      final c = FacingCanonicaliser();
      final out = c.apply(exchanged(0));
      expect(c.swapping, isTrue);
      expect(out[Lm.leftShoulder].x, lessThan(out[Lm.rightShoulder].x));
      expect(out[Lm.leftWrist].x, lessThan(out[Lm.rightWrist].x));
      expect(out[Lm.leftAnkle].x, lessThan(out[Lm.rightAnkle].x));
    });

    test('a brief flip does not change the decision; a sustained one does',
        () {
      final c = FacingCanonicaliser();
      var t = 0;
      for (; t < 1000; t += 33) {
        c.apply(stickFrame(t: t));
      }
      for (var i = 0; i < 3; i++, t += 33) {
        c.apply(exchanged(t));
      }
      expect(c.swapping, isFalse);
      for (; t < 4000; t += 33) {
        c.apply(exchanged(t));
      }
      expect(c.swapping, isTrue);
    });
  });
}
