import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:joynetic/screens/settings_screen.dart';
import 'package:joynetic/services/api_client.dart';
import 'package:joynetic/services/coach_service.dart';
import 'package:joynetic/services/local_data.dart';
import 'package:joynetic/services/settings.dart';
import 'package:joynetic/game/forest_game.dart';
import 'package:joynetic/services/session_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _EmptyQueue extends SessionQueue {
  _EmptyQueue(super.api);
  bool cleared = false;
  @override
  Future<List<Map<String, Object?>>> pending() async => [];
  @override
  Future<void> clear() async {
    cleared = true;
  }
}

void main() {
  test(
    'explorer and optional mission stars persist, older settings stay valid',
    () {
      for (final look in HeroLook.values) {
        final original = Settings(
          heroLook: look,
          missionLevels: {'w1-forest-escape'},
        );
        final saved = Settings.fromJson(
          jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
        );
        expect(saved.heroLook, look);
        expect(saved.missionLevels, original.missionLevels);
      }
      expect(Settings.fromJson({}).heroLook, HeroLook.fox);
      expect(Settings.fromJson({'heroLook': 'future'}).heroLook, HeroLook.fox);
      expect(Settings.fromJson({}).missionLevels, isEmpty);
    },
  );
  group('age band', () {
    test('defaults to gentle with a 1.2 warning multiplier', () {
      const s = Settings();
      expect(s.ageBand, AgeBand.gentle);
      expect(s.warningMultiplier, 1.2);
      expect(s.copyWith(ageBand: AgeBand.balanced).warningMultiplier, 1.0);
      expect(s.copyWith(ageBand: AgeBand.active).warningMultiplier, 1.0);
    });

    test('round-trips through JSON', () {
      for (final b in AgeBand.values) {
        final s = const Settings().copyWith(ageBand: b);
        final back = Settings.fromJson(
          jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
        );
        expect(back.ageBand, b);
      }
    });

    test('old settings without ageBand load as gentle', () {
      final j = const Settings().toJson()..remove('ageBand');
      expect(Settings.fromJson(j).ageBand, AgeBand.gentle);
      expect(
        Settings.fromJson({'ageBand': 'nonsense'}).ageBand,
        AgeBand.gentle,
      );
    });

    test('picking a band applies safe defaults', () {
      const base = Settings(lowImpact: false, assist: false);
      final g = base.withAgeBand(AgeBand.gentle);
      expect(g.lowImpact, isTrue);
      expect(g.assist, isTrue);
      final b = g.withAgeBand(AgeBand.balanced);
      expect(b.lowImpact, isTrue);
      expect(b.assist, isTrue);
      final a = g.withAgeBand(AgeBand.active);
      expect(a.assist, isFalse);
      expect(a.lowImpact, isTrue, reason: 'jumps stay opt-in');
    });
  });

  group('wipeLocalData', () {
    test(
      'removes settings, tokens, coach history, gym code and queue',
      () async {
        SharedPreferences.setMockInitialValues({
          'settings.v1': '{}',
          'auth.access': 'a',
          'auth.refresh': 'r',
          CoachHistoryNotifier.key: '[]',
          'pendingGymCode': 'ABC',
          'unrelated': 1,
        });
        final prefs = await SharedPreferences.getInstance();
        final dir = await Directory.systemTemp.createTemp('mq_wipe');
        addTearDown(() => dir.delete(recursive: true));
        final queue = File('${dir.path}/session_queue.json')
          ..writeAsStringSync('[]');

        await wipeLocalData(prefs, dir: () async => dir);

        for (final k in localDataKeys) {
          expect(prefs.containsKey(k), isFalse, reason: k);
        }
        expect(TokenStore(prefs).hasSession, isFalse);
        expect(queue.existsSync(), isFalse);
        expect(prefs.getInt('unrelated'), 1);
      },
    );

    test('tolerates a missing queue file and directory', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await wipeLocalData(
        prefs,
        dir: () async => Directory('${Directory.systemTemp.path}/mq_missing'),
      );
      await wipeLocalData(prefs, dir: () async => throw StateError('no dir'));
    });
  });

  group('settings screen', () {
    Future<ProviderContainer> pump(
      WidgetTester t,
      Map<String, Object> values,
    ) async {
      SharedPreferences.setMockInitialValues(values);
      final prefs = await SharedPreferences.getInstance();
      t.view.physicalSize = const Size(1080, 2400);
      t.view.devicePixelRatio = 2.6;
      addTearDown(t.view.reset);
      final c = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          sessionQueueProvider.overrideWithValue(
            _EmptyQueue(ApiClient(TokenStore(prefs))),
          ),
        ],
      );
      addTearDown(c.dispose);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await t.pumpAndSettle();
      return c;
    }

    testWidgets('shows the play style picker and changes the band', (t) async {
      final c = await pump(t, {});
      expect(find.text('Play style'), findsOneWidget);
      expect(find.text('You choose; we never ask your age.'), findsOneWidget);
      expect(find.byKey(const ValueKey('age-band')), findsOneWidget);
      expect(find.byKey(const ValueKey('sign-out')), findsNothing);
      await t.ensureVisible(find.text('Active'));
      await t.pumpAndSettle();
      await t.tap(find.text('Active'));
      await t.pumpAndSettle();
      expect(c.read(settingsProvider).ageBand, AgeBand.active);
      expect(c.read(settingsProvider).assist, isFalse);
    });

    testWidgets('sign out clears tokens and keeps progress', (t) async {
      final c = await pump(t, {
        'settings.v1': jsonEncode(
          const Settings(signedIn: true, completedLevels: {'w1-l1'}).toJson(),
        ),
        'auth.access': 'a',
        'auth.refresh': 'r',
      });
      final button = find.byKey(const ValueKey('sign-out'));
      await t.scrollUntilVisible(
        button,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.pumpAndSettle();
      await t.tap(button);
      await t.pumpAndSettle();
      final s = c.read(settingsProvider);
      expect(s.signedIn, isFalse);
      expect(s.completedLevels, {'w1-l1'});
      expect(c.read(tokenStoreProvider).hasSession, isFalse);
    });
  });
}
