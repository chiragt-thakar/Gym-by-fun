import 'dart:math' as math;

import 'calibration.dart';
import 'events.dart';
import 'extra_recognisers.dart';
import 'features.dart';
import 'landmarks.dart';
import 'recognisers.dart';

/// Ids of the built-in detectors.
abstract final class DetectorIds {
  static const squat = 'squat';
  static const lean = 'lean';
  static const raiseArms = 'raiseArms';
  static const barrierHold = 'barrierHold';
  static const sideStep = 'sideStep';
  static const jump = 'jump';
  static const punch = 'punch';
  static const twist = 'twist';
  static const kneeLift = 'kneeLift';
}

/// What a detector is built from.
class DetectorContext {
  const DetectorContext({
    required this.calibration,
    this.thresholds = const MotionThresholds(),
    this.extra = const ExtraMoveThresholds(),
  });

  final CalibrationProfile calibration;
  final MotionThresholds thresholds;
  final ExtraMoveThresholds extra;
}

/// A request for one detector: its registry id and, optionally, its typed
/// config (each detector documents its config class; null = defaults).
class DetectorSpec {
  const DetectorSpec(this.id, [this.config]);
  final String id;
  final Object? config;
}

typedef DetectorBuilder = Recogniser Function(
    DetectorContext context, Object? config);

/// Maps detector ids to builders. A game asks the engine for detectors by
/// id; adding a gesture is one [register] call, with no change to the
/// engine or to any other game.
class DetectorRegistry {
  /// An empty registry.
  DetectorRegistry();

  /// Every built-in detector.
  factory DetectorRegistry.standard() => DetectorRegistry()
    ..register(
      DetectorIds.squat,
      (c, cfg) => SquatRecogniser(
          c.calibration, _config(DetectorIds.squat, cfg, c.thresholds)),
    )
    ..register(
      DetectorIds.lean,
      (c, cfg) => LeanRecogniser(
          c.calibration, _config(DetectorIds.lean, cfg, c.thresholds)),
    )
    ..register(
      DetectorIds.raiseArms,
      (c, cfg) => RaiseArmsRecogniser(
          _config(DetectorIds.raiseArms, cfg, c.thresholds)),
    )
    ..register(
      DetectorIds.barrierHold,
      (c, cfg) => BarrierHoldRecogniser(c.calibration, c.thresholds,
          _config(DetectorIds.barrierHold, cfg, c.extra)),
    )
    ..register(
      DetectorIds.sideStep,
      (c, cfg) => SideStepRecogniser(c.calibration, c.thresholds,
          _config(DetectorIds.sideStep, cfg, c.extra)),
    )
    ..register(
      DetectorIds.jump,
      (c, cfg) => JumpDetector(
          c.calibration, _config(DetectorIds.jump, cfg, const JumpConfig())),
    )
    ..register(
      DetectorIds.punch,
      (c, cfg) => PunchDetector(c.calibration,
          _config(DetectorIds.punch, cfg, const PunchConfig())),
    )
    ..register(
      DetectorIds.twist,
      (c, cfg) => TwistDetector(c.calibration,
          _config(DetectorIds.twist, cfg, const TwistConfig())),
    )
    ..register(
      DetectorIds.kneeLift,
      (c, cfg) => KneeLiftDetector(c.calibration,
          _config(DetectorIds.kneeLift, cfg, const KneeLiftConfig())),
    );

  final Map<String, DetectorBuilder> _builders = {};

  Iterable<String> get ids => _builders.keys;

  bool has(String id) => _builders.containsKey(id);

  /// Adds a detector. Throws if [id] is already taken.
  void register(String id, DetectorBuilder builder) {
    if (_builders.containsKey(id)) {
      throw ArgumentError.value(id, 'id', 'Detector already registered');
    }
    _builders[id] = builder;
  }

  /// Builds the detector [spec] asks for. Throws [ArgumentError] for an
  /// unknown id or a config of the wrong type.
  Recogniser build(DetectorSpec spec, DetectorContext context) {
    final b = _builders[spec.id];
    if (b == null) {
      throw ArgumentError.value(spec.id, 'id', 'Unknown detector');
    }
    return b(context, spec.config);
  }
}

T _config<T extends Object>(String id, Object? config, T fallback) {
  if (config == null) return fallback;
  if (config is T) return config;
  throw ArgumentError(
      'Detector "$id" needs a $T config, got ${config.runtimeType}');
}

// ---------------------------------------------------------------- jump

class JumpConfig {
  const JumpConfig({
    this.riseTorso = 0.22,
    this.feetRiseTorso = 0.16,
    this.landTorso = 0.08,
    this.baselineMs = 800,
    this.cooldownMs = 500,
    this.maxAirMs = 900,
    this.minVisibility = 0.5,
  });

  /// Hip rise above the standing baseline (torso lengths) that is a jump.
  final double riseTorso;

  /// The ankles must rise at least this much too: standing up from a squat
  /// or going up on the toes lifts the hips, not the feet.
  final double feetRiseTorso;

  /// Hip rise below which the player has landed.
  final double landTorso;

  /// Time constant of the standing baseline. It follows where the player
  /// stands (and a camera that is nudged) but is far slower than a jump.
  final int baselineMs;
  final int cooldownMs;

  /// A "jump" longer than this is not a jump (the baseline was wrong).
  final int maxAirMs;
  final double minVisibility;
}

/// Jump: hips and feet both rise quickly above a slowly-following standing
/// baseline. Fires once at take-off ([GesturePhase.fired]) and reports the
/// landing ([GesturePhase.ended], with the air time).
///
/// Opt-in only: Joynetic is low-impact by default (rule 9).
class JumpDetector implements Recogniser {
  JumpDetector(this.cal, [this.c = const JumpConfig()]);
  CalibrationProfile cal;
  final JumpConfig c;

  bool _air = false;
  int _startMs = 0;
  int _cooldownUntil = -1 << 30;
  double _peak = 0;
  double _measure = 0;
  double? _hipBase, _ankleBase;
  int? _lastMs;

  @override
  String get id => DetectorIds.jump;
  @override
  String get state => _air ? 'air' : 'ground';
  @override
  double get measure => _measure;
  @override
  void recalibrate(CalibrationProfile c) => cal = c;

  @override
  void update(BodyFeatures b, List<MotionEvent> out) {
    final ts = b.timestampMs;
    final last = _lastMs;
    _lastMs = ts;
    final visible = b.hipVisibility >= c.minVisibility &&
        b.ankleCenter.visibility >= c.minVisibility;
    if (!visible) {
      if (_air) _land(ts, out, completed: false);
      _hipBase = _ankleBase = null;
      _measure = 0;
      return;
    }
    final hipBase = _hipBase, ankleBase = _ankleBase;
    if (hipBase == null || ankleBase == null || last == null || ts <= last) {
      _hipBase = b.hipCenter.y;
      _ankleBase = b.ankleCenter.y;
      _measure = 0;
      return;
    }
    final torso = cal.standingTorso;
    final rise = (hipBase - b.hipCenter.y) / torso;
    final feet = (ankleBase - b.ankleCenter.y) / torso;
    _measure = rise / c.riseTorso;

    if (_air) {
      if (rise > _peak) _peak = rise;
      if (rise < c.landTorso || ts - _startMs > c.maxAirMs) {
        _land(ts, out, completed: true);
        // A stale baseline caused it: take the current stance.
        if (ts - _startMs > c.maxAirMs) {
          _hipBase = b.hipCenter.y;
          _ankleBase = b.ankleCenter.y;
        }
      }
      return;
    }
    // Follow the stance only while grounded.
    final k = 1 - math.exp(-(ts - last) / c.baselineMs);
    _hipBase = hipBase + (b.hipCenter.y - hipBase) * k;
    _ankleBase = ankleBase + (b.ankleCenter.y - ankleBase) * k;
    if (ts < _cooldownUntil) return;
    if (rise >= c.riseTorso && feet >= c.feetRiseTorso) {
      _air = true;
      _startMs = ts;
      _peak = rise;
      out.add(GestureEvent(DetectorIds.jump, GesturePhase.fired, ts,
          strength: rise / c.riseTorso));
    }
  }

  void _land(int ts, List<MotionEvent> out, {required bool completed}) {
    _air = false;
    _cooldownUntil = ts + c.cooldownMs;
    out.add(GestureEvent(DetectorIds.jump, GesturePhase.ended, ts,
        heldMs: ts - _startMs,
        strength: _peak / c.riseTorso,
        completed: completed));
  }

  @override
  void interrupt(int timestampMs, List<MotionEvent> out) {
    if (_air) _land(timestampMs, out, completed: false);
    _hipBase = _ankleBase = null;
    _lastMs = null;
  }
}

// --------------------------------------------------------------- punch

class PunchConfig {
  const PunchConfig({
    this.startSpeed = 3.5,
    this.minTravel = 0.35,
    this.rearmSpeed = 1.0,
    this.cooldownMs = 250,
    this.minVisibility = 0.5,
    this.depthWeight = 0,
    this.maxGapMs = 250,
  });

  /// Arm-extension speed (torso lengths per second) that starts a punch.
  final double startSpeed;

  /// The wrist must travel this far from the shoulder (torso lengths)
  /// during the thrust.
  final double minTravel;

  /// Extension speed below which the thrust is over.
  final double rearmSpeed;

  /// Per hand.
  final int cooldownMs;
  final double minVisibility;

  /// How much the estimated depth (z) counts in the wrist-to-shoulder
  /// distance. 0 = image plane only: hooks, crosses and uppercuts are seen,
  /// a jab straight at the camera is not. Depth is noisy at 2 m; raise this
  /// only after testing on the target phones.
  final double depthWeight;

  /// A longer gap between frames restarts the measurement.
  final int maxGapMs;
}

class _PunchArm {
  double? ext;
  double startExt = 0;
  bool extending = false;
  bool spent = false;
  int cooldownUntil = -1 << 30;

  void reset() {
    ext = null;
    extending = false;
    spent = false;
  }
}

/// Punch: one arm thrusts out — the wrist-to-shoulder distance grows fast
/// and far. Fires once per thrust, per hand ([GesturePhase.fired] with
/// [GestureEvent.side]). Pulling the arm back never fires.
class PunchDetector implements Recogniser {
  PunchDetector(this.cal, [this.c = const PunchConfig()]);
  CalibrationProfile cal;
  final PunchConfig c;

  final _PunchArm _left = _PunchArm();
  final _PunchArm _right = _PunchArm();
  int? _lastMs;
  double _measure = 0;

  @override
  String get id => DetectorIds.punch;
  @override
  String get state => _left.extending || _right.extending ? 'thrust' : 'idle';

  /// The faster arm's extension speed as a multiple of the start speed.
  @override
  double get measure => _measure;
  @override
  void recalibrate(CalibrationProfile c) => cal = c;

  @override
  void update(BodyFeatures b, List<MotionEvent> out) {
    final ts = b.timestampMs;
    final last = _lastMs;
    _lastMs = ts;
    final dtMs = last == null ? 0 : ts - last;
    final fresh = dtMs > 0 && dtMs <= c.maxGapMs;
    final l = _arm(_left, BodySide.left, b.leftWrist, b.leftShoulder, b,
        dtMs / 1000.0, fresh, ts, out);
    final r = _arm(_right, BodySide.right, b.rightWrist, b.rightShoulder, b,
        dtMs / 1000.0, fresh, ts, out);
    _measure = math.max(l, r) / c.startSpeed;
  }

  /// Updates one arm; returns its extension speed (0 when unknown).
  double _arm(_PunchArm a, BodySide side, Landmark wrist, Landmark sh,
      BodyFeatures b, double dtS, bool fresh, int ts, List<MotionEvent> out) {
    if (wrist.visibility < c.minVisibility ||
        sh.visibility < c.minVisibility) {
      a.reset();
      return 0;
    }
    final dx = (wrist.x - sh.x) * b.aspect;
    final dy = wrist.y - sh.y;
    final dz = (wrist.z - sh.z) * b.aspect * c.depthWeight;
    final ext = math.sqrt(dx * dx + dy * dy + dz * dz) / cal.standingTorso;
    final prev = a.ext;
    a.ext = ext;
    if (prev == null || !fresh) {
      a.extending = false;
      a.spent = false;
      return 0;
    }
    final speed = (ext - prev) / dtS;
    if (a.spent) {
      // Wait for the thrust to finish before the next one can start.
      if (speed < c.rearmSpeed) a.spent = false;
      return speed;
    }
    if (!a.extending && speed >= c.startSpeed) {
      a.extending = true;
      a.startExt = prev;
    }
    if (a.extending) {
      if (ext - a.startExt >= c.minTravel) {
        a.extending = false;
        a.spent = true;
        if (ts >= a.cooldownUntil) {
          a.cooldownUntil = ts + c.cooldownMs;
          out.add(GestureEvent(DetectorIds.punch, GesturePhase.fired, ts,
              side: side, strength: speed / c.startSpeed));
        }
      } else if (speed < c.rearmSpeed) {
        a.extending = false; // stalled short: not a punch
      }
    }
    return speed;
  }

  @override
  void interrupt(int timestampMs, List<MotionEvent> out) {
    _left.reset();
    _right.reset();
    _lastMs = null;
  }
}

// --------------------------------------------------------------- twist

class TwistConfig {
  const TwistConfig({
    this.startDeg = 40,
    this.endDeg = 25,
    this.confirmFrames = 2,
    this.heldIntervalMs = 100,
    this.minDepthTorso = 0.08,
    this.minVisibility = 0.5,
  });

  /// Torso rotation that starts a twist, and the level it ends below.
  final double startDeg;
  final double endDeg;
  final int confirmFrames;
  final int heldIntervalMs;

  /// Shoulder depth difference (torso lengths) needed to say which way the
  /// player turned; below it the twist has no side.
  final double minDepthTorso;
  final double minVisibility;
}

/// Twist: the torso turns away from the camera. Rotation is read from how
/// much the shoulder line has narrowed against the calibrated shoulder
/// width (cos θ = seen / real). The direction comes from which shoulder is
/// nearer the camera; when depth cannot tell, the twist has no side.
class TwistDetector implements Recogniser {
  TwistDetector(this.cal, [this.c = const TwistConfig()]);
  CalibrationProfile cal;
  final TwistConfig c;

  bool _turned = false;
  BodySide? _side;
  int _confirm = 0;
  int _startMs = 0, _lastHeldMs = 0;
  double _measure = 0;

  @override
  String get id => DetectorIds.twist;
  @override
  String get state => _turned ? 'turned' : 'square';

  /// Rotation as a multiple of the start angle.
  @override
  double get measure => _measure;
  @override
  void recalibrate(CalibrationProfile c) => cal = c;

  /// Torso rotation in degrees (0 = square to the camera), or null when
  /// the shoulders or hips are not visible.
  double? rotation(BodyFeatures b) {
    final v = c.minVisibility;
    if (b.leftShoulder.visibility < v ||
        b.rightShoulder.visibility < v ||
        b.hipVisibility < v ||
        !(b.torsoLength > 1e-5)) {
      return null;
    }
    final ratio =
        (b.shoulderWidth / b.torsoLength) / cal.shoulderWidthTorso;
    return math.acos(ratio.clamp(0.0, 1.0)) * 180 / math.pi;
  }

  @override
  void update(BodyFeatures b, List<MotionEvent> out) {
    final ts = b.timestampMs;
    final deg = rotation(b);
    if (deg == null) {
      _confirm = 0;
      _measure = 0;
      if (_turned) interrupt(ts, out);
      return;
    }
    _measure = deg / c.startDeg;
    if (!_turned) {
      if (deg < c.startDeg) {
        _confirm = 0;
        return;
      }
      if (++_confirm < c.confirmFrames) return;
      _confirm = 0;
      _turned = true;
      _startMs = _lastHeldMs = ts;
      final dz = (b.rightShoulder.z - b.leftShoulder.z) *
          b.aspect /
          b.torsoLength;
      // Right shoulder nearer the camera: the chest faces the player's left.
      _side = dz.abs() < c.minDepthTorso
          ? null
          : (dz < 0 ? BodySide.left : BodySide.right);
      out.add(GestureEvent(DetectorIds.twist, GesturePhase.started, ts,
          side: _side, strength: _measure));
      return;
    }
    if (deg < c.endDeg) {
      _turned = false;
      out.add(GestureEvent(DetectorIds.twist, GesturePhase.ended, ts,
          side: _side, heldMs: ts - _startMs));
    } else if (ts - _lastHeldMs >= c.heldIntervalMs) {
      _lastHeldMs = ts;
      out.add(GestureEvent(DetectorIds.twist, GesturePhase.held, ts,
          side: _side, heldMs: ts - _startMs, strength: _measure));
    }
  }

  @override
  void interrupt(int timestampMs, List<MotionEvent> out) {
    if (_turned) {
      out.add(GestureEvent(DetectorIds.twist, GesturePhase.ended, timestampMs,
          side: _side, heldMs: timestampMs - _startMs, completed: false));
    }
    _turned = false;
    _confirm = 0;
  }
}

// ----------------------------------------------------------- knee lift

class KneeLiftConfig {
  const KneeLiftConfig({
    this.liftTorso = 0.25,
    this.rearmTorso = 0.10,
    this.cooldownMs = 200,
    this.minVisibility = 0.5,
  });

  /// Height difference between the knees (torso lengths) that is a lift.
  final double liftTorso;

  /// … and the difference below which the next lift can count.
  final double rearmTorso;
  final int cooldownMs;
  final double minVisibility;
}

/// Knee lift (a marching step on the spot): one knee rises above the other.
/// Uses the difference between the two knees, so a squat (both drop) or a
/// camera nudge (both move) never counts. Fires once per lift with the
/// lifted [GestureEvent.side]; the knees must come level before the next.
class KneeLiftDetector implements Recogniser {
  KneeLiftDetector(this.cal, [this.c = const KneeLiftConfig()]);
  CalibrationProfile cal;
  final KneeLiftConfig c;

  BodySide? _lifted;
  int _cooldownUntil = -1 << 30;
  double _measure = 0;

  @override
  String get id => DetectorIds.kneeLift;
  @override
  String get state => _lifted?.name ?? 'level';

  /// Knee height difference as a signed multiple of the lift threshold
  /// (positive = the player's left knee is higher).
  @override
  double get measure => _measure;
  @override
  void recalibrate(CalibrationProfile c) => cal = c;

  @override
  void update(BodyFeatures b, List<MotionEvent> out) {
    final v = c.minVisibility;
    if (b.leftKnee.visibility < v ||
        b.rightKnee.visibility < v ||
        b.hipVisibility < v) {
      _measure = 0;
      return; // cannot tell: keep the state
    }
    final ts = b.timestampMs;
    final diff = (b.rightKnee.y - b.leftKnee.y) / cal.standingTorso;
    _measure = diff / c.liftTorso;
    if (_lifted != null) {
      if (diff.abs() < c.rearmTorso) {
        _lifted = null;
        _cooldownUntil = ts + c.cooldownMs;
      }
      return;
    }
    if (diff.abs() >= c.liftTorso && ts >= _cooldownUntil) {
      final side = diff > 0 ? BodySide.left : BodySide.right;
      _lifted = side;
      out.add(GestureEvent(DetectorIds.kneeLift, GesturePhase.fired, ts,
          side: side, strength: diff.abs() / c.liftTorso));
    }
  }

  @override
  void interrupt(int timestampMs, List<MotionEvent> out) {
    _lifted = null;
  }
}
