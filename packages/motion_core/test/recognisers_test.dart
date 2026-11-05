import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:test/test.dart';

List<MotionEvent> play(List<ScriptStep> script,
    {MotionThresholds t = const MotionThresholds(),
    SyntheticBody? body,
    int fps = 30}) {
  final s = SyntheticSession(body ?? SyntheticBody(seed: 4), fps: fps);
  final engine = MotionEngine(calibration: s.calibrate(), thresholds: t);
  return runEngine(engine, s.record(script).frames);
}

Iterable<Move> started(List<MotionEvent> e) =>
    e.whereType<MoveStarted>().map((s) => s.move);

const idle = ScriptStep(Action.idle, 1200);

void main() {
  group('squat', () {
    test('a full squat starts, holds, ends and completes a rep', () {
      final e = play([idle, const ScriptStep(Action.squat, 1500), idle]);
      expect(started(e), [Move.squat]);
      expect(e.whereType<MoveHeld>().where((h) => h.move == Move.squat),
          isNotEmpty);
      expect(e.whereType<RepCompleted>().single.move, Move.squat);
      final ended = e.whereType<MoveEnded>().single;
      expect(ended.completed, isTrue);
    });

    test('a forward bend without hip drop does not count', () {
      final e = play([idle, const ScriptStep(Action.forwardBend, 1500), idle]);
      expect(started(e), isEmpty);
    });

    test('a shallow dip is rejected as too shallow, never started', () {
      final e = play(
          [idle, const ScriptStep(Action.squat, 1500, intensity: 0.45), idle]);
      expect(started(e), isEmpty);
      expect(
          e.whereType<MoveRejected>().single.reason, RejectReason.tooShallow);
    });

    test('low-impact mode accepts a half squat', () {
      final e = play(
          [idle, const ScriptStep(Action.squat, 1500, intensity: 0.5), idle],
          t: const MotionThresholds.lowImpact());
      expect(started(e), [Move.squat]);
    });

    test('two squats give two reps', () {
      final e = play([
        idle,
        const ScriptStep(Action.squat, 1200),
        const ScriptStep(Action.idle, 600),
        const ScriptStep(Action.squat, 1200),
        idle,
      ]);
      expect(e.whereType<RepCompleted>().length, 2);
    });
  });

  group('lean', () {
    test('lean left then right gives one lane change each', () {
      final e = play([
        idle,
        const ScriptStep(Action.leanLeft, 1000),
        const ScriptStep(Action.idle, 600),
        const ScriptStep(Action.leanRight, 1000),
        idle,
      ]);
      expect(started(e), [Move.leanLeft, Move.leanRight]);
    });

    test('holding a lean changes only one lane', () {
      final e = play([idle, const ScriptStep(Action.leanLeft, 3000), idle]);
      expect(started(e), [Move.leanLeft]);
    });

    test('a side shuffle is not a lean', () {
      final e = play([idle, const ScriptStep(Action.sideShuffle, 1500), idle]);
      expect(started(e), isEmpty);
    });

    test('small sway does not change lanes', () {
      final e = play([idle, const ScriptStep(Action.sway, 1500), idle]);
      expect(started(e), isEmpty);
    });

    test('side-step mode uses hip translation instead', () {
      final e = play([idle, const ScriptStep(Action.sideShuffle, 1500), idle],
          t: const MotionThresholds(sideStepLanes: true));
      expect(started(e), [Move.leanRight]);
    });
  });

  group('raise arms', () {
    test('both arms up for 150 ms starts the move', () {
      final e = play([idle, const ScriptStep(Action.raiseArms, 1200), idle]);
      expect(started(e), [Move.raiseArms]);
      expect(e.whereType<RepCompleted>().single.move, Move.raiseArms);
    });

    test('arms to chest height does not count', () {
      final e = play([idle, const ScriptStep(Action.armsToChest, 1200), idle]);
      expect(started(e), isEmpty);
    });

    test('one arm needs the low-impact option', () {
      final script = [idle, const ScriptStep(Action.oneArmRaise, 1200), idle];
      expect(started(play(script)), isEmpty);
      expect(started(play(script, t: const MotionThresholds.lowImpact())),
          [Move.raiseArms]);
    });
  });

  group('tracking pause', () {
    test('leaving the frame mid-squat ends the move without credit', () {
      final s = SyntheticSession(SyntheticBody(seed: 9));
      final engine = MotionEngine(calibration: s.calibrate());
      // Cut the recording while the player is still low in the squat.
      final frames = s
          .record([idle, const ScriptStep(Action.squat, 2500)])
          .frames
          .where((f) => f.timestampMs < 2400)
          .toList();
      final events = runEngine(engine, frames);
      expect(started(events), [Move.squat]);
      final last = frames.last.timestampMs;
      final gone = [
        for (var i = 1; i <= 15; i++)
          PoseFrame(timestampMs: last + i * 33, landmarks: const [])
      ];
      final out = runEngine(engine, gone);
      expect(out.whereType<MoveEnded>().single.completed, isFalse);
      expect(
          out.whereType<TrackingPaused>().single.issue, TrackingIssue.noPerson);
      expect(engine.light, TrackingLight.red);
      // Coming back resumes after the resume delay.
      final back = s.record([const ScriptStep(Action.idle, 800)]).frames.map(
          (f) => PoseFrame(
              timestampMs: f.timestampMs + last + 1000,
              landmarks: f.landmarks,
              imageHeight: 640));
      final resumed = runEngine(engine, back);
      expect(resumed.whereType<TrackingResumed>(), hasLength(1));
      expect(engine.light, TrackingLight.green);
    });

    test('a short glitch does not pause', () {
      final s = SyntheticSession(SyntheticBody(seed: 9));
      final engine = MotionEngine(calibration: s.calibrate());
      runEngine(engine, s.record([idle]).frames);
      final e = runEngine(engine, [
        for (var i = 0; i < 4; i++)
          PoseFrame(timestampMs: 1300 + i * 33, landmarks: const [])
      ]);
      expect(e, isEmpty);
      expect(engine.light, TrackingLight.amber);
    });
  });
}
