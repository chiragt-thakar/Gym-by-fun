import 'package:flutter/material.dart';

/// High contrast, huge type: the phone is 2 m away on the floor.
ThemeData buildTheme({Color seed = const Color(0xFF1FB5A8)}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF0E1A14),
    textTheme: const TextTheme(
      displaySmall: TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
      headlineMedium: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
      titleLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      bodyLarge: TextStyle(fontSize: 19, height: 1.4),
      bodyMedium: TextStyle(fontSize: 17, height: 1.4),
    ),
  );
}
