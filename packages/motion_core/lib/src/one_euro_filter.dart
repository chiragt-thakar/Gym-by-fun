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
class LandmarkSmoother {
  LandmarkSmoother({double minCutoff = 1.7, double beta = 0.3})
      : _fx = {
          for (final i in Lm.smoothed)
            i: OneEuroFilter(minCutoff: minCutoff, beta: beta)
        },
        _fy = {
          for (final i in Lm.smoothed)
            i: OneEuroFilter(minCutoff: minCutoff, beta: beta)
        };

  final Map<int, OneEuroFilter> _fx;
  final Map<int, OneEuroFilter> _fy;

  PoseFrame smooth(PoseFrame frame) {
    if (!frame.hasPerson) return frame;
    final out = List<Landmark>.of(frame.landmarks);
    for (final i in Lm.smoothed) {
      final l = frame.landmarks[i];
      out[i] = l.copyWith(
        x: _fx[i]!.filter(l.x, frame.timestampMs),
        y: _fy[i]!.filter(l.y, frame.timestampMs),
      );
    }
    return frame.withLandmarks(out);
  }

  void reset() {
    for (final f in _fx.values) {
      f.reset();
    }
    for (final f in _fy.values) {
      f.reset();
    }
  }
}
