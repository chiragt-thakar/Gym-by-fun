import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_director/game_director.dart';
import 'package:go_router/go_router.dart';
import 'package:motion_core/motion_core.dart';

import '../l10n/tr.dart';

import '../game/forest_game.dart';
import '../game/stages.dart';
import '../game/stage_info.dart' show missionName;
import '../l10n/strings.dart';
import '../services/pose_service.dart';
import '../services/session_queue.dart';
import '../services/settings.dart';
import '../services/premium.dart';
import '../services/voice.dart';
import '../widgets/common.dart';
import '../widgets/frame_view.dart';
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
  const QuestScreen({
    super.key,
    this.tutorial = false,
    this.levelId,
    this.gentle = false,
  });
  final bool tutorial;

  /// A player-chosen, one-run override. Never rewrites saved preferences.
  final bool gentle;

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
  final _runTime = Stopwatch();
  Future<void>? _cameraStop;
  StreamSubscription<MotionEvent>? _menuSub;
  ReadyGate _readyGate = ReadyGate();
  bool _menuRaised = false;
  int _readyDisplay = -1;
  int _spokenCount = 0;
  final _clientId = SessionQueue.newClientId();
  String? _error;
  DeviceTier _tier = DeviceTier.mid;

  /// The run (or exercise flow) is paused: by the player, or by the app
  /// going to the background. Pausing never costs hearts or progress.
  bool _paused = false;

  /// A failed run past the checkpoint, waiting for the player's choice.
  RunResult? _checkpointOffer;
  bool _disposed = false;

  // Re-entrancy guards: a Skip double tap or Skip racing the timer must not
  // start the camera twice or finish the session twice.
  bool _runBegun = false;
  bool _completed = false;
  bool _resuming = false;
  bool _finishing = false;

  late final Voice _voice;

  // Framing guide: the latest smoothed frame + debounced advice, for the
  // in-game frame finder and edge glow. Display only; the run's pause and
  // resume timing stays in MotionEngine.
  static const _framing = Framing();
  final _framed = ValueNotifier<FramedView>(const FramedView(null, null));
  final _framingFilter = FramingFilter();
  final _smoother = LandmarkSmoother();
  StreamSubscription<PoseFrame>? _frameSub;
  FramingAdvice? _rawAdvice;
  FramingFix? _spokenFix;
  int _spokenAt = 0;
  bool _mirror = false;

  void _onFrame(PoseFrame f) {
    final ts = f.timestampMs;
    final raw = _framing.advise(f);
    _rawAdvice = raw;
    final shown = _framingFilter.update(raw, ts);
    _framed.value = FramedView(_smoother.smooth(f), shown);
    if ((_paused || _checkpointOffer != null) && _phase == _Phase.run) {
      final good =
          raw.ok &&
          const QualityGate().check(f).ok &&
          _session?.light == TrackingLight.green;
      if (!shown.ok && ts - _spokenAt >= 6000) {
        _spokenAt = ts;
        _voice.sayKey(framingKey(shown.fix), force: true);
      }
      final go = _readyGate.update(ts, good: good, raised: _menuRaised);
      final display =
          (_readyGate.progress * 10).floor() * 10 + _readyGate.countdown;
      if (display != _readyDisplay) {
        _readyDisplay = display;
        if (mounted) setState(() {});
      }
      if (_readyGate.confirmed &&
          !_menuRaised &&
          good &&
          _readyGate.countdown != _spokenCount) {
        _spokenCount = _readyGate.countdown;
        _voice.say('$_spokenCount', force: true);
      }
      if (!good || _menuRaised) _spokenCount = 0;
      if (go) {
        if (_checkpointOffer != null) _continueFromCheckpoint();
        if (_paused) {
          _resume();
        } else {
          _session?.collectStats = true;
          _runTime.start();
        }
      }
      return;
    }
    // While the run waits, repeat the direction when it changes or every 8 s.
    final waiting = _game?.hud.value.trackingIssue != null;
    if (waiting &&
        !shown.ok &&
        (shown.fix != _spokenFix || ts - _spokenAt >= 8000) &&
        ts - _spokenAt >= 2500) {
      _spokenFix = shown.fix;
      _spokenAt = ts;
      _voice.sayKey(framingKey(shown.fix), force: true);
    }
  }

  /// Spoken when the run pauses for tracking: the direction to move.
  String? _issueKey(TrackingIssue _) {
    final a = _rawAdvice;
    if (a == null || a.ok) return null;
    _spokenFix = a.fix;
    _spokenAt = _session?.lastFrame?.timestampMs ?? 0;
    return framingKey(a.fix);
  }

  @override
  void initState() {
    super.initState();
    _voice = ref.read(voiceProvider);
    WidgetsBinding.instance.addObserver(this);
    // Asset bundles and inherited presentation settings are available only
    // after initState. A route can legitimately supply its own asset bundle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prepare();
    });
  }

  Future<void> _prepare() async {
    final s = ref.read(settingsProvider);
    final cal = s.calibration;
    if (cal == null) {
      // The router's play gate normally catches this first.
      if (mounted) {
        context.go(
          Uri(
            path: '/get-ready',
            queryParameters: {'next': GoRouterState.of(context).uri.toString()},
          ).toString(),
        );
      }
      return;
    }
    final bundle = DefaultAssetBundle.of(context);
    try {
      await _voice.init(s.language);
      if (!mounted) return;
      _stage = widget.tutorial
          ? stages.first
          : (stageById(widget.levelId ?? forestEscapeId) ?? stages.first);
      final premium = PaywallPolicy.paymentsEnabled
          ? await ref.read(premiumProvider.future)
          : const PremiumState(premium: true);
      if (!mounted) return;
      if (!widget.tutorial &&
          !canPlayStage(
            _stage,
            s.completedLevels,
            premiumLocked: PaywallPolicy.paymentsEnabled && !premium.premium,
          )) {
        setState(
          () => _error = tr(
            'This stage is locked. Choose an available stage on the world map.',
          ),
        );
        return;
      }
      final level = widget.tutorial
          ? tutorialFrom(await loadForest(bundle))
          : LevelConfig.decode(await bundle.loadString(_stage.asset));
      if (!mounted) return;
      final runSettings = widget.tutorial || widget.gentle
          ? RunSettings(
              difficulty: Difficulty.beginner,
              lowImpact: widget.gentle || s.lowImpact,
              assist: true,
              warningMultiplier: widget.gentle ? 1.2 : s.warningMultiplier,
            )
          : s.runSettings;
      _tier = s.deviceTier ?? DeviceTier.mid;
      final session = MotionSession(
        ref.read(poseSourceProvider),
        initialCalibration: cal,
        thresholds: widget.gentle
            ? const MotionThresholds.lowImpact()
            : s.thresholds,
      );
      _session = session;
      _menuSub = session.events.listen((event) {
        if (!_paused && _checkpointOffer == null) return;
        if (event is MoveStarted && event.move == Move.raiseArms ||
            event is MoveHeld && event.move == Move.raiseArms) {
          _menuRaised = true;
        }
        if (event is MoveEnded && event.move == Move.raiseArms ||
            event is TrackingPaused) {
          _menuRaised = false;
        }
      });
      _game = ForestGame(
        engine: RunEngine(level, runSettings),
        motionEvents: session.events,
        audio: this,
        theme: _stage.theme,
        heroLook: s.heroLook,
        reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
        lightOf: () => session.light,
        issueKeyOf: _issueKey,
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
    await _cameraStop;
    if (!mounted || _disposed) return false;
    final session = _session;
    if (session == null) return false;
    bool ok;
    try {
      ok = await session.start(
        tier: _tier,
        selfView: ref.read(settingsProvider).cameraMirror,
      );
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
    _frameSub ??= session.frames.listen(_onFrame);
    if (_mirror != session.selfView) setState(() => _mirror = session.selfView);
    return true;
  }

  Future<void> _beginRun() async {
    if (_runBegun) return;
    _runBegun = true;
    setState(() => _phase = _Phase.loading);
    if (!await _startCamera()) return;
    _startedAt = DateTime.now();
    _runTime
      ..reset()
      ..start();
    setState(() => _phase = _Phase.run);
    // The app may have gone to the background while the camera was starting
    // (pause is ignored during loading): freeze the run straight away.
    final life = WidgetsBinding.instance.lifecycleState;
    if (life != null && life != AppLifecycleState.resumed) {
      _pause();
      _cameraStop = _session?.stop();
    }
  }

  void _onRunFinished(RunResult r) {
    if (!mounted) return;
    final game = _game;
    if (!r.completed &&
        !widget.tutorial &&
        game != null &&
        game.engine.atCheckpoint) {
      game.pauseEngine();
      _runTime.stop();
      _session?.collectStats = false;
      _resetReady();
      setState(() => _checkpointOffer = r);
      return;
    }
    _finishRun(r);
  }

  void _finishRun(RunResult? r) {
    // Double-tap or Finish + Continue in one frame: finish only once (Q2-9).
    if (r == null || _finishing) return;
    _finishing = true;
    _runTime.stop();
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
    // Paused while the offer was up: the camera is off, so leave the run
    // frozen behind the Paused overlay; Resume restarts camera and engine.
    if (_paused) return;
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
        _resetReady();
        if (_phase == _Phase.run) _cameraStop = _session?.stop();
      case AppLifecycleState.resumed:
        if (_paused && _phase == _Phase.run) _rearmCamera();
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Freezes gameplay and voice. Foreground tracking remains available for
  /// menu confirmation; lifecycle transitions stop the camera separately.
  void _pause() {
    if (_paused || _error != null || _phase == _Phase.loading) return;
    _paused = true;
    _runTime.stop();
    _resetReady();
    _voice.stop();
    if (_phase == _Phase.run) {
      final game = _game;
      if (game != null) {
        game.pauseEngine();
        // Treat the pause as a tracking loss so held moves clear and the
        // reaction window applies after resume (Q2-2, Q2-3, rule 5). The
        // engine's own hint output is dropped: the Paused overlay explains.
        game.engine.input(
          TrackingPaused(
            _session?.lastFrame?.timestampMs ?? 0,
            TrackingIssue.noPerson,
          ),
        );
      }
      _session?.collectStats = false;
      // On an explicit in-app pause the camera stays native and active for
      // menu confirmation. Lifecycle pauses above always stop the camera.
    }
    if (mounted) setState(() {});
  }

  void _resetReady() {
    _readyGate = ReadyGate();
    _menuRaised = false;
    _readyDisplay = -1;
    _spokenCount = 0;
  }

  Future<void> _rearmCamera() async {
    if (!await _startCamera()) return;
    final life = WidgetsBinding.instance.lifecycleState;
    if (life != null && life != AppLifecycleState.resumed) {
      _cameraStop = _session?.stop();
    }
  }

  void _requestReady() {
    if (_phase != _Phase.run) {
      _resume();
      return;
    }
    _readyGate.request();
    _rearmCamera();
    setState(() {});
  }

  Future<void> _retryCamera() async {
    setState(() => _error = null);
    _resetReady();
    if (_phase == _Phase.loading && _runBegun) {
      _runBegun = false;
      await _beginRun();
    } else {
      // Keep the existing engine/checkpoint while a camera owned by another
      // app becomes available again. Confirmation is still required.
      await _rearmCamera();
    }
  }

  Future<void> _resume() async {
    if (!_paused || _resuming) return;
    _resuming = true;
    try {
      if (_phase == _Phase.run) {
        if (!await _startCamera()) return;
        // The app went to the background while the camera was starting
        // (pause is ignored mid-resume): stay paused (Q2-4).
        final life = WidgetsBinding.instance.lifecycleState;
        if (life != null && life != AppLifecycleState.resumed) {
          await _session?.stop();
          return;
        }
        final game = _game;
        if (game != null) {
          game.engine.input(
            TrackingResumed(_session?.lastFrame?.timestampMs ?? 0),
          );
          // A pending checkpoint choice keeps the game frozen until answered.
          if (_checkpointOffer == null) game.resumeEngine();
        }
      }
      if (mounted) setState(() => _paused = false);
      if (_phase == _Phase.run) {
        _session?.collectStats = true;
        _runTime.start();
      }
    } finally {
      _resuming = false;
    }
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
    if (_completed) return;
    _completed = true;
    final r = _result;
    final session = _session;
    _session = null;
    final stats = _stats ?? session?.moveStats();
    await session?.dispose();
    if (r == null || !mounted) return;
    final s = ref.read(settingsProvider);
    final durationS = _runTime.elapsed.inSeconds.clamp(1, 3600);
    final data = ResultsData(
      result: r,
      levelId: _stage.levelId,
      clientId: _clientId,
      startedAt: _startedAt,
      durationS: durationS,
      moveStats: stats,
      tutorial: widget.tutorial,
      maxHearts: _game?.engine.level.hearts ?? 3,
      assist: _game?.engine.settings.assist ?? false,
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
            missionLevels: !widget.tutorial && r.completed && r.missionWon
                ? {...s.missionLevels, _stage.levelId}
                : null,
          ),
        );
    context.go('/results', extra: data);
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    final session = _session;
    _session = null;
    session?.dispose();
    // Drop the run (engine, plan, HUD notifier) with the screen so nothing
    // from it outlives the results screen.
    _game?.dispose();
    _game = null;
    _frameSub?.cancel();
    _menuSub?.cancel();
    _framed.dispose();
    _voice.stop();
    super.dispose();
  }

  // GameAudio
  @override
  void cue(String name) => _voice.cue(name);
  @override
  void say(String text) => _voice.say(tr(text));
  @override
  void sayKey(String key) => _voice.sayKey(key, force: true);

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ScreenScaffold(
        title: tr('Daily Quest'),
        children: [
          Text(_error!, style: const TextStyle(fontSize: 19)),
          if (_session != null) BigButton(tr('Retry'), onPressed: _retryCamera),
          BigButton(
            tr(_phase == _Phase.run ? 'Quit (this run is not saved)' : 'Back'),
            onPressed: _quit,
          ),
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
      _Phase.run => _RunView(
        game: _game!,
        s: s,
        onPause: _pause,
        framed: _framed,
        mirror: _mirror,
      ),
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
              detail: _readyHelp(),
              actions: [
                BigButton(
                  tr('Continue from checkpoint'),
                  onPressed: _requestReady,
                ),
                BigButton(
                  tr('Finish run'),
                  secondary: true,
                  onPressed: () => _finishRun(_checkpointOffer),
                ),
              ],
            )
          else if (_paused)
            _Overlay(
              title: tr('Paused'),
              text: _phase == _Phase.run
                  ? tr('Camera on for hands-free resume.')
                  : tr('Take your time.'),
              detail: _phase == _Phase.run ? _readyHelp() : null,
              actions: [
                BigButton(tr('Resume'), onPressed: _requestReady),
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

  Widget _readyHelp() => Column(
    children: [
      ValueListenableBuilder<FramedView>(
        valueListenable: _framed,
        builder: (context, v, _) => SizedBox(
          width: 72,
          height: 96,
          child: FrameView(
            frame: v.frame,
            advice: v.advice ?? const FramingAdvice(FramingFix.findMe),
            mirror: false,
            showCue: false,
            showTarget: true,
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        _readyGate.confirmed
            ? tr('Lower your arms. Stand in frame for the countdown.')
            : tr('Raise your arms and hold to continue. Then lower them.'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20),
      ),
      const SizedBox(height: 10),
      LinearProgressIndicator(value: _readyGate.progress, minHeight: 6),
      if (_readyGate.confirmed)
        Text(
          '${_readyGate.countdown}',
          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900),
        ),
    ],
  );
}

/// Full-screen modal card used for pause and checkpoint choices.
class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.title,
    required this.text,
    required this.actions,
    this.detail,
  });
  final String title;
  final String text;
  final List<Widget> actions;
  final Widget? detail;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Material(
      color: Colors.black87,
      child: SafeArea(
        child: SingleChildScrollView(
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
              if (detail != null) ...[detail!, const SizedBox(height: 16)],
              ...actions,
            ],
          ),
        ),
      ),
    ),
  );
}

/// The latest smoothed frame and debounced framing advice.
@immutable
class FramedView {
  const FramedView(this.frame, this.advice);
  final PoseFrame? frame;
  final FramingAdvice? advice;
}

class _RunView extends StatelessWidget {
  const _RunView({
    required this.game,
    required this.s,
    required this.onPause,
    required this.framed,
    required this.mirror,
  });
  final ForestGame game;
  final S s;
  final VoidCallback onPause;
  final ValueListenable<FramedView> framed;
  final bool mirror;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Keyed and built once per run: HUD changes rebuild only the
          // ValueListenableBuilder below, never the GameWidget.
          GameWidget(key: const ValueKey('forest-game'), game: game),
          // Early warning: the screen edge glows on the side the player is
          // drifting out of, before tracking is lost.
          ValueListenableBuilder<FramedView>(
            valueListenable: framed,
            builder: (context, v, _) => ScreenEdgeGlow(v.advice),
          ),
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
                            size: 30,
                          ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.bolt,
                          color: Colors.cyanAccent,
                          size: 20,
                        ),
                        Text(
                          '${h.energy}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        const SizedBox(width: 12),
                        TrackingDot(h.light, size: 28),
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
                    padding: EdgeInsets.fromLTRB(
                      12,
                      0,
                      (MediaQuery.sizeOf(context).width * 0.26)
                              .clamp(72.0, 140.0)
                              .toDouble() +
                          24,
                      10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${tr('Score')}  ${h.score}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(
                      left: 12,
                      right:
                          (MediaQuery.sizeOf(context).width * 0.26)
                              .clamp(72.0, 140.0)
                              .toDouble() +
                          24,
                    ),
                    child: LinearProgressIndicator(
                      value: h.progress,
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  if (h.missionKind != null)
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        12,
                        10,
                        (MediaQuery.sizeOf(context).width * 0.26)
                                .clamp(72.0, 140.0)
                                .toDouble() +
                            24,
                        0,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xE60B1611),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(
                                h.missionGoal == 0
                                    ? 'Mission protected'
                                    : missionName(h.missionKind!),
                              ),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: h.missionGoal == 0
                                        ? 0
                                        : (h.missionCount / h.missionGoal)
                                              .clamp(0, 1)
                                              .toDouble(),
                                    minHeight: 4,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (h.missionWon)
                                  const Icon(
                                    Icons.check_rounded,
                                    color: Color(0xFF3FD0C0),
                                    size: 18,
                                  )
                                else
                                  Text(
                                    '${h.missionCount.clamp(0, h.missionGoal)}/${h.missionGoal}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF3FD0C0),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const Spacer(),
                  if (h.feedback != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xEE0B1611),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFF3FD0C0)),
                          ),
                          child: Text(
                            '${tr(h.feedback!)}${h.combo >= 3 ? '  ·  ${tr('Flow')} ${h.combo}' : ''}',
                            style: const TextStyle(
                              color: Color(0xFFF6EEDC),
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  // A tracking pause is explained by the frame finder.
                  if (h.trackingIssue == null &&
                      (h.hint != null || h.action != null))
                    _Banner(
                      text: tr(switch (h.action) {
                        EncounterType.beam => 'Duck under',
                        EncounterType.laneBlock => 'Find a free lane',
                        EncounterType.orb => 'Reach for the light',
                        EncounterType.gate => 'Raise to open',
                        null => switch (h.segment) {
                          SegmentKind.practice => 'Practise your moves',
                          SegmentKind.breather => 'Breather time',
                          SegmentKind.combo => 'Flow section',
                          SegmentKind.checkpoint => 'Checkpoint reached',
                          SegmentKind.finale => 'Final stretch',
                          _ => 'Follow the trail',
                        },
                      }),
                      color: Colors.black54,
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          ValueListenableBuilder<HudState>(
            valueListenable: game.hud,
            builder: (context, h, _) => _FrameFinder(
              framed: framed,
              waiting: h.trackingIssue != null,
              fallbackIssue: h.trackingIssue,
              mirror: mirror,
              s: s,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the player where they are in the camera's view.
///
/// During play (mirror on) it is a small picture-in-picture under the HUD.
/// When tracking pauses it grows into a big 3:4 frame with the body
/// outline, red edges where the body is cut off, a direction arrow and one
/// plain line ("Move a little to your left"). When tracking is back it
/// shrinks again by itself; no tap is needed.
///
/// It is one widget at one place in the tree, so the native mirror is never
/// re-attached when it changes size.
class _FrameFinder extends StatelessWidget {
  const _FrameFinder({
    required this.framed,
    required this.waiting,
    required this.fallbackIssue,
    required this.mirror,
    required this.s,
  });
  final ValueListenable<FramedView> framed;
  final bool waiting;
  final TrackingIssue? fallbackIssue;
  final bool mirror;
  final S s;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth, h = c.maxHeight;
        final bigW = (w - 48).clamp(120.0, (h * 0.56) * 3 / 4).toDouble();
        final smallW = (w * 0.26).clamp(72.0, 140.0).toDouble();
        final fw = waiting ? bigW : smallW;
        final left = waiting ? (w - bigW) / 2 : w - smallW - 12;
        final top = waiting ? h * 0.15 : pad.top + 72;
        final duration = MediaQuery.maybeDisableAnimationsOf(context) == true
            ? Duration.zero
            : const Duration(milliseconds: 350);
        // With the mirror off, retain the landmark-only avatar as body feedback.
        const visible = true;
        return Stack(
          children: [
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: waiting ? 1 : 0,
                duration: duration,
                child: const ColoredBox(
                  color: Color(0xB3000000),
                  child: SizedBox.expand(),
                ),
              ),
            ),
            if (visible)
              AnimatedPositioned(
                duration: duration,
                curve: Curves.easeOutCubic,
                left: left,
                top: top,
                width: fw,
                height: fw * 4 / 3,
                child: IgnorePointer(
                  child: ValueListenableBuilder<FramedView>(
                    valueListenable: framed,
                    builder: (context, v, _) => FrameView(
                      frame: v.frame,
                      advice:
                          v.advice ?? const FramingAdvice(FramingFix.findMe),
                      mirror: mirror,
                      showCue: waiting,
                      showTarget: waiting,
                      radius: waiting ? 24 : 14,
                    ),
                  ),
                ),
              ),
            if (waiting)
              Positioned(
                left: 16,
                right: 16,
                top: top + bigW * 4 / 3 + 12,
                child: ValueListenableBuilder<FramedView>(
                  valueListenable: framed,
                  builder: (context, v, _) {
                    final a = v.advice;
                    final line = a == null || a.ok
                        ? (a?.ok ?? false)
                              ? tr('Back in the frame!')
                              : s.t(ForestGame.issueKey(fallbackIssue!))
                        : s.t(framingKey(a.fix));
                    return Column(
                      children: [
                        Text(
                          line,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tr('The game waits for you.'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        );
      },
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
        fontSize: 24,
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
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _begin(0);
  }

  void _begin(int i) {
    if (_done) return;
    if (i >= widget.exercises.length) {
      _done = true;
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
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (box.maxHeight - 48)
                    .clamp(0.0, double.infinity)
                    .toDouble(),
              ),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
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
          ),
        ),
      ),
    );
  }
}
