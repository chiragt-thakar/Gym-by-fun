import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motion_core/motion_core.dart';

import '../l10n/tr.dart';
import '../services/pose_service.dart';
import '../services/settings.dart';
import '../services/voice.dart';
import '../app/theme.dart';
import '../widgets/common.dart';
import '../widgets/frame_view.dart';

/// About 30 seconds: stand still, arms up, two squats, lean left, lean right.
/// Stores the player's own range on this device.
///
/// Fully hands-free (the phone is 2–2.5 m away): every step is spoken, it
/// advances by itself, framing problems are spoken with a direction, and a
/// step the player cannot finish within [_skipAfterMs] of in-frame time
/// falls back to a gentle default instead of leaving them stuck.
class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});
  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationState();
}

class _CalibrationState extends ConsumerState<CalibrationScreen> {
  static const _framing = Framing();
  static const _skipAfterMs = 20000;
  static const _repeatHintMs = 6000;

  final _cal = Calibrator();
  final _smoother = LandmarkSmoother();
  final _filter = FramingFilter();
  MotionSession? _session;
  StreamSubscription<PoseFrame>? _sub;
  PoseFrame? _frame;
  FramingAdvice _advice = const FramingAdvice(FramingFix.findMe);
  CalibrationStep _announced = CalibrationStep.done;
  FramingFix? _spokenFix;
  int _spokenAt = 0;
  int _skipNoticeUntil = 0;
  int _now = 0;
  bool _mirror = false;
  bool _finishing = false;

  static const _instructions = {
    CalibrationStep.neutral: 'Stand tall and still',
    CalibrationStep.armsUp: 'Raise both arms above your head',
    CalibrationStep.squats: 'Do two comfortable squats',
    CalibrationStep.leanLeft: 'Lean to your left and hold',
    CalibrationStep.leanRight: 'Lean to your right and hold',
    CalibrationStep.done: 'All set!',
  };

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final s = ref.read(settingsProvider);
    await ref.read(voiceProvider).init(s.language);
    if (!mounted) return;
    final session = MotionSession(
      ref.read(poseSourceProvider),
      initialCalibration: null,
    );
    final started = await session.start(
      tier: s.deviceTier ?? DeviceTier.mid,
      selfView: s.cameraMirror,
    );
    if (!mounted) {
      await session.dispose();
      return;
    }
    if (!started) {
      await session.dispose();
      if (mounted) context.go('/setup');
      return;
    }
    _session = session;
    _sub = session.frames.listen(_onFrame);
    setState(() => _mirror = session.selfView);
  }

  void _onFrame(PoseFrame f) {
    if (_finishing || !mounted) return;
    final ts = f.timestampMs;
    _now = ts;
    final q = const QualityGate().check(f);
    final shown = _filter.update(_framing.advise(f, q), ts);
    final smooth = _smoother.smooth(f);
    // Only trustworthy frames measure the player's range.
    if (q.ok) _cal.add(smooth);
    final voice = ref.read(voiceProvider);
    if (_cal.step != CalibrationStep.done &&
        _cal.stepActiveMs >= _skipAfterMs &&
        _cal.skip()) {
      _skipNoticeUntil = ts + 3000;
      voice.sayKey('cal_skip', force: true);
    }
    if (_cal.step != _announced) {
      _announced = _cal.step;
      final line = tr(_instructions[_cal.step]!);
      if (ts < _skipNoticeUntil) {
        // After a skip, let the reassurance finish before the next step.
        Future<void>.delayed(
          const Duration(milliseconds: 2600),
          () => voice.say(line, force: true),
        );
      } else {
        voice.say(line, force: true);
      }
    } else if (!shown.ok &&
        (shown.fix != _spokenFix || ts - _spokenAt >= _repeatHintMs)) {
      _spokenFix = shown.fix;
      _spokenAt = ts;
      voice.sayKey(framingKey(shown.fix));
    }
    if (shown.ok) _spokenFix = null;
    setState(() {
      _frame = smooth;
      _advice = shown;
    });
    if (_cal.step == CalibrationStep.done) _finish();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    final notifier = ref.read(settingsProvider.notifier);
    final profile = _cal.build();
    notifier.update((s) => s.copyWith(calibration: profile));
    await _sub?.cancel();
    _sub = null;
    await _session?.dispose();
    _session = null;
    if (mounted) {
      context.go(
        ref.read(settingsProvider).tutorialDone ? '/home' : '/tutorial',
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = _cal.step;
    final idx = CalibrationStep.values.indexOf(step);
    final str = ref.watch(settingsProvider).s;
    final framed = _advice.ok;
    // Big type: it is read from 2–2.5 m away. When the frame is wrong the
    // headline says how to fix it; calibration simply waits meanwhile.
    final headline = framed
        ? tr(_instructions[step]!)
        : str.t(framingKey(_advice.fix));
    final skipping = _now < _skipNoticeUntil;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: idx / (CalibrationStep.values.length - 1),
                  minHeight: 14,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SizedBox(
                // Fixed height: nothing below moves when the text changes.
                height: 84,
                child: Center(
                  child: Text(
                    headline,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: framed ? null : Lantern.warning,
                    ),
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
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      FrameView(
                        frame: _frame,
                        advice: _advice,
                        mirror: _mirror,
                      ),
                      if (framed)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _StepProgress(
                            progress: _cal.progress,
                            label: step == CalibrationStep.squats
                                ? '${_cal.squatsDone} / 2'
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: SizedBox(
                height: 48,
                child: Center(
                  child: Text(
                    skipping
                        ? tr('Using a gentle default for this step')
                        : tr(
                            'Move only as far as feels comfortable. The game uses your range.',
                          ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      fontSize: 16,
                      color: skipping ? Lantern.scarf : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The step's progress ring (or a tick when done), on a dark disc so it
/// reads over the camera mirror.
class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.progress, this.label});
  final double progress;
  final String? label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: Colors.black54,
      borderRadius: BorderRadius.all(Radius.circular(48)),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: progress >= 1
                ? const SuccessBadge(size: 64)
                : CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 8,
                    strokeCap: StrokeCap.round,
                  ),
          ),
          if (label != null) ...[
            const SizedBox(width: 12),
            Text(
              label!,
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
            ),
          ],
        ],
      ),
    ),
  );
}
