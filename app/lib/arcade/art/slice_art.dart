import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';

import 'paint_kit.dart';

// NEON SLICE: a rain-dark arcade alley. Magenta and cyan signs, a wet floor
// that mirrors them, and fruit that glows from inside.
const _magenta = Color(0xFFFF3D9A);
const _cyan = Color(0xFF2EE6FF);
const _volt = Color(0xFFC8F542);
const _violet = Color(0xFF8B7CFF);
const _ink = Color(0xFF07060F);

/// The player's kit in this game: a dark jacket with magenta seams.
const sliceLook = AvatarLook(
  skin: Color(0xFFB97F5E),
  hair: Color(0xFF16121C),
  top: Color(0xFF2A2440),
  bottom: Color(0xFF15131F),
  shoe: Color(0xFFEDEBFF),
  trim: _magenta,
  hairStyle: HairStyle.crop,
);

/// Body colour of each fruit design (0..4) and the prism.
const _fruitColours = [
  Color(0xFFFF7A2F), // ember orange
  Color(0xFFB8F04A), // volt lime
  Color(0xFFFF3D9A), // plasma berry
  Color(0xFF2EE6C8), // aqua melon
  Color(0xFFFFD23F), // sun pear
];

Color sliceColour(int look) => look >= 5
    ? const Color(0xFFE9F6FF)
    : _fruitColours[look % _fruitColours.length];

/// The alley. [heat] 0..2 is the round's act: the signs burn brighter and
/// the floor runs faster as it climbs.
void sliceBackdrop(
  Canvas c,
  Size s,
  double t, {
  int heat = 0,
  bool frenzy = false,
}) {
  sky(
    c,
    s,
    const [_ink, Color(0xFF160B2B), Color(0xFF2A0F3A)],
    stops: const [0, 0.5, 1],
  );
  final horizon = s.height * 0.62;

  // Far skyline: dark towers with a few lit windows.
  final tower = Paint()..color = const Color(0xFF0D0A1C);
  final window = Paint();
  var x = -10.0;
  var i = 0;
  while (x < s.width) {
    final w = s.width * (0.08 + 0.1 * hash(i * 5 + 1));
    final h = s.height * (0.16 + 0.26 * hash(i * 5 + 2));
    final rect = Rect.fromLTWH(x, horizon - h, w, h);
    c.drawRect(rect, tower);
    for (var k = 0; k < 7; k++) {
      if (hash(i * 31 + k) < 0.45) continue;
      window.color = [_magenta, _cyan, _volt, _violet][(i + k) % 4].withValues(
        alpha: 0.35 + 0.3 * hash(i * 13 + k),
      );
      c.drawRect(
        Rect.fromLTWH(
          rect.left + w * (0.15 + 0.5 * hash(i * 7 + k)),
          rect.top + h * (0.1 + 0.11 * k),
          w * 0.16,
          3,
        ),
        window,
      );
    }
    x += w + 4;
    i++;
  }

  // Three neon signs: tube frames that flicker a little.
  final boost = 1 + 0.25 * heat;
  void sign(Rect r, Color col, int seed) {
    final on =
        (0.72 + 0.28 * math.sin(t * (2.1 + seed) + seed * 1.7)) *
        (hash((t * 3).floor() + seed) > 0.06 ? 1 : 0.35);
    glow(c, r.center, r.longestSide * 0.9, col, alpha: 0.22 * on * boost);
    final rr = RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * 0.3));
    c.drawRRect(
      rr,
      Paint()
        ..color = col.withValues(alpha: (0.55 * on).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    c.drawRRect(
      rr,
      Paint()
        ..color = Colors.white.withValues(alpha: (0.7 * on).clamp(0.0, 1.0))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  sign(
    Rect.fromLTWH(s.width * 0.06, s.height * 0.14, s.width * 0.26, s.height * 0.07),
    _magenta,
    1,
  );
  sign(
    Rect.fromLTWH(s.width * 0.66, s.height * 0.2, s.width * 0.28, s.height * 0.055),
    _cyan,
    2,
  );
  sign(
    Rect.fromLTWH(s.width * 0.4, s.height * 0.08, s.width * 0.18, s.height * 0.045),
    _volt,
    3,
  );
  lightShaft(c, Offset(s.width * 0.19, s.height * 0.21), s.height * 0.5, s.width * 0.22, _magenta, alpha: 0.1 * boost);
  lightShaft(c, Offset(s.width * 0.8, s.height * 0.26), s.height * 0.45, s.width * 0.2, _cyan, alpha: 0.1 * boost);

  // Wet floor: perspective lines running towards the player, and the
  // signs smeared into it.
  perspectiveFloor(
    c,
    s,
    horizon,
    near: const Color(0xFF120A20),
    far: const Color(0xFF2B1242),
    line: _cyan.withValues(alpha: 0.16),
    scroll: t * (0.25 + 0.18 * heat),
  );
  for (final (fx, col) in [(0.19, _magenta), (0.8, _cyan), (0.49, _volt)]) {
    final r = Rect.fromLTWH(
      s.width * fx - s.width * 0.05,
      horizon,
      s.width * 0.1,
      s.height - horizon,
    );
    c.drawRect(
      r,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [col.withValues(alpha: 0.26), col.withValues(alpha: 0)],
        ).createShader(r),
    );
  }

  // Thin rain, far behind the action.
  final rain = Paint()
    ..color = const Color(0x22C9D6FF)
    ..strokeWidth = 1;
  for (var k = 0; k < 26; k++) {
    final rx = hash(k * 3 + 9) * s.width;
    final ry = ((hash(k * 11 + 4) + t * (0.9 + 0.5 * hash(k))) % 1) * horizon;
    c.drawLine(Offset(rx, ry), Offset(rx - 3, ry + 14), rain);
  }

  vignette(c, s, strength: 0.6);
  if (frenzy) {
    c.drawRect(
      (Offset.zero & s).deflate(5),
      Paint()
        ..color = _volt.withValues(alpha: 0.35 + 0.25 * math.sin(t * 9))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );
  }
}

/// One whole fruit (or prism, or mine) at [at], radius [r], turned by
/// [turn] radians.
void _fruit(Canvas c, Offset at, double r, SliceTarget tg, double turn, double t) {
  if (tg.isBomb) {
    _mine(c, at, r, t + tg.id);
    return;
  }
  final look = tg.kind == SliceKind.prism ? 5 : tg.look;
  final col = tg.golden ? const Color(0xFFFFD86B) : sliceColour(look);
  glow(c, at, r * 2.1, col, alpha: 0.38);
  c.save();
  c.translate(at.dx, at.dy);
  c.rotate(turn);
  _fruitBody(c, r, look, col);
  c.restore();
  if (tg.golden) {
    c.drawPath(
      starPath(at, r * 0.42),
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }
}

/// The fruit itself, centred on the origin. Each design has its own
/// silhouette detail so they are told apart by shape, not only colour.
void _fruitBody(Canvas c, double r, int look, Color col) {
  final dark = Paint()..color = const Color(0xCC07060F);
  if (look == 5) {
    // Prism: a cut gem.
    final gem = Path();
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      final p = Offset(math.cos(a) * r, math.sin(a) * r);
      i == 0 ? gem.moveTo(p.dx, p.dy) : gem.lineTo(p.dx, p.dy);
    }
    gem.close();
    c.drawPath(gem, Paint()..color = const Color(0xCC07060F)..style = PaintingStyle.stroke..strokeWidth = 5);
    c.drawPath(
      gem,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFF7FE9FF), Color(0xFF8B7CFF), Color(0xFFFF7ACB)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: r)),
    );
    final facet = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..strokeWidth = 1.4;
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      c.drawLine(Offset.zero, Offset(math.cos(a) * r, math.sin(a) * r), facet);
    }
    return;
  }
  if (look == 4) {
    // Pear: a small top lobe on a round body.
    c.drawCircle(Offset(0, -r * 0.55), r * 0.58, dark);
    glossSphere(c, Offset(0, -r * 0.55), r * 0.5, col);
  }
  c.drawCircle(Offset.zero, r + 2.5, dark);
  glossSphere(c, Offset.zero, r, col);
  final detail = Paint()
    ..color = shade(col, -0.45).withValues(alpha: 0.55)
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.2, r * 0.07)
    ..strokeCap = StrokeCap.round;
  switch (look) {
    case 0:
      // Orange: a dimpled crown.
      for (var i = 0; i < 5; i++) {
        final a = -math.pi / 2 + (i - 2) * 0.32;
        c.drawLine(
          Offset(math.cos(a) * r * 0.35, math.sin(a) * r * 0.35 - r * 0.25),
          Offset(math.cos(a) * r * 0.62, math.sin(a) * r * 0.62 - r * 0.25),
          detail,
        );
      }
    case 1:
      // Lime: segment lines from the centre.
      for (var i = 0; i < 6; i++) {
        final a = i * math.pi / 3 + 0.3;
        c.drawLine(Offset.zero, Offset(math.cos(a) * r * 0.78, math.sin(a) * r * 0.78), detail);
      }
    case 2:
      // Berry: seeds.
      final seed = Paint()..color = const Color(0xFFFFE9A8).withValues(alpha: 0.85);
      for (var i = 0; i < 9; i++) {
        final a = i * 2.4;
        final d = r * (0.25 + 0.5 * hash(i + 3));
        c.drawOval(
          Rect.fromCenter(
            center: Offset(math.cos(a) * d, math.sin(a) * d),
            width: r * 0.1,
            height: r * 0.16,
          ),
          seed,
        );
      }
    case 3:
      // Melon: curved stripes.
      for (final k in [-0.5, 0.0, 0.5]) {
        c.drawArc(
          Rect.fromCenter(center: Offset(k * r, 0), width: r * 0.9, height: r * 1.9),
          -math.pi / 2,
          math.pi,
          false,
          detail,
        );
      }
  }
  // Stem and leaf.
  final top = Offset(0, -r * (look == 4 ? 1.05 : 0.95));
  c.drawLine(
    top,
    top + Offset(r * 0.08, -r * 0.28),
    Paint()
      ..color = const Color(0xFF3B2A1E)
      ..strokeWidth = math.max(2, r * 0.1)
      ..strokeCap = StrokeCap.round,
  );
  final leaf = Path()
    ..moveTo(top.dx + r * 0.08, top.dy - r * 0.2)
    ..quadraticBezierTo(top.dx + r * 0.55, top.dy - r * 0.6, top.dx + r * 0.7, top.dy - r * 0.12)
    ..quadraticBezierTo(top.dx + r * 0.35, top.dy - r * 0.05, top.dx + r * 0.08, top.dy - r * 0.2)
    ..close();
  c.drawPath(leaf, Paint()..color = const Color(0xFF58D68D));
}

/// A static mine: a dark core, a hot centre that throbs, short spikes and
/// arcs of current. Reads as "do not touch" by shape as well as colour.
void _mine(Canvas c, Offset at, double r, double t) {
  const hot = Color(0xFFFF4D3D);
  final pulse = 0.5 + 0.5 * math.sin(t * 9);
  glow(c, at, r * 2.2, hot, alpha: 0.25 + 0.2 * pulse);
  final spike = Paint()
    ..color = const Color(0xFF1B1622)
    ..strokeWidth = math.max(3, r * 0.2)
    ..strokeCap = StrokeCap.round;
  for (var i = 0; i < 8; i++) {
    final a = i * math.pi / 4 + t * 0.6;
    c.drawLine(
      at + Offset(math.cos(a) * r * 0.7, math.sin(a) * r * 0.7),
      at + Offset(math.cos(a) * r * 1.22, math.sin(a) * r * 1.22),
      spike,
    );
  }
  glossSphere(c, at, r * 0.92, const Color(0xFF2A2333));
  c.drawCircle(at, r * (0.3 + 0.08 * pulse), Paint()..color = hot);
  c.drawCircle(at, r * 0.14, Paint()..color = const Color(0xFFFFE2B0));
  // Current jumping between spikes.
  final arc = Paint()
    ..color = const Color(0xFFFFB199).withValues(alpha: 0.7)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6;
  for (var i = 0; i < 2; i++) {
    final a0 = (t * 3 + i * 2.6) % (math.pi * 2);
    c.drawArc(Rect.fromCircle(center: at, radius: r * 1.12), a0, 0.7, false, arc);
  }
  // Warning ring.
  c.drawCircle(
    at,
    r * 1.5,
    Paint()
      ..color = hot.withValues(alpha: 0.35 + 0.35 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
}

/// One hand's blade: a tapering ribbon along its recent path. Bright while
/// the hand is fast enough to cut, a faint thread otherwise.
void _trail(Canvas c, BodyMap m, List<TrailPoint> pts, int clock, Color col) {
  if (pts.length < 2) return;
  final glowPaint = Paint()..strokeCap = StrokeCap.round;
  final core = Paint()..strokeCap = StrokeCap.round;
  for (var i = 1; i < pts.length; i++) {
    final a = pts[i - 1], b = pts[i];
    final age = ((clock - b.at) / SliceEngine.trailMs).clamp(0.0, 1.0);
    final life = 1 - age;
    final pa = m(a.x, a.y), pb = m(b.x, b.y);
    if (b.hot) {
      glowPaint
        ..color = col.withValues(alpha: 0.5 * life)
        ..strokeWidth = m.unit * 0.2 * life + 3;
      core
        ..color = Colors.white.withValues(alpha: 0.95 * life)
        ..strokeWidth = m.unit * 0.06 * life + 1.5;
      c.drawLine(pa, pb, glowPaint);
      c.drawLine(pa, pb, core);
    } else {
      core
        ..color = col.withValues(alpha: 0.28 * life)
        ..strokeWidth = 2;
      c.drawLine(pa, pb, core);
    }
  }
  // The blade tip.
  final tip = pts.last;
  final at = m(tip.x, tip.y);
  glow(c, at, m.unit * 0.3, col, alpha: tip.hot ? 0.7 : 0.3);
  c.drawCircle(at, m.unit * 0.05 + 2, Paint()..color = Colors.white);
}

/// The two halves of a cut fruit flying apart, the slash and the juice.
void _cut(Canvas c, BodyMap m, SliceCut cut, int clock) {
  final age = ((clock - cut.at) / SliceEngine.cutMs).clamp(0.0, 1.0);
  final tg = cut.target;
  final look = tg.kind == SliceKind.prism ? 5 : tg.look;
  final col = tg.golden ? const Color(0xFFFFD86B) : sliceColour(look);
  final at = m(cut.x, cut.y);
  final r = SliceCutArt.radius * m.unit;
  // Screen angle of the blade (body space has y up).
  final ang = -cut.angle;
  final along = Offset(math.cos(ang), math.sin(ang));
  final normal = Offset(-along.dy, along.dx);
  final perfect = cut.grade == Grade.perfect;

  // The slash: a white line that thins out fast.
  if (age < 0.35) {
    final k = 1 - age / 0.35;
    final len = r * (perfect ? 3.4 : 2.6);
    c.drawLine(
      at - along * len,
      at + along * len,
      Paint()
        ..color = Colors.white.withValues(alpha: k)
        ..strokeWidth = (perfect ? 6 : 4) * k + 1
        ..strokeCap = StrokeCap.round,
    );
  }
  shockRing(c, at, age * 1.4, r * (perfect ? 2.6 : 1.9), col);
  sparkBurst(c, at, age, col, n: perfect ? 18 : 11, spread: r * 3.2, seed: tg.id * 17);

  // Halves: thrown apart across the cut, spinning, falling.
  final fade = age < 0.6 ? 1.0 : (1 - (age - 0.6) / 0.4).clamp(0.0, 1.0);
  for (final side in [-1.0, 1.0]) {
    final drift = normal * side * r * (0.35 + 2.2 * age) + along * side * r * 0.4 * age;
    final fall = Offset(0, r * 4.5 * age * age);
    final p = at + drift + fall;
    c.save();
    c.translate(p.dx, p.dy);
    c.rotate(ang + side * age * 2.4);
    // Keep the half on this side of the cut line.
    c.clipRect(
      side < 0
          ? Rect.fromLTRB(-r * 1.6, -r * 1.6, r * 1.6, 0)
          : Rect.fromLTRB(-r * 1.6, 0, r * 1.6, r * 1.6),
    );
    // A layer only while fading out (the last moments of a few halves).
    if (fade < 1) {
      c.saveLayer(
        Rect.fromCircle(center: Offset.zero, radius: r * 1.7),
        Paint()..color = Colors.white.withValues(alpha: fade),
      );
    } else {
      c.save();
    }
    _fruitBody(c, r, look, col);
    // The cut face: pale flesh along the edge.
    c.drawRect(
      Rect.fromLTRB(-r, side < 0 ? -r * 0.12 : 0, r, side < 0 ? 0 : r * 0.12),
      Paint()..color = shade(col, 0.6),
    );
    c.restore();
    c.restore();
  }
}

/// Sizes shared between the live scene and its cut effect.
abstract final class SliceCutArt {
  /// Radius (torso lengths) the halves are drawn at.
  static const radius = 0.34;
}

/// Live round: fruit in the air, both blades, cut halves, mines.
void slicePlay(Canvas c, Size s, BodyMap m, SliceEngine e, double t) {
  final clock = e.clockMs;
  final r = e.stage.radius * m.unit;
  // Launch pad glow at the floor line.
  final floor = m(0, SliceTarget.floorY).dy;
  for (final tg in e.visible) {
    final (x, y) = tg.at(clock);
    final at = m(x, y);
    // A shadow on the floor that tightens as the fruit comes down.
    final height = ((y - SliceTarget.floorY) / 3).clamp(0.0, 1.0);
    softShadow(
      c,
      Offset(at.dx, math.max(floor, at.dy + r)),
      r * (2.4 - height),
      r * 0.5,
      alpha: 0.4 * (1 - height * 0.7),
    );
    final rr = tg.kind == SliceKind.prism ? r * 0.85 : r;
    _fruit(c, at, rr, tg, tg.spin * (clock - tg.launchAt) / 260, t);
  }
  for (final cut in e.cuts) {
    _cut(c, m, cut, clock);
  }
  _trail(c, m, e.trail(BodySide.left), clock, e.stunned ? const Color(0xFF8A8FA0) : _cyan);
  _trail(c, m, e.trail(BodySide.right), clock, e.stunned ? const Color(0xFF8A8FA0) : _magenta);

  if (e.stunned) {
    // Blades are dead for a moment: a red wash that fades back.
    final k = ((e.stunUntil - clock) / SliceEngine.stunMs).clamp(0.0, 1.0);
    c.drawRect(
      Offset.zero & s,
      Paint()..color = const Color(0xFFFF4D3D).withValues(alpha: 0.22 * k),
    );
  }
  if (e.combo >= 5) {
    strokedText(
      c,
      '×${e.combo}',
      Offset(s.width / 2, m(0, 2.25).dy.clamp(70.0, s.height)),
      size: 30,
      color: e.frenzy ? _volt : Colors.white,
    );
  }
}

/// Static preview for library covers and the gallery.
void slicePreview(Canvas c, Size s, int variant) {
  final t = 1.5 + variant * 1.3;
  sliceBackdrop(c, s, t, heat: variant.clamp(0, 2), frenzy: variant == 3);
  final vp = viewportFor(s, topShare: 0.6);
  final m = BodyMap.demo(vp);
  final j = switch (variant) {
    1 => AvatarJoints.demo(m, shoulderL: 100, elbowL: 150, shoulderR: 35),
    2 => AvatarJoints.demo(m, shoulderL: 40, shoulderR: 60, elbowR: 120, lean: -5),
    3 => AvatarJoints.demo(m, shoulderL: 140, shoulderR: 140, elbowL: 160, elbowR: 160),
    _ => AvatarJoints.demo(m, shoulderR: 125, elbowR: 165, shoulderL: 25, lean: 4),
  };
  paintAvatar(c, j, look: sliceLook);
  final r = m.unit * 0.36;
  SliceTarget tg(int id, int look, {SliceKind kind = SliceKind.fruit}) => SliceTarget(
    id: id,
    kind: kind,
    launchAt: 0,
    flightMs: 2000,
    x0: 0,
    x1: 0,
    apexY: 1,
    look: look,
  );
  void slash(Offset a, Offset b, Color col) {
    c.drawLine(
      a,
      b,
      Paint()
        ..color = col.withValues(alpha: 0.55)
        ..strokeWidth = m.unit * 0.2
        ..strokeCap = StrokeCap.round,
    );
    c.drawLine(
      a,
      b,
      Paint()
        ..color = Colors.white
        ..strokeWidth = m.unit * 0.05
        ..strokeCap = StrokeCap.round,
    );
  }

  switch (variant) {
    case 1:
      _fruit(c, m(-0.2, 1.5), r, tg(1, 1), 0.3, t);
      _fruit(c, m(0.9, 0.9), r, tg(2, 3), -0.4, t);
      _fruit(c, m(-1.1, 0.2), r, tg(3, 4), 0.2, t);
      slash(m(-1.7, 0.9), m(-0.5, 1.5), _cyan);
    case 2:
      _fruit(c, m(1.2, 1.1), r, tg(4, 0), 0.5, t);
      _mine(c, m(0.2, 1.3), r, t);
      _fruit(c, m(-1.1, 0.8), r, tg(5, 2), 0.1, t);
      strokedText(c, 'LEAVE THE MINES', Offset(s.width / 2, vp.top + 26), size: 16, color: const Color(0xFFFF8A7A));
    case 3:
      for (var i = 0; i < 5; i++) {
        _fruit(c, m(-1.3 + i * 0.65, 1.0 + 0.5 * math.sin(i * 1.1)), r * 0.9, tg(10 + i, i), i * 0.4, t);
      }
      slash(m(-1.6, 1.3), m(1.6, 1.15), _magenta);
      strokedText(c, '×12  NEON FRENZY', Offset(s.width / 2, vp.top + 26), size: 18, color: _volt);
    default:
      _fruit(c, m(1.25, 1.25), r, tg(6, 0), 0.4, t);
      _fruit(c, m(-0.6, 1.5), r * 0.85, tg(7, 5, kind: SliceKind.prism), 0.2, t);
      _fruit(c, m(-1.3, 0.4), r, tg(8, 1), -0.3, t);
      slash(m(0.6, 0.6), m(1.7, 1.6), _magenta);
      sparkBurst(c, m(1.25, 1.25), 0.3, _fruitColours[0], spread: r * 3, seed: 4);
  }
}
