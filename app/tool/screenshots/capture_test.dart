// Renders real app screens and game scenes to PNG (docs/screenshots/).
// Run: cd app && flutter test tool/screenshots/capture_test.dart
// Uses the real widgets and painter with the bundled Roboto font.
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
import 'package:motionquest/app/theme.dart';
import 'package:motionquest/game/forest_game.dart';
import 'package:motionquest/game/stages.dart';
import 'package:motionquest/screens/crew_screen.dart';
import 'package:motionquest/screens/home_screen.dart';
import 'package:motionquest/screens/onboarding_screens.dart';
import 'package:motionquest/screens/results_screen.dart';
import 'package:motionquest/screens/settings_screen.dart';
import 'package:motionquest/screens/stage_info_sheet.dart';
import 'package:motionquest/services/premium.dart';
import 'package:motionquest/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

const out = '../docs/screenshots';
const fonts = '/opt/flutter/bin/cache/artifacts/material_fonts';

Future<void> loadFonts() async {
  final roboto = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold', 'Black']) {
    final f = File('$fonts/Roboto-$w.ttf');
    if (f.existsSync()) {
      roboto.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
  }
  await roboto.load();
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(
        File('$fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
  await icons.load();
}

final _result = RunResult(
  levelId: forestEscapeId,
  completed: true,
  score: 4280,
  hearts: 2,
  cleared: 41,
  hit: 1,
  forgiven: 1,
  energy: 9,
  reps: const {Move.squat: 14, Move.leanLeft: 9, Move.leanRight: 8, Move.raiseArms: 12},
  gameMs: 181000,
  activeMs: 172000,
  difficulty: Difficulty.beginner,
  lowImpact: true,
);

final Map<String, Widget Function()> screens = {
  '01-welcome': () => const WelcomeScreen(),
  '02-readiness': () => const ReadinessScreen(),
  '03-home-world-map': () => const HomeScreen(),
  '04-stage-info-body-map': () =>
      Scaffold(body: StageInfoSheet(stage: stages.first, onPlay: () {})),
  '05-stage-info-desert': () => Scaffold(
      body: StageInfoSheet(stage: stageById('w2-desert-dunes')!, onPlay: () {})),
  '06-results-coach-kavi': () => ResultsScreen(
        data: ResultsData(
          result: _result,
          clientId: 'shot1',
          startedAt: DateTime.utc(2026, 11, 4, 5),
          durationS: 330,
          moveStats: const {
            'squat': {'attempts': 18, 'recognised': 14, 'tooShallow': 4},
          },
        ),
      ),
  '07-settings': () => const SettingsScreen(),
  '08-gym-crew': () => const CrewScreen(),
};

/// The app bar title style has no family (phones fall back to the system
/// font); the test renderer needs it explicit.
ThemeData _shotTheme() {
  final t = buildTheme();
  return t.copyWith(
    appBarTheme: t.appBarTheme.copyWith(
      titleTextStyle: t.appBarTheme.titleTextStyle?.copyWith(fontFamily: 'Roboto'),
    ),
  );
}

Future<void> capture(WidgetTester t, String name, Widget Function() screen) async {
  final key = GlobalKey();
  // ignore: invalid_use_of_visible_for_testing_member
  SharedPreferences.setMockInitialValues({
    'settings.v1': jsonEncode(const Settings()
        .copyWith(
          ageConfirmed: true,
          readinessDone: true,
          setupDone: true,
          tutorialDone: true,
          completedLevels: {forestEscapeId, 'w1-river-crossing'},
        )
        .toJson()),
  });
  final prefs = await SharedPreferences.getInstance();
  t.view.devicePixelRatio = 3.0;
  t.view.physicalSize = const Size(1080, 2280);
  addTearDown(t.view.reset);
  await t.pumpWidget(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      premiumProvider.overrideWith((_) async => const PremiumState()),
      homeDataProvider.overrideWith((_) async => null),
    ],
    child: RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _shotTheme(),
        home: screen(),
      ),
    ),
  ));
  await t.pump(const Duration(milliseconds: 500));
  await t.pump(const Duration(seconds: 2));
  await t.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> scene(String name, String levelId, SceneTheme theme, double from) async {
  final level = LevelConfig.decode(File('assets/levels/$levelId.json').readAsStringSync());
  final engine = RunEngine(level, const RunSettings());
  // Frame the first beam after [from], half-way down the road.
  final w = engine.director.warningMs;
  final target = engine.plan.firstWhere(
      (p) => p.arriveMs > from && p.type == EncounterType.beam,
      orElse: () => engine.plan.firstWhere((p) => p.arriveMs > from));
  final atMs = target.arriveMs - w * 0.45;
  const size = Size(1080, 2280);
  final rec = ui.PictureRecorder();
  final canvas = Canvas(rec)..scale(1);
  canvas.drawRect(Offset.zero & size, Paint()..color = theme.background);
  ForestPainter(
    size: size,
    t: atMs / 1000,
    clockMs: atMs,
    plan: engine.plan,
    heroLane: 1,
    ducking: false,
    armsUp: false,
    lanes: 3,
    warningMs: engine.director.warningMs,
    theme: theme,
  ).paint(canvas);
  final img = await rec.endRecording().toImage(1080, 2280);
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  setUpAll(() async {
    Directory(out).createSync(recursive: true);
    await loadFonts();
  });

  for (final e in screens.entries) {
    testWidgets('screen ${e.key}', (t) => capture(t, e.key, e.value));
  }

  testWidgets('game scenes', (t) async {
    await t.runAsync(() async {
      await scene('10-game-forest-escape', forestEscapeId, SceneTheme.forest, 26500);
      await scene('11-game-desert-dunes', 'w2-desert-dunes', SceneTheme.desert, 41000);
      await scene('12-game-neon-city', 'w3-neon-city-rooftops', SceneTheme.neon, 52000);
      await scene('13-game-mountain-trail', 'w4-mountain-trail', SceneTheme.mountain, 45000);
    });
  });
}
