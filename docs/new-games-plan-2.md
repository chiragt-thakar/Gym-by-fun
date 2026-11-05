# New self-view games plan (DRAFT): Mirror Mela, Tapeball Tamasha, Pataka Pose

> **Status: draft.** This file combines the six research and design notes as written. A reconciled final version is in progress and will replace it.
> Known reconciliations still to apply in the final version:
> - **Coach Kavi is one character:** the original Bengal fox in a teal running vest (§3). Pataka Pose's "paper-lantern puppet" Kavi is dropped; Kavi hosts it.
> - **Self-view modes:** Avatar (default), Silhouette, Mirror (opt-in). Camera pixels never enter Dart (native texture). Screenshots are blocked while Mirror is visible. Share clips are rendered from landmarks only.
> - **Adults 18+ only.** Party modes carry no "family" or minors framing.
> - **Camera limits:** end poses only; side, overhead or low targets; no motion toward the camera; no fast combos.
> - **Claims:** general fitness information only. No calorie, weight-loss, treat or cure claims.
> - The shared BeatEngine and schema v2 come from `docs/new-games-plan.md`.

## Contents
1. Self-view technology and privacy
2. Modern visual language ("Lantern Pulse")
3. Characters and avatars
4. Game C: Mirror Mela (AR mirror arcade)
5. Game D: Tapeball Tamasha (self-view street cricket + Raid Rush + Shuttle Rally)
6. Game E: Pataka Pose (party pose game)


---

## Self-view (mirror) technical research — MotionQuest

Status: research notes, no repo edits. Facts marked [src] are from the cited pages; [mem] = from prior knowledge, verify before relying on it; [est] = estimate, measure on device.

### 0. Where the code is today (native/pose_bridge)
- `PosePipeline.kt` binds **only `ImageAnalysis`** (RGBA_8888, `STRATEGY_KEEP_ONLY_LATEST`, a `busy` flag that drops frames) to `DEFAULT_FRONT_CAMERA`. No Preview use case yet.
- Every frame is rotated by `rotationDegrees` and mirrored (`postScale(-1,1)`), then passed to `PoseLandmarker` (LIVE_STREAM, GPU with CPU fallback). So landmarks are already **normalised to an upright, mirrored analysis frame** of `frameW x frameH`, and those are sent with each landmark packet. That makes overlay alignment much easier (see 3).
- `docs/architecture.md:34` says "Only landmarks cross into Dart | Frames through Flutter cap Android near 24 fps; privacy." Self-view keeps to that: Dart only gets an integer texture id.

### 1. Showing the preview without pixels entering Dart
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

### 2. Mirroring
- CameraX `Preview.setMirrorMode(MIRROR_MODE_ON_FRONT_ONLY)` is the default, but it was **added in 1.7.0-alpha03 and is a no-op on API ≤32** (it relies on `OutputConfiguration.setMirrorMode`, API 33+). [src: developer.android.com Preview reference]. India budget fleet = many API 29–32 devices, so we cannot rely on it.
- **Recommended:** leave the buffer un-mirrored (set `MIRROR_MODE_OFF` where available, so behaviour is the same on every device) and mirror in Flutter with `Transform(transform: Matrix4.diagonal3Values(-1,1,1))` around the `Texture`. This is a compositor transform; Dart never touches pixels.
  - Rotation: if `handlesCropAndRotation == false`, native sends `sensorRotationDegrees` once (method-channel reply), and Dart wraps the Texture in a `RotatedBox` / `Transform.rotate`. The Flutter `camera` plugin does the same. [mem]
- Landmarks are already mirrored natively (`postScale(-1,1)`), so after the Dart-side mirror both the preview and the landmarks are in "selfie space". Do not mirror landmarks a second time.

### 3. Aligning landmarks with the displayed preview
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

### 4. Background blur / replacement (MediaPipe Image Segmenter), native only
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

### 5. AR overlays anchored to the body (drawn in Flutter/Flame)
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

### 6. Performance budget (target budget phone, 3–4 GB RAM, Helio G85 / SD 680 class)
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

### 7. "Silhouette / avatar only" privacy mode (toggle)
- Three modes in Settings, chosen at onboarding, switchable any time from the pause menu:
  1. **Avatar** (recommended default; works on every device): `Preview` is **not bound at all**, so the camera image is never rendered. Flame draws an original stylised avatar driven by landmarks.
  2. **Silhouette** (needs segmentation tier): the native shader outputs the mask filled with a flat colour or gradient over the game background. No camera colour pixels reach the texture.
  3. **Mirror** (opt-in): real camera image, optionally with blur/replacement.
- Mode switches rebind use cases natively (`unbind(preview)` / `bind`). Landmarks are unaffected, so gameplay continues without a pause.
- Persist the choice locally (shared prefs). It is a preference, so no server sync is needed. If synced, it is a boolean only.

### 8. What must never happen (enforceable controls)
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

### 9. API sketch
#### Kotlin (pose_bridge)
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
#### Dart (pose_bridge/lib + app)
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

### 10. Proposed docs/architecture.md changes (rule 4 still satisfied)
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

### Sources
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

---

## 2 — Modern UI / visual language for three self-view games (MotionQuest)

Scope: 2025–2026 trend scan (cited) and an original visual language ("Lantern Pulse") for the
self-view games, where the live front-camera image is the background. It extends the existing
"Forest Lantern" theme (`app/lib/app/theme.dart`) and does not replace it.
Context checked: theme.dart tokens; `docs/screenshots/10-game-forest-escape.png`, which shows a
portrait 1080x2280 flat-vector runner, a warm sky gradient, a fox-orange hero with a teal scarf,
and chunky shapes.

Caveat: most 2026 "trend" sources are agency blogs. Treat them as directional only. The
legibility and accessibility guidance comes from research and platform guidelines, and is firmer.

---

### 1. Trend scan (2025–2026)

| Trend | What sources say | Use for MotionQuest? |
|---|---|---|
| Fewer competing CTAs, clearer icon language, stronger contrast in live events | [pixune 2026 review](https://pixune.com/blog/best-examples-mobile-game-ui-design/), [appfollow 2026](https://appfollow.io/blog/mobile-gaming-trends-2026), [ejaw 2026](https://ejaw.net/how-mobile-game-ux-interface-design-drives-player-retention-in-2026) | **Yes, core.** At 2 m away, one message at a time. |
| Depth layers, animated menus, micro-interactions, dark mode | [adrydapp 2026 guide](https://adrydapp.blogspot.com/2026/03/mobile-game-ui-design-trends-2026-guide.html), [barrettmedia 2026](https://barrettmedia.com/2026/01/21/graphic-design-for-video-games-trends-players-notice-in-2026/) | Yes. Fake depth with offset shadows and parallax, not blur. |
| Bold, oversized type as the main visual; kinetic typography; motion-first polish | [line25 2026](https://line25.com/articles/web-design-trends-2026/), [theedigital 2026](https://www.theedigital.com/blog/web-design-trend), [studiomeyer 2026](https://studiomeyer.io/en/blog/webdesign-trends-2026) | **Yes.** Big numerals and words that "punch in". Respect reduced-motion. |
| "Glassmorphism 2.0" (layered blur, context transparency) | [line25 2026](https://line25.com/articles/web-design-trends-2026/), [theedigital](https://www.theedigital.com/blog/web-design-trend) | **Look only, without the blur.** Real-time blur over a camera texture is costly on budget GPUs. Use a "tinted plate" instead (see section 4). |
| Material 3 Expressive: spring motion, shape morphing, variable-font axes as feedback, varied corner radii | [Android dev: M3 Expressive design language](https://developer.android.com/design/ui/wear/guides/get-started/design-language) | Yes. Spring physics and shape morphs are cheap. Avoid a weight-axis variable font because the app uses system fonts only (see type). |
| Accessibility: scalable text, colourblind support, simplified interactions | [pixune](https://pixune.com/blog/best-examples-mobile-game-ui-design/), [Xbox Accessibility Guidelines](https://learn.microsoft.com/en-us/gaming/accessibility/guidelines), [gameaccessibilityguidelines.com](https://gameaccessibilityguidelines.com/?p=12), [Unity blog](https://unity.com/blog/video-game-accessibility-basics) | **Mandatory.** 4.5:1 (normal) and 3:1 (large) contrast, 7:1 for a high-contrast mode, colour never the only cue, reduced motion follows the OS. |
| Indian contemporary design: richer, deeper, warmer palettes; high contrast; confident maximal colour replacing stark white | [Asian Paints ColourNext 2025 "India Everywhere"](https://www.beautifulhomes.asianpaints.com/magazine/decor-advice/trends/this-asian-paints-colournext-story-is-about-india-everywhere), [Cosmopolitan India on ColourNext 2025](https://www.cosmopolitan.in/life/features/story/asian-paints-colournext-2025-the-design-trends-that-will-define-this-year-1177034-2025-03-06), [designpataki](https://www.designpataki.com/?p=45875) | Yes, as a mood: deep jewel and earth bases with saturated festive accents (marigold, kumkum red, peacock teal). Do not use literal motifs as decoration everywhere. |
| AR text legibility over complex/video backgrounds | [Gabbard et al. 2007 IEEE VR, text drawing styles](https://ed-swan.github.io/publications/papers/2007_Gabbard-etal_Text-Drawing-Styles_IEEE-VR.pdf), [Glanceable typography over complex backgrounds (PubMed 32425139)](https://pubmed.ncbi.nlm.nih.gov/32425139/), [Google Fonts: type in AR/VR](https://fonts.google.com/knowledge/using_type_in_ar_and_vr/introducing_ar_vr), [Brown VR wiki, reading in AR](https://www.vrwiki.cs.brown.edu/applications-of-vr/reading-in-vr/reading-in-ar) | **Key evidence.** A solid or semi-opaque billboard behind text is the most robust option. Outlines help. Scrim plus blur is best, but we drop the blur for cost. On video see-through, a thin outline around the text works well. |
| AR fitness drill app case study | [uxdesign.cc AR athlete case study](https://uxdesign.cc/re-designing-a-mobile-ar-experience-for-athletes-a-ux-case-study-11b1be491166) | Bold saturated colours, humanist sans, gestures instead of on-screen buttons. This matches our pose-driven input. |
| 10-foot (TV) UI sizing | [Amazon Fire TV UX guidelines](https://developer.amazon.com/docs/fire-tv/design-and-user-experience-guidelines.html), [10-foot UI (Wikipedia)](https://en.wikipedia.com/wiki/10-foot_user_interface), [designing a 10ft UI](https://pascalpotvin.medium.com/designing-a-10ft-ui-ae2ca0da08b7) | Size by angle subtended, not px. Avoid thin weights (100–300). Light text on dark reads better at distance. |

---

### 2. Colour system: "Lantern Pulse" (an extension of Forest Lantern)

Principle: keep Forest Lantern for the shell (menus, map, results). Add a **camera-overlay
palette** that only ever sits on a **plate** (a solid or tinted backing) or carries a **dark
outline**, because the camera image behind it can be any colour.

#### 2a. Kept as-is (do not change; existing widgets depend on them)
| Token | Hex | Role |
|---|---|---|
| `Lantern.night` | `#0B1611` | Shell background, plate base |
| `Lantern.canopy` | `#13241C` | Panels |
| `Lantern.moss` | `#1C3328` | Raised panels |
| `Lantern.ridge` | `#2A4A3A` | Borders |
| `Lantern.glow` | `#FF9A3C` | Primary (hero orange) |
| `Lantern.ember` | `#E0701F` | Pressed |
| `Lantern.scarf` | `#3FD0C0` | Secondary teal |
| `Lantern.parchment` | `#F6EEDC` | Main text |
| `Lantern.fog` | `#B9C9BF` | Secondary text |
| `Lantern.warning` | `#FFC857` | Amber |
| `Lantern.danger` | `#FF6B5A` | Danger |
| `Lantern.onGlow` | `#231203` | Text on orange |

#### 2b. New overlay tokens (proposed `LanternPulse` class, additive)
| Token | Hex | Use | Contrast note |
|---|---|---|---|
| `plate` | `#0B1611` at 78% alpha (`#C70B1611`) | Backing for every HUD element over camera | The night base at 78% keeps parchment text above about 10:1 on most video. Raise to 88% if the auto-exposure frame is bright. |
| `plateSolid` | `#0B1611` | High-contrast mode / bright rooms | parchment on night is about 16:1 |
| `stroke` | `#050B08` (= `chunkyShadow`) | 3–4 dp outline on glyphs and icons outside plates | Dark outline plus light fill reads on any background |
| `marigold` | `#FFB627` | Combo, streak, "good" accents (festive, warm) | On night about 11:1 |
| `kumkum` | `#FF4D6D` | Hot accent, boss, timer critical. Not for errors alone. | On night about 5.6:1. Pair with an icon. |
| `peacock` | `#00C2B8` | Player-2 or "target zone" | On night about 8.6:1 |
| `indigoDusk` | `#2B2F77` | Deep backdrop gradient stop (celebration cards) | Use behind parchment only |
| `mehendi` | `#9BCB3C` | "Perfect" / correct-rep tick | On night about 9.5:1 |
| `chalk` | `#FFFFFF` | Numerals on plates (max punch) | |
| `trackingAmber` | = `warning #FFC857` | "Can't see you" state (slow-down, never punish) | Always shown with a person-outline icon |

Contrast values are approximate (WCAG relative luminance) and need checking with a contrast
tool before shipping.

#### 2c. Per-game accent pairs (each game gets one hero accent plus the shared neutrals)
Keep `glow` as the brand constant. Each game swaps only the **accent** and **gradient**.
| Game slot | Accent A | Accent B | Gradient (for title cards / celebration only, never behind live text without a plate) |
|---|---|---|---|
| Game 1 (warm, rhythm/combo) | `#FFB627` marigold | `#FF4D6D` kumkum | `#FF9A3C → #FF4D6D` |
| Game 2 (cool, precision/zone) | `#00C2B8` peacock | `#3FD0C0` scarf | `#0F3E39 → #00C2B8` |
| Game 3 (night, arcade/neon-ish) | `#B98CFF` lilac | `#9BCB3C` mehendi | `#2B2F77 → #B98CFF` |

Colourblind safety: do not pair kumkum and mehendi as the only "bad/good" distinction. Good is
always tick plus upward motion. Miss is a soft grey ring plus a sideways nudge.

---

### 3. Type scale for 2 m readability

#### 3a. Maths
- At 20/20 acuity a letter is just resolvable at 5 arcmin, which is about **2.9 mm cap height at
  2 m**. Comfortable glance-reading while moving, sweaty and possibly without glasses needs
  about 3–4x that.
- Android: 1 dp is about 0.16 mm (1/160 in; it varies by density bucket). System sans cap height
  is about 0.70–0.72 of the em.
- `fontSize_dp ≈ capHeight_mm / 0.72 / 0.159`

| Role | Target cap height | Font size (dp) | Weight | Use |
|---|---|---|---|---|
| `hudHero` | 12 mm | **104** | w900, tabular figures | Countdown 3-2-1, rep count, "GO" |
| `hudPrimary` | 9 mm | **80** | w900 | Score, combo multiplier |
| `hudLabel` | 6 mm | **52** | w800, +0.5 letterSpacing, ALL CAPS ≤ 2 words | "COMBO", "LEFT", move name |
| `hudFloor` | 4.5 mm | **40** | w800 | The smallest text allowed while playing |
| shell `displaySmall` (existing) | about 5 mm | 44 | w900 | Unchanged |
| shell body (existing) | about 2 mm | 17–19 | w400 | Hand-held use only (setup, results) |

Rules:
- Max **3 words** on screen during play, and **one** primary message at a time.
- Use numerals with `FontFeature.tabularFigures()` so counters don't jitter.
- Keep system fonts (offline-first, as in theme.dart). Get distinctiveness from w900, tight
  negative tracking on numerals (-2) and wide tracking on labels (+0.5 to +1).
- Never use weights below w600 in-game. Thin weights vanish at distance
  ([10ft UI guidance](https://pascalpotvin.medium.com/designing-a-10ft-ui-ae2ca0da08b7)).
- Respect the system text scale up to 1.3x in the shell. In the HUD, clamp, because layout must
  not reflow mid-move. Offer an in-game "Large HUD" toggle (+20%) instead
  ([Xbox XAG text size](https://learn.microsoft.com/en-us/gaming/accessibility/guidelines)).
- Hindi/Devanagari labels: system Noto Sans Devanagari has taller ascenders and a headline bar.
  Allow 1.25x line height and test that 52 dp labels still fit.

---

### 4. HUD layouts over the live camera view

Portrait (matches current screenshots). The phone is on the floor 2 m away, so the player sees a
small screen. Use **edges and centre only**, with big shapes.

```
┌──────────────────────────┐
│ [♥♥♥]          [⏱ 0:42]  │  ← top band: 2 compact plates, 40–52 dp text
│                          │
│                          │
│        ( 3 )             │  ← centre: ONE hero message (104 dp), transient
│     ┌─────────────┐      │
│     │  self-view  │      │  ← camera self-view, the player's body; keep the
│     │  + skeleton │      │     torso area free of HUD
│     │  ghost      │      │
│     └─────────────┘      │
│  ◀ zone      zone ▶      │  ← side target zones (outlined, not filled)
│ ┌──────────────────────┐ │
│ │ SQUAT  ▮▮▮▮▯  x4     │ │  ← bottom plate: move name + progress + combo
│ └──────────────────────┘ │
└──────────────────────────┘
```

Contrast techniques, cheapest first (no blur anywhere):
1. **Tinted plate** behind every text block: a rounded rect (radius 22, as in `Lantern.radius`)
   filled with `plate` (night at 78–88%) and a 2 dp `ridge` border. This is the research-backed
   "billboard" ([Gabbard 2007](https://ed-swan.github.io/publications/papers/2007_Gabbard-etal_Text-Drawing-Styles_IEEE-VR.pdf)).
2. **Edge scrims**: a top and bottom linear gradient, night 0% → 65%, about 18% of screen height
   each. It costs one quad and gives plates a calm frame.
3. **Glyph outline** for anything outside a plate (hero countdown, floating "+10"): paint the text
   twice, a stroke pass (`Paint()..style=stroke..strokeWidth=6..color=stroke`) and then a fill.
   This is cheaper than `Shadow` lists with blur radius. A hard offset shadow (dx 0, dy 4, blur 0)
   in `chunkyShadow` adds depth with no blur cost.
4. **Optional camera dimming**: multiply the camera preview by 0.75–0.85 brightness during play,
   using a single `ColorFilter` matrix or an overlay of night at 20%. That gives every overlay a
   predictable floor. Turn it off on the onboarding framing screen so the player sees themselves
   clearly.
5. **Adaptive plate alpha** (later): sample the mean luma of the HUD regions from the
   preview's low-res luminance, which is already available natively. Send one float across
   the bridge, never frames, so rule 4 holds. Raise plate alpha when the room is bright. This
   follows the adaptive-outline idea in Gabbard 2007.

Self-view skeleton and ghost:
- Draw the landmark skeleton as **3–4 dp parchment strokes with a 2 dp dark stroke under them**.
  Don't draw it in a single neon colour, which disappears on clothing of the same colour.
- Draw the "target pose" ghost as a **dashed outline** in the game's accent, never a filled body.
  When the player matches, it fills to 30% and pulses once.
- Draw target zones as thick outlined rounded rects or rings, and fill them only on hit.

Tracking-lost state (rule 5): the whole HUD desaturates to 40% (one ColorFilter). A centre plate
shows a person-outline icon, "Step back into view" and an amber ring. Gameplay slows down. No red
and no life loss.

---

### 5. Motion principles (budget-phone safe)

- **No blur. No backdrop filters. No full-screen shaders.** Use transform (scale, translate,
  rotate) and opacity only. Those composite cheaply in Flutter/Flame.
- **Springs, not long tweens** (in the spirit of M3 Expressive). Punch-in uses scale 0.6 → 1.08 →
  1.0 over about 220 ms (`Curves.easeOutBack`, or `SpringDescription(mass:1, stiffness:500,
  damping:22)`). Exit is a 120 ms fade plus scale to 0.9.
- **80/20 rule**: 80% of UI motion is calm (fades, 150–200 ms). 20% is expressive, reserved for
  rep complete, combo up, level clear.
- **Timing budget**: feedback must start within **1 frame** of the recogniser event. Celebration
  ≤ 600 ms so it never hides the next cue. At most **2 simultaneous animated HUD elements**.
- **Kinetic type, carefully**: numbers "tick" by sliding up 12 dp plus a fade (odometer). Move
  names can stretch-in using `scaleX` 1.2 → 1.0, which reads like a variable-width axis without
  needing a variable font.
- **Particles**: pool ≤ 40 sprites, using additive-looking bright sprites without real additive
  blending if that is costly. Lifetime ≤ 700 ms.
- **Reduced motion** (OS `MediaQuery.disableAnimations` or an in-app toggle): replace scale
  bounces with fades, remove screen shake and parallax, and keep the colour/icon state change
  ([Xbox XAG motion](https://learn.microsoft.com/en-us/gaming/accessibility/guidelines)).
- **Photosensitivity**: no flashes > 3 per second, and no full-screen white flash. Use a
  marigold border pulse instead.
- **Frame target**: 60 fps where possible, and a guaranteed 30 fps floor on budget devices
  (common India segment). Animations are time-based, not frame-count-based.

---

### 6. Iconography

- **Style**: chunky, rounded-terminal, filled glyphs with a 3 dp dark outline (`stroke`), drawn on
  a 24-unit grid and rendered at 48–72 dp in-game. One consistent corner radius family, echoing
  the 22 dp card radius.
- **Body-first icon set (original)**: simple stick or capsule figures in the same proportions as
  the in-game hero (round head, capsule torso). Poses: arms up, side step, squat, march, reach
  left/right, lean. Use the same figure in onboarding, the HUD move prompt and results, so one
  visual vocabulary carries through.
- **Status icons**: person-outline (tracking), sun-with-arrow (too dark/too bright), phone-tilt
  (camera angle), footprints (step back), pause (two thick bars).
- Colour is never the only cue. Every state = icon + word + colour.
- Material Symbols Rounded (Apache 2.0) is acceptable for shell icons. Custom figures stay
  original (AGENTS rule 10).

---

### 7. Celebration and feedback effects

| Event | Visual | Sound/haptic hint | Budget |
|---|---|---|---|
| Rep recognised (state permits) | Ghost outline fills to accent at 30%, a small tick pops near the bottom plate, the counter odometer ticks | Short pluck | 220 ms, 0 particles |
| Perfect timing | Tick in `mehendi` + "PERFECT" label punch-in (52 dp) + 12 spark sprites from the hand/foot landmark | Higher pluck | 400 ms |
| Combo x5, x10 | Combo plate morphs shape (rounded rect → pill → star-cornered badge, an M3-style shape morph), with a marigold border pulse | Rising tone | 500 ms |
| Miss / late | Grey ring shrinks, gentle sideways nudge of the cue. No red X and no shake. | Soft thud | 200 ms |
| Level clear | Full-width plate with the per-game gradient, big "CLEARED" in 104 dp, confetti from the top edges built from 3 original shapes (diya-like teardrop, marigold dot, kite-diamond). This nods to festivals without copying any motif artwork. | Short fanfare | ≤ 1.5 s, skippable by a raise-hand pose |
| Tracking lost | HUD desaturate + amber ring + slow-mo (see section 4) | Calm chime | Persistent until recovered |

Feedback always comes from game state (rule 6). The recogniser event just requests feedback, and
the game decides which row applies.

---

### 8. Onboarding for self-view

1. **Hand-held step (shell UI, normal type):** explain that the camera stays on device and only
   body points are used. One screen, one toggle for jumps (default off, rule 9).
2. **Place the phone:** an illustration of a phone propped upright on the floor at about 2 m.
   Show a live preview with a **framing silhouette** (dashed parchment outline of a full body)
   plus 3 big checks that tick as they pass: "Whole body visible", "Light OK", "Space clear". Use
   the 52–80 dp tier from here on, because the player is walking away.
3. **Distance meter:** a vertical bar on the screen edge with a person icon sliding toward a
   "sweet spot" band, driven by the shoulder–hip span in normalised landmarks. Text: "Closer" /
   "Perfect" / "Step back".
4. **Hello pose:** "Raise both hands to start". This doubles as a calibration capture and as
   confirmation that pose control works. Thereafter **no touch is needed** while playing (pause =
   hold hands in an X, or tap if they walk up).
5. **First-move tutorial:** the ghost outline demonstrates the move once at half speed, then the
   player mirrors it 3 times with generous thresholds and celebration on each.
6. **Re-entry:** if the player returns within 24 h, skip to step 2 with the checks pre-ticked if
   they pass in under 2 s.

---

### 9. Do / Don't

**Do**
- Put every in-game text on a plate or give it a dark outline. Test on white walls, patterned
  saree/kurta fabrics, bright windows and dim tube-light rooms.
- Show one message at a time, use 40 dp as the text floor and 104 dp for hero numerals.
- Use icon + word + colour for every state.
- Use spring scale and opacity animations. Keep celebrations ≤ 600 ms mid-play.
- Keep the player's torso area of the self-view clear.
- Take Indian warmth from the palette (marigold, kumkum, peacock, indigo dusk) and from
  festive-geometry confetti shapes, drawn originally.
- Honour reduced motion and offer a high-contrast HUD (solid plates, 7:1).

**Don't**
- Don't use `BackdropFilter`/blur, glass blur, full-screen shaders or motion blur.
- Don't use neon text directly on the camera, thin weights, or long sentences during play.
- Don't use red, shake or "FAIL" for tracking loss or misses.
- Don't use colour as the only signal, or red/green-only good/bad pairs.
- Don't put flashing > 3 Hz or full-screen white flashes on screen.
- Don't use stereotyped "Indian" clip-art (temples, rangoli wallpapers) as decoration.
  Contemporary means restraint.
- Don't copy any specific game's HUD, mascot proportions, icon set or palette. All shapes and
  figures stay original.
- Don't make UI that requires a touch while the player is 2 m away.
- Don't make claims about calories or weight loss in celebration copy. Use "Great moves!", not
  "You burned X kcal".

---

### 10. Evolving Forest Lantern without breaking it

1. **Additive only**: add `abstract final class LanternPulse` (overlay tokens from 2b) and a
   `ThemeExtension<HudTheme>` that holds the HUD type scale (3a), plate alpha, stroke width and the
   per-game accent pair. Existing `Lantern.*` constants and `buildTheme()` stay unchanged, so no
   widget or golden test changes.
2. **Per-game accent via the extension**, not via `ColorScheme.fromSeed` swaps, so shell colours
   stay stable across games. `buildTheme(seed:)` already exists, and the seed should keep
   defaulting to `glow`.
3. **Shared primitives**: create a `HudPlate` widget/Flame component (plate + border + optional
   outline text painter) and a `StrokedText` painter. All three games use them, which gives one
   place to tune contrast.
4. **Shell gets light-touch modernisation only**: bump `displaySmall` usage on results to a
   kinetic odometer, add spring transitions in go_router pages, add the marigold accent for
   streaks. Same hex for primary and surfaces.
5. **High-contrast mode** = `plate` → `plateSolid`, stroke width +50%, accents swapped to the
   lighter variants. Implement it as an extension flag.
6. **Record decisions** (per AGENTS.md): put the stable token/extension design in
   `docs/architecture.md` and the HUD thresholds (type tiers, timings, flash limits) in
   `docs/game-design.md`.
7. **Verify**: a golden test of `HudPlate` over 4 fixed background images (white wall, busy
   fabric, dark room, bright window). Add an automated contrast check on token pairs (WCAG
   formula in a unit test) so future palette edits can't drop below 4.5:1.

---

### Sources
- https://pixune.com/blog/best-examples-mobile-game-ui-design/
- https://appfollow.io/blog/mobile-gaming-trends-2026
- https://ejaw.net/how-mobile-game-ux-interface-design-drives-player-retention-in-2026
- https://adrydapp.blogspot.com/2026/03/mobile-game-ui-design-trends-2026-guide.html
- https://barrettmedia.com/2026/01/21/graphic-design-for-video-games-trends-players-notice-in-2026/
- https://line25.com/articles/web-design-trends-2026/
- https://www.theedigital.com/blog/web-design-trend
- https://studiomeyer.io/en/blog/webdesign-trends-2026
- https://developer.android.com/design/ui/wear/guides/get-started/design-language
- https://learn.microsoft.com/en-us/gaming/accessibility/guidelines
- https://gameaccessibilityguidelines.com/?p=12
- https://unity.com/blog/video-game-accessibility-basics
- https://www.beautifulhomes.asianpaints.com/magazine/decor-advice/trends/this-asian-paints-colournext-story-is-about-india-everywhere
- https://www.cosmopolitan.in/life/features/story/asian-paints-colournext-2025-the-design-trends-that-will-define-this-year-1177034-2025-03-06
- https://www.designpataki.com/?p=45875
- https://ed-swan.github.io/publications/papers/2007_Gabbard-etal_Text-Drawing-Styles_IEEE-VR.pdf
- https://pubmed.ncbi.nlm.nih.gov/32425139/
- https://fonts.google.com/knowledge/using_type_in_ar_and_vr/introducing_ar_vr
- https://www.vrwiki.cs.brown.edu/applications-of-vr/reading-in-vr/reading-in-ar
- https://uxdesign.cc/re-designing-a-mobile-ar-experience-for-athletes-a-ux-case-study-11b1be491166
- https://developer.amazon.com/docs/fire-tv/design-and-user-experience-guidelines.html
- https://en.wikipedia.com/wiki/10-foot_user_interface
- https://pascalpotvin.medium.com/designing-a-10ft-ui-ae2ca0da08b7

---

## 3 — Characters, avatar/AR costumes, animation pipeline (research + design notes)

Status: research notes only, repo not edited. `docs/new-games-plan.md` does not exist; the cast below is
mapped to roles (rhythm/dance, pad-boxing, runner/race, balance/cooldown) so it can attach to whichever three
new games are chosen. Existing facts: Kavi is "an original fox-orange runner's guide" (`docs/game-design.md`
§AI coach); lines live in `app/lib/l10n/coach_strings.dart` (en/hi/gu); current Hindi lines use masculine first
person ("मैं सुझाव दूँगा"). App assets today = 320 KB. Deps: flame 1.38, no Rive/Lottie/Spine.

### A. What research says makes companions work (with caveats)
1. **Story and characters drive longer sessions.** Interviews with 30 *Zombies, Run!* users found narrative/characters were the
   favourite feature and made sessions longer and use longer-term (qualitative, small n) — Faric et al., Games for Health J. 2021:
   https://discovery.ucl.ac.uk/id/eprint/10139156/ . Trial protocol NCT02341235 reports "high levels of parasocial interaction
   with the two main NPCs": https://cdn.clinicaltrials.gov/large-docs/35/NCT02341235/Prot_SAP_000.pdf
   → Give each game one named voice that talks *to "you"*, in short barks, not cutscenes.
2. **Second-person voice draws in less-active people** (Lyons, UTMB): https://chairsearches.utmb.edu/newsroom/article8962.aspx
3. **Companion turns exercise into game verbs.** Ring Fit's Ring is a chatty partner and its moves become attacks
   (review: https://news.yahoo.com/ring-fit-adventure-review-nintendo-113006617.html ; design analysis:
   https://ceeol.com/search/article-detail?id=1009100 ). → Our rule 6 already fits: the companion reacts to *game outcomes*, not raw reps.
4. **Guilt-trip mascots backfire for some users.** Duo's evolution into a passive-aggressive streak nag is credited with engagement,
   but users report streak anxiety / "letting Duo down"; Duolingo added Streak Freeze. Sources are weak (blogs):
   https://desirabilitylab.com/backfill/backfill-2025-46-duolingo-streak-design ,
   https://mojo.iimu.ac.in/2026/meet-the-loveable-language-learners-unlocking-the-secret-to-duolingos-success.html
   (the "J. Educational Computing Research" claim there could not be verified — do not cite it).
   → **Rule for our cast: warm teasing about the game, never guilt, never about the body, never streak shame.** Matches AGENTS rule 5
   and the no-medical/no-weight-claims rule.
5. Design takeaways (synthesis, not sourced): one strong silhouette + one colour per character; 3–5 expressions beat many frames;
   personality shown through *reaction timing* (cheer within 200 ms of a game outcome); recurring catchphrase per character;
   characters remember things (best score, favourite world) from local run summaries — cheap "relationship" with no cloud.

### B. Animation pipeline for Flutter/Flame, small install, budget phones
| Option | Install cost | Runtime cost | Fit |
|---|---|---|---|
| **Cut-out rig in Flame** (layered PNG/WebP parts + `Effect`s/`EffectController` tweens, data in JSON) | ~0 new code; ~80–200 KB per character atlas | Very low: a few sprites + transforms | **Recommended default** for all characters in-run and in menus |
| **Sprite sheets** (`SpriteAnimation` + `flame_texturepacker`, multi-page, load groups on demand: https://pub.dev/documentation/flame_texturepacker/latest/) | 0 new native code; PNG/WebP on disk | Flutter decodes to RGBA: 2048² atlas ≈ 16 MB RAM (cf. https://forum.unity.com/threads/sprite-atlas-etc2-fallback.723944/) | FX (sparks, aura loops, trails), short bursts; keep atlases ≤1024² |
| **Rive** (`rive`/`rive_native`, `flame_rive`: https://pub-web-s1.flutter-io.cn/packages/flame_rive) | Native `.so` per ABI; one dev reports APK bloat of ~80 MB attributed to Rive (https://itnext.io/how-i-drastically-reduced-my-flutter-app-size-by-80mb-with-just-one-line-of-code-967ba19cef98); Rive lists `librive-android.so` + C++ stdlib and size-reduction flags (https://rive.app/docs/runtimes/runtime-sizes.md — host blocked here, not read in full) | Fast GPU renderer; state machines + inputs; .riv files tiny (vendor claims 10–15x smaller than Lottie: https://rive.app/blog/rive-as-a-lottie-alternative) | Best tool for an *interactive* coach portrait (idle/cheer/think + lip-flap) — adopt only if `flutter build appbundle --analyze-size` shows acceptable per-ABI delta (target ≤3 MB) |
| **Lottie** | Pure Dart pkg, small | JSON parse at load, CPU-heavy for complex files; no state machines (https://www.tillitsdone.com/blogs/rive-vs-lottie--flutter-animations) | Only for 1–2 UI flourishes (results screen confetti); not in-run |
| **Spine** (`flame_spine` is still 0.4.0-dev: https://pub.dev/packages/flame_spine/versions/0.4.0-dev.0+7/install ; spine-flutter on spine-c FFI: https://www.esotericsoftware.com/spine-flutter ) | Native lib + paid Spine editor licence (runtime use requires a licence — verify terms) | Good; prefer binary `.skel`, share skeleton data across instances | Overkill for us; skip unless an animator insists |

**Decision proposal:** cut-out rigs for characters (deterministic, data-driven, no deps), sprite sheets for FX, Lottie/Rive
deferred. Measure on the budget reference phone with the camera + pose running (pose already eats GPU/CPU): character layer
budget ≤2 ms/frame, ≤12 MB texture RAM total at any time, unload per-world assets between runs.
Use WebP (lossless or q≈90) for atlases; `flutter build appbundle` + Play splits by ABI/density.

### C. Coach Kavi, refined
- **Who:** an original anthropomorphic **Bengal fox** (Indian native species; big ears, black-tipped tail, slim legs) — keeps the existing
  "fox-orange" identity and is distinct from other fox mascots. Wears a sleeveless teal running vest with a single white stripe,
  wristbands, no logos. Silhouette: ears + tail S-curve. *(If the team meant "fox-orange" as colour only, the same palette works on a
  human coach; flag for product owner.)*
- **Palette:** fox orange `#E8742A`, cream `#F6E7D0`, ink `#2B2230`, vest teal `#1E8C8A`, accent marigold `#F5B700`.
- **Personality:** calm senior teammate, dry humour, notices effort and smart play; never a drill sergeant. Catchphrase: "Chalo, ek aur!"
  (EN: "One more go?") — game-invitation, not a demand. Celebrates choices (taking assist mode, low-impact) as *smart*.
- **Voice rules (all languages):** ≤8 words per bark; second person; game verbs only (gate, pad, beat, gem, rival); never body,
  weight, calories, "burn", "tone", pain, health; tracking problems are *Kavi's/the camera's* fault ("I lost you — step back a bit");
  respectful **आप** register in Hindi, **તમે** in Gujarati; Hinglish allowed only in EN-UI mode as flavour; native-speaker review.
- **Gender/grammar:** Hindi first-person verbs gender the speaker (दूँगा/दूँगी). Either fix Kavi as he (current strings) or ship a
  Kavi-voice setting; for addressing the *player*, prefer imperative/present forms that are gender-neutral in आप
  ("चलिए!", "बहुत बढ़िया!") and avoid gendered past tense ("आप जीत गए/गईं") unless the player set pronouns.
- **Line style examples:** start "Ready? Squat through the first gate." / "तैयार? पहले गेट पर स्क्वॉट कीजिए।" / "તૈયાર? પહેલા ગેટ પર સ્ક્વોટ કરો."
  Good play "Clean line! Keep that rhythm." / "शानदार! यही लय रखिए।" / "સરસ! આ જ લય રાખો."
  Tracking "I can't see your feet — step back." / "पैर नहीं दिख रहे — थोड़ा पीछे हटिए।" / "પગ દેખાતા નથી — થોડા પાછળ જાઓ."
  Rest "Nice run. Shall we try a lighter one next?" (offer, never instruct).
- **Expressions (6):** neutral, smile, big cheer, thinking (paw to chin), pointing, concerned-kind (for tracking loss).

### D. Companion & rival cast (original; Indian fauna; no deities' vahanas or sacred animals)
Avoid as characters: cow, elephant (Ganesha), monkey (Hanuman), peacock (Krishna/Kartikeya), cobra/naga, owl (Lakshmi), swan,
tiger-with-rider, any halo, third eye, tilak, om/swastika/crescent/cross, temple bells as "power-ups". Also avoid Bholu (Indian
Railways elephant) and Shera (CWG tiger) look-alikes.

| Name | What | Role / game slot | Look & palette | Personality / catchphrase |
|---|---|---|---|---|
| **Mithu** | Rose-ringed parakeet | MC/DJ of the rhythm/dance game; calls beats, combo hype | Leaf green `#3DAA4A`, red beak `#D7263D`, pink-black neck ring, oversized headphones | Loud, joyful, puns on beats; "Beat pakdo!" ("Catch the beat!") |
| **Golu** | Young Indian one-horned rhino | Pad-holder trainer in the boxing/pad game; holds the punch pads | Slate grey `#7A8490`, warm pink ears, red pads `#E63946` with white rims, sweatband | Gentle giant, proud of your aim, over-dramatic "oof!" when hit; "Ek, do — combo!" |
| **Neela** | Smooth-coated otter | Balance/cool-down host; slow breathing and stretch segments; low-impact champion | River teal `#2A9D8F`, sand belly `#E9C46A`, flower-print towel | Unhurried, kind, quiet jokes; "Aaraam se." ("Easy does it.") |
| **Chikki** | Indian palm squirrel | **Rival** racer: animates your own best-run ghost and taunts the *race*, never you | Tawny `#B5835A`, three cream back stripes, tiny goggles, scarf `#F4A261` | Cheeky, competitive, a good loser who gives a high-five; "Pakad sako toh pakdo!" ("Catch me if you can!") |
| **Baadal** | Mischievous monsoon cloud creature (not a spirit/god) | **Boss / prankster rival**: steals the sun, rains obstacles; reformed after the world boss | Storm blue `#4A5A8C` to lilac `#9D8DF1`, puffy, two lightning-shaped eyebrows | Theatrical, sulky, secretly lonely; "Garaj garaj!" |
| **Jugnu** | Firefly sprite helper | Tracking-help companion across all games: glows where the camera loses you, lights a framing outline; turns rule 5 into a character | Glow yellow `#FFE45E`, tiny | Says almost nothing; chirps + points; text hints carry meaning |

Relationship hooks (local only): Mithu remembers your best combo, Chikki's ghost improves when you beat it, Golu keeps a "pad wall"
of your best accuracy, Baadal sends a sheepish postcard after defeat. All driven by local run summaries + JSON content, no cloud.

### E. Player avatar & AR costume system
**Avatar (in the 2.5D world, and on share cards):**
- Built from independent pickers — no "male/female" gate: body shape (5 presets: slim, average, broad, curvy, larger), height (3),
  skin tone (10 swatches spanning very light to very deep, inspired by the open Monk Skin Tone scale), hair (12 styles incl. buzz,
  braid, bun, curls, long straight, bald), facial hair (optional), outfit sets (athleisure, kurta-style top + joggers, salwar-style
  joggers, tee + shorts, full-sleeve modest set), shoe colour.
- Optional pronoun setting (he/she/they/none) only changes grammar of a few Hindi/Gujarati lines; default "none" (neutral forms).
- Player-chosen headwear may include respectful sport headwear (e.g., sports hijab, patka) as *inclusion options*; never as costume
  items, never on NPCs, never as unlockables/joke items — confirm with cultural reviewers.
- No body-changing rewards (no "slimmer avatar after X runs"). Body shape is cosmetic and never tied to progress.

**AR costume over self-view (body-anchored, landmark-only):**
- Pose Landmarker gives 33 points (no face mesh), so anchor to: head = nose (0) + ears (7/8) → hats, crowns-of-leaves, headphones;
  shoulders (11/12) → capes, back aura, shoulder pads; wrists (15/16) → glove glows + motion trails; hips (23/24) → belt glow;
  ankles (27/28) → footstep sparks.
- Scale every item by shoulder width; rotate by ear/shoulder line; smooth with the existing One Euro filter; fade out (not snap) when
  landmark visibility < threshold; mirror for selfie preview.
- Draw in Flutter/Flame over the native preview texture — only landmarks cross into Dart (rule 4); never compose a camera frame +
  costume into an image; **no photo/video capture of self-view** (rule 2). Sharing uses the avatar-only card.
- Keep the face visible: no masks over eyes/mouth; hats sit above the ear line, auras behind the body.
- Item types (all original): 6 hats (marigold-leaf band, kite cap, star headband, cloud puff from Baadal, Mithu headphones, Kavi ears),
  4 auras (sunrise, monsoon, firefly ring, rangoli-geometry halo-free ring behind shoulders — *not* a halo above the head),
  5 trails (ribbon, sparkle, kite string, rain drops, diya-free ember), 3 footstep FX. Unlock via play, never pay-only nudges.

### F. Asset list and size budget (install, compressed WebP/OGG)
| Asset | Spec | Est. size |
|---|---|---|
| Kavi cut-out rig: ~18 parts + 6 expression heads | 1 atlas 1024² | 250 KB |
| 5 companions/rivals rigs (Mithu, Golu, Neela, Chikki, Baadal) | 1 atlas 512–1024² each | 5 × 150 KB = 750 KB |
| Jugnu + UI glow | 256² sheet | 30 KB |
| Rig animation data (JSON keyframes: idle, cheer, point, think, react-hit, react-miss, wave) | per character | 7 × 15 KB ≈ 100 KB |
| Avatar parts: 5 bodies × 3 heights as scalable parts, 12 hair, 5 outfits × 4 colourways, faces | 2–3 atlases 1024², palette-swapped skin via shader/tint (no per-tone art) | 700 KB |
| AR costume items (18) + FX sheets (trails/sparks) | 2 atlases 1024² | 400 KB |
| Portraits for menus/dialogs (7 characters × 2 sizes) | 512² | 400 KB |
| VO barks: ~40 lines × 3 langs × 7 chars max (Opus/OGG ~32 kbps, ~1.5 s) — or non-verbal chirps + text | ~6 KB each | 1.5–2.5 MB (or ~300 KB chirps only) |
| **Total character budget** | | **≈ 3–5 MB**, keep total app assets under ~10 MB |
Runtime RAM ceiling for character/costume textures: ≤12 MB resident (each 1024² atlas ≈ 4 MB decoded).

### G. Art production plan and freelancer briefs
Phases (≈8–10 weeks, parallel where possible):
1. **Wk 1–2 Character design** (1 illustrator): silhouettes → 3 options per character → pick → turnaround + 6-expression sheet + palette.
   Cultural/sensitivity review (2 native reviewers: Hindi, Gujarati; plus one inclusion reviewer) before lock.
2. **Wk 3–5 Rig parts + animation** (1 2D game animator): cut-out parts exported to atlas (TexturePacker or free equivalent),
   keyframes as JSON matching a small schema we define (`content/schema/character.schema.json` — validate like levels, rule 7).
3. **Wk 3–6 Avatar & costume kit** (illustrator #2): modular avatar parts, skin via tint mask, 18 costume items with anchor points
   documented per landmark.
4. **Wk 5–7 VO** (3 voice actors per language or 1 multilingual per character; studio or remote): record barks; deliver 48 kHz WAV
   masters + OGG. Optional: non-verbal chirps first, full VO later.
5. **Wk 7–8 Integration + device test** on budget phone; size gate in CI (`--analyze-size`), texture RAM check.

Brief template (every freelancer):
- Deliverables, formats (layered PSD/Krita/Affinity source, PNG @2x, atlas + JSON), naming, colour tokens above.
- **Original work only**: no tracing/referencing existing mascots (Duo, Ring, Pokémon, Sonic, IPL/team mascots, Bholu, Shera); provide
  sketches/process files as provenance; disclose any AI tools (recommend none for final art) — supports AGENTS rule 10.
- Full IP assignment / work-for-hire, moral-rights waiver where allowed, model releases for voice actors, perpetual worldwide licence.
- Content rules: no religious symbols or deity references, no flags/real teams/brands, no body-shaming or weight humour, no medical
  claims, adults 18+ tone but family-safe; diverse body/skin representation in key art.
- Technical limits: max atlas 1024², ≤ part counts above, transparent padding 2 px, pivot points marked, 60 fps-safe (≤24 keyed fps OK).
- Acceptance: review rounds (2), sensitivity sign-off, on-device check.

Rough budget (India freelance rates vary widely; assumption, not researched): design ₹1.5–3 L, animation ₹1.5–3 L, avatar/costume
₹1–2 L, VO ₹0.5–1.5 L.

### Open questions for the product owner
1. Is Kavi a fox character or a human coach with a fox-orange brand colour? (Notes assume Bengal fox.)
2. Fix Kavi's Hindi grammatical gender, or offer a voice setting?
3. Accept Rive's native lib size for an interactive coach portrait, or stay deps-free with cut-out rigs?
4. Inclusion headwear options: approve with reviewers?

---

## Game C: MIRROR MELA, an AR mirror arcade (MotionQuest mode)

*Tagline: "The fair comes to you."* (Mela = fair, a secular word used across India.) Working
name; check trademark before launch. You see yourself mirrored on screen, or a landmark-drawn
avatar if you prefer. Fair-stall objects (bubbles, paper lanterns, marigolds, kites, colour
splashes) float to points around your body. You reach, hold a pose or dodge to meet them.
It is an arcade: short rounds, high score, combo, then go again.

Hard constraints from the tech research (3-tech.md) that shape every rule below:
- **Every interaction is an end state**: a body point inside a zone for ≥ 2 frames, or a pose
  held. Never velocity. No swipes, slashes or forward punches.
- **All zones sit in the image plane** (left/right/up/down of the body). Nothing toward the
  camera, because z is unscaled and foreshortening is ambiguous.
- **Zones are body-relative** (torso units from shoulder centre, scaled by calibrated reach),
  never fixed screen pixels. Every zone is clamped inside 85 % of frame width and 90 % of height
  so wrists never leave the frame.
- **Timing windows are ±250–400 ms**, judged on capture timestamp minus `latencyOffsetMs`.
- **Phone on the floor 2.0 m away**, portrait, play space 2 m × 2 m.

---

### 1. Core loop (one 75 s round)

1. An object appears at the screen edge and drifts to its **anchor** (a zone next to your body).
   An **approach ring** shrinks onto it over the warning time. When the ring closes, that is
   the moment to hit.
2. Put the named body point in the zone (hand, both hands, head, hips) and hold it 2 frames.
   The object pops, a note plays, and the combo rises.
3. Hazards (Orbit mode only) sweep through a band. Leave the band (squat, lean or step) before
   the ring closes.
4. Round ends → score, grade (C/B/A/S), best combo, "zones you reached" body map → 20 s rest →
   next round.

Rule 6 holds: reaching an empty zone does nothing. No score, no penalty.

### 2. Body points and zones

**Body points** (taken from the 33 landmarks; One Euro filter with a higher β on hands to cut lag):
- `handL/handR` = mean of wrist, index and pinky (15/17/19, 16/18/20) when each has visibility
  ≥ 0.5. Otherwise the wrist alone if its visibility is ≥ 0.6. Otherwise emit `notVisible`.
- `head` = nose, or shoulder centre + 0.9 torso if nose visibility < 0.5.
- `hips` = hip centre. `kneeL/kneeR` = knees (25/26).

**Zone map** (torso units T = shoulder-centre to hip-centre; R = calibrated arm reach
= max |wrist − shoulder| from calibration, default 1.15 T). The player's left is drawn on screen
left because the view is mirrored.

| Zone id | Body point | Anchor (relative to shoulder centre, +y = up) | Hit radius beginner / int / adv | Detectability |
|---|---|---|---|---|
| `hi-L` / `hi-R` | same-side hand | x ±0.55 R, y +0.85 R (diagonal overhead) | 0.50 / 0.42 / 0.36 T | Reliable |
| `side-L` / `side-R` | same-side hand | x ±0.85 R, y 0 (shoulder height, lateral) | 0.50 / 0.42 / 0.36 T | Reliable (lateral reach ≥ 0.75) |
| `low-L` / `low-R` | same-side hand | x ±0.70 R, y −0.95 T (hip height, out to side) | 0.55 / 0.45 / 0.40 T | Reliable; needs a small side bend |
| `crown` | both hands | x 0, y +0.95 R | both hands within 0.6 T | Reliable (= raise arms) |
| `chest` | both hands | x 0, y −0.35 T, hands ≤ 0.35 T apart | 0.45 T | Medium (hands overlap → accept visibility ≥ 0.3, like clap) |
| `knee-L` / `knee-R` | knee | knee lift ≥ 0.5 calibrated lift, held 2 frames | n/a | Reliable (march recogniser) |
| `duck` | head | head band drops ≥ 45 % (low-impact) / 60 % calibrated squat depth | n/a | Reliable (existing squat) |
| `lean-L` / `lean-R` | hips + shoulders | existing lean recogniser ≥ 60 % of range | n/a | Reliable |

Cross-body zones (left hand to right side) are **off in v1**. Crossing arms swaps L/R landmarks
on BlazePose Lite. They can come back once recorded-data recall reaches ≥ 0.9.

**Hit rule:** the body point is inside the radius for ≥ 2 consecutive frames (≥ 1 frame + max
over window for `chest`), within the timing window. Grades use the timestamp of the first
qualifying frame:

| | Perfect | Good | Graze | Miss |
|---|---|---|---|---|
| Beginner | ≤ ±200 ms | ≤ ±400 ms | in time, point at 1.0–1.3× radius | otherwise |
| Intermediate | ≤ ±150 ms | ≤ ±300 ms | 1.0–1.25× | |
| Advanced | ≤ ±120 ms | ≤ ±250 ms | 1.0–1.2× | |
| Assist (any) | +100 ms | +200 ms | 1.0–1.4× | |

Window ≥ max(spec, 2.5 × measured frame interval). At 15 fps that is ≥ 167 ms. **Early hold:**
a hand already parked in the zone when the window opens scores Good, never Perfect. This stops
players camping with their arms up while still being friendly.

### 3. Three sub-modes

#### 3a. Bubble Bazaar: pop and catch (the flagship and free mode)
- Soap bubbles, lanterns and marigolds float to the hand zones. **Shape tells the hand**:
  left-hand targets are circles with a ◐ mark, right-hand targets are diamonds. Colour is extra
  information, never the only signal. Beginner accepts **any hand** (full points).
- **Catch-and-place** (from intermediate): a "basket" object needs 2 hits, first a catch at
  `side-L`, then within 1.5 s a drop at `low-R`. This turns reaches into a controlled cross-body
  path at shoulder level without crossed wrists.
- **Double lantern**: `crown` or `chest` (both hands). Never two single-hand targets due within
  ±250 ms of each other on beginner.
- Density: beginner 22 targets/min (one per ≈ 2.7 s), intermediate 30, advanced 38. Maximum on
  screen at once: 1 / 2 / 3.
- Per-hand minimum gap 1000 / 800 / 650 ms (+250 ms low-impact). Overhead (`hi-*`, `crown`) ≤ 6
  per 30 s, never more than 3 in a row (shoulder load).

#### 3b. Rang Wall: paint the wall with poses
- A wall of 8 tiles. Each tile shows a **pose stencil**. Hold the pose for **600 ms** (beginner),
  800 ms (intermediate) or 1000 ms (advanced) and colour bursts out to fill that tile. Players
  choose the next tile by leaning or stepping toward it (lean = move cursor, existing
  recogniser), or play the guided sequence.
- **Pose set (v1, all end states in the image plane)**: Star (both `hi-*`), T (both `side-*`),
  Goalpost (elbows at shoulder height, forearms vertical; elbow angle 70–110°), Side bend L/R
  (`hi-` same side + lean), Half chair (squat 45 % + both `side-*`), Tree-lite (one `knee-*` lifted
  + `crown`, advanced only, ≤ 3 s), Victory (`crown`).
- Score = tile coverage. The fill grows with held time from 70 % at the minimum hold to 100 % at
  2× minimum, capped there so long holds earn nothing extra. Wall complete (8 tiles) = +500 and
  the finished wall saves as a **landmark-free art card** (colours plus pose icons only).
- Pose match = every required body point in its zone + joint angles within ±25° (beginner) / ±18°
  / ±12°. On a failed match the HUD names **the one part that is off** ("left arm higher"),
  never just "wrong".
- Slower and calmer: about 10–12 poses/min. Good as round 3 or as a cool-down.

#### 3c. Orbit: collect and dodge "all around you"
- A ring of 8 **clock positions** around the body silhouette (10, 11, 12, 1, 2, 3, 4 and 8
  o'clock; 5–7 is the floor, so unused). Sparks orbit slowly and **stop** at a position, then the
  ring closes and you collect them with the hand zones above.
- The "360°" comes from **sound and staging, not depth**. Hazards (slow comets, a swinging fair
  rope, a spinning wheel spoke) are first heard **behind** you (stereo pan plus a small shadow
  that crosses the floor from the back) for 1.0 s. They then sweep a band across the screen:
  - head band → `duck` (half squat on low-impact)
  - left or right half → `lean-*` or side-step away
  - chest band → **no** (would need a jump or a forward move; never used)
- Hazard warning 2.2 s minimum (matches existing `warningMs` floor). A hit costs **combo + 1 of 3
  shield pips, never the round**. With 0 pips, scoring is ×0.5 until the next 5-combo restores a
  pip. Rounds never end early.
- Mix: beginner 80 % collect / 20 % dodge, intermediate 70/30, advanced 60/40. Dodges ≥ 3 s apart.
  Never a collect within 1200 ms after a dodge (time to recover balance).

### 4. Round and session structure (≈ 5 min 15 s)

| Time | Block | Content |
|---|---|---|
| 0:00–0:35 | Check-in | Distance and space check (arm span inside frame with ≥ 10 % margin each side), quick calibration reuse (or the 30 s calibration if none, or drift > 15 %) |
| 0:35–0:50 | Warm-up | 8 slow `side-*`/`crown` bubbles, unscored, 3.0 s warning |
| 0:50–2:05 | Round 1 (75 s) | Bubble Bazaar |
| 2:05–2:25 | Rest 20 s | Score, best combo, breathing ring |
| 2:25–3:40 | Round 2 (75 s) | Orbit (or player's pick) |
| 3:40–4:00 | Rest 20 s | |
| 4:00–5:00 | Round 3 (60 s) | Rang Wall (slower poses, a calmer finish) |
| 5:00–5:15 | Cool-down | 2 held stretches (side bend L/R, 6 s each), results, share |

Round inner pacing (75 s): 0–10 s intro (single zones, slow) → 10–35 s build → 35–45 s
breather (easy collects only, no hazards, no overhead) → 45–70 s peak (doubles, catch-and-place,
hazards) → 70–75 s finale burst (6 golden targets, sequenced L-R-L-R-crown-crown).
Beginner rounds are 60 s, advanced 90 s. Single-round "Quick Play" is also available.

### 5. Scoring, combos, Fever

- Points: Perfect 100, Good 60, Graze 30, Miss 0. Double (both-hand) ×1.5. Catch-and-place
  pair +150 bonus. Dodge cleared +50. Rang tile 200 × coverage.
- Combo: each non-Miss adds +5 % (×1.0 → ×2.0 at a 20 combo). A Miss or hazard hit resets the
  multiplier to ×1.0. A **forgiven** target (tracking) never breaks the combo.
- **Mela Rush (Fever)** at a 15 combo: 8 s of golden targets worth ×1.5, music layer added. Same
  zones and spacing; **never harder or faster**.
- Round grade from the share of maximum possible: S ≥ 90 %, A ≥ 75 %, B ≥ 55 %, C below.
- Rule 5: a target is **forgiven** if tracking was amber or red at any point from 300 ms before
  its window opened to the window closing, or if there was < 800 ms (1200 ms assist) of green
  play since tracking came back. Forgiven targets are removed from the maximum. On amber the
  world slows to 60 %, on red it freezes, and the HUD shows "Step back, I can't see your left
  hand", etc.

### 6. Difficulty and pace profiles

| | Warning (ring) | Max on screen | Targets/min | Hit radius | Hold (Rang) | Hazards |
|---|---|---|---|---|---|---|
| Beginner | 2.0 s | 1 | 22 | 0.50 T | 600 ms | ≥ 2.6 s warning, 20 % |
| Intermediate | 1.6 s | 2 | 30 | 0.42 T | 800 ms | 2.2 s, 30 % |
| Advanced | 1.3 s | 3 | 38 | 0.36 T | 1000 ms | 2.2 s, 40 % |
| Assist | +25 % | −1 (min 1) | −25 % | +20 % | −200 ms | +0.4 s |

Harder settings **add decisions** (specific hand, catch-and-place, mixed collect and dodge), not
speed. Approach speed is never faster than 1.3 s.

**Pace profiles (adults 18+ only; self-chosen, never inferred from the camera, no medical
framing):**

| Profile (shown as) | Suggested for | Defaults |
|---|---|---|
| **Energetic** | anyone wanting more | Intermediate, overhead cap 6/30 s, rest 20 s |
| **Steady** (default) | everyone | Beginner, low-impact on, rest 20 s |
| **Gentle** | e.g. 55+ or returning to activity (copy says "prefer a softer pace") | Beginner + Assist, half squat max, overhead cap 4/30 s, no `knee-*`, rest 30 s, 4 min session |

Zones always scale to **your calibrated reach**, so shorter or less flexible players get the
same targets relative to their own body.

### 7. Accessibility and low-impact

- **No jumps, ever, in this mode.** No fast moves, no forward lunges, no floor touches. Deepest
  squat = half squat on low-impact (45 % depth).
- **Seated play** (Gentle, opt-in): upper-body zones only (`hi`, `side`, `crown`, `chest`, lean).
  This needs a new **upper-body QualityGate profile** (shoulders, elbows, wrists, hips at
  visibility ≥ 0.5; legs ignored). That is a dependency and must pass the replay gate.
- **One-arm mode**: all single-hand targets go to the chosen side. Doubles become single `crown`
  or `hi-*`.
- **Not colour alone**: shapes per hand, a different sound per zone, stereo pan L/R, large ring.
- **Text** ≥ 20 sp at 2 m and readable at 2 m. Hindi + English copy at launch (others later).
  Coach Kavi voice lines are optional.
- Overhead and shoulder load caps per 30 s (see 3a). Holds capped at 3 s (Tree-lite) or 6 s
  (cool-down stretch).
- **Space check** before every session: an arm span of 2.2 R must fit inside the frame. If it does
  not: "Move back or clear space; arms out to the side needs about 1 m each way."

### 8. Mirror view and privacy

- **Mirror view (default on, one-tap off):** the CameraX preview is drawn **natively** (a
  platform texture). Dart never receives pixels (rule 4); only landmarks cross. The preview is
  dimmed to 55 % with a soft vignette so game objects stand out. A glowing outline is drawn from
  the landmarks.
- **Avatar mode (privacy):** preview hidden; a stylised landmark-driven figure (rounded
  capsules, chosen skin) stands in. Recommended in shared homes and suggested automatically at
  first run ("Prefer not to see yourself? Try Avatar").
- **Lag honesty:** the live preview has no delay, but landmarks arrive 110–180 ms later. If hits
  were judged against the preview, objects would seem to pop a moment late. Pops are judged and
  drawn at **landmark** positions, with a hand halo so the player sees what the game sees. Avatar
  mode has no mismatch. Test on budget phones: if the lag is visible, delay the preview
  presentation by the median pipeline latency (native side, frame skip, no queue beyond 1 frame).
- `FLAG_SECURE` is on while the camera preview is visible. Screenshots and screen recorders then
  capture no camera pixels. Avatar mode allows screenshots.
- Overlay alignment: native reports the preview crop rect, rotation and mirror flag once per
  config change. Dart maps normalised landmarks into the same rect.

### 9. Juice

- **Pop:** 50 ms hit-stop on that object only (never the world), 12–16 particles, a ring
  shockwave to 1.6× radius over 180 ms, score text pops up and floats 40 px.
- **Musical zones:** each zone plays a note of a pentatonic scale (Sa Re Ga Pa Dha; C D E G A).
  Left side is lower, high zones higher, `crown` = octave Sa. A combo therefore plays a melody.
  Perfect adds a sparkle overtone; Graze is a muted pluck. Sounds generated like
  `tools/gen_cues.py` (original).
- **Rang Wall:** paint splash fills from the pose's contact points outward over 400 ms. On wall
  complete, the tiles briefly cycle into a rangoli-style kaleidoscope (original geometry).
- **Orbit:** hazards get a 1.0 s rear audio sting and a floor shadow, then a whoosh. A dodge
  gives a slow-mo shimmer of 150 ms.
- Budgets (budget tier): ≤ 150 live particles, ≤ 24 visible objects, painter ≤ 6 ms/frame,
  cached Paints, zero per-frame allocations (same as ForestPainter). Screen shake ≤ 4 px, off in
  Gentle and with the reduce-motion setting.

### 10. Progression and cosmetics (earned only, never pay-to-win)

- **XP** uses the existing formula (score/20 + active s/10 + 50 per completed session) → Hero
  level.
- **Mela Tickets** (soft currency, earned only, no purchase): 1 per 1,000 points, +5 per completed
  session, +10 for the daily challenge. Spend on hand trails (10), pop effects (8), avatar skins
  (12), wall palettes (8), stall themes (6). Cosmetics never change hitboxes or windows.
- **Stalls (arenas):** Bubble Bazaar, Lantern Night, Kite Terrace, Monsoon Courtyard, Harvest
  Field, Starlit Ferris. Unlock 1 per 2 Hero levels (free set) and all of them in Premium.
- **Daily Remix:** a deterministic seed (IST date) shuffles the target order from the authored
  pool. The director stays deterministic and config-driven; same day, same content for everyone.
- **Personal bests** per mode × difficulty. "Zones reached" heat map over a week (what you
  did, never a body-measurement claim).
- **Pass-and-play** (2–4 players, one tracked at a time): each plays one 60 s Bubble Bazaar
  round with a shared scoreboard and auto-calibration per player (10 s quick version).

### 11. Social share (never camera video)

- During a round, the last **15 s of landmarks** sit in a RAM ring buffer: 15 s × 30 fps × 33
  points × (x, y, visibility) ≈ 180 KB. The buffer is dropped when the session ends.
- "Make my clip" renders **on device** (MediaCodec): avatar figure + game objects + score +
  combo + watermark "MotionQuest • Mirror Mela", 720×1280, 15 s, ≈ 3–4 MB MP4, Reels/Shorts
  ready. The player picks an avatar skin for the clip.
- Sharing uses the Android share sheet and needs a tap. **No auto upload. No camera pixels in any
  path. No landmarks sent to the server.** The rendered MP4 is saved to app cache and deleted
  after 24 h unless the player saves it.
- Alternate share: a static Rang Wall art card (PNG) and a result card (grade, best combo,
  stall).
- No body numbers on cards (no calories, no "burned", no weight). Copy: "I scored 18,420 at
  Mirror Mela".

### 12. Free and Premium (Google Play billing only; no nudges during play, rule 11)

| Free (unlimited play) | Premium (existing MotionQuest subscription) |
|---|---|
| Bubble Bazaar: all difficulties, 2 stalls | All 3 modes on all 6 stalls |
| Orbit: 1 stall | Rang Wall: full 40-wall library + 4 new walls/month (JSON content packs) |
| Rang Wall: 3 walls | Premium cosmetic set (6 skins, 4 trails), clip frame themes |
| Daily Remix, share clips, pass-and-play (Bubble Bazaar) | Pass-and-play in all modes, weekly Crew challenge boards |

Pricing suggestion, for the team to decide: fold into the MotionQuest plan (e.g. ₹99/month,
₹699/year). Shown only on the store screen and the post-session results screen, never during a
round. Gym-code access unlocks Premium for gym members.

### 13. Content and config (rules 7 and 8)

- Level JSON `mode: "mirror"` with `subMode: bazaar|orbit|rang`, `roundS`, encounters
  `{atS | atBeat, type: target|double|catchPlace|hazard|pose, zone, hand: left|right|any,
  minDifficulty, overhead: bool}`, plus a pose library JSON for Rang (body points, zones, angle
  ranges).
- Validator additions: per-hand spacing, overhead cap per 30 s, no collect within 1200 ms of
  a dodge, hazards ≥ 2.2 s warning and only in head/side bands, zones inside the 85 %/90 % frame
  clamp, breather has no hazards and no overhead.
- Simulator bots: competent (latency 150 ms, σ 60 ms) ≥ 90 % Good-or-better on every level ×
  difficulty. Slow (200 ms, σ 120, 15 fps) ≥ 60 % non-Miss on beginner. Dropout bot: 0 combo
  breaks from forgiven targets. One-arm and seated bots can reach 100 % of their targets.

### 14. Metrics (targets for beta)

| Metric | Target |
|---|---|
| Zone hit recall on recorded clips (≥ 20 players, 2 phones incl. budget) | ≥ 0.90 per zone |
| False pops (point in zone with no reach intent, idle 2 min) | ≤ 1 per 2 min |
| Miss rate per zone in the field | flag any zone > 35 % (mis-tuned anchor or radius) |
| Rounds with amber/red tracking > 10 % of time | < 8 % |
| 5-min session completion | ≥ 70 % |
| D1 / D7 retention (mode players) | ≥ 35 % / ≥ 15 % |
| Sessions per active player per week | ≥ 3 |
| Avatar vs mirror usage | track only; informs default |
| Clip made / clip shared per session | ≥ 15 % / ≥ 5 % (hypothesis, untested in India) |
| Free → Premium conversion from Mirror Mela players | track vs runner baseline |
| Performance | capture→judged < 200 ms budget tier, painter ≤ 6 ms, ≥ 15 fps |

### 15. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Preview–landmark lag looks broken (a pop happens after your hand has passed) | Judge and draw at landmarks, hand halo, avatar option; optional native preview delay; measure on budget tier first |
| Wrists marginal (8–12 px) on budget phones, motion blur | Zones big (≥ 0.36 T), end-state 2-frame dwell, hand = mean of 3 points, distance prompt 2.0 m |
| Hands near the frame edge drop visibility | Zones clamped inside 85 %/90 %; space check; `notVisible` reason shown |
| L/R swap when arms cross | No cross-body zones in v1; catch-and-place stays same-height and uncrossed |
| Arm camping (hands up all round) | Early-hold = Good max; zones alternate sides; overhead cap |
| Shoulder fatigue or strain | Overhead caps, breathers, Gentle profile, no rapid reaches; no medical claims anywhere |
| Small rooms in Indian homes; furniture or ceiling fans | Space check (arm span in frame); no jumps; reach only to the sides, never up past the calibrated overhead |
| Saree, dupatta, loose kurta hide elbows/knees | Hand point falls back to wrist; knee zones off if knee visibility is low (auto-swap to `side-*`) |
| Self-consciousness seeing yourself | Avatar mode one tap, suggested on first run |
| Screen capture of camera view | `FLAG_SECURE` while preview shows; clips are avatar-only |
| Novelty wears off after 2 weeks | Daily Remix, monthly Rang packs, pass-and-play, Crew boards |
| Looks like existing AR pop games | Original fair theme, musical-zone melody, pose-painting wall, rear-audio dodges; all assets original (rule 10) |

### 16. Build order (smallest playable first)

1. Body-point and zone hit-tester in `motion_core` (tests first: synthetic poses per zone,
   10/15/30 fps, noise, dropped frames, decoys: arms-up ≠ `hi-*` single, idle ≠ any zone).
2. `MirrorEngine` in `game_director` (RunEngine contract; grades, combo, forgiveness) +
   simulator bots.
3. Avatar-mode painter + Bubble Bazaar beginner level (1 stall). This is the vertical slice.
4. Native preview texture + crop/mirror rect + `FLAG_SECURE`; measure lag.
5. Orbit (reuses squat/lean) → Rang Wall (pose matcher) → clip renderer → upper-body gate
   (seated).

---

## 5 — GAME D: "Tapeball Tamasha" (self-view street cricket + India casual sports) — design brief (2026-11-05)

Read: AGENTS.md, docs/stages-roadmap.md (§2 World 5 Stadium Nights, §3.6 swing, §3.7 bowl, §6 bands, §7 Free/Premium),
scratchpad/research/3-tech.md (front-camera limits). No repo edits. Numbers marked *est.* need device/replay confirmation.

### 0. One line
A self-view backyard/gully cricket game: you see your own mirrored silhouette (stylised, never raw video — rule 2) standing on a
taped-up lane pitch; you **bat, bowl and field with body moves**, plus two India-loved casual mini-modes: **Raid Rush**
(kabaddi-style raid with side steps) and **Shuttle Rally** (badminton-style overhead reaches). Low-impact by default, no jumps,
no running toward the phone, empty hands always.

**Name:** *Tapeball Tamasha* (tape-ball = generic street-cricket term; "tamasha" = spectacle). Backups: *Backyard Boundary*,
*Gully Games Night*. Run a trademark + Play Store search before lock-in. **Avoid "Chhakka"** as a title word (also used as a slur
in parts of India). Avoid "Premier", "League", "IPL", "T20 World", "Super Kings", "Indians", "Royals", "Knight", "Titans",
"Capitals", "Sunrisers", "Giants" in any title, mode, crew or cosmetic name.

### 1. Fit with what exists
- Reuses roadmap moves: batting swing (§3.6, `ball`), bowling action (§3.7, `wicket`), squat, lean, side step, raise arms,
  barrier hold, march/knee lift (3-tech §4.1). New: `catchZone` (end-pose reach), `overheadReach` (one-arm high side zone).
- Engine: a judged-target engine like 3-tech's `BeatEngine` contract (`input`, `advance`, `RunEvent` out) — a **delivery is a
  target with `atMs`**; no lanes needed. Level schema v2 `mode: "cricket" | "raid" | "shuttle"` plus a `match` block
  (`balls`, `targetRuns`, `wicketsAllowed`, `bowlerSeed`). All formats are JSON configs (rule 7); director deterministic and
  seeded (rule 8) so crew tournaments are fair (same seed = same deliveries for everyone).
- Visual: reuse `SceneTheme.stadium` colours for the Stadium Nights theme; new gully/terrace/maidan themes as palettes.
- World 5 Stadium Nights stays as the runner world; Game D is a **separate mode hub** ("Sports" tab) that shares recognisers.

### 2. Core loop (one delivery ≈ 10–14 s)
1. **Set** (2 s): stand on the crease marker (centre). HUD shows a mirrored silhouette + "space ring".
2. **Delivery telegraph** (band warning time: Gentle ≥ 2.0 s, Balanced ≥ 1.6, Active ≥ 1.3): stylised original bowler
   (a cartoon neighbourhood character or the original "bowling machine" from w5) runs in; **approach ring** shrinks onto the
   hit zone — the ring *is* the timing window (3-tech §4.5).
3. **Shot** (player): backlift → swing (or leave / defend). Graded Perfect/Good/OK/Miss on capture timestamp with latency
   compensation (3-tech §3.2).
4. **Outcome** (game state decides, rule 6): grade + chosen shot + fielder layout (seeded) → 0/1/2/4/6 or caught.
5. **Run between wickets** (cardio beat, optional by band): on 1s/2s the HUD says "Run!" → **march in place**; every 4 steps
   = 1 run before the throw-in bar fills. Never forward running, never a sprint (cadence target ≤ 2 Hz *est.*).
6. **Reset / breather** (2–3 s): replay of your shot as a stylised animation (no video), commentary line.
Bowling innings mirror the loop (you bowl, AI bats, then you **field** the ball it hits).

### 3. Move → action mapping (front camera, 2.0–2.5 m, Lite model)
All recognisers fire on **end states held ≥ 2 frames**, never on velocity (3-tech §3.1). Every reject emits a reason
(`notVisible | tooShallow | tooEarly`) so the HUD can explain (rule 5, Q5-8).

| Action | Move | Detection notes | Verdict |
|---|---|---|---|
| **Drive / ground shot** | Batting swing §3.6: wrists together (< 0.3 torso), backlift at/above trailing shoulder held 100 ms, wrist midpoint travels ≥ 1.0 shoulder width (low-impact 0.6, no rotation) to front hip, 250–1200 ms | Use **wrist midpoint**, not L/R wrist — avoids MediaPipe L/R swap when wrists cross. Swing is lateral/in-plane (across body), not toward camera. Hips within 0.5 torso = no lunge. 1.5 s cooldown. | Reliable (end states) |
| **Lofted shot** (bonus, can give 6) | Same swing, but end zone is **shoulder height or above** on the front side, held 2 frames | End-zone y relative to shoulder line is coarse and robust. Ship as bonus only until replay data confirms. | Medium |
| **Leave** | Both hands high: wrists above nose ≥ 0.15 torso (raise-arms) during the ball window | Existing `raiseArms`. Engine resolves by encounter: during a delivery window, raise = leave. Leaving a wide ball = good judgement bonus. | Reliable |
| **Defend / block** | Barrier hold at chest (existing `BarrierHoldRecogniser`) across arrival ±200 ms | Already shipped; foreshortened push is *only* used as a static hold, never as a punch-like strike. | Reliable |
| **Bowl** | Bowling action §3.7: standing, straight arm (≥ 150°, low-impact 130°) above nose ≥ 0.3 torso → wrist below hip on front side in 400–1500 ms | No run-up, no step. Overhead-only start state, sweep down is in-plane. 1.5 s cooldown. | Reliable |
| **Line choice (bowling)** | Side step L / centre / R before the "ready" tone | Existing `SideStepRecogniser`. Picks off/middle/leg target. | Reliable |
| **Pace vs slower ball** | Tempo of the bowl: start→complete ≤ 800 ms = pace, 900–1500 ms = slower ball | Duration between two end states (frame-quantised ±67 ms at 15 fps) — not a velocity threshold. Wide gap between bands absorbs jitter. | Medium (ship as "bonus") |
| **Catch (high)** | `catchZone`: both wrists together (< 0.35 torso) in a lit zone — high-left / high-centre / high-right — held 2 frames before ball lands | Zones are relative to torso (3-tech: wrists marginal in px → zones, not angles). High-centre collides with raise-arms: wrists-together distinguishes it. | Reliable *est.* |
| **Catch (low) / ground stop** | Half squat (hip drop ≥ low-impact squat) + both wrists below hip, on the side the ball comes (lean or side step first) | Squat + lean already shipped. **No dives**, no lunges — "step and get low". | Reliable |
| **Throw-in** | Raise one arm overhead (bowl start state) and hold 300 ms → "throw" | End state only; a gentle overhead hold, not a fling. Counts toward overhead cap (§9). | Reliable |
| **Celebrate** (optional, no score) | Both arms up held 1 s | Flavour only; never required. | Reliable |
| **Raid Rush: dodge** | Side step L/R | Existing. | Reliable |
| **Raid Rush: touch** | Lateral open-hand reach to the side: reach ≥ 0.75 armLength (low-impact 0.6), elbow ≥ 145°, wrist at shoulder ±0.3 torso, held 2 frames | Same signal as lateral punch (3-tech §2) but **slow and held** — no punching motion. Targets placed ≥ 30° off-axis so reach is in-plane. | Reliable |
| **Raid Rush: duck the chain** | Squat (low-impact half squat) | Existing. | Reliable |
| **Raid Rush: bonus line** | Toe-tap reach (Gentle) / knee lift (Active) | Knee lift recogniser (3-tech §4.1). No hops. | Reliable |
| **Shuttle Rally: smash / clear** | `overheadReach`: one wrist above nose ≥ 0.3 torso **and** offset to the shuttle side (wrist x beyond shoulder), held 2 frames | Distinct from bowl (no sweep-down needed) and from raise-arms (one arm, side offset). Engine resolves by encounter; never place a `wicket` and a shuttle within 2 s. | Reliable *est.* |
| **Shuttle Rally: net drop** | Side step + mid-height reach on that side | No lunges toward the net (= toward the camera). | Reliable |
| **Shuttle Rally: move across** | Side step | Existing. | Reliable |

**Explicitly banned (detection + safety):** forward lunges, steps or runs toward the phone; punch or swing *at* the camera;
dives; jumps (unless the player enables them, and then only in Raid Rush as a "small hop"); wrist flicks for spin (undetectable
at 8–12 px wrists); fast repeated swings (blur); twisting under load (rotation requirement off in low-impact).

### 4. Match formats (all JSON configs, all ≤ 4 min of play)
| Format | Rules | Length | Bands |
|---|---|---|---|
| **Nets** | Free practice, 12 balls, hints, no outs; shows grade + "why" for every miss | 2–3 min | All; Free |
| **Super Over** | Bat 6 balls, 2 wickets max (beginner: no wickets — misses are dots), then bowl 6 balls to defend your total; fielding in between | 2 × ~75 s + breaks ≈ 3:30 | All |
| **3-Minute Chase** | Need *T* runs in 18 balls (T seeded by difficulty: 18 / 26 / 34 *est.*); timer only runs while tracking is green | 3:00 | All; Premium |
| **Bowl-Out** | 6 deliveries at lit stumps (line + tempo variety), AI defends | ~90 s | All; warm-up friendly |
| **Fielding Drill** | 10 catches / stops, zones random-seeded, march-back between | ~2 min | All |
| **Gully Match** | 2 overs bat + 2 overs bowl vs AI side, breather card between innings | ~8 min | Balanced/Active only, Premium |
| **Raid Rush** | 3 raids × 30 s "breath bar"; tag defenders (touch), dodge, return to midline (side step centre) | ~2:30 | All |
| **Shuttle Rally** | Rally to 11 (best of 1), rally continues until a miss; shuttle hang time 1.6–2.4 s | ~3 min | All; Premium |

Rules that keep it fair and safe:
- **Tracking failure (rule 5):** any delivery whose window overlaps amber/red tracking is a **"dead ball"** — re-bowled, no run,
  no wicket, the chase timer pauses, HUD explains ("Step back — I lost your hands").
- **Rule 6:** a swing with no ball in window does nothing. A swing out of timing just misses.
- Wickets only on intermediate+; a wicket is only possible on a ball telegraphed "stumps lit" (bowled) or a catch the AI fielder
  takes from an OK-grade lofted shot. Never more than 2 wickets lost per Super Over.
- Deliveries of one over never mix a `ball` and a `wicket` within 3 s (w5 rule); after a bowl or overhead, 2 s empty.

### 5. Difficulty × age bands (compose with §6 of the roadmap)
| | Gentle (default) | Balanced | Active |
|---|---|---|---|
| Warning (ball telegraph) | ≥ 2.0 s | ≥ 1.6 s | ≥ 1.3 s |
| Swing window | ±550 ms (assist) | ±350 → ±300 | ±300 → ±250 |
| Swing thresholds | low-impact (0.6 width, no rotation) | low-impact until calibrated twice | standard (1.0 width, ≥ 15 % rotation) |
| Bowls per session (max) | 12 | 18 | 24 |
| Overhead moves / min (bowl + smash + throw) | ≤ 4 | ≤ 6 | ≤ 8 |
| Run-between-wickets march | off (auto-run) | on, 4 steps/run | on, 4 steps/run, longer chases |
| Wickets | none on beginner | 2 | 2 (3 in Gully Match) |
| Raid Rush bonus line | toe-tap | toe-tap | knee lift |
| Rally speed | hang time 2.4 s | 2.0 s | 1.6 s |
Safe-progression rules (one step per week of play, deload every 4th, struggle and comeback rules) apply as written in §6.

### 6. Commentary and voice (en / hi / gu)
- **Original pre-recorded voice actors** (one male, one female per language) — no TTS of real commentators, no imitation of
  famous voices, catchphrases or broadcast jingles. ~250 lines per language at launch, keyed by event
  (`perfect_drive`, `lofted_six`, `dot`, `dead_ball_tracking`, `wicket_bowled`, `catch_taken`, `run_call`, `chase_close`,
  `streak_5`, `warmup`, `space_check`). Deterministic picker with a no-repeat window of 20 lines (seeded, rule 8).
- Hindi and Gujarati use natural code-switching ("Kya timing hai!", "Shabash, ekdum seedha bat!", Gujarati:
  "Wah, jordar shot!", "Dhire dhire, saras!"). Native-speaker review for slang that is crude in one region.
- Tone: neighbourhood "mohalla" commentator, warm and funny about *the game*, never about the body. No weight, calorie or
  health lines (AGENTS.md). Allowed: "Nice rhythm!", "Great balance!". Banned: "burn", "tone", "fat", "lose".
- Tracking lines blame the camera, never the player: "Arre, the camera lost you — take one step back."
- Audio-only cues for every ball (whistle on delivery, "thwock" on hit) so the game is playable by ear. Subtitles always on.
- **No microphone**: no voice shot-calling, no chant detection (new permission, privacy surface).
- Crowd = generated murmur, no real chants or team songs; swell on 5+ streak (w5 rule).

### 7. Progression and cosmetics
- **Player card** (no real-player likeness): level 1–50 from "Gully Rookie" to "Maidan Legend" (original titles); XP from
  balls faced, catches, raids — not from minutes (avoid encouraging overplay; daily XP soft cap after 3 sessions).
- **Skill badges** (end-state skills): "Straight Bat" (10 Perfect drives), "Safe Hands" (20 catches), "Line & Length"
  (6 bowl-out hits), "Raid Ninja", "Shuttle Wall".
- **Cosmetics — all earned by play, none sold individually, no loot boxes, no random drops:**
  - Bats: tape-ball bat with coloured grip tape, plank bat, painted-stripes bat, glow bat (Stadium Nights), monsoon bat.
  - Kits: original colour palettes reviewed against a **deny-list of franchise colour combos** (two-colour primary pairs in
    current pro-league use); patterns: block-print border, kite-festival stripes, plain whites for "Classic".
  - Stadium themes: *Gully Lane* (scooters, parked cycles, a water tank as stumps), *Terrace Top* (washing lines, kites),
    *School Maidan*, *Beach Evening*, *Monsoon Ground* (rain shimmer), *Stadium Nights* (reuse `SceneTheme.stadium`).
    No real grounds or skylines; no deity imagery or religious symbols (roadmap rule).
  - Mini-mode skins: kabaddi mat colours, shuttle trails.
- **Avatar:** the self-view silhouette wears the kit as a stylised overlay drawn from landmarks only (no camera pixels shown,
  stored or uploaded — rules 2/4).

### 8. Gym crew tournaments (server gyms + progress + reports modules)
- A gym creates a **crew** (4–11 members) or joins a gym league; members are verified gym members (entitlement → Premium free).
- **Format:** weekly "Crew Cup". Every member plays the **same seeded Super Over / Chase** (deterministic director → identical
  deliveries). Crew score = sum of each member's best 2 counted attempts that week; **max 3 counted attempts per day** and
  every attempt ≥ 4 h apart (stops grinding; no "no breaks" mode).
- **Divisions by band** (Gentle / Balanced / Active) so a 55-year-old member is never ranked against a 22-year-old's
  thresholds; crew score normalises each attempt to its band par.
- Knockout bracket: 8 crews, quarter/semi/final over 3 weeks; async within a 48 h window per round.
- Anti-cheat without video: server plausibility checks on uploaded **event summaries** (grades, timing deltas, landmark
  quality stats, fps) — impossible-timing streaks or fps anomalies flag for review; tracking-forgiven balls are excluded.
- Gym owner dashboard (reports module): participation, attendance-linked streaks — no individual body metrics shown.
- No prizes of monetary value; trophies are in-app cosmetics + gym wall certificate (avoid prize-competition / real-money
  gaming rules; keep clear of India's 2025 online gaming law on real-money games).

### 9. Space and injury safety (the biggest real risk)
Indian homes: small rooms, **ceiling fans at 2.4–2.7 m**, glass cabinets, TVs, children and pets walking in.
- **Space check before every cricket/shuttle session** (≈ 15 s, mandatory first time each day):
  1. "Stand where you'll play" — QualityGate full-body-in-frame at ≥ 2.0 m (body ≤ 65 % frame height *est.*).
  2. "Arms out wide" (T-pose) and "both arms up": both wrists must stay inside the frame with ≥ 8 % margin — proves the player is
     far enough from the phone; also calibrates arm length/shoulder width for the swing.
  3. Self-checklist (tap each): **Fan switched off** · **1 m clear on each side and above your hands** · **Nothing breakable
     within reach** · **No real bat, racket or ball in your hands** · **Dry, non-slip floor / bare feet or trainers**.
  4. If the check fails or is skipped, only *Nets (low-impact, no overhead)* and Raid Rush (side steps) are offered.
- **Empty hands rule:** pose models can't see objects reliably, so the game never asks for props; loading tips repeat it.
- **Intruder pause:** if a second person enters the frame (Pose Landmarker `numPoses = 2` on upper-mid devices; on budget, sudden
  landmark jumps / quality drop) → instant pause "Someone's in your play space." Tracking loss pause already covers the rest.
- **Overhead shoulder load:** per-band caps (§5); optional "switch arm" every over in bowl-out (balanced load, also helps
  left/right symmetry); 2 s empty after every overhead move.
- **Back:** rotation requirement off in low-impact; swing hips-stable guard prevents lunge; no full-power "slog" bonus.
- **No forward motion toward the camera** anywhere (detection *and* tripping/phone-knock safety).
- "This doesn't feel right" button on pause → end gently, keep progress, standard disclaimer (§6 rule 6).
- Warm-up (45 s: arm circles, gentle trunk turns, march) and cool-down auto-inserted around the first session of the day.

### 10. Cricket-season timing without IP
- Run a **"Summer Cricket Fest"** event window roughly mid-March → early June (when the big domestic T20 season and exam-free
  evenings coincide) and short "Cricket Fever Week" windows around major international tournaments — all named generically.
- Never use league/tournament/team/player names, trophies, fixtures, match results, scores or broadcaster graphics
  (score-bug layouts, replay wipes, sponsor-style overlays). No "official", no "live match" tie-ins, **no prediction or
  "pick the winner of tonight's match" features** (fantasy/real-money adjacency).
- Play Store listing and ASO: no trademarked league or team names as keywords (Play metadata policy + trademark risk).
- Evening-friendly: Daily "Over of the Day" refreshes at 18:00 IST so a 3-min session fits before evening matches; no push
  notifications timed to real match starts.
- Festival crossovers reuse existing event rules (Diwali lights theme for Stadium Nights, Holi colour bats) — no religious symbols.

### 11. Free vs Premium (Google Play Billing only, access checked at mode select, never mid-match — §7 rules)
| Free | Premium (₹129/mo, ₹699/yr; gym members free) |
|---|---|
| Nets, daily Super Over ("Over of the Day"), Bowl-Out, Raid Rush taster (1 raid set), Gully Lane theme, 3 bats, 2 kits, joining a gym crew if their gym grants it | 3-Minute Chase, Gully Match, Fielding Drill, full Raid Rush, Shuttle Rally, all themes, all cosmetic tracks, creating private crews/leagues, Festival events |
No ads with payment nudges, no links outside Google Play (rule 11), no paywall on a results screen after a loss.

### 12. Metrics
- **Fun/retention:** D1 / D7 / D30; sessions per active week; Super Overs per session; % chases finished; mode mix.
- **Motion quality (from replay + telemetry, no video):** swing recall ≥ 0.9 and false-trigger ≤ 1 / 2 min idle (replay gate,
  ≥ 20 players, 2 phones incl. budget); reject-reason rates per move (notVisible / tooShallow / tooEarly); dead-ball rate
  (target < 5 % of deliveries); median latency-compensated timing delta and spread; fps distribution.
- **Fairness:** win rate of seeded chases by band (target 55–75 % beginner); simulator bots (`competent`, `slow` 200 ms/15 fps,
  dropout) all pass feasibility gates before a config ships.
- **Safety:** space-check completion and failure rate; "doesn't feel right" taps per 1 000 sessions; intruder pauses per session;
  overhead-cap hits; support tickets tagged injury/property (target ~0; any → review).
- **Business:** Free → Premium conversion from Sports hub; crew participation (% gym members playing weekly Crew Cup); crew
  retention vs solo.
- "Active minutes" only — never calories or fitness outcomes.

### 13. Risks and mitigations
| Risk | Mitigation |
|---|---|
| **IP / trademark** (league, franchises, players' likeness, stadiums, trophy shapes, broadcaster look, commentator voices, team colours) | Original characters, grounds and voices; colour deny-list; legal review of name, icons, commentary script; no real-match tie-ins; generic event names. |
| **Real-money / gambling adjacency** | No predictions, no cash/coupon prizes, no betting language ("odds", "stake"). |
| **Injury from swinging in small rooms** (fans, furniture, glass, kids/pets) | Mandatory space check, fan-off checklist, frame-margin distance test, empty-hands rule, intruder pause, low-impact default, overhead caps. |
| **Shoulder/back strain** from repeated bowling, smashes or rotation | Per-band overhead caps, 2 s gaps, no rotation in low-impact, warm-up, deload rules. |
| **Detection: L/R wrist swap** when hands cross the body in a swing | Use wrist midpoint + wrists-together, not per-wrist identity. |
| **Detection: blur on fast swings** (15–30 fps) | End-state backlift + end-zone detection; travel window 250–1200 ms; no speed bonus. |
| **Overlap between raise-arms / bowl / overhead reach / catch-high** | Engine resolves by active encounter; never two overhead-family targets within 2 s; wrists-together disambiguates catch. |
| **Latency makes timing feel unfair** | Latency compensation on capture timestamp, wide windows, approach ring visualises window, dead-ball on tracking loss. |
| **Loose clothing / saree / dupatta hides wrists or knees** | `notVisible` reason + hint; low-impact thresholds; march detection falls back to auto-run. |
| **Low intensity** (cricket is mostly standing) | Run-between-wickets march, fielding drills, Raid Rush; keep it fun-first, not a fitness claim. |
| **Repetition boredom** | Seeded bowler variety (line, slower balls, "googly" visual-only fake-outs), themes, mini-modes, weekly Crew Cup. |

### 14. Build order (smallest valuable slice first)
1. Nets + Super Over (bat only) on existing swing/raise/barrier recognisers + space check + commentary (en).
2. Bowl-Out (bowl + side-step line) and fielding (`catchZone`, low stop), then full Super Over.
3. Crew Cup (seeded attempts, server summaries, plausibility checks).
4. Raid Rush (side step, lateral touch, squat), then Shuttle Rally (`overheadReach`).
5. hi/gu voice, Summer Cricket Fest themes, Chase and Gully Match.
Each step: recorded-data replay gate for any new recogniser (AGENTS.md: tests first, no threshold change without replay pass).

---

## Game E: PATAKA POSE, a self-view party pose game (design draft, 2026-11-05)

Status: design proposal only. Nothing in the repo is changed. Inputs: AGENTS.md rules 1–11, research/1-market.md
(mirror/pose matching is the top Nex mode; pass-the-phone play; ~3 min rounds) and research/3-tech.md (end-state not
velocity; never threshold absolute z; Lite model; ≥ 15 fps budget; ~110–180 ms pipeline latency; wrists and ankles
are the weakest landmarks).

> **One-second pitch:** "Freeze in the shape before it reaches you." A glowing *pataka* (firecracker) cut-out frame
> flies toward the player. Strike the shape and hold it until it passes, and it bursts into confetti.
> Break the shape and it pops a silly *phuss*.

Name check: "Pataka" is everyday Hindi/Marathi slang for a firecracker and also for a show-stealing person
("woh toh pataka hai!"). The name is generic, not trademark-bait, and carries no deity imagery. The working
alternative is **"Freeze Bazaar"**. The approaching-cut-out mechanic is a common genre convention, so the visual
form must be our own: rangoli-light frames, Kavi's paper-lantern props, the mela setting. We copy no show format,
wall look, sound or catchphrase.

---

### 1. Why this game fits MotionQuest

| Constraint | How Pataka Pose meets it |
|---|---|
| MediaPipe strengths (static whole-body shapes) | Every judgement is made on an **end-state held pose**, never on velocity (3-tech §2 rule 1). |
| Lite-model weakness at wrists and ankles | Scoring weights **shoulder, elbow, hip and knee angles**. Wrists and ankles are used only for coarse zones such as "above the head" or "foot off the floor". |
| No absolute z (3-tech) | All angles are 2-D image-plane angles. Poses that only differ in depth (forward punch, arms forward) are **banned** from the library. |
| Latency 110–180 ms | A hold-based game needs no beat timing. Latency only delays the "locked!" sparkle, and the hold window absorbs that. |
| Rule 5 (tracking failure costs nothing) | If visibility drops, the frame **slows and hovers** with "Kavi can't see your knees, step back." There is no fail and no score penalty. |
| Rule 6 (a move does nothing on its own) | Outcomes depend on game state: frame type, hold timer, combo, team turn. |
| Rule 7 (JSON content) | Pose library, round playlists and festival skins are JSON under `content/` and validated by schema. |
| Rule 9 (low-impact) | No jumps. Every pose has a seated, wall-support or reduced-range variant. Jump-y "star burst" poses are opt-in and off by default. |
| Party / pass-the-phone (1-market rec 4) | One tracked body at a time is the default. Turn-taking and teams need no multi-person tracking. |

---

### 2. Core loop (one round ≈ 2.5–3 min)

```
 [Show]  silhouette preview appears small on the horizon (2.0–3.5 s lead, by difficulty)
   │      + Kavi calls the pose name ("Cutting Chai!")
 [Match] player moves; live "stick-glow" skeleton (from landmarks) shows matched limbs green, off limbs amber
   │
 [Lock]  similarity ≥ lock threshold for ≥ 2 consecutive frames → hold timer starts (ring fills)
   │
 [Hold]  keep ≥ hold threshold (lock − 8 pts hysteresis) for holdMs → frame BURSTS (confetti, combo +1)
   │      dip below → ring pauses (not resets) for 300 ms grace, then drains at 2× fill speed
 [Pass]  frame reaches player: score = best sustained similarity × hold completion; star rating 0–3
   │
 [Breather] every 4–6 frames a "Chill Frame" (stand tall, shake out) = active recovery, still scored lightly
```

- **Readable in one second:** one verb, "hold the shape".
- **Mastery layer:** per-pose personal-best %, 3-star medals, combo streaks, and perfect-round "Pataka!" bonuses.
- **Self-view:** the background is the game scene, never the camera image. The player sees a **landmark-rendered
  avatar** (stick-glow or a cosmetic costume rig) over the scene. A small optional "mirror" PIP of the live camera
  can show *on-screen only*, for framing, never recorded (rule 2). Default: avatar only. The PIP is a settings toggle.
- **Mirroring:** the display is mirrored (selfie convention). Pose definitions use **player-left/right**, and the
  matcher compares the definition with the un-mirrored landmarks. "Raise your RIGHT arm" means the arm on the right of
  the screen, which is the player's right because the display is a mirror. This is tested explicitly (§13).

#### 2.1 Frame types (all JSON-defined)
| Frame | Behaviour | Purpose |
|---|---|---|
| **Cut-out Frame** | Standard: match + hold before arrival. | Core. |
| **Statue Bazaar** | Lights go "off" for 3–5 s; player must stay frozen (low motion energy *and* pose held). Kavi tries to make you laugh. | Living-statue comedy. |
| **Mirror Kavi** | Kavi (a puppet character) strikes a pose, then the player copies it. Sometimes Kavi does it *mirrored* on purpose and says "mirror-mirror!" | Dance-freeze feel without beat timing. |
| **Sequence Chain** | 2–3 poses in a row, each held 800–1200 ms, flowing (e.g. Tree → Warrior → Star). | Yoga-inspired flow framed as a "combo move". |
| **Balance Lantern** | Hold a one-leg pose; a lantern floats higher the longer you hold, up to 8 s. Can be put down any time with no penalty. | Balance challenge, opt-in, support allowed. |
| **Blink Frame** (advanced) | Silhouette shown for 1 s then hidden; strike it from memory. | Memory/laughs. |
| **Chill Frame** | Stand tall / shoulder rolls. Always passes. | Recovery, pacing. |

---

### 3. Pose matching and similarity

#### 3.1 Features (all 2-D, scale-invariant, from the 33 landmarks + visibility)
Each pose defines a target for a subset of these **features**. Angles are in degrees, image plane, player-left/right:

| Feature id | Definition | Landmarks |
|---|---|---|
| `shoulderAbd.L/R` | angle between torso-down vector (shoulder→hip) and upper arm (shoulder→elbow); 0 = arm down, 90 = T, 180 = straight up | 11/12, 23/24, 13/14 |
| `elbowFlex.L/R` | interior angle shoulder–elbow–wrist; 180 = straight | 11–13–15 / 12–14–16 |
| `hipAbd.L/R` | angle between pelvis-down vertical (hip-mid → down, torso-aligned) and thigh (hip→knee) | 23/24, 25/26 |
| `kneeFlex.L/R` | interior angle hip–knee–ankle | 23–25–27 / 24–26–28 |
| `torsoLean` | signed angle of hip-mid→shoulder-mid from image vertical (+ = lean to player right) | 11,12,23,24 |
| `zone.wristL/R` | coarse zone of wrist relative to body: `overhead` (above nose−0.1 torso), `head` (≤ 0.45 torso from nose), `chest`, `hip`, `low`, `side-out` | 15/16, 0, torso len |
| `footLift.L/R` | ankle y above standing ankle y by ≥ 0.12 torso (calibrated) | 27/28 |
| `stance` | ankle spread / hip width: `narrow` < 1.2, `normal` 1.2–2.0, `wide` > 2.0 | 23,24,27,28 |

Torso length = mean(shoulder–hip distance L, R). It is recomputed from calibration and is never taken from z.

#### 3.2 Similarity score (0–100 %)
For each feature *i* in the pose with weight *wᵢ*, tolerance *tolᵢ* and falloff *fᵢ*:

```
angle features:  sᵢ = clamp(1 − max(0, |Δθᵢ| − tolᵢ) / fᵢ, 0, 1)          (Δθ wraps at 180)
zone/stance/lift: sᵢ = 1 if in target zone, 0.5 if in an adjacent zone, else 0
visibility gate:  if any landmark of feature i has visibility < 0.5 → feature is "unseen"
similarity = 100 × Σ wᵢ·sᵢ / Σ wᵢ          (over seen features only)
```
- **Unseen rule (rule 5):** if unseen features carry > 30 % of the pose weight, the frame **hovers** (it stops
  approaching), Kavi explains what is not visible, and **no score is recorded** for that frame. The frame must never be
  scored generously from a partial view, because that gives free points to an out-of-frame player.
- **Defaults** (beginner): `tol` 20°, `f` 30° for shoulders and hips; `tol` 25°, `f` 35° for elbows and knees;
  torsoLean `tol` 10°, `f` 15°. Intermediate tightens tol by 5°, advanced by 10°. These go in `docs/game-design.md`
  as named thresholds once they are approved.
- **Smoothing:** use the existing One Euro filtered landmarks. Similarity is a 3-frame median, which kills single-frame
  spikes.
- **Lock / hold:** lock at ≥ 75 % (beginner) / 80 / 85 for ≥ 2 frames; hold threshold = lock − 8 (hysteresis).
  `holdMs` is per pose (§4). The effective hold is `max(holdMs, 3 × frameIntervalMs)`.
- **Freeze check (Statue Bazaar only):** mean per-landmark displacement of 12 core joints per frame is < 0.02 torso
  (filtered). The tolerance is generous so breathing and phone wobble pass.
- **Anti-cheese:** per-feature weights stop "near-miss everything" from scoring high. Each pose also lists 1–2
  **must** features: if a must feature has sᵢ < 0.4, similarity is capped at 60 %. Example: Tree must have
  `footLift` on one side.
- **Mirror acceptance:** symmetric-option poses (`mirrorOk: true`) are scored against both the pose and its L/R swap,
  and the better score is taken. Beginner sets `mirrorOk` true on most poses.

#### 3.3 Score per frame
`frameScore = round(peakSustainedSimilarity × holdCompletion)` where peakSustained is the best 300 ms-window median
during the hold. Stars: ★ ≥ 60, ★★ ≥ 80, ★★★ ≥ 92 and a full hold. Combo multiplier ×1.0 → ×1.5 (caps at 6 frames).
A tracking hover breaks nothing: the combo is preserved.

---

### 4. Pose library (24 poses + low-impact variants)

Legend: **Key features** with target angles (beginner tolerance from §3.2 unless noted). **Must** = cap feature.
**Hold** = beginner/advanced ms. **LI** = low-impact / seated / supported variant. **Safety** notes are used for
Kavi's cues. None of these are medical claims. They are framed as "shapes", not therapy.

| # | Name (in-game) | Key features (targets) | Must | Hold ms | LI variant | Detection / safety notes |
|---|---|---|---|---|---|---|
| 1 | **Star Burst (Tara)** | shoulderAbd L/R 135°, elbow 170°, stance wide, hipAbd L/R 20° | stance wide | 1500/2500 | Arms at 110°, normal stance | Very robust. No jump; a jumping star is an opt-in variant only. |
| 2 | **Cutting Chai** (one hand on hip, other arm "pouring" up-side) | shoulderAbd L 45° + elbowFlex L 90° + zone.wristL hip; shoulderAbd R 150° | wristL hip | 1500/2500 | Seated OK (upper-body only) | `mirrorOk`. Hand-on-hip zone is robust even if the wrist is low-vis. |
| 3 | **Goalpost** | shoulderAbd L/R 90°, elbowFlex L/R 90° (forearms up) | both elbows 90 | 1500/2500 | Seated | Classic, very readable. |
| 4 | **Lamp Post** (arms straight up) | shoulderAbd L/R 170°, elbow 170°, torsoLean 0 | both > 150 | 2000/3000 | One arm up, alternate | Cue: "relax shoulders, no straining". |
| 5 | **Teapot** (side bend, one hand on hip) | torsoLean ±20°, wrist on hip one side, opposite shoulderAbd 160° | torsoLean | 1500/2500 | Lean 10° | `mirrorOk`. torsoLean tol 8°. Cue: "gentle, only as far as comfy". |
| 6 | **Auto-Rickshaw Driver** (seated-style, both arms forward-low, knees bent) | kneeFlex L/R 120°, shoulderAbd 40°, elbow 120°, zone.wrist chest | kneeFlex | 1500/2500 | Actually sit on a chair, arms only | Avoids forward-arm depth: judged on knee bend + elbow angle, not reach. |
| 7 | **Chair Pose / Kursi** (mini-squat, arms up) | kneeFlex L/R 130° (beginner) / 110° (adv), shoulderAbd 150° | kneeFlex | 1500/3000 | Knees 150°, hand on chair back | Needs knees visible; hover if not. Cue: "knees over toes, not past". |
| 8 | **Tree (Vriksha-ish, "Coconut Tree")** | footLift one side, kneeFlex lifted 90–120°, hipAbd lifted 35°, wrists overhead or chest | footLift | 2000/4000 | Toe stays on floor (kickstand); hand on wall | `mirrorOk`. Balance: "hold a wall, it's still a tree". Not judged on foot-on-thigh placement (ankle unreliable). |
| 9 | **Flamingo** | footLift one side, kneeFlex lifted 90°, arms shoulderAbd 90° | footLift | 2000/4000 | Toe tap; wall support | Same as Tree; lantern balance variant. |
| 10 | **Warrior Wave** (wide lunge-ish stance, arms T) | stance wide, kneeFlex front 130°, back 170°, shoulderAbd 90° both | stance wide | 2000/3000 | Narrower stance, knee 155° | 2-D: side-on stance shrinks; use front-facing wide stance. `mirrorOk`. |
| 11 | **Archer** (bow-draw: one arm out straight, other bent at chest) | shoulderAbd L 90° elbow 175°; shoulderAbd R 90° elbowFlex R 60° | lead elbow | 1500/2500 | Seated | Lateral, so no depth ambiguity. `mirrorOk`. |
| 12 | **Bhangra Shoulders** (both arms up, elbows bent, wrists overhead) | shoulderAbd 150°, elbowFlex 120°, zone.wrist overhead | wrists overhead | 1200/2000 | One arm | Freeze only; no shimmy judged. |
| 13 | **Surprise! (Arre Wah)** (hands on cheeks / head) | zone.wrist head both, elbowFlex < 60° | zone head | 1000/1800 | Seated | Hands near face → wrists may swap/low-vis: zone-only, tolerant. Comedy pose. |
| 14 | **Thinking Statue** (one hand chin, other across waist) | zone.wristL head, zone.wristR hip/chest, elbowFlex L 45° | wristL head | 1500/2500 | Seated | `mirrorOk`. Statue Bazaar favourite. |
| 15 | **Selfie Stick** (one arm up-diagonal, other hand peace near face) | shoulderAbd L 140° elbow 170°; zone.wristR head | lead arm | 1200/2000 | Seated | Peace sign NOT judged (hands not tracked). Display-only. |
| 16 | **Kite Flyer (Patang)** (both arms up-diagonal to one side, lean) | shoulderAbd L 150° R 110°, torsoLean ±10° | torsoLean | 1500/2500 | No lean | `mirrorOk`. Makar Sankranti hero pose. |
| 17 | **Robot Freeze** (one arm up 90/90, other down 90/90) | shoulderAbd L 90° elbow 90° (up), shoulderAbd R 90° elbow 90° (down via wrist zone low) | wrist zones | 1200/2000 | Seated | Up/down forearm differentiated by wrist zone, not angle. |
| 18 | **Superhero Landing (standing)** (hands on hips, wide stance, chest proud) | zone.wrist hip both, stance wide, torsoLean 0 | wrists hip | 1500/2500 | Normal stance | No actual landing/jump. |
| 19 | **Side Lunge Sweep** | stance wide, kneeFlex one 130° other 170°, torsoLean ±10° | bent knee | 1500/2500 | Knee 150° | `mirrorOk`. Cue: "toes forward". |
| 20 | **Airplane (Hawai Jahaaz)** (T-arms, lean to one side) | shoulderAbd 90° both, torsoLean ±15° | torsoLean | 1500/2500 | Lean 8° | Fun with "turbulence" wobble animation. |
| 21 | **Knee Hug Hero** (one knee raised, hands near knee) | footLift one side, zone.wrist hip/low both, kneeFlex lifted < 90° | footLift | 1200/2000 | Knee lift small, hands on chair | Balance. Wall/chair support allowed and encouraged. |
| 22 | **Lotus Wave (seated or standing)** (both arms overhead, palms "together") | shoulderAbd 165° both, wrists distance < 0.35 torso, overhead | wrists together | 1500/3000 | Seated cross-legged NOT required, any seat | Hands-together uses wrist distance (tolerant 0.35 torso). |
| 23 | **Dabba Lifter** (both arms bent "carrying a tiffin" at chest + half squat) | elbowFlex 70° both, zone.wrist chest, kneeFlex 140° | kneeFlex | 1500/2500 | No squat | |
| 24 | **Pataka!** (finisher: one arm up straight, other T, one knee lifted) | shoulderAbd L 170°, R 90°, footLift R | footLift | 1500/2500 | Toe tap instead of lift | Signature round-ender. |
| 25 | **Chill Frame** (stand tall, arms relaxed) | shoulderAbd < 25° both, stance normal | none | 1000 | Seated | Recovery; always passes if visible. |

**Excluded on purpose:** forward reach, forward bends to the floor, back bends, inversions, deep squats beyond 100°
knee, kneeling or floor poses (the camera loses the hips and the floor is often unsafe or dirty in shared rooms),
fast spins, jumps (opt-in only), and anything with neck flexion targets. Hand or finger shapes are never judged
because Pose does not track hands.

**Body-diverse tolerance:** the matcher never needs a deeper range than the beginner target. Adaptive tolerance: if
a player fails the same feature 3 times, that feature's `tol` widens by 5° for that player and session. This is shown
as "Kavi adjusted this shape for you", never as a failure message.

---

### 5. Difficulty and age bands (adults 18+ only)

The audience is always 18+ (product rule). The bands are **comfort/energy bands**, not ages. The player chooses one,
and Kavi suggests a change after a round:

| Band | Lead time | Lock % | Hold scale | Poses allowed | Balance | Notes |
|---|---|---|---|---|---|---|
| **Easy / "Chai Break"** (new, older adults, office wear) | 3.5 s | 75 | 0.8× | upper-body + Chill + LI variants, seated-friendly | wall/chair cue always | Whole round playable seated. |
| **Normal / "Mela"** | 2.8 s | 80 | 1.0× | full library, LI on request | toe-tap OK | Default. |
| **Spicy / "Mirchi"** | 2.0 s | 85 | 1.3× | adds Sequence Chain and Blink | full lift | Tighter tol (−5°). |
| **Pataka Pro** | 1.6 s | 88 | 1.5× | 3-pose chains, mirror tricks | full | Leaderboards (opt-in). |

A family gathering may include under-18s. The app does not target them, and the party flow makes no child-specific
claims. Onboarding confirms 18+ for the account holder. Guests in party mode are "players" with only a nickname and
no account (see Risks).

---

### 6. Round and session structure

- **Round:** 12–16 frames, about 2.5–3 min. Shape: warm (3 easy) → build (6–8 mixed) → 1 Statue Bazaar → peak (2–3,
  including a chain) → finisher Pataka! → Chill. The deterministic director, driven by config, builds rounds from JSON
  playlists or a seeded generator (rule 8). It caps "demanding" poses (squat/lunge/balance) at 2 in a row and inserts
  a Chill after every 4–6 frames.
- **Session:** 1 round = "quick pataka" (keeps the streak). 3–4 rounds = 10–12 min "Mela night". The player can stop
  after any round.
- **Calibration (once, 20 s):** "Stand in the glowing outline" (framing), then "arms out like an aeroplane" (arm
  length, shoulder width), "stand still 2 s" (standing ankle y, torso length). This reuses the existing calibration
  profile fields.
- **Framing:** full body needed for leg poses. If knees are out of frame, the director swaps in upper-body poses and
  says so ("Phone a bit further? Till then, upper-body poses!"). This is rule 5 behaviour.

#### 6.1 Party modes
| Mode | Players | Tracking | Flow |
|---|---|---|---|
| **Pass-the-Pataka** (turn-taking) | 2–8 on one phone | 1 body | Each player gets 4 frames, then "Pass!" screen with a 5 s step-in countdown + quick re-frame check (no recalibration; per-player tol defaults). Shared scoreboard. |
| **Team Toli** | 2 teams of 1–4 | 1 body | Alternating players per team; team score = sum of bests; "Captain's Pick": the leading team picks the next pose for the other. |
| **Statue Showdown** | 2–8 | 1 body | Elimination-free: each player does a 5-frame Statue Bazaar; the room votes funniest freeze clip (tap). Score + votes. |
| **Copy-Cat Chain** | 2–6 | 1 body | Player A *invents* a pose (held 2 s, captured as feature vector); B must match it; then B adds one. Memory chain. Invented poses are validated against the safety envelope (angles within library ranges; no floor/back-bend features) or Kavi rejects with a joke. |
| **Duo Frame** (experimental) | 2 in frame | `numPoses=2` | Only on devices that hold ≥ 24 fps in a pre-check. Each frame has two silhouettes (left/right). Falls back to Pass-the-Pataka otherwise. |

**Duo Frame tech gate:** MediaPipe Pose Landmarker supports `numPoses > 1`, but cost rises with each person and
identity can swap when people cross. Mitigations: assign players by screen half (sort by hip-mid x each frame); never
let players swap sides in a pose; forbid crossing. The device pre-check measures 10 s at `numPoses=2`, and the mode is
disabled below 24 fps. The bridge still sends only landmarks (rule 4), as a list of up to 2 × 33 points. This needs
a native_bridge change and is **post-MVP**.

---

### 7. Humour and personality: Coach Kavi

Kavi is an original character: a cheerful, slightly dramatic paper-lantern puppet with a moustache that changes per
festival, a "mela announcer" voice, and Hinglish by default (English and Hindi packs, more languages later). Kavi
never body-shames, never mentions weight, and never gives medical advice. Kavi teases *the frame*, *the game* or
*Kavi itself*, never the player's body.

Sample lines (all text in JSON localisation files):
- Pose call: "Next up: Cutting Chai! Extra adrak, extra attitude."
- Lock: "Locked! Statue-level confidence."
- Perfect: "PATAKA! The whole mohalla heard that one."
- Near miss: "So close! The frame and you were *almost* in a relationship."
- Statue Bazaar tease (while the player must stay still): "Don't laugh… don't laugh… a pigeon is looking at you…",
  "Kavi is legally not allowed to tickle you. Yet."
- Tracking hover (rule 5): "I've lost your knees, they've gone to Goa without you. Step back a little?",
  "Too dark, yaar. A bit more light and we're back."
- Balance support: "Holding the wall is pro strategy, not cheating."
- Pass-the-phone: "Phone handover! Wipe the sweat, not the screen… actually, wipe the screen also."
- Team taunt: "Team Samosa leads! Team Jalebi, untangle yourselves."
- Rest: "Chill frame. Breathe like you just found parking in Bandra."

Funny moments: auto-captured **"Freeze Fails"**, the 1.5 s of landmarks around the lowest-similarity moment during a
Statue Bazaar wobble, replayed with a "wobble cam" effect; Kavi trying to copy you and failing comically; and frames
in the shape of a jalebi or a questionably drawn auto-rickshaw.

---

### 8. Shareable clips (landmarks only, never camera video)

- During a round, a ring buffer keeps the last ~6 s of **filtered landmarks** (33 × (x, y, vis) at ≤ 30 Hz ≈ 25 KB) in
  memory only. Camera frames are never retained (rules 2 and 4). The buffer holds landmark data, not frames, so it is
  not a frame queue (rule 3).
- At round end, the "Pataka Reel" shows 3 auto-picked moments: best perfect, funniest freeze fail, final pose.
- The share renderer draws the **costume avatar** (stick-glow, kurta-bot, lantern-person, etc.), the frame, confetti
  and the score, and encodes a 5–8 s 9:16 MP4/GIF on-device. The clip contains **no camera pixels and no face**. It
  carries a watermark "Made with landmarks only — no camera video".
- Sharing goes through the Android share sheet only. Nothing uploads unless the user shares. Clips are not kept after
  the session unless the user taps Save (to app storage) or shares. Rendered clips are kept under the user's
  control and noted in `docs/security.md`.
- Party mode: the guest nickname appears in the clip only if they tick "show my name".

---

### 9. Progression and cosmetics

- **Pose Album:** each of the 24 poses has bronze/silver/gold (★ thresholds) and a personal-best %. The album is the
  long-term goal ("Gotta strike 'em all").
- **Mela Map:** 6 stalls (Chai Stall, Kite Market, Lantern Lane, Rangoli Gali, Dhol Corner, Rooftop Finale), 5 rounds
  each with 3 stars. Stars unlock the next stall. Unlocks come from playing, never from daily chores.
- **Cosmetics (cosmetic only, never stat-affecting):** avatar skins (Kurta-Bot, Neon Stick, Paper Lantern, Cricket
  Kit, Auto Driver), confetti types (marigold, rangoli dust, kite strings), frame skins, Kavi moustache styles,
  victory stingers.
- **Weekly "Pose of the Week":** a curated pose with a global (opt-in) leaderboard of best similarity %. Only
  aggregate scores go to the server, never landmarks by default.
- **Streak:** a 1-round mini session counts. Streak Freeze is earned by play, not bought. No guilt notifications:
  at most 1 gentle reminder a day, and it can be switched off.

---

### 10. Festival variants (content drops, JSON only)

No deity imagery and no religious ritual gestures as poses (for example, no namaskar as a scored pose to "win").
The themes are cultural and celebratory.

| Festival | Theme twist | New poses / frames |
|---|---|---|
| **Diwali** | Frames are diyas and rangoli-light. Burst = sparkle (no loud cracker SFX by default; "eco-pataka"). | Lantern Hold (Balance Lantern skin), Sparkler Swirl (freeze at end-state) |
| **Holi** | Colour-burst frames; avatar gets splashed by the colour of your best pose. | Pichkari Aim (Archer variant), Colour Cloud Star |
| **Makar Sankranti / Uttarayan** | Kite-cut frames; "Patang Duel" in team mode. | Kite Flyer, Manja Pull (Archer + lean) |
| **Navratri-style dance nights** | Freeze-on-the-drum-hit Mirror Kavi rounds (music with wide windows, no beat precision needed: the freeze is judged *after* the hit). | Dandiya Freeze (both arms up-diagonal; no sticks needed) |
| **Onam / Pongal** | Harvest frames, boat-race team mode (team sync on the same pose, turn-based). | Oar Pull (Archer variant) |
| **Cricket season (IPL-time)** | Stadium frames; "Commentator Kavi". | Six! (Lamp Post), Wicket Keeper (chair pose), Appeal (one arm up) |
| **New Year / Wedding season (Sangeet)** | "Sangeet Showdown" party playlist. | Baraat Shoulders (Bhangra), Selfie Stick |

Each variant is `content/party/festivals/<id>.json`: a playlist, a skin id and localisation keys. It is validated by
the schema, so shipping one is content work.

---

### 11. Free / Premium (Google Play Billing only; rule 11)

| Free | Premium ("Mela Pass", Play subscription; also lifetime IAP) |
|---|---|
| 12 core poses, 2 Mela Map stalls, Pass-the-Pataka up to 4 players, Pose of the Week, landmark clips with watermark | All 24+ poses + every festival drop, full Mela Map, 8-player party + Team Toli + Copy-Cat Chain, all avatar skins, clip without the extra end-card, Duo Frame (where supported) |
| No ads during play (a camera game must not interrupt someone mid-pose); optional rewarded "extra cosmetic roll" only post-round | Festival packs also sold individually as small IAP (₹19–49 range per 1-market ARPU data) |

India pricing guidance: monthly ₹79–99, yearly ₹499–599, festival pack ₹29. These figures are hypotheses for A/B
testing. There are no links or nudges to pay outside Play (rule 11). Safety features (LI variants, support cues) and
accessibility are **never** paywalled.

---

### 12. Metrics

| Metric | Target (hypothesis) | Why |
|---|---|---|
| First-round completion (install → finished round 1) | ≥ 70 % | readability |
| Pose lock rate per frame (beginner) | 80–90 % (too high = boring, too low = frustrating) | difficulty tuning |
| Tracking-hover rate | < 5 % of frame time; per-pose breakdown | detection quality, framing UX |
| "Felt unfair" post-round thumbs-down | < 10 % | matcher tolerance |
| Party sessions (≥ 2 players) share of sessions | ≥ 25 % | core thesis |
| Players per party session | ≥ 3 median | |
| Clip share rate | ≥ 8 % of party sessions | virality |
| D1 / D7 / D30 retention | 40 / 18 / 8 % | |
| Rounds per session | ≥ 2.2 | |
| Free → Premium | 2–4 % of MAU (India) | |
| Tracking accuracy gate (offline replay) | per-pose lock recall ≥ 0.9 on recorded clips; false lock on decoy poses ≤ 5 % | rule 1 |
| Perf | ≥ 15 fps budget (hard), ≥ 24 fps for Duo Frame | 3-tech |

Telemetry is privacy-first: only aggregates and per-pose similarity distributions are sent, opt-in. No landmarks are
sent by default. Research recordings need explicit separate consent.

---

### 13. Implementation notes (for later tasks; no repo changes now)

- `packages/motion_core`: add `PoseFeatures` (angles, zones, stance from landmarks + calibration) and `PoseMatcher`
  (similarity, must-caps, mirrorOk, unseen gating, lock/hold hysteresis), **tests first** with `SyntheticBody`
  poses at 10/15/30 fps, noise, occlusion, mirrored input and decoys (Goalpost ≠ Robot, Tree ≠ Knee Hug).
- `packages/game_director`: `PartyDirector.plan(playlist, settings, seed)`, deterministic; simulator bots (`slow`,
  `wobbly`, `dropout`) prove every round is completable at beginner with LI variants, and that dropout never loses
  progress (rule 5).
- `content/schema/pose.schema.json` + `content/party/poses/*.json`, `rounds/*.json`, `festivals/*.json`;
  `npm run content:validate` covers them.
- `app/`: a Flame `PartyGame` with an approaching-frame component and a landmark avatar renderer (shared with the clip
  encoder). The clip encoder renders avatar frames only.
- `native/pose_bridge`: unchanged for MVP. Duo Frame needs `numPoses` and a multi-pose payload (post-MVP).

---

### 14. Risks and mitigations

| Risk | Severity | Mitigation |
|---|---|---|
| Matcher feels unfair (2-D ambiguity, clothing like sarees or dupattas hiding knees) | High | Angle-based, generous tolerances; unseen → hover, not fail; upper-body fallback; adaptive tol; replay gate before tuning; recorded clips from diverse bodies and clothing. |
| Mirror/left-right confusion | Med | Mirror display; `mirrorOk` on beginner; Kavi says "screen-side" not "left"; explicit tests. |
| Balance poses cause falls | High | Balance poses opt-in for lantern mode; toe-tap default on Easy; constant wall/chair cue; no floor/jump poses; one-tap "I need a break" pause; safety screen ("clear space, non-slip floor"). |
| Party chaos: people walking behind the player cause tracking swaps | Med | Single-pose mode tracks the largest/most central body; "One player in the glow zone" framing; hover when the person changes mid-frame (torso length jump > 25 %). |
| Duo Frame fps on budget phones | Med | Gated by device pre-check; post-MVP; Pass-the-Pataka is the real party mode. |
| Privacy perception ("it's filming my living room") | High | Avatar-only default view; landmark-only clips with watermark; no frame storage; clear onboarding copy; rule 2. |
| Guests/minors at family parties | Med | Account holder 18+; guests use nickname only, no data stored beyond session scores; no targeting of children; no child-specific marketing. |
| Cultural missteps in festival content | Med | No deity imagery or ritual gestures as scored poses; local review panel per festival; avoid regional stereotypes in Kavi lines. |
| Format similarity to TV "hole in the wall" shows / other mirror games | Med | Own setting (mela), frame art, character and sound; no copied wall look, catchphrases or audio; legal review of name and art (rule 10). |
| Medical framing creep ("yoga for back pain") | High | Copy review: "shapes", "play", "stretch-style poses"; no therapy, weight-loss or health claims; yoga-inspired names are playful (Coconut Tree), not clinical. |
| Novelty drop (1-market: Nex/Active Arcade) | High | Pose Album + Mela Map + weekly pose + festival drops as JSON; party modes create social reasons to return. |
| Laughing breaks statue → frustration | Low | That is the joke: Freeze Fail becomes a clip, partial credit is given, and the combo is not broken in party mode. |

---

### 15. MVP cut (suggested)
1. Solo Cut-out Frame + Chill + Statue Bazaar; 12 poses (#1–5, 7, 8 LI, 11, 13, 14, 18, 25); Easy and Normal bands.
2. Pass-the-Pataka (2–4 players) with a shared scoreboard.
3. Landmark avatar clip share (stick-glow skin only).
4. Diwali skin as the first JSON festival drop, to prove that content is data.
Next: Mirror Kavi, Sequence Chain, Team Toli, Copy-Cat Chain, Pose Album. Later: Duo Frame (fps-gated).
