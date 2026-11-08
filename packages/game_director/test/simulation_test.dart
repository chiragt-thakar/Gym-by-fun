// "Every level is finishable at every difficulty in simulated runs."
import 'package:game_director/game_director.dart';
import 'package:test/test.dart';

import 'levels.dart';

void main() {
  for (final level in allLevels()) {
    for (final d in Difficulty.values) {
      for (final low in [true, false]) {
        test(
            '${level.id} · ${d.name} · lowImpact=$low · competent bot clears everything',
            () {
          final r = simulate(level, RunSettings(difficulty: d, lowImpact: low),
              BotProfile.competent);
          expect(r.allFeasible, isTrue, reason: r.infeasible.join('\n'));
          expect(r.result.completed, isTrue);
          expect(r.result.hit, 0);
          if (level.gameplay != null) {
            expect(r.result.missionWon, isTrue);
            expect(r.result.missionGoal, greaterThan(0));
          }
        });

        test(
            '${level.id} · ${d.name} · lowImpact=$low · slow beginner still finishes',
            () {
          final r = simulate(level, RunSettings(difficulty: d, lowImpact: low),
              BotProfile.slow);
          expect(r.result.completed, isTrue,
              reason: 'hit=${r.result.hit} ${r.infeasible.join('\n')}');
        });
      }

      test('${level.id} · ${d.name} · tracking dropouts never cost hearts', () {
        const bot = BotProfile(
            name: 'dropouts',
            dropouts: [(20000, 3000), (60000, 1500), (120000, 5000)]);
        final clean =
            simulate(level, RunSettings(difficulty: d), BotProfile.competent);
        final r = simulate(level, RunSettings(difficulty: d), bot);
        expect(r.result.completed, isTrue);
        expect(r.result.hit, clean.result.hit);
        expect(r.result.forgiven, greaterThanOrEqualTo(0));
      });
    }

    test('${level.id} · gentle (warning ×1.2, assist, low-impact) · finishes',
        () {
      const gentle =
          RunSettings(lowImpact: true, assist: true, warningMultiplier: 1.2);
      final r = simulate(level, gentle, BotProfile.slow);
      expect(r.allFeasible, isTrue, reason: r.infeasible.join('\n'));
      expect(r.result.completed, isTrue);
      final c = simulate(level, gentle, BotProfile.competent);
      expect(c.result.hit, 0, reason: c.infeasible.join('\n'));
    });
  }
}
