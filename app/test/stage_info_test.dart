import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joynetic/game/stage_info.dart';
import 'package:joynetic/game/stages.dart';
import 'package:joynetic/screens/stage_info_sheet.dart';
import 'package:joynetic/services/premium.dart';
import 'package:joynetic/services/settings.dart';
import 'package:joynetic/widgets/body_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpSheet(
  WidgetTester t,
  Stage stage, {
  bool paymentsEnabled = false,
  bool premium = false,
  VoidCallback? onPlay,
}) async {
  await t.pumpWidget(const SizedBox());
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  t.view.physicalSize = const Size(1080, 2400);
  t.view.devicePixelRatio = 2.6;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        premiumProvider.overrideWith(
          (_) async => PremiumState(premium: premium),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: StageInfoSheet(
            stage: stage,
            onPlay: onPlay ?? () {},
            paymentsEnabled: paymentsEnabled,
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  test('every stage has info with a primary region and a reference', () {
    for (final st in stages) {
      final info = stageInfos[st.levelId];
      expect(info, isNotNull, reason: st.levelId);
      expect(info!.primary, isNotEmpty, reason: st.levelId);
      expect(info.references, isNotEmpty, reason: st.levelId);
      expect(info.benefits.length, inInclusiveRange(2, 3), reason: st.levelId);
      expect(info.movements, isNotEmpty, reason: st.levelId);
      for (final r in info.secondary) {
        expect(info.primary, isNot(contains(r)), reason: st.levelId);
      }
    }
    expect(stageInfos.length, stages.length);
  });

  test('World 1 is free; later worlds are premium', () {
    for (final st in stages) {
      expect(
        infoFor(st).tier,
        st.world == 1 ? StageTier.free : StageTier.premium,
        reason: st.levelId,
      );
    }
  });

  test('benefit text makes no medical or weight-loss claims', () {
    final banned = RegExp(
      r'cure|treat|prevent|weight loss|lose weight|diagnos|burn fat',
      caseSensitive: false,
    );
    for (final info in stageInfos.values) {
      for (final b in info.benefits) {
        expect(banned.hasMatch(b), isFalse, reason: b);
      }
    }
    expect(banned.hasMatch(stageInfoDisclaimer), isFalse);
  });

  test('body map paints all three styles with every region', () {
    for (final style in BodyStyle.values) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      BodyMapPainter(
        style: style,
        primary: BodyRegion.values.take(5).toList(),
        secondary: BodyRegion.values.skip(5).toList(),
      ).paint(canvas, const Size(130, 260));
      recorder.endRecording().dispose();
    }
    const a = BodyMapPainter(
      style: BodyStyle.neutral,
      primary: [BodyRegion.quads],
      secondary: [],
    );
    expect(
      a.shouldRepaint(
        const BodyMapPainter(
          style: BodyStyle.neutral,
          primary: [BodyRegion.quads],
          secondary: [],
        ),
      ),
      isFalse,
    );
    expect(
      a.shouldRepaint(
        const BodyMapPainter(
          style: BodyStyle.male,
          primary: [BodyRegion.quads],
          secondary: [],
        ),
      ),
      isTrue,
    );
  });

  test('bodyStyle round-trips and defaults to neutral', () {
    const s = Settings(bodyStyle: BodyStyle.female);
    expect(Settings.fromJson(s.toJson()).bodyStyle, BodyStyle.female);
    final old = const Settings().toJson()..remove('bodyStyle');
    expect(Settings.fromJson(old).bodyStyle, BodyStyle.neutral);
    expect(
      Settings.fromJson({'bodyStyle': 'nonsense'}).bodyStyle,
      BodyStyle.neutral,
    );
  });

  testWidgets('sheet shows info, disclaimer and a playable Play button', (
    t,
  ) async {
    var played = 0;
    await pumpSheet(t, stages.first, onPlay: () => played++);
    expect(find.text('Forest Escape'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.byType(BodyMap), findsOneWidget);
    expect(find.text('Trains'), findsOneWidget);
    await t.scrollUntilVisible(find.text(stageInfoDisclaimer), 200);
    expect(find.text(stageInfoDisclaimer), findsOneWidget);
    expect(find.textContaining('WHO Guidelines'), findsOneWidget);
    await t.scrollUntilVisible(find.byKey(const ValueKey('stage-play')), 200);
    await t.tap(find.byKey(const ValueKey('stage-play')));
    expect(played, 1);
  });

  testWidgets('premium stage is playable while payments are off', (t) async {
    await pumpSheet(t, stages.last);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-play')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-locked')), findsNothing);
  });

  testWidgets('premium stage locks only with payments on and no Premium', (
    t,
  ) async {
    await pumpSheet(t, stages.last, paymentsEnabled: true);
    expect(find.byKey(const ValueKey('stage-locked')), findsOneWidget);
    expect(find.byKey(const ValueKey('stage-play')), findsNothing);

    await pumpSheet(t, stages.last, paymentsEnabled: true, premium: true);
    expect(find.byKey(const ValueKey('stage-play')), findsOneWidget);

    await pumpSheet(t, stages.first, paymentsEnabled: true);
    expect(find.byKey(const ValueKey('stage-play')), findsOneWidget);
  });
}
