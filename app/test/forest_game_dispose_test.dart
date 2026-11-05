import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';
import 'package:motionquest/game/forest_game.dart';

class _SilentAudio implements GameAudio {
  @override
  void cue(String name) {}
  @override
  void say(String text) {}
  @override
  void sayKey(String key) {}
}

void main() {
  test('dispose releases the HUD notifier and is idempotent', () {
    final engine = RunEngine(
      LevelConfig.decode(
        File('assets/levels/w1-forest-escape.json').readAsStringSync(),
      ),
      const RunSettings(),
    );
    final events = StreamController<MotionEvent>();
    final game = ForestGame(
      engine: engine,
      motionEvents: events.stream,
      audio: _SilentAudio(),
    );
    game.update(1 / 60);
    game.dispose();
    expect(game.isDisposed, isTrue);
    // A disposed ChangeNotifier rejects new listeners.
    expect(() => game.hud.addListener(() {}), throwsFlutterError);
    // Frames after dispose are ignored instead of touching the notifier.
    game.update(1 / 60);
    game.dispose();
    events.close();
  });
}
