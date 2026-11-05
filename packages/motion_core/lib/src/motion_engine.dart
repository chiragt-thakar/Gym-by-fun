import 'calibration.dart';
import 'events.dart';
import 'extra_recognisers.dart';
import 'features.dart';
import 'landmarks.dart';
import 'one_euro_filter.dart';
import 'quality_gate.dart';
import 'recognisers.dart';

/// Traffic-light state of the in-game tracking dot.
enum TrackingLight { green, amber, red }

/// Everything the debug screen shows for one frame.
class EngineSnapshot {
  const EngineSnapshot({
    required this.timestampMs,
    required this.light,
    required this.quality,
    required this.states,
    required this.measures,
  });

  final int timestampMs;
  final TrackingLight light;
  final QualityResult quality;
  final Map<String, String> states;
  final Map<String, double> measures;
}

/// The motion pipeline for one play session:
///
///   PoseFrame → QualityGate → One Euro smoothing → BodyFeatures → recognisers
///
/// Call [process] with each new frame (latest frame only — the bridge drops
/// older ones). It returns the events that frame produced, in order.
class MotionEngine {
  MotionEngine({
    required this.calibration,
    this.thresholds = const MotionThresholds(),
    QualityGate? gate,
    this.smooth = true,
    this.pauseAfterMs = 250,
    this.resumeAfterMs = 300,
    this.enableBarrierHold = false,
    this.enableSideStep = false,
    this.extraThresholds = const ExtraMoveThresholds(),
  })  : gate = gate ?? const QualityGate(),
        _smoother = LandmarkSmoother() {
    _squat = SquatRecogniser(calibration, thresholds);
    _lean = LeanRecogniser(calibration, thresholds);
    _arms = RaiseArmsRecogniser(thresholds);
    _barrier = enableBarrierHold
        ? BarrierHoldRecogniser(calibration, thresholds, extraThresholds)
        : null;
    _step = enableSideStep
        ? SideStepRecogniser(calibration, thresholds, extraThresholds)
        : null;
  }

  final CalibrationProfile calibration;
  final MotionThresholds thresholds;
  final QualityGate gate;
  final bool smooth;

  /// A bad-quality streak shorter than this is ignored (amber light only).
  final int pauseAfterMs;

  /// Good frames needed before play resumes after a pause.
  final int resumeAfterMs;

  /// Opt-in roadmap moves (default off, so World 1–3 gameplay is unchanged).
  /// They emit [ExtraMoveStarted] / [ExtraMoveHeld] / [ExtraMoveEnded] /
  /// [ExtraMoveRejected], never the [Move] events.
  final bool enableBarrierHold;
  final bool enableSideStep;
  final ExtraMoveThresholds extraThresholds;

  final LandmarkSmoother _smoother;
  late final SquatRecogniser _squat;
  late final LeanRecogniser _lean;
  late final RaiseArmsRecogniser _arms;
  late final BarrierHoldRecogniser? _barrier;
  late final SideStepRecogniser? _step;

  bool _paused = false;
  int? _badSince;
  int? _goodSince;
  QualityResult _lastQuality = const QualityResult.fail(TrackingIssue.noPerson);
  int _lastTs = 0;

  bool get paused => _paused;
  QualityResult get lastQuality => _lastQuality;

  TrackingLight get light => _paused
      ? TrackingLight.red
      : (_lastQuality.ok ? TrackingLight.green : TrackingLight.amber);

  /// Scratch buffer the recognisers append to; cleared every frame so the
  /// common "nothing happened" frame allocates no event list.
  final List<MotionEvent> _out = <MotionEvent>[];

  /// Returns this frame's events. Frames without events return a shared
  /// empty, unmodifiable list; otherwise a fresh list the caller may keep.
  List<MotionEvent> process(PoseFrame raw) {
    final out = _out..clear();
    _process(raw, out);
    return out.isEmpty ? const <MotionEvent>[] : List.of(out);
  }

  void _process(PoseFrame raw, List<MotionEvent> out) {
    final ts = raw.timestampMs;
    _lastTs = ts;
    final q = gate.check(raw);
    _lastQuality = q;

    if (!q.ok) {
      _goodSince = null;
      _badSince ??= ts;
      if (!_paused && ts - _badSince! >= pauseAfterMs) {
        _paused = true;
        _squat.interrupt(ts, out);
        _lean.interrupt(ts, out);
        _arms.interrupt(ts, out);
        _barrier?.interrupt(ts, out);
        _step?.interrupt(ts, out);
        _smoother.reset();
        out.add(TrackingPaused(ts, q.issue!));
      }
      return;
    }

    _badSince = null;
    final frame = smooth ? _smoother.smooth(raw) : raw;
    if (_paused) {
      _goodSince ??= ts;
      if (ts - _goodSince! < resumeAfterMs) return;
      _paused = false;
      out.add(TrackingResumed(ts));
    }

    final b = BodyFeatures.from(frame);
    _squat.update(b, out);
    _lean.update(b, out);
    _arms.update(b, out);
    _barrier?.update(b, out);
    _step?.update(b, out);
  }

  EngineSnapshot get snapshot => EngineSnapshot(
        timestampMs: _lastTs,
        light: light,
        quality: _lastQuality,
        states: {
          'squat': _squat.state,
          'lean': _lean.state,
          'raiseArms': _arms.state,
          if (_barrier case final r?) 'barrierHold': r.state,
          if (_step case final r?) 'sideStep': r.state,
        },
        measures: {
          'squat': _squat.measure,
          'lean': _lean.measure,
          'raiseArms': _arms.measure,
          if (_barrier case final r?) 'barrierHold': r.measure,
          if (_step case final r?) 'sideStep': r.measure,
        },
      );
}
