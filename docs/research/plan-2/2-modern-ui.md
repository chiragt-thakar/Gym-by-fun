# 2 — Modern UI / visual language for three self-view games (MotionQuest)

Scope: 2025–2026 trend scan (cited) and an original visual language ("Lantern Pulse") for the
self-view games, where the live front-camera image is the background. It extends the existing
"Forest Lantern" theme (`app/lib/app/theme.dart`) and does not replace it.
Context checked: theme.dart tokens; `docs/screenshots/10-game-forest-escape.png`, which shows a
portrait 1080x2280 flat-vector runner, a warm sky gradient, a fox-orange hero with a teal scarf,
and chunky shapes.

Caveat: most 2026 "trend" sources are agency blogs. Treat them as directional only. The
legibility and accessibility guidance comes from research and platform guidelines, and is firmer.

---

## 1. Trend scan (2025–2026)

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

## 2. Colour system: "Lantern Pulse" (an extension of Forest Lantern)

Principle: keep Forest Lantern for the shell (menus, map, results). Add a **camera-overlay
palette** that only ever sits on a **plate** (a solid or tinted backing) or carries a **dark
outline**, because the camera image behind it can be any colour.

### 2a. Kept as-is (do not change; existing widgets depend on them)
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

### 2b. New overlay tokens (proposed `LanternPulse` class, additive)
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

### 2c. Per-game accent pairs (each game gets one hero accent plus the shared neutrals)
Keep `glow` as the brand constant. Each game swaps only the **accent** and **gradient**.
| Game slot | Accent A | Accent B | Gradient (for title cards / celebration only, never behind live text without a plate) |
|---|---|---|---|
| Game 1 (warm, rhythm/combo) | `#FFB627` marigold | `#FF4D6D` kumkum | `#FF9A3C → #FF4D6D` |
| Game 2 (cool, precision/zone) | `#00C2B8` peacock | `#3FD0C0` scarf | `#0F3E39 → #00C2B8` |
| Game 3 (night, arcade/neon-ish) | `#B98CFF` lilac | `#9BCB3C` mehendi | `#2B2F77 → #B98CFF` |

Colourblind safety: do not pair kumkum and mehendi as the only "bad/good" distinction. Good is
always tick plus upward motion. Miss is a soft grey ring plus a sideways nudge.

---

## 3. Type scale for 2 m readability

### 3a. Maths
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

## 4. HUD layouts over the live camera view

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

## 5. Motion principles (budget-phone safe)

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

## 6. Iconography

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

## 7. Celebration and feedback effects

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

## 8. Onboarding for self-view

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

## 9. Do / Don't

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

## 10. Evolving Forest Lantern without breaking it

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

## Sources
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
