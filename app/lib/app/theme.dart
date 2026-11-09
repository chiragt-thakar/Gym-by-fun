import 'package:flutter/material.dart';

/// "Forest Lantern" palette: deep forest night, warm lantern-orange accent
/// (the fox-orange hero) and a teal secondary (the hero's scarf).
///
/// Every pairing below is high contrast. Colour is never the only signal:
/// widgets pair it with icons, shapes or text.
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

  /// Hairline borders and dividers on panels.
  static const line = Color(0xFF223B2F);

  /// Slightly raised surface for cards inside panels.
  static const surface2 = Color(0xFF172C22);

  /// Tertiary text (captions, timestamps).
  static const mist = Color(0xFF8DA397);

  static const radius = 20.0;
  static const chunkyShadow = Color(0xFF050B08);
}

/// Spacing scale: every gap in the shell comes from here.
abstract final class Space {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Side gutter for every scrolling page.
  static const gutter = 20.0;
}

/// Text styles for the shell (hand-held screens). In-game HUD text is much
/// larger and lives with the game renderers.
abstract final class Txt {
  static const overline = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.4,
    color: Lantern.scarf,
  );
  static const caption = TextStyle(
    fontSize: 13,
    color: Lantern.mist,
    height: 1.35,
  );
  static const numeral = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: Lantern.parchment,
    fontFeatures: [FontFeature.tabularFigures()],
    height: 1.1,
  );
}

/// [fontFamily] is only for headless previews; the app uses the system font.
ThemeData buildTheme({Color seed = Lantern.glow, String? fontFamily}) {
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
        outlineVariant: Lantern.line,
      );
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(Lantern.radius),
  );
  const heading = TextStyle(
    fontWeight: FontWeight.w800,
    color: Lantern.parchment,
    letterSpacing: -0.3,
    height: 1.2,
  );
  final f = fontFamily;
  return ThemeData(
    fontFamily: f,
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Lantern.night,
    canvasColor: Lantern.night,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.standard,
    textTheme: TextTheme(
      displaySmall: heading.copyWith(fontSize: 32, letterSpacing: -0.8),
      headlineMedium: heading.copyWith(fontSize: 26, letterSpacing: -0.5),
      headlineSmall: heading.copyWith(fontSize: 22),
      titleLarge: heading.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
      titleMedium: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Lantern.parchment,
        height: 1.3,
      ),
      titleSmall: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Lantern.parchment,
      ),
      bodyLarge: const TextStyle(
        fontSize: 16,
        height: 1.5,
        color: Lantern.parchment,
      ),
      bodyMedium: const TextStyle(
        fontSize: 15,
        height: 1.45,
        color: Lantern.parchment,
      ),
      bodySmall: const TextStyle(fontSize: 13, height: 1.4, color: Lantern.fog),
      labelLarge: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
      ),
      labelMedium: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Lantern.night,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: Lantern.parchment,
      titleSpacing: 4,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
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
        side: const BorderSide(color: Lantern.line, width: 1),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Lantern.canopy,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: Lantern.glow.withValues(alpha: 0.18),
      indicatorShape: const StadiumBorder(),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 24,
          color: s.contains(WidgetState.selected) ? Lantern.glow : Lantern.mist,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w800
              : FontWeight.w600,
          color: s.contains(WidgetState.selected)
              ? Lantern.parchment
              : Lantern.mist,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 54),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          fontFamily: f,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 50),
        foregroundColor: Lantern.parchment,
        side: const BorderSide(color: Lantern.ridge, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          fontFamily: f,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Lantern.scarf,
        textStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFamily: f,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      secondaryLabelStyle: TextStyle(fontFamily: f),
      backgroundColor: Lantern.surface2,
      selectedColor: Lantern.glow.withValues(alpha: 0.2),
      side: const BorderSide(color: Lantern.line),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Lantern.parchment,
        fontFamily: f,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      showCheckmark: false,
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: Lantern.glow,
      textColor: Lantern.parchment,
      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      titleTextStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Lantern.parchment,
      ),
      subtitleTextStyle: TextStyle(
        fontSize: 13,
        color: Lantern.fog,
        height: 1.35,
      ),
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
        minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
        textStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 14, fontWeight: FontWeight.w800, fontFamily: f),
        ),
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Lantern.scarf
              : Lantern.surface2,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? const Color(0xFF032420)
              : Lantern.parchment,
        ),
        side: const WidgetStatePropertyAll(
          BorderSide(color: Lantern.ridge, width: 1),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
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
      labelStyle: const TextStyle(color: Lantern.fog, fontSize: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Lantern.ridge, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Lantern.ridge, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Lantern.glow, width: 2),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Lantern.line, thickness: 1),
    expansionTileTheme: const ExpansionTileThemeData(
      shape: Border(),
      collapsedShape: Border(),
      iconColor: Lantern.fog,
      collapsedIconColor: Lantern.fog,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Lantern.canopy,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: Lantern.ridge,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Lantern.moss,
      contentTextStyle: const TextStyle(
        color: Lantern.parchment,
        fontSize: 15,
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
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {TargetPlatform.android: FadeForwardsPageTransitionsBuilder()},
    ),
  );
}
