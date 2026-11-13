import 'package:flutter/material.dart';

import '../app/theme.dart';

/// The Joynetic button: a tall pill. The primary is solid volt with ink
/// text (one per screen); the secondary is a quiet outlined pill. It
/// shrinks a little while pressed. No shadows or blur, so it stays cheap on
/// budget phones, and it is 56 px tall for sweaty hands.
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
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final (face, fg, border) = switch ((widget.secondary, enabled)) {
      (false, true) => (_down ? Jn.voltDeep : Jn.volt, Jn.onVolt, Jn.volt),
      (true, true) => (_down ? Jn.raised : Jn.inset, Jn.text, Jn.edge),
      (_, false) => (Jn.panel, Jn.textFaint, Jn.line),
    };
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
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
          child: AnimatedScale(
            scale: _down && enabled && !still ? 0.97 : 1,
            duration: Motion.quick,
            curve: Motion.enter,
            child: AnimatedContainer(
              duration: Motion.quick,
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: face,
                // The primary action glows: a gradient face and a soft halo.
                gradient: !widget.secondary && enabled && !_down
                    ? Jn.action
                    : null,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: border, width: 1.5),
                boxShadow: !widget.secondary && enabled
                    ? [
                        BoxShadow(
                          color: Jn.volt.withValues(alpha: _down ? 0.12 : 0.28),
                          blurRadius: 22,
                          spreadRadius: -4,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
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
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.1,
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
