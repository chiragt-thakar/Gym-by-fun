import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motion_core/motion_core.dart';

import '../app/theme.dart';
import '../services/pose_service.dart';
import '../services/settings.dart';
import '../widgets/tracking_overlay.dart';

/// Tracking diagnostics: the skeleton as the tracker sees it (coloured by
/// confidence), the tracking state, calibration quality, frame rate and
/// every detector's state, plus a live event log. Landmarks only.
///
/// The same panel can be shown over any camera screen: Settings → Tracking
/// → Diagnostics overlay.
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});
  @override
  ConsumerState<DebugScreen> createState() => _DebugState();
}

class _DebugState extends ConsumerState<DebugScreen> {
  MotionSession? _session;
  final _log = <String>[];
  StreamSubscription<MotionEvent>? _ev;
  StreamSubscription<TrackedFrame>? _fr;
  String _status = 'Starting camera…';

  /// Which pose model the bridge is running (lite or full).
  String _model() => switch (ref.read(poseSourceProvider)) {
    NativePoseSource(:final model) => model,
    _ => simulatedInput ? 'simulated' : '?',
  };

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
      // Every plug-in detector, so each can be checked on a real body.
      detectors: const [
        DetectorSpec(DetectorIds.sideStep),
        DetectorSpec(DetectorIds.jump),
        DetectorSpec(DetectorIds.punch),
        DetectorSpec(DetectorIds.twist),
        DetectorSpec(DetectorIds.kneeLift),
      ],
    );
    final ok = await session.start(
      tier: s.deviceTier ?? DeviceTier.mid,
      multiPerson: s.multiPerson,
    );
    if (!mounted) {
      await session.dispose();
      return;
    }
    if (!ok) {
      await session.dispose();
      setState(() => _status = 'Camera permission denied');
      return;
    }
    _session = session;
    _status = s.calibration == null
        ? 'No calibration: using a quick standing estimate'
        : 'Calibrated · ${_model()} model';
    _ev = session.events.listen(
      (e) => setState(() {
        _log.insert(0, e.toString());
        if (_log.length > 14) _log.removeLast();
      }),
    );
    _fr = session.tracked.listen((t) {
      if (session.engine == null && t.quality.ok) {
        session.calibration = CalibrationProfile.fromStanding(t.frame);
      }
    });
    setState(() {});
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
    return Scaffold(
      appBar: AppBar(title: const Text('Tracking diagnostics')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text(_status, style: const TextStyle(color: Lantern.fog)),
            const SizedBox(height: 8),
            if (s != null) TrackingDiagnostics(session: s, expanded: true),
            const Divider(height: 24),
            for (final l in _log)
              Text(
                l,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
          ],
        ),
      ),
    );
  }
}
