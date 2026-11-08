import 'landmarks.dart';
import 'quality_gate.dart';

/// A side of the camera image, in selfie (mirrored) screen space.
enum FrameEdge { left, right, top, bottom }

/// The one thing the player should do to get back into a good frame.
///
/// Directions are the player's own: in selfie space their left is screen
/// left (smaller x), so a body cut off at the right edge means
/// [moveLeft].
enum FramingFix {
  ok,

  /// Nobody is visible.
  findMe,

  /// Head or feet are cut off, or the body is too big.
  stepBack,

  /// The body is too small to track well.
  stepCloser,

  /// Shift towards the player's own left.
  moveLeft,

  /// Shift towards the player's own right.
  moveRight,

  /// Key points are hidden: dim room, clutter or loose clothes.
  moreLight,
}

class FramingAdvice {
  const FramingAdvice(this.fix, {this.cut = const {}, this.near = const {}});

  final FramingFix fix;

  /// Edges the body crosses (key points outside the image).
  final Set<FrameEdge> cut;

  /// Edges the body is close to while still inside: an early warning,
  /// shown before tracking is lost.
  final Set<FrameEdge> near;

  bool get ok => fix == FramingFix.ok;

  @override
  bool operator ==(Object other) =>
      other is FramingAdvice &&
      other.fix == fix &&
      _sameSet(other.cut, cut) &&
      _sameSet(other.near, near);

  @override
  int get hashCode => Object.hash(
        fix,
        Object.hashAllUnordered(cut),
        Object.hashAllUnordered(near),
      );

  static bool _sameSet(Set<FrameEdge> a, Set<FrameEdge> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  String toString() => 'FramingAdvice($fix, cut: $cut, near: $near)';
}

/// Turns a frame (and the quality gate's verdict on it) into one
/// plain-language framing fix plus the edges to highlight on screen.
///
/// Uses the same key points and margin as [QualityGate], so the advice
/// always explains exactly why the gate failed.
class Framing {
  const Framing({this.gate = const QualityGate(), this.nearMargin = 0.06});

  final QualityGate gate;

  /// Distance from an edge (normalised) that counts as "close".
  final double nearMargin;

  FramingAdvice advise(PoseFrame f, [QualityResult? quality]) {
    if (!f.hasPerson) return const FramingAdvice(FramingFix.findMe);
    final q = quality ?? gate.check(f);
    final m = gate.config.frameMargin;
    final n = nearMargin;
    var minX = double.infinity, maxX = double.negativeInfinity;
    var minY = double.infinity, maxY = double.negativeInfinity;
    for (final i in Lm.fullBody) {
      final l = f[i];
      if (l.x < minX) minX = l.x;
      if (l.x > maxX) maxX = l.x;
      if (l.y < minY) minY = l.y;
      if (l.y > maxY) maxY = l.y;
    }
    final cut = <FrameEdge>{
      if (minX < m) FrameEdge.left,
      if (maxX > 1 - m) FrameEdge.right,
      if (minY < m) FrameEdge.top,
      if (maxY > 1 - m) FrameEdge.bottom,
    };
    if (q.ok) {
      return FramingAdvice(
        FramingFix.ok,
        near: {
          if (minX < n) FrameEdge.left,
          if (maxX > 1 - n) FrameEdge.right,
          if (minY < n) FrameEdge.top,
          if (maxY > 1 - n) FrameEdge.bottom,
        },
      );
    }
    final fix = switch (q.issue!) {
      TrackingIssue.noPerson => FramingFix.findMe,
      TrackingIssue.tooClose => FramingFix.stepBack,
      TrackingIssue.tooFar => FramingFix.stepCloser,
      TrackingIssue.lowVisibility => FramingFix.moreLight,
      TrackingIssue.outOfFrame => _outOfFrame(cut),
    };
    return FramingAdvice(fix, cut: cut);
  }

  static FramingFix _outOfFrame(Set<FrameEdge> cut) {
    // Moving sideways never brings cut-off feet or head back.
    if (cut.contains(FrameEdge.top) || cut.contains(FrameEdge.bottom)) {
      return FramingFix.stepBack;
    }
    final left = cut.contains(FrameEdge.left);
    final right = cut.contains(FrameEdge.right);
    if (left && right) return FramingFix.stepBack;
    if (right) return FramingFix.moveLeft;
    if (left) return FramingFix.moveRight;
    return FramingFix.stepBack;
  }
}

/// Debounces [FramingAdvice] for the screen and voice, so guidance does not
/// flicker on single noisy frames. A different advice must last [settleMs]
/// (frame clock) before it is shown. Display only: the game's own pause and
/// resume timing stays in `MotionEngine`.
class FramingFilter {
  FramingFilter({this.settleMs = 400});

  final int settleMs;
  FramingAdvice? _shown;
  FramingAdvice? _pending;
  int _pendingSince = 0;

  FramingAdvice? get shown => _shown;

  FramingAdvice update(FramingAdvice a, int timestampMs) {
    final shown = _shown;
    if (shown == null || shown == a) {
      _pending = null;
      return _shown = a;
    }
    if (_pending != a) {
      _pending = a;
      _pendingSince = timestampMs;
    }
    if (timestampMs - _pendingSince >= settleMs) {
      _pending = null;
      _shown = a;
    }
    return _shown!;
  }

  void reset() {
    _shown = null;
    _pending = null;
  }
}
