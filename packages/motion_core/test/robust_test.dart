import 'package:motion_core/motion_core.dart';
import 'package:test/test.dart';

void main() {
  test('median of odd and even lists, without touching the input', () {
    final v = [3.0, 1.0, 2.0];
    expect(median(v), 2);
    expect(v, [3.0, 1.0, 2.0]);
    expect(median([4.0, 1.0, 3.0, 2.0]), 2.5);
    expect(median([7.0]), 7);
  });

  test('percentile interpolates', () {
    expect(percentile([0.0, 10.0], 0.25), 2.5);
    expect(percentile([1.0, 2.0, 3.0, 4.0, 5.0], 0), 1);
    expect(percentile([1.0, 2.0, 3.0, 4.0, 5.0], 1), 5);
    expect(percentile([1.0, 2.0, 3.0, 4.0, 5.0], 0.9), closeTo(4.6, 1e-9));
  });

  test('empty input gives NaN, never throws', () {
    expect(median(const []).isNaN, isTrue);
    expect(percentile(const [], 0.5).isNaN, isTrue);
    expect(mad(const []).isNaN, isTrue);
    expect(robustMean(const []).isNaN, isTrue);
  });

  test('MAD ignores one wild value', () {
    expect(mad([1.0, 2.0, 3.0, 4.0, 100.0]), 1);
  });

  test('robust mean rejects the outlier a plain mean would follow', () {
    final v = [1.0, 2.0, 3.0, 4.0, 100.0];
    expect(robustMean(v), 2.5);
    expect(v.reduce((a, b) => a + b) / v.length, 22);
  });

  test('robust mean of identical values is that value', () {
    expect(robustMean([0.4, 0.4, 0.4]), 0.4);
  });
}
