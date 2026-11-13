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

/// How a game dresses the player's character. Every game has its own
/// look so the cast is not one figure in different colours.
class AvatarLook {
  const AvatarLook({
    this.skin = const Color(0xFFC98F6B),
    this.hair = const Color(0xFF2A1D1A),
    this.top = const Color(0xFF2F7D6B),
    this.bottom = const Color(0xFF1D2530),
    this.shoe = const Color(0xFFF3F5F7),
    this.trim = const Color(0xFFC8F542),
    this.hairStyle = HairStyle.short,
    this.sleeves = true,
    this.longLegs = true,
    this.face = true,
  });

  /// A one-material figure (pose silhouettes, ghosts): [body] for the
  /// clothes, [limb] for everything else, and no face.
  const AvatarLook.mannequin(Color body, Color limb, Color accent)
    : skin = limb,
      hair = limb,
      top = body,
      bottom = body,
      shoe = limb,
      trim = accent,
      hairStyle = HairStyle.short,
      sleeves = true,
      longLegs = true,
      face = false;

  final Color skin;
  final Color hair;

  /// Jersey / jacket, shorts or leggings, trainers.
  final Color top;
  final Color bottom;
  final Color shoe;

  /// Stripe, seams and sole: the game's accent.
  final Color trim;
  final HairStyle hairStyle;

  /// Long sleeves (the forearm is in the top's colour) or bare forearms.
  final bool sleeves;

  /// Leggings to the ankle, or shorts with bare shins.
  final bool longLegs;

  /// Draw eyes, brows, nose and mouth.
  final bool face;

  AvatarLook copyWith({Color? trim, Color? top}) => AvatarLook(
    skin: skin,
    hair: hair,
    top: top ?? this.top,
    bottom: bottom,
    shoe: shoe,
    trim: trim ?? this.trim,
    hairStyle: hairStyle,
    sleeves: sleeves,
    longLegs: longLegs,
    face: face,
  );
}

enum HairStyle { short, bun, crop, tied }

/// Lighter (amount > 0) or darker (amount < 0) version of a colour.
Color shade(Color c, double amount) => amount >= 0
    ? Color.lerp(c, const Color(0xFFFFFFFF), amount.clamp(0.0, 1.0))!
    : Color.lerp(c, const Color(0xFF05070A), (-amount).clamp(0.0, 1.0))!;

/// A limb segment as a tapered capsule, shaded across its width so it reads
/// as a rounded volume lit from the upper left. Drawn as a quad plus two
/// end discs that share one gradient, so there are no seams.
void _limb(
  Canvas c,
  Offset a,
  Offset b,
  double ra,
  double rb,
  Color color,
  double opacity,
) {
  final d = b - a;
  final len = d.distance;
  // The normal that faces the light (upper left).
  var n = len < 0.5
      ? const Offset(-0.7071, -0.7071)
      : Offset(-d.dy / len, d.dx / len);
  if (n.dx + n.dy > 0) n = -n;
  final paint = Paint()
    ..shader = LinearGradient(
      colors: [
        shade(color, 0.22).withValues(alpha: opacity),
        color.withValues(alpha: opacity),
        shade(color, -0.38).withValues(alpha: opacity),
      ],
      stops: const [0, 0.42, 1],
      // Runs from the lit edge to the shaded edge, across the limb.
      transform: GradientRotation(math.atan2(-n.dy, -n.dx)),
    ).createShader(
      Rect.fromCircle(center: (a + b) / 2, radius: math.max(ra, rb)),
    );
  if (len >= 0.5) {
    c.drawPath(
      Path()
        ..moveTo(a.dx + n.dx * ra, a.dy + n.dy * ra)
        ..lineTo(b.dx + n.dx * rb, b.dy + n.dy * rb)
        ..lineTo(b.dx - n.dx * rb, b.dy - n.dy * rb)
        ..lineTo(a.dx - n.dx * ra, a.dy - n.dy * ra)
        ..close(),
      paint,
    );
  }
  c.drawCircle(a, ra, paint);
  c.drawCircle(b, rb, paint);
}

/// A sphere-like disc (heads, hands, joints) lit from the upper left.
void _ball(Canvas c, Offset at, double r, Color color, double opacity) {
  c.drawCircle(
    at,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.45, -0.5),
        radius: 1.15,
        colors: [
          shade(color, 0.25).withValues(alpha: opacity),
          color.withValues(alpha: opacity),
          shade(color, -0.4).withValues(alpha: opacity),
        ],
        stops: const [0, 0.5, 1],
      ).createShader(Rect.fromCircle(center: at, radius: r)),
  );
}

/// A rounded, lit limb for other characters in the games (see [paintAvatar]
/// for how the player's own figure uses it).
void shadedLimb(Canvas c, Offset a, Offset b, double ra, double rb, Color color, {double opacity = 1}) =>
    _limb(c, a, b, ra, rb, color, opacity);

/// A rounded, lit ball: heads, hands, bodies.
void shadedBall(Canvas c, Offset at, double r, Color color, {double opacity = 1}) =>
    _ball(c, at, r, color, opacity);

/// Paints the player's character from tracked joints.
///
/// It is drawn as a lit, rounded figure: tapered limbs shaded across their
/// width, a shaped torso with a jersey stripe, shorts or leggings,
/// trainers, hands, a neck and a head with hair and a face, and a soft
/// contact shadow on the floor. [look] is the game's own kit; without one,
/// [body] / [limb] / [accent] make a one-material mannequin (pose
/// silhouettes and ghosts).
///
/// With [outlineOnly] (camera mirror on) it is a light outline over the
/// player's own image, so the player sees themselves.
void paintAvatar(
  Canvas c,
  AvatarJoints j, {
  Color body = const Color(0xFF2F7D6B),
  Color limb = const Color(0xFF3E8C74),
  Color outline = const Color(0xFF05070A),
  Color accent = const Color(0xFFC8F542),
  AvatarLook? look,
  bool outlineOnly = false,
  double opacity = 1,
}) {
  final u = j.unit;
  final p = j.p, v = j.vis;
  bool ok(int a) => v[a] > 0.35;
  const lSh = AvatarJoints.lSh, rSh = AvatarJoints.rSh;
  const lEl = AvatarJoints.lEl, rEl = AvatarJoints.rEl;
  const lWr = AvatarJoints.lWr, rWr = AvatarJoints.rWr;
  const lHip = AvatarJoints.lHip, rHip = AvatarJoints.rHip;
  const lKn = AvatarJoints.lKn, rKn = AvatarJoints.rKn;
  const lAn = AvatarJoints.lAn, rAn = AvatarJoints.rAn;
  const head = AvatarJoints.head;

  if (outlineOnly) {
    _avatarOutline(c, j, accent, outline, opacity);
    return;
  }
  final k = look ?? AvatarLook.mannequin(body, limb, accent);
  final o = opacity;

  // Contact shadow: where the feet meet the floor.
  if (ok(lAn) && ok(rAn)) {
    final foot = (p[lAn] + p[rAn]) / 2 + Offset(0, u * 0.16);
    final w = (p[lAn] - p[rAn]).distance + u * 0.9;
    final rect = Rect.fromCenter(center: foot, width: w, height: u * 0.3);
    c.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF000000).withValues(alpha: 0.5 * o),
            const Color(0x00000000),
          ],
        ).createShader(rect),
    );
  }

  void seg(int a, int b, double ra, double rb, Color col) {
    if (!ok(a) || !ok(b)) return;
    // A dark under-shape keeps the figure readable on any backdrop.
    _limb(c, p[a], p[b], ra + u * 0.03, rb + u * 0.03, outline, 0.55 * o);
    _limb(c, p[a], p[b], ra, rb, col, o);
  }

  final shin = k.longLegs ? k.bottom : k.skin;
  final forearm = k.sleeves ? k.top : k.skin;

  // Back to front: legs, shoes, torso, arms, head.
  seg(lHip, lKn, u * 0.17, u * 0.13, k.bottom);
  seg(rHip, rKn, u * 0.17, u * 0.13, k.bottom);
  seg(lKn, lAn, u * 0.125, u * 0.09, shin);
  seg(rKn, rAn, u * 0.125, u * 0.09, shin);
  for (final (an, out) in [(lAn, -1.0), (rAn, 1.0)]) {
    if (!ok(an)) continue;
    // Trainer: a short capsule pointing a little outward, with a sole.
    final toe = p[an] + Offset(out * u * 0.2, u * 0.1);
    final heel = p[an] + Offset(-out * u * 0.05, u * 0.07);
    _limb(c, heel, toe, u * 0.115, u * 0.1, outline, 0.55 * o);
    _limb(c, heel, toe, u * 0.1, u * 0.085, k.shoe, o);
    c.drawLine(
      heel + Offset(0, u * 0.085),
      toe + Offset(0, u * 0.075),
      Paint()
        ..color = k.trim.withValues(alpha: o)
        ..strokeWidth = math.max(1.5, u * 0.035)
        ..strokeCap = StrokeCap.round,
    );
  }

  if (ok(lSh) && ok(rSh) && ok(lHip) && ok(rHip)) {
    final sl = p[lSh], sr = p[rSh], hl = p[lHip], hr = p[rHip];
    final sc = (sl + sr) / 2, hc = (hl + hr) / 2;
    final across = (sr - sl);
    final aw = across.distance < 1 ? Offset(u * 0.7, 0) : across;
    final ax = aw / aw.distance;
    // Shoulders a little wider than the joints, a waist, then the hips.
    final s0 = sl - ax * u * 0.12, s1 = sr + ax * u * 0.12;
    final waist = Offset.lerp(sc, hc, 0.72)!;
    final w0 = waist - ax * (hl - hr).distance * 0.62;
    final w1 = waist + ax * (hl - hr).distance * 0.62;
    final h0 = hl - ax * u * 0.1, h1 = hr + ax * u * 0.1;
    Path torso(double grow) => Path()
      ..moveTo(s0.dx - ax.dx * grow, s0.dy - grow)
      ..quadraticBezierTo(sc.dx, sc.dy - u * 0.1 - grow, s1.dx + ax.dx * grow, s1.dy - grow)
      ..quadraticBezierTo(w1.dx + ax.dx * (u * 0.06 + grow), w1.dy, h1.dx + ax.dx * grow, h1.dy + grow)
      ..quadraticBezierTo(hc.dx, hc.dy + u * 0.16 + grow, h0.dx - ax.dx * grow, h0.dy + grow)
      ..quadraticBezierTo(w0.dx - ax.dx * (u * 0.06 + grow), w0.dy, s0.dx - ax.dx * grow, s0.dy - grow)
      ..close();
    c.drawPath(torso(u * 0.035), Paint()..color = outline.withValues(alpha: 0.55 * o));
    final box = torso(0).getBounds();
    c.drawPath(
      torso(0),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            shade(k.top, 0.2).withValues(alpha: o),
            k.top.withValues(alpha: o),
            shade(k.top, -0.4).withValues(alpha: o),
          ],
          stops: const [0, 0.4, 1],
        ).createShader(box),
    );
    // Shorts / waistband over the hips.
    final band = Path()
      ..moveTo(w0.dx - ax.dx * u * 0.04, w0.dy + u * 0.02)
      ..lineTo(w1.dx + ax.dx * u * 0.04, w1.dy + u * 0.02)
      ..quadraticBezierTo(h1.dx + ax.dx * u * 0.06, h1.dy, h1.dx, h1.dy + u * 0.1)
      ..quadraticBezierTo(hc.dx, hc.dy + u * 0.2, h0.dx, h0.dy + u * 0.1)
      ..quadraticBezierTo(h0.dx - ax.dx * u * 0.06, h0.dy, w0.dx - ax.dx * u * 0.04, w0.dy + u * 0.02)
      ..close();
    c.drawPath(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            shade(k.bottom, 0.14).withValues(alpha: o),
            shade(k.bottom, -0.3).withValues(alpha: o),
          ],
        ).createShader(band.getBounds()),
    );
    // The game's stripe across the chest, and a collar.
    final chest = Offset.lerp(sc, hc, 0.3)!;
    c.save();
    c.clipPath(torso(0));
    c.drawLine(
      chest - ax * u,
      chest + ax * u,
      Paint()
        ..color = k.trim.withValues(alpha: 0.95 * o)
        ..strokeWidth = u * 0.085,
    );
    c.drawLine(
      chest - ax * u + Offset(0, u * 0.09),
      chest + ax * u + Offset(0, u * 0.09),
      Paint()
        ..color = k.trim.withValues(alpha: 0.4 * o)
        ..strokeWidth = u * 0.03,
    );
    c.restore();
  }

  // Neck, then arms over the torso.
  if (ok(head) && ok(lSh) && ok(rSh)) {
    final sc = (p[lSh] + p[rSh]) / 2;
    _limb(c, sc - Offset(0, u * 0.02), Offset.lerp(sc, p[head], 0.6)!, u * 0.09, u * 0.08, k.skin, o);
  }
  seg(lSh, lEl, u * 0.125, u * 0.1, k.top);
  seg(rSh, rEl, u * 0.125, u * 0.1, k.top);
  seg(lEl, lWr, u * 0.095, u * 0.075, forearm);
  seg(rEl, rWr, u * 0.095, u * 0.075, forearm);
  for (final w in [lWr, rWr]) {
    if (!ok(w)) continue;
    c.drawCircle(p[w], u * 0.115, Paint()..color = outline.withValues(alpha: 0.55 * o));
    _ball(c, p[w], u * 0.095, k.skin, o);
  }

  if (ok(head)) {
    final hc = p[head];
    final r = u * 0.26;
    c.drawCircle(hc, r + u * 0.03, Paint()..color = outline.withValues(alpha: 0.55 * o));
    // Hair behind the face for the longer styles.
    if (k.hairStyle == HairStyle.tied) {
      _limb(c, hc + Offset(r * 0.5, -r * 0.2), hc + Offset(r * 0.95, r * 0.9), r * 0.3, r * 0.12, k.hair, o);
    } else if (k.hairStyle == HairStyle.bun) {
      _ball(c, hc + Offset(0, -r * 1.12), r * 0.36, k.hair, o);
    }
    _ball(c, hc, r, k.skin, o);
    // Hair: a cap over the top of the head, with a hairline.
    final cap = Path()
      ..arcTo(Rect.fromCircle(center: hc, radius: r), math.pi * 1.02, math.pi * 0.96, true)
      ..quadraticBezierTo(
        hc.dx + r * 0.25,
        hc.dy - r * (k.hairStyle == HairStyle.crop ? 0.72 : 0.5),
        hc.dx - r * 0.99,
        hc.dy - r * 0.06,
      )
      ..close();
    c.drawPath(
      cap,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [shade(k.hair, 0.22).withValues(alpha: o), shade(k.hair, -0.25).withValues(alpha: o)],
        ).createShader(Rect.fromCircle(center: hc, radius: r)),
    );
    // Face: only when the head is big enough to read.
    if (k.face && r >= 9) {
      final ink = Paint()..color = const Color(0xFF1A1210).withValues(alpha: 0.9 * o);
      final ey = hc.dy + r * 0.08;
      for (final sx in [-1.0, 1.0]) {
        final e = Offset(hc.dx + sx * r * 0.36, ey);
        c.drawOval(Rect.fromCenter(center: e, width: r * 0.2, height: r * 0.25), ink);
        c.drawCircle(e + Offset(-r * 0.03, -r * 0.05), r * 0.045, Paint()..color = Colors.white.withValues(alpha: 0.85 * o));
        // Brow.
        c.drawLine(
          e + Offset(-r * 0.16, -r * 0.24),
          e + Offset(r * 0.16, -r * 0.27 + sx * r * 0.02),
          Paint()
            ..color = shade(k.hair, -0.1).withValues(alpha: 0.9 * o)
            ..strokeWidth = math.max(1.2, r * 0.07)
            ..strokeCap = StrokeCap.round,
        );
      }
      // Nose shadow and a calm mouth.
      c.drawLine(
        hc + Offset(r * 0.04, r * 0.2),
        hc + Offset(r * 0.1, r * 0.42),
        Paint()
          ..color = shade(k.skin, -0.3).withValues(alpha: 0.7 * o)
          ..strokeWidth = math.max(1, r * 0.06)
          ..strokeCap = StrokeCap.round,
      );
      c.drawArc(
        Rect.fromCenter(center: hc + Offset(0, r * 0.52), width: r * 0.55, height: r * 0.3),
        math.pi * 0.15,
        math.pi * 0.7,
        false,
        Paint()
          ..color = shade(k.skin, -0.5).withValues(alpha: 0.85 * o)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, r * 0.07)
          ..strokeCap = StrokeCap.round,
      );
    }
  }
}

/// The mirror-mode figure: a light outline over the player's own image.
void _avatarOutline(Canvas c, AvatarJoints j, Color accent, Color outline, double opacity) {
  final u = j.unit;
  final p = j.p, v = j.vis;
  bool ok(int a) => v[a] > 0.35;
  final under = Paint()
    ..color = outline.withValues(alpha: 0.75 * opacity)
    ..strokeCap = StrokeCap.round;
  final line = Paint()
    ..color = Colors.white.withValues(alpha: 0.85 * opacity)
    ..strokeCap = StrokeCap.round;
  void bone(int a, int b, double w) {
    if (!ok(a) || !ok(b)) return;
    under.strokeWidth = w + u * 0.08;
    line.strokeWidth = math.max(3, w * 0.25);
    c.drawLine(p[a], p[b], under);
    c.drawLine(p[a], p[b], line);
  }

  const lSh = AvatarJoints.lSh, rSh = AvatarJoints.rSh;
  const lHip = AvatarJoints.lHip, rHip = AvatarJoints.rHip;
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
    c.drawPath(
      torso,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }
  bone(lSh, AvatarJoints.lEl, u * 0.24);
  bone(AvatarJoints.lEl, AvatarJoints.lWr, u * 0.21);
  bone(rSh, AvatarJoints.rEl, u * 0.24);
  bone(AvatarJoints.rEl, AvatarJoints.rWr, u * 0.21);
  for (final w in [AvatarJoints.lWr, AvatarJoints.rWr]) {
    if (!ok(w)) continue;
    c.drawCircle(p[w], u * 0.15, under);
    c.drawCircle(p[w], u * 0.1, Paint()..color = accent.withValues(alpha: opacity));
  }
  if (ok(AvatarJoints.head)) {
    c.drawCircle(
      p[AvatarJoints.head],
      u * 0.24,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7 * opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
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


// ----------------------------------------------------------------- effects
// Shared, cheap effects. Each is a pure function of its age [t] (0..1), so
// nothing keeps state and nothing allocates beyond a few paints.

/// Darkens the corners so the eye rests on the player.
void vignette(Canvas c, Size s, {double strength = 0.55}) {
  final rect = Offset.zero & s;
  c.drawRect(
    rect,
    Paint()
      ..shader = RadialGradient(
        radius: 0.95,
        colors: [
          const Color(0x00000000),
          const Color(0xFF000000).withValues(alpha: strength),
        ],
        stops: const [0.55, 1],
      ).createShader(rect),
  );
}

/// A floor receding to [horizon] (a y in pixels): a gradient, lines that
/// converge on the vanishing point and cross-lines that bunch up with
/// distance. [scroll] slides the cross-lines towards the viewer.
void perspectiveFloor(
  Canvas c,
  Size s,
  double horizon, {
  required Color near,
  required Color far,
  Color line = const Color(0x22FFFFFF),
  double scroll = 0,
  int rays = 9,
  int rows = 7,
}) {
  final rect = Rect.fromLTRB(0, horizon, s.width, s.height);
  if (rect.height <= 0) return;
  c.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [far, near],
      ).createShader(rect),
  );
  final p = Paint()
    ..color = line
    ..strokeWidth = 1;
  final vp = Offset(s.width / 2, horizon);
  for (var i = 0; i <= rays; i++) {
    final x = -s.width * 0.6 + s.width * 2.2 * i / rays;
    c.drawLine(vp, Offset(x, s.height), p);
  }
  for (var i = 0; i < rows; i++) {
    final k = (i + scroll % 1) / rows;
    final y = horizon + rect.height * k * k;
    p.color = line.withValues(alpha: line.a * (0.3 + 0.7 * k));
    c.drawLine(Offset(0, y), Offset(s.width, y), p);
  }
}

/// A soft cone of light from [from] downwards.
void lightShaft(
  Canvas c,
  Offset from,
  double length,
  double spread,
  Color color, {
  double alpha = 0.22,
  double lean = 0,
}) {
  final path = Path()
    ..moveTo(from.dx - spread * 0.08, from.dy)
    ..lineTo(from.dx + spread * 0.08, from.dy)
    ..lineTo(from.dx + lean + spread, from.dy + length)
    ..lineTo(from.dx + lean - spread, from.dy + length)
    ..close();
  c.drawPath(
    path,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ).createShader(path.getBounds()),
  );
}

/// An oval contact shadow.
void softShadow(Canvas c, Offset at, double w, double h, {double alpha = 0.45}) {
  final rect = Rect.fromCenter(center: at, width: w, height: h);
  c.drawOval(
    rect,
    Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF000000).withValues(alpha: alpha),
          const Color(0x00000000),
        ],
      ).createShader(rect),
  );
}

/// A glossy sphere: body colour, a specular highlight, a rim and a little
/// light bouncing up from below. For bubbles, orbs, gems and fruit.
void glossSphere(Canvas c, Offset at, double r, Color color, {double alpha = 1}) {
  final rect = Rect.fromCircle(center: at, radius: r);
  c.drawCircle(
    at,
    r,
    Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.4, -0.45),
        radius: 1.2,
        colors: [
          shade(color, 0.55).withValues(alpha: alpha),
          color.withValues(alpha: alpha),
          shade(color, -0.55).withValues(alpha: alpha),
        ],
        stops: const [0, 0.45, 1],
      ).createShader(rect),
  );
  // Bounce light on the lower right.
  c.drawArc(
    rect.deflate(r * 0.1),
    math.pi * 0.1,
    math.pi * 0.5,
    false,
    Paint()
      ..color = shade(color, 0.5).withValues(alpha: 0.35 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r * 0.08)
      ..strokeCap = StrokeCap.round,
  );
  // Specular highlight.
  c.drawOval(
    Rect.fromCenter(
      center: at + Offset(-r * 0.36, -r * 0.42),
      width: r * 0.5,
      height: r * 0.3,
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.75 * alpha),
  );
}

/// Sparks flying out of [at] and falling: [t] 0..1 of their life.
void sparkBurst(
  Canvas c,
  Offset at,
  double t,
  Color color, {
  int n = 14,
  double spread = 80,
  int seed = 0,
}) {
  if (t <= 0 || t >= 1) return;
  final out = Curves.easeOutCubic.transform(t);
  final paint = Paint()
    ..strokeCap = StrokeCap.round
    ..strokeWidth = 2.6 * (1 - t) + 0.8;
  for (var i = 0; i < n; i++) {
    final a = (i / n) * math.pi * 2 + hash(seed + i * 3) * 0.9;
    final d = spread * out * (0.45 + 0.55 * hash(seed + i * 7));
    final dirV = Offset(math.cos(a), math.sin(a));
    final head = at + dirV * d + Offset(0, 46 * t * t);
    final tail = head - dirV * (10 + 14 * (1 - t));
    paint.color = (i.isEven ? color : shade(color, 0.5)).withValues(
      alpha: 1 - t,
    );
    c.drawLine(tail, head, paint);
  }
}

/// A ring racing outwards from an impact.
void shockRing(Canvas c, Offset at, double t, double radius, Color color) {
  if (t <= 0 || t >= 1) return;
  final k = Curves.easeOutCubic.transform(t);
  c.drawCircle(
    at,
    radius * (0.3 + 0.9 * k),
    Paint()
      ..color = color.withValues(alpha: 0.8 * (1 - t))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * (1 - t) + 1,
  );
}

/// A score popping out of an action: it lands with a small overshoot,
/// rises and fades. [age] in seconds; lives about 1.1 s.
void scorePop(
  Canvas c,
  String text,
  Offset at,
  double age,
  Color color, {
  bool big = false,
}) {
  if (age < 0 || age >= 1.1) return;
  final enter = (age / 0.16).clamp(0.0, 1.0);
  final scale = 0.6 + 0.4 * Curves.easeOutBack.transform(enter);
  final fade = age < 0.7 ? 1.0 : (1 - (age - 0.7) / 0.4).clamp(0.0, 1.0);
  final size = ((big ? 34 : 24) * scale / 2).round() * 2.0;
  final pos = at + Offset(0, -18 - 46 * Curves.easeOutCubic.transform(age / 1.1));
  if (big) glow(c, pos, size * 1.6, color, alpha: 0.35 * fade);
  strokedText(c, text, pos, size: size, color: color, opacity: (fade * 10).round() / 10);
}

/// Out-of-focus lights drifting slowly in front of the scene: cheap depth.
void bokeh(
  Canvas c,
  Size s,
  double t,
  List<Color> colors, {
  int n = 9,
  double minY = 0,
  double maxY = 1,
  double alpha = 0.16,
  int seed = 0,
}) {
  final paint = Paint();
  for (var i = 0; i < n; i++) {
    final x = (hash(seed + i * 7 + 1) + t * 0.006 * (i.isEven ? 1 : -1)) % 1;
    final y = minY + (maxY - minY) * hash(seed + i * 13 + 5);
    final r = s.shortestSide * (0.03 + 0.05 * hash(seed + i * 3 + 2));
    final tw = 0.6 + 0.4 * math.sin(t * 0.9 + i * 1.7);
    final at = Offset(x * s.width, y * s.height);
    paint.shader = RadialGradient(
      colors: [
        colors[i % colors.length].withValues(alpha: alpha * tw),
        colors[i % colors.length].withValues(alpha: alpha * tw * 0.6),
        colors[i % colors.length].withValues(alpha: 0),
      ],
      stops: const [0, 0.75, 1],
    ).createShader(Rect.fromCircle(center: at, radius: r));
    c.drawCircle(at, r, paint);
  }
}

/// A band of haze: atmosphere between the far scenery and the action.
void hazeBand(Canvas c, Size s, double y, double height, Color color, {double alpha = 0.3}) {
  final rect = Rect.fromLTWH(0, y - height / 2, s.width, height);
  c.drawRect(
    rect,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: alpha),
          color.withValues(alpha: 0),
        ],
      ).createShader(rect),
  );
}

/// Light lying on a floor: a soft ellipse.
void lightPool(Canvas c, Offset at, double w, double h, Color color, {double alpha = 0.3}) {
  final rect = Rect.fromCenter(center: at, width: w, height: h);
  c.drawOval(
    rect,
    Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)],
      ).createShader(rect),
  );
}
