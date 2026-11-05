import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/calibration_screen.dart';
import '../screens/crew_screen.dart';
import '../screens/debug_screen.dart';
import '../screens/home_screen.dart';
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
  '/tutorial',
};

/// Where a player who hasn't finished onboarding must go next.
String? nextOnboardingStep(Settings s) {
  if (!s.ageConfirmed) return '/welcome';
  if (!s.readinessDone) return '/readiness';
  if (!s.setupDone) return '/setup';
  if (s.calibration == null) return '/calibrate';
  if (!s.tutorialDone) return '/tutorial';
  return null;
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
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
      return nextOnboardingStep(s);
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
      GoRoute(path: '/age', builder: (_, _) => const AgeGateScreen()),
      GoRoute(path: '/readiness', builder: (_, _) => const ReadinessScreen()),
      GoRoute(path: '/sign-in', builder: (_, _) => const SignInScreen()),
      GoRoute(path: '/setup', builder: (_, _) => const SetupScreen()),
      GoRoute(path: '/calibrate', builder: (_, _) => const CalibrationScreen()),
      GoRoute(
        path: '/tutorial',
        builder: (_, _) => const QuestScreen(tutorial: true),
      ),
      GoRoute(path: '/join', redirect: (_, _) => '/home'),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/quest', builder: (_, _) => const QuestScreen()),
      GoRoute(
        path: '/results',
        builder: (_, st) => ResultsScreen(data: st.extra as ResultsData?),
      ),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/crew', builder: (_, _) => const CrewScreen()),
      GoRoute(path: '/debug', builder: (_, _) => const DebugScreen()),
      GoRoute(path: '/recorder', builder: (_, _) => const RecorderScreen()),
    ],
  );
});
