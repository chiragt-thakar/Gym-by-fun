import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'services/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait first: the whole body fits a phone propped up in portrait.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const JoyneticApp(),
    ),
  );
}

class JoyneticApp extends ConsumerWidget {
  const JoyneticApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild everything when the language changes.
    ref.watch(settingsProvider.select((s) => s.language));
    return MaterialApp.router(
      title: 'Joynetic',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
