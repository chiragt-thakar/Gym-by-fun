import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_director/game_director.dart';
import 'package:joynetic/app/theme.dart';
import 'package:joynetic/arcade/arcade_results_screen.dart';
import 'package:joynetic/arcade/arcade_screen.dart';
import 'package:joynetic/arcade/art/game_art.dart';
import 'package:joynetic/arcade/art/paint_kit.dart' show artFontFamily;
import 'package:joynetic/game/stages.dart';
import 'package:joynetic/screens/game_detail_screen.dart';
import 'package:joynetic/screens/games_screen.dart';
import 'package:joynetic/screens/home_screen.dart';
import 'package:joynetic/screens/profile_screen.dart';
import 'package:joynetic/screens/progress_screen.dart';
import 'package:joynetic/services/premium.dart';
import 'package:joynetic/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Opt-in UI previews of the v2 shell and game art:
/// `flutter test --dart-define=CAPTURE_UX=true test/capture_v2_test.dart`.
/// Writes PNGs to docs/screenshots/v2-*.png. Illustrations only, no camera.
void main() {
  if (!const bool.fromEnvironment('CAPTURE_UX')) return;

  Future<void> fonts() async {
    artFontFamily = 'Preview';
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    final bold = File('C:/Windows/Fonts/segoeuib.ttf');
    final loader = FontLoader('Preview')
      ..addFont(Future.value(ByteData.sublistView(font.readAsBytesSync())))
      ..addFont(Future.value(ByteData.sublistView(bold.readAsBytesSync())));
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  }

  ThemeData theme() {
    final t = buildTheme(fontFamily: 'Preview');
    return t.copyWith(
      textTheme: t.textTheme.apply(fontFamily: 'Preview'),
      appBarTheme: t.appBarTheme.copyWith(
        titleTextStyle: t.appBarTheme.titleTextStyle!.copyWith(fontFamily: 'Preview'),
      ),
    );
  }

  Future<void> shot(WidgetTester t, String name, Widget child, {Size size = const Size(390, 844), Future<void> Function()? before}) async {
    await fonts();
    SharedPreferences.setMockInitialValues({
      'settings.v1': jsonEncode(const Settings(
        ageConfirmed: true,
        readinessDone: true,
        completedLevels: {'w1-forest-escape', 'w1-river-crossing'},
      ).toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = size;
    addTearDown(t.view.reset);
    final key = GlobalKey();
    await t.pumpWidget(ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        premiumProvider.overrideWith((_) async => const PremiumState()),
        homeDataProvider.overrideWith((_) async => null),
        syncStatusProvider.overrideWith((_) async => (pending: 0, rejected: 0)),
      ],
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme(),
          home: DefaultTextStyle(style: const TextStyle(fontFamily: 'Preview'), child: child),
        ),
      ),
    ));
    await t.runAsync(() async => Future<void>.delayed(const Duration(milliseconds: 400)));
    await t.pump(const Duration(milliseconds: 600));
    await t.pump(const Duration(seconds: 1));
    if (before != null) await before();
    final render = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await t.runAsync(() async {
      final img = await render.toImage(pixelRatio: 2);
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      File('../docs/screenshots/v2-$name.png').writeAsBytesSync(png!.buffer.asUint8List());
      img.dispose();
    });
  }

  testWidgets('home', (t) => shot(t, 'home', const HomeScreen()));
  testWidgets('home scrolled', (t) => shot(t, 'home-2', const HomeScreen(), before: () async {
    await t.drag(find.byType(ListView).first, const Offset(0, -620));
    await t.pump(const Duration(seconds: 1));
  }));
  testWidgets('games', (t) => shot(t, 'games', const GamesScreen()));
  testWidgets('progress', (t) => shot(t, 'progress', const ProgressScreen()));
  testWidgets('profile', (t) => shot(t, 'profile', const ProfileScreen()));
  for (final id in ['craftguard', 'lumen', 'adventure', 'pataka-pose']) {
    testWidgets('detail $id', (t) => shot(t, 'detail-$id', GameDetailScreen(gameId: id)));
  }
  testWidgets('detail lumen scrolled', (t) => shot(t, 'detail-lumen-2', const GameDetailScreen(gameId: 'lumen'), before: () async {
    await t.drag(find.byType(CustomScrollView).first, const Offset(0, -900));
    await t.pump(const Duration(seconds: 1));
  }));
  testWidgets('results', (t) => shot(
    t,
    'results',
    const ArcadeResultsScreen(
      result: ArcadeResult(
        args: ArcadeArgs(gameId: 'craftguard', stageId: 'baoli-warden'),
        stageName: 'Baoli Warden',
        previousBest: 900,
        summary: ArcadeSummary(
          gameId: 'craftguard',
          stageId: 'baoli-warden',
          score: 2840,
          stars: 2,
          maxStars: 3,
          accuracy: 0.78,
          bestCombo: 14,
          activeMs: 162000,
          completed: true,
          headline: 'You calmed the Baoli Warden',
          moves: {'duck': 11, 'lean': 8, 'guard': 5, 'side strike': 9, 'arms up': 4},
          details: {'Seal': 'Brass', 'Sparks left': '2'},
        ),
      ),
    ),
  ));
  // Each game's in-play art at phone size (same painters as play).
  for (final id in ['mirror-mela', 'pataka-pose', 'craftguard', 'taal-toofan', 'tapeball', 'lumen']) {
    testWidgets('art $id', (t) => shot(
      t,
      'art-$id',
      Scaffold(
        body: Column(
          children: [
            for (var v = 0; v < 4; v++)
              AspectRatio(aspectRatio: 16 / 9, child: GameArt(gameId: id, variant: v)),
          ],
        ),
      ),
      size: const Size(390, 880),
    ));
  }
  testWidgets('stages list unaffected', (t) async {
    expect(stages, isNotEmpty);
  });
}
