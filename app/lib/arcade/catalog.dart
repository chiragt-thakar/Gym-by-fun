import 'package:flutter/material.dart';

/// How a game is filed in the library.
enum GameGenre { adventure, rhythm, arcade, sports, party, puzzle }

extension GameGenreLabel on GameGenre {
  String get label => switch (this) {
    GameGenre.adventure => 'Adventure',
    GameGenre.rhythm => 'Rhythm',
    GameGenre.arcade => 'Arcade',
    GameGenre.sports => 'Sports',
    GameGenre.party => 'Party',
    GameGenre.puzzle => 'Puzzle',
  };
}

class MoveInfo {
  const MoveInfo(this.icon, this.label);
  final IconData icon;
  final String label;
}

class HowToStep {
  const HowToStep(this.icon, this.title, this.text);
  final IconData icon;
  final String title;
  final String text;
}

/// Presentation data for one game in the library. Rules and levels live in
/// the engines and the JSON content; this is only how the game is shown.
class GameInfo {
  const GameInfo({
    required this.id,
    required this.title,
    required this.tagline,
    required this.description,
    required this.genre,
    required this.accent,
    required this.deep,
    required this.icon,
    required this.minutes,
    required this.intensity,
    required this.moves,
    required this.howTo,
    required this.stageNoun,
    this.isNew = false,
    this.selfView = false,
    this.comfort,
    this.extraGenre,
  });

  final String id;
  final String title;
  final String tagline;
  final String description;
  final GameGenre genre;
  final GameGenre? extraGenre;

  /// Bright accent (chips, rings) and a deep tone for card washes.
  final Color accent;
  final Color deep;
  final IconData icon;
  final String minutes;
  final String intensity;
  final List<MoveInfo> moves;
  final List<HowToStep> howTo;

  /// What one level is called in this game: "Stage", "Guardian", "Song"...
  final String stageNoun;
  final bool isNew;

  /// Best with the camera mirror on (you see yourself in the scene).
  final bool selfView;
  final String? comfort;

  bool inGenre(GameGenre g) => genre == g || extraGenre == g;
}

const adventureId = 'adventure';

const games = <GameInfo>[
  GameInfo(
    id: adventureId,
    title: 'MotionQuest Trails',
    tagline: 'Run through four worlds with your whole body.',
    description:
        'The original adventure. Your explorer runs on their own; you duck '
        'under branches, lean to switch paths and raise your arms to open '
        'gates. Eighteen chapters across the forest, the desert, Neon City '
        'and the mountains, each with its own mission and keepsake.',
    genre: GameGenre.adventure,
    accent: Color(0xFFFF9A3C),
    deep: Color(0xFF2B1A0C),
    icon: Icons.forest_rounded,
    minutes: '5–7 min',
    intensity: 'Light to moderate',
    stageNoun: 'Chapter',
    moves: [
      MoveInfo(Icons.south_rounded, 'Duck'),
      MoveInfo(Icons.swap_horiz_rounded, 'Lean'),
      MoveInfo(Icons.pan_tool_alt_rounded, 'Arms up'),
    ],
    howTo: [
      HowToStep(
        Icons.south_rounded,
        'Duck under beams',
        'A comfortable squat slips under branches and banners.',
      ),
      HowToStep(
        Icons.swap_horiz_rounded,
        'Lean to change lanes',
        'Lean left or right to find the open path.',
      ),
      HowToStep(
        Icons.pan_tool_alt_rounded,
        'Raise your arms',
        'Catch light orbs and open the gates.',
      ),
    ],
  ),
  GameInfo(
    id: 'craftguard',
    title: 'Craftguard Duels',
    tagline: 'Calm giant craft guardians on a four-count.',
    description:
        'An original guardian made of stepwells, kites or brass wakes up and '
        'attacks on a spoken count: ek, do, teen, char. Duck, lean or guard '
        'on the hit to break its poise, then strike the glowing side pads and '
        'raise your arms to calm it. Guardians are calmed, never destroyed.',
    genre: GameGenre.arcade,
    extraGenre: GameGenre.rhythm,
    accent: Color(0xFFE8B04A),
    deep: Color(0xFF1F2A5C),
    icon: Icons.shield_moon_rounded,
    minutes: '2–4 min',
    intensity: 'Light to moderate',
    stageNoun: 'Guardian',
    isNew: true,
    moves: [
      MoveInfo(Icons.south_rounded, 'Duck'),
      MoveInfo(Icons.swap_horiz_rounded, 'Lean'),
      MoveInfo(Icons.shield_rounded, 'Guard'),
      MoveInfo(Icons.back_hand_rounded, 'Side strike'),
      MoveInfo(Icons.pan_tool_alt_rounded, 'Arms up'),
    ],
    howTo: [
      HowToStep(
        Icons.hearing_rounded,
        'Listen for the count',
        'Every attack is counted in. Move on the fourth beat.',
      ),
      HowToStep(
        Icons.shield_rounded,
        'Answer the attack',
        'Duck, lean or raise a guard by your face. Clean answers break its poise.',
      ),
      HowToStep(
        Icons.back_hand_rounded,
        'Strike the side pads',
        'When it staggers, reach out to the glowing pads beside you, then raise both arms.',
      ),
    ],
    comfort:
        'Strikes are slow reaches out to the side, never fast punches. '
        'Missing a pad never costs a spark.',
  ),
  GameInfo(
    id: 'taal-toofan',
    title: 'Taal Toofan',
    tagline: 'Build the band one move at a time.',
    description:
        'Move cards land on your body on the beat: a clap between your hands, '
        'a step at your feet, a wave out to the side. Every move family you '
        'hit adds an instrument. Fill the Josh meter and shout Hoy for Toofan '
        'Time. Songs always finish; your score is your accuracy.',
    genre: GameGenre.rhythm,
    extraGenre: GameGenre.party,
    accent: Color(0xFFFF4D6D),
    deep: Color(0xFF2A0F2E),
    icon: Icons.music_note_rounded,
    minutes: '1–2 min a song',
    intensity: 'Light to moderate',
    stageNoun: 'Song',
    isNew: true,
    moves: [
      MoveInfo(Icons.front_hand_rounded, 'Clap'),
      MoveInfo(Icons.swap_horiz_rounded, 'Step'),
      MoveInfo(Icons.waving_hand_rounded, 'Wave'),
      MoveInfo(Icons.north_rounded, 'Reach'),
      MoveInfo(Icons.south_rounded, 'Dip'),
    ],
    howTo: [
      HowToStep(
        Icons.record_voice_over_rounded,
        'Follow the caller',
        'Each move is called one beat early, like a dance class.',
      ),
      HowToStep(
        Icons.adjust_rounded,
        'Hit the card as it lands',
        'Cards land where the move happens: hands, feet or out to the side.',
      ),
      HowToStep(
        Icons.bolt_rounded,
        'Toofan Time',
        'Fill the Josh meter, then raise your arms for double points.',
      ),
    ],
  ),
  GameInfo(
    id: 'mirror-mela',
    title: 'Mirror Mela',
    tagline: 'The fair comes to you. Pop it, catch it, dodge it.',
    description:
        'Bubbles, lanterns and marigolds drift to points around your body. '
        'Put the right hand in the zone as the ring closes and it pops with a '
        'note, so a good combo plays a melody. Orbit rounds add slow cloud '
        'sweeps to duck under or lean away from.',
    genre: GameGenre.arcade,
    accent: Color(0xFFFFB627),
    deep: Color(0xFF3A1A12),
    icon: Icons.bubble_chart_rounded,
    minutes: '1–1.5 min a round',
    intensity: 'Light',
    stageNoun: 'Round',
    isNew: true,
    selfView: true,
    moves: [
      MoveInfo(Icons.north_east_rounded, 'Reach high'),
      MoveInfo(Icons.east_rounded, 'Reach out'),
      MoveInfo(Icons.south_rounded, 'Duck'),
      MoveInfo(Icons.swap_horiz_rounded, 'Lean'),
    ],
    howTo: [
      HowToStep(
        Icons.radio_button_checked_rounded,
        'Watch the ring',
        'A ring shrinks onto each object. Reach in as it closes.',
      ),
      HowToStep(
        Icons.back_hand_rounded,
        'Right hand, right shape',
        'Circles are for your left hand, diamonds for your right.',
      ),
      HowToStep(
        Icons.cloud_rounded,
        'Dodge the sweeps',
        'In Orbit rounds, duck or lean away from the passing cloud.',
      ),
    ],
  ),
  GameInfo(
    id: 'tapeball',
    title: 'Tapeball Tamasha',
    tagline: 'Gully cricket in your living room.',
    description:
        'Golu runs in, the ring closes, and you swing across your body. Time '
        'it well and the ball clears the neighbour\'s scooter. Leave the wide '
        'ones with your arms up, or block with a guard. Every delivery is '
        'seeded, so today\'s Super Over is the same for everyone.',
    genre: GameGenre.sports,
    accent: Color(0xFF00C2B8),
    deep: Color(0xFF0F3E39),
    icon: Icons.sports_cricket_rounded,
    minutes: '2–4 min',
    intensity: 'Light to moderate',
    stageNoun: 'Format',
    isNew: true,
    selfView: true,
    moves: [
      MoveInfo(Icons.sports_cricket_rounded, 'Swing'),
      MoveInfo(Icons.pan_tool_alt_rounded, 'Leave the ball'),
      MoveInfo(Icons.shield_rounded, 'Block'),
    ],
    howTo: [
      HowToStep(
        Icons.back_hand_rounded,
        'Backlift',
        'Hands together up by your back shoulder. Hold a moment.',
      ),
      HowToStep(
        Icons.sports_cricket_rounded,
        'Swing on the ring',
        'Sweep your hands across your body as the ring closes on the ball.',
      ),
      HowToStep(
        Icons.pan_tool_alt_rounded,
        'Leave the wides',
        'Arms up for a wide and you earn the extra run.',
      ),
    ],
    comfort:
        'Swings stay in front of your body, never toward the phone. '
        'Clear about two metres of space around you.',
  ),
  GameInfo(
    id: 'pataka-pose',
    title: 'Pataka Pose',
    tagline: 'Freeze in the shape before it reaches you.',
    description:
        'A glowing firecracker cut-out flies in. Strike its shape, hold it, '
        'and it bursts into confetti. Coach Kavi hosts and teases the frame, '
        'never you. Pass the Pataka turns one phone into a game night for '
        'friends taking turns.',
    genre: GameGenre.party,
    extraGenre: GameGenre.arcade,
    accent: Color(0xFFB98CFF),
    deep: Color(0xFF2B2F77),
    icon: Icons.celebration_rounded,
    minutes: '2–3 min',
    intensity: 'Light',
    stageNoun: 'Show',
    isNew: true,
    selfView: true,
    moves: [
      MoveInfo(Icons.accessibility_new_rounded, 'Hold a shape'),
      MoveInfo(Icons.self_improvement_rounded, 'Balance'),
      MoveInfo(Icons.pause_circle_rounded, 'Freeze'),
    ],
    howTo: [
      HowToStep(
        Icons.photo_size_select_actual_rounded,
        'Read the frame',
        'Kavi calls the pose as the frame appears on the horizon.',
      ),
      HowToStep(
        Icons.accessibility_new_rounded,
        'Strike and hold',
        'Matched limbs glow green. Hold until the ring fills.',
      ),
      HowToStep(
        Icons.groups_rounded,
        'Pass the Pataka',
        'Party mode: four frames each, then the next friend steps in.',
      ),
    ],
    comfort: 'Balance shapes are optional and you can hold a wall or chair any time.',
  ),
  GameInfo(
    id: 'lumen',
    title: 'LUMEN: Orbital Architect',
    tagline: 'Restore a garden in orbit, one route at a time.',
    description:
        'An abandoned ring habitat waits above the Earth. Reach to a tool card '
        'to pick a conduit, lean to turn it, and when the energy route '
        'connects, a comfortable bend welds it. Water flows, lights wake and '
        'plants unfold. Thinking takes no game time, and nothing runs out.',
    genre: GameGenre.puzzle,
    accent: Color(0xFF7FD8FF),
    deep: Color(0xFF0E1B33),
    icon: Icons.blur_circular_rounded,
    minutes: '4–6 min',
    intensity: 'Light',
    stageNoun: 'Habitat',
    isNew: true,
    moves: [
      MoveInfo(Icons.back_hand_rounded, 'Reach to choose'),
      MoveInfo(Icons.swap_horiz_rounded, 'Lean to turn'),
      MoveInfo(Icons.south_rounded, 'Bend to weld'),
    ],
    howTo: [
      HowToStep(
        Icons.looks_one_rounded,
        'Choose a tool card',
        'Reach to card 1, 2 or 3 below shoulder height and hold a moment.',
      ),
      HowToStep(
        Icons.rotate_right_rounded,
        'Lean to turn',
        'Lean right to turn the conduit clockwise, left to turn it back.',
      ),
      HowToStep(
        Icons.bolt_rounded,
        'Weld the route',
        'When it connects, lower your arms, then a comfortable bend welds it.',
      ),
    ],
    comfort: 'Feet stay planted. Rest your arms between repairs for as long as you like.',
  ),
];

GameInfo? gameById(String id) {
  for (final g in games) {
    if (g.id == id) return g;
  }
  return null;
}
