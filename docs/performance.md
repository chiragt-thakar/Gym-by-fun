# Performance

MotionQuest must play smoothly on budget Android phones (2–3 GB RAM, little
free storage). These budgets are release gates, not aspirations.

## Budgets

| Metric | Budget | Where it is measured |
|---|---|---|
| Pose inference (capture → landmarks) | ≤ 33 ms (≤ 40 ms on budget tier) | `inferenceMs` from the native bridge |
| Capture → game action | < 150 ms | debug screen "capture→event" (`PerfStats.pipelineMs`) |
| Pose frame rate | ≥ 24 fps (≥ 15 fps budget tier, game slows down) | `PerfStats.fps` |
| Dart motion pipeline | < 0.3 ms/frame on CI (≈ 0.005 ms measured) | `packages/motion_core/test/perf_benchmark_test.dart` |
| Install size | < 150 MB per APK | CI step "Install size budget" |

## What was optimised

**Dart hot path (runs every frame, `packages/motion_core`)**
- `LandmarkSmoother` keeps its One Euro filters in flat lists (no map lookups)
  and allocates exactly one fixed-length landmark list per frame. The list is
  never reused, because the recorder and debug overlay may keep frames.
- `BodyFeatures.from` computes leg visibility without a temporary list.
- `QualityGate` computes hip/shoulder centres inline (no midpoint objects, no
  `math.pow`).
- `MotionEngine.process` appends to a reused scratch buffer. Frames that produce
  no events (most frames) return a shared const empty list. Frames that do
  produce events return a fresh copy the caller may keep. The behaviour is
  unchanged: the replay accuracy gate still passes.

**App (`app/lib/services`)**
- `PerfStats` uses fixed 60-slot ring buffers with running sums. It no longer
  uses `removeAt(0)` list shifting or averages by `reduce`.
- `MotionSession` reuses a single `Stopwatch`. The move counter maps are built
  once per session, and per-frame work only touches existing entries.
- `Voice` loads only the 8 small cue WAVs, once per app run, even when the
  language changes. Cue audio and TTS fail independently, and no audio or TTS
  error can throw into gameplay.

**Native (`native/pose_bridge`)**
- Latest frame only: `STRATEGY_KEEP_ONLY_LATEST`, and frames are dropped while
  the landmarker is busy (rules 3 and 4). Only landmark doubles cross into Dart.
- At most one upright RGBA bitmap exists at a time. It is freed in `onResult`
  after `input.close()` and before the busy flag is released, and on the error
  path if `detectAsync` never accepted it. The raw camera bitmap is recycled as
  soon as the rotated copy exists.
- GPU delegate with CPU fallback. The budget tier analyses 360×480 instead of
  480×640.

**Build / size (`app/android`)**
- R8 minify + resource shrinking are on for release.
- The release ships ARM only (`arm64-v8a`, `armeabi-v7a`). The MediaPipe native
  libs dominate the APK, so dropping x86/x86_64 saves a lot. CI builds
  `--split-per-abi --target-platform android-arm,android-arm64`, so each phone
  downloads only its own ABI. The fat release APK uses `ndk.abiFilters` instead
  (AGP rejects both at once). Play uses the app bundle, which splits by ABI
  automatically.
- `android:hardwareAccelerated="true"`. `largeHeap` is deliberately off: we
  stay within the normal heap instead of asking the OS for more RAM.
- The `.task` model is stored uncompressed so MediaPipe can memory-map it.

## How to measure on a device

1. Install a release APK (`flutter build apk --release --split-per-abi`) or a
   profile build (`flutter run --profile`). Never judge performance from
   debug builds.
2. Settings → Developer → Tracking debug screen. It shows fps, inference ms,
   Dart ms and capture→event latency (rolling 60 frames), plus the delegate
   (gpu/cpu) and the suggested device tier.
3. Play for 2 minutes in a normally lit room and note the steady-state
   numbers. Check them against the table above.
4. Memory: `adb shell dumpsys meminfo app.motionquest` during a run. The
   PSS should stay flat over time; growth means a bitmap leak.
5. Frame pacing: Flutter DevTools performance tab in a profile build.

## Low-tier behaviour

`PerfStats.tier` classifies the device from live numbers: upper-mid is
≥ 27 fps and ≤ 25 ms inference, mid is ≥ 22 fps and ≤ 40 ms, and anything
below that is budget. On the budget tier:

- the bridge analyses 360×480 frames;
- tracking problems never cost lives or progress: the game slows down and
  explains why (rule 5);
- note: the quality gate's 256 px minimum body size uses the real image
  height, so at 480 px tall the player must fill ≥ 53 % of the frame (vs ≥ 40 %
  at 640 px). If field tests show "too far" pauses on budget phones, tune
  `minBodyPixels` per tier, and only while the replay gate stays green.
