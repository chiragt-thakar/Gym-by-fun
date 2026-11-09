import 'dart:math' as math;

import 'package:motion_core/motion_core.dart';

import 'arcade.dart';

/// TAPEBALL TAMASHA — gully cricket in the living room. Golu bowls; swing
/// across your body as the ring closes, leave the wide ones with arms up,
/// or block with a guard. Seeded deliveries make every format fair.

enum BallLine { off, middle, leg, wide }

enum Shot { drive, lofted, defend, leave, none }

class CricketFormat {
  const CricketFormat({
    required this.id,
    required this.name,
    required this.balls,
    this.wickets = 0,
    this.target,
    this.seed = 7,
    this.wideShare = 0.15,
    this.blurb = '',
  });
  final String id;
  final String name;
  final int balls;

  /// 0 = nets: no outs.
  final int wickets;

  /// Runs to chase, if any.
  final int? target;
  final int seed;
  final double wideShare;
  final String blurb;

  factory CricketFormat.fromJson(Map<String, dynamic> j) => CricketFormat(
        id: j['id'] as String,
        name: j['name'] as String,
        balls: (j['balls'] as num).toInt(),
        wickets: (j['wickets'] as num?)?.toInt() ?? 0,
        target: (j['target'] as num?)?.toInt(),
        seed: (j['seed'] as num?)?.toInt() ?? 7,
        wideShare: (j['wideShare'] as num?)?.toDouble() ?? 0.15,
        blurb: j['blurb'] as String? ?? '',
      );
}

/// Outcome table: shot → grade → weighted results. A result is runs (0–6)
/// or -1 for caught. Loaded from JSON so balance is content, not code.
class OutcomeTable {
  const OutcomeTable(this.rows);
  final Map<String, Map<String, List<(int, double)>>> rows;

  factory OutcomeTable.fromJson(Map<String, dynamic> j) => OutcomeTable({
        for (final shot in j.entries)
          shot.key: {
            for (final g in (shot.value as Map).entries)
              g.key as String: [
                for (final r in g.value as List<dynamic>)
                  (
                    ((r as List<dynamic>)[0] as num).toInt(),
                    (r[1] as num).toDouble(),
                  ),
              ],
          },
      });

  int roll(String shot, Grade g, double r, {required bool outsAllowed}) {
    final options = rows[shot]?[g.name] ?? const [(0, 1.0)];
    final usable = [
      for (final o in options)
        if (outsAllowed || o.$1 >= 0) o,
    ];
    final total = usable.fold<double>(0, (a, o) => a + o.$2);
    var x = r * total;
    for (final o in usable) {
      x -= o.$2;
      if (x <= 0) return o.$1;
    }
    return usable.isEmpty ? 0 : usable.last.$1;
  }
}

class Delivery {
  Delivery(this.number, this.line, this.arriveAt);
  final int number;
  final BallLine line;
  final int arriveAt;
  Shot shot = Shot.none;
  Grade? grade;

  /// Runs scored, or -1 caught, -2 bowled.
  int? result;
  bool dead = false;
}

class CricketEngine with ArcadeClock implements ArcadeEngine {
  CricketEngine(
    this.format,
    this.outcomes, {
    this.difficulty = 'beginner',
    this.lowImpact = true,
    this.latencyMs = 100,
  })  : _rng = SeededRandom(format.seed),
        _swing = SwingRecogniser(lowImpact
            ? const SwingThresholds.lowImpact()
            : const SwingThresholds()) {
    telegraphMs = switch (difficulty) {
      'advanced' => 1300,
      'intermediate' => 1600,
      _ => 2000,
    };
    window = switch (difficulty) {
      'advanced' => 300,
      'intermediate' => 380,
      _ => 550,
    };
    _queue();
  }

  final CricketFormat format;
  final OutcomeTable outcomes;
  final String difficulty;
  final bool lowImpact;
  final int latencyMs;
  final SeededRandom _rng;
  final SwingRecogniser _swing;
  late final int telegraphMs;
  late final int window;

  static const setMs = 1600;
  static const afterMs = 2600;

  final List<Delivery> deliveries = [];
  Delivery? current;

  /// 'set', 'runup', 'result', 'done'.
  String phase = 'set';
  int _phaseAt = 0;
  int runs = 0;
  int wickets = 0;
  int legal = 0;
  int combo = 0;
  int bestCombo = 0;
  int fours = 0, sixes = 0;
  int deadBalls = 0;
  int _guardFrames = 0;
  int _leaveFrames = 0;
  bool _deadThisBall = false;
  final MoveState moves = MoveState();
  final Map<String, int> _counts = {};
  BodyPose? lastPose;
  SwingEvent? lastSwing;

  @override
  int get clockMs => clock;
  @override
  int get durationMs => 0;
  @override
  bool get holding => isHeld;
  @override
  bool get finished => phase == 'done';

  bool get won => format.target != null && runs >= format.target!;
  int get ballsLeft => format.balls - legal;

  /// 0 → 1 as the ball travels to the crease.
  double get ballProgress {
    final d = current;
    if (d == null || phase != 'runup') return 0;
    return (1 - (d.arriveAt - clock) / telegraphMs).clamp(0.0, 1.15);
  }

  void _queue() {
    final roll = _rng.next();
    final line = roll < format.wideShare
        ? BallLine.wide
        : const [BallLine.off, BallLine.middle, BallLine.leg][_rng.nextInt(3)];
    current = Delivery(legal + 1, line, clock + setMs + telegraphMs);
    phase = 'set';
    _phaseAt = clock;
    _deadThisBall = false;
    _guardFrames = 0;
    _leaveFrames = 0;
    _swing.reset();
  }

  int get _actionT => clock - latencyMs;

  @override
  void advance(int dtMs, {required bool tracked}) {
    if (finished) return;
    final wasHeld = isHeld;
    tick(dtMs, tracked);
    if (isHeld) {
      if (!wasHeld && phase == 'runup') _deadThisBall = true;
      return;
    }
    final d = current!;
    switch (phase) {
      case 'set':
        if (clock - _phaseAt >= setMs) {
          phase = 'runup';
          _phaseAt = clock;
          pending.add(ArcadeEvent('runup', value: d.line.index));
        }
      case 'runup':
        if (_deadThisBall) {
          d.dead = true;
          deadBalls++;
          pending.add(const ArcadeEvent('deadBall',
              text: 'Dead ball. Step back, I lost your hands.'));
          _toResult();
          return;
        }
        if (_actionT > d.arriveAt + window) _resolveUnplayed(d);
      case 'result':
        if (clock - _phaseAt >= afterMs) _nextBall();
    }
  }

  void _toResult() {
    phase = 'result';
    _phaseAt = clock;
  }

  void _nextBall() {
    final d = current!;
    if (!d.dead) {
      deliveries.add(d);
      // Wides are re-bowled, as in real cricket.
      if (d.line != BallLine.wide) legal++;
    }
    final out = format.wickets > 0 && wickets >= format.wickets;
    if (legal >= format.balls || out || won) {
      phase = 'done';
      pending.add(ArcadeEvent('over',
          text: won
              ? 'Chased it down!'
              : format.target != null
                  ? 'So close. ${format.target! - runs} short.'
                  : 'That is the over!'));
      return;
    }
    _queue();
  }

  void _resolveUnplayed(Delivery d) {
    if (d.line == BallLine.wide && d.shot == Shot.none) {
      // A wide that was not chased: one extra.
      _score(d, 1, Shot.none, Grade.ok, text: 'Wide! One extra.');
      return;
    }
    d.grade = Grade.miss;
    combo = 0;
    if (d.line == BallLine.middle &&
        format.wickets > 0 &&
        difficulty != 'beginner') {
      d.result = -2;
      wickets++;
      pending.add(
          const ArcadeEvent('wicket', text: 'Bowled him! Golu is dancing.'));
    } else {
      d.result = 0;
      pending.add(const ArcadeEvent('dot', text: 'Beaten! Swing on the ring.'));
    }
    _toResult();
  }

  @override
  void pose(BodyPose body) {
    lastPose = body;
    if (isHeld || phase != 'runup') {
      _swing.update(body);
      return;
    }
    final d = current!;
    final off = _actionT - d.arriveAt;
    final e = _swing.update(body);
    if (e != null) {
      lastSwing = e;
      if (e.completed) {
        _count('swing');
        final shotOff = off;
        if (shotOff < -window) {
          pending.add(const ArcadeEvent('early',
              text: 'Too early! Wait for the ring.'));
        } else if (shotOff <= window) {
          _playShot(d, e.lofted ? Shot.lofted : Shot.drive, shotOff);
          return;
        }
      }
    }
    if (off.abs() <= 250) {
      _guardFrames = body.isGuard ? _guardFrames + 1 : 0;
      if (_guardFrames >= 2) {
        _count('block');
        _score(d, 0, Shot.defend, Grade.good, text: 'Solid block!');
        return;
      }
    }
    if (d.line == BallLine.wide && off.abs() <= window) {
      _leaveFrames = (moves.armsUp || body.armsUp) ? _leaveFrames + 1 : 0;
      if (_leaveFrames >= 2) {
        _count('arms up');
        _score(d, 1, Shot.leave, Grade.perfect, text: 'Well left! Wide given.');
      }
    }
  }

  void _playShot(Delivery d, Shot shot, int offset) {
    final p = window * 0.35, g = window * 0.65;
    final a = offset.abs();
    final grade = a <= p
        ? Grade.perfect
        : a <= g
            ? Grade.good
            : Grade.ok;
    final r = outcomes.roll(shot.name, grade, _rng.next(),
        outsAllowed: format.wickets > 0 && difficulty != 'beginner');
    if (r < 0) {
      d.shot = shot;
      d.grade = grade;
      d.result = -1;
      wickets++;
      combo = 0;
      pending.add(const ArcadeEvent('wicket',
          text: 'Caught! Chikki takes a screamer.'));
      _toResult();
      return;
    }
    _score(d, r, shot, grade,
        text: switch (r) {
          6 => 'SIX! Over the neighbour\'s scooter!',
          4 => 'FOUR! Through the gap.',
          0 => 'Good contact, no run.',
          _ => '$r run${r == 1 ? '' : 's'}. Keep the strike ticking.',
        });
  }

  void _score(Delivery d, int r, Shot shot, Grade grade, {String? text}) {
    d.shot = shot;
    d.grade = grade;
    d.result = r;
    runs += r;
    if (r == 4) fours++;
    if (r == 6) sixes++;
    if (grade != Grade.miss) {
      combo++;
      bestCombo = math.max(bestCombo, combo);
    }
    pending.add(ArcadeEvent('shot',
        grade: grade, value: r, points: r, text: text, id: d.number));
    _toResult();
  }

  void _count(String m) => _counts[m] = (_counts[m] ?? 0) + 1;

  @override
  void motion(MotionEvent event) => moves.apply(event);

  @override
  List<ArcadeEvent> drainEvents() => drain();

  @override
  ArcadeSummary get summary {
    final played = deliveries.where((d) => !d.dead).toList();
    final good = played
        .where((d) => d.grade == Grade.perfect || d.grade == Grade.good)
        .length;
    final acc = played.isEmpty ? 0.0 : good / played.length;
    final t = format.target;
    final stars = t != null
        ? (won ? (ballsLeft >= 3 ? 3 : 2) : (runs >= t * 0.7 ? 1 : 0))
        : starsFor(runs / math.max(1, format.balls), const [0.75, 1.25, 2.0]);
    return ArcadeSummary(
      gameId: 'tapeball',
      stageId: format.id,
      score: runs,
      stars: stars,
      maxStars: 3,
      accuracy: acc,
      bestCombo: bestCombo,
      activeMs: clock,
      completed: finished,
      headline: t != null
          ? (won ? 'Chased $t with $ballsLeft balls to spare' : '$runs of $t')
          : '$runs runs off $legal balls',
      moves: Map.of(_counts),
      forgiven: deadBalls,
      details: {
        'Runs': '$runs',
        if (format.wickets > 0) 'Wickets': '$wickets/${format.wickets}',
        'Fours': '$fours',
        'Sixes': '$sixes',
      },
    );
  }
}
