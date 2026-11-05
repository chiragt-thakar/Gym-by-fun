import 'package:game_director/game_director.dart';
import 'package:test/test.dart';

import 'levels.dart';

void main() {
  test('the plan is deterministic', () {
    final a = Director(forest(), const RunSettings()).plan();
    final b = Director(forest(), const RunSettings()).plan();
    expect(a.map((p) => '${p.type}${p.arriveMs}${p.lanes}'),
        b.map((p) => '${p.type}${p.arriveMs}${p.lanes}'));
  });

  test('warning time follows difficulty', () {
    for (final (d, ms) in [
      (Difficulty.beginner, 2000),
      (Difficulty.intermediate, 1600),
      (Difficulty.advanced, 1300),
    ]) {
      final plan = Director(forest(), RunSettings(difficulty: d)).plan();
      final single = plan.where(
          (p) => p.lanes.length != 2 || p.type != EncounterType.laneBlock);
      expect(single.every((p) => p.warningMs == ms), isTrue, reason: '$d');
    }
  });

  test('assist mode gives more warning', () {
    final p = Director(forest(), const RunSettings(assist: true)).plan();
    expect(p.first.warningMs, 2500);
  });

  test('warning multiplier defaults to 1.0 and leaves warnings unchanged', () {
    expect(const RunSettings().warningMultiplier, 1.0);
    final a = Director(forest(), const RunSettings()).plan();
    final b =
        Director(forest(), const RunSettings(warningMultiplier: 1.0)).plan();
    expect(b.map((p) => p.warnMs), a.map((p) => p.warnMs));
    expect(Director(forest(), const RunSettings()).warningMs, 2000);
  });

  test('warning multiplier increases warning, stacks with assist', () {
    expect(
        Director(forest(), const RunSettings(warningMultiplier: 1.2)).warningMs,
        2400);
    expect(
        Director(forest(),
                const RunSettings(warningMultiplier: 1.2, assist: true))
            .warningMs,
        3000);
    final base = Director(forest(), const RunSettings()).plan();
    final gentle =
        Director(forest(), const RunSettings(warningMultiplier: 1.2)).plan();
    // Same encounters at the same times; never cued later, mostly earlier.
    expect(gentle.map((p) => p.arriveMs), base.map((p) => p.arriveMs));
    var longer = 0;
    for (var i = 0; i < base.length; i++) {
      expect(gentle[i].warningMs, greaterThanOrEqualTo(base[i].warningMs));
      if (gentle[i].warningMs > base[i].warningMs) longer++;
    }
    expect(longer, greaterThan(0));
  });

  test('extra warning never cues before the previous encounter arrives', () {
    for (final s in const [
      RunSettings(assist: true),
      RunSettings(warningMultiplier: 1.5, assist: true),
    ]) {
      final base = Director(forest(), const RunSettings()).plan();
      final plan = Director(forest(), s).plan();
      for (var i = 1; i < plan.length; i++) {
        expect(
            plan[i].warnMs,
            greaterThanOrEqualTo(plan[i - 1].arriveMs < base[i].warnMs
                ? plan[i - 1].arriveMs
                : base[i].warnMs));
      }
    }
  });

  test('warning multiplier is clamped to 1.0–1.5', () {
    expect(const RunSettings(warningMultiplier: 0.5).warningMultiplier, 1.0);
    expect(const RunSettings(warningMultiplier: 3).warningMultiplier, 1.5);
    expect(
        Director(forest(), const RunSettings(warningMultiplier: 3)).warningMs,
        3000);
  });

  test('harder difficulties get more encounters', () {
    int n(Difficulty d) =>
        Director(forest(), RunSettings(difficulty: d)).plan().length;
    expect(n(Difficulty.beginner), lessThan(n(Difficulty.intermediate)));
    expect(n(Difficulty.intermediate), lessThan(n(Difficulty.advanced)));
  });

  test('never more demanding moves in a row than the cap', () {
    for (final d in Difficulty.values) {
      final dir = Director(forest(), RunSettings(difficulty: d));
      var run = 0;
      for (final p in dir.plan()) {
        if (p.type.demanding) {
          run++;
          expect(run, lessThanOrEqualTo(dir.profile.maxDemandingInRow));
        } else if (p.type != EncounterType.orb) {
          run = 0;
        }
      }
    }
  });

  test('cap swaps extra beams for lighter orbs', () {
    final l = LevelConfig.fromJson({
      'id': 'w1-beams',
      'version': 1,
      'schemaVersion': 1,
      'world': 1,
      'name': 'Beams',
      'lanes': 3,
      'durationS': 60,
      'difficulty': {
        for (final d in ['beginner', 'intermediate', 'advanced'])
          d: {'warningMs': 1500, 'maxDemandingInRow': 2, 'hints': 'off'}
      },
      'scoring': {'beam': 1, 'laneBlock': 1, 'orb': 1, 'gate': 1},
      'segments': [
        {'id': 's', 'kind': 'learn', 'startS': 0, 'endS': 60}
      ],
      'encounters': [
        for (var i = 0; i < 6; i++) {'atS': 5 + i * 3, 'type': 'beam'}
      ],
    });
    final plan = Director(l, const RunSettings()).plan();
    expect(plan.map((p) => p.type.name).toList(),
        ['beam', 'beam', 'orb', 'beam', 'beam', 'orb']);
    expect(plan[2].substituted, isTrue);
  });

  test('no two moves are ever asked for at once', () {
    for (final d in Difficulty.values) {
      for (final low in [true, false]) {
        final dir =
            Director(forest(), RunSettings(difficulty: d, lowImpact: low));
        final plan = dir.plan();
        for (var i = 1; i < plan.length; i++) {
          final gap = plan[i].arriveMs - plan[i - 1].arriveMs;
          expect(
              gap,
              greaterThanOrEqualTo(
                  MoveTimes.recovery(plan[i - 1].type, lowImpact: low)),
              reason: '$d low=$low ${plan[i - 1]} → ${plan[i]}');
        }
      }
    }
  });

  test('hints: always / first time / off', () {
    int hints(Difficulty d) => Director(forest(), RunSettings(difficulty: d))
        .plan()
        .where((p) => p.hint != null)
        .length;
    final total = Director(forest(), const RunSettings()).plan().length;
    expect(hints(Difficulty.beginner), total);
    expect(hints(Difficulty.intermediate), lessThan(total));
    expect(hints(Difficulty.advanced), 0);
  });

  test('pacer slows on amber, stops on red, recovers on green', () {
    final p = Pacer();
    for (var i = 0; i < 60; i++) {
      p.update(16, 1);
    }
    expect(p.scale, closeTo(0.6, 1e-9));
    for (var i = 0; i < 60; i++) {
      p.update(16, 2);
    }
    expect(p.scale, 0);
    for (var i = 0; i < 60; i++) {
      p.update(16, 0);
    }
    expect(p.scale, 1);
  });
}
