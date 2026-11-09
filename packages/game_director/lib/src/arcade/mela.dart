import 'dart:math' as math;

import 'package:motion_core/motion_core.dart';

import 'arcade.dart';

/// MIRROR MELA — "the fair comes to you". Fair objects drift to zones around
/// the player's body; put the named hand in the zone as the ring closes.
/// Orbit rounds add slow sweeps to duck under or lean away from.

enum MelaKind { hand, crown, chest, duck, dodgeLeft, dodgeRight }

/// Zones in body space (torso units from the shoulder centre, +y up).
const melaZones = <String, (double, double, BodySide?)>{
  'hiL': (-0.75, 1.15, BodySide.left),
  'hiR': (0.75, 1.15, BodySide.right),
  'sideL': (-1.3, 0.05, BodySide.left),
  'sideR': (1.3, 0.05, BodySide.right),
  'lowL': (-1.15, -0.75, BodySide.left),
  'lowR': (1.15, -0.75, BodySide.right),
};

class MelaStage {
  const MelaStage({
    required this.id,
    required this.name,
    required this.mode,
    required this.durationMs,
    required this.warningMs,
    required this.targetsPerMin,
    required this.radius,
    this.zones = const ['hiL', 'hiR', 'sideL', 'sideR'],
    this.hazardShare = 0,
    this.doubleShare = 0.1,
    this.anyHand = true,
    this.seed = 1,
    this.windows = const TimingWindows(perfect: 200, good: 400, ok: 400),
    this.blurb = '',
  });

  final String id;
  final String name;

  /// 'bazaar' (reach only) or 'orbit' (with sweeps).
  final String mode;
  final int durationMs;
  final int warningMs;
  final int targetsPerMin;
  final double radius;
  final List<String> zones;
  final double hazardShare;
  final double doubleShare;

  /// Beginner rounds accept either hand on any target.
  final bool anyHand;
  final int seed;
  final TimingWindows windows;
  final String blurb;

  factory MelaStage.fromJson(Map<String, dynamic> j) => MelaStage(
        id: j['id'] as String,
        name: j['name'] as String,
        mode: j['mode'] as String? ?? 'bazaar',
        durationMs: (j['durationMs'] as num).toInt(),
        warningMs: (j['warningMs'] as num).toInt(),
        targetsPerMin: (j['targetsPerMin'] as num).toInt(),
        radius: (j['radius'] as num).toDouble(),
        zones: [for (final z in j['zones'] as List<dynamic>) z as String],
        hazardShare: (j['hazardShare'] as num?)?.toDouble() ?? 0,
        doubleShare: (j['doubleShare'] as num?)?.toDouble() ?? 0.1,
        anyHand: j['anyHand'] as bool? ?? true,
        seed: (j['seed'] as num?)?.toInt() ?? 1,
        windows: TimingWindows.fromJson(j['windows'] as Map<String, dynamic>?),
        blurb: j['blurb'] as String? ?? '',
      );

  /// Same stage with another seed (Daily Remix) and/or assist.
  MelaStage variant({int? seed, bool assist = false}) => MelaStage(
        id: id,
        name: name,
        mode: mode,
        durationMs: durationMs,
        warningMs: assist ? (warningMs * 1.25).round() : warningMs,
        targetsPerMin: assist ? (targetsPerMin * 0.75).round() : targetsPerMin,
        radius: assist ? radius * 1.2 : radius,
        zones: zones,
        hazardShare: hazardShare,
        doubleShare: doubleShare,
        anyHand: anyHand || assist,
        seed: seed ?? this.seed,
        windows: assist ? windows.scaled(1.25) : windows,
        blurb: blurb,
      );
}

class MelaTarget {
  MelaTarget({
    required this.id,
    required this.kind,
    required this.hitAt,
    required this.spawnAt,
    this.zone,
    this.x = 0,
    this.y = 0,
    this.side,
    this.golden = false,
  });

  final int id;
  final MelaKind kind;
  final int hitAt;
  final int spawnAt;
  final String? zone;
  final double x;
  final double y;
  final BodySide? side;
  final bool golden;

  bool done = false;
  Grade? grade;
  bool forgiven = false;
  int _inside = 0;
  int? _firstInside;
  bool _graze = false;
  bool _heldAtOpen = false;
  bool _seenOpen = false;

  bool get isHazard =>
      kind == MelaKind.duck ||
      kind == MelaKind.dodgeLeft ||
      kind == MelaKind.dodgeRight;

  /// 0 at spawn → 1 at the hit moment.
  double progress(int clock) =>
      ((clock - spawnAt) / math.max(1, hitAt - spawnAt)).clamp(0.0, 1.2);
}

class MelaEngine with ArcadeClock implements ArcadeEngine {
  MelaEngine(this.stage, {this.latencyMs = 100}) {
    _plan();
  }

  final MelaStage stage;
  final int latencyMs;
  final List<MelaTarget> targets = [];
  final MoveState moves = MoveState();

  int score = 0;
  int combo = 0;
  int bestCombo = 0;
  int shields = 3;
  int rushUntil = -1;
  bool _halved = false;
  int _base = 0;
  int _maxBase = 0;
  final Map<String, int> _moveCounts = {};
  BodyPose? lastPose;

  @override
  int get clockMs => clock;
  @override
  int get durationMs => stage.durationMs;
  @override
  bool get holding => isHeld;
  @override
  bool get finished => clock >= stage.durationMs;

  bool get rush => clock < rushUntil;
  double get multiplier =>
      math.min(2.0, 1 + 0.05 * combo) * (rush ? 1.5 : 1) * (_halved ? 0.5 : 1);

  /// Targets on screen now.
  Iterable<MelaTarget> get visible => targets.where((t) =>
      !t.done && t.spawnAt <= clock && clock <= t.hitAt + stage.windows.close);

  void _plan() {
    final rng = SeededRandom(stage.seed);
    final interval = 60000 ~/ stage.targetsPerMin;
    var t = 2500;
    var id = 0;
    var lastHazard = -100000;
    final lastHand = <BodySide, int>{
      BodySide.left: -100000,
      BodySide.right: -100000,
    };
    final end = stage.durationMs - 7000;
    var lastT = 0;
    while (t < end) {
      final roll = rng.next();
      if (stage.hazardShare > 0 &&
          roll < stage.hazardShare &&
          t - lastHazard >= 3000 &&
          t > 8000) {
        final kind = rng.pick(
            const [MelaKind.duck, MelaKind.dodgeLeft, MelaKind.dodgeRight]);
        final warn = math.max(stage.warningMs, 2200);
        targets
            .add(MelaTarget(id: id++, kind: kind, hitAt: t, spawnAt: t - warn));
        lastHazard = t;
        t += math.max(interval, 1200 + 400);
        continue;
      }
      if (roll > 1 - stage.doubleShare) {
        final crown = rng.next() < 0.6;
        targets.add(MelaTarget(
          id: id++,
          kind: crown ? MelaKind.crown : MelaKind.chest,
          hitAt: t,
          spawnAt: t - stage.warningMs,
          x: 0,
          y: crown ? 1.15 : -0.35,
        ));
        lastHand[BodySide.left] = lastHand[BodySide.right] = t;
      } else {
        var zone = rng.pick(stage.zones);
        var spec = melaZones[zone]!;
        final side = spec.$3!;
        if (t - lastHand[side]! < 1000) {
          // Same hand too soon: use the mirrored zone.
          zone = zone.endsWith('L')
              ? '${zone.substring(0, zone.length - 1)}R'
              : '${zone.substring(0, zone.length - 1)}L';
          if (melaZones.containsKey(zone) && stage.zones.contains(zone)) {
            spec = melaZones[zone]!;
          }
        }
        targets.add(MelaTarget(
          id: id++,
          kind: MelaKind.hand,
          hitAt: t,
          spawnAt: t - stage.warningMs,
          zone: zone,
          x: spec.$1,
          y: spec.$2,
          side: stage.anyHand ? null : spec.$3,
        ));
        lastHand[spec.$3!] = t;
      }
      lastT = t;
      t += interval;
    }
    // Golden finale: left, right, left, right, crown.
    var f = math.max(lastT + 1200, end + 600);
    const finale = ['sideL', 'sideR', 'hiL', 'hiR'];
    for (final z in finale) {
      final spec = melaZones[z]!;
      targets.add(MelaTarget(
        id: id++,
        kind: MelaKind.hand,
        hitAt: f,
        spawnAt: f - stage.warningMs,
        zone: z,
        x: spec.$1,
        y: spec.$2,
        side: stage.anyHand ? null : spec.$3,
        golden: true,
      ));
      f += 900;
    }
    targets.add(MelaTarget(
        id: id++,
        kind: MelaKind.crown,
        hitAt: f + 300,
        spawnAt: f + 300 - stage.warningMs,
        y: 1.15,
        golden: true));
    for (final t in targets) {
      _maxBase += t.isHazard ? 50 : (t.kind == MelaKind.hand ? 100 : 150);
    }
  }

  int get _actionT => clock - latencyMs;

  @override
  void advance(int dtMs, {required bool tracked}) {
    tick(dtMs, tracked);
    if (isHeld) return;
    final w = stage.windows;
    for (final t in targets) {
      if (t.done || t.spawnAt > clock) continue;
      if (t.isHazard) {
        if (_actionT >= t.hitAt) _judgeHazard(t);
        continue;
      }
      if (_actionT > t.hitAt + w.close) {
        t.done = true;
        if (inGrace) {
          t.forgiven = true;
          forgivenCount++;
          _maxBase -= t.kind == MelaKind.hand ? 100 : 150;
          pending.add(ArcadeEvent('forgiven', id: t.id));
        } else {
          t.grade = Grade.miss;
          combo = 0;
          pending.add(ArcadeEvent('miss', id: t.id, x: t.x, y: t.y));
        }
      }
    }
  }

  void _judgeHazard(MelaTarget t) {
    t.done = true;
    if (inGrace) {
      t.forgiven = true;
      forgivenCount++;
      _maxBase -= 50;
      pending.add(ArcadeEvent('forgiven', id: t.id));
      return;
    }
    final hip = lastPose?.hipCenter;
    final safe = switch (t.kind) {
      MelaKind.duck => moves.squat,
      // A sweep through the left half: lean or step to the right.
      MelaKind.dodgeLeft => moves.leanRight || (hip != null && hip.x > 0.3),
      MelaKind.dodgeRight => moves.leanLeft || (hip != null && hip.x < -0.3),
      _ => true,
    };
    if (safe) {
      t.grade = Grade.good;
      _count(t.kind == MelaKind.duck ? 'duck' : 'lean');
      _award(t, 50);
      pending.add(ArcadeEvent('dodge', id: t.id, points: 50));
    } else {
      t.grade = Grade.miss;
      combo = 0;
      shields = math.max(0, shields - 1);
      if (shields == 0) _halved = true;
      pending.add(ArcadeEvent('hit',
          id: t.id,
          text: switch (t.kind) {
            MelaKind.duck => 'Duck under the sweep!',
            MelaKind.dodgeLeft => 'Lean right, away from it!',
            _ => 'Lean left, away from it!',
          }));
    }
  }

  @override
  void pose(BodyPose body) {
    lastPose = body;
    if (isHeld) return;
    final w = stage.windows;
    final r = stage.radius;
    for (final t in targets) {
      if (t.done || t.isHazard) continue;
      final off = _actionT - t.hitAt;
      if (off < w.open || off > w.close) continue;
      final inside = _inside(body, t, r);
      final graze = !inside && _inside(body, t, r * 1.3);
      if (!t._seenOpen) {
        t._seenOpen = true;
        t._heldAtOpen = inside;
      }
      if (inside || graze) {
        t._inside++;
        t._firstInside ??= _actionT;
        t._graze = t._graze || graze;
        if (t._inside >= 2) _pop(t, t._firstInside! - t.hitAt);
      } else {
        t._inside = 0;
        t._firstInside = null;
        t._graze = false;
        t._heldAtOpen = false;
      }
    }
  }

  bool _inside(BodyPose b, MelaTarget t, double r) => switch (t.kind) {
        MelaKind.hand => b.handIn(t.side, t.x, t.y, r),
        MelaKind.crown => b.handIn(BodySide.left, t.x, t.y, r * 1.6) &&
            b.handIn(BodySide.right, t.x, t.y, r * 1.6),
        MelaKind.chest => b.handsTogether,
        _ => false,
      };

  void _pop(MelaTarget t, int offset) {
    var g = stage.windows.grade(offset);
    if (g == Grade.miss) g = Grade.ok;
    if (t._graze) g = Grade.ok;
    if (t._heldAtOpen && g == Grade.perfect) g = Grade.good;
    t.done = true;
    t.grade = g;
    final base = switch (g) {
      Grade.perfect => 100,
      Grade.good => 60,
      _ => 30,
    };
    final full = t.kind == MelaKind.hand ? base : (base * 1.5).round();
    _count(t.kind == MelaKind.hand ? 'reach' : 'both arms');
    final pts = _award(t, full);
    final note = t.zone == null
        ? 4
        : const ['lowL', 'sideL', 'hiL', 'hiR', 'sideR', 'lowR']
                .indexOf(t.zone!) %
            5;
    pending.add(ArcadeEvent('pop',
        id: t.id, grade: g, points: pts, value: note, x: t.x, y: t.y));
  }

  int _award(MelaTarget t, int base) {
    _base += base;
    combo++;
    bestCombo = math.max(bestCombo, combo);
    if (_halved && combo >= 5) {
      _halved = false;
      shields = 3;
      pending.add(const ArcadeEvent('shields'));
    }
    if (combo % 15 == 0) {
      rushUntil = clock + 8000;
      pending.add(const ArcadeEvent('rush', text: 'Mela Rush!'));
    }
    final pts = (base * multiplier).round();
    score += pts;
    return pts;
  }

  void _count(String m) => _moveCounts[m] = (_moveCounts[m] ?? 0) + 1;

  @override
  void motion(MotionEvent event) => moves.apply(event);

  @override
  List<ArcadeEvent> drainEvents() => drain();

  double get accuracy => _maxBase <= 0 ? 0 : (_base / _maxBase).clamp(0, 1);

  String get letter => accuracy >= 0.9
      ? 'S'
      : accuracy >= 0.75
          ? 'A'
          : accuracy >= 0.55
              ? 'B'
              : 'C';

  @override
  ArcadeSummary get summary => ArcadeSummary(
        gameId: 'mirror-mela',
        stageId: stage.id,
        score: score,
        stars: starsFor(accuracy, const [0.55, 0.75, 0.9]),
        maxStars: 3,
        accuracy: accuracy,
        bestCombo: bestCombo,
        activeMs: clock,
        completed: finished,
        headline: 'Grade $letter at the ${stage.name}',
        moves: Map.of(_moveCounts),
        forgiven: forgivenCount,
        details: {'Grade': letter},
      );
}
