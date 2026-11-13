# Performance

Joynetic must play smoothly on budget Android phones (2–3 GB RAM, little
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

**Game renderer and HUD (`app/lib/game/forest_game.dart`)**
- `ForestPainter` runs every frame and now allocates no `Paint`, `Path`,
  `Shader` or `List` per frame. Paints are cached per `SceneTheme` (an
  `Expando`, so themes are never kept alive). Fixed-colour paints are static,
  and only stroke widths that scale with depth are changed before a draw. Two
  static scratch `Path`s are reused with `reset()`. The sky gradient shader is
  rebuilt only when the horizon height changes. The visuals are unchanged.
- Visible encounters: the plan is sorted by `arriveMs`, so the painter
  binary-searches the first encounter with `arriveMs >= clock - 350`. It then
  walks forward while `arriveMs - (warningMs + wideBlockExtraMs) <= clock`
  and draws that window back to front (far first). This replaces a
  `where().toList()..sort()` that ran every frame.
- `ForestGame` keeps one painter and updates its per-frame fields in place.
- HUD: `hud.value` is assigned only when a shown field changed. Progress is
  quantised to 1/500 (well under 1 dp on the bar), so the Flutter HUD rebuilds
  a few times a second instead of 60 times.
- `test/perf_test.dart` paints 600 frames for each of the 4 themes (2,400 in
  total, sweeping the whole level). This takes well under a second locally,
  and the test bound is 8 s. The test also checks that the HUD is not
  reassigned when nothing changed.

**Widgets**
- `BodyMap`: every paint is a static final. Geometry was already cached per
  style.
- `ForestBackdrop`: the glow `Paint` is cached together with its shader. It
  is no longer created on each paint.
- Home world map: `ListView.builder` (header, one item per world, footer), so
  world cards are built lazily. Each card sits in its own `RepaintBoundary`.

## Storage

Install size matters on budget phones with little free space.

- **Dependencies:** every package in `app/pubspec.yaml` was checked against
  `package:<name>/` imports under `app/lib`. All of them (flutter_riverpod,
  go_router, flame, flame_audio, http, path_provider, shared_preferences,
  flutter_tts, motion_core, game_director, pose_bridge) are in use, so none
  were removed.
- **CI release build** (`.github/workflows/ci.yml`):
  `flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64 --obfuscate --split-debug-info=build/symbols --tree-shake-icons`.
  - `--split-per-abi` + ARM-only targets: each phone downloads one ABI.
  - `--obfuscate --split-debug-info`: Dart symbol tables leave the APK. The
    symbols are uploaded as the `motionquest-debug-symbols` artifact. Keep the
    file for each release, because without it crash stack traces can't be
    read (`flutter symbolize -i <trace> -d <symbols>/app.android-arm64.symbols`).
  - `--tree-shake-icons`: only the Material icon glyphs we use are bundled
    (on by default for release builds; we pass it explicitly).
  - The "Install size budget" step prints each APK's size in MB (two decimals)
    and fails if any APK is 150 MB or larger.

## Asset sizes (bundled in the APK)

| Asset | Size |
|---|---|
| `app/assets/levels` (11 JSON) | 82.7 KB |
| `app/assets/audio` (8 WAV cues) | 141.0 KB |
| **Total `app/assets`** | **223.7 KB** |

The cues are already 22.05 kHz, mono, 16-bit, 0.12–0.62 s each. The highest
tone is 1.76 kHz, so 16 kHz would be safe for the tones, but it would cut the
top of the noise "whoosh". It would save only about 39 KB before zip
compression, which is under 0.1 % of an APK dominated by the MediaPipe native
libraries and the `.task` model. We left the cues as they are. Revisit this
only if assets grow, for example by moving to OGG/Opus.

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
