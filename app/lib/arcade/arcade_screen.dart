import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_director/game_director.dart';
import 'package:go_router/go_router.dart';
import 'package:motion_core/motion_core.dart';
import 'package:pose_bridge/pose_bridge.dart';

import '../app/theme.dart';
import '../l10n/tr.dart';
import '../services/pose_service.dart';
import '../services/settings.dart';
import '../services/voice.dart';
import '../widgets/common.dart';
import '../widgets/frame_view.dart';
import '../widgets/tracking_overlay.dart';
import 'art/cricket_art.dart';
import 'art/duel_art.dart';
import 'art/looks.dart';
import 'art/lumen_art.dart';
import 'art/mela_art.dart';
import 'art/paint_kit.dart';
import 'art/pataka_art.dart';
import 'art/slice_art.dart';
import 'art/taal_art.dart';
import 'catalog.dart';
import 'content.dart';
import 'progress.dart';

/// What the player chose on the game page.
class ArcadeArgs {
  const ArcadeArgs({
    required this.gameId,
    required this.stageId,
    this.difficulty,
    this.assist,
    this.players = const [],
    this.noSquat = false,
    this.level,
    this.daily = false,
  });
  final String gameId;
  final String stageId;
  final String? difficulty;
  final bool? assist;
  final List<String> players;
  final bool noSquat;
  final String? level;
  final bool daily;

  Uri toUri() => Uri(
    path: '/play/$gameId',
    queryParameters: {
      'stage': stageId,
      'd': ?difficulty,
      if (assist != null) 'assist': assist! ? '1' : '0',
      if (players.isNotEmpty) 'players': players.join(','),
      if (noSquat) 'nosquat': '1',
      'level': ?level,
      if (daily) 'daily': '1',
    },
  );

  factory ArcadeArgs.fromUri(String gameId, Uri uri) {
    final q = uri.queryParameters;
    return ArcadeArgs(
      gameId: gameId,
      stageId: q['stage'] ?? '',
      difficulty: q['d'],
      assist: q['assist'] == null ? null : q['assist'] == '1',
      players: [
        for (final p in (q['players'] ?? '').split(','))
          if (p.trim().isNotEmpty) p.trim(),
      ],
      noSquat: q['nosquat'] == '1',
      level: q['level'],
      daily: q['daily'] == '1',
    );
  }
}

/// Builds the rule engine for a game from bundled content.
ArcadeEngine buildEngine(ArcadeContent c, ArcadeArgs a, Settings s) {
  final difficulty = a.difficulty ?? s.difficulty.name;
  final assist = a.assist ?? s.assist;
  final daily = a.daily ? dailySeed(DateTime.now().toUtc()) : null;
  switch (a.gameId) {
    case 'mirror-mela':
      final st = c.mela.firstWhere(
        (m) => m.id == a.stageId,
        orElse: () => c.mela.first,
      );
      return MelaEngine(st.variant(seed: daily, assist: assist));
    case 'pataka-pose':
      final st = c.patakaStages.firstWhere(
        (p) => p.id == a.stageId,
        orElse: () => c.patakaStages.first,
      );
      return PatakaEngine(
        stage: st,
        library: c.poses,
        band: assist ? PatakaBand.chai : null,
        players: a.players.length > 1 ? a.players : const ['You'],
        framesPerTurn: 4,
      );
    case 'craftguard':
      final g = c.guardians.firstWhere(
        (g) => g.id == a.stageId,
        orElse: () => c.guardians.first,
      );
      return DuelEngine(
        g,
        difficulty: difficulty,
        lowImpact: s.lowImpact,
        assist: assist,
      );
    case 'taal-toofan':
      final song = c.songs.firstWhere(
        (x) => x.id == a.stageId,
        orElse: () => c.songs.first,
      );
      return TaalEngine(
        song,
        level:
            a.level ??
            switch (difficulty) {
              'advanced' => 'toofan',
              'intermediate' => 'groove',
              _ => 'light',
            },
        lowImpact: s.lowImpact,
      );
    case 'tapeball':
      final f = c.formats.firstWhere(
        (x) => x.id == a.stageId,
        orElse: () => c.formats.first,
      );
      final format = CricketFormat(
        id: f.id,
        name: f.name,
        balls: f.balls,
        wickets: f.wickets,
        target: f.target,
        seed:
            daily ??
            (c.dailyFormats.contains(f.id)
                ? dailySeed(DateTime.now().toUtc(), salt: 3)
                : f.seed),
        wideShare: f.wideShare,
        blurb: f.blurb,
      );
      return CricketEngine(
        format,
        c.outcomes,
        difficulty: assist ? 'beginner' : difficulty,
        lowImpact: s.lowImpact,
      );
    case 'neon-slice':
      final st = c.slice.firstWhere(
        (x) => x.id == a.stageId,
        orElse: () => c.slice.first,
      );
      return SliceEngine(st.variant(seed: daily, assist: assist));
    default:
      final st = c.lumen.firstWhere(
        (x) => x.id == a.stageId,
        orElse: () => c.lumen.first,
      );
      return LumenEngine(st, noSquat: a.noSquat);
  }
}

String stageNameOf(ArcadeContent c, String gameId, String stageId) {
  for (final s in c.stagesFor(gameId)) {
    if (s.id == stageId) return s.name;
  }
  return '';
}

/// Passed to the results page.
class ArcadeResult {
  const ArcadeResult({
    required this.args,
    required this.summary,
    required this.stageName,
    required this.previousBest,
    this.nextStage,
  });
  final ArcadeArgs args;
  final ArcadeSummary summary;
  final String stageName;
  final int previousBest;
  final ArcadeStage? nextStage;
}

enum _Phase { loading, framing, countdown, play }

class _Fx {
  _Fx(
    this.at,
    this.text,
    this.color,
    this.born, {
    this.burst = false,
    this.big = false,
  });
  final Offset at;
  final String text;
  final Color color;
  final int born;

  /// Sparks and a shock ring as well as the text.
  final bool burst;

  /// A headline moment (a bonus, a six): larger, with a glow.
  final bool big;
}

class ArcadeScreen extends ConsumerStatefulWidget {
  const ArcadeScreen({super.key, required this.args});
  final ArcadeArgs args;
  @override
  ConsumerState<ArcadeScreen> createState() => _ArcadeScreenState();
}

class _ArcadeScreenState extends ConsumerState<ArcadeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  _Phase _phase = _Phase.loading;
  late final GameInfo _game = gameById(widget.args.gameId) ?? games.first;
  late final Voice _voice;
  late final Ticker _ticker;
  final _repaint = ValueNotifier<int>(0);
  ArcadeEngine? _engine;
  ArcadeContent? _content;
  MotionSession? _session;
  StreamSubscription<TrackedFrame>? _frameSub;
  StreamSubscription<MotionEvent>? _eventSub;
  final _anchor = BodyAnchor();
  final _framingFilter = FramingFilter();
  static const _framing = Framing();
  PoseFrame? _frame;
  BodyPose? _pose;
  FramingAdvice _advice = const FramingAdvice(FramingFix.findMe);
  Duration _last = Duration.zero;
  int _now = 0;
  int _framedFor = 0;
  int _usableFor = 0;
  int _countdownLeft = 0;
  bool _paused = false;
  bool _mirror = false;
  bool _finishing = false;
  bool _disposed = false;
  String? _error;
  String? _caption;
  int _captionUntil = 0;
  final List<_Fx> _fx = [];
  final Set<String> _restoredModules = {};
  ReadyGate _ready = ReadyGate();
  bool _raised = false;
  int _lastHoldSpeech = -100000;

  @override
  void initState() {
    super.initState();
    _voice = ref.read(voiceProvider);
    _ticker = createTicker(_onTick);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _prepare();
    });
  }

  Future<void> _prepare() async {
    final s = ref.read(settingsProvider);
    final cal = s.calibration;
    if (cal == null) {
      context.go(
        Uri(
          path: '/get-ready',
          queryParameters: {'next': widget.args.toUri().toString()},
        ).toString(),
      );
      return;
    }
    try {
      await _voice.init(s.language);
      final content = await ref.read(arcadeContentProvider.future);
      if (!mounted) return;
      _content = content;
      _engine = buildEngine(content, widget.args, s);
      final session = MotionSession(
        ref.read(poseSourceProvider),
        initialCalibration: cal,
        thresholds: s.thresholds,
      );
      _session = session;
      session.cameraLost.addListener(_onCameraLost);
      _eventSub = session.events.listen(_onMotion);
      final ok = await session.start(
        tier: s.deviceTier ?? DeviceTier.mid,
        selfView: s.cameraMirror,
        multiPerson: s.multiPerson,
      );
      if (!mounted || _disposed) {
        await session.dispose();
        return;
      }
      if (!ok) {
        setState(() => _error = tr('Camera permission is needed to play.'));
        return;
      }
      _mirror = session.selfView;
      _frameSub = session.tracked.listen(_onFrame);
      setState(() => _phase = _Phase.framing);
      _say('Step back until your whole body glows in the frame.');
      _ticker.start();
    } on PlatformException catch (e) {
      debugPrint('arcade camera: ${e.code}');
      if (mounted) {
        setState(
          () => _error = e.code == 'no_permission'
              ? tr('Camera permission is needed to play.')
              : tr('The camera could not start. Please try again.'),
        );
      }
    } catch (e) {
      debugPrint('arcade prepare failed: $e');
      if (mounted) setState(() => _error = tr('Something went wrong.'));
    }
  }

  /// The camera stopped and could not be restarted: say so, keep nothing
  /// running, and let the player go back.
  void _onCameraLost() {
    final session = _session;
    if (session == null || !session.cameraLost.value || !mounted) return;
    _ticker.stop();
    session.stop();
    setState(
      () => _error = tr(
        'The camera stopped. Close any other app that is using it, then try again.',
      ),
    );
  }

  void _onMotion(MotionEvent e) {
    if ((e is TrackingPaused || e is TrackingResumed) &&
        ref.read(settingsProvider).haptics) {
      HapticFeedback.mediumImpact();
    }
    if (e is MoveStarted && e.move == Move.raiseArms ||
        e is MoveHeld && e.move == Move.raiseArms) {
      _raised = true;
    }
    if (e is MoveEnded && e.move == Move.raiseArms || e is TrackingPaused) {
      _raised = false;
    }
    if (_phase == _Phase.play && !_paused) _engine?.motion(e);
  }

  /// One tracked frame. Play runs on any frame whose torso is tracked
  /// (the tracker has already locked onto the player and bridged gaps); a
  /// hidden foot or knee no longer stops a game that does not need it.
  void _onFrame(TrackedFrame t) {
    final f = t.frame;
    _frame = f;
    final raw = _framing.advise(t.raw, t.quality);
    final shown = _framingFilter.update(raw, t.timestampMs);
    // Before play the full advice helps the player frame themselves; once
    // playing, only what matters is shown.
    _advice = _phase == _Phase.play
        ? playAdvice(shown, usable: t.playable)
        : shown;
    final good = t.playable;
    if (good) {
      _anchor.update(f);
      _pose = BodyPose.from(f, anchor: _anchor);
    } else {
      _pose = null;
    }
    if (_paused) {
      final go = _ready.update(t.timestampMs, good: good, raised: _raised);
      if (go) _resume();
      return;
    }
    if (_phase == _Phase.play && good) _engine?.pose(_pose!);
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMilliseconds.clamp(0, 100);
    _last = elapsed;
    _now = elapsed.inMilliseconds;
    if (_paused) return;
    switch (_phase) {
      case _Phase.framing:
        // A clean full-body view starts quickly. A player whose feet will
        // not fit (a small room) still starts, after a longer steady spell.
        final ok = _advice.ok && _pose != null;
        _framedFor = ok ? _framedFor + dt : 0;
        _usableFor = _pose != null ? _usableFor + dt : 0;
        if (_framedFor >= 1200 || _usableFor >= 4000) _startCountdown();
      case _Phase.countdown:
        final before = (_countdownLeft / 1000).ceil();
        _countdownLeft -= dt;
        final after = (_countdownLeft / 1000).ceil();
        if (after != before && after > 0) _voice.cue('a_count');
        if (_countdownLeft <= 0) {
          setState(() => _phase = _Phase.play);
          _voice.cue('a_bell');
        }
      case _Phase.play:
        final e = _engine!;
        final tracked =
            (_session?.light ?? TrackingLight.red) != TrackingLight.red;
        e.advance(dt, tracked: tracked);
        _handle(e.drainEvents());
        if (e.finished) _finish();
      case _Phase.loading:
        break;
    }
    _fx.removeWhere((f) => _now - f.born > 1100);
    _repaint.value++;
  }

  void _startCountdown() {
    setState(() {
      _phase = _Phase.countdown;
      _countdownLeft = 3000;
    });
    _voice.cue('a_count');
    _say('Ready? Three, two, one.');
  }

  // ---------------------------------------------------------------- events

  Offset _screenOf(double x, double y) {
    final size = MediaQuery.sizeOf(context);
    final vp = _viewport(size);
    final p = _pose;
    final m = p != null ? BodyMap.fromPose(p, vp) : BodyMap.demo(vp);
    return m(x, y);
  }

  void _fxAt(
    double x,
    double y,
    String text,
    Color color, {
    bool burst = false,
    bool big = false,
  }) => _fx.add(
    _Fx(_screenOf(x, y), text, color, _now, burst: burst, big: big),
  );

  void _captionLine(String? text, {int ms = 2600}) {
    if (text == null) return;
    _caption = tr(text);
    _captionUntil = _now + ms;
  }

  void _say(String text) => _voice.say(tr(text), force: true);

  Color _gradeColor(Grade? g) => switch (g) {
    Grade.perfect => const Color(0xFF9BCB3C),
    Grade.good => Lantern.scarf,
    Grade.ok => Lantern.warning,
    _ => Lantern.fog,
  };

  void _handle(List<ArcadeEvent> events) {
    for (final ev in events) {
      switch (ev.kind) {
        case 'hold':
          _voice.cue('tracking');
          if (_now - _lastHoldSpeech > 6000) {
            _lastHoldSpeech = _now;
            _say('I lost you for a moment. Step back into the frame.');
          }
          _captionLine('Tracking paused. Nothing is lost.', ms: 100000);
          continue;
        case 'resume':
          _caption = null;
          continue;
      }
      switch (widget.args.gameId) {
        case 'mirror-mela':
          _melaEvent(ev);
        case 'pataka-pose':
          _patakaEvent(ev);
        case 'craftguard':
          _duelEvent(ev);
        case 'taal-toofan':
          _taalEvent(ev);
        case 'tapeball':
          _cricketEvent(ev);
        case 'lumen':
          _lumenEvent(ev);
        case 'neon-slice':
          _sliceEvent(ev);
      }
    }
  }

  void _sliceEvent(ArcadeEvent ev) {
    switch (ev.kind) {
      case 'launch':
        _voice.cue('a_whoosh');
      case 'slice':
        _voice.cue('a_pop${ev.value % 5}');
        _fxAt(
          ev.x,
          ev.y,
          '+${ev.points}',
          ev.grade == Grade.perfect ? sliceColour(ev.value) : Lantern.parchment,
          burst: ev.grade == Grade.perfect,
        );
      case 'multi':
        _voice.cue('a_chime');
        _fxAt(
          ev.x,
          ev.y + 0.5,
          '${ev.value} IN ONE  +${ev.points}',
          Lantern.glow,
          burst: true,
          big: true,
        );
      case 'bomb':
        _voice.cue('a_thud');
        if (ref.read(settingsProvider).haptics) HapticFeedback.heavyImpact();
        _fxAt(ev.x, ev.y, '${ev.points}', Lantern.danger, burst: true);
        _say(ev.text!);
        _captionLine(ev.text);
      case 'frenzy':
        _voice.cue('a_bell');
        _say('Neon Frenzy!');
        _captionLine('Neon Frenzy! Points ×1.5 for six seconds.');
      case 'phase':
        _voice.cue('a_drum');
        _captionLine(ev.text, ms: 1800);
    }
  }

  void _melaEvent(ArcadeEvent ev) {
    switch (ev.kind) {
      case 'pop':
        _voice.cue('a_pop${ev.value % 5}');
        _fxAt(
          ev.x,
          ev.y,
          '${ev.grade!.label} +${ev.points}',
          _gradeColor(ev.grade),
          burst: ev.grade == Grade.perfect,
        );
      case 'dodge':
        _voice.cue('a_whoosh');
        _fxAt(0, 0.6, 'Dodged +${ev.points}', Lantern.scarf);
      case 'hit':
        _voice.cue('a_thud');
        _captionLine(ev.text);
      case 'rush':
        _voice.cue('a_bell');
        _say('Mela Rush!');
        _captionLine('Mela Rush! Points ×1.5 for eight seconds.');
      case 'shields':
        _captionLine('Shields restored.');
    }
  }

  void _patakaEvent(ArcadeEvent ev) {
    switch (ev.kind) {
      case 'call':
        _say(ev.text!);
        _captionLine(ev.text, ms: 3500);
      case 'lock':
        _voice.cue('a_select');
      case 'burst':
        _voice.cue('a_burst');
        _fxAt(0, 0.4, '+${ev.points}', const Color(0xFFFFB627), burst: true);
        if (ev.value == 3) _say(ev.text!);
        _captionLine(ev.text);
      case 'pass' || 'miss':
        if (ev.text != null) {
          _say(ev.text!);
          _captionLine(ev.text);
        }
      case 'passTurn':
        _voice.cue('a_bell');
        _say(ev.text!);
        _captionLine(ev.text, ms: 5000);
      case 'adjusted':
        _captionLine(ev.text);
      case 'hover':
        if (_now > _captionUntil) {
          _captionLine('Step back a little so I can see the whole shape.');
        }
    }
  }

  void _duelEvent(ArcadeEvent ev) {
    switch (ev.kind) {
      case 'beat':
        _voice.cue('a_tick');
      case 'call' || 'regroup' || 'phase' || 'stagger' || 'opening':
        if (ev.kind == 'stagger') _voice.cue('a_bell');
        _say(ev.text!);
        _captionLine(ev.text);
      case 'telegraph':
        _say(ev.text!);
        _captionLine(ev.text, ms: 3000);
      case 'count':
        _voice.cue('a_count');
      case 'impact':
        _voice.cue('a_whoosh');
      case 'answer':
        _voice.cue('a_drum');
        _fxAt(
          0,
          0.9,
          ev.grade!.label,
          _gradeColor(ev.grade),
          burst: ev.grade == Grade.perfect,
        );
      case 'strike':
        _voice.cue(ev.value == DuelMove.charge.index ? 'a_bell' : 'a_clap');
        final x = ev.side == BodySide.left
            ? -1.15
            : (ev.side == BodySide.right ? 1.15 : 0.0);
        _fxAt(
          x,
          ev.side == null ? 1.6 : 0.05,
          '+${ev.points}',
          duelColor,
          burst: true,
        );
      case 'hit':
        _voice.cue('a_thud');
        _say(ev.text!);
        _captionLine(ev.text);
      case 'calmed':
        _voice.cue('a_chime');
        _say(ev.text!);
        _captionLine(ev.text, ms: 5000);
    }
  }

  static const duelColor = Color(0xFFE8B04A);

  int _lastCalledSection = -1;

  void _taalEvent(ArcadeEvent ev) {
    final e = _engine as TaalEngine;
    switch (ev.kind) {
      case 'beat':
        final b = ev.value % 8;
        _voice.cue(b == 0 || b == 4 ? 'a_drum' : 'a_tick');
        if (e.stems.contains('claps') && (b == 2 || b == 6)) {
          _voice.cue('a_clap');
        }
        if (e.stems.contains('melody') && b.isOdd) _voice.cue('a_shaker');
      case 'countIn':
        _voice.cue('a_count');
        _captionLine('${ev.value}', ms: 600);
      case 'call':
        _captionLine(ev.text, ms: 900);
        if (e.section != _lastCalledSection) {
          _lastCalledSection = e.section;
          _say(ev.text!);
        }
      case 'hit':
        _voice.cue(ev.grade == Grade.perfect ? 'a_pop2' : 'a_pop0');
        final (x, y) = taalZone(TaalMove.values[ev.value]);
        _fxAt(
          x,
          y,
          ev.grade!.label,
          _gradeColor(ev.grade),
          burst: ev.grade == Grade.perfect,
        );
        if (ev.text != null) _captionLine(ev.text);
      case 'toofanCall':
        _say(ev.text!);
        _captionLine(ev.text);
      case 'toofan':
        _voice.cue('a_bell');
        _captionLine('Toofan Time! Double points.');
    }
  }

  void _cricketEvent(ArcadeEvent ev) {
    switch (ev.kind) {
      case 'runup':
        _voice.cue('a_whoosh');
      case 'shot':
        _voice.cue(ev.value >= 4 ? 'a_burst' : 'a_bat');
        _fxAt(
          0,
          1.6,
          ev.value == 0 ? 'Dot' : '+${ev.value}',
          ev.value >= 4 ? const Color(0xFFFFD23F) : Lantern.scarf,
          burst: ev.value >= 4,
        );
        if (ev.text != null) {
          _say(ev.text!);
          _captionLine(ev.text);
        }
      case 'wicket' || 'dot' || 'deadBall' || 'over' || 'early':
        if (ev.kind == 'wicket') _voice.cue('a_thud');
        if (ev.text != null) {
          if (ev.kind != 'early') _say(ev.text!);
          _captionLine(ev.text);
        }
    }
  }

  void _lumenEvent(ArcadeEvent ev) {
    final e = _engine as LumenEngine;
    switch (ev.kind) {
      case 'board':
        _say('Repair: ${ev.text}');
        _captionLine('Repair: ${ev.text}', ms: 3000);
      case 'select':
        _voice.cue('a_select');
        _captionLine(
          'Conduit ${ev.value} selected. Lean right to turn it clockwise, left to turn it back.',
        );
      case 'turn':
        _voice.cue('a_rotate');
      case 'connected':
        _voice.cue('a_chime');
        _say(ev.text!);
        _captionLine(ev.text, ms: 4000);
      case 'broken':
        _captionLine('The route broke. Keep turning; nothing is lost.');
      case 'weldReady':
        _captionLine(
          e.noSquat
              ? 'Hold your hands together to weld.'
              : 'Now a comfortable bend to weld.',
        );
      case 'weld':
        _voice.cue('a_weld');
        _say(ev.text!);
        _captionLine(ev.text, ms: 3500);
      case 'restored':
        _voice.cue('a_chime');
        final board = e.stage.boards[ev.value];
        _restoredModules.add('${e.stage.habitat}/${board.module}');
      case 'rest':
        _say(ev.text!);
        _captionLine(ev.text, ms: 100000);
    }
  }

  // --------------------------------------------------------------- flow

  Future<void> _finish({bool early = false}) async {
    if (_finishing) return;
    _finishing = true;
    _ticker.stop();
    final e = _engine;
    final c = _content;
    final session = _session;
    _session = null;
    await _frameSub?.cancel();
    await _eventSub?.cancel();
    _frameSub = null;
    _eventSub = null;
    // Stop the camera now; tear the session down without blocking the page.
    await session?.stop();
    unawaited(session?.dispose());
    if (e == null || c == null || !mounted) return;
    final summary = e.summary;
    final progress = ref.read(arcadeProgressProvider);
    final previousBest = progress
        .record(summary.gameId, summary.stageId)
        .bestScore;
    final stages = c.stagesFor(widget.args.gameId);
    final i = stages.indexWhere((s) => s.id == widget.args.stageId);
    if (summary.activeMs > 5000 || summary.completed) {
      ref
          .read(arcadeProgressProvider.notifier)
          .record(summary, habitat: _restoredModules);
    }
    if (!mounted) return;
    if (early && summary.activeMs <= 5000) {
      context.pop();
      return;
    }
    context.pushReplacement(
      '/arcade-results',
      extra: ArcadeResult(
        args: widget.args,
        summary: summary,
        stageName: stageNameOf(c, widget.args.gameId, widget.args.stageId),
        previousBest: previousBest,
        nextStage: i >= 0 && i + 1 < stages.length ? stages[i + 1] : null,
      ),
    );
  }

  void _pause() {
    if (_paused || _phase == _Phase.loading) return;
    setState(() {
      _paused = true;
      _ready = ReadyGate();
    });
    _voice.stop();
  }

  void _resume() {
    if (!_paused) return;
    setState(() => _paused = false);
    _last = Duration.zero;
    if (!_ticker.isActive) _ticker.start();
    if (_engine != null && _phase == _Phase.play) {
      // Treat the pause like a tracking loss so held moves clear (rule 5).
      _engine!.motion(
        TrackingPaused(_frame?.timestampMs ?? 0, TrackingIssue.noPerson),
      );
      _engine!.advance(0, tracked: false);
    }
  }

  Future<void> _resumeTapped() async {
    final session = _session;
    if (session != null && !session.running) {
      final s = ref.read(settingsProvider);
      final ok = await session.start(
        tier: s.deviceTier ?? DeviceTier.mid,
        selfView: s.cameraMirror,
        multiPerson: s.multiPerson,
      );
      if (!ok || !mounted) return;
    }
    _ticker.stop();
    _last = Duration.zero;
    _resume();
  }

  Future<void> _quit() async {
    if (_phase == _Phase.play && (_engine?.clockMs ?? 0) > 5000) {
      await _finish(early: true);
      return;
    }
    _ticker.stop();
    final session = _session;
    _session = null;
    _voice.stop();
    await _frameSub?.cancel();
    await _eventSub?.cancel();
    _frameSub = null;
    _eventSub = null;
    await session?.stop();
    unawaited(session?.dispose());
    if (mounted) context.canPop() ? context.pop() : context.go('/games');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive ||
          AppLifecycleState.hidden ||
          AppLifecycleState.paused:
        _pause();
        _session?.stop();
      case AppLifecycleState.resumed:
        final session = _session;
        if (session != null && !session.running && _phase != _Phase.loading) {
          final s = ref.read(settingsProvider);
          session.start(
            tier: s.deviceTier ?? DeviceTier.mid,
            selfView: s.cameraMirror,
            multiPerson: s.multiPerson,
          );
        }
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _frameSub?.cancel();
    _eventSub?.cancel();
    final session = _session;
    _session = null;
    session?.dispose();
    _voice.stop();
    _repaint.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------- layout

  Rect _viewport(Size size) => viewportFor(
    size,
    topShare: switch (widget.args.gameId) {
      'craftguard' || 'tapeball' => 0.78,
      'lumen' => 0.96,
      'mirror-mela' => 0.5,
      _ => 0.62,
    },
  );

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ScreenScaffold(
        title: tr(_game.title),
        children: [
          StateView(
            icon: Icons.videocam_off_rounded,
            title: _error!,
            actions: [BigButton(tr('Back'), onPressed: _quit)],
          ),
        ],
      );
    }
    final s = ref.watch(settingsProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_phase == _Phase.loading) {
          _quit();
        } else if (_paused) {
          _quit();
        } else {
          _pause();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: LayoutBuilder(
            builder: (context, box) {
              final size = box.biggest;
              final vp = _viewport(size);
              return Stack(
                fit: StackFit.expand,
                children: [
                  RepaintBoundary(
                    child: CustomPaint(painter: _Backdrop(this, _repaint)),
                  ),
                  if (_mirror)
                    Positioned.fromRect(
                      rect: vp,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const PoseMirror(),
                            ColoredBox(
                              color: Colors.black.withValues(alpha: 0.28),
                            ),
                          ],
                        ),
                      ),
                    ),
                  RepaintBoundary(
                    child: CustomPaint(
                      painter: _Play(
                        this,
                        _repaint,
                        mirror: _mirror,
                        heroAccent: _game.accent,
                      ),
                    ),
                  ),
                  SafeArea(child: _hud(context, s)),
                  if (_phase == _Phase.loading) const BrandLoader(),
                  if (_phase == _Phase.framing) _framingCard(context),
                  if (_paused) _pauseOverlay(context),
                  if (s.diagnostics)
                    if (_session case final session?)
                      Positioned(
                        left: 8,
                        right: 8,
                        bottom: 84,
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: TrackingDiagnostics(session: session),
                        ),
                      ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _hud(BuildContext context, Settings s) {
    final e = _engine;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 12, 0),
          child: Row(
            children: [
              IconButton.filledTonal(
                tooltip: tr('Pause'),
                onPressed: _phase == _Phase.loading ? null : _pause,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xCC0A0C10),
                ),
                icon: const Icon(Icons.pause_rounded, color: Lantern.parchment),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ValueListenableBuilder<int>(
                  valueListenable: _repaint,
                  builder: (context, _, _) => _scorePlate(e),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<int>(
                valueListenable: _repaint,
                builder: (context, _, _) =>
                    TrackingDot(_session?.light ?? TrackingLight.red, size: 22),
              ),
            ],
          ),
        ),
        const Spacer(),
        ValueListenableBuilder<int>(
          valueListenable: _repaint,
          builder: (context, _, _) {
            final text = _now < _captionUntil ? _caption : _stateHint();
            if (text == null) return const SizedBox(height: 12);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xD90A0C10),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _game.accent.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Lantern.parchment,
                    height: 1.25,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String? _stateHint() {
    final e = _engine;
    if (_phase != _Phase.play || e == null) return null;
    if (e is LumenEngine) {
      return switch (e.state) {
        'inspect' => tr('Reach to a numbered card and hold.'),
        'edit' => tr(
          'Lean to turn conduit ${e.selected}. Reach another card to switch.',
        ),
        'ready' => tr(
          e.weldArmed
              ? (e.noSquat
                    ? 'Hold your hands together to weld.'
                    : 'A comfortable bend welds the route.')
              : 'Connected! Lower your arms.',
        ),
        _ => null,
      };
    }
    if (e is PatakaEngine && e.phase == 'show' && e.frame?.pose != null) {
      return e.frame!.pose!.name;
    }
    if (e is SliceEngine && e.stunned) return tr('Blades recharging…');
    return null;
  }

  Widget _scorePlate(ArcadeEngine? e) {
    final (label, value, extra) = switch (e) {
      MelaEngine m => (
        'SCORE',
        '${m.score}',
        m.combo > 1 ? '×${m.combo} combo' : null,
      ),
      PatakaEngine p => (
        p.players.length > 1 ? p.players[p.player].toUpperCase() : 'SCORE',
        '${p.score}',
        'Frame ${math.min(p.current + 1, p.frames.length)}/${p.frames.length}',
      ),
      DuelEngine d => (
        'SPARKS ${'◆' * d.sparks}${'◇' * (3 - d.sparks)}',
        '${d.score}',
        d.combo > 1 ? '×${d.combo}' : null,
      ),
      TaalEngine t => (
        '${(t.accuracy * 100).round()}%',
        '${t.score}',
        t.combo > 1 ? '×${t.multiplier} · ${t.combo}' : null,
      ),
      CricketEngine c => (
        c.format.target != null
            ? 'NEED ${math.max(0, c.format.target! - c.runs)}'
            : 'RUNS',
        c.format.wickets > 0 ? '${c.runs}/${c.wickets}' : '${c.runs}',
        '${c.ballsLeft} balls left',
      ),
      SliceEngine n => (
        const ['WARM-UP', 'HEAT', 'OVERDRIVE'][n.phase],
        '${n.score}',
        n.combo > 1 ? '×${n.combo} combo' : null,
      ),
      LumenEngine l => (
        'REPAIR ${math.min(l.boardIndex + 1, l.stage.boards.length)}/${l.stage.boards.length}',
        l.board.title,
        null,
      ),
      _ => ('', '', null),
    };
    final progress = e == null || e.durationMs == 0
        ? null
        : (e.clockMs / e.durationMs).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xCC0A0C10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Lantern.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: _game.accent,
                  ),
                ),
              ),
              if (extra != null)
                Text(
                  extra,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Lantern.fog,
                  ),
                ),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Lantern.parchment,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                color: _game.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _framingCard(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.55,
          ),
          child: AppCard(
            color: const Color(0xEE0A0C10),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        framingIcon(_advice.fix),
                        color: _advice.ok ? Lantern.scarf : Lantern.warning,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _advice.ok
                              ? tr('Perfect. Hold still…')
                              : tr(
                                  'Step back until your whole body is in view',
                                ),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (final step in _game.howTo)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(step.icon, size: 18, color: _game.accent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              tr(step.title),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr('The game starts on its own when you are framed.'),
                          style: Txt.caption,
                        ),
                      ),
                      TextButton(
                        onPressed: _startCountdown,
                        child: Text(tr('Start now')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Widget _pauseOverlay(BuildContext context) => Positioned.fill(
    child: ColoredBox(
      color: const Color(0xE6050B08),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.pause_circle_filled_rounded,
                  size: 56,
                  color: Lantern.glow,
                ),
                const SizedBox(height: 12),
                Text(
                  tr('Paused'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    'Nothing is lost while you rest. Raise both arms and hold to continue, then lower them.',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Lantern.fog),
                ),
                const SizedBox(height: 12),
                if (_ready.confirmed)
                  Text(
                    '${_ready.countdown}',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      color: Lantern.scarf,
                    ),
                  )
                else if (_ready.progress > 0)
                  SizedBox(
                    width: 180,
                    child: LinearProgressIndicator(
                      value: _ready.progress,
                      color: Lantern.scarf,
                    ),
                  ),
                const SizedBox(height: 20),
                BigButton(
                  tr('Resume'),
                  icon: Icons.play_arrow_rounded,
                  onPressed: _resumeTapped,
                ),
                BigButton(
                  tr(
                    _phase == _Phase.play && (_engine?.clockMs ?? 0) > 5000
                        ? 'Finish and see results'
                        : 'Leave',
                  ),
                  secondary: true,
                  icon: Icons.logout_rounded,
                  onPressed: _quit,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _Backdrop extends CustomPainter {
  _Backdrop(this.s, Listenable repaint) : super(repaint: repaint);
  final _ArcadeScreenState s;
  @override
  void paint(Canvas c, Size size) {
    final t = s._now / 1000;
    final e = s._engine;
    switch (s.widget.args.gameId) {
      case 'mirror-mela':
        melaBackdrop(
          c,
          size,
          t,
          storm: (e is MelaEngine) && e.stage.mode == 'orbit',
        );
      case 'pataka-pose':
        patakaBackdrop(c, size, t);
      case 'craftguard':
        duelBackdrop(c, size, t);
      case 'taal-toofan':
        final te = e is TaalEngine ? e : null;
        taalBackdrop(
          c,
          size,
          t,
          beat: te == null ? t * 1.6 : te.clockMs / te.song.beatMs,
          toofan: te?.toofan ?? false,
        );
      case 'tapeball':
        cricketBackdrop(c, size, t);
      case 'neon-slice':
        final se = e is SliceEngine ? e : null;
        sliceBackdrop(
          c,
          size,
          t,
          heat: se?.phase ?? 0,
          frenzy: se?.frenzy ?? false,
        );
      default:
        lumenBackdrop(c, size, t);
    }
  }

  @override
  bool shouldRepaint(_Backdrop old) => false;
}

class _Play extends CustomPainter {
  _Play(
    this.s,
    Listenable repaint, {
    required this.mirror,
    required this.heroAccent,
  }) : super(repaint: repaint);
  final _ArcadeScreenState s;
  final bool mirror;
  final Color heroAccent;

  @override
  void paint(Canvas c, Size size) {
    final t = s._now / 1000;
    final vp = s._viewport(size);
    // The player: an outline over the mirror, or the original avatar.
    final joints = AvatarJoints.fromFrame(s._frame, vp);
    if (joints != null) {
      paintAvatar(
        c,
        joints,
        outlineOnly: mirror,
        accent: heroAccent,
        look: lookFor(s.widget.args.gameId),
      );
    } else if (s._phase != _Phase.loading) {
      // Where to stand.
      final m = BodyMap.demo(vp);
      paintAvatar(
        c,
        AvatarJoints.demo(m),
        outlineOnly: true,
        opacity: 0.35,
        accent: heroAccent,
      );
    }
    final pose = s._pose;
    final m = pose != null ? BodyMap.fromPose(pose, vp) : BodyMap.demo(vp);
    final e = s._engine;
    if (e != null &&
        (s._phase == _Phase.play || s._phase == _Phase.countdown)) {
      switch (e) {
        case MelaEngine me:
          melaPlay(c, size, m, me, t);
        case PatakaEngine pe:
          patakaPlay(c, size, m, pe, t);
        case DuelEngine de:
          duelPlay(c, size, m, de, t, vp: vp);
        case TaalEngine te:
          taalPlay(c, size, m, te, t);
        case CricketEngine ce:
          cricketPlay(c, size, m, ce, pose, t);
        case SliceEngine se:
          slicePlay(c, size, m, se, t);
        case LumenEngine le:
          final area = Rect.fromLTWH(
            size.width * 0.1,
            math.max(70, vp.top - size.height * 0.33),
            size.width * 0.8,
            size.height * 0.3,
          );
          lumenPlay(c, size, m, le, area, t);
      }
    }
    if (s._phase == _Phase.countdown) {
      final n = (s._countdownLeft / 1000).ceil().clamp(1, 3);
      final k = 1 - (s._countdownLeft % 1000) / 1000;
      strokedText(
        c,
        '$n',
        Offset(size.width / 2, size.height * 0.42),
        size: 104 + 20 * (1 - k),
        color: Lantern.parchment,
        opacity: 1 - k * 0.4,
      );
    }
    for (final f in s._fx) {
      final age = (s._now - f.born) / 1000;
      if (f.burst) {
        // An impact: a ring racing out, sparks, and a little confetti.
        shockRing(c, f.at, age / 0.55, f.big ? 110 : 70, f.color);
        sparkBurst(c, f.at, age / 0.8, f.color, seed: f.born);
        confetti(c, f.at, age / 1.1, [
          f.color,
          Lantern.glow,
          Lantern.scarf,
        ], n: f.big ? 22 : 10, seed: f.born);
      }
      scorePop(c, f.text, f.at, age, f.color, big: f.big);
    }
  }

  @override
  bool shouldRepaint(_Play old) => old.mirror != mirror;
}
