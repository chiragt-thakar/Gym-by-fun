// Replays landmark recordings (never video) through the motion core and
// prints the per-move accuracy report. Exits 1 if the Stage 0 gate fails.
//
//   dart run bin/replay.dart <file-or-dir>... [--low-impact] [--json]
//       [--min-recall 0.9] [--max-false-per-min 1.0]
//   dart run bin/replay.dart --make-synthetic <dir> [--count 3]
import 'dart:convert';
import 'dart:io';

import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';

void main(List<String> args) {
  if (args.isEmpty || args.contains('-h') || args.contains('--help')) {
    stdout
        .writeln('usage: replay.dart <file-or-dir>... [--low-impact] [--json] '
            '[--min-recall 0.9] [--max-false-per-min 1.0]\n'
            '       replay.dart --make-synthetic <dir> [--count 3]');
    exit(64);
  }
  String? opt(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  final synth = opt('--make-synthetic');
  if (synth != null) {
    final n = int.parse(opt('--count') ?? '3');
    Directory(synth).createSync(recursive: true);
    for (var i = 0; i < n; i++) {
      final s = SyntheticSession(
          SyntheticBody(seed: 100 + i, height: 0.55 + i * 0.05),
          seed: i);
      final rec = s.record(s.randomScript(1.5),
          calibration: s.calibrate(), meta: {'subject': 'synthetic-$i'});
      File('$synth/synthetic_$i.json').writeAsStringSync(rec.encode());
    }
    stdout.writeln('wrote $n synthetic recordings to $synth');
    return;
  }

  final valued = {'--min-recall', '--max-false-per-min'};
  final paths = <String>[];
  for (var i = 0; i < args.length; i++) {
    if (valued.contains(args[i])) {
      i++;
    } else if (!args[i].startsWith('--')) {
      paths.add(args[i]);
    }
  }
  final files = <File>[
    for (final p in paths)
      if (FileSystemEntity.isDirectorySync(p))
        ...Directory(p)
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
      else
        File(p)
  ]..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    stderr.writeln('no recordings found');
    exit(66);
  }

  final thresholds = args.contains('--low-impact')
      ? const MotionThresholds.lowImpact()
      : const MotionThresholds();
  final minRecall = double.parse(opt('--min-recall') ?? '0.9');
  final maxFalse = double.parse(opt('--max-false-per-min') ?? '1.0');
  final total = AccuracyReport();
  for (final f in files) {
    final r = replay(LandmarkRecording.decode(f.readAsStringSync()),
        thresholds: thresholds);
    total.merge(r);
    final verdict = r.passes(minRecall: minRecall, maxFalsePerMin: maxFalse)
        ? 'PASS'
        : 'FAIL';
    stdout.writeln('$verdict  ${f.uri.pathSegments.last}');
  }
  if (args.contains('--json')) {
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(total.toJson()));
  } else {
    stdout.writeln('\n${total.toTable()}');
  }
  final ok = total.passes(minRecall: minRecall, maxFalsePerMin: maxFalse);
  stdout.writeln(ok ? 'Stage 0 gate: PASS' : 'Stage 0 gate: FAIL');
  exit(ok ? 0 : 1);
}
