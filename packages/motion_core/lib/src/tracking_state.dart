import 'quality_gate.dart';

/// Where the tracker is, for the game and for player feedback.
enum TrackingState {
  /// The whole body is tracked cleanly.
  tracking,

  /// Play continues on reduced information: a short gap is being bridged,
  /// or part of the body (feet, a knee) is hidden or out of frame.
  degraded,

  /// The player cannot be tracked. The game holds; nothing is lost.
  lost,

  /// The player is back in view; play resumes after a short steady spell.
  recovering,
}

class TrackingStateConfig {
  const TrackingStateConfig({
    this.pauseAfterMs = 250,
    this.resumeAfterMs = 300,
    this.degradeAfterMs = 400,
    this.settleMs = 300,
  });

  /// Unusable frames for this long ⇒ [TrackingState.lost]. Shorter gaps are
  /// bridged.
  final int pauseAfterMs;

  /// Usable frames for this long after a loss ⇒ play resumes.
  final int resumeAfterMs;

  /// Usable-but-imperfect frames for this long ⇒ [TrackingState.degraded].
  final int degradeAfterMs;

  /// Clean frames for this long ⇒ back to [TrackingState.tracking].
  final int settleMs;
}

/// Turns per-frame quality into a debounced tracking state.
///
/// Every transition has its own dwell time, so a single noisy frame can
/// never pause the game, flash a warning or clear one. Time is the frame
/// clock, which makes the machine deterministic under replay.
///
/// ```
///            bad ≥ pauseAfter
///   tracking ───────────────▶ lost ◀──── bad ────┐
///     ▲   │ imperfect ≥ degradeAfter   │ usable  │
///     │   ▼     (or any bad frame)     ▼         │
///     └ degraded ◀── usable ≥ resumeAfter ── recovering
///   clean ≥ settle
/// ```
class TrackingStateMachine {
  TrackingStateMachine([this.config = const TrackingStateConfig()]);

  final TrackingStateConfig config;

  /// Optimistic until proven otherwise, so the first good frame plays.
  TrackingState _state = TrackingState.tracking;
  int? _badSince;
  int? _usableSince;
  int? _goodSince;
  int? _softSince;

  TrackingState get state => _state;

  /// True while the game must hold ([TrackingState.lost] or
  /// [TrackingState.recovering]).
  bool get paused =>
      _state == TrackingState.lost || _state == TrackingState.recovering;

  /// Feeds one frame's quality; returns the (possibly new) state.
  TrackingState update(FrameQuality quality, int timestampMs) {
    final ts = timestampMs;
    if (quality == FrameQuality.bad) {
      _usableSince = null;
      _goodSince = null;
      _softSince = null;
      final since = _badSince ??= ts;
      if (_state == TrackingState.recovering) {
        _state = TrackingState.lost;
      } else if (_state != TrackingState.lost) {
        _state = ts - since >= config.pauseAfterMs
            ? TrackingState.lost
            : TrackingState.degraded;
      }
      return _state;
    }

    _badSince = null;
    final usableSince = _usableSince ??= ts;
    final good = quality == FrameQuality.good;
    if (good) {
      _goodSince ??= ts;
      _softSince = null;
    } else {
      _softSince ??= ts;
      _goodSince = null;
    }
    if (_state == TrackingState.lost) _state = TrackingState.recovering;
    if (_state == TrackingState.recovering) {
      if (ts - usableSince >= config.resumeAfterMs) {
        _state = good ? TrackingState.tracking : TrackingState.degraded;
      }
    } else if (good) {
      if (_state == TrackingState.degraded &&
          ts - _goodSince! >= config.settleMs) {
        _state = TrackingState.tracking;
      }
    } else if (_state == TrackingState.tracking &&
        ts - _softSince! >= config.degradeAfterMs) {
      _state = TrackingState.degraded;
    }
    return _state;
  }

  /// Forces [TrackingState.lost] (no frames are arriving at all).
  void forceLost() {
    _state = TrackingState.lost;
    _badSince = null;
    _usableSince = null;
    _goodSince = null;
    _softSince = null;
  }

  void reset() {
    _state = TrackingState.tracking;
    _badSince = null;
    _usableSince = null;
    _goodSince = null;
    _softSince = null;
  }
}
