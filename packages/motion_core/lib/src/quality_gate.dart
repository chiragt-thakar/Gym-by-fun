import 'dart:math' as math;

import 'landmarks.dart';

/// Why a frame is not good enough to drive the game. Every reason maps to a
/// plain-language hint in the app; none of them ever costs the player a life.
enum TrackingIssue {
  /// No person detected at all.
  noPerson,

  /// Part of the body is outside the image (usually feet or head).
  outOfFrame,

  /// Key points are hidden or low-confidence (loose clothes, clutter, dim light).
  lowVisibility,

  /// The player is too far away / too small in the image.
  tooFar,

  /// The player is too close: the body fills more than the frame allows.
  tooClose,
}

/// How far a frame can be trusted.
enum FrameQuality {
  /// The whole body is in frame and clearly visible.
  good,

  /// The torso is tracked but something else is not ideal (feet cut off,
  /// a hidden knee, a little too close). Play continues: each detector
  /// checks the landmarks it needs itself.
  degraded,

  /// Nothing usable: nobody there, or the torso itself is hidden / outside
  /// the image / far too small.
  bad,
}

class QualityResult {
  const QualityResult.pass(this.bodyHeight)
      : issue = null,
        level = FrameQuality.good;
  const QualityResult.fail(TrackingIssue this.issue, [this.bodyHeight = 0])
      : level = FrameQuality.bad;

  /// Not ideal, but the torso is tracked: [issue] says what to improve.
  const QualityResult.degraded(TrackingIssue this.issue, this.bodyHeight)
      : level = FrameQuality.degraded;

  /// The most important thing wrong with the frame, or null when it is
  /// [FrameQuality.good].
  final TrackingIssue? issue;

  final FrameQuality level;

  /// Normalised height of the body bounding box (0..1), for UI guidance.
  final double bodyHeight;

  /// True only for a clean, full-body frame.
  bool get ok => issue == null;

  /// True when the frame can drive play (good or degraded).
  bool get usable => level != FrameQuality.bad;

  @override
  String toString() => ok
      ? 'QualityResult.ok'
      : 'QualityResult.${usable ? 'degraded' : 'fail'}($issue)';
}

class QualityGateConfig {
  const QualityGateConfig({
    this.minVisibility = 0.5,
    this.minMeanVisibility = 0.65,
    this.frameMargin = 0.01,
    this.minBodyHeight = 0.35,
    this.maxBodyHeight = 0.98,
    this.minBodyPixels = 256,
    this.coreMinVisibility = 0.4,
    this.coreOutside = 0.03,
    this.farSlack = 0.85,
  });

  /// Every full-body key point must be at least this visible.
  final double minVisibility;

  /// Mean visibility across key points (catches dim rooms).
  final double minMeanVisibility;

  /// How far inside the image edge key points must be.
  final double frameMargin;

  /// Body bounding-box height as a fraction of image height.
  final double minBodyHeight;
  final double maxBodyHeight;

  /// ML Kit advises a subject of at least 256 × 256 px.
  final int minBodyPixels;

  /// Shoulders and hips must each be at least this visible for a frame to
  /// be usable at all.
  final double coreMinVisibility;

  /// Shoulders and hips may sit this far outside the image (the estimator
  /// extrapolates a little past the edge) before the frame is unusable.
  final double coreOutside;

  /// A body between this fraction of the minimum size and the minimum is
  /// only [FrameQuality.degraded], so a player hovering at the limit does
  /// not flip between playing and paused.
  final double farSlack;
}

/// Grades each frame: [FrameQuality.good] (clean full body),
/// [FrameQuality.degraded] (torso tracked, something else not ideal) or
/// [FrameQuality.bad]. Stateless; debouncing and hysteresis over time live
/// in `TrackingStateMachine`.
class QualityGate {
  const QualityGate([this.config = const QualityGateConfig()]);

  final QualityGateConfig config;

  QualityResult check(PoseFrame frame) {
    if (!frame.hasPerson) {
      return const QualityResult.fail(TrackingIssue.noPerson);
    }

    var minY = 1.0, maxY = 0.0, sumVis = 0.0;
    var outOfFrame = false;
    var lowVis = false;
    final m = config.frameMargin;
    for (final i in Lm.fullBody) {
      final l = frame[i];
      sumVis += l.visibility;
      if (l.visibility < config.minVisibility) lowVis = true;
      if (l.x < m || l.x > 1 - m || l.y < m || l.y > 1 - m) outOfFrame = true;
      if (l.y < minY) minY = l.y;
      if (l.y > maxY) maxY = l.y;
    }
    // Body size: the bounding box shrinks when the player squats, so also
    // estimate standing height from the torso (≈ 1/3.3 of nose-to-ankle).
    // Otherwise a squat would read as "too far" and pause the game.
    // Hip/shoulder centres computed inline (no midpoint objects per frame).
    final lh = frame[Lm.leftHip], rh = frame[Lm.rightHip];
    final ls = frame[Lm.leftShoulder], rs = frame[Lm.rightShoulder];
    final dx = (lh.x + rh.x) / 2 - (ls.x + rs.x) / 2;
    final dy = (lh.y + rh.y) / 2 - (ls.y + rs.y) / 2;
    final torso = math.sqrt(dx * dx + dy * dy);
    final height =
        math.max(maxY - minY, torso * 3.3).clamp(0.0, 1.0).toDouble();

    // The first thing wrong, in a fixed order, so the guidance is stable.
    final h = frame.imageHeight;
    final TrackingIssue? issue;
    var far = 1.0; // size as a fraction of the minimum, when too far
    if (outOfFrame) {
      issue = TrackingIssue.outOfFrame;
    } else if (lowVis || sumVis / Lm.fullBody.length < config.minMeanVisibility) {
      issue = TrackingIssue.lowVisibility;
    } else if (maxY - minY > config.maxBodyHeight) {
      issue = TrackingIssue.tooClose;
    } else if (height < config.minBodyHeight) {
      issue = TrackingIssue.tooFar;
      far = height / config.minBodyHeight;
    } else if (h != null && height * h < config.minBodyPixels) {
      issue = TrackingIssue.tooFar;
      far = height * h / config.minBodyPixels;
    } else {
      issue = null;
    }
    if (issue == null) return QualityResult.pass(height);

    // Still playable if the torso itself is tracked and big enough.
    var core = true;
    final o = config.coreOutside;
    for (final i in Lm.core) {
      final l = frame[i];
      if (!(l.visibility >= config.coreMinVisibility) ||
          !(l.x >= -o && l.x <= 1 + o && l.y >= -o && l.y <= 1 + o)) {
        core = false;
        break;
      }
    }
    if (!core || (issue == TrackingIssue.tooFar && far < config.farSlack)) {
      return QualityResult.fail(issue, height);
    }
    return QualityResult.degraded(issue, height);
  }
}
