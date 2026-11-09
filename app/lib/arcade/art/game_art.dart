import 'package:flutter/material.dart';

import '../../game/forest_game.dart' show SceneTheme;
import '../../widgets/forest_backdrop.dart' show WorldVista;
import 'cricket_art.dart';
import 'duel_art.dart';
import 'lumen_art.dart';
import 'mela_art.dart';
import 'pataka_art.dart';
import 'taal_art.dart';

/// Original, offline preview art for a game. [variant] picks one of four
/// scenes (stages / moments). Static: painted once, no camera, no assets.
class GameArt extends StatelessWidget {
  const GameArt({
    super.key,
    required this.gameId,
    this.variant = 0,
    this.guardianArt,
    this.habitat,
  });
  final String gameId;
  final int variant;

  /// Craftguard: which guardian to draw.
  final String? guardianArt;

  /// LUMEN: show the player's own habitat with these modules restored.
  final Set<String>? habitat;

  @override
  Widget build(BuildContext context) {
    if (gameId == 'adventure') {
      return WorldVista(
        theme: const [
          SceneTheme.forest,
          SceneTheme.desert,
          SceneTheme.neon,
          SceneTheme.mountain,
        ][variant % 4],
      );
    }
    return RepaintBoundary(
      child: CustomPaint(
        painter: _ArtPainter(gameId, variant % 4, guardianArt, habitat),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.gameId, this.variant, this.guardian, this.habitat);
  final String gameId;
  final int variant;
  final String? guardian;
  final Set<String>? habitat;

  @override
  void paint(Canvas c, Size s) {
    c.clipRect(Offset.zero & s);
    final h = habitat;
    if (h != null) {
      paintHabitat(c, s, h, 1.5);
      return;
    }
    switch (gameId) {
      case 'mirror-mela':
        melaPreview(c, s, variant);
      case 'pataka-pose':
        patakaPreview(c, s, variant);
      case 'craftguard':
        duelPreview(c, s, variant, art: guardian ?? 'baoli');
      case 'taal-toofan':
        taalPreview(c, s, variant);
      case 'tapeball':
        cricketPreview(c, s, variant);
      case 'lumen':
        lumenPreview(c, s, variant);
    }
  }

  @override
  bool shouldRepaint(_ArtPainter old) =>
      old.gameId != gameId ||
      old.variant != variant ||
      old.guardian != guardian ||
      old.habitat?.length != habitat?.length;
}

/// Captions for the four preview scenes of each game.
List<String> previewCaptions(String gameId) => switch (gameId) {
  'adventure' => const [
    'World 1 · Forest Awakening',
    'World 2 · Desert Trials',
    'World 3 · Neon City',
    'World 4 · Mountain Expedition',
  ],
  'mirror-mela' => const [
    'Bubble Bazaar: reach as the ring closes',
    'Right hand for diamonds',
    'Orbit: duck under the cloud sweep',
    "Baadal's Storm",
  ],
  'pataka-pose' => const [
    'A frame flies in from the horizon',
    'Hold the shape until the ring fills',
    'Burst it: Pataka!',
    'Mela Night under the fireworks',
  ],
  'craftguard' => const [
    'Guard on the count',
    'Lean away from the ledge drop',
    'Stagger! Strike the side pads',
    'Charge to calm the guardian',
  ],
  'taal-toofan' => const [
    'Cards land where the move happens',
    'Wave out to the side',
    'Taali on the beat',
    'Toofan Time: arms up!',
  ],
  'tapeball' => const [
    'Golu runs in',
    'Leave the wide: arms up',
    'Timed it. Six!',
    'Evening nets in the gully',
  ],
  'lumen' => const [
    'Reach to a tool card',
    'Lean to turn the conduit',
    'Connected: bend to weld',
    'Your conservatory comes back to life',
  ],
  _ => const ['', '', '', ''],
};
