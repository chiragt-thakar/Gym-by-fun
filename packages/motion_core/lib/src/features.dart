import 'dart:math' as math;

import 'calibration.dart';
import 'landmarks.dart';

/// Body measurements derived from one frame, in normalised image units.
///
/// The recognisers work on these, never on raw landmarks, so the maths for
/// "how deep is this squat" lives in exactly one place.
class BodyFeatures {
  BodyFeatures._({
    required this.timestampMs,
    required this.hipCenter,
    required this.shoulderCenter,
    required this.nose,
    required this.leftWrist,
    required this.rightWrist,
    required this.torsoLength,
    required this.legSpan,
    required this.leanOffset,
    required this.minLegVisibility,
    required this.hipVisibility,
    required this.leftShoulder,
    required this.rightShoulder,
    required this.leftElbow,
    required this.rightElbow,
    required this.ankleCenter,
  });

  factory BodyFeatures.from(PoseFrame f) {
    final hip = midpoint(f[Lm.leftHip], f[Lm.rightHip]);
    final sh = midpoint(f[Lm.leftShoulder], f[Lm.rightShoulder]);
    final ankle = midpoint(f[Lm.leftAnkle], f[Lm.rightAnkle]);
    final torso = math.max(1e-6, _dist(hip, sh));
    // No temporary list: this runs every frame.
    final legVis = math.min(
      math.min(f[Lm.leftKnee].visibility, f[Lm.rightKnee].visibility),
      math.min(f[Lm.leftHip].visibility, f[Lm.rightHip].visibility),
    );
    return BodyFeatures._(
      timestampMs: f.timestampMs,
      hipCenter: hip,
      shoulderCenter: sh,
      nose: f[Lm.nose],
      leftWrist: f[Lm.leftWrist],
      rightWrist: f[Lm.rightWrist],
      torsoLength: torso,
      legSpan: ankle.y - hip.y,
      leanOffset: sh.x - hip.x,
      minLegVisibility: legVis,
      hipVisibility: hip.visibility,
      leftShoulder: f[Lm.leftShoulder],
      rightShoulder: f[Lm.rightShoulder],
      leftElbow: f[Lm.leftElbow],
      rightElbow: f[Lm.rightElbow],
      ankleCenter: ankle,
    );
  }

  final int timestampMs;
  final Landmark hipCenter;
  final Landmark shoulderCenter;
  final Landmark nose;
  final Landmark leftWrist;
  final Landmark rightWrist;

  /// Shoulder-centre to hip-centre distance.
  final double torsoLength;

  /// Vertical distance from hip centre down to ankle centre. Shrinks as the
  /// hips drop; unaffected by the phone being tilted up or down a little and
  /// unchanged by a forward bend (hips stay up).
  final double legSpan;

  /// Horizontal shoulder-centre offset from hip-centre (negative = player's left).
  final double leanOffset;

  /// Lowest visibility of hips and knees (the squat guard).
  final double minLegVisibility;
  final double hipVisibility;

  final Landmark leftShoulder;
  final Landmark rightShoulder;
  final Landmark leftElbow;
  final Landmark rightElbow;

  /// Midpoint of the ankles (visibility = the lower of the two).
  final Landmark ankleCenter;

  /// How deep the squat is, as a fraction of the player's calibrated
  /// comfortable depth (0 = standing, 1 = calibrated bottom).
  double squatFraction(CalibrationProfile c) =>
      (c.standingLegSpan - legSpan) / c.squatDepth;

  /// Lean as a signed fraction of the calibrated range: −1 = full left,
  /// +1 = full right.
  double leanFraction(CalibrationProfile c) {
    final shift = leanOffset - c.standingLeanOffset;
    return shift < 0 ? shift / c.leanRangeLeft : shift / c.leanRangeRight;
  }

  /// Side-step (low-impact lane change): hip-centre shift from the
  /// calibrated standing position, as a fraction of the step range.
  double sideStepFraction(CalibrationProfile c) =>
      (hipCenter.x - c.standingHipX) / c.sideStepRange;

  /// Wrists above the nose line (smaller y = higher).
  bool get leftWristAboveNose => leftWrist.y < nose.y;
  bool get rightWristAboveNose => rightWrist.y < nose.y;

  /// Wrists back below the shoulder line.
  bool get leftWristBelowShoulders => leftWrist.y > shoulderCenter.y;
  bool get rightWristBelowShoulders => rightWrist.y > shoulderCenter.y;
}

/// Straight-line distance between two landmarks in image units.
double landmarkDistance(Landmark a, Landmark b) => _dist(a, b);

double _dist(Landmark a, Landmark b) {
  final dx = a.x - b.x, dy = a.y - b.y;
  return math.sqrt(dx * dx + dy * dy);
}
