import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/tr.dart';

import 'package:motion_core/motion_core.dart';

import '../app/theme.dart';
import '../services/pose_service.dart';
import '../services/settings.dart';
import '../services/voice.dart';
import '../widgets/common.dart';
import '../widgets/frame_view.dart';

/// Space and phone setup, then a live 3:4 frame view (camera mirror if the
/// player allows it, plus their outline) that turns green when the whole
/// body is visible and lit. Also runs the 3-second device benchmark.
///
/// Hands-free: the player is 2–2.5 m from the phone, so once they have been
/// in a good frame for a moment a spoken 3-second countdown starts and
/// calibration opens by itself. The button is only a shortcut.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});
  @override
  ConsumerState<SetupScreen> createState() => _SetupState();
}

class _SetupState extends ConsumerState<SetupScreen> {
  static const _framing = Framing();
  static const _goodHoldMs = 1500;
  static const _countdownMs = 3000;
  static const _repeatHintMs = 6000;

  MotionSession? _session;
  StreamSubscription<PoseFrame>? _sub;
  final _smoother = LandmarkSmoother();
  final _filter = FramingFilter();
  PoseFrame? _frame;
  FramingAdvice _advice = const FramingAdvice(FramingFix.findMe);
  int? _goodSince;
  int? _startedAt;
  int? _autoAt;
  int _now = 0;
  FramingFix? _spokenFix;
  int _spokenAt = 0;
  bool _denied = false;
  bool _ready = false;
  bool _starting = false;
  bool _finishing = false;
  bool _mirror = false;

  Future<void> _startCamera() async {
    if (_starting || _session != null) return;
    setState(() => _starting = true);
    final s = ref.read(settingsProvider);
    await ref.read(voiceProvider).init(s.language);
    if (!mounted) return;
    final session = MotionSession(
      ref.read(poseSourceProvider),
      initialCalibration: null,
    );
    final ok = await session.start(
      tier: DeviceTier.mid,
      selfView: s.cameraMirror,
    );
    if (!mounted) {
      await session.dispose();
      return;
    }
    if (!ok) {
      await session.dispose();
      if (!mounted) return;
      setState(() {
        _denied = true;
        _starting = false;
      });
      return;
    }
    _session = session;
    _mirror = session.selfView;
    _sub = session.frames.listen(_onFrame);
    setState(() => _starting = false);
  }

  void _onFrame(PoseFrame f) {
    if (_finishing || !mounted) return;
    final ts = f.timestampMs;
    _now = ts;
    _startedAt ??= ts;
    final q = const QualityGate().check(f);
    final shown = _filter.update(_framing.advise(f, q), ts);
    if (shown.ok) {
      _goodSince ??= ts;
    } else {
      _goodSince = null;
      _autoAt = null; // left the frame: the countdown waits
    }
    final benchDone = ts - _startedAt! >= 3000;
    final ready =
        benchDone && _goodSince != null && ts - _goodSince! >= _goodHoldMs;
    final voice = ref.read(voiceProvider);
    if (ready && _autoAt == null) {
      _autoAt = ts + _countdownMs;
      voice.sayKey('setup_auto', force: true);
    } else if (!shown.ok &&
        (shown.fix != _spokenFix || ts - _spokenAt >= _repeatHintMs)) {
      // Spoken, because the player is too far away to read the screen.
      _spokenFix = shown.fix;
      _spokenAt = ts;
      voice.sayKey(framingKey(shown.fix));
    }
    if (shown.ok) _spokenFix = null;
    setState(() {
      _frame = _smoother.smooth(f);
      _advice = shown;
      _ready = ready;
    });
    final at = _autoAt;
    if (at != null && ts >= at) _finish();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final tier = _session?.perf.tier ?? DeviceTier.mid;
    final notifier = ref.read(settingsProvider.notifier);
    notifier.update((s) => s.copyWith(setupDone: true, deviceTier: tier));
    await _sub?.cancel();
    _sub = null;
    await _session?.dispose();
    _session = null;
    if (!mounted) return;
    // Redoing setup keeps an existing calibration (Q1-8).
    final s = ref.read(settingsProvider);
    context.go(
      s.calibration == null
          ? '/calibrate'
          : (s.tutorialDone ? '/home' : '/tutorial'),
    );
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
            onPressed: _starting ? null : _startCamera,
          ),
        ],
      );
    }
    final counting = _autoAt != null;
    final hint = counting
        ? tr('Starting calibration…')
        : _advice.ok
        ? tr('Great — hold still…')
        : str.t(framingKey(_advice.fix));
    // Big type: it is read from 2–2.5 m away.
    final big = Theme.of(context).textTheme.headlineMedium?.copyWith(
      fontWeight: FontWeight.w800,
      color: _advice.ok ? Colors.white : Lantern.warning,
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: SizedBox(
                // Fixed height: the frame never jumps when the text changes.
                height: 76,
                child: Center(
                  child: Text(
                    hint,
                    style: big,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: FrameView(
                    frame: _frame,
                    advice: _advice,
                    mirror: _mirror,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: counting
                        ? _Countdown(
                            remainingMs: (_autoAt! - _now).clamp(
                              0,
                              _countdownMs,
                            ),
                            totalMs: _countdownMs,
                          )
                        : (_ready
                              ? const SuccessBadge(size: 64)
                              : Icon(
                                  framingIcon(_advice.fix),
                                  size: 56,
                                  color: _advice.ok
                                      ? Colors.greenAccent
                                      : Lantern.warning,
                                )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          counting
                              ? tr('No tap needed. It starts by itself.')
                              : tr('Fit your body inside the outline'),
                          style: const TextStyle(fontSize: 18),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Only a shortcut for someone next to the phone.
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: TextButton(
                            onPressed: _ready ? _finish : null,
                            child: Text(
                              tr('Next: calibrate'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
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

/// Ring + seconds left before calibration opens by itself.
class _Countdown extends StatelessWidget {
  const _Countdown({required this.remainingMs, required this.totalMs});
  final int remainingMs;
  final int totalMs;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      SizedBox.expand(
        child: CircularProgressIndicator(
          value: 1 - remainingMs / totalMs,
          strokeWidth: 8,
          strokeCap: StrokeCap.round,
          color: Colors.greenAccent,
        ),
      ),
      Text(
        '${(remainingMs / 1000).ceil().clamp(1, 9)}',
        style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
      ),
    ],
  );
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
