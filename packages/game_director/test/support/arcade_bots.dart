import 'dart:math' as math;

import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';

/// Emits motion-core events for a bot that wants a move held or released.
class BotMoves {
  final Set<Move> _on = {};
  List<MotionEvent> want(Set<Move> next, int ts) {
    final out = <MotionEvent>[
      for (final m in _on.difference(next)) MoveEnded(m, ts),
      for (final m in next.difference(_on)) MoveStarted(m, ts),
    ];
    _on
      ..clear()
      ..addAll(next);
    return out;
  }
}

typedef BotStep = (PoseFrame, Set<Move>);

/// Runs [e] with a bot choosing a pose (and held core moves) every frame.
void drive(ArcadeEngine e, BotStep Function(int clock) bot,
    {int maxMs = 600000, bool Function(int clock)? tracked}) {
  final moves = BotMoves();
  for (var t = 0; t < maxMs && !e.finished; t += 33) {
    final ok = tracked?.call(e.clockMs) ?? true;
    e.advance(33, tracked: ok);
    if (!ok) continue;
    final (frame, held) = bot(e.clockMs);
    for (final ev in moves.want(held, t)) {
      e.motion(ev);
    }
    e.pose(BodyPose.from(PoseFrame(
        timestampMs: t,
        landmarks: frame.landmarks,
        imageWidth: frame.imageWidth,
        imageHeight: frame.imageHeight)));
  }
}

final relaxed = stickFrame();
final padL = stickFrame(shoulderL: 90);
final padR = stickFrame(shoulderR: 90);
final armsUp = stickFrame(shoulderL: 175, shoulderR: 175);
final guard = stickFrame(shoulderL: 65, elbowL: 50, shoulderR: 65, elbowR: 50);
final hiL = stickFrame(shoulderL: 150);
final hiR = stickFrame(shoulderR: 150);
final clap = stickFrame(shoulderL: 35, elbowL: 70, shoulderR: 35, elbowR: 70);

BotStep fighter(DuelEngine e, int clock) {
  for (final a in e.asks) {
    if (a.resolved) continue;
    if ((clock - 100 - a.at).abs() > 90) continue;
    return switch (a.move) {
      DuelMove.duck => (relaxed, {Move.squat}),
      DuelMove.left => (relaxed, {Move.leanLeft}),
      DuelMove.right => (relaxed, {Move.leanRight}),
      DuelMove.guard => (guard, {}),
      DuelMove.padL => (padL, {}),
      DuelMove.padR => (padR, {}),
      DuelMove.charge => (armsUp, {Move.raiseArms}),
    };
  }
  return (relaxed, {});
}

final waveL = stickFrame(shoulderL: 120);
final waveR = stickFrame(shoulderR: 120);
final reachL = stickFrame(shoulderL: 160);
final reachR = stickFrame(shoulderR: 160);

BotStep dancer(TaalEngine e, int clock) {
  for (final c in e.cards) {
    if (c.done || (clock - 100 - c.at).abs() > 70) continue;
    return switch (c.move) {
      TaalMove.clap => (clap, {}),
      TaalMove.stepL => (relaxed, {Move.leanLeft}),
      TaalMove.stepR => (relaxed, {Move.leanRight}),
      TaalMove.waveL => (waveL, {}),
      TaalMove.waveR => (waveR, {}),
      TaalMove.reachL => (reachL, {}),
      TaalMove.reachR => (reachR, {}),
      TaalMove.dip => (relaxed, {Move.squat}),
      TaalMove.hoy => (armsUp, {Move.raiseArms}),
    };
  }
  return (relaxed, {});
}

/// A frame with one hand at body-space ([x], [y]) (torso units from the
/// shoulder centre, +y up) and the other resting by the side.
PoseFrame handAt(double x, double y, {bool left = false, int t = 0}) {
  final p = (0.375 + x * 0.18, 0.37 - y * 0.18);
  return stickFrame(
    t: t,
    override: left ? {15: p, 17: p, 19: p} : {16: p, 18: p, 20: p},
  );
}

/// A frame with both hands placed in body space.
PoseFrame handsAt((double, double) l, (double, double) r) {
  final lp = (0.375 + l.$1 * 0.18, 0.37 - l.$2 * 0.18);
  final rp = (0.375 + r.$1 * 0.18, 0.37 - r.$2 * 0.18);
  return stickFrame(
      override: {15: lp, 17: lp, 19: lp, 16: rp, 18: rp, 20: rp});
}

/// A careful Neon Slice player: each hand drifts (too slowly to cut) to
/// where its next fruit will peak, then sweeps straight through it. It
/// never sweeps where a mine is.
class SliceBot {
  SliceBot(this.e);
  final SliceEngine e;

  /// Per frame: under the slowest blade speed at 30 fps.
  static const _drift = 0.05;

  final _hand = <(double, double)>[(-0.7, 0.2), (0.7, 0.2)];
  final _skip = <int>{};

  BotStep step(int clock) {
    final at = clock - e.latencyMs;
    for (var h = 0; h < 2; h++) {
      _hand[h] = _move(h, at);
    }
    return (handsAt(_hand[0], _hand[1]), {});
  }

  (double, double) _move(int h, int at) {
    final (hx, hy) = _hand[h];
    for (final t in e.targets) {
      if (t.done || t.isBomb || _skip.contains(t.id)) continue;
      if (at < t.launchAt - 300 || t.progress(at) > 0.56) continue;
      final peakX = (t.x0 + t.x1) / 2;
      if ((peakX >= 0) != (h == 1)) continue;
      final u = t.progress(at);
      if (u >= 0.44 && t.reachable(at)) {
        final (x, y) = t.at(at);
        final ex = 2 * x - hx, ey = 2 * y - hy;
        final dx = x - hx, dy = y - hy;
        if (dx * dx + dy * dy > 0.75 * 0.75 || !_clear(hx, hy, ex, ey, at)) {
          _skip.add(t.id);
          continue;
        }
        return (ex, ey); // the sweep
      }
      // Drift to a spot beside the peak.
      final gx = peakX + (hx >= peakX ? 0.45 : -0.45), gy = t.apexY;
      final dx = gx - hx, dy = gy - hy;
      final d = dx * dx + dy * dy;
      if (d <= _drift * _drift) return (gx, gy);
      final k = _drift / math.sqrt(d);
      return (hx + dx * k, hy + dy * k);
    }
    return (hx, hy);
  }

  /// No mine near the sweep from (ax, ay) to (bx, by).
  bool _clear(double ax, double ay, double bx, double by, int at) {
    for (final t in e.targets) {
      if (!t.isBomb || t.done || !t.inFlight(at)) continue;
      final (px, py) = t.at(at);
      final vx = bx - ax, vy = by - ay;
      final l2 = vx * vx + vy * vy;
      final u = l2 == 0
          ? 0.0
          : (((px - ax) * vx + (py - ay) * vy) / l2).clamp(0.0, 1.0);
      final cx = ax + vx * u - px, cy = ay + vy * u - py;
      if (math.sqrt(cx * cx + cy * cy) < e.stage.radius + 0.4) return false;
    }
    return true;
  }
}
