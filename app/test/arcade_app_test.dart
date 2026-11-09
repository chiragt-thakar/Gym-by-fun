import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:motionquest/app/router.dart';
import 'package:motionquest/arcade/arcade_screen.dart';
import 'package:motionquest/arcade/catalog.dart';
import 'package:motionquest/arcade/content.dart';
import 'package:motionquest/arcade/progress.dart';
import 'package:motionquest/screens/game_detail_screen.dart';
import 'package:motionquest/screens/get_ready_screen.dart';
import 'package:motionquest/screens/games_screen.dart';
import 'package:motionquest/screens/home_screen.dart';
import 'package:motionquest/services/coach_service.dart';
import 'package:motionquest/services/pose_service.dart';
import 'package:motionquest/services/premium.dart';
import 'package:motionquest/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

CalibrationProfile _cal() => CalibrationProfile.fromStanding(
  PoseFrame(timestampMs: 0, landmarks: SyntheticBody(noise: 0).pose()),
);

const _summary = ArcadeSummary(
  gameId: 'mirror-mela',
  stageId: 'bubble-bazaar',
  score: 900,
  stars: 2,
  maxStars: 3,
  accuracy: 0.8,
  bestCombo: 9,
  activeMs: 60000,
  completed: true,
  headline: 'Grade A',
  moves: {'reach': 20},
);

void main() {
  group('arcade args', () {
    test('round-trip through the play route', () {
      const a = ArcadeArgs(
        gameId: 'pataka-pose',
        stageId: 'pass-the-pataka',
        difficulty: 'advanced',
        assist: true,
        players: ['Asha', 'Ravi'],
        noSquat: true,
        level: 'groove',
        daily: true,
      );
      final uri = a.toUri();
      expect(uri.path, '/play/pataka-pose');
      final b = ArcadeArgs.fromUri('pataka-pose', uri);
      expect(b.stageId, a.stageId);
      expect(b.difficulty, 'advanced');
      expect(b.assist, isTrue);
      expect(b.players, ['Asha', 'Ravi']);
      expect(b.noSquat, isTrue);
      expect(b.level, 'groove');
      expect(b.daily, isTrue);
    });

    test('play routes are gated until calibration, and are safe next targets', () {
      const s = Settings(ageConfirmed: true, readinessDone: true);
      final play = Uri.parse('/play/lumen?stage=first-light');
      expect(Uri.parse(playGate(s, play)!).path, '/get-ready');
      expect(safeNext(play.toString()), play.toString());
      expect(playGate(s.copyWith(calibration: _cal()), play), isNull);
      expect(playGate(s, Uri.parse('/games')), isNull);
      expect(playGate(s, Uri.parse('/game/lumen')), isNull);
    });
  });

  group('bundled content', () {
    late ArcadeContent content;
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      content = await ArcadeContent.load(rootBundle);
    });

    test('every catalogue game has levels, except the runner', () {
      for (final g in games) {
        final stages = content.stagesFor(g.id);
        if (g.id == adventureId) {
          expect(stages, isEmpty);
        } else {
          expect(stages, isNotEmpty, reason: g.id);
        }
      }
    });

    test('an engine builds for every stage of every game', () {
      const s = Settings();
      for (final g in games.where((g) => g.id != adventureId)) {
        for (final st in content.stagesFor(g.id)) {
          final e = buildEngine(
            content,
            ArcadeArgs(
              gameId: g.id,
              stageId: st.id,
              players: st.party ? const ['A', 'B'] : const [],
            ),
            s,
          );
          expect(e.finished, isFalse, reason: '${g.id}/${st.id}');
          e.advance(33, tracked: true);
        }
      }
    });
  });

  group('progress', () {
    late ProviderContainer c;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      c = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      );
    });
    tearDown(() => c.dispose());

    test('keeps the best score and stars, counts plays, marks the day', () {
      final n = c.read(arcadeProgressProvider.notifier);
      n.record(_summary);
      n.record(
        const ArcadeSummary(
          gameId: 'mirror-mela',
          stageId: 'bubble-bazaar',
          score: 400,
          stars: 1,
          maxStars: 3,
          accuracy: 0.5,
          bestCombo: 3,
          activeMs: 60000,
          completed: true,
          headline: '',
        ),
      );
      final p = c.read(arcadeProgressProvider);
      final r = p.record('mirror-mela', 'bubble-bazaar');
      expect(r.bestScore, 900);
      expect(r.stars, 2);
      expect(r.plays, 2);
      expect(p.sessions, hasLength(2));
      expect(c.read(activityDaysProvider), contains(localActivityDay(DateTime.now())));
    });

    test('stages unlock in order once the one before is completed', () {
      final order = ['a', 'b', 'c'];
      var p = const ArcadeProgress();
      expect(p.unlocked('g', order, 'a'), isTrue);
      expect(p.unlocked('g', order, 'b'), devUnlockAllForTests);
      expect(p.unlocked('g', order, 'c', alwaysOpen: true), isTrue);
      p = ArcadeProgress(records: {
        'g': {'a': const StageRecord(completed: true, stars: 1)},
      });
      expect(p.unlocked('g', order, 'b'), isTrue);
    });

    test('habitat repairs persist across restarts', () async {
      c.read(arcadeProgressProvider.notifier).record(
        const ArcadeSummary(
          gameId: 'lumen',
          stageId: 'first-light',
          score: 500,
          stars: 2,
          maxStars: 3,
          accuracy: 0.5,
          bestCombo: 2,
          activeMs: 90000,
          completed: false,
          headline: '',
        ),
        habitat: {'conservatory/light', 'conservatory/water'},
      );
      final prefs = c.read(sharedPrefsProvider);
      final again = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      );
      addTearDown(again.dispose);
      expect(again.read(arcadeProgressProvider).habitat, {
        'conservatory/light',
        'conservatory/water',
      });
    });
  });

  group('navigation', () {
    Future<ProviderContainer> app(WidgetTester t, {Settings? settings, PoseSource? pose}) async {
      await t.binding.setSurfaceSize(const Size(400, 860));
      addTearDown(() => t.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({
        'settings.v1': jsonEncode(
          (settings ?? const Settings(ageConfirmed: true, readinessDone: true)).toJson(),
        ),
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        premiumProvider.overrideWith((_) async => const PremiumState()),
        homeDataProvider.overrideWith((_) async => null),
        syncStatusProvider.overrideWith((_) async => (pending: 0, rejected: 0)),
        if (pose != null) poseSourceProvider.overrideWithValue(pose),
      ]);
      addTearDown(container.dispose);
      await t.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: container.read(routerProvider)),
      ));
      await t.pumpAndSettle();
      return container;
    }

    Future<void> back(WidgetTester t) async {
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
    }

    testWidgets('bottom tabs switch pages and back returns Home, never exits', (t) async {
      final c = await app(t);
      expect(find.byType(HomeScreen), findsOneWidget);
      await t.tap(find.text('Games').last);
      await t.pumpAndSettle();
      expect(find.byType(GamesScreen), findsOneWidget);
      await back(t);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(c.read(routerProvider).routerDelegate.currentConfiguration.uri.path, '/home');
    });

    testWidgets('on Home, back warns first and only a second press exits', (t) async {
      final calls = <MethodCall>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await app(t);
      await back(t);
      expect(find.text('Press back again to exit'), findsOneWidget);
      expect(calls.where((c) => c.method == 'SystemNavigator.pop'), isEmpty);
      await t.binding.handlePopRoute();
      await t.pump();
      expect(calls.where((c) => c.method == 'SystemNavigator.pop'), isNotEmpty);
    });

    testWidgets('a game page opens over the tabs and back returns to the library', (t) async {
      final c = await app(t);
      c.read(routerProvider).go('/games');
      await t.pumpAndSettle();
      await t.ensureVisible(find.byKey(const ValueKey('game-craftguard')));
      await t.pumpAndSettle();
      await t.tap(find.text('Craftguard Duels').first);
      await t.pumpAndSettle();
      expect(find.byType(GameDetailScreen), findsOneWidget);
      await back(t);
      expect(find.byType(GameDetailScreen), findsNothing);
      expect(find.byType(GamesScreen), findsOneWidget);
    });

    testWidgets('a directly opened page goes Home on back', (t) async {
      final c = await app(t);
      c.read(routerProvider).go('/game/craftguard');
      await t.pumpAndSettle();
      expect(find.byType(GameDetailScreen), findsOneWidget);
      await back(t);
      expect(c.read(routerProvider).routerDelegate.currentConfiguration.uri.path, '/games');
    });

    testWidgets('Play without calibration asks for setup first', (t) async {
      final c = await app(t);
      c.read(routerProvider).push('/play/mirror-mela?stage=bubble-bazaar');
      await t.pumpAndSettle();
      expect(find.byType(GetReadyScreen), findsOneWidget);
      expect(find.byType(ArcadeScreen), findsNothing);
    });

    testWidgets('the play screen starts the camera, pauses on back and releases it on leave', (t) async {
      final source = ReplayPoseSource(const []);
      final c = await app(
        t,
        settings: Settings(ageConfirmed: true, readinessDone: true, setupDone: true, calibration: _cal()),
        pose: source,
      );
      c.read(routerProvider).push('/play/mirror-mela?stage=bubble-bazaar');
      for (var i = 0; i < 20 && !source.started; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(source.started, isTrue);
      expect(find.byType(ArcadeScreen), findsOneWidget);
      await t.binding.handlePopRoute();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Paused'), findsOneWidget);
      await t.tap(find.text('Leave'));
      for (var i = 0; i < 10 && source.started; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(source.started, isFalse, reason: 'camera released');
      expect(find.byType(ArcadeScreen), findsNothing);
    });
  });
}

/// The developer build unlocks everything; normal test runs do not.
const devUnlockAllForTests = bool.fromEnvironment('DEV_UNLOCK_ALL');
