import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_director/game_director.dart';
import 'package:go_router/go_router.dart';

import '../l10n/tr.dart';

import '../game/forest_game.dart';
import '../game/stages.dart';
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
  const QuestScreen({super.key, this.tutorial = false, this.levelId});
  final bool tutorial;

  /// Stage to play (see game/stages.dart). Null plays Forest Escape.
  final String? levelId;
  @override
  ConsumerState<QuestScreen> createState() => _QuestState();
}

class _QuestState extends ConsumerState<QuestScreen>
    with WidgetsBindingObserver
    implements GameAudio {
  _Phase _phase = _Phase.loading;
  MotionSession? _session;
  ForestGame? _game;
  Stage _stage = stages.first;
  RunResult? _result;
  Map<String, Map<String, int>>? _stats;
  late DateTime _startedAt;
  final _clientId = SessionQueue.newClientId();
  String? _error;
  DeviceTier _tier = DeviceTier.mid;

  /// The run (or exercise flow) is paused: by the player, or by the app
  /// going to the background. Pausing never costs hearts or progress.
  bool _paused = false;

  /// A failed run past the checkpoint, waiting for the player's choice.
  RunResult? _checkpointOffer;
  bool _disposed = false;

  Voice get _voice => ref.read(voiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    try {
      await _voice.init(s.language);
      if (!mounted) return;
      _stage = widget.tutorial
          ? stages.first
          : (stageById(widget.levelId ?? forestEscapeId) ?? stages.first);
      final level = widget.tutorial
          ? tutorialFrom(await loadForest(bundle))
          : LevelConfig.decode(await bundle.loadString(_stage.asset));
      if (!mounted) return;
      final runSettings = widget.tutorial
          ? RunSettings(
              difficulty: Difficulty.beginner,
              lowImpact: s.lowImpact,
              assist: true,
            )
          : s.runSettings;
      _tier = s.deviceTier ?? DeviceTier.mid;
      final session = MotionSession(
        ref.read(poseSourceProvider),
        initialCalibration: cal,
        thresholds: s.thresholds,
      );
      _session = session;
      _game = ForestGame(
        engine: RunEngine(level, runSettings),
        motionEvents: session.events,
        audio: this,
        theme: _stage.theme,
        lightOf: () => session.light,
        onFinished: (r) => WidgetsBinding.instance.addPostFrameCallback(
          (_) => _onRunFinished(r),
        ),
      )..pauseWhenBackgrounded = false;
    } catch (e) {
      if (mounted) setState(() => _error = tr('Something went wrong.'));
      return;
    }
    // The camera starts only when the run begins (not during warm-up).
    if (widget.tutorial) {
      await _beginRun();
    } else {
      setState(() => _phase = _Phase.warmup);
    }
  }

  /// Starts the camera session and the run. Returns false on failure.
  Future<bool> _startCamera() async {
    final session = _session;
    if (session == null) return false;
    bool ok;
    try {
      ok = await session.start(tier: _tier);
    } on PlatformException catch (e) {
      debugPrint('pose start failed: ${e.code}');
      ok = false;
      if (mounted) {
        setState(
          () => _error = e.code == 'no_permission'
              ? tr('Camera permission is needed to play.')
              : tr('The camera could not start. Please try again.'),
        );
      }
      await session.stop();
      return false;
    }
    if (!mounted || _disposed) {
      // The player left while the camera was starting: release it.
      await session.dispose();
      return false;
    }
    if (!ok) {
      setState(() => _error = tr('Camera permission is needed to play.'));
      return false;
    }
    return true;
  }

  Future<void> _beginRun() async {
    setState(() => _phase = _Phase.loading);
    if (!await _startCamera()) return;
    _startedAt = DateTime.now();
    setState(() => _phase = _Phase.run);
  }

  void _onRunFinished(RunResult r) {
    if (!mounted) return;
    final game = _game;
    if (!r.completed &&
        !widget.tutorial &&
        game != null &&
        game.engine.atCheckpoint) {
      game.pauseEngine();
      setState(() => _checkpointOffer = r);
      return;
    }
    _finishRun(r);
  }

  void _finishRun(RunResult r) {
    _result = r;
    _checkpointOffer = null;
    _stats = _session?.moveStats();
    _session?.stop();
    if (widget.tutorial) {
      _complete();
    } else {
      setState(() => _phase = _Phase.cooldown);
    }
  }

  void _continueFromCheckpoint() {
    final game = _game;
    if (game == null || !game.engine.restartFromCheckpoint()) {
      final r = _checkpointOffer;
      if (r != null) _finishRun(r);
      return;
    }
    setState(() => _checkpointOffer = null);
    game.resumeEngine();
  }

  // ------------------------------------------------------------ pausing

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive ||
          AppLifecycleState.hidden ||
          AppLifecycleState.paused:
        _pause();
      case AppLifecycleState.resumed || AppLifecycleState.detached:
        break;
    }
  }

  /// Freezes the run: game loop, camera and voice. Resume needs the player.
  void _pause() {
    if (_paused || _error != null || _phase == _Phase.loading) return;
    _paused = true;
    _voice.stop();
    if (_phase == _Phase.run) {
      _game?.pauseEngine();
      _session?.stop();
    }
    if (mounted) setState(() {});
  }

  Future<void> _resume() async {
    if (!_paused) return;
    if (_phase == _Phase.run) {
      if (!await _startCamera()) return;
      // A pending checkpoint choice keeps the game frozen until answered.
      if (_checkpointOffer == null) _game?.resumeEngine();
    }
    if (mounted) setState(() => _paused = false);
  }

  /// Leaves without saving: the player chose this explicitly.
  Future<void> _quit() async {
    final session = _session;
    _session = null;
    _game?.pauseEngine();
    _voice.stop();
    await session?.dispose();
    if (mounted) context.go('/home');
  }

  void _onBack() {
    switch (_phase) {
      case _Phase.loading:
        _quit();
      case _Phase.cooldown:
        _complete();
      case _Phase.warmup || _Phase.run:
        _pause();
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
    final engine = _game?.engine;
    final seen = <EncounterType>{
      if (engine != null)
        for (final p in engine.plan)
          if (p.arriveMs <= engine.clockMs) p.type,
    };
    ref
        .read(settingsProvider.notifier)
        .update(
          (x) => x.copyWith(
            // A failed tutorial is offered again next time.
            tutorialDone: s.tutorialDone || r.completed,
            sessionsPlayed: widget.tutorial
                ? s.sessionsPlayed
                : s.sessionsPlayed + 1,
            seenTypes: {...s.seenTypes, ...seen},
            completedLevels: !widget.tutorial && r.completed
                ? {...s.completedLevels, _stage.levelId}
                : null,
          ),
        );
    context.go('/results', extra: data);
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
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
    final body = switch (_phase) {
      _Phase.loading => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      _Phase.warmup => _ExerciseFlow(
        title: s.t('warmup'),
        exercises: warmup,
        voice: _voice,
        paused: _paused,
        onDone: _beginRun,
      ),
      _Phase.run => _RunView(game: _game!, s: s, onPause: _pause),
      _Phase.cooldown => _ExerciseFlow(
        title: s.t('cooldown'),
        exercises: cooldown,
        voice: _voice,
        paused: _paused,
        onDone: _complete,
      ),
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Stack(
        children: [
          body,
          if (_checkpointOffer != null)
            _Overlay(
              title: tr('Out of hearts'),
              text: tr('Your checkpoint is saved.'),
              actions: [
                BigButton(
                  tr('Continue from checkpoint'),
                  onPressed: _continueFromCheckpoint,
                ),
                BigButton(
                  tr('Finish run'),
                  secondary: true,
                  onPressed: () => _finishRun(_checkpointOffer!),
                ),
              ],
            )
          else if (_paused)
            _Overlay(
              title: tr('Paused'),
              text: tr('Ready? Step back into view and tap Resume.'),
              actions: [
                BigButton(tr('Resume'), onPressed: _resume),
                BigButton(
                  tr('Quit (this run is not saved)'),
                  secondary: true,
                  onPressed: _quit,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Full-screen modal card used for pause and checkpoint choices.
class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.title,
    required this.text,
    required this.actions,
  });
  final String title;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Material(
      color: Colors.black87,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, color: Colors.white),
              ),
              const SizedBox(height: 24),
              ...actions,
            ],
          ),
        ),
      ),
    ),
  );
}

class _RunView extends StatelessWidget {
  const _RunView({required this.game, required this.s, required this.onPause});
  final ForestGame game;
  final S s;
  final VoidCallback onPause;

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
                        IconButton(
                          tooltip: tr('Pause'),
                          iconSize: 36,
                          icon: const Icon(Icons.pause_circle_filled),
                          onPressed: onPause,
                        ),
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
    this.paused = false,
  });
  final String title;
  final List<Exercise> exercises;
  final Voice voice;

  /// While paused the countdown holds and nothing is spoken.
  final bool paused;
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
      if (!mounted || widget.paused) return;
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
