# New games plan 2 — three self-view games (Mirror Mela, Tapeball Tamasha, Pataka Pose)

> **Implementation note (2026-11-09):** a first playable version of the games in this document now ships in the app (v2). See [progress.md](progress.md) for what was built, what deliberately differs, and what is still open; rules live in [game-design.md](game-design.md#arcade-games-v2-2026-11-09).

Status: **plan / proposal, 2026-11-05.** Nothing here is implemented. Owner decisions are collected in §10.
Inputs: `AGENTS.md`, `docs/architecture.md`, `docs/game-design.md`, `docs/stages-roadmap.md`, research notes
`research2/1-selfview-tech.md`, `2-modern-ui.md`, `3-characters.md`, `4-game-c.md`, `5-game-d.md`, `6-game-e.md`
and `research/3-tech.md` (camera limits). Source links from those notes are kept inline and in §11.

Relation to `docs/new-games-plan.md` (Games A and B): that file is **not in the repo yet**. This plan reuses — and must
not duplicate — the pieces it introduces, as specified in `research/3-tech.md` §4: the `BeatEngine`
(`packages/game_director/lib/src/beat_engine.dart`, RunEngine contract, latency-compensated judging), level
**schema v2** (`schemaVersion` 1|2, `mode`, `moves`, `music`, `atBeat`), `BotProfile` latency/jitter/fps bots, the
`MotionGame` painter switch, and the motion_core `BodyFeatures`/calibration helpers. Where this plan adds anything, it
is written as an **extension** of those (new `mode` values, new encounter types, new recognisers). If plan 1 lands
with different names, rename here; do not fork.

Numbers marked *est.* are first-principles estimates and must be confirmed on the budget reference phone and by the
recorded-data replay gate before they go into `docs/game-design.md`.

---

## 1. Executive summary — what makes each game awesome

1. **You are the controller *and* the star.** All three games put the player's own moving body on screen — as a
   stylised **Avatar** (default, works on every phone), a flat **Silhouette**, or an opt-in **Mirror** of the real
   camera — with game objects anchored to their real shoulders, hands and head.
2. **Privacy is architectural, not a promise.** The camera image is a native GPU texture; Dart only ever holds an
   integer texture id plus landmarks. Avatar mode never even binds the camera Preview. `FLAG_SECURE` is on while
   Mirror is visible, and share clips are re-rendered from landmarks — a clip *cannot* contain a camera pixel.
3. **Mirror Mela (Game C)** — "The fair comes to you." Bubbles, lanterns and marigolds drift to points around your
   body; reach, hold and dodge to pop them. Every zone plays a pentatonic note, so a good combo *plays a melody*.
   75-second arcade rounds, instant restart, Daily Remix.
4. **Tapeball Tamasha (Game D)** — the gully-cricket evening every Indian adult remembers, in your living room: bat,
   bowl, catch and run-between-wickets (march in place), plus **Raid Rush** (kabaddi-style side-step raids) and
   **Shuttle Rally** (badminton overhead reaches). Seeded deliveries make **gym Crew Cup** tournaments fair.
5. **Pataka Pose (Game E)** — "Freeze in the shape before it reaches you." A glowing firecracker cut-out flies in;
   strike and hold the shape and it bursts into confetti. **Coach Kavi hosts**, teasing the *frame*, never you.
   Pass-the-Pataka makes it the 18+ flatmates / friends / office game-night pick.
6. **Built for what one front camera can really see.** Every judgement is an **end state held ≥ 2 frames**, every
   target sits in the image plane (sides / overhead), nothing moves toward the camera, nothing needs fast combos.
   Windows are ±250–550 ms on capture timestamps with latency compensation (`research/3-tech.md` §3).
7. **Never punishing.** Tracking loss = forgiven target / dead ball / hovering frame, the world slows, Jugnu the
   firefly lights where the camera lost you, and Kavi blames the camera ("I lost you — step back a bit").
8. **One modern visual language — Lantern Pulse** — shared by all three: tinted plates (no blur), 40–104 dp HUD type
   readable at 2 m, spring motion, colour never the only cue, per-game accent pairs on the Forest Lantern base.
9. **One cast across the app**: Kavi (Bengal fox, teal vest) coaches everywhere; Mithu the parakeet MCs Mirror Mela
   and commentates cricket; Golu the rhino bowls; Chikki the squirrel is the cheeky rival; Neela the otter runs
   cool-downs and balance; Baadal the cloud is the prankster boss; Jugnu is tracking help.
10. **Content is data, the director is deterministic.** Levels, deliveries, pose libraries, festivals and cosmetics are
    JSON validated by schema; same seed → same round for everyone (Daily Remix, Crew Cup, Pose of the Week). General
    fitness wording only — "great moves", "active minutes" — never calories, weight or therapy.

---

## 2. Self-view technology & privacy architecture

### 2.1 Today vs. target
| | Today (`native/pose_bridge/.../PosePipeline.kt`) | Target |
|---|---|---|
| Use cases bound | `ImageAnalysis` only (RGBA_8888, `STRATEGY_KEEP_ONLY_LATEST`, `busy` drop flag), front camera | `ImageAnalysis` + optional `Preview` in one `UseCaseGroup` with a shared `ViewPort` (9:16, `ROTATION_0`) |
| Landmark space | rotated + mirrored (`postScale(-1,1)`) full analysis frame | same, but **cropped to `ImageProxy.cropRect` first** → landmarks are normalised to the on-screen viewport |
| Into Dart | landmarks (33 × x,y,z,vis) + timestamp + frame size | unchanged **+ one opaque texture id** and 5 ints/bools (`textureId,width,height,rotation,handlesCropAndRotation`) |
| `docs/architecture.md:34` wording | "Only landmarks cross into Dart" | "Only landmarks (and an opaque texture id) cross into Dart" |

### 2.2 Data-flow diagram
```
                         NATIVE (Kotlin, pose_bridge)                           |  DART (app / Flame)
                                                                                |
 Front camera ──► CameraX ──┬─► ImageAnalysis (KEEP_ONLY_LATEST, busy-drop)     |
                            │      crop(cropRect) → rotate → mirror             |
                            │      → PoseLandmarker (Lite, LIVE_STREAM)         |
                            │      → 33 landmarks + ts ──────── EventChannel ───┼─► MotionEngine (QualityGate,
                            │                                                   |    One Euro, recognisers,
                            │      [tier-gated] SelfieSegmenter 144×256         |    ViewportMapper, PoseMatcher)
                            │        ≤15 Hz own executor, drop-latest           |          │
                            │        → mask (GL texture, never leaves native)   |          ▼
                            │                │                                  |    Engine (BeatEngine + rule pack)
                            └─► Preview ─────┼─► [CameraEffect GL SurfaceProc.] |          │
                              (≤720p, only   │     blur / backdrop / silhouette |          ▼
                               in Mirror or  ▼                                  |    Flame GameWidget (transparent)
                               Silhouette)  SurfaceProducer surface ─ textureId ┼─► Texture(id) ◄ Transform(-1,1) mirror
                                            (GPU buffer, engine composites)     |    Stack: [SelfViewLayer, Game, HUD]
                                                                                |
  NEVER BOUND: ImageCapture, VideoCapture, MediaRecorder, MediaCodec (CI-enforced) | NEVER: frame bytes, mask bytes,
  NEVER: frames to disk, crash logs, analytics                                     | toImage() on any camera subtree
```

### 2.3 Self-view modes (one setting, chosen at onboarding, switchable from pause; persisted in shared prefs)
| Mode | Preview bound? | What the player sees | Tier | FLAG_SECURE | Screenshots of app |
|---|---|---|---|---|---|
| **Avatar** (default) | **No** — camera image is never rendered | Original landmark-driven avatar (§4.3) on the game scene | All | Off | Allowed |
| **Silhouette** | Yes, through segmentation shader that outputs **mask × flat colour/gradient only** (no camera colour reaches the texture). Fallback on non-segmentation tiers: landmark-capsule silhouette drawn in Flame, Preview unbound | Flat glowing body shape in the game accent | Seg tier (bench median < 25 ms over 30 frames) or capsule fallback | Off (no camera colour pixels) | Allowed |
| **Mirror** (opt-in) | Yes | Real camera, dimmed to 75–85 % brightness + vignette; optional "studio backdrop" (background replaced by the stall scenery, seg tier) or blur | All for plain mirror; seg tier for backdrop/blur | **On** while visible | Blocked (system) — use in-app share card |

- Switching mode rebinds natively (`unbind(preview)` / `bind`); landmarks keep flowing, gameplay does not pause.
- First run suggests Avatar explicitly: "Prefer not to see yourself? Avatar is on." (shared-home privacy, self-consciousness).
- `Activity.setRecentsScreenshotEnabled(false)` (API 33+) **always** during a session; HUD shows a "camera on" pip
  whenever any use case is bound (Android 12+ also shows the system privacy dot).
- PlatformView + `SurfaceView.setSecure(true)` is the fallback only if per-layer secure becomes a hard requirement
  (hybrid composition cost on budget phones; [MS docs](https://learn.microsoft.com/de-de/dotnet/api/android.views.surfaceview.setsecure?view=net-android-37.0)).

### 2.4 Mirroring and alignment
- `Preview.setMirrorMode` is a no-op on API ≤ 32 ([CameraX Preview](https://developer.android.com/reference/androidx/camera/core/Preview.html)), and the
  India budget fleet is heavy on API 29–32. So: buffer un-mirrored (`MIRROR_MODE_OFF` where available), mirror in Dart
  with `Matrix4.diagonal3Values(-1,1,1)` (compositor transform, no pixels). Landmarks are mirrored **once**, natively.
- If `SurfaceProducer.handlesCropAndRotation()` is false, native returns `rotation` once and Dart wraps the texture in
  `RotatedBox` ([Flutter surface plugins](https://docs.flutter.dev/release/breaking-changes/android-surface-plugins)).
- Game is **portrait-locked** for v1 (removes display-rotation from the matrix).
- `ViewportMapper` (pure Dart, `packages/motion_core/lib/src/viewport_mapper.dart`, own `Point2` type, no Flutter
  import) maps viewport-normalised landmarks to widget coords for `BoxFit.cover`:
  `s = max(dstW/srcW, dstH/srcH); X = (dstW − srcW·s)/2 + x·srcW·s; Y = (dstH − srcH·s)/2 + y·srcH·s`.
- **Latency honesty:** preview is ~1 frame behind sensor; landmarks arrive 110–180 ms later (`3-tech` §1). Hits are
  judged **and drawn** at landmark positions, with a hand halo showing "what the game sees". Anchored cosmetics use
  One Euro + linear prediction of `inferenceMs` (display only, never recogniser input). If lag is visible on the
  budget phone, native may delay preview presentation by the median pipeline latency (frame skip, ≤ 1 frame buffered,
  never a queue — rule 3).

### 2.5 API sketch
Kotlin (`native/pose_bridge/android/.../SelfView.kt`, new; `PoseBridgePlugin.kt` gains 3 methods on `motionquest/pose_bridge`):
```kotlin
// "startSelfView" {mode:"mirror"|"silhouette", backdrop:"none"|"blur"|"stall"} ->
//     {textureId:Long, width:Int, height:Int, rotation:Int, handlesCropAndRotation:Boolean}
// "stopSelfView" -> null            // unbinds Preview; landmarks keep flowing
// "setSecure" {on:Boolean} -> null  // window FLAG_SECURE (main thread)
class SelfView(private val textures: TextureRegistry, private val activity: Activity) {
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
        preview.setSurfaceProvider(exec, provider); return p.id()
    }
    private val provider = Preview.SurfaceProvider { req ->
        val p = producer ?: return@SurfaceProvider req.willNotProvideSurface()
        p.setSize(req.resolution.width, req.resolution.height)
        req.provideSurface(p.surface, exec) { }
    }
    fun release() { preview.setSurfaceProvider(null); producer?.release(); producer = null }
}
val group = UseCaseGroup.Builder()
    .setViewPort(ViewPort.Builder(Rational(9, 16), Surface.ROTATION_0).build())
    .addUseCase(analysis)
    .apply { selfView?.let { addUseCase(it.preview) } }
    // .addEffect(segEffect)   // CameraEffect(PREVIEW) + GL SurfaceProcessor, tier-gated (verify on pinned CameraX)
    .build()
provider.bindToLifecycle(owner, CameraSelector.DEFAULT_FRONT_CAMERA, group)
fun setSecure(on: Boolean) = with(activity.window) {
    if (on) addFlags(WindowManager.LayoutParams.FLAG_SECURE) else clearFlags(WindowManager.LayoutParams.FLAG_SECURE) }
```
Dart (`native/pose_bridge/lib/pose_bridge.dart`, `app/lib/game/self_view_layer.dart`):
```dart
enum SelfViewMode { avatar, silhouette, mirror }
class SelfViewHandle { final int textureId, width, height, rotation; final bool handlesCropAndRotation; ... }
abstract class PoseBridge {
  Future<SelfViewHandle?> startSelfView(SelfViewMode mode, {Backdrop backdrop = Backdrop.none}); // null for avatar
  Future<void> stopSelfView();
  Future<void> setSecureWindow(bool on);
}
class SelfViewLayer extends StatelessWidget {          // never inside a capture RepaintBoundary
  const SelfViewLayer(this.h, {super.key, this.dim = 0.8});
  final SelfViewHandle h; final double dim;
  @override
  Widget build(BuildContext c) => ClipRect(child: FittedBox(fit: BoxFit.cover, child: SizedBox(
      width: h.width.toDouble(), height: h.height.toDouble(),
      child: ColorFiltered(colorFilter: ColorFilter.matrix(_dimMatrix(dim)),
        child: Transform(alignment: Alignment.center, transform: Matrix4.diagonal3Values(-1, 1, 1),
          child: RotatedBox(quarterTurns: h.handlesCropAndRotation ? 0 : h.rotation ~/ 90,
            child: Texture(textureId: h.textureId)))))));
}
// SelfViewController (Riverpod): owns mode, calls setSecureWindow(mode == mirror && visible), handles
// AppLifecycleState.paused -> stopSelfView, thermal ladder step 5 -> avatar.
```

### 2.6 Performance & thermal budget (budget phone: 3–4 GB RAM, Helio G85 / SD 680 class)
| Stage | Budget | Notes |
|---|---|---|
| Preview | 30 fps, ≤ 720p | zero-copy GPU path; never request 1080p |
| Pose (ImageAnalysis) | 15–30 Hz, existing analysis res | optional saving: pass rotation via `ImageProcessingOptions` and mirror numerically → drop one full-frame bitmap copy |
| Capture → judged event | < 200 ms budget, < 150 ms upper-mid | compensated by `latencyOffsetMs` (`3-tech` §4.2) |
| Segmentation | 0 Hz default; 10–15 Hz on seg tier | Pixel 6 ≈ 33–35 ms CPU, GPU no faster ([MediaPipe segmenter](https://ai.google.dev/mediapipe/solutions/vision/image_segmenter)); budget 60–100 ms *est.* → cannot run every frame |
| Composite shader | ≤ 3 ms GPU | only with blur/backdrop/silhouette |
| Flame painter | ≤ 6 ms/frame; 30 fps locked budget, 60 high tier | cached Paints, zero per-frame allocs (as `ForestPainter`) |
| Avatar + costume layer | ≤ 2 ms/frame, ≤ 12 MB texture RAM | 1024² atlas ≈ 4 MB decoded |
| Recognisers + PoseMatcher | ≤ 0.3 ms/frame total | `perf_benchmark_test.dart` |
| Particles / objects | ≤ 150 particles, ≤ 24 visible objects | |
| Memory | ≤ 1 analysis bitmap in flight, 1 mask texture, CameraX-owned preview buffers | no extra frame copies |

Thermal ([ADPF](https://developer.android.com/games/optimize/adpf/thermal)): `addThermalStatusListener`; `getThermalHeadroom(10)` polled ≤ once / 10 s;
headroom > ~1.0 → step down. Below API 30: sustained inference ms > 1.3 × session baseline. **Degrade ladder** (each
step logged + calm toast, never costs lives/progress): ① segmentation 5 Hz → off ② preview 720p → 480p ③ particles
halved ④ pose 30 → 15 Hz (director switches to half-time density, windows widen) ⑤ self-view → Avatar.

### 2.7 Enforceable privacy controls (add to `docs/security.md` as §8.1–8.8)
| # | Control | Enforcement |
|---|---|---|
| 8.1 | Only `Preview` + `ImageAnalysis` may be bound | unit test on the use-case set; CI grep fails on `ImageCapture`, `VideoCapture`, `MediaRecorder`, `MediaCodec` under `native/pose_bridge/` |
| 8.2 | No camera/mask pixels into Dart | channel codec allow-list (numbers/bools/landmark lists only); Dart lint bans `toImage`/`toImageSync` in files importing `self_view_layer.dart` |
| 8.3 | Share clips/cards rendered from game state + landmarks only | clip renderer takes `LandmarkClip` + `RunSummary`, never a widget tree; golden test asserts no `Texture` in the clip scene |
| 8.4 | `FLAG_SECURE` while Mirror visible | widget test on `SelfViewController`; manual screenshot check in QA script |
| 8.5 | Recents screenshot disabled during sessions (API 33+) | instrumentation test |
| 8.6 | No frames to disk / crash reports / analytics; debug dumps `BuildConfig.DEBUG` only | release lint check |
| 8.7 | Camera unbinds on pause/background/lock; `unbindAll` on `onSurfaceCleanup` | lifecycle test |
| 8.8 | Landmark clip ring buffer is RAM-only, dropped at session end; landmarks never uploaded by default | code review + `session_queue.dart` payload test |

**Clip encoder placement:** the MP4 encoder (MediaCodec) lives in a **separate** plugin `native/clip_encoder/` whose
only input is an RGBA stream of the **offscreen avatar scene** rendered by Flame (720×1280, 30 fps, 5–15 s). It has
no camera dependency (CI check: no `androidx.camera` import), so 8.1 stays true for `pose_bridge`.

---

## 3. Visual language & HUD system — "Lantern Pulse"

Principle: keep **Forest Lantern** (`app/lib/app/theme.dart`) for the shell; add an additive **overlay palette** that
always sits on a **plate** or carries a dark **stroke**, because the background (camera or avatar scene) can be anything.
Evidence: billboards/outlines are the most robust AR text style ([Gabbard 2007](https://ed-swan.github.io/publications/papers/2007_Gabbard-etal_Text-Drawing-Styles_IEEE-VR.pdf),
[PubMed 32425139](https://pubmed.ncbi.nlm.nih.gov/32425139/)); size by visual angle ([Fire TV](https://developer.amazon.com/docs/fire-tv/design-and-user-experience-guidelines.html),
[10ft UI](https://pascalpotvin.medium.com/designing-a-10ft-ui-ae2ca0da08b7)); accessibility per [Xbox XAG](https://learn.microsoft.com/en-us/gaming/accessibility/guidelines). Trend
sources (pixune, appfollow, line25, M3 Expressive, Asian Paints ColourNext 2025) are directional only.

### 3.1 Colour tokens
Kept (`Lantern.*`, unchanged): night `#0B1611`, canopy `#13241C`, moss `#1C3328`, ridge `#2A4A3A`, glow `#FF9A3C`,
ember `#E0701F`, scarf `#3FD0C0`, parchment `#F6EEDC`, fog `#B9C9BF`, warning `#FFC857`, danger `#FF6B5A`, onGlow `#231203`.

New `abstract final class LanternPulse` (`app/lib/app/lantern_pulse.dart`):
| Token | Hex | Use | Contrast on night *(approx., verify)* |
|---|---|---|---|
| `plate` | `#C70B1611` (night @ 78 %; 88 % in bright rooms) | backing for every HUD element | parchment ≥ 10:1 |
| `plateSolid` | `#0B1611` | high-contrast mode | parchment ≈ 16:1 |
| `stroke` | `#050B08` | 3–4 dp outline for text/icons off-plate | — |
| `marigold` | `#FFB627` | combo, streak, good accents | ≈ 11:1 |
| `kumkum` | `#FF4D6D` | hot accent, boss, timer critical (always + icon) | ≈ 5.6:1 |
| `peacock` | `#00C2B8` | P2 / target zone | ≈ 8.6:1 |
| `indigoDusk` | `#2B2F77` | celebration gradient stop | parchment only |
| `mehendi` | `#9BCB3C` | perfect / correct tick | ≈ 9.5:1 |
| `lilac` | `#B98CFF` | Game E accent | verify |
| `chalk` | `#FFFFFF` | numerals on plates | — |
| `trackingAmber` | `= warning #FFC857` | "can't see you" (always with person-outline icon) | — |

Per-game accent pairs (`HudTheme` `ThemeExtension`, not `ColorScheme` swaps; `glow` stays the brand constant):
| Game | Accent A | Accent B | Title/celebration gradient (never behind live text without plate) |
|---|---|---|---|
| C Mirror Mela (warm, combo/music) | marigold `#FFB627` | kumkum `#FF4D6D` | `#FF9A3C → #FF4D6D` |
| D Tapeball Tamasha (cool, precision/zones, maidan) | peacock `#00C2B8` | scarf `#3FD0C0` | `#0F3E39 → #00C2B8` |
| E Pataka Pose (night, firecracker) | lilac `#B98CFF` | mehendi `#9BCB3C` | `#2B2F77 → #B98CFF` |

Colour-blind rule: good = tick + upward motion; miss = soft grey ring + sideways nudge; never kumkum/mehendi as the only pair.

### 3.2 Type scale (2 m reading distance; `fontSize_dp ≈ capHeight_mm / 0.72 / 0.159`)
| Role | Cap height | dp | Weight | Use |
|---|---|---|---|---|
| `hudHero` | 12 mm | **104** | w900, tabular figures, tracking −2 | 3-2-1, "GO", big counts |
| `hudPrimary` | 9 mm | **80** | w900 | score, combo multiplier, runs/target |
| `hudLabel` | 6 mm | **52** | w800, +0.5 tracking, ALL CAPS ≤ 2 words | "COMBO", pose name, "RUN!" |
| `hudFloor` | 4.5 mm | **40** | w800 | smallest text allowed during play |
| shell `displaySmall` | ≈ 5 mm | 44 | w900 | unchanged |
| shell body | ≈ 2 mm | 17–19 | w400 | hand-held screens only |
Rules: ≤ 3 words and one primary message at a time; never < w600 in-game; system fonts only (offline); HUD clamps
text scale, offers "Large HUD" +20 %; Devanagari/Gujarati 1.25× line height, test 52 dp labels fit.

### 3.3 HUD layout and components
```
┌──────────────────────────┐
│ [◖◖◗ shield]   [⏱ 0:42] │  top band: 2 compact plates (40–52 dp)        ← edge scrim night 0→65 %, 18 % height
│        ( 3 )             │  centre: ONE transient hero message (104 dp)
│     ┌─────────────┐      │
│ ◀zone│ self-view /│zone▶ │  torso area kept free of HUD; target zones are outlined rings, filled only on hit
│     │ avatar     │      │
│     └─────────────┘      │
│ ┌──────────────────────┐ │
│ │ MOVE  ▮▮▮▮▯  x4      │ │  bottom plate: move/pose name + progress + combo
│ └──────────────────────┘ │  ← bottom scrim; "camera on" pip bottom-left when any use case is bound
└──────────────────────────┘
```
Shared components (one implementation, used by all three games; `app/lib/game/hud/`):
| Component | File | Spec |
|---|---|---|
| `HudPlate` (widget + Flame component) | `hud_plate.dart` | radius 22, `plate` fill, 2 dp `ridge` border, optional `StrokedText`; high-contrast → `plateSolid`, stroke +50 % |
| `StrokedText` painter | `stroked_text.dart` | stroke pass (6 px, `stroke`) then fill; hard offset shadow dy 4, blur 0 |
| `ApproachRing` | `approach_ring.dart` | ring shrinks onto target over `warningMs`; ring closing = window centre |
| `TargetZone` | `target_zone.dart` | thick outlined rounded rect/ring; shape encodes hand (◐ circle = left, ◆ diamond = right) |
| `GhostPose` | `ghost_pose.dart` | dashed accent outline of target pose; fills to 30 % + 1 pulse on match |
| `Skeleton` | `skeleton_painter.dart` | 3–4 dp parchment strokes over 2 dp dark under-stroke (never single neon) |
| `ComboBadge` | `combo_badge.dart` | M3-style shape morph rounded-rect → pill → star badge at ×5/×10 |
| `TrackingOverlay` | `tracking_overlay.dart` | HUD desaturate 40 % (one ColorFilter) + amber ring + person icon + "Step back into view" + Jugnu glow at lost joint |
| `DistanceMeter` | `distance_meter.dart` | edge bar, person icon slides to sweet-spot band from shoulder–hip span |

### 3.4 Motion rules (budget-safe)
- **No blur, no `BackdropFilter`, no full-screen shaders.** Transform + opacity only.
- Springs: punch-in scale 0.6 → 1.08 → 1.0 over ~220 ms (`SpringDescription(mass:1, stiffness:500, damping:22)`); exit 120 ms fade + 0.9.
- 80/20: 80 % calm fades (150–200 ms), 20 % expressive (rep, combo, clear).
- Feedback starts ≤ 1 frame after the engine event; mid-play celebrations ≤ 600 ms; ≤ 2 animated HUD elements at once.
- Odometer numbers (slide 12 dp + fade); move names stretch-in `scaleX` 1.2 → 1.0.
- Particles pooled ≤ 40 per burst, lifetime ≤ 700 ms. Screen shake ≤ 4 px, off in Gentle and reduced motion.
- Reduced motion (OS or toggle): bounces → fades; no shake/parallax. Photosensitivity: ≤ 3 flashes/s, no full-screen white; use a marigold border pulse.
- Feedback table (all games): rep/hit 220 ms tick + pluck; Perfect `mehendi` tick + "PERFECT" 52 dp + 12 sparks 400 ms;
  combo ×5/×10 badge morph 500 ms; miss grey ring 200 ms soft thud; clear = full-width gradient plate + "CLEARED" 104 dp +
  original confetti (diya-like teardrop, marigold dot, kite diamond) ≤ 1.5 s, skippable by raise-hand.

### 3.5 Icons
Chunky rounded filled glyphs, 3 dp `stroke` outline, 24-unit grid, 48–72 dp in game. Original **body-first figure set**
(round head, capsule torso — same proportions as the avatar) for arms up, side step, squat, march, reach L/R, lean,
swing, bowl, catch. Status icons: person-outline, sun-arrow, phone-tilt, footprints, pause. Every state = icon + word +
colour. Material Symbols Rounded (Apache 2.0) allowed in the shell only.

### 3.6 Onboarding (shared by all three games; `app/lib/screens/self_view_onboarding_screen.dart`)
1. **Hand-held:** "The camera stays on your phone. Only 33 body points are used. Nothing is recorded." Mode picker
   (Avatar pre-selected / Silhouette / Mirror) + jumps toggle (default off, rule 9) + 18+ confirmation (account holder).
2. **Place the phone:** upright on the floor, ~2.0 m. Framing silhouette + 3 checks: Whole body visible · Light OK · Space clear.
3. **Distance meter** "Closer / Perfect / Step back".
4. **Hello pose:** raise both hands → doubles as calibration capture (reuse `calibration.dart` fields) and proof pose control works.
   No touch needed after this (pause = hold hands in an X 1 s, or tap).
5. **First move:** ghost demonstrates at half speed; player mirrors 3× with generous thresholds.
6. **Re-entry < 24 h:** skip to step 2; auto-pass if checks clear in < 2 s.
Per-game add-ons: C space check (arm span 2.2 R inside frame); D mandatory space checklist (§6.10); E balance safety card.

### 3.7 Do / Don't (copy and art)
Do: plates or strokes for all in-game text; test on white walls, patterned saree/kurta fabrics, bright windows, dim
tube-light rooms; Indian warmth via palette and original festive geometry. Don't: neon text on camera, thin weights,
long sentences, red/shake/"FAIL" for misses or tracking, stereotyped clip-art (temples, rangoli wallpaper), copying any
game's HUD/mascot/palette, any touch requirement at 2 m, any calorie/weight line ("Great moves!", never "You burned X kcal").

---

## 4. Characters & avatars

### 4.1 Cast (one shared cast; original Indian fauna; no deity vahanas or sacred animals)
| Character | What | Where | Look & palette | Personality / catchphrase |
|---|---|---|---|---|
| **Coach Kavi** (the one Kavi) | Anthropomorphic **Bengal fox** (big ears, black-tipped tail, slim legs); sleeveless **teal running vest** with one white stripe, wristbands, no logos | **All games**: onboarding, session intros, rests, results. **Host of Pataka Pose (E)**; between-balls captain in D | fox `#E8742A`, cream `#F6E7D0`, ink `#2B2230`, vest `#1E8C8A`, accent `#F5B700` | Calm senior teammate, dry humour, theatrical "mela announcer" mode in E. "Chalo, ek aur!" (EN "One more go?") |
| **Mithu** | Rose-ringed parakeet, oversized headphones | **MC of Mirror Mela (C)** — calls zones, hypes combos; **commentator** in D ("Mithu on the mic") | leaf `#3DAA4A`, beak `#D7263D`, pink-black neck ring | Loud, joyful, beat puns. "Beat pakdo!" |
| **Golu** | Young one-horned rhino, sweatband | **Bowler / keeper in D**; holds Raid Rush mat; pad wall of your best accuracy | slate `#7A8490`, pink ears, red pads `#E63946` | Gentle giant, dramatic "oof!". "Ek, do — combo!" |
| **Neela** | Smooth-coated otter, flower-print towel | **Cool-downs** in all games; **Chill Frames + Balance Lantern** in E; Gentle-profile guide | teal `#2A9D8F`, sand `#E9C46A` | Unhurried, kind. "Aaraam se." |
| **Chikki** | Indian palm squirrel, tiny goggles, scarf | **Rival**: AI batting side & raid defender captain in D, Copy-Cat Chain rival in E, best-run ghost | tawny `#B5835A`, cream stripes, scarf `#F4A261` | Cheeky good loser, high-fives. "Pakad sako toh pakdo!" |
| **Baadal** | Monsoon cloud creature (not a spirit/god) | **Orbit hazards boss in C**; Monsoon Ground rain delays in D (cosmetic); Statue Bazaar prankster in E | storm `#4A5A8C` → lilac `#9D8DF1`, lightning eyebrows | Theatrical, sulky, secretly lonely. "Garaj garaj!" |
| **Jugnu** | Firefly sprite | **Tracking help in every game**: glows where the camera lost you, lights the framing outline | glow `#FFE45E` | Chirps + points; text carries the meaning |

Reconciliation: earlier drafts described Kavi as a "paper-lantern puppet with a festival moustache" for Game E —
**dropped**. Kavi is the fox everywhere. E's festival flavour comes from Kavi's **vest colourways and festival scarves**
(e.g. Diwali marigold scarf, Holi colour-splash vest, Uttarayan kite-string wristbands) and from props Kavi holds
(paper lanterns as props only). All Kavi's E lines are kept (§7.7).

Avoid entirely: cow, elephant, monkey, peacock as a character (peacock **colour** token is fine), cobra/naga, owl,
swan, tiger-with-rider, halos, third eye, tilak, religious symbols, temple bells as power-ups; Bholu / Shera look-alikes.

### 4.2 Voice & tone rules (all languages; strings in `app/lib/l10n/coach_strings.dart` → move to JSON `content/l10n/*.json`)
| Rule | Detail |
|---|---|
| Length | ≤ 8 words per in-play bark; ≤ 2 lines on rest screens |
| Person | Second person, talks to "you" ([Lyons/UTMB](https://chairsearches.utmb.edu/newsroom/article8962.aspx)); short barks not cutscenes ([Faric 2021](https://discovery.ucl.ac.uk/id/eprint/10139156/)) |
| Subject | Game verbs only (zone, bubble, ball, shape, frame, raid). Tease the frame, the game or the character itself — **never the body**, weight, calories, "burn", "tone", pain, health, guilt or streak shame ([Duolingo backlash, weak sources](https://desirabilitylab.com/backfill/backfill-2025-46-duolingo-streak-design)) |
| Tracking | Always the camera's/Kavi's fault: "I lost you — step back a bit." / "पैर नहीं दिख रहे — थोड़ा पीछे हटिए।" / "પગ દેખાતા નથી — થોડા પાછળ જાઓ." |
| Choices | Praise assist/low-impact/seated/wall support as *smart*: "Holding the wall is pro strategy, not cheating." |
| Register | Hindi **आप**, Gujarati **તમે**; Hinglish as flavour in EN mode only; player addressed with gender-neutral imperatives ("चलिए!", "बहुत बढ़िया!"); avoid gendered past tense unless pronouns set |
| Kavi's own gender | Current strings are masculine first person ("दूँगा"). Owner decision §10-2 |
| Timing | Reaction bark ≤ 200 ms after the engine outcome (never on raw rep, rule 6); no-repeat window 20 lines, seeded picker (rule 8) |
| Review | Native-speaker review hi/gu; regional slang check (D commentary) |

### 4.3 Player avatar & costume system (`app/lib/game/avatar/`)
- **Pickers, no male/female gate:** body shape 5 (slim, average, broad, curvy, larger), height 3, skin tone 10 swatches
  (Monk-scale-inspired, tint mask — no per-tone art), hair 12 (buzz, braid, bun, curls, long straight, bald…), optional
  facial hair, outfit sets 5 × 4 colourways (athleisure, kurta-style top + joggers, salwar-style joggers, tee + shorts,
  full-sleeve modest set), shoe colour. Optional pronoun setting (he/she/they/none; default none) only changes grammar.
- **No body-changing rewards** (no "slimmer avatar after X runs"). Body shape is cosmetic, never tied to progress.
- **Rig:** cut-out parts (head, torso, upper/lower arm ×2, upper/lower leg ×2, hands, feet) placed by landmarks via
  `ViewportMapper`; bone lengths from calibration so the avatar never "stretches"; visibility < 0.5 → limb fades over
  150 ms and is held at last pose (never snaps).
- **AR costumes (anchored, landmark-only, drawn in Flame above the texture or avatar):** head = nose + ears (0, 7/8) →
  hats/headphones/Kavi ears (above ear line; never cover eyes/mouth); shoulders 11/12 → capes, back aura (behind body,
  **not** a halo above the head); wrists 15/16 → glove glow + trails; hips 23/24 → belt glow; ankles 27/28 → footstep sparks.
  Scale by shoulder width, rotate by shoulder/ear line, One Euro smoothing.
- **Items (v1, original):** 6 hats (marigold-leaf band, kite cap, star headband, Baadal cloud puff, Mithu headphones,
  Kavi ears), 4 auras (sunrise, monsoon, firefly ring, geometric ring behind shoulders), 5 trails (ribbon, sparkle, kite
  string, raindrops, ember), 3 footstep FX; per-game kits (D bats/kits, E skins Kurta-Bot, Neon Stick, Lantern-Light, Auto Driver).
- Character/costume data: `content/schema/character.schema.json`, `content/schema/costume.schema.json` (§8.3).

### 4.4 Asset & size budget (install, WebP q≈90 / OGG)
| Asset | Spec | Est. size |
|---|---|---|
| Kavi cut-out rig (~18 parts + 6 expression heads: neutral, smile, big cheer, thinking, pointing, concerned-kind) | 1 atlas 1024² | 250 KB |
| Mithu, Golu, Neela, Chikki, Baadal rigs | 512–1024² each | 750 KB |
| Jugnu + UI glow | 256² | 30 KB |
| Rig animation JSON (idle, cheer, point, think, react-hit, react-miss, wave) | 7 chars | 100 KB |
| Avatar parts (bodies × heights, hair, outfits, faces) | 2–3 atlases 1024², tinted skin | 700 KB |
| Costume items (18) + FX sheets | 2 atlases 1024² | 400 KB |
| Kavi festival vests/scarves (6) | 512² | 120 KB |
| Portraits (7 chars × 2 sizes) | 512² | 400 KB |
| Game C/D/E scenery (6 stalls, 6 grounds, 6 Mela Map stalls; palettes + shared parts) | atlases ≤ 1024² | 2.0 MB |
| SFX + pentatonic zone notes (generated like `tools/gen_cues.py`) | OGG | 400 KB |
| Barks: chirps + text at launch | OGG | 300 KB |
| Full VO (optional, on-demand pack per language) | ~6 KB/line | 1.5–2.5 MB per language, **not in base install** |
| Music: 3 tracks (one per game) | OGG ≤ 3 MB each | ≤ 6 MB, first track in install, others on-demand via `/content` |
| **Total new base install** | | **≈ 8–9 MB** (character set ≈ 3–5 MB of it); app assets today 320 KB |
Runtime: ≤ 12 MB resident character/costume textures; unload per-game assets between sessions; atlases ≤ 1024²
(2048² ≈ 16 MB decoded). Animation tech: **cut-out rigs in Flame + sprite-sheet FX**; Lottie only for 1–2 shell
flourishes; Rive only if `flutter build appbundle --analyze-size` shows ≤ 3 MB per-ABI delta (one report of ~80 MB
bloat: [itnext](https://itnext.io/how-i-drastically-reduced-my-flutter-app-size-by-80mb-with-just-one-line-of-code-967ba19cef98)); Spine skipped (licence + `flame_spine` 0.4.0-dev).

### 4.5 Production plan (≈ 8–10 weeks, parallel with M1–M4)
| Week | Work | Who | Gate |
|---|---|---|---|
| 1–2 | Silhouettes → 3 options per character → pick → turnaround + 6-expression sheet | Illustrator #1 | Sensitivity review: Hindi + Gujarati native reviewers + 1 inclusion reviewer |
| 3–5 | Cut-out parts → atlas + JSON keyframes against `character.schema.json` | 2D game animator | `npm run content:validate` passes; on-device ≤ 2 ms |
| 3–6 | Avatar kit (tint masks) + 18 costumes with documented landmark anchors | Illustrator #2 | anchor test scene with recorded landmarks |
| 5–7 | Chirps first; VO (en/hi/gu) for Kavi + Mithu if approved; 48 kHz WAV masters + OGG | Voice actors | model releases |
| 7–8 | Integration, CI size gate (`--analyze-size`), texture RAM check on budget phone | Eng | budgets in §4.4 |
Brief rules for every freelancer: original work only (no tracing Duo, Ring, Pokémon, Sonic, league/team mascots,
Bholu, Shera), process files as provenance, disclose AI tools (recommend none for final art), full IP assignment /
work-for-hire, no religious symbols, flags, teams or brands, no body/weight humour, diverse bodies and skin in key art.
Rough cost (assumption): design ₹1.5–3 L, animation ₹1.5–3 L, avatar/costumes ₹1–2 L, VO ₹0.5–1.5 L.

---

## 5. Game C — MIRROR MELA (AR mirror arcade)

*"The fair comes to you."* Host: **Mithu**; hazards boss: **Baadal**; tracking: **Jugnu**; cool-down: **Neela**. Accent: marigold/kumkum.

### 5.1 Core loop (one 75 s round)
1. A fair object (bubble, paper lantern, marigold, kite, colour splash) enters from the edge and drifts to its **anchor**
   zone beside your body; an **approach ring** shrinks onto it over the warning time.
2. Put the named body point in the zone and hold **≥ 2 frames** inside the window → pop, a pentatonic note, combo +1.
3. Orbit only: hazards sweep a band; leave it (half squat, lean, side step) before the ring closes.
4. Round end → score, grade C/B/A/S, best combo, "zones you reached" body map → 20 s rest → next round.
Rule 6: reaching an empty zone does nothing — no score, no penalty.

### 5.2 Body points and zones (moves → actions)
Body points: `handL/R` = mean of wrist/index/pinky (15/17/19, 16/18/20) when each vis ≥ 0.5, else wrist alone if vis ≥ 0.6,
else `notVisible`; `head` = nose, or shoulder centre + 0.9 T if nose vis < 0.5; `hips` = hip centre; `kneeL/R` = 25/26.
T = shoulder-centre→hip-centre; R = calibrated reach (default 1.15 T). Zones clamped inside 85 % frame width / 90 % height.

| Zone | Body point | Anchor (from shoulder centre, +y up) | Radius beg / int / adv | Detection note |
|---|---|---|---|---|
| `hi-L` / `hi-R` | same-side hand | x ±0.55 R, y +0.85 R | 0.50 / 0.42 / 0.36 T | Reliable (overhead, in-plane) |
| `side-L` / `side-R` | same-side hand | x ±0.85 R, y 0 | 0.50 / 0.42 / 0.36 T | Reliable (lateral reach ≥ 0.75) |
| `low-L` / `low-R` | same-side hand | x ±0.70 R, y −0.95 T | 0.55 / 0.45 / 0.40 T | Reliable; small side bend |
| `crown` | both hands | x 0, y +0.95 R, hands within 0.6 T | — | Reliable (= raise arms) |
| `chest` | both hands | x 0, y −0.35 T, hands ≤ 0.35 T apart | 0.45 T | Medium: overlap → accept vis ≥ 0.3, any frame in window (clap rule) |
| `knee-L` / `knee-R` | knee | lift ≥ 0.5 calibrated lift, 2 frames | — | Reliable (KneeLift from plan 1 / `3-tech` §4.1) |
| `duck` | head | head drop ≥ 45 % (low-impact) / 60 % calibrated squat depth | — | Reliable (existing `SquatRecogniser`) |
| `lean-L` / `lean-R` | hips + shoulders | ≥ 60 % of lean range | — | Reliable (existing `LeanRecogniser`) |
Cross-body zones **off in v1** (crossed arms swap L/R on BlazePose Lite); return when recorded recall ≥ 0.9.

Grades (timestamp of first qualifying frame, capture time − `latencyOffsetMs`):
| | Perfect | Good | Graze | Miss |
|---|---|---|---|---|
| Beginner | ≤ ±200 ms | ≤ ±400 ms | in time, 1.0–1.3× radius | else |
| Intermediate | ≤ ±150 | ≤ ±300 | 1.0–1.25× | |
| Advanced | ≤ ±120 | ≤ ±250 | 1.0–1.2× | |
| Assist | +100 | +200 | 1.0–1.4× | |
Window ≥ max(spec, 2.5 × measured frame interval). **Early hold:** hand already parked when the window opens → Good max (anti-camping).

### 5.3 Sub-modes
| Mode | Rules | Density / caps |
|---|---|---|
| **Bubble Bazaar** (flagship, free, vertical slice) | Hand targets; shape tells the hand (◐ circle left, ◆ diamond right; beginner accepts any hand). **Double lantern** = `crown`/`chest`. **Catch-and-place** (int+): catch at `side-L`, drop at `low-R` within 1.5 s (no crossed wrists) | 22 / 30 / 38 targets/min; max on screen 1 / 2 / 3; per-hand gap 1000 / 800 / 650 ms (+250 low-impact); overhead ≤ 6 per 30 s, ≤ 3 in a row; never two singles within ±250 ms on beginner |
| **Orbit** | 8 clock positions (10, 11, 12, 1, 2, 3, 4, 8 o'clock); sparks stop then ring closes. Baadal's hazards (slow comet, swinging fair rope, wheel spoke) are first **heard behind you** (stereo pan + floor shadow, 1.0 s), then sweep **head band → `duck`** or **left/right half → `lean`/side step**. Chest band never used (would need a jump or forward move) | Hazard warning ≥ 2.2 s; mix collect/dodge 80/20, 70/30, 60/40; dodges ≥ 3 s apart; no collect within 1200 ms after a dodge. Hit = −combo and −1 of 3 shield pips, never the round; 0 pips → ×0.5 until next 5-combo |
| **Rang Wall** | 8 tiles, each a pose stencil; hold 600 / 800 / 1000 ms → colour fills tile. Lean to move cursor or follow guided order. Poses: Star, T, Goalpost (elbow 70–110°), Side bend L/R, Half chair (squat 45 % + T), Tree-lite (adv, ≤ 3 s), Victory. Uses the shared `PoseMatcher` (§8.1) with angle tol ±25° / ±18° / ±12°; failed match names **one** part ("left arm higher") | 10–12 poses/min; fill 70 % at min hold → 100 % at 2×, capped; wall complete +500 and saves a landmark-free art card |

### 5.4 Session structure (≈ 5:15)
| Time | Block | Content |
|---|---|---|
| 0:00–0:35 | Check-in | distance + space check (arm span 2.2 R inside frame, ≥ 10 % margin); reuse calibration unless missing or drift > 15 % |
| 0:35–0:50 | Warm-up | 8 slow `side-*`/`crown` bubbles, unscored, 3.0 s warning |
| 0:50–2:05 | Round 1 | Bubble Bazaar 75 s |
| 2:05–2:25 | Rest | score, combo, Neela breathing ring |
| 2:25–3:40 | Round 2 | Orbit (or pick) |
| 3:40–4:00 | Rest | |
| 4:00–5:00 | Round 3 | Rang Wall 60 s (calm finish) |
| 5:00–5:15 | Cool-down | side bend L/R 6 s each, results, share |
Inner pacing (75 s): 0–10 intro singles → 10–35 build → 35–45 breather (no hazards, no overhead) → 45–70 peak
(doubles, catch-and-place, hazards) → 70–75 finale (6 golden L-R-L-R-crown-crown). Beginner 60 s, advanced 90 s. Quick Play = 1 round.

### 5.5 Scoring
Perfect 100, Good 60, Graze 30, Miss 0; double ×1.5; catch-and-place +150; dodge +50; Rang tile 200 × coverage.
Combo +5 % per non-miss (×1.0 → ×2.0 at 20); miss/hazard resets; forgiven never breaks. **Mela Rush** (fever) at 15
combo: 8 s golden ×1.5 + music layer — **never harder or faster**. Grade S ≥ 90 %, A ≥ 75 %, B ≥ 55 % of max possible.

### 5.6 Difficulty & bands
| | Warning | Max on screen | Targets/min | Radius | Rang hold | Hazards |
|---|---|---|---|---|---|---|
| Beginner | 2.0 s | 1 | 22 | 0.50 T | 600 ms | ≥ 2.6 s, 20 % |
| Intermediate | 1.6 s | 2 | 30 | 0.42 T | 800 ms | 2.2 s, 30 % |
| Advanced | 1.3 s | 3 | 38 | 0.36 T | 1000 ms | 2.2 s, 40 % |
| Assist | +25 % | −1 (min 1) | −25 % | +20 % | −200 ms | +0.4 s |
Harder = more decisions, not more speed (approach never < 1.3 s). Pace profiles (self-chosen, never camera-inferred, adults 18+):
**Energetic** (intermediate, overhead cap 6/30 s), **Steady** (default: beginner, low-impact on), **Gentle** ("prefer a softer
pace": beginner + assist, half squat max, overhead 4/30 s, no `knee-*`, rest 30 s, 4 min session). Zones scale to calibrated reach.

### 5.7 Forgiveness (rule 5) & accessibility
- Target **forgiven** if tracking was amber/red from 300 ms before its window to window close, or < 800 ms (1200 assist)
  of green since recovery; removed from the max. Amber → world 60 % speed; red → freeze; Jugnu glows at the lost hand.
- No jumps ever in this mode; deepest = half squat on low-impact; no floor touches, no forward lunges.
- **Seated** (Gentle, opt-in): upper-body zones only; needs new upper-body `QualityGate` profile (shoulders, elbows,
  wrists, hips vis ≥ 0.5; legs ignored) — must pass the replay gate.
- **One-arm mode**; knee zones auto-swap to `side-*` when knee vis is low (sarees, dupattas, loose kurtas).
- Not colour alone: shape per hand, distinct note per zone, stereo pan, big ring.

### 5.8 Juice
Pop: 50 ms hit-stop on the object only, 12–16 particles, shockwave ring 1.6× over 180 ms, score floats 40 px.
**Musical zones:** pentatonic Sa Re Ga Pa Dha (C D E G A), left lower, high zones higher, `crown` = upper Sa; Perfect adds
sparkle overtone, Graze a muted pluck — a combo plays a melody (generated, original). Rang Wall splash fills outward over
400 ms; complete wall cycles an original geometric kaleidoscope. Orbit: rear sting + floor shadow + whoosh; dodge = 150 ms shimmer.

### 5.9 Progression & cosmetics
XP = existing formula (score/20 + active s/10 + 50 per completed session). **Mela Tickets** (earned only, never sold):
1 per 1,000 points, +5 per session, +10 daily challenge → hand trails (10), pop effects (8), avatar skins (12), wall
palettes (8), stall themes (6). **Stalls:** Bubble Bazaar, Lantern Night, Kite Terrace, Monsoon Courtyard, Harvest
Field, Starlit Ferris (1 per 2 Hero levels free set; all with Premium). **Daily Remix:** IST-date seed shuffles from the
authored pool (deterministic). Personal bests per mode × difficulty; weekly "zones reached" map (what you did, never a body measure).

### 5.10 Social
Last **15 s of landmarks** in RAM (15 × 30 × 33 × (x,y,vis) ≈ 180 KB) → "Make my clip": avatar + objects + score +
watermark "Joynetic • Mirror Mela", 720×1280, 15 s, ≈ 3–4 MB MP4 via `native/clip_encoder`; share sheet only, no
auto upload, cache deleted after 24 h unless saved. Static Rang Wall art card + result card. **Pass-and-play** 2–4 adults,
one tracked at a time, 60 s Bubble Bazaar each, 10 s quick calibration per player. Copy: "I scored 18,420 at Mirror Mela".

### 5.11 Festivals (JSON stall skins)
Diwali Lantern Night (diya-shaped bubbles, no cracker SFX by default), Holi colour splashes (Rang Wall palette swap),
Uttarayan Kite Terrace (kites as targets; catch-and-place "reel in"), Monsoon Courtyard (Baadal week: extra Orbit
content), Onam/Pongal Harvest Field. No deity imagery or ritual gestures.

### 5.12 Free / Premium (Google Play only; offer only on store screen and post-session results — never during a round, never after a loss)
| Free (unlimited) | Premium (existing Joynetic Premium; gym code unlocks) |
|---|---|
| Bubble Bazaar all difficulties, 2 stalls; Orbit 1 stall; Rang Wall 3 walls; Daily Remix; clips; pass-and-play (Bubble Bazaar) | All 3 modes × 6 stalls; Rang Wall 40-wall library + 4 new/month (JSON packs); premium cosmetic set (6 skins, 4 trails), clip frames; pass-and-play all modes; weekly Crew boards |

### 5.13 Metrics (beta targets)
| Metric | Target |
|---|---|
| Zone hit recall (recorded clips, ≥ 20 players, 2 phones incl. budget) | ≥ 0.90 per zone |
| False pops (idle 2 min) | ≤ 1 / 2 min |
| Field miss rate per zone | flag > 35 % (mis-tuned anchor/radius) |
| Rounds with amber/red > 10 % of time | < 8 % |
| 5-min session completion | ≥ 70 % |
| D1 / D7 | ≥ 35 % / ≥ 15 % |
| Sessions / active player / week | ≥ 3 |
| Clip made / shared per session | ≥ 15 % / ≥ 5 % (hypothesis) |
| Avatar vs Mirror usage | track only (informs default) |
| Perf | capture→judged < 200 ms budget, painter ≤ 6 ms, ≥ 15 fps |

### 5.14 Risks
| Risk | Mitigation |
|---|---|
| Preview–landmark lag looks broken | judge + draw at landmarks, hand halo, Avatar default, optional native preview delay |
| Wrists 8–12 px on budget phones, blur | big zones (≥ 0.36 T), 2-frame dwell, 3-point hand mean, 2.0 m distance prompt |
| Hands near frame edge drop visibility | 85 %/90 % clamp, space check, `notVisible` shown |
| L/R swap on crossed arms | no cross-body zones v1 |
| Arm camping | early-hold = Good max, alternating sides, overhead cap |
| Shoulder fatigue | overhead caps, breathers, Gentle profile; no medical claims |
| Small rooms, ceiling fans | arm-span space check; no jumps; never above calibrated overhead |
| Self-consciousness | Avatar default, Mirror opt-in |
| Looks like existing AR pop games | original fair theme, musical melody zones, pose-painting wall, rear-audio dodges; original assets |
| Novelty fades in 2 weeks | Daily Remix, monthly Rang packs, pass-and-play, Crew boards |

---

## 6. Game D — TAPEBALL TAMASHA (self-view street cricket + Raid Rush + Shuttle Rally)

Commentary: **Mithu on the mic**; captain between balls: **Kavi**; bowler/keeper: **Golu**; rival side and raid
defenders: **Chikki's crew**; warm-up/cool-down: **Neela**. Accent: peacock/scarf. Name: *Tapeball Tamasha*
(backups *Backyard Boundary*, *Gully Games Night*). **Never** "Chhakka" in titles (slur in parts of India) and never
"Premier", "League", "IPL", "T20 World", "Super Kings", "Indians", "Royals", "Knight", "Titans", "Capitals",
"Sunrisers", "Giants" in any title/mode/crew/cosmetic. Lives in a separate **Sports** hub; World 5 Stadium Nights stays a runner world.

### 6.1 Core loop (one delivery ≈ 10–14 s)
1. **Set** (2 s): stand on the centre crease marker; mirrored avatar wearing your kit, "space ring" on the floor.
2. **Telegraph** (Gentle ≥ 2.0 s, Balanced ≥ 1.6, Active ≥ 1.3): Golu runs in (or the original bowling machine); approach
   ring shrinks onto the hit zone — the ring *is* the window.
3. **Shot:** backlift → swing, or leave / defend. Graded Perfect/Good/OK/Miss on capture timestamp with latency compensation.
4. **Outcome** (rule 6 — game state decides): grade + chosen shot + seeded fielder layout → 0/1/2/4/6 or caught.
5. **Run between wickets** (Balanced/Active): "RUN!" → **march in place**, 4 steps = 1 run before the throw-in bar fills;
   cadence ≤ 2 Hz *est.*; never forward running.
6. **Reset** (2–3 s): stylised replay of your shot from landmarks (no video) + Mithu line.
Bowling innings mirror it: you bowl, Chikki's side bats, then you field what they hit.

### 6.2 Moves → actions (front camera, 2.0–2.5 m, Lite model; all end states ≥ 2 frames; every reject emits `notVisible | tooShallow | tooEarly`)
| Action | Move | Detection notes | Verdict |
|---|---|---|---|
| Drive / ground shot | Swing (roadmap §3.6): wrists together (< 0.3 T), backlift at/above trailing shoulder held 100 ms, wrist **midpoint** travels ≥ 1.0 shoulder width (low-impact 0.6, no rotation) to front hip in 250–1200 ms | midpoint avoids L/R swap; lateral, in-plane; hips within 0.5 T = no lunge; 1.5 s cooldown | Reliable |
| Lofted shot (bonus 6) | same swing, end zone ≥ shoulder height front side, 2 frames | coarse y vs shoulder line; bonus only until replay confirms | Medium |
| Leave | both wrists above nose ≥ 0.15 T during ball window | existing `RaiseArmsRecogniser`; leaving a wide = judgement bonus | Reliable |
| Defend / block | barrier hold at chest across arrival ±200 ms | existing `BarrierHoldRecogniser`; static hold only, never a strike | Reliable |
| Bowl | Bowl (roadmap §3.7): straight arm (≥ 150°, low-impact 130°) above nose ≥ 0.3 T → wrist below hip front side in 400–1500 ms | no run-up, no step; in-plane sweep; 1.5 s cooldown | Reliable |
| Line choice | side step L / centre / R before "ready" tone | existing `SideStepRecogniser` | Reliable |
| Pace vs slower ball | bowl duration ≤ 800 ms = pace; 900–1500 ms = slower | duration between end states, wide gap absorbs ±67 ms quantisation | Medium (bonus) |
| Catch high | `catchZone`: wrists together (< 0.35 T) in lit zone high-L/C/R, 2 frames before landing | wrists-together separates it from raise-arms | Reliable *est.* |
| Catch low / ground stop | half squat + both wrists below hip on ball side (lean/step first) | squat + lean existing; **no dives, no lunges** | Reliable |
| Throw-in | one arm overhead, hold 300 ms | end state; counts toward overhead cap | Reliable |
| Celebrate | both arms up 1 s | flavour only, no score | Reliable |
| Raid: dodge | side step L/R | existing | Reliable |
| Raid: touch | `lateralTouch`: reach ≥ 0.75 arm (LI 0.6), elbow ≥ 145°, wrist at shoulder ±0.3 T, held 2 frames | slow held reach, targets ≥ 30° off-axis; **no punching** | Reliable |
| Raid: duck the chain | squat (LI half) | existing | Reliable |
| Raid: bonus line | toe tap (Gentle) / knee lift (Active) | no hops | Reliable |
| Shuttle: smash / clear | `overheadReach`: one wrist above nose ≥ 0.3 T **and** beyond shoulder on shuttle side, 2 frames | distinct from bowl (no sweep) and raise-arms (one arm, offset); never a bowl and a shuttle within 2 s | Reliable *est.* |
| Shuttle: net drop | side step + mid-height reach that side | no lunge toward net (= camera) | Reliable |
**Banned:** lunges/steps/runs toward the phone, swings or punches *at* the camera, dives, jumps (unless enabled — then only a
small hop in Raid Rush), wrist-flick spin, fast repeated swings, twisting under load (rotation off in low-impact).

### 6.3 Modes / match formats (JSON; ≤ 4 min of play except Gully Match)
| Format | Rules | Length | Access |
|---|---|---|---|
| **Nets** | 12 balls, hints, no outs; grade + "why" on every miss | 2–3 min | Free |
| **Super Over** ("Over of the Day" daily seed, refresh 18:00 IST) | bat 6 (2 wickets max; beginner none), field, then bowl 6 to defend | ≈ 3:30 | Free (daily) / Premium (any seed) |
| **Bowl-Out** | 6 deliveries at lit stumps (line + tempo), AI defends | ~90 s | Free |
| **Fielding Drill** | 10 catches/stops, seeded zones, march back between | ~2 min | Premium |
| **3-Minute Chase** | need T runs in 18 balls (T 18 / 26 / 34 *est.*); timer runs only while tracking green | 3:00 | Premium |
| **Gully Match** | 2 overs bat + 2 bowl vs Chikki's side, breather card between | ~8 min | Balanced/Active, Premium |
| **Raid Rush** | 3 raids × 30 s "breath bar": tag defenders, dodge, duck the chain, return to midline (side step centre) | ~2:30 | Free taster (1 raid set) / Premium |
| **Shuttle Rally** | rally to 11; hang time 2.4 / 2.0 / 1.6 s | ~3 min | Premium |

### 6.4 Session structure
45 s warm-up (arm circles, gentle trunk turns, march; auto-inserted first session of the day) → space check (§6.10) →
chosen format → 30 s cool-down with Neela. Daily XP soft cap after 3 sessions (avoid overplay). Breather card ≥ 20 s between innings.

### 6.5 Scoring
Batting: outcome table `grade × shot × fieldSeed` (JSON `outcomes`), e.g. Perfect drive → 4 (60 %) / 2 (30 %) / 1;
Perfect lofted → 6; OK lofted into a lit fielder → caught (int+ only); leave of a wide +1 extra; dot on Miss. Bowling: stumps
hit = wicket; line + tempo variety ×1.2 bonus; fielding catch +10, stop +5. Chase win = stars 1–3 by balls remaining.
Mithu calls every outcome (keyed lines).

### 6.6 Difficulty × bands
| | Gentle (default) | Balanced | Active |
|---|---|---|---|
| Ball telegraph | ≥ 2.0 s | ≥ 1.6 s | ≥ 1.3 s |
| Swing window | ±550 ms (assist) | ±350 → ±300 | ±300 → ±250 |
| Swing thresholds | low-impact (0.6 width, no rotation) | LI until calibrated twice | standard (1.0 width, ≥ 15 % rotation) |
| Bowls per session (max) | 12 | 18 | 24 |
| Overhead moves/min (bowl + smash + throw) | ≤ 4 | ≤ 6 | ≤ 8 |
| Run-between-wickets | auto-run | march, 4 steps/run | march, longer chases |
| Wickets | none on beginner | 2 | 2 (3 in Gully Match) |
| Raid bonus | toe tap | toe tap | knee lift |
| Shuttle hang time | 2.4 s | 2.0 s | 1.6 s |
Safe progression per `docs/stages-roadmap.md` §6 (one step per week of play, deload every 4th, struggle/comeback rules).

### 6.7 Forgiveness
Any delivery whose window overlaps amber/red is a **dead ball** — re-bowled, no run, no wicket, chase timer pauses, Kavi:
"Step back — I lost your hands." A swing with no ball in window does nothing; out-of-timing swing just misses. ≤ 2
wickets lost per Super Over. No `ball` and `wicket` encounter within 3 s; 2 s empty after any bowl/overhead.
March fallback: if knees not visible, auto-run (never a lost run).

### 6.8 Progression & cosmetics (all earned by play; none sold individually; no loot boxes)
Player card levels 1–50 ("Gully Rookie" → "Maidan Legend"); XP from balls faced, catches, raids (not minutes). Badges:
Straight Bat (10 Perfect drives), Safe Hands (20 catches), Line & Length (6 bowl-out hits), Raid Ninja, Shuttle Wall.
Bats: tape-grip, plank, painted stripes, glow (Stadium Nights), monsoon. Kits: original palettes checked against a
**deny-list of franchise colour pairs**; patterns block-print border, kite stripes, "Classic" whites. Grounds: Gully
Lane (water-tank stumps), Terrace Top (washing lines, kites), School Maidan, Beach Evening, Monsoon Ground, Stadium
Nights (reuse `SceneTheme.stadium`). No real grounds, skylines, trophies or player likeness. Avatar wears kit via costume anchors.

### 6.9 Social — Gym Crew Cup (server `gyms` + `progress` + `reports`)
- Crew 4–11 verified gym members (gym entitlement → Premium). Weekly **Crew Cup**: everyone plays the **same seeded**
  Super Over / Chase. Crew score = sum of each member's best 2 counted attempts; ≤ 3 counted attempts/day, ≥ 4 h apart.
- **Divisions by band** (Gentle / Balanced / Active); attempts normalised to band par.
- Knockout: 8 crews, QF/SF/F over 3 weeks, async 48 h windows.
- Anti-cheat without video: plausibility checks on uploaded **event summaries** (grades, timing deltas, quality stats,
  fps); impossible streaks/fps anomalies flagged; forgiven balls excluded.
- Gym dashboard: participation and attendance-linked streaks only — no individual body metrics.
- No prizes of monetary value (cosmetics + gym wall certificate); clear of real-money gaming rules.
- Share: stylised shot replay clip (avatar + ball trail + scorecard) via `clip_encoder`; "I chased 26 in 18 balls".

### 6.10 Space & injury safety (biggest real risk)
Mandatory space check before every cricket/shuttle session (≈ 15 s, first time each day):
1. full body in frame at ≥ 2.0 m (body ≤ 65 % frame height *est.*);
2. T-pose and both-arms-up with both wrists inside frame by ≥ 8 % margin (proves distance; calibrates arm length);
3. checklist taps: **Fan switched off** · **1 m clear each side and above your hands** · **Nothing breakable in reach** ·
   **No real bat, racket or ball in hand** · **Dry, non-slip floor**;
4. fail/skip → only Nets (low-impact, no overhead) and Raid Rush offered.
Intruder pause ("Someone's in your play space") on sudden landmark jumps / torso length jump > 25 % (and `numPoses=2`
on upper-mid tier later). Per-band overhead caps; "switch arm" every over in Bowl-Out; "This doesn't feel right" on pause
→ end gently, keep progress.

### 6.11 Festivals / seasons (generic names only)
**Summer Cricket Fest** (mid-March → early June) and short "Cricket Fever Week" windows around big tournaments; Diwali
lights theme for Stadium Nights; Holi colour bats. Never league/team/player names, fixtures, results, trophies,
broadcaster score-bug looks; no "pick tonight's winner" (fantasy/real-money adjacency); no pushes timed to real matches;
no trademarked keywords in Play metadata.

### 6.12 Free / Premium
| Free | Premium (Joynetic Premium; gym members free) |
|---|---|
| Nets, Over of the Day, Bowl-Out, Raid Rush taster, Gully Lane, 3 bats, 2 kits, joining a gym crew when granted | Chase, Gully Match, Fielding Drill, full Raid Rush, Shuttle Rally, all grounds, all cosmetic tracks, private crews/leagues, festival events |
Access checked at mode select, never mid-match; no paywall on a loss screen; no links outside Play.

### 6.13 Metrics
Swing recall ≥ 0.9 and false trigger ≤ 1 / 2 min idle (replay gate, ≥ 20 players, 2 phones); reject-reason rates per move;
dead-ball rate < 5 %; median compensated timing delta + spread; seeded-chase win rate 55–75 % on beginner; simulator bots
pass before a config ships; space-check completion/failure; "doesn't feel right" per 1,000 sessions; injury/property
support tickets ≈ 0 (any → review); D1/D7/D30; Super Overs per session; Sports-hub conversion; % gym members in weekly Crew Cup. "Active minutes" only.

### 6.14 Risks
| Risk | Mitigation |
|---|---|
| IP/trademark (leagues, teams, likeness, grounds, trophies, broadcaster look, commentator voices, team colours) | original cast/grounds/voices (Mithu, not a real commentator), colour deny-list, legal review, generic events |
| Real-money adjacency | no predictions, no cash/coupon prizes, no "odds/stake" language |
| Swinging in small rooms (fans, glass, pets) | mandatory space check, fan-off item, frame-margin test, empty hands, intruder pause, LI default, overhead caps |
| Shoulder/back strain | caps, 2 s gaps, rotation off in LI, warm-up, deload |
| L/R wrist swap in swings | wrist midpoint + wrists-together |
| Blur on fast swings | end-state backlift + end zone; 250–1200 ms window; no speed bonus |
| Overhead-family collisions (raise/bowl/overhead/catch-high) | engine resolves by active encounter; never two within 2 s; wrists-together disambiguates |
| Latency feels unfair | capture-ts compensation, wide windows, ring = window, dead balls |
| Loose clothing hides wrists/knees | `notVisible` hint, LI thresholds, auto-run fallback |
| Low intensity (standing cricket) | march runs, fielding, Raid Rush — fun-first, no fitness claims |
| Repetition | seeded bowler variety (line, slower ball, visual-only fake-outs), grounds, mini-modes, weekly Crew Cup |

---

## 7. Game E — PATAKA POSE (party pose game)

*"Freeze in the shape before it reaches you."* **Host: Coach Kavi** (fox, festival vest/scarf). Neela runs Chill Frames
and Balance Lantern; Baadal pranks during Statue Bazaar; Chikki is the Copy-Cat rival. Accent: lilac/mehendi.
Working alternative name *Freeze Bazaar*. The approaching-cut-out is a genre convention; our form is original
(rangoli-light frames, mela setting, Kavi's lantern props); we copy no show format, wall look, sound or catchphrase.
**Audience: adults 18+ only** — framed as flatmates, friends, colleagues, game night; never family/kids framing.

### 7.1 Core loop (round ≈ 2.5–3 min, 12–16 frames)
```
[Show]  silhouette frame appears on the horizon (lead 1.6–3.5 s by band); Kavi calls the pose ("Cutting Chai!")
[Match] live skeleton/avatar: matched limbs mehendi + tick, off limbs amber + arrow (never colour alone)
[Lock]  similarity ≥ lock for ≥ 2 frames → hold ring starts filling
[Hold]  stay ≥ lock − 8 (hysteresis) for holdMs → frame BURSTS (confetti, combo +1)
        dip below → ring pauses 300 ms grace, then drains at 2× fill speed
[Pass]  frame reaches you: score = peak sustained similarity × hold completion → 0–3 stars
[Chill] every 4–6 frames a Chill Frame (stand tall, shake out) — always passes if visible
```
Mirroring: display is mirrored; pose definitions use **player** left/right; Kavi says "screen-side" on beginner.

### 7.2 Frame types (JSON)
| Frame | Behaviour |
|---|---|
| Cut-out Frame | match + hold before arrival (core) |
| Statue Bazaar | lights "off" 3–5 s; stay frozen (low motion energy + pose held); Kavi and Baadal try to make you laugh |
| Mirror Kavi | Kavi strikes a pose; you copy it; sometimes Kavi does it mirrored on purpose — "mirror-mirror!" |
| Sequence Chain | 2–3 poses, each held 800–1200 ms (Tree → Warrior Wave → Star) |
| Balance Lantern | one-leg hold; Neela's lantern rises the longer you hold (≤ 8 s); put down any time, no penalty; opt-in |
| Blink Frame (adv) | silhouette shown 1 s then hidden; strike from memory |
| Chill Frame | stand tall / shoulder rolls; recovery |

### 7.3 Moves → detection (shared `PoseFeatures` + `PoseMatcher`, §8.1)
Features (2-D, scale-invariant, player-L/R): `shoulderAbd.L/R` (0 down, 90 T, 180 up), `elbowFlex.L/R`, `hipAbd.L/R`,
`kneeFlex.L/R`, `torsoLean` (signed), `zone.wristL/R` (`overhead|head|chest|hip|low|side-out`), `footLift.L/R` (ankle ≥ 0.12 T
above standing ankle), `stance` (ankle spread / hip width: narrow < 1.2, normal 1.2–2.0, wide > 2.0). Torso length from calibration, never z.

Similarity: angle `sᵢ = clamp(1 − max(0,|Δθ| − tol)/f, 0, 1)`; zone/stance/lift 1 / 0.5 adjacent / 0; `sim = 100·Σwᵢsᵢ/Σwᵢ`
over **seen** features (vis ≥ 0.5). 3-frame median. Defaults (beginner): shoulders/hips tol 20° f 30°; elbows/knees tol 25° f 35°;
torsoLean tol 10° f 15°; int −5°, adv −10°. **Must** features: sᵢ < 0.4 caps sim at 60 %. `mirrorOk` poses scored both ways, best taken.
Freeze check: mean displacement of 12 core joints < 0.02 T/frame. Weights favour shoulder/elbow/hip/knee; wrists/ankles zone-only.

Pose library v1 (25 incl. Chill; full table to `content/party/poses/*.json`):
| # | Pose | Key targets | Must | Hold beg/adv ms | Low-impact variant |
|---|---|---|---|---|---|
| 1 | Star Burst (Tara) | shoulderAbd 135° both, elbow 170°, stance wide | stance wide | 1500/2500 | arms 110°, normal stance (no jump) |
| 2 | Cutting Chai | L hand on hip (abd 45°, elbow 90°), R arm 150° | wristL hip | 1500/2500 | seated |
| 3 | Goalpost | abd 90° both, elbow 90° both | both elbows | 1500/2500 | seated |
| 4 | Lamp Post | abd 170° both, elbows 170° | both > 150 | 2000/3000 | one arm, alternate |
| 5 | Teapot | torsoLean ±20°, hand on hip, other arm 160° | torsoLean | 1500/2500 | lean 10° |
| 6 | Auto-Rickshaw Driver | knees 120°, abd 40°, elbow 120°, wrists chest | kneeFlex | 1500/2500 | actually sit; arms only |
| 7 | Kursi (chair) | knees 130° (adv 110°), arms 150° | kneeFlex | 1500/3000 | knees 150°, hand on chair back |
| 8 | Coconut Tree | footLift one side, knee 90–120°, wrists overhead/chest | footLift | 2000/4000 | toe stays down; wall hand |
| 9 | Flamingo | footLift, knee 90°, arms T | footLift | 2000/4000 | toe tap, wall |
| 10 | Warrior Wave | stance wide, front knee 130°, back 170°, arms T | stance wide | 2000/3000 | knee 155° |
| 11 | Archer | lead arm 90°/175°, draw arm 90°/60° | lead elbow | 1500/2500 | seated |
| 12 | Bhangra Shoulders | abd 150°, elbow 120°, wrists overhead | wrists overhead | 1200/2000 | one arm |
| 13 | Arre Wah! (surprise) | wrists head zone, elbow < 60° | zone head | 1000/1800 | seated |
| 14 | Thinking Statue | L wrist head, R wrist hip/chest | wristL head | 1500/2500 | seated |
| 15 | Selfie Stick | lead arm 140°/170°, other wrist head | lead arm | 1200/2000 | seated (peace sign display-only) |
| 16 | Kite Flyer (Patang) | abd L 150° R 110°, lean ±10° | torsoLean | 1500/2500 | no lean |
| 17 | Robot Freeze | one forearm up, one down (wrist zones) | wrist zones | 1200/2000 | seated |
| 18 | Superhero Stand | wrists hip both, stance wide, lean 0 | wrists hip | 1500/2500 | normal stance |
| 19 | Side Lunge Sweep | stance wide, one knee 130° other 170° | bent knee | 1500/2500 | knee 150° |
| 20 | Hawai Jahaaz | T arms, lean ±15° | torsoLean | 1500/2500 | lean 8° |
| 21 | Knee Hug Hero | footLift, hands hip/low, knee < 90° | footLift | 1200/2000 | small lift, chair |
| 22 | Lotus Wave | abd 165° both, wrists < 0.35 T apart overhead | wrists together | 1500/3000 | any seat |
| 23 | Dabba Lifter | elbows 70°, wrists chest, knees 140° | kneeFlex | 1500/2500 | no squat |
| 24 | Pataka! (finisher) | L arm 170°, R 90°, R footLift | footLift | 1500/2500 | toe tap |
| 25 | Chill Frame | abd < 25° both, stance normal | — | 1000 | seated |
Excluded: forward reach, forward bends to floor, back bends, inversions, knee < 100°, kneeling/floor poses, fast spins,
jumps (opt-in only), neck targets, hand/finger shapes (Pose has no hands), religious gestures (no namaskar as a scored pose).

### 7.4 Party modes (18+ players; account holder confirms "Everyone playing is 18+" at party start; guests = nickname only)
| Mode | Players | Tracking | Flow |
|---|---|---|---|
| **Pass-the-Pataka** | 2–8, one phone | 1 body | 4 frames each → "Pass!" 5 s step-in countdown + re-frame check (no recalibration) → shared scoreboard |
| **Team Toli** | 2 teams × 1–4 | 1 body | alternating players; team = sum of bests; Captain's Pick: leader picks the other team's next pose |
| **Statue Showdown** | 2–8 | 1 body | each does a 5-frame Statue Bazaar; room taps a vote for funniest freeze; no elimination |
| **Copy-Cat Chain** | 2–6 | 1 body | A invents a pose (held 2 s → feature vector), B matches and adds one; invented poses checked against the safety envelope (library angle ranges, no floor/back-bend) or Kavi rejects with a joke |
| **Duo Frame** (post-MVP) | 2 in frame | `numPoses=2` | only if 10 s pre-check holds ≥ 24 fps; players assigned by screen half (hip-mid x), crossing forbidden; else falls back to Pass-the-Pataka. Bridge payload = up to 2 × 33 landmarks (still rule 4) |
Single-pose mode tracks the largest/most central body; torso-length jump > 25 % mid-frame → hover ("one player in the glow zone").

### 7.5 Round / session structure
Round: warm (3 easy) → build (6–8 mixed) → 1 Statue Bazaar → peak (2–3 incl. a chain) → Pataka! finisher → Chill.
Director caps demanding poses (squat/lunge/balance) at 2 in a row; Chill every 4–6 frames. Session: 1 round "Quick Pataka"
(keeps the streak) or 3–4 rounds "Mela Night" (10–12 min); stop after any round. Calibration once (20 s): glowing outline,
aeroplane arms, stand still 2 s (reuses calibration profile fields). Knees out of frame → director swaps to upper-body poses
and says so ("Phone a bit further? Till then, upper-body poses!").

### 7.6 Scoring, difficulty & bands
`frameScore = round(peakSustainedSimilarity × holdCompletion)` (best 300 ms median window). Stars ★ ≥ 60, ★★ ≥ 80, ★★★ ≥ 92 + full
hold. Combo ×1.0 → ×1.5 (cap at 6 frames). Perfect round = "PATAKA!" bonus +20 %.
| Band (comfort, not age) | Lead | Lock % | Hold scale | Poses | Balance |
|---|---|---|---|---|---|
| **Chai Break** | 3.5 s | 75 | 0.8× | upper-body + Chill + LI; whole round playable seated | wall/chair cue always |
| **Mela** (default) | 2.8 s | 80 | 1.0× | full library, LI on request | toe tap OK |
| **Mirchi** | 2.0 s | 85 | 1.3× | + Sequence Chain, Blink; tol −5° | full lift |
| **Pataka Pro** | 1.6 s | 88 | 1.5× | 3-pose chains, mirror tricks; opt-in leaderboard | full |
**Adaptive tolerance:** 3 fails on the same feature → that feature's tol +5° for the session, shown as "Kavi adjusted this shape for you".

### 7.7 Forgiveness & Kavi's lines (kept from the Game E draft, now spoken by fox Kavi)
Unseen features > 30 % of pose weight → frame **hovers** (stops approaching), Kavi explains, **no score recorded** (never
generous scoring from a partial view); combo preserved. Laughing in Statue Bazaar is the joke: partial credit, Freeze Fail clip, combo kept in party modes.
- Pose call: "Next up: Cutting Chai! Extra adrak, extra attitude."
- Lock: "Locked! Statue-level confidence."  · Perfect: "PATAKA! The whole mohalla heard that one."
- Near miss: "So close! The frame and you were *almost* in a relationship."
- Statue tease: "Don't laugh… don't laugh… a pigeon is looking at you…" / "Kavi is legally not allowed to tickle you. Yet."
- Tracking: "I've lost your knees, they've gone to Goa without you. Step back a little?" / "Too dark, yaar. A bit more light and we're back."
- Balance: "Holding the wall is pro strategy, not cheating."
- Pass: "Phone handover! Wipe the sweat, not the screen… actually, wipe the screen also."
- Teams: "Team Samosa leads! Team Jalebi, untangle yourselves."
- Rest: "Chill frame. Breathe like you just found parking in Bandra."
- Fox-specific additions: "My ears are up — so are your arms. Good." / "Even my tail can't hold this one. Respect."
Hindi/Gujarati versions by native writers (same rules §4.2); no regional stereotypes beyond affectionate city jokes, reviewed.

### 7.8 Progression & cosmetics
**Pose Album** (bronze/silver/gold per pose + personal-best %); **Mela Map** 6 stalls (Chai Stall, Kite Market, Lantern Lane,
Rangoli Gali, Dhol Corner, Rooftop Finale) × 5 rounds × 3 stars; skins (Kurta-Bot, Neon Stick, Lantern-Light, Cricket Kit
from D, Auto Driver), confetti (marigold, rangoli dust, kite strings), frame skins, **Kavi vest/scarf styles** (replaces
the dropped moustache cosmetic), victory stingers. Weekly **Pose of the Week** (aggregate scores only, opt-in leaderboard).
Streak: 1 round counts; Streak Freeze earned by play; ≤ 1 gentle reminder/day, switch-off-able, no guilt copy.

### 7.9 Social
"Pataka Reel": ring buffer of last ~6 s filtered landmarks (≈ 25 KB, RAM only) → 3 auto-picked moments (best perfect,
funniest Freeze Fail with "wobble cam", final pose) → 5–8 s 9:16 MP4 via `clip_encoder`, costume avatar + frame +
confetti + score, watermark **"Made with landmarks only — no camera video"**. Guest nickname shown only if they tick "show my name".

### 7.10 Festivals (`content/party/festivals/<id>.json`: playlist + skin + l10n keys)
| Festival | Twist | New poses/frames | Kavi look |
|---|---|---|---|
| Diwali | diya/rangoli-light frames, sparkle burst ("eco-pataka", no loud cracker SFX by default) | Lantern Hold, Sparkler Swirl (end-state) | marigold scarf |
| Holi | colour-burst frames; avatar splashed with your best pose's colour | Pichkari Aim (Archer variant), Colour Cloud Star | colour-splash vest |
| Makar Sankranti / Uttarayan | kite-cut frames, Patang Duel team mode | Kite Flyer, Manja Pull | kite-string wristbands |
| Navratri-style dance nights | freeze judged *after* the drum hit (wide windows) | Dandiya Freeze (no sticks) | mirror-work vest trim |
| Onam / Pongal | harvest frames, boat-race team sync | Oar Pull | leaf-green vest |
| Cricket season | stadium frames, "Commentator Kavi" cameo with Mithu | Six! (Lamp Post), Wicket Keeper (Kursi), Appeal | cricket cap (cosmetic, generic) |
| New Year / Sangeet season | "Sangeet Showdown" playlist | Baraat Shoulders, Selfie Stick | sequin vest |

### 7.11 Free / Premium
| Free | Premium (Joynetic Premium; festival packs as small IAP — owner decision §10) |
|---|---|
| 12 core poses (#1–5, 7, 8 LI, 11, 13, 14, 18, 25), 2 Mela Map stalls, Pass-the-Pataka ≤ 4 players, Pose of the Week, watermarked clips | all 24+ poses + festival drops, full Mela Map, 8-player party, Team Toli, Copy-Cat Chain, all skins, Duo Frame where supported |
No ads during play; LI variants, support cues and accessibility never paywalled; Play billing only.

### 7.12 Metrics
| Metric | Target |
|---|---|
| Install → round 1 finished | ≥ 70 % |
| Lock rate per frame (Mela band) | 80–90 % |
| Hover rate | < 5 % of frame time (per-pose breakdown) |
| "Felt unfair" thumbs-down | < 10 % |
| Party sessions (≥ 2 players) | ≥ 25 % of sessions; median ≥ 3 players |
| Clip share rate | ≥ 8 % of party sessions |
| D1 / D7 / D30 | 40 / 18 / 8 % |
| Rounds per session | ≥ 2.2 |
| Replay gate | per-pose lock recall ≥ 0.9; false lock on decoys ≤ 5 % |
| Perf | ≥ 15 fps budget (hard), ≥ 24 fps Duo Frame |
Telemetry opt-in aggregates + per-pose similarity histograms only; research recordings need separate consent.

### 7.13 Risks
| Risk | Sev | Mitigation |
|---|---|---|
| Matcher feels unfair (2-D ambiguity, sarees/dupattas hide knees) | High | angle-based generous tol, hover not fail, upper-body fallback, adaptive tol, diverse recorded clips before tuning |
| L/R confusion | Med | mirror display, `mirrorOk` on beginner, "screen-side" wording, explicit tests |
| Balance falls | High | Balance Lantern opt-in, toe tap default on Chai Break, wall/chair cue, no floor/jump poses, one-tap break, safety card |
| People walking behind | Med | largest/central body, glow-zone framing, hover on torso jump > 25 % |
| Minors at gatherings | Med | 18+ account holder + party-start 18+ confirmation, adult framing in all copy/store art, no child marketing, guests nickname-only, no guest data beyond session scores |
| Privacy ("filming my living room") | High | Avatar default, landmark-only clips + watermark, no frame storage, clear onboarding |
| Cultural missteps | Med | no deity imagery or ritual gestures as scored poses, festival review panel |
| Format similarity to TV wall shows / mirror games | Med | own mela setting, frame art, cast and sound; legal review of name/art |
| Medical-framing creep ("yoga for back pain") | High | copy review: "shapes", "play", "stretch-style"; playful names |
| Novelty drop | High | Pose Album, Mela Map, Pose of the Week, festival JSON drops, party reasons to return |

---

## 8. Shared tech

### 8.1 motion_core additions (pure Dart, **tests first**; no threshold change without replay pass)
| File (`packages/motion_core/lib/src/`) | What | Used by |
|---|---|---|
| `viewport_mapper.dart` | landmark → widget mapping for BoxFit.cover, rotation 0/90/270, mirror | all |
| `body_points.dart` | `handL/R` (3-point mean with vis fallbacks), `head` (nose / shoulder+0.9T), `hips`, knees; T and R from calibration | C, D |
| `zone_hit_tester.dart` | body-relative zones (`hi/side/low/crown/chest`), radius per difficulty, 2-frame dwell, early-hold flag, 85/90 % clamp | C, D (catch zones), E (`zone.wrist`) |
| `pose_features.dart` | shoulderAbd, elbowFlex, hipAbd, kneeFlex, torsoLean, wrist zones, footLift, stance — 2-D only | C (Rang Wall), E |
| `pose_matcher.dart` | similarity, must-caps, `mirrorOk`, unseen gating (> 30 % → hover), lock/hold hysteresis, 3-frame median, adaptive tol, freeze check | C, E |
| `cricket_recognisers.dart` | `SwingRecogniser` (roadmap §3.6), `BowlRecogniser` (§3.7), `CatchZoneRecogniser`, `OverheadReachRecogniser`, `LateralTouchRecogniser` | D |
| (from plan 1) `KneeLiftRecogniser`, `ClapRecogniser` rules, `BodyFeatures` | reuse; do not reimplement | C knee zones, D march, E footLift baseline |
| `quality_gate.dart` | new `upperBody` profile (legs ignored) | C seated, E Chai Break |
| `landmark_clip.dart` | RAM ring buffer of filtered landmarks (fixed capacity, Float32List, zero alloc per frame) | clips (all) |
Tests (`packages/motion_core/test/`): `viewport_mapper_test.dart`, `zone_hit_tester_test.dart`, `pose_matcher_test.dart`,
`cricket_recognisers_test.dart`; `SyntheticBody` gains `reach(zone)`, `pose(id)`, `swing`, `bowl(tempo)`, `catch(zone)`,
`overheadReach(side)`; each at 10/15/30 fps, noise σ 0.006–0.015, dropped frames, occlusion → `notVisible`, mirrored input.
Decoys: arms-up ≠ `hi-*` single; idle ≠ any zone; Goalpost ≠ Robot; Tree ≠ Knee Hug; raise ≠ bowl ≠ overheadReach ≠ catch-high;
barrier ≠ lateralTouch; swing with crossed wrists still one swing. Replay gate (`accuracy.dart`, `tools/recorder/`):
≥ 20 players × each move/zone/pose, 2 phones (1 budget), recall ≥ 0.9, false trigger ≤ 1 / 2 min idle, false lock ≤ 5 %.
Perf: all recognisers + matcher < 0.3 ms/frame in `perf_benchmark_test.dart`.

### 8.2 Engines (one engine, three rule packs — `packages/game_director/lib/src/`)
- **`BeatEngine`** (from plan 1 / `3-tech` §4.2; RunEngine contract `input`, `advance`, `setLight`, `List<RunEvent>`,
  `RunResult`; capture-ts − `latencyOffsetMs` judging; `TargetJudged{perfect,good,ok,miss,forgiven}`) gains two
  target kinds: **`zoneTarget`** (dwell in a zone inside a window) and **`holdTarget`** (similarity ≥ lock then hold for
  `holdMs` before `arriveMs`; hover pauses its clock). Music clock optional (`music` absent → wall clock).
- `rules/mirror_rules.dart` (C): combo, Mela Rush, shield pips, forgiveness, early-hold cap, grade S/A/B/C.
- `rules/match_rules.dart` (D): delivery → target; `match` state machine (balls, runs, wickets, innings, dead ball,
  run-between-wickets march counting, seeded `outcomes` table); Raid/Shuttle as small rule variants.
- `rules/party_rules.dart` (E): stars, combo ×1.5 cap, adaptive tol hooks, turn rotation (`PartySession`: players,
  frames per turn, team scores) — turn handling is game state, so engine stays deterministic.
- Directors (`director.dart`): `MirrorDirector.plan`, `MatchDirector.plan(seed)`, `PartyDirector.plan(playlist, settings, seed)` —
  all deterministic, config-driven; Daily Remix / Over of the Day / Pose of the Week seeds = IST date hash.

### 8.3 Schema additions (`content/schema/level.schema.json` v2 branch + new schemas; `npm run content:validate`)
v2 `mode` enum adds `"mirror" | "cricket" | "raid" | "shuttle" | "party"`; new encounter `type`s:
`zoneTarget, double, catchPlace, hazardBand, poseTile` (C), `delivery, catch, stop, raidTag, raidChain, shuttle` (D),
`poseFrame, statue, mirrorKavi, chain, balanceLantern, blink, chill` (E). New files: `content/schema/pose.schema.json`,
`character.schema.json`, `costume.schema.json`, `party_round.schema.json`, `festival.schema.json`.

Game C level (`content/levels/mirror/bazaar-01.json`):
```json
{
  "schemaVersion": 2, "id": "mirror-bazaar-01", "mode": "mirror", "subMode": "bazaar",
  "stall": "bubble-bazaar", "roundS": 75, "moves": ["zone", "squat", "lean"],
  "music": { "track": "mela_pulse_01", "bpm": 96, "offsetMs": 120, "beatsPerBar": 4 },
  "encounters": [
    { "atBeat": 8,  "type": "zoneTarget", "zone": "side-L", "hand": "any",  "minDifficulty": "beginner", "overhead": false },
    { "atBeat": 12, "type": "zoneTarget", "zone": "hi-R",   "hand": "right","minDifficulty": "beginner", "overhead": true },
    { "atBeat": 20, "type": "double",     "zone": "crown",                  "minDifficulty": "beginner", "overhead": true },
    { "atBeat": 28, "type": "catchPlace", "zone": "side-L", "dropZone": "low-R", "dropWithinMs": 1500, "minDifficulty": "intermediate" }
  ],
  "breather": { "fromS": 35, "toS": 45 }
}
```
Game D match (`content/levels/cricket/super-over-daily.json`):
```json
{
  "schemaVersion": 2, "id": "cricket-super-over", "mode": "cricket", "ground": "gully-lane",
  "moves": ["swing", "raiseArms", "barrierHold", "bowl", "sideStep", "catchZone", "squat", "march"],
  "match": { "format": "superOver", "balls": 6, "wicketsAllowed": 2, "bowlerSeed": "ist-date", "bowlInnings": true },
  "deliveries": { "pool": ["full-straight", "short-wide", "slower-full", "stumps-lit"], "minGapMs": 3000 },
  "outcomes": { "perfect.drive": { "4": 0.6, "2": 0.3, "1": 0.1 }, "perfect.lofted": { "6": 1.0 }, "ok.lofted": { "caught": 0.5, "1": 0.5 } },
  "caps": { "overheadPerMin": { "gentle": 4, "balanced": 6, "active": 8 }, "emptyAfterOverheadMs": 2000 }
}
```
Game E pose + round (`content/party/poses/cutting-chai.json`, `content/party/rounds/mela-01.json`):
```json
{ "id": "cutting-chai", "name": { "en": "Cutting Chai", "hi": "कटिंग चाय" }, "mirrorOk": true, "upperBodyOnly": true,
  "features": [
    { "f": "shoulderAbd.L", "target": 45,  "w": 1.0 }, { "f": "elbowFlex.L", "target": 90, "w": 1.0 },
    { "f": "zone.wristL", "target": "hip", "w": 1.5, "must": true }, { "f": "shoulderAbd.R", "target": 150, "w": 1.0 } ],
  "holdMs": { "beginner": 1500, "advanced": 2500 }, "lowImpact": "seated", "demanding": false, "safetyCue": "relax_shoulders" }
```
```json
{ "schemaVersion": 2, "id": "party-mela-01", "mode": "party", "stall": "chai-stall",
  "frames": [ { "type": "poseFrame", "pose": "star-burst" }, { "type": "poseFrame", "pose": "cutting-chai" },
              { "type": "chill" }, { "type": "statue", "pose": "thinking-statue", "darkMs": 4000 },
              { "type": "chain", "poses": ["coconut-tree", "warrior-wave", "star-burst"], "eachHoldMs": 1000, "minBand": "mirchi" },
              { "type": "poseFrame", "pose": "pataka" }, { "type": "chill" } ] }
```
Validator rules: C — per-hand spacing, overhead ≤ 6/30 s (≤ 3 in a row), no collect ≤ 1200 ms after a dodge, hazards ≥ 2.2 s and
only head/side bands, zones inside clamp, breather has no hazards/overhead. D — no ball+wicket within 3 s, 2 s empty after
overhead, overhead caps per band, outcome probabilities sum to 1, no banned names (title deny-list). E — demanding ≤ 2 in a
row, Chill every ≤ 6 frames, every pose has an LI variant, no excluded feature combos (floor/back-bend/knee < 100°), festival
ids resolve. All — `moves` covers every encounter; schemaVersion 1 levels stay valid unchanged.

### 8.4 Simulator / bots (`packages/game_director/lib/src/simulator.dart`, extends plan-1 `BotProfile`)
| Bot | Profile | Gate |
|---|---|---|
| `competent` | latency 150 ms, σ 60, 30 fps | ≥ 90 % Good-or-better every level × difficulty (C, D); ≥ 2 stars per frame on Mela band (E) |
| `slow` | 200 ms, σ 120, 15 fps | ≥ 60 % non-miss beginner (C); chase win ≥ 55 % Gentle (D); every round completable on Chai Break (E) |
| `dropout` | random 1–3 s tracking loss | 0 combo breaks from forgiven targets; 0 wickets/runs lost on dead balls; 0 frames scored while hovering |
| `oneArm`, `seated` | upper-body only | 100 % of their targets reachable (C, E Chai Break) |
| `wobbly` (E) | similarity noise ±8 | lock rate 80–90 % on Mela band |
| `camper` (C) | arms parked overhead | never above Good on any target |

### 8.5 Painters & app (`app/lib/game/`)
`MotionGame` (plan 1) picks by `level.mode`: `mirror_painter.dart` (stall scenery, objects, approach rings, Orbit clock),
`pitch_painter.dart` (gully lane perspective strip behind the avatar, ball trail, fielders, scoreboard plate),
`party_painter.dart` (approaching frame scaling from horizon, confetti). Shared: `avatar/avatar_painter.dart` (cut-out rig
from landmarks — also used offscreen by the clip renderer), `avatar/costume_layer.dart`, `hud/*` (§3.3), `self_view_layer.dart`.
Perf discipline as `ForestPainter`: cached Paints via Expando per theme, static scratch Paths, binary search visible targets by
`arriveMs`, HUD reassigned only on change. Clip renderer: `app/lib/share/clip_renderer.dart` → `native/clip_encoder`.

### 8.6 Tests (beyond motion_core)
- `game_director/test/beat_engine_zone_test.dart`, `match_rules_test.dart`, `party_rules_test.dart`, `directors_determinism_test.dart` (same seed → identical plan).
- `server` content tests for every validator rule (one failing fixture per rule).
- `app/test/self_view_controller_test.dart` (FLAG_SECURE on/off by mode + visibility; lifecycle stop), `hud_plate_golden_test.dart`
  over 4 backgrounds (white wall, busy fabric, dark room, bright window), `contrast_tokens_test.dart` (WCAG ≥ 4.5:1 / 3:1 / 7:1 HC),
  `clip_scene_test.dart` (no `Texture` in clip tree), `perf_test.dart` extended to 3 new painters × themes × 600 frames.
- Native: use-case-set unit test; CI grep bans (§2.7); instrumentation test for recents screenshot disable.

---

## 9. Build plan M0–M6

| Milestone | Scope | Acceptance criteria |
|---|---|---|
| **M0 — Self-view foundation** (≈ 2 wk) | `SelfView.kt` (Preview → SurfaceProducer), shared ViewPort + cropRect crop, Dart `SelfViewHandle`/`SelfViewLayer`/`SelfViewController`, `ViewportMapper`, modes Avatar/Mirror (Silhouette = capsule fallback), FLAG_SECURE + recents, CI bans, thermal ladder skeleton, `architecture.md`/`security.md` rows | Landmark overlay aligned within ≤ 2 % of frame width on 2 devices (budget + upper-mid) at rotation 0; Avatar mode verified to bind **no** Preview; screenshot in Mirror shows black camera layer; `dart analyze`/`flutter analyze`/tests green; CI grep job fails on a planted `ImageCapture` import; preview 30 fps + pose ≥ 15 fps on budget phone |
| **M1 — Avatar + Lantern Pulse + Bubble Bazaar slice** (≈ 3 wk) | `LanternPulse` tokens, `HudTheme`, `HudPlate`, `StrokedText`, `ApproachRing`, `TargetZone`, `TrackingOverlay`; placeholder avatar rig; `body_points`, `zone_hit_tester` (tests first); BeatEngine `zoneTarget` + `mirror_rules`; `mirror_painter`; 1 Bubble Bazaar beginner level (1 stall); shared onboarding; schema v2 `mode: mirror` + validator rules | Playable 75 s round end-to-end on budget phone in Avatar and Mirror; zone recall ≥ 0.9 on ≥ 10-player pilot recordings; idle false pops ≤ 1 / 2 min; `competent`/`slow`/`dropout`/`camper` bots pass; painter ≤ 6 ms; contrast + golden tests pass; tracking loss never breaks combo |
| **M2 — Mirror Mela complete + clips** (≈ 3 wk) | Orbit (Baadal hazards), `pose_features` + `pose_matcher` (tests first) → Rang Wall, full session structure, Mela Tickets, 6 stalls, Daily Remix, `landmark_clip` + `clip_renderer` + `native/clip_encoder`, upper-body gate (seated), pass-and-play | All §5.13 replay/perf gates; clip MP4 15 s ≤ 4 MB with no Texture in scene (test); seeded Daily Remix identical across 2 devices; seated bot 100 %; session completion ≥ 70 % in internal beta |
| **M3 — Pataka Pose MVP** (≈ 3 wk) | `holdTarget` + `party_rules`, `PartyDirector`, `party_painter`, 12 MVP poses + Chill + Statue Bazaar, Chai Break + Mela bands, Pass-the-Pataka 2–4, Pataka Reel (stick-glow skin), Diwali festival JSON, Kavi host lines en/hi | Per-pose lock recall ≥ 0.9, decoy false lock ≤ 5 %; hover < 5 % frame time in pilot; mirrored-input tests pass; every round completable by `slow` on Chai Break; 18+ party gate present; festival shipped as content only (no code change) |
| **M4 — Tapeball Tamasha core** (≈ 4 wk) | `SwingRecogniser`, `BowlRecogniser`, `CatchZoneRecogniser` (tests + replay first), `match_rules`, `MatchDirector`, `pitch_painter`, mandatory space check, Nets + Super Over + Bowl-Out + Fielding Drill, Mithu commentary text + chirps (en) | Swing/bowl recall ≥ 0.9, idle false ≤ 1 / 2 min on ≥ 20 players × 2 phones; dead-ball rate < 5 %; seeded Super Over identical across devices; Gentle `slow` bot wins chase ≥ 55 %; space-check failure path offers only Nets/Raid; banned-name validator active |
| **M5 — Sports hub + social** (≈ 3 wk) | `LateralTouch`, `OverheadReach` → Raid Rush + Shuttle Rally; Chase + Gully Match; Crew Cup (server `gyms`/`progress`/`reports`: seeded attempts, caps, band divisions, plausibility checks, dashboard); E Team Toli, Copy-Cat Chain, Mirror Kavi, Sequence Chain, Pose Album | Server lint/typecheck/tests green; plausibility checks reject synthetic impossible-timing fixtures; ≤ 3 counted attempts/day enforced server-side; no landmarks in any upload payload (test); overhead-family collision tests pass |
| **M6 — Characters, festivals, polish, launch** (≈ 4 wk, art from wk 1) | final cast rigs + avatar kit + 18 costumes; Kavi festival vests; hi/gu barks (+ optional VO packs); Silhouette segmentation tier (bench-gated, ≤ 15 Hz, GL shader, studio backdrop); festival packs for all 3 games; Duo Frame experiment (fps-gated, behind flag); store listing review (no medical/weight claims, no league names) | Base install delta ≤ 9 MB, texture RAM ≤ 12 MB, character layer ≤ 2 ms; seg tier holds 30 fps preview with pose ≥ 15 fps or auto-disables; sensitivity sign-off (hi, gu, inclusion); trademark search done for all 3 names; `docs/progress.md`, `game-design.md` thresholds, `architecture.md`, `security.md` updated |

Each milestone ends per AGENTS.md: lint clean, tests passing, `docs/progress.md` updated, short "what changed / how to verify".

---

## 10. Owner decisions / open questions

| # | Question | Recommendation |
|---|---|---|
| 1 | Is Kavi a **Bengal fox** character or a human coach with a fox-orange brand colour? | Fox (this plan assumes it everywhere, incl. Pataka Pose host) |
| 2 | Kavi's **Hindi grammatical gender**: keep masculine ("दूँगा", current strings), switch, or offer a Kavi-voice setting? | Keep one fixed voice for v1 (cheaper review), player addressed gender-neutrally; revisit with VO casting |
| 3 | **Rive** for an interactive Kavi portrait if the per-ABI size delta is ≤ 3 MB? | Stay deps-free (cut-out rigs); measure Rive in a spike only if portraits feel flat |
| 4 | **Sports/inclusion headwear** (sports hijab, patka) as player-chosen avatar options (never costumes/unlockables/NPCs)? | Yes, with cultural reviewers' sign-off |
| 5 | **Trademark / Play Store search** for "Mirror Mela", "Tapeball Tamasha", "Pataka Pose" (backups: Backyard Boundary, Gully Games Night, Freeze Bazaar) | Run before any art with the name; legal review of cricket commentary script and icons |
| 6 | **Default self-view mode**: Avatar (this plan) vs Mirror (Game C draft)? | Avatar default; track Avatar vs Mirror usage and revisit after beta |
| 7 | **Pricing**: drafts proposed ₹99/₹699, ₹129/₹699, ₹79–99/₹499–599. One Joynetic Premium price? Festival packs as separate IAP (₹19–49)? Lifetime IAP? | One Premium price for all games (per `docs/stages-roadmap.md` §7); decide festival IAP after A/B |
| 8 | **VO** scope: chirps + text at launch vs full en/hi/gu VO for Kavi + Mithu (~1.5–2.5 MB per language, on-demand)? Male/female commentator voices for D? | Chirps + text at M3/M4; VO packs at M6 if budget allows |
| 9 | **Party guests**: nickname-only guests with an 18+ confirmation at party start — acceptable, or require each guest to confirm? | Party-start confirmation by account holder + adult-only copy and store art |
| 10 | **Silhouette** on non-segmentation phones: ship landmark-capsule silhouette, or hide the option? | Ship capsule fallback (same privacy, every tier) |
| 11 | **Music**: 3 original tracks (one per game) in install vs on-demand download? | First track in install, rest on-demand via `/content` |
| 12 | **Duo Frame** (`numPoses=2`, multi-pose payload) — invest post-launch? | Only if party share ≥ 25 % and ≥ 30 % of devices pass the 24 fps pre-check |
| 13 | Cricket **season events** naming and timing (Summer Cricket Fest mid-March → early June) | Approve generic names; no pushes tied to real matches |
| 14 | Where does the **Sports hub** live in navigation (new tab vs inside Quest)? | New "Play" tab with three tiles (Mirror Mela, Tapeball Tamasha, Pataka Pose) |

---

## 11. Sources (from the research notes)
Self-view tech: [Flutter Android surface plugins](https://docs.flutter.dev/release/breaking-changes/android-surface-plugins) ·
[FlutterRenderer javadoc](https://api.flutter.dev/javadoc/io/flutter/embedding/engine/renderer/FlutterRenderer.html) ·
[KINTO Tech blog](https://blog.kinto-technologies.com/posts/2024-12-17-flutter-platform-view-android/), [techplay](https://techplay.jp/blog/24844) ·
[CameraX Preview.SurfaceProvider](https://developer.android.com/reference/androidx/camera/core/Preview.SurfaceProvider) ·
[CameraX Preview / setMirrorMode](https://developer.android.com/reference/androidx/camera/core/Preview.html) ·
[CameraX package summary (ViewPort, UseCaseGroup)](https://developer.android.com/reference/androidx/camera/core/package-summary) ·
[MediaPipe Image Segmenter](https://ai.google.dev/mediapipe/solutions/vision/image_segmenter), [mirror](https://developers.google.com/edge/mediapipe/solutions/vision/image_segmenter) ·
[ADPF Thermal](https://developer.android.com/games/optimize/adpf/thermal) · [OWASP MASTG-BEST-0014](https://mas.owasp.org/MASTG/best-practices/MASTG-BEST-0014/) ·
[SurfaceView.setSecure](https://learn.microsoft.com/de-de/dotnet/api/android.views.surfaceview.setsecure?view=net-android-37.0), [BytePlus](https://docs.byteplus.com/vi/docs/byteplus-vos/docs-anti-screen-recording) ·
[Android 13 recents screenshot](https://www.xda-developers.com/android-13-developers-disable-app-previews/).
Camera limits: [arXiv 2512.06783](https://arxiv.org/pdf/2512.06783) · [BlazePose GHUM](https://arxiv.org/pdf/2206.11678.pdf) ·
[Monocular 3D pose reliability](https://thesai.org/Downloads/Volume17No10/Paper_65-Accuracy_and_Reliability_of_Monocular_3D_Pose.pdf) · [Telerehab feasibility](https://ouci.dntb.gov.ua/works/40ZpzPp9).
UI: [pixune](https://pixune.com/blog/best-examples-mobile-game-ui-design/) · [appfollow](https://appfollow.io/blog/mobile-gaming-trends-2026) ·
[ejaw](https://ejaw.net/how-mobile-game-ux-interface-design-drives-player-retention-in-2026) · [adrydapp](https://adrydapp.blogspot.com/2026/03/mobile-game-ui-design-trends-2026-guide.html) ·
[barrettmedia](https://barrettmedia.com/2026/01/21/graphic-design-for-video-games-trends-players-notice-in-2026/) · [line25](https://line25.com/articles/web-design-trends-2026/) ·
[theedigital](https://www.theedigital.com/blog/web-design-trend) · [studiomeyer](https://studiomeyer.io/en/blog/webdesign-trends-2026) ·
[M3 Expressive](https://developer.android.com/design/ui/wear/guides/get-started/design-language) · [Xbox XAG](https://learn.microsoft.com/en-us/gaming/accessibility/guidelines) ·
[gameaccessibilityguidelines](https://gameaccessibilityguidelines.com/?p=12) · [Unity accessibility](https://unity.com/blog/video-game-accessibility-basics) ·
[Asian Paints ColourNext 2025](https://www.beautifulhomes.asianpaints.com/magazine/decor-advice/trends/this-asian-paints-colournext-story-is-about-india-everywhere) ·
[Cosmopolitan India](https://www.cosmopolitan.in/life/features/story/asian-paints-colournext-2025-the-design-trends-that-will-define-this-year-1177034-2025-03-06) · [designpataki](https://www.designpataki.com/?p=45875) ·
[Gabbard 2007](https://ed-swan.github.io/publications/papers/2007_Gabbard-etal_Text-Drawing-Styles_IEEE-VR.pdf) · [PubMed 32425139](https://pubmed.ncbi.nlm.nih.gov/32425139/) ·
[Google Fonts AR/VR type](https://fonts.google.com/knowledge/using_type_in_ar_and_vr/introducing_ar_vr) · [Brown VR wiki](https://www.vrwiki.cs.brown.edu/applications-of-vr/reading-in-vr/reading-in-ar) ·
[uxdesign AR athletes](https://uxdesign.cc/re-designing-a-mobile-ar-experience-for-athletes-a-ux-case-study-11b1be491166) ·
[Fire TV UX](https://developer.amazon.com/docs/fire-tv/design-and-user-experience-guidelines.html) · [10-foot UI](https://en.wikipedia.com/wiki/10-foot_user_interface) · [Designing a 10ft UI](https://pascalpotvin.medium.com/designing-a-10ft-ui-ae2ca0da08b7).
Characters: [Faric et al. 2021](https://discovery.ucl.ac.uk/id/eprint/10139156/) · [NCT02341235 protocol](https://cdn.clinicaltrials.gov/large-docs/35/NCT02341235/Prot_SAP_000.pdf) ·
[Lyons/UTMB](https://chairsearches.utmb.edu/newsroom/article8962.aspx) · [Ring Fit review](https://news.yahoo.com/ring-fit-adventure-review-nintendo-113006617.html) · [CEEOL analysis](https://ceeol.com/search/article-detail?id=1009100) ·
[desirabilitylab (weak)](https://desirabilitylab.com/backfill/backfill-2025-46-duolingo-streak-design) · [IIMU mojo (weak)](https://mojo.iimu.ac.in/2026/meet-the-loveable-language-learners-unlocking-the-secret-to-duolingos-success.html) ·
[flame_texturepacker](https://pub.dev/documentation/flame_texturepacker/latest/) · [atlas RAM](https://forum.unity.com/threads/sprite-atlas-etc2-fallback.723944/) ·
[flame_rive](https://pub-web-s1.flutter-io.cn/packages/flame_rive) · [Rive APK bloat report](https://itnext.io/how-i-drastically-reduced-my-flutter-app-size-by-80mb-with-just-one-line-of-code-967ba19cef98) ·
[Rive runtime sizes](https://rive.app/docs/runtimes/runtime-sizes.md) · [Rive vs Lottie](https://rive.app/blog/rive-as-a-lottie-alternative) · [tillitsdone](https://www.tillitsdone.com/blogs/rive-vs-lottie--flutter-animations) ·
[flame_spine](https://pub.dev/packages/flame_spine/versions/0.4.0-dev.0+7/install) · [spine-flutter](https://www.esotericsoftware.com/spine-flutter).
