import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';

/// What the Flutter HUD shows on top of the game.
class HudState {
  const HudState({
    this.hearts = 3,
    this.maxHearts = 3,
    this.energy = 0,
    this.score = 0,
    this.progress = 0,
    this.light = TrackingLight.green,
    this.hint,
    this.trackingIssue,
    this.lastOutcome,
  });

  final int hearts;
  final int maxHearts;
  final int energy;
  final int score;
  final double progress;
  final TrackingLight light;
  final String? hint;
  final TrackingIssue? trackingIssue;
  final Outcome? lastOutcome;

  HudState copyWith({
    int? hearts,
    int? energy,
    int? score,
    double? progress,
    TrackingLight? light,
    String? hint,
    bool clearHint = false,
    TrackingIssue? trackingIssue,
    bool clearIssue = false,
    Outcome? lastOutcome,
  }) => HudState(
    hearts: hearts ?? this.hearts,
    maxHearts: maxHearts,
    energy: energy ?? this.energy,
    score: score ?? this.score,
    progress: progress ?? this.progress,
    light: light ?? this.light,
    hint: clearHint ? null : (hint ?? this.hint),
    trackingIssue: clearIssue ? null : (trackingIssue ?? this.trackingIssue),
    lastOutcome: lastOutcome ?? this.lastOutcome,
  );
}

/// Side effects the game asks for (sound, voice), so it stays testable.
abstract class GameAudio {
  void cue(String name);
  void say(String text);
  void sayKey(String key);
}

/// Forest Escape, rendered from the pure-Dart [RunEngine].
///
/// The engine owns the rules; this class only draws and forwards input. A
/// recognised move does nothing unless the engine says it matters.
class ForestGame extends FlameGame {
  ForestGame({
    required this.engine,
    required this.motionEvents,
    required this.audio,
    this.lightOf,
    this.issueKeyOf,
    this.onFinished,
    this.theme = SceneTheme.forest,
  }) : hud = ValueNotifier(
         HudState(hearts: engine.hearts, maxHearts: engine.level.hearts),
       );

  final RunEngine engine;
  final Stream<MotionEvent> motionEvents;
  final GameAudio audio;

  /// Colours and side scenery for the current stage.
  final SceneTheme theme;

  /// Live tracking light from the motion engine (amber slows the world).
  final TrackingLight Function()? lightOf;

  /// A more specific spoken line for a tracking issue (for example "move a
  /// little to your left"), or null to use [issueKey].
  final String? Function(TrackingIssue)? issueKeyOf;
  final void Function(RunResult)? onFinished;

  final ValueNotifier<HudState> hud;
  StreamSubscription<MotionEvent>? _sub;
  double _heroLane = 1;
  double _t = 0;
  int _hintUntilMs = 0;

  @override
  Color backgroundColor() => theme.background;

  @override
  Future<void> onLoad() async {
    _heroLane = engine.lane.toDouble();
    _sub = motionEvents.listen((e) => _handle(engine.input(e)));
  }

  @override
  void onRemove() {
    // GameWidget detaches the game when the run view leaves the tree (also
    // on a phase change); stop listening to motion straight away.
    _sub?.cancel();
    _sub = null;
    super.onRemove();
  }

  bool _disposed = false;

  /// Whether [dispose] has run; the game must not be shown again after it.
  bool get isDisposed => _disposed;

  /// Releases what the game holds outside Flame: the motion subscription and
  /// the [hud] notifier. The owner (QuestScreen) calls this exactly when it
  /// drops the game; it is not tied to [onRemove] or [onDispose] because a
  /// GameWidget may detach and re-attach the same game. Safe to call twice.
  /// Also runs [FlameGame.dispose], clearing components and image caches.
  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _sub?.cancel();
    _sub = null;
    hud.dispose();
    super.dispose();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_disposed || engine.finished) return;
    final l = lightOf?.call();
    if (l != null) engine.setLight(l);
    final ms = (dt * 1000).round().clamp(0, 100);
    _t += dt * engine.pacer.scale;
    _handle(engine.advance(ms));
    _heroLane += (engine.lane - _heroLane) * math.min(1, dt * 12);
    final now = engine.clockMs.round();
    _syncHud(clearHint: now > _hintUntilMs);
  }

  /// Progress is quantised to [_progressSteps] steps so the HUD (and its
  /// progress bar) rebuilds a few times a second instead of every frame.
  static const _progressSteps = 500;

  /// Per-frame HUD sync. Assigns a new [HudState] only when a visible field
  /// actually changed, so the Flutter HUD is not rebuilt 60 times a second.
  void _syncHud({required bool clearHint}) {
    final cur = hud.value;
    final progress =
        ((engine.clockMs / engine.level.durationMs).clamp(0.0, 1.0) *
                _progressSteps)
            .floorToDouble() /
        _progressSteps;
    final hint = clearHint ? null : cur.hint;
    if (cur.hearts == engine.hearts &&
        cur.energy == engine.energy &&
        cur.score == engine.score &&
        cur.progress == progress &&
        cur.light == engine.light &&
        cur.hint == hint) {
      return;
    }
    hud.value = cur.copyWith(
      hearts: engine.hearts,
      energy: engine.energy,
      score: engine.score,
      progress: progress,
      light: engine.light,
      clearHint: clearHint,
    );
  }

  void _handle(List<RunEvent> events) {
    if (_disposed) return;
    for (final e in events) {
      switch (e) {
        case CuePlayed():
          audio.cue(e.sound);
        case HintShown(:final text):
          _hintUntilMs = e.atMs + 2200;
          hud.value = hud.value.copyWith(hint: text);
          audio.say(text);
        case EncounterResolved(:final outcome):
          if (outcome == Outcome.cleared) audio.cue('clear');
          if (outcome == Outcome.hit && e.encounter.type.damages) {
            audio.cue('hit');
          }
          hud.value = hud.value.copyWith(lastOutcome: outcome);
        case CheckpointReached():
          audio.cue('checkpoint');
          audio.sayKey('checkpoint');
        case TrackingHint(:final issue):
          if (issue == null) {
            hud.value = hud.value.copyWith(clearIssue: true);
            audio.sayKey('tracking_back');
          } else {
            hud.value = hud.value.copyWith(trackingIssue: issue);
            audio.cue('tracking');
            audio.sayKey(issueKeyOf?.call(issue) ?? issueKey(issue));
          }
        case RunFinished(:final result):
          onFinished?.call(result);
        case LaneChanged() || HeartsChanged() || SegmentStarted():
          break;
      }
    }
  }

  static String issueKey(TrackingIssue i) => switch (i) {
    TrackingIssue.tooFar => 'too_far',
    TrackingIssue.tooClose => 'too_close',
    TrackingIssue.lowVisibility => 'low_visibility',
    TrackingIssue.noPerson || TrackingIssue.outOfFrame => 'step_back',
  };

  // ---------------------------------------------------------------- render

  late final ForestPainter _painter = ForestPainter(
    size: Size.zero,
    t: 0,
    clockMs: 0,
    plan: engine.plan,
    heroLane: _heroLane,
    ducking: false,
    armsUp: false,
    lanes: engine.level.lanes,
    warningMs: engine.director.warningMs,
    theme: theme,
  );

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // One painter per game, updated in place: no per-frame painter object.
    _painter
      ..size = Size(size.x, size.y)
      ..t = _t
      ..clockMs = engine.clockMs
      ..heroLane = _heroLane
      ..ducking = engine.ducking
      ..armsUp = engine.armsUp
      ..paint(canvas);
  }
}

/// What the side of the road is lined with.
enum SceneProps { trees, cacti }

/// A stage's look: colours and side props only. Obstacle shapes stay the
/// same in every stage so each encounter type is always readable.
class SceneTheme {
  const SceneTheme({
    required this.background,
    required this.skyTop,
    required this.skyBottom,
    required this.sun,
    required this.hillFar,
    required this.hillNear,
    required this.ground,
    required this.road,
    required this.propTrunk,
    required this.propCrown,
    required this.beam,
    required this.block,
    this.props = SceneProps.trees,
  });

  final Color background;
  final Color skyTop;
  final Color skyBottom;
  final Color sun;
  final Color hillFar;
  final Color hillNear;
  final Color ground;
  final Color road;
  final Color propTrunk;
  final Color propCrown;

  /// Obstacle tints (shapes never change).
  final Color beam;
  final Color block;
  final SceneProps props;

  static const forest = SceneTheme(
    background: Color(0xFF0E2A1B),
    skyTop: Color(0xFFFFC27A),
    skyBottom: Color(0xFF7FC8A9),
    sun: Color(0xFFFFF1C1),
    hillFar: Color(0xFF214A33),
    hillNear: Color(0xFF1A3D29),
    ground: Color(0xFF2E6B3F),
    road: Color(0xFF8C6A45),
    propTrunk: Color(0xFF4A2F1B),
    propCrown: Color(0xFF173F25),
    beam: Color(0xFF6B3E1F),
    block: Color(0xFF7A7A7A),
  );

  static const desert = SceneTheme(
    background: Color(0xFF3A2410),
    skyTop: Color(0xFFFF9E5E),
    skyBottom: Color(0xFFFFE0A3),
    sun: Color(0xFFFFFBE6),
    hillFar: Color(0xFFD9A55B),
    hillNear: Color(0xFFC78C45),
    ground: Color(0xFFE2B66E),
    road: Color(0xFFB98A4E),
    propTrunk: Color(0xFF3F7A3A),
    propCrown: Color(0xFF2F6A2E),
    beam: Color(0xFF5E8F3A),
    block: Color(0xFFA9773F),
    props: SceneProps.cacti,
  );

  /// World 3: night city, glowing magenta and cyan.
  static const neon = SceneTheme(
    background: Color(0xFF0B0820),
    skyTop: Color(0xFF1A0B3D),
    skyBottom: Color(0xFF6A1B9A),
    sun: Color(0xFFFF4FD8),
    hillFar: Color(0xFF261A55),
    hillNear: Color(0xFF1B1240),
    ground: Color(0xFF151030),
    road: Color(0xFF3A3560),
    propTrunk: Color(0xFF00E5FF),
    propCrown: Color(0xFF2A1F66),
    beam: Color(0xFFFF4FD8),
    block: Color(0xFF00B8D4),
  );

  /// World 4: cool mountain air, snow and pine.
  static const mountain = SceneTheme(
    background: Color(0xFF1C2B3A),
    skyTop: Color(0xFF9EC9F5),
    skyBottom: Color(0xFFE3F1FF),
    sun: Color(0xFFFFFFFF),
    hillFar: Color(0xFF8DA3B8),
    hillNear: Color(0xFF61788F),
    ground: Color(0xFFDCE6EE),
    road: Color(0xFF8A7F73),
    propTrunk: Color(0xFF4A3526),
    propCrown: Color(0xFF1F4D3A),
    beam: Color(0xFF6D4C3D),
    block: Color(0xFF7D8590),
  );
}

/// Paint objects for one [SceneTheme], built once and reused every frame.
/// Only stroke widths (which scale with depth) are mutated before each draw;
/// Flutter copies paint state at draw time, so this is safe.
class _ThemePaints {
  _ThemePaints(SceneTheme theme)
    : sun = Paint()..color = theme.sun,
      hillFar = Paint()..color = theme.hillFar,
      hillNear = Paint()..color = theme.hillNear,
      ground = Paint()..color = theme.ground,
      road = Paint()..color = theme.road,
      trunk = Paint()..color = theme.propTrunk,
      crown = Paint()..color = theme.propCrown,
      beam = Paint()..color = theme.beam,
      block = Paint()..color = theme.block;

  final Paint sun;
  final Paint hillFar;
  final Paint hillNear;
  final Paint ground;
  final Paint road;
  final Paint trunk;
  final Paint crown;
  final Paint beam;
  final Paint block;

  /// Sky gradient, rebuilt only when the horizon height changes.
  final Paint sky = Paint();
  double _skyHorizon = double.nan;

  Paint skyFor(SceneTheme theme, double horizon) {
    if (horizon != _skyHorizon) {
      _skyHorizon = horizon;
      sky.shader = Gradient.linear(Offset.zero, Offset(0, horizon), [
        theme.skyTop,
        theme.skyBottom,
      ]);
    }
    return sky;
  }
}

/// Procedural 2.5D forest: layered parallax, perspective lanes, big clear
/// silhouettes. Obstacles differ by shape and sound, never by colour alone.
///
/// Runs every frame, so it allocates no Paint, Path, Shader or List objects
/// per frame: paints are cached per theme, paths are reused via `reset()`,
/// and visible encounters are found by binary search over the time-sorted
/// plan instead of filtering and sorting a new list.
class ForestPainter {
  ForestPainter({
    required this.size,
    required this.t,
    required this.clockMs,
    required this.plan,
    required this.heroLane,
    required this.ducking,
    required this.armsUp,
    required this.lanes,
    required this.warningMs,
    this.theme = SceneTheme.forest,
  });

  final SceneTheme theme;

  // Per-frame inputs. Mutable so the game can reuse one painter.
  Size size;
  double t;
  double clockMs;
  final List<PlannedEncounter> plan;
  double heroLane;
  bool ducking;
  bool armsUp;
  final int lanes;
  final int warningMs;

  static final Expando<_ThemePaints> _themePaints = Expando();

  // Theme-independent paints.
  static final Paint _laneLine = Paint()
    ..color = const Color(0x88FFFFFF)
    ..strokeWidth = 3;
  static final Paint _outline = Paint()
    ..style = PaintingStyle.stroke
    ..color = const Color(0xFF111111);
  static final Paint _chevron = Paint()
    ..style = PaintingStyle.stroke
    ..color = const Color(0xFFFFFFFF);
  static final Paint _white = Paint()..color = const Color(0xFFFFFFFF);
  static final Paint _orbGlow = Paint()..color = const Color(0x6600E5FF);
  static final Paint _orbCore = Paint()..color = const Color(0xFF7CF7FF);
  static final Paint _arch = Paint()
    ..style = PaintingStyle.stroke
    ..color = const Color(0xFFB8860B);
  static final Paint _heroBody = Paint()..color = const Color(0xFFFF7A2F);
  static final Paint _heroScarf = Paint()..color = const Color(0xFF1FB5A8);
  static final Paint _heroArm = Paint()
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFFFF7A2F);
  static final Paint _heroLegs = Paint()
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xFF2B1A10);

  // Scratch paths, reset before each use. Painting is single-threaded and
  // the canvas copies path data when recording, so reuse is safe.
  static final Path _path = Path();
  static final Path _path2 = Path();

  /// Encounters can be drawn up to this long after they arrive.
  static const _afterArriveMs = 350;

  /// Upper bound on how long before arrival an encounter is warned.
  int get _maxLeadMs => warningMs + Director.wideBlockExtraMs;

  _ThemePaints get _paints => _themePaints[theme] ??= _ThemePaints(theme);

  double get w => size.width;
  double get h => size.height;
  double get horizon => h * 0.38;
  double get heroY => h * 0.86;

  /// Screen x of a lane position at depth d (0 = at the hero, 1 = horizon).
  double laneX(double lane, double d) {
    final roadHalf = w * 0.46 * (1 - d) + w * 0.06 * d;
    final laneW = roadHalf * 2 / lanes;
    return w / 2 - roadHalf + laneW * (lane + 0.5);
  }

  double depthY(double d) =>
      heroY + (horizon - heroY) * (1 - math.pow(1 - d, 1.6).toDouble());
  double scaleAt(double d) => 1 - d * 0.82;

  void paint(Canvas c) {
    final pp = _paints;
    _sky(c, pp);
    _hills(c, 0.15, pp.hillFar, 0.30, 60);
    _hills(c, 0.35, pp.hillNear, 0.34, 90);
    _trees(c, pp);
    _road(c, pp);
    // The plan is sorted by arrival time. Visible window:
    // warnMs <= clock <= arriveMs + 350. Draw far (latest arrival) first.
    final first = _firstArrivingAfter(clockMs - _afterArriveMs);
    var last = first;
    while (last < plan.length && plan[last].arriveMs - _maxLeadMs <= clockMs) {
      last++;
    }
    for (var i = last - 1; i >= first; i--) {
      final p = plan[i];
      if (clockMs < p.warnMs || clockMs > p.arriveMs + _afterArriveMs) {
        continue;
      }
      final d = ((p.arriveMs - clockMs) / warningMs)
          .clamp(-0.2, 1.0)
          .toDouble();
      _encounter(c, pp, p, d);
    }
    _hero(c);
  }

  /// Index of the first planned encounter with arriveMs >= [ms].
  int _firstArrivingAfter(double ms) {
    var lo = 0, hi = plan.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (plan[mid].arriveMs < ms) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  void _sky(Canvas c, _ThemePaints pp) {
    final r = Rect.fromLTWH(0, 0, w, horizon + 2);
    c.drawRect(r, pp.skyFor(theme, horizon));
    c.drawCircle(Offset(w * 0.78, horizon * 0.45), w * 0.07, pp.sun);
  }

  void _hills(Canvas c, double speed, Paint paint, double amp, double period) {
    final path = _path
      ..reset()
      ..moveTo(0, horizon);
    final off = t * 40 * speed;
    for (var x = 0.0; x <= w; x += 8) {
      final y =
          horizon - h * amp * 0.25 * (0.5 + 0.5 * math.sin((x + off) / period));
      path.lineTo(x, y);
    }
    path
      ..lineTo(w, horizon + 2)
      ..lineTo(0, horizon + 2)
      ..close();
    c.drawPath(path, paint);
  }

  void _trees(Canvas c, _ThemePaints pp) {
    final ground = Rect.fromLTWH(0, horizon, w, h - horizon);
    c.drawRect(ground, pp.ground);
    // Trees streaming past on both sides of the road.
    for (var i = 0; i < 10; i++) {
      final phase = ((t * 0.55 + i / 10) % 1.0);
      final d = 1 - phase;
      final y = depthY(d);
      final s = scaleAt(d) * h * 0.22;
      for (var side = -1.0; side <= 1.0; side += 2) {
        final x = w / 2 + side * (w * 0.08 + (w * 0.5) * (1 - d) + s * 0.4);
        if (theme.props == SceneProps.cacti) {
          _cactus(c, pp, x, y, s);
          continue;
        }
        c.drawRect(
          Rect.fromCenter(
            center: Offset(x, y - s * 0.2),
            width: s * 0.12,
            height: s * 0.4,
          ),
          pp.trunk,
        );
        final crown = _path
          ..reset()
          ..moveTo(x, y - s * 1.1)
          ..lineTo(x - s * 0.35, y - s * 0.3)
          ..lineTo(x + s * 0.35, y - s * 0.3)
          ..close();
        c.drawPath(crown, pp.crown);
      }
    }
  }

  /// A simple procedural saguaro-style silhouette: trunk plus two arms.
  void _cactus(Canvas c, _ThemePaints pp, double x, double y, double s) {
    final body = pp.trunk;
    final arm = pp.crown;
    final r = Radius.circular(s * 0.06);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x - s * 0.07, y - s * 0.8, x + s * 0.07, y),
        r,
      ),
      body,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x - s * 0.28, y - s * 0.55, x - s * 0.16, y - s * 0.3),
        r,
      ),
      arm,
    );
    c.drawRect(
      Rect.fromLTRB(x - s * 0.28, y - s * 0.36, x - s * 0.07, y - s * 0.3),
      arm,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x + s * 0.16, y - s * 0.65, x + s * 0.28, y - s * 0.4),
        r,
      ),
      arm,
    );
    c.drawRect(
      Rect.fromLTRB(x + s * 0.07, y - s * 0.46, x + s * 0.28, y - s * 0.4),
      arm,
    );
  }

  void _road(Canvas c, _ThemePaints pp) {
    final road = _path
      ..reset()
      ..moveTo(laneX(-0.5, 0), heroY + h * 0.2)
      ..lineTo(laneX(-0.5, 1), horizon)
      ..lineTo(laneX(lanes - 0.5, 1), horizon)
      ..lineTo(laneX(lanes - 0.5, 0), heroY + h * 0.2)
      ..close();
    c.drawPath(road, pp.road);
    for (var l = 0; l < lanes - 1; l++) {
      for (var k = 0; k < 12; k++) {
        final d0 = ((k / 12 + t * 0.8) % 1.0);
        final d1 = (d0 + 0.035).clamp(0.0, 1.0);
        c.drawLine(
          Offset(laneX(l + 0.5, d0), depthY(d0)),
          Offset(laneX(l + 0.5, d1), depthY(d1)),
          _laneLine,
        );
      }
    }
  }

  void _encounter(Canvas c, _ThemePaints pp, PlannedEncounter p, double d) {
    final dd = d.clamp(0.0, 1.0);
    final y = depthY(dd);
    final s = scaleAt(dd);
    final outline = _outline..strokeWidth = 4 * s;
    switch (p.type) {
      case EncounterType.beam:
        // A low branch across the whole road at head height: duck!
        final left = laneX(-0.5, dd), right = laneX(lanes - 0.5, dd);
        final r = Rect.fromLTRB(
          left,
          y - h * 0.30 * s,
          right,
          y - h * 0.24 * s,
        );
        final rr = RRect.fromRectAndRadius(r, Radius.circular(10 * s));
        c.drawRRect(rr, pp.beam);
        c.drawRRect(rr, outline);
        // Chevrons pointing down.
        final chevron = _chevron..strokeWidth = 5 * s;
        for (var i = 0; i < 3; i++) {
          final cx = left + (right - left) * (0.25 + i * 0.25);
          final ch = _path
            ..reset()
            ..moveTo(cx - 14 * s, r.bottom + 8 * s)
            ..lineTo(cx, r.bottom + 22 * s)
            ..lineTo(cx + 14 * s, r.bottom + 8 * s);
          c.drawPath(ch, chevron);
        }
      case EncounterType.laneBlock:
        for (final l in p.lanes) {
          final x = laneX(l.toDouble(), dd);
          final rw = w * 0.22 * s, rh = h * 0.16 * s;
          final rock = _path
            ..reset()
            ..moveTo(x - rw / 2, y)
            ..lineTo(x - rw * 0.35, y - rh)
            ..lineTo(x + rw * 0.2, y - rh * 1.1)
            ..lineTo(x + rw / 2, y)
            ..close();
          c.drawPath(rock, pp.block);
          c.drawPath(rock, outline);
        }
      case EncounterType.orb:
        final x = laneX(p.lanes.first.toDouble(), dd);
        final cy = y - h * 0.34 * s;
        c.drawCircle(Offset(x, cy), 30 * s, _orbGlow);
        c.drawCircle(Offset(x, cy), 18 * s, _orbCore);
        // Star shape so it reads without colour.
        final star = _path..reset();
        for (var i = 0; i < 10; i++) {
          final a = -math.pi / 2 + i * math.pi / 5;
          final rr = (i.isEven ? 16 : 7) * s;
          final px = x + math.cos(a) * rr, py = cy + math.sin(a) * rr;
          if (i == 0) {
            star.moveTo(px, py);
          } else {
            star.lineTo(px, py);
          }
        }
        star.close();
        c.drawPath(star, _white);
      case EncounterType.gate:
        final left = laneX(-0.5, dd), right = laneX(lanes - 0.5, dd);
        final top = y - h * 0.42 * s;
        final arch = _arch..strokeWidth = 16 * s;
        c.drawArc(
          Rect.fromLTRB(left, top, right, y + (right - left) * 0.3),
          math.pi,
          math.pi,
          false,
          arch,
        );
        c.drawLine(
          Offset(left, y),
          Offset(left, top + (right - left) * 0.3),
          arch,
        );
        c.drawLine(
          Offset(right, y),
          Offset(right, top + (right - left) * 0.3),
          arch,
        );
        // Up arrows: raise your arms.
        final cx = (left + right) / 2;
        final arrow = _path2
          ..reset()
          ..moveTo(cx, top + 10 * s)
          ..lineTo(cx - 22 * s, top + 40 * s)
          ..lineTo(cx + 22 * s, top + 40 * s)
          ..close();
        c.drawPath(arrow, _white);
    }
  }

  void _hero(Canvas c) {
    final x = laneX(heroLane, 0);
    final bob = ducking ? 0.0 : math.sin(t * 14) * 4;
    final body = h * (ducking ? 0.11 : 0.17);
    final top = heroY - body + bob;
    // Cape-like body (original hero: a fox-orange runner with a teal scarf).
    final torso = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, top + body * 0.55),
        width: w * 0.09,
        height: body * 0.6,
      ),
      const Radius.circular(14),
    );
    c.drawRRect(torso, _heroBody);
    c.drawCircle(Offset(x, top + body * 0.12), w * 0.04, _heroBody);
    c.drawRect(
      Rect.fromCenter(
        center: Offset(x, top + body * 0.3),
        width: w * 0.1,
        height: body * 0.06,
      ),
      _heroScarf,
    );
    final arm = _heroArm..strokeWidth = w * 0.018;
    final shY = top + body * 0.35;
    for (var side = -1.0; side <= 1.0; side += 2) {
      final hand = armsUp
          ? Offset(x + side * w * 0.05, top - body * 0.25)
          : Offset(x + side * w * 0.07, top + body * 0.65);
      c.drawLine(Offset(x + side * w * 0.035, shY), hand, arm);
    }
    final legs = _heroLegs..strokeWidth = w * 0.02;
    final hip = Offset(x, top + body * 0.85);
    final stride = ducking ? 0.0 : math.sin(t * 14) * w * 0.025;
    c.drawLine(hip, Offset(x - w * 0.03 + stride, heroY + bob), legs);
    c.drawLine(hip, Offset(x + w * 0.03 - stride, heroY + bob), legs);
  }
}
