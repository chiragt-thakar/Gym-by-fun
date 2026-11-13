import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motion_core/motion_core.dart';

import '../app/router.dart' show withNext;
import '../l10n/tr.dart';
import '../services/pose_service.dart';
import '../services/settings.dart';
import '../services/voice.dart';
import '../app/theme.dart';
import '../widgets/common.dart';
import '../widgets/frame_view.dart';
import '../widgets/tracking_overlay.dart';

/// One plain-language fix for something that made a calibration less
/// trustworthy.
String calibrationFix(CalibrationIssue i) => switch (i) {
  CalibrationIssue.unsteady =>
    'Hold still, and rest the phone on something steady.',
  CalibrationIssue.lowLight =>
    'It is a little dark. Turn on a light in front of you.',
  CalibrationIssue.feetHidden =>
    'Step back until your feet are in view, if you have the room.',
  CalibrationIssue.tooFar => 'Step a little closer to the phone.',
  CalibrationIssue.tooClose => 'Step back so raised arms stay in view.',
  CalibrationIssue.lowFrameRate =>
    'The phone is running slowly. Close other apps if you can.',
  CalibrationIssue.tilted => 'Straighten the phone so it is not leaning.',
  CalibrationIssue.sideOn => 'Face the phone squarely.',
  CalibrationIssue.stepsSkipped => 'Some steps used gentle defaults.',
  CalibrationIssue.unevenSquats =>
    'Squat to about the same comfortable depth each time.',
  CalibrationIssue.unevenLean => 'Lean about the same to both sides.',
};

/// About 30 seconds: stand still, arms up, two squats, lean left, lean right.
/// Stores the player's own body model and range on this device.
///
/// Fully hands-free (the phone is 2–2.5 m away): every step is spoken, it
/// advances by itself, framing problems are spoken with a direction, and a
/// step the player cannot finish within [_skipAfterMs] of in-frame time
/// falls back to a gentle default instead of leaving them stuck.
///
/// Every measurement is scored. A poor result (too dark, feet hidden and
/// steps skipped, a moving phone) says what to fix and runs once more by
/// itself; the player can also keep it. Nobody is ever trapped here.
///
/// [quick] re-checks only the standing position and keeps the measured
/// range: five seconds, for a new spot or a moved phone.
///
/// [next] is the run the player tapped before calibrating; it opens when
/// calibration is done.
class CalibrationScreen extends ConsumerStatefulWidget {
  const CalibrationScreen({super.key, this.next, this.quick = false});
  final String? next;
  final bool quick;
  @override
  ConsumerState<CalibrationScreen> createState() => _CalibrationState();
}

class _CalibrationState extends ConsumerState<CalibrationScreen> {
  static const _framing = Framing();
  static const _skipAfterMs = 20000;
  static const _repeatHintMs = 6000;
  static const _retryAfterMs = 7000;

  late Calibrator _cal = _newCalibrator();
  final _filter = FramingFilter();
  MotionSession? _session;
  StreamSubscription<TrackedFrame>? _sub;
  PoseFrame? _frame;
  FramingAdvice _advice = const FramingAdvice(FramingFix.findMe);
  bool _tracked = false;
  CalibrationStep _announced = CalibrationStep.done;
  FramingFix? _spokenFix;
  int _spokenAt = 0;
  CalibrationIssue? _spokenCondition;
  int _conditionAt = -100000;
  int _skipNoticeUntil = 0;
  int _now = 0;
  bool _mirror = false;
  bool _finishing = false;

  /// A poor first attempt, shown with its fixes while the retry counts down.
  CalibrationReport? _poor;
  CalibrationProfile? _poorProfile;
  int _retryAt = 0;
  bool _retried = false;

  static const _instructions = {
    CalibrationStep.neutral: 'Stand tall and still',
    CalibrationStep.armsUp: 'Raise both arms above your head',
    CalibrationStep.squats: 'Do two comfortable squats',
    CalibrationStep.leanLeft: 'Lean to your left and hold',
    CalibrationStep.leanRight: 'Lean to your right and hold',
    CalibrationStep.done: 'All set!',
  };

  Calibrator _newCalibrator() {
    final base = widget.quick ? ref.read(settingsProvider).calibration : null;
    return Calibrator(base: base);
  }

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
      multiPerson: s.multiPerson,
    );
    if (!mounted) {
      await session.dispose();
      return;
    }
    if (!started) {
      await session.dispose();
      if (mounted) context.go(withNext('/setup', widget.next));
      return;
    }
    _session = session;
    _sub = session.tracked.listen(_onFrame);
    setState(() => _mirror = session.selfView);
  }

  void _buzz() {
    if (ref.read(settingsProvider).haptics) HapticFeedback.mediumImpact();
  }

  void _onFrame(TrackedFrame t) {
    if (_finishing || !mounted) return;
    final ts = t.timestampMs;
    _now = ts;
    final shown = _filter.update(_framing.advise(t.raw, t.quality), ts);
    final voice = ref.read(voiceProvider);

    // Waiting to retry after a poor result: nothing is measured meanwhile.
    if (_poor != null) {
      if (ts >= _retryAt) _retry();
      setState(() {
        _frame = t.frame;
        _advice = shown;
        _tracked = t.playable;
      });
      return;
    }

    // Only measured frames with the torso tracked teach the profile; a
    // predicted body or a tracking gap never does.
    if (t.playable && !t.coasted) _cal.add(t.frame);

    if (_cal.step != CalibrationStep.done &&
        _cal.stepActiveMs >= _skipAfterMs &&
        _cal.skip()) {
      _skipNoticeUntil = ts + 3000;
      voice.sayKey('cal_skip', force: true);
    }
    if (_cal.step != _announced) {
      if (_announced != CalibrationStep.done) _buzz();
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
    } else if (!t.playable &&
        !shown.ok &&
        (shown.fix != _spokenFix || ts - _spokenAt >= _repeatHintMs)) {
      _spokenFix = shown.fix;
      _spokenAt = ts;
      voice.sayKey(framingKey(shown.fix));
    } else if (t.playable) {
      // Conditions worth fixing now, one at a time and not too often.
      final condition = _condition();
      if (condition != null &&
          (condition != _spokenCondition || ts - _conditionAt >= 15000) &&
          ts - _conditionAt >= 8000) {
        _spokenCondition = condition;
        _conditionAt = ts;
        voice.say(tr(calibrationFix(condition)));
      }
    }
    if (shown.ok) _spokenFix = null;
    setState(() {
      _frame = t.frame;
      _advice = shown;
      _tracked = t.playable;
    });
    if (_cal.step == CalibrationStep.done) _onDone(ts);
  }

  /// The live condition most worth mentioning, if any.
  CalibrationIssue? _condition() {
    final c = _cal.conditions;
    for (final i in const [
      CalibrationIssue.unsteady,
      CalibrationIssue.lowLight,
      CalibrationIssue.feetHidden,
      CalibrationIssue.lowFrameRate,
    ]) {
      if (c.contains(i)) return i;
    }
    return null;
  }

  void _onDone(int ts) {
    final report = _cal.report;
    final profile = _cal.build();
    // One automatic second attempt for a poor result. A second poor result
    // is kept: play must never be blocked by the room the player has.
    if (report.shouldRetry && !_retried && !widget.quick) {
      _retried = true;
      final fixes = _fixes(report);
      ref
          .read(voiceProvider)
          .say(
            fixes.isEmpty
                ? tr("Let's try that once more.")
                : '${tr(calibrationFix(fixes.first))} ${tr("Let's try that once more.")}',
            force: true,
          );
      setState(() {
        _poor = report;
        _poorProfile = profile;
        _retryAt = ts + _retryAfterMs;
      });
      return;
    }
    _finish(profile);
  }

  /// The issues a player can do something about, most useful first.
  static List<CalibrationIssue> _fixes(CalibrationReport r) => [
    for (final i in const [
      CalibrationIssue.lowLight,
      CalibrationIssue.unsteady,
      CalibrationIssue.feetHidden,
      CalibrationIssue.tooClose,
      CalibrationIssue.tooFar,
      CalibrationIssue.sideOn,
      CalibrationIssue.tilted,
      CalibrationIssue.lowFrameRate,
      CalibrationIssue.unevenSquats,
      CalibrationIssue.unevenLean,
    ])
      if (r.issues.contains(i)) i,
  ];

  void _retry() {
    setState(() {
      _poor = null;
      _poorProfile = null;
      _cal = _newCalibrator();
      _announced = CalibrationStep.done;
      _skipNoticeUntil = 0;
    });
  }

  Future<void> _finish(CalibrationProfile profile) async {
    if (_finishing) return;
    _finishing = true;
    _buzz();
    final notifier = ref.read(settingsProvider.notifier);
    notifier.update((s) => s.copyWith(calibration: profile));
    await _sub?.cancel();
    _sub = null;
    await _session?.dispose();
    _session = null;
    if (mounted) {
      context.go(
        widget.next ??
            (ref.read(settingsProvider).tutorialDone ? '/home' : '/tutorial'),
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
    final settings = ref.watch(settingsProvider);
    final str = settings.s;
    final step = _cal.step;
    final poor = _poor;
    final steps = widget.quick
        ? const [CalibrationStep.neutral]
        : CalibrationStep.values
              .where((s) => s != CalibrationStep.done)
              .toList();
    final idx = step == CalibrationStep.done
        ? steps.length
        : steps.indexOf(step);
    // Big type: it is read from 2–2.5 m away. While the player cannot be
    // tracked the headline says how to fix it; calibration simply waits.
    final headline = poor != null
        ? tr("Let's try that once more")
        : _tracked
        ? tr(_instructions[step]!)
        : str.t(framingKey(_advice.fix));
    final skipping = _now < _skipNoticeUntil;
    final condition = poor == null && _tracked ? _condition() : null;
    final helper = skipping
        ? tr('Using a gentle default for this step')
        : condition != null
        ? tr(calibrationFix(condition))
        : widget.quick
        ? tr('A quick check of where you are standing. Your range is kept.')
        : tr(
            'Move only as far as feels comfortable. The game uses your range.',
          );
    final session = _session;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _StepTrail(done: idx, total: steps.length),
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
                      color: _tracked || poor != null ? null : Lantern.warning,
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
                        advice: _tracked
                            ? playAdvice(_advice, usable: true)
                            : _advice,
                        mirror: _mirror,
                        showCue: !_tracked && poor == null,
                      ),
                      if (poor != null)
                        Positioned.fill(
                          child: _RetryCard(
                            fixes: _fixes(poor),
                            progress:
                                (1 - (_retryAt - _now) / _retryAfterMs)
                                    .clamp(0.0, 1.0)
                                    .toDouble(),
                            onKeep: () => _finish(_poorProfile!),
                            onRetry: _retry,
                          ),
                        )
                      else if (_tracked)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _StepProgress(
                            progress: _cal.progress,
                            label: step == CalibrationStep.squats
                                ? '${_cal.squatsDone} / 2'
                                : null,
                          ),
                        ),
                      if (settings.diagnostics && session != null)
                        Positioned(
                          left: 6,
                          top: 6,
                          right: 6,
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: TrackingDiagnostics(session: session),
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
                    poor != null ? tr('Your camera stays on this phone.') : helper,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      color: skipping
                          ? Lantern.scarf
                          : (condition != null ? Lantern.warning : null),
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

/// Step dots: finished, current, to do. Shape as well as colour.
class _StepTrail extends StatelessWidget {
  const _StepTrail({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Step ${(done + 1).clamp(1, total)} of $total',
    child: Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: i == done ? 12 : 8,
              decoration: BoxDecoration(
                color: i < done
                    ? Lantern.scarf
                    : (i == done ? Lantern.glow : Lantern.moss),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// What to fix after a poor result, while the second attempt counts down.
class _RetryCard extends StatelessWidget {
  const _RetryCard({
    required this.fixes,
    required this.progress,
    required this.onKeep,
    required this.onRetry,
  });
  final List<CalibrationIssue> fixes;
  final double progress;
  final VoidCallback onKeep;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xE6090B10),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('I could not see you clearly enough.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          for (final f in fixes.take(3))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.arrow_right_alt_rounded,
                    color: Lantern.warning,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr(calibrationFix(f)),
                      style: const TextStyle(fontSize: 18, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: progress, minHeight: 8),
          ),
          const SizedBox(height: 6),
          Text(
            tr('Starting again by itself…'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: Lantern.fog),
          ),
          const SizedBox(height: 10),
          BigButton(tr('Try again now'), onPressed: onRetry),
          TextButton(
            onPressed: onKeep,
            child: Text(
              tr('Use this result anyway'),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    ),
  );
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
