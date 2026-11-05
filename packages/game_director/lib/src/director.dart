import 'level.dart';

/// Player choices that shape pacing.
class RunSettings {
  const RunSettings({
    this.difficulty = Difficulty.beginner,
    bool? lowImpact,
    this.assist = false,
    this.seenTypes = const {},
  }) : _lowImpact = lowImpact;

  final Difficulty difficulty;
  final bool? _lowImpact;

  /// Assist mode: wider timing windows, lane auto-centring.
  final bool assist;

  /// Encounter types the player has already met (for first-time hints).
  final Set<EncounterType> seenTypes;

  bool lowImpactFor(DifficultyProfile p) => _lowImpact ?? p.lowImpactDefault;
}

/// Minimum physical time each answer takes, used to keep every encounter
/// finishable. Starting values; tuned in playtests (docs/game-design.md).
abstract final class MoveTimes {
  /// Down, pass under the beam, back up enough to move again.
  static const beamRecoveryMs = 1100;
  static const leanRecoveryMs = 650;
  static const raiseRecoveryMs = 750;

  /// Extra recovery in low-impact mode.
  static const lowImpactExtraMs = 250;

  static int recovery(EncounterType t, {required bool lowImpact}) {
    final base = switch (t) {
      EncounterType.beam => beamRecoveryMs,
      EncounterType.laneBlock => leanRecoveryMs,
      EncounterType.orb || EncounterType.gate => raiseRecoveryMs,
    };
    return base + (lowImpact ? lowImpactExtraMs : 0);
  }
}

/// An encounter as the run will actually present it.
class PlannedEncounter {
  const PlannedEncounter({
    required this.index,
    required this.type,
    required this.lanes,
    required this.arriveMs,
    required this.warnMs,
    this.hint,
    this.substituted = false,
  });

  final int index;
  final EncounterType type;
  final List<int> lanes;
  final int arriveMs;

  /// When the cue sounds and the obstacle appears.
  final int warnMs;

  /// Hint text to show and speak, if hints apply.
  final String? hint;

  /// True if the director swapped a demanding encounter for a lighter one.
  final bool substituted;

  int get warningMs => arriveMs - warnMs;

  @override
  String toString() => 'Planned#$index(${type.name} $lanes @$arriveMs)';
}

/// The deterministic workout-aware director.
///
/// Same level + same settings ⇒ same plan, every time. It never claims to
/// measure fatigue, heart rate or medical readiness; it only applies rules.
class Director {
  Director(this.level, this.settings)
      : profile = level.difficulty[settings.difficulty]!;

  final LevelConfig level;
  final RunSettings settings;
  final DifficultyProfile profile;

  bool get lowImpact => settings.lowImpactFor(profile);

  /// Extra warning for lane blocks that cover two lanes.
  static const wideBlockExtraMs = 600;

  /// Warning time after assist mode is applied.
  int get warningMs =>
      settings.assist ? (profile.warningMs * 1.25).round() : profile.warningMs;

  List<PlannedEncounter> plan() {
    final out = <PlannedEncounter>[];
    final seen = {...settings.seenTypes};
    var demandingRun = 0;
    var earliestNext = 0;
    EncounterType? prevType;

    for (final spec in level.encounters) {
      // 1. Difficulty filter.
      if (spec.minDifficulty.index > settings.difficulty.index) continue;

      // 2. Breathers never carry anything that can hurt.
      final seg = level.segmentAt(spec.atMs);
      if (seg?.kind == SegmentKind.breather && spec.type.damages) continue;

      // 3. Cap demanding moves in a row: swap the extra for a lighter orb.
      var type = spec.type;
      var lanes = spec.lanes;
      var substituted = false;
      if (type.demanding) {
        demandingRun++;
        if (demandingRun > profile.maxDemandingInRow) {
          type = EncounterType.orb;
          lanes = [level.lanes ~/ 2];
          substituted = true;
          demandingRun = 0;
        }
      } else if (type != EncounterType.orb) {
        demandingRun = 0;
      }

      // 4. Feasibility: leave enough time to physically finish the previous
      //    move, and never ask for two moves at once.
      var at = spec.atMs;
      if (prevType != null && at < earliestNext) at = earliestNext;
      if (at > level.durationMs) break;

      // 5. Hints.
      String? hint;
      final h = spec.hint;
      if (h != null || profile.hints == HintMode.always) {
        final show = switch (profile.hints) {
          HintMode.always => true,
          HintMode.firstTime => !seen.contains(type),
          HintMode.off => false,
        };
        if (show) hint = h ?? _defaultHint(type);
      }
      seen.add(type);

      out.add(PlannedEncounter(
        index: out.length,
        type: type,
        lanes: lanes,
        arriveMs: at,
        // A two-lane block may need two leans: cue it earlier.
        warnMs: at -
            warningMs -
            (type == EncounterType.laneBlock && lanes.length > 1
                ? wideBlockExtraMs
                : 0),
        hint: hint,
        substituted: substituted,
      ));
      earliestNext = at + MoveTimes.recovery(type, lowImpact: lowImpact);
      prevType = type;
    }
    return out;
  }

  static String _defaultHint(EncounterType t) => switch (t) {
        EncounterType.beam => 'Squat to duck!',
        EncounterType.laneBlock => 'Lean to change lane!',
        EncounterType.orb => 'Raise your arms to grab energy!',
        EncounterType.gate => 'Arms up to open the gate!',
      };
}

/// Run-time pacing: how fast the world moves this instant.
///
/// The game slows down — never punishes — when tracking is shaky, and stops
/// when the player has left the frame.
class Pacer {
  Pacer({this.amberScale = 0.6, this.rampPerSecond = 2.5});

  final double amberScale;
  final double rampPerSecond;

  double _scale = 1;
  double get scale => _scale;

  /// Back to full pace (e.g. on a checkpoint restart).
  void reset() => _scale = 1;

  /// [light]: 0 = green, 1 = amber, 2 = red (paused).
  double update(int dtMs, int light) {
    final target = switch (light) { 0 => 1.0, 1 => amberScale, _ => 0.0 };
    final step = rampPerSecond * dtMs / 1000;
    if (_scale < target) {
      _scale = (_scale + step).clamp(0, target).toDouble();
    } else {
      _scale = (_scale - step).clamp(target, 1).toDouble();
    }
    return _scale;
  }
}
