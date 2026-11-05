# QA 5: motion recogniser stress and level pacing (2026-11-05)

Review only. No code or content was changed. The throwaway test `packages/motion_core/test/_qa5_test.dart` used SyntheticSession/SyntheticBody from the default MotionEngine and MotionThresholds, and was deleted afterwards. The level metrics came from a scratchpad script, measured on beginner-visible encounters (encounters marked minDifficulty above beginner were excluded). The level schema has no "surprise" concept, so a gate encounter counts as a surprise here.

## Recogniser results (per script: 1 squat, lean L, lean R, raise arms; decoys: shallow dip, sway, forward bend, arms to chest, side shuffle)
- Body height 0.62/0.85/0.95: 4/4 detected, 0 decoy triggers. Height 0.38: 2/4 (squat and raise both **missed silently**, with no MoveRejected). Height 0.30: 0/4. The quality gate blocks this, which is expected.
- 10/12/15 fps: 4/4, 0 false triggers. Dropping every 3rd frame (empty landmarks): 4/4.
- Noise σ 0.006/0.01/0.015: 4/4, 0 decoy triggers, 0 triggers in 20 s idle. σ 0.02: **calibration throws** `Bad state: Calibration not finished (at neutral)`.
- Occlusion (visibility 0.2): wrists hidden still gave 4/4, so raiseArms fired with no visible wrists. Legs hidden gave 0/4. One side hidden gave 0/4. Neither case produced a reject reason.
- Fast repeats x5: squats at 400–800 ms with 100–400 ms gaps gave 5/5 reps in every case. Raise arms at 400 ms gave **0/5** (all three gaps). At 600 ms or longer it gave 5/5.
- Rapid lean L→R with no idle between, 400/600/900 ms: 1+1 and 2+2 correct, no doubles.
- Squat while leaning: lean 0.3/0.5 gave 2 squats only. Lean 0.8/1.0 gave 2 squats **plus 1 leanLeft and 1 leanRight**.

## Level metrics (beginner)
Values per level: encounters/min, demanding (non-orb) per min, peak in any 30 s, beams/min, longest run of non-orb encounters against beginner maxDemandingInRow=3, and gate (surprise) gaps in seconds.
w1-firefly 20.3/13.0/13/5.3/5, gates 5.5–15 · w1-forest 17.6/13.3/13/5.6/8 · w1-garba 24.7/14.0/15/0.0/3 · w1-guardian 20.9/17.1/19/7.4/**16** · w1-monsoon 21.0/13.3/13/5.7/5 · w1-river 20.0/16.0/19/6.7/12 · w2-dunes 20.0/16.0/19/6.7/12 · w2-mirage 14.7/10.7/10/3.7/6, gates 3.5–77.6 · w2-oasis 19.3/15.7/19/6.3/10, gates 3.5–86 · w2-sandstorm 20.9/17.4/19/7.7/**16** · w3-chase 18.3/14.3/13/6.0/10 · w3-rooftops 16.3/12.3/13/5.0/9 · w3-market 19.3/15.7/19/6.3/10 · w3-skyline 18.6/15.1/12/4.9/10 · w4-glacier 14.7/10.0/12/3.3/9 · w4-mountain 15.0/9.7/12/3.3/9 · w4-summit-storm 16.9/12.6/13/5.1/9 · w4-sunrise 10.3/5.3/6/1.3/3.
In 13 of 18 levels the first gate comes at 135–179 s, so the first 2+ minutes have no surprises.

## Findings
| id | sev | file | issue | fix |
|---|---|---|---|---|
| Q5-1 | High | content/levels/w2-oasis-caravan.json, w3-neon-night-market.json | Near-duplicates beyond exact copy: type sequence similarity 1.00 and 95% identical timestamps, in different worlds. | Re-author one of them (new timings, different mix). Add a similarity check to content:validate. |
| Q5-2 | High | w1-guardian-grove.json, w2-sandstorm-temple.json (also w1-river, w2-dunes 12, w2-oasis, w3-*, w4-* 9–10) | Beginner gets 16 demanding encounters in a row against maxDemandingInRow=3. 16 of 18 levels exceed the cap in the content itself, so they rely on the director to fix it at runtime. | Insert orbs or breathers so the authored content honours the beginner cap. Have the validator fail when the streak is over the cap. |
| Q5-3 | Med | w1-guardian-grove, w1-river-crossing, w2-desert-dunes, w2-oasis, w2-sandstorm, w3-market | Too dense for Beginner: 19 demanding encounters in a 30 s window and 16–17.4 demanding/min, while w4-sunrise-summit has 5.3/min. Difficulty does not ramp across worlds: World 1 is about as dense as World 4 or denser. | Cap beginner at about 12 demanding/min and 13 per 30 s. Gate the extra encounters behind minDifficulty:intermediate. |
| Q5-4 | Med | w4-glacier-pass.json ~ w4-mountain-trail.json; w2-desert-dunes ~ w2-oasis/w3-market (0.90 seq, 0.87 times); w1-firefly ~ w1-monsoon (0.90, 0.75); w1-guardian ~ w2-sandstorm (0.81, 0.73) | Template-cloned levels. Glacier and mountain have 0.97 type-sequence similarity and 90% identical timestamps. | Vary the timing grid and the combo order for each level. Reuse a template only with jitter of ±1–2 s or more and a different set of segments. |
| Q5-5 | Med | 13 levels (e.g. w1-forest, w1-river, w3-rooftops, w4-glacier, w4-mountain) | Monotonous: no gate before 154–179 s, and later gates are evenly spaced (glacier/mountain exactly 8 s apart). w2-mirage and w2-oasis go 77–86 s between gates. | Put one gate in the learn or combo segment (about 45–90 s) and space gates 20–40 s apart. |
| Q5-6 | Med | w1-garba-quest-event.json | Zero beams (0/min), so no squats at all. 9.7 lane blocks/min and 13 gates. Lowest move variety of any level, and the densest at 24.7/min with a 1.1 s minimum gap (warning is 2.2 s). | Add squat beams. Space encounters 1.5 s or more apart for beginner. |
| Q5-7 | High | packages/motion_core (raise-arms recogniser) | A raise-arms move lasting 400 ms is missed 0/5 at any gap, while 400 ms squats score 5/5. Fast players tapping orbs will be ignored without explanation. | Lower the raise-arms hold/min-duration so it fires at about 350 ms, and check that replay_accuracy still passes. If it is intentional, document it in game-design.md. |
| Q5-8 | Med | packages/motion_core (gate/recogniser feedback) | Silent misses: at body height 0.38 (passes the 0.35 gate), squat and raise give 0/1 each. With legs or one side occluded, all moves are missed. In both cases no MoveRejected(notVisible) is emitted, so the player gets no explanation (rule 5). | Raise minBodyHeight to about 0.42, or emit notVisible when the attempt involves joints that are not visible. Add a regression test. |
| Q5-9 | Med | packages/motion_core (raiseArms + visibility) | raiseArms still fires 1/1 when all wrist and hand landmarks have visibility 0.2. | Require wrist visibility ≥ minVisibility for raiseArms, otherwise reject as notVisible. |
| Q5-10 | Low | packages/motion_core (lean vs squat; calibration) | A squat combined with a lean of 0.8 or more also fires leanLeft and leanRight (2 extra lane changes in 2 squats). Calibration throws a StateError at noise σ 0.02 instead of returning a recoverable state. | Suppress lean while squat is active, or raise the lean threshold during a squat. Make Calibrator.build failure a recoverable result and show the "hold still" UX. |

## How to verify
Recreate the stress test from the bullets above using SyntheticSession and runEngine (playing scripts through the engine), and re-run `python3 -I <scratchpad>/levels.py content/levels`.
