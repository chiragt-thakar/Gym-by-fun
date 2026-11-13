import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../game/forest_game.dart';

import 'package:game_director/game_director.dart';

class ExplorerPortrait extends StatelessWidget {
  const ExplorerPortrait({super.key, required this.look});
  final HeroLook look;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _ExplorerPortraitPainter(look),
    child: const SizedBox(width: 140, height: 140),
  );
}

class _ExplorerPortraitPainter extends CustomPainter {
  const _ExplorerPortraitPainter(this.look);
  final HeroLook look;
  @override
  void paint(Canvas c, Size size) {
    // Reuse the actual game character art at a larger scale for selection.
    c.save();
    c.translate(size.width * 0.5 - 110, -430);
    ForestPainter(
      size: const Size(220, 650),
      t: 0,
      clockMs: 0,
      plan: const <PlannedEncounter>[],
      heroLane: 1,
      ducking: false,
      armsUp: false,
      lanes: 3,
      warningMs: 2000,
      heroLook: look,
    ).paintExplorer(c);
    c.restore();
  }

  @override
  bool shouldRepaint(_ExplorerPortraitPainter old) => look != old.look;
}

/// Original, offline vector cover art. Static and isolated from the game
/// loop: no textures, downloads, camera pixels or animation work per frame.
class WorldVista extends StatelessWidget {
  const WorldVista({super.key, required this.theme, this.restored = true});
  final SceneTheme theme;
  final bool restored;
  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _WorldVistaPainter(theme, restored),
      child: const SizedBox.expand(),
    ),
  );
}

class _WorldVistaPainter extends CustomPainter {
  _WorldVistaPainter(this.theme, this.restored);
  final SceneTheme theme;
  final bool restored;
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final neon = theme == SceneTheme.neon;
    final mountain = theme == SceneTheme.mountain;
    final desert = theme == SceneTheme.desert;
    final accent = neon
        ? Lantern.scarf
        : desert
        ? Lantern.glow
        : mountain
        ? const Color(0xFFB9DBFF)
        : Lantern.scarf;
    final sky = neon
        ? const Color(0xFF19132E)
        : desert
        ? const Color(0xFF593C42)
        : const Color(0xFF142D32);
    final rect = Offset.zero & s;
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [sky, theme.hillFar],
        ).createShader(rect),
    );
    final stars = Paint()..color = Lantern.parchment.withValues(alpha: 0.55);
    for (var i = 0; i < 22; i++) {
      c.drawCircle(
        Offset(
          ((i * 73 + 29) % 997) / 997 * w,
          ((i * 47 + 13) % 97) / 97 * h * 0.56,
        ),
        i % 3 == 0 ? 1.4 : 0.7,
        stars,
      );
    }
    final moon = Offset(w * 0.77, h * 0.26);
    c.drawCircle(
      moon,
      h * 0.27,
      Paint()
        ..shader = RadialGradient(
          colors: [accent.withValues(alpha: 0.18), accent.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: moon, radius: h * 0.27)),
    );
    c.drawCircle(moon, h * 0.085, Paint()..color = const Color(0xFFFCE4B8));
    for (var layer = 0; layer < 3; layer++) {
      final path = Path()..moveTo(0, h);
      if (mountain) {
        path.lineTo(-w * 0.1, h * 0.85);
        for (var i = 0; i < 6; i++) {
          path.lineTo(w * (i / 5), h * (0.28 + layer * 0.17 + (i % 2) * 0.2));
        }
      } else {
        for (var x = 0.0; x <= w + 8; x += 8) {
          path.lineTo(
            x,
            h * (0.54 + layer * 0.15) +
                math.sin(x / w * 7 + layer * 1.9) * h * 0.09,
          );
        }
      }
      path
        ..lineTo(w, h)
        ..close();
      c.drawPath(
        path,
        Paint()
          ..color = Color.lerp(
            theme.hillFar,
            Lantern.night,
            0.28 + layer * 0.24,
          )!,
      );
    }
    if (neon) {
      for (var i = 0; i < 12; i++) {
        final x = w * i / 11;
        final bh = h * (0.18 + (i * 7 % 5) * 0.055);
        c.drawRect(
          Rect.fromLTWH(x, h * 0.8 - bh, w * 0.06, bh),
          Paint()..color = const Color(0xFF121D2C),
        );
        for (var j = 0; j < 4; j++) {
          c.drawRect(
            Rect.fromLTWH(x + 4, h * 0.8 - bh + 8 + j * 9, 3, 3),
            Paint()..color = accent.withValues(alpha: 0.65),
          );
        }
      }
    } else if (!desert) {
      for (var i = 0; i < 9; i++) {
        final x = w * i / 8;
        final th = h * (0.2 + (i % 3) * 0.05);
        final path = Path()
          ..moveTo(x, h * 0.88 - th)
          ..lineTo(x - th * 0.32, h * 0.88)
          ..lineTo(x + th * 0.32, h * 0.88)
          ..close();
        c.drawPath(path, Paint()..color = const Color(0xFF0B201E));
      }
    }
    // A winding lantern trail pulls the eye into the scene.
    final trail = Path()
      ..moveTo(w * 0.47, h * 1.06)
      ..cubicTo(w * 0.95, h * 0.82, w * 0.21, h * 0.78, w * 0.61, h * 0.53);
    c.drawPath(
      trail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = h * 0.045
        ..color = accent.withValues(alpha: 0.14),
    );
    c.drawPath(
      trail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.5
        ..color = accent.withValues(alpha: 0.5),
    );
    for (var i = 0; i < 7; i++) {
      final x = w * (0.13 + i * 0.12);
      final y = h * (0.68 + math.sin(i * 1.3) * 0.13);
      if (restored) {
        c.drawCircle(
          Offset(x, y),
          11,
          Paint()
            ..shader = RadialGradient(
              colors: [
                Lantern.glow.withValues(alpha: 0.36),
                Lantern.glow.withValues(alpha: 0),
              ],
            ).createShader(Rect.fromCircle(center: Offset(x, y), radius: 11)),
        );
      }
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, y), width: 4, height: 6),
          const Radius.circular(1),
        ),
        Paint()..color = restored ? Lantern.glow : Lantern.ridge,
      );
    }
  }

  @override
  bool shouldRepaint(_WorldVistaPainter old) =>
      old.theme != theme || old.restored != restored;
}

/// The shell backdrop: quiet ink with two soft glows (volt top right, aqua
/// bottom left) and a few thin arcs sweeping across, like the trail of a
/// moving limb. Static: the shaders and the arc path are built once per
/// size and nothing animates, so it costs nothing behind a scrolling list.
///
/// (The class keeps its original name; every page already uses it.)
class ForestBackdrop extends StatelessWidget {
  const ForestBackdrop({super.key});

  static final _painter = ForestBackdropPainter();

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(painter: _painter, child: const SizedBox.expand()),
  );
}

class ForestBackdropPainter extends CustomPainter {
  Size? _size;
  late Path _arcs;
  final Paint _voltGlow = Paint();
  final Paint _aquaGlow = Paint();

  static final _arcPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = const Color(0x12F3F5F7);

  void _build(Size s) {
    _size = s;
    final w = s.width, h = s.height;
    _voltGlow.shader =
        RadialGradient(
          colors: [Jn.volt.withAlpha(30), Jn.volt.withAlpha(0)],
        ).createShader(
          Rect.fromCircle(center: Offset(w * 0.92, h * 0.04), radius: w * 0.8),
        );
    _aquaGlow.shader =
        RadialGradient(
          colors: [Jn.aqua.withAlpha(20), Jn.aqua.withAlpha(0)],
        ).createShader(
          Rect.fromCircle(center: Offset(w * 0.02, h * 0.98), radius: w * 0.9),
        );
    // Concentric arcs around a point below the bottom-left corner.
    final centre = Offset(-w * 0.15, h * 1.05);
    final path = Path();
    for (var i = 0; i < 6; i++) {
      final r = w * (0.55 + i * 0.22);
      path.addArc(
        Rect.fromCircle(center: centre, radius: r),
        -math.pi / 2,
        math.pi / 2,
      );
    }
    _arcs = path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (_size != size) _build(size);
    final rect = Offset.zero & size;
    canvas
      ..drawRect(rect, _voltGlow)
      ..drawRect(rect, _aquaGlow)
      ..drawPath(_arcs, _arcPaint);
  }

  // Static: paint() rebuilds its cache when the size changes.
  @override
  bool shouldRepaint(ForestBackdropPainter old) => old != this;
}
