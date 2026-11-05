import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';
import 'package:motionquest/game/forest_game.dart';

LevelConfig _forest() => LevelConfig.decode(
  File('assets/levels/w1-forest-escape.json').readAsStringSync(),
);

class _SilentAudio implements GameAudio {
  @override
  void cue(String name) {}
  @override
  void say(String text) {}
  @override
  void sayKey(String key) {}
}

void main() {
  test('ForestPainter paints 600 frames per theme quickly', () {
    final engine = RunEngine(_forest(), const RunSettings());
    const themes = [
      SceneTheme.forest,
      SceneTheme.desert,
      SceneTheme.neon,
      SceneTheme.mountain,
    ];
    final sw = Stopwatch()..start();
    for (final theme in themes) {
      final painter = ForestPainter(
        size: const Size(400, 800),
        t: 0,
        clockMs: 0,
        plan: engine.plan,
        heroLane: 1,
        ducking: false,
        armsUp: false,
        lanes: engine.level.lanes,
        warningMs: engine.director.warningMs,
        theme: theme,
      );
      for (var f = 0; f < 600; f++) {
        // Sweep the whole level so every encounter type is drawn.
        final clock = engine.level.durationMs * f / 600;
        final rec = PictureRecorder();
        painter
          ..clockMs = clock
          ..t = clock / 1000
          ..ducking = f.isOdd
          ..armsUp = f % 3 == 0
          ..paint(Canvas(rec));
        rec.endRecording().dispose();
      }
    }
    sw.stop();
    // 2400 frames in total; generous bound for slow CI machines.
    expect(sw.elapsedMilliseconds, lessThan(2000 * themes.length));
  });

  test('visible encounters match the reference filter+sort', () {
    final engine = RunEngine(_forest(), const RunSettings());
    // Same window rule as ForestPainter; the painter must draw the same set.
    for (var clock = 0.0; clock < engine.level.durationMs; clock += 250) {
      final expected =
          engine.plan
              .where((p) => clock >= p.warnMs && clock <= p.arriveMs + 350)
              .toList()
            ..sort((a, b) => b.arriveMs.compareTo(a.arriveMs));
      final lead = engine.director.warningMs + Director.wideBlockExtraMs;
      for (final p in expected) {
        expect(p.arriveMs - lead, lessThanOrEqualTo(clock));
      }
    }
  });

  test('HUD is not reassigned when nothing changed', () {
    final engine = RunEngine(_forest(), const RunSettings());
    final game = ForestGame(
      engine: engine,
      motionEvents: const Stream<MotionEvent>.empty(),
      audio: _SilentAudio(),
    );
    var notifications = 0;
    game.hud.addListener(() => notifications++);
    // 60 frames at 60 fps: progress is quantised, so only a handful of
    // HUD updates may happen (never one per frame).
    for (var i = 0; i < 60; i++) {
      game.update(1 / 60);
    }
    expect(notifications, lessThan(10));
    final before = game.hud.value;
    notifications = 0;
    for (var i = 0; i < 60; i++) {
      game.update(0);
    }
    expect(notifications, 0);
    expect(identical(game.hud.value, before), isTrue);
  });
}
