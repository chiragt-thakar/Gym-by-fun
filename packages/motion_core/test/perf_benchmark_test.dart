import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:test/test.dart';

/// Hot-path budget: MotionEngine.process runs once per camera frame on the
/// UI isolate, so it must stay far below the 33 ms frame budget. The bound
/// is deliberately generous (CI runners are slow and noisy); real devices
/// are measured from the debug screen (docs/performance.md).
void main() {
  test('MotionEngine.process averages under 0.3 ms per frame', () {
    final s = SyntheticSession(SyntheticBody(seed: 11));
    final calibration = s.calibrate();
    final frames = s.record(s.randomScript(1.7)).frames;
    expect(frames.length, greaterThanOrEqualTo(3000));
    final run = frames.take(3000).toList(growable: false);

    // Warm up the JIT so the measurement reflects steady state.
    final warm = MotionEngine(calibration: calibration);
    for (final f in run) {
      warm.process(f);
    }

    final engine = MotionEngine(calibration: calibration);
    var events = 0;
    final sw = Stopwatch()..start();
    for (final f in run) {
      events += engine.process(f).length;
    }
    sw.stop();
    final avgMs = sw.elapsedMicroseconds / 1000 / run.length;
    // ignore: avoid_print
    print('MotionEngine.process: ${avgMs.toStringAsFixed(4)} ms/frame '
        'over ${run.length} frames, $events events');
    expect(events, greaterThan(0));
    expect(avgMs, lessThan(0.3));
  });
}
