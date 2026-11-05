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

class QualityResult {
  const QualityResult.pass(this.bodyHeight) : issue = null;
  const QualityResult.fail(TrackingIssue this.issue, [this.bodyHeight = 0]);

  final TrackingIssue? issue;

  /// Normalised height of the body bounding box (0..1), for UI guidance.
  final double bodyHeight;

  bool get ok => issue == null;

  @override
  String toString() => ok ? 'QualityResult.ok' : 'QualityResult.fail($issue)';
}

class QualityGateConfig {
  const QualityGateConfig({
    this.minVisibility = 0.5,
    this.minMeanVisibility = 0.65,
    this.frameMargin = 0.01,
    this.minBodyHeight = 0.35,
    this.maxBodyHeight = 0.98,
    this.minBodyPixels = 256,
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
}

/// Decides, frame by frame, whether landmarks are trustworthy enough to play.
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
    final hip = midpoint(frame[Lm.leftHip], frame[Lm.rightHip]);
    final sh = midpoint(frame[Lm.leftShoulder], frame[Lm.rightShoulder]);
    final torso =
        math.sqrt(math.pow(hip.x - sh.x, 2) + math.pow(hip.y - sh.y, 2));
    final height =
        math.max(maxY - minY, torso * 3.3).clamp(0.0, 1.0).toDouble();

    if (outOfFrame) return QualityResult.fail(TrackingIssue.outOfFrame, height);
    if (lowVis || sumVis / Lm.fullBody.length < config.minMeanVisibility) {
      return QualityResult.fail(TrackingIssue.lowVisibility, height);
    }
    if (maxY - minY > config.maxBodyHeight) {
      return QualityResult.fail(TrackingIssue.tooClose, height);
    }
    if (height < config.minBodyHeight) {
      return QualityResult.fail(TrackingIssue.tooFar, height);
    }
    final h = frame.imageHeight;
    if (h != null && height * h < config.minBodyPixels) {
      return QualityResult.fail(TrackingIssue.tooFar, height);
    }
    return QualityResult.pass(height);
  }
}
