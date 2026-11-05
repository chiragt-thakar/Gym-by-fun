import 'calibration.dart';
import 'events.dart';
import 'features.dart';

/// Recogniser thresholds. Starting values from the motion spec; tune only
/// with recorded data, and only while the replay tests still pass
/// (see docs/game-design.md).
class MotionThresholds {
  const MotionThresholds({
    this.squatStart = 0.60,
    this.squatEnd = 0.25,
    this.squatShallowFloor = 0.35,
    this.leanStart = 0.60,
    this.leanRearm = 0.25,
    this.leanCooldownMs = 300,
    this.raiseHoldMs = 150,
    this.allowOneArm = false,
    this.sideStepLanes = false,
    this.confirmFrames = 2,
    this.heldIntervalMs = 100,
    this.minLegVisibility = 0.5,
  });

  /// Low-impact profile: a half squat counts and one arm is enough.
  const MotionThresholds.lowImpact()
      : this(
            squatStart: 0.45,
            squatEnd: 0.20,
            squatShallowFloor: 0.28,
            allowOneArm: true);

  /// Hip drop (fraction of calibrated depth) that starts a squat.
  final double squatStart;

  /// Hip drop below which the squat has ended.
  final double squatEnd;

  /// A dip that peaks between this and [squatStart] is reported as too shallow.
  final double squatShallowFloor;

  /// Lean fraction that starts a lane change, and the re-arm level.
  final double leanStart;
  final double leanRearm;
  final int leanCooldownMs;

  /// How long wrists must stay above the nose line.
  final int raiseHoldMs;
  final bool allowOneArm;

  /// Use a side step (hip shift) instead of a torso lean to change lanes.
  final bool sideStepLanes;

  /// Consecutive frames past a start threshold before a move starts.
  final int confirmFrames;

  /// How often MoveHeld is emitted while a move is held.
  final int heldIntervalMs;

  /// Squat guard: hips and knees must be at least this visible.
  final double minLegVisibility;

  Map<String, Object> toJson() => {
        'squatStart': squatStart,
        'squatEnd': squatEnd,
        'leanStart': leanStart,
        'leanRearm': leanRearm,
        'leanCooldownMs': leanCooldownMs,
        'raiseHoldMs': raiseHoldMs,
        'allowOneArm': allowOneArm,
        'sideStepLanes': sideStepLanes,
        'confirmFrames': confirmFrames,
      };
}

/// Common interface so the engine and the debug screen can treat every
/// recogniser the same way.
abstract class Recogniser {
  /// Human-readable current state for the debug screen.
  String get state;

  /// The live measure (fraction of calibrated range) for the debug screen.
  double get measure;

  void update(BodyFeatures b, List<MotionEvent> out);

  /// Called when tracking pauses: end anything in progress without credit.
  void interrupt(int timestampMs, List<MotionEvent> out);
}

enum _SquatState { up, down }

/// Squat: hips drop past [MotionThresholds.squatStart] of the calibrated
/// depth; the duck starts on the way down and holds while low; ends back
/// above [MotionThresholds.squatEnd]. A forward bend without hip drop does
/// not move the measure, so it never counts.
class SquatRecogniser implements Recogniser {
  SquatRecogniser(this.cal, this.t);
  final CalibrationProfile cal;
  final MotionThresholds t;

  _SquatState _s = _SquatState.up;
  int _confirm = 0;
  int _startMs = 0, _lastHeldMs = 0;
  double _peak = 0;
  bool _rejectedThisDip = false;
  double _measure = 0;

  @override
  String get state => _s.name;
  @override
  double get measure => _measure;

  @override
  void update(BodyFeatures b, List<MotionEvent> out) {
    final f = b.squatFraction(cal);
    _measure = f;
    final ts = b.timestampMs;
    switch (_s) {
      case _SquatState.up:
        if (f >= t.squatStart) {
          if (b.minLegVisibility < t.minLegVisibility) {
            _confirm = 0;
            if (!_rejectedThisDip) {
              out.add(MoveRejected(Move.squat, ts, RejectReason.notVisible));
              _rejectedThisDip = true;
            }
            return;
          }
          if (++_confirm >= t.confirmFrames) {
            _s = _SquatState.down;
            _startMs = _lastHeldMs = ts;
            _confirm = 0;
            out.add(MoveStarted(Move.squat, ts,
                confidence: b.minLegVisibility.clamp(0, 1).toDouble()));
          }
        } else {
          _confirm = 0;
          if (f > _peak) _peak = f;
          if (f < t.squatEnd) {
            if (_peak >= t.squatShallowFloor && !_rejectedThisDip) {
              out.add(MoveRejected(Move.squat, ts, RejectReason.tooShallow));
            }
            _peak = 0;
            _rejectedThisDip = false;
          }
        }
      case _SquatState.down:
        if (f < t.squatEnd) {
          _s = _SquatState.up;
          _peak = 0;
          _rejectedThisDip = false;
          out
            ..add(MoveEnded(Move.squat, ts))
            ..add(RepCompleted(Move.squat, ts, ts - _startMs));
        } else if (ts - _lastHeldMs >= t.heldIntervalMs) {
          _lastHeldMs = ts;
          out.add(MoveHeld(Move.squat, ts, ts - _startMs));
        }
    }
  }

  @override
  void interrupt(int timestampMs, List<MotionEvent> out) {
    if (_s == _SquatState.down) {
      out.add(MoveEnded(Move.squat, timestampMs, completed: false));
    }
    _s = _SquatState.up;
    _confirm = 0;
    _peak = 0;
    _rejectedThisDip = false;
  }
}

enum _LeanState { centre, left, right }

/// Lean: shoulder-centre shift past hip-centre beyond
/// [MotionThresholds.leanStart] of the calibrated range; one lane per lean;
/// re-arms below [MotionThresholds.leanRearm]; cooldown between starts.
class LeanRecogniser implements Recogniser {
  LeanRecogniser(this.cal, this.t);
  final CalibrationProfile cal;
  final MotionThresholds t;

  _LeanState _s = _LeanState.centre;
  int _confirm = 0;
  int? _lastStartMs;
  int _startMs = 0, _lastHeldMs = 0;
  bool _rejected = false;
  double _measure = 0;

  @override
  String get state => _s.name;
  @override
  double get measure => _measure;

  @override
  void update(BodyFeatures b, List<MotionEvent> out) {
    final f = t.sideStepLanes ? b.sideStepFraction(cal) : b.leanFraction(cal);
    _measure = f;
    final ts = b.timestampMs;
    switch (_s) {
      case _LeanState.centre:
        final dir = f <= -t.leanStart
            ? _LeanState.left
            : f >= t.leanStart
                ? _LeanState.right
                : null;
        if (dir == null) {
          _confirm = 0;
          if (f.abs() < t.leanRearm) _rejected = false;
          return;
        }
        final move = dir == _LeanState.left ? Move.leanLeft : Move.leanRight;
        final last = _lastStartMs;
        if (last != null && ts - last < t.leanCooldownMs) {
          if (!_rejected) {
            out.add(MoveRejected(move, ts, RejectReason.tooEarly));
            _rejected = true;
          }
          _confirm = 0;
          return;
        }
        if (++_confirm >= t.confirmFrames) {
          _s = dir;
          _confirm = 0;
          _lastStartMs = _startMs = _lastHeldMs = ts;
          out.add(MoveStarted(move, ts));
        }
      case _LeanState.left:
      case _LeanState.right:
        final move = _s == _LeanState.left ? Move.leanLeft : Move.leanRight;
        if (f.abs() < t.leanRearm) {
          _s = _LeanState.centre;
          _rejected = false;
          out
            ..add(MoveEnded(move, ts))
            ..add(RepCompleted(move, ts, ts - _startMs));
        } else if (ts - _lastHeldMs >= t.heldIntervalMs) {
          _lastHeldMs = ts;
          out.add(MoveHeld(move, ts, ts - _startMs));
        }
    }
  }

  @override
  void interrupt(int timestampMs, List<MotionEvent> out) {
    if (_s != _LeanState.centre) {
      out.add(MoveEnded(
          _s == _LeanState.left ? Move.leanLeft : Move.leanRight, timestampMs,
          completed: false));
    }
    _s = _LeanState.centre;
    _confirm = 0;
    _rejected = false;
  }
}

enum _ArmsState { armed, rising, up, lowering }

/// Raise arms: wrists above the nose line for [MotionThresholds.raiseHoldMs];
/// arms must drop below the shoulders before the next activation.
class RaiseArmsRecogniser implements Recogniser {
  RaiseArmsRecogniser(this.t);
  final MotionThresholds t;

  _ArmsState _s = _ArmsState.armed;
  int _riseMs = 0, _startMs = 0, _lastHeldMs = 0;
  double _measure = 0;

  @override
  String get state => _s.name;
  @override
  double get measure => _measure;

  @override
  void update(BodyFeatures b, List<MotionEvent> out) {
    final above = t.allowOneArm
        ? (b.leftWristAboveNose || b.rightWristAboveNose)
        : (b.leftWristAboveNose && b.rightWristAboveNose);
    final below = t.allowOneArm
        ? (b.leftWristBelowShoulders && b.rightWristBelowShoulders)
        : (b.leftWristBelowShoulders || b.rightWristBelowShoulders);
    // Measure: how far the higher wrist is above the nose, in torso units.
    final hi = b.leftWrist.y < b.rightWrist.y ? b.leftWrist.y : b.rightWrist.y;
    _measure = (b.nose.y - hi) / b.torsoLength;
    final ts = b.timestampMs;
    switch (_s) {
      case _ArmsState.armed:
        if (above) {
          _s = _ArmsState.rising;
          _riseMs = ts;
        }
      case _ArmsState.rising:
        if (!above) {
          // Dipped under the nose line before the hold finished: it never
          // activated, so it is still armed and must start the hold again.
          _s = _ArmsState.armed;
        } else if (ts - _riseMs >= t.raiseHoldMs) {
          _s = _ArmsState.up;
          _startMs = _lastHeldMs = ts;
          out.add(MoveStarted(Move.raiseArms, ts));
        }
      case _ArmsState.up:
        if (below) {
          _s = _ArmsState.armed;
          out
            ..add(MoveEnded(Move.raiseArms, ts))
            ..add(RepCompleted(Move.raiseArms, ts, ts - _startMs));
        } else if (ts - _lastHeldMs >= t.heldIntervalMs) {
          _lastHeldMs = ts;
          out.add(MoveHeld(Move.raiseArms, ts, ts - _startMs));
        }
      case _ArmsState.lowering:
        if (below) _s = _ArmsState.armed;
    }
  }

  @override
  void interrupt(int timestampMs, List<MotionEvent> out) {
    if (_s == _ArmsState.up) {
      out.add(MoveEnded(Move.raiseArms, timestampMs, completed: false));
      // Arms must still come down before the next activation.
      _s = _ArmsState.lowering;
    } else if (_s == _ArmsState.rising) {
      _s = _ArmsState.lowering;
    }
  }
}
