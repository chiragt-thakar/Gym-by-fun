// DEVELOPMENT ONLY. A pose source that needs no camera, so every screen —
// set-up, calibration, play, recovery — can be exercised on an emulator or
// a desk. It is reachable only through `--dart-define=JOYNETIC_INPUT=…`
// (see `devInput` in pose_service.dart); a release build never constructs
// it, and real on-device pose estimation remains the only input players
// ever get (rule 1).
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:motion_core/motion_core.dart';
import 'package:motion_core/testing.dart';
import 'package:path_provider/path_provider.dart';

import 'pose_service.dart';
import 'settings.dart';

class SimulatedPoseSource implements PoseSource {
  /// [recorded] replays the newest landmark recording saved by the recorder
  /// screen (falling back to the synthetic script when there is none).
  /// [frames], when given, is played instead of either (tests).
  SimulatedPoseSource({this.recorded = false, List<PoseFrame>? frames})
    : _given = frames;

  final bool recorded;
  final List<PoseFrame>? _given;

  final _out = StreamController<PoseFrame>.broadcast();
  List<PoseFrame> _frames = const [];
  Timer? _timer;
  int _i = 0;
  int _base = 0;
  final Stopwatch _clock = Stopwatch()..start();

  @override
  bool selfViewActive = false;

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Stream<PoseFrame> get frames => _out.stream;

  /// A session a tester can follow along with: stand, the calibration
  /// routine (so the calibration screen completes), then a mix of moves
  /// and deliberate non-moves.
  static List<PoseFrame> script({int seed = 11}) {
    final s = SyntheticSession(SyntheticBody(seed: seed), seed: seed);
    final lead = s.record([const ScriptStep(Action.idle, 3000)]).frames;
    final cal = s.calibrationFrames(startMs: lead.last.timestampMs + 33);
    final play = s.record(s.randomScript(2)).frames;
    final offset = cal.last.timestampMs + 33;
    return [
      ...lead,
      ...cal,
      for (final f in play)
        PoseFrame(
          timestampMs: f.timestampMs + offset,
          landmarks: f.landmarks,
          imageWidth: f.imageWidth,
          imageHeight: f.imageHeight,
        ),
    ];
  }

  Future<List<PoseFrame>> _load() async {
    final given = _given;
    if (given != null) return given;
    if (recorded) {
      try {
        final dir = Directory(
          '${(await getApplicationDocumentsDirectory()).path}/recordings',
        );
        if (dir.existsSync()) {
          final files =
              dir
                  .listSync()
                  .whereType<File>()
                  .where((f) => f.path.endsWith('.json'))
                  .toList()
                ..sort(
                  (a, b) =>
                      b.lastModifiedSync().compareTo(a.lastModifiedSync()),
                );
          if (files.isNotEmpty) {
            final rec = LandmarkRecording.decode(
              await files.first.readAsString(),
            );
            if (rec.frames.length > 1) return rec.frames;
          }
        }
      } catch (e) {
        debugPrint('recorded input unavailable, using the script: $e');
      }
    }
    return script();
  }

  @override
  Future<String> start({
    DeviceTier tier = DeviceTier.mid,
    bool selfView = false,
    bool multiPerson = false,
  }) async {
    _timer?.cancel();
    if (_frames.isEmpty) _frames = await _load();
    final frames = _frames;
    if (frames.length < 2) return 'sim';
    // Continue the frame clock across restarts, so time never runs back.
    _base = _clock.elapsedMilliseconds;
    _i = 0;
    final first = frames.first.timestampMs;
    final span = frames.last.timestampMs - first;
    final period = (span / (frames.length - 1)).round().clamp(10, 200);
    _timer = Timer.periodic(Duration(milliseconds: period), (_) {
      if (_out.isClosed) return;
      final n = frames.length;
      final f = frames[_i % n];
      final loops = _i ~/ n;
      _i++;
      _out.add(
        PoseFrame(
          timestampMs:
              _base + (f.timestampMs - first) + loops * (span + period),
          landmarks: f.landmarks,
          imageWidth: f.imageWidth ?? 480,
          imageHeight: f.imageHeight ?? 640,
          inferenceMs: 0,
        ),
      );
    });
    return 'sim';
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }
}
