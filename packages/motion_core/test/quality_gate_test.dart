import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:test/test.dart';

PoseFrame frame(List<Landmark> lm, {int? h = 640}) =>
    PoseFrame(timestampMs: 0, landmarks: lm, imageHeight: h, imageWidth: 480);

void main() {
  const gate = QualityGate();

  test('a full, well-lit body passes', () {
    final r = gate.check(frame(SyntheticBody(noise: 0).pose()));
    expect(r.ok, isTrue);
    expect(r.bodyHeight, greaterThan(0.5));
  });

  test('no person', () {
    expect(gate.check(frame(const [])).issue, TrackingIssue.noPerson);
  });

  test('feet out of frame', () {
    final lm = SyntheticBody(noise: 0, footY: 1.08).pose();
    expect(gate.check(frame(lm)).issue, TrackingIssue.outOfFrame);
  });

  test('too far away', () {
    final lm = SyntheticBody(noise: 0, height: 0.25, footY: 0.6).pose();
    expect(gate.check(frame(lm)).issue, TrackingIssue.tooFar);
  });

  test('body too small in pixels on a low-resolution stream', () {
    final lm = SyntheticBody(noise: 0, height: 0.5, footY: 0.75).pose();
    expect(gate.check(frame(lm, h: 640)).ok, isTrue);
    expect(gate.check(frame(lm, h: 480)).issue, TrackingIssue.tooFar);
  });

  test('squatting does not read as too far away', () {
    final b = SyntheticBody(noise: 0, height: 0.5, footY: 0.85);
    expect(gate.check(frame(b.pose(squat: 1.1))).ok, isTrue);
  });

  test('hidden knees fail on visibility', () {
    final lm = SyntheticBody(noise: 0).pose();
    lm[Lm.leftKnee] = lm[Lm.leftKnee].copyWith(visibility: 0.2);
    expect(gate.check(frame(lm)).issue, TrackingIssue.lowVisibility);
  });
}
