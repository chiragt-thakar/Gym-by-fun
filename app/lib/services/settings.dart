import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../l10n/tr.dart';

enum DeviceTier { upperMid, mid, budget }

/// How the body diagram is drawn. Chosen by the player; never inferred.
enum BodyStyle { neutral, female, male }

/// Play style (age band). The player picks it; we never ask or infer age.
enum AgeBand { gentle, balanced, active }

/// Everything the player chooses, kept on the device.
class Settings {
  const Settings({
    this.language = AppLanguage.en,
    this.difficulty = Difficulty.beginner,
    this.lowImpact = true,
    this.assist = false,
    this.ageConfirmed = false,
    this.readinessDone = false,
    this.setupDone = false,
    this.tutorialDone = false,
    this.signedIn = false,
    this.calibration,
    this.deviceTier,
    this.seenTypes = const {},
    this.sessionsPlayed = 0,
    this.completedLevels = const {},
    this.bodyStyle = BodyStyle.neutral,
    this.ageBand = AgeBand.gentle,
    this.cameraMirror = true,
  });

  final AppLanguage language;
  final Difficulty difficulty;

  /// Low-impact by default: half squats count, one arm is enough, no jumps.
  final bool lowImpact;
  final bool assist;
  final bool ageConfirmed;

  /// The readiness check was shown. Its answers are never stored.
  final bool readinessDone;
  final bool setupDone;
  final bool tutorialDone;
  final bool signedIn;
  final CalibrationProfile? calibration;
  final DeviceTier? deviceTier;
  final Set<EncounterType> seenTypes;
  final int sessionsPlayed;

  /// Level ids the player has finished at least once (unlocks the next stage).
  final Set<String> completedLevels;

  /// Body diagram style on stage info. The player picks it in Settings.
  final BodyStyle bodyStyle;

  /// Play style. Gentle by default; the player can change it in Settings.
  final AgeBand ageBand;

  /// Show the live camera mirror while framing (setup, calibration, the
  /// in-game frame guide). Drawn natively, never saved. Off = body outline
  /// only, and the camera preview is never bound.
  final bool cameraMirror;

  /// Extra warning time for the band (for future director use).
  double get warningMultiplier => ageBand == AgeBand.gentle ? 1.2 : 1.0;

  /// Picks a play style and applies its safe defaults: Gentle turns on
  /// low-impact and assist; Active turns assist off; Balanced keeps both.
  Settings withAgeBand(AgeBand band) => copyWith(
    ageBand: band,
    lowImpact: band == AgeBand.gentle ? true : null,
    assist: switch (band) {
      AgeBand.gentle => true,
      AgeBand.active => false,
      AgeBand.balanced => null,
    },
  );

  S get s => S(language);

  MotionThresholds get thresholds =>
      lowImpact ? const MotionThresholds.lowImpact() : const MotionThresholds();

  RunSettings get runSettings => RunSettings(
    difficulty: difficulty,
    lowImpact: lowImpact,
    assist: assist,
    seenTypes: seenTypes,
    warningMultiplier: warningMultiplier,
  );

  Settings copyWith({
    AppLanguage? language,
    Difficulty? difficulty,
    bool? lowImpact,
    bool? assist,
    bool? ageConfirmed,
    bool? readinessDone,
    bool? setupDone,
    bool? tutorialDone,
    bool? signedIn,
    CalibrationProfile? calibration,
    bool clearCalibration = false,
    DeviceTier? deviceTier,
    Set<EncounterType>? seenTypes,
    int? sessionsPlayed,
    Set<String>? completedLevels,
    BodyStyle? bodyStyle,
    AgeBand? ageBand,
    bool? cameraMirror,
  }) => Settings(
    language: language ?? this.language,
    difficulty: difficulty ?? this.difficulty,
    lowImpact: lowImpact ?? this.lowImpact,
    assist: assist ?? this.assist,
    ageConfirmed: ageConfirmed ?? this.ageConfirmed,
    readinessDone: readinessDone ?? this.readinessDone,
    setupDone: setupDone ?? this.setupDone,
    tutorialDone: tutorialDone ?? this.tutorialDone,
    signedIn: signedIn ?? this.signedIn,
    calibration: clearCalibration ? null : (calibration ?? this.calibration),
    deviceTier: deviceTier ?? this.deviceTier,
    seenTypes: seenTypes ?? this.seenTypes,
    sessionsPlayed: sessionsPlayed ?? this.sessionsPlayed,
    completedLevels: completedLevels ?? this.completedLevels,
    bodyStyle: bodyStyle ?? this.bodyStyle,
    ageBand: ageBand ?? this.ageBand,
    cameraMirror: cameraMirror ?? this.cameraMirror,
  );

  Map<String, Object?> toJson() => {
    'language': language.name,
    'difficulty': difficulty.name,
    'lowImpact': lowImpact,
    'assist': assist,
    'ageConfirmed': ageConfirmed,
    'readinessDone': readinessDone,
    'setupDone': setupDone,
    'tutorialDone': tutorialDone,
    'signedIn': signedIn,
    'calibration': calibration?.toJson(),
    'deviceTier': deviceTier?.name,
    'seenTypes': [for (final t in seenTypes) t.name],
    'sessionsPlayed': sessionsPlayed,
    'completedLevels': [...completedLevels],
    'bodyStyle': bodyStyle.name,
    'ageBand': ageBand.name,
    'cameraMirror': cameraMirror,
  };

  factory Settings.fromJson(Map<String, dynamic> j) => Settings(
    language: AppLanguage.values.asNameMap()[j['language']] ?? AppLanguage.en,
    difficulty:
        Difficulty.values.asNameMap()[j['difficulty']] ?? Difficulty.beginner,
    lowImpact: j['lowImpact'] as bool? ?? true,
    assist: j['assist'] as bool? ?? false,
    ageConfirmed: j['ageConfirmed'] as bool? ?? false,
    readinessDone: j['readinessDone'] as bool? ?? false,
    setupDone: j['setupDone'] as bool? ?? false,
    tutorialDone: j['tutorialDone'] as bool? ?? false,
    signedIn: j['signedIn'] as bool? ?? false,
    calibration: j['calibration'] == null
        ? null
        : CalibrationProfile.fromJson(
            Map<String, dynamic>.from(j['calibration'] as Map),
          ),
    deviceTier: DeviceTier.values.asNameMap()[j['deviceTier']],
    seenTypes: {
      for (final n in (j['seenTypes'] as List<dynamic>? ?? const []))
        ?EncounterType.values.asNameMap()[n],
    },
    sessionsPlayed: (j['sessionsPlayed'] as num?)?.toInt() ?? 0,
    completedLevels: {
      for (final n in (j['completedLevels'] as List<dynamic>? ?? const []))
        if (n is String) n,
    },
    bodyStyle:
        BodyStyle.values.asNameMap()[j['bodyStyle']] ?? BodyStyle.neutral,
    ageBand: AgeBand.values.asNameMap()[j['ageBand']] ?? AgeBand.gentle,
    cameraMirror: j['cameraMirror'] as bool? ?? true,
  );
}

/// Injected at startup (see main.dart) so reads are synchronous.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError(),
);

class SettingsNotifier extends Notifier<Settings> {
  static const _key = 'settings.v1';

  @override
  Settings build() {
    final raw = ref.watch(sharedPrefsProvider).getString(_key);
    var s = const Settings();
    if (raw != null) {
      try {
        s = Settings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    currentLanguage = s.language;
    return s;
  }

  void update(Settings Function(Settings) f) {
    state = f(state);
    currentLanguage = state.language;
    ref.read(sharedPrefsProvider).setString(_key, jsonEncode(state.toJson()));
  }

  void reset() {
    state = const Settings();
    currentLanguage = state.language;
    ref.read(sharedPrefsProvider).remove(_key);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(
  SettingsNotifier.new,
);
