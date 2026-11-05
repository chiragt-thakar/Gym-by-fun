import 'dart:math' as math;

import 'package:motion_core/motion_core.dart';
import 'package:test/test.dart';

void main() {
  test('first sample passes through unchanged', () {
    expect(OneEuroFilter().filter(0.42, 0), 0.42);
  });

  test('reduces jitter on a still signal', () {
    final f = OneEuroFilter();
    final rng = math.Random(3);
    var rawVar = 0.0, outVar = 0.0;
    for (var i = 0; i < 300; i++) {
      final raw = 0.5 + (rng.nextDouble() - 0.5) * 0.02;
      final out = f.filter(raw, i * 33);
      if (i > 30) {
        rawVar += math.pow(raw - 0.5, 2);
        outVar += math.pow(out - 0.5, 2);
      }
    }
    expect(outVar, lessThan(rawVar * 0.5));
  });

  test('follows a fast step with little lag', () {
    final f = OneEuroFilter();
    for (var i = 0; i < 30; i++) {
      f.filter(0.0, i * 33);
    }
    var out = 0.0;
    for (var i = 30; i < 36; i++) {
      out = f.filter(1.0, i * 33);
    }
    // ~200 ms after the step the output is most of the way there.
    expect(out, greaterThan(0.8));
  });

  test('ignores non-increasing timestamps', () {
    final f = OneEuroFilter()..filter(0.1, 100);
    expect(f.filter(0.9, 100), 0.9);
  });
}
