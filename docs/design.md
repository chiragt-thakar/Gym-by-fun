# Joynetic design

The design system, and what shows when. Tokens live in
`app/lib/app/theme.dart`; shared components in `app/lib/widgets/`.

## Who it is for

Adults 18–35 who sit most of the day and want something fun to do for 3–15
minutes at home. They are not gym people and do not want to be told they should
be. They will pay for something that feels made with care and that they can
trust with a camera pointed at their living room.

Three consequences shape everything:

1. **Trust before delight.** The camera is the scary part. The app says what it
   does with it, plainly, before asking — and then shows it (the stick figure
   the tracker actually sees is always available).
2. **Two reading distances.** In the hand (menus, results) and two metres away
   (set-up, calibration, play, pause). Stage screens use one big line, at most
   two; nothing needs a tap from across the room.
3. **A game, never a prescription.** No medical or weight-loss claims, no
   calories, no guilt. Copy is warm, short and specific.

## Principles

- **One action per screen.** Exactly one volt button. Everything else is quiet.
- **Aqua means "I see you".** It is used for tracking, success and privacy —
  nothing else. Volt is for the thing to do next. Amber warns; coral is an error.
- **Colour is never the only signal.** Every state also has an icon, a shape or
  words (the tracking dot is a circle / triangle / square).
- **Nothing is ever lost.** A tracking loss, a pause, a backgrounded app, a
  failed camera: the game waits and says so.
- **Say it once, in the player's direction.** "Move a little to your left", not
  "subject out of frame".
- **Calm motion.** Things move to explain a change, once. Nothing loops in the
  shell. Reduced-motion is honoured.

## Tokens — "Ink & Volt"

| Token | Value | Use |
|---|---|---|
| `Jn.ink` | `#0A0C10` | Page background |
| `Jn.panel` | `#12151B` | Cards, sheets, the tab bar |
| `Jn.inset` | `#161A21` | Cards inside panels, secondary buttons |
| `Jn.raised` | `#1A1E26` | Inputs, pressed surfaces |
| `Jn.line` | `#242A35` | Hairlines |
| `Jn.edge` | `#343C4A` | Stronger borders |
| `Jn.scrim` | `#05070A` 90 % | Over the game or the camera |
| `Jn.volt` | `#C8F542` | The primary action; brand |
| `Jn.voltDeep` | `#A6D62B` | Pressed primary |
| `Jn.onVolt` | `#0E1200` | Text on volt |
| `Jn.aqua` | `#5EE6D0` | Tracking, success, privacy, links |
| `Jn.text` | `#F3F5F7` | Text |
| `Jn.textDim` | `#AEB6C2` | Secondary text |
| `Jn.textFaint` | `#7C8594` | Captions |
| `Jn.warning` | `#FFC857` | Warnings |
| `Jn.danger` | `#FF6B5A` | Errors, lost tracking |

Text on `ink` / `panel`: `text` 17:1, `textDim` 9:1, `textFaint` 5:1 (captions
only). `onVolt` on `volt` 15:1. The older `Lantern.*` names are aliases of these
tokens, so screens written before the redesign use the same palette.

Game worlds keep their own art palettes (forest, desert, neon, mountain, the six
arcade games); the shell around them is always Ink & Volt.

### Type

System font (Roboto on Android) — no font download, instant start.

| Scale | Style | Size / weight |
|---|---|---|
| Hand | `displaySmall` | 34 / 900, tracking −1.1 |
| | `headlineMedium` | 26 / 800 |
| | `titleLarge` | 20 / 800 |
| | `bodyLarge` / `bodyMedium` | 16 / 15, line height 1.5 |
| | `Txt.caption`, `Txt.overline` | 13 / 12 (overline: 800, tracked, aqua) |
| | `Txt.numeral` | 26 / 800, tabular figures |
| Stage | `Txt.stage` | 28 / 800 — the one line read from 2 m |
| | `Txt.stageSub` | 20 |
| | `Txt.stageNumeral` | 96 / 900, tabular — countdowns |

### Space, shape, motion

- Spacing: 4 · 8 · 12 · 16 · 24 · 32; page gutter 20 (`Space`).
- Radius: controls 16, cards 24, buttons and chips fully round.
- Touch targets: 56 px tall buttons, 48 px minimum anywhere.
- No shadows, no blur (cheap on budget phones; flat reads better at distance).
- Motion (`Motion`): `quick` 120 ms (press), `standard` 250 ms (state change),
  `slow` 380 ms (the frame finder growing); curves `easeOutCubic`, and
  `easeOutBack` for a success pop. Page changes fade forward.

### Components

| Component | File | Notes |
|---|---|---|
| `BigButton` / `QuestButton` | `quest_button.dart` | Volt pill (primary) or outlined pill (secondary); scales to 0.97 while pressed. |
| `AppCard`, `LanternCard` | `ui_kit.dart`, `lantern_card.dart` | Panel with a hairline; tones: plain, volt, aqua, warning. |
| `SectionHeader`, `NavRow`, `MetaPill`, `StatTile`, `StarRow`, `TagBadge` | `ui_kit.dart` | Shell building blocks. |
| `JoyneticMark` | `brand.dart` | The mark: a volt tile with a body in motion. Drawn, not an image. |
| `TrustPoint`, `CameraTrustPanel` | `brand.dart` | The privacy promises, wherever trust is asked for. |
| `StateView` | `brand.dart` | Error and empty states: icon, headline, help, actions. |
| `StepProgress` | `step_progress.dart` | Onboarding trail. |
| `FrameView`, `FramingCue`, `ScreenEdgeGlow` | `frame_view.dart` | What the camera sees: mirror or avatar, skeleton, edge glows, direction cue. |
| `TrackingDot` | `common.dart` | Green circle / amber triangle / red square. |
| `TrackingDiagnostics` | `tracking_overlay.dart` | The diagnostics overlay. |
| `ForestBackdrop` | `forest_backdrop.dart` | The shell backdrop: ink, two soft glows, a few motion arcs. Static. |

### Sound and haptics

| Moment | Sound | Haptic | Voice |
|---|---|---|---|
| Calibration step done | — | medium | the next instruction |
| Calibration finished | — | medium | — |
| Encounter cue / cleared / hit | `cue_*`, `clear`, `hit` | — | hint on first sight |
| Tracking lost | `tracking` | medium | one direction ("Step back") |
| Tracking found | — | medium | — |
| Countdown | `a_count`, then `a_bell` | — | "Three, two, one" |
| Checkpoint | `checkpoint` | — | — |

Haptics can be turned off (Settings → Tracking → Vibration cues). Voice is how
the app talks at two metres; every spoken line is also on screen.

## Screen map

```
first launch ─▶ Welcome ─▶ 18+ ─▶ Readiness ─▶ Sign in (skippable) ─▶ Home
                                                                       │
        ┌────────────── tabs: Home · Games · Progress · Profile ◀──────┘
        │
   tap Play ── no body profile? ─▶ Get ready ─▶ Set up space ─▶ Calibrate ─┐
        │                                                                  │
        └──────────────── has profile ─────────────────────────────────────┤
                                                                           ▼
                        warm-up ─▶ PLAY ─▶ cool-down ─▶ Results ─▶ Home / next
                                    │
                    pause · tracking lost · checkpoint · camera stopped
```

| Screen | Route | Shows when | Purpose and key elements |
|---|---|---|---|
| **Welcome** | `/welcome` | First launch (age not confirmed) | Mark, name, "Your body is the controller.", three promises (3–15 minutes · camera stays on this phone · a game, not medical advice), language chips, Continue. |
| **18+** | `/age` | After Welcome | Adults only; the not-medical line. Under 18 ends here, kindly. |
| **Readiness** | `/readiness` | After 18+ | Five yes/no health questions, never stored. Any "yes" advises a doctor and keeps low-impact on. |
| **Sign in** | `/sign-in` | After Readiness; from Profile | Optional. Explains what an account adds (backup, gym crew). |
| **Home** | `/home` | Default | The next adventure card, time estimate, this week, keepsakes, chapter maps. A gentle prompt if there is no body profile yet. |
| **Games** | `/games`, `/game/:id` | Tab | The arcade library; a game page with stages, bests, what it works. |
| **Progress** | `/progress` | Tab | Activity calendar, minutes and moves, bests. Empty state: "Your first session will show up here." |
| **Profile** | `/profile` | Tab | Player, body and space, settings, gym crew, the privacy line. |
| **Get ready** | `/get-ready?next=` | Tapping Play without a body profile | Why calibration exists, the three steps and how long, hands-free note, privacy line. Start / Not now. |
| **Set up space** | `/setup?next=` | From Get ready; Profile → placement guide | **The camera permission moment.** "Your camera is the controller", the camera trust panel (processed on this phone · never recorded · only 33 body points), placement guide, then *Allow camera and start*. After permission: a live frame with the outline, spoken directions, and an automatic countdown when framed. A view cut off only at the feet is accepted after a longer steady wait. Denied → what to do in Android Settings. |
| **Calibrate** | `/calibrate?next=`, `?quick=1` | After set-up; Settings → Recalibrate / Quick re-check | Step trail, one big instruction, the live frame, a progress ring. Hands-free: steps advance by themselves; a step that cannot be done uses a gentle default after 20 s. Live fixes ("It is a little dark…"). A poor result explains what to fix and tries once more by itself; *Use this result anyway* is always there. |
| **Warm-up / cool-down** | inside `/quest` | Before and after a runner stage | One exercise, a big countdown, Skip. |
| **Play — runner** | `/quest?level=`, `/tutorial` | A stage | HUD: hearts, energy, score, progress, mission; tracking dot; pause. A small picture-in-picture of what the camera sees. |
| **Play — arcade** | `/play/:game?stage=` | An arcade game | Framing card → 3-2-1 → play. Score plate, tracking dot, one caption line. |
| **Pause** | overlay | Pause button, back, app backgrounded | "Paused". Hands-free resume: raise your arms and hold, lower them, 3-2-1. Resume / Quit buttons for someone at the phone. Backgrounding always stops the camera. |
| **Tracking lost** | overlay | `TrackingState.lost` | The game dims, the frame grows to the middle with red edges where the body is cut off, one direction in stage type, "The game waits for you." It shrinks back by itself when the player is seen steadily again. No tap. |
| **Partial view** | — | `TrackingState.degraded` | Nothing blocks play. The screen edge glows amber only when drifting out sideways. |
| **Checkpoint** | overlay | Out of hearts past a checkpoint | Continue from checkpoint (hands-free confirm) / Finish run. |
| **Camera stopped** | error state | No frames and three restarts failed, or the camera could not start | `StateView`: what happened, "Nothing is lost. Your run is waiting for you.", Retry / Quit. |
| **Locked stage** | error state | A direct link to a locked stage | Says so; Back. |
| **Results** | `/results`, `/arcade-results` | After a run | What happened, stars, the coach's one tip, next. No calories, no judgement. |
| **Settings** | `/settings` | Profile | Play, explorer, **Tracking** (body profile and its quality, players, quick re-check, recalibrate, others-in-the-room lock, vibration, diagnostics overlay), Privacy (the trust panel, consents, export, delete), About. |
| **Gym crew** | `/crew` | Profile, gym QR link | Join with a code, the crew board. |
| **Diagnostics** | `/debug` | Profile → Developer tools | The full diagnostics panel and an event log. |
| **Recorder** | `/recorder` | Settings → Developer | Landmark recordings for the accuracy corpus (with consent; never video). |

### States every screen handles

- **Loading**: a quiet spinner on ink; never a blank white flash.
- **Empty**: one sentence saying what will appear and how to make it appear.
- **Error**: `StateView` — what happened in plain words, that nothing is lost,
  one way forward.
- **Offline**: the game is fully playable; sessions queue and sync later
  ("Saved on this phone").

### Navigation rules

- Four tabs. Back on a non-Home tab goes Home; on Home, twice to exit.
- Full-screen flows (onboarding, set-up, calibration, play, results) sit above
  the tabs and always have a way out that never loses a run silently.
- A deep page opened directly gets a back that goes Home, never out of the app.
- Play is gated only by the body profile; browsing never needs the camera.

## Copy

- Second person, present tense, no exclamation marks unless something good
  just happened.
- Directions are the player's own: "your left".
- Never: burn, calories, weight, fix, problem areas, should.
- Privacy copy is factual and checkable: *"The camera is read on this phone,
  live. Nothing is recorded or sent anywhere. The game sees 33 body points,
  not you."*
- New strings added in this redesign are English first; Hindi and Gujarati fall
  back to English until translated (`l10n/tr.dart`).
