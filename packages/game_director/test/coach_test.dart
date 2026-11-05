import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';
import 'package:test/test.dart';

final day0 = DateTime.utc(2026, 11, 2, 18);

SessionSummary run({
  int day = 0,
  bool completed = true,
  int score = 1000,
  int hearts = 3,
  int hit = 0,
  int? effort = 2,
  Difficulty difficulty = Difficulty.beginner,
  bool lowImpact = true,
  Map<Move, int> reps = const {
    Move.squat: 10,
    Move.leanLeft: 8,
    Move.leanRight: 8,
    Move.raiseArms: 6,
  },
  Map<Move, MoveStats> stats = const {},
}) =>
    SessionSummary(
      date: day0.add(Duration(days: day)),
      levelId: 'w1-forest',
      completed: completed,
      score: score,
      hearts: hearts,
      maxHearts: 3,
      cleared: 20,
      hit: hit,
      reps: reps,
      difficulty: difficulty,
      lowImpact: lowImpact,
      effort: effort,
      moveStats: stats,
    );

const coach = Coach();

void main() {
  group('difficulty', () {
    test('no history gives neutral advice', () {
      final a = coach.advise(const []);
      expect(a.difficulty.reason, CoachReason.noHistory);
      expect(a.difficulty.changes, isFalse);
      expect(a.tips, isEmpty);
      expect(a.recap, isNull);
    });

    test('two clean, comfortable finishes suggest one level up', () {
      final a = coach.advise([run(hit: 1, effort: 3), run(day: 1)]);
      expect(a.difficulty.reason, CoachReason.readyToMoveUp);
      expect(a.difficulty.recommended, Difficulty.intermediate);
      expect(a.difficulty.movesUp, isTrue);
      expect(a.difficulty.suggestAssist, isFalse);
    });

    test('one clean finish is not enough', () {
      final a = coach.advise([run()]);
      expect(a.difficulty.reason, CoachReason.steady);
      expect(a.difficulty.changes, isFalse);
    });

    test('two hits or effort above 3 blocks moving up', () {
      expect(coach.advise([run(hit: 2), run(day: 1)]).difficulty.reason,
          CoachReason.steady);
      expect(coach.advise([run(), run(day: 1, effort: 4)]).difficulty.movesUp,
          isFalse);
    });

    test('finishes at a different level do not count towards moving up', () {
      final a =
          coach.advise([run(difficulty: Difficulty.advanced), run(day: 1)]);
      expect(a.difficulty.reason, CoachReason.steady);
    });

    test('never jumps more than one level', () {
      final a = coach.advise([
        for (var i = 0; i < 6; i++) run(day: i, difficulty: Difficulty.beginner)
      ]);
      expect(a.difficulty.recommended, Difficulty.intermediate);
      final down = coach.advise([
        run(difficulty: Difficulty.advanced, completed: false, hearts: 0),
      ]);
      expect(down.difficulty.recommended, Difficulty.intermediate);
    });

    test('on the top level a good streak stays put', () {
      final a = coach.advise([
        run(difficulty: Difficulty.advanced),
        run(day: 1, difficulty: Difficulty.advanced),
      ]);
      expect(a.difficulty.reason, CoachReason.atTop);
      expect(a.difficulty.changes, isFalse);
    });

    test('an unfinished run suggests easier and assist', () {
      final a = coach.advise([
        run(difficulty: Difficulty.intermediate, completed: false, hearts: 0)
      ]);
      expect(a.difficulty.reason, CoachReason.runNotFinished);
      expect(a.difficulty.recommended, Difficulty.beginner);
      expect(a.difficulty.suggestAssist, isTrue);
    });

    test('losing two hearts suggests easier', () {
      final a =
          coach.advise([run(difficulty: Difficulty.intermediate, hearts: 1)]);
      expect(a.difficulty.reason, CoachReason.heartsLost);
      expect(a.difficulty.recommended, Difficulty.beginner);
    });

    test('a hard rating suggests easier; beginner stays beginner + assist', () {
      final a = coach.advise([run(effort: 4)]);
      expect(a.difficulty.reason, CoachReason.feltHard);
      expect(a.difficulty.recommended, Difficulty.beginner);
      expect(a.difficulty.suggestAssist, isTrue);
    });

    test('suggests low-impact when it was off and the run felt hard', () {
      final a = coach.advise([run(effort: 5, lowImpact: false)]);
      expect(a.difficulty.suggestLowImpact, isTrue);
    });

    test('never suggests leaving low-impact', () {
      final histories = [
        [run(effort: 4), run(day: 1, effort: 5)],
        [run(), run(day: 1)],
        [run(completed: false)],
      ];
      for (final h in histories) {
        expect(coach.advise(h).difficulty.suggestLowImpact, isFalse,
            reason: 'already low-impact');
      }
    });
  });

  group('form tips', () {
    test('many shallow squats ask to sink deeper', () {
      final a = coach.advise([
        run(stats: {Move.squat: const MoveStats(attempts: 12, tooShallow: 5)})
      ]);
      expect(a.tips, [const CoachMessage('coach_tip_squat_deeper')]);
    });

    test('not visible gives a camera tip, early leans a centre tip', () {
      final a = coach.advise([
        run(stats: {
          Move.squat: const MoveStats(notVisible: 2),
          Move.raiseArms: const MoveStats(notVisible: 2),
          Move.leanLeft: const MoveStats(tooEarly: 2),
          Move.leanRight: const MoveStats(tooEarly: 1),
        })
      ]);
      expect(a.tips.map((t) => t.key),
          ['coach_tip_camera', 'coach_tip_lean_centre']);
    });

    test('at most two tips, most frequent first', () {
      final a = coach.advise([
        run(stats: {
          Move.squat: const MoveStats(tooShallow: 3, tooEarly: 9),
          Move.raiseArms: const MoveStats(tooShallow: 6),
        })
      ]);
      expect(a.tips.map((t) => t.key),
          ['coach_tip_squat_rise', 'coach_tip_raise_higher']);
    });

    test('a few rejections give no tip', () {
      final a = coach.advise([
        run(stats: {Move.squat: const MoveStats(tooShallow: 2)})
      ]);
      expect(a.tips, isEmpty);
    });
  });

  group('recap and goal', () {
    test('a new best score is celebrated', () {
      final a = coach.advise([run(score: 900), run(day: 1, score: 1200)]);
      expect(a.recap!.key, 'coach_recap_best');
      expect(a.recap!.params['score'], 1200);
      expect(a.recap!.params['move'], 'squat');
    });

    test('flawless, finished and effort recaps', () {
      expect(coach.advise([run()]).recap!.key, 'coach_recap_flawless');
      expect(coach.advise([run(hit: 1, hearts: 2)]).recap!.key,
          'coach_recap_finished');
      expect(coach.advise([run(completed: false)]).recap!.key,
          'coach_recap_effort');
    });

    test('next goal: finish, then all hearts, then a higher score', () {
      expect(coach.advise([run(completed: false)]).nextGoal!.key,
          'coach_goal_finish');
      expect(coach.advise([run(hearts: 2)]).nextGoal,
          const CoachMessage('coach_goal_all_hearts', {'hearts': 3}));
      expect(coach.advise([run(score: 1250)]).nextGoal,
          const CoachMessage('coach_goal_score', {'score': 1300}));
    });
  });

  group('balance', () {
    test('one dominant move suggests variety', () {
      final a = coach.advise([
        run(reps: {Move.squat: 20, Move.raiseArms: 5}),
      ]);
      expect(
          a.balance,
          const CoachMessage('coach_balance_variety', {
            'move': 'squat',
            'percent': 80,
          }));
    });

    test('runs older than a week do not count', () {
      final a = coach.advise([
        run(reps: {Move.squat: 50}),
        run(day: 8),
      ]);
      expect(a.balance, isNull);
    });

    test('too few reps say nothing', () {
      expect(
          coach.advise([
            run(reps: {Move.squat: 10})
          ]).balance,
          isNull);
    });

    test('three hard runs in a row suggest a lighter day', () {
      final a = coach.advise([
        run(effort: 4),
        run(day: 1, effort: 5),
        run(day: 2, effort: 4),
      ]);
      expect(a.balance!.key, 'coach_balance_lighter');
      final b = coach.advise([
        run(effort: 4),
        run(day: 1, effort: 2),
        run(day: 2, effort: 4),
      ]);
      expect(b.balance, isNull);
    });
  });

  test('advice is deterministic', () {
    final h = [
      run(score: 800, effort: 3),
      run(day: 1, score: 950, stats: {
        Move.squat: const MoveStats(tooShallow: 4, notVisible: 4),
      }),
    ];
    expect(coach.advise(h).toString(), coach.advise(List.of(h)).toString());
  });

  test('summaries survive a JSON round trip', () {
    final s = run(stats: {
      Move.leanLeft: const MoveStats(attempts: 5, recognised: 3, tooEarly: 2),
    });
    final back = SessionSummary.fromJson(s.toJson());
    expect(back.toJson(), s.toJson());
  });

  test('fromResult copies the run', () {
    const r = RunResult(
      levelId: 'w1-forest',
      completed: true,
      score: 500,
      hearts: 2,
      cleared: 9,
      hit: 1,
      forgiven: 0,
      energy: 3,
      reps: {Move.squat: 4},
      gameMs: 1000,
      activeMs: 900,
      difficulty: Difficulty.intermediate,
      lowImpact: true,
    );
    final s = SessionSummary.fromResult(r, date: day0, effort: 3);
    expect(s.heartsLost, 1);
    expect(s.difficulty, Difficulty.intermediate);
    expect(s.effort, 3);
  });
}
