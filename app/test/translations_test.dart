import 'package:flutter_test/flutter_test.dart';
import 'package:motionquest/game/stage_info.dart';
import 'package:motionquest/l10n/strings.dart';
import 'package:motionquest/l10n/tr.dart';

void main() {
  tearDown(() => currentLanguage = AppLanguage.en);

  final benefits = {for (final i in stageInfos.values) ...i.benefits};

  for (final lang in [AppLanguage.hi, AppLanguage.gu]) {
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
