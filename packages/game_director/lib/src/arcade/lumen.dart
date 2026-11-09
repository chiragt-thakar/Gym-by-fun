import 'dart:math' as math;

import 'package:motion_core/motion_core.dart';

import 'arcade.dart';

/// LUMEN: ORBITAL ARCHITECT — restore a ring habitat by routing energy.
/// Reach to a numbered tool card to pick a conduit, lean to turn it, then a
/// comfortable bend (or a hands-together hold) welds a connected route.
/// Thinking takes no game time; nothing ever runs out.

enum Dir { n, e, s, w }

extension DirOps on Dir {
  Dir get opposite => Dir.values[(index + 2) % 4];
  int get dr => switch (this) { Dir.n => -1, Dir.s => 1, _ => 0 };
  int get dc => switch (this) { Dir.e => 1, Dir.w => -1, _ => 0 };
}

enum PieceType { straight, corner }

class LumenPiece {
  LumenPiece(this.r, this.c, this.type, this.rot,
      {this.card, this.fixed = false});
  final int r;
  final int c;
  final PieceType type;
  int rot;

  /// Tool card number (1–3) for an editable conduit.
  final int? card;
  final bool fixed;

  /// Ports in clockwise order N-E, E-S, S-W, W-N for corners;
  /// N-S, E-W for straights.
  Set<Dir> get ports => type == PieceType.straight
      ? (rot.isEven ? {Dir.n, Dir.s} : {Dir.e, Dir.w})
      : const [
          {Dir.n, Dir.e},
          {Dir.e, Dir.s},
          {Dir.s, Dir.w},
          {Dir.w, Dir.n},
        ][rot % 4];

  void turn(bool clockwise) {
    final n = type == PieceType.straight ? 2 : 4;
    rot = (rot + (clockwise ? 1 : n - 1)) % n;
  }

  LumenPiece copy() => LumenPiece(r, c, type, rot, card: card, fixed: fixed);

  factory LumenPiece.fromJson(Map<String, dynamic> j) => LumenPiece(
        (j['r'] as num).toInt(),
        (j['c'] as num).toInt(),
        PieceType.values.byName(j['type'] as String),
        (j['rot'] as num).toInt(),
        card: (j['card'] as num?)?.toInt(),
        fixed: j['fixed'] as bool? ?? false,
      );
}

class LumenBoard {
  LumenBoard({
    required this.id,
    required this.title,
    required this.module,
    required this.rows,
    required this.cols,
    required this.source,
    required this.receiver,
    required this.pieces,
    this.story = '',
  });

  final String id;
  final String title;

  /// What the repair restores: light, water, air, canopy, ...
  final String module;
  final int rows;
  final int cols;

  /// Source cell and the direction it emits.
  final (int, int, Dir) source;

  /// Receiver cell and the side it accepts energy from.
  final (int, int, Dir) receiver;
  final List<LumenPiece> pieces;
  final String story;

  factory LumenBoard.fromJson(Map<String, dynamic> j) {
    (int, int, Dir) cell(Map<String, dynamic> m) => (
          (m['r'] as num).toInt(),
          (m['c'] as num).toInt(),
          Dir.values.byName(m['dir'] as String),
        );
    return LumenBoard(
      id: j['id'] as String,
      title: j['title'] as String,
      module: j['module'] as String,
      rows: (j['rows'] as num).toInt(),
      cols: (j['cols'] as num).toInt(),
      source: cell(j['source'] as Map<String, dynamic>),
      receiver: cell(j['receiver'] as Map<String, dynamic>),
      pieces: [
        for (final p in j['pieces'] as List<dynamic>)
          LumenPiece.fromJson(p as Map<String, dynamic>),
      ],
      story: j['story'] as String? ?? '',
    );
  }

  LumenBoard copy() => LumenBoard(
        id: id,
        title: title,
        module: module,
        rows: rows,
        cols: cols,
        source: source,
        receiver: receiver,
        pieces: [for (final p in pieces) p.copy()],
        story: story,
      );

  LumenPiece? at(int r, int c) {
    for (final p in pieces) {
      if (p.r == r && p.c == c) return p;
    }
    return null;
  }

  List<LumenPiece> get editable => pieces.where((p) => p.card != null).toList()
    ..sort((a, b) => a.card!.compareTo(b.card!));

  /// Follows the energy from the source. Returns the lit cells in order and
  /// whether the route reaches the receiver from its accepting side.
  (List<(int, int)>, bool) trace() {
    final lit = <(int, int)>[];
    var travel = source.$3;
    var r = source.$1 + travel.dr, c = source.$2 + travel.dc;
    for (var guard = 0; guard <= rows * cols + 2; guard++) {
      if (r == receiver.$1 && c == receiver.$2) {
        return (lit, travel.opposite == receiver.$3);
      }
      if (r < 0 || c < 0 || r >= rows || c >= cols) break;
      final p = at(r, c);
      if (p == null) break;
      final into = travel.opposite;
      final ports = p.ports;
      if (!ports.contains(into)) break;
      lit.add((r, c));
      travel = ports.firstWhere((d) => d != into);
      r += travel.dr;
      c += travel.dc;
    }
    return (lit, false);
  }

  bool get connected => trace().$2;
}

class LumenStage {
  const LumenStage({
    required this.id,
    required this.name,
    required this.habitat,
    required this.boards,
    this.blurb = '',
  });
  final String id;
  final String name;
  final String habitat;
  final List<LumenBoard> boards;
  final String blurb;

  factory LumenStage.fromJson(Map<String, dynamic> j) => LumenStage(
        id: j['id'] as String,
        name: j['name'] as String,
        habitat: j['habitat'] as String,
        boards: [
          for (final b in j['boards'] as List<dynamic>)
            LumenBoard.fromJson(b as Map<String, dynamic>),
        ],
        blurb: j['blurb'] as String? ?? '',
      );
}

/// Body-space tool card zones (below shoulder height, never overhead).
const lumenCards = <int, (double, double)>{
  1: (-1.2, -0.55),
  2: (0.0, -0.3),
  3: (1.2, -0.55),
};

class LumenEngine with ArcadeClock implements ArcadeEngine {
  LumenEngine(this.stage,
      {this.noSquat = false,
      this.dwellMs = 450,
      this.rearmMs = 300,
      this.cardRadius = 0.45}) {
    _load(0);
  }

  final LumenStage stage;

  /// Weld with a hands-together hold instead of a bend.
  final bool noSquat;
  final int dwellMs;
  final int rearmMs;
  final double cardRadius;

  int boardIndex = 0;
  late LumenBoard board;

  /// 'intro', 'inspect', 'edit', 'ready', 'restoring', 'rest', 'done'.
  String state = 'intro';
  int _stateAt = 0;
  int? selected;
  int? hover;
  int dwell = 0;
  int weldHold = 0;
  int _neutralFor = 0;
  bool _armed = true;
  bool _weldArmed = false;
  int restored = 0;
  int selections = 0, turns = 0, welds = 0;
  final MoveState moves = MoveState();
  bool _together = false;
  bool _ambiguous = false;

  @override
  int get clockMs => clock;
  @override
  int get durationMs => 0;
  @override
  bool get holding => isHeld;
  @override
  bool get finished => state == 'done';

  int get stateMs => clock - _stateAt;
  double get dwellProgress => (dwell / dwellMs).clamp(0.0, 1.0);
  double get weldProgress => (weldHold / 700).clamp(0.0, 1.0);
  bool get armed => _armed;
  bool get weldArmed => _weldArmed;

  void _load(int i) {
    boardIndex = i;
    board = stage.boards[i].copy();
    selected = null;
    _set('intro');
    pending.add(ArcadeEvent('board', value: i, text: board.title));
  }

  void _set(String s) {
    state = s;
    _stateAt = clock;
    dwell = 0;
    weldHold = 0;
  }

  @override
  void advance(int dtMs, {required bool tracked}) {
    if (finished) return;
    final dt = tick(dtMs, tracked);
    if (isHeld) {
      // Incomplete gestures are discarded; the board itself is kept.
      dwell = 0;
      weldHold = 0;
      _armed = false;
      _weldArmed = false;
      _neutralFor = 0;
      return;
    }
    final neutral = hover == null && !_together && !_ambiguous;
    _neutralFor = neutral ? _neutralFor + dt : 0;
    if (_neutralFor >= rearmMs) _armed = true;
    switch (state) {
      case 'intro':
        if (stateMs >= 2500) _set('inspect');
      case 'inspect' || 'edit' || 'ready':
        _selection(dt);
        if (state == 'ready') {
          if (_neutralFor >= rearmMs && !moves.leanLeft && !moves.leanRight) {
            if (!_weldArmed) pending.add(const ArcadeEvent('weldReady'));
            _weldArmed = true;
          }
          if (noSquat && _weldArmed && _together) {
            weldHold += dt;
            if (weldHold >= 700) _weld();
          } else {
            weldHold = 0;
          }
        }
      case 'restoring':
        if (stateMs >= 3500) {
          restored++;
          pending.add(ArcadeEvent('restored',
              value: boardIndex, text: '${board.title} restored'));
          if (boardIndex + 1 >= stage.boards.length) {
            _set('done');
          } else {
            _set('rest');
            pending.add(const ArcadeEvent('rest',
                text: 'Rest your arms. Reach to card 2 when you are ready.'));
          }
        }
      case 'rest':
        if (stateMs >= 3000) {
          _selection(dt, continueOnly: true);
        }
    }
  }

  void _selection(int dt, {bool continueOnly = false}) {
    final h = hover;
    if (h == null || !_armed || _ambiguous || (state == 'ready' && _together)) {
      dwell = 0;
      return;
    }
    if (continueOnly && h != 2) {
      dwell = 0;
      return;
    }
    dwell += dt;
    if (dwell < dwellMs) return;
    dwell = 0;
    _armed = false;
    _neutralFor = 0;
    if (continueOnly) {
      _load(boardIndex + 1);
      return;
    }
    final cards = board.editable;
    if (h > cards.length) return;
    selected = h;
    selections++;
    _weldArmed = false;
    _set('edit');
    pending.add(ArcadeEvent('select', value: h));
  }

  @override
  void pose(BodyPose body) {
    if (isHeld) return;
    final r = cardRadius;
    final hits = <int>{};
    for (final e in lumenCards.entries) {
      final (x, y) = e.value;
      final side = e.key == 1
          ? BodySide.left
          : e.key == 3
              ? BodySide.right
              : null;
      if (body.handIn(side, x, y, r)) hits.add(e.key);
    }
    _together = body.handsTogether;
    // A hand in two different cards at once is ambiguous: cancel.
    _ambiguous = hits.length > 1;
    hover = hits.length == 1 && !_together ? hits.first : null;
    if (_together && state != 'ready') hover = null;
  }

  @override
  void motion(MotionEvent event) {
    moves.apply(event);
    if (isHeld) return;
    if (event is MoveStarted) {
      final lean = event.move == Move.leanLeft || event.move == Move.leanRight;
      if (lean && (state == 'edit' || state == 'ready') && stateMs >= 400) {
        _rotate(event.move == Move.leanRight);
      } else if (event.move == Move.squat &&
          state == 'ready' &&
          _weldArmed &&
          !noSquat) {
        _weld();
      }
    }
  }

  void _rotate(bool clockwise) {
    final s = selected;
    if (s == null) return;
    final piece = board.editable[s - 1];
    piece.turn(clockwise);
    turns++;
    pending.add(ArcadeEvent('turn',
        value: s, side: clockwise ? BodySide.right : BodySide.left));
    final ok = board.connected;
    if (ok && state != 'ready') {
      _set('ready');
      _weldArmed = false;
      pending.add(ArcadeEvent('connected',
          text: noSquat
              ? 'Connected! Arms down, then hold your hands together to weld.'
              : 'Connected! Arms down, then a comfortable bend to weld.'));
    } else if (!ok && state == 'ready') {
      _set('edit');
      pending.add(const ArcadeEvent('broken'));
    }
  }

  void _weld() {
    welds++;
    _weldArmed = false;
    _set('restoring');
    pending.add(ArcadeEvent('weld', value: boardIndex, text: board.story));
  }

  @override
  List<ArcadeEvent> drainEvents() => drain();

  @override
  ArcadeSummary get summary => ArcadeSummary(
        gameId: 'lumen',
        stageId: stage.id,
        score: restored * 250 + math.max(0, 50 - turns),
        stars: (restored / stage.boards.length * 3).round(),
        maxStars: 3,
        accuracy: restored / stage.boards.length,
        bestCombo: restored,
        activeMs: clock,
        completed: finished,
        headline: '${stage.name}: $restored of ${stage.boards.length} repairs',
        moves: {
          'tool reaches': selections,
          'leans': turns,
          if (noSquat) 'hands-together welds': welds else 'bend welds': welds,
        },
        details: {
          'Restored': '$restored / ${stage.boards.length}',
          'Tool actions': '${selections + turns + welds}',
        },
      );
}
