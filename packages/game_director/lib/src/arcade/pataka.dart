import 'dart:math' as math;

import 'package:motion_core/motion_core.dart';

import 'arcade.dart';

/// PATAKA POSE — a glowing firecracker cut-out flies in; strike and hold
/// its shape before it reaches you and it bursts into confetti.

enum FrameKind { cutout, chill, statue }

class PatakaPose {
  const PatakaPose({
    required this.target,
    required this.name,
    required this.call,
    this.holdMs = 1500,
    this.upperBody = true,
    this.demanding = false,
  });

  final PoseTarget target;
  final String name;

  /// Kavi's call line.
  final String call;
  final int holdMs;

  /// Playable without the legs in view (seated / small rooms).
  final bool upperBody;

  /// Squat / lunge / balance shapes: never more than two in a row.
  final bool demanding;

  String get id => target.id;

  factory PatakaPose.fromJson(Map<String, dynamic> j) => PatakaPose(
        target: PoseTarget.fromJson(j),
        name: j['name'] as String,
        call: j['call'] as String? ?? j['name'] as String,
        holdMs: (j['holdMs'] as num?)?.toInt() ?? 1500,
        upperBody: j['upperBody'] as bool? ?? true,
        demanding: j['demanding'] as bool? ?? false,
      );
}

/// Comfort bands, never age: they set lead time, lock threshold and hold.
class PatakaBand {
  const PatakaBand(this.id, this.leadMs, this.lock, this.holdScale, this.tol);
  final String id;
  final int leadMs;
  final double lock;
  final double holdScale;
  final double tol;

  static const chai = PatakaBand('chai', 3500, 72, 0.8, 6);
  static const mela = PatakaBand('mela', 2800, 78, 1.0, 0);
  static const mirchi = PatakaBand('mirchi', 2000, 84, 1.3, -5);
  static const pro = PatakaBand('pro', 1600, 88, 1.5, -10);
  static const all = [chai, mela, mirchi, pro];
  static PatakaBand byId(String id) =>
      all.firstWhere((b) => b.id == id, orElse: () => mela);
}

class PatakaStage {
  const PatakaStage({
    required this.id,
    required this.name,
    required this.frames,
    this.band = 'mela',
    this.blurb = '',
  });
  final String id;
  final String name;

  /// Pose ids in order; 'chill' is a recovery frame, `statue:<id>` a
  /// freeze-and-hold frame.
  final List<String> frames;
  final String band;
  final String blurb;

  factory PatakaStage.fromJson(Map<String, dynamic> j) => PatakaStage(
        id: j['id'] as String,
        name: j['name'] as String,
        frames: [for (final f in j['frames'] as List<dynamic>) f as String],
        band: j['band'] as String? ?? 'mela',
        blurb: j['blurb'] as String? ?? '',
      );
}

class PatakaFrame {
  PatakaFrame(this.index, this.kind, this.pose, this.holdMs, this.player);
  final int index;
  final FrameKind kind;
  final PatakaPose? pose;
  final int holdMs;
  final int player;

  int age = 0;
  int held = 0;
  double peak = 0;
  bool locked = false;
  bool burst = false;
  bool passed = false;
  int score = 0;
  int stars = 0;
  int _lockFrames = 0;
  int _graceLeft = 300;

  double get holdFraction => (held / math.max(1, holdMs)).clamp(0.0, 1.0);
}

class PatakaEngine with ArcadeClock implements ArcadeEngine {
  PatakaEngine({
    required this.stage,
    required Map<String, PatakaPose> library,
    PatakaBand? band,
    this.players = const ['You'],
    this.framesPerTurn = 4,
    this.passMs = 5000,
    this.gapMs = 1400,
  })  : band = band ?? PatakaBand.byId(stage.band),
        _library = library,
        playerScores = List<int>.filled(players.length, 0) {
    var player = 0;
    var count = 0;
    for (var i = 0; i < stage.frames.length; i++) {
      final token = stage.frames[i];
      final kind = token == 'chill'
          ? FrameKind.chill
          : token.startsWith('statue:')
              ? FrameKind.statue
              : FrameKind.cutout;
      final pose = kind == FrameKind.chill
          ? null
          : _library[kind == FrameKind.statue ? token.substring(7) : token];
      if (kind != FrameKind.chill && pose == null) {
        throw FormatException('Unknown pose $token in ${stage.id}');
      }
      final hold = switch (kind) {
        FrameKind.chill => 1000,
        FrameKind.statue => 3000,
        FrameKind.cutout => (pose!.holdMs * this.band.holdScale).round(),
      };
      frames.add(PatakaFrame(i, kind, pose, hold, player));
      if (players.length > 1 && kind != FrameKind.chill) {
        count++;
        if (count % framesPerTurn == 0) player = (player + 1) % players.length;
      }
    }
    _phaseLeft = 1200;
  }

  final PatakaStage stage;
  final PatakaBand band;
  final Map<String, PatakaPose> _library;
  final List<String> players;
  final int framesPerTurn;
  final int passMs;
  final int gapMs;
  final List<PatakaFrame> frames = [];
  final PoseMatcher _matcher = const PoseMatcher();

  int current = 0;

  /// 'intro', 'show', 'result' or 'pass'.
  String phase = 'intro';
  int _phaseLeft = 0;
  int combo = 0;
  int bestCombo = 0;
  int score = 0;
  double similarity = 0;
  double seenWeight = 0;
  PoseAngle? worst;
  final List<double> _sims = [];
  final Map<PoseAngle, int> _fails = {};
  final Map<PoseAngle, double> _extraTol = {};
  BodyPose? _prev;
  double _motion = 0;
  final List<int> playerScores;

  int get phaseLeftMs => _phaseLeft;

  PatakaFrame? get frame => current < frames.length ? frames[current] : null;
  int get approachMs => band.leadMs + (frame?.holdMs ?? 0);

  /// 0 when the frame appears → 1 when it reaches the player.
  double get approach =>
      frame == null ? 1 : (frame!.age / approachMs).clamp(0.0, 1.0);

  /// Whose turn it is (party modes).
  int get player => frame?.player ?? 0;

  @override
  int get clockMs => clock;
  @override
  int get durationMs => 0;
  @override
  bool get holding => isHeld;
  @override
  bool get finished => current >= frames.length;

  @override
  void advance(int dtMs, {required bool tracked}) {
    if (finished) return;
    // The pass countdown runs even while the next player steps in.
    final dt = phase == 'pass' ? dtMs.clamp(0, 100) : tick(dtMs, tracked);
    if (phase == 'pass') clock += dt;
    if (dt == 0) return;
    switch (phase) {
      case 'intro' || 'result' || 'pass':
        _phaseLeft -= dt;
        if (_phaseLeft <= 0) _startFrame();
      case 'show':
        _updateFrame(dt);
    }
  }

  void _startFrame() {
    phase = 'show';
    _sims.clear();
    similarity = 0;
    final f = frame;
    if (f == null) return;
    pending.add(ArcadeEvent('call',
        id: f.index,
        text: switch (f.kind) {
          FrameKind.chill => 'Chill frame. Stand tall and breathe.',
          FrameKind.statue => 'Statue! ${f.pose!.call} — and freeze!',
          FrameKind.cutout => 'Next up: ${f.pose!.call}',
        }));
  }

  void _updateFrame(int dt) {
    final f = frame!;
    // Hover: a frame we cannot judge fairly waits for the player.
    if (f.kind != FrameKind.chill && seenWeight < 0.7) {
      pending.add(const ArcadeEvent('hover'));
      return;
    }
    f.age += dt;
    final lockAt = f.kind == FrameKind.chill ? 0.0 : band.lock;
    final frozen = f.kind != FrameKind.statue || _motion < 0.05;
    if (similarity >= lockAt && frozen) {
      f._lockFrames++;
      if (f._lockFrames >= 2 && !f.locked) {
        f.locked = true;
        pending.add(ArcadeEvent('lock', id: f.index));
      }
    }
    if (f.locked) {
      if (similarity >= lockAt - 8 && frozen) {
        f.held += dt;
        f._graceLeft = 300;
        f.peak = math.max(f.peak, similarity);
      } else if (f._graceLeft > 0) {
        f._graceLeft -= dt;
      } else {
        f.held = math.max(0, f.held - 2 * dt);
      }
    }
    if (f.held >= f.holdMs) {
      f.burst = true;
      _finishFrame(f);
    } else if (f.age >= approachMs) {
      _finishFrame(f);
    }
  }

  void _finishFrame(PatakaFrame f) {
    final peak = f.kind == FrameKind.chill ? 100.0 : f.peak;
    f.score = (peak * (f.burst ? 1 : f.holdFraction)).round();
    f.passed = f.burst || f.score >= 60;
    f.stars = f.score >= 92 && f.burst
        ? 3
        : f.score >= 80
            ? 2
            : f.score >= 60
                ? 1
                : 0;
    if (f.kind == FrameKind.chill) f.stars = 0;
    if (f.passed) {
      combo++;
      bestCombo = math.max(bestCombo, combo);
    } else {
      combo = 0;
      final w = worst;
      if (w != null) {
        final n = (_fails[w] ?? 0) + 1;
        _fails[w] = n;
        if (n == 3) {
          _extraTol[w] = (_extraTol[w] ?? 0) + 5;
          pending.add(const ArcadeEvent('adjusted',
              text: 'Kavi adjusted this shape for you.'));
        }
      }
    }
    final mult = 1 + math.min(combo, 6) * 0.0833;
    final pts = f.kind == FrameKind.chill ? 0 : (f.score * 10 * mult).round();
    score += pts;
    playerScores[f.player] += pts;
    pending.add(ArcadeEvent(f.burst ? 'burst' : (f.passed ? 'pass' : 'miss'),
        id: f.index,
        points: pts,
        value: f.stars,
        grade: f.stars == 3
            ? Grade.perfect
            : f.stars >= 1
                ? Grade.good
                : Grade.miss,
        text: f.kind == FrameKind.chill
            ? null
            : f.stars == 3
                ? 'PATAKA! The whole mohalla heard that one.'
                : f.passed
                    ? 'Locked! Statue-level confidence.'
                    : _hint(worst)));
    final next = current + 1;
    final turnChange = next < frames.length &&
        players.length > 1 &&
        frames[next].player != f.player;
    current = next;
    if (finished) return;
    phase = turnChange ? 'pass' : 'result';
    _phaseLeft = turnChange ? passMs : gapMs;
    if (turnChange) {
      pending.add(ArcadeEvent('passTurn',
          value: frames[next].player,
          text: 'Pass! ${players[frames[next].player]}, step in.'));
    }
  }

  static String _hint(PoseAngle? a) => switch (a) {
        PoseAngle.shoulderL => 'So close! Move your left arm.',
        PoseAngle.shoulderR => 'So close! Move your right arm.',
        PoseAngle.elbowL => 'So close! Bend or straighten your left elbow.',
        PoseAngle.elbowR => 'So close! Bend or straighten your right elbow.',
        PoseAngle.hipL || PoseAngle.kneeL => 'So close! Check your left leg.',
        PoseAngle.hipR || PoseAngle.kneeR => 'So close! Check your right leg.',
        PoseAngle.lean => 'So close! Mind the lean.',
        null => 'So close!',
      };

  @override
  void pose(BodyPose body) {
    final prev = _prev;
    if (prev != null) {
      var d = 0.0;
      for (final pair in [
        (prev.leftWrist, body.leftWrist),
        (prev.rightWrist, body.rightWrist),
        (prev.leftElbow, body.leftElbow),
        (prev.rightElbow, body.rightElbow),
        (prev.nose, body.nose),
        (prev.hipCenter, body.hipCenter),
      ]) {
        d += pair.$1.distanceTo(pair.$2);
      }
      _motion = _motion * 0.7 + (d / 6) * 0.3;
    }
    _prev = body;
    final f = frame;
    if (f == null || phase != 'show') {
      seenWeight = 1;
      return;
    }
    if (f.kind == FrameKind.chill) {
      final relaxed = !(body.armsUp);
      similarity = relaxed ? 100 : 50;
      seenWeight = 1;
      return;
    }
    final m = _matcher.match(body, f.pose!.target,
        tolOffset: band.tol, extra: _extraTol);
    seenWeight = m.seenWeight;
    worst = m.worst;
    _sims.add(m.similarity);
    if (_sims.length > 3) _sims.removeAt(0);
    final sorted = List.of(_sims)..sort();
    similarity = sorted[sorted.length ~/ 2];
  }

  @override
  void motion(MotionEvent event) {}

  @override
  List<ArcadeEvent> drainEvents() => drain();

  int get _scored => frames.where((f) => f.kind != FrameKind.chill).length;

  @override
  ArcadeSummary get summary {
    final scored = frames.where((f) => f.kind != FrameKind.chill);
    final done = scored.where((f) => f.index < current);
    final avg = done.isEmpty
        ? 0.0
        : done.fold<int>(0, (a, f) => a + f.score) / (done.length * 100);
    final bursts = done.where((f) => f.burst).length;
    final best = players.length > 1
        ? players[playerScores.indexOf(playerScores.reduce(math.max))]
        : null;
    return ArcadeSummary(
      gameId: 'pataka-pose',
      stageId: stage.id,
      score: score,
      stars: starsFor(avg, const [0.6, 0.75, 0.88]),
      maxStars: 3,
      accuracy: avg,
      bestCombo: bestCombo,
      activeMs: clock,
      completed: finished,
      headline: best != null
          ? '$best takes the Pataka crown!'
          : '$bursts of $_scored frames burst',
      moves: {'poses held': done.where((f) => f.passed).length},
      details: {
        'Bursts': '$bursts / $_scored',
        if (players.length > 1)
          for (var i = 0; i < players.length; i++)
            players[i]: '${playerScores[i]}',
      },
    );
  }
}
