import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:motion_core/motion_core.dart';

/// Maps body space (torso units from the shoulder centre, +y up) onto the
/// canvas. In play it follows the real landmarks; in previews it is a fixed
/// demo body. Original vector art only: no camera pixels are ever painted.
class BodyMap {
  const BodyMap(this.origin, this.unit);
  final Offset origin;

  /// Pixels per torso length.
  final double unit;

  Offset call(double x, double y) =>
      Offset(origin.dx + x * unit, origin.dy - y * unit);

  /// [vp] is the 3:4 camera viewport on screen.
  factory BodyMap.fromPose(BodyPose p, Rect vp) {
    final (x0, y0) = p.toImage(0, 0);
    final (x1, y1) = p.toImage(0, 1);
    final o = Offset(vp.left + x0 * vp.width, vp.top + y0 * vp.height);
    final u =
        (Offset(vp.left + x1 * vp.width, vp.top + y1 * vp.height) - o).distance;
    return BodyMap(o, u);
  }

  /// A standing player in the middle of the viewport (previews).
  factory BodyMap.demo(Rect vp, {double dx = 0}) => BodyMap(
    Offset(vp.center.dx + dx * vp.width, vp.top + vp.height * 0.36),
    vp.height * 0.16,
  );
}

/// The 3:4 viewport the camera sees, fitted to the width of [size] and
/// placed so the game's HUD has room above and below.
Rect viewportFor(Size size, {double topShare = 0.5}) {
  final w = size.width;
  var h = w * 4 / 3;
  var vw = w;
  if (h > size.height * 0.86) {
    h = size.height * 0.86;
    vw = h * 3 / 4;
  }
  final top = (size.height - h) * topShare;
  return Rect.fromLTWH((w - vw) / 2, top, vw, h);
}

/// Joint positions for the stylised avatar, on the canvas.
class AvatarJoints {
  AvatarJoints(this.p, this.vis);

  /// head, lSh, rSh, lEl, rEl, lWr, rWr, lHip, rHip, lKn, rKn, lAn, rAn
  final List<Offset> p;
  final List<double> vis;

  static const head = 0, lSh = 1, rSh = 2, lEl = 3, rEl = 4, lWr = 5;
  static const rWr = 6, lHip = 7, rHip = 8, lKn = 9, rKn = 10, lAn = 11;
  static const rAn = 12;

  double get unit {
    final sh = (p[lSh] + p[rSh]) / 2, hp = (p[lHip] + p[rHip]) / 2;
    return math.max(8, (sh - hp).distance);
  }

  static const _lm = [
    Lm.nose,
    Lm.leftShoulder,
    Lm.rightShoulder,
    Lm.leftElbow,
    Lm.rightElbow,
    Lm.leftWrist,
    Lm.rightWrist,
    Lm.leftHip,
    Lm.rightHip,
    Lm.leftKnee,
    Lm.rightKnee,
    Lm.leftAnkle,
    Lm.rightAnkle,
  ];

  /// From live landmarks (already smoothed) placed in the viewport.
  static AvatarJoints? fromFrame(PoseFrame? f, Rect vp) {
    if (f == null || !f.hasPerson) return null;
    return AvatarJoints(
      [
        for (final i in _lm)
          Offset(vp.left + f[i].x * vp.width, vp.top + f[i].y * vp.height),
      ],
      [for (final i in _lm) f[i].visibility],
    );
  }

  /// A posed demo body for previews. Angles in degrees, like the games use.
  static AvatarJoints demo(
    BodyMap m, {
    double shoulderL = 12,
    double shoulderR = 12,
    double elbowL = 170,
    double elbowR = 170,
    double hipL = 7,
    double hipR = 7,
    double lean = 0,
    double dip = 0,
    bool bendInL = false,
    bool bendInR = false,
  }) {
    double r(double d) => d * math.pi / 180;
    Offset rot(Offset v, double deg) {
      final a = r(deg);
      return Offset(
        v.dx * math.cos(a) - v.dy * math.sin(a),
        v.dx * math.sin(a) + v.dy * math.cos(a),
      );
    }

    // Body space with y up; convert at the end.
    final hip = Offset(0, -1 - dip * 0.35);
    final up = Offset(math.sin(r(lean)), math.cos(r(lean)));
    final across = Offset(math.cos(r(lean)), -math.sin(r(lean)));
    final sh = hip + up;
    final lSh = sh - across * 0.36, rSh = sh + across * 0.36;
    final down = -up;
    // In y-up space, rotating "outward" for the left arm is clockwise.
    final lUp = rot(down, -shoulderL), rUp = rot(down, shoulderR);
    final lEl = lSh + lUp * 0.62, rEl = rSh + rUp * 0.62;
    final lBend = (bendInL || shoulderL < 60) ? 1 : -1;
    final rBend = (bendInR || shoulderR < 60) ? -1 : 1;
    final lWr = lEl + rot(lUp, lBend * (180 - elbowL)) * 0.56;
    final rWr = rEl + rot(rUp, rBend * (180 - elbowR)) * 0.56;
    final lHip = hip - across * 0.24, rHip = hip + across * 0.24;
    final knee = 0.85 - dip * 0.25;
    final lKn = lHip + rot(const Offset(0, -1), -hipL) * knee;
    final rKn = rHip + rot(const Offset(0, -1), hipR) * knee;
    final lAn = Offset(lKn.dx - dip * 0.12, -3.0 + 0.05);
    final rAn = Offset(rKn.dx + dip * 0.12, -3.0 + 0.05);
    final headP = sh + up * 0.48;
    final pts = [headP, lSh, rSh, lEl, rEl, lWr, rWr, lHip, rHip, lKn, rKn];
    return AvatarJoints([
      for (final q in pts) m(q.dx, q.dy),
      m(lAn.dx, lAn.dy),
      m(rAn.dx, rAn.dy),
    ], List.filled(13, 1));
  }
}

/// Paints the original MotionQuest body avatar: rounded capsule limbs, a
/// soft torso and a round head. With [outlineOnly] (camera mirror on) it is
/// a light outline over the player's own image.
void paintAvatar(
  Canvas c,
  AvatarJoints j, {
  Color body = const Color(0xFF2E6B5A),
  Color limb = const Color(0xFF3E8C74),
  Color outline = const Color(0xFF050B08),
  Color accent = const Color(0xFFFF9A3C),
  bool outlineOnly = false,
  double opacity = 1,
}) {
  final u = j.unit;
  final p = j.p, v = j.vis;
  bool ok(int a) => v[a] > 0.35;
  final under = Paint()
    ..color = outline.withValues(alpha: 0.75 * opacity)
    ..strokeCap = StrokeCap.round;
  final fill = Paint()
    ..color = (outlineOnly ? Colors.white : limb).withValues(
      alpha: (outlineOnly ? 0.85 : 1) * opacity,
    )
    ..strokeCap = StrokeCap.round;
  void bone(int a, int b, double w) {
    if (!ok(a) || !ok(b)) return;
    under.strokeWidth = w + u * 0.08;
    fill.strokeWidth = outlineOnly ? math.max(3, w * 0.25) : w;
    c.drawLine(p[a], p[b], under);
    c.drawLine(p[a], p[b], fill);
  }

  const lSh = AvatarJoints.lSh, rSh = AvatarJoints.rSh;
  const lHip = AvatarJoints.lHip, rHip = AvatarJoints.rHip;
  // Legs, then torso, then arms (arms in front).
  bone(lHip, AvatarJoints.lKn, u * 0.3);
  bone(AvatarJoints.lKn, AvatarJoints.lAn, u * 0.26);
  bone(rHip, AvatarJoints.rKn, u * 0.3);
  bone(AvatarJoints.rKn, AvatarJoints.rAn, u * 0.26);
  if (ok(lSh) && ok(rSh) && ok(lHip) && ok(rHip)) {
    final torso = Path()
      ..moveTo(p[lSh].dx, p[lSh].dy)
      ..lineTo(p[rSh].dx, p[rSh].dy)
      ..lineTo(p[rHip].dx, p[rHip].dy)
      ..lineTo(p[lHip].dx, p[lHip].dy)
      ..close();
    if (!outlineOnly) {
      c.drawPath(
        torso,
        Paint()
          ..color = outline.withValues(alpha: 0.75 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.36
          ..strokeJoin = StrokeJoin.round,
      );
      c.drawPath(
        torso,
        Paint()
          ..color = body.withValues(alpha: opacity)
          ..style = PaintingStyle.fill,
      );
      c.drawPath(
        torso,
        Paint()
          ..color = body.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = u * 0.28
          ..strokeJoin = StrokeJoin.round,
      );
      // Scarf: the explorer's teal band, here in the game accent.
      c.drawLine(
        p[lSh] + Offset(0, u * 0.08),
        p[rSh] + Offset(0, u * 0.08),
        Paint()
          ..color = accent.withValues(alpha: opacity)
          ..strokeWidth = u * 0.16
          ..strokeCap = StrokeCap.round,
      );
    } else {
      c.drawPath(
        torso,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }
  bone(lSh, AvatarJoints.lEl, u * 0.24);
  bone(AvatarJoints.lEl, AvatarJoints.lWr, u * 0.21);
  bone(rSh, AvatarJoints.rEl, u * 0.24);
  bone(AvatarJoints.rEl, AvatarJoints.rWr, u * 0.21);
  for (final w in [AvatarJoints.lWr, AvatarJoints.rWr]) {
    if (!ok(w)) continue;
    c.drawCircle(p[w], u * 0.15, under);
    c.drawCircle(
      p[w],
      u * (outlineOnly ? 0.1 : 0.13),
      Paint()
        ..color = (outlineOnly ? accent : const Color(0xFFF6EEDC)).withValues(
          alpha: opacity,
        ),
    );
  }
  if (ok(AvatarJoints.head)) {
    final hc = ok(lSh) && ok(rSh)
        ? Offset(p[AvatarJoints.head].dx, p[AvatarJoints.head].dy)
        : p[AvatarJoints.head];
    final r = u * 0.24;
    if (outlineOnly) {
      c.drawCircle(
        hc,
        r,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7 * opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    } else {
      c.drawCircle(
        hc,
        r + u * 0.05,
        Paint()..color = outline.withValues(alpha: 0.75 * opacity),
      );
      c.drawCircle(hc, r, Paint()..color = limb.withValues(alpha: opacity));
      c.drawCircle(
        hc + Offset(-r * 0.3, -r * 0.3),
        r * 0.35,
        Paint()..color = Colors.white.withValues(alpha: 0.18 * opacity),
      );
    }
  }
}

/// Soft radial glow.
void glow(Canvas c, Offset at, double r, Color color, {double alpha = 0.55}) {
  c.drawCircle(
    at,
    r,
    Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: at, radius: r)),
  );
}

/// A ring closing on a target: [t] 0 → wide, 1 → on the target.
void approachRing(
  Canvas c,
  Offset at,
  double r,
  double t,
  Color color, {
  double width = 4,
}) {
  final k = (1 - t.clamp(0.0, 1.0));
  final rr = r * (1 + 1.6 * k);
  c.drawCircle(
    at,
    rr,
    Paint()
      ..color = const Color(0xCC050B08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width + 3,
  );
  c.drawCircle(
    at,
    rr,
    Paint()
      ..color = color.withValues(alpha: 0.35 + 0.65 * t.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = width,
  );
}

/// Arc progress around a point (hold rings, dwell rings).
void progressArc(
  Canvas c,
  Offset at,
  double r,
  double t,
  Color color, {
  double width = 6,
}) {
  final rect = Rect.fromCircle(center: at, radius: r);
  c.drawArc(
    rect,
    0,
    math.pi * 2,
    false,
    Paint()
      ..color = const Color(0x66050B08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width,
  );
  c.drawArc(
    rect,
    -math.pi / 2,
    math.pi * 2 * t.clamp(0.0, 1.0),
    false,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width,
  );
}

Path starPath(Offset c, double r, {int points = 5, double inner = 0.45}) {
  final path = Path();
  for (var i = 0; i < points * 2; i++) {
    final a = -math.pi / 2 + i * math.pi / points;
    final rr = i.isEven ? r : r * inner;
    final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

Path diamondPath(Offset c, double r) => Path()
  ..moveTo(c.dx, c.dy - r)
  ..lineTo(c.dx + r * 0.8, c.dy)
  ..lineTo(c.dx, c.dy + r)
  ..lineTo(c.dx - r * 0.8, c.dy)
  ..close();

final Map<String, TextPainter> _textCache = {};

/// Font for canvas text. Null = the system font; headless previews set one.
String? artFontFamily;

/// Bold text with a dark under-stroke so it reads on any background.
void strokedText(
  Canvas c,
  String text,
  Offset center, {
  double size = 18,
  Color color = const Color(0xFFF6EEDC),
  FontWeight weight = FontWeight.w900,
  double opacity = 1,
}) {
  final key =
      '$text|$size|${color.toARGB32()}|$weight|${(opacity * 20).round()}';
  final tp = _textCache[key] ??= () {
    if (_textCache.length > 160) _textCache.clear();
    final style = TextStyle(
      fontSize: size,
      fontWeight: weight,
      letterSpacing: 0.3,
      height: 1,
      fontFamily: artFontFamily,
    );
    final stroke = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size * 0.22
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xFF050B08).withValues(alpha: opacity),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    return stroke;
  }();
  final fillKey = '$key|fill';
  final fill = _textCache[fillKey] ??= TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: 0.3,
        height: 1,
        fontFamily: artFontFamily,
        color: color.withValues(alpha: opacity),
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final o = center - Offset(tp.width / 2, tp.height / 2);
  tp.paint(c, o);
  fill.paint(c, o);
}

/// Deterministic pseudo-random in 0..1 for decoration.
double hash(int i) {
  final x = math.sin(i * 12.9898 + 78.233) * 43758.5453;
  return x - x.floorToDouble();
}

/// A vertical sky gradient filling [s].
void sky(Canvas c, Size s, List<Color> colors, {List<double>? stops}) {
  final rect = Offset.zero & s;
  c.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
        stops: stops,
      ).createShader(rect),
  );
}

void starfield(
  Canvas c,
  Size s, {
  int n = 40,
  double maxY = 0.6,
  double t = 0,
}) {
  final paint = Paint();
  for (var i = 0; i < n; i++) {
    final tw = 0.55 + 0.45 * math.sin(t * 2 + i);
    paint.color = const Color(0xFFF6EEDC)
        .withValues(alpha: 0.25 + 0.4 * hash(i) * tw);
    c.drawCircle(
      Offset(hash(i * 3 + 1) * s.width, hash(i * 7 + 2) * s.height * maxY),
      hash(i) > 0.8 ? 1.6 : 0.9,
      paint,
    );
  }
}

/// Confetti burst: [t] 0..1 of its life.
void confetti(
  Canvas c,
  Offset at,
  double t,
  List<Color> colors, {
  int n = 18,
  double spread = 90,
  int seed = 0,
}) {
  if (t >= 1) return;
  final paint = Paint();
  for (var i = 0; i < n; i++) {
    final a = (i / n) * math.pi * 2 + hash(seed + i) * 0.6;
    final d =
        spread *
        Curves.easeOutCubic.transform(t) *
        (0.6 + 0.4 * hash(seed + i * 5));
    final p = at + Offset(math.cos(a) * d, math.sin(a) * d + 40 * t * t);
    paint.color = colors[i % colors.length].withValues(alpha: 1 - t);
    if (i % 3 == 0) {
      c.drawPath(diamondPath(p, 5), paint);
    } else if (i % 3 == 1) {
      c.drawCircle(p, 3.5, paint);
    } else {
      c.save();
      c.translate(p.dx, p.dy);
      c.rotate(a + t * 6);
      c.drawRect(const Rect.fromLTWH(-4, -1.5, 8, 3), paint);
      c.restore();
    }
  }
}
