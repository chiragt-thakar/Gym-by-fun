import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';

import 'paint_kit.dart';

const _lilac = Color(0xFFB98CFF);
const _mehendi = Color(0xFF9BCB3C);
const _marigold = Color(0xFFFFB627);
const _kumkum = Color(0xFFFF4D6D);

/// Night mela: indigo sky, slow fireworks and a rangoli-light floor.
void patakaBackdrop(Canvas c, Size s, double t) {
  sky(
    c,
    s,
    const [Color(0xFF120F33), Color(0xFF2B2F77), Color(0xFF3B1F5C)],
    stops: const [0, 0.6, 1],
  );
  starfield(c, s, n: 34, maxY: 0.5, t: t);
  // Fireworks: three slow, looping bursts (≤ 1 flash per second).
  for (var i = 0; i < 3; i++) {
    final phase = ((t * 0.35 + i / 3) % 1.0);
    final at = Offset(
      s.width * (0.2 + 0.3 * i),
      s.height * (0.12 + 0.06 * (i % 2)),
    );
    final col = [_marigold, _lilac, _kumkum][i];
    final n = 14;
    for (var k = 0; k < n; k++) {
      final a = k / n * math.pi * 2;
      final d = 40 * Curves.easeOut.transform(phase);
      c.drawCircle(
        at + Offset(math.cos(a) * d, math.sin(a) * d + 10 * phase * phase),
        2.2,
        Paint()..color = col.withValues(alpha: (1 - phase) * 0.9),
      );
    }
  }
  // Rangoli floor: concentric light diamonds in perspective.
  final horizon = s.height * 0.62;
  final floor = Rect.fromLTRB(0, horizon, s.width, s.height);
  c.drawRect(
    floor,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF221A4A), Color(0xFF120E2A)],
      ).createShader(floor),
  );
  final cx = s.width / 2;
  for (var k = 1; k <= 6; k++) {
    final w = s.width * 0.14 * k, h = (s.height - horizon) * 0.12 * k;
    final cy = horizon + (s.height - horizon) * 0.55;
    final path = Path()
      ..moveTo(cx, cy - h)
      ..lineTo(cx + w, cy)
      ..lineTo(cx, cy + h)
      ..lineTo(cx - w, cy)
      ..close();
    c.drawPath(
      path,
      Paint()
        ..color = [
          _lilac,
          _marigold,
          _mehendi,
        ][k % 3].withValues(alpha: 0.18 + 0.08 * math.sin(t * 2 + k))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
  // Stall silhouettes on the horizon.
  final sil = Paint()..color = const Color(0xFF181238);
  for (var i = 0; i < 7; i++) {
    final x = i * s.width / 6 - 20;
    final h = 30 + 24 * hash(i);
    c.drawRect(Rect.fromLTWH(x, horizon - h, s.width / 7, h), sil);
    c.drawPath(
      Path()
        ..moveTo(x - 6, horizon - h)
        ..lineTo(x + s.width / 14, horizon - h - 18)
        ..lineTo(x + s.width / 7 + 6, horizon - h)
        ..close(),
      sil,
    );
  }
}

AvatarJoints ghostFor(BodyMap m, PoseTarget? target, {bool mirrored = false}) {
  double a(PoseAngle k, double d) => target?.angles[k] ?? d;
  final t = mirrored && target != null ? target.mirrored() : target;
  double b(PoseAngle k, double d) => t?.angles[k] ?? d;
  return AvatarJoints.demo(
    m,
    shoulderL: b(PoseAngle.shoulderL, 12),
    shoulderR: b(PoseAngle.shoulderR, 12),
    elbowL: b(PoseAngle.elbowL, 170),
    elbowR: b(PoseAngle.elbowR, 170),
    hipL: b(PoseAngle.hipL, 7),
    hipR: b(PoseAngle.hipR, 7),
    lean: a(PoseAngle.lean, 0) * (mirrored ? -1 : 1),
  );
}

/// The cut-out frame: a glowing panel with the target shape as a dark
/// silhouette window, outlined in the game accent.
void cutoutFrame(
  Canvas c,
  BodyMap m,
  PoseTarget? target,
  double approach, {
  double alpha = 1,
  Color accent = _lilac,
}) {
  final center = m(0, -1.0);
  final w = m.unit * 4.4, h = m.unit * 5.2;
  final panel = RRect.fromRectAndRadius(
    Rect.fromCenter(center: center, width: w, height: h),
    Radius.circular(m.unit * 0.5),
  );
  c.drawRRect(panel, Paint()..color = accent.withValues(alpha: 0.2 * alpha));
  c.drawRRect(
    panel,
    Paint()
      ..color = accent.withValues(alpha: 0.9 * alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4,
  );
  // Corner sparks like a firecracker fuse.
  for (final corner in [
    panel.outerRect.topLeft,
    panel.outerRect.topRight,
    panel.outerRect.bottomLeft,
    panel.outerRect.bottomRight,
  ]) {
    glow(c, corner, 16, _marigold, alpha: 0.7 * alpha);
  }
  final ghost = ghostFor(m, target);
  paintAvatar(
    c,
    ghost,
    body: const Color(0xFF0B0820).withValues(alpha: 0.85 * alpha),
    limb: const Color(0xFF0B0820).withValues(alpha: 0.85 * alpha),
    outline: accent.withValues(alpha: alpha),
    accent: accent.withValues(alpha: 0.5 * alpha),
    opacity: alpha,
  );
}

void patakaPlay(Canvas c, Size s, BodyMap m, PatakaEngine e, double t) {
  final f = e.frame;
  if (f == null) return;
  if (e.phase == 'show') {
    final a = e.approach;
    // From the horizon to the player: grows and drops into place.
    final far = BodyMap(Offset(s.width / 2, s.height * 0.3), m.unit * 0.28);
    final k = Curves.easeIn.transform(a);
    final mm = BodyMap(
      Offset.lerp(far.origin, m.origin, k)!,
      far.unit + (m.unit - far.unit) * k,
    );
    if (f.kind == FrameKind.chill) {
      final at = mm(0, -1);
      glow(c, at, mm.unit * 2.5, _mehendi, alpha: 0.35);
      strokedText(c, 'CHILL', at, size: 18 + 18 * k, color: _mehendi);
    } else {
      cutoutFrame(
        c,
        mm,
        f.pose?.target,
        a,
        alpha: 0.55 + 0.45 * k,
        accent: f.kind == FrameKind.statue ? _marigold : _lilac,
      );
    }
    // Hold ring above the head.
    final at = m(0, 1.25);
    final match = e.similarity >= e.band.lock;
    progressArc(
      c,
      at,
      m.unit * 0.42,
      f.holdFraction,
      match ? _mehendi : const Color(0xFFFFC857),
      width: 7,
    );
    strokedText(
      c,
      '${e.similarity.round()}%',
      at,
      size: 18,
      color: match ? _mehendi : const Color(0xFFF6EEDC),
    );
    if (f.locked) {
      c.drawCircle(
        at,
        m.unit * 0.55,
        Paint()
          ..color = _mehendi.withValues(alpha: 0.4 + 0.3 * math.sin(t * 8))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }
}

void patakaPreview(Canvas c, Size s, int variant) {
  patakaBackdrop(c, s, 1.5 + variant * 0.7);
  const goalpost = PoseTarget(
    id: 'g',
    angles: {
      PoseAngle.shoulderL: 90,
      PoseAngle.shoulderR: 90,
      PoseAngle.elbowL: 90,
      PoseAngle.elbowR: 90,
    },
  );
  const star = PoseTarget(
    id: 's',
    angles: {
      PoseAngle.shoulderL: 135,
      PoseAngle.shoulderR: 135,
      PoseAngle.hipL: 18,
      PoseAngle.hipR: 18,
    },
  );
  const chai = PoseTarget(
    id: 'c',
    angles: {
      PoseAngle.shoulderL: 45,
      PoseAngle.elbowL: 90,
      PoseAngle.shoulderR: 150,
      PoseAngle.elbowR: 165,
    },
  );
  final target = [star, goalpost, chai, chai][variant % 4];
  final h = s.height;
  // Wide framing: the frame flies in on the left; the player strikes the
  // shape on the right.
  final m = BodyMap(Offset(s.width * 0.68, h * 0.34), h * 0.13);
  if (variant != 2) {
    final scale = variant == 1 ? 0.95 : 0.7;
    final frameMap = BodyMap(
      Offset(s.width * 0.3, h * (0.5 - 0.22 * scale) + h * 0.06),
      h * 0.13 * scale,
    );
    cutoutFrame(
      c,
      frameMap,
      target,
      0.6,
      alpha: 0.95,
      accent: variant == 3 ? _marigold : _lilac,
    );
  }
  final j = ghostFor(m, variant == 0 ? goalpost : target);
  paintAvatar(c, j, accent: _lilac);
  if (variant == 2) {
    confetti(
      c,
      m(0, 0.2),
      0.4,
      const [_marigold, _lilac, _mehendi, _kumkum],
      n: 28,
      spread: m.unit * 2.6,
    );
    strokedText(
      c,
      'PATAKA!',
      Offset(s.width * 0.3, h * 0.4),
      size: h * 0.14,
      color: _marigold,
    );
  } else {
    final match = variant == 1 || variant == 3;
    progressArc(
      c,
      m(0, 1.3),
      m.unit * 0.4,
      match ? 0.7 : 0.2,
      match ? _mehendi : const Color(0xFFFFC857),
      width: 6,
    );
  }
}
