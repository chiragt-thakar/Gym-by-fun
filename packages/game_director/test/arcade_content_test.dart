import 'dart:convert';
import 'dart:io';

import 'package:game_director/game_director.dart';
import 'package:test/test.dart';

import 'support/arcade_bots.dart';

/// The canonical arcade content in content/arcade must decode, keep the
/// engines' invariants, be playable by a competent bot, and match the copy
/// bundled into the app.
Map<String, dynamic> load(String name) =>
    jsonDecode(File('../../content/arcade/$name.json').readAsStringSync())
        as Map<String, dynamic>;

List<Map<String, dynamic>> list(Map<String, dynamic> j, String key) =>
    [for (final x in j[key] as List<dynamic>) x as Map<String, dynamic>];

void main() {
  test('bundled app copies match the canonical content', () {
    for (final f in Directory('../../content/arcade')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))) {
      final name = f.uri.pathSegments.last;
      final bundled = File('../../app/assets/arcade/$name');
      expect(bundled.existsSync(), isTrue, reason: '$name not bundled');
      expect(jsonDecode(bundled.readAsStringSync()),
          jsonDecode(f.readAsStringSync()),
          reason: '$name differs from the app copy');
    }
  });

  test('Mirror Mela stages plan a full round', () {
    for (final j in list(load('mirror-mela'), 'stages')) {
      final stage = MelaStage.fromJson(j);
      for (final z in stage.zones) {
        expect(melaZones.containsKey(z), isTrue, reason: '${stage.id} $z');
      }
      final e = MelaEngine(stage);
      expect(e.targets.length, greaterThan(10), reason: stage.id);
      expect(e.targets.last.hitAt + 600, lessThan(stage.durationMs),
          reason: '${stage.id} finale fits the round');
      if (stage.mode == 'orbit') {
        expect(e.targets.where((t) => t.isHazard), isNotEmpty);
      }
    }
  });

  test('Pataka Pose stages reference real, safe poses', () {
    final j = load('pataka-pose');
    final library = {
      for (final p in list(j, 'poses'))
        p['id'] as String: PatakaPose.fromJson(p),
    };
    for (final s in list(j, 'stages')) {
      final stage = PatakaStage.fromJson(s);
      var demanding = 0;
      var sinceChill = 0;
      for (final f in stage.frames) {
        if (f == 'chill') {
          sinceChill = 0;
          demanding = 0;
          continue;
        }
        final id = f.startsWith('statue:') ? f.substring(7) : f;
        final pose = library[id];
        expect(pose, isNotNull, reason: '${stage.id}: $id');
        if (stage.band == 'chai') {
          expect(pose!.upperBody, isTrue,
              reason: 'Chai Break is upper-body only: $id');
        }
        demanding = pose!.demanding ? demanding + 1 : 0;
        expect(demanding, lessThanOrEqualTo(2), reason: '${stage.id}: $id');
        sinceChill++;
        if (s['party'] != true) {
          expect(sinceChill, lessThanOrEqualTo(6),
              reason: '${stage.id} needs a chill frame every 4-6 frames');
        }
      }
      expect(
          () => PatakaEngine(stage: stage, library: library), returnsNormally);
    }
  });

  test('every Craftguard guardian can be calmed by a clean fighter', () {
    for (final j in list(load('craftguard'), 'guardians')) {
      final g = Guardian.fromJson(j);
      for (final d in ['beginner', 'advanced']) {
        final e = DuelEngine(g, difficulty: d);
        drive(e, (c) => fighter(e, c));
        expect(e.calmed, isTrue, reason: '${g.id} $d');
        expect(e.clockMs ~/ 1000, inInclusiveRange(60, 330),
            reason: '${g.id} $d lasts ${e.clockMs ~/ 1000}s');
      }
    }
  });

  test('every Taal Toofan song is danceable and always finishes', () {
    for (final j in list(load('taal-toofan'), 'songs')) {
      final song = TaalSong.fromJson(j);
      for (final level in ['light', 'groove', 'toofan']) {
        final e = TaalEngine(song, level: level);
        drive(e, (c) => dancer(e, c));
        expect(e.finished, isTrue, reason: '${song.id} $level');
        expect(e.summary.accuracy, greaterThan(0.8),
            reason: '${song.id} $level');
      }
      final secs = song.totalBeats * song.beatMs ~/ 1000;
      expect(secs, inInclusiveRange(60, 210), reason: '${song.id} ${secs}s');
    }
  });

  test('Neon Slice stages are fair, bounded and playable', () {
    for (final j in list(load('neon-slice'), 'stages')) {
      final stage = SliceStage.fromJson(j);
      final e = SliceEngine(stage);
      expect(e.targets.length, greaterThan(15), reason: stage.id);
      for (final t in e.targets) {
        expect(t.landAt, lessThan(stage.durationMs), reason: stage.id);
        if (t.isBomb) {
          expect(t.launchAt, greaterThan(10000),
              reason: '${stage.id}: no mines while warming up');
        }
      }
      expect(e.targets.where((t) => t.isBomb).isNotEmpty, stage.bombShare > 0,
          reason: stage.id);
      final bot = SliceBot(e);
      drive(e, bot.step);
      expect(e.finished, isTrue, reason: stage.id);
      expect(e.summary.accuracy, greaterThan(0.4), reason: stage.id);
      expect(e.bombsHit, 0, reason: stage.id);
    }
  });

  test('Tapeball formats and outcomes decode', () {
    final j = load('tapeball');
    final table = OutcomeTable.fromJson(j['outcomes'] as Map<String, dynamic>);
    for (final f in list(j, 'formats')) {
      final format = CricketFormat.fromJson(f);
      final e = CricketEngine(format, table);
      drive(e, (_) => (relaxed, {}));
      expect(e.finished, isTrue, reason: format.id);
      expect(e.wickets, 0, reason: 'beginner never loses a wicket idle');
    }
    expect(table.roll('lofted', Grade.perfect, 0.0, outsAllowed: false),
        greaterThanOrEqualTo(4));
  });

  test('every LUMEN board starts broken and has a solution', () {
    for (final s in list(load('lumen'), 'stages')) {
      final stage = LumenStage.fromJson(s);
      for (final b in stage.boards) {
        expect(b.connected, isFalse, reason: '${b.id} starts solved');
        final cells = <(int, int)>{};
        for (final p in b.pieces) {
          expect(p.r < b.rows && p.c < b.cols, isTrue, reason: b.id);
          expect(cells.add((p.r, p.c)), isTrue, reason: '${b.id} overlap');
        }
        final cards = [for (final p in b.editable) p.card!];
        expect(cards, [for (var i = 1; i <= cards.length; i++) i],
            reason: '${b.id} cards are numbered 1..n');
        expect(_solvable(b), isTrue, reason: '${b.id} has no solution');
      }
    }
  });
}

bool _solvable(LumenBoard board) {
  final b = board.copy();
  final pieces = b.editable;
  bool go(int i) {
    if (i == pieces.length) return b.connected;
    final n = pieces[i].type == PieceType.straight ? 2 : 4;
    for (var k = 0; k < n; k++) {
      if (go(i + 1)) return true;
      pieces[i].turn(true);
    }
    return false;
  }

  return go(0);
}
