import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../arcade/arcade_results_screen.dart';
import '../arcade/arcade_screen.dart';

import '../screens/calibration_screen.dart';
import '../screens/crew_screen.dart';
import '../screens/get_ready_screen.dart';
import '../screens/debug_screen.dart';
import '../screens/game_detail_screen.dart';
import '../screens/games_screen.dart';
import '../screens/home_screen.dart';
import '../screens/main_shell.dart';
import '../screens/profile_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/onboarding_screens.dart';
import '../screens/quest_screen.dart';
import '../screens/recorder_screen.dart';
import '../screens/results_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/setup_screen.dart';
import '../screens/sign_in_screen.dart';
import '../services/settings.dart';

const pendingGymCodeKey = 'pendingGymCode';

const _onboarding = {
  '/welcome',
  '/age',
  '/readiness',
  '/sign-in',
  '/setup',
  '/calibrate',
  '/get-ready',
};

/// Where a player who hasn't finished onboarding must go next. Only the
/// safety steps (18+ and the readiness check) are required: body setup and
/// calibration are offered once, can be skipped, and are asked for again
/// only when the player taps play (see [playGate]).
String? nextOnboardingStep(Settings s) {
  if (!s.ageConfirmed) return '/welcome';
  if (!s.readinessDone) return '/readiness';
  return null;
}

/// A run needs the player's own movement range. Starting one without a
/// calibration goes to the get-ready page first and comes back afterwards.
bool isPlayRoute(String path) =>
    path == '/quest' || path == '/tutorial' || path.startsWith('/play/');

String? playGate(Settings s, Uri uri) {
  if (s.calibration != null) return null;
  if (!isPlayRoute(uri.path)) return null;
  return Uri(
    path: '/get-ready',
    queryParameters: {'next': uri.toString()},
  ).toString();
}

/// Only in-app play routes may be a `next` target after body setup.
String? safeNext(String? next) {
  if (next == null) return null;
  final uri = Uri.tryParse(next);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  return isPlayRoute(uri.path) ? next : null;
}

/// Appends `?next=` to an internal route when a play target is waiting.
String withNext(String path, String? next) => next == null
    ? path
    : Uri(path: path, queryParameters: {'next': next}).toString();

/// Pages that can be opened directly (with `go`) get a back action that
/// never leaves the app: back returns to the previous page, or Home.
class BackToHome extends StatelessWidget {
  const BackToHome({super.key, required this.child, this.fallback = '/home'});
  final Widget child;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    return PopScope(
      canPop: router.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) router.go(fallback);
      },
      child: child,
    );
  }
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  Widget back(Widget child, [String fallback = '/home']) =>
      BackToHome(fallback: fallback, child: child);
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    redirect: (context, state) {
      final s = ref.read(settingsProvider);
      final path = state.uri.path;
      // Gym QR poster deep link: motionquest://join?code=… Remember the code
      // (onboarding may come first), then continue to the crew screen.
      if (path == '/join') {
        final code = state.uri.queryParameters['code'];
        if (code != null &&
            RegExp(r'^[A-Za-z]{1,4}-[A-Za-z0-9]{6}$').hasMatch(code)) {
          ref
              .read(sharedPrefsProvider)
              .setString(pendingGymCodeKey, code.toUpperCase());
        }
        return nextOnboardingStep(s) ?? (s.signedIn ? '/crew' : '/sign-in');
      }
      if (_onboarding.contains(path) ||
          path == '/debug' ||
          path == '/recorder') {
        return null;
      }
      return nextOnboardingStep(s) ?? playGate(s, state.uri);
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(
        path: '/age',
        builder: (_, _) => back(const AgeGateScreen(), '/welcome'),
      ),
      GoRoute(
        path: '/readiness',
        builder: (_, _) => back(const ReadinessScreen(), '/age'),
      ),
      GoRoute(path: '/sign-in', builder: (_, _) => back(const SignInScreen())),
      GoRoute(
        path: '/setup',
        builder: (_, st) =>
            back(SetupScreen(next: safeNext(st.uri.queryParameters['next']))),
      ),
      GoRoute(
        path: '/calibrate',
        builder: (_, st) => back(
          CalibrationScreen(
            next: safeNext(st.uri.queryParameters['next']),
            quick: st.uri.queryParameters['quick'] == '1',
          ),
        ),
      ),
      GoRoute(
        path: '/get-ready',
        builder: (_, st) => back(
          GetReadyScreen(next: safeNext(st.uri.queryParameters['next'])),
        ),
      ),
      GoRoute(
        path: '/tutorial',
        builder: (_, _) => const QuestScreen(tutorial: true),
      ),
      GoRoute(path: '/join', redirect: (_, _) => '/home'),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/games', builder: (_, _) => const GamesScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (_, _) => const ProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/game/:id',
        builder: (_, st) =>
            back(GameDetailScreen(gameId: st.pathParameters['id']!), '/games'),
      ),
      GoRoute(
        path: '/play/:game',
        builder: (_, st) => ArcadeScreen(
          key: ValueKey(st.uri.toString()),
          args: ArcadeArgs.fromUri(st.pathParameters['game']!, st.uri),
        ),
      ),
      GoRoute(
        path: '/arcade-results',
        builder: (_, st) =>
            ArcadeResultsScreen(result: st.extra as ArcadeResult?),
      ),
      GoRoute(
        path: '/quest',
        builder: (_, st) => QuestScreen(
          levelId: st.uri.queryParameters['level'],
          gentle: st.uri.queryParameters['pace'] == 'gentle',
        ),
      ),
      GoRoute(
        path: '/results',
        builder: (_, st) => back(ResultsScreen(data: st.extra as ResultsData?)),
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => back(const SettingsScreen(), '/profile'),
      ),
      GoRoute(
        path: '/crew',
        builder: (_, _) => back(const CrewScreen(), '/profile'),
      ),
      GoRoute(
        path: '/debug',
        builder: (_, _) => back(const DebugScreen(), '/profile'),
      ),
      GoRoute(
        path: '/recorder',
        builder: (_, _) => back(const RecorderScreen(), '/profile'),
      ),
    ],
  );
});
