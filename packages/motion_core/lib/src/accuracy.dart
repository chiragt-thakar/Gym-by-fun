import 'calibration.dart';
import 'events.dart';
import 'landmarks.dart';
import 'motion_engine.dart';
import 'quality_gate.dart';
import 'recognisers.dart';
import 'recording.dart';

/// Per-move result of replaying a labelled recording.
class MoveAccuracy {
  int labelled = 0;
  int recognised = 0;
  int falseTriggers = 0;
  final List<int> delaysMs = [];

  int get missed => labelled - recognised;
  double get recall => labelled == 0 ? 1 : recognised / labelled;
  double get meanDelayMs =>
      delaysMs.isEmpty ? 0 : delaysMs.reduce((a, b) => a + b) / delaysMs.length;

  void merge(MoveAccuracy o) {
    labelled += o.labelled;
    recognised += o.recognised;
    falseTriggers += o.falseTriggers;
    delaysMs.addAll(o.delaysMs);
  }

  Map<String, Object> toJson() => {
        'labelled': labelled,
        'recognised': recognised,
        'missed': missed,
        'falseTriggers': falseTriggers,
        'recall': double.parse(recall.toStringAsFixed(4)),
        'meanDelayMs': meanDelayMs.round(),
      };
}

/// The Phase 0 accuracy report: recognised %, false triggers per minute and
/// recognition delay, per move.
class AccuracyReport {
  AccuracyReport() : moves = {for (final m in Move.values) m: MoveAccuracy()};

  final Map<Move, MoveAccuracy> moves;
  int durationMs = 0;
  int recordings = 0;
  int pauses = 0;

  double get minutes => durationMs / 60000;
  int get falseTriggers => moves.values.fold(0, (a, m) => a + m.falseTriggers);
  double get falseTriggersPerMinute =>
      minutes == 0 ? 0 : falseTriggers / minutes;

  /// The Stage 0 gate: 90 %+ recognised per move and < 1 false trigger/min.
  bool passes({double minRecall = 0.90, double maxFalsePerMin = 1.0}) =>
      moves.values.every((m) => m.labelled == 0 || m.recall >= minRecall) &&
      falseTriggersPerMinute < maxFalsePerMin;

  void merge(AccuracyReport o) {
    for (final m in Move.values) {
      moves[m]!.merge(o.moves[m]!);
    }
    durationMs += o.durationMs;
    recordings += o.recordings;
    pauses += o.pauses;
  }

  Map<String, Object> toJson() => {
        'recordings': recordings,
        'minutes': double.parse(minutes.toStringAsFixed(2)),
        'falseTriggersPerMinute':
            double.parse(falseTriggersPerMinute.toStringAsFixed(3)),
        'trackingPauses': pauses,
        'moves': {for (final e in moves.entries) e.key.name: e.value.toJson()},
      };

  String toTable() {
    final b = StringBuffer()
      ..writeln('move        labelled  recognised  recall   false  delay(ms)')
      ..writeln('----------  --------  ----------  -------  -----  ---------');
    for (final e in moves.entries) {
      final m = e.value;
      if (m.labelled == 0 && m.falseTriggers == 0) continue;
      b.writeln('${e.key.name.padRight(10)}  ${'${m.labelled}'.padLeft(8)}  '
          '${'${m.recognised}'.padLeft(10)}  '
          '${'${(m.recall * 100).toStringAsFixed(1)}%'.padLeft(7)}  '
          '${'${m.falseTriggers}'.padLeft(5)}  '
          '${'${m.meanDelayMs.round()}'.padLeft(9)}');
    }
    b.writeln(
        'recordings: $recordings, minutes: ${minutes.toStringAsFixed(2)}, '
        'false triggers/min: ${falseTriggersPerMinute.toStringAsFixed(2)}, '
        'tracking pauses: $pauses');
    return b.toString();
  }
}

/// Replays a recording through a fresh [MotionEngine] and scores it against
/// its labels. A label counts as recognised if a [MoveStarted] for the same
/// move lands between [earlyMs] before its start and [lateMs] after its end;
/// every other [MoveStarted] is a false trigger.
AccuracyReport replay(
  LandmarkRecording rec, {
  MotionThresholds thresholds = const MotionThresholds(),
  QualityGate gate = const QualityGate(),
  int earlyMs = 150,
  int lateMs = 250,
}) {
  final cal = rec.calibration ?? _standingCalibration(rec, gate);
  final engine =
      MotionEngine(calibration: cal, thresholds: thresholds, gate: gate);
  final starts = <MoveStarted>[];
  var pauses = 0;
  for (final f in rec.frames) {
    for (final e in engine.process(f)) {
      if (e is MoveStarted) starts.add(e);
      if (e is TrackingPaused) pauses++;
    }
  }

  final report = AccuracyReport()
    ..durationMs = rec.durationMs
    ..recordings = 1
    ..pauses = pauses;
  final used = <MoveStarted>{};
  for (final l in rec.labels) {
    final acc = report.moves[l.move]!..labelled += 1;
    for (final s in starts) {
      if (used.contains(s) || s.move != l.move) continue;
      if (s.timestampMs >= l.startMs - earlyMs &&
          s.timestampMs <= l.endMs + lateMs) {
        used.add(s);
        acc.recognised++;
        acc.delaysMs.add(s.timestampMs - l.startMs);
        break;
      }
    }
  }
  for (final s in starts) {
    if (!used.contains(s)) report.moves[s.move]!.falseTriggers++;
  }
  return report;
}

CalibrationProfile _standingCalibration(
    LandmarkRecording rec, QualityGate gate) {
  for (final f in rec.frames) {
    if (gate.check(f).ok) return CalibrationProfile.fromStanding(f);
  }
  throw StateError('Recording has no usable frame to calibrate from');
}

/// Convenience for tests: the events a recording produces, in order.
List<MotionEvent> runEngine(MotionEngine engine, Iterable<PoseFrame> frames) =>
    [for (final f in frames) ...engine.process(f)];
