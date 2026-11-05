import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motion_core/motion_core.dart';
import 'package:pose_bridge/pose_bridge.dart';

import 'settings.dart';

/// Where landmark frames come from. In the app this is always the real
/// on-device pose estimator (rule 1); tests substitute a recorded source.
abstract class PoseSource {
  Future<bool> ensurePermission();
  Future<String> start({DeviceTier tier = DeviceTier.mid});
  Stream<PoseFrame> get frames;
  Future<void> stop();
}

class NativePoseSource implements PoseSource {
  NativePoseSource([PoseBridge? bridge]) : _bridge = bridge ?? PoseBridge();
  final PoseBridge _bridge;

  @override
  Future<bool> ensurePermission() async =>
      await _bridge.hasPermission() || await _bridge.requestPermission();

  @override
  Future<String> start({DeviceTier tier = DeviceTier.mid}) async {
    // Budget phones analyse a smaller image to hold 15–24 fps.
    final (w, h) = tier == DeviceTier.budget ? (360, 480) : (480, 640);
    final r = await _bridge.start(width: w, height: h);
    return r.delegate;
  }

  @override
  Stream<PoseFrame> get frames => _bridge.frames.map(PoseFrame.fromFlat);

  @override
  Future<void> stop() => _bridge.stop();
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
  });

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

  set calibration(CalibrationProfile c) =>
      _engine = MotionEngine(calibration: c, thresholds: thresholds);

  Future<bool> start({DeviceTier tier = DeviceTier.mid}) async {
    if (!await source.ensurePermission()) return false;
    final c = initialCalibration;
    if (c != null) {
      _engine = MotionEngine(calibration: c, thresholds: thresholds);
    }
    delegate = await source.start(tier: tier);
    _sub = source.frames.listen(_onFrame);
    return true;
  }

  // Reused for every frame instead of allocating a Stopwatch each time.
  final Stopwatch _sw = Stopwatch();

  void _onFrame(PoseFrame f) {
    _sw
      ..reset()
      ..start();
    lastFrame = f;
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
  }

  Map<String, Map<String, int>> moveStats() => {
    for (final m in Move.values)
      m.name: {
        'attempts': started[m]! + rejected[m]!,
        'falseTriggers': 0,
        'avgLatencyMs': perf.pipelineMs.round(),
        'recognised': started[m]!,
        for (final r in RejectReason.values) r.name: rejectedBy[m]![r]!,
      },
  };

  Future<void> stop() async {
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
