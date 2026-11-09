import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:test/test.dart';

/// A two-handed bat swing in the image plane: hands together high on the
/// player's right (backlift), then across the body to the left hip.
List<PoseFrame> swing({
  int start = 0,
  int holdMs = 300,
  int swingMs = 500,
  double endShoulder = 20,
  double reach = 1,
}) {
  final frames = <PoseFrame>[];
  var t = start;
  // Backlift: both hands up by the right shoulder.
  for (; t < start + holdMs; t += 33) {
    frames.add(_hands(t, 0.45, 0.25));
  }
  final from = t;
  for (; t <= from + swingMs; t += 33) {
    final k = (t - from) / swingMs;
    final x = 0.45 - k * (0.45 + 0.6 * reach);
    final y = 0.25 - k * (0.25 + (endShoulder < 60 ? 0.9 : -0.1));
    frames.add(_hands(t, x, y));
  }
  for (var i = 0; i < 10; i++, t += 33) {
    frames.add(stickFrame(t: t));
  }
  return frames;
}

/// Both wrists placed at body-space (x, y) torso units from shoulder centre.
PoseFrame _hands(int t, double x, double y) {
  const aspect = 0.75, torso = 0.18;
  final shX = 0.5 * aspect, shY = 0.55 - torso;
  final px = shX + x * torso, py = shY - y * torso;
  return stickFrame(t: t, override: {
    Lm.leftWrist: (px - 0.01, py),
    Lm.rightWrist: (px + 0.01, py),
    17: (px - 0.01, py),
    19: (px - 0.01, py),
    18: (px + 0.01, py),
    20: (px + 0.01, py),
  });
}

List<SwingEvent> run(List<PoseFrame> frames,
    {SwingThresholds t = const SwingThresholds()}) {
  final r = SwingRecogniser(t);
  final out = <SwingEvent>[];
  for (final f in frames) {
    final e = r.update(BodyPose.from(f));
    if (e != null) out.add(e);
  }
  return out;
}

void main() {
  test('a full swing across the body is recognised once', () {
    final e = run(swing());
    expect(e, hasLength(1));
    expect(e.single.completed, isTrue);
    expect(e.single.fromSide, BodySide.right);
    expect(e.single.lofted, isFalse);
  });

  test('a flat swing that stays high is lofted', () {
    final e = run(swing(endShoulder: 90));
    expect(e.single.completed, isTrue);
    expect(e.single.lofted, isTrue);
  });

  test('a short push is rejected as too shallow', () {
    final e = run(swing(reach: -0.5));
    expect(e.single.completed, isFalse);
    expect(e.single.reason, RejectReason.tooShallow);
  });

  test('low-impact accepts a shorter swing', () {
    final short = swing(reach: 0.0);
    expect(run(short).single.completed, isFalse);
    expect(run(short, t: const SwingThresholds.lowImpact()).single.completed,
        isTrue);
  });

  test('no backlift, no swing', () {
    final frames = [for (var t = 0; t < 2000; t += 33) stickFrame(t: t)];
    expect(run(frames), isEmpty);
  });

  test('cooldown stops a double count', () {
    final frames = [...swing(), ...swing(start: 1100)];
    expect(run(frames).where((e) => e.completed), hasLength(1));
    final later = [...swing(), ...swing(start: 2400)];
    expect(run(later).where((e) => e.completed), hasLength(2));
  });
}
