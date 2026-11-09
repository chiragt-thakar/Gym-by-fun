import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:test/test.dart';

const goalpost = PoseTarget(
  id: 'goalpost',
  angles: {
    PoseAngle.shoulderL: 90,
    PoseAngle.shoulderR: 90,
    PoseAngle.elbowL: 90,
    PoseAngle.elbowR: 90,
  },
  must: {PoseAngle.elbowL, PoseAngle.elbowR},
);

const kite = PoseTarget(
  id: 'kite',
  angles: {
    PoseAngle.shoulderL: 150,
    PoseAngle.shoulderR: 100,
    PoseAngle.lean: 10,
  },
  mirrorOk: true,
);

void main() {
  const m = PoseMatcher();

  test('an exact pose scores 100', () {
    final r = m.match(
        BodyPose.from(
            stickFrame(shoulderL: 90, shoulderR: 90, elbowL: 90, elbowR: 90)),
        goalpost);
    expect(r.similarity, greaterThan(97));
    expect(r.seenWeight, closeTo(1, 1e-9));
  });

  test('standing relaxed is far from a goalpost', () {
    final r = m.match(BodyPose.from(stickFrame()), goalpost);
    expect(r.similarity, lessThan(40));
    expect(r.worst, isNotNull);
  });

  test('within tolerance still scores full marks', () {
    final r = m.match(
        BodyPose.from(
            stickFrame(shoulderL: 105, shoulderR: 80, elbowL: 108, elbowR: 75)),
        goalpost);
    expect(r.similarity, greaterThan(95));
  });

  test('a failed must feature caps the score at 60', () {
    final r = m.match(
        BodyPose.from(
            stickFrame(shoulderL: 90, shoulderR: 90, elbowL: 175, elbowR: 90)),
        goalpost);
    expect(r.similarity, lessThanOrEqualTo(60));
    expect(r.worst, PoseAngle.elbowL);
  });

  test('mirrorOk poses score both ways', () {
    final mirrored =
        BodyPose.from(stickFrame(shoulderL: 100, shoulderR: 150, lean: -10));
    expect(m.match(mirrored, kite).similarity, greaterThan(95));
    const strict = PoseTarget(id: 'k', angles: {
      PoseAngle.shoulderL: 150,
      PoseAngle.shoulderR: 100,
      PoseAngle.lean: 10,
    });
    expect(m.match(mirrored, strict).similarity, lessThan(70));
  });

  test('unseen joints are excluded and reported', () {
    final r = m.match(
        BodyPose.from(stickFrame(
            shoulderL: 90,
            shoulderR: 90,
            elbowL: 90,
            elbowR: 90,
            hidden: {Lm.leftElbow: 0.1})),
        goalpost);
    expect(r.seenWeight, lessThan(0.6));
  });

  test('a tighter tolerance lowers a near-miss score', () {
    final p = BodyPose.from(
        stickFrame(shoulderL: 110, shoulderR: 70, elbowL: 115, elbowR: 65));
    final loose = m.match(p, goalpost, tolOffset: 5).similarity;
    final tight = m.match(p, goalpost, tolOffset: -10).similarity;
    expect(tight, lessThan(loose));
  });

  test('targets decode from JSON', () {
    final t = PoseTarget.fromJson({
      'id': 'x',
      'angles': {'shoulderL': 90, 'lean': -5},
      'must': ['shoulderL'],
      'mirrorOk': true,
    });
    expect(t.angles[PoseAngle.lean], -5);
    expect(t.must, {PoseAngle.shoulderL});
    expect(t.mirrorOk, isTrue);
  });
}
