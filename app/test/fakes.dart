// TEST ONLY: a recorded pose source. The app itself only ever uses the real
// native pose estimator (rule 1).
import 'dart:async';

import 'package:motion_core/motion_core.dart';
import 'package:motionquest/services/pose_service.dart';
import 'package:motionquest/services/settings.dart';

class ReplayPoseSource implements PoseSource {
  ReplayPoseSource(this.recorded, {this.permission = true});
  final List<PoseFrame> recorded;
  final bool permission;
  final _c = StreamController<PoseFrame>.broadcast();
  bool started = false;

  @override
  Future<bool> ensurePermission() async => permission;

  @override
  Future<String> start({DeviceTier tier = DeviceTier.mid}) async {
    started = true;
    return 'cpu';
  }

  /// Pushes all recorded frames synchronously.
  void playAll() {
    for (final f in recorded) {
      _c.add(f);
    }
  }

  /// Pushes a single frame.
  void push(PoseFrame f) => _c.add(f);

  /// Simulates a native pose error on the frame stream.
  void fail(Object error) => _c.addError(error);

  @override
  Stream<PoseFrame> get frames => _c.stream;

  @override
  Future<void> stop() async => started = false;
}
