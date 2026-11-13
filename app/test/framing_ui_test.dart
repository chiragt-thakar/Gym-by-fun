import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Action;
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'package:game_director/game_director.dart';
import 'package:joynetic/game/forest_game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:joynetic/l10n/strings.dart';
import 'package:joynetic/l10n/tr.dart';
import 'package:joynetic/screens/calibration_screen.dart';
import 'package:joynetic/screens/setup_screen.dart';
import 'package:joynetic/screens/quest_screen.dart';
import 'package:joynetic/services/pose_service.dart';
import 'package:joynetic/services/settings.dart';
import 'package:joynetic/services/voice.dart';
import 'package:joynetic/widgets/frame_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

class _LevelBundle extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      File(key).readAsStringSync();
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

/// Records what would be spoken; never touches TTS or audio.
class RecordingVoice extends Voice {
  final spoken = <String>[];
  @override
  Future<void> init(AppLanguage lang) async {}
  @override
  Future<void> say(String text, {bool force = false}) async => spoken.add(text);
  @override
  Future<void> sayKey(String key, {bool force = false}) async =>
      spoken.add(key);
  @override
  Future<void> cue(String name) async {}
  @override
  Future<void> stop() async {}
}

/// Pushes [ms] of frames of [body] at 30 fps, starting at [from].
Future<int> play(
  WidgetTester t,
  ReplayPoseSource src,
  SyntheticBody body,
  int from,
  int ms,
) async {
  var ts = from;
  for (; ts < from + ms; ts += 33) {
    src.push(
      PoseFrame(timestampMs: ts, landmarks: body.pose(), imageHeight: 640),
    );
    await t.pump();
  }
  return ts;
}

void main() {
  late ReplayPoseSource src;
  late RecordingVoice voice;

  Future<void> pumpQuest(
    WidgetTester t,
    SyntheticSession recording, {
    bool locked = false,
    bool gentle = false,
    bool fullRun = false,
    Settings preferences = const Settings(),
    double textScale = 1,
  }) async {
    t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    SharedPreferences.setMockInitialValues({
      'settings.v1': jsonEncode(
        preferences.copyWith(calibration: recording.calibrate()).toJson(),
      ),
    });
    final prefs = await SharedPreferences.getInstance();
    src = ReplayPoseSource(const []);
    voice = RecordingVoice();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          poseSourceProvider.overrideWithValue(src),
          voiceProvider.overrideWithValue(voice),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: DefaultAssetBundle(
            bundle: _LevelBundle(),
            child: QuestScreen(
              tutorial: !locked && !gentle && !fullRun,
              gentle: gentle,
              levelId: locked ? 'w1-river-crossing' : null,
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < 20; i++) {
      final ready = locked
          ? find.textContaining('This stage is locked.')
          : gentle || fullRun
          ? find.text('Skip')
          : find.byTooltip('Pause');
      if (ready.evaluate().isNotEmpty) break;
      await t.pump(const Duration(milliseconds: 50));
    }
    if (!locked && !gentle && !fullRun) {
      expect(
        find.byTooltip('Pause'),
        findsOneWidget,
        reason: t
            .widgetList<Text>(find.byType(Text))
            .map((w) => w.data)
            .join(' | '),
      );
    }
  }

  testWidgets('direct locked quest route fails before starting the camera', (
    t,
  ) async {
    await pumpQuest(t, SyntheticSession(SyntheticBody(noise: 0)), locked: true);
    expect(find.textContaining('This stage is locked.'), findsOneWidget);
    expect(src.started, isFalse);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Gentle today changes this run without changing saved preferences',
    (t) async {
      await pumpQuest(
        t,
        SyntheticSession(SyntheticBody(noise: 0)),
        gentle: true,
        preferences: const Settings(
          difficulty: Difficulty.advanced,
          lowImpact: false,
          assist: false,
        ),
      );
      for (var i = 0; i < warmup.length; i++) {
        await t.tap(find.text('Skip'));
        await t.pump(const Duration(milliseconds: 50));
      }
      await t.pump();
      final widget = t.widget(
        find.byWidgetPredicate((w) => w is GameWidget),
      ) as GameWidget;
      final settings = (widget.game as ForestGame).engine.settings;
      expect(settings.difficulty, Difficulty.beginner);
      expect(
        settings.lowImpactFor(
          (widget.game as ForestGame).engine.level.difficulty[settings
              .difficulty]!,
        ),
        isTrue,
      );
      expect(settings.assist, isTrue);
      final saved = ProviderScope.containerOf(
        t.element(find.byType(QuestScreen)),
      ).read(settingsProvider);
      expect(saved.difficulty, Difficulty.advanced);
      expect(saved.lowImpact, isFalse);
      expect(saved.assist, isFalse);
      await t.pumpWidget(const SizedBox());
      await t.pump();
    },
  );

  testWidgets(
    'live quest HUD fits a 320px phone and background stops the camera',
    (t) async {
      addTearDown(
        () =>
            t.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed),
      );
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(320, 568);
      addTearDown(t.view.reset);
      await pumpQuest(
        t,
        SyntheticSession(SyntheticBody(noise: 0)),
        textScale: 1.3,
        fullRun: true,
      );
      for (var i = 0; i < warmup.length; i++) {
        await t.ensureVisible(find.text('Skip'));
        await t.tap(find.text('Skip'));
        await t.pump(const Duration(milliseconds: 50));
        expect(t.takeException(), isNull, reason: 'warm-up step $i');
      }
      for (
        var i = 0;
        i < 10 && find.text('Clear the trail').evaluate().isEmpty;
        i++
      ) {
        await t.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Clear the trail'), findsOneWidget);
      expect(t.takeException(), isNull);
      // Deliver the lifecycle notification to the screen directly so Flutter's
      // test scheduler can keep rendering the overlay while "backgrounded".
      final lifecycle =
          t.state(find.byType(QuestScreen)) as WidgetsBindingObserver;
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
      for (var i = 0; i < 20 && src.started; i++) {
        await t.pump(const Duration(milliseconds: 1));
      }
      await t.pump();
      expect(src.started, isFalse, reason: 'camera calls: ${src.calls}');
      expect(find.text('Paused'), findsOneWidget);
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await t.pump();
      await t.pump();
      expect(src.started, isTrue);
      expect(
        find.text('Paused'),
        findsOneWidget,
        reason: 'foregrounding alone never resumes gameplay',
      );
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.paused);
      await t.pump();
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      src.nextStartError = PlatformException(code: 'camera_unavailable');
      lifecycle.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await t.pump();
      await t.pump();
      expect(
        find.text('The camera could not start. Please try again.'),
        findsOneWidget,
      );
      await t.tap(find.text('Retry'));
      await t.pump();
      await t.pump();
      expect(src.started, isTrue);
      expect(
        find.text('Paused'),
        findsOneWidget,
        reason: 'camera retry preserves the paused run',
      );
      await t.pumpWidget(const SizedBox());
      await t.pump();
    },
  );

  testWidgets('paused quest resumes from real replayed poses without a tap', (
    t,
  ) async {
    final recording = SyntheticSession(SyntheticBody(noise: 0));
    await pumpQuest(t, recording);
    await t.pump(const Duration(milliseconds: 100));
    await t.tap(find.byTooltip('Pause'));
    await t.pump();
    expect(find.text('Paused'), findsOneWidget);
    expect(
      src.started,
      isTrue,
      reason: 'foreground pause supports hands-free controls',
    );
    final poses = recording.record([
      const ScriptStep(Action.idle, 1000),
      const ScriptStep(Action.raiseArms, 2200),
      const ScriptStep(Action.idle, 4000),
    ]).frames;
    for (final f in poses) {
      src.push(f);
      await t.pump(const Duration(milliseconds: 33));
    }
    expect(find.text('Paused'), findsNothing);
    expect(voice.spoken, containsAll(['3', '2', '1']));
    await t.pumpWidget(const SizedBox());
    await t.pump();
  });

  Future<void> pumpSetup(WidgetTester t) async {
    SharedPreferences.setMockInitialValues({
      'settings.v1': jsonEncode(const Settings().toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    src = ReplayPoseSource(const []);
    voice = RecordingVoice();
    final router = GoRouter(
      initialLocation: '/setup',
      routes: [
        GoRoute(path: '/setup', builder: (_, _) => const SetupScreen()),
        GoRoute(
          path: '/calibrate',
          builder: (_, _) => const Scaffold(body: Text('CALIBRATE')),
        ),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          poseSourceProvider.overrideWithValue(src),
          voiceProvider.overrideWithValue(voice),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    final start = find.text('Allow camera and start');
    await t.scrollUntilVisible(
      start,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(start);
    await t.pump();
    await t.pump();
  }

  testWidgets('setup moves on to calibration by itself, no tap needed', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await pumpSetup(t);
    final body = SyntheticBody(noise: 0);
    // Benchmark (3 s) + good hold (1.5 s) → spoken countdown starts.
    var ts = await play(t, src, body, 0, 4700);
    expect(find.text(tr('Starting calibration…')), findsOneWidget);
    expect(voice.spoken, contains('setup_auto'));
    expect(find.text('CALIBRATE'), findsNothing);
    // Three seconds later calibration opens without any tap.
    ts = await play(t, src, body, ts, 3100);
    // Releasing the camera awaits StreamSubscription.cancel(), whose future
    // completes in the root zone: let real microtasks run between pumps.
    for (var i = 0; i < 5; i++) {
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await t.pump();
    }
    await t.pumpAndSettle();
    expect(find.text('CALIBRATE'), findsOneWidget);
  });

  testWidgets('leaving the frame stops the countdown and says which way', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await pumpSetup(t);
    var ts = await play(t, src, SyntheticBody(noise: 0), 0, 4700);
    expect(find.text(tr('Starting calibration…')), findsOneWidget);
    // Drifts off the right edge of the screen = to the player's right.
    ts = await play(t, src, SyntheticBody(noise: 0, centerX: 0.95), ts, 1000);
    expect(find.text(tr('Starting calibration…')), findsNothing);
    expect(voice.spoken, contains('frame_move_left'));
    expect(find.text(S(AppLanguage.en).t('frame_move_left')), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsWidgets);
    await play(t, src, SyntheticBody(noise: 0, centerX: 0.95), ts, 4000);
    expect(find.text('CALIBRATE'), findsNothing);
  });

  testWidgets('a calibration step the player cannot do moves on by itself', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => t.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({
      'settings.v1': jsonEncode(const Settings().toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    src = ReplayPoseSource(const []);
    voice = RecordingVoice();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          poseSourceProvider.overrideWithValue(src),
          voiceProvider.overrideWithValue(voice),
        ],
        child: const MaterialApp(home: CalibrationScreen()),
      ),
    );
    await t.pump();
    await t.pump();
    final body = SyntheticBody(noise: 0);
    var ts = await play(t, src, body, 0, 2400);
    expect(find.text('Raise both arms above your head'), findsOneWidget);
    // Never raises the arms: after 20 s in frame a gentle default is used.
    ts = await play(t, src, body, ts, 19000);
    expect(voice.spoken, isNot(contains('cal_skip')));
    await play(t, src, body, ts, 1500);
    expect(voice.spoken, contains('cal_skip'));
    expect(find.text('Do two comfortable squats'), findsOneWidget);
    expect(find.text('Using a gentle default for this step'), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('FrameView shows a direction cue only when framing is off', (
    t,
  ) async {
    Widget view(FramingAdvice a) => MaterialApp(
      home: Center(
        child: SizedBox(width: 300, child: FrameView(frame: null, advice: a)),
      ),
    );
    await t.pumpWidget(view(const FramingAdvice(FramingFix.ok)));
    expect(find.byType(FramingCue), findsNothing);
    await t.pumpWidget(
      view(const FramingAdvice(FramingFix.moveRight, cut: {FrameEdge.left})),
    );
    await t.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);
  });

  test('every framing line exists in en, hi and gu', () {
    for (final lang in AppLanguage.values) {
      for (final fix in FramingFix.values) {
        final key = framingKey(fix);
        expect(S(lang).t(key), isNot(key), reason: '$key in ${lang.name}');
      }
      for (final key in ['setup_auto', 'cal_skip']) {
        expect(S(lang).t(key), isNot(key));
      }
    }
    final en = S(AppLanguage.en);
    for (final lang in [AppLanguage.hi, AppLanguage.gu]) {
      for (final fix in FramingFix.values) {
        final key = framingKey(fix);
        expect(S(lang).t(key), isNot(en.t(key)), reason: '$key ${lang.name}');
      }
    }
  });

  test('new screen strings are translated', () {
    addTearDown(() => currentLanguage = AppLanguage.en);
    const lines = [
      'Show camera mirror',
      'Starting calibration…',
      'No tap needed. It starts by itself.',
      'Fit your body inside the outline',
      'Using a gentle default for this step',
      'Back in the frame!',
      'The game waits for you.',
    ];
    for (final lang in [AppLanguage.hi, AppLanguage.gu]) {
      currentLanguage = lang;
      for (final l in lines) {
        expect(tr(l), isNot(l), reason: '$l in ${lang.name}');
      }
    }
  });
}
