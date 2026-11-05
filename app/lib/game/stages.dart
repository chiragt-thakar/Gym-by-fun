import 'forest_game.dart';
import 'stage_info.dart';

/// One playable stage: a level config bundled in assets/levels/.
class Stage {
  const Stage({
    required this.levelId,
    required this.world,
    required this.worldName,
    required this.stageNumber,
    required this.title,
    required this.description,
    required this.theme,
  });

  final String levelId;
  final int world;
  final String worldName;
  final int stageNumber;
  final String title;
  final String description;
  final SceneTheme theme;

  String get asset => 'assets/levels/$levelId.json';
}

/// A world on the map. Worlds with no stages are "coming soon".
class World {
  const World(this.number, this.name, this.stages);
  final int number;
  final String name;
  final List<Stage> stages;
  bool get comingSoon => stages.isEmpty;
}

const forestEscapeId = 'w1-forest-escape';

/// Every playable stage, in play order. Unlocking follows this order.
const stages = <Stage>[
  Stage(
    levelId: forestEscapeId,
    world: 1,
    worldName: 'Forest Awakening',
    stageNumber: 1,
    title: 'Forest Escape',
    description: 'Duck branches, dodge rocks, open the forest gate.',
    theme: SceneTheme.forest,
  ),
  Stage(
    levelId: 'w1-river-crossing',
    world: 1,
    worldName: 'Forest Awakening',
    stageNumber: 2,
    title: 'River Crossing',
    description: 'Log beams, river rocks and firefly orbs.',
    theme: SceneTheme.forest,
  ),
  Stage(
    levelId: 'w1-guardian-grove',
    world: 1,
    worldName: 'Forest Awakening',
    stageNumber: 3,
    title: 'Guardian Grove',
    description: 'Calm the ancient tree guardian. Branches and roots!',
    theme: SceneTheme.forest,
  ),
  Stage(
    levelId: 'w1-firefly-trail',
    world: 1,
    worldName: 'Forest Awakening',
    stageNumber: 4,
    title: 'Firefly Trail',
    description: 'A calm night trail. Catch firefly orbs, follow the deer.',
    theme: SceneTheme.forest,
  ),
  Stage(
    levelId: 'w1-garba-quest-event',
    world: 1,
    worldName: 'Forest Awakening',
    stageNumber: 5,
    title: 'Garba Quest',
    description: 'Festival rhythm event: orbs and arches on the taali beat.',
    theme: SceneTheme.neon,
  ),
  Stage(
    levelId: 'w2-desert-dunes',
    world: 2,
    worldName: 'Desert Trials',
    stageNumber: 1,
    title: 'Desert Dunes',
    description: 'Sand walls, cactus arches and mirage orbs.',
    theme: SceneTheme.desert,
  ),
  Stage(
    levelId: 'w2-sandstorm-temple',
    world: 2,
    worldName: 'Desert Trials',
    stageNumber: 2,
    title: 'Sandstorm Temple',
    description: 'Wide sand walls and the temple gates.',
    theme: SceneTheme.desert,
  ),
  Stage(
    levelId: 'w2-oasis-caravan',
    world: 2,
    worldName: 'Desert Trials',
    stageNumber: 3,
    title: 'Oasis Caravan',
    description: 'Ride with the caravan: crates, tent ropes and water jars.',
    theme: SceneTheme.desert,
  ),
  Stage(
    levelId: 'w2-mirage-maze',
    world: 2,
    worldName: 'Desert Trials',
    stageNumber: 4,
    title: 'Mirage Maze',
    description:
        'A gentle lean-heavy maze with wide gaps and a shaded breather.',
    theme: SceneTheme.desert,
  ),
  Stage(
    levelId: 'w3-neon-city-rooftops',
    world: 3,
    worldName: 'Neon City',
    stageNumber: 1,
    title: 'Neon City Rooftops',
    description: 'Neon signs, drones and power cells on the rooftops.',
    theme: SceneTheme.neon,
  ),
  Stage(
    levelId: 'w3-neon-city-chase',
    world: 3,
    worldName: 'Neon City',
    stageNumber: 2,
    title: 'Neon City Chase',
    description: 'Outrun the drones, then dash through the gates.',
    theme: SceneTheme.neon,
  ),
  Stage(
    levelId: 'w3-neon-night-market',
    world: 3,
    worldName: 'Neon City',
    stageNumber: 3,
    title: 'Neon Night Market',
    description: 'Lantern strings, stall carts and glow tokens.',
    theme: SceneTheme.neon,
  ),
  Stage(
    levelId: 'w3-skyline-finale',
    world: 3,
    worldName: 'Neon City',
    stageNumber: 4,
    title: 'Skyline Finale',
    description: 'A rooftop drone-hub run ending in an arms-up gate gauntlet.',
    theme: SceneTheme.neon,
  ),
  Stage(
    levelId: 'w4-mountain-trail',
    world: 4,
    worldName: 'Mountain Expedition',
    stageNumber: 1,
    title: 'Mountain Trail',
    description: 'A gentle trail: boulders, rock arches, prayer flags.',
    theme: SceneTheme.mountain,
  ),
  Stage(
    levelId: 'w4-summit-storm',
    world: 4,
    worldName: 'Mountain Expedition',
    stageNumber: 2,
    title: 'Summit Storm',
    description: 'Wind gusts and rockfall on the way to the summit.',
    theme: SceneTheme.mountain,
  ),
  Stage(
    levelId: 'w4-glacier-pass',
    world: 4,
    worldName: 'Mountain Expedition',
    stageNumber: 3,
    title: 'Glacier Pass',
    description: 'Ice arches, crevasses and snow crystals on a frozen glacier.',
    theme: SceneTheme.mountain,
  ),
  Stage(
    levelId: 'w4-sunrise-summit',
    world: 4,
    worldName: 'Mountain Expedition',
    stageNumber: 4,
    title: 'Sunrise Summit',
    description:
        'A calm dawn climb to the summit, with a long tea-stop breather.',
    theme: SceneTheme.mountain,
  ),
];

const _laterWorlds = [
  'Stadium Nights',
  'Ancient Temple',
  'Shadow Arena',
  'Cosmic Journey',
  'Final Guardian',
];

/// Worlds in map order: the playable ones, then the ones still to come.
/// Built once.
final List<World> worlds = List.unmodifiable(_buildWorlds());

List<World> _buildWorlds() {
  final out = <World>[];
  for (final st in stages) {
    if (out.isEmpty || out.last.number != st.world) {
      out.add(World(st.world, st.worldName, []));
    }
    out.last.stages.add(st);
  }
  for (final name in _laterWorlds) {
    out.add(World(out.length + 1, name, const []));
  }
  return out;
}

Stage? stageById(String id) {
  for (final st in stages) {
    if (st.levelId == id) return st;
  }
  return null;
}

/// The first stage is always open; each later one opens when the stage
/// before it is completed.
bool isUnlocked(Stage stage, Set<String> completed) {
  final i = stages.indexOf(stage);
  if (i <= 0) return true;
  return completed.contains(stages[i - 1].levelId);
}

/// What the Daily Quest plays: the first unlocked stage not yet completed,
/// or Forest Escape once everything is done. With [premiumLocked] (payments
/// on and the player not Premium) Premium stages are skipped, so the Daily
/// Quest only ever routes to a free stage.
Stage nextStage(Set<String> completed, {bool premiumLocked = false}) {
  for (final st in stages) {
    if (premiumLocked && infoFor(st).premium) continue;
    if (!completed.contains(st.levelId) && isUnlocked(st, completed)) {
      return st;
    }
  }
  return stages.first;
}
