import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:joynetic/app/router.dart';
import 'package:joynetic/screens/get_ready_screen.dart';
import 'package:joynetic/screens/setup_screen.dart';
import 'package:joynetic/services/pose_service.dart';
import 'package:joynetic/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

/// Explore first, calibrate at play: browsing needs no calibration, a run
/// goes through get-ready → setup → calibrate and then opens the run tapped.
void main() {
  late GoRouter router;

  Future<void> pump(
    WidgetTester t,
    String initial, {
    Settings? settings,
  }) async {
    await t.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final s =
        settings ?? const Settings(ageConfirmed: true, readinessDone: true);
    SharedPreferences.setMockInitialValues({
      'settings.v1': jsonEncode(s.toJson()),
    });
    final prefs = await SharedPreferences.getInstance();
    String stub(String name, GoRouterState st) => '$name ${st.uri}';
    router = GoRouter(
      initialLocation: initial,
      redirect: (_, st) => playGate(s, st.uri),
      routes: [
        GoRoute(
          path: '/home',
          builder: (_, st) => Scaffold(body: Text(stub('HOME', st))),
        ),
        GoRoute(
          path: '/quest',
          builder: (_, st) => Scaffold(body: Text(stub('QUEST', st))),
        ),
        GoRoute(
          path: '/calibrate',
          builder: (_, st) => Scaffold(body: Text(stub('CALIBRATE', st))),
        ),
        GoRoute(
          path: '/get-ready',
          builder: (_, st) =>
              GetReadyScreen(next: safeNext(st.uri.queryParameters['next'])),
        ),
        GoRoute(
          path: '/setup',
          builder: (_, st) =>
              SetupScreen(next: safeNext(st.uri.queryParameters['next'])),
        ),
      ],
    );
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          poseSourceProvider.overrideWithValue(ReplayPoseSource(const [])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> tapScrolled(WidgetTester t, Finder f) async {
    await t.scrollUntilVisible(
      f,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pumpAndSettle();
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets('play without calibration opens get-ready for that stage', (
    t,
  ) async {
    await pump(t, '/quest?level=w1-forest-escape');
    expect(find.byType(GetReadyScreen), findsOneWidget);
    expect(find.text('Forest Escape'), findsOneWidget);

    await tapScrolled(t, find.byKey(const ValueKey('get-ready-start')));
    expect(find.byType(SetupScreen), findsOneWidget);
    expect(
      Uri.parse(router.routerDelegate.currentConfiguration.uri.toString())
          .queryParameters['next'],
      '/quest?level=w1-forest-escape',
    );
    // On the way to a run there is no skip: the player asked to play.
    expect(find.byKey(const ValueKey('skip-setup')), findsNothing);
  });

  testWidgets('setup already done goes straight to calibration', (t) async {
    await pump(
      t,
      '/quest?level=w1-forest-escape',
      settings: const Settings(
        ageConfirmed: true,
        readinessDone: true,
        setupDone: true,
      ),
    );
    await tapScrolled(t, find.byKey(const ValueKey('get-ready-start')));
    expect(
      find.text(
        'CALIBRATE /calibrate?next=%2Fquest%3Flevel%3Dw1-forest-escape',
      ),
      findsOneWidget,
    );
  });

  testWidgets('"not now" returns to exploring', (t) async {
    await pump(t, '/home');
    router.push('/quest?level=w1-forest-escape');
    await t.pumpAndSettle();
    expect(find.byType(GetReadyScreen), findsOneWidget);
    await tapScrolled(t, find.byKey(const ValueKey('get-ready-later')));
    expect(find.text('HOME /home'), findsOneWidget);
  });

  testWidgets('first-time setup can be skipped to explore the app', (t) async {
    await pump(t, '/setup');
    await tapScrolled(t, find.byKey(const ValueKey('skip-setup')));
    expect(find.text('HOME /home'), findsOneWidget);
  });

  testWidgets('a calibrated player plays straight away', (t) async {
    await pump(
      t,
      '/quest?level=w1-forest-escape',
      settings: Settings(
        ageConfirmed: true,
        readinessDone: true,
        setupDone: true,
        calibration: CalibrationProfile.fromStanding(
          PoseFrame(timestampMs: 0, landmarks: SyntheticBody(noise: 0).pose()),
        ),
      ),
    );
    expect(find.text('QUEST /quest?level=w1-forest-escape'), findsOneWidget);
  });
}
