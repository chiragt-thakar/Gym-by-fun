import 'dart:math' as math;

import '../landmarks.dart';

/// TEST SUPPORT ONLY. Builds a 33-landmark frame from joint angles, so pose
/// features, matching and game rules can be tested with exact geometry.
/// Never wired into the app (rule 1).
///
/// Angles are in degrees, using the player's own left/right. The frame is a
/// mirrored selfie like the native bridge sends: the player's left side is
/// on the screen's left (smaller x).
///
/// - [shoulderL]/[shoulderR]: arm abduction, 0 = by the side, 90 = T,
///   180 = straight up.
/// - [elbowL]/[elbowR]: elbow angle, 180 = straight.
/// - [hipL]/[hipR]: leg abduction from vertical.
/// - [kneeL]/[kneeR]: knee angle, 180 = straight.
/// - [lean]: torso tilt, positive = towards the player's right.
/// - [dip]: 0..1 hip drop (a squat, in torso lengths × 0.5).
/// - [shiftX]: whole-body shift in image-height units.
/// - [liftL]/[liftR]: 0..1 knee lift (foot leaves the floor).
/// - [riseY]: whole-body lift in image-height units (a jump).
/// - [twist]: torso rotation in degrees, positive = chest towards the
///   player's right. Narrows the shoulder line and sets shoulder depth.
PoseFrame stickFrame({
  int t = 0,
  double shoulderL = 10,
  double shoulderR = 10,
  double elbowL = 175,
  double elbowR = 175,
  double hipL = 6,
  double hipR = 6,
  double kneeL = 178,
  double kneeR = 178,
  double lean = 0,
  double dip = 0,
  double shiftX = 0,
  double liftL = 0,
  double liftR = 0,
  double riseY = 0,
  double twist = 0,
  double visibility = 0.95,
  Map<int, double> hidden = const {},
  Map<int, (double, double)> override = const {},
}) {
  const w = 480, h = 640;
  const aspect = w / h;
  const torso = 0.18;
  const shoulderFull = 0.065;
  const hipHalf = 0.045;
  const upperArm = 0.11, foreArm = 0.10, thigh = 0.15, shin = 0.15;
  double rad(double d) => d * math.pi / 180;
  final shoulderHalf = shoulderFull * math.cos(rad(twist));
  // Depth of each shoulder (same scale as x; smaller = nearer the camera).
  final shoulderDepth = shoulderFull * math.sin(rad(twist));
  (double, double) rot((double, double) v, double deg) {
    final a = rad(deg);
    return (
      v.$1 * math.cos(a) - v.$2 * math.sin(a),
      v.$1 * math.sin(a) + v.$2 * math.cos(a),
    );
  }

  (double, double) add((double, double) p, (double, double) v, double len) =>
      (p.$1 + v.$1 * len, p.$2 + v.$2 * len);

  final hipC = (0.5 * aspect + shiftX, 0.55 + dip * torso * 0.5);
  final up = (math.sin(rad(lean)), -math.cos(rad(lean)));
  final across = (math.cos(rad(lean)), math.sin(rad(lean)));
  final shC = add(hipC, up, torso);
  final lSh = add(shC, across, -shoulderHalf);
  final rSh = add(shC, across, shoulderHalf);
  final lHip = add(hipC, across, -hipHalf);
  final rHip = add(hipC, across, hipHalf);
  final nose = add(shC, up, 0.08);

  // Arms: "down" is the torso's down direction.
  final down = (-up.$1, -up.$2);
  final lUpperDir = rot(down, shoulderL); // outward = clockwise on screen
  final rUpperDir = rot(down, -shoulderR);
  final lElbow = add(lSh, lUpperDir, upperArm);
  final rElbow = add(rSh, rUpperDir, upperArm);
  // Raised arms bend up (a goalpost); low arms bend in towards the chest.
  final lFore =
      rot(lUpperDir, shoulderL >= 60 ? 180 - elbowL : -(180 - elbowL));
  final rFore =
      rot(rUpperDir, shoulderR >= 60 ? -(180 - elbowR) : 180 - elbowR);
  final lWrist = add(lElbow, lFore, foreArm);
  final rWrist = add(rElbow, rFore, foreArm);

  final lThighDir = rot((0.0, 1.0), hipL);
  final rThighDir = rot((0.0, 1.0), -hipR);
  var lKnee = add(lHip, lThighDir, thigh);
  var rKnee = add(rHip, rThighDir, thigh);
  var lAnkle = add(lKnee, rot(lThighDir, -(180 - kneeL)), shin);
  var rAnkle = add(rKnee, rot(rThighDir, 180 - kneeR), shin);
  if (liftL > 0) {
    lKnee = (lKnee.$1, lKnee.$2 - liftL * 0.09);
    lAnkle = (lAnkle.$1, lAnkle.$2 - liftL * 0.12);
  }
  if (liftR > 0) {
    rKnee = (rKnee.$1, rKnee.$2 - liftR * 0.09);
    rAnkle = (rAnkle.$1, rAnkle.$2 - liftR * 0.12);
  }

  final pts = List<(double, double)>.filled(Lm.count, nose);
  for (var i = 1; i <= 10; i++) {
    pts[i] = (nose.$1 + (i.isOdd ? -0.01 : 0.01), nose.$2 - 0.01);
  }
  pts[Lm.leftShoulder] = lSh;
  pts[Lm.rightShoulder] = rSh;
  pts[Lm.leftElbow] = lElbow;
  pts[Lm.rightElbow] = rElbow;
  pts[Lm.leftWrist] = lWrist;
  pts[Lm.rightWrist] = rWrist;
  pts[17] = add(lWrist, lFore, 0.02); // left pinky
  pts[19] = add(lWrist, lFore, 0.025); // left index
  pts[21] = add(lWrist, lFore, 0.015); // left thumb
  pts[18] = add(rWrist, rFore, 0.02);
  pts[20] = add(rWrist, rFore, 0.025);
  pts[22] = add(rWrist, rFore, 0.015);
  pts[Lm.leftHip] = lHip;
  pts[Lm.rightHip] = rHip;
  pts[Lm.leftKnee] = lKnee;
  pts[Lm.rightKnee] = rKnee;
  pts[Lm.leftAnkle] = lAnkle;
  pts[Lm.rightAnkle] = rAnkle;
  pts[29] = (lAnkle.$1, lAnkle.$2 + 0.01);
  pts[30] = (rAnkle.$1, rAnkle.$2 + 0.01);
  pts[31] = (lAnkle.$1 - 0.01, lAnkle.$2 + 0.015);
  pts[32] = (rAnkle.$1 + 0.01, rAnkle.$2 + 0.015);
  override.forEach((i, p) => pts[i] = p);

  return PoseFrame(
    timestampMs: t,
    imageWidth: w,
    imageHeight: h,
    landmarks: [
      for (var i = 0; i < Lm.count; i++)
        Landmark(
          pts[i].$1 / aspect,
          pts[i].$2 - riseY,
          i == Lm.leftShoulder
              ? -shoulderDepth / aspect
              : (i == Lm.rightShoulder ? shoulderDepth / aspect : 0),
          hidden[i] ?? visibility,
        ),
    ],
  );
}
