import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_director/game_director.dart';

import 'looks.dart';
import 'paint_kit.dart';

const _kumkum = Color(0xFFFF4D6D);
const _marigold = Color(0xFFFFB627);
const _peacock = Color(0xFF00C2B8);
const _lilac = Color(0xFFB98CFF);
const _mehendi = Color(0xFF9BCB3C);

/// Where each move's card lands on the body.
(double, double) taalZone(TaalMove m) => switch (m) {
  TaalMove.clap => (0, -0.45),
  TaalMove.stepL => (-0.55, -3.0),
  TaalMove.stepR => (0.55, -3.0),
  TaalMove.waveL => (-1.05, 0.45),
  TaalMove.waveR => (1.05, 0.45),
  TaalMove.reachL => (-0.62, 1.1),
  TaalMove.reachR => (0.62, 1.1),
  TaalMove.dip => (0, -1.35),
  TaalMove.hoy => (0, 1.55),
};

Color taalColor(TaalMove m) => switch (m) {
  TaalMove.clap => _marigold,
  TaalMove.stepL || TaalMove.stepR => _peacock,
  TaalMove.waveL || TaalMove.waveR => _lilac,
  TaalMove.reachL || TaalMove.reachR => _mehendi,
  TaalMove.dip => const Color(0xFF7FD8FF),
  TaalMove.hoy => _kumkum,
};

IconData taalIcon(TaalMove m) => switch (m) {
  TaalMove.clap => Icons.front_hand_rounded,
  TaalMove.stepL => Icons.west_rounded,
  TaalMove.stepR => Icons.east_rounded,
  TaalMove.waveL || TaalMove.waveR => Icons.waving_hand_rounded,
  TaalMove.reachL => Icons.north_west_rounded,
  TaalMove.reachR => Icons.north_east_rounded,
  TaalMove.dip => Icons.south_rounded,
  TaalMove.hoy => Icons.celebration_rounded,
};

void _taalScene(
  Canvas c,
  Size s,
  double t, {
  double beat = 0,
  bool toofan = false,
}) {
  sky(
    c,
    s,
    toofan
        ? const [Color(0xFF3A0820), Color(0xFF6A1236), Color(0xFF2A0F2E)]
        : const [Color(0xFF14081F), Color(0xFF2A0F2E), Color(0xFF1A0A1C)],
  );
  // Light beams from the truss.
  for (var i = 0; i < 5; i++) {
    final x = s.width * (0.1 + i * 0.2);
    final a = math.sin(t * 0.8 + i) * 0.35;
    final col = [_kumkum, _marigold, _peacock, _lilac, _mehendi][i];
    final beam = Path()
      ..moveTo(x, 0)
      ..lineTo(x + math.sin(a) * s.height - 40, s.height * 0.9)
      ..lineTo(x + math.sin(a) * s.height + 40, s.height * 0.9)
      ..close();
    c.drawPath(
      beam,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [col.withValues(alpha: 0.35), col.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, s.width, s.height)),
    );
  }
  // Truss.
  c.drawRect(
    Rect.fromLTWH(0, 0, s.width, 14),
    Paint()..color = const Color(0xFF0B0510),
  );
  for (var i = 0; i < 5; i++) {
    c.drawCircle(
      Offset(s.width * (0.1 + i * 0.2), 12),
      7,
      Paint()..color = const Color(0xFFF6EEDC),
    );
  }
  // LED dance floor.
  final horizon = s.height * 0.66;
  final pulse = math.pow(1 - (beat % 1), 3).toDouble();
  const rows = 6, cols = 7;
  for (var r = 0; r < rows; r++) {
    for (var k = 0; k < cols; k++) {
      final y0 = horizon + (s.height - horizon) * (r / rows);
      final y1 = horizon + (s.height - horizon) * ((r + 1) / rows);
      final spread0 = 0.55 + 0.45 * r / rows,
          spread1 = 0.55 + 0.45 * (r + 1) / rows;
      double x(double f, double sp) =>
          s.width / 2 + (f - 0.5) * s.width * sp * 1.4;
      final path = Path()
        ..moveTo(x(k / cols, spread0), y0)
        ..lineTo(x((k + 1) / cols, spread0), y0)
        ..lineTo(x((k + 1) / cols, spread1), y1)
        ..lineTo(x(k / cols, spread1), y1)
        ..close();
      final lit = ((r + k + beat.floor()) % 3 == 0);
      final col = [_kumkum, _lilac, _peacock][(r + k) % 3];
      c.drawPath(
        path,
        Paint()..color = col.withValues(alpha: lit ? 0.18 + 0.4 * pulse : 0.06),
      );
      c.drawPath(
        path,
        Paint()
          ..color = const Color(0x33000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }
  // Speaker stacks.
  for (final x in [6.0, s.width - 46]) {
    for (var i = 0; i < 3; i++) {
      final r = Rect.fromLTWH(x, horizon - 110 + i * 38, 40, 36);
      c.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(4)),
        Paint()..color = const Color(0xFF16101C),
      );
      c.drawCircle(
        r.center,
        11 + 2 * pulse,
        Paint()..color = const Color(0xFF3A2A44),
      );
    }
  }
}

void _card(
  Canvas c,
  Offset at,
  double size,
  TaalMove m, {
  double alpha = 1,
  bool toofan = false,
}) {
  final col = toofan ? _marigold : taalColor(m);
  final r = RRect.fromRectAndRadius(
    Rect.fromCenter(center: at, width: size, height: size),
    Radius.circular(size * 0.24),
  );
  // A lit tile: a drop shadow, a face that falls from light to deep, and
  // a gloss across its upper half.
  c.drawRRect(
    r.shift(Offset(0, size * 0.07)).inflate(2),
    Paint()..color = const Color(0xFF000000).withValues(alpha: 0.35 * alpha),
  );
  c.drawRRect(
    r.inflate(3),
    Paint()..color = const Color(0xFF050B08).withValues(alpha: alpha),
  );
  c.drawRRect(
    r,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          shade(col, 0.3).withValues(alpha: alpha),
          col.withValues(alpha: alpha),
          shade(col, -0.35).withValues(alpha: alpha),
        ],
      ).createShader(r.outerRect),
  );
  c.drawRRect(
    RRect.fromRectAndCorners(
      Rect.fromLTRB(r.left + size * 0.06, r.top + size * 0.05, r.right - size * 0.06, r.top + size * 0.42),
      topLeft: Radius.circular(size * 0.2),
      topRight: Radius.circular(size * 0.2),
      bottomLeft: Radius.circular(size * 0.34),
      bottomRight: Radius.circular(size * 0.34),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.16 * alpha),
  );
  c.drawRRect(
    r.deflate(size * 0.08),
    Paint()
      ..color = Colors.white.withValues(alpha: 0.25 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  final icon = taalIcon(m);
  final tp = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: size * 0.58,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: const Color(0xFF14081F).withValues(alpha: alpha),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
}

void taalPlay(Canvas c, Size s, BodyMap m, TaalEngine e, double t) {
  final clock = e.clockMs;
  final horizon = Offset(s.width / 2, s.height * 0.28);
  final cards = e.visible.toList()..sort((a, b) => b.at.compareTo(a.at));
  for (final card in cards) {
    final (zx, zy) = taalZone(card.move);
    final target = m(zx, zy);
    final p = (1 - (card.at - clock) / e.leadMs).clamp(0.0, 1.1);
    final k = Curves.easeInQuad.transform(p.clamp(0.0, 1.0));
    final at = Offset.lerp(horizon, target, k)!;
    final size = m.unit * (0.35 + 0.55 * k);
    if (p > 0.55) {
      approachRing(
        c,
        target,
        m.unit * 0.55,
        (p - 0.55) / 0.45,
        taalColor(card.move),
        width: 5,
      );
    }
    glow(
      c,
      at,
      size,
      card.toofan ? _marigold : taalColor(card.move),
      alpha: 0.35 * k,
    );
    _card(c, at, size, card.move, alpha: 0.4 + 0.6 * k, toofan: card.toofan);
  }
  // Josh meter (right edge) and Toofan glow.
  final meter = Rect.fromLTWH(
    s.width - 22,
    s.height * 0.3,
    10,
    s.height * 0.36,
  );
  c.drawRRect(
    RRect.fromRectAndRadius(meter.inflate(3), const Radius.circular(8)),
    Paint()..color = const Color(0xCC050B08),
  );
  final fill = (e.toofan ? 1.0 : (e.josh / 32).clamp(0.0, 1.0));
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTRB(
        meter.left,
        meter.bottom - meter.height * fill,
        meter.right,
        meter.bottom,
      ),
      const Radius.circular(6),
    ),
    Paint()..color = e.toofan ? _marigold : _kumkum,
  );
  strokedText(
    c,
    'JOSH',
    Offset(meter.center.dx - 2, meter.top - 14),
    size: 10,
    color: _kumkum,
  );
  // Band stems lit as the band builds.
  const stems = [
    ('drums', Icons.album_rounded),
    ('dhol', Icons.circle_rounded),
    ('claps', Icons.front_hand_rounded),
    ('melody', Icons.music_note_rounded),
    ('bass', Icons.graphic_eq_rounded),
    ('toofan', Icons.bolt_rounded),
  ];
  for (var i = 0; i < stems.length; i++) {
    final on = e.stems.contains(stems[i].$1);
    final at = Offset(16, s.height * 0.32 + i * 30);
    c.drawCircle(
      at,
      11,
      Paint()..color = on ? _marigold : const Color(0x33F6EEDC),
    );
    final icon = stems[i].$2;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 13,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: on ? const Color(0xFF14081F) : const Color(0x88F6EEDC),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }
  if (e.toofan) {
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..color = _marigold.withValues(alpha: 0.2 + 0.15 * math.sin(t * 7))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12,
    );
  }
}

void taalPreview(Canvas c, Size s, int variant) {
  taalBackdrop(c, s, 1.0 + variant, beat: 0.15, toofan: variant == 3);
  final vp = viewportFor(s, topShare: 0.6);
  final m = BodyMap.demo(vp);
  final j = switch (variant) {
    1 => AvatarJoints.demo(m, shoulderL: 120, shoulderR: 20),
    2 => AvatarJoints.demo(
      m,
      shoulderL: 35,
      elbowL: 70,
      shoulderR: 35,
      elbowR: 70,
    ),
    3 => AvatarJoints.demo(m, shoulderL: 165, shoulderR: 165),
    _ => AvatarJoints.demo(m, lean: -10, shoulderR: 140),
  };
  paintAvatar(c, j, look: taalLook);
  final horizon = Offset(s.width / 2, s.height * 0.28);
  void card(TaalMove mv, double k) {
    final (zx, zy) = taalZone(mv);
    final target = m(zx, zy);
    final at = Offset.lerp(horizon, target, k)!;
    if (k > 0.8) {
      approachRing(c, target, m.unit * 0.55, 0.9, taalColor(mv), width: 5);
    }
    _card(
      c,
      at,
      m.unit * (0.35 + 0.55 * k),
      mv,
      toofan: variant == 3 && mv == TaalMove.hoy,
    );
  }

  switch (variant) {
    case 1:
      card(TaalMove.waveL, 0.95);
      card(TaalMove.clap, 0.4);
    case 2:
      card(TaalMove.clap, 1.0);
      confetti(c, m(0, -0.45), 0.3, const [_marigold, _kumkum], spread: 50);
      card(TaalMove.stepR, 0.35);
    case 3:
      card(TaalMove.hoy, 0.95);
      strokedText(
        c,
        'TOOFAN TIME',
        Offset(s.width / 2, s.height * 0.88),
        size: s.height * 0.1,
        color: _marigold,
      );
    default:
      card(TaalMove.stepL, 0.9);
      card(TaalMove.reachR, 0.6);
      card(TaalMove.clap, 0.2);
  }
}

/// The concert stage: beams, an LED floor and speaker stacks, seen from the
/// front of the crowd — stage haze catches the beams, the floor throws
/// light back up, and a row of hands in front bounces on the beat.
void taalBackdrop(
  Canvas c,
  Size s,
  double t, {
  double beat = 0,
  bool toofan = false,
}) {
  _taalScene(c, s, t, beat: beat, toofan: toofan);
  final horizon = s.height * 0.66;
  final pulse = math.pow(1 - (beat % 1), 3).toDouble();
  hazeBand(c, s, horizon - s.height * 0.08, s.height * 0.3, toofan ? _marigold : _lilac, alpha: 0.14 + 0.1 * pulse);
  lightPool(
    c,
    Offset(s.width / 2, horizon + (s.height - horizon) * 0.5),
    s.width * 1.1,
    (s.height - horizon) * 0.9,
    toofan ? _marigold : _kumkum,
    alpha: 0.12 + 0.16 * pulse,
  );
  bokeh(c, s, t, const [_kumkum, _marigold, _peacock, _lilac], n: 7, minY: 0.05, maxY: 0.5, alpha: 0.12, seed: 11);
  // The crowd in front: heads and raised hands, dark against the stage.
  final crowd = Paint()..color = const Color(0xF20A0510);
  final arm = Paint()
    ..color = const Color(0xF20A0510)
    ..strokeWidth = s.width * 0.016
    ..strokeCap = StrokeCap.round;
  const people = 9;
  for (var i = 0; i < people; i++) {
    final x = s.width * (i + 0.5) / people + (hash(i) - 0.5) * 14;
    final bob = pulse * (6 + 6 * hash(i * 3)) * (toofan ? 1.6 : 1);
    final r = s.width * (0.036 + 0.014 * hash(i * 7));
    final y = s.height - r * (0.7 + 0.9 * hash(i * 5)) - bob;
    c.drawCircle(Offset(x, y), r, crowd);
    c.drawRect(Rect.fromLTRB(x - r * 1.3, y + r * 0.7, x + r * 1.3, s.height), crowd);
    if (i.isEven || toofan) {
      final lift = r * (2.2 + 0.8 * hash(i * 11)) + bob;
      c.drawLine(Offset(x - r, y + r), Offset(x - r * 1.5, y - lift), arm);
      c.drawLine(Offset(x + r, y + r), Offset(x + r * 1.5, y - lift * 0.9), arm);
    }
  }
  vignette(c, s, strength: 0.55);
}
