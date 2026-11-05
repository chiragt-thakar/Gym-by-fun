import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:test/test.dart';

void main() {
  test('recordings round-trip and contain no pixels', () {
    final s = SyntheticSession(SyntheticBody(seed: 5));
    final rec = s.record([const ScriptStep(Action.squat, 1000)],
        calibration: s.calibrate(), meta: {'device': 'test'});
    final json = rec.encode();
    final back = LandmarkRecording.decode(json);
    expect(back.frames.length, rec.frames.length);
    expect(back.labels.single.move, Move.squat);
    expect(back.isSynthetic, isTrue);
    expect(back.calibration, isNotNull);
    expect(json.contains('image'), isFalse);
  });

  test('flat bridge format decodes', () {
    final flat = <num>[1234, 480, 640, 12.5];
    for (var i = 0; i < 33; i++) {
      flat.addAll([0.5, 0.5, 0.0, 0.9]);
    }
    final f = PoseFrame.fromFlat(flat);
    expect(f.timestampMs, 1234);
    expect(f.landmarks.length, 33);
    expect(f.inferenceMs, 12.5);
    final none = PoseFrame.fromFlat([1, 480, 640, 3.0]);
    expect(none.hasPerson, isFalse);
  });

  test('builder labels spans', () {
    final b = RecordingBuilder(meta: {'subject': 'A'})
      ..add(PoseFrame(timestampMs: 0, landmarks: const []))
      ..beginLabel(Move.leanLeft, 100)
      ..endLabel(Move.leanLeft, 900);
    final r = b.build();
    expect(r.labels.single.endMs, 900);
    expect(r.meta['subject'], 'A');
  });

  test('wrong format is refused', () {
    expect(() => LandmarkRecording.fromJson({'format': 'x', 'version': 1}),
        throwsFormatException);
  });
}
