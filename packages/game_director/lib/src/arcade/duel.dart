import 'dart:math' as math;

import 'package:motion_core/motion_core.dart';

import 'arcade.dart';

/// CRAFTGUARD DUELS — an original craft-construct guardian attacks on a
/// spoken 4-count. Answer cleanly to break its Poise; when it staggers,
/// strike the glowing side pads and raise your arms to Charge. Guardians
/// are calmed, never destroyed, and "game over" never appears.

enum DuelMove { duck, left, right, guard, padL, padR, charge }

extension DuelMoveInfo on DuelMove {
  bool get hazard =>
      this == DuelMove.duck ||
      this == DuelMove.left ||
      this == DuelMove.right ||
      this == DuelMove.guard;

  String get call => switch (this) {
        DuelMove.duck => 'Duck!',
        DuelMove.left => 'Left!',
        DuelMove.right => 'Right!',
        DuelMove.guard => 'Guard!',
        DuelMove.padL => 'Strike left!',
        DuelMove.padR => 'Strike right!',
        DuelMove.charge => 'Charge!',
      };

  int get basePoints => switch (this) {
        DuelMove.duck || DuelMove.left || DuelMove.right => 100,
        DuelMove.guard => 125,
        DuelMove.padL || DuelMove.padR => 75,
        DuelMove.charge => 150,
      };
}

class Guardian {
  const Guardian({
    required this.id,
    required this.name,
    required this.art,
    required this.phases,
    required this.bpm,
    this.attackNames = const {},
    this.pads = 2,
    this.calmLine = 'The guardian is calm.',
    this.intro = 'Listen for the count. Move on the hit.',
    this.blurb = '',
    this.premium = false,
  });

  final String id;
  final String name;

  /// Which original vector guardian the app draws.
  final String art;

  /// Attack scripts, one list per phase ('duck', 'left', 'right', 'guard').
  final List<List<DuelMove>> phases;

  /// BPM by difficulty name.
  final Map<String, int> bpm;
  final Map<DuelMove, String> attackNames;
  final int pads;
  final String calmLine;
  final String intro;
  final String blurb;
  final bool premium;

  factory Guardian.fromJson(Map<String, dynamic> j) {
    final names = DuelMove.values.asNameMap();
    return Guardian(
      id: j['id'] as String,
      name: j['name'] as String,
      art: j['art'] as String,
      phases: [
        for (final p in j['phases'] as List<dynamic>)
          [for (final a in p as List<dynamic>) names[a as String]!],
      ],
      bpm: {
        for (final e in (j['bpm'] as Map).entries)
          e.key as String: (e.value as num).toInt(),
      },
      attackNames: {
        for (final e in (j['attackNames'] as Map? ?? const {}).entries)
          names[e.key as String]!: e.value as String,
      },
      pads: (j['pads'] as num?)?.toInt() ?? 2,
      calmLine: j['calmLine'] as String? ?? 'The guardian is calm.',
      intro: j['intro'] as String? ?? 'Listen for the count. Move on the hit.',
      blurb: j['blurb'] as String? ?? '',
      premium: j['premium'] as bool? ?? false,
    );
  }
}

class DuelAsk {
  DuelAsk(this.id, this.move, this.at, {this.counter = false});
  final int id;
  final DuelMove move;
  final int at;
  final bool counter;
  bool resolved = false;
  Grade? grade;
  int _frames = 0;
  int? _first;
  bool _heldAtOpen = false;
  bool _seenOpen = false;
}

class DuelEngine with ArcadeClock implements ArcadeEngine {
  DuelEngine(
    this.guardian, {
    this.difficulty = 'beginner',
    this.lowImpact = true,
    this.assist = false,
    this.latencyMs = 100,
    TimingWindows windows =
        const TimingWindows(perfect: 150, good: 280, ok: 420, lateBias: 120),
  }) : windows = assist ? windows.scaled(1.25) : windows {
    beatMs = 60000 ~/ (guardian.bpm[difficulty] ?? guardian.bpm.values.first);
    _phraseEnd = 0;
    _nextPhrase();
  }

  final Guardian guardian;
  final String difficulty;
  final bool lowImpact;
  final bool assist;
  final int latencyMs;
  final TimingWindows windows;
  late final int beatMs;

  /// 'intro', 'attack', 'opening', 'rest', 'regroup', 'finale', 'done'.
  String mode = 'intro';
  int phase = 0;
  int sparks = 3;
  double poise = 0;
  late final List<double> calm = List<double>.filled(guardian.phases.length, 0);
  double surge = 0;
  int combo = 0;
  int bestCombo = 0;
  int score = 0;
  bool staggered = false;
  int regroups = 0;
  final List<DuelAsk> asks = [];
  final MoveState moves = MoveState();
  BodyPose? lastPose;

  int _phraseStart = 0;
  int _phraseEnd = 0;
  int _attackIndex = 0;
  int _loops = 0;
  int _lastSparkLoss = -100000;
  int _lastBeat = -1;
  int _nextId = 0;
  int _base = 0, _maxBase = 0;
  bool _calmed = false;
  final Map<String, int> _counts = {};

  @override
  int get clockMs => clock;
  @override
  int get durationMs => 0;
  @override
  bool get holding => isHeld;
  @override
  bool get finished => mode == 'done';

  /// Beats since the current phrase began (for the count ring).
  double get phraseBeat => (clock - _phraseStart) / beatMs;
  int get phraseBeats => ((_phraseEnd - _phraseStart) / beatMs).round();

  /// Calm across the whole duel, 0..1.
  double get calmTotal =>
      calm.fold<double>(0, (a, b) => a + b) / (100 * calm.length);

  bool get calmed => _calmed;

  /// The hazard currently counting in, if any.
  DuelAsk? get incoming {
    for (final a in asks) {
      if (!a.resolved && a.move.hazard) return a;
    }
    return null;
  }

  int get _actionT => clock - latencyMs;

  void _nextPhrase() {
    _phraseStart = _phraseEnd;
    final t0 = _phraseStart;
    final b = beatMs;
    if (mode == 'intro' && _phraseEnd == 0) {
      _phraseEnd = t0 + 8 * b;
      pending.add(ArcadeEvent('call', text: guardian.intro));
      return;
    }
    if (sparks <= 0) {
      mode = 'regroup';
      regroups++;
      sparks = 3;
      poise = 0;
      calm[phase] = 0;
      _attackIndex = 0;
      _loops = 0;
      _phraseEnd = t0 + 8 * b;
      pending.add(ArcadeEvent('regroup',
          text: regroups >= 2
              ? 'Regroup. Assist is in Settings if you want it.'
              : 'Regroup! Your sparks are back.'));
      return;
    }
    if (mode == 'opening' || mode == 'attack' && _loops >= 3) {
      if (calm[phase] >= 100 || _loops >= 3) {
        if (_loops >= 3 && calm[phase] < 100) {
          calm[phase] = 100;
          pending.add(ArcadeEvent('call',
              text: 'The ${guardian.name} respects your effort.'));
        }
        phase++;
        poise = 0;
        _attackIndex = 0;
        _loops = 0;
        if (phase >= guardian.phases.length) {
          mode = 'finale';
          _phraseEnd = t0 + 8 * b;
          final full = surge >= 100;
          asks.add(DuelAsk(_nextId++, DuelMove.charge, t0 + 4 * b));
          pending.add(ArcadeEvent('call',
              text: full
                  ? 'Surge finisher! Arms up and hold!'
                  : 'Final charge! Arms up!'));
          return;
        }
        mode = 'rest';
        _phraseEnd = t0 + 8 * b;
        pending.add(
            ArcadeEvent('phase', value: phase, text: 'Breathe. Next phase.'));
        return;
      }
      poise = 50;
    }
    if (mode == 'finale') {
      mode = 'done';
      _calmed = true;
      pending.add(ArcadeEvent('calmed', text: guardian.calmLine));
      return;
    }
    final script = guardian.phases[phase];
    if (poise >= 100 || _attackIndex >= script.length) {
      staggered = poise >= 100;
      if (!staggered) _loops++;
      _attackIndex = 0;
      mode = 'opening';
      final pads = math.min(guardian.pads, difficulty == 'advanced' ? 3 : 2);
      var t = t0 + 2 * b;
      for (var i = 0; i < pads; i++) {
        asks.add(
            DuelAsk(_nextId++, i.isEven ? DuelMove.padL : DuelMove.padR, t));
        t += 2 * b;
      }
      asks.add(DuelAsk(_nextId++, DuelMove.charge, t));
      _phraseEnd = t + 2 * b;
      pending.add(ArcadeEvent(staggered ? 'stagger' : 'opening',
          text: staggered ? 'Stagger! Strike the pads!' : 'An opening!'));
      return;
    }
    mode = 'attack';
    final move = script[_attackIndex++];
    final at = t0 + 4 * b;
    asks.add(DuelAsk(_nextId++, move, at));
    _phraseEnd = t0 + 8 * b;
    pending.add(ArcadeEvent('telegraph',
        id: asks.last.id,
        text: guardian.attackNames[move] ?? move.call,
        value: move.index));
  }

  @override
  void advance(int dtMs, {required bool tracked}) {
    if (finished) return;
    tick(dtMs, tracked);
    if (isHeld) return;
    final beat = (clock - _phraseStart) ~/ beatMs;
    if (beat != _lastBeat || clock < _phraseStart) {
      _lastBeat = beat;
      pending.add(ArcadeEvent('beat', value: beat));
      for (final a in asks) {
        if (!a.resolved && a.move.hazard) {
          final left = ((a.at - clock) / beatMs).round();
          if (left >= 1 && left <= 3) {
            pending.add(ArcadeEvent('count', value: 4 - left, id: a.id));
          } else if (left == 0) {
            pending.add(ArcadeEvent('impact', id: a.id, text: a.move.call));
          }
        }
      }
    }
    for (final a in asks) {
      if (a.resolved) continue;
      if (_actionT - a.at > windows.close) _expire(a);
    }
    asks.removeWhere((a) => a.resolved && clock - a.at > 3000);
    if (clock >= _phraseEnd) {
      _lastBeat = -1;
      _nextPhrase();
    }
  }

  void _expire(DuelAsk a) {
    a.resolved = true;
    _maxBase += a.move.basePoints;
    if (inGrace) {
      forgivenCount++;
      _maxBase -= a.move.basePoints;
      pending.add(ArcadeEvent('forgiven', id: a.id));
      return;
    }
    a.grade = Grade.miss;
    if (a.move.hazard) {
      combo = 0;
      if (clock - _lastSparkLoss >= 2000) {
        _lastSparkLoss = clock;
        sparks = math.max(0, sparks - 1);
        pending.add(ArcadeEvent('hit',
            id: a.id,
            text: switch (a.move) {
              DuelMove.duck => 'That was a duck, low!',
              DuelMove.left => 'Lean to your left!',
              DuelMove.right => 'Lean to your right!',
              _ => 'Guard up by your face!',
            }));
      } else {
        pending.add(ArcadeEvent('glance', id: a.id));
      }
    } else {
      pending.add(ArcadeEvent('missPad', id: a.id));
    }
  }

  bool _doing(DuelMove m, BodyPose b) {
    final hip = b.hipCenter;
    return switch (m) {
      DuelMove.duck => moves.squat,
      DuelMove.left => moves.leanLeft || (hip.seen && hip.x < -0.3),
      DuelMove.right => moves.leanRight || (hip.seen && hip.x > 0.3),
      DuelMove.guard => b.isGuard,
      DuelMove.padL => b.handIn(BodySide.left, -1.15, 0.05, 0.6),
      DuelMove.padR => b.handIn(BodySide.right, 1.15, 0.05, 0.6),
      DuelMove.charge => moves.armsUp ||
          b.armsUp ||
          (lowImpact &&
              b.nose.seen &&
              ((b.leftHand.seen && b.leftHand.y > b.nose.y + 0.15) ||
                  (b.rightHand.seen && b.rightHand.y > b.nose.y + 0.15))),
    };
  }

  @override
  void pose(BodyPose body) {
    lastPose = body;
    if (isHeld || finished) return;
    for (final a in List.of(asks)) {
      if (a.resolved) continue;
      final off = _actionT - a.at;
      if (off < windows.open || off > windows.close) continue;
      final doing = _doing(a.move, body);
      if (!a._seenOpen) {
        a._seenOpen = true;
        a._heldAtOpen = doing;
      }
      if (!doing) {
        a._frames = 0;
        a._first = null;
        a._heldAtOpen = false;
        continue;
      }
      a._frames++;
      a._first ??= _actionT;
      final need = a.move == DuelMove.duck ||
              a.move == DuelMove.left ||
              a.move == DuelMove.right
          ? 1
          : 2;
      if (a._frames >= need) _answer(a);
    }
  }

  void _answer(DuelAsk a) {
    var g = windows.grade(a._first! - a.at);
    if (g == Grade.miss) g = Grade.ok;
    if (a._heldAtOpen && g == Grade.perfect) g = Grade.good;
    a.resolved = true;
    a.grade = g;
    combo++;
    bestCombo = math.max(bestCombo, combo);
    final mult = math.min(2.0, 1 + 0.1 * (combo ~/ 5));
    final base = a.move.basePoints;
    _base += base;
    _maxBase += base;
    final pts = (base * (g == Grade.perfect ? 1.25 : 1) * mult).round();
    score += pts;
    surge = math.min(
        100,
        surge +
            switch (g) {
              Grade.perfect => 15,
              Grade.good => 10,
              _ => 5,
            });
    final key = switch (a.move) {
      DuelMove.duck => 'duck',
      DuelMove.left || DuelMove.right => 'lean',
      DuelMove.guard => 'guard',
      DuelMove.padL || DuelMove.padR => 'side strike',
      DuelMove.charge => 'arms up',
    };
    _counts[key] = (_counts[key] ?? 0) + 1;
    final stag = staggered ? 1.5 : 1.0;
    if (a.move.hazard) {
      poise = math.min(
          100,
          poise +
              switch (g) {
                Grade.perfect => 25,
                Grade.good => 20,
                _ => 15,
              });
      final counter = switch (difficulty) {
        'advanced' => true,
        'intermediate' => g != Grade.ok,
        _ => g == Grade.perfect,
      };
      if (counter && !a.counter) {
        final side = a.move == DuelMove.left ? DuelMove.padR : DuelMove.padL;
        asks.add(DuelAsk(_nextId++, side, a.at + 2 * beatMs, counter: true));
      }
    } else if (a.move == DuelMove.padL || a.move == DuelMove.padR) {
      if (a.counter) {
        poise = math.min(100, poise + 10);
      } else {
        calm[_calmPhase] = math.min(100, calm[_calmPhase] + 20 * stag);
      }
    } else if (a.move == DuelMove.charge) {
      if (mode == 'finale' || surge >= 100) {
        if (mode != 'finale') calm[_calmPhase] = 100;
        surge = mode == 'finale' ? surge : 0;
      } else {
        calm[_calmPhase] = math.min(100, calm[_calmPhase] + 40 * stag);
      }
    }
    pending.add(ArcadeEvent(a.move.hazard ? 'answer' : 'strike',
        id: a.id,
        grade: g,
        points: pts,
        side: a.move == DuelMove.padL
            ? BodySide.left
            : a.move == DuelMove.padR
                ? BodySide.right
                : null,
        value: a.move.index));
  }

  int get _calmPhase => math.min(phase, calm.length - 1);

  @override
  void motion(MotionEvent event) => moves.apply(event);

  @override
  List<ArcadeEvent> drainEvents() => drain();

  double get accuracy => _maxBase == 0 ? 0 : _base / _maxBase;

  @override
  ArcadeSummary get summary {
    final stars = !_calmed
        ? 0
        : 1 +
            (sparks >= 2 && regroups == 0 ? 1 : 0) +
            (accuracy >= 0.8 ? 1 : 0);
    return ArcadeSummary(
      gameId: 'craftguard',
      stageId: guardian.id,
      score: score,
      stars: stars,
      maxStars: 3,
      accuracy: accuracy,
      bestCombo: bestCombo,
      activeMs: clock,
      completed: _calmed,
      headline: _calmed
          ? 'You calmed the ${guardian.name}'
          : 'The ${guardian.name} waits for a rematch',
      moves: Map.of(_counts),
      forgiven: forgivenCount,
      details: {
        'Seal': switch (stars) {
          3 => 'Indigo',
          2 => 'Brass',
          1 => 'Clay',
          _ => '—',
        },
        'Sparks left': '$sparks',
        if (regroups > 0) 'Regroups': '$regroups',
      },
    );
  }
}
