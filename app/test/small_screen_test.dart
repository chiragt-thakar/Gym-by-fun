import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';
import 'package:motionquest/game/stages.dart';
import 'package:motionquest/app/theme.dart';
import 'package:motionquest/services/coach_service.dart';
import 'package:motionquest/services/api_client.dart';
import 'package:motionquest/services/session_queue.dart';
import 'package:motionquest/l10n/strings.dart';
import 'package:motionquest/l10n/tr.dart';
import 'package:motionquest/arcade/arcade_results_screen.dart';
import 'package:motionquest/arcade/arcade_screen.dart';
import 'package:motionquest/screens/crew_screen.dart';
import 'package:motionquest/screens/game_detail_screen.dart';
import 'package:motionquest/screens/games_screen.dart';
import 'package:motionquest/screens/profile_screen.dart';
import 'package:motionquest/screens/progress_screen.dart';
import 'package:motionquest/screens/home_screen.dart';
import 'package:motionquest/screens/onboarding_screens.dart';
import 'package:motionquest/screens/results_screen.dart';
import 'package:motionquest/screens/settings_screen.dart';
import 'package:motionquest/screens/sign_in_screen.dart';
import 'package:motionquest/screens/stage_info_sheet.dart';
import 'package:motionquest/services/premium.dart';
import 'package:motionquest/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PreviewQueue extends SessionQueue {
  _PreviewQueue(super.api);
  @override
  Future<void> add(Map<String, Object?> session) async {}
  @override
  Future<int> flush() async => 0;
}

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
  missionWon: true,
  missionCount: 12,
  missionGoal: 10,
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
  'games': () => const GamesScreen(),
  'progress': () => const ProgressScreen(),
  'profile': () => const ProfileScreen(),
  'detail craftguard': () => const GameDetailScreen(gameId: 'craftguard'),
  'detail pataka': () => const GameDetailScreen(gameId: 'pataka-pose'),
  'detail runner': () => const GameDetailScreen(gameId: 'adventure'),
  'arcade results': () => const ArcadeResultsScreen(
    result: ArcadeResult(
      args: ArcadeArgs(gameId: 'tapeball', stageId: 'super-over'),
      stageName: 'Super Over',
      previousBest: 8,
      summary: ArcadeSummary(
        gameId: 'tapeball',
        stageId: 'super-over',
        score: 14,
        stars: 3,
        maxStars: 3,
        accuracy: 0.8,
        bestCombo: 5,
        activeMs: 150000,
        completed: true,
        headline: 'Chased 12 with 2 balls to spare',
        moves: {'swing': 6, 'arms up': 1},
        details: {'Runs': '14', 'Wickets': '0/2', 'Fours': '2', 'Sixes': '1'},
      ),
    ),
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
  // Opt-in, reproducible UI previews; these trees contain no camera view.
  if (const bool.fromEnvironment('CAPTURE_UX')) {
    for (final name in ['home', 'map', 'results']) {
      testWidgets('capture adventure $name', (t) async {
        final font = File('C:/Windows/Fonts/segoeui.ttf');
        final loader = FontLoader('Preview');
        loader.addFont(
          Future.value(ByteData.sublistView(font.readAsBytesSync())),
        );
        await loader.load();
        final icons = FontLoader('MaterialIcons');
        icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
        final catalog = {
          for (final stage in stages)
            stage.levelId: LevelConfig.decode(
              File(stage.asset).readAsStringSync(),
            ),
        };
        final now = DateTime.now();
        SharedPreferences.setMockInitialValues({
          'settings.v1': jsonEncode(
            const Settings(
              completedLevels: {'w1-forest-escape'},
              sessionsPlayed: 3,
            ).toJson(),
          ),
          CoachHistoryNotifier.key: jsonEncode([
            for (final d in [4, 2, 0])
              SessionSummary.fromResult(
                _result,
                date: now.subtract(Duration(days: d)),
                clientId: 'preview$d',
              ).toJson(),
          ]),
        });
        final prefs = await SharedPreferences.getInstance();
        t.view.devicePixelRatio = 1;
        t.view.physicalSize = const Size(390, 844);
        addTearDown(t.view.reset);
        final theme = buildTheme();
        final boundaryKey = GlobalKey();
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPrefsProvider.overrideWithValue(prefs),
              sessionQueueProvider.overrideWithValue(
                _PreviewQueue(ApiClient(TokenStore(prefs))),
              ),
              levelCatalogueProvider.overrideWith((_) async => catalog),
              homeDataProvider.overrideWith((_) async => null),
              syncStatusProvider.overrideWith(
                (_) async => (pending: 3, rejected: 0),
              ),
              premiumProvider.overrideWith((_) async => const PremiumState()),
            ],
            child: RepaintBoundary(
              key: boundaryKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: theme.copyWith(
                  textTheme: theme.textTheme.apply(fontFamily: 'Preview'),
                  appBarTheme: theme.appBarTheme.copyWith(
                    titleTextStyle: theme.appBarTheme.titleTextStyle!.copyWith(
                      fontFamily: 'Preview',
                    ),
                  ),
                  segmentedButtonTheme: SegmentedButtonThemeData(
                    style: theme.segmentedButtonTheme.style!.copyWith(
                      textStyle: const WidgetStatePropertyAll(
                        TextStyle(fontFamily: 'Preview', fontSize: 18),
                      ),
                    ),
                  ),
                ),
                home: name != 'results'
                    ? const HomeScreen()
                    : ResultsScreen(
                        data: ResultsData(
                          result: _result,
                          levelId: 'w1-forest-escape',
                          clientId: 'preview-result',
                          startedAt: now,
                          durationS: 180,
                        ),
                      ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        if (name == 'map') {
          await t.drag(find.byType(ListView).first, const Offset(0, -700));
          await t.pumpAndSettle();
        }
        final render =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await t.runAsync(() async {
          final img = await render.toImage(pixelRatio: 3);
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          File('../docs/screenshots/next-$name.png')
              .writeAsBytesSync(png!.buffer.asUint8List());
          img.dispose();
        });
        expect(t.takeException(), isNull);
      });
    }
  }
  for (final MapEntry(key: name, value: screen) in _screens.entries) {
    for (final size in _sizes) {
      for (final scale in _scales) {
        for (final lang in AppLanguage.values) {
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
