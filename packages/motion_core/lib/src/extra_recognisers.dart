import 'calibration.dart';
import 'events.dart';
import 'features.dart';
import 'landmarks.dart';
import 'recognisers.dart';

/// Thresholds for the opt-in roadmap moves (docs/stages-roadmap.md §3.1,
/// §3.2). Kept apart from [MotionThresholds] so existing tuning and its JSON
/// are unchanged. Tune only with recorded data (docs/game-design.md).
class ExtraMoveThresholds {
  const ExtraMoveThresholds({
    this.barrierBandTorso = 0.6,
    this.barrierSpanMargin = 0.10,
    this.barrierReachMax = 0.55,
    this.armLengthTorso = 1.05,
    this.guardNoseTorso = 0.4,
    this.barrierGraceMs = 200,
    this.barrierOneHand = false,
    this.stepStart = 0.60,
    this.stepEnd = 0.25,
    this.stepMaxLean = 0.40,
    this.stepFeetRatio = 0.5,
    this.stepCooldownMs = 400,
    this.minVisibility = 0.5,
  });

  /// Low-impact profile: one hand is a barrier, a smaller step counts.
  const ExtraMoveThresholds.lowImpact()
      : this(barrierOneHand: true, stepStart: 0.45, stepEnd: 0.20);

  /// Wrists between the shoulder line and this many torsos below it.
  final double barrierBandTorso;

  /// Wrists' x inside the shoulder span widened by this fraction each side.
  final double barrierSpanMargin;

  /// Wrist-to-shoulder distance at most this fraction of arm length
  /// (2-D foreshortening of an arm pushed towards the camera).
  final double barrierReachMax;

  /// Arm length as a multiple of the calibrated standing torso, until
  /// calibration records it ("push palms forward, hold 1 s").
  final double armLengthTorso;

  /// A wrist this close to the nose (torso units) is a guard, not a barrier.
  final double guardNoseTorso;

  /// Conditions may be false this long before the barrier ends (jitter).
  final int barrierGraceMs;
  final bool barrierOneHand;

  /// Side-step fraction that starts a step, and the re-arm level.
  final double stepStart;
  final double stepEnd;

  /// A step only counts while the lean fraction stays below this.
  final double stepMaxLean;

  /// The ankle centre must shift at least this fraction of the hip shift.
  final double stepFeetRatio;
  final int stepCooldownMs;

  /// Landmarks a recogniser reads must be at least this visible.
  final double minVisibility;
}

enum _BarrierState { idle, held }

/// Barrier hold (§3.2): both wrists at chest height, inside the shoulder
/// span, arms pushed forward (short 2-D reach, elbows below the wrists and
/// above the hips) and not near the face (that is a guard). Starts after
/// [MotionThresholds.confirmFrames] frames; ends after the conditions have
/// been false for [ExtraMoveThresholds.barrierGraceMs].
class BarrierHoldRecogniser implements Recogniser {
  BarrierHoldRecogniser(this.cal, this.t, this.x);
  CalibrationProfile cal;
  final MotionThresholds t;
  final ExtraMoveThresholds x;

  @override
  String get id => 'barrierHold';
  @override
  void recalibrate(CalibrationProfile c) => cal = c;

  _BarrierState _s = _BarrierState.idle;
  int _confirm = 0;
  int _startMs = 0, _lastHeldMs = 0, _lastTrueMs = 0;
  bool _rejected = false;
  double _measure = 0;

  @override
  String get state => _s.name;

  /// 1 when every condition holds for the required hands, else 0.
  @override
  double get measure => _measure;

  bool _hand(BodyFeatures b, Landmark wrist, Landmark elbow, Landmark sh,
      double lo, double hi, double armLen) {
    final top = b.shoulderCenter.y;
    final inBand =
        wrist.y >= top && wrist.y <= top + x.barrierBandTorso * b.torsoLength;
    final inSpan = wrist.x >= lo && wrist.x <= hi;
    final forward = landmarkDistance(wrist, sh) <= x.barrierReachMax * armLen;
    final elbowBelow = elbow.y >= wrist.y && elbow.y <= b.hipCenter.y;
    final notGuard =
        landmarkDistance(wrist, b.nose) >= x.guardNoseTorso * b.torsoLength;
    return inBand && inSpan && forward && elbowBelow && notGuard;
  }

  bool _visible(Landmark w, Landmark e, Landmark s) =>
      w.visibility >= x.minVisibility &&
      e.visibility >= x.minVisibility &&
      s.visibility >= x.minVisibility;

  @override
  void update(BodyFeatures b, List<MotionEvent> out) {
    final ls = b.leftShoulder, rs = b.rightShoulder;
    final minX = ls.x < rs.x ? ls.x : rs.x;
    final maxX = ls.x < rs.x ? rs.x : ls.x;
    final margin = (maxX - minX) * x.barrierSpanMargin;
    final armLen = x.armLengthTorso * cal.standingTorso;
    final l = _hand(
        b, b.leftWrist, b.leftElbow, ls, minX - margin, maxX + margin, armLen);
    final r = _hand(b, b.rightWrist, b.rightElbow, rs, minX - margin,
        maxX + margin, armLen);
    final lv = _visible(b.leftWrist, b.leftElbow, ls);
    final rv = _visible(b.rightWrist, b.rightElbow, rs);
    final shape = x.barrierOneHand ? (l || r) : (l && r);
    final visible = x.barrierOneHand ? ((l && lv) || (r && rv)) : (lv && rv);
    final ok = shape && visible;
    _measure = ok ? 1 : 0;
    final ts = b.timestampMs;
    switch (_s) {
      case _BarrierState.idle:
        if (!shape) {
          _confirm = 0;
          _rejected = false;
          return;
        }
        if (!visible) {
          _confirm = 0;
          if (!_rejected) {
            out.add(ExtraMoveRejected(
                ExtraMove.barrierHold, ts, RejectReason.notVisible));
            _rejected = true;
          }
          return;
        }
        if (++_confirm >= t.confirmFrames) {
          _s = _BarrierState.held;
          _confirm = 0;
          _startMs = _lastHeldMs = _lastTrueMs = ts;
          out.add(ExtraMoveStarted(ExtraMove.barrierHold, ts));
        }
      case _BarrierState.held:
        if (ok) {
          _lastTrueMs = ts;
        } else if (ts - _lastTrueMs >= x.barrierGraceMs) {
          _s = _BarrierState.idle;
          _rejected = false;
          out.add(ExtraMoveEnded(
              ExtraMove.barrierHold, ts, _lastTrueMs - _startMs));
          return;
        }
        if (ts - _lastHeldMs >= t.heldIntervalMs) {
          _lastHeldMs = ts;
          out.add(ExtraMoveHeld(ExtraMove.barrierHold, ts, ts - _startMs));
        }
    }
  }

  @override
  void interrupt(int timestampMs, List<MotionEvent> out) {
    if (_s == _BarrierState.held) {
      out.add(ExtraMoveEnded(
          ExtraMove.barrierHold, timestampMs, _lastTrueMs - _startMs,
          completed: false));
    }
    _s = _BarrierState.idle;
    _confirm = 0;
    _rejected = false;
  }
}

enum _StepState { centre, left, right }

/// Side step (§3.1): hip centre shifts past [ExtraMoveThresholds.stepStart]
/// of the calibrated step range while the torso lean stays small and the
/// feet move with the hips. Re-arms below [ExtraMoveThresholds.stepEnd];
/// cooldown between starts. A hip sway with planted feet is rejected as
/// too shallow.
///
/// Feet check: calibration has no standing ankle x yet, so the ankle centre
/// is compared against the standing hip x (feet sit under the hips when
/// standing square to the camera).
class SideStepRecogniser implements Recogniser {
  SideStepRecogniser(this.cal, this.t, this.x);
  CalibrationProfile cal;
  final MotionThresholds t;
  final ExtraMoveThresholds x;

  @override
  String get id => 'sideStep';
  @override
  void recalibrate(CalibrationProfile c) => cal = c;

  _StepState _s = _StepState.centre;
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
    final f = b.sideStepFraction(cal);
    _measure = f;
    final ts = b.timestampMs;
    switch (_s) {
      case _StepState.centre:
        final dir = f <= -x.stepStart
            ? _StepState.left
            : f >= x.stepStart
                ? _StepState.right
                : null;
        if (dir == null) {
          _confirm = 0;
          if (f.abs() < x.stepEnd) _rejected = false;
          return;
        }
        final move =
            dir == _StepState.left ? ExtraMove.stepLeft : ExtraMove.stepRight;
        void reject(RejectReason r) {
          _confirm = 0;
          if (!_rejected) {
            out.add(ExtraMoveRejected(move, ts, r));
            _rejected = true;
          }
        }

        if (b.hipVisibility < x.minVisibility ||
            b.ankleCenter.visibility < x.minVisibility) {
          return reject(RejectReason.notVisible);
        }
        final last = _lastStartMs;
        if (last != null && ts - last < x.stepCooldownMs) {
          return reject(RejectReason.tooEarly);
        }
        if (b.leanFraction(cal).abs() >= x.stepMaxLean) {
          // A lean with a hip shift is a lean, not a step: no event.
          _confirm = 0;
          return;
        }
        final hipShift = b.hipCenter.x - cal.standingHipX;
        final feetShift = b.ankleCenter.x - cal.standingHipX;
        if (feetShift * hipShift <= 0 ||
            feetShift.abs() < x.stepFeetRatio * hipShift.abs()) {
          return reject(RejectReason.tooShallow);
        }
        if (++_confirm >= t.confirmFrames) {
          _s = dir;
          _confirm = 0;
          _lastStartMs = _startMs = _lastHeldMs = ts;
          out.add(ExtraMoveStarted(move, ts));
        }
      case _StepState.left:
      case _StepState.right:
        final move =
            _s == _StepState.left ? ExtraMove.stepLeft : ExtraMove.stepRight;
        if (f.abs() < x.stepEnd) {
          _s = _StepState.centre;
          _rejected = false;
          out.add(ExtraMoveEnded(move, ts, ts - _startMs));
        } else if (ts - _lastHeldMs >= t.heldIntervalMs) {
          _lastHeldMs = ts;
          out.add(ExtraMoveHeld(move, ts, ts - _startMs));
        }
    }
  }

  @override
  void interrupt(int timestampMs, List<MotionEvent> out) {
    if (_s != _StepState.centre) {
      out.add(ExtraMoveEnded(
          _s == _StepState.left ? ExtraMove.stepLeft : ExtraMove.stepRight,
          timestampMs,
          timestampMs - _startMs,
          completed: false));
    }
    _s = _StepState.centre;
    _confirm = 0;
    _rejected = false;
  }
}
