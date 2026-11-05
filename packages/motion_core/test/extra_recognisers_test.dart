import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:test/test.dart';

List<MotionEvent> play(List<ScriptStep> script,
    {bool barrier = true,
    bool step = true,
    MotionThresholds t = const MotionThresholds(),
    ExtraMoveThresholds x = const ExtraMoveThresholds(),
    SyntheticBody? body,
    int fps = 30}) {
  final s = SyntheticSession(body ?? SyntheticBody(seed: 4), fps: fps);
  final engine = MotionEngine(
      calibration: s.calibrate(),
      thresholds: t,
      extraThresholds: x,
      enableBarrierHold: barrier,
      enableSideStep: step);
  return runEngine(engine, s.record(script).frames);
}

Iterable<ExtraMove> started(List<MotionEvent> e) =>
    e.whereType<ExtraMoveStarted>().map((s) => s.move);

Iterable<Move> coreStarted(List<MotionEvent> e) =>
    e.whereType<MoveStarted>().map((s) => s.move);

const idle = ScriptStep(Action.idle, 1200);

void main() {
  group('barrier hold', () {
    test('starts, holds every ~100 ms, ends with the held time', () {
      final e = play([idle, const ScriptStep(Action.barrierHold, 2500), idle],
          step: false);
      expect(started(e), [ExtraMove.barrierHold]);
      final held = e.whereType<ExtraMoveHeld>().toList();
      expect(held.length, greaterThan(15));
      final end = e.whereType<ExtraMoveEnded>().single;
      expect(end.completed, isTrue);
      expect(end.heldMs, inInclusiveRange(1600, 2500));
      expect(coreStarted(e), isEmpty);
    });

    test('holds through a single-frame jitter (200 ms grace)', () {
      // Two holds 100 ms apart behave as one.
      final e = play([
        idle,
        const ScriptStep(Action.barrierHold, 1500),
        const ScriptStep(Action.barrierHold, 1500),
        idle,
      ], step: false);
      expect(started(e).length, lessThanOrEqualTo(2));
      expect(e.whereType<ExtraMoveEnded>().length, started(e).length);
    });

    test('two separate holds give two starts and two ends', () {
      final e = play([
        idle,
        const ScriptStep(Action.barrierHold, 1500),
        idle,
        const ScriptStep(Action.barrierHold, 1500),
        idle,
      ], step: false);
      expect(started(e), [ExtraMove.barrierHold, ExtraMove.barrierHold]);
      expect(e.whereType<ExtraMoveEnded>().length, 2);
    });

    test('a held guard is never a barrier (only its brief transit is)', () {
      final e = play([idle, const ScriptStep(Action.guardUp, 1800), idle],
          step: false);
      // Raising the hands to the face passes through the chest zone for a
      // few frames; the steady guard pose itself never holds a barrier.
      for (final end in e.whereType<ExtraMoveEnded>()) {
        expect(end.heldMs, lessThan(300));
      }
    });

    test('decoys never start a barrier', () {
      for (final a in [
        Action.armsToChest,
        Action.raiseArms,
        Action.oneArmRaise,
        Action.squat,
        Action.leanLeft,
        Action.forwardBend,
        Action.idle,
      ]) {
        final e = play([idle, ScriptStep(a, 1800), idle], step: false);
        expect(started(e), isEmpty, reason: '$a');
      }
    });

    test('one hand only counts in low-impact mode', () {
      final script = [
        idle,
        const ScriptStep(Action.oneHandBarrier, 1800),
        idle
      ];
      expect(started(play(script, step: false)), isEmpty);
      expect(
          started(play(script,
              step: false, x: const ExtraMoveThresholds.lowImpact())),
          [ExtraMove.barrierHold]);
    });

    test('does not trigger raise arms', () {
      final e = play([idle, const ScriptStep(Action.barrierHold, 2000), idle],
          step: false);
      expect(coreStarted(e), isEmpty);
    });
  });

  group('side step', () {
    test('step left and right start, hold and end', () {
      final e = play([
        idle,
        const ScriptStep(Action.stepLeft, 1500),
        idle,
        const ScriptStep(Action.stepRight, 1500),
        idle,
      ], barrier: false);
      expect(started(e), [ExtraMove.stepLeft, ExtraMove.stepRight]);
      expect(e.whereType<ExtraMoveHeld>(), isNotEmpty);
      expect(e.whereType<ExtraMoveEnded>().map((x) => x.move),
          [ExtraMove.stepLeft, ExtraMove.stepRight]);
    });

    test('a torso lean is not a step', () {
      final e = play([
        idle,
        const ScriptStep(Action.leanLeft, 1500),
        idle,
        const ScriptStep(Action.leanRight, 1500),
        idle,
      ], barrier: false);
      expect(started(e), isEmpty);
    });

    test('a hip sway with planted feet is rejected as too shallow', () {
      final e = play([idle, const ScriptStep(Action.hipSway, 1500), idle],
          barrier: false);
      expect(started(e), isEmpty);
      expect(e.whereType<ExtraMoveRejected>().single.reason,
          RejectReason.tooShallow);
    });

    test('a small step counts only in low-impact mode', () {
      final script = [
        idle,
        const ScriptStep(Action.stepRight, 1500, intensity: 0.45),
        idle
      ];
      expect(started(play(script, barrier: false)), isEmpty);
      expect(
          started(play(script,
              barrier: false, x: const ExtraMoveThresholds.lowImpact())),
          [ExtraMove.stepRight]);
    });

    test('idle, squat and arm decoys never start a step', () {
      for (final a in [
        Action.idle,
        Action.squat,
        Action.raiseArms,
        Action.sway,
        Action.barrierHold,
      ]) {
        final e = play([idle, ScriptStep(a, 1800), idle], barrier: false);
        expect(started(e), isEmpty, reason: '$a');
      }
    });
  });

  group('opt-in', () {
    test('engine default emits no extra events and keeps snapshot keys', () {
      final s = SyntheticSession(SyntheticBody(seed: 4));
      final engine = MotionEngine(calibration: s.calibrate());
      final e = runEngine(
          engine,
          s.record([
            idle,
            const ScriptStep(Action.barrierHold, 1500),
            const ScriptStep(Action.stepLeft, 1500),
            idle,
          ]).frames);
      expect(
          e.where((x) =>
              x is ExtraMoveStarted ||
              x is ExtraMoveHeld ||
              x is ExtraMoveEnded ||
              x is ExtraMoveRejected),
          isEmpty);
      expect(engine.snapshot.states.keys, ['squat', 'lean', 'raiseArms']);
    });

    test('tracking pause ends a barrier without credit', () {
      final s = SyntheticSession(SyntheticBody(seed: 4));
      final engine =
          MotionEngine(calibration: s.calibrate(), enableBarrierHold: true);
      final frames = s.record([
        idle,
        const ScriptStep(Action.barrierHold, 1500),
      ]).frames;
      final e = runEngine(engine, frames);
      final last = frames.last.timestampMs;
      final out = <MotionEvent>[...e];
      for (var t = last + 33; t < last + 600; t += 33) {
        out.addAll(engine.process(PoseFrame(
            timestampMs: t,
            imageWidth: 480,
            imageHeight: 640,
            landmarks: List.filled(Lm.count, const Landmark(0.5, 0.5, 0, 0)))));
      }
      final end = out.whereType<ExtraMoveEnded>().single;
      expect(end.completed, isFalse);
      expect(out.whereType<TrackingPaused>(), isNotEmpty);
    });
  });
}
