import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Onboarding step trail: finished steps show a tick, the current step is a
/// wide lantern pill with its number, upcoming steps are hollow. Shape and
/// icon carry the meaning as well as colour.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.current, required this.total});

  /// Zero-based index of the current step.
  final int current;
  final int total;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Step ${current + 1} of $total',
    excludeSemantics: true,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: i <= current ? Lantern.scarf : Lantern.ridge,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            _Dot(index: i, current: current),
          ],
        ],
      ),
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot({required this.index, required this.current});
  final int index;
  final int current;

  @override
  Widget build(BuildContext context) {
    final done = index < current;
    final now = index == current;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutBack,
      width: now ? 64 : 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: now
            ? Lantern.glow
            : done
            ? Lantern.scarf
            : Lantern.night,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: now ? Lantern.ember : (done ? Lantern.scarf : Lantern.ridge),
          width: 2.5,
        ),
      ),
      child: done
          ? const Icon(Icons.check, size: 22, color: Color(0xFF032420))
          : Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: now ? Lantern.onGlow : Lantern.fog,
              ),
            ),
    );
  }
}
