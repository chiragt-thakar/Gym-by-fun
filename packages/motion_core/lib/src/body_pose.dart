import 'dart:math' as math;

import 'events.dart' show BodySide;
import 'landmarks.dart';

export 'events.dart' show BodySide;

/// A point in body space: torso units from the shoulder centre, +y up,
/// +x towards the player's right (screen right).
class BodyPoint {
  const BodyPoint(this.x, this.y, this.visibility);
  static const unseen = BodyPoint(0, 0, 0);

  final double x;
  final double y;
  final double visibility;

  bool get seen => visibility >= 0.5;

  double distanceTo(BodyPoint o) {
    final dx = x - o.x, dy = y - o.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}

/// Joint angles the pose games use, all in degrees, in the player's own
/// left/right.
enum PoseAngle {
  /// Arm abduction: 0 by the side, 90 a T, 180 straight up.
  shoulderL,
  shoulderR,

  /// Elbow angle: 180 straight.
  elbowL,
  elbowR,

  /// Leg abduction from the torso line.
  hipL,
  hipR,

  /// Knee angle: 180 straight.
  kneeL,
  kneeR,

  /// Torso tilt from vertical, positive towards the player's right.
  lean,
}

/// A slowly-following reference for body space. Game objects anchored to
/// it stay still while the player dips or leans, and follow when the
/// player re-positions. Updated only from standing frames.
class BodyAnchor {
  BodyAnchor({this.follow = 0.08});

  /// Per-frame blend towards the current standing body (0..1).
  final double follow;

  double? _x, _y, _scale;
  bool get ready => _x != null;
  double get originX => _x ?? 0;
  double get originY => _y ?? 0;
  double get scale => _scale ?? 0.2;

  void reset() => _x = _y = _scale = null;

  void update(PoseFrame f) {
    if (!f.hasPerson) return;
    final aspect = _frameAspect(f);
    final sx = (f[Lm.leftShoulder].x + f[Lm.rightShoulder].x) / 2 * aspect;
    final sy = (f[Lm.leftShoulder].y + f[Lm.rightShoulder].y) / 2;
    final hx = (f[Lm.leftHip].x + f[Lm.rightHip].x) / 2 * aspect;
    final hy = (f[Lm.leftHip].y + f[Lm.rightHip].y) / 2;
    final torso = math.max(1e-4, math.sqrt(_sq(sx - hx) + _sq(sy - hy)));
    if (_x == null || (hx - _x!).abs() > 1.5 * _scale!) {
      _x = sx;
      _y = sy;
      _scale = torso;
      return;
    }
    // Dipped (squat/duck): keep the standing reference.
    if (hy > _y! + _scale! * 1.12) return;
    _x = _x! + (sx - _x!) * follow;
    _y = _y! + (sy - _y!) * follow;
    _scale = _scale! + (torso - _scale!) * follow;
  }
}

double _sq(double v) => v * v;
double _frameAspect(PoseFrame f) {
  final w = f.imageWidth, h = f.imageHeight;
  return w != null && h != null && h > 0 ? w / h : 0.75;
}

/// Body-relative geometry of one frame, for games that place targets around
/// the player (zones, poses, swings). Pure function of the landmarks; no
/// thresholds of the core recognisers are involved.
class BodyPose {
  BodyPose._(
      this._frame, this._aspect, this._ox, this._oy, this._scale, this.torso);

  /// [anchor], when given and ready, fixes the origin and scale so body
  /// space does not move with every dip.
  factory BodyPose.from(PoseFrame f, {BodyAnchor? anchor}) {
    final aspect = _frameAspect(f);
    final sx = (f[Lm.leftShoulder].x + f[Lm.rightShoulder].x) / 2 * aspect;
    final sy = (f[Lm.leftShoulder].y + f[Lm.rightShoulder].y) / 2;
    final hx = (f[Lm.leftHip].x + f[Lm.rightHip].x) / 2 * aspect;
    final hy = (f[Lm.leftHip].y + f[Lm.rightHip].y) / 2;
    final torso = math.max(1e-4, math.sqrt(_sq(sx - hx) + _sq(sy - hy)));
    if (anchor != null && anchor.ready) {
      return BodyPose._(
          f, aspect, anchor.originX, anchor.originY, anchor.scale, torso);
    }
    return BodyPose._(f, aspect, sx, sy, torso, torso);
  }

  final PoseFrame _frame;
  final double _aspect;
  final double _ox, _oy, _scale;

  /// This frame's own torso length in image-height units.
  final double torso;

  int get timestampMs => _frame.timestampMs;

  BodyPoint point(int i) {
    final l = _frame[i];
    return BodyPoint(
        (l.x * _aspect - _ox) / _scale, (_oy - l.y) / _scale, l.visibility);
  }

  /// Body space back to normalised image coordinates (for drawing).
  (double, double) toImage(double bx, double by) =>
      ((_ox + bx * _scale) / _aspect, _oy - by * _scale);

  /// Torso length in body units (1 without an anchor).
  double get torsoUnits => torso / _scale;

  BodyPoint get nose => point(Lm.nose);
  BodyPoint get leftShoulder => point(Lm.leftShoulder);
  BodyPoint get rightShoulder => point(Lm.rightShoulder);
  BodyPoint get leftElbow => point(Lm.leftElbow);
  BodyPoint get rightElbow => point(Lm.rightElbow);
  BodyPoint get leftWrist => point(Lm.leftWrist);
  BodyPoint get rightWrist => point(Lm.rightWrist);
  BodyPoint get leftHip => point(Lm.leftHip);
  BodyPoint get rightHip => point(Lm.rightHip);
  BodyPoint get leftKnee => point(Lm.leftKnee);
  BodyPoint get rightKnee => point(Lm.rightKnee);
  BodyPoint get leftAnkle => point(Lm.leftAnkle);
  BodyPoint get rightAnkle => point(Lm.rightAnkle);

  BodyPoint get shoulderCenter => _mid(leftShoulder, rightShoulder);
  BodyPoint get hipCenter => _mid(leftHip, rightHip);

  /// Shoulder width in body units.
  double get shoulderWidth => leftShoulder.distanceTo(rightShoulder);

  /// Hand point: mean of wrist, index and pinky when all are visible, else
  /// the wrist alone when it is clearly visible, else unseen.
  BodyPoint get leftHand => _hand(Lm.leftWrist, 19, 17);
  BodyPoint get rightHand => _hand(Lm.rightWrist, 20, 18);

  BodyPoint hand(BodySide side) => side == BodySide.left ? leftHand : rightHand;

  BodyPoint _hand(int wrist, int index, int pinky) {
    final w = point(wrist), i = point(index), p = point(pinky);
    if (w.seen && i.seen && p.seen) {
      return BodyPoint((w.x + i.x + p.x) / 3, (w.y + i.y + p.y) / 3,
          math.min(w.visibility, math.min(i.visibility, p.visibility)));
    }
    if (w.visibility >= 0.6) return w;
    return BodyPoint.unseen;
  }

  /// True if the given hand (or either hand when [side] is null) is within
  /// [radius] of body-space ([x], [y]).
  bool handIn(BodySide? side, double x, double y, double radius) {
    bool inZone(BodyPoint h) =>
        h.seen && h.distanceTo(BodyPoint(x, y, 1)) <= radius;
    if (side != null) return inZone(hand(side));
    return inZone(leftHand) || inZone(rightHand);
  }

  /// Both hands up between chest and forehead, elbows bent, hands apart: a
  /// boxing-style guard.
  bool get isGuard {
    final l = leftHand, r = rightHand;
    if (!l.seen || !r.seen) return false;
    bool up(BodyPoint h) => h.y >= -0.6 && h.y <= 0.75 && h.x.abs() <= 0.95;
    if (!up(l) || !up(r)) return false;
    final d = l.distanceTo(r);
    if (d < 0.2 || d > 1.8) return false;
    final el = angle(PoseAngle.elbowL), er = angle(PoseAngle.elbowR);
    return (el == null || el <= 125) && (er == null || er <= 125);
  }

  /// Both hands together in front of the body (a clap / folded hands).
  bool get handsTogether {
    final l = leftHand, r = rightHand;
    if (!l.seen || !r.seen) return false;
    final my = (l.y + r.y) / 2, mx = (l.x + r.x) / 2;
    return l.distanceTo(r) <= 0.45 &&
        my >= -0.9 &&
        my <= 0.4 &&
        mx.abs() <= 0.5;
  }

  /// Both hands above the nose.
  bool get armsUp {
    final l = leftHand, r = rightHand, n = nose;
    return l.seen && r.seen && n.seen && l.y > n.y && r.y > n.y;
  }

  /// Joint angle in degrees, or null when a joint it needs is not visible.
  double? angle(PoseAngle a) {
    switch (a) {
      case PoseAngle.shoulderL:
        return _abduction(leftShoulder, leftElbow, leftHip);
      case PoseAngle.shoulderR:
        return _abduction(rightShoulder, rightElbow, rightHip);
      case PoseAngle.elbowL:
        return _inner(leftShoulder, leftElbow, leftWrist);
      case PoseAngle.elbowR:
        return _inner(rightShoulder, rightElbow, rightWrist);
      case PoseAngle.hipL:
        return _hipAbduction(leftHip, leftKnee);
      case PoseAngle.hipR:
        return _hipAbduction(rightHip, rightKnee);
      case PoseAngle.kneeL:
        return _inner(leftHip, leftKnee, leftAnkle);
      case PoseAngle.kneeR:
        return _inner(rightHip, rightKnee, rightAnkle);
      case PoseAngle.lean:
        final s = shoulderCenter, h = hipCenter;
        if (!s.seen || !h.seen) return null;
        return math.atan2(s.x - h.x, s.y - h.y) * 180 / math.pi;
    }
  }

  /// Angle between the torso's downward centre line and the upper arm
  /// (shoulder → elbow). [hip] must be visible for the torso line.
  double? _abduction(BodyPoint sh, BodyPoint el, BodyPoint hip) {
    final s = shoulderCenter, h = hipCenter;
    if (!sh.seen || !el.seen || !hip.seen || !s.seen || !h.seen) return null;
    return _between(h.x - s.x, h.y - s.y, el.x - sh.x, el.y - sh.y);
  }

  double? _hipAbduction(BodyPoint hip, BodyPoint knee) {
    final s = shoulderCenter, h = hipCenter;
    if (!hip.seen || !knee.seen || !s.seen || !h.seen) return null;
    return _between(h.x - s.x, h.y - s.y, knee.x - hip.x, knee.y - hip.y);
  }

  double? _inner(BodyPoint a, BodyPoint b, BodyPoint c) {
    if (!a.seen || !b.seen || !c.seen) return null;
    return _between(a.x - b.x, a.y - b.y, c.x - b.x, c.y - b.y);
  }

  static double _between(double ax, double ay, double bx, double by) {
    final la = math.sqrt(ax * ax + ay * ay), lb = math.sqrt(bx * bx + by * by);
    if (la < 1e-9 || lb < 1e-9) return 0;
    final c = ((ax * bx + ay * by) / (la * lb)).clamp(-1.0, 1.0);
    return math.acos(c) * 180 / math.pi;
  }

  static BodyPoint _mid(BodyPoint a, BodyPoint b) => BodyPoint(
      (a.x + b.x) / 2, (a.y + b.y) / 2, math.min(a.visibility, b.visibility));
}
