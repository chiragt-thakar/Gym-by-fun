import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_director/game_director.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:motionquest/app/router.dart';
import 'package:motionquest/game/forest_game.dart';
import 'package:motionquest/l10n/strings.dart';
import 'package:motionquest/screens/quest_screen.dart';
import 'package:motionquest/services/api_client.dart';
import 'package:motionquest/services/pose_service.dart';
import 'package:motionquest/services/session_queue.dart';
import 'package:motionquest/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

LevelConfig forest() => LevelConfig.decode(File('assets/levels/w1-forest-escape.json').readAsStringSync());

void main() {
  test('bundled levels match the canonical content/levels', () {
    for (final f in Directory('../content/levels').listSync().whereType<File>()) {
      final bundled = File('assets/levels/${f.uri.pathSegments.last}');
      expect(bundled.existsSync(), isTrue, reason: 'run tools/sync_content.sh');
      expect(bundled.readAsStringSync(), f.readAsStringSync(), reason: 'run tools/sync_content.sh');
    }
  });

  test('onboarding order: age → readiness → setup → calibrate → tutorial → home', () {
    var s = const Settings();
    expect(nextOnboardingStep(s), '/welcome');
    s = s.copyWith(ageConfirmed: true);
    expect(nextOnboardingStep(s), '/readiness');
    s = s.copyWith(readinessDone: true);
    expect(nextOnboardingStep(s), '/setup');
    s = s.copyWith(setupDone: true);
    expect(nextOnboardingStep(s), '/calibrate');
    s = s.copyWith(calibration: CalibrationProfile.fromStanding(PoseFrame(timestampMs: 0, landmarks: SyntheticBody(noise: 0).pose())));
    expect(nextOnboardingStep(s), '/tutorial');
    s = s.copyWith(tutorialDone: true);
    expect(nextOnboardingStep(s), isNull);
  });

  test('settings round-trip; low-impact is the default', () {
    const s = Settings();
    expect(s.lowImpact, isTrue);
    expect(s.thresholds.allowOneArm, isTrue);
    final back = Settings.fromJson(jsonDecode(jsonEncode(s.copyWith(language: AppLanguage.gu, difficulty: Difficulty.advanced, seenTypes: {EncounterType.beam}).toJson())) as Map<String, dynamic>);
    expect(back.language, AppLanguage.gu);
    expect(back.difficulty, Difficulty.advanced);
    expect(back.seenTypes, {EncounterType.beam});
  });

  test('every UI string has English; voice cues exist in all three languages', () {
    for (final key in ['squat_hint', 'lean_hint', 'orb_hint', 'gate_hint', 'step_back', 'checkpoint']) {
      for (final l in AppLanguage.values) {
        expect(S(l).t(key), isNot(key), reason: '$key/$l');
      }
    }
  });

  test('tutorial is the practice segment only', () {
    final t = tutorialFrom(forest());
    expect(t.durationMs, lessThan(40000));
    expect(t.encounters.every((e) => e.atMs < 30000), isTrue);
    expect(t.checkpoint, isNull);
  });

  test('motion session turns replayed landmarks into move events', () async {
    final s = SyntheticSession(SyntheticBody(seed: 3));
    final cal = s.calibrate();
    final src = ReplayPoseSource(s.record([
      const ScriptStep(Action.idle, 1000),
      const ScriptStep(Action.squat, 1400),
      const ScriptStep(Action.idle, 800),
    ]).frames);
    final session = MotionSession(src, initialCalibration: cal);
    expect(await session.start(), isTrue);
    final events = <MotionEvent>[];
    final sub = session.events.listen(events.add);
    src.playAll();
    await Future<void>.delayed(Duration.zero);
    expect(events.whereType<MoveStarted>().map((e) => e.move), [Move.squat]);
    expect(session.perf.fps, greaterThan(20));
    expect(session.moveStats()['squat']!['attempts'], 1);
    await sub.cancel();
    await session.dispose();
  });

  test('camera permission denied → session does not start', () async {
    final session = MotionSession(ReplayPoseSource(const [], permission: false), initialCalibration: null);
    expect(await session.start(), isFalse);
  });

  test('forest painter draws every encounter type without errors', () {
    final engine = RunEngine(forest(), const RunSettings());
    for (final at in [8000.0, 15500.0, 27500.0, 153500.0]) {
      final rec = PictureRecorder();
      ForestPainter(
        size: const Size(400, 800),
        t: at / 1000,
        clockMs: at,
        plan: engine.plan,
        heroLane: 1,
        ducking: at > 10000,
        armsUp: at > 20000,
        lanes: 3,
        warningMs: engine.director.warningMs,
      ).paint(Canvas(rec));
      rec.endRecording();
    }
  });

  group('offline session queue', () {
    late Directory tmp;
    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('mq');
      SharedPreferences.setMockInitialValues({'auth.access': 'a', 'auth.refresh': 'r'});
    });
    tearDown(() => tmp.delete(recursive: true));

    RunResult result() => const RunResult(
        levelId: 'w1-forest-escape', completed: true, score: 900, hearts: 2, cleared: 10, hit: 1, forgiven: 0, energy: 3,
        reps: {Move.squat: 4, Move.leanLeft: 2, Move.leanRight: 2, Move.raiseArms: 3},
        gameMs: 181000, activeMs: 175000, difficulty: Difficulty.beginner, lowImpact: true);

    test('keeps sessions while offline and uploads them later', () async {
      final prefs = await SharedPreferences.getInstance();
      var online = false;
      final uploaded = <dynamic>[];
      final client = MockClient((req) async {
        if (!online) throw const SocketException('offline');
        uploaded.addAll((jsonDecode(req.body) as Map)['sessions'] as List);
        return http.Response(jsonEncode({'accepted': [], 'duplicates': [], 'flagged': []}), 200);
      });
      final q = SessionQueue(ApiClient(TokenStore(prefs), client: client, base: 'http://x'), dir: () async => tmp);
      await q.add(SessionQueue.fromResult(result(), clientId: 'abc12345', startedAt: DateTime.utc(2026, 11, 4), durationS: 300));
      expect(await q.flush(), 0);
      expect((await q.pending()).length, 1);
      online = true;
      expect(await q.flush(), 1);
      expect(await q.pending(), isEmpty);
      final s = uploaded.single as Map;
      expect(s['clientId'], 'abc12345');
      expect(s['activeS'], 175);
      expect(s['difficulty'], 'beginner');
    });
  });
}
