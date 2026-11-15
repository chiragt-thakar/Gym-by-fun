// NEON SLICE in the app: the library entry, the bundled rounds, the engine
// the play screen builds, and that every scene paints. Also the brand
// widgets and the star reveal on the results page. The game's rules are
// tested in packages/game_director/test/slice_test.dart.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_director/game_director.dart';
import 'package:joynetic/arcade/arcade_screen.dart';
import 'package:joynetic/arcade/art/game_art.dart';
import 'package:joynetic/arcade/art/looks.dart';
import 'package:joynetic/arcade/art/paint_kit.dart';
import 'package:joynetic/arcade/art/slice_art.dart';
import 'package:joynetic/arcade/catalog.dart';
import 'package:joynetic/arcade/content.dart';
import 'package:joynetic/services/settings.dart';
import 'package:joynetic/widgets/brand.dart';
import 'package:joynetic/widgets/ui_kit.dart';
import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';

/// A frame with the right hand at body-space ([x], [y]) (torso units from
/// the shoulder centre, +y up).
PoseFrame _handAt(double x, double y, int t) {
  final p = (0.375 + x * 0.18, 0.37 - y * 0.18);
  final f = stickFrame(override: {16: p, 18: p, 20: p});
  return PoseFrame(
    timestampMs: t,
    landmarks: f.landmarks,
    imageWidth: f.imageWidth,
    imageHeight: f.imageHeight,
  );
}

/// Paints [draw] onto an off-screen canvas; any exception fails the test.
void _paint(void Function(Canvas c) draw) {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  recorder.endRecording().dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Neon Slice in the library', () {
    test('is in the catalogue with its own identity and instructions', () {
      final g = gameById('neon-slice');
      expect(g, isNotNull);
      expect(g!.title, 'Neon Slice');
      expect(g.isNew, isTrue);
      expect(g.inGenre(GameGenre.arcade), isTrue);
      expect(g.howTo, hasLength(3));
      expect(g.moves, isNotEmpty);
      expect(g.comfort, isNotNull);
      // No other game shares its accent: each game owns its colour.
      expect(games.where((x) => x.accent == g.accent), hasLength(1));
      expect(previewCaptions('neon-slice').every((c) => c.isNotEmpty), isTrue);
    });

    test('every game has its own character look', () {
      final ids = [
        for (final g in games)
          if (g.id != adventureId) g.id,
      ];
      final tops = {for (final id in ids) lookFor(id).top};
      expect(tops, hasLength(ids.length));
      expect(lookFor('neon-slice'), same(sliceLook));
    });
  });

  group('Neon Slice content', () {
    late ArcadeContent content;
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      content = await ArcadeContent.load(rootBundle);
    });

    test('three rounds, easiest first, the first without mines', () {
      final rounds = content.slice;
      expect(rounds, hasLength(3));
      expect(rounds.first.bombShare, 0);
      for (var i = 1; i < rounds.length; i++) {
        expect(
          rounds[i].peakPerMin,
          greaterThan(rounds[i - 1].peakPerMin),
          reason: rounds[i].id,
        );
        expect(rounds[i].bombShare, greaterThan(rounds[i - 1].bombShare));
      }
      final shown = content.stagesFor('neon-slice');
      expect(shown.map((s) => s.id), rounds.map((s) => s.id));
      expect(shown.first.subtitle, contains('no mines'));
      expect(shown.last.subtitle, contains('with mines'));
    });

    test('the bundled file is the validated content file', () {
      expect(
        File('assets/arcade/neon-slice.json').readAsStringSync(),
        File('../content/arcade/neon-slice.json').readAsStringSync(),
      );
    });

    test('the play screen builds a slice engine; assist makes it gentler', () {
      const s = Settings();
      final id = content.slice[1].id;
      final plain = buildEngine(
        content,
        ArcadeArgs(gameId: 'neon-slice', stageId: id, assist: false),
        s,
      );
      final gentle = buildEngine(
        content,
        ArcadeArgs(gameId: 'neon-slice', stageId: id, assist: true),
        s,
      );
      expect(plain, isA<SliceEngine>());
      plain as SliceEngine;
      gentle as SliceEngine;
      expect(plain.stage.id, id);
      expect(gentle.stage.radius, greaterThan(plain.stage.radius));
      expect(gentle.stage.minSpeed, lessThan(plain.stage.minSpeed));
      // An unknown round falls back to the first one instead of failing.
      final fallback = buildEngine(
        content,
        const ArcadeArgs(gameId: 'neon-slice', stageId: 'nope'),
        s,
      );
      expect((fallback as SliceEngine).stage.id, content.slice.first.id);
    });

    test('the daily round is the same for everyone on the same day', () {
      const s = Settings();
      SliceEngine build() =>
          buildEngine(
                content,
                ArcadeArgs(
                  gameId: 'neon-slice',
                  stageId: content.slice.first.id,
                  daily: true,
                ),
                s,
              )
              as SliceEngine;
      final a = build(), b = build();
      expect(
        [for (final t in a.targets) (t.launchAt, t.x0)],
        [for (final t in b.targets) (t.launchAt, t.x0)],
      );
    });
  });

  group('Neon Slice scenes', () {
    const sizes = [Size(320, 568), Size(412, 915)];

    test('the alley paints in every act and in a frenzy', () {
      for (final size in sizes) {
        for (var heat = 0; heat < 3; heat++) {
          _paint((c) => sliceBackdrop(c, size, 3.7, heat: heat));
        }
        _paint((c) => sliceBackdrop(c, size, 9.1, heat: 2, frenzy: true));
      }
    });

    test('a live round paints: fruit, a mine, blades, a cut and a stun', () {
      SliceTarget at(int id, double x, int peak, SliceKind kind) => SliceTarget(
        id: id,
        kind: kind,
        launchAt: peak - 1000,
        flightMs: 2000,
        x0: x,
        x1: x,
        apexY: 0.6,
        look: id % 5,
      );
      const stage = SliceStage(
        id: 't',
        name: 'Test',
        durationMs: 30000,
        startPerMin: 20,
        peakPerMin: 40,
      );
      final e = SliceEngine(
        stage,
        plan: [
          at(1, 0.8, 1100, SliceKind.fruit),
          at(2, -0.8, 1300, SliceKind.prism),
          at(3, 0.8, 1800, SliceKind.bomb),
          at(4, 0.0, 2400, SliceKind.fruit),
        ],
      );
      var sawCut = false, sawStun = false;
      for (var t = 0; e.clockMs < 2600; t += 33) {
        e.advance(33, tracked: true);
        // Sweep through (0.8, 0.6) at the first fruit's peak and again at
        // the mine's.
        final c = e.clockMs;
        final sweeping =
            (c >= 1100 && c < 1133) || (c >= 1800 && c < 1833);
        e.pose(BodyPose.from(_handAt(sweeping ? 1.3 : 0.3, 0.6, t)));
        e.drainEvents();
        sawCut = sawCut || e.cuts.isNotEmpty;
        sawStun = sawStun || e.stunned;
        for (final size in sizes) {
          final m = BodyMap.demo(viewportFor(size, topShare: 0.62));
          _paint((canvas) => slicePlay(canvas, size, m, e, t / 1000));
        }
      }
      expect(sawCut, isTrue, reason: 'the cut effect was painted');
      expect(sawStun, isTrue, reason: 'the stun wash was painted');
      expect(e.slicedCount, 1);
      expect(e.bombsHit, 1);
    });

    testWidgets('all four library previews paint at card and hero sizes', (
      t,
    ) async {
      for (final size in const [Size(160, 110), Size(400, 230)]) {
        for (var v = 0; v < 4; v++) {
          await t.pumpWidget(
            Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: SizedBox.fromSize(
                  size: size,
                  child: GameArt(gameId: 'neon-slice', variant: v),
                ),
              ),
            ),
          );
          expect(t.takeException(), isNull, reason: 'variant $v at $size');
        }
      }
    });
  });

  group('brand', () {
    test('the mark is one bundled file, declared in the pubspec', () {
      expect(File(JoyneticBrand.markAsset).existsSync(), isTrue);
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('assets/brand/'),
      );
      expect(
        JoyneticBrand.nameLead + JoyneticBrand.nameTail,
        JoyneticBrand.name.toLowerCase(),
      );
    });

    testWidgets('logo keeps its size whatever image is behind the mark', (
      t,
    ) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: JoyneticLogo(size: 40, stacked: true)),
          ),
        ),
      );
      expect(t.getSize(find.byType(JoyneticMark)), const Size(40, 40));
      expect(find.byType(JoyneticWordmark), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  group('star reveal', () {
    Widget host(Widget child, {bool still = false}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: still),
        child: Scaffold(body: Center(child: child)),
      ),
    );

    testWidgets('earned stars land one by one and end filled', (t) async {
      await t.pumpWidget(host(const StarRow(2, size: 30, reveal: true)));
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      // The second star waits 220 ms for the first.
      await t.pump(const Duration(milliseconds: 150));
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      await t.pumpAndSettle();
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(2));
      expect(find.byIcon(Icons.star_outline_rounded), findsOneWidget);
    });

    testWidgets('reduced motion shows the result at once', (t) async {
      await t.pumpWidget(
        host(const StarRow(3, size: 30, reveal: true), still: true),
      );
      expect(find.byIcon(Icons.star_rounded), findsNWidgets(3));
    });
  });
}
