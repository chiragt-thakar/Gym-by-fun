import 'dart:math' as math;

import 'package:motion_core/motion_core.dart';

import 'arcade.dart';

/// NEON SLICE — glowing fruit arcs up in front of the player; a fast sweep
/// of either hand cuts it. Static mines fly with the fruit and must be left
/// alone.
///
/// Slicing is judged on the hand's own path: the segment a hand travelled
/// between two tracked frames is a blade, but only while the hand is moving
/// fast. A hand that rests where fruit passes cuts nothing, a fruit can be
/// cut once, and a jump in the hand position (a tracking glitch) is never a
/// cut.

enum SliceKind { fruit, prism, bomb }

class SliceStage {
  const SliceStage({
    required this.id,
    required this.name,
    required this.durationMs,
    required this.startPerMin,
    required this.peakPerMin,
    this.bombShare = 0,
    this.waveShare = 0.2,
    this.flightMs = 2300,
    this.radius = 0.34,
    this.minSpeed = 2.0,
    this.seed = 1,
    this.blurb = '',
  });

  final String id;
  final String name;
  final int durationMs;

  /// Launches a minute at the start of the round and at its peak; the pace
  /// climbs smoothly between the two.
  final int startPerMin;
  final int peakPerMin;

  /// Chance (at the peak) that a launch brings a mine with it.
  final double bombShare;

  /// Chance (at the peak) that a launch is a wave of two or three.
  final double waveShare;

  /// How long a fruit is in the air.
  final int flightMs;

  /// Fruit radius in torso lengths.
  final double radius;

  /// Hand speed (torso lengths per second) that makes a blade.
  final double minSpeed;
  final int seed;
  final String blurb;

  factory SliceStage.fromJson(Map<String, dynamic> j) => SliceStage(
        id: j['id'] as String,
        name: j['name'] as String,
        durationMs: (j['durationMs'] as num).toInt(),
        startPerMin: (j['startPerMin'] as num).toInt(),
        peakPerMin: (j['peakPerMin'] as num).toInt(),
        bombShare: (j['bombShare'] as num?)?.toDouble() ?? 0,
        waveShare: (j['waveShare'] as num?)?.toDouble() ?? 0.2,
        flightMs: (j['flightMs'] as num?)?.toInt() ?? 2300,
        radius: (j['radius'] as num?)?.toDouble() ?? 0.34,
        minSpeed: (j['minSpeed'] as num?)?.toDouble() ?? 2.0,
        seed: (j['seed'] as num?)?.toInt() ?? 1,
        blurb: j['blurb'] as String? ?? '',
      );

  /// Same stage with another seed (Daily Remix) and/or assist: bigger
  /// fruit, a gentler sweep counts, fewer mines, more air time.
  SliceStage variant({int? seed, bool assist = false}) => SliceStage(
        id: id,
        name: name,
        durationMs: durationMs,
        startPerMin: startPerMin,
        peakPerMin: assist ? (peakPerMin * 0.8).round() : peakPerMin,
        bombShare: assist ? bombShare * 0.5 : bombShare,
        waveShare: waveShare,
        flightMs: assist ? (flightMs * 1.2).round() : flightMs,
        radius: assist ? radius * 1.25 : radius,
        minSpeed: assist ? minSpeed * 0.7 : minSpeed,
        seed: seed ?? this.seed,
        blurb: blurb,
      );
}

/// One thing in the air. Its path is a pure function of the game clock, so
/// it freezes with the clock when tracking is lost.
class SliceTarget {
  SliceTarget({
    required this.id,
    required this.kind,
    required this.launchAt,
    required this.flightMs,
    required this.x0,
    required this.x1,
    required this.apexY,
    this.look = 0,
    this.spin = 1,
    this.golden = false,
  });

  /// Where everything launches from and falls back to (body space, below
  /// the hands), and the height above which a hand can reach it.
  static const floorY = -1.7;
  static const reachY = -1.25;

  final int id;
  final SliceKind kind;
  final int launchAt;
  final int flightMs;
  final double x0;
  final double x1;
  final double apexY;

  /// Which fruit design to draw (0..4).
  final int look;

  /// Rotation speed and direction, for drawing.
  final double spin;

  /// Part of the closing fan.
  final bool golden;

  bool sliced = false;
  bool missed = false;
  bool forgiven = false;

  bool get done => sliced || missed || forgiven;
  bool get isBomb => kind == SliceKind.bomb;
  int get landAt => launchAt + flightMs;

  /// Points for a clean cut.
  int get base => switch (kind) {
        SliceKind.prism => 300,
        SliceKind.bomb => 0,
        SliceKind.fruit => 100,
      };

  /// 0 at launch → 1 at landing.
  double progress(int t) => ((t - launchAt) / flightMs).clamp(0.0, 1.0);

  /// Body-space position at game time [t]: a parabola from the floor up to
  /// [apexY] and back, drifting from [x0] to [x1].
  (double, double) at(int t) {
    final u = progress(t);
    return (
      x0 + (x1 - x0) * u,
      floorY + (apexY - floorY) * 4 * u * (1 - u),
    );
  }

  bool inFlight(int t) => t >= launchAt && t <= landAt;

  /// True while a hand could reach it.
  bool reachable(int t) => inFlight(t) && at(t).$2 >= reachY;
}

/// A cut that just happened, kept briefly so the halves can be drawn
/// flying apart.
class SliceCut {
  const SliceCut({
    required this.target,
    required this.at,
    required this.x,
    required this.y,
    required this.angle,
    required this.grade,
  });
  final SliceTarget target;

  /// Game clock of the cut.
  final int at;
  final double x;
  final double y;

  /// Direction of the blade, radians (body space, +y up).
  final double angle;
  final Grade grade;
}

/// One point of a hand's recent path, for drawing the blade trail.
class TrailPoint {
  const TrailPoint(this.x, this.y, this.at, this.hot);
  final double x;
  final double y;
  final int at;

  /// True when the hand was fast enough to cut at this point.
  final bool hot;
}

class _Blade {
  double? x;
  double? y;
  int ts = 0;
  int swipe = 0;
  final List<TrailPoint> trail = [];

  void lift() {
    x = null;
    y = null;
    swipe = 0;
  }
}

class SliceEngine with ArcadeClock implements ArcadeEngine {
  /// [plan] replaces the seeded plan (tests place fruit exactly).
  SliceEngine(this.stage, {this.latencyMs = 100, List<SliceTarget>? plan}) {
    if (plan != null) {
      targets.addAll(plan);
    } else {
      _plan();
    }
    for (final t in targets) {
      _maxBase += t.base;
    }
  }

  final SliceStage stage;

  /// How late a pose is, compared with what the player saw (camera plus
  /// inference). Fruit is judged where it was that long ago.
  final int latencyMs;
  final List<SliceTarget> targets = [];

  /// Recent cuts (about 0.7 s), newest last.
  final List<SliceCut> cuts = [];

  /// How far past the fruit's edge a blade still cuts (torso lengths).
  static const bladeReach = 0.12;

  /// A hand that moved further than this between two frames jumped; it
  /// did not sweep.
  static const maxStep = 1.6;

  /// Longest gap between two frames that still joins into one sweep.
  static const maxGapMs = 250;

  static const frenzyEvery = 12;
  static const frenzyMs = 6000;
  static const stunMs = 1200;
  static const bombPenalty = 150;
  static const trailMs = 240;
  static const cutMs = 700;

  int score = 0;
  int combo = 0;
  int bestCombo = 0;
  int slicedCount = 0;
  int bombsHit = 0;
  int bestSwipe = 0;
  int frenzyUntil = -1;
  int stunUntil = -1;
  int _base = 0;
  int _maxBase = 0;
  int _phase = 0;
  int _launched = 0;
  final Map<BodySide, _Blade> _blades = {
    BodySide.left: _Blade(),
    BodySide.right: _Blade(),
  };

  @override
  int get clockMs => clock;
  @override
  int get durationMs => stage.durationMs;
  @override
  bool get holding => isHeld;
  @override
  bool get finished => clock >= stage.durationMs;

  bool get frenzy => clock < frenzyUntil;

  /// True for a moment after cutting a mine: blades are dead.
  bool get stunned => clock < stunUntil;

  double get multiplier => math.min(2.0, 1 + 0.05 * combo) * (frenzy ? 1.5 : 1);

  /// 0 warm-up, 1 heat, 2 overdrive: the round's three acts.
  int get phase => clock < stage.durationMs * 0.33
      ? 0
      : (clock < stage.durationMs * 0.7 ? 1 : 2);

  /// Everything in the air now.
  Iterable<SliceTarget> get visible =>
      targets.where((t) => !t.done && t.inFlight(clock));

  /// A hand's recent path (empty when the hand is not seen).
  List<TrailPoint> trail(BodySide side) => _blades[side]!.trail;

  void _plan() {
    final rng = SeededRandom(stage.seed);
    final end = stage.durationMs - 5500;
    var t = 2500;
    var id = 0;
    var lastBomb = -100000;

    SliceTarget make(SliceKind kind, int at, double x0, {bool golden = false}) {
      final drift = (rng.next() * 2 - 1) * 0.7;
      return SliceTarget(
        id: id++,
        kind: kind,
        launchAt: at,
        flightMs: (stage.flightMs * (0.85 + 0.3 * rng.next())).round(),
        x0: x0,
        x1: (x0 + drift).clamp(-1.45, 1.45).toDouble(),
        apexY: 0.25 + rng.next() * 1.1,
        look: rng.nextInt(5),
        spin: rng.next() * 2 - 1,
        golden: golden,
      );
    }

    while (t < end) {
      final p = t / stage.durationMs;
      final k = p * p * (3 - 2 * p); // smooth 0 → 1 over the round
      final rate = stage.startPerMin + (stage.peakPerMin - stage.startPerMin) * k;
      final wave = rng.next() < stage.waveShare * (0.4 + 0.6 * k)
          ? 2 + rng.nextInt(2)
          : 1;
      for (var i = 0; i < wave; i++) {
        final x0 = wave == 1
            ? (rng.next() * 2 - 1) * 1.3
            : -0.9 + 1.8 * i / (wave - 1) + (rng.next() - 0.5) * 0.3;
        final prism = wave == 1 && t > 8000 && rng.next() < 0.07;
        targets.add(make(
            prism ? SliceKind.prism : SliceKind.fruit, t + i * 140, x0));
      }
      if (stage.bombShare > 0 &&
          t > 10000 &&
          t - lastBomb > 2500 &&
          rng.next() < stage.bombShare * (0.3 + 0.7 * k)) {
        targets.add(
            make(SliceKind.bomb, t + 200, (rng.next() * 2 - 1) * 1.2));
        lastBomb = t;
      }
      // A wave earns a slightly longer breath.
      t += (60000 / rate * (wave == 1 ? 1 : 1.5)).round();
    }
    // The closing fan: five golden fruit, left to right.
    for (var i = 0; i < 5; i++) {
      targets.add(make(SliceKind.fruit, end + 500 + i * 180, -1.2 + 0.6 * i,
          golden: true));
    }
  }

  int get _actionT => clock - latencyMs;

  @override
  void advance(int dtMs, {required bool tracked}) {
    tick(dtMs, tracked);
    if (isHeld) return;
    // One launch cue per frame, however many take off.
    var launched = false;
    while (_launched < targets.length &&
        targets[_launched].launchAt <= clock) {
      _launched++;
      launched = true;
    }
    if (launched) pending.add(const ArcadeEvent('launch'));

    final ph = phase;
    if (ph != _phase) {
      _phase = ph;
      pending.add(ArcadeEvent('phase',
          value: ph, text: ph == 1 ? 'Heating up.' : 'Overdrive!'));
    }

    final at = _actionT;
    for (final t in targets) {
      if (t.done || at <= t.landAt) continue;
      if (t.isBomb) {
        t.missed = true; // left alone: exactly right
      } else if (inGrace) {
        t.forgiven = true;
        forgivenCount++;
        _maxBase -= t.base;
        pending.add(ArcadeEvent('forgiven', id: t.id));
      } else {
        t.missed = true;
        combo = 0;
        pending.add(ArcadeEvent('miss', id: t.id, x: t.x1, y: SliceTarget.reachY));
      }
    }
    cuts.removeWhere((c) => clock - c.at > cutMs);
    for (final b in _blades.values) {
      b.trail.removeWhere((p) => clock - p.at > trailMs);
    }
  }

  @override
  void pose(BodyPose body) {
    if (isHeld) return;
    _sweep(BodySide.left, body.leftHand, body.timestampMs);
    _sweep(BodySide.right, body.rightHand, body.timestampMs);
  }

  void _sweep(BodySide side, BodyPoint hand, int ts) {
    final b = _blades[side]!;
    if (!hand.seen) {
      b.lift();
      return;
    }
    final px = b.x, py = b.y, pts = b.ts;
    b
      ..x = hand.x
      ..y = hand.y
      ..ts = ts;
    if (px == null || py == null) {
      b.trail.add(TrailPoint(hand.x, hand.y, clock, false));
      return;
    }
    final dt = ts - pts;
    final dx = hand.x - px, dy = hand.y - py;
    final len = math.sqrt(dx * dx + dy * dy);
    final fast = dt > 0 &&
        dt <= maxGapMs &&
        len <= maxStep &&
        len / (dt / 1000) >= stage.minSpeed;
    b.trail.add(TrailPoint(hand.x, hand.y, clock, fast && !stunned));
    if (!fast) {
      b.swipe = 0; // the sweep ended: the next cut starts a new one
      return;
    }
    if (stunned) return;
    final at = _actionT;
    for (final t in targets) {
      if (t.done || !t.reachable(at)) continue;
      final (tx, ty) = t.at(at);
      final d = _segmentDistance(px, py, hand.x, hand.y, tx, ty);
      if (d > stage.radius + bladeReach) continue;
      _cut(t, side, b, d, math.atan2(dy, dx), tx, ty);
      if (stunned) return; // that was a mine
    }
  }

  void _cut(SliceTarget t, BodySide side, _Blade b, double distance,
      double angle, double x, double y) {
    t.sliced = true;
    if (t.isBomb) {
      bombsHit++;
      combo = 0;
      b.swipe = 0;
      stunUntil = clock + stunMs;
      frenzyUntil = -1;
      final lost = math.min(score, bombPenalty);
      score -= lost;
      pending.add(ArcadeEvent('bomb',
          id: t.id,
          points: -lost,
          side: side,
          x: x,
          y: y,
          text: 'Static mine! Leave the dark ones.'));
      return;
    }
    final grade = distance <= stage.radius * 0.4 ? Grade.perfect : Grade.good;
    final base = (grade == Grade.perfect ? t.base : t.base * 0.7).round();
    _base += base;
    combo++;
    bestCombo = math.max(bestCombo, combo);
    slicedCount++;
    b.swipe++;
    bestSwipe = math.max(bestSwipe, b.swipe);
    final pts = (base * multiplier).round();
    score += pts;
    cuts.add(SliceCut(
        target: t, at: clock, x: x, y: y, angle: angle, grade: grade));
    pending.add(ArcadeEvent('slice',
        id: t.id,
        grade: grade,
        points: pts,
        side: side,
        value: t.kind == SliceKind.prism ? 5 : t.look,
        x: x,
        y: y));
    if (b.swipe >= 3) {
      // Three or more in one sweep: a bonus that grows with each extra.
      final bonus = 50 * (b.swipe - 2);
      score += bonus;
      pending.add(ArcadeEvent('multi',
          points: bonus, value: b.swipe, side: side, x: x, y: y));
    }
    if (combo % frenzyEvery == 0) {
      frenzyUntil = clock + frenzyMs;
      pending.add(const ArcadeEvent('frenzy', text: 'Neon Frenzy!'));
    }
  }

  /// Distance from point (px, py) to the segment (ax, ay)–(bx, by).
  static double _segmentDistance(
      double ax, double ay, double bx, double by, double px, double py) {
    final vx = bx - ax, vy = by - ay;
    final l2 = vx * vx + vy * vy;
    final u = l2 == 0
        ? 0.0
        : (((px - ax) * vx + (py - ay) * vy) / l2).clamp(0.0, 1.0);
    final cx = ax + vx * u - px, cy = ay + vy * u - py;
    return math.sqrt(cx * cx + cy * cy);
  }

  @override
  void motion(MotionEvent event) {}

  @override
  List<ArcadeEvent> drainEvents() => drain();

  double get accuracy => _maxBase <= 0 ? 0 : (_base / _maxBase).clamp(0, 1);

  int get _fruitTotal =>
      targets.where((t) => !t.isBomb && !t.forgiven).length;

  @override
  ArcadeSummary get summary => ArcadeSummary(
        gameId: 'neon-slice',
        stageId: stage.id,
        score: score,
        stars: starsFor(accuracy, const [0.45, 0.65, 0.85]),
        maxStars: 3,
        accuracy: accuracy,
        bestCombo: bestCombo,
        activeMs: clock,
        completed: finished,
        headline: 'Sliced $slicedCount of $_fruitTotal at ${stage.name}',
        moves: {'slice': slicedCount},
        forgiven: forgivenCount,
        details: {
          'Sliced': '$slicedCount / $_fruitTotal',
          'Best sweep': '$bestSwipe',
          'Mines hit': '$bombsHit',
        },
      );
}
