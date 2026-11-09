import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';

import 'paint_kit.dart';

const _peacock = Color(0xFF00C2B8);
const _scarf = Color(0xFF3FD0C0);
const _chalk = Color(0xFFF2F0E6);
const _tape = Color(0xFFFFD23F);

/// Evening gully: houses with lit windows, a streetlight, a washing line
/// and the pitch running back to the bowler.
void cricketBackdrop(Canvas c, Size s, double t) {
  sky(
    c,
    s,
    const [Color(0xFF0B2A3A), Color(0xFF1D4E5A), Color(0xFFE08A4A)],
    stops: const [0, 0.55, 1],
  );
  final horizon = s.height * 0.52;
  // Houses on both sides.
  for (var i = 0; i < 6; i++) {
    final leftSide = i < 3;
    final k = i % 3;
    final w = s.width * (0.22 - k * 0.03);
    final h = s.height * (0.32 - k * 0.06);
    final x = leftSide
        ? k * s.width * 0.12 - 10
        : s.width - w - k * s.width * 0.12 + 10;
    final r = Rect.fromLTWH(x, horizon - h + 30, w, h);
    c.drawRect(
      r,
      Paint()
        ..color = [
          const Color(0xFF2E3A4A),
          const Color(0xFF3C2E3E),
          const Color(0xFF26404A),
        ][k],
    );
    // Windows.
    for (var wy = 0; wy < 3; wy++) {
      for (var wx = 0; wx < 2; wx++) {
        final lit = hash(i * 10 + wy * 2 + wx) > 0.35;
        final win = Rect.fromLTWH(
          r.left + w * (0.18 + wx * 0.42),
          r.top + h * (0.12 + wy * 0.26),
          w * 0.24,
          h * 0.14,
        );
        c.drawRect(
          win,
          Paint()
            ..color = lit ? const Color(0xFFFFD27A) : const Color(0xFF1A2230),
        );
        if (lit) glow(c, win.center, 18, const Color(0xFFFFD27A), alpha: 0.25);
      }
    }
    // Water tank on the roof.
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r.left + w * 0.3, r.top - 16, w * 0.3, 16),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF111820),
    );
  }
  // Washing line with kurtas.
  final line = Path()
    ..moveTo(s.width * 0.12, horizon - 40)
    ..quadraticBezierTo(
      s.width * 0.5,
      horizon - 10,
      s.width * 0.88,
      horizon - 40,
    );
  c.drawPath(
    line,
    Paint()
      ..color = const Color(0x88F2F0E6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
  for (var i = 0; i < 5; i++) {
    final x = s.width * (0.22 + i * 0.14);
    final y =
        horizon -
        34 +
        18 * (1 - math.pow((x / s.width - 0.5) * 2, 2)).toDouble();
    final sway = math.sin(t * 1.5 + i) * 2;
    c.drawRect(
      Rect.fromLTWH(x - 8 + sway, y, 16, 22),
      Paint()
        ..color = [
          _peacock,
          const Color(0xFFFF4D6D),
          _tape,
          const Color(0xFFB98CFF),
          _scarf,
        ][i],
    );
  }
  // Road and pitch.
  final road = Path()
    ..moveTo(s.width * 0.38, horizon)
    ..lineTo(s.width * 0.62, horizon)
    ..lineTo(s.width * 1.1, s.height)
    ..lineTo(-s.width * 0.1, s.height)
    ..close();
  c.drawPath(road, Paint()..color = const Color(0xFF3A3A40));
  final pitch = Path()
    ..moveTo(s.width * 0.47, horizon)
    ..lineTo(s.width * 0.53, horizon)
    ..lineTo(s.width * 0.72, s.height)
    ..lineTo(s.width * 0.28, s.height)
    ..close();
  c.drawPath(pitch, Paint()..color = const Color(0xFF8A6A4A));
  c.drawLine(
    Offset(s.width * 0.3, s.height * 0.93),
    Offset(s.width * 0.7, s.height * 0.93),
    Paint()
      ..color = _chalk
      ..strokeWidth = 3,
  );
  // Streetlight.
  final pole = Offset(s.width * 0.9, horizon + 10);
  c.drawLine(
    pole,
    pole - Offset(0, s.height * 0.3),
    Paint()
      ..color = const Color(0xFF1A1E24)
      ..strokeWidth = 5,
  );
  final bulb = pole - Offset(18, s.height * 0.3 - 6);
  glow(c, bulb, 60, const Color(0xFFFFE6A0), alpha: 0.45);
  c.drawCircle(bulb, 6, Paint()..color = const Color(0xFFFFF2CC));
}

/// Golu the rhino, the gully's original bowler.
void paintGolu(
  Canvas c,
  Offset at,
  double size,
  double run, {
  bool bowl = false,
}) {
  final body = Paint()..color = const Color(0xFF8E96A3);
  final dark = Paint()..color = const Color(0xFF050B08);
  final bob = math.sin(run * math.pi * 6) * size * 0.04;
  final b = at + Offset(0, bob);
  c.drawOval(
    Rect.fromCenter(
      center: b,
      width: size * 0.62,
      height: size * 0.8,
    ).inflate(2),
    dark,
  );
  c.drawOval(
    Rect.fromCenter(center: b, width: size * 0.62, height: size * 0.8),
    body,
  );
  final head = b - Offset(0, size * 0.5);
  c.drawCircle(head, size * 0.24 + 2, dark);
  c.drawCircle(head, size * 0.24, body);
  final horn = Path()
    ..moveTo(head.dx - size * 0.05, head.dy - size * 0.05)
    ..lineTo(head.dx, head.dy - size * 0.32)
    ..lineTo(head.dx + size * 0.05, head.dy - size * 0.05)
    ..close();
  c.drawPath(horn, Paint()..color = _chalk);
  // Cap.
  c.drawArc(
    Rect.fromCircle(center: head, radius: size * 0.24),
    math.pi,
    math.pi,
    true,
    Paint()..color = _peacock,
  );
  c.drawCircle(head + Offset(-size * 0.08, size * 0.02), size * 0.03, dark);
  c.drawCircle(head + Offset(size * 0.08, size * 0.02), size * 0.03, dark);
  final arm = Paint()
    ..color = const Color(0xFF7A828F)
    ..strokeWidth = size * 0.12
    ..strokeCap = StrokeCap.round;
  final sh = b - Offset(0, size * 0.25);
  final swing = bowl ? -math.pi * 0.9 * run : math.sin(run * math.pi * 6) * 0.6;
  c.drawLine(
    sh,
    sh + Offset(math.sin(swing) * size * 0.4, -math.cos(swing) * size * 0.4),
    arm,
  );
  c.drawLine(sh, sh + Offset(-size * 0.3, size * 0.25), arm);
}

/// The bat in the player's hands: from the hand midpoint, away from the
/// shoulders. Drawn only when both hands are tracked.
void paintBat(Canvas c, BodyMap m, BodyPose? p) {
  if (p == null) return;
  final l = p.leftHand, r = p.rightHand;
  if (!l.seen || !r.seen) return;
  final mx = (l.x + r.x) / 2, my = (l.y + r.y) / 2;
  final dir = Offset(mx, my + 0.1);
  final len = dir.distance == 0 ? 1.0 : dir.distance;
  final tip = Offset(mx, my) + dir / len * 1.6;
  final a = m(mx, my), b = m(tip.dx, tip.dy);
  c.drawLine(
    a,
    b,
    Paint()
      ..color = const Color(0xFF050B08)
      ..strokeWidth = m.unit * 0.3
      ..strokeCap = StrokeCap.round,
  );
  c.drawLine(
    a,
    b,
    Paint()
      ..color = const Color(0xFFD9B27A)
      ..strokeWidth = m.unit * 0.22
      ..strokeCap = StrokeCap.round,
  );
  c.drawLine(
    a,
    Offset.lerp(a, b, 0.3)!,
    Paint()
      ..color = _peacock
      ..strokeWidth = m.unit * 0.24
      ..strokeCap = StrokeCap.round,
  );
}

/// Where the ball arrives, beside the player on the bowler's side (body
/// space). Height varies with the line; a wide is out of reach.
(double, double) hitZone(BallLine l) => switch (l) {
  BallLine.off => (-1.15, -0.55),
  BallLine.middle => (-1.1, -0.95),
  BallLine.leg => (-1.05, -1.35),
  BallLine.wide => (-2.4, -0.9),
};

/// Golu bowls from the player's left, in the image plane, so the swing
/// across the body meets the ball.
Offset bowlerAt(Size s, BodyMap m) =>
    Offset(math.max(34, m(-3.4, 0).dx), m(0, -1.4).dy);

void cricketPlay(
  Canvas c,
  Size s,
  BodyMap m,
  CricketEngine e,
  BodyPose? pose,
  double t,
) {
  final d = e.current;
  final bowler = bowlerAt(s, m);
  final run = e.phase == 'runup' ? e.ballProgress : 0.0;
  paintGolu(
    c,
    bowler,
    m.unit * 1.5,
    e.clockMs / 1000,
    bowl: e.phase == 'runup' && run < 0.3,
  );
  // Chalk stumps on the wall behind the batter.
  final stumps = m(0.35, -1.9);
  for (var i = -1; i <= 1; i++) {
    c.drawLine(
      stumps + Offset(i * m.unit * 0.14, 0),
      stumps + Offset(i * m.unit * 0.14, m.unit * 1.0),
      Paint()
        ..color = _chalk.withValues(alpha: 0.55)
        ..strokeWidth = 3,
    );
  }
  if (d != null && e.phase == 'runup') {
    final (hx, hy) = hitZone(d.line);
    final hit = m(hx, hy);
    final p = e.ballProgress;
    approachRing(
      c,
      hit,
      m.unit * 0.55,
      p,
      d.line == BallLine.wide ? const Color(0xFFFFC857) : _scarf,
      width: 5,
    );
    final release = bowler + Offset(m.unit * 0.3, -m.unit * 0.9);
    final k = p.clamp(0.0, 1.0);
    final ball = Offset.lerp(release, hit, k)!;
    // One bounce on the way, like a tape ball on the gully road.
    final bounce = -math.sin(k * math.pi) * m.unit * 0.8;
    final at = ball + Offset(0, bounce);
    c.drawOval(
      Rect.fromCenter(
        center: Offset(at.dx, m(0, -2.9).dy),
        width: 16,
        height: 5,
      ),
      Paint()..color = const Color(0x55000000),
    );
    c.drawCircle(at, 7 + 5 * k, Paint()..color = const Color(0xFFF2F0E6));
    c.drawArc(
      Rect.fromCircle(center: at, radius: 7 + 5 * k),
      -0.6,
      1.2,
      false,
      Paint()
        ..color = _tape
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    if (d.line == BallLine.wide) {
      strokedText(
        c,
        'WIDE? ARMS UP',
        hit + Offset(0, m.unit * 0.9),
        size: 16,
        color: const Color(0xFFFFC857),
      );
    }
  }
  paintBat(c, m, pose);
  // This over: one dot per delivery.
  final balls = e.deliveries.where((x) => !x.dead).toList();
  final shown = math.min(math.max(6, e.format.balls), 12);
  final w = shown * 22.0;
  for (var i = 0; i < shown; i++) {
    final at = Offset((s.width - w) / 2 + i * 22 + 11, s.height - 26);
    final ball = i < balls.length
        ? balls[balls.length > shown ? balls.length - shown + i : i]
        : null;
    final r = ball?.result;
    final col = r == null
        ? const Color(0x33F2F0E6)
        : r < 0
        ? const Color(0xFFFF6B5A)
        : r >= 4
        ? _tape
        : r > 0
        ? _scarf
        : const Color(0x88F2F0E6);
    c.drawCircle(at, 9, Paint()..color = col);
    if (r != null) {
      strokedText(
        c,
        r < 0 ? 'W' : '$r',
        at,
        size: 11,
        color: const Color(0xFF050B08),
      );
    }
  }
}

void cricketPreview(Canvas c, Size s, int variant) {
  cricketBackdrop(c, s, 1 + variant.toDouble());
  final m = BodyMap(Offset(s.width * 0.62, s.height * 0.36), s.height * 0.13);
  final bowler = Offset(s.width * 0.13, m(0, -1.4).dy);
  paintGolu(c, bowler, m.unit * 1.5, 0.4, bowl: variant == 0);
  final j = switch (variant) {
    1 => AvatarJoints.demo(m, shoulderL: 150, shoulderR: 150),
    2 => AvatarJoints.demo(
      m,
      shoulderL: 40,
      elbowL: 80,
      shoulderR: 40,
      elbowR: 80,
      lean: -6,
    ),
    _ => AvatarJoints.demo(
      m,
      shoulderL: 120,
      elbowL: 110,
      shoulderR: 130,
      elbowR: 120,
      lean: 4,
    ),
  };
  paintAvatar(c, j, accent: _peacock);
  final hands = (j.p[AvatarJoints.lWr] + j.p[AvatarJoints.rWr]) / 2;
  if (variant != 1) {
    final tip = variant == 2
        ? hands + Offset(-m.unit * 1.5, m.unit * 0.2)
        : hands + Offset(m.unit * 0.9, -m.unit * 1.1);
    c.drawLine(
      hands,
      tip,
      Paint()
        ..color = const Color(0xFF050B08)
        ..strokeWidth = m.unit * 0.3
        ..strokeCap = StrokeCap.round,
    );
    c.drawLine(
      hands,
      tip,
      Paint()
        ..color = const Color(0xFFD9B27A)
        ..strokeWidth = m.unit * 0.22
        ..strokeCap = StrokeCap.round,
    );
  }
  final (hx, hy) = hitZone(variant == 1 ? BallLine.wide : BallLine.middle);
  final hit = m(hx, hy);
  final k = variant == 2 ? 1.0 : 0.65;
  approachRing(
    c,
    hit,
    m.unit * 0.55,
    k,
    variant == 1 ? const Color(0xFFFFC857) : _scarf,
    width: 5,
  );
  final release = bowler + Offset(m.unit * 0.3, -m.unit * 0.9);
  final ball =
      Offset.lerp(release, hit, k)! +
      Offset(0, -math.sin(k * math.pi) * m.unit * 0.8);
  c.drawCircle(ball, 9, Paint()..color = _chalk);
  if (variant == 2) {
    strokedText(
      c,
      'SIX!',
      Offset(s.width * 0.3, s.height * 0.2),
      size: s.height * 0.16,
      color: _tape,
    );
    confetti(c, hit, 0.4, const [
      _tape,
      _scarf,
      Color(0xFFFF4D6D),
    ], spread: m.unit * 2);
  }
}
