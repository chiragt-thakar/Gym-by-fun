import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motion_core/motion_core.dart';
import 'package:pose_bridge/pose_bridge.dart';

import 'settings.dart';

/// Where landmark frames come from. In the app this is always the real
/// on-device pose estimator (rule 1); tests substitute a recorded source.
abstract class PoseSource {
  Future<bool> ensurePermission();

  /// Starts the camera. [selfView] also binds the native camera preview for
  /// the mirror (the image never reaches Dart). Returns the delegate used.
  Future<String> start({
    DeviceTier tier = DeviceTier.mid,
    bool selfView = false,
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

final poseSourceProvider = Provider<PoseSource>((_) => NativePoseSource());

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

  DeviceTier get tier {
    if (fps >= 27 && inferenceMs <= 25) return DeviceTier.upperMid;
    if (fps >= 22 && inferenceMs <= 40) return DeviceTier.mid;
    return DeviceTier.budget;
  }
}

/// One live tracking session: pose frames → motion engine → events.
class MotionSession {
  MotionSession(
    this.source, {
    required this.initialCalibration,
    this.thresholds = const MotionThresholds(),
    this.stallAfter = const Duration(milliseconds: 500),
  });

  /// No frame for this long while running counts as lost tracking (rule 5).
  final Duration stallAfter;

  final PoseSource source;
  final CalibrationProfile? initialCalibration;
  final MotionThresholds thresholds;
  MotionEngine? _engine;
  StreamSubscription<PoseFrame>? _sub;
  final _events = StreamController<MotionEvent>.broadcast();
  final _frames = StreamController<PoseFrame>.broadcast();
  final perf = PerfStats();
  PoseFrame? lastFrame;
  String delegate = '';

  /// Per-move stats for the session upload (no video, only counts).
  final Map<Move, int> started = {for (final m in Move.values) m: 0};
  final Map<Move, int> rejected = {for (final m in Move.values) m: 0};

  /// Rejections by reason, for Coach Kavi's form tips. Counts only.
  final Map<Move, Map<RejectReason, int>> rejectedBy = {
    for (final m in Move.values) m: {for (final r in RejectReason.values) r: 0},
  };

  Stream<MotionEvent> get events => _events.stream;
  Stream<PoseFrame> get frames => _frames.stream;
  MotionEngine? get engine => _engine;

  /// True while the frame watchdog has paused tracking (no frames arriving).
  bool get stalled => _stalled;
  bool _stalled = false;
  Timer? _watchdog;

  /// Set by [stop] when tracking was paused, so [start] can resume the HUD.
  bool _resumeOnStart = false;
  final Stopwatch _sinceFrame = Stopwatch();

  /// Tracking light for the HUD: red whenever frames have stopped.
  TrackingLight get light =>
      _stalled ? TrackingLight.red : (_engine?.light ?? TrackingLight.red);

  set calibration(CalibrationProfile c) =>
      _engine = MotionEngine(calibration: c, thresholds: thresholds);

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
  }) {
    if (_sub != null) return Future.value(true);
    return _starting ??= _start(
      tier,
      selfView,
    ).whenComplete(() => _starting = null);
  }

  /// True while the native mirror preview is bound (see `PoseMirror`).
  bool get selfView => running && source.selfViewActive;

  void _cancelTimers() {
    _watchdog?.cancel();
    _watchdog = null;
  }

  Future<bool> _start(DeviceTier tier, bool selfView) async {
    if (!await source.ensurePermission()) return false;
    final c = initialCalibration;
    if (c != null) {
      _engine = MotionEngine(calibration: c, thresholds: thresholds);
    }
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
    delegate = await source.start(tier: tier, selfView: selfView);
    _cancelTimers();
    await _sub?.cancel();
    _sub = source.frames.listen(_onFrame, onError: _onStreamError);
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
    if (_stalled || _sinceFrame.elapsed < stallAfter) return;
    _stall();
  }

  void _stall() {
    if (_stalled || _events.isClosed) return;
    _stalled = true;
    final ts = (lastFrame?.timestampMs ?? 0) + _sinceFrame.elapsedMilliseconds;
    _events.add(TrackingPaused(ts, TrackingIssue.noPerson));
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
    final out = _engine?.process(f) ?? const <MotionEvent>[];
    perf.add(f, _sw.elapsedMicroseconds / 1000);
    _frames.add(f);
    // Counter maps are created once per session; per-frame work only
    // updates existing entries (and only when an event happened).
    for (final e in out) {
      if (e is MoveStarted) {
        started[e.move] = started[e.move]! + 1;
      } else if (e is MoveRejected) {
        rejected[e.move] = rejected[e.move]! + 1;
        final byReason = rejectedBy[e.move]!;
        byReason[e.reason] = byReason[e.reason]! + 1;
      }
      _events.add(e);
    }
    if (_stalled) {
      _stalled = false;
      // The engine never saw the stall; if it is not paused itself, tell the
      // game tracking is back. Otherwise its own TrackingResumed will follow.
      final engine = _engine;
      if (engine != null && !engine.paused) {
        _events.add(TrackingResumed(f.timestampMs));
      }
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
    await _sub?.cancel();
    _sub = null;
    await source.stop();
  }

  Future<void> dispose() async {
    await stop();
    await _events.close();
    await _frames.close();
  }
}
