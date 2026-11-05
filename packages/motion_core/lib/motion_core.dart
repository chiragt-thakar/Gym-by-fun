/// MotionQuest motion pipeline.
///
/// Landmarks in, game-agnostic motion events out:
///
///   PoseFrame → QualityGate → LandmarkSmoother → BodyFeatures → recognisers → MotionEvent
///
/// Everything here is pure Dart and deterministic so it can be replay-tested on
/// recorded landmark files (never video).
library;

export 'src/landmarks.dart';
export 'src/one_euro_filter.dart';
export 'src/quality_gate.dart';
export 'src/calibration.dart';
export 'src/features.dart';
export 'src/events.dart';
export 'src/recognisers.dart';
export 'src/motion_engine.dart';
export 'src/recording.dart';
export 'src/accuracy.dart';
