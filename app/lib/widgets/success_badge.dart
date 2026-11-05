import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Lightweight success state: a teal medallion with a tick that pops in
/// once (a single implicit tween, nothing loops). Pass [label] to show text
/// beside the tick; the tick alone still reads without colour.
class SuccessBadge extends StatelessWidget {
  const SuccessBadge({super.key, this.label, this.size = 56});
  final String? label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final text = label;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Lantern.scarf,
              shape: BoxShape.circle,
              border: Border.all(color: Lantern.parchment, width: 3),
            ),
            child: Icon(
              Icons.check_rounded,
              size: size * 0.62,
              color: const Color(0xFF032420),
            ),
          ),
          if (text != null) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                text,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
