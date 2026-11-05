import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Tone of a [LanternCard]. Each tone also carries its own default icon so
/// colour is never the only signal.
enum LanternTone { plain, glow, scarf, warning }

/// Rounded, chunky panel with a thick border and an optional leading icon.
/// No shadows, so it is cheap inside lists.
class LanternCard extends StatelessWidget {
  const LanternCard({
    super.key,
    required this.child,
    this.icon,
    this.tone = LanternTone.plain,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final IconData? icon;
  final LanternTone tone;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final (bg, border, iconColor) = switch (tone) {
      LanternTone.plain => (Lantern.canopy, Lantern.ridge, Lantern.glow),
      LanternTone.glow => (const Color(0xFF3A2410), Lantern.glow, Lantern.glow),
      LanternTone.scarf => (
        const Color(0xFF0E2F2B),
        Lantern.scarf,
        Lantern.scarf,
      ),
      LanternTone.warning => (
        const Color(0xFF4A2A06),
        Lantern.warning,
        Lantern.warning,
      ),
    };
    final ic = icon;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Lantern.radius),
        border: Border.all(color: border, width: 2.5),
      ),
      child: ic == null
          ? child
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(ic, size: 34, color: iconColor),
                const SizedBox(width: 14),
                Expanded(child: child),
              ],
            ),
    );
  }
}
