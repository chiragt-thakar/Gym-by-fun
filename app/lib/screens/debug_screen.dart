import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motion_core/motion_core.dart';

import '../services/pose_service.dart';
import '../services/settings.dart';
import '../widgets/common.dart';

/// Phase 0 debug view: skeleton, recogniser states, fps and latency.
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});
  @override
  ConsumerState<DebugScreen> createState() => _DebugState();
}

class _DebugState extends ConsumerState<DebugScreen> {
  MotionSession? _session;
  final _log = <String>[];
  StreamSubscription<MotionEvent>? _ev;
  StreamSubscription<PoseFrame>? _fr;
  PoseFrame? _frame;
  String _status = 'Starting camera…';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final s = ref.read(settingsProvider);
    final session = MotionSession(
      ref.read(poseSourceProvider),
      initialCalibration: s.calibration,
      thresholds: s.thresholds,
    );
    if (!await session.start(tier: s.deviceTier ?? DeviceTier.mid)) {
      setState(() => _status = 'Camera permission denied');
      return;
    }
    _session = session;
    _status = s.calibration == null
        ? 'No calibration: using a quick standing estimate'
        : 'Calibrated';
    _ev = session.events.listen(
      (e) => setState(() {
        _log.insert(0, e.toString());
        if (_log.length > 14) _log.removeLast();
      }),
    );
    _fr = session.frames.listen((f) {
      if (session.engine == null && const QualityGate().check(f).ok) {
        session.calibration = CalibrationProfile.fromStanding(f);
      }
      setState(() => _frame = f);
    });
  }

  @override
  void dispose() {
    _ev?.cancel();
    _fr?.cancel();
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    final snap = s?.engine?.snapshot;
    final p = s?.perf;
    String f(double v) => v.toStringAsFixed(1);
    return Scaffold(
      appBar: AppBar(title: const Text('Tracking debug')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  CustomPaint(
                    painter: SkeletonPainter(
                      _frame,
                      ok: snap?.quality.ok ?? false,
                    ),
                    child: const SizedBox.expand(),
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    child: TrackingDot(
                      snap?.light ?? TrackingLight.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Text(_status),
                  if (p != null)
                    Text(
                      'fps ${f(p.fps)} · inference ${f(p.inferenceMs)} ms · dart ${f(p.dartMs)} ms · '
                      'capture→event ${f(p.pipelineMs)} ms · ${s!.delegate} · tier ${p.tier.name}',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  if (snap != null) ...[
                    Text(
                      'quality: ${snap.quality.ok ? 'ok' : snap.quality.issue!.name}  body ${f(snap.quality.bodyHeight * 100)}%',
                    ),
                    for (final k in snap.states.keys)
                      Text(
                        '$k: ${snap.states[k]}  (${f(snap.measures[k]! * 100)}%)',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                        ),
                      ),
                  ],
                  const Divider(),
                  for (final l in _log)
                    Text(
                      l,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
