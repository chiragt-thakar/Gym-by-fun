// Content quality rules that every shipped level must meet.
import 'package:test/test.dart';

import 'levels.dart';

void main() {
  test('no two levels share the same encounter layout', () {
    final seen = <String, String>{};
    for (final l in allLevels()) {
      final sig = l.encounters
          .map((e) => '${e.atMs}:${e.type.name}:${e.lanes.join(',')}')
          .join('|');
      expect(seen[sig], isNull,
          reason: '${l.id} duplicates the layout of ${seen[sig]}');
      seen[sig] = l.id;
    }
  });

  test('level ids are unique', () {
    final ids = allLevels().map((l) => l.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
