import 'package:flutter/material.dart';

/// Joynetic design tokens. See docs/design.md.
///
/// **Ink & Volt**: a near-black, slightly cool ink; one high-energy colour
/// (volt, a yellow-green) for the single most important action on a screen;
/// one calm colour (aqua) that always and only means "the tracker sees
/// you". Amber warns, coral is for errors. Nothing else carries meaning.
///
/// Every text/background pairing below is at least 7:1, because the screen
/// is read from two metres away. Colour is never the only signal: widgets
/// pair it with an icon, a shape or words.
abstract final class Jn {
  // Surfaces, darkest first.
  static const ink = Color(0xFF0A0C10); // page background
  static const panel = Color(0xFF12151B); // cards, sheets, bars
  static const raised = Color(0xFF1A1E26); // inputs, raised panels
  static const inset = Color(0xFF161A21); // cards inside panels
  static const line = Color(0xFF242A35); // hairlines, dividers
  static const edge = Color(0xFF343C4A); // stronger borders
  static const scrim = Color(0xE605070A); // over the game / the camera

  // Brand.
  static const volt = Color(0xFFC8F542); // primary action
  static const voltDeep = Color(0xFFA6D62B); // pressed
  static const onVolt = Color(0xFF0E1200);
  static const aqua = Color(0xFF5EE6D0); // tracking, success, links
  static const onAqua = Color(0xFF03231F);

  /// Depth: a cool violet used only in gradients and glows, never for
  /// meaning.
  static const violet = Color(0xFF8B7CFF);

  /// The brand gradient (the logo tile, the primary button, hero accents).
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [volt, aqua],
  );

  /// The primary button: volt, warming a little towards the top left.
  static const action = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFD8FF5E), volt, Color(0xFFA9E63A)],
    stops: [0, 0.45, 1],
  );

  /// Cards: lit from above, so a panel reads as a raised surface.
  static const surface = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF181C24), Color(0xFF101319)],
  );

  /// The shadow under a raised card.
  static const cardShadow = [
    BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 8)),
  ];

  // Text.
  static const text = Color(0xFFF3F5F7);
  static const textDim = Color(0xFFAEB6C2);
  static const textFaint = Color(0xFF7C8594);

  // Status.
  static const warning = Color(0xFFFFC857);
  static const danger = Color(0xFFFF6B5A);

  /// Corner radii: controls 16, cards 24, pills fully round.
  static const radiusControl = 16.0;
  static const radiusCard = 24.0;
}

/// Motion: three durations, two curves. Decorative motion is skipped when
/// the system asks for reduced motion (`MediaQuery.disableAnimations`).
abstract final class Motion {
  /// Press feedback, toggles.
  static const quick = Duration(milliseconds: 120);

  /// Things that change state in place (a step finishing, a chip).
  static const standard = Duration(milliseconds: 250);

  /// Things that move across the screen (the frame finder growing).
  static const slow = Duration(milliseconds: 380);

  static const enter = Curves.easeOutCubic;
  static const pop = Curves.easeOutBack;
}

/// The token names the screens were written with, kept so every existing
/// widget picks up the Joynetic palette. New code uses [Jn].
abstract final class Lantern {
  static const night = Jn.ink; // scaffold background
  static const canopy = Jn.panel; // panels
  static const moss = Jn.raised; // raised panels / inputs
  static const ridge = Jn.edge; // borders
  static const glow = Jn.volt; // primary
  static const ember = Jn.voltDeep; // pressed primary
  static const scarf = Jn.aqua; // secondary
  static const parchment = Jn.text; // main text
  static const fog = Jn.textDim; // secondary text
  static const warning = Jn.warning;
  static const danger = Jn.danger;
  static const onGlow = Jn.onVolt; // text on the primary colour

  /// Hairline borders and dividers on panels.
  static const line = Jn.line;

  /// Slightly raised surface for cards inside panels.
  static const surface2 = Jn.inset;

  /// Tertiary text (captions, timestamps).
  static const mist = Jn.textFaint;

  static const radius = Jn.radiusCard;
  static const chunkyShadow = Color(0xFF05070A);
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

/// Text styles beyond the theme's text theme.
///
/// Two scales: **hand** (the phone is in the hand: 12–32 sp) and **stage**
/// (the player stands two metres away: 20 sp and up, heavy weights, at most
/// two lines).
abstract final class Txt {
  static const overline = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.6,
    color: Jn.aqua,
  );
  static const caption = TextStyle(
    fontSize: 13,
    color: Jn.textFaint,
    height: 1.35,
  );
  static const numeral = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: Jn.text,
    fontFeatures: [FontFeature.tabularFigures()],
    height: 1.1,
  );

  /// Stage scale: the one line a player must read from across the room.
  static const stage = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.4,
    height: 1.15,
    color: Jn.text,
  );

  /// Stage scale: supporting line under [stage].
  static const stageSub = TextStyle(fontSize: 20, height: 1.3, color: Jn.textDim);

  /// Stage scale: a countdown or a score.
  static const stageNumeral = TextStyle(
    fontSize: 96,
    fontWeight: FontWeight.w900,
    letterSpacing: -3,
    height: 1,
    color: Jn.text,
    fontFeatures: [FontFeature.tabularFigures()],
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
        primaryContainer: const Color(0xFF2C3A0E),
        onPrimaryContainer: Lantern.parchment,
        secondary: Lantern.scarf,
        onSecondary: Jn.onAqua,
        secondaryContainer: const Color(0xFF103A35),
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
    letterSpacing: -0.4,
    height: 1.15,
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
      displaySmall: heading.copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w900,
        letterSpacing: -1.1,
      ),
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
      height: 72,
      indicatorColor: Lantern.glow.withValues(alpha: 0.16),
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
        minimumSize: const Size(0, 56),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: const StadiumBorder(),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
          fontFamily: f,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        foregroundColor: Lantern.parchment,
        side: const BorderSide(color: Lantern.ridge, width: 1.5),
        shape: const StadiumBorder(),
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
      // Selected: solid volt with ink text, so the choice is unmistakable.
      secondaryLabelStyle: TextStyle(
        fontFamily: f,
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: Lantern.onGlow,
      ),
      backgroundColor: Lantern.surface2,
      selectedColor: Lantern.glow,
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
              ? Lantern.parchment
              : Lantern.surface2,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? Lantern.night
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
