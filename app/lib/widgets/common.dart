import 'package:flutter/material.dart';
import 'package:motion_core/motion_core.dart';

/// Big tap target for sweaty hands.
class BigButton extends StatelessWidget {
  const BigButton(this.label, {super.key, required this.onPressed, this.icon, this.secondary = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(64)),
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
    );
    final child = Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      if (icon != null) ...[Icon(icon, size: 28), const SizedBox(width: 12)],
      Flexible(child: Text(label, textAlign: TextAlign.center)),
    ]);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: secondary
          ? OutlinedButton(onPressed: onPressed, style: style, child: child)
          : FilledButton(onPressed: onPressed, style: style, child: child),
    );
  }
}

class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({super.key, required this.title, required this.children, this.actions, this.showBack = true});
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  final bool showBack;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title), automaticallyImplyLeading: showBack, actions: actions),
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.all(20), children: children),
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
      TrackingLight.green => (Icons.circle, Colors.greenAccent, 'Tracking good'),
      TrackingLight.amber => (Icons.change_history, Colors.amberAccent, 'Tracking shaky'),
      TrackingLight.red => (Icons.square, Colors.redAccent, 'Tracking paused'),
    };
    return Semantics(label: label, child: Icon(icon, color: color, size: size));
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
        RRect.fromRectAndRadius(Rect.fromLTWH(size.width * 0.2, size.height * 0.05, size.width * 0.6, size.height * 0.9),
            const Radius.circular(40)),
        outline);
    if (f == null || !f.hasPerson) return;
    final bone = Paint()
      ..color = ok ? Colors.greenAccent : Colors.amberAccent
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    Offset p(int i) => Offset(f[i].x * size.width, f[i].y * size.height);
    for (final (a, b) in Lm.edges) {
      if (f[a].visibility > 0.4 && f[b].visibility > 0.4) canvas.drawLine(p(a), p(b), bone);
    }
    for (final i in Lm.smoothed) {
      if (f[i].visibility > 0.4) canvas.drawCircle(p(i), 7, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(SkeletonPainter old) => old.frame != frame || old.ok != ok;
}
