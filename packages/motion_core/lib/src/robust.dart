/// Robust (outlier-rejecting) statistics for calibration and drift
/// correction. Landmark noise is heavy-tailed: one bad frame can be far off,
/// so plain means and min/max are never used on measured ranges.
library;

/// Median of [values]. Returns NaN for an empty list. Does not modify the
/// input.
double median(List<double> values) => percentile(values, 0.5);

/// Linear-interpolated percentile, [p] in 0..1. Returns NaN for an empty
/// list. Does not modify the input.
double percentile(List<double> values, double p) {
  if (values.isEmpty) return double.nan;
  final sorted = List<double>.of(values)..sort();
  if (sorted.length == 1) return sorted[0];
  final pos = p.clamp(0.0, 1.0) * (sorted.length - 1);
  final lo = pos.floor();
  final hi = pos.ceil();
  if (lo == hi) return sorted[lo];
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}

/// Median absolute deviation around [center] (default: the median).
/// Multiply by [madToSigma] for a robust standard-deviation estimate.
double mad(List<double> values, [double? center]) {
  if (values.isEmpty) return double.nan;
  final c = center ?? median(values);
  return median([for (final v in values) (v - c).abs()]);
}

/// Scale factor that turns a MAD into a standard deviation for normally
/// distributed data.
const madToSigma = 1.4826;

/// Mean of the values within [k] robust standard deviations of the median.
/// Falls back to the median when the spread is zero. Returns NaN for an
/// empty list.
double robustMean(List<double> values, {double k = 3}) {
  if (values.isEmpty) return double.nan;
  final m = median(values);
  final s = mad(values, m) * madToSigma;
  if (s <= 0) return m;
  var sum = 0.0;
  var n = 0;
  for (final v in values) {
    if ((v - m).abs() <= k * s) {
      sum += v;
      n++;
    }
  }
  return n == 0 ? m : sum / n;
}
