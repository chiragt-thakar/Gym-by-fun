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
nothing; tracking loss between cue and arrival forgives the encounter.

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
