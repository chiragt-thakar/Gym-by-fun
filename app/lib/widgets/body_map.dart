import 'package:flutter/material.dart';

import '../game/stage_info.dart';
import '../l10n/tr.dart';
import '../services/settings.dart';

/// Strong colour + diagonal hatching for the main focus; light colour + dots
/// for areas that also work. Pattern and labels carry the meaning too, so the
/// map reads without colour.
const bodyMapPrimary = Color(0xFFE8743B);
const bodyMapSecondary = Color(0xFF8FC1E3);
const _silhouette = Color(0xFF55606E);
const _outline = Color(0xFF2A313A);
const _hair = Color(0xFF3B3430);
const _ink = Color(0xFF1C1F24);

/// Unit space for all geometry; scaled to fit at paint time.
const _w = 100.0;
const _h = 200.0;

/// An original, stylised front-view body diagram.
class BodyMap extends StatelessWidget {
  const BodyMap({
    super.key,
    required this.style,
    required this.primary,
    required this.secondary,
    this.height = 260,
    this.showLegend = true,
  });

  final BodyStyle style;
  final List<BodyRegion> primary;
  final List<BodyRegion> secondary;
  final double height;
  final bool showLegend;

  @override
  Widget build(BuildContext context) {
    final label =
        '${tr('Main focus')}: ${primary.map((r) => tr(r.label)).join(', ')}. '
        '${tr('Also works')}: ${secondary.map((r) => tr(r.label)).join(', ')}.';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: label,
          image: true,
          child: SizedBox(
            height: height,
            width: height / 2,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: BodyMapPainter(
                  style: style,
                  primary: primary,
                  secondary: secondary,
                ),
              ),
            ),
          ),
        ),
        if (showLegend) ...[const SizedBox(height: 8), const BodyMapLegend()],
      ],
    );
  }
}

class BodyMapLegend extends StatelessWidget {
  const BodyMapLegend({super.key});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16,
    runSpacing: 6,
    alignment: WrapAlignment.center,
    children: [
      _LegendItem(primary: true, text: tr('Main focus')),
      _LegendItem(primary: false, text: tr('Also works')),
    ],
  );
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.primary, required this.text});
  final bool primary;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(
        width: 22,
        height: 22,
        child: CustomPaint(painter: _SwatchPainter(primary)),
      ),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 15)),
    ],
  );
}

class _SwatchPainter extends CustomPainter {
  const _SwatchPainter(this.primary);
  final bool primary;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    final path = Path()..addRRect(rect);
    _paintRegion(canvas, path, primary, size.width / 22);
    canvas.drawRRect(rect, _swatchEdge);
  }

  static final _swatchEdge = Paint()
    ..style = PaintingStyle.stroke
    ..color = _outline;

  @override
  bool shouldRepaint(_SwatchPainter old) => old.primary != primary;
}

final _hatch = _buildHatch();
final _dots = _buildDots();

Path _buildHatch() {
  final p = Path();
  for (var x = -_h; x < _w + _h; x += 3.2) {
    p
      ..moveTo(x, 0)
      ..lineTo(x + _h, _h);
  }
  return p;
}

Path _buildDots() {
  final p = Path();
  for (var y = 1.5; y < _h; y += 3.6) {
    for (var x = 1.5; x < _w; x += 3.6) {
      p.addOval(Rect.fromCircle(center: Offset(x, y), radius: 0.7));
    }
  }
  return p;
}

// Paints are created once; only the hatch stroke width varies per call.
final _primaryFill = Paint()..color = bodyMapPrimary;
final _secondaryFill = Paint()..color = bodyMapSecondary;
final _hatchPaint = Paint()
  ..style = PaintingStyle.stroke
  ..color = _ink.withValues(alpha: 0.55);
final _dotsPaint = Paint()..color = _ink.withValues(alpha: 0.45);
final _primaryEdge = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.0
  ..color = _ink;
final _secondaryEdge = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 0.6
  ..color = _ink;
final _outlinePaint = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.0
  ..color = _outline;
final _hairPaint = Paint()..color = _hair;
final _silhouettePaint = Paint()..color = _silhouette;

void _paintRegion(Canvas canvas, Path region, bool primary, double unit) {
  canvas.drawPath(region, primary ? _primaryFill : _secondaryFill);
  canvas
    ..save()
    ..clipPath(region);
  if (primary) {
    canvas.drawPath(
      _hatch,
      _hatchPaint..strokeWidth = 0.9 / unit.clamp(0.2, 10),
    );
  } else {
    canvas.drawPath(_dots, _dotsPaint);
  }
  canvas.restore();
  canvas.drawPath(region, primary ? _primaryEdge : _secondaryEdge);
}

/// Paths are built once per style and reused; repaint only when the style or
/// highlighted regions change.
class BodyMapPainter extends CustomPainter {
  const BodyMapPainter({
    required this.style,
    required this.primary,
    required this.secondary,
  });

  final BodyStyle style;
  final List<BodyRegion> primary;
  final List<BodyRegion> secondary;

  static final _cache = <BodyStyle, _Geometry>{};

  static _Geometry _geometryFor(BodyStyle style) =>
      _cache.putIfAbsent(style, () => _Geometry(style));

  @override
  void paint(Canvas canvas, Size size) {
    final g = _geometryFor(style);
    final scale = (size.width / _w) < (size.height / _h)
        ? size.width / _w
        : size.height / _h;
    canvas
      ..save()
      ..translate((size.width - _w * scale) / 2, (size.height - _h * scale) / 2)
      ..scale(scale);

    if (g.hairBack != null) {
      canvas.drawPath(g.hairBack!, _hairPaint);
    }
    canvas
      ..drawPath(g.body, _silhouettePaint)
      ..drawPath(g.body, _outlinePaint)
      ..drawPath(g.hairFront, _hairPaint);

    for (final r in secondary) {
      if (primary.contains(r)) continue;
      _paintRegion(canvas, g.regions[r]!, false, 1);
    }
    for (final r in primary) {
      _paintRegion(canvas, g.regions[r]!, true, 1);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(BodyMapPainter old) =>
      old.style != style ||
      !_sameList(old.primary, primary) ||
      !_sameList(old.secondary, secondary);
}

bool _sameList(List<BodyRegion> a, List<BodyRegion> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Simple stylised shapes. Styles differ only in shoulder, waist and hip
/// width and hair silhouette.
class _Geometry {
  _Geometry(BodyStyle style) {
    final (sh, waist, hip) = switch (style) {
      BodyStyle.neutral => (22.0, 15.0, 18.0),
      BodyStyle.female => (19.0, 13.0, 20.0),
      BodyStyle.male => (25.0, 16.5, 17.0),
    };
    const cx = _w / 2;
    final b = Path()
      // Head and neck.
      ..addOval(
        Rect.fromCenter(center: const Offset(cx, 18), width: 20, height: 24),
      )
      ..addRect(const Rect.fromLTRB(cx - 5, 27, cx + 5, 37));
    // Torso.
    b.addPath(
      Path()
        ..moveTo(cx - sh, 42)
        ..quadraticBezierTo(cx - sh + 2, 36, cx - 6, 35)
        ..lineTo(cx + 6, 35)
        ..quadraticBezierTo(cx + sh - 2, 36, cx + sh, 42)
        ..quadraticBezierTo(cx + waist + 2, 64, cx + waist, 82)
        ..quadraticBezierTo(cx + hip + 1, 92, cx + hip, 106)
        ..lineTo(cx - hip, 106)
        ..quadraticBezierTo(cx - hip - 1, 92, cx - waist, 82)
        ..quadraticBezierTo(cx - waist - 2, 64, cx - sh, 42)
        ..close(),
      Offset.zero,
    );
    for (final side in const [-1.0, 1.0]) {
      final ax = cx + side * sh;
      // Arm and hand.
      b
        ..addPath(
          _poly([
            Offset(ax - side * 1, 42),
            Offset(ax + side * 8, 46),
            Offset(ax + side * 12, 118),
            Offset(ax + side * 5, 118),
          ]),
          Offset.zero,
        )
        ..addOval(
          Rect.fromCircle(center: Offset(ax + side * 8.5, 123), radius: 4.5),
        )
        // Leg and foot.
        ..addPath(
          _poly([
            Offset(cx + side * 1.5, 104),
            Offset(cx + side * hip, 104),
            Offset(cx + side * (hip - 6), 150),
            Offset(cx + side * 10, 188),
            Offset(cx + side * 4, 188),
            Offset(cx + side * 3, 150),
          ]),
          Offset.zero,
        )
        ..addOval(
          Rect.fromCenter(
            center: Offset(cx + side * 8, 191),
            width: 11,
            height: 6,
          ),
        );
    }
    body = b;

    switch (style) {
      case BodyStyle.female:
        hairBack = RRect.fromRectAndRadius(
          const Rect.fromLTRB(cx - 12.5, 6, cx + 12.5, 42),
          const Radius.circular(10),
        ).toPath();
        hairFront = Path()
          ..addArc(
            Rect.fromCenter(
              center: const Offset(cx, 17),
              width: 22,
              height: 24,
            ),
            3.3,
            2.82,
          )
          ..close();
      case BodyStyle.male:
        hairBack = null;
        hairFront = Path()
          ..addArc(
            Rect.fromCenter(
              center: const Offset(cx, 16),
              width: 21,
              height: 20,
            ),
            3.4,
            2.62,
          )
          ..close();
      case BodyStyle.neutral:
        hairBack = RRect.fromRectAndRadius(
          const Rect.fromLTRB(cx - 11.5, 6, cx + 11.5, 26),
          const Radius.circular(10),
        ).toPath();
        hairFront = Path()
          ..addArc(
            Rect.fromCenter(
              center: const Offset(cx, 16.5),
              width: 22,
              height: 22,
            ),
            3.25,
            2.92,
          )
          ..close();
    }

    Path mirror(Path left) => Path()
      ..addPath(left, Offset.zero)
      ..addPath(
        left.transform(
          (Matrix4.identity()
                ..translateByDouble(_w, 0, 0, 1)
                ..scaleByDouble(-1, 1, 1, 1))
              .storage,
        ),
        Offset.zero,
      );

    regions = {
      BodyRegion.shoulders: mirror(
        Path()..addOval(
          Rect.fromCircle(center: Offset(cx - sh + 1.5, 44), radius: 6),
        ),
      ),
      BodyRegion.upperBack: mirror(
        _poly([
          const Offset(cx - 5.5, 33),
          Offset(cx - sh + 5, 38.5),
          const Offset(cx - 6, 40),
        ]),
      ),
      BodyRegion.arms: mirror(
        _poly([
          Offset(cx - sh - 7.5, 54),
          Offset(cx - sh - 0.5, 54),
          Offset(cx - sh - 4.5, 115),
          Offset(cx - sh - 11.5, 115),
        ]),
      ),
      BodyRegion.core: RRect.fromRectAndRadius(
        const Rect.fromLTRB(cx - 7, 52, cx + 7, 96),
        const Radius.circular(4),
      ).toPath(),
      BodyRegion.obliques: mirror(
        _poly([
          Offset(cx - sh + 5, 54),
          const Offset(cx - 8.5, 56),
          const Offset(cx - 8.5, 94),
          Offset(cx - waist - 0.5, 92),
          Offset(cx - waist + 1, 80),
        ]),
      ),
      BodyRegion.glutes: mirror(
        Path()..addOval(
          Rect.fromCenter(
            center: Offset(cx - hip * 0.45, 100),
            width: hip * 0.7,
            height: 9,
          ),
        ),
      ),
      BodyRegion.hipAbductors: mirror(
        Path()..addOval(
          Rect.fromCenter(
            center: Offset(cx - hip + 2.5, 106),
            width: 5,
            height: 16,
          ),
        ),
      ),
      BodyRegion.quads: mirror(
        _poly([
          Offset(cx - hip + 2, 110),
          const Offset(cx - 6, 110),
          const Offset(cx - 6.5, 146),
          Offset(cx - hip + 6.5, 146),
        ]),
      ),
      BodyRegion.hamstrings: mirror(
        _poly([
          const Offset(cx - 5, 112),
          const Offset(cx - 2, 112),
          const Offset(cx - 3, 146),
          const Offset(cx - 5.5, 146),
        ]),
      ),
      BodyRegion.calves: mirror(
        _poly([
          Offset(cx - hip + 6, 156),
          const Offset(cx - 3.5, 156),
          const Offset(cx - 4.5, 182),
          const Offset(cx - 9.5, 182),
        ]),
      ),
    };
  }

  late final Path body;
  late final Path? hairBack;
  late final Path hairFront;
  late final Map<BodyRegion, Path> regions;
}

Path _poly(List<Offset> pts) => Path()..addPolygon(pts, true);

extension on RRect {
  Path toPath() => Path()..addRRect(this);
}
