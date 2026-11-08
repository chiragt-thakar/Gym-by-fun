import 'package:motion_core/motion_core.dart';

import 'director.dart';
import 'level.dart';

enum Outcome {
  /// Answered correctly: points.
  cleared,

  /// Wrong or no answer: a heart lost (orbs: just missed).
  hit,

  /// Tracking was lost while it mattered: no damage, no points.
  forgiven,
}

/// Counts outcomes, never raw moves. Checkpoint replays cannot farm progress;
/// camera-forgiven opportunities reduce the target rather than penalising it.
class MissionTracker {
  MissionTracker(this.config, List<PlannedEncounter> plan) {
    if (config != null) {
      for (final p in plan) {
        if (_matches(p.type)) _eligible.add(p.index);
      }
    }
  }
  final LevelGameplay? config;
  final _eligible = <int>{}, _cleared = <int>{}, _forgiven = <int>{};
  bool complete = false;
  bool get enabled => config != null;
  int get count => _cleared.length;
  int get goal => config == null
      ? 0
      : ((_eligible.length - _forgiven.length) * config!.targetFraction).ceil();
  double get progress => goal == 0 ? 0 : (count / goal).clamp(0, 1).toDouble();
  bool _matches(EncounterType type) => switch (config!.mission) {
        MissionKind.lights => type == EncounterType.orb,
        MissionKind.gates => type == EncounterType.gate,
        MissionKind.path => type.damages,
      };
  void resolve(PlannedEncounter encounter, Outcome outcome) {
    if (!_eligible.contains(encounter.index)) return;
    if (outcome == Outcome.cleared) {
      _cleared.add(encounter.index);
      _forgiven.remove(encounter.index);
    } else if (outcome == Outcome.forgiven &&
        !_cleared.contains(encounter.index)) {
      _forgiven.add(encounter.index);
    }
    if (goal > 0 && count >= goal) complete = true;
  }
}

/// Things the renderer, audio and HUD react to.
sealed class RunEvent {
  const RunEvent(this.atMs);
  final int atMs;
}

class CuePlayed extends RunEvent {
  const CuePlayed(super.atMs, this.encounter);
  final PlannedEncounter encounter;
  String get sound => encounter.type.soundCue;
}

class HintShown extends RunEvent {
  const HintShown(super.atMs, this.text);
  final String text;
}

class EncounterResolved extends RunEvent {
  const EncounterResolved(
      super.atMs, this.encounter, this.outcome, this.points);
  final PlannedEncounter encounter;
  final Outcome outcome;
  final int points;
}

class LaneChanged extends RunEvent {
  const LaneChanged(super.atMs, this.lane);
  final int lane;
}

class HeartsChanged extends RunEvent {
  const HeartsChanged(super.atMs, this.hearts);
  final int hearts;
}

class CheckpointReached extends RunEvent {
  const CheckpointReached(super.atMs);
}

class SegmentStarted extends RunEvent {
  const SegmentStarted(super.atMs, this.segment);
  final Segment segment;
}

class TrackingHint extends RunEvent {
  const TrackingHint(super.atMs, this.issue);

  /// null = tracking is back.
  final TrackingIssue? issue;
}

class RunFinished extends RunEvent {
  const RunFinished(super.atMs, this.result);
  final RunResult result;
}

class RunResult {
  const RunResult({
    required this.levelId,
    required this.completed,
    required this.score,
    required this.hearts,
    required this.cleared,
    required this.hit,
    required this.forgiven,
    required this.energy,
    required this.reps,
    required this.gameMs,
    required this.activeMs,
    required this.difficulty,
    required this.lowImpact,
    this.missionWon = false,
    this.missionCount = 0,
    this.missionGoal = 0,
  });

  final String levelId;
  final bool completed;
  final int score;
  final int hearts;
  final int cleared;
  final int hit;
  final int forgiven;
  final int energy;
  final Map<Move, int> reps;

  /// Level clock reached, and wall-clock time actually moving.
  final int gameMs;
  final int activeMs;
  final Difficulty difficulty;
  final bool lowImpact;
  final bool missionWon;
  final int missionCount, missionGoal;

  int get movesDone => reps.values.fold(0, (a, b) => a + b);

  Map<String, Object> toJson() => {
        'levelId': levelId,
        'completed': completed,
        'score': score,
        'hearts': hearts,
        'cleared': cleared,
        'hit': hit,
        'forgiven': forgiven,
        'energy': energy,
        'reps': {for (final e in reps.entries) e.key.name: e.value},
        'gameMs': gameMs,
        'activeMs': activeMs,
        'difficulty': difficulty.name,
        'lowImpact': lowImpact,
        'missionWon': missionWon,
        'missionCount': missionCount,
        'missionGoal': missionGoal,
      };
}

/// The rules of a run, independent of rendering.
///
/// Feed it motion events with [input] and time with [advance]. A recognised
/// move does nothing on its own (rule 6): a squat only matters if a beam is
/// arriving. A tracking failure never costs a heart (rule 5).
class RunEngine {
  RunEngine(this.level, this.settings)
      : director = Director(level, settings),
        hearts = level.hearts {
    plan = director.plan();
    mission = MissionTracker(level.gameplay, plan);
    lane = level.lanes ~/ 2;
  }

  final LevelConfig level;
  final RunSettings settings;
  final Director director;
  late final List<PlannedEncounter> plan;
  late final MissionTracker mission;

  final Pacer pacer = Pacer();

  int hearts;
  late int lane;
  int score = 0;
  int energy = 0;
  int streak = 0;
  int cleared = 0, hit = 0, forgiven = 0;
  final Map<Move, int> reps = {for (final m in Move.values) m: 0};

  /// Level clock (slows and stops with tracking quality).
  double clockMs = 0;
  int activeMs = 0;
  int _wallMs = 0;

  bool ducking = false;
  bool armsUp = false;
  int? _lastRaiseWall;
  int? _lastSquatEndWall;
  TrackingLight _light = TrackingLight.green;

  /// Last level-clock time at which tracking was lost (red).
  int? _lastLostClock;

  /// Last wall-clock time at which tracking was lost (red). The level clock
  /// is slowed or stopped around a loss, so reaction time after recovery is
  /// measured in wall time.
  int? _lastLostWall;

  /// Wall-clock time each planned encounter's cue was (last) played.
  late final List<int?> _cueWall = List.filled(plan.length, null);

  int _nextCue = 0;
  int _nextResolve = 0;
  bool _checkpointDone = false;
  bool _checkpointSaved = false;
  Segment? _segment;
  bool finished = false;

  /// Grace windows (wall-clock ms), widened in assist mode.
  int get _raiseWindowMs => settings.assist ? 900 : 600;
  int get _squatGraceMs => settings.assist ? 400 : 200;

  /// Wall-clock green tracking the player needs before an arrival for it to
  /// be judged; less than this after a loss and the encounter is forgiven.
  int get _reactionMs => settings.assist ? 1200 : 800;

  /// Level-clock margin before a cue in which a loss still forgives it (a
  /// loss just before the cue means the cue may have been missed).
  static const _cueMarginMs = 300;

  bool get atCheckpoint => _checkpointSaved;

  TrackingLight get light => _light;

  /// Motion events from the motion engine.
  List<RunEvent> input(MotionEvent e) {
    final out = <RunEvent>[];
    if (finished) return out;
    final at = clockMs.round();
    switch (e) {
      case MoveStarted(move: Move.squat):
        ducking = true;
      case MoveEnded(move: Move.squat):
        ducking = false;
        _lastSquatEndWall = _wallMs;
      case MoveStarted(move: Move.leanLeft):
        if (lane > 0) out.add(LaneChanged(at, --lane));
      case MoveStarted(move: Move.leanRight):
        if (lane < level.lanes - 1) out.add(LaneChanged(at, ++lane));
      case MoveStarted(move: Move.raiseArms):
        armsUp = true;
        _lastRaiseWall = _wallMs;
      case MoveEnded(move: Move.raiseArms):
        armsUp = false;
      case RepCompleted(:final move):
        reps[move] = reps[move]! + 1;
      case TrackingPaused(:final issue):
        _light = TrackingLight.red;
        _lastLostClock = at;
        _lastLostWall = _wallMs;
        ducking = false;
        armsUp = false;
        out.add(TrackingHint(at, issue));
      case TrackingResumed():
        _light = TrackingLight.green;
        out.add(TrackingHint(at, null));
      default:
        break;
    }
    return out;
  }

  /// Amber light from the engine (shaky tracking) slows the world a little.
  void setLight(TrackingLight l) {
    if (_light == TrackingLight.red && l != TrackingLight.red) {
      // Resume handled by TrackingResumed; ignore amber flicker meanwhile.
      if (l == TrackingLight.amber) return;
    }
    _light = l;
  }

  /// Advances wall time by [dtMs]; the level clock advances by dt × pace.
  List<RunEvent> advance(int dtMs) {
    final out = <RunEvent>[];
    if (finished) return out;
    _wallMs += dtMs;
    final scale = pacer.update(dtMs, _light.index);
    if (scale > 0) activeMs += dtMs;
    clockMs += dtMs * scale;
    final now = clockMs.round();
    if (_light == TrackingLight.red) {
      _lastLostClock = now;
      _lastLostWall = _wallMs;
    }

    final seg = level.segmentAt(now);
    if (seg != null && seg != _segment) {
      _segment = seg;
      out.add(SegmentStarted(now, seg));
      if (seg.hint != null) out.add(HintShown(now, seg.hint!));
    }

    while (_nextCue < plan.length && plan[_nextCue].warnMs <= now) {
      _cueWall[_nextCue] = _wallMs;
      final p = plan[_nextCue++];
      out.add(CuePlayed(now, p));
      if (p.hint != null) out.add(HintShown(now, p.hint!));
    }

    while (_nextResolve < plan.length && plan[_nextResolve].arriveMs <= now) {
      final i = _nextResolve++;
      out.addAll(_resolve(plan[i], now, _cueWall[i]));
      if (finished) return out;
    }

    final cp = level.checkpoint;
    if (cp != null && !_checkpointDone && now >= cp.startMs) {
      _checkpointDone = true;
      _checkpointSaved = true;
      out.add(CheckpointReached(now));
      if (hearts < level.hearts) {
        hearts++;
        out.add(HeartsChanged(now, hearts));
      }
    }

    if (now >= level.durationMs && _nextResolve >= plan.length) {
      out.add(_finish(now, completed: true));
    }
    return out;
  }

  List<RunEvent> _resolve(PlannedEncounter p, int now, int? cueWall) {
    final out = <RunEvent>[];
    // Forgiven (rule 5) when the player could not have answered fairly:
    // tracking is lost now, was lost at any point from just before the cue
    // to arrival (level clock), or the player has had less than a reaction
    // time of tracked play since the cue or since tracking came back (wall
    // clock: the level clock was slowed or stopped meanwhile).
    final greenSinceWall = [
      if (cueWall != null) cueWall,
      if (_lastLostWall != null) _lastLostWall!,
    ].fold<int?>(null, (a, b) => a == null || b > a ? b : a);
    final trackingLost = _light == TrackingLight.red ||
        (_lastLostClock != null &&
            _lastLostClock! >= p.warnMs - _cueMarginMs) ||
        (greenSinceWall != null && _wallMs - greenSinceWall < _reactionMs);
    Outcome outcome;
    if (trackingLost) {
      outcome = Outcome.forgiven;
    } else {
      final ok = switch (p.type) {
        EncounterType.beam => ducking ||
            (_lastSquatEndWall != null &&
                _wallMs - _lastSquatEndWall! <= _squatGraceMs),
        EncounterType.laneBlock => !p.lanes.contains(lane),
        EncounterType.orb => p.lanes.contains(lane) && _raisedRecently,
        EncounterType.gate => _raisedRecently,
      };
      outcome = ok ? Outcome.cleared : Outcome.hit;
    }

    var points = 0;
    switch (outcome) {
      case Outcome.cleared:
        streak++;
        cleared++;
        final mult = 1 + (streak.clamp(0, 10) / 10);
        points = (level.scoring[p.type]! * mult).round();
        score += points;
        if (p.type == EncounterType.orb) energy++;
      case Outcome.hit:
        streak = 0;
        if (p.type.damages) {
          hit++;
          hearts--;
          out.add(HeartsChanged(now, hearts));
        }
      case Outcome.forgiven:
        forgiven++;
    }
    out.add(EncounterResolved(now, p, outcome, points));
    mission.resolve(p, outcome);
    if (hearts <= 0) out.add(_finish(now, completed: false));
    return out;
  }

  bool get _raisedRecently =>
      armsUp ||
      (_lastRaiseWall != null && _wallMs - _lastRaiseWall! <= _raiseWindowMs);

  /// After running out of hearts past the checkpoint, continue from there.
  ///
  /// Only valid once the run has ended on hearts; calling it again before
  /// another loss does nothing, so hearts cannot be refilled twice. All
  /// transient state is reset so nothing from the failed attempt (an old
  /// tracking loss, a held squat, a streak) carries over, and the
  /// checkpoint segment and its hint replay.
  bool restartFromCheckpoint() {
    final cp = level.checkpoint;
    if (!_checkpointSaved || cp == null || !finished || hearts > 0) {
      return false;
    }
    finished = false;
    hearts = level.hearts;
    clockMs = cp.startMs.toDouble();
    _light = TrackingLight.green;
    _lastLostClock = null;
    _lastLostWall = null;
    ducking = false;
    armsUp = false;
    _lastRaiseWall = null;
    _lastSquatEndWall = null;
    streak = 0;
    _segment = null;
    pacer.reset();
    _nextResolve = plan.indexWhere((p) => p.arriveMs >= cp.startMs);
    if (_nextResolve < 0) _nextResolve = plan.length;
    _nextCue = plan.indexWhere((p) => p.warnMs >= cp.startMs);
    if (_nextCue < 0) _nextCue = plan.length;
    // Encounters still to resolve get their cue again.
    if (_nextResolve < _nextCue) _nextCue = _nextResolve;
    return true;
  }

  RunFinished _finish(int now, {required bool completed}) {
    finished = true;
    return RunFinished(now, result(completed: completed, now: now));
  }

  RunResult result({required bool completed, int? now}) => RunResult(
        levelId: level.id,
        completed: completed,
        score: score,
        hearts: hearts,
        cleared: cleared,
        hit: hit,
        forgiven: forgiven,
        energy: energy,
        reps: Map.unmodifiable(reps),
        gameMs: now ?? clockMs.round(),
        activeMs: activeMs,
        difficulty: settings.difficulty,
        lowImpact: director.lowImpact,
        missionWon: mission.complete,
        missionCount: mission.count,
        missionGoal: mission.goal,
      );
}
