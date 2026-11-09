import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:test/test.dart';

void main() {
  group('BodyPose geometry', () {
    test('origin is the shoulder centre, +y up, in torso units', () {
      final p = BodyPose.from(stickFrame());
      expect(p.nose.y, greaterThan(0.3));
      expect(p.hipCenter.y, closeTo(-1, 0.02));
      expect(p.hipCenter.x, closeTo(0, 0.02));
      expect(p.leftShoulder.x, lessThan(0),
          reason: 'player-left on screen-left');
      expect(p.rightShoulder.x, greaterThan(0));
    });

    test('arm angles round-trip from the stick figure', () {
      final p = BodyPose.from(
          stickFrame(shoulderL: 90, elbowL: 90, shoulderR: 135, elbowR: 170));
      expect(p.angle(PoseAngle.shoulderL)!, closeTo(90, 3));
      expect(p.angle(PoseAngle.elbowL)!, closeTo(90, 3));
      expect(p.angle(PoseAngle.shoulderR)!, closeTo(135, 3));
      expect(p.angle(PoseAngle.elbowR)!, closeTo(170, 3));
    });

    test('lean and leg angles round-trip', () {
      expect(BodyPose.from(stickFrame(lean: 15)).angle(PoseAngle.lean)!,
          closeTo(15, 3));
      final p = BodyPose.from(stickFrame(hipL: 30, kneeR: 130));
      expect(p.angle(PoseAngle.hipL)!, closeTo(30, 4));
      expect(p.angle(PoseAngle.kneeR)!, closeTo(130, 4));
    });

    test('hidden joints make their angles unseen', () {
      final p = BodyPose.from(stickFrame(hidden: {Lm.leftElbow: 0.1}));
      expect(p.angle(PoseAngle.elbowL), isNull);
      expect(p.angle(PoseAngle.shoulderL), isNull);
      expect(p.angle(PoseAngle.elbowR), isNotNull);
    });

    test('hand point averages wrist, index and pinky', () {
      final p = BodyPose.from(stickFrame(shoulderL: 90));
      expect(p.leftHand.seen, isTrue);
      expect(p.leftHand.x, lessThan(p.leftWrist.x));
    });

    test('image point maps body space back to the frame', () {
      final f = stickFrame(shoulderR: 90);
      final p = BodyPose.from(f);
      final (x, y) = p.toImage(p.rightWrist.x, p.rightWrist.y);
      expect(x, closeTo(f[Lm.rightWrist].x, 1e-6));
      expect(y, closeTo(f[Lm.rightWrist].y, 1e-6));
    });

    test('an anchor keeps zones still while the player dips', () {
      final anchor = BodyAnchor();
      final stand = stickFrame();
      for (var i = 0; i < 30; i++) {
        anchor.update(stickFrame(t: i * 33));
      }
      final dipped = stickFrame(t: 1000, dip: 0.8);
      anchor.update(dipped);
      final free = BodyPose.from(dipped);
      final anchored = BodyPose.from(dipped, anchor: anchor);
      expect(free.nose.y, closeTo(BodyPose.from(stand).nose.y, 0.02),
          reason: 'unanchored pose moves with the body');
      expect(anchored.nose.y, lessThan(free.nose.y - 0.2),
          reason: 'anchored space stays at standing height');
    });
  });

  group('gestures', () {
    test('guard: both wrists up by the face, elbows bent', () {
      final guard = BodyPose.from(
          stickFrame(shoulderL: 65, elbowL: 50, shoulderR: 65, elbowR: 50));
      expect(guard.isGuard, isTrue);
      expect(BodyPose.from(stickFrame()).isGuard, isFalse);
      expect(BodyPose.from(stickFrame(shoulderL: 175, shoulderR: 175)).isGuard,
          isFalse,
          reason: 'raised arms are not a guard');
    });

    test('hands together at the chest', () {
      final clap = BodyPose.from(
          stickFrame(shoulderL: 35, elbowL: 70, shoulderR: 35, elbowR: 70));
      expect(clap.handsTogether, isTrue);
      expect(BodyPose.from(stickFrame()).handsTogether, isFalse);
    });

    test('hand in zone', () {
      final p = BodyPose.from(stickFrame(shoulderR: 90));
      expect(p.handIn(BodySide.right, 1.3, 0, 0.5), isTrue);
      expect(p.handIn(BodySide.left, 1.3, 0, 0.5), isFalse);
      expect(p.handIn(null, 1.3, 0, 0.5), isTrue, reason: 'any hand');
    });
  });
}
