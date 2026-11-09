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
