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

/// About 30 seconds: stand still, arms up, two squats, lean left, lean right.
/// Stores the player's own range on this device.
class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key});
  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationState();
}

class _CalibrationState extends ConsumerState<CalibrationScreen> {
  final _cal = Calibrator();
  final _smoother = LandmarkSmoother();
  MotionSession? _session;
  StreamSubscription<PoseFrame>? _sub;
  PoseFrame? _frame;
  CalibrationStep _announced = CalibrationStep.done;
  bool _paused = false;
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
    final session = MotionSession(
      ref.read(poseSourceProvider),
      initialCalibration: null,
    );
    if (!await session.start(tier: s.deviceTier ?? DeviceTier.mid)) {
      if (mounted) context.go('/setup');
      return;
    }
    _session = session;
    _sub = session.frames.listen(_onFrame);
  }

  void _onFrame(PoseFrame f) {
    if (_finishing) return;
    final ok = const QualityGate().check(f).ok;
    if (ok) _cal.add(_smoother.smooth(f));
    if (_cal.step != _announced) {
      _announced = _cal.step;
      ref.read(voiceProvider).say(tr(_instructions[_cal.step]!), force: true);
    }
    setState(() {
      _frame = f;
      _paused = !ok;
    });
    if (_cal.step == CalibrationStep.done) _finish();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    await _sub?.cancel();
    _sub = null;
    final profile = _cal.build();
    await _session?.dispose();
    _session = null;
    ref
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(calibration: profile));
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
            Expanded(
              child: CustomPaint(
                painter: SkeletonPainter(_frame, ok: !_paused),
                child: const SizedBox.expand(),
              ),
            ),
            LanternCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    tr(_instructions[step]!),
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (step == CalibrationStep.squats)
                    Text(
                      '${_cal.squatsDone} / 2',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: _cal.progress >= 1
                        ? const SuccessBadge(size: 64)
                        : CircularProgressIndicator(
                            value: _cal.progress,
                            strokeWidth: 8,
                            strokeCap: StrokeCap.round,
                          ),
                  ),
                  if (_paused)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Lantern.warning,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              tr('Make sure your whole body is in the frame.'),
                              style: const TextStyle(
                                fontSize: 18,
                                color: Lantern.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      'Move only as far as feels comfortable. The game uses your range.',
                    ),
                    textAlign: TextAlign.center,
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
