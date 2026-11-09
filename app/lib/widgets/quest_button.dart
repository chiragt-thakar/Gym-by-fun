import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Chunky "lantern" button: a raised face sitting on a solid lip that
/// sinks when pressed. Built from plain containers (no shadows, no blur) so
/// it stays cheap on budget phones. Big enough for sweaty hands.
class QuestButton extends StatefulWidget {
  const QuestButton(
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
  State<QuestButton> createState() => _QuestButtonState();
}

class _QuestButtonState extends State<QuestButton> {
  static const _lip = 4.0;
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final (face, lip, fg, border) = switch ((widget.secondary, enabled)) {
      (false, true) => (
        Lantern.glow,
        Lantern.ember,
        Lantern.onGlow,
        Lantern.ember,
      ),
      (true, true) => (
        Lantern.surface2,
        Lantern.chunkyShadow,
        Lantern.parchment,
        Lantern.ridge,
      ),
      (_, false) => (
        Lantern.canopy,
        Lantern.chunkyShadow,
        Lantern.fog,
        Lantern.ridge,
      ),
    };
    final offset = _down && enabled ? _lip : 0.0;
    final radius = BorderRadius.circular(16);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Semantics(
        button: true,
        enabled: enabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _set(true) : null,
          onTapUp: enabled ? (_) => _set(false) : null,
          onTapCancel: () => _set(false),
          onTap: widget.onPressed,
          child: Container(
            constraints: const BoxConstraints(minHeight: 54 + _lip),
            decoration: BoxDecoration(color: lip, borderRadius: radius),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 70),
              margin: EdgeInsets.only(top: offset, bottom: _lip - offset),
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: face,
                borderRadius: radius,
                border: Border.all(color: border, width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, size: 22, color: fg),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                        color: fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
