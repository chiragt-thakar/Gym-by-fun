import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:motion_core/motion_core.dart';

import '../app/theme.dart';
import 'quest_button.dart';
import 'forest_backdrop.dart';

export 'brand.dart';
export 'forest_backdrop.dart';
export 'lantern_card.dart';
export 'quest_button.dart';
export 'step_progress.dart';
export 'success_badge.dart';
export 'ui_kit.dart';

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

/// Standard page: a clean title bar with a back button that always leads
/// somewhere sensible (the previous page, or Home when this page was opened
/// directly), the forest backdrop behind, and a padded scrolling column.
class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    super.key,
    required this.title,
    required this.children,
    this.actions,
    this.showBack = true,
    this.subtitle,
  });
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final bool showBack;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final nav = Navigator.of(context);
    final router = GoRouter.maybeOf(context);
    final canPop = nav.canPop() || (router?.canPop() ?? false);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: !showBack
            ? null
            : IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  if (canPop) {
                    nav.maybePop();
                  } else {
                    router?.go('/home');
                  }
                },
              ),
        titleSpacing: showBack ? 0 : Space.gutter,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, overflow: TextOverflow.ellipsis),
            if (subtitle != null)
              Text(
                subtitle!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: Lantern.mist,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        actions: actions,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: ForestBackdrop()),
          SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Space.gutter,
                Space.s,
                Space.gutter,
                Space.xxl,
              ),
              children: children,
            ),
          ),
        ],
      ),
    );
  }
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
      ..color = (ok ? Lantern.scarf : Colors.white54)
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
      ..color = ok ? Lantern.scarf : Lantern.warning
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
