import 'dart:math' as math;

import 'package:motion_core/motion_core.dart';

import 'arcade.dart';

/// TAAL TOOFAN — move cards land on your body on the beat. Every move family
/// you hit builds the band; fill the Josh meter for Toofan Time. Songs
/// always finish and ranking uses accuracy, so nobody "fails" a song.

enum TaalMove { clap, stepL, stepR, waveL, waveR, reachL, reachR, dip, hoy }

extension TaalMoveInfo on TaalMove {
  String get call => switch (this) {
        TaalMove.clap => 'Taali!',
        TaalMove.stepL => 'Step left',
        TaalMove.stepR => 'Step right',
        TaalMove.waveL => 'Wave left',
        TaalMove.waveR => 'Wave right',
        TaalMove.reachL => 'Reach up left',
        TaalMove.reachR => 'Reach up right',
        TaalMove.dip => 'Dip!',
        TaalMove.hoy => 'Hoy!',
      };

  /// Big moves get a little more time.
  bool get big =>
      this == TaalMove.stepL || this == TaalMove.stepR || this == TaalMove.dip;

  /// The band stem this move family builds.
  String get stem => switch (this) {
        TaalMove.clap => 'claps',
        TaalMove.stepL || TaalMove.stepR => 'dhol',
        TaalMove.waveL ||
        TaalMove.waveR ||
        TaalMove.reachL ||
        TaalMove.reachR =>
          'melody',
        TaalMove.dip => 'bass',
        TaalMove.hoy => 'toofan',
      };
}

class TaalSection {
  const TaalSection(this.name, this.kind, this.counts, this.pattern);
  final String name;

  /// intro, verse, hook, chill, finale.
  final String kind;

  /// Number of 8-counts.
  final int counts;

  /// Eight tokens: a [TaalMove] name or '-' for rest.
  final List<String> pattern;

  factory TaalSection.fromJson(Map<String, dynamic> j) => TaalSection(
        j['name'] as String,
        j['kind'] as String,
        (j['counts'] as num).toInt(),
        [for (final t in j['pattern'] as List<dynamic>) t as String],
      );
}

class TaalSong {
  const TaalSong({
    required this.id,
    required this.title,
    required this.family,
    required this.bpm,
    required this.sections,
    this.blurb = '',
    this.hook = '',
  });
  final String id;
  final String title;
  final String family;
  final int bpm;
  final List<TaalSection> sections;
  final String blurb;

  /// Name of the song's learnable hook step.
  final String hook;

  int get beatMs => 60000 ~/ bpm;
  int get totalBeats =>
      sections.fold(0, (n, s) => n + s.counts * 8) + 4; // + count-in

  factory TaalSong.fromJson(Map<String, dynamic> j) => TaalSong(
        id: j['id'] as String,
        title: j['title'] as String,
        family: j['family'] as String,
        bpm: (j['bpm'] as num).toInt(),
        sections: [
          for (final s in j['sections'] as List<dynamic>)
            TaalSection.fromJson(s as Map<String, dynamic>),
        ],
        blurb: j['blurb'] as String? ?? '',
        hook: j['hook'] as String? ?? '',
      );
}

class TaalCard {
  TaalCard(this.id, this.move, this.at, this.section, {this.toofan = false});
  final int id;
  final TaalMove move;
  final int at;
  final int section;
  final bool toofan;
  Grade? grade;
  bool skipped = false;
  bool done = false;
  int _frames = 0;
  int? _first;
  bool _seenOpen = false;
  bool _heldAtOpen = false;
}

class TaalEngine with ArcadeClock implements ArcadeEngine {
  TaalEngine(
    this.song, {
    this.level = 'light',
    this.lowImpact = true,
    this.latencyMs = 100,
  }) : windows = const TimingWindows(
            perfect: 120, good: 220, ok: 320, lateBias: 100) {
    final b = song.beatMs;
    var beat = 4; // one bar count-in
    var id = 0;
    for (var s = 0; s < song.sections.length; s++) {
      final sec = song.sections[s];
      _sectionStarts.add(beat * b);
      for (var c = 0; c < sec.counts; c++) {
        for (var i = 0; i < 8; i++) {
          final token = sec.pattern[i];
          final keep = switch (level) {
            'light' => i.isEven,
            'groove' => i != 7,
            _ => true,
          };
          final move = TaalMove.values.asNameMap()[token];
          if (move != null && keep && sec.kind != 'chill') {
            cards.add(TaalCard(id++, move, (beat + c * 8 + i) * b, s));
          }
        }
      }
      beat += sec.counts * 8;
    }
    _endMs = beat * b + 1500;
    _nextId = id;
    leadMs = math.max(
        switch (level) { 'light' => 6, 'groove' => 5, _ => 4 } * b,
        switch (level) { 'light' => 2000, 'groove' => 1600, _ => 1300 });
  }

  final TaalSong song;
  final String level;
  final bool lowImpact;
  final int latencyMs;
  final TimingWindows windows;
  final List<TaalCard> cards = [];
  final List<int> _sectionStarts = [];
  final MoveState moves = MoveState();
  late final int leadMs;
  late final int _endMs;
  int _nextId = 0;

  int score = 0;
  int combo = 0;
  int bestCombo = 0;
  double josh = 0;
  int toofanUntil = -1;
  bool _toofanCalled = false;
  int _lastBeat = -1;
  int _countIn = 0;
  final Set<String> stems = {'drums'};
  final Map<Grade, int> grades = {for (final g in Grade.values) g: 0};
  final Map<String, int> _counts = {};

  @override
  int get clockMs => clock;
  @override
  int get durationMs => _endMs;
  @override
  bool get holding => isHeld || _countIn > 0;
  @override
  bool get finished => clock >= _endMs;

  bool get toofan => clock < toofanUntil;
  int get beat => clock ~/ song.beatMs;

  /// Section being danced now.
  int get section {
    var s = 0;
    for (var i = 0; i < _sectionStarts.length; i++) {
      if (clock >= _sectionStarts[i]) s = i;
    }
    return s;
  }

  int get multiplier => combo >= 50
      ? 4
      : combo >= 25
          ? 3
          : combo >= 10
              ? 2
              : 1;

  Iterable<TaalCard> get visible => cards.where((c) =>
      !c.done && c.at - leadMs <= clock && clock <= c.at + windows.close);

  int get _actionT => clock - latencyMs;

  @override
  void advance(int dtMs, {required bool tracked}) {
    if (finished) return;
    final wasHeld = isHeld;
    if (_countIn > 0 && tracked) {
      // Count back in on the beat before the song moves again.
      final before = _countIn;
      _countIn = math.max(0, _countIn - dtMs.clamp(0, 100));
      final b = song.beatMs;
      if ((before - 1) ~/ b != (_countIn - 1) ~/ b || _countIn == 0) {
        pending.add(ArcadeEvent('countIn', value: (_countIn + b - 1) ~/ b));
      }
      return;
    }
    tick(dtMs, tracked);
    if (isHeld) return;
    if (wasHeld) {
      _countIn = 4 * song.beatMs;
      return;
    }
    if (beat != _lastBeat) {
      _lastBeat = beat;
      pending.add(ArcadeEvent('beat',
          value: beat, id: song.sections[section].kind.hashCode & 0xff));
      for (final c in cards) {
        if (!c.done && c.at - song.beatMs == beat * song.beatMs) {
          pending.add(ArcadeEvent('call', id: c.id, text: c.move.call));
        }
      }
    }
    _maybeToofan();
    for (final c in cards) {
      if (c.done) continue;
      if (_actionT - c.at > windows.close + (c.move.big ? 20 : 0)) {
        c.done = true;
        if (inGrace) {
          c.skipped = true;
          pending.add(ArcadeEvent('skip', id: c.id));
        } else {
          c.grade = Grade.miss;
          grades[Grade.miss] = grades[Grade.miss]! + 1;
          combo = 0;
          pending.add(ArcadeEvent('miss', id: c.id));
          if (c.toofan) _toofanCalled = false;
        }
      }
    }
  }

  void _maybeToofan() {
    if (josh < 32 || toofan || _toofanCalled) return;
    final b = song.beatMs;
    // On the next 8-count downbeat, at least two beats away.
    final start = _sectionStarts.first;
    var at = ((clock - start) ~/ (8 * b) + 1) * 8 * b + start;
    if (at - clock < 2 * b) at += 8 * b;
    if (at >= _endMs - 4 * b) return;
    cards.removeWhere((c) => c.at == at && !c.done);
    cards.add(TaalCard(_nextId++, TaalMove.hoy, at, section, toofan: true));
    cards.sort((a, c) => a.at.compareTo(c.at));
    _toofanCalled = true;
    pending.add(const ArcadeEvent('toofanCall', text: 'Toofan! Arms up!'));
  }

  bool _doing(TaalMove m, BodyPose b) {
    final hip = b.hipCenter;
    return switch (m) {
      TaalMove.clap => b.handsTogether,
      TaalMove.stepL => moves.leanLeft || (hip.seen && hip.x < -0.25),
      TaalMove.stepR => moves.leanRight || (hip.seen && hip.x > 0.25),
      TaalMove.waveL => b.handIn(BodySide.left, -1.0, 0.45, 0.6),
      TaalMove.waveR => b.handIn(BodySide.right, 1.0, 0.45, 0.6),
      TaalMove.reachL => b.handIn(BodySide.left, -0.6, 1.05, 0.55),
      TaalMove.reachR => b.handIn(BodySide.right, 0.6, 1.05, 0.55),
      TaalMove.dip => moves.squat || (hip.seen && hip.y < -1.2),
      TaalMove.hoy => moves.armsUp ||
          b.armsUp ||
          (lowImpact &&
              b.nose.seen &&
              ((b.leftHand.seen && b.leftHand.y > b.nose.y + 0.15) ||
                  (b.rightHand.seen && b.rightHand.y > b.nose.y + 0.15))),
    };
  }

  @override
  void pose(BodyPose body) {
    if (holding || finished) return;
    for (final c in cards) {
      if (c.done) continue;
      final off = _actionT - c.at;
      final extra = c.move.big ? 20 : 0;
      if (off < windows.open - extra) break; // cards are time-ordered
      if (off > windows.close + extra) continue;
      final doing = _doing(c.move, body);
      if (!c._seenOpen) {
        c._seenOpen = true;
        c._heldAtOpen = doing;
      }
      if (!doing) {
        c._frames = 0;
        c._first = null;
        c._heldAtOpen = false;
        continue;
      }
      c._frames++;
      c._first ??= _actionT;
      final need = c.move == TaalMove.clap ? 1 : 2;
      if (c._frames >= need) _hit(c);
    }
  }

  void _hit(TaalCard c) {
    var g = windows.grade(c._first! - c.at);
    if (g == Grade.miss) g = Grade.ok;
    if (c._heldAtOpen && g == Grade.perfect) g = Grade.good;
    c.done = true;
    c.grade = g;
    grades[g] = grades[g]! + 1;
    combo++;
    bestCombo = math.max(bestCombo, combo);
    final base = switch (g) {
      Grade.perfect => 300,
      Grade.good => 100,
      _ => 50,
    };
    final pts = base * multiplier * (toofan ? 2 : 1);
    score += pts;
    if (!toofan) {
      josh += switch (g) {
        Grade.perfect => 2,
        Grade.good => 1,
        _ => 0.5,
      };
    }
    final key = switch (c.move) {
      TaalMove.clap => 'clap',
      TaalMove.stepL || TaalMove.stepR => 'step',
      TaalMove.waveL || TaalMove.waveR => 'wave',
      TaalMove.reachL || TaalMove.reachR => 'reach',
      TaalMove.dip => 'dip',
      TaalMove.hoy => 'arms up',
    };
    _counts[key] = (_counts[key] ?? 0) + 1;
    final newStem = stems.add(c.move.stem);
    if (c.toofan) {
      toofanUntil = clock + 32 * song.beatMs;
      josh = 0;
      _toofanCalled = false;
      stems.add('toofan');
      pending.add(const ArcadeEvent('toofan', text: 'Toofan Time!'));
    }
    pending.add(ArcadeEvent('hit',
        id: c.id,
        grade: g,
        points: pts,
        value: c.move.index,
        text: newStem ? 'The ${c.move.stem} joins the band!' : null));
  }

  @override
  void motion(MotionEvent event) => moves.apply(event);

  @override
  List<ArcadeEvent> drainEvents() => drain();

  int get scoredCards => cards.where((c) => c.done && !c.skipped).length;

  double get accuracy {
    final n = scoredCards;
    if (n == 0) return 0;
    return (grades[Grade.perfect]! +
            0.6 * grades[Grade.good]! +
            0.25 * grades[Grade.ok]!) /
        n;
  }

  @override
  ArcadeSummary get summary {
    final stars = starsFor(accuracy, const [0.4, 0.55, 0.7, 0.82, 0.92]);
    final fullGroove = grades[Grade.miss] == 0 && scoredCards > 0;
    return ArcadeSummary(
      gameId: 'taal-toofan',
      stageId: song.id,
      score: score,
      stars: stars,
      maxStars: 5,
      accuracy: accuracy,
      bestCombo: bestCombo,
      activeMs: clock,
      completed: finished,
      headline: fullGroove
          ? 'Full Groove on ${song.title}!'
          : '${(accuracy * 100).round()}% on ${song.title}',
      moves: Map.of(_counts),
      forgiven: cards.where((c) => c.skipped).length,
      details: {
        'Accuracy': '${(accuracy * 100).round()}%',
        'Perfect': '${grades[Grade.perfect]}',
        'Band': '${stems.length} stems',
      },
    );
  }
}
