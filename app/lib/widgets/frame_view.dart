import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:motion_core/motion_core.dart';
import 'package:pose_bridge/pose_bridge.dart';

import '../app/theme.dart';

/// Voice/text key (in `S`) for a framing fix.
String framingKey(FramingFix f) => switch (f) {
  FramingFix.ok => 'frame_ok',
  FramingFix.findMe => 'frame_find_me',
  FramingFix.stepBack => 'frame_step_back',
  FramingFix.stepCloser => 'frame_step_closer',
  FramingFix.moveLeft => 'frame_move_left',
  FramingFix.moveRight => 'frame_move_right',
  FramingFix.moreLight => 'frame_more_light',
};

/// Icon for a framing fix. Selfie space: the player's left is screen left,
/// so "move to your left" points left.
IconData framingIcon(FramingFix f) => switch (f) {
  FramingFix.ok => Icons.check_circle_rounded,
  FramingFix.findMe => Icons.person_search_rounded,
  FramingFix.stepBack => Icons.zoom_in_map_rounded,
  FramingFix.stepCloser => Icons.zoom_out_map_rounded,
  FramingFix.moveLeft => Icons.arrow_back_rounded,
  FramingFix.moveRight => Icons.arrow_forward_rounded,
  FramingFix.moreLight => Icons.light_mode_rounded,
};

/// A 3:4 window onto exactly what the camera sees (the shared viewport):
/// the optional native mirror, a body-shaped target, the player's
/// skeleton, glowing edges where the body is cut off (red) or close
/// (amber), and a big direction cue.
///
/// Keep this widget at a stable place in the tree while [mirror] is on:
/// re-creating it re-attaches the native preview.
class FrameView extends StatelessWidget {
  const FrameView({
    super.key,
    required this.frame,
    required this.advice,
    this.mirror = false,
    this.showCue = true,
    this.showTarget = true,
    this.radius = 24,
  });

  final PoseFrame? frame;
  final FramingAdvice advice;

  /// Show the live camera mirror behind the outline.
  final bool mirror;
  final bool showCue;
  final bool showTarget;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final ok = advice.ok;
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: ok ? Lantern.scarf : Lantern.warning,
            width: 3,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF0E1A14)),
              // Index 1 stays the mirror whenever it is on, so it is never
              // re-created by other changes.
              if (mirror) const PoseMirror(),
              IgnorePointer(
                child: CustomPaint(
                  painter: FramePainter(
                    frame,
                    advice,
                    showTarget: showTarget,
                    dimForMirror: mirror,
                  ),
                ),
              ),
              if (showCue && !ok) Center(child: FramingCue(advice.fix)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A big icon that slides once in the direction to move. One-shot (never
/// repeating), so it is calm and test-friendly.
class FramingCue extends StatelessWidget {
  const FramingCue(this.fix, {super.key, this.size = 96});
  final FramingFix fix;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dx = switch (fix) {
      FramingFix.moveLeft => -1.0,
      FramingFix.moveRight => 1.0,
      _ => 0.0,
    };
    return TweenAnimationBuilder<double>(
      key: ValueKey(fix),
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.maybeDisableAnimationsOf(context) == true
          ? Duration.zero
          : const Duration(milliseconds: 700),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(dx * size * 0.5 * t, 0),
        child: Opacity(opacity: t.clamp(0, 1).toDouble(), child: child),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.15),
          child: Icon(framingIcon(fix), size: size, color: Lantern.warning),
        ),
      ),
    );
  }
}

/// Paints the target, skeleton and edge glows in viewport space
/// (landmark x, y in 0..1 → the 3:4 box).
class FramePainter extends CustomPainter {
  FramePainter(
    this.frame,
    this.advice, {
    this.showTarget = true,
    this.dimForMirror = false,
  });

  final PoseFrame? frame;
  final FramingAdvice advice;
  final bool showTarget;
  final bool dimForMirror;

  static final _target = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  static final _targetFill = Paint();
  static final _bone = Paint()..strokeCap = StrokeCap.round;
  static final _joint = Paint();
  static final _head = Paint()..style = PaintingStyle.stroke;
  static final _edge = Paint();
  static final _shade = Paint()..color = const Color(0x33000000);
  static final _grid = Paint()
    ..color = const Color(0x143FD0C0)
    ..strokeWidth = 1;
  static final _outline = Paint()
    ..color = const Color(0xFF0B262B)
    ..strokeCap = StrokeCap.round;
  static final _suit = Paint()..color = const Color(0xFF1B777A);
  static final _visor = Paint()..color = const Color(0xFFB4F6E8);
  static final _torso = Path();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final ok = advice.ok;
    if (dimForMirror) canvas.drawRect(Offset.zero & size, _shade);
    if (!dimForMirror) {
      for (var i = 1; i < 8; i++) {
        canvas.drawLine(Offset(w * i / 8, 0), Offset(w * i / 8, h), _grid);
        canvas.drawLine(Offset(0, h * i / 8), Offset(w, h * i / 8), _grid);
      }
    }

    if (showTarget) {
      // Where a standing body should sit: head to feet with a margin.
      final c = ok ? Lantern.scarf : Colors.white;
      _target.color = c.withValues(alpha: ok ? 0.9 : 0.55);
      _targetFill.color = c.withValues(alpha: ok ? 0.10 : 0.05);
      final head = Offset(w * 0.5, h * 0.14);
      canvas.drawCircle(head, h * 0.06, _targetFill);
      canvas.drawCircle(head, h * 0.06, _target);
      // A standing-body target with actual arm/leg space, rather than a
      // full-height pill that suggests the player should hide their arms.
      for (var side = -1.0; side <= 1; side += 2) {
        final shoulder = Offset(w * (0.5 + side * 0.12), h * 0.27);
        final hip = Offset(w * (0.5 + side * 0.08), h * 0.56);
        canvas.drawLine(
          shoulder,
          Offset(w * (0.5 + side * 0.23), h * 0.56),
          _target,
        );
        canvas.drawLine(shoulder, hip, _target);
        canvas.drawLine(
          hip,
          Offset(w * (0.5 + side * 0.13), h * 0.91),
          _target,
        );
      }
      canvas.drawLine(
        Offset(w * 0.38, h * 0.27),
        Offset(w * 0.62, h * 0.27),
        _target,
      );
      canvas.drawLine(
        Offset(w * 0.42, h * 0.56),
        Offset(w * 0.58, h * 0.56),
        _target,
      );
    }

    final band = (w < h ? w : h) * 0.16;
    for (final e in advice.cut) {
      _glow(canvas, size, e, band, Lantern.danger);
    }
    for (final e in advice.near) {
      _glow(canvas, size, e, band * 0.6, Lantern.warning);
    }

    final f = frame;
    if (f == null || !f.hasPerson) return;
    final stroke = (w * 0.022).clamp(3.0, 9.0).toDouble();
    _bone
      ..strokeWidth = stroke
      ..color = ok ? Lantern.scarf : Lantern.warning;
    _joint.color = Colors.white;
    Offset p(int i) => Offset(f[i].x * w, f[i].y * h);
    bool visible(int i) =>
        f[i].visibility > 0.4 && f[i].x.isFinite && f[i].y.isFinite;
    final avatarStroke = dimForMirror ? stroke : stroke * 2.2;
    if (!dimForMirror &&
        [
          Lm.leftShoulder,
          Lm.rightShoulder,
          Lm.rightHip,
          Lm.leftHip,
        ].every(visible)) {
      final torso = _torso
        ..reset()
        ..moveTo(p(Lm.leftShoulder).dx, p(Lm.leftShoulder).dy)
        ..lineTo(p(Lm.rightShoulder).dx, p(Lm.rightShoulder).dy)
        ..lineTo(p(Lm.rightHip).dx, p(Lm.rightHip).dy)
        ..lineTo(p(Lm.leftHip).dx, p(Lm.leftHip).dy)
        ..close();
      canvas.drawPath(torso, _suit);
    }
    for (final (a, b) in Lm.edges) {
      if (visible(a) && visible(b)) {
        _outline.strokeWidth = avatarStroke + (dimForMirror ? 3 : 5);
        canvas.drawLine(p(a), p(b), _outline);
        _bone
          ..strokeWidth = avatarStroke
          ..color = math.min(f[a].visibility, f[b].visibility) < 0.65
              ? Lantern.warning
              : ok
              ? Lantern.scarf
              : Lantern.warning;
        canvas.drawLine(p(a), p(b), _bone);
      }
    }
    for (final i in Lm.smoothed) {
      if (visible(i)) {
        _joint.color = f[i].visibility < 0.65 ? Lantern.warning : Colors.white;
        canvas.drawCircle(p(i), stroke * 0.95, _outline);
        canvas.drawCircle(p(i), stroke * 0.58, _joint);
      }
    }
    final nose = f[Lm.nose];
    if (nose.visibility > 0.4 &&
        visible(Lm.leftShoulder) &&
        visible(Lm.rightShoulder) &&
        visible(Lm.nose)) {
      final sh = (f[Lm.leftShoulder].x - f[Lm.rightShoulder].x).abs() * w;
      _head
        ..strokeWidth = stroke
        ..color = _bone.color;
      final radius = math.max(stroke * 2, math.min(sh * 0.29, w * 0.095));
      if (!dimForMirror) {
        canvas.drawCircle(p(Lm.nose), radius, _suit);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: p(Lm.nose),
              width: radius * 1.4,
              height: radius * 0.5,
            ),
            Radius.circular(radius * 0.2),
          ),
          _visor,
        );
      }
      canvas.drawCircle(
        p(Lm.nose),
        // max/min, not clamp: in a small PiP the floor exceeds the cap.
        radius,
        _head,
      );
    }
  }

  void _glow(Canvas canvas, Size s, FrameEdge e, double band, Color c) {
    final (Rect r, Alignment from, Alignment to) = switch (e) {
      FrameEdge.left => (
        Rect.fromLTWH(0, 0, band, s.height),
        Alignment.centerLeft,
        Alignment.centerRight,
      ),
      FrameEdge.right => (
        Rect.fromLTWH(s.width - band, 0, band, s.height),
        Alignment.centerRight,
        Alignment.centerLeft,
      ),
      FrameEdge.top => (
        Rect.fromLTWH(0, 0, s.width, band),
        Alignment.topCenter,
        Alignment.bottomCenter,
      ),
      FrameEdge.bottom => (
        Rect.fromLTWH(0, s.height - band, s.width, band),
        Alignment.bottomCenter,
        Alignment.topCenter,
      ),
    };
    _edge.shader = LinearGradient(
      begin: from,
      end: to,
      colors: [c.withValues(alpha: 0.85), c.withValues(alpha: 0)],
    ).createShader(r);
    canvas.drawRect(r, _edge);
    _edge.shader = null;
  }

  @override
  bool shouldRepaint(FramePainter old) =>
      old.frame != frame ||
      old.advice != advice ||
      old.showTarget != showTarget ||
      old.dimForMirror != dimForMirror;
}

/// Soft glow on the edges of the whole game screen where the player is
/// about to leave (amber) or has left (red) the camera's view. Selfie space
/// matches the screen, so the glow is on the same side as the player.
class ScreenEdgeGlow extends StatelessWidget {
  const ScreenEdgeGlow(this.advice, {super.key});
  final FramingAdvice? advice;

  @override
  Widget build(BuildContext context) {
    final a = advice;
    if (a == null || (a.cut.isEmpty && a.near.isEmpty)) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: FramePainter(
          null,
          FramingAdvice(FramingFix.ok, near: {...a.near, ...a.cut}),
          showTarget: false,
        ),
      ),
    );
  }
}
