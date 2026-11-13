/// Joynetic tracking engine.
///
/// Landmarks in, game-agnostic motion input out:
///
///   PoseFrame → BodyTracker (SubjectLock → QualityGate → LandmarkStabiliser
///             → TrackingStateMachine) → BodyFeatures → detectors
///             → MotionEvent + MotionSignals
///
/// Everything here is pure Dart and deterministic so it can be replay-tested
/// on recorded landmark files (never video). See docs/tracking.md.
library;

export 'src/landmarks.dart';
export 'src/robust.dart';
export 'src/one_euro_filter.dart';
export 'src/stabiliser.dart';
export 'src/subject_lock.dart';
export 'src/tracking_state.dart';
export 'src/body_tracker.dart';
export 'src/quality_gate.dart';
export 'src/framing.dart';
export 'src/calibration.dart';
export 'src/features.dart';
export 'src/events.dart';
export 'src/recognisers.dart';
export 'src/extra_recognisers.dart';
export 'src/detectors.dart';
export 'src/drift.dart';
export 'src/signals.dart';
export 'src/motion_engine.dart';
export 'src/recording.dart';
export 'src/accuracy.dart';
export 'src/body_pose.dart';
export 'src/pose_matcher.dart';
export 'src/swing.dart';
