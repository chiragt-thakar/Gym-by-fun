/// Thin Dart API over the native MotionQuest pose bridge.
///
/// Only landmark numbers arrive here — never camera pixels. Each frame is a
/// flat list: `[t, w, h, inferenceMs, x0, y0, z0, v0, x1, …]` with 33
/// landmarks, or just the 4-value header when no person is in view. Decode
/// with `PoseFrame.fromFlat` from `motion_core`.
library;

import 'dart:async';

import 'package:flutter/services.dart';

class PoseBridgeStartResult {
  const PoseBridgeStartResult(this.delegate);

  /// `gpu` or `cpu` (GPU falls back to CPU on phones that can't run it).
  final String delegate;
}

class PoseBridge {
  PoseBridge({
    MethodChannel? methods,
    EventChannel? events,
  })  : _methods = methods ?? const MethodChannel('motionquest/pose_bridge'),
        _events =
            events ?? const EventChannel('motionquest/pose_bridge/landmarks');

  final MethodChannel _methods;
  final EventChannel _events;
  Stream<List<double>>? _frames;

  Future<bool> hasPermission() async =>
      await _methods.invokeMethod<bool>('hasPermission') ?? false;

  Future<bool> requestPermission() async =>
      await _methods.invokeMethod<bool>('requestPermission') ?? false;

  /// Starts the front camera and pose landmarker. Portrait, about 480×640.
  Future<PoseBridgeStartResult> start({
    int width = 480,
    int height = 640,
    bool preferGpu = true,
  }) async {
    final r = await _methods.invokeMapMethod<String, Object?>('start', {
      'width': width,
      'height': height,
      'delegate': preferGpu ? 'gpu' : 'cpu',
    });
    return PoseBridgeStartResult((r?['delegate'] as String?) ?? 'cpu');
  }

  Future<void> stop() => _methods.invokeMethod<void>('stop');

  /// Landmark frames, newest only (the native side drops stale frames).
  Stream<List<double>> get frames => _frames ??= _events
      .receiveBroadcastStream()
      .map((e) => (e as List<Object?>).cast<num>().map((n) => n.toDouble()).toList(growable: false));
}
