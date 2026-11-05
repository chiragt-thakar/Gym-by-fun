import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../l10n/tr.dart';

enum DeviceTier { upperMid, mid, budget }

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

  S get s => S(language);

  MotionThresholds get thresholds =>
      lowImpact ? const MotionThresholds.lowImpact() : const MotionThresholds();

  RunSettings get runSettings => RunSettings(
    difficulty: difficulty,
    lowImpact: lowImpact,
    assist: assist,
    seenTypes: seenTypes,
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
