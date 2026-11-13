import 'dart:math' as math;

import 'landmarks.dart';

class SubjectLockConfig {
  const SubjectLockConfig({
    this.maxJumpTorso = 0.6,
    this.maxSpeedTorsoPerS = 3.0,
    this.maxScaleRatio = 2.5,
    this.reacquireAfterMs = 600,
  });

  /// A body whose torso centre is further than this (in torso lengths) from
  /// the locked player, plus what [maxSpeedTorsoPerS] allows for the time
  /// since the player was last seen, is somebody else.
  final double maxJumpTorso;

  /// Fastest plausible travel of the player's torso, in torso lengths per
  /// second (3 is about 1.5 m/s: a quick side shuffle).
  final double maxSpeedTorsoPerS;

  /// Largest plausible torso-length ratio between two sightings. Loose on
  /// purpose: a forward bend halves the 2-D torso.
  final double maxScaleRatio;

  /// When the locked player has not been seen for this long, the most
  /// prominent body in view becomes the player.
  final int reacquireAfterMs;
}

/// Keeps the game locked onto one person.
///
/// The pose estimator may report several people, or (with one pose) jump to
/// a bystander when the player is briefly hidden. The lock follows the body
/// that continues the player's own track; a body that appears somewhere
/// else is ignored until the player has been gone for
/// [SubjectLockConfig.reacquireAfterMs]. While only strangers are visible
/// the frame is reported as person-less, so a passer-by can never play the
/// game or disturb the calibration.
class SubjectLock {
  SubjectLock([this.config = const SubjectLockConfig()]);

  final SubjectLockConfig config;

  double? _cx, _cy, _scale;
  int _seenMs = 0;

  /// How many times a body other than the locked player was ignored.
  int rejected = 0;

  bool get locked => _cx != null;

  void reset() {
    _cx = _cy = _scale = null;
    _seenMs = 0;
  }

  /// Returns [f] reduced to the primary player's landmarks (with
  /// [PoseFrame.others] dropped), or a person-less frame.
  PoseFrame select(PoseFrame f) {
    final ts = f.timestampMs;
    if (!f.hasPerson) {
      if (locked && ts - _seenMs > config.reacquireAfterMs) reset();
      return f;
    }
    final aspect = f.aspect;
    final single = f.others.isEmpty;

    if (locked) {
      // Time since the player was seen; a clock that went backwards (a new
      // recording, a restarted camera) starts a new track.
      final gap = ts - _seenMs;
      if (gap < 0 || gap > config.reacquireAfterMs) {
        reset();
      } else {
        final allowed =
            config.maxJumpTorso + config.maxSpeedTorsoPerS * gap / 1000.0;
        List<Landmark>? best;
        var bestCost = double.infinity;
        var bx = 0.0, by = 0.0, bs = 0.0;
        void consider(List<Landmark> lm) {
          final (x, y, s) = _torso(lm, aspect);
          if (!(s > 0)) return;
          final ratio = s > _scale! ? s / _scale! : _scale! / s;
          if (ratio > config.maxScaleRatio) return;
          final dx = x - _cx!, dy = y - _cy!;
          final cost = math.sqrt(dx * dx + dy * dy) / _scale!;
          if (cost <= allowed && cost < bestCost) {
            best = lm;
            bestCost = cost;
            bx = x;
            by = y;
            bs = s;
          }
        }

        consider(f.landmarks);
        for (final o in f.others) {
          consider(o);
        }
        final chosen = best;
        if (chosen != null) {
          _cx = bx;
          _cy = by;
          _scale = bs;
          _seenMs = ts;
          return single ? f : f.withLandmarks(chosen);
        }
        // Only strangers in view: wait for the player.
        rejected++;
        return f.withLandmarks(const <Landmark>[]);
      }
    }

    // No lock: take the most prominent body (large, central, visible).
    List<Landmark>? top;
    var topScore = 0.0;
    var tx = 0.0, ty = 0.0, tscale = 0.0;
    void rank(List<Landmark> lm) {
      final (x, y, s) = _torso(lm, aspect);
      if (!(s > 0)) return;
      var vis = 1.0;
      for (final i in Lm.core) {
        vis = math.min(vis, lm[i].visibility);
      }
      final off = (x / aspect - 0.5).abs().clamp(0.0, 0.5).toDouble();
      final score = s * (1 - off) * (0.25 + 0.75 * vis.clamp(0.0, 1.0));
      if (score > topScore) {
        top = lm;
        topScore = score;
        tx = x;
        ty = y;
        tscale = s;
      }
    }

    rank(f.landmarks);
    for (final o in f.others) {
      rank(o);
    }
    final picked = top;
    if (picked == null) return f.withLandmarks(const <Landmark>[]);
    _cx = tx;
    _cy = ty;
    _scale = tscale;
    _seenMs = ts;
    return single ? f : f.withLandmarks(picked);
  }

  /// Torso centre (x aspect-corrected) and torso length of one body.
  static (double, double, double) _torso(List<Landmark> lm, double aspect) {
    final ls = lm[Lm.leftShoulder], rs = lm[Lm.rightShoulder];
    final lh = lm[Lm.leftHip], rh = lm[Lm.rightHip];
    final sx = (ls.x + rs.x) / 2 * aspect, sy = (ls.y + rs.y) / 2;
    final hx = (lh.x + rh.x) / 2 * aspect, hy = (lh.y + rh.y) / 2;
    final dx = sx - hx, dy = sy - hy;
    // Shoulder width keeps the scale meaningful in a deep forward bend.
    final wx = (ls.x - rs.x) * aspect, wy = ls.y - rs.y;
    final scale = math.max(
      math.sqrt(dx * dx + dy * dy),
      math.sqrt(wx * wx + wy * wy) * 0.8,
    );
    return ((sx + hx) / 2, (sy + hy) / 2, scale);
  }
}

/// Makes "left" always mean the player's own left (smaller x in the
/// mirrored selfie frame).
///
/// A pose model labels left and right from what the person in the image
/// looks like. Depending on whether the image was mirrored before or after
/// inference, a player facing the camera can arrive with the left/right
/// landmark indices exchanged. This watches which shoulder index is on
/// which side and, when the evidence is sustained, swaps every left/right
/// pair so the rest of the engine sees one convention. The decision is
/// sticky (leaky integrator with hysteresis), so a twist or a crossed arm
/// never flips it.
class FacingCanonicaliser {
  FacingCanonicaliser({this.settleMs = 400, this.minSeparationTorso = 0.3});

  /// Time constant of the evidence integrator.
  final int settleMs;

  /// Shoulders closer together than this (in torso lengths, e.g. side-on)
  /// give no evidence.
  final double minSeparationTorso;

  double _evidence = 0; // −1 = indices exchanged, +1 = canonical
  bool _decided = false;
  bool _swap = false;
  int? _lastMs;

  /// True while left/right pairs are being exchanged.
  bool get swapping => _swap;

  void reset() {
    _evidence = 0;
    _decided = false;
    _swap = false;
    _lastMs = null;
  }

  PoseFrame apply(PoseFrame f) {
    if (!f.hasPerson) return f;
    final ls = f[Lm.leftShoulder], rs = f[Lm.rightShoulder];
    final lh = f[Lm.leftHip], rh = f[Lm.rightHip];
    final a = f.aspect;
    final tx = ((ls.x + rs.x) - (lh.x + rh.x)) / 2 * a;
    final ty = ((ls.y + rs.y) - (lh.y + rh.y)) / 2;
    final torso = math.sqrt(tx * tx + ty * ty);
    final ts = f.timestampMs;
    final last = _lastMs;
    _lastMs = ts;
    if (torso > 1e-6 && ls.visibility >= 0.5 && rs.visibility >= 0.5) {
      final sep = (rs.x - ls.x) * a / torso;
      if (sep.abs() >= minSeparationTorso) {
        final vote = sep > 0 ? 1.0 : -1.0;
        if (!_decided) {
          _decided = true;
          _evidence = vote;
          _swap = vote < 0;
        } else {
          final dt = last == null ? 0 : (ts - last).clamp(0, 100);
          final k = (dt / settleMs).clamp(0.0, 1.0);
          _evidence += (vote - _evidence) * k;
          if (_swap && _evidence > 0.8) _swap = false;
          if (!_swap && _evidence < -0.8) _swap = true;
        }
      }
    }
    if (!_swap) return f;
    final out = List<Landmark>.of(f.landmarks, growable: false);
    for (final (l, r) in Lm.pairs) {
      final t = out[l];
      out[l] = out[r];
      out[r] = t;
    }
    return f.withLandmarks(out);
  }
}
