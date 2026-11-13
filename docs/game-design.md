# Game design: rules and thresholds

## Gameplay, explorers and live body guide (2026-11-09)

The runner now has seven authored scene profiles: forest, river, ruins, desert,
neon rooftops, mountain bridges and festival streets. These are visual and
objective variants of the existing runner, not seven separate game engines.
River stages put the explorer on a raft; ruins use broken columns; neon stages
have a window-lit skyline and lane rails; mountain stages have peaks, snowy
pines and bridge boards. Rain, fireflies, sand, stars, snow or petals are chosen
by level data. Reduced-motion mode freezes decorative weather, scarf flutter
and companion orbit; required movement/game-state feedback remains visible.

### Optional missions and replay stars

Every current level contains schema-validated `gameplay` metadata:
`scene`, `atmosphere`, `mission` and `targetFraction` (0.25..1). Current authored
targets use 0.6. Immutable content versions were incremented to 3, and bundled
copies match canonical content. Levels without this optional metadata still
load with their previous game rules and no mission UI.

- **Gather the lights:** clear orb encounters in the correct lane with a reach.
- **Awaken the beacons:** answer gate encounters with a reach at the right time.
- **Clear the trail:** clear damaging encounters with the appropriate move/lane.

The target is `ceil(eligible planned encounters * targetFraction)`, calculated
after the director selects that difficulty's actual encounters. Server/Dart
validation also requires at least one beginner-level opportunity. A raw move
never counts; only resolved matching encounters count, once per plan index.
Mission progress survives a checkpoint retry without counting its encounters
again. If an unresolved opportunity is forgiven because of tracking, it is
removed from the target denominator. It awards no invented clear or points.
All-forgiven opportunities produce a protected neutral state, not a free star.
Earned mission completion never regresses. Existing scoring, hearts, pacing,
unlock order and movement thresholds are unchanged.

The destination ring fills with mission progress, and Jugnu, a small original
firefly companion, accompanies earned progress. A mission star is saved in
`Settings.missionLevels` only when a non-tutorial stage is completed with its
mission achieved. Stars are cosmetic, appear on the world map, have no payment
requirement and never gate stage progress. Existing stage completions remain
valid; replaying for a star is optional.

### Three original explorers

Settings -> Your explorer offers **Kavi the fox**, **Neela the otter**, and
**Tara the starbot**. They share identical rules and recognition; this is an
explicit cosmetic choice, never inferred from the player. The actual game art
is reused for the selection preview. Bent limbs, capes/scarves, boots and
recogniser-driven easing make ducking, reaching and lane changes readable.
No character has a recognition or scoring advantage.

### Body guide and readable cues

The native camera mirror retains a high-contrast skeleton with outlined limbs,
joint centres and amber low-confidence segments. With the mirror off, the same
real visible landmarks draw a capsule-limb body avatar with a torso and neutral
visor. No segmentation or camera pixels enter Dart. Invisible/non-finite joints
are omitted rather than invented; the standing outline is only a framing target.
Display visibility cutoffs (0.4 to draw; below 0.65 highlighted amber) do not alter
the quality gate or any movement recogniser. The guide stays available under the
HUD during play, and still expands for framing recovery.

The mission and body guide occupy the header, leaving the approaching obstacles
and explorer visible. Visual cues use short localised actions (duck, find a free
lane, reach, open) and short segment labels rather than paragraphs at 2 m.
Existing authored hints remain available to the voice path. The warm-up/cool-down
layout now scrolls when a small phone or large text cannot fit the full exercise.

The rendering previews in `docs/screenshots/gameplay-*.png` are produced by
opt-in tests with authored scenes and synthetic landmark fixtures. They contain
no camera image and are not evidence of physical movement accuracy or real-phone
frame rate. Those still need a consenting person in front of the camera.

## Adventure experience update (2026-11-09)

Product focus: a welcoming, private adventure that makes it easy to start,
understand a successful move, and come back. Competitive retention is a
hypothesis, not a measured result of this update.

### Research and decisions

- [FitXR: Your Journey](https://fitxr.com/blogs/fitxr-platform/new-your-journey-workouts-built-around-you)
  describes a curated path based on preferences and previous classes. Our
  interpretation: recommend a clear next chapter instead of making the player
  browse a large catalogue. Joynetic keeps its deterministic unlock chain;
  this update does not introduce a learned recommendation model.
- [Nintendo: Ring Fit game modes](https://www.nintendo.com/en-gb/Support/Purchases-Subscriptions/Games/How-to-Choose-a-Game-Mode-Ring-Fit-Adventure--1664661.html)
  distinguishes adventure, quick play and custom exercise. Our interpretation:
  preserve the adventure while allowing an explicit easier choice. The new
  **Gentle today** button applies beginner difficulty, low-impact recognition,
  assist and 1.2x base warnings to one run, without overwriting preferences.
- [BodyArcade](https://bodyarcade.com/) describes short camera-controlled games
  and on-device video processing. This is a company description, not an
  independent performance assessment. Our interpretation: camera control and
  privacy alone will not distinguish Joynetic; continuity, feedback and a
  coherent original world need to carry the experience.

These are product-design inputs, not proof that a feature improves adherence,
fitness outcomes or willingness to pay. No competitor assets or game content
were copied.

### Shipped behaviour

- The next-adventure card shows the mission from level JSON, chosen difficulty,
  movement mode, and a total time estimate computed from that level plus the
  actual 75 s warm-up and 60 s cool-down lists. Tracking breaks can extend it.
- Each of 18 levels has schema-validated `journey.mission`, `completion` and
  `keepsake` text. World-specific cover art is original procedural vector art.
  Completing a chapter earns its unique keepsake via `completedLevels`, once;
  replaying cannot duplicate it. Keepsakes are cosmetic and do not affect
  scoring or gate free content. Existing completions receive their keepsakes.
- Results show the authored completion scene on success; only a completed
  non-tutorial run earns a keepsake. Unfinished runs receive encouragement
  without a reward.
- Cleared encounters show contextual feedback: Clean duck / Smooth dodge /
  Light collected / Gate opened. A flow count appears at three or more
  consecutive clears, using the engine's existing streak. Forgiven and missed
  encounters do not produce success effects. Decorative particles honour the
  system reduced-motion setting; the feedback text remains available.
- The recent activity calendar remembers the last 14 distinct local activity
  dates independently of the last 20 coach summaries. Rest days cause no
  keepsake loss. Move/minute totals are explicitly recent-run totals, not
  fabricated lifetime or server statistics.
- The HUD separates hearts/tracking/pause from score/energy to fit a 320px
  phone. Later world cards collapse, with the current world open by default.

### Hands-free menus

During an in-app run pause or checkpoint choice, the game stops accepting
motion input but the foreground camera can continue to recognise a menu
confirmation. A neutral pose must be observed first, then a recognised arms-up
pose held for 1.2 s. The player lowers their arms and stays well framed for a
spoken 3 s countdown. A tap on Resume / Continue can replace the gesture, but
cannot bypass framing or the countdown. Poor framing or a frame gap over
250 ms restarts the countdown. Gesture confirmation never chooses Quit or
Finish run, so an accidental menu movement cannot discard a session.

Menu movements are excluded from workout attempt/rejection counts and do not
reach RunEngine. Backgrounding stops the camera; foregrounding re-arms the
menu, and never resumes the game by itself. No recogniser thresholds changed.
Manual pauses and cool-down time no longer inflate the uploaded run duration.

Gentle's 1.2 warning multiplier combines with assist's existing 1.25 multiplier
to give 1.5x base warning lead, subject to the director's encounter-spacing
limits. Low-impact remains the default and jumps are never enabled by this UI.

### Evidence still needed

Widget previews in `docs/screenshots/next-*.png` use test fixture activity and
locally loaded preview fonts; they are not Android camera playtests. Validate
gesture intent, voice availability, readability from 2 m, native preview
alignment, latency and battery use on three phone tiers. Run first-session
playtests before claiming a competitive advantage. Measure time to first
successful move, framing interruptions, first-run completion and voluntary
return over a week; do not infer these from automated test counts.

Thresholds are starting values. Change them only with recorded data, and only
while `packages/motion_core/test/replay_accuracy_test.dart` still passes.

## Moves (World 1)

| Move | Measure | Starts | Ends / re-arms | Guards |
|---|---|---|---|---|
| Squat | Hip-to-ankle span shrink, as % of calibrated comfortable depth | ≥ 60 % for 2 frames | < 25 % | Hips and knees visibility ≥ 0.5; forward bend doesn't change the measure |
| Lean | Shoulder-centre minus hip-centre x, relative to standing, as % of calibrated lean range per side | ≥ 60 % for 2 frames | < 25 % | One lane per lean; 300 ms cooldown between starts (early leans rejected as "too early") |
| Raise arms | Both wrists above the nose line | held 150 ms | Wrists below shoulder line | Must come down before the next activation |

Low-impact profile: squat starts at 45 % (half squat), ends at 20 %; one arm is
enough. Side-step mode (lane change by hip translation) exists for players who
prefer it. `MoveRejected` reasons: too shallow (dip peaked between 35 % and the
start threshold), not visible, too early.

## Quality gate

Full-body key points visible (each ≥ 0.5, mean ≥ 0.65), inside the frame,
body height ≥ 35 % of the image and ≥ 256 px (size uses max(bbox, 3.3 × torso)
so squats don't read as "too far"), bbox ≤ 98 %. Failing for 250 ms pauses
tracking; 300 ms of good frames resumes. Analysis is 480×640 on every tier.

## Framing guidance (setup, calibration, in game)

`Framing.advise` turns the gate's verdict into one fix. Selfie space: screen
left is the player's left.

| Gate result | Fix shown and spoken |
|---|---|
| no person | "Step into the frame" |
| out of frame, head or feet cut (or both sides) | "Step back" |
| out of frame, right edge only | "Move a little to your left" (arrow left) |
| out of frame, left edge only | "Move a little to your right" (arrow right) |
| too close | "Step back" |
| too far | "Come a little closer" |
| low visibility | "Add light in front of you" |

- Cut edges glow red in the frame view; edges within 6 % of the image glow
  amber while tracking is still good (early warning, also on the game screen).
- `FramingFilter`: a new advice must last 400 ms before the text, icon or
  voice changes (display only).
- Spoken hints repeat on change or every 6 s (setup, calibration) / 8 s (game
  waiting), never more than once per 2.5 s in game.
- Setup is hands-free: 3 s benchmark, then 1.5 s in a good frame starts a
  spoken 3 s countdown and calibration opens by itself; leaving the frame
  cancels the countdown. The "Next" button is only a shortcut.
- In game: with the mirror on, a small 3:4 picture-in-picture sits under the
  HUD. When tracking pauses it grows into the frame finder (outline, cut
  edges, arrow, one line, "The game waits for you"). It shrinks back by
  itself when tracking resumes.

## Calibration (~30 s)

When: only the safety steps (18+ and readiness) are required before the app
opens. Setup and calibration are offered once in onboarding and can be
skipped ("Skip for now and explore"). Any run (`/quest`, `/tutorial`) started
without a calibration goes to the get-ready page first (router `playGate`),
then setup (skipped if already done) → calibration → straight into the run
the player tapped. Browsing never needs a calibration.

Still 2 s (hip wander < 8 % torso vs running mean) → arms up held 0.5 s → two
squats → lean left held 0.5 s → lean right held 0.5 s. Minimums: squat depth
15 % torso, lean range 10 % torso. Drift check: torso length ±15 %, or the
hips moved more than one torso sideways.

- A squat counts once the drop is back under half the minimum depth (7.5 %
  torso; was 4.5 %): players rarely return to the exact standing span.
- Hands-free: every step is spoken and advances by itself.
- If a step (not the standing baseline) is not finished after 20 s **in
  frame** (`Calibrator.stepActiveMs`; gaps count at most 100 ms, so time out
  of frame never counts), it is skipped with "No problem, we will use a
  gentle setting". What was measured is kept; anything missing uses the
  population defaults (squat 45 % torso, lean 30 % torso, reach 0.6 torso
  above the nose).

## Forest Escape (≈3 min)

| Time | Segment | What happens |
|---|---|---|
| 0:00–0:30 | Practice | Two slow beams, a lane block, an orb; hints |
| 0:30–1:30 | Learn | Single obstacles, growing variety and speed |
| 1:30–1:45 | Breather | Orbs only |
| 1:45–2:30 | Combos | Lane block then beam; lean then raise arms |
| 2:30 | Checkpoint | Progress saved; a lost heart comes back |
| 2:30–3:00 | Finale | Gate sequence, then results |

3 hearts. Hitting a beam, lane block or gate costs one; a missed orb costs
nothing. Tracking failure never costs a heart: an encounter is forgiven if
tracking is lost at arrival, was lost at any point from 300 ms (level clock)
before its cue to arrival, or the player has had less than a reaction time
(800 ms wall clock, 1200 ms in assist) of tracked play since the cue or
since tracking came back. A checkpoint restart (only after running out of
hearts past the checkpoint, once per loss) resets tracking light, loss
times, held moves, grace timers, streak, pace and the current segment, so
the checkpoint hint replays and pending encounters are cued again.

## Stages

Stages play in catalogue order (`app/lib/game/stages.dart`); stage N+1 unlocks
when stage N is completed (completed level ids live in on-device Settings).
The Daily Quest plays the first unlocked, uncompleted stage. Every stage uses
the same segment pattern as Forest Escape (practice, learn, breather of orbs
only, combos, checkpoint, finale) and the same four encounter types; only the
theme colours and side props change, never obstacle shapes.

| Stage | Level id | Length | Flavour |
|---|---|---|---|
| 1-1 Forest Escape | `w1-forest-escape` | 3:01 | Branches, rocks, forest gates |
| 1-2 River Crossing | `w1-river-crossing` | 3:00 | Log beams, river rocks, firefly orbs; lean-then-squat combos |
| 1-3 Guardian Grove | `w1-guardian-grove` | 3:30 | Mini-boss: sweeping branches, root walls; gate sequence calms the guardian |
| 2-1 Desert Dunes | `w2-desert-dunes` | 3:00 | Sand walls, low cactus arches, mirage orbs (desert theme) |
| 2-2 Sandstorm Temple | `w2-sandstorm-temple` | 3:30 | Two-lane sand walls, harder combos, temple gates finale |

Intermediate and advanced add extra encounters via `minDifficulty` (mostly
centre-lane orbs placed mid-gap). Every stage is proven finishable by the
simulation test at every difficulty with the competent and slow bots.
Worlds 3–9 show as "coming soon".

## Difficulty

| | Warning | Demanding in a row | Hints | Low-impact default |
|---|---|---|---|---|
| Beginner | 2.0 s | 3 | always | on |
| Intermediate | 1.6 s | 5 | first time | on |
| Advanced | 1.3 s | 7 | off | player's choice |

Assist mode: +25 % warning, wider windows (squat grace 400 ms, raise window 900 ms).
Two-lane blocks are cued 600 ms earlier. Minimum spacing after each answer:
beam 1100 ms, lean 650 ms, raise 750 ms (+250 ms each in low-impact).
Encounters can be marked `minDifficulty` so harder settings add decisions, not
just speed.

## Director rules (deterministic)

1. Drop encounters above the chosen difficulty.
2. Breathers never carry anything that can hurt.
3. Cap demanding (beam) encounters in a row; swap the extra for an orb.
4. Enforce minimum spacing so no two moves are asked for at once.
5. Hints by difficulty.
At run time the `Pacer` slows the world to 60 % on amber tracking and to a stop
on red, ramping at 2.5×/s. It never claims to measure fatigue or heart rate.

## Scoring and progression

Points only from resolved encounters (beam 100, lane block 100, orb 50, gate
150) × streak multiplier (+10 % per consecutive clear, up to ×2). XP =
score/20 + active seconds/10 + 50 for completing. Hero level = ⌊√(XP/100)⌋+1.
Crew effort points = active minutes × 10 + 20 for completing, max 100 per
session. Streaks follow the IST calendar day, with 2 free shields a month; a
broken streak restarts at 1 and never removes other progress.

## Sound cues

Each obstacle has its own generated sound (`tools/gen_cues.py`): beam = falling
whoosh, lane block = two knocks, orb = rising sparkle, gate = three-note bell.
Shapes also differ (chevrons, rocks, star, arch with up-arrow), never colour alone.

## AI coach: Coach Kavi

Coach Kavi (an original fox-orange runner's guide) is Joynetic's on-device
coach. It is rule-based, deterministic and offline: `Coach` in
`packages/game_director/lib/src/coach.dart`, no cloud model. It reads the last
20 run summaries (counts only, stored locally) and returns message keys plus
parameters; English, Hindi and Gujarati text lives in
`app/lib/l10n/coach_strings.dart`. Kavi makes game suggestions only and never
claims to measure fatigue, heart rate or health.

- **Difficulty**: last run unfinished, ≥2 hearts lost, or effort rating ≥4 →
  suggest one level easier plus assist mode (and low-impact if it was off).
  Two most recent runs at the current level both finished with ≤1 hit and
  effort ≤3 (or unrated) → suggest one level harder. Never more than one level
  at a time; never suggests turning low-impact off. The player confirms with a
  "Try <level>" button.
- **Form tips** (max 2, most frequent first): a rejection reason needs ≥3
  occurrences in the run. tooShallow → sink deeper / lean further / lift
  higher ("only as far as comfortable"); tooEarly → stand fully / return to
  centre / lower arms; notVisible (all moves) → lighting and framing tip.
- **Recap**: new personal best > flawless (0 hits) > finished > good effort,
  with score, obstacles cleared and most-used move. **Next goal**: finish →
  keep all hearts → next round 100 above the best score.
- **Week balance**: three runs in a row rated ≥4 → suggest a lighter run;
  otherwise, with ≥20 reps in the 7 days up to the latest run, one move above
  60 % of reps → suggest another stage for variety.

## Opt-in roadmap moves: barrier hold and side step (motion_core)

Implemented in `packages/motion_core/lib/src/extra_recognisers.dart`, off by default
(`MotionEngine(enableBarrierHold: true, enableSideStep: true)`). They emit
`ExtraMoveStarted/Held/Ended/Rejected` with `ExtraMove { barrierHold, stepLeft, stepRight }`,
a separate enum so exhaustive `switch`es over `Move` elsewhere are unaffected. Thresholds
live in `ExtraMoveThresholds` (`MotionThresholds` and its JSON are unchanged).

| Barrier hold (§3.2) | Default | Low-impact |
|---|---|---|
| Wrist band below shoulder line | 0–0.6 torso | same |
| Wrist x inside shoulder span ± | 10 % of span | same |
| Forward: wrist–shoulder distance ≤ | 0.55 × arm length (arm = 1.05 × standing torso until calibrated) | same |
| Elbow y | between wrist and hip | same |
| Guard exclusion: wrist–nose distance ≥ | 0.4 torso | same |
| Hands | both | one (`barrierOneHand`) |
| Start | conditions true for `confirmFrames` (2) | same |
| End | conditions false for 200 ms; `ExtraMoveEnded.heldMs` = start → last true frame | same |
| Held events | every `heldIntervalMs` (100 ms) | same |
| Visibility | wrist, elbow, shoulder ≥ 0.5 else `notVisible` once per attempt | same |

Known: raising the hands to a guard passes through the barrier zone for a few frames
(< 300 ms of hold in tests); the `pushWall` rule (held ≥ 70 % of `holdMs`) absorbs it.

| Side step (§3.1) | Default | Low-impact |
|---|---|---|
| Start: \|sideStepFraction\| ≥ | 0.60 for 2 frames | 0.45 |
| Lean guard: \|leanFraction\| < | 0.40 (otherwise silently ignored) | same |
| Feet moved: ankle-centre shift ≥ | 50 % of hip shift, same side, else `tooShallow` | same |
| End / re-arm: \|fraction\| < | 0.25 | 0.20 |
| Cooldown between starts | 400 ms (`tooEarly`) | same |
| Visibility | hips and ankles ≥ 0.5 else `notVisible` | same |

The feet check compares the ankle centre with the calibrated standing hip x, because
calibration does not yet record a standing ankle x. Tests: `test/extra_recognisers_test.dart`
(synthetic only; a recorded clip is required before these moves are used in content).

## Play-style warning multiplier
- `RunSettings.warningMultiplier` (default 1.0, clamped 1.0–1.5). Gentle play style = 1.2;
  Balanced and Active = 1.0. Set from `Settings.warningMultiplier`; the tutorial passes it too.
- `Director.warningMs = round(profile.warningMs × multiplier × (assist ? 1.25 : 1))`.
  Two-lane blocks still add `wideBlockExtraMs` (600 ms) on top.
- Extra warning (multiplier and/or assist) never pulls a cue before the previous encounter
  arrives: the cue is clamped to the previous arrival, but never later than the profile's base
  warning. Without this clamp the simulator showed hits with longer warnings, because the next
  cue invited the player to move before the last obstacle had passed. Arrival times and
  feasibility spacing are unchanged, so more warning never makes a run harder.
- Verified: gentle (×1.2, assist, low-impact) simulated once per level — competent bot takes
  0 hits, slow bot finishes, all encounters feasible.

## Arcade games (v2, 2026-11-09)
Six new games share one pattern: **pure-Dart rule engines in
`packages/game_director/lib/src/arcade/`**, content in `content/arcade/*.json`
(validated by `content/schema/arcade.schema.json` and by the engine tests),
body geometry from `motion_core` (`BodyPose`, `PoseMatcher`, `SwingRecogniser`),
and one shared play screen in the app. Engines see landmarks and motion events
only, never pixels.

Shared rules (every game):
- **Game clock = real time while tracked.** A red tracking light freezes the
  clock (`ArcadeClock`). After tracking returns, anything whose window closes in
  the next 800 ms is *forgiven* and removed from the maximum (rule 5).
- **Rule 6:** every input is judged only against a live target/ask; reaching
  an empty zone, punching with no pad, or bending before a route connects does
  nothing.
- **Latency:** inputs are judged at `clock - 100 ms`; windows are late-biased
  (`TimingWindows.lateBias`). A move already held when its window opens earns at
  most *Good* (anti-camping).
- **Body space:** torso units from the shoulder centre, +y up, player-left on
  screen-left. A slow `BodyAnchor` (updated only from standing frames) keeps zones
  still while the player dips.
- Pause = tracking loss (held moves clear). Hands-free resume uses `ReadyGate`
  (raise both arms 1.2 s, lower, 3 s good frames).
- Sounds are original, synthesised by `tools/make_sounds.py`.

| Game | Core verb | Judging | Forgiveness / fairness |
|---|---|---|---|
| **Mirror Mela** | Hand into a zone as its ring closes | Zones `hiL/R (±0.75, 1.15)`, `sideL/R (±1.3, 0.05)`, `lowL/R (±1.15, −0.75)`; radius 0.44–0.52 T; ≥ 2 frames inside; graze = 1.3× radius → OK | Orbit sweeps ≥ 3 s apart, ≥ 2.2 s warning; a hit only costs combo + 1 of 3 shields (5-combo restores); golden finale fits inside the round |
| **Pataka Pose** | Strike and hold a shape | `PoseMatcher` angles (shoulder/hip tol 20° + falloff 30°, elbow/knee 25°/35°, lean 10°/15°); 3-frame median; lock ≥ band lock for 2 frames; hold ≥ lock − 8; 300 ms grace then 2× drain | Frame **hovers** if < 70 % of pose weight is visible (no score); 3 fails on one joint → +5° for that joint; chill frame every ≤ 6 frames; ≤ 2 demanding shapes in a row; party turns every 4 frames with a 5 s step-in |
| **Craftguard Duels** | Answer an attack on a 4-count | Impact at beat 4 of an 8-beat phrase; windows perfect 150 / good 280 / ok 420 ms + 120 ms late bias; duck/lean = recogniser state or hip shift ≥ 0.3 T; guard = `BodyPose.isGuard` 2 frames; pads at (±1.15, 0.05) r 0.6 | Sparks lost at most 1 per 2 s; 0 sparks → **Regroup** (phase restarts, never game over); missed pads/charges cost nothing; after 3 fallback loops a phase completes anyway |
| **Taal Toofan** | Hit move cards on the beat | Cards land on body zones; windows 120/220/320 ms + 100 ms bias (+20 ms for step/dip); clap needs 1 frame, others 2; Light/Groove/Toofan score 4/7/8 of every 8-count | Songs always finish; accuracy = (P + 0.6 G + 0.25 OK) / scored; tracking loss holds the groove and counts back in 4 beats; skipped cards excluded |
| **Tapeball Tamasha** | Swing across the body | `SwingRecogniser`: hands together (≤ 0.45 T) held ≥ 100 ms at/above shoulder on one side, then hand-midpoint travel ≥ 1.0 shoulder width (low-impact 0.6) within 100–1200 ms; lofted if hands still ≥ −0.3 T; ±550/380/300 ms window by difficulty | Lost tracking in a run-up = **dead ball**, re-bowled; no wickets on beginner; wides are re-bowled; ball arrives *beside* the player in the image plane, never toward the camera |
| **LUMEN** | Reach-select, lean-turn, bend-weld | Cards at (−1.2, −0.55), (0, −0.3), (1.2, −0.55) r 0.45, dwell 450 ms; neutral 300 ms rearms; leans rotate one step per recognised lean; weld = fresh squat after the route connects and arms are neutral (no-squat: hands together 700 ms) | No timers; thinking takes no game time; tracking loss discards partial gestures, keeps the board; restored modules persist and never decay |

Content invariants checked by `packages/game_director/test/arcade_content_test.dart`:
every LUMEN board starts broken and has a solution; Pataka stages reference real
poses, Chai Break is upper-body only; every guardian is calmed and every song
danced (> 80 % accuracy) by a competent bot on every level; Tapeball formats
finish with no wickets lost for an idle beginner; the app's bundled copies equal
the canonical JSON. No core recogniser threshold (squat/lean/raise/barrier/step)
was changed.
