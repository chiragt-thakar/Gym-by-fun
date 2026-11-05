# Game design: rules and thresholds

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
tracking; 300 ms of good frames resumes.

## Calibration (~30 s)

Still 2 s (hip wander < 8 % torso vs running mean) → arms up held 0.5 s → two
squats → lean left held 0.5 s → lean right held 0.5 s. Minimums: squat depth
15 % torso, lean range 10 % torso. Drift check: torso length ±15 %, or the
hips moved more than one torso sideways.

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

Coach Kavi (an original fox-orange runner's guide) is MotionQuest's on-device
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
