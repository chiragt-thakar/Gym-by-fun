// The root-cause tests for "tracking is lost when I move a little": play
// must continue while the torso is tracked, whatever happens to the feet,
// a knee or a wrist, and short gaps must be bridged.
import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:test/test.dart';

PoseFrame hide(PoseFrame f, Iterable<int> indices, [double v = 0.1]) {
  final set = indices.toSet();
  return f.withLandmarks([
    for (var i = 0; i < f.landmarks.length; i++)
      set.contains(i) ? f.landmarks[i].copyWith(visibility: v) : f.landmarks[i]
  ]);
}

const feet = [27, 28, 29, 30, 31, 32];
const hands = [15, 16, 17, 18, 19, 20, 21, 22];
const idle = ScriptStep(Action.idle, 1200);

Iterable<Move> started(List<MotionEvent> e) =>
    e.whereType<MoveStarted>().map((s) => s.move);

void main() {
  const gate = QualityGate();
  PoseFrame frame(List<Landmark> lm) => PoseFrame(
      timestampMs: 0, landmarks: lm, imageWidth: 480, imageHeight: 640);

  group('graded quality', () {
    test('a clean full body is good', () {
      final q = gate.check(frame(SyntheticBody(noise: 0).pose()));
      expect(q.level, FrameQuality.good);
      expect(q.ok, isTrue);
      expect(q.usable, isTrue);
    });

    test('feet cut off: degraded but usable, with the reason kept', () {
      final q = gate.check(frame(SyntheticBody(noise: 0, footY: 1.08).pose()));
      expect(q.level, FrameQuality.degraded);
      expect(q.ok, isFalse);
      expect(q.usable, isTrue);
      expect(q.issue, TrackingIssue.outOfFrame);
    });

    test('a hidden knee or ankle: degraded but usable', () {
      final lm = SyntheticBody(noise: 0).pose();
      for (final i in [Lm.leftKnee, Lm.rightAnkle]) {
        final q = gate.check(hide(frame(lm), [i]));
        expect(q.level, FrameQuality.degraded, reason: 'landmark $i');
        expect(q.issue, TrackingIssue.lowVisibility);
      }
    });

    test('a hidden shoulder or hip: unusable', () {
      final lm = SyntheticBody(noise: 0).pose();
      for (final i in Lm.core) {
        final q = gate.check(hide(frame(lm), [i]));
        expect(q.usable, isFalse, reason: 'landmark $i');
      }
    });

    test('the torso leaving the image: unusable', () {
      final q = gate.check(frame(SyntheticBody(noise: 0, centerX: 1.1).pose()));
      expect(q.usable, isFalse);
      expect(q.issue, TrackingIssue.outOfFrame);
    });

    test('slightly too small is degraded; far too small is unusable', () {
      // 256 px minimum at 640 px tall = 0.40 of the image.
      final near = SyntheticBody(noise: 0, height: 0.38, footY: 0.7).pose();
      final far = SyntheticBody(noise: 0, height: 0.25, footY: 0.6).pose();
      expect(gate.check(frame(near)).level, FrameQuality.degraded);
      expect(gate.check(frame(near)).issue, TrackingIssue.tooFar);
      expect(gate.check(frame(far)).level, FrameQuality.bad);
    });

    test('nobody there: unusable', () {
      expect(gate.check(frame(const [])).usable, isFalse);
    });
  });

  group('BodyTracker', () {
    test('reports tracking on clean frames and bridges a short dropout', () {
      final tracker = BodyTracker();
      TrackedFrame? t;
      for (var i = 0; i < 30; i++) {
        t = tracker.process(stickFrame(t: i * 33));
      }
      expect(t!.state, TrackingState.tracking);
      expect(t.playable, isTrue);
      expect(t.coasted, isFalse);

      // 132 ms with no body at all.
      for (var i = 30; i < 34; i++) {
        t = tracker.process(PoseFrame(timestampMs: i * 33, landmarks: const []));
        expect(t.state, TrackingState.degraded);
        expect(t.paused, isFalse);
        expect(t.playable, isFalse, reason: 'a prediction never plays');
        // The display keeps a body on screen.
        expect(t.coasted, isTrue);
        expect(t.frame.hasPerson, isTrue);
        expect(t.raw.hasPerson, isFalse);
      }
      t = tracker.process(stickFrame(t: 34 * 33));
      expect(t.playable, isTrue);
    });

    test('a long dropout is a loss; return recovers without a restart', () {
      final tracker = BodyTracker();
      var ts = 0;
      for (; ts < 600; ts += 33) {
        tracker.process(stickFrame(t: ts));
      }
      for (final end = ts + 1000; ts < end; ts += 33) {
        tracker.process(PoseFrame(timestampMs: ts, landmarks: const []));
      }
      expect(tracker.state, TrackingState.lost);
      // Back in view, a step to the side of where they were.
      final seen = <TrackingState>[];
      for (final end = ts + 600; ts < end; ts += 33) {
        seen.add(tracker.process(stickFrame(t: ts, shiftX: 0.1)).state);
      }
      expect(seen.first, TrackingState.recovering);
      expect(seen.last, TrackingState.tracking);
    });

    test('a passer-by cannot take over while the player is in view', () {
      final tracker = BodyTracker();
      final player = stickFrame();
      double hipX(PoseFrame f) => (f[Lm.leftHip].x + f[Lm.rightHip].x) / 2;
      for (var t = 0; t < 2000; t += 33) {
        final other = stickFrame(t: t, shiftX: 0.3);
        final out = tracker.process(PoseFrame(
          timestampMs: t,
          imageWidth: 480,
          imageHeight: 640,
          landmarks: t > 500 ? other.landmarks : stickFrame(t: t).landmarks,
          others: t > 500 ? [stickFrame(t: t).landmarks] : const [],
        ));
        expect(hipX(out.frame), closeTo(hipX(player), 1e-6));
        expect(out.state, TrackingState.tracking);
      }
    });

    test('markStalled forces a loss', () {
      final tracker = BodyTracker()..process(stickFrame(t: 0));
      tracker.markStalled();
      expect(tracker.state, TrackingState.lost);
      expect(tracker.paused, isTrue);
    });
  });

  group('play continues on partial visibility', () {
    late SyntheticSession s;
    late CalibrationProfile cal;
    setUp(() {
      s = SyntheticSession(SyntheticBody(seed: 31));
      cal = s.calibrate();
    });

    test('feet out of view: a squat still counts, and nothing pauses', () {
      final engine = MotionEngine(calibration: cal);
      final frames = s
          .record([idle, const ScriptStep(Action.squat, 1500), idle])
          .frames
          .map((f) => hide(f, feet))
          .toList();
      final e = runEngine(engine, frames);
      expect(started(e), [Move.squat]);
      expect(e.whereType<RepCompleted>().single.move, Move.squat);
      expect(e.whereType<TrackingPaused>(), isEmpty);
      expect(engine.light, TrackingLight.green);
      expect(engine.trackingState, TrackingState.degraded);
    });

    test('feet out of view: a shallow dip still does not count', () {
      final engine = MotionEngine(calibration: cal);
      final frames = s
          .record([idle, const ScriptStep(Action.shallowDip, 1500), idle])
          .frames
          .map((f) => hide(f, feet))
          .toList();
      expect(started(runEngine(engine, frames)), isEmpty);
    });

    test('feet out of view: leans and arm raises are unaffected', () {
      final engine = MotionEngine(calibration: cal);
      final frames = s
          .record([
            idle,
            const ScriptStep(Action.leanLeft, 1000),
            idle,
            const ScriptStep(Action.raiseArms, 1200),
            idle,
          ])
          .frames
          .map((f) => hide(f, feet))
          .toList();
      expect(started(runEngine(engine, frames)),
          [Move.leanLeft, Move.raiseArms]);
    });

    test('a wrist that flickers out mid-raise does not end the move', () {
      final engine = MotionEngine(calibration: cal);
      final frames = s
          .record([idle, const ScriptStep(Action.raiseArms, 1800), idle])
          .frames
          .map((f) => f.timestampMs >= 2000 && f.timestampMs < 2150
              ? hide(f, hands)
              : f)
          .toList();
      final e = runEngine(engine, frames);
      expect(started(e), [Move.raiseArms]);
      expect(e.whereType<MoveEnded>().single.completed, isTrue);
      expect(e.whereType<RepCompleted>(), hasLength(1));
    });

    test('hidden wrists never start a raise', () {
      final engine = MotionEngine(calibration: cal);
      final frames = s
          .record([idle, const ScriptStep(Action.raiseArms, 1500), idle])
          .frames
          .map((f) => hide(f, [...hands, Lm.leftElbow, Lm.rightElbow]))
          .toList();
      expect(started(runEngine(engine, frames)), isEmpty);
    });

    test('a stall ends moves once and recovers through the state machine',
        () {
      final engine = MotionEngine(calibration: cal);
      final frames = s
          .record([idle, const ScriptStep(Action.squat, 3000)])
          .frames
          .where((f) => f.timestampMs < 2600)
          .toList();
      runEngine(engine, frames);
      final stalled = engine.stall(2700);
      expect(stalled.whereType<MoveEnded>().single.completed, isFalse);
      expect(stalled.whereType<TrackingPaused>(), hasLength(1));
      expect(engine.stall(2800), isEmpty, reason: 'already paused');
      expect(engine.light, TrackingLight.red);
      final back = s.record([idle]).frames.map((f) => PoseFrame(
          timestampMs: f.timestampMs + 5000,
          landmarks: f.landmarks,
          imageWidth: 480,
          imageHeight: 640));
      expect(runEngine(engine, back).whereType<TrackingResumed>(),
          hasLength(1));
    });
  });
}
