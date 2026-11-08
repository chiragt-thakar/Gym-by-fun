import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:motionquest/l10n/strings.dart';
import 'package:motionquest/l10n/tr.dart';
import 'package:motionquest/screens/calibration_screen.dart';
import 'package:motionquest/screens/setup_screen.dart';
import 'package:motionquest/services/pose_service.dart';
import 'package:motionquest/services/settings.dart';
import 'package:motionquest/services/voice.dart';
import 'package:motionquest/widgets/frame_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

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
