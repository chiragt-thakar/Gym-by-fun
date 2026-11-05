import 'dart:convert';

import 'calibration.dart';
import 'events.dart';
import 'landmarks.dart';

/// A labelled span in a recording: "the player squatted from 1200 to 2100 ms".
class MoveLabel {
  const MoveLabel(this.move, this.startMs, this.endMs);
  final Move move;
  final int startMs;
  final int endMs;

  Map<String, Object> toJson() =>
      {'move': move.name, 'startMs': startMs, 'endMs': endMs};

  factory MoveLabel.fromJson(Map<String, dynamic> j) => MoveLabel(
        Move.values.byName(j['move'] as String),
        (j['startMs'] as num).toInt(),
        (j['endMs'] as num).toInt(),
      );
}

/// A landmark recording: frames of 33 points plus optional labels.
/// Never contains images or video.
class LandmarkRecording {
  LandmarkRecording({
    required this.frames,
    this.labels = const [],
    this.calibration,
    Map<String, Object?>? meta,
  }) : meta = meta ?? {};

  static const format = 'motionquest.landmarks';
  static const version = 1;

  final List<PoseFrame> frames;
  final List<MoveLabel> labels;
  final CalibrationProfile? calibration;
  final Map<String, Object?> meta;

  int get durationMs =>
      frames.isEmpty ? 0 : frames.last.timestampMs - frames.first.timestampMs;

  bool get isSynthetic => meta['synthetic'] == true;

  Map<String, Object?> toJson() => {
        'format': format,
        'version': version,
        'meta': meta,
        if (calibration != null) 'calibration': calibration!.toJson(),
        'labels': [for (final l in labels) l.toJson()],
        'frames': [for (final f in frames) f.toJson()],
      };

  String encode() => jsonEncode(toJson());

  factory LandmarkRecording.fromJson(Map<String, dynamic> j) {
    if (j['format'] != format) {
      throw const FormatException('Not a MotionQuest landmark recording');
    }
    final v = (j['version'] as num).toInt();
    if (v > version) throw FormatException('Unsupported recording version $v');
    return LandmarkRecording(
      meta: Map<String, Object?>.from(j['meta'] as Map? ?? const {}),
      calibration: j['calibration'] == null
          ? null
          : CalibrationProfile.fromJson(
              Map<String, dynamic>.from(j['calibration'] as Map)),
      labels: [
        for (final l in (j['labels'] as List<dynamic>? ?? const []))
          MoveLabel.fromJson(Map<String, dynamic>.from(l as Map))
      ],
      frames: [
        for (final f in (j['frames'] as List<dynamic>))
          PoseFrame.fromJson(Map<String, dynamic>.from(f as Map))
      ],
    );
  }

  factory LandmarkRecording.decode(String s) =>
      LandmarkRecording.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

/// Builds a recording on the device, frame by frame. The recorder screen
/// marks labels live while a helper calls out moves.
class RecordingBuilder {
  RecordingBuilder({Map<String, Object?>? meta}) : meta = meta ?? {};
  final Map<String, Object?> meta;
  final List<PoseFrame> _frames = [];
  final List<MoveLabel> _labels = [];
  final Map<Move, int> _open = {};
  CalibrationProfile? calibration;

  int get frameCount => _frames.length;

  void add(PoseFrame f) => _frames.add(f);

  void beginLabel(Move m, int ts) => _open[m] = ts;

  void endLabel(Move m, int ts) {
    final s = _open.remove(m);
    if (s != null) _labels.add(MoveLabel(m, s, ts));
  }

  LandmarkRecording build() => LandmarkRecording(
        frames: List.unmodifiable(_frames),
        labels: List.unmodifiable(_labels),
        calibration: calibration,
        meta: meta,
      );
}
