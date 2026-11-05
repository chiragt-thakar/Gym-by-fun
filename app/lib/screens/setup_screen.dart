import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/tr.dart';

import 'package:motion_core/motion_core.dart';

import '../app/theme.dart';
import '../game/forest_game.dart';
import '../services/pose_service.dart';
import '../services/settings.dart';
import '../widgets/common.dart';

/// Space and phone setup, then a live outline that turns green when the
/// whole body is visible and lit. Also runs the 3-second device benchmark.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});
  @override
  ConsumerState<SetupScreen> createState() => _SetupState();
}

class _SetupState extends ConsumerState<SetupScreen> {
  MotionSession? _session;
  StreamSubscription<PoseFrame>? _sub;
  PoseFrame? _frame;
  QualityResult _q = const QualityResult.fail(TrackingIssue.noPerson);
  int? _goodSince;
  int? _startedAt;
  bool _denied = false;
  bool _ready = false;

  Future<void> _startCamera() async {
    final session = MotionSession(
      ref.read(poseSourceProvider),
      initialCalibration: null,
    );
    final ok = await session.start(tier: DeviceTier.mid);
    if (!mounted) {
      await session.dispose();
      return;
    }
    if (!ok) {
      setState(() => _denied = true);
      return;
    }
    _session = session;
    _sub = session.frames.listen((f) {
      final q = const QualityGate().check(f);
      _startedAt ??= f.timestampMs;
      if (q.ok) {
        _goodSince ??= f.timestampMs;
      } else {
        _goodSince = null;
      }
      final benchDone = f.timestampMs - _startedAt! >= 3000;
      if (!mounted) return;
      setState(() {
        _frame = f;
        _q = q;
        _ready =
            benchDone &&
            _goodSince != null &&
            f.timestampMs - _goodSince! >= 1500;
      });
    });
    setState(() {});
  }

  Future<void> _finish() async {
    final tier = _session?.perf.tier ?? DeviceTier.mid;
    await _sub?.cancel();
    await _session?.dispose();
    ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(setupDone: true, deviceTier: tier));
    if (mounted) context.go('/calibrate');
  }

  @override
  void dispose() {
    _sub?.cancel();
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final str = ref.watch(settingsProvider).s;
    if (_session == null) {
      return ScreenScaffold(
        title: tr('Set up your space'),
        children: [
          _Step(
            Icons.smartphone,
            tr(
              'Prop the phone up in portrait against a wall or a bottle, front camera facing you.',
            ),
          ),
          _Step(
            Icons.crop_free,
            tr('Clear a 2 × 2 m space, away from furniture edges.'),
          ),
          _Step(
            Icons.directions_walk,
            tr('Stand 2 – 2.5 m away so your whole body fits, head to feet.'),
          ),
          _Step(
            Icons.light_mode,
            tr(
              'Light in front of you works best; avoid a bright window behind you.',
            ),
          ),
          const SizedBox(height: 12),
          LanternCard(
            tone: LanternTone.scarf,
            icon: Icons.lock,
            child: Text(
              str.t('video_never_leaves'),
              style: const TextStyle(fontSize: 18),
            ),
          ),
          if (_denied)
            LanternCard(
              tone: LanternTone.warning,
              icon: Icons.videocam_off,
              child: Text(
                tr(
                  'Camera permission is needed to play. You can allow it in Android Settings → Apps → MotionQuest.',
                ),
                style: const TextStyle(color: Lantern.warning, fontSize: 17),
              ),
            ),
          BigButton(
            tr('Allow camera and start'),
            icon: Icons.videocam,
            onPressed: _startCamera,
          ),
        ],
      );
    }
    final hint = _q.ok
        ? tr('Great — hold still…')
        : ref.watch(settingsProvider).s.t(ForestGame.issueKey(_q.issue!));
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: CustomPaint(
                painter: SkeletonPainter(_frame, ok: _q.ok),
                child: const SizedBox.expand(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_ready) ...[
                        const SuccessBadge(size: 44),
                        const SizedBox(width: 12),
                      ],
                      Flexible(
                        child: Text(
                          hint,
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  BigButton(
                    tr('Next: calibrate'),
                    onPressed: _ready ? _finish : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => LanternCard(
    icon: icon,
    child: Text(text, style: const TextStyle(fontSize: 18)),
  );
}
