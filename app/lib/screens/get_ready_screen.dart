import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/router.dart' show withNext;
import '../app/theme.dart';
import '../game/stages.dart';
import '../l10n/tr.dart';
import '../services/settings.dart';
import '../widgets/common.dart';

/// Shown when the player taps play before the game knows their movement
/// range. Players can explore the app without calibrating; a run cannot
/// start without it, because every move is measured against their own range.
///
/// A short trail of what happens next, then straight into the run they
/// tapped ([next]). Nothing here is required to browse the app.
class GetReadyScreen extends ConsumerWidget {
  const GetReadyScreen({super.key, this.next});

  /// The run to open when setup and calibration are done.
  final String? next;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final target = next == null ? null : Uri.tryParse(next!);
    final levelId = target?.queryParameters['level'];
    final stage = levelId == null ? null : stageById(levelId);
    final runName = target?.path == '/tutorial'
        ? tr('Practise your moves')
        : tr(stage?.title ?? 'Your next adventure');
    void start() =>
        context.go(withNext(s.setupDone ? '/calibrate' : '/setup', next));
    void later() => context.canPop() ? context.pop() : context.go('/home');

    return ScreenScaffold(
      title: tr('Get ready to play'),
      children: [
        LanternCard(
          tone: LanternTone.glow,
          icon: Icons.accessibility_new,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Teach the game how you move'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr(
                  'One quick check so every move is measured against your own comfortable range. You only do this once.',
                ),
                style: const TextStyle(fontSize: 16, color: Lantern.fog),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _TrailStep(
          number: 1,
          icon: Icons.smartphone,
          title: tr('Set up your space'),
          detail: tr('Prop up the phone and step back'),
          time: tr('about 1 min'),
          done: s.setupDone,
        ),
        _TrailStep(
          number: 2,
          icon: Icons.self_improvement,
          title: tr('Show your comfortable range'),
          detail: tr('Stand tall, arms up, two squats, lean left and right'),
          time: tr('about 30 s'),
        ),
        _TrailStep(
          number: 3,
          icon: Icons.play_arrow_rounded,
          title: runName,
          detail: tr('Your run starts right after'),
          last: true,
        ),
        const SizedBox(height: 8),
        LanternCard(
          tone: LanternTone.scarf,
          icon: Icons.record_voice_over,
          child: Text(
            tr(
              'Hands-free: once you are in place, the voice guides you and each step starts by itself.',
            ),
            style: const TextStyle(fontSize: 16),
          ),
        ),
        LanternCard(
          icon: Icons.lock,
          child: Text(
            s.s.t('video_never_leaves'),
            style: const TextStyle(fontSize: 16),
          ),
        ),
        BigButton(
          key: const ValueKey('get-ready-start'),
          s.setupDone ? tr('Start calibration') : tr("Let's set up"),
          icon: Icons.videocam,
          onPressed: start,
        ),
        TextButton(
          key: const ValueKey('get-ready-later'),
          onPressed: later,
          child: Text(
            tr('Not now, keep exploring'),
            style: const TextStyle(fontSize: 17),
          ),
        ),
      ],
    );
  }
}

/// One stop on the trail: a numbered lantern, a line down to the next one.
class _TrailStep extends StatelessWidget {
  const _TrailStep({
    required this.number,
    required this.icon,
    required this.title,
    required this.detail,
    this.time,
    this.done = false,
    this.last = false,
  });
  final int number;
  final IconData icon;
  final String title;
  final String detail;
  final String? time;
  final bool done;
  final bool last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 44,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? Lantern.scarf : Lantern.moss,
                  border: Border.all(
                    color: done ? Lantern.scarf : Lantern.glow,
                    width: 2,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check, color: Lantern.night)
                    : Text(
                        '$number',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Lantern.glow,
                        ),
                      ),
              ),
              if (!last)
                Expanded(
                  child: Container(
                    width: 3,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: Lantern.ridge,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18, top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: Lantern.fog),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done ? Lantern.fog : Lantern.parchment,
                        ),
                      ),
                    ),
                    if (time != null && !done)
                      Text(
                        time!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Lantern.scarf,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: const TextStyle(fontSize: 15, color: Lantern.fog),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
