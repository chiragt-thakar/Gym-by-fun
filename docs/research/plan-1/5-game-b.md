# Game Mode B: TAAL TOOFAN (working name), a MotionQuest dance party mode

*"Taal" = rhythm, "Toofan" = storm. One line: beat-synced move cards fly at your on-screen
avatar; you hit them with your body on the beat, build the band's sound layer by layer, and
unleash "Toofan Time". Original festival-inspired music. Phone on the floor, 2 m away, audio first.*

Alternatives if the name fails clearance: **Beat Baraat**, **Thumka Storm**, **Naach Pulse**.

Scope rules carried over from AGENTS.md, all binding: real on-device pose only; no camera frames
stored or uploaded (this shapes the highlight clip, §10); latest frame only; landmarks-only into
Dart; tracking loss never costs score/combo/progress (§4.4); a move only counts against a card
(rule 6); charts are schema-validated JSON (§6); the director is deterministic (§6.4); no jumps by
default; original assets only; payments only through Google Play. Fitness game, never medical:
no calorie, weight or heart claims. We show "moves" and "party minutes" only.

---

## 1. What makes it different (design pillars)

1. **The card lands on your body.** Cards don't sit in lanes. Each card flies from the back of
   a festival stage and lands on the body zone that does the move: claps land between your
   hands, reaches land on a halo at the target point, steps land at your feet. You read it as
   "where", not just "what".
2. **Audio first: a dance-class caller.** Every card is called 1 beat early by a short voice
   ("Taali!", "Step right!", "Reach up!"), and every new phrase gets a "5, 6, 7, 8" count-in.
   You can play with your eyes on the room, not the 6-inch screen.
3. **You build the band (stem build-up).** Each move family drives one instrument stem:
   claps → manjira/claps, steps → dhol, reaches/waves → shehnai-synth melody, squat-pulse → bass
   drop, twist → tumbi/strings. Hit 4 cards of a family in a row and its stem joins at the next
   bar line; 2 misses in a row fade it out at the next bar line. Changes land on bar boundaries,
   so camera latency never makes the music feel late.
4. **Every song has one learnable hook step.** The chorus repeats the same 8-count routine (a
   "hook step", like a film song's signature move). That is the thing people repeat at weddings
   and post as a Reel.
5. **Forgiving, fair, and no failing.** Songs always finish. Scoring is by accuracy %, so a 60-year-old
   on Gentle and a 22-year-old on Toofan can compete fairly at a family party.

---

## 2. Core loop

| Loop | Length | Contents |
|---|---|---|
| Micro | 1 beat to 1 bar (0.5–2.5 s) | Hear the call (beat −1) → see the card land (beat 0) → move → Perfect/Good/Miss flash + sparkle sound → combo ticks |
| Phrase | 8 bars (~16 s at 120 BPM) | Count-in → 8-count pattern ×2 → a stem joins or drops → Josh meter fills |
| Song | 2:00–3:00 | Intro → verse → hook → chill-out breather → verse → hook ×2 → freeze-pose finale → results → clip offer |
| Session | 3–4 songs, 9–13 min | Optional 45 s warm-up (march, arm circles), then songs, then a 45 s cool-down song at 80 BPM (reach and breathe) |
| Meta | Day / week / festival | Beat of the Day (one rotating song), weekly Hook Step Challenge, dancer rank, cosmetics, festival packs |

**Josh meter and Toofan Time.** Perfect +2, Good +1, Miss 0 (it never drains). Full at 32
points (about 16 Perfects). When full, a gold "Toofan" card is called ("Toofan! Arms up!") and
answered with a raise-arms move. That triggers 8 bars of Toofan Time: score ×2, all stems come in,
a light show on stage and a crowd chant. If you don't raise your arms, the meter stays full until
the next phrase (rule 6: the move matters only because the game state asks for it).

**Score.** Perfect 300, Good 100, Miss 0, times the combo multiplier: ×1 (0–9), ×2 (10–24), ×3
(25–49), ×4 (50+). **Accuracy %** = (Perfect + 0.6 × Good) / scored cards. Stars by accuracy:
1★ 40 %, 2★ 55 %, 3★ 70 %, 4★ 82 %, 5★ 92 %. A "Full Groove" badge needs no Miss. Party and duel
rankings use accuracy %, never raw score or move count.

---

## 3. Move vocabulary and detection notes

Every move is detected from the 33 landmarks, normalised by the existing calibration (standing
height, shoulder width SW, arm length AL = shoulder→wrist, comfortable squat depth, side-step
range). Each recogniser emits `MoveOnset { move, variant, tOnsetUs, confidence }`, where
`tOnsetUs` is the **interpolated time of the hit point** (below) from camera sensor timestamps.
It is not the time of the 2-frame confirmation. Visibility guard for all moves: the involved
joints ≥ 0.5, or else `notVisible` (no Miss, see §4.4). All values are starting points; tune them
only against recorded clips with `replay_accuracy_test` passing.

| # | Move (call) | Variants | Measure | Hit point (timestamp) | Default threshold | Low-impact / Gentle | Notes / risks |
|---|---|---|---|---|---|---|---|
| 1 | **Step-touch** ("Step left/right") | L, R | Hip-centre x shift as a fraction of calibrated side-step range (reuse `sideStep` features) | First frame ≥ threshold, linearly interpolated between frames | ≥ 0.45 of range (stepping out and back takes 1 beat) | **Toe-tap out**: ankle x − hip x ≥ 0.6 × hip width, no weight shift | Same direction on consecutive beats is allowed with no cooldown, but there must be a return under 0.25 in between. Mirror: "right" always means the *player's* right |
| 2 | **Clap / Taali** ("Taali!") | mid (chest), high (above head), low (hip) | Wrist-to-wrist distance / SW (use the midpoint of wrist and index landmarks 15/19, 16/20) | Minimum of the distance curve (parabolic fit over 3 frames) | Approach from ≥ 0.9 SW to ≤ 0.35 SW within 600 ms | ≤ 0.5 SW is enough; mid only | Hands overlap and motion blur drop wrist visibility. Accept the onset if the hands reached ≤ 0.5 SW with a closing speed ≥ 2 SW/s, even when the minimum frame is low-visibility. **The mic is never used.** |
| 3 | **Arm wave** ("Wave!") | L arm, R arm, both (rainbow) | Wrist above the shoulder line, horizontal wrist velocity | Wrist crosses the body midline (x interpolation) | Wrist y above the shoulder line and \|vx\| ≥ 1.2 SW/s across ≥ 0.8 SW of travel | Wrist above the shoulder is not required (chest-height sweep) | Distinct from raise-arms by its lateral travel. Both-arm "rainbow" = both wrists crossing within 150 ms |
| 4 | **Twist** ("Twist!") | L, R, any | Projected shoulder width / standing SW, signed by nose-x vs shoulder-centre and L/R shoulder z difference | Minimum of the width ratio | Ratio ≤ 0.82, with hips staying ≥ 0.92 of the standing hip width (the hips stay forward) | Ratio ≤ 0.88; **direction not required** ("any") | The weakest 2D signal. Gentle and Groove use "any" direction; Toofan uses signed direction only when the replay recall on recorded clips is ≥ 90 %. Elbows at chest height ("hands in front") makes the projection clearer |
| 5 | **Squat-pulse / Dip** ("Dip!") | single, ×2 pulse (2 bottoms in 2 beats) | Hip-to-ankle span shrink as % of calibrated depth (squat features) | Bottom of the hip-y curve (minimum, parabolic fit) | ≥ 35 % depth (a mini-squat; the run game uses 60 %) | ≥ 25 % (a knee-soft dip) | Bottom timing is natural to the music ("down on the beat"). Max density in §7 |
| 6 | **Reach** ("Reach up/out/low") | up-L, up-R, out-L, out-R, low-L/R (to knee height, never the floor) | Wrist position in body coordinates. Target centre for up-R: shoulder_R + (0.5 AL, −0.85 AL); out: (1.0 AL, 0); low: (0.4 AL, +1.1 AL) | First frame inside the target circle | Radius 0.35 AL | Radius 0.45 AL; low reaches removed | The card halo is drawn exactly at this zone on the avatar, so what you see is what's judged |
| 7 | **Raise arms / Hoy!** (Bhangra arms, Toofan trigger) | both, one | Existing raise-arms recogniser | Wrists cross above the nose line | Existing (held 150 ms; the hold is waived for a rhythm onset) | One arm (existing low-impact) | Reuses the shipped recogniser |
| 8 | **March** (hold card, "March 4!") | 2, 4 or 8 beats | Existing `jog`/march knee lift | Each knee peak | March 30 % lift | Same | Scored per beat (±250 ms per beat). Used in breathers and warm-up |
| 9 | **Freeze pose** (finale, "Strike a pose!") | 6 original signature poses (e.g. "Sky Point": one arm diagonal up, other hand on hip) | Joint-angle template distance | Held ≥ 70 % of 2 beats | Angle error ≤ 25° per tracked joint | ≤ 35° | The clip's closing frame. Always scored generously |

Launch with 1–7 (the brief's six plus the existing raise arms). March and freeze reuse existing
logic. Jumps and hops **never appear** unless the player has jumps enabled; with jumps off the
deterministic director replaces any authored `hop` with a calf raise.

**Anti-mash (fairness).** A card takes the *first* onset of its move inside its window. Other moves
and extra onsets do nothing (rule 6, no penalty). If ≥ 3 onsets of the same move fall within the
600 ms around a card (clap spamming), the result is capped at Good, with a gentle tip: "Clap on the
beat, not nonstop."

---

## 4. Timing windows and latency compensation

### 4.1 Where the latency comes from (mid-range Android, 30 fps)
| Stage | Typical | Handling |
|---|---|---|
| Camera exposure + ISP → frame | 33–70 ms | Use the **sensor timestamp** (CameraX `ImageInfo.timestamp`, base checked with `SENSOR_INFO_TIMESTAMP_SOURCE`), not the arrival time |
| MediaPipe inference (Lite/Full, GPU) | 20–45 ms | Irrelevant to judging, because we judge by the frame timestamp. It only delays the *feedback* |
| One Euro filter lag | 15–40 ms | Detect hit points on a **low-lag feature path** (min_cutoff raised for the rhythm recognisers) |
| Frame quantisation | ±16 ms at 30 fps, ±21 ms at 24 fps | Sub-frame interpolation of the hit point |
| Audio output | Phone speaker 20–60 ms (AAudio), wired 10–30 ms, **Bluetooth 150–300 ms** | The audio clock comes from `AudioTrack.getTimestamp()` (presentation time). Per-route offset (§4.3) |

Judgement error = `tOnset − tBeatHeard − userOffset[route] − moveBias[move]`.
`moveBias` defaults (to be tuned from recordings): clap 0, wave 0, reach +30 ms, step +50 ms,
twist +60 ms, squat-pulse +70 ms, because big body moves "land" slightly after the felt beat.

### 4.2 Windows (after compensation; early − / late +)
| Band → | Active (18–30) | Balanced (31–50) | Gentle (50+, default) |
|---|---|---|---|
| Perfect | −80 / +100 ms | −90 / +110 ms | −100 / +125 ms |
| Good | −160 / +200 ms | −175 / +220 ms | −200 / +250 ms |
| Miss | outside Good | outside Good | outside Good |
| Big moves (step, dip, twist) | +20 ms on every bound | +20 ms | +20 ms |
| Assist toggle | ×1.25 on every bound | ×1.25 | ×1.25 |

- The late side is wider because pipeline jitter is mostly late (dropped frames).
- **Frame-rate guard:** if the measured fps is < 25, add half the frame interval to every bound. If
  the fps is < 20, Good extends to +300 ms and the HUD says "Low frame rate — timing relaxed".
  Below 15 fps the mode isn't offered (it falls back to the runner modes).
- Feedback is shown when the late Good bound closes (≈ 200–250 ms after the beat, plus about
  50 ms of inference), so up to ~300 ms after the beat. That's acceptable because the music itself
  never waits for detection (pillar 3: stems change on bar lines).
- The visual card landing is drawn at `tBeatHeard − displayLatency` (1–2 frames, about 16–33 ms) so
  the eyes and ears agree.

### 4.3 Calibration: "Taali Check" (12 s)
At first launch, on every audio-route change (Bluetooth connected or disconnected), and from
Settings: a dhol metronome plays at 100 BPM; the player claps 16 times; the first 4 are
discarded; **median offset → `userOffset[route]`**, clamped to ±350 ms. If the interquartile
range is > 120 ms, the game says "Let's try again — more light helps," then falls back to route
defaults (speaker +40, wired +20, Bluetooth +220 ms). Offsets are stored per route on the device
only. A Bluetooth route shows a one-time tip: "Phone speaker or wired gives the tightest
timing." There's also a manual ±10 ms nudge slider in Settings.

### 4.4 Tracking loss (rule 5)
- Quality gate fails for 250 ms (existing rule) → cards in that span are **Skipped** (grey). They
  aren't Misses, don't count in accuracy, and freeze the combo instead of breaking it.
- Fails for > 1 bar → **Groove Hold**: the music loops the current 2-bar *vamp* (drums + bass
  stem, authored per section), no new cards spawn, and the caller explains: "Step back so I can
  see your feet." After 300 ms of good frames there's a 1-bar count-in, and play resumes at the next
  section boundary. This is the rhythm-game version of "the game slows down and explains why".
- More bodies than expected in frame (for example a passer-by or a child walking in) → Groove Hold with
  "Only the dancer should be in view." Bystander landmarks are never used or recorded.

---

## 5. Song and level structure

### 5.1 Music direction (all original, work-for-hire with full buyout incl. sync + social)
| Style family | Feel | BPM | Signature patterns |
|---|---|---|---|
| Garba-inspired ("Raas" family) | Circular taali grooves; dholak, dhol, manjira, harmonium-synth | 100 → 116 → 128 accelerating across 3 rounds | "Taali-3": claps on beats 1, 2, 3 (rest on 4) over step-touches; circling reaches |
| Bhangra-inspired ("Dhol" family) | Dhol chaal, tumbi, bounce | 92–104 half-time feel | "Hoy!" arms up, shoulder-bounce dips, step-touch with arm waves |
| Bollywood dance-pop ("Filmi" family) | Synth-pop + tabla/dhol fusion, hook chants | 112–126 | Points, waves, twists, freeze poses, a clear hook step |
| Chill / cool-down | Lo-fi tabla, flute-synth | 78–90 | Slow reaches, breathing beat, sway (unscored) |

Lyrics are optional, short Hinglish/Gujarati/Punjabi chants ("Chal chal!", "Hoy!", "Ek, do, teen!").
**Lyrics and art are reviewed: no deities, devotional lines, temples, aarti or religious symbols**;
festival art uses geometric patterns, mirror-work, lights, kites and colour. A musicologist checks
for melodies that sound like famous film songs (copyright risk). Each song is delivered as
stems (drums, bass, melody, chant, move-family layers, vamp loops) in Opus at 48 kHz/128 kbps, about
3.5 MB per 2:30 song, plus pre-rendered 75 % tempo stems for Practice (no DSP cost at runtime).

### 5.2 Song structure template (2:30 at 112 BPM ≈ 70 bars)
| Section | Bars | Cards | Purpose |
|---|---|---|---|
| Intro + count-in | 4 | 0 (a demo dancer shows the hook step) | Get in place; quality-gate check |
| Verse A | 16 | 2 move families, on beats 1 and 3 | Learn |
| Pre-hook | 4 | Build: claps on every beat | Tension |
| **Hook ×1** | 8 | The 8-count hook step ×2 | Learnable signature |
| **Chill-out** | 8 | March or sway, unscored (Gentle ≥ 15 s) | Breather |
| Verse B | 12 | 3 families, a few off-beats on Toofan | Variety |
| **Hook ×2** | 16 | The hook step, then the hook + Toofan card | Peak |
| Finale | 2 | Freeze pose | Clip ending |

Garba-family songs swap verses for **3 rounds of 16 bars, each one BPM step faster** (a tempo map
event), with a 4-bar breather between rounds. That matches the existing Garba Quest plan
(96/108/120 on the run side).

### 5.3 Launch setlist (working titles, to be cleared by legal)
1. *Chakri Chal* (Raas, 100→128)  2. *Mirror-Work Nights* (Raas, 104→124)  3. *Dhol Express* (Dhol, 96)
4. *Tumbi Tornado* (Dhol, 102)  5. *Neon Thumka* (Filmi, 118)  6. *Filmi Flash* (retro disco, 120)
7. *Sangeet Squad* (wedding-sangeet pop, 112)  8. *Patang Pe Dil* (kite-festival, 110)
9. *Gulaal Groove* (Holi, 120)  10. *Roshni Rush* (Diwali lights, 108)  11. *Midnight Masti* (NYE, 124)
12. *Chill Chai* (cool-down, 80, unscored). The roadmap adds 2 songs a month.

---

## 6. Authoring format (JSON + JSON Schema, rule 7)

Proposed paths: `content/rhythm/songs/<songId>.json`, `content/schema/rhythm-chart.schema.json`,
validated by `npm run content:validate`. Audio files are referenced by content hash and served by the
content API.

```json
{
  "id": "rt-neon-thumka",
  "title": "Neon Thumka",
  "family": "filmi",
  "access": "free",
  "event": null,
  "audio": { "stems": { "drums": "sha256:…", "bass": "sha256:…", "melody": "sha256:…",
             "chant": "sha256:…", "layer.clap": "sha256:…", "layer.step": "sha256:…",
             "layer.reach": "sha256:…", "layer.dip": "sha256:…", "vamp": "sha256:…" },
             "practiceTempo": 0.75, "firstBeatMs": 1840 },
  "tempoMap": [ { "beat": 0, "bpm": 118, "meter": 4 } ],
  "sections": [
    { "id": "intro", "startBeat": 0, "beats": 16, "kind": "intro", "vampBeat": 0 },
    { "id": "verseA", "startBeat": 16, "beats": 64, "kind": "verse", "vampBeat": 16 },
    { "id": "hook1", "startBeat": 96, "beats": 32, "kind": "hook", "hookStep": "neonThumkaHook" },
    { "id": "chill", "startBeat": 128, "beats": 32, "kind": "breather", "scored": false }
  ],
  "hookSteps": {
    "neonThumkaHook": [
      { "beat": 0, "move": "stepTouch", "side": "right" },
      { "beat": 1, "move": "clap", "variant": "high" },
      { "beat": 2, "move": "stepTouch", "side": "left" },
      { "beat": 3, "move": "clap", "variant": "high" },
      { "beat": 4, "move": "reach", "variant": "upRight" },
      { "beat": 5, "move": "reach", "variant": "upLeft" },
      { "beat": 6, "move": "dip" },
      { "beat": 7, "move": "wave", "variant": "both" }
    ]
  },
  "charts": {
    "light":  { "notes": [ { "beat": 16, "move": "stepTouch", "side": "right" },
                           { "beat": 18, "move": "clap", "variant": "mid" } ],
                "hookPattern": { "neonThumkaHook": [0, 2, 4, 6] } },
    "groove": { "notes": [ ] },
    "toofan": { "notes": [ { "beat": 33.5, "move": "clap", "variant": "mid" } ] }
  },
  "highlight": { "preferSection": "hook2", "lengthBeats": 30 },
  "calls": { "locale": ["en-IN", "hi-IN", "gu-IN", "pa-IN"] }
}
```

### 6.1 Schema rules
- Beats on a 0.5 grid; a 0.25 grid only on `toofan` and only for `clap`/`wave`. `side` is required for
  stepTouch/reach/wave/twist (except `twist: any`). `move` comes from a closed enum. Jumps are not in
  the enum (`hop` is allowed only with `"requiresJumps": true` and gets an auto calf-raise substitute).
- Hooks are referenced, not copied: `hookPattern` picks which beats of the 8-count are scored at
  that difficulty (Light scores 4 of 8, Groove 6, Toofan all 8), so all three difficulties dance
  the *same* routine.
- `scored: false` sections must exist: ≥ 15 s per 60 s (Gentle) or as set by the band (§7).

### 6.2 Linter + simulator (packages/game_director, deterministic)
Fails the build if any chart × band × low-impact combination breaks:
- min gap between scored cards: 500 ms for small moves (clap, wave), 750 ms for big moves (step,
  reach, twist), 1000 ms for a dip (Active); Balanced ×1.25, Gentle ×1.5 (the director drops
  violating cards deterministically, keeping beat-1 cards first);
- dip caps: ≤ 4 in a row (Gentle), 6 (Balanced), 8 (Active), then ≥ 4 beats of small moves;
  ≤ 10 / 14 / 20 dips per minute;
- twist ≤ 8 per 16 bars on Gentle;
- **a simulated bot** with N(0, 45 ms) timing jitter, +30 ms bias, 3 % dropped onsets and one
  2-s tracking dropout must reach ≥ 3★ on every chart in its band. A "slow bot" (late +120 ms)
  must reach ≥ 2★ on Light/Gentle.

### 6.3 Pacing targets per difficulty
| | Light | Groove | Toofan |
|---|---|---|---|
| Scored cards per minute | 18–28 | 30–44 | 46–66 |
| Move families per song | 3 | 4–5 | 6–7 |
| Off-beat cards | 0 | ≤ 5 % | ≤ 15 % |
| Card approach (visible lead) | 6 beats, ≥ 2.0 s | 5 beats, ≥ 1.6 s | 4 beats, ≥ 1.3 s |
| Voice call | beat −1 | beat −1 | beat −1 (only for new or switching moves after the first hook) |

---

## 7. Difficulty, bands and safety

The bands are the existing optional presets: **Gentle (50+, the default when none is picked),
Balanced (31–50), Active (18–30)**. We never ask for age or infer it from the camera. The band sets
the ceilings, and difficulty picks a value inside them.

| | Gentle | Balanced | Active |
|---|---|---|---|
| Default difficulty | Light | Light → Groove after 3 clean songs (suggested, never automatic) | Groove |
| Timing windows | widest (§4.2) | middle | standard |
| Max cards per minute | 30 | 44 | 66 |
| Big moves per minute max | 12 | 18 | 26 |
| Breather | ≥ 15 s per 60 s | ≥ 12 s per 75 s | ≥ 10 s per 90 s |
| Low-impact | locked on (confirm twice to change) | on | on, easy to turn off |
| Dip depth | 25 % | 30 % | 35 % |
| Songs before a "take a break" card | 3 | 4 | 5 |

Safety: no jumps by default; no floor touches; twists keep the hips forward; space ≥ 2 × 2 m per
player. A **tile/marble floor tip** (common in Indian homes): "Barefoot or grippy shoes — no socks on
tiles." Party competition ranks by accuracy, never by speed or count, so nobody gets pushed past
comfort.

---

## 8. Modes

### 8.1 Solo
Song select → quick calibration (existing, plus Taali Check once per route) → song → results
(accuracy, stars, best combo, moves count, party minutes) → clip offer → next song.
**Practice the Hook:** the chorus 8-count at 75 % tempo, with spoken breakdowns ("Step, clap, step,
clap, reach, reach, dip, wave") and no score. Free on every song you can access.

### 8.2 Ghar Party (tag-in party, 2–8 players)
The phone stays on the floor, so "pass the phone" really means **swapping the spot**.
- Each guest picks a nickname, colour and band (a session-only guest profile; nothing else is
  stored, and there are no accounts for guests). On first tag-in there's a 6-s mini-calibration
  (stand 2 s, arms up 1 s, one dip); saved household profiles skip it.
- **Relay:** one song, players rotate every 16 bars. The game plays a 2-bar vamp handoff ("Next up:
  Priya — step in!"); the leaving player is detected by tracking loss (which never costs anything),
  and the new player by the quality gate passing.
- **Battle:** everyone dances the same 45-s hook segment, and the ranking is by accuracy %.
- **Teams:** 2 teams, alternating rounds, team accuracy averaged.
- The end screen gives a "Party MVP" card and fun awards ("Taali Titan", "Steady Steps",
  "Toofan Trigger") as a share image.
- The product is adults 18+. The party copy says "house party with friends and family (18+)", the art
  style is adult-leaning (not cartoon-kiddy), and nothing is child-directed (Google Play
  Families-policy risk, §14).

### 8.3 Jodi (2 players in the same frame), capability-gated
- MediaPipe Pose Landmarker with `numPoses = 2`. **Gate:** a 10-s device test must sustain ≥ 20 fps
  with both bodies passing the quality gate (each body height ≥ 35 % of the image and ≥ 256 px);
  otherwise the mode offers Relay instead.
- Framing: **landscape**, players 2.7–3.0 m from the phone, at least 1 m apart. On-screen floor
  zones show "Player 1 stand here / Player 2 stand here" (a front camera at about 65–70° horizontal
  FOV covers about 3.4 m wide at 2.5 m).
- Identity: MediaPipe gives no person IDs, so we assign by hip-centre continuity (nearest neighbour,
  max jump 0.25 image width per 100 ms, with hysteresis). The choreography never asks players to cross:
  P1's steps go to *their* left and P2's to *their* right ("mirror charts", generated
  deterministically from the base chart).
- No contact moves (no high-fives): merged bodies confuse detection and add collision risk.
  Instead, **Jodi Sync**: both players Perfect on the same card gives +50 % and a sparkle link
  between avatars. A Sync streak of 8 triggers a shared Toofan Time.
- Rule 5 per player: if one player is lost, only that player's cards skip. If both are lost, Groove Hold.
- Thermal budget: Jodi songs are capped at 3 in a row, then a 60-s cool-down card (also good for the phone).

---

## 9. Progression and rewards (cosmetics only, all earned)

- **Taal XP** per song = 100 × accuracy × difficulty factor (Light 1.0, Groove 1.3, Toofan 1.6) +
  25 per star. **Dancer Rank 1–50**, with titles: Naya Dancer (1) → Thumka Starter (5) → Taali Pro (10)
  → Dhol Champ (20) → Raas Royal (30) → Toofan Star (40) → Taal Legend (50). The curve: rank n needs
  250 + 50n XP, so rank 50 takes about 75 hours of play.
- **Unlocks (cosmetics, original designs):** avatar outfits (mirror-work jacket, phulkari-inspired
  dupatta pattern, kediyu-inspired top, neon streetwear, wedding-sangeet sherwani-style jacket),
  hand trails, card skins, stage floors (mirror-work, kite sky, neon street), hit sounds (dhol,
  tabla, clap), **freeze-pose emotes** (used in clips) and clip frames.
- **Song mastery:** 5★ per difficulty plus a "Hook Mastered" badge (≥ 90 % Perfect in the hooks).
- **Weekly Hook Challenge:** 7 small tasks (e.g. "5★ the hook of Chakri Chal", "throw a 3-player
  party") → one weekly cosmetic. It's free, and there's no paid pass.
- **Streak:** any ≥ 3-min Taal session counts toward the existing IST daily streak (same 2 shields a month).
- Event cosmetics are earned during the window only and are **never sold** (existing rule).

---

## 10. Highlight clip (15 s for Reels/Shorts), privacy by construction

AGENTS rule 2 forbids storing camera frames, so **clips are never camera video**. They're rendered
from landmarks only:
- **Styles:** *Normalised Avatar* (default: joint angles retargeted onto a standard-proportion
  character, so the clip reveals nothing about the player's body shape), *Silhouette* (a
  pattern-filled shape from their own proportions, opt-in) and *Neon Lines* (a glowing stick figure).
- **Recording:** a landmark ring buffer during the song (33 points × 4 floats × 30 fps × 15 s
  ≈ 240 KB in RAM). The window is the hook (`highlight.preferSection`), or else the 15 s with the
  highest Perfect density. It ends on the freeze pose.
- **Render:** on device, offscreen Flame render → MediaCodec H.264, 1080×1920 at 30 fps, about 8 Mbps
  (about 15 MB), using the song's original audio (we own it). Overlays are the song title, the hook-step
  name, combo pops and an optional nickname and score (off by default). The watermark reads "Taal
  Toofan · MotionQuest" with no link and no payment mention.
- **Consent:** opt-in per clip. The first time, a screen explains: "Made from your movement points,
  not your camera. We don't upload anything; you choose where to share." Sharing goes through the
  Android share sheet only. The clip file sits in app cache and is deleted after 24 h unless the player
  taps "Save to gallery". Metadata is stripped. In Jodi, both avatars are normalised and unnamed
  by default.
- A real-camera clip option is **out of scope**. It would need a product and legal change to rule 2;
  recommendation: don't do it.

---

## 11. Social and viral loop

1. **Hook step as a challenge:** each song's 8-count is designed to be repeatable without the app.
   The weekly hashtag is #TaalToofan<SongName>.
2. **Original audio in the Reels and Shorts audio libraries:** we distribute our songs through a
   distributor that lists them for "Use this audio", and **whitelist our own channel and users**
   rather than claiming them (no Content ID claims against players). Any creator using the sound
   then advertises the game.
3. **Duel links (async):** "Beat my 87 % on Neon Thumka (Groove)". The deep link carries only the song,
   difficulty and score (plus a display name if signed in) and opens the Play listing if the app isn't
   installed (Play Install Referrer for attribution). The server stores the score only.
4. **Party MVP cards** (images) after Ghar Party.
5. **Gym crews:** partner gyms host "Crew Raas Nights" during Navratri with an opt-in crew
   leaderboard (existing gyms module and consent rules: first name and summaries only).
6. **Invite reward:** both players earn an exclusive (non-purchasable) hand trail after the friend
   finishes 3 songs. Nothing is tied to payment.

---

## 12. Festival events calendar (windows are server config; dates verified each year against an almanac)

| Event | Approx. window | Pack | Theme / notes | Access |
|---|---|---|---|---|
| **Sangeet Season** | Nov 15 – Feb 15 (wedding season) | 3 wedding-sangeet pop songs + "Family Hook" | Learn a hook for your cousin's sangeet; Ghar Party focus | Premium (1 song in Beat of the Day rotation) |
| **New Year Countdown Party** | Dec 26 – Jan 4 | *Midnight Masti* + countdown remix (the last 10 beats are a move countdown) | Neon party; **no alcohol imagery** | Premium |
| **Patang / Harvest Beats** (Uttarayan, Lohri) | Jan 10 – Jan 18 | *Patang Pe Dil* (kites, Gujarat-first) + a Bhangra harvest track | Kite sky floor; reach-heavy charts ("pull the kite string") | Premium |
| **Holi Colour Clash** | Holi weekend ±4 days (Mar 2027) | *Gulaal Groove* + colour-burst remix | Every Perfect sprays colour on the stage; high-contrast palette; shapes carry meaning (colour-blind safe) | Premium |
| **Jodi Week** (Friendship Day) | First week of Aug | Duet-charted songs | Promotes Jodi mode | Free charts on free songs |
| **Navratri Raas Nights** (tentpole) | 9 nights + 2 encore days (late Sep – Oct 2027) | 3 Raas-family songs, a new one unlocking each 3rd night; nightly "Raas round" with 3 accelerating rounds | Gujarat/Ahmedabad-first rollout flag (like Garba Quest); mirror-work and geometric dance floors; no religious imagery; Gujarati and Hindi calls | **Free** (it is the one free festival event, consistent with Garba Quest) |
| **Diwali Roshni Rush** | Diwali week (late Oct/Nov) | *Roshni Rush* + lights remix | The stage lights up string by string as stems build. **No firecrackers or bangs**; soft bells | Premium |

Rollout: closed beta Jan 2027 (Patang Beats as the test event) → public launch for **Holi 2027** → the
tentpole is **Navratri 2027**. Diwali 2026 (8 Nov) is too close to ship for.

---

## 13. Free vs Premium (same subscription: ₹129/month, ₹699/year, Google Play Billing only; gym members get it free)

| | Free | Premium |
|---|---|---|
| Songs | 3 evergreen (one per family: *Chakri Chal*, *Dhol Express*, *Neon Thumka*) + Chill Chai + **Beat of the Day** (one premium song free per day, rotating) | Full library (12 at launch, +2 a month) |
| Difficulties, Practice the Hook | All | All |
| Ghar Party | Relay and Battle, up to 4 players, free songs | Up to 8 players, Teams, custom setlists |
| Jodi (if the device qualifies) | On free songs | All songs |
| Highlight clips | Yes, all styles, same watermark | Same + extra clip frames earned through play |
| Festival events | Navratri Raas Nights | All other events |
| Cosmetics | Earned (never sold) | Earned (never sold); more sources via more songs |
| Ads | None | None |

There are no in-app links or nudges toward payment outside Play. The store page shows only the
standard Play subscription.

---

## 14. Metrics (targets)

**Detection and timing (release gates, replay-tested):**
- Recall on labelled replay clips: ≥ 95 % for clap, step, dip, reach and raise arms; ≥ 90 % for wave
  and twist-any; ≥ 85 % for twist-signed (otherwise it stays Toofan-only/off).
- False onsets during free dancing ≤ 1 per minute per move.
- After Taali Check, across a 10-device matrix (Redmi Note, Samsung A-series, Realme, Moto G, Pixel a):
  median \|timing error\| ≤ 40 ms, p95 ≤ 120 ms.
- 1P ≥ 24 fps on Helio G85/Snapdragon 680-class phones with 4 GB RAM; Jodi ≥ 20 fps; 20-min session
  with no drop below 20 fps from thermal throttling; ≤ 8 % battery per 20 min.
- "Did the game miss a move you made?" post-song yes-rate ≤ 8 %.

**Product:**
- D1 ≥ 35 %, D7 ≥ 15 %, D30 ≥ 6 % for players who enter Taal Toofan.
- ≥ 3 songs per session; median session ≥ 9 min.
- ≥ 25 % of event-month sessions are Ghar Party or Jodi; average party size ≥ 3.
- Gentle Light completion ≥ 90 %.
- Clips generated on ≥ 10 % of completed songs; shared on ≥ 3 %; viral K-factor from clips and
  duels ≥ 0.15 during Navratri.
- Premium conversion of Taal players ≥ 4 % in the event month; Beat-of-the-Day plays ≥ 30 % of free DAU.
- Zero cultural/religious-content complaints escalated. Break-card shown-to-dismissed ratio is tracked.

---

## 15. Risks and mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| **Bluetooth party speakers** (common in Indian homes) add 150–300 ms of variable latency | Feels "always late" | Per-route Taali Check, Bluetooth default +220 ms, phone-speaker tip, wide late windows, stems change on bar lines |
| Low-end fps / jitter | Unfair misses | Sensor timestamps + interpolation, fps-scaled windows, mode hidden below 15 fps |
| Clap occlusion and blur | Missed claps | Closing-speed rule, wrist+index midpoint, recorded-data tuning; never use the mic |
| Twist unreliable in 2D | Frustration | "Any" direction default; signed twist only past the recall gate |
| **Cultural/religious sensitivity** (Garba is devotional for many) | Backlash | "Festival-inspired" framing, no deities or devotional lyrics or temples, Gujarati and Punjabi cultural advisors, Ahmedabad-first rollout with feedback |
| **Music soundalikes / copyright** | Takedowns, Reels muting | Original commissions with full buyout, musicologist review, distributor whitelist, no Content ID claims on users |
| Minors joining family parties / Play Families policy | Policy breach | 18+ positioning and copy, adult-leaning art, guest profiles store nothing, extra bodies trigger Groove Hold |
| Collisions in small rooms (Jodi, parties) | Injury | Floor zones, ≥ 1 m apart, no crossing or contact moves, 2 × 2 m per player prompt, tile-floor tip |
| Overexertion from competition | Injury, churn | Accuracy-based ranking, no fail, band caps, break cards, chill-out sections |
| Thermal/battery with 2 poses | Fps collapse | Capability gate, 3-song cap, Lite model in Jodi |
| Spam/mash exploits | Unfair scores | Anti-mash cap; leaderboards are friends and gym only |
| Highlight clip privacy expectations | Trust | Landmark-only render, normalised avatar default, per-clip opt-in, 24-h cache delete, share sheet only |
| Scope (6 new recognisers + audio clock + renderer) | Delay | Phase it: M0 clap + step + judge + replay tests → M1 6 moves, 3 songs, solo → M2 Ghar Party + clips → M3 Jodi (gated) → M4 events. Tests first in `motion_core` per AGENTS.md |

---

## 16. Repo mapping (proposal only; nothing has been implemented)

- `native/pose_bridge`: pass the sensor timestamp through (it may already be in the landmark
  timestamp; verify the time base), add a `numPoses` option (1/2), and expose a low-latency audio
  clock (AAudio/Oboe or `AudioTrack.getTimestamp`) to Dart. Frames stay native.
- `packages/motion_core`: a `RhythmRecognisers` set (off by default, like `extra_recognisers.dart`)
  emitting `MoveOnset` with interpolated hit times, plus a low-lag feature path; tests first plus
  recorded clips per move.
- `packages/game_director`: `RhythmChartLoader`, `RhythmJudge` (pure, deterministic windows/bias/
  offset), `ChartLinter` + bot simulator (§6.2), band modifiers reused.
- `content/rhythm/` + `content/schema/rhythm-chart.schema.json`; extend `content:validate`; server
  content module serves event songs inside their windows only.
- `app/`: a Flame "festival stage" scene (avatar from landmarks, flying cards, stem mixer, Groove
  Hold), Ghar Party/Jodi flows, and the clip renderer (MediaCodec) + share sheet.
- Docs to update on acceptance: `docs/game-design.md` (windows, thresholds), `docs/architecture.md`
  (audio clock, clip pipeline), `docs/security.md` (clip privacy controls).
