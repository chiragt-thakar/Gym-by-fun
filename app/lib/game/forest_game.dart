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
    this.onFinished,
  }) : hud = ValueNotifier(
         HudState(hearts: engine.hearts, maxHearts: engine.level.hearts),
       );

  final RunEngine engine;
  final Stream<MotionEvent> motionEvents;
  final GameAudio audio;

  /// Live tracking light from the motion engine (amber slows the world).
  final TrackingLight Function()? lightOf;
  final void Function(RunResult)? onFinished;

  final ValueNotifier<HudState> hud;
  StreamSubscription<MotionEvent>? _sub;
  double _heroLane = 1;
  double _t = 0;
  int _hintUntilMs = 0;

  @override
  Color backgroundColor() => const Color(0xFF0E2A1B);

  @override
  Future<void> onLoad() async {
    _heroLane = engine.lane.toDouble();
    _sub = motionEvents.listen((e) => _handle(engine.input(e)));
  }

  @override
  void onRemove() {
    _sub?.cancel();
    super.onRemove();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (engine.finished) return;
    final l = lightOf?.call();
    if (l != null) engine.setLight(l);
    final ms = (dt * 1000).round().clamp(0, 100);
    _t += dt * engine.pacer.scale;
    _handle(engine.advance(ms));
    _heroLane += (engine.lane - _heroLane) * math.min(1, dt * 12);
    final now = engine.clockMs.round();
    hud.value = hud.value.copyWith(
      hearts: engine.hearts,
      energy: engine.energy,
      score: engine.score,
      progress: (engine.clockMs / engine.level.durationMs).clamp(0, 1),
      light: engine.light,
      clearHint: now > _hintUntilMs,
    );
  }

  void _handle(List<RunEvent> events) {
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
            audio.sayKey(issueKey(issue));
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

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    ForestPainter(
      size: Size(size.x, size.y),
      t: _t,
      clockMs: engine.clockMs,
      plan: engine.plan,
      heroLane: _heroLane,
      ducking: engine.ducking,
      armsUp: engine.armsUp,
      lanes: engine.level.lanes,
      warningMs: engine.director.warningMs,
    ).paint(canvas);
  }
}

/// Procedural 2.5D forest: layered parallax, perspective lanes, big clear
/// silhouettes. Obstacles differ by shape and sound, never by colour alone.
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
  });

  final Size size;
  final double t;
  final double clockMs;
  final List<PlannedEncounter> plan;
  final double heroLane;
  final bool ducking;
  final bool armsUp;
  final int lanes;
  final int warningMs;

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
    _sky(c);
    _hills(c, 0.15, const Color(0xFF214A33), 0.30, 60);
    _hills(c, 0.35, const Color(0xFF1A3D29), 0.34, 90);
    _trees(c);
    _road(c);
    final visible =
        plan
            .where((p) => clockMs >= p.warnMs && clockMs <= p.arriveMs + 350)
            .toList()
          ..sort((a, b) => b.arriveMs.compareTo(a.arriveMs)); // far first
    for (final p in visible) {
      final d = ((p.arriveMs - clockMs) / warningMs)
          .clamp(-0.2, 1.0)
          .toDouble();
      _encounter(c, p, d);
    }
    _hero(c);
  }

  void _sky(Canvas c) {
    final r = Rect.fromLTWH(0, 0, w, horizon + 2);
    c.drawRect(
      r,
      Paint()
        ..shader = Gradient.linear(Offset.zero, Offset(0, horizon), [
          const Color(0xFFFFC27A),
          const Color(0xFF7FC8A9),
        ]),
    );
    c.drawCircle(
      Offset(w * 0.78, horizon * 0.45),
      w * 0.07,
      Paint()..color = const Color(0xFFFFF1C1),
    );
  }

  void _hills(Canvas c, double speed, Color color, double amp, double period) {
    final path = Path()..moveTo(0, horizon);
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
    c.drawPath(path, Paint()..color = color);
  }

  void _trees(Canvas c) {
    final ground = Rect.fromLTWH(0, horizon, w, h - horizon);
    c.drawRect(ground, Paint()..color = const Color(0xFF2E6B3F));
    // Trees streaming past on both sides of the road.
    for (var i = 0; i < 10; i++) {
      final phase = ((t * 0.55 + i / 10) % 1.0);
      final d = 1 - phase;
      final y = depthY(d);
      final s = scaleAt(d) * h * 0.22;
      for (final side in [-1.0, 1.0]) {
        final x = w / 2 + side * (w * 0.08 + (w * 0.5) * (1 - d) + s * 0.4);
        final trunk = Paint()..color = const Color(0xFF4A2F1B);
        c.drawRect(
          Rect.fromCenter(
            center: Offset(x, y - s * 0.2),
            width: s * 0.12,
            height: s * 0.4,
          ),
          trunk,
        );
        final crown = Path()
          ..moveTo(x, y - s * 1.1)
          ..lineTo(x - s * 0.35, y - s * 0.3)
          ..lineTo(x + s * 0.35, y - s * 0.3)
          ..close();
        c.drawPath(crown, Paint()..color = const Color(0xFF173F25));
      }
    }
  }

  void _road(Canvas c) {
    final road = Path()
      ..moveTo(laneX(-0.5, 0), heroY + h * 0.2)
      ..lineTo(laneX(-0.5, 1), horizon)
      ..lineTo(laneX(lanes - 0.5, 1), horizon)
      ..lineTo(laneX(lanes - 0.5, 0), heroY + h * 0.2)
      ..close();
    c.drawPath(road, Paint()..color = const Color(0xFF8C6A45));
    final line = Paint()
      ..color = const Color(0x88FFFFFF)
      ..strokeWidth = 3;
    for (var l = 0; l < lanes - 1; l++) {
      for (var k = 0; k < 12; k++) {
        final d0 = ((k / 12 + t * 0.8) % 1.0);
        final d1 = (d0 + 0.035).clamp(0.0, 1.0);
        c.drawLine(
          Offset(laneX(l + 0.5, d0), depthY(d0)),
          Offset(laneX(l + 0.5, d1), depthY(d1)),
          line,
        );
      }
    }
  }

  void _encounter(Canvas c, PlannedEncounter p, double d) {
    final dd = d.clamp(0.0, 1.0);
    final y = depthY(dd);
    final s = scaleAt(dd);
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * s
      ..color = const Color(0xFF111111);
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
        c.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(10 * s)),
          Paint()..color = const Color(0xFF6B3E1F),
        );
        c.drawRRect(
          RRect.fromRectAndRadius(r, Radius.circular(10 * s)),
          outline,
        );
        // Chevrons pointing down.
        for (var i = 0; i < 3; i++) {
          final cx = left + (right - left) * (0.25 + i * 0.25);
          final ch = Path()
            ..moveTo(cx - 14 * s, r.bottom + 8 * s)
            ..lineTo(cx, r.bottom + 22 * s)
            ..lineTo(cx + 14 * s, r.bottom + 8 * s);
          c.drawPath(
            ch,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5 * s
              ..color = const Color(0xFFFFFFFF),
          );
        }
      case EncounterType.laneBlock:
        for (final l in p.lanes) {
          final x = laneX(l.toDouble(), dd);
          final rw = w * 0.22 * s, rh = h * 0.16 * s;
          final rock = Path()
            ..moveTo(x - rw / 2, y)
            ..lineTo(x - rw * 0.35, y - rh)
            ..lineTo(x + rw * 0.2, y - rh * 1.1)
            ..lineTo(x + rw / 2, y)
            ..close();
          c.drawPath(rock, Paint()..color = const Color(0xFF7A7A7A));
          c.drawPath(rock, outline);
        }
      case EncounterType.orb:
        final x = laneX(p.lanes.first.toDouble(), dd);
        final cy = y - h * 0.34 * s;
        c.drawCircle(
          Offset(x, cy),
          30 * s,
          Paint()..color = const Color(0x6600E5FF),
        );
        c.drawCircle(
          Offset(x, cy),
          18 * s,
          Paint()..color = const Color(0xFF7CF7FF),
        );
        // Star shape so it reads without colour.
        final star = Path();
        for (var i = 0; i < 10; i++) {
          final a = -math.pi / 2 + i * math.pi / 5;
          final rr = (i.isEven ? 16 : 7) * s;
          final pt = Offset(x + math.cos(a) * rr, cy + math.sin(a) * rr);
          i == 0 ? star.moveTo(pt.dx, pt.dy) : star.lineTo(pt.dx, pt.dy);
        }
        star.close();
        c.drawPath(star, Paint()..color = const Color(0xFFFFFFFF));
      case EncounterType.gate:
        final left = laneX(-0.5, dd), right = laneX(lanes - 0.5, dd);
        final top = y - h * 0.42 * s;
        final arch = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16 * s
          ..color = const Color(0xFFB8860B);
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
        final arrow = Path()
          ..moveTo(cx, top + 10 * s)
          ..lineTo(cx - 22 * s, top + 40 * s)
          ..lineTo(cx + 22 * s, top + 40 * s)
          ..close();
        c.drawPath(arrow, Paint()..color = const Color(0xFFFFFFFF));
    }
  }

  void _hero(Canvas c) {
    final x = laneX(heroLane, 0);
    final bob = ducking ? 0.0 : math.sin(t * 14) * 4;
    final body = h * (ducking ? 0.11 : 0.17);
    final top = heroY - body + bob;
    final paint = Paint()..color = const Color(0xFFFF7A2F);
    final dark = Paint()..color = const Color(0xFF2B1A10);
    // Cape-like body (original hero: a fox-orange runner with a teal scarf).
    final torso = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(x, top + body * 0.55),
        width: w * 0.09,
        height: body * 0.6,
      ),
      const Radius.circular(14),
    );
    c.drawRRect(torso, paint);
    c.drawCircle(Offset(x, top + body * 0.12), w * 0.04, paint);
    c.drawRect(
      Rect.fromCenter(
        center: Offset(x, top + body * 0.3),
        width: w * 0.1,
        height: body * 0.06,
      ),
      Paint()..color = const Color(0xFF1FB5A8),
    );
    final arm = Paint()
      ..strokeWidth = w * 0.018
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFF7A2F);
    final sh = Offset(x, top + body * 0.35);
    for (final side in [-1.0, 1.0]) {
      final hand = armsUp
          ? Offset(x + side * w * 0.05, top - body * 0.25)
          : Offset(x + side * w * 0.07, top + body * 0.65);
      c.drawLine(sh + Offset(side * w * 0.035, 0), hand, arm);
    }
    final legs = Paint()
      ..strokeWidth = w * 0.02
      ..strokeCap = StrokeCap.round
      ..color = dark.color;
    final hip = Offset(x, top + body * 0.85);
    final stride = ducking ? 0.0 : math.sin(t * 14) * w * 0.025;
    c.drawLine(hip, Offset(x - w * 0.03 + stride, heroY + bob), legs);
    c.drawLine(hip, Offset(x + w * 0.03 - stride, heroY + bob), legs);
  }
}
