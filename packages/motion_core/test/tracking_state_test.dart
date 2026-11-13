import 'package:motion_core/motion_core.dart';
import 'package:test/test.dart';

void main() {
  const good = FrameQuality.good;
  const soft = FrameQuality.degraded;
  const bad = FrameQuality.bad;

  /// Feeds [q] every 33 ms from [from] for [ms]; returns the next time.
  int feed(TrackingStateMachine m, FrameQuality q, int from, int ms) {
    var t = from;
    for (; t < from + ms; t += 33) {
      m.update(q, t);
    }
    return t;
  }

  test('starts tracking and stays there on clean frames', () {
    final m = TrackingStateMachine();
    expect(m.state, TrackingState.tracking);
    feed(m, good, 0, 2000);
    expect(m.state, TrackingState.tracking);
    expect(m.paused, isFalse);
  });

  test('a short gap degrades but never pauses', () {
    final m = TrackingStateMachine();
    var t = feed(m, good, 0, 500);
    t = feed(m, bad, t, 200);
    expect(m.state, TrackingState.degraded);
    expect(m.paused, isFalse);
    // Clean again: back to tracking only after the settle time.
    m.update(good, t);
    expect(m.state, TrackingState.degraded);
    feed(m, good, t, 400);
    expect(m.state, TrackingState.tracking);
  });

  test('a long gap is a loss', () {
    final m = TrackingStateMachine();
    var t = feed(m, good, 0, 500);
    t = feed(m, bad, t, 240);
    expect(m.state, TrackingState.degraded);
    feed(m, bad, t, 100);
    expect(m.state, TrackingState.lost);
    expect(m.paused, isTrue);
  });

  test('recovery needs a steady spell; a bad frame restarts it', () {
    final m = TrackingStateMachine();
    var t = feed(m, bad, 0, 400);
    expect(m.state, TrackingState.lost);
    t = feed(m, good, t, 200);
    expect(m.state, TrackingState.recovering);
    expect(m.paused, isTrue);
    m.update(bad, t);
    expect(m.state, TrackingState.lost);
    t = feed(m, good, t + 33, 280);
    expect(m.state, TrackingState.recovering);
    feed(m, good, t, 100);
    expect(m.state, TrackingState.tracking);
  });

  test('recovering on imperfect frames resumes as degraded', () {
    final m = TrackingStateMachine();
    final t = feed(m, bad, 0, 400);
    feed(m, soft, t, 400);
    expect(m.state, TrackingState.degraded);
    expect(m.paused, isFalse);
  });

  test('imperfect frames degrade only after a dwell, and never pause', () {
    final m = TrackingStateMachine();
    var t = feed(m, good, 0, 300);
    t = feed(m, soft, t, 300);
    expect(m.state, TrackingState.tracking);
    t = feed(m, soft, t, 300);
    expect(m.state, TrackingState.degraded);
    feed(m, soft, t, 10000);
    expect(m.state, TrackingState.degraded);
  });

  test('flickering between clean and imperfect does not flap the state', () {
    final m = TrackingStateMachine();
    final seen = <TrackingState>{};
    for (var i = 0; i < 200; i++) {
      seen.add(m.update(i.isEven ? good : soft, i * 33));
    }
    expect(seen, {TrackingState.tracking});
  });

  test('a stall forces a loss without waiting for a frame', () {
    final m = TrackingStateMachine();
    feed(m, good, 0, 300);
    m.forceLost();
    expect(m.state, TrackingState.lost);
    final t = feed(m, good, 5000, 280);
    expect(m.state, TrackingState.recovering);
    feed(m, good, t, 100);
    expect(m.state, TrackingState.tracking);
  });

  test('custom timings are respected', () {
    final m = TrackingStateMachine(
        const TrackingStateConfig(pauseAfterMs: 1000, resumeAfterMs: 0));
    final t = feed(m, bad, 0, 900);
    expect(m.state, TrackingState.degraded);
    feed(m, bad, t, 200);
    expect(m.state, TrackingState.lost);
    m.update(good, 5000);
    expect(m.state, TrackingState.tracking);
  });
}
