// The Phase 0 gate as a test: every move recognised 90 %+ of the time and
// fewer than 1 false trigger per minute, across bodies, frame rates, noise
// and clothing. Runs on every commit; a drop in accuracy fails the build.
//
// Until field recordings land in test/recordings/, the corpus is synthetic
// (see lib/src/testing/synthetic.dart). Real recordings in that folder are
// replayed by the same gate.
import 'dart:io';

import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:test/test.dart';

class Case {
  const Case(this.name, this.body, this.fps, {this.seed = 1});
  final String name;
  final SyntheticBody body;
  final int fps;
  final int seed;
}

void main() {
  final cases = [
    Case('mid phone, average height', SyntheticBody(seed: 11), 30, seed: 1),
    Case('budget phone 15 fps', SyntheticBody(seed: 12, noise: 0.004), 15,
        seed: 2),
    Case('budget phone 24 fps, small player',
        SyntheticBody(seed: 13, height: 0.5, footY: 0.85), 24,
        seed: 3),
    Case('tall player close to camera',
        SyntheticBody(seed: 14, height: 0.8, footY: 0.95), 30,
        seed: 4),
    Case('loose clothing (kurta / saree)',
        SyntheticBody(seed: 15, lowLegVisibility: true), 30,
        seed: 5),
    Case('dim tube light: noisy landmarks',
        SyntheticBody(seed: 16, noise: 0.006), 24,
        seed: 6),
    Case('player off-centre', SyntheticBody(seed: 17, centerX: 0.38), 30,
        seed: 7),
  ];

  final total = AccuracyReport();

  for (final c in cases) {
    test('synthetic: ${c.name}', () {
      final s = SyntheticSession(c.body, fps: c.fps, seed: c.seed);
      final rec = s.record(s.randomScript(2), calibration: s.calibrate());
      final r = replay(rec);
      total.merge(r);
      expect(r.passes(), isTrue, reason: r.toTable());
    });
  }

  final dir = Directory('test/recordings');
  final files = dir.existsSync()
      ? (dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path)))
      : <File>[];
  for (final f in files) {
    test('recorded: ${f.uri.pathSegments.last}', () {
      final r = replay(LandmarkRecording.decode(f.readAsStringSync()));
      total.merge(r);
      expect(r.passes(), isTrue, reason: r.toTable());
    });
  }

  tearDownAll(() {
    final out = File('build/accuracy_report.txt')..createSync(recursive: true);
    out.writeAsStringSync(total.toTable());
    stdout.writeln('\nMotion accuracy report\n${total.toTable()}');
  });

  // Delay here is from the *start of the player's movement* (label onset) to
  // recognition, so it includes the ~280 ms the synthetic body takes to move
  // into position. The 150 ms budget is pipeline latency (camera → action)
  // and is measured on real phones by the debug screen.
  test('recognition follows movement onset promptly', () {
    final s = SyntheticSession(SyntheticBody(seed: 21), fps: 30);
    final r = replay(
        s.record(s.randomScript(1, decoys: false), calibration: s.calibrate()));
    // Label start = movement onset; delay covers easing into the move.
    for (final m in [Move.squat, Move.leanLeft, Move.leanRight]) {
      expect(r.moves[m]!.meanDelayMs, lessThan(350), reason: r.toTable());
    }
    // Raise arms adds its deliberate 150 ms hold.
    expect(r.moves[Move.raiseArms]!.meanDelayMs, lessThan(520));
  });
}
