import 'body_pose.dart';
import 'events.dart';

class SwingThresholds {
  const SwingThresholds({
    this.travelShoulders = 1.0,
    this.togetherMax = 0.45,
    this.togetherSwingMax = 0.7,
    this.backliftMinX = 0.25,
    this.backliftMinY = -0.15,
    this.holdMs = 100,
    this.minMs = 100,
    this.maxMs = 1200,
    this.cooldownMs = 1000,
    this.loftedMinY = -0.3,
  });

  /// Low-impact: a shorter swing counts.
  const SwingThresholds.lowImpact() : this(travelShoulders: 0.6);

  /// Hand-midpoint travel needed, in shoulder widths.
  final double travelShoulders;

  /// Wrists closer than this (torso units) count as gripping the bat.
  final double togetherMax;

  /// Looser grip limit while the swing is moving (blur, Lite model).
  final double togetherSwingMax;

  /// Backlift: hands at least this far to one side and this high.
  final double backliftMinX;
  final double backliftMinY;
  final int holdMs;

  /// The swing must reach its travel within this time window.
  final int minMs;
  final int maxMs;
  final int cooldownMs;

  /// Hands still at or above this height when the travel is reached: lofted.
  final double loftedMinY;
}

/// A recognised (or rejected) bat swing.
class SwingEvent {
  const SwingEvent({
    required this.timestampMs,
    required this.completed,
    required this.fromSide,
    this.lofted = false,
    this.durationMs = 0,
    this.reason,
  });

  final int timestampMs;
  final bool completed;

  /// The side of the backlift (the trailing shoulder).
  final BodySide fromSide;
  final bool lofted;
  final int durationMs;
  final RejectReason? reason;

  @override
  String toString() => completed
      ? 'Swing($fromSide${lofted ? ' lofted' : ''} ${durationMs}ms @$timestampMs)'
      : 'SwingRejected($reason @$timestampMs)';
}

/// Two-handed swing across the body, judged on end states in the image
/// plane: hands together held high on one side (backlift), then the hand
/// midpoint travels across the body. Never uses speed or depth.
class SwingRecogniser {
  SwingRecogniser([this.t = const SwingThresholds()]);
  final SwingThresholds t;

  BodySide? _side;
  int? _liftSince;
  double _startX = 0;
  int? _swingStart;
  int _liftEnd = 0;
  int _cooldownUntil = -1 << 30;

  String get state => _swingStart != null
      ? 'swing'
      : _side != null
          ? 'backlift'
          : 'idle';

  void reset() {
    _side = null;
    _liftSince = null;
    _swingStart = null;
  }

  SwingEvent? update(BodyPose p) {
    final ts = p.timestampMs;
    final l = p.leftHand, r = p.rightHand;
    if (!l.seen || !r.seen) {
      final side = _side;
      final moving = _swingStart != null;
      reset();
      return moving && side != null
          ? SwingEvent(
              timestampMs: ts,
              completed: false,
              fromSide: side,
              reason: RejectReason.notVisible)
          : null;
    }
    final grip = l.distanceTo(r);
    final mx = (l.x + r.x) / 2, my = (l.y + r.y) / 2;

    if (_swingStart == null) {
      final lifted = grip <= t.togetherMax &&
          my >= t.backliftMinY &&
          mx.abs() >= t.backliftMinX &&
          ts >= _cooldownUntil;
      if (lifted) {
        final side = mx > 0 ? BodySide.right : BodySide.left;
        if (_side != side) {
          _side = side;
          _liftSince = ts;
          _startX = mx;
        }
        _liftEnd = ts;
        if ((side == BodySide.right && mx > _startX) ||
            (side == BodySide.left && mx < _startX)) {
          _startX = mx;
        }
        return null;
      }
      final side = _side;
      if (side == null) return null;
      if (ts - _liftSince! < t.holdMs || grip > t.togetherSwingMax) {
        reset();
        return null;
      }
      if (_travel(side, mx) >= 0.1) _swingStart = ts;
      return null;
    }

    final side = _side!;
    final travel = _travel(side, mx);
    final need = t.travelShoulders * p.shoulderWidth;
    final elapsed = ts - _liftEnd;
    if (travel >= need) {
      reset();
      if (elapsed < t.minMs) return null;
      _cooldownUntil = ts + t.cooldownMs;
      return SwingEvent(
        timestampMs: ts,
        completed: true,
        fromSide: side,
        lofted: my >= t.loftedMinY,
        durationMs: elapsed,
      );
    }
    if (grip > t.togetherSwingMax || elapsed > t.maxMs) {
      reset();
      return SwingEvent(
        timestampMs: ts,
        completed: false,
        fromSide: side,
        reason: RejectReason.tooShallow,
      );
    }
    return null;
  }

  double _travel(BodySide side, double mx) =>
      side == BodySide.right ? _startX - mx : mx - _startX;
}
