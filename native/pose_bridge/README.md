# pose_bridge

Native Android bridge for MotionQuest: CameraX front camera → MediaPipe Pose
Landmarker (lite, live-stream mode, GPU with CPU fallback).

- **Frames stay native.** Only 33 landmarks + visibility + timestamp cross the
  EventChannel; pixels are released right after inference and never stored.
- **Latest frame only.** `STRATEGY_KEEP_ONLY_LATEST`, and frames arriving while
  inference is busy are closed unprocessed — no queue.
- **Selfie coordinates.** Frames are rotated upright and mirrored, so the
  player's left is smaller `x`.
- The model (`pose_landmarker_lite.task`, Apache-2.0) is downloaded by the
  `downloadPoseModel` Gradle task before each build and is git-ignored.

iOS (Swift + Vision/MediaPipe) is planned for Stage 4.
