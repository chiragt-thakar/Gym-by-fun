import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_director/game_director.dart';
import 'package:go_router/go_router.dart';

import '../l10n/tr.dart';

import 'package:motion_core/motion_core.dart';

import '../game/forest_game.dart';
import '../l10n/strings.dart';
import '../services/pose_service.dart';
import '../services/session_queue.dart';
import '../services/settings.dart';
import '../services/voice.dart';
import '../widgets/common.dart';
import 'results_screen.dart';

const forestAsset = 'assets/levels/w1-forest-escape.json';

Future<LevelConfig> loadForest(AssetBundle bundle) async =>
    LevelConfig.decode(await bundle.loadString(forestAsset));

/// The tutorial is Forest Escape's practice segment on its own.
LevelConfig tutorialFrom(LevelConfig l) {
  final practice = l.segments.firstWhere((s) => s.kind == SegmentKind.practice);
  return LevelConfig(
    id: l.id,
    version: l.version,
    schemaVersion: l.schemaVersion,
    world: l.world,
    name: 'Tutorial',
    lanes: l.lanes,
    durationMs: practice.endMs + 2000,
    hearts: l.hearts,
    segments: [practice],
    encounters: l.encounters.where((e) => e.atMs < practice.endMs).toList(),
    difficulty: l.difficulty,
    scoring: l.scoring,
  );
}

class Exercise {
  const Exercise(this.name, this.seconds, this.cue);
  final String name;
  final int seconds;
  final String cue;
}

/// Gentle, low-impact warm-up (75 s) and cool-down (60 s).
const warmup = [
  Exercise('March in place', 15, 'March gently on the spot, swing your arms.'),
  Exercise('Arm circles', 15, 'Small arm circles, then bigger.'),
  Exercise('Side reaches', 15, 'Reach one arm over your head, then the other.'),
  Exercise('Half squats', 15, 'Slow, gentle half squats. Knees over toes.'),
  Exercise('Shoulder rolls', 15, 'Roll your shoulders back and breathe.'),
];
const cooldown = [
  Exercise(
    'Overhead stretch',
    12,
    'Reach both arms up and breathe out slowly.',
  ),
  Exercise('Side stretch left', 12, 'Lean gently to the left and hold.'),
  Exercise('Side stretch right', 12, 'Lean gently to the right and hold.'),
  Exercise(
    'Calf stretch',
    12,
    'Hold a wall, step one foot back, heel down. Swap halfway.',
  ),
  Exercise('Deep breaths', 12, 'Breathe in for four, out for six. Great work.'),
];

enum _Phase { loading, warmup, run, cooldown }

class QuestScreen extends ConsumerStatefulWidget {
  const QuestScreen({super.key, this.tutorial = false});
  final bool tutorial;
  @override
  ConsumerState<QuestScreen> createState() => _QuestState();
}

class _QuestState extends ConsumerState<QuestScreen> implements GameAudio {
  _Phase _phase = _Phase.loading;
  MotionSession? _session;
  ForestGame? _game;
  RunResult? _result;
  Map<String, Map<String, int>>? _stats;
  late DateTime _startedAt;
  final _clientId = SessionQueue.newClientId();
  String? _error;

  Voice get _voice => ref.read(voiceProvider);

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    final s = ref.read(settingsProvider);
    final cal = s.calibration;
    if (cal == null) {
      if (mounted) context.go('/calibrate');
      return;
    }
    final bundle = DefaultAssetBundle.of(context);
    await _voice.init(s.language);
    final forest = await loadForest(bundle);
    final level = widget.tutorial ? tutorialFrom(forest) : forest;
    final runSettings = widget.tutorial
        ? RunSettings(
            difficulty: Difficulty.beginner,
            lowImpact: s.lowImpact,
            assist: true,
          )
        : s.runSettings;
    final session = MotionSession(
      ref.read(poseSourceProvider),
      initialCalibration: cal,
      thresholds: s.thresholds,
    );
    if (!await session.start(tier: s.deviceTier ?? DeviceTier.mid)) {
      setState(() => _error = tr('Camera permission is needed to play.'));
      return;
    }
    _session = session;
    _startedAt = DateTime.now();
    _game = ForestGame(
      engine: RunEngine(level, runSettings),
      motionEvents: session.events,
      audio: this,
      lightOf: () => session.engine?.light ?? TrackingLight.red,
      onFinished: (r) => WidgetsBinding.instance.addPostFrameCallback(
        (_) => _onRunFinished(r),
      ),
    );
    setState(() => _phase = widget.tutorial ? _Phase.run : _Phase.warmup);
  }

  void _onRunFinished(RunResult r) {
    _result = r;
    _stats = _session?.moveStats();
    _session?.stop();
    if (widget.tutorial) {
      _complete();
    } else {
      setState(() => _phase = _Phase.cooldown);
    }
  }

  Future<void> _complete() async {
    final r = _result;
    final session = _session;
    _session = null;
    final stats = _stats ?? session?.moveStats();
    await session?.dispose();
    if (r == null || !mounted) return;
    final s = ref.read(settingsProvider);
    final durationS = DateTime.now()
        .difference(_startedAt)
        .inSeconds
        .clamp(1, 3600);
    final data = ResultsData(
      result: r,
      clientId: _clientId,
      startedAt: _startedAt,
      durationS: durationS,
      moveStats: stats,
      tutorial: widget.tutorial,
    );
    ref
        .read(settingsProvider.notifier)
        .update(
          (x) => x.copyWith(
            tutorialDone: true,
            sessionsPlayed: widget.tutorial
                ? s.sessionsPlayed
                : s.sessionsPlayed + 1,
            seenTypes: {...s.seenTypes, ...EncounterType.values},
          ),
        );
    context.go('/results', extra: data);
  }

  @override
  void dispose() {
    _session?.dispose();
    _voice.stop();
    super.dispose();
  }

  // GameAudio
  @override
  void cue(String name) => _voice.cue(name);
  @override
  void say(String text) => _voice.say(text);
  @override
  void sayKey(String key) => _voice.sayKey(key, force: true);

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ScreenScaffold(
        title: 'Daily Quest',
        children: [
          Text(_error!, style: const TextStyle(fontSize: 19)),
          BigButton('Back', onPressed: () => context.go('/home')),
        ],
      );
    }
    final s = ref.watch(settingsProvider).s;
    return switch (_phase) {
      _Phase.loading => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      _Phase.warmup => _ExerciseFlow(
        title: s.t('warmup'),
        exercises: warmup,
        voice: _voice,
        onDone: () => setState(() => _phase = _Phase.run),
      ),
      _Phase.run => _RunView(game: _game!, s: s),
      _Phase.cooldown => _ExerciseFlow(
        title: s.t('cooldown'),
        exercises: cooldown,
        voice: _voice,
        onDone: _complete,
      ),
    };
  }
}

class _RunView extends StatelessWidget {
  const _RunView({required this.game, required this.s});
  final ForestGame game;
  final S s;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(game: game),
          SafeArea(
            child: ValueListenableBuilder<HudState>(
              valueListenable: game.hud,
              builder: (context, h, _) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        for (var i = 0; i < h.maxHearts; i++)
                          Icon(
                            i < h.hearts
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: Colors.redAccent,
                            size: 40,
                          ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.bolt,
                          color: Colors.cyanAccent,
                          size: 36,
                        ),
                        Text(
                          '${h.energy}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${h.score}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 12),
                        TrackingDot(h.light, size: 36),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: LinearProgressIndicator(
                      value: h.progress,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  const Spacer(),
                  if (h.trackingIssue != null)
                    _Banner(
                      text: s.t(ForestGame.issueKey(h.trackingIssue!)),
                      color: Colors.black87,
                    )
                  else if (h.hint != null)
                    _Banner(text: h.hint!, color: Colors.black54),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w800,
        color: Colors.white,
      ),
    ),
  );
}

/// A timed, voice-guided list of gentle exercises.
class _ExerciseFlow extends StatefulWidget {
  const _ExerciseFlow({
    required this.title,
    required this.exercises,
    required this.voice,
    required this.onDone,
  });
  final String title;
  final List<Exercise> exercises;
  final Voice voice;
  final VoidCallback onDone;
  @override
  State<_ExerciseFlow> createState() => _ExerciseFlowState();
}

class _ExerciseFlowState extends State<_ExerciseFlow> {
  int _i = 0;
  int _left = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _begin(0);
  }

  void _begin(int i) {
    if (i >= widget.exercises.length) {
      _timer?.cancel();
      widget.onDone();
      return;
    }
    final e = widget.exercises[i];
    setState(() {
      _i = i;
      _left = e.seconds;
    });
    widget.voice.say('${tr(e.name)}. ${tr(e.cue)}', force: true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_left <= 1) {
        _begin(_i + 1);
      } else {
        setState(() => _left--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.exercises[_i];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const Spacer(),
              Text(
                tr(e.name),
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                tr(e.cue),
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Text(
                '$_left',
                style: const TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text('${_i + 1} / ${widget.exercises.length}'),
              BigButton(
                tr('Skip'),
                secondary: true,
                onPressed: () => _begin(_i + 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
