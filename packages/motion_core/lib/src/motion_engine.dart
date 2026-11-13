import 'body_tracker.dart';
import 'calibration.dart';
import 'detectors.dart';
import 'drift.dart';
import 'events.dart';
import 'extra_recognisers.dart';
import 'features.dart';
import 'landmarks.dart';
import 'quality_gate.dart';
import 'recognisers.dart';
import 'signals.dart';
import 'tracking_state.dart';

/// Traffic-light state of the in-game tracking dot.
///
/// Green: the last frame could drive play. Amber: a gap is being bridged.
/// Red: tracking is lost and the game is holding.
enum TrackingLight { green, amber, red }

/// Everything the diagnostics overlay shows for one frame.
class EngineSnapshot {
  const EngineSnapshot({
    required this.timestampMs,
    required this.light,
    required this.quality,
    required this.states,
    required this.measures,
    this.trackingState = TrackingState.tracking,
    this.predicted = 0,
    this.driftRebases = 0,
  });

  final int timestampMs;
  final TrackingLight light;
  final QualityResult quality;
  final Map<String, String> states;
  final Map<String, double> measures;
  final TrackingState trackingState;

  /// Landmarks predicted (not measured) in the last frame.
  final int predicted;

  /// Times the calibration was re-positioned by drift correction.
  final int driftRebases;
}

/// The motion pipeline for one play session:
///
///   PoseFrame → BodyTracker (lock, quality, stabiliser, state machine)
///             → BodyFeatures → detectors → MotionEvent
///
/// Call [process] with each new frame (latest frame only — the bridge drops
/// older ones). It returns the events that frame produced, in order.
///
/// The three core moves (squat, lean, raise arms) are always on. Everything
/// else is a plug-in: pass [detectors] with ids from the [registry].
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
    List<DetectorSpec> detectors = const [],
    DetectorRegistry? registry,
    BodyTracker? tracker,
    this.driftCorrection = true,
  })  : gate = gate ?? tracker?.config.gate ?? const QualityGate(),
        _drift = DriftCorrector(calibration) {
    this.tracker = tracker ??
        BodyTracker(BodyTrackerConfig(
          gate: this.gate,
          smooth: smooth,
          state: TrackingStateConfig(
            pauseAfterMs: pauseAfterMs,
            resumeAfterMs: resumeAfterMs,
          ),
        ));
    final reg = registry ?? DetectorRegistry.standard();
    final ctx = DetectorContext(
      calibration: calibration,
      thresholds: thresholds,
      extra: extraThresholds,
    );
    _detectors = [
      reg.build(const DetectorSpec(DetectorIds.squat), ctx),
      reg.build(const DetectorSpec(DetectorIds.lean), ctx),
      reg.build(const DetectorSpec(DetectorIds.raiseArms), ctx),
      if (enableBarrierHold)
        reg.build(const DetectorSpec(DetectorIds.barrierHold), ctx),
      if (enableSideStep)
        reg.build(const DetectorSpec(DetectorIds.sideStep), ctx),
      for (final spec in detectors) reg.build(spec, ctx),
    ];
    final seen = <String>{};
    for (final d in _detectors) {
      if (!seen.add(d.id)) {
        throw ArgumentError('Detector "${d.id}" requested twice');
      }
    }
  }

  /// The calibration the session started with. See [liveCalibration].
  final CalibrationProfile calibration;
  final MotionThresholds thresholds;
  final QualityGate gate;
  final bool smooth;

  /// Unusable frames for shorter than this are bridged (amber light only).
  /// Ignored when a shared [tracker] is supplied: its own config rules.
  final int pauseAfterMs;

  /// Usable frames needed before play resumes after a pause.
  final int resumeAfterMs;

  /// Opt-in roadmap moves (default off, so World 1–3 gameplay is unchanged).
  /// They emit [ExtraMoveStarted] / [ExtraMoveHeld] / [ExtraMoveEnded] /
  /// [ExtraMoveRejected], never the [Move] events.
  final bool enableBarrierHold;
  final bool enableSideStep;
  final ExtraMoveThresholds extraThresholds;

  /// Passive drift correction (see [DriftCorrector]). Off only for replay
  /// experiments.
  final bool driftCorrection;

  /// The tracking front end. Shared with the caller when one was supplied
  /// (the app keeps one per camera session, across engines).
  late final BodyTracker tracker;

  late final List<Recogniser> _detectors;
  final DriftCorrector _drift;

  QualityResult _lastQuality = const QualityResult.fail(TrackingIssue.noPerson);
  int _lastTs = 0;
  int _predicted = 0;
  BodyFeatures? _features;

  /// True while the game must hold for a tracking loss.
  bool get paused => tracker.paused;
  QualityResult get lastQuality => _lastQuality;
  TrackingState get trackingState => tracker.state;

  /// The calibration as currently positioned by drift correction: the same
  /// body and range as [calibration], at the player's present distance and
  /// spot.
  CalibrationProfile get liveCalibration => _drift.profile;

  /// The active detectors, in update order.
  List<Recogniser> get detectors => List.unmodifiable(_detectors);

  /// The latest continuous signals ([MotionSignals.none] while untracked).
  MotionSignals get signals {
    final f = _features;
    return f == null || paused
        ? MotionSignals.none
        : MotionSignals.from(f, _drift.profile);
  }

  TrackingLight get light => paused
      ? TrackingLight.red
      : (_lastQuality.usable ? TrackingLight.green : TrackingLight.amber);

  /// Scratch buffer the recognisers append to; cleared every frame so the
  /// common "nothing happened" frame allocates no event list.
  final List<MotionEvent> _out = <MotionEvent>[];

  /// Returns this frame's events. Frames without events return a shared
  /// empty, unmodifiable list; otherwise a fresh list the caller may keep.
  List<MotionEvent> process(PoseFrame raw) =>
      processTracked(tracker.process(raw));

  /// Like [process], for a frame the shared [tracker] has already seen
  /// (the app runs the tracker once per frame and hands the result to
  /// whichever engine is active).
  List<MotionEvent> processTracked(TrackedFrame t) {
    final out = _out..clear();
    _process(t, out);
    return out.isEmpty ? const <MotionEvent>[] : List.of(out);
  }

  void _process(TrackedFrame t, List<MotionEvent> out) {
    final ts = t.timestampMs;
    _lastTs = ts;
    _lastQuality = t.quality;
    _predicted = t.predicted.length;

    final wasPaused = t.previous == TrackingState.lost ||
        t.previous == TrackingState.recovering;
    if (t.state == TrackingState.lost) {
      if (!wasPaused) {
        for (final d in _detectors) {
          d.interrupt(ts, out);
        }
        _drift.reset();
        _features = null;
        out.add(TrackingPaused(ts, t.quality.issue ?? TrackingIssue.noPerson));
      }
      return;
    }
    // A bridged gap, or waiting for a steady spell after a loss: hold.
    if (!t.quality.usable || t.state == TrackingState.recovering) return;
    if (wasPaused) out.add(TrackingResumed(ts));

    final b = BodyFeatures.from(t.frame);
    _features = b;
    for (final d in _detectors) {
      d.update(b, out);
    }
    if (driftCorrection) {
      final moved = _drift.observe(b);
      if (moved != null) {
        for (final d in _detectors) {
          d.recalibrate(moved);
        }
      }
    }
  }

  /// Ends every move in progress without credit and reports a pause, for a
  /// loss the frames cannot show (the camera stalled). No-op when already
  /// paused. The matching [TrackingResumed] comes from [process] once
  /// frames return and settle.
  List<MotionEvent> stall(int timestampMs) {
    if (paused) return const <MotionEvent>[];
    final out = _out..clear();
    for (final d in _detectors) {
      d.interrupt(timestampMs, out);
    }
    _drift.reset();
    _features = null;
    tracker.markStalled();
    out.add(TrackingPaused(timestampMs, TrackingIssue.noPerson));
    return List.of(out);
  }

  EngineSnapshot get snapshot => EngineSnapshot(
        timestampMs: _lastTs,
        light: light,
        quality: _lastQuality,
        states: {for (final d in _detectors) d.id: d.state},
        measures: {for (final d in _detectors) d.id: d.measure},
        trackingState: tracker.state,
        predicted: _predicted,
        driftRebases: _drift.rebases,
      );
}
