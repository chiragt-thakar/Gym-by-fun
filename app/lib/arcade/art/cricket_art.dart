import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';

import 'looks.dart';
import 'paint_kit.dart';

const _peacock = Color(0xFF00C2B8);
const _scarf = Color(0xFF3FD0C0);
const _chalk = Color(0xFFF2F0E6);
const _tape = Color(0xFFFFD23F);

/// Evening gully: houses with lit windows, a streetlight, a washing line
/// and the pitch running back to the bowler.
void _cricketScene(Canvas c, Size s, double t) {
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
  const hide = Color(0xFF8E96A3);
  const dark = Color(0xFF07090D);
  final cycle = math.sin(run * math.pi * 6);
  final bob = cycle * size * 0.04;
  final b = at + Offset(0, bob);
  softShadow(c, at + Offset(0, size * 0.66), size * 0.9, size * 0.16, alpha: 0.4);

  // Legs: a short running stride, the far leg first.
  for (final side in [-1.0, 1.0]) {
    final hip = b + Offset(side * size * 0.14, size * 0.28);
    final foot = at + Offset(side * size * 0.16 + side * cycle * size * 0.1, size * 0.62 - (side * cycle > 0 ? size * 0.06 : 0));
    shadedLimb(c, hip, foot, size * 0.1, size * 0.085, shade(hide, -0.15));
    shadedLimb(c, foot, foot + Offset(side * size * 0.08, size * 0.02), size * 0.07, size * 0.06, const Color(0xFFF2F0E6));
  }
  // Barrel body in a team vest.
  final body = Rect.fromCenter(center: b, width: size * 0.62, height: size * 0.8);
  c.drawOval(body.inflate(2.5), Paint()..color = dark);
  c.drawOval(
    body,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.5),
        radius: 1.1,
        colors: [shade(hide, 0.25), hide, shade(hide, -0.45)],
        stops: const [0, 0.5, 1],
      ).createShader(body),
  );
  c.save();
  c.clipPath(Path()..addOval(body));
  c.drawRect(
    Rect.fromLTRB(body.left, b.dy - size * 0.2, body.right, b.dy + size * 0.24),
    Paint()
      ..shader = LinearGradient(
        colors: [shade(_peacock, 0.15), shade(_peacock, -0.4)],
      ).createShader(body),
  );
  c.drawRect(
    Rect.fromLTRB(body.left, b.dy - size * 0.02, body.right, b.dy + size * 0.04),
    Paint()..color = _tape,
  );
  c.restore();

  // Arms: the bowling arm comes over the top as he releases.
  final sh = b - Offset(0, size * 0.25);
  final swing = bowl ? -math.pi * 0.9 * run : cycle * 0.6;
  shadedLimb(c, sh + Offset(-size * 0.2, size * 0.04), sh + Offset(-size * 0.36, size * 0.3), size * 0.07, size * 0.06, hide);
  final hand = sh + Offset(size * 0.2, 0) + Offset(math.sin(swing) * size * 0.42, -math.cos(swing) * size * 0.42);
  shadedLimb(c, sh + Offset(size * 0.2, size * 0.02), hand, size * 0.075, size * 0.06, hide);

  // Head: ears, a broad snout, the horn and a cap.
  final head = b - Offset(0, size * 0.5);
  for (final side in [-1.0, 1.0]) {
    shadedBall(c, head + Offset(side * size * 0.2, -size * 0.16), size * 0.07, shade(hide, -0.1));
  }
  c.drawCircle(head, size * 0.24 + 2.5, Paint()..color = dark);
  shadedBall(c, head, size * 0.24, hide);
  final snout = head + Offset(0, size * 0.1);
  c.drawOval(
    Rect.fromCenter(center: snout, width: size * 0.3, height: size * 0.2),
    Paint()..color = shade(hide, 0.12),
  );
  final horn = Path()
    ..moveTo(snout.dx - size * 0.06, snout.dy - size * 0.03)
    ..quadraticBezierTo(snout.dx - size * 0.02, snout.dy - size * 0.2, snout.dx + size * 0.02, snout.dy - size * 0.3)
    ..quadraticBezierTo(snout.dx + size * 0.05, snout.dy - size * 0.14, snout.dx + size * 0.06, snout.dy - size * 0.03)
    ..close();
  c.drawPath(
    horn,
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFFFFBEF), Color(0xFFC9C2AE)],
      ).createShader(horn.getBounds()),
  );
  for (final side in [-1.0, 1.0]) {
    c.drawCircle(snout + Offset(side * size * 0.07, size * 0.03), size * 0.016, Paint()..color = dark);
    final eye = head + Offset(side * size * 0.1, -size * 0.03);
    c.drawCircle(eye, size * 0.04, Paint()..color = const Color(0xFFF7F4EA));
    c.drawCircle(eye + Offset(size * 0.008, size * 0.006), size * 0.022, Paint()..color = dark);
  }
  // Cap with a peak.
  c.drawArc(
    Rect.fromCircle(center: head, radius: size * 0.245),
    math.pi * 1.05,
    math.pi * 0.9,
    true,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [shade(_peacock, 0.25), shade(_peacock, -0.3)],
      ).createShader(Rect.fromCircle(center: head, radius: size * 0.245)),
  );
  c.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(head.dx - size * 0.26, head.dy - size * 0.1, size * 0.34, size * 0.05),
      Radius.circular(size * 0.03),
    ),
    Paint()..color = shade(_peacock, -0.35),
  );
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
    glossSphere(c, at, 7 + 5 * k, const Color(0xFFF2F0E6));
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
  paintAvatar(c, j, look: cricketLook);
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
  glossSphere(c, ball, 9, _chalk);
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

/// The gully at the end of the day: the sun low behind the houses, long
/// shadows across the road, the streetlight just on, dust hanging in the
/// warm air.
void cricketBackdrop(Canvas c, Size s, double t) {
  _cricketScene(c, s, t);
  final horizon = s.height * 0.52;
  final depth = s.height - horizon;
  // Low sun at the end of the lane.
  final sun = Offset(s.width * 0.5, horizon - 6);
  glow(c, sun, s.width * 0.5, const Color(0xFFFFB45A), alpha: 0.45);
  glow(c, sun, s.width * 0.16, const Color(0xFFFFF0C8), alpha: 0.6);
  // Long shadows of the houses, falling towards the player.
  for (final (x0, x1) in [(0.0, 0.3), (1.0, 0.7)]) {
    final shadow = Path()
      ..moveTo(s.width * x0, horizon)
      ..lineTo(s.width * x1, horizon)
      ..lineTo(s.width * (x1 + (x1 - 0.5) * 0.5), s.height)
      ..lineTo(s.width * x0, s.height)
      ..close();
    c.drawPath(
      shadow,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x66101822), Color(0x22101822)],
        ).createShader(Rect.fromLTRB(0, horizon, s.width, s.height)),
    );
  }
  // Sunlight down the middle of the pitch.
  lightPool(c, Offset(s.width / 2, horizon + depth * 0.4), s.width * 0.5, depth * 1.2, const Color(0xFFFFD9A0), alpha: 0.22);
  // The streetlight's cone.
  lightShaft(c, Offset(s.width * 0.9 - 18, horizon + 16 - s.height * 0.3), s.height * 0.36, s.width * 0.14, const Color(0xFFFFE6A0), alpha: 0.2, lean: -s.width * 0.04);
  hazeBand(c, s, horizon, s.height * 0.14, const Color(0xFFFFC08A), alpha: 0.3);
  final mote = Paint();
  for (var i = 0; i < 16; i++) {
    final x = (hash(i * 7 + 3) + t * 0.004 * (1 + hash(i))) % 1 * s.width;
    final y = horizon - s.height * 0.1 + depth * hash(i * 5 + 2);
    mote.color = const Color(0xFFFFE9C2).withValues(alpha: 0.1 + 0.2 * hash(i));
    c.drawCircle(Offset(x, y + math.sin(t * 0.7 + i) * 4), 1.3, mote);
  }
  vignette(c, s, strength: 0.45);
}
