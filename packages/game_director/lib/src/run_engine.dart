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
    lane = level.lanes ~/ 2;
  }

  final LevelConfig level;
  final RunSettings settings;
  final Director director;
  late final List<PlannedEncounter> plan;

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

  int _nextCue = 0;
  int _nextResolve = 0;
  bool _checkpointDone = false;
  bool _checkpointSaved = false;
  Segment? _segment;
  bool finished = false;

  /// Grace windows (wall-clock ms), widened in assist mode.
  int get _raiseWindowMs => settings.assist ? 900 : 600;
  int get _squatGraceMs => settings.assist ? 400 : 200;

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
    if (_light == TrackingLight.red) _lastLostClock = now;

    final seg = level.segmentAt(now);
    if (seg != null && seg != _segment) {
      _segment = seg;
      out.add(SegmentStarted(now, seg));
      if (seg.hint != null) out.add(HintShown(now, seg.hint!));
    }

    while (_nextCue < plan.length && plan[_nextCue].warnMs <= now) {
      final p = plan[_nextCue++];
      out.add(CuePlayed(now, p));
      if (p.hint != null) out.add(HintShown(now, p.hint!));
    }

    while (_nextResolve < plan.length && plan[_nextResolve].arriveMs <= now) {
      out.addAll(_resolve(plan[_nextResolve++], now));
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

  List<RunEvent> _resolve(PlannedEncounter p, int now) {
    final out = <RunEvent>[];
    // Lost at any point between the cue and arrival: the player could not
    // have answered fairly, so it is forgiven.
    final trackingLost = _light == TrackingLight.red ||
        (_lastLostClock != null && _lastLostClock! >= p.warnMs);
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
    if (hearts <= 0) out.add(_finish(now, completed: false));
    return out;
  }

  bool get _raisedRecently =>
      armsUp ||
      (_lastRaiseWall != null && _wallMs - _lastRaiseWall! <= _raiseWindowMs);

  /// After running out of hearts past the checkpoint, continue from there.
  bool restartFromCheckpoint() {
    final cp = level.checkpoint;
    if (!_checkpointSaved || cp == null) return false;
    finished = false;
    hearts = level.hearts;
    clockMs = cp.startMs.toDouble();
    _nextCue = plan.indexWhere((p) => p.warnMs >= cp.startMs);
    if (_nextCue < 0) _nextCue = plan.length;
    _nextResolve = plan.indexWhere((p) => p.arriveMs >= cp.startMs);
    if (_nextResolve < 0) _nextResolve = plan.length;
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
      );
}
