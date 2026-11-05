import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';
import 'package:motionquest/l10n/coach_strings.dart';
import 'package:motionquest/l10n/strings.dart';
import 'package:motionquest/screens/results_screen.dart';
import 'package:motionquest/services/coach_service.dart';
import 'package:motionquest/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

RunResult result({int score = 1000, int hit = 0, int hearts = 3}) => RunResult(
  levelId: 'w1-forest',
  completed: true,
  score: score,
  hearts: hearts,
  cleared: 20,
  hit: hit,
  forgiven: 0,
  energy: 5,
  reps: const {Move.squat: 10, Move.leanLeft: 6, Move.raiseArms: 6},
  gameMs: 180000,
  activeMs: 170000,
  difficulty: Difficulty.beginner,
  lowImpact: true,
);

SessionSummary summary(int i, {int score = 1000}) => SessionSummary.fromResult(
  result(score: score),
  date: DateTime.utc(2026, 11, 1).add(Duration(hours: i)),
  effort: 2,
);

Future<ProviderContainer> container([
  Map<String, Object> prefs = const {},
]) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  final c = ProviderContainer(
    overrides: [sharedPrefsProvider.overrideWithValue(p)],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('history is kept to the last 20 and survives a restart', () async {
    final c = await container();
    for (var i = 0; i < 25; i++) {
      c.read(coachHistoryProvider.notifier).record(summary(i, score: i));
    }
    final h = c.read(coachHistoryProvider);
    expect(h.length, CoachHistoryNotifier.maxHistory);
    expect(h.first.score, 5);
    expect(h.last.score, 24);

    final p = await SharedPreferences.getInstance();
    final c2 = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(p)],
    );
    addTearDown(c2.dispose);
    expect(c2.read(coachHistoryProvider).map((s) => s.score), [
      for (var i = 5; i < 25; i++) i,
    ]);
  });

  test('saving the same run again replaces it (dedupe by clientId)', () async {
    final c = await container();
    SessionSummary run({int? effort}) => SessionSummary.fromResult(
      result(),
      date: DateTime.utc(2026, 11, 1),
      clientId: 'client-0001',
      effort: effort,
    );
    c.read(coachHistoryProvider.notifier)
      ..record(summary(0))
      ..record(run())
      ..record(run(effort: 4));
    final h = c.read(coachHistoryProvider);
    expect(h, hasLength(2));
    expect(h.last.clientId, 'client-0001');
    expect(h.last.effort, 4);
  });

  test('stored history holds counts only, no frames or landmarks', () async {
    final c = await container();
    c.read(coachHistoryProvider.notifier).record(summary(0));
    final raw = (await SharedPreferences.getInstance()).getString(
      CoachHistoryNotifier.key,
    )!;
    expect(raw, isNot(contains('landmark')));
    expect(raw, isNot(contains('frame')));
  });

  test('advice follows the history', () async {
    final c = await container();
    expect(
      c.read(coachAdviceProvider).difficulty.reason,
      CoachReason.noHistory,
    );
    c.read(coachHistoryProvider.notifier)
      ..record(summary(0))
      ..record(summary(1));
    final a = c.read(coachAdviceProvider);
    expect(a.difficulty.recommended, Difficulty.intermediate);
  });

  test('pose stats convert to coach stats', () {
    final m = moveStatsFrom({
      'squat': {'attempts': 9, 'recognised': 5, 'tooShallow': 4},
      'unknown': {'attempts': 1},
    });
    expect(m.keys, [Move.squat]);
    expect(m[Move.squat]!.tooShallow, 4);
  });

  test('every coach key has en, hi and gu text', () {
    const keys = [
      'coach_recap_best',
      'coach_recap_flawless',
      'coach_recap_finished',
      'coach_recap_effort',
      'coach_goal_finish',
      'coach_goal_all_hearts',
      'coach_goal_score',
      'coach_tip_squat_deeper',
      'coach_tip_squat_rise',
      'coach_tip_lean_further',
      'coach_tip_lean_centre',
      'coach_tip_raise_higher',
      'coach_tip_raise_lower',
      'coach_tip_camera',
      'coach_balance_variety',
      'coach_balance_lighter',
    ];
    for (final k in [
      ...keys,
      for (final r in CoachReason.values) 'coach_reason_${r.name}',
    ]) {
      final en = coachKey(AppLanguage.en, k);
      expect(en, isNot(k), reason: k);
      expect(coachKey(AppLanguage.hi, k), isNot(en), reason: 'hi $k');
      expect(coachKey(AppLanguage.gu, k), isNot(en), reason: 'gu $k');
    }
    expect(
      coachText(
        AppLanguage.en,
        const CoachMessage('coach_balance_variety', {
          'move': 'squat',
          'percent': 70,
        }),
      ),
      contains('70% of this week\'s moves were squats'),
    );
  });

  testWidgets('results show the Coach Kavi card and apply a level', (t) async {
    final first = summary(0);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    t.view.physicalSize = const Size(1080, 4000);
    t.view.devicePixelRatio = 2.6;
    addTearDown(t.view.reset);
    final c = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    c.read(coachHistoryProvider.notifier).record(first);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          home: ResultsScreen(
            data: ResultsData(
              result: result(score: 1500),
              clientId: 'c1',
              startedAt: DateTime.utc(2026, 11, 1, 5),
              durationS: 180,
              moveStats: const {
                'squat': {'attempts': 12, 'recognised': 6, 'tooShallow': 6},
              },
            ),
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.byKey(const Key('coach-card')), findsOneWidget);
    expect(find.text('Coach Kavi'), findsOneWidget);
    expect(find.textContaining('New personal best: 1500'), findsOneWidget);
    expect(find.textContaining('Sink a little deeper'), findsOneWidget);
    expect(find.textContaining('Next goal: Score 1600'), findsOneWidget);

    final button = find.text('Try Intermediate');
    expect(button, findsOneWidget);
    await t.ensureVisible(button);
    await t.tap(button);
    await t.pump();
    expect(c.read(settingsProvider).difficulty, Difficulty.intermediate);
    expect(find.text('Done — your next run uses this.'), findsOneWidget);
  });
}
