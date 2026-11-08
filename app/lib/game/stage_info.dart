import 'stages.dart';

import 'package:game_director/game_director.dart';

String missionName(MissionKind kind) => switch (kind) {
  MissionKind.lights => 'Gather the lights',
  MissionKind.gates => 'Awaken the beacons',
  MissionKind.path => 'Clear the trail',
};

/// Body areas the body map can highlight.
enum BodyRegion {
  quads,
  glutes,
  hamstrings,
  calves,
  core,
  obliques,
  shoulders,
  upperBack,
  arms,
  hipAbductors,
}

/// Movements the game asks for.
enum MovementPattern { squat, sideBend, overheadReach }

enum Intensity { light, moderate }

/// Free stages are World 1; later worlds are Premium.
enum StageTier { free, premium }

extension BodyRegionLabel on BodyRegion {
  String get label => switch (this) {
    BodyRegion.quads => 'Front thighs',
    BodyRegion.glutes => 'Glutes',
    BodyRegion.hamstrings => 'Back thighs',
    BodyRegion.calves => 'Calves',
    BodyRegion.core => 'Core',
    BodyRegion.obliques => 'Side waist',
    BodyRegion.shoulders => 'Shoulders',
    BodyRegion.upperBack => 'Upper back',
    BodyRegion.arms => 'Arms',
    BodyRegion.hipAbductors => 'Outer hips',
  };
}

extension MovementPatternLabel on MovementPattern {
  String get label => switch (this) {
    MovementPattern.squat => 'Squat',
    MovementPattern.sideBend => 'Side lean',
    MovementPattern.overheadReach => 'Overhead reach',
  };
}

extension IntensityLabel on Intensity {
  String get label => switch (this) {
    Intensity.light => 'Light',
    Intensity.moderate => 'Moderate',
  };
}

/// A published source behind a general-fitness statement (name + year only).
class EvidenceRef {
  const EvidenceRef(this.source, this.year);
  final String source;
  final int year;
  @override
  String toString() => '$source ($year)';
}

const who2020 = EvidenceRef(
  'WHO Guidelines on physical activity and sedentary behaviour',
  2020,
);
const acsm11 = EvidenceRef(
  "ACSM's Guidelines for Exercise Testing and Prescription, 11th ed.",
  2021,
);
const garber2011 = EvidenceRef(
  'Garber et al., ACSM Position Stand, Med Sci Sports Exerc',
  2011,
);

/// What a stage asks of the body. General fitness information only.
class StageInfo {
  const StageInfo({
    required this.levelId,
    required this.primary,
    required this.secondary,
    required this.movements,
    required this.intensity,
    required this.benefits,
    required this.references,
    required this.tier,
  });

  final String levelId;
  final List<BodyRegion> primary;
  final List<BodyRegion> secondary;
  final List<MovementPattern> movements;
  final Intensity intensity;
  final List<String> benefits;
  final List<EvidenceRef> references;
  final StageTier tier;

  bool get premium => tier == StageTier.premium;
}

const _all = [
  MovementPattern.squat,
  MovementPattern.sideBend,
  MovementPattern.overheadReach,
];

const stageInfos = <String, StageInfo>{
  'w1-forest-escape': StageInfo(
    levelId: 'w1-forest-escape',
    primary: [BodyRegion.quads, BodyRegion.glutes],
    secondary: [BodyRegion.core, BodyRegion.obliques, BodyRegion.shoulders],
    movements: _all,
    intensity: Intensity.light,
    benefits: [
      'Gets you moving with easy, controlled squats.',
      'Practises leaning side to side with balance.',
      'Adds active minutes to your week.',
    ],
    references: [who2020, acsm11],
    tier: StageTier.free,
  ),
  'w1-river-crossing': StageInfo(
    levelId: 'w1-river-crossing',
    primary: [BodyRegion.quads, BodyRegion.obliques],
    secondary: [BodyRegion.glutes, BodyRegion.core, BodyRegion.shoulders],
    movements: _all,
    intensity: Intensity.light,
    benefits: [
      'Builds leg strength with repeated squats.',
      'Side leans work the muscles along your waist.',
      'Reaching up gently moves the shoulders.',
    ],
    references: [who2020, garber2011],
    tier: StageTier.free,
  ),
  'w1-guardian-grove': StageInfo(
    levelId: 'w1-guardian-grove',
    primary: [BodyRegion.quads, BodyRegion.glutes, BodyRegion.obliques],
    secondary: [BodyRegion.core, BodyRegion.hamstrings, BodyRegion.shoulders],
    movements: _all,
    intensity: Intensity.moderate,
    benefits: [
      'A longer mix of squats and leans for steady effort.',
      'Helps build muscular endurance in the legs.',
      'Counts toward weekly activity guidelines.',
    ],
    references: [who2020, acsm11, garber2011],
    tier: StageTier.free,
  ),
  'w1-firefly-trail': StageInfo(
    levelId: 'w1-firefly-trail',
    primary: [BodyRegion.shoulders, BodyRegion.upperBack],
    secondary: [BodyRegion.quads, BodyRegion.obliques],
    movements: _all,
    intensity: Intensity.light,
    benefits: [
      'Overhead reaches move the shoulders and arms.',
      'Easy squats keep the legs active.',
      'A relaxed way to add movement to your day.',
    ],
    references: [who2020, acsm11],
    tier: StageTier.free,
  ),
  'w1-garba-quest-event': StageInfo(
    levelId: 'w1-garba-quest-event',
    primary: [
      BodyRegion.obliques,
      BodyRegion.hipAbductors,
      BodyRegion.shoulders,
    ],
    secondary: [BodyRegion.glutes, BodyRegion.core],
    movements: [MovementPattern.sideBend, MovementPattern.overheadReach],
    intensity: Intensity.light,
    benefits: [
      'Side leans work the waist and outer hips.',
      'Overhead reaches move the shoulders and arms.',
      'Adds active minutes to your week.',
    ],
    references: [who2020, acsm11],
    tier: StageTier.free,
  ),
  'w2-desert-dunes': StageInfo(
    levelId: 'w2-desert-dunes',
    primary: [BodyRegion.obliques, BodyRegion.hipAbductors],
    secondary: [BodyRegion.quads, BodyRegion.core, BodyRegion.shoulders],
    movements: _all,
    intensity: Intensity.light,
    benefits: [
      'Side leans work the waist and outer hips.',
      'Squats keep the legs working between walls.',
      'Practises moving with control and balance.',
    ],
    references: [acsm11, garber2011],
    tier: StageTier.premium,
  ),
  'w2-sandstorm-temple': StageInfo(
    levelId: 'w2-sandstorm-temple',
    primary: [BodyRegion.obliques, BodyRegion.quads, BodyRegion.hipAbductors],
    secondary: [BodyRegion.glutes, BodyRegion.core, BodyRegion.shoulders],
    movements: _all,
    intensity: Intensity.moderate,
    benefits: [
      'Wide leans and squats for a fuller workout.',
      'Builds muscular endurance in legs and waist.',
      'Adds active minutes to your week.',
    ],
    references: [who2020, garber2011],
    tier: StageTier.premium,
  ),
  'w2-oasis-caravan': StageInfo(
    levelId: 'w2-oasis-caravan',
    primary: [BodyRegion.obliques, BodyRegion.hipAbductors, BodyRegion.quads],
    secondary: [BodyRegion.glutes, BodyRegion.core, BodyRegion.shoulders],
    movements: _all,
    intensity: Intensity.light,
    benefits: [
      'Side leans work the waist and outer hips.',
      'Squats keep the legs working between walls.',
      'Adds active minutes to your week.',
    ],
    references: [who2020, acsm11],
    tier: StageTier.premium,
  ),
  'w3-neon-city-rooftops': StageInfo(
    levelId: 'w3-neon-city-rooftops',
    primary: [BodyRegion.shoulders, BodyRegion.arms],
    secondary: [BodyRegion.upperBack, BodyRegion.quads, BodyRegion.obliques],
    movements: _all,
    intensity: Intensity.light,
    benefits: [
      'Overhead reaches move the shoulders and arms.',
      'Squats and leans keep the whole body involved.',
      'Breaks up long periods of sitting.',
    ],
    references: [who2020, acsm11],
    tier: StageTier.premium,
  ),
  'w3-neon-city-chase': StageInfo(
    levelId: 'w3-neon-city-chase',
    primary: [BodyRegion.shoulders, BodyRegion.quads, BodyRegion.glutes],
    secondary: [BodyRegion.arms, BodyRegion.upperBack, BodyRegion.core],
    movements: _all,
    intensity: Intensity.moderate,
    benefits: [
      'A faster mix of reaches, squats and leans.',
      'Raises your effort for steady aerobic activity.',
      'Builds muscular endurance in legs and shoulders.',
    ],
    references: [who2020, acsm11, garber2011],
    tier: StageTier.premium,
  ),
  'w3-neon-night-market': StageInfo(
    levelId: 'w3-neon-night-market',
    primary: [BodyRegion.shoulders, BodyRegion.arms, BodyRegion.quads],
    secondary: [BodyRegion.upperBack, BodyRegion.obliques, BodyRegion.core],
    movements: _all,
    intensity: Intensity.light,
    benefits: [
      'Overhead reaches move the shoulders and arms.',
      'Squats and leans keep the whole body involved.',
      'Breaks up long periods of sitting.',
    ],
    references: [who2020, acsm11],
    tier: StageTier.premium,
  ),
  'w4-mountain-trail': StageInfo(
    levelId: 'w4-mountain-trail',
    primary: [BodyRegion.quads, BodyRegion.shoulders],
    secondary: [BodyRegion.glutes, BodyRegion.calves, BodyRegion.core],
    movements: _all,
    intensity: Intensity.light,
    benefits: [
      'A gentle pace with plenty of overhead reaches.',
      'Easy squats keep the legs active.',
      'A relaxed way to add movement to your day.',
    ],
    references: [who2020, acsm11],
    tier: StageTier.premium,
  ),
  'w4-summit-storm': StageInfo(
    levelId: 'w4-summit-storm',
    primary: [BodyRegion.quads, BodyRegion.glutes, BodyRegion.core],
    secondary: [BodyRegion.obliques, BodyRegion.shoulders, BodyRegion.calves],
    movements: _all,
    intensity: Intensity.moderate,
    benefits: [
      'A steady mix of squats, leans and reaches.',
      'Builds leg strength and muscular endurance.',
      'Counts toward weekly activity guidelines.',
    ],
    references: [who2020, acsm11, garber2011],
    tier: StageTier.premium,
  ),
  'w4-glacier-pass': StageInfo(
    levelId: 'w4-glacier-pass',
    primary: [BodyRegion.quads, BodyRegion.glutes, BodyRegion.obliques],
    secondary: [BodyRegion.shoulders, BodyRegion.core, BodyRegion.calves],
    movements: _all,
    intensity: Intensity.moderate,
    benefits: [
      'A steady mix of squats, leans and reaches.',
      'Builds leg strength and muscular endurance.',
      'Counts toward weekly activity guidelines.',
    ],
    references: [who2020, acsm11, garber2011],
    tier: StageTier.premium,
  ),
  'w4-sunrise-summit': StageInfo(
    levelId: 'w4-sunrise-summit',
    primary: [BodyRegion.quads, BodyRegion.shoulders],
    secondary: [BodyRegion.glutes, BodyRegion.obliques, BodyRegion.calves],
    movements: _all,
    intensity: Intensity.light,
    benefits: [
      'A steady mix of squats, leans and reaches.',
      'Adds active minutes to your week.',
    ],
    references: [who2020, acsm11],
    tier: StageTier.premium,
  ),
  'w2-mirage-maze': StageInfo(
    levelId: 'w2-mirage-maze',
    primary: [BodyRegion.hipAbductors, BodyRegion.obliques, BodyRegion.core],
    secondary: [BodyRegion.quads, BodyRegion.glutes, BodyRegion.shoulders],
    movements: _all,
    intensity: Intensity.light,
    benefits: [
      'A steady mix of squats, leans and reaches.',
      'Adds active minutes to your week.',
    ],
    references: [who2020, acsm11],
    tier: StageTier.premium,
  ),
  'w3-skyline-finale': StageInfo(
    levelId: 'w3-skyline-finale',
    primary: [BodyRegion.shoulders, BodyRegion.quads, BodyRegion.glutes],
    secondary: [BodyRegion.core, BodyRegion.obliques, BodyRegion.upperBack],
    movements: _all,
    intensity: Intensity.moderate,
    benefits: [
      'A steady mix of squats, leans and reaches.',
      'Builds leg strength and muscular endurance.',
      'Counts toward weekly activity guidelines.',
    ],
    references: [who2020, acsm11, garber2011],
    tier: StageTier.premium,
  ),
  'w1-monsoon-meadow': StageInfo(
    levelId: 'w1-monsoon-meadow',
    primary: [
      BodyRegion.quads,
      BodyRegion.glutes,
      BodyRegion.obliques,
      BodyRegion.shoulders,
    ],
    secondary: [BodyRegion.core, BodyRegion.hamstrings, BodyRegion.upperBack],
    movements: _all,
    intensity: Intensity.light,
    benefits: [
      'A steady mix of squats, leans and reaches.',
      'Adds active minutes to your week.',
    ],
    references: [who2020, acsm11],
    tier: StageTier.free,
  ),
};

/// Info for a stage. Every stage in [stages] has an entry (see tests).
StageInfo infoFor(Stage stage) => stageInfos[stage.levelId]!;
