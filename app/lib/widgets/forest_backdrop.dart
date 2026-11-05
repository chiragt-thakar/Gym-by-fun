import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Procedural night-forest backdrop: a lantern glow, a few stars, two rows
/// of rolling hills and pine silhouettes. Everything is generated from a
/// fixed seed (always the same original scene) and the Paths are cached,
/// so they are rebuilt only when the size changes. Nothing animates.
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
  late Path _farHills;
  late Path _nearHills;
  late Path _farTrees;
  late Path _nearTrees;
  late List<Offset> _stars;
  final Paint _glowPaint = Paint();

  static final _farHillPaint = Paint()..color = const Color(0xFF12241B);
  static final _farTreePaint = Paint()..color = const Color(0xFF16301F);
  static final _nearHillPaint = Paint()..color = const Color(0xFF0E1D16);
  static final _nearTreePaint = Paint()..color = const Color(0xFF09140F);
  static final _starPaint = Paint()..color = const Color(0x66F6EEDC);

  void _build(Size s) {
    _size = s;
    final rnd = math.Random(7);
    final w = s.width, h = s.height;
    Path hills(double base, double amp, double waves, double phase) {
      final p = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 12) {
        final y =
            base -
            amp * math.sin(x / w * math.pi * waves + phase) -
            amp * 0.4 * math.sin(x / w * math.pi * waves * 2.3 + phase);
        p.lineTo(x, y);
      }
      return p
        ..lineTo(w, h)
        ..close();
    }

    double hillY(double x, double base, double amp, double waves, double ph) =>
        base -
        amp * math.sin(x / w * math.pi * waves + ph) -
        amp * 0.4 * math.sin(x / w * math.pi * waves * 2.3 + ph);

    Path trees(double base, double amp, double waves, double ph, double sz) {
      final p = Path();
      var x = rnd.nextDouble() * sz;
      while (x < w + sz) {
        final th = sz * (0.8 + rnd.nextDouble() * 0.7);
        final tw = th * 0.42;
        final y = hillY(x, base, amp, waves, ph) + 4;
        // Three stacked rounded tiers: a chunky, friendly pine.
        for (var t = 0; t < 3; t++) {
          final top = y - th + t * th * 0.24;
          final half = tw * (0.55 + t * 0.25);
          final bottom = top + th * 0.42;
          p
            ..moveTo(x, top)
            ..quadraticBezierTo(
              x + half * 0.3,
              top + th * 0.1,
              x + half,
              bottom,
            )
            ..quadraticBezierTo(x, bottom + th * 0.06, x - half, bottom)
            ..quadraticBezierTo(x - half * 0.3, top + th * 0.1, x, top)
            ..close();
        }
        p.addRect(
          Rect.fromLTWH(x - tw * 0.08, y - th * 0.2, tw * 0.16, th * 0.3),
        );
        x += tw * (0.9 + rnd.nextDouble() * 1.6);
      }
      return p;
    }

    final farBase = h * 0.80, nearBase = h * 0.90;
    _farHills = hills(farBase, h * 0.03, 2.2, 0.6);
    _farTrees = trees(farBase, h * 0.03, 2.2, 0.6, h * 0.09);
    _nearHills = hills(nearBase, h * 0.025, 1.6, 2.1);
    _nearTrees = trees(nearBase, h * 0.025, 1.6, 2.1, h * 0.13);
    _stars = [
      for (var i = 0; i < 26; i++)
        Offset(rnd.nextDouble() * w, rnd.nextDouble() * h * 0.45),
    ];
    _glowPaint.shader =
        RadialGradient(
          colors: [Lantern.glow.withAlpha(46), Lantern.glow.withAlpha(0)],
        ).createShader(
          Rect.fromCircle(center: Offset(w * 0.85, h * 0.08), radius: w * 0.7),
        );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    if (_size != size) _build(size);
    canvas.drawRect(Offset.zero & size, _glowPaint);
    for (final s in _stars) {
      canvas.drawCircle(s, 1.6, _starPaint);
    }
    canvas
      ..drawPath(_farHills, _farHillPaint)
      ..drawPath(_farTrees, _farTreePaint)
      ..drawPath(_nearHills, _nearHillPaint)
      ..drawPath(_nearTrees, _nearTreePaint);
  }

  // The scene is static; Flutter repaints on size change via the
  // RepaintBoundary/layout anyway, and paint() rebuilds the cache then.
  @override
  bool shouldRepaint(ForestBackdropPainter old) => old != this;
}
