import 'dart:convert';

import 'package:motion_core/motion_core.dart';

/// Obstacle and pickup types in World 1. Each maps to exactly one move and
/// one sound cue, so a player can play by ear.
enum EncounterType {
  /// Low beam across all lanes: squat to duck.
  beam,

  /// Block in one or two lanes: lean into a free lane.
  laneBlock,

  /// Energy orb in a lane: raise arms to collect (optional, never damages).
  orb,

  /// Finale switch-gate across all lanes: raise arms to open.
  gate,
}

extension EncounterMove on EncounterType {
  /// The move that answers this encounter. Lane blocks are answered by a
  /// lean whose direction depends on where the player stands.
  Move? get move => switch (this) {
        EncounterType.beam => Move.squat,
        EncounterType.orb || EncounterType.gate => Move.raiseArms,
        EncounterType.laneBlock => null,
      };

  /// Demanding encounters count towards the "in a row" cap.
  bool get demanding => this == EncounterType.beam;

  /// Hitting it costs a heart. Orbs never hurt.
  bool get damages => this != EncounterType.orb;

  String get soundCue => 'cue_$name';
}

enum Difficulty { beginner, intermediate, advanced }

enum SceneKind { forest, river, ruins, desert, neon, mountain, festival }

enum Atmosphere { fireflies, rain, sand, stars, snow, petals }

enum MissionKind { lights, gates, path }

/// Authored scene identity and an optional, non-punishing replay objective.
class LevelGameplay {
  const LevelGameplay(
      {required this.scene,
      required this.mission,
      required this.targetFraction,
      required this.atmosphere});
  final SceneKind scene;
  final MissionKind mission;
  final double targetFraction;
  final Atmosphere atmosphere;
  factory LevelGameplay.fromJson(Map<String, dynamic> j) {
    final fraction = (j['targetFraction'] as num).toDouble();
    if (!fraction.isFinite || fraction < 0.25 || fraction > 1) {
      throw const FormatException('Mission targetFraction must be in 0.25..1');
    }
    return LevelGameplay(
        scene: SceneKind.values.byName(j['scene'] as String),
        mission: MissionKind.values.byName(j['mission'] as String),
        targetFraction: fraction,
        atmosphere: Atmosphere.values.byName(j['atmosphere'] as String));
  }
}

/// Optional authored story and completion keepsake. Presentation only: these
/// never alter scoring, pacing or movement recognition.
class JourneyStory {
  const JourneyStory(
      {required this.mission,
      required this.completion,
      required this.keepsake});
  final String mission;
  final String completion;
  final String keepsake;
  factory JourneyStory.fromJson(Map<String, dynamic> j) {
    String read(String key) {
      final value = j[key];
      if (value is! String || value.trim().isEmpty || value.length > 100) {
        throw FormatException('Invalid journey $key');
      }
      return value;
    }

    return JourneyStory(
        mission: read('mission'),
        completion: read('completion'),
        keepsake: read('keepsake'));
  }
}

enum HintMode { always, firstTime, off }

/// Per-difficulty pacing, read from the level config.
class DifficultyProfile {
  const DifficultyProfile({
    required this.warningMs,
    required this.maxDemandingInRow,
    required this.hints,
    required this.lowImpactDefault,
  });

  /// How long before arrival the sound cue plays and the obstacle appears.
  final int warningMs;
  final int maxDemandingInRow;
  final HintMode hints;
  final bool lowImpactDefault;

  factory DifficultyProfile.fromJson(Map<String, dynamic> j) =>
      DifficultyProfile(
        warningMs: (j['warningMs'] as num).toInt(),
        maxDemandingInRow: (j['maxDemandingInRow'] as num).toInt(),
        hints: HintMode.values.byName(j['hints'] as String),
        lowImpactDefault: j['lowImpactDefault'] as bool? ?? true,
      );
}

enum SegmentKind { practice, learn, breather, combo, checkpoint, finale }

class Segment {
  const Segment(this.id, this.kind, this.startMs, this.endMs, {this.hint});
  final String id;
  final SegmentKind kind;
  final int startMs;
  final int endMs;
  final String? hint;

  factory Segment.fromJson(Map<String, dynamic> j) => Segment(
        j['id'] as String,
        SegmentKind.values.byName(j['kind'] as String),
        ((j['startS'] as num) * 1000).round(),
        ((j['endS'] as num) * 1000).round(),
        hint: j['hint'] as String?,
      );
}

/// One authored encounter.
class EncounterSpec {
  const EncounterSpec({
    required this.atMs,
    required this.type,
    this.lanes = const [],
    this.minDifficulty = Difficulty.beginner,
    this.hint,
  });

  /// Planned arrival time at the hero.
  final int atMs;
  final EncounterType type;

  /// Lanes it occupies (0 = left). Beams and gates occupy all lanes.
  final List<int> lanes;

  /// Encounters marked harder are dropped at easier difficulties.
  final Difficulty minDifficulty;
  final String? hint;

  factory EncounterSpec.fromJson(Map<String, dynamic> j, int laneCount) {
    final type = EncounterType.values.byName(j['type'] as String);
    final allLanes = List<int>.generate(laneCount, (i) => i);
    final lanes = switch (type) {
      EncounterType.beam || EncounterType.gate => allLanes,
      _ => [for (final l in (j['lanes'] as List<dynamic>)) (l as num).toInt()],
    };
    return EncounterSpec(
      atMs: ((j['atS'] as num) * 1000).round(),
      type: type,
      lanes: lanes,
      minDifficulty: j['minDifficulty'] == null
          ? Difficulty.beginner
          : Difficulty.values.byName(j['minDifficulty'] as String),
      hint: j['hint'] as String?,
    );
  }
}

class LevelConfig {
  LevelConfig({
    required this.id,
    required this.version,
    required this.schemaVersion,
    required this.world,
    required this.name,
    required this.lanes,
    required this.durationMs,
    required this.hearts,
    required this.segments,
    required this.encounters,
    required this.difficulty,
    required this.scoring,
    this.journey,
    this.gameplay,
  });

  static const supportedSchemaVersion = 1;

  final String id;
  final int version;
  final int schemaVersion;
  final int world;
  final String name;
  final int lanes;
  final int durationMs;
  final int hearts;
  final List<Segment> segments;
  final List<EncounterSpec> encounters;
  final Map<Difficulty, DifficultyProfile> difficulty;
  final Map<EncounterType, int> scoring;
  final JourneyStory? journey;
  final LevelGameplay? gameplay;

  Segment? segmentAt(int ms) {
    for (final s in segments) {
      if (ms >= s.startMs && ms < s.endMs) return s;
    }
    return null;
  }

  Segment? get checkpoint {
    for (final s in segments) {
      if (s.kind == SegmentKind.checkpoint) return s;
    }
    return null;
  }

  /// Parses a level. Structural validation against
  /// `content/schema/level.schema.json` happens in CI and on the server
  /// before publishing; this re-checks the invariants the game relies on.
  factory LevelConfig.fromJson(Map<String, dynamic> j) {
    final sv = (j['schemaVersion'] as num).toInt();
    if (sv > supportedSchemaVersion) {
      throw FormatException('Level schema $sv is newer than this app');
    }
    final lanes = (j['lanes'] as num).toInt();
    final level = LevelConfig(
      id: j['id'] as String,
      version: (j['version'] as num).toInt(),
      schemaVersion: sv,
      world: (j['world'] as num).toInt(),
      name: j['name'] as String,
      gameplay: j['gameplay'] == null
          ? null
          : LevelGameplay.fromJson(j['gameplay'] as Map<String, dynamic>),
      journey: j['journey'] == null
          ? null
          : JourneyStory.fromJson(j['journey'] as Map<String, dynamic>),
      lanes: lanes,
      durationMs: ((j['durationS'] as num) * 1000).round(),
      hearts: (j['hearts'] as num?)?.toInt() ?? 3,
      segments: [
        for (final s in j['segments'] as List<dynamic>)
          Segment.fromJson(s as Map<String, dynamic>)
      ],
      encounters: [
        for (final e in j['encounters'] as List<dynamic>)
          EncounterSpec.fromJson(e as Map<String, dynamic>, lanes)
      ]..sort((a, b) => a.atMs.compareTo(b.atMs)),
      difficulty: {
        for (final e in (j['difficulty'] as Map<String, dynamic>).entries)
          Difficulty.values.byName(e.key):
              DifficultyProfile.fromJson(e.value as Map<String, dynamic>)
      },
      scoring: {
        for (final e in (j['scoring'] as Map<String, dynamic>).entries)
          EncounterType.values.byName(e.key): (e.value as num).toInt()
      },
    );
    level._check();
    return level;
  }

  factory LevelConfig.decode(String s) =>
      LevelConfig.fromJson(jsonDecode(s) as Map<String, dynamic>);

  void _check() {
    final goal = gameplay?.mission;
    if (goal != null &&
        !encounters.any((e) =>
            e.minDifficulty == Difficulty.beginner &&
            switch (goal) {
              MissionKind.lights => e.type == EncounterType.orb,
              MissionKind.gates => e.type == EncounterType.gate,
              MissionKind.path => e.type.damages,
            })) {
      throw FormatException('$id: mission needs a beginner-level opportunity');
    }
    for (final d in Difficulty.values) {
      if (!difficulty.containsKey(d)) {
        throw FormatException('$id: missing difficulty "${d.name}"');
      }
    }
    for (final e in encounters) {
      if (e.atMs < 0 || e.atMs > durationMs) {
        throw FormatException('$id: encounter at ${e.atMs} ms outside level');
      }
      if (e.lanes.any((l) => l < 0 || l >= lanes)) {
        throw FormatException('$id: encounter at ${e.atMs} ms has a bad lane');
      }
      if (e.type == EncounterType.laneBlock && e.lanes.length >= lanes) {
        throw FormatException(
            '$id: lane block at ${e.atMs} ms leaves no free lane');
      }
    }
    for (final s in segments) {
      if (s.endMs <= s.startMs) {
        throw FormatException('$id: segment ${s.id} is empty');
      }
    }
  }
}
