import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_director/game_director.dart';

/// One playable level of an arcade game, as the library shows it.
class ArcadeStage {
  const ArcadeStage({
    required this.id,
    required this.name,
    required this.blurb,
    this.premium = false,
    this.party = false,
    this.daily = false,
    this.subtitle,
  });
  final String id;
  final String name;
  final String blurb;
  final bool premium;
  final bool party;
  final bool daily;
  final String? subtitle;
}

/// All arcade content, decoded once from the bundled JSON (rule 7).
class ArcadeContent {
  ArcadeContent({
    required this.mela,
    required this.poses,
    required this.patakaStages,
    required this.partyStages,
    required this.guardians,
    required this.songs,
    required this.formats,
    required this.dailyFormats,
    required this.outcomes,
    required this.lumen,
    this.slice = const [],
  });

  final List<MelaStage> mela;
  final Map<String, PatakaPose> poses;
  final List<PatakaStage> patakaStages;
  final Set<String> partyStages;
  final List<Guardian> guardians;
  final List<TaalSong> songs;
  final List<CricketFormat> formats;
  final Set<String> dailyFormats;
  final OutcomeTable outcomes;
  final List<LumenStage> lumen;
  final List<SliceStage> slice;

  static Future<ArcadeContent> load(AssetBundle bundle) async {
    Future<Map<String, dynamic>> read(String name) async =>
        jsonDecode(await bundle.loadString('assets/arcade/$name.json'))
            as Map<String, dynamic>;
    List<Map<String, dynamic>> list(Map<String, dynamic> j, String k) => [
      for (final x in j[k] as List<dynamic>) x as Map<String, dynamic>,
    ];
    final mela = await read('mirror-mela');
    final pataka = await read('pataka-pose');
    final duel = await read('craftguard');
    final taal = await read('taal-toofan');
    final tape = await read('tapeball');
    final lumen = await read('lumen');
    final slice = await read('neon-slice');
    return ArcadeContent(
      mela: [for (final s in list(mela, 'stages')) MelaStage.fromJson(s)],
      poses: {
        for (final p in list(pataka, 'poses'))
          p['id'] as String: PatakaPose.fromJson(p),
      },
      patakaStages: [
        for (final s in list(pataka, 'stages')) PatakaStage.fromJson(s),
      ],
      partyStages: {
        for (final s in list(pataka, 'stages'))
          if (s['party'] == true) s['id'] as String,
      },
      guardians: [
        for (final g in list(duel, 'guardians')) Guardian.fromJson(g),
      ],
      songs: [for (final s in list(taal, 'songs')) TaalSong.fromJson(s)],
      formats: [
        for (final f in list(tape, 'formats')) CricketFormat.fromJson(f),
      ],
      dailyFormats: {
        for (final f in list(tape, 'formats'))
          if (f['daily'] == true) f['id'] as String,
      },
      outcomes: OutcomeTable.fromJson(tape['outcomes'] as Map<String, dynamic>),
      lumen: [for (final s in list(lumen, 'stages')) LumenStage.fromJson(s)],
      slice: [for (final s in list(slice, 'stages')) SliceStage.fromJson(s)],
    );
  }

  /// Library view of a game's levels, in play order.
  List<ArcadeStage> stagesFor(String gameId) => switch (gameId) {
    'mirror-mela' => [
      for (final s in mela)
        ArcadeStage(
          id: s.id,
          name: s.name,
          blurb: s.blurb,
          subtitle: s.mode == 'orbit' ? 'Orbit · with sweeps' : 'Reach round',
        ),
    ],
    'pataka-pose' => [
      for (final s in patakaStages)
        ArcadeStage(
          id: s.id,
          name: s.name,
          blurb: s.blurb,
          party: partyStages.contains(s.id),
          subtitle: '${s.frames.where((f) => f != 'chill').length} frames',
        ),
    ],
    'craftguard' => [
      for (final g in guardians)
        ArcadeStage(
          id: g.id,
          name: g.name,
          blurb: g.blurb,
          premium: g.premium,
          subtitle: '${g.phases.length} phases',
        ),
    ],
    'taal-toofan' => [
      for (final s in songs)
        ArcadeStage(
          id: s.id,
          name: s.title,
          blurb: s.blurb,
          subtitle: '${s.bpm} BPM · ${_family(s.family)}',
        ),
    ],
    'tapeball' => [
      for (final f in formats)
        ArcadeStage(
          id: f.id,
          name: f.name,
          blurb: f.blurb,
          daily: dailyFormats.contains(f.id),
          subtitle: f.target != null
              ? '${f.balls} balls · chase ${f.target}'
              : '${f.balls} balls · no outs',
        ),
    ],
    'lumen' => [
      for (final s in lumen)
        ArcadeStage(
          id: s.id,
          name: s.name,
          blurb: s.blurb,
          subtitle: '${s.boards.length} repairs',
        ),
    ],
    'neon-slice' => [
      for (final s in slice)
        ArcadeStage(
          id: s.id,
          name: s.name,
          blurb: s.blurb,
          subtitle: s.bombShare > 0
              ? '${s.durationMs ~/ 1000} s · with mines'
              : '${s.durationMs ~/ 1000} s · no mines',
        ),
    ],
    _ => const [],
  };

  static String _family(String f) => switch (f) {
    'raas' => 'Raas groove',
    'dhol' => 'Dhol bounce',
    'filmi' => 'Filmi pop',
    _ => 'Chill',
  };
}

final arcadeContentProvider = FutureProvider<ArcadeContent>(
  (ref) => ArcadeContent.load(rootBundle),
);
