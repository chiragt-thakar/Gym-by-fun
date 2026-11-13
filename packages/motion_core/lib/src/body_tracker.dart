import 'landmarks.dart';
import 'quality_gate.dart';
import 'stabiliser.dart';
import 'subject_lock.dart';
import 'tracking_state.dart';

/// Everything the tracker knows about one camera frame. This is what games,
/// calibration and overlays consume; nothing downstream looks at raw
/// landmarks again.
class TrackedFrame {
  const TrackedFrame({
    required this.raw,
    required this.frame,
    required this.quality,
    required this.state,
    required this.previous,
    this.predicted = const <int>[],
    this.coasted = false,
  });

  /// The primary player's landmarks as measured (after the subject lock
  /// and left/right canonicalisation), unfiltered. Person-less when the
  /// player is not in view.
  final PoseFrame raw;

  /// Stabilised landmarks: filtered, confidence-gated, short gaps
  /// predicted. Use this for drawing and for body geometry.
  final PoseFrame frame;

  /// This frame's own quality (before any debouncing).
  final QualityResult quality;

  /// Debounced tracking state after this frame, and before it.
  final TrackingState state;
  final TrackingState previous;

  /// Landmark indices in [frame] that were predicted rather than measured.
  final List<int> predicted;

  /// True when the whole body in [frame] is a prediction (the measurement
  /// was unusable). Never drives detectors.
  final bool coasted;

  int get timestampMs => raw.timestampMs;

  /// True when this frame may drive gameplay: it was measured, the torso is
  /// tracked, and the game is not holding for a tracking loss.
  bool get playable =>
      quality.usable &&
      (state == TrackingState.tracking || state == TrackingState.degraded);

  /// True when the game must hold.
  bool get paused =>
      state == TrackingState.lost || state == TrackingState.recovering;
}

class BodyTrackerConfig {
  const BodyTrackerConfig({
    this.gate = const QualityGate(),
    this.stabiliser = const StabiliserConfig(),
    this.state = const TrackingStateConfig(),
    this.lock = const SubjectLockConfig(),
    this.smooth = true,
    this.canonicaliseFacing = true,
  });

  final QualityGate gate;
  final StabiliserConfig stabiliser;
  final TrackingStateConfig state;
  final SubjectLockConfig lock;

  /// False passes landmarks through unfiltered (replay experiments only).
  final bool smooth;

  /// See `FacingCanonicaliser`.
  final bool canonicaliseFacing;
}

/// The game-agnostic tracking front end:
///
///   raw frame → SubjectLock → FacingCanonicaliser → QualityGate
///             → LandmarkStabiliser → TrackingStateMachine → [TrackedFrame]
///
/// It knows nothing about calibration, moves or games. Feed it every frame
/// from the pose source (latest frame only) and build anything on the
/// [TrackedFrame]s it returns.
class BodyTracker {
  BodyTracker([this.config = const BodyTrackerConfig()])
      : _lock = SubjectLock(config.lock),
        _stabiliser = LandmarkStabiliser(config.stabiliser),
        _machine = TrackingStateMachine(config.state);

  final BodyTrackerConfig config;
  final SubjectLock _lock;
  final FacingCanonicaliser _facing = FacingCanonicaliser();
  final LandmarkStabiliser _stabiliser;
  final TrackingStateMachine _machine;

  TrackedFrame? _last;

  TrackingState get state => _machine.state;
  bool get paused => _machine.paused;

  /// The most recent result, or null before the first frame.
  TrackedFrame? get last => _last;

  /// Diagnostics: bodies ignored because they were not the player, and
  /// whether left/right indices are being exchanged.
  int get strangersRejected => _lock.rejected;
  bool get facingSwapped => _facing.swapping;

  TrackedFrame process(PoseFrame input) {
    var raw = _lock.select(input);
    if (config.canonicaliseFacing) raw = _facing.apply(raw);
    final q = config.gate.check(raw);
    final previous = _machine.state;

    PoseFrame frame;
    var coasted = false;
    var predicted = const <int>[];
    if (q.usable) {
      if (config.smooth) {
        frame = _stabiliser.update(raw);
        predicted = _stabiliser.predicted;
      } else {
        frame = raw;
      }
    } else {
      final p = config.smooth ? _stabiliser.predict(raw) : null;
      if (p != null) {
        frame = p;
        coasted = true;
        predicted = _stabiliser.predicted;
      } else {
        frame = raw;
      }
    }

    final state = _machine.update(q.level, raw.timestampMs);
    if (state == TrackingState.lost && previous != TrackingState.lost) {
      // Start clean when the player comes back: stale velocities must not
      // leak across a loss.
      _stabiliser.reset();
    }
    return _last = TrackedFrame(
      raw: raw,
      frame: frame,
      quality: q,
      state: state,
      previous: previous,
      predicted: predicted,
      coasted: coasted,
    );
  }

  /// Call when frames stop arriving (camera stalled): the state becomes
  /// [TrackingState.lost] without waiting for a frame that will not come.
  void markStalled() {
    _machine.forceLost();
    _stabiliser.reset();
  }

  /// Forgets the player and all filter state (new session, new camera).
  void reset() {
    _lock.reset();
    _facing.reset();
    _stabiliser.reset();
    _machine.reset();
    _last = null;
  }
}
