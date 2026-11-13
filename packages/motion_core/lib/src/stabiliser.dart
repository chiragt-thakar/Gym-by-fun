import 'dart:math' as math;

import 'landmarks.dart';
import 'one_euro_filter.dart';

class StabiliserConfig {
  const StabiliserConfig({
    this.minCutoff = 1.7,
    this.beta = 0.3,
    this.dCutoff = 1.0,
    this.trustVisibility = 0.5,
    this.holdMs = 250,
    this.velocityDecayMs = 120,
  });

  /// One Euro parameters (see [OneEuroFilter]). Tuned on the replay corpus:
  /// change only while the accuracy gate still passes.
  final double minCutoff;
  final double beta;
  final double dCutoff;

  /// A landmark at least this visible is measured; below it the landmark
  /// coasts on its last velocity for up to [holdMs].
  final double trustVisibility;

  /// Longest dropout that is bridged by prediction, per landmark and for
  /// the whole body.
  final int holdMs;

  /// Time constant with which the coasting velocity dies away. Total
  /// coasting travel is bounded by velocity × this, so a prediction can
  /// never run off.
  final int velocityDecayMs;
}

/// Per-landmark state estimator for all 33 landmarks.
///
/// - **Filtering**: a One Euro filter on x and y (adaptive cut-off: steady
///   at rest, low lag in fast moves).
/// - **Confidence gating**: a landmark below
///   [StabiliserConfig.trustVisibility] is not allowed to drag the estimate
///   around.
/// - **Short-gap prediction**: such a landmark coasts on its filtered
///   velocity, exponentially damped, for up to [StabiliserConfig.holdMs],
///   and is reported as just-trusted so one flickering joint does not stop
///   a move. After that it is passed through with its true low visibility
///   and the detector that needs it declines to act.
/// - **Whole-body gaps**: [predict] coasts every landmark the same way for
///   frames with no usable body, for display continuity.
class LandmarkStabiliser {
  LandmarkStabiliser([this.config = const StabiliserConfig()])
      : _fx = List.generate(
          Lm.count,
          (_) => OneEuroFilter(
            minCutoff: config.minCutoff,
            beta: config.beta,
            dCutoff: config.dCutoff,
          ),
          growable: false,
        ),
        _fy = List.generate(
          Lm.count,
          (_) => OneEuroFilter(
            minCutoff: config.minCutoff,
            beta: config.beta,
            dCutoff: config.dCutoff,
          ),
          growable: false,
        );

  final StabiliserConfig config;
  final List<OneEuroFilter> _fx;
  final List<OneEuroFilter> _fy;

  // Last trusted measurement per landmark: time, output position, velocity.
  final List<int> _goodMs = List<int>.filled(Lm.count, -1);
  final List<double> _gx = List<double>.filled(Lm.count, 0);
  final List<double> _gy = List<double>.filled(Lm.count, 0);
  final List<double> _vx = List<double>.filled(Lm.count, 0);
  final List<double> _vy = List<double>.filled(Lm.count, 0);
  PoseFrame? _last;

  /// Indices that were predicted (not measured) in the last output.
  List<int> get predicted => _predicted;
  List<int> _predicted = const <int>[];

  /// Damped constant-velocity travel factor after [dtMs]: seconds of
  /// "effective" motion, never more than the decay constant.
  double _travel(int dtMs) {
    final tau = config.velocityDecayMs / 1000.0;
    return tau * (1 - math.exp(-(dtMs / 1000.0) / tau));
  }

  /// Filters a frame that contains a body. Returns a new frame; the input
  /// is never modified.
  PoseFrame update(PoseFrame frame) {
    if (!frame.hasPerson) return frame;
    final ts = frame.timestampMs;
    final src = frame.landmarks;
    final out = List<Landmark>.of(src, growable: false);
    List<int>? predicted;
    for (var i = 0; i < Lm.count; i++) {
      final l = src[i];
      final measured = l.visibility >= config.trustVisibility &&
          l.x.isFinite &&
          l.y.isFinite;
      if (measured) {
        final x = _fx[i].filter(l.x, ts);
        final y = _fy[i].filter(l.y, ts);
        _goodMs[i] = ts;
        _gx[i] = x;
        _gy[i] = y;
        _vx[i] = _fx[i].velocity;
        _vy[i] = _fy[i].velocity;
        out[i] = Landmark(x, y, l.z, l.visibility);
        continue;
      }
      final good = _goodMs[i];
      final gap = ts - good;
      if (good >= 0 && gap >= 0 && gap <= config.holdMs) {
        // Coast: ignore the untrusted measurement, keep the motion going.
        final k = _travel(gap);
        out[i] = Landmark(
          _gx[i] + _vx[i] * k,
          _gy[i] + _vy[i] * k,
          l.z,
          config.trustVisibility,
        );
        (predicted ??= <int>[]).add(i);
      } else if (l.x.isFinite && l.y.isFinite) {
        // Gone for too long: follow the measurement smoothly, but keep its
        // true (low) visibility so nothing acts on it.
        out[i] = Landmark(
          _fx[i].filter(l.x, ts),
          _fy[i].filter(l.y, ts),
          l.z,
          l.visibility,
        );
      } else {
        out[i] = Landmark(_gx[i], _gy[i], l.z, 0);
      }
    }
    _predicted = predicted ?? const <int>[];
    return _last = frame.withLandmarks(out);
  }

  /// A coasted copy of the last body for a frame with no usable body, or
  /// null when there is nothing recent enough to coast from. [like]
  /// supplies the timestamp and image size.
  PoseFrame? predict(PoseFrame like) {
    final last = _last;
    if (last == null) return null;
    final ts = like.timestampMs;
    final gap = ts - last.timestampMs;
    if (gap < 0 || gap > config.holdMs) return null;
    final out = List<Landmark>.of(last.landmarks, growable: false);
    final all = <int>[];
    for (var i = 0; i < Lm.count; i++) {
      final good = _goodMs[i];
      if (good < 0 || ts - good > config.holdMs) continue;
      final k = _travel(ts - good);
      out[i] = Landmark(
        _gx[i] + _vx[i] * k,
        _gy[i] + _vy[i] * k,
        out[i].z,
        out[i].visibility,
      );
      all.add(i);
    }
    _predicted = all;
    return PoseFrame(
      timestampMs: ts,
      landmarks: out,
      imageWidth: like.imageWidth ?? last.imageWidth,
      imageHeight: like.imageHeight ?? last.imageHeight,
      inferenceMs: like.inferenceMs,
    );
  }

  void reset() {
    for (var i = 0; i < Lm.count; i++) {
      _fx[i].reset();
      _fy[i].reset();
      _goodMs[i] = -1;
      _vx[i] = 0;
      _vy[i] = 0;
    }
    _last = null;
    _predicted = const <int>[];
  }
}
