import 'package:motion_core/motion_core.dart';

import 'director.dart';
import 'level.dart';
import 'run_engine.dart';

/// A scripted player used to prove that every level is finishable at every
/// difficulty. It hears each cue, waits its reaction time, and performs the
/// move with realistic durations.
class BotProfile {
  const BotProfile({
    required this.name,
    this.reactionMs = 450,
    this.squatDownMs = 300,
    this.leanMs = 250,
    this.leanGapMs = 380,
    this.raiseMs = 300,
    this.holdAfterArrivalMs = 250,
    this.ignoreEvery = 0,
    this.dropouts = const [],
  });

  final String name;

  /// From cue to starting to move.
  final int reactionMs;

  /// From starting to move to the motion core confirming it.
  final int squatDownMs;
  final int leanMs;

  /// Between consecutive leans (recogniser cooldown + re-arm).
  final int leanGapMs;

  /// Arm travel + the 150 ms hold.
  final int raiseMs;
  final int holdAfterArrivalMs;

  /// If > 0, the bot ignores every n-th encounter (a distracted player).
  final int ignoreEvery;

  /// Tracking dropouts: (level-clock start ms, wall duration ms).
  final List<(int, int)> dropouts;

  static const competent = BotProfile(name: 'competent');
  static const slow = BotProfile(
      name: 'slow beginner',
      reactionMs: 650,
      squatDownMs: 450,
      leanMs: 350,
      leanGapMs: 450,
      raiseMs: 400);
}

class Feasibility {
  const Feasibility(this.encounter, this.slackMs);
  final PlannedEncounter encounter;

  /// Time to spare between the move being confirmed and arrival.
  final int slackMs;
  bool get ok => slackMs >= 0;
  @override
  String toString() => '$encounter slack=${slackMs}ms';
}

class SimResult {
  const SimResult(this.result, this.feasibility, this.events);
  final RunResult result;
  final List<Feasibility> feasibility;
  final List<RunEvent> events;
  bool get allFeasible => feasibility.every((f) => f.ok);
  Iterable<Feasibility> get infeasible => feasibility.where((f) => !f.ok);
}

class _Scheduled {
  _Scheduled(this.at, this.event, {this.wall = false});
  final int at;
  final MotionEvent event;
  final bool wall;
}

/// Runs a whole level with a bot, 16 ms per tick, deterministically.
SimResult simulate(LevelConfig level, RunSettings settings, BotProfile bot,
    {int tickMs = 16}) {
  final engine = RunEngine(level, settings);
  final queue = <_Scheduled>[];
  final feas = <Feasibility>[];
  final log = <RunEvent>[];
  var botLane = engine.lane;
  var busyUntil = 0; // bot can't start a new action before this clock time
  var wall = 0;
  var handled = 0;

  for (final (start, _) in bot.dropouts) {
    queue.add(
        _Scheduled(start, TrackingPaused(start, TrackingIssue.outOfFrame)));
  }

  void schedule(int at, MotionEvent e) => queue.add(_Scheduled(at, e));

  void respond(PlannedEncounter p) {
    handled++;
    if (bot.ignoreEvery > 0 && handled % bot.ignoreEvery == 0) return;
    var t = p.warnMs + bot.reactionMs;
    if (t < busyUntil) t = busyUntil;
    int confirmed;
    switch (p.type) {
      case EncounterType.beam:
        confirmed = t + bot.squatDownMs;
        schedule(confirmed, MoveStarted(Move.squat, confirmed));
        final up = p.arriveMs + bot.holdAfterArrivalMs;
        schedule(up, MoveEnded(Move.squat, up));
        schedule(up, RepCompleted(Move.squat, up, up - confirmed));
        busyUntil = up + 150;
      case EncounterType.laneBlock:
        final free = [
          for (var l = 0; l < level.lanes; l++)
            if (!p.lanes.contains(l)) l
        ]..sort((a, b) => (a - botLane).abs().compareTo((b - botLane).abs()));
        final target = free.first;
        confirmed = t;
        while (botLane != target) {
          confirmed += bot.leanMs;
          final left = target < botLane;
          final m = left ? Move.leanLeft : Move.leanRight;
          schedule(confirmed, MoveStarted(m, confirmed));
          schedule(confirmed + 200, MoveEnded(m, confirmed + 200));
          botLane += left ? -1 : 1;
          confirmed += bot.leanGapMs - bot.leanMs;
        }
        busyUntil = confirmed + 100;
      case EncounterType.orb:
      case EncounterType.gate:
        confirmed = t;
        if (p.type == EncounterType.orb && !p.lanes.contains(botLane)) {
          // Lean towards the orb first.
          final target = p.lanes.first;
          while (botLane != target) {
            confirmed += bot.leanMs;
            final left = target < botLane;
            final m = left ? Move.leanLeft : Move.leanRight;
            schedule(confirmed, MoveStarted(m, confirmed));
            schedule(confirmed + 200, MoveEnded(m, confirmed + 200));
            botLane += left ? -1 : 1;
            confirmed += bot.leanGapMs - bot.leanMs;
          }
        }
        confirmed += bot.raiseMs;
        // Players time the grab to the orb's arrival, not the cue.
        final timed = p.arriveMs - 250;
        if (confirmed < timed) confirmed = timed;
        schedule(confirmed, MoveStarted(Move.raiseArms, confirmed));
        final down = confirmed + 400;
        schedule(down, MoveEnded(Move.raiseArms, down));
        schedule(down, RepCompleted(Move.raiseArms, down, 400));
        busyUntil = down + 100;
    }
    feas.add(Feasibility(p, p.arriveMs - confirmed));
  }

  while (!engine.finished && wall < level.durationMs * 4) {
    final clock = engine.clockMs.round();
    queue.sort((a, b) => a.at.compareTo(b.at));
    final due = [
      for (final q in queue)
        if (q.wall ? q.at <= wall : q.at <= clock) q
    ];
    for (final s in due) {
      queue.remove(s);
      final evs = engine.input(s.event);
      log.addAll(evs);
      if (s.event is TrackingPaused) {
        final d = bot.dropouts.firstWhere((x) => x.$1 == s.at);
        queue.add(
            _Scheduled(wall + d.$2, TrackingResumed(wall + d.$2), wall: true));
      }
    }
    final evs = engine.advance(tickMs);
    wall += tickMs;
    for (final e in evs) {
      log.add(e);
      if (e is CuePlayed) respond(e.encounter);
    }
  }
  final result = log.whereType<RunFinished>().isEmpty
      ? engine.result(completed: false)
      : log.whereType<RunFinished>().last.result;
  return SimResult(result, feas, log);
}
