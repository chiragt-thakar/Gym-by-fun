import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:test/test.dart';

/// A detector a game might add: proves the plug-in path end to end.
class ClapDetector implements Recogniser {
  int updates = 0;
  CalibrationProfile? recalibratedTo;

  @override
  String get id => 'clap';
  @override
  String get state => 'idle';
  @override
  double get measure => 0;
  @override
  void update(BodyFeatures b, List<MotionEvent> out) {
    if (++updates == 3) {
      out.add(GestureEvent('clap', GesturePhase.fired, b.timestampMs));
    }
  }

  @override
  void interrupt(int timestampMs, List<MotionEvent> out) {}
  @override
  void recalibrate(CalibrationProfile c) => recalibratedTo = c;
}

final standing = CalibrationProfile.fromStanding(stickFrame());

/// Unfiltered engine with one plug-in, so geometry in the tests is exact.
MotionEngine engineWith(String id, [Object? config]) => MotionEngine(
      calibration: standing,
      smooth: false,
      detectors: [DetectorSpec(id, config)],
    );

List<GestureEvent> gestures(List<MotionEvent> e, String id) =>
    e.whereType<GestureEvent>().where((g) => g.gesture == id).toList();

List<PoseFrame> still(int from, int frames) =>
    [for (var i = 0; i < frames; i++) stickFrame(t: (from + i) * 33)];

void main() {
  group('registry', () {
    final ctx = DetectorContext(calibration: standing);

    test('the standard registry knows every built-in detector', () {
      expect(
          DetectorRegistry.standard().ids,
          containsAll([
            DetectorIds.squat,
            DetectorIds.lean,
            DetectorIds.raiseArms,
            DetectorIds.barrierHold,
            DetectorIds.sideStep,
            DetectorIds.jump,
            DetectorIds.punch,
            DetectorIds.twist,
            DetectorIds.kneeLift,
          ]));
    });

    test('built detectors report their registry id', () {
      final reg = DetectorRegistry.standard();
      for (final id in reg.ids) {
        expect(reg.build(DetectorSpec(id), ctx).id, id);
      }
    });

    test('an unknown id or a config of the wrong type is refused', () {
      final reg = DetectorRegistry.standard();
      expect(() => reg.build(const DetectorSpec('nope'), ctx),
          throwsArgumentError);
      expect(
          () => reg.build(
              const DetectorSpec(DetectorIds.jump, PunchConfig()), ctx),
          throwsArgumentError);
      expect(() => reg.register(DetectorIds.jump, (c, cfg) => ClapDetector()),
          throwsArgumentError);
    });

    test('a typed config reaches its detector', () {
      final d = DetectorRegistry.standard().build(
          const DetectorSpec(DetectorIds.jump, JumpConfig(riseTorso: 0.5)),
          ctx);
      expect((d as JumpDetector).c.riseTorso, 0.5);
    });

    test('a game adds a gesture with one registration', () {
      final clap = ClapDetector();
      final reg = DetectorRegistry.standard()
        ..register('clap', (c, cfg) => clap);
      final engine = MotionEngine(
        calibration: standing,
        detectors: const [DetectorSpec('clap')],
        registry: reg,
      );
      expect(engine.detectors.map((d) => d.id),
          ['squat', 'lean', 'raiseArms', 'clap']);
      final e = runEngine(engine, still(0, 10));
      expect(gestures(e, 'clap'), hasLength(1));
      expect(engine.snapshot.states.keys, contains('clap'));
    });

    test('the same detector cannot be requested twice', () {
      expect(
          () => MotionEngine(
                calibration: standing,
                enableSideStep: true,
                detectors: const [DetectorSpec(DetectorIds.sideStep)],
              ),
          throwsArgumentError);
    });

    test('plug-ins are off unless asked for', () {
      final engine = MotionEngine(calibration: standing);
      expect(engine.detectors.map((d) => d.id), ['squat', 'lean', 'raiseArms']);
    });
  });

  group('jump', () {
    List<PoseFrame> hop() {
      final rises = [
        ...List.filled(30, 0.0),
        0.02, 0.05, 0.07, 0.07, 0.05, 0.02,
        ...List.filled(20, 0.0),
      ];
      return [
        for (var i = 0; i < rises.length; i++)
          stickFrame(t: i * 33, riseY: rises[i])
      ];
    }

    test('fires once at take-off and reports the landing', () {
      final e = gestures(
          runEngine(engineWith(DetectorIds.jump), hop()), DetectorIds.jump);
      expect(e.map((g) => g.phase), [GesturePhase.fired, GesturePhase.ended]);
      expect(e.first.strength, greaterThan(1));
      expect(e.last.heldMs, inInclusiveRange(100, 300));
      expect(e.last.completed, isTrue);
    });

    test('two hops are two jumps', () {
      final second = hop()
          .map((f) => PoseFrame(
              timestampMs: f.timestampMs + 3000,
              landmarks: f.landmarks,
              imageWidth: 480,
              imageHeight: 640))
          .toList();
      final e = gestures(
          runEngine(engineWith(DetectorIds.jump), [...hop(), ...second]),
          DetectorIds.jump);
      expect(e.where((g) => g.phase == GesturePhase.fired), hasLength(2));
    });

    test('standing up from a squat is not a jump (the feet stay down)', () {
      final body = SyntheticBody(noise: 0);
      PoseFrame f(int i, double squat) => PoseFrame(
          timestampMs: i * 33,
          landmarks: body.pose(squat: squat),
          imageWidth: 480,
          imageHeight: 640);
      final engine = MotionEngine(
        calibration: CalibrationProfile.fromStanding(f(0, 0)),
        smooth: false,
        detectors: const [DetectorSpec(DetectorIds.jump)],
      );
      final e = runEngine(engine, [
        for (var i = 0; i < 30; i++) f(i, 0),
        for (var i = 30; i < 90; i++) f(i, 1),
        for (var i = 90; i < 120; i++) f(i, 0),
      ]);
      expect(gestures(e, DetectorIds.jump), isEmpty);
      expect(e.whereType<RepCompleted>().single.move, Move.squat);
    });

    test('a small bounce is not a jump', () {
      final frames = [
        ...still(0, 30),
        for (var i = 30; i < 36; i++) stickFrame(t: i * 33, riseY: 0.02),
        ...still(36, 20),
      ];
      expect(
          gestures(runEngine(engineWith(DetectorIds.jump), frames),
              DetectorIds.jump),
          isEmpty);
    });
  });

  group('knee lift', () {
    List<PoseFrame> march() => [
          ...still(0, 10),
          for (var i = 10; i < 20; i++) stickFrame(t: i * 33, liftL: 1),
          ...still(20, 10),
          for (var i = 30; i < 40; i++) stickFrame(t: i * 33, liftR: 1),
          ...still(40, 10),
        ];

    test('each lift fires once, with its side', () {
      final e = gestures(
          runEngine(engineWith(DetectorIds.kneeLift), march()),
          DetectorIds.kneeLift);
      expect(e.map((g) => g.side), [BodySide.left, BodySide.right]);
      expect(e.every((g) => g.phase == GesturePhase.fired), isTrue);
    });

    test('a squat lowers both knees and never counts', () {
      final frames = [
        ...still(0, 10),
        for (var i = 10; i < 40; i++) stickFrame(t: i * 33, dip: 1),
        ...still(40, 10),
      ];
      expect(
          gestures(runEngine(engineWith(DetectorIds.kneeLift), frames),
              DetectorIds.kneeLift),
          isEmpty);
    });

    test('a hidden knee changes nothing', () {
      final frames = [
        ...still(0, 10),
        for (var i = 10; i < 20; i++)
          stickFrame(t: i * 33, liftL: 1, hidden: {Lm.leftKnee: 0.1}),
        ...still(20, 10),
      ];
      expect(
          gestures(runEngine(engineWith(DetectorIds.kneeLift), frames),
              DetectorIds.kneeLift),
          isEmpty);
    });
  });

  group('punch', () {
    // Stick figure, x in image-height units: the right shoulder is at
    // (0.44, 0.37), the left at (0.31, 0.37); a torso is 0.18.
    PoseFrame arm(int i, int wrist, (double, double) at) =>
        stickFrame(t: i * 33, override: {wrist: at});

    List<PoseFrame> thrust(int wrist, double dir) {
      final sx = 0.375 + dir * 0.065;
      (double, double) p(double out, double y) => (sx + dir * out, y);
      var i = 0;
      return [
        for (var k = 0; k < 15; k++) arm(i++, wrist, p(0.03, 0.34)),
        arm(i++, wrist, p(0.06, 0.36)),
        arm(i++, wrist, p(0.12, 0.37)),
        arm(i++, wrist, p(0.18, 0.37)),
        for (var k = 0; k < 10; k++) arm(i++, wrist, p(0.18, 0.37)),
        // Pull back fast.
        arm(i++, wrist, p(0.12, 0.37)),
        arm(i++, wrist, p(0.06, 0.36)),
        for (var k = 0; k < 10; k++) arm(i++, wrist, p(0.03, 0.34)),
      ];
    }

    test('a fast thrust fires once, with the hand; pulling back does not',
        () {
      final e = gestures(
          runEngine(engineWith(DetectorIds.punch), thrust(Lm.rightWrist, 1)),
          DetectorIds.punch);
      expect(e, hasLength(1));
      expect(e.single.phase, GesturePhase.fired);
      expect(e.single.side, BodySide.right);
      expect(e.single.strength, greaterThan(1));
    });

    test('the left hand is reported as the left', () {
      final e = gestures(
          runEngine(engineWith(DetectorIds.punch), thrust(Lm.leftWrist, -1)),
          DetectorIds.punch);
      expect(e.single.side, BodySide.left);
    });

    test('a slow reach is not a punch', () {
      final frames = [
        for (var i = 0; i < 40; i++)
          arm(i, Lm.rightWrist,
              (0.44 + 0.03 + 0.15 * (i / 39), 0.34 + 0.03 * (i / 39)))
      ];
      expect(
          gestures(runEngine(engineWith(DetectorIds.punch), frames),
              DetectorIds.punch),
          isEmpty);
    });

    test('a hidden wrist never punches', () {
      final frames = [
        for (final f in thrust(Lm.rightWrist, 1))
          f.withLandmarks([
            for (var i = 0; i < f.landmarks.length; i++)
              i == Lm.rightWrist
                  ? f.landmarks[i].copyWith(visibility: 0.2)
                  : f.landmarks[i]
          ])
      ];
      expect(
          gestures(runEngine(engineWith(DetectorIds.punch), frames),
              DetectorIds.punch),
          isEmpty);
    });
  });

  group('twist', () {
    List<PoseFrame> turn(double deg) => [
          ...still(0, 10),
          for (var i = 10; i < 25; i++) stickFrame(t: i * 33, twist: deg),
          ...still(25, 10),
        ];

    test('starts, holds and ends, with the side the chest turned to', () {
      final e = gestures(
          runEngine(engineWith(DetectorIds.twist), turn(60)),
          DetectorIds.twist);
      expect(e.first.phase, GesturePhase.started);
      expect(e.first.side, BodySide.right);
      expect(e.last.phase, GesturePhase.ended);
      expect(e.last.heldMs, inInclusiveRange(300, 500));
      expect(e.where((g) => g.phase == GesturePhase.started), hasLength(1));
      expect(e.where((g) => g.phase == GesturePhase.held), isNotEmpty);
    });

    test('the other way is the other side', () {
      final e = gestures(
          runEngine(engineWith(DetectorIds.twist), turn(-60)),
          DetectorIds.twist);
      expect(e.first.side, BodySide.left);
    });

    test('a small turn is not a twist', () {
      expect(
          gestures(runEngine(engineWith(DetectorIds.twist), turn(20)),
              DetectorIds.twist),
          isEmpty);
    });

    test('a tracking loss ends a twist without credit', () {
      final engine = engineWith(DetectorIds.twist);
      runEngine(engine, [
        ...still(0, 10),
        for (var i = 10; i < 25; i++) stickFrame(t: i * 33, twist: 60),
      ]);
      final e = gestures(engine.stall(25 * 33), DetectorIds.twist);
      expect(e.single.phase, GesturePhase.ended);
      expect(e.single.completed, isFalse);
    });
  });

  group('continuous signals', () {
    late SyntheticSession s;
    late MotionEngine engine;
    setUp(() {
      s = SyntheticSession(SyntheticBody(seed: 4));
      engine = MotionEngine(calibration: s.calibrate());
    });

    void playUntil(Action a, int ms) {
      runEngine(
          engine,
          s.record([const ScriptStep(Action.idle, 1200), ScriptStep(a, 2500)])
              .frames
              .where((f) => f.timestampMs < ms));
    }

    test('nothing tracked: the neutral, invalid signal', () {
      expect(engine.signals.valid, isFalse);
      expect(MotionSignals.none.squat, 0);
    });

    test('standing is near zero on every axis', () {
      playUntil(Action.idle, 1000);
      final g = engine.signals;
      expect(g.valid, isTrue);
      expect(g.squat.abs(), lessThan(0.15));
      expect(g.lean.abs(), lessThan(0.15));
      expect(g.hipX.abs(), lessThan(0.1));
      expect(g.armLeft, lessThan(0.2));
    });

    test('a full squat reads about 1 of the calibrated depth', () {
      playUntil(Action.squat, 2500);
      expect(engine.signals.squat, closeTo(1, 0.15));
    });

    test('a full lean reads about −1 / +1', () {
      playUntil(Action.leanLeft, 2500);
      expect(engine.signals.lean, closeTo(-1, 0.15));
    });

    test('raised arms read about 1 of the calibrated reach', () {
      playUntil(Action.raiseArms, 2500);
      expect(engine.signals.armLeft, closeTo(1, 0.2));
      expect(engine.signals.armRight, closeTo(1, 0.2));
    });

    test('signals go neutral while tracking is lost', () {
      playUntil(Action.squat, 2500);
      engine.stall(2600);
      expect(engine.signals.valid, isFalse);
    });
  });
}
