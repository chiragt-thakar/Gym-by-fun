import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_director/game_director.dart';
import 'package:joynetic/game/forest_game.dart';
import 'package:flutter/painting.dart';
import 'package:joynetic/game/stage_info.dart';
import 'package:joynetic/game/stages.dart';
import 'package:joynetic/screens/home_screen.dart';
import 'package:joynetic/services/settings.dart';

void main() {
  test('direct routes cannot bypass progression or premium access', () {
    final paid = stageById('w2-desert-dunes')!;
    expect(canPlayStage(stages[1], {}), isFalse);
    expect(
      canPlayStage(paid, {'w1-monsoon-meadow'}, premiumLocked: true),
      isFalse,
    );
    expect(canPlayStage(paid, {'w1-monsoon-meadow'}), isTrue);
  });

  test('all authored stories are complete with unique keepsakes', () {
    final keepsakes = <String>{};
    for (final stage in stages) {
      final level = LevelConfig.decode(File(stage.asset).readAsStringSync());
      expect(level.journey, isNotNull);
      expect(level.journey!.mission, isNotEmpty);
      expect(keepsakes.add(level.journey!.keepsake), isTrue);
      final total = level.durationMs ~/ 1000 + 135;
      expect(
        questTimeLabel(level),
        '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}',
      );
    }
  });
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
      isUnlocked(stageById('w2-desert-dunes')!, {'w1-monsoon-meadow'}),
      isTrue,
    );
    expect(
      isUnlocked(stageById('w1-firefly-trail')!, {'w1-guardian-grove'}),
      isTrue,
    );
    expect(stageById('w1-firefly-trail')!.stageNumber, 4);
    expect(stageById('w1-garba-quest-event')!.stageNumber, 5);
    expect(stageById('w2-oasis-caravan')!.stageNumber, 3);
    expect(
      isUnlocked(stageById('w2-oasis-caravan')!, {'w2-sandstorm-temple'}),
      isTrue,
    );
    expect(stageById('w3-neon-night-market')!.stageNumber, 3);
    expect(
      isUnlocked(stageById('w3-neon-night-market')!, {'w3-neon-city-chase'}),
      isTrue,
    );
    // Each world opens after the previous world's last stage.
    expect(stageById('w2-mirage-maze')!.stageNumber, 4);
    expect(
      isUnlocked(stageById('w3-neon-city-rooftops')!, {'w2-mirage-maze'}),
      isTrue,
    );
    expect(stageById('w3-skyline-finale')!.stageNumber, 4);
    expect(
      isUnlocked(stageById('w4-mountain-trail')!, {'w3-skyline-finale'}),
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

  test('daily quest skips Premium stages while they are locked', () {
    final world1 = {
      for (final st in stages)
        if (st.world == 1) st.levelId,
    };
    expect(nextStage(world1).levelId, 'w2-desert-dunes');
    final locked = nextStage(world1, premiumLocked: true);
    expect(infoFor(locked).premium, isFalse);
    expect(locked.levelId, forestEscapeId);
    expect(
      nextStage({forestEscapeId}, premiumLocked: true).levelId,
      'w1-river-crossing',
    );
  });

  test('worlds are built once', () {
    expect(identical(worlds, worlds), isTrue);
  });

  test('gym colour parses #RRGGBB and falls back to null', () {
    expect(
      parseGymColour({
        'colours': {'primary': '#12AbEf'},
      }),
      const Color(0xFF12ABEF),
    );
    expect(parseGymColour(null), isNull);
    expect(parseGymColour({}), isNull);
    expect(
      parseGymColour({
        'colours': {'primary': '#FFF'},
      }),
      isNull,
    );
    expect(
      parseGymColour({
        'colours': {'primary': 'zzzzzzz'},
      }),
      isNull,
    );
    expect(parseGymColour({'colours': 'red'}), isNull);
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

  test('developer unlock-all opens every stage', () {
    for (final st in stages) {
      expect(isUnlocked(st, {}, unlockAll: true), isTrue);
      expect(isUnlocked(st, {}, premiumLocked: true, unlockAll: true), isTrue);
    }
    expect(devUnlockAll, isFalse); // off unless built with the flag
  });
}
