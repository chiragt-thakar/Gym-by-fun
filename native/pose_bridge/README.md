# pose_bridge

Native Android bridge for MotionQuest: CameraX front camera → MediaPipe Pose
Landmarker (live-stream mode; Full on fast phones, Lite otherwise; GPU with
CPU fallback).

- **Frames stay native.** Only 33 landmarks + visibility + timestamp cross the
  EventChannel; pixels are released right after inference and never stored.
- **Latest frame only.** `STRATEGY_KEEP_ONLY_LATEST`, and frames arriving while
  inference is busy are closed unprocessed — no queue.
- **Selfie coordinates.** Frames are rotated upright and mirrored, so the
  player's left is smaller `x`.
- **One 3:4 viewport.** Analysis and the optional Preview share a 3:4
  portrait `ViewPort`; analysis is cropped to it, so landmarks match the
  mirror exactly.
- **Camera mirror (`PoseMirror`, view type `motionquest/self_view`).** A
  CameraX `PreviewView` platform view, bound only when `start(selfView: true)`.
  Pixels go camera → screen natively; `FLAG_SECURE` is set while it is shown.
- The models (`pose_landmarker_lite.task`, `pose_landmarker_full.task`,
  Apache-2.0) are downloaded by the `downloadPoseModel` Gradle task before
  each build and are git-ignored.

iOS (Swift + Vision/MediaPipe) is planned for Stage 4.
