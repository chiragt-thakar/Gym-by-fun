# Self-view (mirror) technical research — Joynetic

Status: research notes, no repo edits. Facts marked [src] are from the cited pages; [mem] = from prior knowledge, verify before relying on it; [est] = estimate, measure on device.

## 0. Where the code is today (native/pose_bridge)
- `PosePipeline.kt` binds **only `ImageAnalysis`** (RGBA_8888, `STRATEGY_KEEP_ONLY_LATEST`, a `busy` flag that drops frames) to `DEFAULT_FRONT_CAMERA`. No Preview use case yet.
- Every frame is rotated by `rotationDegrees` and mirrored (`postScale(-1,1)`), then passed to `PoseLandmarker` (LIVE_STREAM, GPU with CPU fallback). So landmarks are already **normalised to an upright, mirrored analysis frame** of `frameW x frameH`, and those are sent with each landmark packet. That makes overlay alignment much easier (see 3).
- `docs/architecture.md:34` says "Only landmarks cross into Dart | Frames through Flutter cap Android near 24 fps; privacy." Self-view keeps to that: Dart only gets an integer texture id.

## 1. Showing the preview without pixels entering Dart
**Recommended: CameraX `Preview` → Flutter `TextureRegistry.SurfaceProducer` → Dart `Texture(textureId)` widget.**
- `SurfaceProducer` is the current embedder API for plugins that render to a Surface. It is recommended for Impeller and replaces `createSurfaceTexture()` (3.22, stable in 3.24). [src: docs.flutter.dev android-surface-plugins]
- Caveats [src, same page]:
  - Check `SurfaceProducer.handlesCropAndRotation()`. If it is false you must rotate yourself (camera previews may lose the transform matrix).
  - Surfaces can be destroyed when the app goes to the background. Use `setCallback` with `onSurfaceAvailable` / `onSurfaceCleanup` (3.27/3.29 renames). On cleanup, rebind or re-call `setSurfaceProvider`.
- How it connects: `Preview.setSurfaceProvider { req -> producer.setSize(w,h); req.provideSurface(producer.surface, exec) {...} }`. [src: KINTO Tech blog, CameraX Preview.SurfaceProvider docs]
- Privacy: the camera writes straight to a GPU buffer (gralloc) that the Flutter engine composites. No Dart object ever holds pixels, and no ByteBuffer crosses the platform channel. Rule 4 stays satisfied.
- **Alternative: PlatformView (`AndroidView` + CameraX `PreviewView`)**
  - Pros: PreviewView handles rotation and scaling itself. In SurfaceView mode you could call `SurfaceView.setSecure(true)` to protect only the camera layer [src: MS docs / BytePlus; must be set before the window attaches].
  - Cons: hybrid composition adds per-frame composition cost and threading issues, and Flame/Flutter overlays drawn on top of a PlatformView are slower on budget/older Android. TLHC mode renders to a texture anyway, which removes the setSecure benefit. [mem]
  - Verdict: use Texture. Keep PlatformView as a fallback only if per-layer secure turns out to be a hard requirement.

## 2. Mirroring
- CameraX `Preview.setMirrorMode(MIRROR_MODE_ON_FRONT_ONLY)` is the default, but it was **added in 1.7.0-alpha03 and is a no-op on API ≤32** (it relies on `OutputConfiguration.setMirrorMode`, API 33+). [src: developer.android.com Preview reference]. India budget fleet = many API 29–32 devices, so we cannot rely on it.
- **Recommended:** leave the buffer un-mirrored (set `MIRROR_MODE_OFF` where available, so behaviour is the same on every device) and mirror in Flutter with `Transform(transform: Matrix4.diagonal3Values(-1,1,1))` around the `Texture`. This is a compositor transform; Dart never touches pixels.
  - Rotation: if `handlesCropAndRotation == false`, native sends `sensorRotationDegrees` once (method-channel reply), and Dart wraps the Texture in a `RotatedBox` / `Transform.rotate`. The Flutter `camera` plugin does the same. [mem]
- Landmarks are already mirrored natively (`postScale(-1,1)`), so after the Dart-side mirror both the preview and the landmarks are in "selfie space". Do not mirror landmarks a second time.

## 3. Aligning landmarks with the displayed preview
Problem: Preview and ImageAnalysis can get different resolutions and aspect ratios, and so a different field of view. The widget then crops (BoxFit.cover) on top of that.
- **Step A — same FOV natively:** bind both in one `UseCaseGroup` with a shared `ViewPort` (aspect = the on-screen widget aspect, e.g. 9:16 portrait, and `Surface.ROTATION_0`). CameraX then gives both use cases a crop rect covering the same sensor region. [src: CameraX package summary: "ViewPort: the field of view of one or many UseCases"; same-FOV detail is mem, verify.]
  - ImageAnalysis frames arrive as the full buffer plus `ImageProxy.cropRect`. Today's code ignores cropRect, so it must either crop the bitmap to `cropRect` before rotating and mirroring (cheapest: crop in the same `createBitmap` call) or send cropRect as normalised numbers.
  - Recommendation: crop natively, so the landmark normalised space is the viewport.
- **Step B — the Dart mapping is pure math on landmarks, not pixels:**
  ```
  // landmarks normalised to viewport (upright, mirrored), aspect a_v = W/H
  // widget size (Sw, Sh); BoxFit.cover scale s = max(Sw/W, Sh/H)
  dx = (Sw - W*s)/2 ; dy = (Sh - H*s)/2
  screenX = dx + x*W*s ; screenY = dy + y*H*s
  ```
  - If the ViewPort aspect equals the widget aspect, this reduces to `x*Sw, y*Sh`.
  - Put it in `motion_core` as `ViewportMapper` (pure Dart, unit-tested with rotation 0/90/270 and mirror cases).
- **Step C — latency skew:** preview is about 1 frame behind the sensor. Landmarks arrive after inference (pipeline already reports `inference` ms; budget phones about 40–80 ms [est]). So overlays visibly lag a fast-moving body.
  - Mitigation: One Euro filter (already in motion_core) plus a short linear prediction of `inferenceMs` for anchors only, never for recogniser input. Keep anchored props loose: hats on head, aura on torso, nothing pinned to fingertips.
- Rotation: lock the game to portrait (or landscape, one only) for v1. That removes display-rotation changes from the matrix.

## 4. Background blur / replacement (MediaPipe Image Segmenter), native only
- Model: **SelfieSegmenter** square 256×256, or landscape 144×256. Pixel 6 full-pipeline latency: square ≈33.5 ms CPU / 35.2 ms GPU; landscape ≈34.2 / 33.6 ms. **GPU gives no speedup for this small model.** Output: float confidence mask and/or uint8 category mask; LIVE_STREAM mode is async via a listener. [src: ai.google.dev / developers.google.com image_segmenter]
- Budget-phone cost [est]: Helio G85 / SD 680 class is 2–3× slower than Pixel 6 on CPU, so about 60–100 ms per mask. Running it in series with pose (pose already uses most of the 33 ms frame) **cannot hold 30 fps**.
- Plan:
  1. Segmentation is **optional and off by default**. Enable it only on a device-tier allowlist, or after an on-device benchmark at first run (median over 30 frames < 25 ms).
  2. Run it at **≤10–15 Hz** on its own single-thread executor, using the same `busy`/drop-latest pattern (rule 3: never queue). Reuse the last mask between updates and blend over time (EMA on the mask) to hide shimmer.
  3. Use the landscape 144×256 model where the viewport is 9:16 (rotate the input). Ask for the confidence mask only.
  4. **Compositing happens on the GPU, natively**: camera frame + mask go through a GLES shader (blur via downsample plus 2-pass Gaussian at ¼ res, or background replacement with a bundled original image), and the result is written to the SurfaceProducer surface.
     - Hook point: CameraX `CameraEffect` + `SurfaceProcessor` (camera-core 1.3+), applied to the PREVIEW target. [mem, verify API on the pinned CameraX version]
     - The mask comes from the ImageAnalysis path and is uploaded as a small GL texture. Mask pixels never leave native.
  5. Fallback if no segmentation: plain preview with a stylised vignette or tint. That is cheap and still feels intentional.
- Alternative to blur: "studio backdrop", meaning the background is replaced with the level's sky or scenery. This is better for the game fantasy and hides home interiors (privacy win in shared households).

## 5. AR overlays anchored to the body (drawn in Flutter/Flame)
- Stack order (Dart):
  1. `Texture` (mirrored)
  2. Flame `GameWidget` with a transparent background
  3. HUD
- Anchors are computed from landmarks via `ViewportMapper`:
  - head: nose plus the ear midpoint; scale = shoulder width
  - shoulders/torso: centroid of 11, 12, 23, 24
  - wrists: 15, 16
  - feet: 27, 28 / 31, 32
- Hide an anchor when landmark visibility < 0.5. Fade it out over 150 ms; do not snap.
- Assets: original sprites/particles only (rule 10).
- An overlay never affects gameplay outcomes by itself (rule 6). Pickups are still resolved by game state.
- On a tracking pause (rule 5), fade the overlays and show the existing amber/explain UI. No lives lost.

## 6. Performance budget (target budget phone, 3–4 GB RAM, Helio G85 / SD 680 class)
| Stage | Target | Notes |
|---|---|---|
| Camera preview | 30 fps, ≤720p (1280×720) | Zero-copy GPU path; do not request 1080p. Use `ResolutionSelector` with a 720p cap for Preview. |
| Pose (ImageAnalysis) | 15–30 Hz, existing small analysis res | Unchanged. Optimisation [mem]: skip the `Bitmap.createBitmap` rotate+mirror and pass rotation via MediaPipe `ImageProcessingOptions.setRotationDegrees`, mirroring landmarks numerically. That saves a full-frame CPU copy per frame. |
| Segmentation | 0 (default) or 10–15 Hz | Tier-gated, see 4. |
| Composite shader | ≤3 ms GPU | Only when blur/replacement is on. |
| Flame render | 30 fps locked on budget tier | 60 fps only on high tier. |
- Thermal: use the ADPF Thermal API (API 30+).
  - `PowerManager.addThermalStatusListener` for status changes.
  - `getThermalHeadroom(10)` polled **no more than once every 10 s**, otherwise it returns NaN.
  - Headroom > ~1.0 means reduce immediately. [src: developer.android.com/games/optimize/adpf/thermal]
- Degrade ladder (each step logged, shown as a calm toast, **never** costs lives or progress):
  1. segmentation → 5 Hz, then off
  2. preview 720p → 480p
  3. Flame effects/particles reduced
  4. pose 30 → 15 Hz
  5. self-view off → avatar/silhouette mode
- Below API 30: use a fallback heuristic (sustained inference ms rising more than 30% over the session baseline).
- Memory: at most 1 analysis bitmap in flight (already enforced), 1 mask texture, and a Preview buffer queue owned by CameraX/engine. No extra frame copies.

## 7. "Silhouette / avatar only" privacy mode (toggle)
- Three modes in Settings, chosen at onboarding, switchable any time from the pause menu:
  1. **Avatar** (recommended default; works on every device): `Preview` is **not bound at all**, so the camera image is never rendered. Flame draws an original stylised avatar driven by landmarks.
  2. **Silhouette** (needs segmentation tier): the native shader outputs the mask filled with a flat colour or gradient over the game background. No camera colour pixels reach the texture.
  3. **Mirror** (opt-in): real camera image, optionally with blur/replacement.
- Mode switches rebind use cases natively (`unbind(preview)` / `bind`). Landmarks are unaffected, so gameplay continues without a pause.
- Persist the choice locally (shared prefs). It is a preference, so no server sync is needed. If synced, it is a boolean only.

## 8. What must never happen (enforceable controls)
1. **No `ImageCapture`, `VideoCapture`, `MediaRecorder` or `MediaCodec` encoder anywhere in pose_bridge.**
   - CI grep / lint rule fails the build on these imports.
   - Unit test: the use-case set passed to `bindToLifecycle` ⊆ {Preview, ImageAnalysis}.
2. **No camera pixels into Dart**:
   - Ban `ImageAnalysis` frame bytes, mask bytes or bitmaps on channels.
   - Ban `RenderRepaintBoundary.toImage()` / `Scene.toImage()` / `toImageSync()` on any subtree containing the camera `Texture`. A Texture layer may be captured into the image. [mem — treat as possible and ban]
   - Put the Texture outside every `RepaintBoundary` used for capture.
3. **Share clips / screenshots are re-rendered from game state + avatar**, never a capture of the screen or of the composed widget tree.
   - The share-clip generator renders a Flame scene (avatar driven by recorded landmarks or score data) to an offscreen canvas.
   - Landmark recordings stay local unless the existing recorder rules allow otherwise.
4. **FLAG_SECURE options:**
   - (a) Window `FLAG_SECURE` while Mirror mode is visible: blocks screenshots, screen recording, casting to non-secure displays and the recents thumbnail [src: OWASP MASTG-BEST-0014]. Cost: users can't screenshot their score; mitigate with the in-app share card (3).
   - (b) `Activity.setRecentsScreenshotEnabled(false)` (API 33+) hides only the recents thumbnail [src: XDA]. Apply it always during a session; it is cheap.
   - (c) `SurfaceView.setSecure(true)` protects only that view but requires a SurfaceView/PlatformView. It is **not available with the Texture approach**, because Texture content composites into Flutter's own surface.
   - Recommendation: (a) when Mirror mode is on, plus (b) always. Avatar mode needs no FLAG_SECURE.
   - Android 14+ `Activity.registerScreenCaptureCallback` can detect (not block) screenshots [mem]. Optional: show "camera layer is hidden from screenshots" education.
5. No frames to disk (no cache, no debug dumps in release; guard debug-only frame dumps behind `BuildConfig.DEBUG` and exclude from release via a lint check). No frames in crash reports or analytics.
6. The camera stops (unbinds) on pause, background or lock. CameraX is lifecycle-bound already; also call `unbindAll` in `onSurfaceCleanup`.
7. A visible "camera on" indicator in the HUD whenever any camera use case is bound. Android 12+ also shows the system privacy dot.

## 9. API sketch
### Kotlin (pose_bridge)
```kotlin
// PoseBridgePlugin: new methods on "motionquest/pose_bridge"
//  "startSelfView" {mode: "mirror"|"silhouette", blur: Boolean}
//      -> {textureId: Long, width: Int, height: Int, rotation: Int, handlesCropAndRotation: Boolean}
//  "stopSelfView" -> null   (unbinds Preview; landmarks keep flowing)
//  "setSecure" {on: Boolean} -> null (window FLAG_SECURE)

class SelfView(
    private val textures: TextureRegistry,
    private val activity: Activity,
) {
    private var producer: TextureRegistry.SurfaceProducer? = null
    val preview: Preview = Preview.Builder()
        .setResolutionSelector(ResolutionSelector.Builder()
            .setResolutionStrategy(ResolutionStrategy(Size(1280, 720),
                ResolutionStrategy.FALLBACK_RULE_CLOSEST_LOWER)).build())
        .build()

    fun attach(exec: Executor): Long {
        val p = textures.createSurfaceProducer().also { producer = it }
        p.setCallback(object : TextureRegistry.SurfaceProducer.Callback {
            override fun onSurfaceAvailable() { preview.setSurfaceProvider(exec, provider) }
            override fun onSurfaceCleanup() { preview.setSurfaceProvider(null) }
        })
        preview.setSurfaceProvider(exec, provider)
        return p.id()
    }

    private val provider = Preview.SurfaceProvider { req ->
        val p = producer ?: return@SurfaceProvider req.willNotProvideSurface()
        p.setSize(req.resolution.width, req.resolution.height)
        req.provideSurface(p.surface, exec) { /* surface released by CameraX */ }
    }

    fun release() { preview.setSurfaceProvider(null); producer?.release(); producer = null }
}

// PosePipeline bind: same FOV for preview + analysis
val viewPort = ViewPort.Builder(Rational(9, 16), Surface.ROTATION_0).build()
val group = UseCaseGroup.Builder()
    .setViewPort(viewPort)
    .addUseCase(analysis)
    .apply { if (selfView != null) addUseCase(selfView.preview) }
    // .addEffect(segmentationEffect)  // CameraEffect(PREVIEW) w/ GL SurfaceProcessor, tier-gated
    .build()
provider.bindToLifecycle(owner, CameraSelector.DEFAULT_FRONT_CAMERA, group)
// analyze(): crop to image.cropRect before rotate+mirror so landmarks are viewport-normalised.

// Secure window (main thread)
fun setSecure(on: Boolean) = if (on) activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                             else activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
// API 33+: activity.setRecentsScreenshotEnabled(false) at session start.
```
### Dart (pose_bridge/lib + app)
```dart
enum SelfViewMode { avatar, silhouette, mirror }

class SelfViewHandle {           // only ints/bools cross the channel
  final int textureId; final int width, height, rotation; final bool handlesCropAndRotation;
}

abstract class PoseBridge {
  Future<SelfViewHandle?> startSelfView(SelfViewMode mode, {bool blur = false}); // null for avatar
  Future<void> stopSelfView();
  Future<void> setSecureWindow(bool on);
}

class SelfViewLayer extends StatelessWidget {   // app/
  const SelfViewLayer(this.h, {super.key});
  final SelfViewHandle h;
  @override
  Widget build(BuildContext c) => ClipRect(
        child: FittedBox(fit: BoxFit.cover, child: SizedBox(
          width: h.width.toDouble(), height: h.height.toDouble(),
          child: Transform(alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(-1, 1, 1),          // mirror
            child: RotatedBox(
              quarterTurns: h.handlesCropAndRotation ? 0 : h.rotation ~/ 90,
              child: Texture(textureId: h.textureId))))));
}

// motion_core (pure Dart, tested): maps viewport-normalised landmarks to widget coords
class ViewportMapper {
  ViewportMapper({required this.srcW, required this.srcH, required this.dstW, required this.dstH});
  final double srcW, srcH, dstW, dstH;
  Offset map(double x, double y) {
    final s = math.max(dstW / srcW, dstH / srcH);
    return Offset((dstW - srcW * s) / 2 + x * srcW * s, (dstH - srcH * s) / 2 + y * srcH * s);
  }
}
// Stack: [SelfViewLayer (if mirror/silhouette), GameWidget(transparent bg), Hud]
```
(Avoid importing Flutter `Offset` in motion_core — use its own Point type.)

## 10. Proposed docs/architecture.md changes (rule 4 still satisfied)
New decision rows:
| Decision | Why |
|---|---|
| Self-view is a native GPU texture (CameraX Preview → SurfaceProducer → `Texture`); Dart receives only a texture id | Pixels never enter the Dart heap or channels; zero-copy; rule 4 holds |
| Preview and ImageAnalysis share one ViewPort; landmarks are normalised to the cropped, upright, mirrored viewport | One coordinate space for overlays; mapping is pure math in motion_core |
| Mirroring for display is a Dart compositor transform; landmarks are mirrored once, natively | `setMirrorMode` is a no-op on API ≤32 |
| Segmentation/blur/silhouette runs natively (GL), tier-gated, ≤15 Hz, drop-latest | Budget-phone cost; rule 3 |
| Self-view modes: avatar (default), silhouette, mirror; avatar never binds Preview | Privacy in shared homes; works on every tier |
| Only Preview + ImageAnalysis may ever be bound; no capture/encoder APIs in pose_bridge (CI check) | Video never stored or uploaded |
| FLAG_SECURE while mirror is visible; recents screenshot disabled during sessions; share clips are re-rendered from game state, never screen-captured | Camera layer can't leak via screenshots, recording, recents or share |
| Thermal degrade ladder (ADPF) ends at avatar mode; never costs lives | Rule 5 |
Also:
- Rewrite the line-34 wording to: "Only landmarks (and an opaque texture id) cross into Dart."
- docs/security.md: add controls 8.1–8.7.
- docs/game-design.md: add the anchor/visibility thresholds (0.5, 150 ms fade).

## Sources
- Flutter — New APIs for Android plugins that render to a Surface: https://docs.flutter.dev/release/breaking-changes/android-surface-plugins
- Flutter FlutterRenderer javadoc: https://api.flutter.dev/javadoc/io/flutter/embedding/engine/renderer/FlutterRenderer.html
- KINTO Tech blog (CameraX → Flutter Texture/PlatformView): https://blog.kinto-technologies.com/posts/2024-12-17-flutter-platform-view-android/ , https://techplay.jp/blog/24844
- CameraX Preview.SurfaceProvider: https://developer.android.com/reference/androidx/camera/core/Preview.SurfaceProvider
- CameraX Preview (setMirrorMode, API ≤32 no-op): https://developer.android.com/reference/androidx/camera/core/Preview.html
- CameraX package summary (ViewPort, UseCaseGroup): https://developer.android.com/reference/androidx/camera/core/package-summary
- MediaPipe Image Segmenter guide (SelfieSegmenter latency, model sizes, masks): https://ai.google.dev/mediapipe/solutions/vision/image_segmenter , https://developers.google.com/edge/mediapipe/solutions/vision/image_segmenter
- ADPF Thermal API: https://developer.android.com/games/optimize/adpf/thermal
- OWASP MASTG-BEST-0014 (FLAG_SECURE): https://mas.owasp.org/MASTG/best-practices/MASTG-BEST-0014/
- SurfaceView.setSecure: https://learn.microsoft.com/de-de/dotnet/api/android.views.surfaceview.setsecure?view=net-android-37.0 ; https://docs.byteplus.com/vi/docs/byteplus-vos/docs-anti-screen-recording
- Android 13 setRecentsScreenshotEnabled: https://www.xda-developers.com/android-13-developers-disable-app-previews/
