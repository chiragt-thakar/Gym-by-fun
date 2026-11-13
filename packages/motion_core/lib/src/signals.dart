import 'calibration.dart';
import 'events.dart';
import 'features.dart';
import 'tracking_state.dart';

/// Continuous, body-relative input for games that steer, aim or fill a
/// meter rather than react to discrete moves. Every value is a fraction of
/// the player's own calibrated range, so a game never sees pixels, camera
/// distance or the player's height.
class MotionSignals {
  const MotionSignals({
    this.valid = false,
    this.squat = 0,
    this.lean = 0,
    this.sideStep = 0,
    this.armLeft = 0,
    this.armRight = 0,
    this.hipX = 0,
    this.hipRise = 0,
  });

  /// The value while nothing is tracked.
  static const none = MotionSignals();

  factory MotionSignals.from(BodyFeatures b, CalibrationProfile c) {
    const v = BodyFeatures.trustVisibility;
    final reach = c.standingHipY - c.reachY;
    double arm(double wristY, double visibility) =>
        visibility >= v && reach > 0
            ? ((b.hipCenter.y - wristY) / reach).clamp(-0.25, 1.5).toDouble()
            : 0.0;
    return MotionSignals(
      valid: true,
      squat: b.squatFraction(c),
      lean: b.leanFraction(c),
      sideStep: b.sideStepFraction(c),
      armLeft: arm(b.leftWrist.y, b.leftWrist.visibility),
      armRight: arm(b.rightWrist.y, b.rightWrist.visibility),
      hipX: (b.hipCenter.x - c.standingHipX) * b.aspect / c.standingTorso,
      hipRise: (c.standingHipY - b.hipCenter.y) / c.standingTorso,
    );
  }

  /// False while the player is not tracked; every value is then 0.
  final bool valid;

  /// Squat depth: 0 standing, 1 the player's calibrated comfortable bottom.
  final double squat;

  /// Torso lean: −1 the player's full left, +1 full right.
  final double lean;

  /// Sideways hip shift from the calibrated spot: −1 / +1 = one
  /// comfortable side step left / right.
  final double sideStep;

  /// Hand height: 0 at hip level, 1 at the player's calibrated full reach.
  /// 0 while the wrist is not visible.
  final double armLeft;
  final double armRight;

  /// Hip position relative to the calibrated spot, in torso lengths
  /// (x: + is the player's right; rise: + is up).
  final double hipX;
  final double hipRise;
}

/// What a game consumes: discrete events, continuous signals and the
/// tracking state. Implemented by the live session, by recorded replay and
/// by the simulator, so a game cannot tell them apart.
abstract interface class MotionInput {
  /// Discrete events, in order ([MoveStarted], [GestureEvent],
  /// [TrackingPaused] …).
  Stream<MotionEvent> get events;

  /// The latest continuous signals ([MotionSignals.none] when untracked).
  MotionSignals get signals;

  TrackingState get trackingState;
}
