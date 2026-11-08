/// Thin Dart API over the native MotionQuest pose bridge.
///
/// Only landmark numbers arrive here — never camera pixels. Each frame is a
/// flat list: `[t, w, h, inferenceMs, x0, y0, z0, v0, x1, …]` with 33
/// landmarks, or just the 4-value header when no person is in view. Decode
/// with `PoseFrame.fromFlat` from `motion_core`.
///
/// The optional self-view mirror ([PoseMirror]) is a native platform view:
/// the camera image is drawn by Android straight onto the screen and never
/// enters Dart.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class PoseBridgeStartResult {
  const PoseBridgeStartResult(
    this.delegate, {
    this.model = 'lite',
    this.selfView = false,
  });

  /// `gpu` or `cpu` (GPU falls back to CPU on phones that can't run it).
  final String delegate;

  /// `lite` or `full` (Full falls back to Lite if the GPU can't run it).
  final String model;

  /// True when the camera preview was bound for [PoseMirror].
  final bool selfView;
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

  /// Starts the front camera and pose landmarker. Portrait, about 480×640,
  /// 3:4. [fullModel] asks for the more accurate Full model (GPU only).
  /// [selfView] also binds the camera preview for [PoseMirror].
  Future<PoseBridgeStartResult> start({
    int width = 480,
    int height = 640,
    bool preferGpu = true,
    bool fullModel = false,
    bool selfView = false,
  }) async {
    final r = await _methods.invokeMapMethod<String, Object?>('start', {
      'width': width,
      'height': height,
      'delegate': preferGpu ? 'gpu' : 'cpu',
      'model': fullModel ? 'full' : 'lite',
      'selfView': selfView,
    });
    return PoseBridgeStartResult(
      (r?['delegate'] as String?) ?? 'cpu',
      model: (r?['model'] as String?) ?? 'lite',
      selfView: (r?['selfView'] as bool?) ?? false,
    );
  }

  Future<void> stop() => _methods.invokeMethod<void>('stop');

  /// Landmark frames, newest only (the native side drops stale frames).
  Stream<List<double>> get frames => _frames ??= _events
      .receiveBroadcastStream()
      .map((e) => (e as List<Object?>).cast<num>().map((n) => n.toDouble()).toList(growable: false));
}

/// The live camera mirror, drawn natively. Size it to a 3:4 box (the shared
/// viewport) so landmarks drawn on top line up. Shows nothing useful unless
/// the bridge was started with `selfView: true`.
class PoseMirror extends StatelessWidget {
  const PoseMirror({super.key});

  static const viewType = 'motionquest/self_view';

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const SizedBox.expand();
    }
    return const AndroidView(
      viewType: viewType,
      creationParamsCodec: StandardMessageCodec(),
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
    );
  }
}
