import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:motion_core/motion_core.dart';
import 'package:path_provider/path_provider.dart';

import '../services/pose_service.dart';
import '../services/settings.dart';
import '../app/theme.dart';
import '../widgets/common.dart';

/// Records landmark sessions as JSON for the replay tests — never video.
///
/// A helper holds a label button while the subject performs the move. Files
/// land in the app's documents folder under recordings/; copy them with
/// `adb pull` into packages/motion_core/test/recordings/.
class RecorderScreen extends ConsumerStatefulWidget {
  const RecorderScreen({super.key});
  @override
  ConsumerState<RecorderScreen> createState() => _RecorderState();
}

class _RecorderState extends ConsumerState<RecorderScreen> {
  final _subject = TextEditingController(text: 'S01');
  String _clothing = 'track pants';
  String _lighting = 'tube light';
  MotionSession? _session;
  StreamSubscription<PoseFrame>? _sub;
  RecordingBuilder? _rec;
  PoseFrame? _frame;
  int _lastTs = 0;
  final Set<Move> _held = {};
  String? _saved;

  Future<void> _toggle() async {
    if (_rec != null) return _stop();
    final s = ref.read(settingsProvider);
    final session = MotionSession(
      ref.read(poseSourceProvider),
      initialCalibration: s.calibration,
    );
    final ok = await session.start(tier: s.deviceTier ?? DeviceTier.mid);
    if (!mounted) {
      await session.dispose();
      return;
    }
    if (!ok) return;
    _session = session;
    final rec = RecordingBuilder(
      meta: {
        'subject': _subject.text.trim(),
        'clothing': _clothing,
        'lighting': _lighting,
        'tier': (s.deviceTier ?? DeviceTier.mid).name,
        'recordedAt': DateTime.now().toUtc().toIso8601String(),
        'consent':
            'verbal consent recorded by operator; landmarks only, no video',
      },
    )..calibration = s.calibration;
    _rec = rec;
    _sub = session.frames.listen((f) {
      rec.add(f);
      _lastTs = f.timestampMs;
      setState(() => _frame = f);
    });
    setState(() {});
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    await _session?.dispose();
    final rec = _rec!.build();
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/recordings',
    )..createSync(recursive: true);
    final name =
        '${_subject.text.trim()}_${DateTime.now().millisecondsSinceEpoch}.json';
    final file = File('${dir.path}/$name');
    await file.writeAsString(rec.encode());
    if (!mounted) return;
    setState(() {
      _rec = null;
      _session = null;
      _saved =
          '${file.path}\n${rec.frames.length} frames · ${rec.labels.length} labels';
    });
  }

  Widget _label(Move m, String text) => GestureDetector(
    onTapDown: (_) {
      _rec?.beginLabel(m, _lastTs);
      setState(() => _held.add(m));
    },
    onTapUp: (_) {
      _rec?.endLabel(m, _lastTs);
      setState(() => _held.remove(m));
    },
    onTapCancel: () {
      _rec?.endLabel(m, _lastTs);
      setState(() => _held.remove(m));
    },
    child: Container(
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _held.contains(m) ? Lantern.scarf : Lantern.moss,
        borderRadius: BorderRadius.circular(Lantern.radius),
        border: Border.all(
          color: _held.contains(m) ? Lantern.parchment : Lantern.ridge,
          width: _held.contains(m) ? 4 : 2.5,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 1,
          color: _held.contains(m) ? Lantern.onGlow : Lantern.parchment,
        ),
      ),
    ),
  );

  @override
  void dispose() {
    _sub?.cancel();
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recording = _rec != null;
    return ScreenScaffold(
      title: 'Landmark recorder',
      children: [
        const Text(
          'Records 33 body points per frame. No images or video are saved.',
        ),
        if (!recording) ...[
          TextField(
            controller: _subject,
            decoration: const InputDecoration(
              labelText: 'Subject ID (no names)',
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: _clothing,
            decoration: const InputDecoration(labelText: 'Clothing'),
            items: [
              for (final c in [
                'track pants',
                'kurta',
                'saree',
                'shorts',
                'loose t-shirt',
              ])
                DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => _clothing = v!,
          ),
          DropdownButtonFormField<String>(
            initialValue: _lighting,
            decoration: const InputDecoration(labelText: 'Lighting'),
            items: [
              for (final l in ['tube light', 'evening', 'daylight', 'dim'])
                DropdownMenuItem(value: l, child: Text(l)),
            ],
            onChanged: (v) => _lighting = v!,
          ),
        ],
        SizedBox(
          height: 260,
          child: CustomPaint(
            painter: SkeletonPainter(_frame),
            child: const SizedBox.expand(),
          ),
        ),
        if (recording) ...[
          Text(
            '${_rec!.frameCount} frames — hold a button while the move happens',
          ),
          const SizedBox(height: 8),
          _label(Move.squat, 'SQUAT'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _label(Move.leanLeft, 'LEAN LEFT')),
              const SizedBox(width: 8),
              Expanded(child: _label(Move.leanRight, 'LEAN RIGHT')),
            ],
          ),
          const SizedBox(height: 8),
          _label(Move.raiseArms, 'ARMS UP'),
        ],
        BigButton(
          recording ? 'Stop and save' : 'Start recording',
          icon: recording ? Icons.stop : Icons.fiber_manual_record,
          onPressed: _toggle,
        ),
        if (_saved != null) SelectableText('Saved: $_saved'),
      ],
    );
  }
}
