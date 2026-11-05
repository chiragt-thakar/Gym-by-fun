import 'dart:math' as math;

import 'features.dart';
import 'landmarks.dart';

/// The player's own movement range, measured in about 30 seconds.
///
/// All values are in normalised image units at the player's play position.
/// The game stores the player's range, not a textbook range.
class CalibrationProfile {
  const CalibrationProfile({
    required this.standingLegSpan,
    required this.standingTorso,
    required this.standingHipX,
    required this.standingHipY,
    required this.standingLeanOffset,
    required this.squatDepth,
    required this.leanRangeLeft,
    required this.leanRangeRight,
    required this.reachY,
    double? sideStepRange,
  }) : sideStepRange = sideStepRange ?? standingTorso * 0.6;

  /// Hip-to-ankle vertical span when standing.
  final double standingLegSpan;

  /// Shoulder-to-hip length when standing; also the drift reference.
  final double standingTorso;
  final double standingHipX;
  final double standingHipY;
  final double standingLeanOffset;

  /// How far the leg span shrinks at the bottom of a comfortable squat.
  final double squatDepth;

  /// Magnitudes of a comfortable lean to each side.
  final double leanRangeLeft;
  final double leanRangeRight;

  /// Wrist height with both arms up.
  final double reachY;

  /// Hip shift for a comfortable side step (low-impact lane change).
  final double sideStepRange;

  /// Lower bounds (as torso fractions) so a timid calibration can't create a
  /// hair trigger that fires on breathing.
  static const minSquatDepthTorso = 0.15;
  static const minLeanRangeTorso = 0.10;

  /// Population defaults from a single standing frame. Used for the tutorial
  /// "quick start" and tests; the real calibration replaces it.
  factory CalibrationProfile.fromStanding(PoseFrame f) {
    final b = BodyFeatures.from(f);
    final t = b.torsoLength;
    return CalibrationProfile(
      standingLegSpan: b.legSpan,
      standingTorso: t,
      standingHipX: b.hipCenter.x,
      standingHipY: b.hipCenter.y,
      standingLeanOffset: b.leanOffset,
      squatDepth: t * 0.45,
      leanRangeLeft: t * 0.30,
      leanRangeRight: t * 0.30,
      reachY: b.nose.y - t * 0.6,
    );
  }

  Map<String, Object> toJson() => {
        'standingLegSpan': standingLegSpan,
        'standingTorso': standingTorso,
        'standingHipX': standingHipX,
        'standingHipY': standingHipY,
        'standingLeanOffset': standingLeanOffset,
        'squatDepth': squatDepth,
        'leanRangeLeft': leanRangeLeft,
        'leanRangeRight': leanRangeRight,
        'reachY': reachY,
        'sideStepRange': sideStepRange,
      };

  factory CalibrationProfile.fromJson(Map<String, dynamic> j) {
    double d(String k) => (j[k] as num).toDouble();
    return CalibrationProfile(
      standingLegSpan: d('standingLegSpan'),
      standingTorso: d('standingTorso'),
      standingHipX: d('standingHipX'),
      standingHipY: d('standingHipY'),
      standingLeanOffset: d('standingLeanOffset'),
      squatDepth: d('squatDepth'),
      leanRangeLeft: d('leanRangeLeft'),
      leanRangeRight: d('leanRangeRight'),
      reachY: d('reachY'),
      sideStepRange: (j['sideStepRange'] as num?)?.toDouble(),
    );
  }

  /// True if a standing frame no longer matches the baseline — usually the
  /// phone moved or the player changed spot. The app asks for a quick
  /// re-calibration.
  bool hasDrifted(BodyFeatures standing, {double tolerance = 0.15}) {
    final scale = (standing.torsoLength - standingTorso).abs() / standingTorso;
    final shift = (standing.hipCenter.x - standingHipX).abs() / standingTorso;
    final vshift = (standing.hipCenter.y - standingHipY).abs() / standingTorso;
    return scale > tolerance || shift > 1.0 || vshift > 0.5;
  }
}

/// The steps of the guided calibration, in order.
enum CalibrationStep { neutral, armsUp, squats, leanLeft, leanRight, done }

/// Guided calibration as a state machine. Feed it smoothed, quality-gated
/// frames; it advances through the steps on its own and exposes progress for
/// the UI.
class Calibrator {
  Calibrator({
    this.stillMs = 2000,
    this.holdMs = 500,
    this.squatsRequired = 2,
    this.stillTolerance = 0.08,
  });

  final int stillMs;
  final int holdMs;
  final int squatsRequired;

  /// Max hip-centre wander (torso fractions) that still counts as "still".
  final double stillTolerance;

  CalibrationStep _step = CalibrationStep.neutral;
  CalibrationStep get step => _step;

  final List<BodyFeatures> _neutral = [];
  double? _legSpan, _torso, _hipX, _hipY, _leanOffset, _reach;
  double _minLegSpan = double.infinity;
  int _squats = 0;
  bool _inSquat = false;
  double _leanLeft = 0, _leanRight = 0;
  int? _holdStart;

  int get squatsDone => _squats;

  /// 0..1 progress within the current step, for the UI ring.
  double progress = 0;

  void add(PoseFrame frame) {
    if (!frame.hasPerson || _step == CalibrationStep.done) return;
    final b = BodyFeatures.from(frame);
    switch (_step) {
      case CalibrationStep.neutral:
        _neutralFrame(b);
      case CalibrationStep.armsUp:
        _armsUpFrame(b);
      case CalibrationStep.squats:
        _squatFrame(b);
      case CalibrationStep.leanLeft:
        _leanFrame(b, left: true);
      case CalibrationStep.leanRight:
        _leanFrame(b, left: false);
      case CalibrationStep.done:
        break;
    }
  }

  void _neutralFrame(BodyFeatures b) {
    // Compare against the window's running mean, not one noisy frame.
    if (_neutral.isNotEmpty) {
      final n = _neutral.length;
      final mx = _neutral.fold(0.0, (a, x) => a + x.hipCenter.x) / n;
      final my = _neutral.fold(0.0, (a, x) => a + x.hipCenter.y) / n;
      final wander = (b.hipCenter.x - mx).abs() + (b.hipCenter.y - my).abs();
      if (wander > stillTolerance * b.torsoLength) _neutral.clear();
    }
    _neutral.add(b);
    final span = _neutral.last.timestampMs - _neutral.first.timestampMs;
    progress = (span / stillMs).clamp(0, 1).toDouble();
    if (span >= stillMs) {
      double avg(double Function(BodyFeatures) f) =>
          _neutral.map(f).reduce((a, c) => a + c) / _neutral.length;
      _legSpan = avg((x) => x.legSpan);
      _torso = avg((x) => x.torsoLength);
      _hipX = avg((x) => x.hipCenter.x);
      _hipY = avg((x) => x.hipCenter.y);
      _leanOffset = avg((x) => x.leanOffset);
      _next(CalibrationStep.armsUp);
    }
  }

  void _armsUpFrame(BodyFeatures b) {
    if (b.leftWristAboveNose && b.rightWristAboveNose) {
      _holdStart ??= b.timestampMs;
      final y = math.min(b.leftWrist.y, b.rightWrist.y);
      _reach = _reach == null ? y : math.min(_reach!, y);
      final held = b.timestampMs - _holdStart!;
      progress = (held / holdMs).clamp(0, 1).toDouble();
      if (held >= holdMs) _next(CalibrationStep.squats);
    } else {
      _holdStart = null;
      progress = 0;
    }
  }

  void _squatFrame(BodyFeatures b) {
    final drop = _legSpan! - b.legSpan;
    final minDrop = CalibrationProfile.minSquatDepthTorso * _torso!;
    if (!_inSquat && drop > minDrop) _inSquat = true;
    if (_inSquat) _minLegSpan = math.min(_minLegSpan, b.legSpan);
    if (_inSquat && drop < minDrop * 0.3) {
      _inSquat = false;
      _squats++;
    }
    progress = _squats / squatsRequired;
    if (_squats >= squatsRequired) _next(CalibrationStep.leanLeft);
  }

  void _leanFrame(BodyFeatures b, {required bool left}) {
    final shift = b.leanOffset - _leanOffset!;
    final minLean = CalibrationProfile.minLeanRangeTorso * _torso!;
    final active = left ? shift < -minLean : shift > minLean;
    if (active) {
      _holdStart ??= b.timestampMs;
      if (left) {
        _leanLeft = math.max(_leanLeft, -shift);
      } else {
        _leanRight = math.max(_leanRight, shift);
      }
      final held = b.timestampMs - _holdStart!;
      progress = (held / holdMs).clamp(0, 1).toDouble();
      if (held >= holdMs) {
        _next(left ? CalibrationStep.leanRight : CalibrationStep.done);
      }
    } else {
      _holdStart = null;
      progress = 0;
    }
  }

  void _next(CalibrationStep s) {
    _step = s;
    _holdStart = null;
    progress = 0;
  }

  /// The measured profile, once [step] is [CalibrationStep.done].
  CalibrationProfile build() {
    if (_step != CalibrationStep.done) {
      throw StateError('Calibration not finished (at $_step)');
    }
    final t = _torso!;
    return CalibrationProfile(
      standingLegSpan: _legSpan!,
      standingTorso: t,
      standingHipX: _hipX!,
      standingHipY: _hipY!,
      standingLeanOffset: _leanOffset!,
      squatDepth: math.max(
          _legSpan! - _minLegSpan, CalibrationProfile.minSquatDepthTorso * t),
      leanRangeLeft:
          math.max(_leanLeft, CalibrationProfile.minLeanRangeTorso * t),
      leanRangeRight:
          math.max(_leanRight, CalibrationProfile.minLeanRangeTorso * t),
      reachY: _reach!,
    );
  }
}
