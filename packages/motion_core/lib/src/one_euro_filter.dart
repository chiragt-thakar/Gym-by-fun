import 'dart:math' as math;

import 'landmarks.dart';

/// One Euro filter (Casiez, Roussel & Vogel, CHI 2012): a low-pass filter
/// whose cut-off rises with speed, so slow jitter is smoothed while fast,
/// deliberate moves keep low latency.
class OneEuroFilter {
  OneEuroFilter({this.minCutoff = 1.7, this.beta = 0.3, this.dCutoff = 1.0});

  /// Minimum cut-off frequency in Hz. Lower = smoother at rest.
  final double minCutoff;

  /// Speed coefficient. Higher = less lag during fast moves.
  final double beta;

  /// Cut-off for the derivative.
  final double dCutoff;

  double? _x;
  double _dx = 0;
  int? _lastMs;

  static double _alpha(double cutoff, double dtS) {
    final tau = 1 / (2 * math.pi * cutoff);
    return 1 / (1 + tau / dtS);
  }

  double filter(double value, int timestampMs) {
    final last = _lastMs;
    final prev = _x;
    if (prev == null || last == null || timestampMs <= last) {
      _x = value;
      _lastMs = timestampMs;
      return value;
    }
    final dt = (timestampMs - last) / 1000.0;
    final rawDx = (value - prev) / dt;
    final aD = _alpha(dCutoff, dt);
    _dx = aD * rawDx + (1 - aD) * _dx;
    final cutoff = minCutoff + beta * _dx.abs();
    final a = _alpha(cutoff, dt);
    final x = a * value + (1 - a) * prev;
    _x = x;
    _lastMs = timestampMs;
    return x;
  }

  void reset() {
    _x = null;
    _dx = 0;
    _lastMs = null;
  }
}

/// Applies a One Euro filter to x and y of the key landmarks.
///
/// Runs every frame, so filters live in flat lists (no map lookups) and each
/// frame costs exactly one fixed-length landmark list.
class LandmarkSmoother {
  LandmarkSmoother({double minCutoff = 1.7, double beta = 0.3})
      : _fx = List.generate(
          Lm.smoothed.length,
          (_) => OneEuroFilter(minCutoff: minCutoff, beta: beta),
          growable: false,
        ),
        _fy = List.generate(
          Lm.smoothed.length,
          (_) => OneEuroFilter(minCutoff: minCutoff, beta: beta),
          growable: false,
        );

  final List<OneEuroFilter> _fx;
  final List<OneEuroFilter> _fy;

  PoseFrame smooth(PoseFrame frame) {
    if (!frame.hasPerson) return frame;
    // A new list per frame: callers may keep earlier frames (recorder, debug
    // overlay), so the landmark list itself must never be reused.
    final out = List<Landmark>.of(frame.landmarks, growable: false);
    final ts = frame.timestampMs;
    const idx = Lm.smoothed;
    for (var k = 0; k < idx.length; k++) {
      final i = idx[k];
      final l = out[i];
      out[i] = Landmark(
        _fx[k].filter(l.x, ts),
        _fy[k].filter(l.y, ts),
        l.z,
        l.visibility,
      );
    }
    return frame.withLandmarks(out);
  }

  void reset() {
    for (final f in _fx) {
      f.reset();
    }
    for (final f in _fy) {
      f.reset();
    }
  }
}
