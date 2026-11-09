import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';

import 'paint_kit.dart';

const _marigold = Color(0xFFFFB627);
const _kumkum = Color(0xFFFF4D6D);
const _peacock = Color(0xFF00C2B8);
const _lilac = Color(0xFFB98CFF);

/// Dusk fairground: string lights, a slow Ferris wheel and striped stalls.
void melaBackdrop(Canvas c, Size s, double t, {bool storm = false}) {
  sky(
    c,
    s,
    storm
        ? const [Color(0xFF1B1430), Color(0xFF3A2440), Color(0xFF2A1A22)]
        : const [Color(0xFF241339), Color(0xFF6B2F4A), Color(0xFF3A1A12)],
    stops: const [0, 0.55, 1],
  );
  starfield(c, s, n: 26, maxY: 0.35, t: t);
  // Ferris wheel.
  final wc = Offset(s.width * 0.78, s.height * 0.34);
  final wr = s.width * 0.26;
  final spoke = Paint()
    ..color = const Color(0x55FFD9A0)
    ..strokeWidth = 2;
  final rot = t * 0.12;
  for (var i = 0; i < 12; i++) {
    final a = rot + i * math.pi / 6;
    final p = wc + Offset(math.cos(a) * wr, math.sin(a) * wr);
    c.drawLine(wc, p, spoke);
    c.drawCircle(
      p,
      5,
      Paint()
        ..color = [_marigold, _kumkum, _peacock][i % 3].withValues(alpha: 0.85),
    );
  }
  c.drawCircle(
    wc,
    wr,
    Paint()
      ..color = const Color(0x66FFD9A0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3,
  );
  final leg = Paint()
    ..color = const Color(0xFF2A1630)
    ..strokeWidth = 6;
  c.drawLine(wc, wc + Offset(-wr * 0.6, wr * 1.5), leg);
  c.drawLine(wc, wc + Offset(wr * 0.6, wr * 1.5), leg);
  // Light strings.
  for (var row = 0; row < 2; row++) {
    final y0 = s.height * (0.08 + row * 0.07);
    final path = Path()..moveTo(0, y0);
    path.quadraticBezierTo(s.width / 2, y0 + 40, s.width, y0);
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0x55000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    for (var i = 0; i <= 14; i++) {
      final x = i / 14;
      final y = y0 + 40 * 4 * x * (1 - x) * 0.5;
      final on = 0.6 + 0.4 * math.sin(t * 3 + i + row * 2);
      final col = [_marigold, _kumkum, _peacock, _lilac][(i + row) % 4];
      glow(c, Offset(x * s.width, y), 10, col, alpha: 0.5 * on);
      c.drawCircle(Offset(x * s.width, y), 3, Paint()..color = col);
    }
  }
  // Stalls along the bottom.
  final ground = s.height * 0.86;
  c.drawRect(
    Rect.fromLTWH(0, ground, s.width, s.height - ground),
    Paint()..color = const Color(0xFF1E0E0A),
  );
  final stallW = s.width / 3.2;
  for (var i = 0; i < 4; i++) {
    final x = -stallW * 0.3 + i * stallW * 1.05;
    final roof = Rect.fromLTWH(x, ground - 70, stallW, 26);
    for (var k = 0; k < 6; k++) {
      c.drawRect(
        Rect.fromLTWH(
          roof.left + k * roof.width / 6,
          roof.top,
          roof.width / 6,
          roof.height,
        ),
        Paint()
          ..color = k.isEven
              ? [_kumkum, _marigold, _peacock, _lilac][i % 4]
              : const Color(0xFFF6EEDC),
      );
    }
    c.drawRect(
      Rect.fromLTWH(x + 6, ground - 44, stallW - 12, 44),
      Paint()..color = const Color(0xFF2C1610),
    );
    glow(c, Offset(x + stallW / 2, ground - 20), 30, _marigold, alpha: 0.35);
  }
}

/// Live round: targets around the body, hazards, shields.
void melaPlay(Canvas c, Size s, BodyMap m, MelaEngine e, double t) {
  final clock = e.clockMs;
  final r = e.stage.radius * m.unit;
  for (final tg in e.visible) {
    final p = tg.progress(clock);
    if (tg.isHazard) {
      _hazard(c, s, m, tg, p, t);
      continue;
    }
    final target = m(tg.x, tg.y);
    final dir = (target - m(0, -0.2));
    final from =
        target +
        (dir.distance == 0 ? const Offset(0, -1) : dir / dir.distance) *
            m.unit *
            2.4;
    final pos = Offset.lerp(
      from,
      target,
      Curves.easeOutCubic.transform(p.clamp(0.0, 1.0)),
    )!;
    final bob = math.sin(t * 4 + tg.id) * 3 * (1 - p.clamp(0.0, 1.0));
    final at = pos + Offset(0, bob);
    final color = tg.golden
        ? _marigold
        : switch (tg.kind) {
            MelaKind.crown => _lilac,
            MelaKind.chest => _kumkum,
            _ =>
              tg.side == BodySide.right
                  ? _peacock
                  : (tg.side == null ? _marigold : _kumkum),
          };
    approachRing(c, target, r, p, color);
    glow(c, at, r * 1.4, color, alpha: 0.45);
    _object(c, at, r * 0.72, tg, color, t);
  }
  // Shield pips under the body.
  for (var i = 0; i < 3; i++) {
    final at = m(-0.3 + i * 0.3, -3.3);
    c.drawCircle(
      at,
      7,
      Paint()..color = i < e.shields ? _peacock : const Color(0x33FFFFFF),
    );
  }
  if (e.rush) {
    final rect = Offset.zero & s;
    c.drawRect(
      rect,
      Paint()
        ..color = _marigold.withValues(alpha: 0.25 + 0.15 * math.sin(t * 6))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10,
    );
  }
}

void _object(
  Canvas c,
  Offset at,
  double r,
  MelaTarget tg,
  Color color,
  double t,
) {
  final dark = Paint()..color = const Color(0xFF050B08);
  switch (tg.kind) {
    case MelaKind.crown:
      // Double paper lantern.
      for (final dx in [-r * 0.7, r * 0.7]) {
        final ctr = at + Offset(dx, 0);
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: ctr, width: r * 1.1, height: r * 1.4),
            Radius.circular(r * 0.4),
          ),
          dark,
        );
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: ctr, width: r * 0.95, height: r * 1.25),
            Radius.circular(r * 0.35),
          ),
          Paint()..color = color,
        );
        c.drawLine(
          ctr - Offset(0, r * 0.62),
          ctr + Offset(0, r * 0.62),
          Paint()
            ..color = const Color(0x55050B08)
            ..strokeWidth = 2,
        );
      }
    case MelaKind.chest:
      // Marigold garland knot.
      for (var i = 0; i < 7; i++) {
        final a = i / 7 * math.pi * 2 + t;
        c.drawCircle(
          at + Offset(math.cos(a) * r * 0.6, math.sin(a) * r * 0.6),
          r * 0.32,
          Paint()..color = i.isEven ? _marigold : const Color(0xFFFF8A1E),
        );
      }
      c.drawCircle(at, r * 0.3, Paint()..color = _kumkum);
    default:
      if (tg.side == BodySide.right) {
        c.drawPath(diamondPath(at, r * 1.08), dark);
        c.drawPath(diamondPath(at, r), Paint()..color = color);
        c.drawPath(
          diamondPath(at, r * 0.55),
          Paint()..color = Colors.white.withValues(alpha: 0.35),
        );
      } else {
        c.drawCircle(at, r + 2.5, dark);
        c.drawCircle(
          at,
          r,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.95),
                    color,
                    color.withValues(alpha: 0.9),
                  ],
                  stops: const [0, 0.35, 1],
                ).createShader(
                  Rect.fromCircle(
                    center: at - Offset(r * 0.3, r * 0.3),
                    radius: r * 1.4,
                  ),
                ),
        );
        if (tg.side == BodySide.left) {
          c.drawArc(
            Rect.fromCircle(center: at, radius: r * 0.55),
            math.pi / 2,
            math.pi,
            true,
            Paint()..color = Colors.white.withValues(alpha: 0.5),
          );
        }
      }
      if (tg.golden) {
        c.drawPath(starPath(at, r * 0.5), Paint()..color = Colors.white);
      }
  }
}

void _hazard(Canvas c, Size s, BodyMap m, MelaTarget tg, double p, double t) {
  final warn = p.clamp(0.0, 1.0);
  final Rect band;
  final String label;
  switch (tg.kind) {
    case MelaKind.duck:
      final top = m(0, 0.9).dy, bottom = m(0, 0.15).dy;
      band = Rect.fromLTRB(0, top, s.width, bottom);
      label = 'DUCK';
    case MelaKind.dodgeLeft:
      band = Rect.fromLTRB(0, m(0, 1.3).dy, m(0.15, 0).dx, m(0, -2.6).dy);
      label = 'LEAN →';
    default:
      band = Rect.fromLTRB(
        m(-0.15, 0).dx,
        m(0, 1.3).dy,
        s.width,
        m(0, -2.6).dy,
      );
      label = '← LEAN';
  }
  c.drawRect(
    band,
    Paint()
      ..color = const Color(0xFF8C7BB8).withValues(alpha: 0.12 + 0.25 * warn),
  );
  final edge = Paint()
    ..color = const Color(0xFFFFC857).withValues(alpha: 0.4 + 0.6 * warn)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  c.drawRect(band.deflate(2), edge);
  // Baadal the cloud sweeping in.
  final cx = tg.kind == MelaKind.duck
      ? s.width * (1.2 - 1.4 * warn)
      : band.center.dx;
  final cy = tg.kind == MelaKind.duck
      ? band.center.dy
      : band.top + band.height * warn;
  final cloud = Paint()..color = const Color(0xFFE6E0F5).withValues(alpha: 0.9);
  for (final o in const [
    Offset(-26, 6),
    Offset(0, -6),
    Offset(26, 4),
    Offset(10, 12),
    Offset(-12, 12),
  ]) {
    c.drawCircle(Offset(cx, cy) + o * (1 + warn * 0.4), 20 + warn * 6, cloud);
  }
  strokedText(
    c,
    label,
    Offset(band.center.dx, band.center.dy + 30),
    size: 26,
    color: const Color(0xFFFFC857),
  );
}

/// Static preview for library covers and the gallery.
void melaPreview(Canvas c, Size s, int variant) {
  final t = 2.0 + variant;
  melaBackdrop(c, s, t, storm: variant == 3);
  final vp = viewportFor(s, topShare: 0.55);
  final m = BodyMap.demo(vp);
  final j = switch (variant) {
    1 => AvatarJoints.demo(m, shoulderR: 92, shoulderL: 30),
    2 => AvatarJoints.demo(m, dip: 0.6, shoulderL: 30, shoulderR: 30),
    3 => AvatarJoints.demo(m, lean: 12, shoulderL: 150, shoulderR: 40),
    _ => AvatarJoints.demo(m, shoulderL: 145, shoulderR: 20),
  };
  paintAvatar(c, j, accent: _marigold);
  final r = m.unit * 0.42;
  void bubble(
    double x,
    double y,
    Color col,
    double prog, {
    bool diamond = false,
  }) {
    final at = m(x, y);
    approachRing(c, at, r, prog, col);
    glow(c, at, r * 1.5, col, alpha: 0.45);
    if (diamond) {
      c.drawPath(diamondPath(at, r * 0.8), Paint()..color = col);
    } else {
      c.drawCircle(at, r * 0.75, Paint()..color = col);
      c.drawCircle(
        at - Offset(r * 0.25, r * 0.25),
        r * 0.2,
        Paint()..color = Colors.white70,
      );
    }
  }

  switch (variant) {
    case 1:
      bubble(1.3, 0.05, _peacock, 0.95, diamond: true);
      bubble(-0.75, 1.15, _kumkum, 0.4);
      confetti(c, m(1.3, 0.05), 0.35, const [
        _marigold,
        _kumkum,
        _peacock,
      ], spread: 60);
    case 2:
      final band = Rect.fromLTRB(0, m(0, 0.9).dy, s.width, m(0, 0.15).dy);
      c.drawRect(band, Paint()..color = const Color(0x448C7BB8));
      strokedText(
        c,
        'DUCK',
        Offset(s.width / 2, band.bottom + 22),
        size: 22,
        color: const Color(0xFFFFC857),
      );
      for (final o in const [Offset(-22, 4), Offset(0, -8), Offset(22, 4)]) {
        c.drawCircle(
          Offset(s.width * 0.25, band.center.dy) + o,
          18,
          Paint()..color = const Color(0xEEE6E0F5),
        );
      }
    case 3:
      bubble(-0.75, 1.15, _kumkum, 0.9);
      bubble(1.15, -0.75, _peacock, 0.5, diamond: true);
      bubble(1.3, 0.05, _marigold, 0.2);
    default:
      bubble(-0.75, 1.15, _kumkum, 0.92);
      bubble(1.3, 0.05, _peacock, 0.45, diamond: true);
  }
}
