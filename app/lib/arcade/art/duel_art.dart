import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_director/game_director.dart';

import 'looks.dart';
import 'paint_kit.dart';

const indigo = Color(0xFF1F2A5C);
const terracotta = Color(0xFFC4552D);
const brass = Color(0xFFC9A227);
const teal = Color(0xFF1E8C8A);
const cream = Color(0xFFF3E9D2);
const kiteMagenta = Color(0xFFC2185B);

/// Craft-punk arena: dusk sky, arches, a patterned terracotta floor.
void _duelScene(Canvas c, Size s, double t, {double dim = 0}) {
  sky(
    c,
    s,
    const [Color(0xFF0F1433), indigo, Color(0xFF3B2A4A)],
    stops: const [0, 0.5, 1],
  );
  starfield(c, s, n: 20, maxY: 0.3, t: t);
  final horizon = s.height * 0.6;
  // Arches.
  final arch = Paint()..color = const Color(0xFF151C40);
  for (var i = 0; i < 5; i++) {
    final w = s.width / 4.2;
    final x = -w * 0.3 + i * w * 1.05;
    final r = RRect.fromRectAndCorners(
      Rect.fromLTWH(x, horizon - 120, w * 0.9, 120),
      topLeft: Radius.circular(w * 0.45),
      topRight: Radius.circular(w * 0.45),
    );
    c.drawRRect(r, arch);
    c.drawRRect(r.deflate(10), Paint()..color = const Color(0xFF242E63));
  }
  // Floor.
  final floor = Rect.fromLTRB(0, horizon, s.width, s.height);
  c.drawRect(
    floor,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF7A3520), Color(0xFF3A170E)],
      ).createShader(floor),
  );
  final ring = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  for (var k = 1; k <= 4; k++) {
    ring.color = cream.withValues(alpha: 0.12);
    c.drawOval(
      Rect.fromCenter(
        center: Offset(s.width / 2, horizon + (s.height - horizon) * 0.55),
        width: s.width * 0.3 * k,
        height: (s.height - horizon) * 0.16 * k,
      ),
      ring,
    );
  }
  // Braziers.
  for (final x in [s.width * 0.08, s.width * 0.92]) {
    final at = Offset(x, horizon + 10);
    c.drawRect(
      Rect.fromCenter(center: at + const Offset(0, 22), width: 14, height: 44),
      Paint()..color = const Color(0xFF2A1A12),
    );
    final flick = 1 + 0.15 * math.sin(t * 9 + x);
    glow(c, at, 40 * flick, const Color(0xFFFF9A3C), alpha: 0.5);
    c.drawCircle(at, 8 * flick, Paint()..color = const Color(0xFFFFD27A));
  }
  if (dim > 0) {
    c.drawRect(
      Offset.zero & s,
      Paint()..color = Colors.black.withValues(alpha: dim),
    );
  }
}

/// The guardian: [windup] 0..1 leans into an attack, [stagger] wobbles it,
/// [calm] 0..1 fades it into its calm form.
void _guardianBody(
  Canvas c,
  Offset at,
  double size,
  String art,
  double t, {
  double windup = 0,
  bool stagger = false,
  double calm = 0,
  int side = 0,
}) {
  c.save();
  final wob = stagger ? math.sin(t * 14) * 0.06 : 0.0;
  c.translate(
    at.dx + side * windup * size * 0.18,
    at.dy + windup * size * 0.05,
  );
  c.rotate(wob + side * windup * 0.08);
  final alpha = 1 - calm * 0.6;
  switch (art) {
    case 'patang':
      _kites(c, size, t, alpha, windup);
    case 'mayur':
      _mayur(c, size, t, alpha, windup);
    case 'lattoo':
      _lattoo(c, size, t, alpha, windup, stagger);
    case 'megh':
      _megh(c, size, t, alpha, windup);
    case 'nightmail':
      _nightmail(c, size, t, alpha, windup);
    default:
      _baoli(c, size, t, alpha, windup);
  }
  c.restore();
}

Paint _p(Color col, double a) => Paint()..color = col.withValues(alpha: a);
final _outline = Paint()
  ..color = const Color(0xFF050B08)
  ..style = PaintingStyle.stroke
  ..strokeWidth = 4
  ..strokeJoin = StrokeJoin.round;

void _eyes(Canvas c, Offset l, Offset r, double s, double a, Color col) {
  for (final e in [l, r]) {
    glow(c, e, s * 2.6, col, alpha: 0.6 * a);
    c.drawCircle(e, s, _p(cream, a));
  }
}

void _baoli(Canvas c, double s, double t, double a, double w) {
  // Stacked stepwell tiers form the body.
  for (var i = 0; i < 6; i++) {
    final wi = s * (0.95 - i * 0.1);
    final r = Rect.fromCenter(
      center: Offset(0, s * 0.25 - i * s * 0.11),
      width: wi,
      height: s * 0.12,
    );
    c.drawRect(
      r,
      _p(
        Color.lerp(const Color(0xFFB9824F), const Color(0xFFE2B57A), i / 6)!,
        a,
      ),
    );
    c.drawRect(r, _outline..strokeWidth = 2.5);
  }
  // Lattice head.
  final head = Rect.fromCenter(
    center: Offset(0, -s * 0.48),
    width: s * 0.42,
    height: s * 0.34,
  );
  c.drawRRect(
    RRect.fromRectAndRadius(head, Radius.circular(s * 0.06)),
    _p(const Color(0xFFCF9A62), a),
  );
  final jaali = _p(const Color(0xFF6A4320), a)..strokeWidth = 2;
  for (var k = 1; k < 5; k++) {
    c.drawLine(
      Offset(head.left + head.width * k / 5, head.top),
      Offset(head.left + head.width * k / 5, head.bottom),
      jaali,
    );
  }
  c.drawRRect(
    RRect.fromRectAndRadius(head, Radius.circular(s * 0.06)),
    _outline..strokeWidth = 3,
  );
  _eyes(
    c,
    Offset(-s * 0.09, -s * 0.5),
    Offset(s * 0.09, -s * 0.5),
    s * 0.035,
    a,
    teal,
  );
  // Stepped arms.
  for (final dir in [-1.0, 1.0]) {
    final reach = 0.55 + w * 0.15;
    for (var k = 0; k < 3; k++) {
      final r = Rect.fromCenter(
        center: Offset(
          dir * s * (0.42 + k * 0.1),
          -s * 0.1 + k * s * 0.08 * reach,
        ),
        width: s * 0.14,
        height: s * 0.14,
      );
      c.drawRect(r, _p(const Color(0xFFC08A55), a));
      c.drawRect(r, _outline..strokeWidth = 2.5);
    }
  }
}

void _kites(Canvas c, double s, double t, double a, double w) {
  final string = Path()
    ..moveTo(-s * 0.3, -s * 0.25)
    ..quadraticBezierTo(0, s * (0.15 - 0.2 * w), s * 0.3, -s * 0.25);
  c.drawPath(
    string,
    Paint()
      ..color = cream.withValues(alpha: 0.8 * a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3,
  );
  for (final (dx, col, ph) in [
    (-0.3, kiteMagenta, 0.0),
    (0.3, const Color(0xFFE0A030), 1.5),
  ]) {
    final ctr = Offset(dx * s, -s * 0.3 + math.sin(t * 2 + ph) * s * 0.04);
    final k = diamondPath(ctr, s * 0.26);
    c.drawPath(k, _p(col, a));
    c.drawPath(k, _outline..strokeWidth = 3);
    c.drawLine(
      ctr - Offset(0, s * 0.26),
      ctr + Offset(0, s * 0.26),
      _p(cream, 0.6 * a)..strokeWidth = 2,
    );
    c.drawLine(
      ctr - Offset(s * 0.2, 0),
      ctr + Offset(s * 0.2, 0),
      _p(cream, 0.6 * a)..strokeWidth = 2,
    );
    _eyes(
      c,
      ctr + Offset(-s * 0.06, -s * 0.04),
      ctr + Offset(s * 0.06, -s * 0.04),
      s * 0.025,
      a,
      col,
    );
    final tail = Path()..moveTo(ctr.dx, ctr.dy + s * 0.26);
    for (var i = 1; i <= 4; i++) {
      tail.lineTo(
        ctr.dx + math.sin(t * 3 + i + ph) * s * 0.05,
        ctr.dy + s * 0.26 + i * s * 0.07,
      );
    }
    c.drawPath(
      tail,
      Paint()
        ..color = col.withValues(alpha: a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
}

void _mayur(Canvas c, double s, double t, double a, double w) {
  final fan = s * (0.5 + 0.08 * w);
  for (var i = 0; i < 11; i++) {
    final ang = math.pi + i / 10 * math.pi;
    final tip = Offset(math.cos(ang) * fan, -s * 0.2 + math.sin(ang) * fan);
    c.drawLine(Offset(0, -s * 0.2), tip, _p(brass, a)..strokeWidth = 5);
    c.drawOval(
      Rect.fromCenter(center: tip, width: s * 0.13, height: s * 0.17),
      _p(const Color(0xFF2E7D6B), a),
    );
    c.drawCircle(tip, s * 0.035, _p(const Color(0xFF1F2A5C), a));
    glow(c, tip, s * 0.07, brass, alpha: (0.3 + 0.5 * w) * a);
  }
  final body = Path()
    ..moveTo(0, -s * 0.5)
    ..cubicTo(s * 0.2, -s * 0.3, s * 0.18, s * 0.1, 0, s * 0.2)
    ..cubicTo(-s * 0.18, s * 0.1, -s * 0.2, -s * 0.3, 0, -s * 0.5);
  c.drawPath(body, _p(const Color(0xFFD4A63A), a));
  c.drawPath(body, _outline..strokeWidth = 3);
  c.drawCircle(Offset(0, -s * 0.52), s * 0.08, _p(const Color(0xFFD4A63A), a));
  c.drawCircle(Offset(0, -s * 0.52), s * 0.08, _outline..strokeWidth = 3);
  _eyes(
    c,
    Offset(-s * 0.03, -s * 0.54),
    Offset(s * 0.03, -s * 0.54),
    s * 0.015,
    a,
    brass,
  );
  for (var i = 0; i < 3; i++) {
    c.drawLine(
      Offset(0, -s * 0.6),
      Offset((i - 1) * s * 0.05, -s * 0.72),
      _p(brass, a)..strokeWidth = 2,
    );
  }
}

void _lattoo(Canvas c, double s, double t, double a, double w, bool stagger) {
  final spin = stagger ? 0.0 : t * 6;
  final body = Path()
    ..moveTo(0, s * 0.35)
    ..cubicTo(s * 0.45, -s * 0.05, s * 0.4, -s * 0.45, 0, -s * 0.5)
    ..cubicTo(-s * 0.4, -s * 0.45, -s * 0.45, -s * 0.05, 0, s * 0.35);
  c.save();
  c.clipPath(body);
  const bands = [
    Color(0xFFD9342B),
    Color(0xFFF2C230),
    Color(0xFF2E8B57),
    Color(0xFF1F5FA8),
  ];
  for (var i = 0; i < 9; i++) {
    final y = -s * 0.5 + i * s * 0.1;
    final shift = math.sin(spin + i) * s * 0.02;
    c.drawRect(
      Rect.fromLTWH(-s * 0.5 + shift, y, s, s * 0.1),
      _p(bands[i % 4], a),
    );
  }
  c.restore();
  c.drawPath(body, _outline..strokeWidth = 3.5);
  c.drawLine(
    Offset(0, -s * 0.5),
    Offset(0, -s * 0.68),
    _p(cream, a)..strokeWidth = 6,
  );
  _eyes(
    c,
    Offset(-s * 0.1, -s * 0.2),
    Offset(s * 0.1, -s * 0.2),
    s * 0.035,
    a,
    const Color(0xFFF2C230),
  );
}

void _megh(Canvas c, double s, double t, double a, double w) {
  final puff = _p(const Color(0xFFCBD3E6), a);
  for (final o in const [
    Offset(-0.32, -0.1),
    Offset(-0.12, -0.32),
    Offset(0.15, -0.36),
    Offset(0.35, -0.12),
    Offset(0, -0.05),
    Offset(-0.22, 0.08),
    Offset(0.22, 0.08),
  ]) {
    c.drawCircle(o * s, s * 0.2, puff);
  }
  for (var i = 0; i < 3; i++) {
    final at = Offset((i - 1) * s * 0.22, s * 0.04);
    c.drawOval(
      Rect.fromCenter(center: at, width: s * 0.18, height: s * 0.13),
      _p(const Color(0xFFE9DFC6), a),
    );
    c.drawOval(
      Rect.fromCenter(center: at, width: s * 0.18, height: s * 0.13),
      _outline..strokeWidth = 2.5,
    );
  }
  _eyes(
    c,
    Offset(-s * 0.1, -s * 0.22),
    Offset(s * 0.1, -s * 0.22),
    s * 0.035,
    a,
    const Color(0xFF7FD8FF),
  );
  // Rain.
  final rain = _p(const Color(0xFF7FD8FF), 0.6 * a)..strokeWidth = 2;
  for (var i = 0; i < 8; i++) {
    final x = (i - 3.5) * s * 0.1;
    final y = s * 0.2 + ((t * 120 + i * 37) % (s * 0.4));
    c.drawLine(Offset(x, y), Offset(x - 3, y + 10), rain);
  }
  if (w > 0.6) {
    final bolt = Path()
      ..moveTo(0, s * 0.15)
      ..lineTo(-s * 0.05, s * 0.35)
      ..lineTo(s * 0.03, s * 0.33)
      ..lineTo(-s * 0.02, s * 0.55);
    c.drawPath(
      bolt,
      Paint()
        ..color = const Color(0xFFFFE27A).withValues(alpha: a)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
  }
}

void _nightmail(Canvas c, double s, double t, double a, double w) {
  // Smoke.
  for (var i = 0; i < 5; i++) {
    final ph = (t * 0.6 + i * 0.2) % 1.0;
    c.drawCircle(
      Offset(s * 0.08 + ph * s * 0.2, -s * 0.72 - ph * s * 0.4),
      s * (0.05 + ph * 0.08),
      _p(const Color(0xFFB0B4C8), (1 - ph) * 0.6 * a),
    );
  }
  // Boiler standing up.
  final boiler = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: Offset(0, -s * 0.1),
      width: s * 0.5,
      height: s * 0.8,
    ),
    Radius.circular(s * 0.22),
  );
  c.drawRRect(boiler, _p(const Color(0xFF2A2F45), a));
  c.drawRRect(boiler, _outline..strokeWidth = 3.5);
  for (var i = 0; i < 4; i++) {
    c.drawLine(
      Offset(-s * 0.25, -s * 0.35 + i * s * 0.18),
      Offset(s * 0.25, -s * 0.35 + i * s * 0.18),
      _p(brass, a)..strokeWidth = 3,
    );
  }
  c.drawRect(
    Rect.fromCenter(
      center: Offset(s * 0.08, -s * 0.6),
      width: s * 0.1,
      height: s * 0.16,
    ),
    _p(const Color(0xFF2A2F45), a),
  );
  // Headlamp face.
  final lamp = Offset(0, -s * 0.32);
  glow(c, lamp, s * 0.25, const Color(0xFFFFE27A), alpha: (0.4 + 0.4 * w) * a);
  c.drawCircle(lamp, s * 0.08, _p(const Color(0xFFFFE27A), a));
  // Trunk arms.
  for (final dir in [-1.0, 1.0]) {
    final r = Rect.fromCenter(
      center: Offset(dir * s * (0.42 + 0.06 * w), -s * 0.05),
      width: s * 0.22,
      height: s * 0.16,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(s * 0.03)),
      _p(const Color(0xFF7A4A2A), a),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(r, Radius.circular(s * 0.03)),
      _outline..strokeWidth = 2.5,
    );
  }
  // Wheels as feet.
  for (final dir in [-1.0, 1.0]) {
    final at = Offset(dir * s * 0.16, s * 0.34);
    c.drawCircle(at, s * 0.09, _p(const Color(0xFFB33A2B), a));
    c.drawCircle(at, s * 0.09, _outline..strokeWidth = 3);
    c.drawLine(
      at,
      at + Offset(math.cos(t * 4) * s * 0.08, math.sin(t * 4) * s * 0.08),
      _p(cream, a)..strokeWidth = 2,
    );
  }
}

IconData _glyph(DuelMove m) => switch (m) {
  DuelMove.duck => Icons.south_rounded,
  DuelMove.left => Icons.west_rounded,
  DuelMove.right => Icons.east_rounded,
  DuelMove.guard => Icons.shield_rounded,
  _ => Icons.circle,
};

void _icon(Canvas c, IconData icon, Offset at, double size, Color color) {
  final tp = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
}

/// Live duel: guardian, the current telegraph with its count ring, pads,
/// the Charge orb and the poise / calm / surge bars.
void duelPlay(
  Canvas c,
  Size s,
  BodyMap m,
  DuelEngine e,
  double t, {
  required Rect vp,
}) {
  final incoming = e.incoming;
  final beat = e.phraseBeat;
  double windup = 0;
  var side = 0;
  if (incoming != null) {
    final left = (incoming.at - e.clockMs) / e.beatMs;
    windup = (1 - (left / 4)).clamp(0.0, 1.0);
    side = incoming.move == DuelMove.left
        ? -1
        : (incoming.move == DuelMove.right ? 1 : 0);
  }
  final gSize = math.min(s.width * 0.6, vp.height * 0.42);
  paintGuardian(
    c,
    Offset(s.width / 2, vp.top + gSize * 0.42),
    gSize,
    e.guardian.art,
    t,
    windup: windup,
    stagger: e.mode == 'opening' && e.staggered,
    calm: e.finished ? 1 : 0,
    side: side,
  );

  // Telegraph glyph + count ring.
  if (incoming != null) {
    final left = (incoming.at - e.clockMs) / e.beatMs;
    final at = Offset(s.width / 2, vp.top + gSize * 0.98);
    final r = 46.0;
    c.drawCircle(at, r + 6, Paint()..color = const Color(0xCC0B1611));
    for (var i = 0; i < 4; i++) {
      final lit = (4 - left) >= i + 1;
      final a = -math.pi / 2 + i * math.pi / 2;
      c.drawArc(
        Rect.fromCircle(center: at, radius: r),
        a + 0.08,
        math.pi / 2 - 0.16,
        false,
        Paint()
          ..color = lit ? brass : const Color(0x55F3E9D2)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 7,
      );
    }
    _icon(c, _glyph(incoming.move), at, 48, cream);
    // Where the hit lands, on the body.
    switch (incoming.move) {
      case DuelMove.duck:
        final y = m(0, 0.45).dy;
        c.drawRect(
          Rect.fromLTRB(vp.left, y - 10, vp.right, y + 10),
          Paint()..color = terracotta.withValues(alpha: 0.25 + 0.6 * windup),
        );
      case DuelMove.left || DuelMove.right:
        final x = m(incoming.move == DuelMove.left ? 0.6 : -0.6, 0).dx;
        final rect = Rect.fromLTRB(
          incoming.move == DuelMove.left ? x : vp.left,
          vp.top + gSize * 0.7,
          incoming.move == DuelMove.left ? vp.right : x,
          m(0, -3).dy,
        );
        c.drawRect(
          rect,
          Paint()..color = terracotta.withValues(alpha: 0.12 + 0.35 * windup),
        );
      case DuelMove.guard:
        c.drawPath(
          diamondPath(m(0, 0.15), m.unit * 0.5),
          Paint()
            ..color = brass.withValues(alpha: 0.3 + 0.5 * windup)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4,
        );
      default:
        break;
    }
  }
  // Pads and charge.
  for (final a in e.asks) {
    if (a.resolved || a.move.hazard) continue;
    final p = (1 - (a.at - e.clockMs) / (e.beatMs * 2)).clamp(0.0, 1.0);
    if (a.move == DuelMove.charge) {
      final at = m(0, 1.6);
      approachRing(c, at, m.unit * 0.4, p, brass);
      glow(c, at, m.unit * 0.9, brass, alpha: 0.6);
      c.drawCircle(at, m.unit * 0.28, Paint()..color = const Color(0xFFFFE27A));
      strokedText(
        c,
        e.surge >= 100 ? 'SURGE!' : 'ARMS UP',
        at + Offset(0, -m.unit * 0.7),
        size: 18,
        color: brass,
      );
    } else {
      final left = a.move == DuelMove.padL;
      final at = m(left ? -1.15 : 1.15, 0.05);
      approachRing(c, at, m.unit * 0.42, p, teal);
      glow(c, at, m.unit * 0.8, teal, alpha: 0.55);
      c.drawCircle(at, m.unit * 0.36, Paint()..color = teal);
      c.drawCircle(at, m.unit * 0.36, _outline..strokeWidth = 3);
      strokedText(c, left ? 'L' : 'R', at, size: 22, color: cream);
    }
  }
  // Bars: poise (guardian), calm segments, surge.
  final barTop = vp.top + 4;
  final w = s.width * 0.56;
  final left = (s.width - w) / 2;
  _bar(
    c,
    Rect.fromLTWH(left, barTop, w, 9),
    e.poise / 100,
    terracotta,
    'POISE',
  );
  final seg = w / e.calm.length;
  for (var i = 0; i < e.calm.length; i++) {
    _bar(
      c,
      Rect.fromLTWH(left + i * seg + 2, barTop + 22, seg - 4, 9),
      e.calm[i] / 100,
      teal,
      i == 0 ? 'CALM' : null,
    );
  }
  _bar(c, Rect.fromLTWH(left, barTop + 44, w, 6), e.surge / 100, brass, null);
  // Beat dot.
  final pulse = 1 - (beat % 1);
  c.drawCircle(
    Offset(left - 16, barTop + 26),
    5 + 4 * pulse,
    Paint()..color = brass.withValues(alpha: 0.5 + 0.5 * pulse),
  );
}

void _bar(Canvas c, Rect r, double v, Color col, String? label) {
  final rr = RRect.fromRectAndRadius(r, Radius.circular(r.height / 2));
  c.drawRRect(rr.inflate(2), Paint()..color = const Color(0xCC050B08));
  c.drawRRect(rr, Paint()..color = const Color(0x33F3E9D2));
  if (v > 0) {
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r.left, r.top, r.width * v.clamp(0.0, 1.0), r.height),
        Radius.circular(r.height / 2),
      ),
      Paint()..color = col,
    );
  }
  if (label != null) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: cream,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset(r.right + 6, r.center.dy - tp.height / 2));
  }
}

void duelPreview(Canvas c, Size s, int variant, {String art = 'baoli'}) {
  duelBackdrop(c, s, 1.2 + variant);
  // Wide framing: the guardian looms on the left, the player answers on
  // the right, so neither covers the other.
  final h = s.height;
  final gSize = math.min(h * 0.62, s.width * 0.42);
  final gCenter = Offset(s.width * 0.34, h * 0.08 + gSize * 0.62);
  paintGuardian(
    c,
    gCenter,
    gSize,
    art,
    1.2 + variant,
    windup: variant == 1 ? 0.8 : 0.2,
    side: variant == 1 ? 1 : 0,
    stagger: variant == 2,
  );
  final m = BodyMap(Offset(s.width * 0.72, h * 0.36), h * 0.13);
  final j = switch (variant) {
    1 => AvatarJoints.demo(m, lean: -14),
    2 => AvatarJoints.demo(m, shoulderR: 90),
    3 => AvatarJoints.demo(m, shoulderL: 170, shoulderR: 170),
    _ => AvatarJoints.demo(
      m,
      shoulderL: 65,
      elbowL: 45,
      shoulderR: 65,
      elbowR: 45,
    ),
  };
  paintAvatar(c, j, look: duelLook);
  if (variant == 2) {
    final at = m(1.15, 0.05);
    glow(c, at, m.unit * 0.8, teal, alpha: 0.6);
    c.drawCircle(at, m.unit * 0.34, Paint()..color = teal);
    strokedText(c, 'R', at, size: m.unit * 0.42, color: cream);
  }
  if (variant == 3) {
    final at = m(0, 1.7);
    glow(c, at, m.unit * 0.9, brass, alpha: 0.6);
    c.drawCircle(at, m.unit * 0.3, Paint()..color = const Color(0xFFFFE27A));
  }
  if (variant == 0 || variant == 1) {
    final at = Offset(gCenter.dx + gSize * 0.5, h * 0.2);
    final r = h * 0.08;
    c.drawCircle(at, r + 4, Paint()..color = const Color(0xCC0B1611));
    c.drawArc(
      Rect.fromCircle(center: at, radius: r),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      Paint()
        ..color = brass
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    _icon(
      c,
      variant == 0 ? Icons.shield_rounded : Icons.west_rounded,
      at,
      r * 1.1,
      cream,
    );
  }
}

/// The stepwell court at night, lit by its two braziers: firelight lying on
/// the stone, moonlight through the middle arch, dust in the air.
void duelBackdrop(Canvas c, Size s, double t, {double dim = 0}) {
  _duelScene(c, s, t);
  final horizon = s.height * 0.6;
  final depth = s.height - horizon;
  lightShaft(c, Offset(s.width / 2, horizon - 118), depth * 0.9 + 118, s.width * 0.2, const Color(0xFFBFD2FF), alpha: 0.12);
  for (final x in [s.width * 0.08, s.width * 0.92]) {
    final flick = 1 + 0.12 * math.sin(t * 9 + x);
    lightPool(c, Offset(x, horizon + depth * 0.3), s.width * 0.7 * flick, depth * 0.75, const Color(0xFFFF9A3C), alpha: 0.3);
  }
  // The duelling ring catches the light.
  lightPool(c, Offset(s.width / 2, horizon + depth * 0.55), s.width * 0.9, depth * 0.6, cream, alpha: 0.1);
  hazeBand(c, s, horizon, s.height * 0.1, const Color(0xFF8A6A9A), alpha: 0.2);
  // Dust motes rising through the firelight.
  final mote = Paint();
  for (var i = 0; i < 18; i++) {
    final x = hash(i * 9 + 2) * s.width;
    final y = horizon + depth * (1 - ((hash(i * 5 + 1) + t * 0.03 * (0.5 + hash(i))) % 1));
    mote.color = const Color(0xFFFFD9A0).withValues(alpha: 0.12 + 0.2 * hash(i * 3));
    c.drawCircle(Offset(x + math.sin(t + i) * 6, y), 1.4, mote);
  }
  vignette(c, s, strength: 0.6);
  if (dim > 0) {
    c.drawRect(Offset.zero & s, Paint()..color = Colors.black.withValues(alpha: dim));
  }
}

/// The guardian, set into the scene: a shadow on the stone under it and a
/// rim of light behind it that flares as it winds up and softens to a warm
/// halo as it calms. [windup] 0..1 leans into an attack, [stagger] wobbles
/// it, [calm] 0..1 fades it into its calm form.
void paintGuardian(
  Canvas c,
  Offset at,
  double size,
  String art,
  double t, {
  double windup = 0,
  bool stagger = false,
  double calm = 0,
  int side = 0,
}) {
  softShadow(c, at + Offset(0, size * 0.62), size * 1.5, size * 0.26, alpha: 0.45 * (1 - calm * 0.5));
  final aura = Color.lerp(
    Color.lerp(teal, terracotta, windup.clamp(0.0, 1.0))!,
    const Color(0xFFFFE2A8),
    calm.clamp(0.0, 1.0),
  )!;
  glow(c, at, size * (0.95 + 0.15 * windup), aura, alpha: 0.22 + 0.2 * windup + 0.15 * calm);
  _guardianBody(c, at, size, art, t, windup: windup, stagger: stagger, calm: calm, side: side);
  if (stagger) {
    // Poise broken: sparks shake loose.
    sparkBurst(c, at - Offset(0, size * 0.2), (t * 1.6) % 1, brass, n: 9, spread: size * 0.8, seed: (t * 1.6).floor());
  }
}
