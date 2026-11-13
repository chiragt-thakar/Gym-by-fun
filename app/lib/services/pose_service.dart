import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motion_core/motion_core.dart';
import 'package:pose_bridge/pose_bridge.dart';

import 'settings.dart';
import 'sim_pose_source.dart';

/// Where landmark frames come from. In a release build this is always the
/// real on-device pose estimator (rule 1). Tests substitute a recorded
/// source, and a developer build can ask for the simulator (see
/// [devInput]).
abstract class PoseSource {
  Future<bool> ensurePermission();

  /// Starts the camera. [selfView] also binds the native camera preview for
  /// the mirror (the image never reaches Dart). [multiPerson] asks the
  /// estimator for every body in view, so the tracker can stay locked onto
  /// the player. Returns the delegate used.
  Future<String> start({
    DeviceTier tier = DeviceTier.mid,
    bool selfView = false,
    bool multiPerson = false,
  });
  Stream<PoseFrame> get frames;
  Future<void> stop();

  /// True when the last [start] bound the native mirror preview.
  bool get selfViewActive;
}

class NativePoseSource implements PoseSource {
  NativePoseSource([PoseBridge? bridge]) : _bridge = bridge ?? PoseBridge();
  final PoseBridge _bridge;

  @override
  bool selfViewActive = false;

  /// `lite` or `full`, for the debug screen.
  String model = 'lite';

  @override
  Future<bool> ensurePermission() async =>
      await _bridge.hasPermission() || await _bridge.requestPermission();

  @override
  Future<String> start({
    DeviceTier tier = DeviceTier.mid,
    bool selfView = false,
    bool multiPerson = false,
  }) async {
    // Every tier analyses 480×640: the landmark model runs on a fixed-size
    // crop either way, and at 360×480 a player at 2–2.5 m is under the
    // 256 px body size the quality gate needs ("too far" on budget phones).
    // Full is steadier at distance; only phones with headroom run it.
    final r = await _bridge.start(
      width: 480,
      height: 640,
      fullModel: tier == DeviceTier.upperMid,
      selfView: selfView,
      maxPoses: multiPerson ? 2 : 1,
    );
    selfViewActive = r.selfView;
    model = r.model;
    return r.delegate;
  }

  @override
  Stream<PoseFrame> get frames => _bridge.frames.map(PoseFrame.fromFlat);

  @override
  Future<void> stop() {
    selfViewActive = false;
    return _bridge.stop();
  }
}

/// Developer builds only: `--dart-define=JOYNETIC_INPUT=sim` plays a
/// scripted synthetic body, `=recorded` replays the newest landmark
/// recording on the device. Both let every screen be exercised without a
/// camera. Unset (every release build) means the real camera.
const devInput = String.fromEnvironment('JOYNETIC_INPUT');

/// True when frames are not coming from the camera.
bool get simulatedInput => devInput == 'sim' || devInput == 'recorded';

final poseSourceProvider = Provider<PoseSource>(
  (_) => switch (devInput) {
    'sim' => SimulatedPoseSource(),
    'recorded' => SimulatedPoseSource(recorded: true),
    _ => NativePoseSource(),
  },
);

/// Fixed-size ring buffer of doubles: no shifting, no growth, no garbage.
class _Ring {
  _Ring(this.capacity) : _v = List<double>.filled(capacity, 0);
  final int capacity;
  final List<double> _v;
  int _next = 0;
  int length = 0;
  double _sum = 0;

  void add(double x) {
    if (length == capacity) {
      _sum -= _v[_next];
    } else {
      length++;
    }
    _v[_next] = x;
    _sum += x;
    _next = (_next + 1) % capacity;
  }

  /// Oldest and newest values (valid when [length] > 0).
  double get first => _v[length == capacity ? _next : 0];
  double get last => _v[(_next - 1 + capacity) % capacity];

  double get mean => length == 0 ? 0 : _sum / length;
}

/// Rolling performance numbers for the debug screen and device tiers.
/// Keeps the last [window] frames in fixed ring buffers (no per-frame
/// allocation or list shifting).
class PerfStats {
  PerfStats({this.window = 60})
    : _times = _Ring(window),
      _inference = _Ring(window),
      _dart = _Ring(window);

  final int window;
  final _Ring _times;
  final _Ring _inference;
  final _Ring _dart;

  void add(PoseFrame f, double dartMs) {
    _times.add(f.timestampMs.toDouble());
    final inf = f.inferenceMs;
    if (inf != null) _inference.add(inf);
    _dart.add(dartMs);
  }

  double get fps {
    if (_times.length < 2) return 0;
    final span = _times.last - _times.first;
    return span <= 0 ? 0 : (_times.length - 1) * 1000 / span;
  }

  double get inferenceMs => _inference.mean;
  double get dartMs => _dart.mean;

  /// Camera capture → event in Dart (excludes display latency).
  double get pipelineMs => inferenceMs + dartMs;

  /// True once the window is full, so [fps] is a steady reading.
  bool get settled => _times.length == window;

  DeviceTier get tier {
    if (fps >= 27 && inferenceMs <= 25) return DeviceTier.upperMid;
    if (fps >= 22 && inferenceMs <= 40) return DeviceTier.mid;
    return DeviceTier.budget;
  }
}

/// One live tracking session: pose frames → tracker → motion engine →
/// events and signals. This is the [MotionInput] every game consumes.
///
/// One [BodyTracker] lives for the whole session and is shared by whichever
/// engine is active, so the lock on the player, the filters and the
/// tracking state survive a re-calibration or a paused run.
class MotionSession implements MotionInput {
  MotionSession(
    this.source, {
    required this.initialCalibration,
    this.thresholds = const MotionThresholds(),
    this.detectors = const [],
    this.stallAfter = const Duration(milliseconds: 500),
    this.restartAfter = const Duration(milliseconds: 2500),
  });

  /// No frame for this long while running counts as lost tracking (rule 5).
  final Duration stallAfter;

  /// No frame for this long: the camera itself is restarted (up to
  /// [maxRestarts] times, each wait longer than the last).
  final Duration restartAfter;
  static const maxRestarts = 3;

  final PoseSource source;
  final CalibrationProfile? initialCalibration;
  final MotionThresholds thresholds;

  /// Plug-in detectors for this session, beyond the three core moves.
  final List<DetectorSpec> detectors;

  /// The tracking front end (player lock, quality, filters, state).
  final BodyTracker tracker = BodyTracker();
  MotionEngine? _engine;
  CalibrationProfile? _live;
  StreamSubscription<PoseFrame>? _sub;
  final _events = StreamController<MotionEvent>.broadcast();
  final _frames = StreamController<PoseFrame>.broadcast();
  final _tracked = StreamController<TrackedFrame>.broadcast();
  final perf = PerfStats();

  /// Menu confirmation movements are real poses, but are not workout attempts.
  bool collectStats = true;
  PoseFrame? lastFrame;

  /// The tracker's view of the latest frame (stabilised landmarks, quality,
  /// state), or null before the first frame.
  TrackedFrame? lastTracked;
  String delegate = '';

  /// True when the camera stopped delivering frames and could not be
  /// restarted. The player has to act (close the other camera app, retry).
  final cameraLost = ValueNotifier<bool>(false);

  /// Per-move stats for the session upload (no video, only counts).
  final Map<Move, int> started = {for (final m in Move.values) m: 0};
  final Map<Move, int> rejected = {for (final m in Move.values) m: 0};

  /// Rejections by reason, for Coach Kavi's form tips. Counts only.
  final Map<Move, Map<RejectReason, int>> rejectedBy = {
    for (final m in Move.values) m: {for (final r in RejectReason.values) r: 0},
  };

  @override
  Stream<MotionEvent> get events => _events.stream;

  /// Raw frames as the camera reported them (for the recorder).
  Stream<PoseFrame> get frames => _frames.stream;

  /// One [TrackedFrame] per camera frame: what screens draw and decide on.
  Stream<TrackedFrame> get tracked => _tracked.stream;
  MotionEngine? get engine => _engine;

  @override
  MotionSignals get signals =>
      _stalled ? MotionSignals.none : (_engine?.signals ?? MotionSignals.none);

  @override
  TrackingState get trackingState =>
      _stalled ? TrackingState.lost : tracker.state;

  /// The calibration as drift correction currently has it positioned.
  CalibrationProfile? get liveCalibration =>
      _engine?.liveCalibration ?? _live ?? initialCalibration;

  /// True while the frame watchdog has paused tracking (no frames arriving).
  bool get stalled => _stalled;
  bool _stalled = false;
  Timer? _watchdog;

  /// A stall was reported while no engine existed (setup, calibration), so
  /// the session itself owes the matching resume.
  bool _resumeOwed = false;

  /// Set by [stop] when tracking was paused, so [start] can resume the HUD.
  bool _resumeOnStart = false;
  final Stopwatch _sinceFrame = Stopwatch();

  // How the camera was last started, for restarts.
  DeviceTier _tier = DeviceTier.mid;
  bool _selfView = false;
  bool _multiPerson = false;
  int _restarts = 0;
  bool _restarting = false;
  bool _downgraded = false;

  /// Tracking light for the HUD: red whenever frames have stopped.
  TrackingLight get light =>
      _stalled ? TrackingLight.red : (_engine?.light ?? TrackingLight.red);

  MotionEngine _newEngine(CalibrationProfile c) => MotionEngine(
    calibration: c,
    thresholds: thresholds,
    detectors: detectors,
    tracker: tracker,
  );

  set calibration(CalibrationProfile c) {
    _live = null;
    _engine = _newEngine(c);
  }

  /// True while frames are subscribed (between a successful [start] and
  /// [stop]).
  bool get running => _sub != null;
  Future<bool>? _starting;

  /// Starts the camera and frame stream. Idempotent: a second call while
  /// running returns true, and one while a start is in flight shares it, so
  /// there is only ever one frame subscription and one watchdog (Q2-1).
  Future<bool> start({
    DeviceTier tier = DeviceTier.mid,
    bool selfView = false,
    bool multiPerson = false,
  }) {
    if (_sub != null) return Future.value(true);
    return _starting ??= _start(
      tier,
      selfView,
      multiPerson,
    ).whenComplete(() => _starting = null);
  }

  /// True while the native mirror preview is bound (see `PoseMirror`).
  bool get selfView => running && source.selfViewActive;

  void _cancelTimers() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  Future<bool> _start(DeviceTier tier, bool selfView, bool multiPerson) async {
    if (!await source.ensurePermission()) return false;
    // A new camera session: forget the previous player lock and filters.
    tracker.reset();
    final c = _live ?? initialCalibration;
    if (c != null) _engine = _newEngine(c);
    // Tracking was paused when the camera stopped (stall or engine pause). A
    // fresh engine will never send its own TrackingResumed, so clear the HUD
    // banner here; a still-paused engine sends its own when tracking returns.
    if (_resumeOnStart) {
      _resumeOnStart = false;
      final engine = _engine;
      if (!_events.isClosed && (engine == null || !engine.paused)) {
        _events.add(TrackingResumed(lastFrame?.timestampMs ?? 0));
      }
    }
    _tier = _downgraded && tier == DeviceTier.upperMid ? DeviceTier.mid : tier;
    _selfView = selfView;
    _multiPerson = multiPerson;
    delegate = await source.start(
      tier: _tier,
      selfView: selfView,
      multiPerson: multiPerson,
    );
    _cancelTimers();
    await _sub?.cancel();
    _sub = source.frames.listen(_onFrame, onError: _onStreamError);
    _restarts = 0;
    cameraLost.value = false;
    _sinceFrame
      ..reset()
      ..start();
    final period = Duration(
      microseconds: (stallAfter.inMicroseconds ~/ 5).clamp(1000, 100000),
    );
    _watchdog = Timer.periodic(period, (_) => _checkStall());
    return true;
  }

  void _checkStall() {
    final silent = _sinceFrame.elapsed;
    if (!_stalled) {
      if (silent >= stallAfter) {
        _stall();
      } else {
        _adaptToSlowFrames();
      }
      return;
    }
    // Still nothing: bring the camera back, waiting longer each time.
    if (_restarting || _restarts >= maxRestarts) return;
    if (silent >= restartAfter * (_restarts + 1)) _restartCamera();
  }

  /// The accurate model on a phone that cannot keep up (hot, busy) is worse
  /// than the light one at a steady rate: fall back once per session.
  void _adaptToSlowFrames() {
    if (_downgraded || _restarting || _tier != DeviceTier.upperMid) return;
    if (!perf.settled || perf.fps >= 15) return;
    _downgraded = true;
    _tier = DeviceTier.mid;
    debugPrint('pose: ${perf.fps.toStringAsFixed(0)} fps, using the light model');
    _restartCamera(countAttempt: false);
  }

  Future<void> _restartCamera({bool countAttempt = true}) async {
    if (_restarting || _sub == null) return;
    _restarting = true;
    if (countAttempt) _restarts++;
    try {
      await source.stop();
      // Stopped by the screen while we were waiting: leave it stopped.
      if (_sub == null) return;
      delegate = await source.start(
        tier: _tier,
        selfView: _selfView,
        multiPerson: _multiPerson,
      );
      if (_sub == null) await source.stop();
    } catch (e) {
      debugPrint('pose restart failed: $e');
    } finally {
      _restarting = false;
      if (_stalled && _restarts >= maxRestarts && _sub != null) {
        cameraLost.value = true;
      }
    }
  }

  void _stall() {
    if (_stalled || _events.isClosed) return;
    _stalled = true;
    final ts = (lastFrame?.timestampMs ?? 0) + _sinceFrame.elapsedMilliseconds;
    final engine = _engine;
    if (engine != null) {
      // Ends moves in progress without credit and holds until the tracker
      // has seen the player steadily again.
      engine.stall(ts).forEach(_events.add);
    } else {
      tracker.markStalled();
      _resumeOwed = true;
      _events.add(TrackingPaused(ts, TrackingIssue.noPerson));
    }
  }

  void _onStreamError(Object error, StackTrace st) {
    // A native pose error must not crash the zone; treat it as lost tracking.
    debugPrint('pose stream error: $error');
    _stall();
  }

  // Reused for every frame instead of allocating a Stopwatch each time.
  final Stopwatch _sw = Stopwatch();

  void _onFrame(PoseFrame f) {
    _sw
      ..reset()
      ..start();
    lastFrame = f;
    _sinceFrame
      ..reset()
      ..start();
    final t = tracker.process(f);
    lastTracked = t;
    final engine = _engine;
    final out = engine?.processTracked(t) ?? const <MotionEvent>[];
    perf.add(f, _sw.elapsedMicroseconds / 1000);
    _frames.add(f);
    _tracked.add(t);
    // Counter maps are created once per session; per-frame work only
    // updates existing entries (and only when an event happened).
    for (final e in out) {
      if (collectStats && e is MoveStarted) {
        started[e.move] = started[e.move]! + 1;
      } else if (collectStats && e is MoveRejected) {
        rejected[e.move] = rejected[e.move]! + 1;
        final byReason = rejectedBy[e.move]!;
        byReason[e.reason] = byReason[e.reason]! + 1;
      }
      _events.add(e);
    }
    if (_stalled) {
      _stalled = false;
      _restarts = 0;
      cameraLost.value = false;
    }
    if (engine != null) {
      // The engine reports its own resume once the tracker has settled.
      _resumeOwed = false;
    } else if (_resumeOwed && !t.paused) {
      _resumeOwed = false;
      _events.add(TrackingResumed(f.timestampMs));
    }
  }

  /// Only measured counts are reported. False triggers and per-move latency
  /// are not measured on device, so they are omitted rather than invented.
  Map<String, Map<String, int>> moveStats() => {
    for (final m in Move.values)
      m.name: {
        'attempts': started[m]! + rejected[m]!,
        'recognised': started[m]!,
        for (final r in RejectReason.values) r.name: rejectedBy[m]![r]!,
      },
  };

  Future<void> stop() async {
    _cancelTimers();
    _sinceFrame.stop();
    if (_stalled || (_engine?.paused ?? false)) _resumeOnStart = true;
    _stalled = false;
    _resumeOwed = false;
    // Keep where drift correction had the player, for the next start.
    _live = _engine?.liveCalibration ?? _live;
    final subscription = _sub;
    _sub = null;
    // Native capture must stop immediately, even if event-channel
    // cancellation takes time to acknowledge. Await both cleanups together.
    await Future.wait<void>([
      source.stop(),
      if (subscription != null) subscription.cancel(),
    ]);
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
    await _frames.close();
    await _tracked.close();
    cameraLost.dispose();
  }
}

/// Menu confirmation only. Uses real recogniser state; never emits motion
/// events. A fresh neutral pose prevents an already-held reach selecting a
/// menu. Missing/poor frames reset the countdown, so stale camera data cannot
/// resume a run. No motion_core recognition thresholds are changed.
class ReadyGate {
  bool _neutralSeen = false;
  bool confirmed = false;
  bool _fired = false;
  int? _heldAt;
  int? _readyAt;
  int? _lastAt;
  double get progress => confirmed ? 1 : _holdProgress;
  double _holdProgress = 0;
  int get countdown => _readyAt == null || _lastAt == null
      ? 3
      : (3 - ((_lastAt! - _readyAt!) ~/ 1000)).clamp(1, 3);

  void request() => confirmed = true;

  bool update(int ts, {required bool good, required bool raised}) {
    if (_fired) return false;
    final gap = _lastAt != null && (ts <= _lastAt! || ts - _lastAt! > 250);
    _lastAt = ts;
    if (!good || gap) {
      _heldAt = null;
      _holdProgress = 0;
      _readyAt = null;
      _neutralSeen = false;
      return false;
    }
    if (!raised) _neutralSeen = true;
    if (!confirmed) {
      if (raised && _neutralSeen) {
        _heldAt ??= ts;
        _holdProgress = ((ts - _heldAt!) / 1200).clamp(0, 1).toDouble();
        if (ts - _heldAt! >= 1200) confirmed = true;
      } else {
        _heldAt = null;
        _holdProgress = 0;
      }
      return false;
    }
    if (raised) {
      _readyAt = null;
      return false;
    }
    _readyAt ??= ts;
    if (ts - _readyAt! < 3000) return false;
    _fired = true;
    return true;
  }
}
