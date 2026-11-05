import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';
import 'package:test/test.dart';

LevelConfig tiny(List<Map<String, Object>> encounters, {int durationS = 30}) =>
    LevelConfig.fromJson({
      'id': 'w1-tiny',
      'version': 1,
      'schemaVersion': 1,
      'world': 1,
      'name': 'Tiny',
      'lanes': 3,
      'durationS': durationS,
      'difficulty': {
        for (final d in ['beginner', 'intermediate', 'advanced'])
          d: {'warningMs': 1500, 'maxDemandingInRow': 5, 'hints': 'off'}
      },
      'scoring': {'beam': 100, 'laneBlock': 100, 'orb': 50, 'gate': 150},
      'segments': [
        {'id': 'a', 'kind': 'learn', 'startS': 0, 'endS': 20},
        {'id': 'cp', 'kind': 'checkpoint', 'startS': 20, 'endS': 21},
        {'id': 'b', 'kind': 'finale', 'startS': 21, 'endS': durationS},
      ],
      'encounters': encounters,
    });

List<RunEvent> runFor(RunEngine e, int ms) =>
    [for (var t = 0; t < ms; t += 16) ...e.advance(16)];

void main() {
  test('a squat with no beam coming does nothing', () {
    final e = RunEngine(
        tiny([
          {'atS': 10, 'type': 'beam'}
        ]),
        const RunSettings());
    runFor(e, 2000);
    e.input(const MoveStarted(Move.squat, 0));
    e.input(const MoveEnded(Move.squat, 0));
    e.input(const RepCompleted(Move.squat, 0, 500));
    expect(e.score, 0);
    expect(e.reps[Move.squat], 1);
  });

  test('ducking under a beam clears it; standing costs a heart', () {
    final e = RunEngine(
        tiny([
          {'atS': 5, 'type': 'beam'},
          {'atS': 10, 'type': 'beam'}
        ]),
        const RunSettings());
    runFor(e, 4500);
    e.input(const MoveStarted(Move.squat, 0));
    final ev = runFor(e, 800);
    e.input(const MoveEnded(Move.squat, 0));
    expect(ev.whereType<EncounterResolved>().single.outcome, Outcome.cleared);
    expect(e.score, greaterThan(0));
    final ev2 = runFor(e, 5000);
    expect(ev2.whereType<EncounterResolved>().single.outcome, Outcome.hit);
    expect(e.hearts, 2);
  });

  test('leaning out of a blocked lane clears it', () {
    final e = RunEngine(
        tiny([
          {
            'atS': 5,
            'type': 'laneBlock',
            'lanes': [1]
          }
        ]),
        const RunSettings());
    expect(e.lane, 1);
    runFor(e, 4000);
    expect(e.input(const MoveStarted(Move.leanLeft, 0)).single,
        isA<LaneChanged>());
    expect(e.lane, 0);
    e.input(const MoveStarted(Move.leanLeft, 0)); // wall: stays in lane 0
    expect(e.lane, 0);
    final ev = runFor(e, 1500);
    expect(ev.whereType<EncounterResolved>().single.outcome, Outcome.cleared);
  });

  test('a missed orb never costs a heart', () {
    final e = RunEngine(
        tiny([
          {
            'atS': 5,
            'type': 'orb',
            'lanes': [1]
          }
        ]),
        const RunSettings());
    runFor(e, 6000);
    expect(e.hearts, 3);
    expect(e.energy, 0);
  });

  test('raising arms collects an orb in your lane', () {
    final e = RunEngine(
        tiny([
          {
            'atS': 5,
            'type': 'orb',
            'lanes': [1]
          }
        ]),
        const RunSettings());
    runFor(e, 4700);
    e.input(const MoveStarted(Move.raiseArms, 0));
    runFor(e, 600);
    expect(e.energy, 1);
  });

  test('tracking loss forgives the obstacle and pauses the clock', () {
    final e = RunEngine(
        tiny([
          {'atS': 5, 'type': 'beam'}
        ]),
        const RunSettings());
    runFor(e, 4000);
    final hint = e.input(const TrackingPaused(0, TrackingIssue.outOfFrame));
    expect(hint.single, isA<TrackingHint>());
    final clock = e.clockMs;
    runFor(e, 3000);
    // Clock slowed to a stop well before the beam arrived.
    expect(e.clockMs - clock, lessThan(500));
    e.input(const TrackingResumed(0));
    final ev = runFor(e, 3000);
    final res = ev.whereType<EncounterResolved>().single;
    expect(res.outcome, Outcome.forgiven);
    expect(e.hearts, 3);
  });

  test('checkpoint restores a heart and allows a restart', () {
    final e = RunEngine(
        tiny([
          {'atS': 5, 'type': 'beam'},
          {'atS': 22, 'type': 'beam'},
          {'atS': 24, 'type': 'beam'},
          {'atS': 26, 'type': 'beam'},
        ]),
        const RunSettings());
    runFor(e, 19000);
    expect(e.hearts, 2);
    final cp = runFor(e, 1500);
    expect(cp.whereType<CheckpointReached>(), hasLength(1));
    expect(e.hearts, 3);
    final ev = runFor(e, 8000);
    final fin = ev.whereType<RunFinished>().single;
    expect(fin.result.completed, isFalse);
    expect(e.restartFromCheckpoint(), isTrue);
    expect(e.hearts, 3);
    expect(e.finished, isFalse);
    expect(e.clockMs, 20000);
  });

  test('a clean run finishes with a result', () {
    final e = RunEngine(
        tiny([
          {'atS': 5, 'type': 'gate'}
        ], durationS: 22),
        const RunSettings());
    runFor(e, 4800);
    e.input(const MoveStarted(Move.raiseArms, 0));
    final ev = runFor(e, 20000);
    final r = ev.whereType<RunFinished>().single.result;
    expect(r.completed, isTrue);
    expect(r.cleared, 1);
    expect(r.toJson()['levelId'], 'w1-tiny');
  });
}
