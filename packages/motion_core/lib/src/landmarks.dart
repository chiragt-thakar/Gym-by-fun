/// Landmark data model shared by the native bridge, the recorder and the
/// recognisers.
///
/// Coordinates follow MediaPipe Pose Landmarker's normalised image space:
/// `x` and `y` in 0..1 with `y` growing downwards. The native bridge mirrors
/// `x` for the front camera, so a frame looks like a selfie: when the player
/// leans to *their* left, the shoulders move towards smaller `x`.
library;

/// One of the 33 MediaPipe pose landmarks.
class Landmark {
  const Landmark(this.x, this.y, this.z, this.visibility);

  final double x;
  final double y;
  final double z;

  /// 0..1 confidence that the point is visible (not occluded, in frame).
  final double visibility;

  Landmark copyWith({double? x, double? y, double? z, double? visibility}) =>
      Landmark(
          x ?? this.x, y ?? this.y, z ?? this.z, visibility ?? this.visibility);

  List<double> toList() => [x, y, z, visibility];

  factory Landmark.fromList(List<dynamic> v) => Landmark(
        (v[0] as num).toDouble(),
        (v[1] as num).toDouble(),
        (v[2] as num).toDouble(),
        v.length > 3 ? (v[3] as num).toDouble() : 1.0,
      );

  @override
  String toString() =>
      'Landmark(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, v=${visibility.toStringAsFixed(2)})';
}

/// MediaPipe pose landmark indices that MotionQuest uses.
abstract final class Lm {
  static const nose = 0;
  static const leftShoulder = 11;
  static const rightShoulder = 12;
  static const leftElbow = 13;
  static const rightElbow = 14;
  static const leftWrist = 15;
  static const rightWrist = 16;
  static const leftHip = 23;
  static const rightHip = 24;
  static const leftKnee = 25;
  static const rightKnee = 26;
  static const leftAnkle = 27;
  static const rightAnkle = 28;

  static const count = 33;

  /// Points that must be visible for the full-body quality check.
  static const fullBody = [
    nose,
    leftShoulder,
    rightShoulder,
    leftHip,
    rightHip,
    leftKnee,
    rightKnee,
    leftAnkle,
    rightAnkle,
  ];

  /// Points smoothed by the One Euro filter.
  static const smoothed = [
    nose,
    leftShoulder,
    rightShoulder,
    leftElbow,
    rightElbow,
    leftWrist,
    rightWrist,
    leftHip,
    rightHip,
    leftKnee,
    rightKnee,
    leftAnkle,
    rightAnkle,
  ];

  /// Skeleton edges for debug drawing.
  static const edges = <(int, int)>[
    (leftShoulder, rightShoulder),
    (leftShoulder, leftElbow),
    (leftElbow, leftWrist),
    (rightShoulder, rightElbow),
    (rightElbow, rightWrist),
    (leftShoulder, leftHip),
    (rightShoulder, rightHip),
    (leftHip, rightHip),
    (leftHip, leftKnee),
    (leftKnee, leftAnkle),
    (rightHip, rightKnee),
    (rightKnee, rightAnkle),
  ];
}

/// One camera frame's worth of landmarks. Never carries pixels.
class PoseFrame {
  PoseFrame({
    required this.timestampMs,
    required this.landmarks,
    this.imageWidth,
    this.imageHeight,
    this.inferenceMs,
  }) : assert(landmarks.isEmpty || landmarks.length == Lm.count);

  /// Capture timestamp on the device's monotonic clock, in milliseconds.
  final int timestampMs;

  /// 33 landmarks, or empty when no person was detected.
  final List<Landmark> landmarks;

  /// Size of the analysed image in pixels, if known (for the size check).
  final int? imageWidth;
  final int? imageHeight;

  /// Native inference time for this frame, if reported.
  final double? inferenceMs;

  bool get hasPerson => landmarks.isNotEmpty;

  Landmark operator [](int i) => landmarks[i];

  PoseFrame withLandmarks(List<Landmark> lms) => PoseFrame(
        timestampMs: timestampMs,
        landmarks: lms,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        inferenceMs: inferenceMs,
      );

  Map<String, Object?> toJson() => {
        't': timestampMs,
        if (imageWidth != null) 'w': imageWidth,
        if (imageHeight != null) 'h': imageHeight,
        if (inferenceMs != null) 'inf': inferenceMs,
        'lm': [
          for (final l in landmarks)
            [_r(l.x), _r(l.y), _r(l.z), _r(l.visibility)]
        ],
      };

  factory PoseFrame.fromJson(Map<String, dynamic> j) => PoseFrame(
        timestampMs: (j['t'] as num).toInt(),
        imageWidth: (j['w'] as num?)?.toInt(),
        imageHeight: (j['h'] as num?)?.toInt(),
        inferenceMs: (j['inf'] as num?)?.toDouble(),
        landmarks: [
          for (final v in (j['lm'] as List<dynamic>))
            Landmark.fromList(v as List<dynamic>)
        ],
      );

  /// Decodes the flat `[t, w, h, inf, x0, y0, z0, v0, x1, ...]` list the
  /// native bridge sends over the EventChannel.
  factory PoseFrame.fromFlat(List<dynamic> flat) {
    final t = (flat[0] as num).toInt();
    final w = (flat[1] as num).toInt();
    final h = (flat[2] as num).toInt();
    final inf = (flat[3] as num).toDouble();
    final lms = <Landmark>[];
    if (flat.length >= 4 + Lm.count * 4) {
      for (var i = 0; i < Lm.count; i++) {
        final o = 4 + i * 4;
        lms.add(Landmark(
          (flat[o] as num).toDouble(),
          (flat[o + 1] as num).toDouble(),
          (flat[o + 2] as num).toDouble(),
          (flat[o + 3] as num).toDouble(),
        ));
      }
    }
    return PoseFrame(
      timestampMs: t,
      landmarks: lms,
      imageWidth: w > 0 ? w : null,
      imageHeight: h > 0 ? h : null,
      inferenceMs: inf >= 0 ? inf : null,
    );
  }
}

double _r(double v) => (v * 10000).roundToDouble() / 10000;

/// Midpoint of two landmarks (visibility = the lower of the two).
Landmark midpoint(Landmark a, Landmark b) => Landmark(
      (a.x + b.x) / 2,
      (a.y + b.y) / 2,
      (a.z + b.z) / 2,
      a.visibility < b.visibility ? a.visibility : b.visibility,
    );
