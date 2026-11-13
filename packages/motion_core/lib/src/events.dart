import 'quality_gate.dart';

/// Which side of the player's own body (the player's left is screen left
/// in the mirrored selfie frame).
enum BodySide { left, right }

/// Moves the motion core can recognise. World 1 uses the first four.
enum Move { squat, leanLeft, leanRight, raiseArms }

/// Why a move attempt did not count, shown to the player after the fact.
enum RejectReason { tooShallow, notVisible, tooEarly }

/// Base class of everything the motion core tells the game.
///
/// A recognised move does nothing on its own: the game decides what it means
/// given what is on screen.
sealed class MotionEvent {
  const MotionEvent(this.timestampMs);

  /// Timestamp of the frame that produced the event (capture clock).
  final int timestampMs;
}

class MoveStarted extends MotionEvent {
  const MoveStarted(this.move, super.timestampMs, {this.confidence = 1});
  final Move move;
  final double confidence;
  @override
  String toString() => 'MoveStarted($move @$timestampMs)';
}

class MoveHeld extends MotionEvent {
  const MoveHeld(this.move, super.timestampMs, this.heldMs);
  final Move move;
  final int heldMs;
  @override
  String toString() => 'MoveHeld($move ${heldMs}ms @$timestampMs)';
}

class MoveEnded extends MotionEvent {
  const MoveEnded(this.move, super.timestampMs, {this.completed = true});
  final Move move;

  /// False when the move was cut short by a tracking pause.
  final bool completed;
  @override
  String toString() => 'MoveEnded($move @$timestampMs)';
}

class RepCompleted extends MotionEvent {
  const RepCompleted(this.move, super.timestampMs, this.durationMs);
  final Move move;
  final int durationMs;
  @override
  String toString() => 'RepCompleted($move ${durationMs}ms @$timestampMs)';
}

/// An attempt that looked like a move but did not count, with the reason.
class MoveRejected extends MotionEvent {
  const MoveRejected(this.move, super.timestampMs, this.reason);
  final Move move;
  final RejectReason reason;
  @override
  String toString() => 'MoveRejected($move $reason @$timestampMs)';
}

class TrackingPaused extends MotionEvent {
  const TrackingPaused(super.timestampMs, this.issue);
  final TrackingIssue issue;
  @override
  String toString() => 'TrackingPaused($issue @$timestampMs)';
}

class TrackingResumed extends MotionEvent {
  const TrackingResumed(super.timestampMs);
  @override
  String toString() => 'TrackingResumed(@$timestampMs)';
}

/// Roadmap moves (docs/stages-roadmap.md §3) kept apart from [Move] so code
/// that switches exhaustively over [Move] keeps compiling. Opt-in only:
/// [MotionEngine] emits these only when its flags turn them on.
enum ExtraMove { barrierHold, stepLeft, stepRight }

class ExtraMoveStarted extends MotionEvent {
  const ExtraMoveStarted(this.move, super.timestampMs);
  final ExtraMove move;
  @override
  String toString() => 'ExtraMoveStarted($move @$timestampMs)';
}

class ExtraMoveHeld extends MotionEvent {
  const ExtraMoveHeld(this.move, super.timestampMs, this.heldMs);
  final ExtraMove move;
  final int heldMs;
  @override
  String toString() => 'ExtraMoveHeld($move ${heldMs}ms @$timestampMs)';
}

class ExtraMoveEnded extends MotionEvent {
  const ExtraMoveEnded(this.move, super.timestampMs, this.heldMs,
      {this.completed = true});
  final ExtraMove move;

  /// Total time the move was held (start to the last frame it was true).
  final int heldMs;

  /// False when the move was cut short by a tracking pause.
  final bool completed;
  @override
  String toString() => 'ExtraMoveEnded($move ${heldMs}ms @$timestampMs)';
}

class ExtraMoveRejected extends MotionEvent {
  const ExtraMoveRejected(this.move, super.timestampMs, this.reason);
  final ExtraMove move;
  final RejectReason reason;
  @override
  String toString() => 'ExtraMoveRejected($move $reason @$timestampMs)';
}

/// The life cycle of a plug-in gesture.
enum GesturePhase {
  /// A sustained gesture began (a twist, a hold).
  started,

  /// Emitted periodically while a sustained gesture continues.
  held,

  /// A sustained gesture finished.
  ended,

  /// A momentary gesture happened (a jump, a punch, a knee lift).
  fired,

  /// It looked like the gesture but did not count; see
  /// [GestureEvent.reason].
  rejected,
}

/// A discrete event from a plug-in detector (see `DetectorRegistry`).
///
/// New gestures use this one event type with a string id, so adding a
/// detector never changes the event model or any game that does not care
/// about it. The built-in core moves keep their typed events
/// ([MoveStarted] …) for existing games.
class GestureEvent extends MotionEvent {
  const GestureEvent(
    this.gesture,
    this.phase,
    super.timestampMs, {
    this.side,
    this.strength = 1,
    this.heldMs = 0,
    this.completed = true,
    this.reason,
  });

  /// The detector id, e.g. `jump`, `punch`, `twist`, `kneeLift`.
  final String gesture;
  final GesturePhase phase;

  /// The side that did it (a punching hand, a lifted knee, the direction of
  /// a twist), when the gesture has one.
  final BodySide? side;

  /// How big the gesture was, as a multiple of its trigger threshold
  /// (1 = just enough).
  final double strength;

  /// For [GesturePhase.held] and [GesturePhase.ended]: how long so far.
  final int heldMs;

  /// False when a sustained gesture was cut short by a tracking loss.
  final bool completed;
  final RejectReason? reason;

  @override
  String toString() => 'Gesture($gesture ${phase.name}'
      '${side == null ? '' : ' ${side!.name}'} @$timestampMs)';
}
