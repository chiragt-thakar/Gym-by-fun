import 'calibration.dart';
import 'features.dart';
import 'robust.dart';

class DriftConfig {
  const DriftConfig({
    this.dwellMs = 1500,
    this.shiftDwellMs = 2500,
    this.scaleDeadband = 0.06,
    this.shiftDeadbandTorso = 1.0,
    this.vshiftDeadbandTorso = 0.5,
    this.postureTolerance = 0.10,
    this.leanTolerance = 0.25,
    this.stillTolerance = 0.08,
    this.minScale = 0.4,
    this.maxScale = 2.5,
  });

  /// The player must stand neutral and still this long before a change of
  /// distance is accepted.
  final int dwellMs;

  /// … and this long before a change of spot is accepted (longer: a side
  /// step that is held must stay a side step).
  final int shiftDwellMs;

  /// Torso-length change (fraction) below which nothing is corrected.
  /// Normal play sits inside this band, so the calibrated numbers are used
  /// untouched.
  final double scaleDeadband;

  /// Sideways / vertical hip shift (torso lengths) below which the spot is
  /// not re-centred.
  final double shiftDeadbandTorso;
  final double vshiftDeadbandTorso;

  /// How far the leg-to-torso ratio may differ from the calibrated
  /// standing ratio and still count as "standing upright".
  final double postureTolerance;

  /// Lean (fraction of the smaller calibrated lean range) below which the
  /// torso counts as upright.
  final double leanTolerance;

  /// Max hip wander (torso lengths) within the window.
  final double stillTolerance;

  /// Scale changes outside this range are not believed.
  final double minScale;
  final double maxScale;
}

/// Passive drift correction: keeps the calibration valid when the player
/// ends up nearer, further or somewhere else than where they calibrated —
/// without asking them to calibrate again.
///
/// It only ever learns from frames in which the player is demonstrably
/// standing neutral: feet and torso visible, the scale-invariant leg/torso
/// ratio matching the calibrated standing ratio (so not squatting or
/// bending), torso upright (not leaning), body still. These tests do not
/// depend on the calibrated scale, so they keep working when the scale is
/// exactly what has gone wrong. Over such a window it takes medians and, if
/// they sit outside a dead band, re-expresses the profile there
/// ([CalibrationProfile.rebase]). Inside the dead band it does nothing at
/// all, so ordinary play is bit-for-bit what the calibration measured.
class DriftCorrector {
  DriftCorrector(CalibrationProfile profile,
      [this.config = const DriftConfig()])
      : _profile = profile;

  final DriftConfig config;
  CalibrationProfile _profile;

  /// The calibration as currently positioned.
  CalibrationProfile get profile => _profile;

  /// How many times the profile has been re-positioned this session.
  int rebases = 0;

  final List<BodyFeatures> _window = [];

  /// Medians are only worth recomputing a few times a second.
  static const _evalEveryMs = 250;
  int _nextEvalMs = 0;

  void reset() => _window.clear();

  /// Feeds one tracked frame. Returns the re-positioned profile when a
  /// correction was made, otherwise null.
  CalibrationProfile? observe(BodyFeatures b) {
    final p = _profile;
    const v = BodyFeatures.trustVisibility;
    if (!b.feetVisible ||
        !p.feetVisible ||
        b.hipVisibility < v ||
        b.shoulderCenter.visibility < v ||
        !_upright(b, p)) {
      _window.clear();
      return null;
    }
    if (_window.isNotEmpty) {
      final n = _window.length;
      var mx = 0.0, my = 0.0;
      for (final x in _window) {
        mx += x.hipCenter.x;
        my += x.hipCenter.y;
      }
      final wander =
          (b.hipCenter.x - mx / n).abs() + (b.hipCenter.y - my / n).abs();
      if (wander > config.stillTolerance * b.torsoLength) _window.clear();
    }
    _window.add(b);
    final span = b.timestampMs - _window.first.timestampMs;
    if (span < 0) {
      // The clock went backwards (a new recording): start again.
      _window
        ..clear()
        ..add(b);
      return null;
    }
    if (span < config.dwellMs) return null;
    if (b.timestampMs < _nextEvalMs &&
        _nextEvalMs - b.timestampMs <= _evalEveryMs) {
      return null;
    }
    _nextEvalMs = b.timestampMs + _evalEveryMs;

    double med(double Function(BodyFeatures) f) =>
        median([for (final x in _window) f(x)]);
    final torso = med((x) => x.torsoLength);
    final hipX = med((x) => x.hipCenter.x);
    final hipY = med((x) => x.hipCenter.y);
    final scale = torso / p.standingTorso;
    final scaled = (scale - 1).abs() > config.scaleDeadband &&
        scale >= config.minScale &&
        scale <= config.maxScale;
    final moved = span >= config.shiftDwellMs &&
        ((hipX - p.standingHipX).abs() > config.shiftDeadbandTorso * torso ||
            (hipY - p.standingHipY).abs() >
                config.vshiftDeadbandTorso * torso);
    if (!scaled && !moved) {
      // Nothing to correct. Keep the window from growing without bound.
      if (span > config.shiftDwellMs + 500) {
        _window.removeRange(0, _window.length ~/ 4);
      }
      return null;
    }
    _profile = p.rebase(
      torso: torso,
      hipX: hipX,
      hipY: hipY,
      legSpan: med((x) => x.legSpan),
      thighSpan: med((x) => x.thighSpan),
      leanOffset: med((x) => x.leanOffset),
      ankleY: med((x) => x.ankleCenter.y),
    );
    rebases++;
    _window.clear();
    return _profile;
  }

  /// Standing upright, judged without trusting the absolute scale: the
  /// leg/torso ratio matches the calibrated standing ratio (a squat or a
  /// forward bend changes it) and the torso is not leaning.
  bool _upright(BodyFeatures b, CalibrationProfile p) {
    if (!(b.torsoLength > 1e-5) || !(b.legSpan > 0)) return false;
    final ratio = (b.legSpan / b.torsoLength) / p.legSpanTorso;
    if ((ratio - 1).abs() > config.postureTolerance) return false;
    final lean = b.leanOffset / b.torsoLength -
        p.standingLeanOffset / p.standingTorso;
    final range = p.leanRangeLeft < p.leanRangeRight
        ? p.leanRangeLeftTorso
        : p.leanRangeRightTorso;
    return lean.abs() <= config.leanTolerance * range;
  }
}
