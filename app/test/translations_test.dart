import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_director/game_director.dart';
import 'package:motionquest/game/stage_info.dart';
import 'package:motionquest/l10n/strings.dart';
import 'package:motionquest/l10n/tr.dart';

void main() {
  tearDown(() => currentLanguage = AppLanguage.en);

  final benefits = {for (final i in stageInfos.values) ...i.benefits};

  for (final lang in [AppLanguage.hi, AppLanguage.gu]) {
    test(
      'authored stories and new recovery strings translate in ${lang.name}',
      () {
        currentLanguage = lang;
        final authored = {
          for (final f in Directory(
            'assets/levels',
          ).listSync().whereType<File>())
            ...(() {
              final story = LevelConfig.decode(f.readAsStringSync()).journey!;
              return [story.mission, story.completion, story.keepsake];
            })(),
          'Settings',
          'Low-impact mode',
          'Assist mode',
          'Language',
          'Raise your arms and hold to continue. Then lower them.',
          'Saved on this phone',
          'Your last 7 days',
          'Your keepsakes',
          'Clean duck',
          'Smooth dodge',
          'Light collected',
          'Gate opened',
          'Your explorer',
          'Kavi the fox',
          'Neela the otter',
          'Tara the starbot',
          'Gather the lights',
          'Awaken the beacons',
          'Clear the trail',
          'Mission protected',
          'Mission star earned',
          'Complete',
          'Duck under',
          'Find a free lane',
          'Reach for the light',
          'Raise to open',
          'Practise your moves',
          'Breather time',
          'Flow section',
          'Checkpoint reached',
          'Final stretch',
          'Follow the trail',
          'Skip for now and explore',
          'Get ready to play',
          'Teach the game how you move',
          'Show your comfortable range',
          "Let's set up",
          'Not now, keep exploring',
          'One minute before your first run',
        };
        for (final key in authored) {
          expect(tr(key), isNot(key), reason: key);
          expect(
            tr(key).contains('??'),
            isFalse,
            reason: 'broken encoding: $key',
          );
        }
      },
    );
    test('every stage benefit has a ${lang.name} translation', () {
      currentLanguage = lang;
      final missing = [
        for (final b in benefits)
          if (tr(b) == b) b,
      ];
      expect(missing, isEmpty);
    });
  }

  test('English returns the key unchanged', () {
    currentLanguage = AppLanguage.en;
    for (final b in benefits) {
      expect(tr(b), b);
    }
  });
}
