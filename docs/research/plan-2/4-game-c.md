# Game C: MIRROR MELA, an AR mirror arcade (MotionQuest mode)

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

## 1. Core loop (one 75 s round)

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

## 2. Body points and zones

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

## 3. Three sub-modes

### 3a. Bubble Bazaar: pop and catch (the flagship and free mode)
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

### 3b. Rang Wall: paint the wall with poses
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

### 3c. Orbit: collect and dodge "all around you"
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

## 4. Round and session structure (≈ 5 min 15 s)

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

## 5. Scoring, combos, Fever

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

## 6. Difficulty and pace profiles

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

## 7. Accessibility and low-impact

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

## 8. Mirror view and privacy

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

## 9. Juice

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

## 10. Progression and cosmetics (earned only, never pay-to-win)

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

## 11. Social share (never camera video)

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

## 12. Free and Premium (Google Play billing only; no nudges during play, rule 11)

| Free (unlimited play) | Premium (existing MotionQuest subscription) |
|---|---|
| Bubble Bazaar: all difficulties, 2 stalls | All 3 modes on all 6 stalls |
| Orbit: 1 stall | Rang Wall: full 40-wall library + 4 new walls/month (JSON content packs) |
| Rang Wall: 3 walls | Premium cosmetic set (6 skins, 4 trails), clip frame themes |
| Daily Remix, share clips, pass-and-play (Bubble Bazaar) | Pass-and-play in all modes, weekly Crew challenge boards |

Pricing suggestion, for the team to decide: fold into the MotionQuest plan (e.g. ₹99/month,
₹699/year). Shown only on the store screen and the post-session results screen, never during a
round. Gym-code access unlocks Premium for gym members.

## 13. Content and config (rules 7 and 8)

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

## 14. Metrics (targets for beta)

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

## 15. Risks and mitigations

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

## 16. Build order (smallest playable first)

1. Body-point and zone hit-tester in `motion_core` (tests first: synthetic poses per zone,
   10/15/30 fps, noise, dropped frames, decoys: arms-up ≠ `hi-*` single, idle ≠ any zone).
2. `MirrorEngine` in `game_director` (RunEngine contract; grades, combo, forgiveness) +
   simulator bots.
3. Avatar-mode painter + Bubble Bazaar beginner level (1 stall). This is the vertical slice.
4. Native preview texture + crop/mirror rect + `FLAG_SECURE`; measure lag.
5. Orbit (reuses squat/lean) → Rang Wall (pose matcher) → clip renderer → upper-body gate
   (seated).
