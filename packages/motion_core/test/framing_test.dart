import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:test/test.dart';

PoseFrame frameOf(SyntheticBody b) =>
    PoseFrame(timestampMs: 0, landmarks: b.pose(), imageHeight: 640);

/// Moves every landmark horizontally by [dx] (normalised units).
PoseFrame shifted(PoseFrame f, double dx) => PoseFrame(
      timestampMs: f.timestampMs,
      imageHeight: f.imageHeight,
      landmarks: [for (final l in f.landmarks) l.copyWith(x: l.x + dx)],
    );

double maxX(PoseFrame f) =>
    Lm.fullBody.map((i) => f[i].x).reduce((a, b) => a > b ? a : b);

void main() {
  const framing = Framing();

  test('a centred, well-sized body is ok with no edges', () {
    final a = framing.advise(frameOf(SyntheticBody(noise: 0)));
    expect(a.fix, FramingFix.ok);
    expect(a.ok, isTrue);
    expect(a.cut, isEmpty);
    expect(a.near, isEmpty);
  });

  test('no person asks the player to step into the frame', () {
    final a = framing.advise(PoseFrame(timestampMs: 0, landmarks: const []));
    expect(a.fix, FramingFix.findMe);
  });

  test('body cut off on the right of the screen → move to your left', () {
    // Selfie space: screen right is larger x, which is the player's right,
    // so they must move to their left.
    final a = framing.advise(frameOf(SyntheticBody(noise: 0, centerX: 0.95)));
    expect(a.fix, FramingFix.moveLeft);
    expect(a.cut, {FrameEdge.right});
  });

  test('body cut off on the left of the screen → move to your right', () {
    final a = framing.advise(frameOf(SyntheticBody(noise: 0, centerX: 0.05)));
    expect(a.fix, FramingFix.moveRight);
    expect(a.cut, {FrameEdge.left});
  });

  test('feet or head cut off → step back', () {
    final a = framing.advise(
      frameOf(SyntheticBody(noise: 0, height: 1.0, footY: 1.08)),
    );
    expect(a.fix, FramingFix.stepBack);
    expect(a.cut, contains(FrameEdge.bottom));
  });

  test('a vertical cut wins over a sideways one', () {
    final a = framing.advise(
      frameOf(SyntheticBody(noise: 0, height: 1.0, footY: 1.08, centerX: 0.95)),
    );
    expect(a.fix, FramingFix.stepBack);
    expect(a.cut, containsAll([FrameEdge.bottom, FrameEdge.right]));
  });

  test('a tiny body → step closer', () {
    final a = framing.advise(frameOf(SyntheticBody(noise: 0, height: 0.25)));
    expect(a.fix, FramingFix.stepCloser);
  });

  test('hidden legs → more light', () {
    final f = frameOf(SyntheticBody(noise: 0));
    final dim = PoseFrame(
      timestampMs: 0,
      imageHeight: 640,
      landmarks: [
        for (var i = 0; i < f.landmarks.length; i++)
          i == Lm.leftKnee || i == Lm.rightKnee
              ? f[i].copyWith(visibility: 0.2)
              : f[i],
      ],
    );
    expect(framing.advise(dim).fix, FramingFix.moreLight);
  });

  test('close to an edge but still inside → ok with an early warning', () {
    final f = frameOf(SyntheticBody(noise: 0));
    // Put the right-most key point 3 % from the right edge.
    final near = shifted(f, 0.97 - maxX(f));
    final a = framing.advise(near);
    expect(a.ok, isTrue);
    expect(a.near, {FrameEdge.right});
    expect(a.cut, isEmpty);
  });

  group('FramingFilter', () {
    const ok = FramingAdvice(FramingFix.ok);
    const left = FramingAdvice(FramingFix.moveLeft, cut: {FrameEdge.right});

    test('adopts the first advice at once', () {
      expect(FramingFilter().update(left, 0), left);
    });

    test('ignores a single noisy frame', () {
      final f = FramingFilter(settleMs: 400);
      f.update(ok, 0);
      expect(f.update(left, 33), ok);
      expect(f.update(ok, 66), ok);
      expect(f.update(left, 500), ok, reason: 'pending restarted at 500');
    });

    test('switches once a change has lasted settleMs', () {
      final f = FramingFilter(settleMs: 400);
      f.update(ok, 0);
      for (var t = 33; t < 400; t += 33) {
        expect(f.update(left, t), ok);
      }
      expect(f.update(left, 433), left);
    });

    test('alternating noise never switches', () {
      final f = FramingFilter(settleMs: 400);
      f.update(ok, 0);
      const right = FramingAdvice(FramingFix.moveRight, cut: {FrameEdge.left});
      for (var t = 33; t < 3000; t += 33) {
        expect(f.update(t.isEven ? left : right, t), ok);
      }
    });

    test('reset forgets the shown advice', () {
      final f = FramingFilter()..update(ok, 0);
      f.reset();
      expect(f.update(left, 10), left);
    });
  });

  test('agrees with the quality gate it is given', () {
    final f = frameOf(SyntheticBody(noise: 0, centerX: 0.95));
    final q = const QualityGate().check(f);
    expect(framing.advise(f, q).fix, FramingFix.moveLeft);
  });
}
