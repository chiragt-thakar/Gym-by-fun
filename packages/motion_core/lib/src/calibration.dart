import 'dart:math' as math;

import 'features.dart';
import 'landmarks.dart';
import 'robust.dart';

/// The player's own body model and movement range, measured in about
/// 30 seconds.
///
/// Stored values are in normalised image units at the position the player
/// stood in when they were measured. They are never used raw across
/// sessions: every length is a multiple of [standingTorso], so [rebase]
/// re-expresses the whole profile at the player's current distance and
/// spot from one steady standing observation (`DriftCorrector` does this
/// passively during play). Detectors divide by these values, which makes
/// every measure a fraction of the player's own range — independent of
/// camera position, resolution and the player's height.
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
    double? standingThighSpan,
    double? squatThighDepth,
    double? shoulderWidth,
    double? hipWidth,
    double? armLength,
    double? standingAnkleY,
    double? bodyHeight,
    this.cameraRoll = 0,
    this.aspect = 0.75,
    this.quality = 0,
    this.feetVisible = true,
    this.version = currentVersion,
  })  : sideStepRange = sideStepRange ?? standingTorso * 0.6,
        standingThighSpan =
            standingThighSpan ?? standingLegSpan * defaultThighToLeg,
        squatThighDepth = squatThighDepth ?? squatDepth * defaultThighDepth,
        shoulderWidth = shoulderWidth ?? standingTorso * defaultShoulderTorso,
        hipWidth = hipWidth ?? standingTorso * defaultHipTorso,
        armLength = armLength ?? standingTorso * defaultArmTorso,
        standingAnkleY = standingAnkleY ?? standingHipY + standingLegSpan,
        bodyHeight = bodyHeight ?? standingTorso * 3.3;

  /// Profile format version written by this build. Version 1 profiles
  /// (ten fields, no `v`) load with population defaults for the rest.
  static const currentVersion = 2;

  final int version;

  /// Hip-to-ankle vertical span when standing.
  final double standingLegSpan;

  /// Shoulder-to-hip length when standing: the body-relative unit.
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

  /// Hip-to-knee vertical span when standing, and how far it shrinks at
  /// the bottom of a comfortable squat (the squat measure when the feet
  /// are out of view).
  final double standingThighSpan;
  final double squatThighDepth;

  /// Limb proportions, in image units at the calibration position.
  final double shoulderWidth;
  final double hipWidth;

  /// Shoulder → elbow → wrist length.
  final double armLength;

  /// Ankle-centre height when standing (the floor line, for jumps).
  final double standingAnkleY;

  /// Nose-to-ankle height as a fraction of the image: how far the player
  /// stood from the camera (about 0.6 at 2–2.5 m on a phone).
  final double bodyHeight;

  /// Tilt of the shoulder line in degrees: the camera's roll (0 = level).
  final double cameraRoll;

  /// Width / height of the image the profile was measured in.
  final double aspect;

  /// Calibration quality score 0..1 (0 = not scored, e.g. a quick start).
  final double quality;

  /// False when the feet were out of view during calibration, so leg
  /// values were estimated from the thighs.
  final bool feetVisible;

  /// Lower bounds (as torso fractions) so a timid calibration can't create a
  /// hair trigger that fires on breathing.
  static const minSquatDepthTorso = 0.15;
  static const minLeanRangeTorso = 0.10;

  /// Population defaults (torso fractions), used for "quick start" and for
  /// any calibration step the player could not finish.
  static const defaultSquatDepthTorso = 0.45;
  static const defaultLeanRangeTorso = 0.30;
  static const defaultReachAboveNoseTorso = 0.6;

  /// Population proportions for values a version 1 profile lacks.
  static const defaultThighToLeg = 0.5;
  static const defaultThighDepth = 0.85;
  static const defaultShoulderTorso = 0.75;
  static const defaultHipTorso = 0.47;
  static const defaultArmTorso = 1.05;

  /// The range in body units (torso lengths): what is actually personal
  /// about the profile, independent of where the player stood.
  double get squatDepthTorso => squatDepth / standingTorso;
  double get leanRangeLeftTorso => leanRangeLeft / standingTorso;
  double get leanRangeRightTorso => leanRangeRight / standingTorso;
  double get legSpanTorso => standingLegSpan / standingTorso;
  double get shoulderWidthTorso => shoulderWidth / standingTorso;
  double get armLengthTorso => armLength / standingTorso;

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
      squatDepth: t * defaultSquatDepthTorso,
      leanRangeLeft: t * defaultLeanRangeTorso,
      leanRangeRight: t * defaultLeanRangeTorso,
      reachY: b.nose.y - t * defaultReachAboveNoseTorso,
      standingThighSpan: b.thighSpan,
      shoulderWidth: b.shoulderWidth,
      hipWidth: b.hipWidth,
      standingAnkleY: b.ankleCenter.y,
      bodyHeight: b.ankleCenter.y - b.nose.y,
      aspect: b.aspect,
    );
  }

  /// The same body and range, re-expressed for a player now standing with
  /// torso length [torso] and hips at ([hipX], [hipY]). Lengths scale with
  /// the torso; measured values, when given, replace the scaled ones.
  CalibrationProfile rebase({
    required double torso,
    required double hipX,
    required double hipY,
    double? legSpan,
    double? thighSpan,
    double? leanOffset,
    double? ankleY,
  }) {
    final k = torso / standingTorso;
    final leg = legSpan ?? standingLegSpan * k;
    return CalibrationProfile(
      standingLegSpan: leg,
      standingTorso: torso,
      standingHipX: hipX,
      standingHipY: hipY,
      standingLeanOffset: leanOffset ?? standingLeanOffset * k,
      squatDepth: squatDepth * k,
      leanRangeLeft: leanRangeLeft * k,
      leanRangeRight: leanRangeRight * k,
      reachY: hipY - (standingHipY - reachY) * k,
      sideStepRange: sideStepRange * k,
      standingThighSpan: thighSpan ?? standingThighSpan * k,
      squatThighDepth: squatThighDepth * k,
      shoulderWidth: shoulderWidth * k,
      hipWidth: hipWidth * k,
      armLength: armLength * k,
      standingAnkleY: ankleY ?? hipY + leg,
      bodyHeight: bodyHeight * k,
      cameraRoll: cameraRoll,
      aspect: aspect,
      quality: quality,
      feetVisible: feetVisible,
      version: version,
    );
  }

  /// Numbers only (the server's calibration backup stores a flat
  /// string → number map).
  Map<String, Object> toJson() => {
        'v': version,
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
        'standingThighSpan': standingThighSpan,
        'squatThighDepth': squatThighDepth,
        'shoulderWidth': shoulderWidth,
        'hipWidth': hipWidth,
        'armLength': armLength,
        'standingAnkleY': standingAnkleY,
        'bodyHeight': bodyHeight,
        'cameraRoll': cameraRoll,
        'aspect': aspect,
        'quality': quality,
        'feetVisible': feetVisible ? 1 : 0,
      };

  /// Reads any version. Missing values (a version 1 profile) take the
  /// population proportions; a newer version's unknown keys are ignored.
  /// Throws [FormatException] when a required value is missing or not a
  /// finite positive length.
  factory CalibrationProfile.fromJson(Map<String, dynamic> j) {
    double d(String k) {
      final v = j[k];
      if (v is! num || !v.isFinite) {
        throw FormatException('Calibration profile: bad "$k"');
      }
      return v.toDouble();
    }

    double? o(String k) {
      final v = j[k];
      return v is num && v.isFinite ? v.toDouble() : null;
    }

    double len(String k) {
      final v = d(k);
      if (v <= 0) throw FormatException('Calibration profile: bad "$k"');
      return v;
    }

    return CalibrationProfile(
      version: (j['v'] as num?)?.toInt() ?? 1,
      standingLegSpan: len('standingLegSpan'),
      standingTorso: len('standingTorso'),
      standingHipX: d('standingHipX'),
      standingHipY: d('standingHipY'),
      standingLeanOffset: d('standingLeanOffset'),
      squatDepth: len('squatDepth'),
      leanRangeLeft: len('leanRangeLeft'),
      leanRangeRight: len('leanRangeRight'),
      reachY: d('reachY'),
      sideStepRange: o('sideStepRange'),
      standingThighSpan: o('standingThighSpan'),
      squatThighDepth: o('squatThighDepth'),
      shoulderWidth: o('shoulderWidth'),
      hipWidth: o('hipWidth'),
      armLength: o('armLength'),
      standingAnkleY: o('standingAnkleY'),
      bodyHeight: o('bodyHeight'),
      cameraRoll: o('cameraRoll') ?? 0,
      aspect: o('aspect') ?? 0.75,
      quality: o('quality') ?? 0,
      feetVisible: (o('feetVisible') ?? 1) != 0,
    );
  }

  /// True if a standing frame no longer matches the baseline — usually the
  /// phone moved or the player changed spot. `DriftCorrector` handles this
  /// automatically during play; this is the one-shot check.
  bool hasDrifted(BodyFeatures standing, {double tolerance = 0.15}) {
    final scale = (standing.torsoLength - standingTorso).abs() / standingTorso;
    final shift = (standing.hipCenter.x - standingHipX).abs() / standingTorso;
    final vshift = (standing.hipCenter.y - standingHipY).abs() / standingTorso;
    return scale > tolerance || shift > 1.0 || vshift > 0.5;
  }
}

/// Something about the conditions that made a calibration less trustworthy.
/// Each maps to one plain-language fix in the app.
enum CalibrationIssue {
  /// The player (or the camera) kept moving while standing still.
  unsteady,

  /// Landmarks were faint: a dim room, backlight or loose clothes.
  lowLight,

  /// The feet were out of view; leg values were estimated.
  feetHidden,

  /// The player was small in the image.
  tooFar,

  /// The player nearly filled the image; raised arms may leave it.
  tooClose,

  /// Frames arrived slowly (a busy or hot phone).
  lowFrameRate,

  /// The camera is noticeably rolled to one side.
  tilted,

  /// The player was not square to the camera.
  sideOn,

  /// One or more steps fell back to gentle defaults.
  stepsSkipped,

  /// The squats differed a lot in depth.
  unevenSquats,

  /// One lean was much smaller than the other.
  unevenLean,
}

enum CalibrationGrade { good, fair, poor }

/// How much a finished calibration can be trusted, and why not.
class CalibrationReport {
  const CalibrationReport(this.score, this.issues);

  /// 0..1; 1 = textbook conditions.
  final double score;
  final Set<CalibrationIssue> issues;

  CalibrationGrade get grade => score >= 0.75
      ? CalibrationGrade.good
      : score >= 0.5
          ? CalibrationGrade.fair
          : CalibrationGrade.poor;

  /// A poor calibration is worth redoing once the conditions are fixed.
  bool get shouldRetry => grade == CalibrationGrade.poor;

  @override
  String toString() =>
      'CalibrationReport(${score.toStringAsFixed(2)} ${grade.name}, $issues)';
}

/// The steps of the guided calibration, in order.
enum CalibrationStep { neutral, armsUp, squats, leanLeft, leanRight, done }

/// Guided calibration as a state machine. Feed it stabilised frames whose
/// torso is tracked; it advances through the steps on its own and exposes
/// progress for the UI.
///
/// Every stored value is a robust statistic over many frames (a median, or
/// a high/low percentile for a range), never a single frame, so one bad
/// landmark cannot bend the profile. [report] scores the result;
/// [conditions] names problems while they are happening.
///
/// With [base] set it is a quick re-calibration: only the standing step
/// runs, and [build] re-expresses [base] at the new position.
class Calibrator {
  Calibrator({
    this.stillMs = 2000,
    this.holdMs = 500,
    this.squatsRequired = 2,
    this.stillTolerance = 0.08,
    this.base,
  });

  final int stillMs;
  final int holdMs;
  final int squatsRequired;

  /// Max hip-centre wander (torso fractions) that still counts as "still".
  final double stillTolerance;

  /// An existing profile to re-position (quick re-calibration), or null
  /// for the full routine.
  final CalibrationProfile? base;

  bool get quick => base != null;

  CalibrationStep _step = CalibrationStep.neutral;
  CalibrationStep get step => _step;

  final List<BodyFeatures> _neutral = [];
  double? _legSpan, _torso, _hipX, _hipY, _leanOffset, _noseY;
  double? _thigh, _shoulderW, _hipW, _armLen, _ankleY, _roll;
  double _aspect = 0.75;
  bool _feet = true;
  double _steadiness = 0;
  int _neutralResets = 0;

  final List<double> _reachSamples = [];
  final List<double> _repBottoms = [];
  final List<double> _repThighBottoms = [];
  final List<double> _repSpans = [];
  final List<double> _repThighs = [];
  int _squats = 0;
  bool _inSquat = false;
  final List<double> _leanLeftSamples = [];
  final List<double> _leanRightSamples = [];

  // Conditions, tracked over every fed frame.
  final List<double> _dts = [];
  double _visSum = 0;
  int _visN = 0;
  double _visLive = 1;
  double _feetLive = 1;

  int? _holdStart;
  int _stepActiveMs = 0;
  int? _lastTs;

  /// A gap between fed frames counts for at most this much step time.
  static const maxGapMs = 100;
  final Set<CalibrationStep> _skipped = {};

  int get squatsDone => _squats;

  /// Steps that used population defaults because the player could not
  /// finish them (tracking trouble, mobility). Never a failure.
  Set<CalibrationStep> get skipped => Set.unmodifiable(_skipped);

  /// 0..1 progress within the current step, for the UI ring.
  double progress = 0;

  /// Time spent in the current step with the player in frame (gaps
  /// between fed frames count for at most [maxGapMs]). The UI uses this to
  /// offer a gentle default instead of leaving the player stuck; time out
  /// of frame never counts against them.
  int get stepActiveMs => _stepActiveMs;

  /// Problems that are happening right now, for live guidance. Empty when
  /// conditions are fine.
  Set<CalibrationIssue> get conditions => {
        if (_step == CalibrationStep.neutral && _neutralResets >= 3)
          CalibrationIssue.unsteady,
        if (_visLive < 0.7) CalibrationIssue.lowLight,
        if (_feetLive < 0.5) CalibrationIssue.feetHidden,
        if (_dts.length >= 15 && _recentDt() > 80)
          CalibrationIssue.lowFrameRate,
      };

  double _recentDt() =>
      median(_dts.sublist(math.max(0, _dts.length - 30)));

  /// Moves past the current step using population defaults for whatever
  /// was not measured. The standing baseline cannot be skipped: every
  /// other value is relative to it. Returns false if nothing was skipped.
  bool skip() {
    switch (_step) {
      case CalibrationStep.neutral || CalibrationStep.done:
        return false;
      case CalibrationStep.armsUp:
        _skipped.add(_step);
        _next(CalibrationStep.squats);
      case CalibrationStep.squats:
        _skipped.add(_step);
        _next(CalibrationStep.leanLeft);
      case CalibrationStep.leanLeft:
        _skipped.add(_step);
        _next(CalibrationStep.leanRight);
      case CalibrationStep.leanRight:
        _skipped.add(_step);
        _next(CalibrationStep.done);
    }
    return true;
  }

  void add(PoseFrame frame) {
    if (!frame.hasPerson || _step == CalibrationStep.done) return;
    final ts = frame.timestampMs;
    final last = _lastTs;
    if (last != null) {
      final gap = ts - last;
      _stepActiveMs += gap.clamp(0, maxGapMs);
      if (gap > 0 && gap <= 500 && _dts.length < 2000) _dts.add(gap.toDouble());
    }
    _lastTs = ts;
    final b = BodyFeatures.from(frame);
    _aspect = b.aspect;

    var vis = 0.0;
    for (final i in Lm.fullBody) {
      vis += frame[i].visibility;
    }
    vis /= Lm.fullBody.length;
    _visSum += vis;
    _visN++;
    _visLive += (vis - _visLive) * 0.1;
    _feetLive += ((b.feetVisible ? 1.0 : 0.0) - _feetLive) * 0.1;

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
      if (wander > stillTolerance * b.torsoLength) {
        // A long window broken by movement: the player or the camera is
        // not steady. (A short one is just the player settling in.)
        if (n >= 8) _neutralResets++;
        _neutral.clear();
      }
    }
    _neutral.add(b);
    final span = _neutral.last.timestampMs - _neutral.first.timestampMs;
    progress = (span / stillMs).clamp(0, 1).toDouble();
    if (span >= stillMs) {
      _measureNeutral();
      _next(quick ? CalibrationStep.done : CalibrationStep.armsUp);
    }
  }

  /// Robust standing baseline and body proportions from the still window.
  void _measureNeutral() {
    List<double> col(double Function(BodyFeatures) f) =>
        [for (final x in _neutral) f(x)];
    double med(double Function(BodyFeatures) f) => median(col(f));

    final torso = med((x) => x.torsoLength);
    _torso = torso;
    final hipXs = col((x) => x.hipCenter.x);
    final hipYs = col((x) => x.hipCenter.y);
    final hipX = median(hipXs), hipY = median(hipYs);
    _hipX = hipX;
    _hipY = hipY;
    _leanOffset = med((x) => x.leanOffset);
    _noseY = med((x) => x.nose.y);
    _steadiness = (mad(hipXs, hipX) + mad(hipYs, hipY)) * madToSigma / torso;

    final thigh = med((x) => x.thighSpan);
    _thigh = thigh;
    final withFeet = [
      for (final x in _neutral)
        if (x.feetVisible) x
    ];
    _feet = withFeet.length >= _neutral.length * 0.7;
    if (_feet) {
      _legSpan = median([for (final x in withFeet) x.legSpan]);
      _ankleY = median([for (final x in withFeet) x.ankleCenter.y]);
    } else {
      // Feet out of view: the knee sits about half-way down the leg.
      final leg = thigh / CalibrationProfile.defaultThighToLeg;
      _legSpan = leg;
      _ankleY = hipY + leg;
    }
    _shoulderW = med((x) => x.shoulderWidth);
    _hipW = med((x) => x.hipWidth);

    // Arm length from the longer-looking arm (the other may be turned
    // towards the camera), only where the whole arm was seen.
    const v = BodyFeatures.trustVisibility;
    final arms = <double>[];
    for (final x in _neutral) {
      var best = 0.0;
      if (x.leftShoulder.visibility >= v &&
          x.leftElbow.visibility >= v &&
          x.leftWrist.visibility >= v) {
        best = landmarkDistance(x.leftShoulder, x.leftElbow) +
            landmarkDistance(x.leftElbow, x.leftWrist);
      }
      if (x.rightShoulder.visibility >= v &&
          x.rightElbow.visibility >= v &&
          x.rightWrist.visibility >= v) {
        best = math.max(
          best,
          landmarkDistance(x.rightShoulder, x.rightElbow) +
              landmarkDistance(x.rightElbow, x.rightWrist),
        );
      }
      if (best > 0) arms.add(best);
    }
    _armLen = arms.length >= 5 ? median(arms) : null;

    _roll = med((x) =>
        math.atan2(
          x.rightShoulder.y - x.leftShoulder.y,
          (x.rightShoulder.x - x.leftShoulder.x) * x.aspect,
        ) *
        180 /
        math.pi);
  }

  void _armsUpFrame(BodyFeatures b) {
    if (b.leftWristAboveNose && b.rightWristAboveNose) {
      _holdStart ??= b.timestampMs;
      _reachSamples.add(math.min(b.leftWrist.y, b.rightWrist.y));
      final held = b.timestampMs - _holdStart!;
      progress = (held / holdMs).clamp(0, 1).toDouble();
      if (held >= holdMs) _next(CalibrationStep.squats);
    } else {
      _holdStart = null;
      progress = 0;
    }
  }

  void _squatFrame(BodyFeatures b) {
    // With the feet out of view the thigh span stands in for the leg span.
    final useFeet = _feet && b.feetVisible;
    final thighDrop = _thigh! - b.thighSpan;
    final drop = useFeet
        ? _legSpan! - b.legSpan
        : thighDrop / CalibrationProfile.defaultThighDepth;
    final minDrop = CalibrationProfile.minSquatDepthTorso * _torso!;
    if (!_inSquat && drop > minDrop) _inSquat = true;
    if (_inSquat) {
      _repSpans.add(_legSpan! - drop);
      _repThighs.add(b.thighSpan);
    }
    // "Back up" is half the minimum depth: players rarely return to the
    // exact standing span, and distance adds landmark noise.
    if (_inSquat && drop < minDrop * 0.5) {
      _closeRep();
      _squats++;
    }
    progress = _squats / squatsRequired;
    if (_squats >= squatsRequired) _next(CalibrationStep.leanLeft);
  }

  /// Records the bottom of the rep in progress (if any).
  void _closeRep() {
    if (_inSquat && _repSpans.isNotEmpty) {
      _repBottoms.add(_bottom(_repSpans));
      _repThighBottoms.add(_bottom(_repThighs));
    }
    _inSquat = false;
    _repSpans.clear();
    _repThighs.clear();
  }

  /// The lowest value of a rep, ignoring one stray frame: with enough
  /// samples the single smallest is dropped (a real bottom lasts several
  /// frames; a landmark spike lasts one).
  static double _bottom(List<double> samples) {
    final sorted = List<double>.of(samples)..sort();
    return sorted.length >= 6 ? sorted[1] : sorted[0];
  }

  void _leanFrame(BodyFeatures b, {required bool left}) {
    final shift = b.leanOffset - _leanOffset!;
    final minLean = CalibrationProfile.minLeanRangeTorso * _torso!;
    final active = left ? shift < -minLean : shift > minLean;
    if (active) {
      _holdStart ??= b.timestampMs;
      if (left) {
        _leanLeftSamples.add(-shift);
      } else {
        _leanRightSamples.add(shift);
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
    // A squat still in progress when the step ends keeps its depth.
    if (_step == CalibrationStep.squats) _closeRep();
    _step = s;
    _holdStart = null;
    _stepActiveMs = 0;
    _inSquat = false;
    progress = 0;
  }

  double _measuredSquatDepth() => _legSpan! - median(_repBottoms);

  /// How much the finished calibration can be trusted. Meaningful once the
  /// standing step is done.
  CalibrationReport get report {
    final t = _torso;
    if (t == null) return const CalibrationReport(0, {});
    final issues = <CalibrationIssue>{};
    var score = 1.0;
    void flag(CalibrationIssue i, double penalty) {
      issues.add(i);
      score -= penalty;
    }

    if (_neutralResets >= 3 || _steadiness > 0.03) {
      flag(CalibrationIssue.unsteady, _neutralResets >= 3 ? 0.2 : 0.1);
    }
    final vis = _visN == 0 ? 1.0 : _visSum / _visN;
    if (vis < 0.8) flag(CalibrationIssue.lowLight, vis < 0.7 ? 0.25 : 0.1);
    if (!_feet) flag(CalibrationIssue.feetHidden, 0.2);
    final height = _ankleY! - _noseY!;
    if (_feet && height < 0.45) flag(CalibrationIssue.tooFar, 0.15);
    if (height > 0.9) flag(CalibrationIssue.tooClose, 0.15);
    if (_dts.length >= 15) {
      final dt = median(_dts);
      if (dt > 55) flag(CalibrationIssue.lowFrameRate, dt > 80 ? 0.2 : 0.1);
    }
    if ((_roll ?? 0).abs() > 8) flag(CalibrationIssue.tilted, 0.1);
    if (_shoulderW! / t < 0.45) flag(CalibrationIssue.sideOn, 0.2);
    if (_skipped.isNotEmpty) {
      flag(CalibrationIssue.stepsSkipped,
          math.min(0.45, 0.15 * _skipped.length));
    }
    if (_repBottoms.length >= 2) {
      final depths = [for (final b in _repBottoms) _legSpan! - b];
      final m = median(depths);
      final spread = depths.reduce(math.max) - depths.reduce(math.min);
      if (m > 0 && spread / m > 0.35) {
        flag(CalibrationIssue.unevenSquats, 0.1);
      }
    }
    if (_leanLeftSamples.isNotEmpty && _leanRightSamples.isNotEmpty) {
      final l = percentile(_leanLeftSamples, 0.9);
      final r = percentile(_leanRightSamples, 0.9);
      if (math.min(l, r) / math.max(l, r) < 0.5) {
        flag(CalibrationIssue.unevenLean, 0.1);
      }
    }
    return CalibrationReport(score.clamp(0.0, 1.0).toDouble(), issues);
  }

  /// The measured profile, once [step] is [CalibrationStep.done].
  CalibrationProfile build() {
    if (_step != CalibrationStep.done) {
      throw StateError('Calibration not finished (at $_step)');
    }
    final t = _torso!;
    final quality = report.score;
    final old = base;
    if (old != null) {
      // Quick re-calibration: same body and range, new position.
      final p = old.rebase(
        torso: t,
        hipX: _hipX!,
        hipY: _hipY!,
        legSpan: _feet ? _legSpan : null,
        thighSpan: _thigh,
        leanOffset: _leanOffset,
        ankleY: _feet ? _ankleY : null,
      );
      return CalibrationProfile(
        standingLegSpan: p.standingLegSpan,
        standingTorso: p.standingTorso,
        standingHipX: p.standingHipX,
        standingHipY: p.standingHipY,
        standingLeanOffset: p.standingLeanOffset,
        squatDepth: p.squatDepth,
        leanRangeLeft: p.leanRangeLeft,
        leanRangeRight: p.leanRangeRight,
        reachY: p.reachY,
        sideStepRange: p.sideStepRange,
        standingThighSpan: p.standingThighSpan,
        squatThighDepth: p.squatThighDepth,
        shoulderWidth: p.shoulderWidth,
        hipWidth: p.hipWidth,
        armLength: p.armLength,
        standingAnkleY: p.standingAnkleY,
        bodyHeight: p.bodyHeight,
        cameraRoll: _roll ?? p.cameraRoll,
        aspect: _aspect,
        // The ranges were not re-measured: never claim more than before.
        quality: math.min(old.quality, quality),
        feetVisible: old.feetVisible && _feet,
      );
    }

    // Measured values win; a skipped step with nothing measured uses the
    // population default for that value.
    double lean(List<double> samples, CalibrationStep s) => samples.isNotEmpty
        ? math.max(percentile(samples, 0.9),
            CalibrationProfile.minLeanRangeTorso * t)
        : (_skipped.contains(s)
            ? CalibrationProfile.defaultLeanRangeTorso * t
            : CalibrationProfile.minLeanRangeTorso * t);
    final squat = _repBottoms.isNotEmpty
        ? math.max(
            _measuredSquatDepth(), CalibrationProfile.minSquatDepthTorso * t)
        : CalibrationProfile.defaultSquatDepthTorso * t;
    final thighDepth = _repThighBottoms.isNotEmpty
        ? math.max(
            _thigh! - median(_repThighBottoms),
            CalibrationProfile.minSquatDepthTorso *
                CalibrationProfile.defaultThighDepth *
                t,
          )
        : squat * CalibrationProfile.defaultThighDepth;
    return CalibrationProfile(
      standingLegSpan: _legSpan!,
      standingTorso: t,
      standingHipX: _hipX!,
      standingHipY: _hipY!,
      standingLeanOffset: _leanOffset!,
      squatDepth: squat,
      leanRangeLeft: lean(_leanLeftSamples, CalibrationStep.leanLeft),
      leanRangeRight: lean(_leanRightSamples, CalibrationStep.leanRight),
      // The 10th percentile of the held wrist height: near the top of the
      // reach, but not one stray frame.
      reachY: _reachSamples.isNotEmpty
          ? percentile(_reachSamples, 0.1)
          : _noseY! - CalibrationProfile.defaultReachAboveNoseTorso * t,
      standingThighSpan: _thigh,
      squatThighDepth: thighDepth,
      shoulderWidth: _shoulderW,
      hipWidth: _hipW,
      armLength: _armLen,
      standingAnkleY: _ankleY,
      bodyHeight: _ankleY! - _noseY!,
      cameraRoll: _roll ?? 0,
      aspect: _aspect,
      quality: quality,
      feetVisible: _feet,
    );
  }
}
