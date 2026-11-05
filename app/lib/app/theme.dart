import 'package:flutter/material.dart';

/// "Forest Lantern" palette: deep forest night, warm lantern-orange accent
/// (the fox-orange hero) and a teal secondary (the hero's scarf).
///
/// Every pairing below is high contrast so text reads from 2 m away on the
/// floor. Colour is never the only signal: widgets pair it with icons,
/// shapes or text.
abstract final class Lantern {
  static const night = Color(0xFF0B1611); // scaffold background
  static const canopy = Color(0xFF13241C); // panels
  static const moss = Color(0xFF1C3328); // raised panels / inputs
  static const ridge = Color(0xFF2A4A3A); // borders, far silhouettes
  static const glow = Color(0xFFFF9A3C); // lantern orange (primary)
  static const ember = Color(0xFFE0701F); // pressed / deep orange
  static const scarf = Color(0xFF3FD0C0); // teal (secondary)
  static const parchment = Color(0xFFF6EEDC); // main text
  static const fog = Color(0xFFB9C9BF); // secondary text
  static const warning = Color(0xFFFFC857); // amber warnings
  static const danger = Color(0xFFFF6B5A);
  static const onGlow = Color(0xFF231203); // text on orange

  static const radius = 22.0;
  static const chunkyShadow = Color(0xFF050B08);
}

/// High contrast, huge type: the phone is 2 m away on the floor.
/// System fonts only (offline-first, no font downloads), made distinctive
/// with heavy weights and letter spacing.
ThemeData buildTheme({Color seed = Lantern.glow}) {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ).copyWith(
        primary: Lantern.glow,
        onPrimary: Lantern.onGlow,
        primaryContainer: const Color(0xFF5A3210),
        onPrimaryContainer: Lantern.parchment,
        secondary: Lantern.scarf,
        onSecondary: const Color(0xFF032420),
        secondaryContainer: const Color(0xFF0F3E39),
        onSecondaryContainer: Lantern.parchment,
        tertiary: Lantern.warning,
        error: Lantern.danger,
        surface: Lantern.canopy,
        onSurface: Lantern.parchment,
        onSurfaceVariant: Lantern.fog,
        surfaceContainerLowest: Lantern.night,
        surfaceContainerLow: Lantern.canopy,
        surfaceContainer: Lantern.canopy,
        surfaceContainerHigh: Lantern.moss,
        surfaceContainerHighest: Lantern.moss,
        outline: Lantern.ridge,
        outlineVariant: Lantern.ridge,
      );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Lantern.radius),
  );
  const heading = TextStyle(
    fontWeight: FontWeight.w900,
    color: Lantern.parchment,
    letterSpacing: -0.5,
    height: 1.15,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Lantern.night,
    canvasColor: Lantern.night,
    splashFactory: InkRipple.splashFactory,
    textTheme: TextTheme(
      displaySmall: heading.copyWith(fontSize: 44, letterSpacing: -1),
      headlineMedium: heading.copyWith(fontSize: 30),
      titleLarge: heading.copyWith(fontSize: 24, fontWeight: FontWeight.w800),
      titleMedium: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: Lantern.parchment,
      ),
      bodyLarge: const TextStyle(
        fontSize: 19,
        height: 1.45,
        color: Lantern.parchment,
      ),
      bodyMedium: const TextStyle(
        fontSize: 17,
        height: 1.45,
        color: Lantern.parchment,
      ),
      labelLarge: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: Lantern.parchment,
      titleTextStyle: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.2,
        color: Lantern.parchment,
      ),
    ),
    cardTheme: CardThemeData(
      color: Lantern.canopy,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Lantern.radius),
        side: const BorderSide(color: Lantern.ridge, width: 2),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Lantern.glow,
      textColor: Lantern.parchment,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Lantern.onGlow : Lantern.fog,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? Lantern.glow : Lantern.moss,
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Lantern.ridge),
      thumbIcon: WidgetStateProperty.resolveWith(
        (s) => Icon(
          s.contains(WidgetState.selected) ? Icons.check : Icons.close,
          color: s.contains(WidgetState.selected)
              ? Lantern.glow
              : Lantern.night,
        ),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 52)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Lantern.scarf : Lantern.moss,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? const Color(0xFF032420)
              : Lantern.parchment,
        ),
        side: const WidgetStatePropertyAll(
          BorderSide(color: Lantern.ridge, width: 2),
        ),
        shape: WidgetStatePropertyAll(shape),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: Lantern.glow,
      linearTrackColor: Lantern.moss,
      circularTrackColor: Lantern.moss,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Lantern.moss,
      labelStyle: const TextStyle(color: Lantern.fog, fontSize: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Lantern.ridge, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Lantern.ridge, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Lantern.glow, width: 3),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Lantern.ridge, thickness: 2),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Lantern.moss,
      contentTextStyle: const TextStyle(
        color: Lantern.parchment,
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      behavior: SnackBarBehavior.floating,
      shape: shape,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Lantern.canopy,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
  );
}
