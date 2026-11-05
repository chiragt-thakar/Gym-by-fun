import 'dart:io';

import 'package:game_director/game_director.dart';

/// Every level shipped in content/levels/.
List<LevelConfig> allLevels() {
  final dir = Directory('../../content/levels');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [for (final f in files) LevelConfig.decode(f.readAsStringSync())];
}

LevelConfig forest() =>
    allLevels().firstWhere((l) => l.id == 'w1-forest-escape');
