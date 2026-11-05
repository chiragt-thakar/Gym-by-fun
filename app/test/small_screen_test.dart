import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';
import 'package:motionquest/game/stages.dart';
import 'package:motionquest/l10n/strings.dart';
import 'package:motionquest/l10n/tr.dart';
import 'package:motionquest/screens/crew_screen.dart';
import 'package:motionquest/screens/home_screen.dart';
import 'package:motionquest/screens/onboarding_screens.dart';
import 'package:motionquest/screens/results_screen.dart';
import 'package:motionquest/screens/settings_screen.dart';
import 'package:motionquest/screens/sign_in_screen.dart';
import 'package:motionquest/screens/stage_info_sheet.dart';
import 'package:motionquest/services/premium.dart';
import 'package:motionquest/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _result = RunResult(
  levelId: 'w1-forest',
  completed: true,
  score: 1500,
  hearts: 3,
  cleared: 20,
  hit: 2,
  forgiven: 1,
  energy: 5,
  reps: const {Move.squat: 10, Move.leanLeft: 6, Move.raiseArms: 6},
  gameMs: 180000,
  activeMs: 170000,
  difficulty: Difficulty.beginner,
  lowImpact: true,
);

final Map<String, Widget Function()> _screens = {
  'welcome': () => const WelcomeScreen(),
  'age gate': () => const AgeGateScreen(),
  'readiness': () => const ReadinessScreen(),
  'home': () => const HomeScreen(),
  'results': () => ResultsScreen(
    data: ResultsData(
      result: _result,
      clientId: 'c1',
      startedAt: DateTime.utc(2026, 11, 1, 5),
      durationS: 180,
      moveStats: const {
        'squat': {'attempts': 12, 'recognised': 6, 'tooShallow': 6},
      },
    ),
  ),
  'settings': () => const SettingsScreen(),
  'crew': () => const CrewScreen(),
  'sign in': () => const SignInScreen(),
  'stage info': () => Scaffold(
    body: StageInfoSheet(stage: stages.first, onPlay: () {}),
  ),
};

const _sizes = [Size(320, 568), Size(360, 640)];
const _scales = [1.0, 1.3];

Future<void> _pump(
  WidgetTester t,
  Widget Function() screen,
  Size size,
  double scale,
  AppLanguage lang,
) async {
  await t.pumpWidget(const SizedBox());
  SharedPreferences.setMockInitialValues({
    'settings.v1': jsonEncode(
      const Settings().copyWith(language: lang).toJson(),
    ),
  });
  currentLanguage = lang;
  addTearDown(() => currentLanguage = AppLanguage.en);
  final prefs = await SharedPreferences.getInstance();
  t.view.devicePixelRatio = 2.0;
  t.view.physicalSize = size * 2.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        premiumProvider.overrideWith((_) async => const PremiumState()),
        homeDataProvider.overrideWith((_) async => null),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: screen(),
      ),
    ),
  );
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(seconds: 2));
}

void main() {
  for (final MapEntry(key: name, value: screen) in _screens.entries) {
    for (final size in _sizes) {
      for (final scale in _scales) {
        for (final lang in [AppLanguage.en, AppLanguage.hi]) {
          testWidgets('$name fits ${size.width.toInt()}x${size.height.toInt()} '
              'at text ${scale}x in ${lang.name}', (t) async {
            await _pump(t, screen, size, scale, lang);
            expect(t.takeException(), isNull);
          });
        }
      }
    }
  }
}
