import 'dart:async';

import 'package:flutter/material.dart';
import 'package:motion_core/motion_core.dart';

import '../app/theme.dart';
import '../services/pose_service.dart';

/// Softens framing advice for a frame that is good enough to play on: the
/// feet being out of view is not worth a red edge during a game, but
/// drifting out sideways still is (as a gentle amber warning).
FramingAdvice playAdvice(FramingAdvice a, {required bool usable}) {
  if (a.ok || !usable) return a;
  return FramingAdvice(
    FramingFix.ok,
    near: {
      ...a.near,
      for (final e in a.cut)
        if (e == FrameEdge.left || e == FrameEdge.right) e,
    },
  );
}

/// Plain words for a tracking state (diagnostics and accessibility).
String trackingStateLabel(TrackingState s) => switch (s) {
  TrackingState.tracking => 'Tracking',
  TrackingState.degraded => 'Partial view',
  TrackingState.lost => 'Lost',
  TrackingState.recovering => 'Recovering',
};

Color trackingStateColor(TrackingState s) => switch (s) {
  TrackingState.tracking => Lantern.scarf,
  TrackingState.degraded => Lantern.warning,
  TrackingState.lost => Lantern.danger,
  TrackingState.recovering => Lantern.warning,
};

/// The tracking diagnostics overlay: what the tracker sees and why.
///
/// Draws every landmark coloured by confidence (hollow = predicted, not
/// measured) in a small 3:4 inset, with the tracking state, frame quality,
/// calibration quality and live scale, frame rate and inference time, and
/// each detector's state and measure. Landmarks only — never camera pixels.
///
/// Toggled in Settings → Tracking → Diagnostics; shown over every camera
/// screen. Ignores touches, so it never gets in the way of play.
class TrackingDiagnostics extends StatefulWidget {
  const TrackingDiagnostics({
    super.key,
    required this.session,
    this.expanded = false,
  });

  final MotionSession session;

  /// The full-page layout (the diagnostics screen) instead of the compact
  /// corner panel.
  final bool expanded;

  @override
  State<TrackingDiagnostics> createState() => _TrackingDiagnosticsState();
}

class _TrackingDiagnosticsState extends State<TrackingDiagnostics> {
  StreamSubscription<TrackedFrame>? _sub;
  TrackedFrame? _t;
  int _shownAt = -1000;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(TrackingDiagnostics old) {
    super.didUpdateWidget(old);
    if (old.session != widget.session) {
      _sub?.cancel();
      _listen();
    }
  }

  void _listen() {
    _sub = widget.session.tracked.listen((t) {
      // Ten repaints a second are plenty for reading numbers.
      if ((t.timestampMs - _shownAt).abs() < 100 || !mounted) return;
      _shownAt = t.timestampMs;
      setState(() => _t = t);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  static String _n(double v, [int digits = 0]) =>
      v.isFinite ? v.toStringAsFixed(digits) : '–';

  List<String> _lines() {
    final s = widget.session;
    final t = _t;
    final p = s.perf;
    final engine = s.engine;
    final cal = s.liveCalibration;
    final base = s.initialCalibration;
    final lines = <String>[
      if (simulatedInput) 'SIMULATED INPUT ($devInput)',
      '${_n(p.fps)} fps · inf ${_n(p.inferenceMs)} ms · dart ${_n(p.dartMs, 2)} ms',
      '${s.delegate.isEmpty ? '?' : s.delegate} · tier ${p.tier.name}'
          '${s.stalled ? ' · STALLED' : ''}',
    ];
    if (t != null) {
      final q = t.quality;
      lines.add(
        'frame ${q.level.name}${q.issue == null ? '' : ' (${q.issue!.name})'}'
        ' · body ${_n(q.bodyHeight * 100)}%',
      );
      lines.add(
        'predicted ${t.predicted.length}${t.coasted ? ' (whole body)' : ''}'
        ' · others ignored ${s.tracker.strangersRejected}'
        '${s.tracker.facingSwapped ? ' · L/R swapped' : ''}',
      );
    }
    if (cal == null) {
      lines.add('calibration: none');
    } else {
      final scale = base == null ? 1.0 : cal.standingTorso / base.standingTorso;
      lines.add(
        'calibration v${cal.version} · quality ${_n(cal.quality * 100)}%'
        '${cal.feetVisible ? '' : ' · no feet'}',
      );
      lines.add(
        'scale ×${_n(scale, 2)} · rebased '
        '${engine?.snapshot.driftRebases ?? 0}×',
      );
    }
    if (engine != null) {
      final snap = engine.snapshot;
      for (final k in snap.states.keys) {
        lines.add(
          '${k.padRight(11)} ${snap.states[k]!.padRight(8)} '
          '${_n(snap.measures[k]! * 100)}%',
        );
      }
    }
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final state = widget.session.trackingState;
    final color = trackingStateColor(state);
    final expanded = widget.expanded;
    final inset = SizedBox(
      width: expanded ? 210 : 84,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xCC05070A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color, width: 1.5),
          ),
          child: CustomPaint(painter: _LandmarkPainter(t)),
        ),
      ),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          trackingStateLabel(state).toUpperCase(),
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: expanded ? 15 : 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
            color: color,
          ),
        ),
        for (final l in _lines())
          Text(
            l,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: expanded ? 13 : 9.5,
              height: 1.3,
              color: Colors.white,
            ),
          ),
      ],
    );
    final panel = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xB305070A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: expanded
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(child: inset),
                  const SizedBox(height: 10),
                  text,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  inset,
                  const SizedBox(width: 6),
                  Flexible(child: text),
                ],
              ),
      ),
    );
    return IgnorePointer(
      child: Semantics(label: 'Tracking diagnostics', child: panel),
    );
  }
}

/// Landmarks coloured by confidence: teal ≥ 0.8, amber ≥ 0.5, red below.
/// Predicted landmarks are hollow rings.
class _LandmarkPainter extends CustomPainter {
  _LandmarkPainter(this.t);
  final TrackedFrame? t;

  static Color _colour(double v) => v >= 0.8
      ? Lantern.scarf
      : (v >= 0.5 ? Lantern.warning : Lantern.danger);

  @override
  void paint(Canvas canvas, Size size) {
    final tracked = t;
    if (tracked == null || !tracked.frame.hasPerson) return;
    final f = tracked.frame;
    final w = size.width, h = size.height;
    final r = (w * 0.022).clamp(1.5, 5.0).toDouble();
    Offset p(int i) => Offset(f[i].x * w, f[i].y * h);
    final bone = Paint()
      ..strokeWidth = r * 0.7
      ..strokeCap = StrokeCap.round;
    for (final (a, b) in Lm.edges) {
      final v = f[a].visibility < f[b].visibility
          ? f[a].visibility
          : f[b].visibility;
      bone.color = _colour(v).withValues(alpha: tracked.coasted ? 0.4 : 0.8);
      canvas.drawLine(p(a), p(b), bone);
    }
    final dot = Paint();
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.5;
    for (var i = 0; i < Lm.count; i++) {
      final c = _colour(f[i].visibility);
      if (tracked.predicted.contains(i)) {
        canvas.drawCircle(p(i), r, ring..color = c);
      } else {
        canvas.drawCircle(p(i), r, dot..color = c);
      }
    }
  }

  @override
  bool shouldRepaint(_LandmarkPainter old) => old.t != t;
}
