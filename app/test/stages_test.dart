import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_director/game_director.dart';
import 'package:motionquest/game/forest_game.dart';
import 'package:motionquest/game/stages.dart';
import 'package:motionquest/services/settings.dart';

void main() {
  test('every stage loads its bundled level and the ids match', () {
    for (final st in stages) {
      final level = LevelConfig.decode(File(st.asset).readAsStringSync());
      expect(level.id, st.levelId);
      expect(level.world, st.world);
    }
  });

  test('every bundled level asset is in the stage catalogue', () {
    final ids = {
      for (final f in Directory('assets/levels').listSync().whereType<File>())
        if (f.path.endsWith('.json'))
          LevelConfig.decode(f.readAsStringSync()).id,
    };
    expect(ids, {for (final st in stages) st.levelId});
  });

  test('stage catalogue is ordered and numbered per world', () {
    expect(stages.first.levelId, forestEscapeId);
    final byWorld = <int, List<int>>{};
    for (final st in stages) {
      byWorld.putIfAbsent(st.world, () => []).add(st.stageNumber);
    }
    for (final nums in byWorld.values) {
      expect(nums, [for (var i = 1; i <= nums.length; i++) i]);
    }
    expect(stageById('w2-desert-dunes')!.theme, SceneTheme.desert);
    expect(stageById('nope'), isNull);
  });

  test('worlds 1–4 are playable, later worlds coming soon', () {
    final w = worlds;
    expect(w.length, 9);
    for (var i = 0; i < 4; i++) {
      expect(w[i].comingSoon, isFalse);
    }
    expect(w[1].name, 'Desert Trials');
    expect(w[2].name, 'Neon City');
    expect(w[3].name, 'Mountain Expedition');
    expect(w.skip(4).every((x) => x.comingSoon), isTrue);
    expect([for (final x in w) x.number], [for (var i = 1; i <= 9; i++) i]);
  });

  test('stage N+1 unlocks only when stage N is completed', () {
    expect(isUnlocked(stages[0], {}), isTrue);
    expect(isUnlocked(stages[1], {}), isFalse);
    expect(isUnlocked(stages[1], {forestEscapeId}), isTrue);
    expect(isUnlocked(stages[2], {forestEscapeId}), isFalse);
    // World 2 opens after the World 1 finale.
    expect(
      isUnlocked(stageById('w2-desert-dunes')!, {'w1-guardian-grove'}),
      isTrue,
    );
  });

  test('daily quest plays the next uncompleted stage', () {
    expect(nextStage({}).levelId, forestEscapeId);
    expect(nextStage({forestEscapeId}).levelId, 'w1-river-crossing');
    expect(
      nextStage({forestEscapeId, 'w1-river-crossing'}).levelId,
      'w1-guardian-grove',
    );
    expect(
      nextStage({for (final st in stages) st.levelId}).levelId,
      forestEscapeId,
    );
  });

  test('completedLevels survives a JSON round-trip', () {
    final s = const Settings().copyWith(
      completedLevels: {forestEscapeId, 'w1-river-crossing'},
    );
    final back = Settings.fromJson(
      jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
    );
    expect(back.completedLevels, {forestEscapeId, 'w1-river-crossing'});
    // Older saves without the field still load.
    final old = Settings.fromJson({'difficulty': 'advanced'});
    expect(old.completedLevels, isEmpty);
    expect(old.difficulty, Difficulty.advanced);
    expect(s.copyWith(lowImpact: false).completedLevels, s.completedLevels);
  });
}
