import 'package:flutter/material.dart';
import 'package:motion_core/motion_core.dart';

import '../app/theme.dart';
import 'quest_button.dart';
import 'forest_backdrop.dart';

export 'forest_backdrop.dart';
export 'lantern_card.dart';
export 'quest_button.dart';
export 'step_progress.dart';
export 'success_badge.dart';

/// Big tap target for sweaty hands. Kept as the app-wide name; the look
/// comes from [QuestButton].
class BigButton extends StatelessWidget {
  const BigButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.icon,
    this.secondary = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;

  @override
  Widget build(BuildContext context) => QuestButton(
    label,
    onPressed: onPressed,
    icon: icon,
    secondary: secondary,
  );
}

/// Standard screen: transparent bar with a lantern tab beside the title,
/// the forest backdrop behind, and a padded scrolling column.
class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.showBack = true,
  });
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final bool showBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
          Container(
            width: 8,
            height: 28,
            decoration: BoxDecoration(
              color: Lantern.glow,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
        ],
      ),
      automaticallyImplyLeading: showBack,
      actions: actions,
    ),
    body: Stack(
      children: [
        const Positioned.fill(child: ForestBackdrop()),
        SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: children,
          ),
        ),
      ],
    ),
  );
}

/// Tracking quality dot: shape *and* colour (green circle, amber triangle,
/// red square), so colour-blind players can read it too.
class TrackingDot extends StatelessWidget {
  const TrackingDot(this.light, {super.key, this.size = 28});
  final TrackingLight light;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (light) {
      TrackingLight.green => (Icons.circle, Lantern.scarf, 'Tracking good'),
      TrackingLight.amber => (
        Icons.change_history,
        Lantern.warning,
        'Tracking shaky',
      ),
      TrackingLight.red => (Icons.square, Lantern.danger, 'Tracking paused'),
    };
    return Semantics(
      label: label,
      child: Icon(icon, color: color, size: size),
    );
  }
}

/// Draws the 33-point skeleton (never the camera image).
class SkeletonPainter extends CustomPainter {
  SkeletonPainter(this.frame, {this.ok = true});
  final PoseFrame? frame;
  final bool ok;

  @override
  void paint(Canvas canvas, Size size) {
    final f = frame;
    final outline = Paint()
      ..color = (ok ? Colors.greenAccent : Colors.white54)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    // Target outline: where the body should fit.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.2,
          size.height * 0.05,
          size.width * 0.6,
          size.height * 0.9,
        ),
        const Radius.circular(40),
      ),
      outline,
    );
    if (f == null || !f.hasPerson) return;
    final bone = Paint()
      ..color = ok ? Colors.greenAccent : Colors.amberAccent
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    Offset p(int i) => Offset(f[i].x * size.width, f[i].y * size.height);
    for (final (a, b) in Lm.edges) {
      if (f[a].visibility > 0.4 && f[b].visibility > 0.4) {
        canvas.drawLine(p(a), p(b), bone);
      }
    }
    for (final i in Lm.smoothed) {
      if (f[i].visibility > 0.4) {
        canvas.drawCircle(p(i), 7, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(SkeletonPainter old) => old.frame != frame || old.ok != ok;
}
