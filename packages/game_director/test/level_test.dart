import 'package:game_director/game_director.dart';
import 'package:test/test.dart';

import 'levels.dart';

void main() {
  test('Forest Escape parses with the expected shape', () {
    final l = forest();
    expect(l.lanes, 3);
    expect(l.hearts, 3);
    expect(l.durationMs, greaterThanOrEqualTo(180000));
    expect(l.checkpoint!.startMs, 150000);
    expect(l.segmentAt(95000)!.kind, SegmentKind.breather);
    expect(l.difficulty[Difficulty.beginner]!.warningMs, 2000);
    expect(l.difficulty[Difficulty.intermediate]!.warningMs, 1600);
    expect(l.difficulty[Difficulty.advanced]!.warningMs, 1300);
  });

  test('breather holds only orbs', () {
    final l = forest();
    final seg = l.segments.firstWhere((s) => s.kind == SegmentKind.breather);
    final inside =
        l.encounters.where((e) => e.atMs >= seg.startMs && e.atMs < seg.endMs);
    expect(inside, isNotEmpty);
    expect(inside.every((e) => e.type == EncounterType.orb), isTrue);
  });

  test('every level leaves a free lane at every lane block', () {
    for (final l in allLevels()) {
      for (final e
          in l.encounters.where((e) => e.type == EncounterType.laneBlock)) {
        expect(e.lanes.length, lessThan(l.lanes), reason: '${l.id} @${e.atMs}');
      }
    }
  });

  test('bad configs are refused', () {
    Map<String, dynamic> base() => {
          'id': 'w1-x',
          'version': 1,
          'schemaVersion': 1,
          'world': 1,
          'name': 'X',
          'lanes': 3,
          'durationS': 60,
          'difficulty': {
            for (final d in ['beginner', 'intermediate', 'advanced'])
              d: {'warningMs': 1500, 'maxDemandingInRow': 3, 'hints': 'off'}
          },
          'scoring': {'beam': 1, 'laneBlock': 1, 'orb': 1, 'gate': 1},
          'segments': [
            {'id': 's', 'kind': 'learn', 'startS': 0, 'endS': 60}
          ],
          'encounters': [
            {'atS': 5, 'type': 'beam'}
          ],
        };
    expect(LevelConfig.fromJson(base()).encounters.single.lanes, [0, 1, 2]);
    expect(
        () => LevelConfig.fromJson(base()
          ..['encounters'] = [
            {
              'atS': 5,
              'type': 'laneBlock',
              'lanes': [0, 1, 2]
            }
          ]),
        throwsFormatException);
    expect(() => LevelConfig.fromJson(base()..['schemaVersion'] = 99),
        throwsFormatException);
    expect(
        () => LevelConfig.fromJson(base()
          ..['encounters'] = [
            {'atS': 99, 'type': 'beam'}
          ]),
        throwsFormatException);
    expect(
        () =>
            LevelConfig.fromJson(base()..['difficulty'] = <String, dynamic>{}),
        throwsFormatException);
  });
}
