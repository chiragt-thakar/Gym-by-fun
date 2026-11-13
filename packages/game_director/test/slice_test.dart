// NEON SLICE rules: what cuts, what does not, scoring, combos, mines,
// pacing and tracking holds. Fruit is placed exactly (an injected plan) so
// every case is geometry, not luck.
import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';
import 'package:test/test.dart';

import 'support/arcade_bots.dart';

const stage = SliceStage(
  id: 't',
  name: 'Test Lane',
  durationMs: 30000,
  startPerMin: 20,
  peakPerMin: 40,
  bombShare: 0.3,
  waveShare: 0.3,
);

/// A fruit that hangs at ([x], [y]) around [at]: launched so that its peak
/// (where it is slowest) is at that moment.
SliceTarget fruitAt(int id, double x, double y, int at,
        {SliceKind kind = SliceKind.fruit}) =>
    SliceTarget(
      id: id,
      kind: kind,
      launchAt: at - 1000,
      flightMs: 2000,
      x0: x,
      x1: x,
      apexY: y,
    );

/// Runs the engine to [untilMs] with the right hand following [hand]
/// (body space) frame by frame. Returns every event.
List<ArcadeEvent> play(
  SliceEngine e,
  (double, double) Function(int clock) hand, {
  int untilMs = 3000,
  bool Function(int clock)? tracked,
}) {
  final events = <ArcadeEvent>[];
  for (var t = 0; e.clockMs < untilMs && t < 120000; t += 33) {
    final ok = tracked?.call(t) ?? true;
    e.advance(33, tracked: ok);
    if (ok) {
      final (x, y) = hand(e.clockMs);
      final f = handAt(x, y);
      e.pose(BodyPose.from(PoseFrame(
          timestampMs: t,
          landmarks: f.landmarks,
          imageWidth: f.imageWidth,
          imageHeight: f.imageHeight)));
    }
    events.addAll(e.drainEvents());
  }
  return events;
}

/// Rest at the side, then one fast horizontal sweep through x = [x] at
/// height [y], starting at game time [at].
(double, double) Function(int) sweep(double x, double y, int at,
        {double half = 0.5, int frames = 1}) =>
    (clock) {
      if (clock < at) return (x - half, y);
      final k = ((clock - at) / (33 * frames)).clamp(0.0, 1.0);
      return (x - half + 2 * half * k, y);
    };

Iterable<ArcadeEvent> of(List<ArcadeEvent> e, String kind) =>
    e.where((x) => x.kind == kind);

void main() {
  group('what cuts', () {
    test('a fast sweep through a fruit cuts it once', () {
      final e = SliceEngine(stage, plan: [fruitAt(1, 0.8, 0.6, 1100)]);
      final events = play(e, sweep(0.8, 0.6, 1100));
      expect(of(events, 'slice'), hasLength(1));
      expect(e.slicedCount, 1);
      expect(e.score, greaterThan(0));
      expect(e.combo, 1);
      expect(e.targets.single.sliced, isTrue);
      expect(e.cuts, isEmpty, reason: 'the cut effect has expired by 3 s');
    });

    test('a cut through the middle is perfect; a graze is good', () {
      final centre = SliceEngine(stage, plan: [fruitAt(1, 0.8, 0.6, 1100)]);
      final a = of(play(centre, sweep(0.8, 0.6, 1100)), 'slice').single;
      expect(a.grade, Grade.perfect);
      final edge = SliceEngine(stage, plan: [fruitAt(1, 0.8, 0.6, 1100)]);
      // The blade passes 0.3 torso under the centre (radius 0.34).
      final b = of(play(edge, sweep(0.8, 0.3, 1100)), 'slice').single;
      expect(b.grade, Grade.good);
      expect(a.points, greaterThan(b.points));
    });

    test('a hand resting where the fruit passes cuts nothing', () {
      final e = SliceEngine(stage, plan: [fruitAt(1, 0.8, 0.6, 1100)]);
      final events = play(e, (_) => (0.8, 0.6));
      expect(of(events, 'slice'), isEmpty);
      expect(of(events, 'miss'), hasLength(1));
      expect(e.score, 0);
    });

    test('a slow pass cuts nothing', () {
      final e = SliceEngine(stage, plan: [fruitAt(1, 0.8, 0.6, 1100)]);
      // One torso length over a second: half the blade speed.
      final events = play(e, sweep(0.8, 0.6, 600, frames: 30));
      expect(of(events, 'slice'), isEmpty);
    });

    test('a sweep that misses the fruit cuts nothing', () {
      final e = SliceEngine(stage, plan: [fruitAt(1, 0.8, 0.6, 1100)]);
      expect(of(play(e, sweep(0.8, -0.4, 1100)), 'slice'), isEmpty);
    });

    test('a hand that jumps across the screen did not sweep', () {
      final e = SliceEngine(stage, plan: [fruitAt(1, 0.0, 0.6, 1100)]);
      // 2.8 torso lengths between two frames, straight through the fruit:
      // a tracking glitch, not a blade.
      final events = play(e, (clock) => (clock < 1100 ? -1.4 : 1.4, 0.6));
      expect(of(events, 'slice'), isEmpty);
    });

    test('fruit below reach cannot be cut', () {
      final e = SliceEngine(stage, plan: [fruitAt(1, 0.8, 0.6, 1100)]);
      // Sweep where the fruit is 60 ms after launch: still under the floor
      // of reach.
      final (x, y) = e.targets.single.at(60);
      expect(y, lessThan(SliceTarget.reachY));
      expect(of(play(e, sweep(x, y, 160)), 'slice'), isEmpty);
    });

    test('the same fruit is never scored twice', () {
      final e = SliceEngine(stage, plan: [fruitAt(1, 0.8, 0.6, 1100)]);
      // Back and forth through the same spot, every frame.
      final events = play(e, (clock) {
        if (clock < 1000) return (0.3, 0.6);
        return ((clock ~/ 33).isEven ? 0.3 : 1.3, 0.6);
      });
      expect(of(events, 'slice'), hasLength(1));
      expect(e.slicedCount, 1);
    });

    test('either hand can cut', () {
      final e = SliceEngine(stage, plan: [fruitAt(1, -0.8, 0.6, 1100)]);
      for (var t = 0; e.clockMs < 2000; t += 33) {
        e.advance(33, tracked: true);
        final x = e.clockMs < 1100 ? -1.3 : -0.3;
        final f = handAt(x, 0.6, left: true);
        e.pose(BodyPose.from(PoseFrame(
            timestampMs: t,
            landmarks: f.landmarks,
            imageWidth: f.imageWidth,
            imageHeight: f.imageHeight)));
      }
      final slice = of(e.drainEvents(), 'slice').single;
      expect(slice.side, BodySide.left);
    });
  });

  group('scoring', () {
    test('a prism is worth three fruit', () {
      final a = SliceEngine(stage, plan: [fruitAt(1, 0.8, 0.6, 1100)]);
      final b = SliceEngine(stage,
          plan: [fruitAt(1, 0.8, 0.6, 1100, kind: SliceKind.prism)]);
      play(a, sweep(0.8, 0.6, 1100));
      play(b, sweep(0.8, 0.6, 1100));
      expect(b.score, a.score * 3);
    });

    test('a combo raises the multiplier; a miss resets it', () {
      final e = SliceEngine(stage, plan: [
        for (var i = 0; i < 4; i++) fruitAt(i, 0.8, 0.6, 1100 + i * 1500),
        fruitAt(9, -1.2, 0.6, 7200), // nobody reaches for this one
        fruitAt(10, 0.8, 0.6, 9500),
      ]);
      final events = play(e, (clock) {
        // A sweep through (0.8, 0.6) at each fruit's peak.
        for (final at in [1100, 2600, 4100, 5600, 9500]) {
          if (clock >= at && clock < at + 33) return (1.3, 0.6);
        }
        return (0.3, 0.6);
      }, untilMs: 11000);
      final points = [for (final s in of(events, 'slice')) s.points];
      expect(points, hasLength(5));
      expect(points[1], greaterThan(points[0]));
      expect(points[3], greaterThan(points[2]));
      expect(of(events, 'miss'), hasLength(1));
      expect(points[4], points[0], reason: 'the combo started again');
      expect(e.bestCombo, 4);
      expect(e.combo, 1);
    });

    test('three in one sweep earns a bonus, once per extra fruit', () {
      final e = SliceEngine(stage, plan: [
        fruitAt(1, 0.2, 0.6, 1100),
        fruitAt(2, 0.7, 0.6, 1100),
        fruitAt(3, 1.2, 0.6, 1100),
      ]);
      // One sweep from x = -0.1 to x = 1.5 in a single frame.
      final events = play(e, sweep(0.7, 0.6, 1100, half: 0.8));
      expect(of(events, 'slice'), hasLength(3));
      final multi = of(events, 'multi').single;
      expect(multi.value, 3);
      expect(multi.points, 50);
      expect(e.bestSwipe, 3);
    });

    test('two separate sweeps are not one multi-cut', () {
      final e = SliceEngine(stage, plan: [
        fruitAt(1, 0.8, 0.6, 1100),
        fruitAt(2, 0.8, 0.6, 1700),
        fruitAt(3, 0.8, 0.6, 2300),
      ]);
      final events = play(e, (clock) {
        for (final at in [1100, 1700, 2300]) {
          if (clock >= at && clock < at + 33) return (1.3, 0.6);
        }
        return (0.3, 0.6);
      });
      expect(of(events, 'slice'), hasLength(3));
      expect(of(events, 'multi'), isEmpty);
      expect(e.bestSwipe, 1);
    });

    test('twelve in a row starts a frenzy worth half as much again', () {
      final e = SliceEngine(stage, plan: [
        for (var i = 0; i < 13; i++) fruitAt(i, 0.8, 0.6, 1100 + i * 600),
      ]);
      final events = play(e, (clock) {
        final k = clock - 1100;
        if (k >= 0 && k % 600 < 33) return (1.3, 0.6);
        return (0.3, 0.6);
      }, untilMs: 9500);
      expect(of(events, 'frenzy'), hasLength(1));
      final points = [for (final s in of(events, 'slice')) s.points];
      expect(points, hasLength(13));
      // 12th: ×1.6. 13th: ×1.65 × 1.5.
      expect(points[12], greaterThan(points[11] * 1.4));
    });
  });

  group('mines', () {
    test('cutting a mine costs points, the combo and a moment', () {
      final e = SliceEngine(stage, plan: [
        fruitAt(1, 0.8, 0.6, 1100),
        fruitAt(2, 0.8, 0.6, 1700),
        fruitAt(3, 0.8, 0.6, 2300, kind: SliceKind.bomb),
        fruitAt(4, 0.8, 0.6, 2900),
        fruitAt(5, 0.8, 0.6, 4500),
      ]);
      final events = play(e, (clock) {
        for (final at in [1100, 1700, 2300, 2900, 4500]) {
          if (clock >= at && clock < at + 33) return (1.3, 0.6);
        }
        return (0.3, 0.6);
      }, untilMs: 6000);
      final bomb = of(events, 'bomb').single;
      expect(bomb.points, -150);
      expect(e.bombsHit, 1);
      // The fruit 600 ms after the mine could not be cut (blades dead for
      // 1.2 s); the one after could, with a fresh combo.
      expect(of(events, 'slice'), hasLength(3));
      expect(e.targets[3].missed, isTrue);
      expect(e.combo, 1);
    });

    test('a mine never takes the score below zero', () {
      final e = SliceEngine(stage,
          plan: [fruitAt(1, 0.8, 0.6, 1100, kind: SliceKind.bomb)]);
      final events = play(e, sweep(0.8, 0.6, 1100));
      expect(e.score, 0);
      expect(of(events, 'bomb').single.points, 0);
    });

    test('leaving a mine alone costs nothing', () {
      final e = SliceEngine(stage,
          plan: [fruitAt(1, 0.8, 0.6, 1100, kind: SliceKind.bomb)]);
      final events = play(e, (_) => (0.3, -1.0));
      expect(of(events, 'miss'), isEmpty);
      expect(of(events, 'bomb'), isEmpty);
      expect(e.summary.accuracy, 0);
      expect(e.bombsHit, 0);
    });
  });

  group('tracking', () {
    test('lost tracking freezes the fruit and never counts a miss', () {
      final e = SliceEngine(stage, plan: [fruitAt(1, 0.8, 0.6, 1100)]);
      // Tracking is lost for 5 s while the fruit is on its way down; it
      // lands just after tracking returns.
      final events = play(e, (_) => (0.3, -1.0),
          untilMs: 3000, tracked: (t) => t < 1700 || t > 6700);
      expect(of(events, 'hold'), hasLength(1));
      expect(of(events, 'resume'), hasLength(1));
      // It fell during the grace after coming back: forgiven.
      expect(of(events, 'miss'), isEmpty);
      expect(of(events, 'forgiven'), hasLength(1));
      expect(e.summary.forgiven, 1);
    });

    test('a hand seen again after a gap does not cut on its first frame',
        () {
      final e = SliceEngine(stage, plan: [fruitAt(1, 0.8, 0.6, 1100)]);
      // Hand at the left of the fruit, lost for a second, then seen at the
      // right of it: the two positions are a second apart, so no blade.
      final events = play(e, (clock) => (clock < 1040 ? 0.3 : 1.3, 0.6),
          tracked: (t) => t < 1000 || t > 2000);
      expect(of(events, 'slice'), isEmpty);
    });
  });

  group('the seeded round', () {
    // A full minute, so pacing and mines are statistics, not luck.
    const round = SliceStage(
      id: 'r',
      name: 'Test Round',
      durationMs: 60000,
      startPerMin: 20,
      peakPerMin: 44,
      bombShare: 0.5,
      waveShare: 0.3,
    );

    test('is the same every time for the same seed', () {
      final a = SliceEngine(round), b = SliceEngine(round);
      expect([for (final t in a.targets) (t.launchAt, t.x0, t.kind)],
          [for (final t in b.targets) (t.launchAt, t.x0, t.kind)]);
      final c = SliceEngine(round.variant(seed: 99));
      expect([for (final t in c.targets) t.x0],
          isNot([for (final t in a.targets) t.x0]));
    });

    test('gets busier as it goes', () {
      final e = SliceEngine(round);
      int launches(int from, int to) => e.targets
          .where((t) => !t.isBomb && t.launchAt >= from && t.launchAt < to)
          .length;
      expect(launches(36000, 54000), greaterThan(launches(2000, 20000)));
    });

    test('keeps mines out of the first ten seconds and ends on a fan', () {
      final e = SliceEngine(round);
      expect(e.targets.where((t) => t.isBomb), isNotEmpty);
      expect(e.targets.where((t) => t.isBomb && t.launchAt < 10000), isEmpty);
      expect(e.targets.where((t) => t.golden), hasLength(5));
      for (final t in e.targets) {
        expect(t.landAt, lessThan(round.durationMs), reason: 'fruit ${t.id}');
        expect(t.apexY, inInclusiveRange(0.25, 1.35));
        expect(t.x0.abs(), lessThanOrEqualTo(1.45));
      }
    });

    test('assist makes fruit bigger, slower and easier to cut', () {
      final a = stage.variant(assist: true);
      expect(a.radius, greaterThan(stage.radius));
      expect(a.minSpeed, lessThan(stage.minSpeed));
      expect(a.flightMs, greaterThan(stage.flightMs));
      expect(a.bombShare, lessThan(stage.bombShare));
    });

    test('a careful player clears most of it; a still one scores nothing',
        () {
      final e = SliceEngine(round);
      final bot = SliceBot(e);
      drive(e, bot.step);
      expect(e.finished, isTrue);
      expect(e.summary.accuracy, greaterThan(0.5));
      expect(e.bombsHit, 0);
      expect(e.summary.moves['slice'], greaterThan(8));

      final idle = SliceEngine(round);
      drive(idle, (_) => (relaxed, {}));
      expect(idle.score, 0);
      expect(idle.summary.stars, 0);
      expect(idle.summary.completed, isTrue);
    });
  });
}
