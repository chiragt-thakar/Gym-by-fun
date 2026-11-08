import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';

/// Original explorers share identical game rules and movement timing.
enum HeroLook { fox, otter, robot }

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
    this.feedback,
    this.feedbackId = 0,
    this.combo = 0,
    this.missionKind,
    this.missionCount = 0,
    this.missionGoal = 0,
    this.missionWon = false,
    this.action,
    this.segment,
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
  final String? feedback;
  final int feedbackId;
  final int combo;
  final MissionKind? missionKind;
  final int missionCount, missionGoal;
  final bool missionWon;
  final EncounterType? action;
  final SegmentKind? segment;

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
    String? feedback,
    bool clearFeedback = false,
    int? feedbackId,
    int? combo,
    MissionKind? missionKind,
    int? missionCount,
    missionGoal,
    bool? missionWon,
    EncounterType? action,
    bool clearAction = false,
    SegmentKind? segment,
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
    feedback: clearFeedback ? null : feedback ?? this.feedback,
    feedbackId: feedbackId ?? this.feedbackId,
    combo: combo ?? this.combo,
    missionKind: missionKind ?? this.missionKind,
    missionCount: missionCount ?? this.missionCount,
    missionGoal: missionGoal ?? this.missionGoal,
    missionWon: missionWon ?? this.missionWon,
    action: clearAction ? null : action ?? this.action,
    segment: segment ?? this.segment,
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
    this.reduceMotion = false,
    this.heroLook = HeroLook.fox,
  }) : hud = ValueNotifier(
         HudState(hearts: engine.hearts, maxHearts: engine.level.hearts),
       );

  final RunEngine engine;
  final Stream<MotionEvent> motionEvents;
  final GameAudio audio;

  /// Colours and side scenery for the current stage.
  final SceneTheme theme;
  final bool reduceMotion;
  final HeroLook heroLook;

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
  bool _inputSuspended = false;
  int _feedbackUntilMs = 0;
  double _armBlend = 0, _crouchBlend = 0;
  int _actionIndex = -1;

  @override
  void pauseEngine() {
    _inputSuspended = true;
    super.pauseEngine();
  }

  @override
  void resumeEngine() {
    _inputSuspended = false;
    super.resumeEngine();
  }

  @override
  Color backgroundColor() => theme.background;

  @override
  Future<void> onLoad() async {
    _heroLane = engine.lane.toDouble();
    _sub = motionEvents.listen((e) {
      if (!_inputSuspended && !_disposed) _handle(engine.input(e));
    });
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
    final ease = math.min(1.0, dt * 14);
    _armBlend += ((engine.armsUp ? 1 : 0) - _armBlend) * ease;
    _crouchBlend += ((engine.ducking ? 1 : 0) - _crouchBlend) * ease;
    final now = engine.clockMs.round();
    if (hud.value.feedback != null && now > _feedbackUntilMs) {
      hud.value = hud.value.copyWith(clearFeedback: true);
    }
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
        cur.hint == hint &&
        cur.missionCount == engine.mission.count &&
        cur.missionGoal == engine.mission.goal &&
        cur.missionWon == engine.mission.complete &&
        cur.missionKind == engine.level.gameplay?.mission) {
      return;
    }
    hud.value = cur.copyWith(
      hearts: engine.hearts,
      energy: engine.energy,
      score: engine.score,
      progress: progress,
      light: engine.light,
      clearHint: clearHint,
      missionKind: engine.level.gameplay?.mission,
      missionCount: engine.mission.count,
      missionGoal: engine.mission.goal,
      missionWon: engine.mission.complete,
    );
  }

  void _handle(List<RunEvent> events) {
    if (_disposed) return;
    for (final e in events) {
      switch (e) {
        case CuePlayed():
          audio.cue(e.sound);
          _actionIndex = e.encounter.index;
          hud.value = hud.value.copyWith(action: e.encounter.type);
        case HintShown(:final text):
          _hintUntilMs = e.atMs + 2200;
          hud.value = hud.value.copyWith(hint: text);
          audio.say(text);
        case EncounterResolved(:final outcome):
          if (_actionIndex == e.encounter.index) {
            hud.value = hud.value.copyWith(clearAction: true);
          }
          if (outcome == Outcome.cleared) {
            audio.cue('clear');
            _feedbackUntilMs = e.atMs + 900;
            hud.value = hud.value.copyWith(
              feedback: switch (e.encounter.type) {
                EncounterType.beam => 'Clean duck',
                EncounterType.laneBlock => 'Smooth dodge',
                EncounterType.orb => 'Light collected',
                EncounterType.gate => 'Gate opened',
              },
              feedbackId: hud.value.feedbackId + 1,
              combo: engine.streak,
            );
          }
          if (outcome == Outcome.hit && e.encounter.type.damages) {
            audio.cue('hit');
          }
          if (outcome != Outcome.cleared) {
            _feedbackUntilMs = 0;
            hud.value = hud.value.copyWith(
              clearFeedback: true,
              combo: engine.streak,
            );
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
        case SegmentStarted():
          hud.value = hud.value.copyWith(segment: e.segment.kind);
        case LaneChanged() || HeartsChanged():
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
    scene: engine.level.gameplay?.scene ?? SceneKind.forest,
    atmosphere: engine.level.gameplay?.atmosphere ?? Atmosphere.fireflies,
    heroLook: heroLook,
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
      ..armBlend = _armBlend
      ..crouchBlend = _crouchBlend
      ..lean = (engine.lane - _heroLane).clamp(-1, 1).toDouble()
      ..missionCharge = engine.mission.progress
      ..ambientMotion = !reduceMotion
      ..successPulse = reduceMotion
          ? 0
          : ((_feedbackUntilMs - engine.clockMs) / 900).clamp(0, 1).toDouble()
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
    this.scene = SceneKind.forest,
    this.atmosphere = Atmosphere.fireflies,
    this.heroLook = HeroLook.fox,
  });

  final SceneTheme theme;
  final SceneKind scene;
  final Atmosphere atmosphere;
  final HeroLook heroLook;

  // Per-frame inputs. Mutable so the game can reuse one painter.
  Size size;
  double t;
  double clockMs;
  final List<PlannedEncounter> plan;
  double heroLane;
  bool ducking;
  bool armsUp;
  double successPulse = 0;
  double missionCharge = 0;
  double? armBlend, crouchBlend;
  double lean = 0;
  bool ambientMotion = true;
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
  static final Paint _heroFace = Paint()..color = const Color(0xFFFFE6BD);
  static final Paint _heroInk = Paint()..color = const Color(0xFF192E29);
  static final Paint _heroShadow = Paint()..color = const Color(0x4405120F);
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
    _beacon(c);
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
    _weather(c);
    _hero(c);
    _companion(c);
    if (successPulse > 0) {
      final x = laneX(heroLane, 0), y = heroY - h * 0.1;
      final radius = w * (0.05 + (1 - successPulse) * 0.12);
      _successPaint.color = const Color(0xFFFFD182)
          .withValues(alpha: successPulse * 0.8);
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        c.drawCircle(
          Offset(x + math.cos(a) * radius, y + math.sin(a) * radius),
          2.5 * successPulse,
          _successPaint,
        );
      }
    }
  }

  static final Paint _successPaint = Paint();
  static final Paint _waterPaint = Paint()..color = const Color(0xFF205E70);
  static final Paint _ripplePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5
    ..color = const Color(0x557DE0D8);
  static final Paint _nightWindow = Paint()..color = const Color(0xFF71EFDA);
  static final Paint _nightBuilding = Paint()..color = const Color(0xFF191A38);
  static final Paint _weatherPaint = Paint()..strokeCap = StrokeCap.round;
  static final Paint _beaconPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3;
  static final Paint _woodPaint = Paint()..color = const Color(0xFF9A643B);
  static final Paint _woodEdge = Paint()
    ..color = const Color(0xFF583E2D)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  /// Shared vector explorer art for settings previews, with no camera input.
  void paintExplorer(Canvas canvas) => _hero(canvas);

  void _weather(Canvas c) {
    final time = ambientMotion ? t : 0.0;
    _weatherPaint
      ..style = PaintingStyle.stroke
      ..strokeWidth = atmosphere == Atmosphere.rain ? 1.5 : 2.5;
    _weatherPaint.color = switch (atmosphere) {
      Atmosphere.rain => const Color(0x557DD5ED),
      Atmosphere.snow => const Color(0xBBF2F7FF),
      Atmosphere.sand => const Color(0x66F2C47F),
      Atmosphere.petals => const Color(0xBBFF91C8),
      Atmosphere.fireflies => const Color(0xBBFFE78D),
      Atmosphere.stars => const Color(0x884DFFE7),
    };
    for (var i = 0; i < 16; i++) {
      final x =
          ((i * 0.171 + time * (atmosphere == Atmosphere.sand ? 0.06 : 0.006)) %
              1) *
          w;
      final y =
          ((i * 0.239 + time * (atmosphere == Atmosphere.rain ? 0.26 : 0.025)) %
              1) *
          h;
      if (atmosphere == Atmosphere.rain) {
        c.drawLine(Offset(x, y), Offset(x - 3, y + 15), _weatherPaint);
      } else if (atmosphere == Atmosphere.petals) {
        c.drawLine(Offset(x, y), Offset(x + 3, y + 4), _weatherPaint);
      } else {
        c.drawCircle(Offset(x, y), i.isEven ? 1.5 : 2.5, _weatherPaint);
      }
    }
  }

  void _beacon(Canvas c) {
    final cy = horizon - h * 0.025, r = w * 0.045;
    _beaconPaint.color = const Color(0x8896B8B4);
    c.drawCircle(Offset(w / 2, cy), r, _beaconPaint);
    if (missionCharge > 0) {
      _beaconPaint.color = const Color(0xFFFFD582);
      c.drawArc(
        Rect.fromCircle(center: Offset(w / 2, cy), radius: r),
        -math.pi / 2,
        2 * math.pi * missionCharge,
        false,
        _beaconPaint,
      );
    }
    for (var i = 0; i < 3; i++) {
      final x = w * (0.46 + i * 0.04);
      c.drawLine(
        Offset(x, cy + r + 4),
        Offset(x, cy + r + h * 0.035),
        _beaconPaint,
      );
    }
  }

  void _companion(Canvas c) {
    if (missionCharge <= 0) return;
    final time = ambientMotion ? t : 0;
    final x = laneX(heroLane, 0) + w * 0.16 + math.sin(time * 2) * 5;
    final y = heroY - h * 0.23 + math.cos(time * 2.4) * 5;
    c.drawCircle(Offset(x, y), 12, _orbGlow);
    c.drawCircle(Offset(x, y), 5, _orbCore);
    _beaconPaint.color = const Color(0x99FFF1B0);
    c.drawOval(
      Rect.fromCenter(center: Offset(x - 5, y - 5), width: 8, height: 4),
      _beaconPaint,
    );
    c.drawOval(
      Rect.fromCenter(center: Offset(x + 5, y - 5), width: 8, height: 4),
      _beaconPaint,
    );
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
    if (scene == SceneKind.festival) {
      _beaconPaint.color = const Color(0x99FFE5B0);
      c.drawLine(
        Offset(0, horizon * 0.35),
        Offset(w, horizon * 0.55),
        _beaconPaint,
      );
      for (var i = 0; i < 12; i++) {
        final x = w * i / 11, y = horizon * (0.35 + i / 11 * 0.2);
        final flag = _path
          ..reset()
          ..moveTo(x, y)
          ..lineTo(x + 12, y + 3)
          ..lineTo(x + 5, y + 20)
          ..close();
        c.drawPath(flag, i.isEven ? _orbCore : _heroScarf);
      }
    }
  }

  void _hills(Canvas c, double speed, Paint paint, double amp, double period) {
    final path = _path
      ..reset()
      ..moveTo(0, horizon);
    final off = t * 40 * speed;
    if (scene == SceneKind.mountain) {
      for (var i = -1; i <= 6; i++) {
        path.lineTo(
          w * i / 5,
          horizon - h * (i.isEven ? 0.19 : 0.03) * (amp / 0.35),
        );
      }
      path
        ..lineTo(w, horizon + 2)
        ..lineTo(0, horizon + 2)
        ..close();
      c.drawPath(path, paint);
      return;
    }
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
    c.drawRect(ground, scene == SceneKind.river ? _waterPaint : pp.ground);
    // Trees streaming past on both sides of the road.
    for (var i = 0; i < 10; i++) {
      final phase = ((t * 0.55 + i / 10) % 1.0);
      final d = 1 - phase;
      final y = depthY(d);
      final s = scaleAt(d) * h * 0.22;
      for (var side = -1.0; side <= 1.0; side += 2) {
        final x = w / 2 + side * (w * 0.08 + (w * 0.5) * (1 - d) + s * 0.4);
        if (scene == SceneKind.neon || scene == SceneKind.festival) {
          final bh = s * (1 + (i % 3) * 0.3), bw = s * 0.45;
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(x - bw / 2, y - bh, x + bw / 2, y),
              Radius.circular(s * 0.04),
            ),
            _nightBuilding,
          );
          for (var row = 0; row < 4; row++) {
            c.drawRect(
              Rect.fromLTWH(
                x - bw * 0.3,
                y - bh + s * 0.15 + row * s * 0.19,
                bw * 0.15,
                s * 0.07,
              ),
              _nightWindow,
            );
            c.drawRect(
              Rect.fromLTWH(
                x + bw * 0.15,
                y - bh + s * 0.15 + row * s * 0.19,
                bw * 0.15,
                s * 0.07,
              ),
              _nightWindow,
            );
          }
          continue;
        }
        if (scene == SceneKind.ruins) {
          c.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(x - s * 0.12, y - s * 0.85, x + s * 0.12, y),
              Radius.circular(s * 0.04),
            ),
            pp.block,
          );
          c.drawRect(
            Rect.fromCenter(
              center: Offset(x, y - s * 0.8),
              width: s * 0.38,
              height: s * 0.12,
            ),
            pp.beam,
          );
          continue;
        }
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
        if (scene == SceneKind.mountain) {
          final snow = _path
            ..reset()
            ..moveTo(x, y - s * 1.1)
            ..lineTo(x - s * 0.14, y - s * 0.78)
            ..lineTo(x + s * 0.14, y - s * 0.78)
            ..close();
          c.drawPath(snow, _white);
        }
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
    c.drawPath(road, scene == SceneKind.river ? _waterPaint : pp.road);
    if (scene == SceneKind.river ||
        scene == SceneKind.mountain ||
        scene == SceneKind.ruins) {
      for (var i = 0; i < 14; i++) {
        final d = (i / 14 + t * 0.38) % 1;
        final y = depthY(d);
        c.drawLine(
          Offset(laneX(-0.5, d), y),
          Offset(laneX(lanes - 0.5, d), y),
          scene == SceneKind.river ? _ripplePaint : _woodEdge,
        );
      }
    }
    if (scene == SceneKind.neon || scene == SceneKind.mountain) {
      _beaconPaint.color = scene == SceneKind.neon
          ? const Color(0xFF56EFDE)
          : const Color(0xFFC4AF8B);
      for (var side = -1.0; side <= 1; side += 2) {
        final lane = side < 0 ? -0.5 : lanes - 0.5;
        c.drawLine(
          Offset(laneX(lane, 0), heroY),
          Offset(laneX(lane, 1), horizon),
          _beaconPaint,
        );
      }
    }
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
    final crouch = crouchBlend ?? (ducking ? 1.0 : 0.0);
    final lift = armBlend ?? (armsUp ? 1.0 : 0.0);
    final motion = ambientMotion ? t : 0.0;
    final bob = (1 - crouch) * math.sin(motion * 12) * 3;
    final body = h * (0.19 - crouch * 0.065);
    final top = heroY - body + bob;
    _heroBody.color = switch (heroLook) {
      HeroLook.fox => const Color(0xFFF68A43),
      HeroLook.otter => const Color(0xFFB38362),
      HeroLook.robot => const Color(0xFF9C9BEE),
    };
    _heroArm.color = _heroBody.color;
    if (scene == SceneKind.river) {
      final raft = _path
        ..reset()
        ..moveTo(x - w * 0.16, heroY + 6)
        ..lineTo(x - w * 0.11, heroY + 22)
        ..lineTo(x + w * 0.13, heroY + 22)
        ..lineTo(x + w * 0.17, heroY + 6)
        ..close();
      c.drawPath(raft, _woodPaint);
      c.drawPath(raft, _woodEdge);
      for (var i = 0; i < 4; i++) {
        c.drawLine(
          Offset(x - w * 0.09 + i * w * 0.06, heroY + 7),
          Offset(x - w * 0.09 + i * w * 0.06, heroY + 21),
          _woodEdge,
        );
      }
    }
    c.drawOval(
      Rect.fromCenter(
        center: Offset(x, heroY + 5),
        width: w * 0.2,
        height: h * 0.014,
      ),
      _heroShadow,
    );
    c.save();
    c.translate(x, heroY);
    c.rotate(-lean * 0.18);
    c.translate(-x, -heroY);
    // Feet and bent legs are behind the coat, keeping the silhouette clear.
    final stride = math.sin(motion * 12) * w * 0.027 * (1 - crouch);
    final hip = Offset(x, top + body * 0.77);
    _heroLegs.strokeWidth = w * 0.026;
    for (var side = -1.0; side <= 1; side += 2) {
      final foot = Offset(x + side * w * 0.037 + side * stride, heroY + bob);
      final knee = Offset(
        x + side * w * (0.026 + crouch * 0.025),
        top + body * 0.9,
      );
      c.drawLine(hip, knee, _heroLegs);
      c.drawLine(knee, foot, _heroLegs);
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: foot, width: w * 0.057, height: h * 0.014),
          const Radius.circular(5),
        ),
        _heroInk,
      );
    }
    // A wind-following cape/tail gives each explorer a distinct outline.
    final cape = _path2
      ..reset()
      ..moveTo(x - w * 0.045, top + body * 0.3)
      ..quadraticBezierTo(
        x - w * 0.11,
        top + body * 0.72,
        x - w * 0.07 + math.sin(motion * 5) * 4,
        top + body * 0.9,
      )
      ..lineTo(x + w * 0.05, top + body * 0.78)
      ..lineTo(x + w * 0.04, top + body * 0.3)
      ..close();
    c.drawPath(cape, _heroScarf);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, top + body * 0.56),
          width: w * 0.12,
          height: body * 0.53,
        ),
        const Radius.circular(13),
      ),
      _heroBody,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, top + body * 0.56),
          width: w * 0.06,
          height: body * 0.32,
        ),
        const Radius.circular(8),
      ),
      _heroFace,
    );
    final head = Offset(x, top + body * 0.12), radius = w * 0.049;
    if (heroLook == HeroLook.robot) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: head,
            width: radius * 2.2,
            height: radius * 1.8,
          ),
          Radius.circular(radius * 0.35),
        ),
        _heroBody,
      );
      c.drawLine(
        Offset(x, head.dy - radius),
        Offset(x, head.dy - radius * 1.55),
        _heroLegs..strokeWidth = 3,
      );
      c.drawCircle(Offset(x, head.dy - radius * 1.55), 3, _orbCore);
    } else {
      for (var side = -1.0; side <= 1; side += 2) {
        if (heroLook == HeroLook.fox) {
          final ear = _path
            ..reset()
            ..moveTo(x + side * radius * 0.25, head.dy - radius * 0.5)
            ..lineTo(x + side * radius, head.dy - radius * 1.65)
            ..lineTo(x + side * radius, head.dy)
            ..close();
          c.drawPath(ear, _heroBody);
        } else {
          c.drawCircle(
            Offset(x + side * radius * 0.85, head.dy - radius * 0.6),
            radius * 0.4,
            _heroBody,
          );
        }
      }
      c.drawCircle(head, radius, _heroBody);
    }
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, head.dy + radius * 0.2),
          width: radius * 1.5,
          height: radius * 0.8,
        ),
        Radius.circular(radius * 0.3),
      ),
      _heroFace,
    );
    for (var side = -1.0; side <= 1; side += 2) {
      c.drawCircle(
        Offset(x + side * radius * 0.34, head.dy),
        radius * 0.11,
        _heroInk,
      );
    }
    if (heroLook != HeroLook.robot) {
      c.drawCircle(Offset(x, head.dy + radius * 0.26), radius * 0.11, _heroInk);
    }
    if (heroLook == HeroLook.otter) {
      _heroLegs.strokeWidth = 1.2;
      for (var side = -1.0; side <= 1; side += 2) {
        c.drawLine(
          Offset(x + side * radius * 0.4, head.dy + radius * 0.3),
          Offset(x + side * radius * 1.2, head.dy + radius * 0.1),
          _heroLegs,
        );
      }
    }
    final scarf = _path2
      ..reset()
      ..moveTo(x, top + body * 0.3)
      ..quadraticBezierTo(
        x + w * 0.1,
        top + body * 0.2,
        x + w * 0.15,
        top + body * (0.3 + math.sin(motion * 6) * 0.04),
      )
      ..lineTo(x + w * 0.11, top + body * 0.37)
      ..lineTo(x, top + body * 0.36)
      ..close();
    c.drawPath(scarf, _heroScarf);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, top + body * 0.31),
          width: w * 0.14,
          height: body * 0.065,
        ),
        const Radius.circular(4),
      ),
      _heroScarf,
    );
    _heroArm.strokeWidth = w * 0.025;
    for (var side = -1.0; side <= 1; side += 2) {
      final shoulder = Offset(x + side * w * 0.045, top + body * 0.37);
      final elbow = Offset(
        x + side * w * 0.08,
        shoulder.dy + body * (0.19 - lift * 0.37),
      );
      final hand = Offset(
        x + side * w * 0.085,
        shoulder.dy + body * (0.38 - lift * 0.88),
      );
      c.drawLine(shoulder, elbow, _heroArm);
      c.drawLine(elbow, hand, _heroArm);
      c.drawCircle(hand, w * 0.017, _heroScarf);
    }
    if (heroLook == HeroLook.robot) {
      c.drawCircle(Offset(x, top + body * 0.53), w * 0.021, _heroInk);
      c.drawCircle(Offset(x, top + body * 0.53), w * 0.012, _orbCore);
    }
    c.restore();
  }
}
