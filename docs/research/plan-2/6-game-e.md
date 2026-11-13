# Game E: PATAKA POSE, a self-view party pose game (design draft, 2026-11-05)

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

## 1. Why this game fits Joynetic

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

## 2. Core loop (one round ≈ 2.5–3 min)

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

### 2.1 Frame types (all JSON-defined)
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

## 3. Pose matching and similarity

### 3.1 Features (all 2-D, scale-invariant, from the 33 landmarks + visibility)
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

### 3.2 Similarity score (0–100 %)
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

### 3.3 Score per frame
`frameScore = round(peakSustainedSimilarity × holdCompletion)` where peakSustained is the best 300 ms-window median
during the hold. Stars: ★ ≥ 60, ★★ ≥ 80, ★★★ ≥ 92 and a full hold. Combo multiplier ×1.0 → ×1.5 (caps at 6 frames).
A tracking hover breaks nothing: the combo is preserved.

---

## 4. Pose library (24 poses + low-impact variants)

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

## 5. Difficulty and age bands (adults 18+ only)

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

## 6. Round and session structure

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

### 6.1 Party modes
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

## 7. Humour and personality: Coach Kavi

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

## 8. Shareable clips (landmarks only, never camera video)

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

## 9. Progression and cosmetics

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

## 10. Festival variants (content drops, JSON only)

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

## 11. Free / Premium (Google Play Billing only; rule 11)

| Free | Premium ("Mela Pass", Play subscription; also lifetime IAP) |
|---|---|
| 12 core poses, 2 Mela Map stalls, Pass-the-Pataka up to 4 players, Pose of the Week, landmark clips with watermark | All 24+ poses + every festival drop, full Mela Map, 8-player party + Team Toli + Copy-Cat Chain, all avatar skins, clip without the extra end-card, Duo Frame (where supported) |
| No ads during play (a camera game must not interrupt someone mid-pose); optional rewarded "extra cosmetic roll" only post-round | Festival packs also sold individually as small IAP (₹19–49 range per 1-market ARPU data) |

India pricing guidance: monthly ₹79–99, yearly ₹499–599, festival pack ₹29. These figures are hypotheses for A/B
testing. There are no links or nudges to pay outside Play (rule 11). Safety features (LI variants, support cues) and
accessibility are **never** paywalled.

---

## 12. Metrics

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

## 13. Implementation notes (for later tasks; no repo changes now)

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

## 14. Risks and mitigations

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

## 15. MVP cut (suggested)
1. Solo Cut-out Frame + Chill + Statue Bazaar; 12 poses (#1–5, 7, 8 LI, 11, 13, 14, 18, 25); Easy and Normal bands.
2. Pass-the-Pataka (2–4 players) with a shared scoreboard.
3. Landmark avatar clip share (stick-glow skin only).
4. Diwali skin as the first JSON festival drop, to prove that content is data.
Next: Mirror Kavi, Sequence Chain, Team Toli, Copy-Cat Chain, Pose Album. Later: Duo Frame (fps-gated).
