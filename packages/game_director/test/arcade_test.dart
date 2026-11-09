import 'package:game_director/game_director.dart';
import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:test/test.dart';

import 'support/arcade_bots.dart';

void main() {
  group('shared', () {
    test('timing windows are late-biased', () {
      const w = TimingWindows(perfect: 100, good: 200, ok: 300, lateBias: 80);
      expect(w.grade(0), Grade.perfect);
      expect(w.grade(60), Grade.perfect);
      expect(w.grade(-150), Grade.good);
      expect(w.grade(250), Grade.good);
      expect(w.grade(-290), Grade.ok);
      expect(w.grade(-400), Grade.miss);
    });

    test('seeded random is repeatable', () {
      final a = SeededRandom(42), b = SeededRandom(42);
      for (var i = 0; i < 20; i++) {
        expect(a.next(), b.next());
      }
      expect(dailySeed(DateTime.utc(2026, 11, 9, 20)),
          dailySeed(DateTime.utc(2026, 11, 9, 20, 30)),
          reason: 'same IST day');
    });
  });

  group('Mirror Mela', () {
    const stage = MelaStage(
      id: 't',
      name: 'Test Bazaar',
      mode: 'bazaar',
      durationMs: 30000,
      warningMs: 2000,
      targetsPerMin: 20,
      radius: 0.5,
      zones: ['sideL', 'sideR'],
      anyHand: false,
    );

    BotStep reacher(MelaEngine e, int clock) {
      for (final t in e.targets) {
        if (t.done || t.isHazard) continue;
        if ((clock - 100 - t.hitAt).abs() <= 120) {
          if (t.kind == MelaKind.crown) return (armsUp, {});
          if (t.kind == MelaKind.chest) return (clap, {});
          if (t.y > 0.6) return (t.x < 0 ? hiL : hiR, {});
          return (t.x < 0 ? padL : padR, {});
        }
      }
      return (relaxed, {});
    }

    test('the plan is deterministic and ends with a golden finale', () {
      final a = MelaEngine(stage), b = MelaEngine(stage);
      expect([for (final t in a.targets) t.hitAt],
          [for (final t in b.targets) t.hitAt]);
      expect(a.targets.where((t) => t.golden), hasLength(5));
    });

    test('reaching each target on time pops it', () {
      final e = MelaEngine(stage);
      drive(e, (c) => reacher(e, c));
      expect(e.finished, isTrue);
      final s = e.summary;
      expect(s.accuracy, greaterThan(0.85));
      expect(s.stars, greaterThanOrEqualTo(2));
      expect(s.moves['reach'], greaterThan(5));
    });

    test('a still player misses, and nothing pops by itself', () {
      final e = MelaEngine(stage);
      drive(e, (_) => (relaxed, {}));
      expect(e.score, 0);
      expect(e.targets.every((t) => t.grade == Grade.miss), isTrue);
    });

    test('lost tracking freezes the clock and forgives, never misses', () {
      final e = MelaEngine(stage);
      drive(e, (_) => (relaxed, {}), maxMs: 20000, tracked: (c) => c < 4000);
      expect(e.clockMs, lessThan(4100));
      expect(e.holding, isTrue);
      final e2 = MelaEngine(stage);
      var t = 0;
      drive(e2, (c) => reacher(e2, c), maxMs: 60000, tracked: (_) {
        t += 33;
        return t < 4000 || t > 9000;
      });
      expect(e2.targets.where((x) => x.grade == Grade.miss), isEmpty);
    });

    test('orbit sweeps are dodged by ducking', () {
      const orbit = MelaStage(
        id: 'o',
        name: 'Orbit',
        mode: 'orbit',
        durationMs: 60000,
        warningMs: 2000,
        targetsPerMin: 24,
        radius: 0.5,
        hazardShare: 0.5,
      );
      final e = MelaEngine(orbit);
      expect(e.targets.where((t) => t.isHazard), isNotEmpty);
      drive(e, (c) {
        for (final t in e.targets) {
          if (!t.done && t.isHazard && (t.hitAt - (c - 100)) < 400) {
            return switch (t.kind) {
              MelaKind.duck => (relaxed, {Move.squat}),
              MelaKind.dodgeLeft => (relaxed, {Move.leanRight}),
              _ => (relaxed, {Move.leanLeft}),
            };
          }
        }
        return reacher(e, c);
      });
      expect(
          e.targets.where((t) => t.isHazard && t.grade == Grade.miss), isEmpty);
      expect(e.shields, 3);
    });
  });

  group('Pataka Pose', () {
    final library = {
      'goalpost': PatakaPose.fromJson({
        'id': 'goalpost',
        'name': 'Goalpost',
        'angles': {
          'shoulderL': 90,
          'shoulderR': 90,
          'elbowL': 90,
          'elbowR': 90,
        },
        'must': ['elbowL', 'elbowR'],
        'holdMs': 1200,
      }),
    };
    final goal =
        stickFrame(shoulderL: 90, shoulderR: 90, elbowL: 90, elbowR: 90);
    const stage = PatakaStage(
        id: 's', name: 'Test', frames: ['goalpost', 'chill', 'goalpost']);

    test('striking and holding the shape bursts every frame', () {
      final e = PatakaEngine(stage: stage, library: library);
      drive(e, (_) => (e.frame?.kind == FrameKind.chill ? relaxed : goal, {}));
      expect(e.finished, isTrue);
      expect(e.frames.where((f) => f.kind == FrameKind.cutout && f.burst),
          hasLength(2));
      expect(e.summary.stars, 3);
    });

    test('the wrong shape does not burst and earns a hint', () {
      final e = PatakaEngine(stage: stage, library: library);
      final lines = <String>[];
      drive(e, (_) {
        lines.addAll([
          for (final ev in e.drainEvents())
            if (ev.kind == 'miss' && ev.text != null) ev.text!,
        ]);
        return (relaxed, {});
      });
      expect(e.frames.where((f) => f.kind == FrameKind.cutout && f.burst),
          isEmpty);
      expect(lines, isNotEmpty);
    });

    test('a frame we cannot see hovers instead of scoring', () {
      final e = PatakaEngine(stage: stage, library: library);
      final hidden = stickFrame(
          shoulderL: 90,
          shoulderR: 90,
          elbowL: 90,
          elbowR: 90,
          hidden: {Lm.leftElbow: 0.1, Lm.rightElbow: 0.1});
      drive(e, (_) => (hidden, {}), maxMs: 15000);
      expect(e.current, 0, reason: 'still waiting on the first frame');
      expect(e.frames.first.age, 0);
    });

    test('pass-the-pataka rotates players', () {
      final e = PatakaEngine(
          stage: const PatakaStage(
              id: 'p', name: 'Party', frames: ['goalpost', 'goalpost']),
          library: library,
          players: ['Asha', 'Ravi'],
          framesPerTurn: 1);
      expect(e.frames.map((f) => f.player), [0, 1]);
      drive(e, (_) => (goal, {}));
      expect(e.playerScores.every((s) => s > 0), isTrue);
    });
  });

  group('Craftguard Duels', () {
    const g = Guardian(
      id: 'g',
      name: 'Test Warden',
      art: 'baoli',
      bpm: {'beginner': 80},
      phases: [
        [DuelMove.duck, DuelMove.right, DuelMove.duck, DuelMove.left],
        [DuelMove.guard, DuelMove.duck, DuelMove.left, DuelMove.guard],
        [DuelMove.duck, DuelMove.left, DuelMove.guard, DuelMove.right],
      ],
    );

    test('a clean fighter calms the guardian with all sparks', () {
      final e = DuelEngine(g);
      drive(e, (c) => fighter(e, c));
      expect(e.calmed, isTrue);
      expect(e.sparks, 3);
      final s = e.summary;
      expect(s.completed, isTrue);
      expect(s.stars, 3);
      expect(s.moves['duck'], greaterThan(0));
      expect(s.moves['side strike'], greaterThan(0));
    });

    test('a still player loses sparks slowly and regroups, never game over',
        () {
      final e = DuelEngine(g);
      drive(e, (_) => (relaxed, {}), maxMs: 120000);
      expect(e.finished, isFalse);
      expect(e.regroups, greaterThan(0));
      expect(e.sparks, greaterThan(0));
    });

    test('a punch with no pad live does nothing (rule 6)', () {
      final e = DuelEngine(g);
      drive(e, (_) => (padL, {}), maxMs: 6000);
      expect(e.score, 0);
    });

    test('tracking loss forgives the attack it covers', () {
      final e = DuelEngine(g);
      var wall = 0;
      drive(e, (c) => fighter(e, c), maxMs: 40000, tracked: (_) {
        wall += 33;
        return wall < 7000 || wall > 12000;
      });
      expect(e.sparks, 3);
    });
  });

  group('Taal Toofan', () {
    const song = TaalSong(
      id: 'test',
      title: 'Test Groove',
      family: 'dhol',
      bpm: 96,
      sections: [
        TaalSection('Verse', 'verse', 6,
            ['stepL', '-', 'stepR', '-', 'clap', '-', 'clap', '-']),
        TaalSection('Hook', 'hook', 6,
            ['waveL', 'clap', 'waveR', 'clap', 'dip', '-', 'reachL', 'hoy']),
        TaalSection(
            'Chill', 'chill', 1, ['-', '-', '-', '-', '-', '-', '-', '-']),
      ],
    );
    test('levels score different numbers of cards from one routine', () {
      final light = TaalEngine(song, level: 'light').cards.length;
      final groove = TaalEngine(song, level: 'groove').cards.length;
      final toofan = TaalEngine(song, level: 'toofan').cards.length;
      expect(light, lessThan(groove));
      expect(groove, lessThanOrEqualTo(toofan));
    });

    test('dancing on the beat earns high accuracy and Toofan Time', () {
      final e = TaalEngine(song, level: 'toofan');
      var toofan = false;
      drive(e, (c) {
        if (e.toofan) toofan = true;
        return dancer(e, c);
      });
      expect(e.finished, isTrue);
      expect(e.summary.accuracy, greaterThan(0.85));
      expect(e.summary.stars, greaterThanOrEqualTo(4));
      expect(toofan, isTrue);
      expect(e.stems, containsAll(['claps', 'dhol', 'melody', 'bass']));
    });

    test('the song always finishes, even standing still', () {
      final e = TaalEngine(song);
      drive(e, (_) => (relaxed, {}));
      expect(e.finished, isTrue);
      expect(e.summary.accuracy, 0);
    });

    test('a held clap is capped at Good (no camping)', () {
      final e = TaalEngine(const TaalSong(
          id: 'c',
          title: 'Claps',
          family: 'raas',
          bpm: 90,
          sections: [
            TaalSection('V', 'verse', 2,
                ['clap', '-', 'clap', '-', 'clap', '-', 'clap', '-']),
          ]));
      drive(e, (_) => (clap, {}));
      expect(e.grades[Grade.perfect], 0);
    });
  });

  group('Tapeball Tamasha', () {
    final table = OutcomeTable.fromJson({
      'drive': {
        'perfect': [
          [4, 1]
        ],
        'good': [
          [2, 1]
        ],
        'ok': [
          [1, 1]
        ],
      },
      'lofted': {
        'perfect': [
          [6, 1]
        ],
        'good': [
          [4, 1]
        ],
        'ok': [
          [-1, 1]
        ],
      },
    });
    const nets = CricketFormat(id: 'nets', name: 'Nets', balls: 6, seed: 3);

    /// Hands at body-space (x, y), as in the swing tests.
    PoseFrame hands(double x, double y) {
      const aspect = 0.75, torso = 0.18;
      final px = 0.5 * aspect + x * torso, py = 0.55 - torso - y * torso;
      return stickFrame(override: {
        Lm.leftWrist: (px - 0.01, py),
        Lm.rightWrist: (px + 0.01, py),
        17: (px - 0.01, py),
        19: (px - 0.01, py),
        18: (px + 0.01, py),
        20: (px + 0.01, py),
      });
    }

    BotStep batter(CricketEngine e, int clock) {
      final d = e.current;
      if (d == null || e.phase != 'runup') return (relaxed, {});
      if (d.line == BallLine.wide) {
        return (clock - 100 > d.arriveAt - 200 ? armsUp : relaxed, {});
      }
      // Swing so the travel completes right at arrival.
      final start = d.arriveAt - 450;
      final t = clock - 100;
      if (t < start - 300) return (relaxed, {});
      if (t < start) return (hands(0.45, 0.25), {});
      final k = ((t - start) / 600).clamp(0.0, 1.0);
      return (hands(0.45 - k * 1.1, 0.25 - k * 1.1), {});
    }

    test('timed swings score runs', () {
      final e = CricketEngine(nets, table);
      drive(e, (c) => batter(e, c));
      expect(e.finished, isTrue);
      expect(e.runs, greaterThan(6));
      expect(e.summary.moves['swing'], greaterThan(0));
    });

    test('standing still in nets never loses a wicket on beginner', () {
      final e = CricketEngine(
          const CricketFormat(
              id: 'so', name: 'Super Over', balls: 6, wickets: 2, target: 12),
          table);
      drive(e, (_) => (relaxed, {}));
      expect(e.finished, isTrue);
      expect(e.wickets, 0);
      expect(e.won, isFalse);
    });

    test('lost tracking during a run-up is a dead ball, re-bowled', () {
      final e = CricketEngine(nets, table);
      var wall = 0;
      drive(e, (c) => batter(e, c), tracked: (_) {
        wall += 33;
        return wall < 2500 || wall > 3500;
      });
      expect(e.summary.forgiven, greaterThanOrEqualTo(1));
      expect(e.legal, nets.balls);
    });
  });

  group('LUMEN', () {
    LumenBoard worked() => LumenBoard(
          id: 'worked',
          title: 'Water pump',
          module: 'water',
          rows: 3,
          cols: 3,
          source: (1, 0, Dir.e),
          receiver: (2, 2, Dir.n),
          pieces: [
            LumenPiece(1, 1, PieceType.corner, 2, card: 1), // A: S-W
            LumenPiece(0, 1, PieceType.corner, 3, card: 2), // B: W-N
            LumenPiece(0, 2, PieceType.corner, 0, card: 3), // C: N-E
            LumenPiece(1, 2, PieceType.straight, 0, fixed: true), // D: N-S
          ],
        );

    test('the worked board from the research doc solves in five turns', () {
      final b = worked();
      expect(b.connected, isFalse);
      b.editable[0].turn(true); // A → W-N
      b.editable[1]
        ..turn(true)
        ..turn(true); // B → E-S
      expect(b.connected, isFalse);
      b.editable[2]
        ..turn(true)
        ..turn(true); // C → S-W
      final (lit, ok) = b.trace();
      expect(ok, isTrue);
      expect(lit, [(1, 1), (0, 1), (0, 2), (1, 2)]);
    });

    test('reach-select, lean-turn and bend-weld restore the board', () {
      final e = LumenEngine(
          LumenStage(id: 's', name: 'Test', habitat: 'h', boards: [worked()]));
      final cardPose = {
        1: padL, // left hand out low-side is near card 1
        2: clap,
        3: padR,
      };
      // Card zones sit below the shoulders; a straight side arm at 60°
      // reaches them.
      cardPose[1] = stickFrame(shoulderL: 55);
      cardPose[3] = stickFrame(shoulderR: 55);
      cardPose[2] = stickFrame(shoulderR: 20, elbowR: 60);
      final script = <(int, int)>[(1, 1), (2, 2), (3, 2)]; // (card, turns)
      var step = 0, turned = 0;
      var phase = 'select';
      var since = 0;
      drive(e, (c) {
        if (e.state == 'intro' || e.state == 'restoring') {
          return (relaxed, {});
        }
        if (e.state == 'ready') {
          since += 33;
          return (relaxed, since > 500 && e.weldArmed ? {Move.squat} : {});
        }
        if (step >= script.length) return (relaxed, {});
        final (card, turns) = script[step];
        switch (phase) {
          case 'select':
            if (e.selected == card && e.state == 'edit') {
              phase = 'release';
              since = 0;
              return (relaxed, {});
            }
            return (cardPose[card]!, {});
          case 'release':
            since += 33;
            if (since > 500) {
              phase = 'lean';
              since = 0;
            }
            return (relaxed, {});
          default:
            since += 33;
            if (since < 300) return (relaxed, {Move.leanRight});
            if (since < 700) return (relaxed, {});
            turned++;
            since = 0;
            if (turned >= turns) {
              turned = 0;
              step++;
              phase = 'select';
            }
            return (relaxed, {});
        }
      }, maxMs: 120000);
      expect(e.finished, isTrue);
      expect(e.restored, 1);
      expect(e.turns, 5);
      expect(e.welds, 1);
      expect(e.summary.stars, 3);
    });

    test('a bend before the route connects never welds', () {
      final e = LumenEngine(
          LumenStage(id: 's', name: 'Test', habitat: 'h', boards: [worked()]));
      drive(e, (c) => (relaxed, {if ((c ~/ 1000).isEven) Move.squat}),
          maxMs: 20000);
      expect(e.welds, 0);
      expect(e.state, 'inspect');
    });
  });
}
