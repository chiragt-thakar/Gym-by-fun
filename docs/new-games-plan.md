# New game modes plan: Craftguard Duels (A) and Taal Toofan (B)

> **Implementation note (2026-11-09):** a first playable version of the games in this document now ships in the app (v2). See [progress.md](progress.md) for what was built, what deliberately differs, and what is still open; rules live in [game-design.md](game-design.md#arcade-games-v2-2026-11-09).

Status: **proposal, nothing implemented** (2026-11-05). This plan stands on its own. It reconciles the five
research notes (market, exercise science, tech feasibility, Game A draft, Game B draft) with AGENTS.md,
`docs/game-design.md`, `docs/stages-roadmap.md` (§3 moves, §5 bosses, §6 bands, §7 access) and
`docs/qa/5-motion-levels.md`. Wherever the notes disagreed, the decision made here applies.

**Names.** Both drafts began with "Taal", so one has been renamed:
- **Game A: Craftguard Duels** (short: *Craftguard*). This was "Taalbound". It is a guardian rhythm duel.
- **Game B: Taal Toofan.** It is a rhythm dance party game. Fallback names: *Beat Baraat*, *Naach Pulse*.
- Run a trademark search for both names (India TM Registry classes 9, 28 and 41, plus a Play Store
  search) before any public use. Until then they are working names.

**Binding constraints (AGENTS.md rules).** Rule 1: real pose input only. Rule 2: no camera frames are stored
or uploaded. Rule 3: only the latest frame is processed. Rule 4: only landmarks reach Dart. Rule 5: a tracking
failure never costs anything. Rule 6: a move counts only against something that is live. Rule 7: content is
JSON. Rule 8: the director is deterministic. Rule 9: no jumps by default. Rule 10: original assets only.
Rule 11: payments through Play only. Players are 18+ only. The games are general fitness, never medical.

---

## 1. Executive summary

1. **Why these two.** The camera-fitness formats that last pair a mechanic you can read in one second with a
   long-term layer. Examples: Ring Fit's RPG, Fitness Boxing's daily loop, rhythm plus leaderboards in Beat
   Saber and Just Dance, and party play on Nex. A boss **duel** (A) and a **dance party** (B) cover the two
   strongest of those layers (§2.1). The runner covers neither.
2. **A in one line.** An original craft-construct guardian (a stepwell, a kite pair, a brass peacock) attacks on
   an audible **4-count**. You duck, lean, guard or brace on "5". Clean answers break its Poise, then you land
   **side pads** and raise your arms to *calm* it. Guardians are calmed, never killed.
3. **B in one line.** Move cards land *on your body zone* on the beat. Each move family adds an instrument stem,
   so you build the band. Every song has one learnable **hook step**, which is what people take into Reels and
   wedding sangeets.
4. **Both are audio-first.** Kavi calls the count ("ek, do, teen…"). The phone sits on the floor 2 m away, and
   the player's eyes can stay on the room.
5. **One engine for both.** A shared `BeatEngine`, `BeatClock`, `TimingWindows` and `BeatDirector` run both
   modes from **level schema v2**. A `oneOf` on `schemaVersion` keeps all 18 v1 levels valid without changes.
6. **Tracking-honest.** Punch pads sit **≥ 30° out to the side, and in practice 60–90°**, because forward
   punches cannot be told apart from a front camera. Recognisers fire on **end pose** (2-D reach plus elbow
   angle), never on speed. Timing is judged on **camera capture timestamps** minus a per-device offset, using
   **one window table per band**, the same for both games.
7. **Forgiving by construction.** Rhythm targets never cost lives. Only telegraphed hazards in A do, at most
   1 Spark per 2 s. A tracking loss freezes the combo and pauses the guardian, or loops a vamp in B. B songs
   always finish.
8. **Private sharing.** 15 s highlight clips are rendered **only from landmarks**, using a normalised avatar.
   They never contain camera video. The player opts in for each clip and shares through the share sheet only.
9. **India-fit business.** Both modes use the existing Premium subscription (₹129/month, ₹699/year, Play
   Billing; gym members get it free). Free tiers are generous (2 guardians, 3 songs plus a daily rotation,
   and the Navratri event). Cosmetics are earned and never sold. Festival packs are data, not code.
10. **Build order.** M0 fixes the QA5 raise-arms and silent-miss bugs and adds capture timestamps. M1 is the
    shared beat foundation. M2 is a Craftguard slice. M3 is a Taal Toofan slice. M4 adds social and meta. M5
    adds content scale and events. Taal Toofan's public launch target is **Holi 2027**; its tentpole is
    **Navratri 2027**.

---

## 2. Research findings

### 2.1 Market

| Finding | Design consequence | Source |
|---|---|---|
| Nex Playground sold more than 650k units in 2025. Its most-played titles are short, readable and social (Mirrorama is #1) | One obvious verb per mode, social play | [BusinessWire CES 2026](https://www.businesswire.com/news/home/20260105396416/en/Nex-Playground-Showcases-Future-of-Active-Play-at-CES-and-an-Early-First-Look-at-its-2026-Product-Roadmap), [Nex top-10 (company blog)](https://www.nexplayground.com/blog/the-top-10-nex-playground-games-of-2025) |
| Ring Fit (more than 10M sold) holds players with RPG progression and 15–30 min sessions | Guardian roster plus Trophy Shelf (A) | [CPG](https://consolepcgaming.com/nintendos-ring-fit-adventure-has-managed-to-sell-over-4-million-copies) (secondary source) |
| Fitness Boxing 3 uses a daily workout, missions and small tasks that keep a streak alive. Critics dislike moves gated behind chores and compulsive prompts | Daily Taal and Beat of the Day, with no chore gating | [TechRadar](https://www.techradar.com/gaming/fitness-boxing-3-your-personal-trainer-review), [Siliconera](https://www.siliconera.com/review-fitness-boxing-3-remains-a-good-exercise-game/) |
| Just Dance's phone-camera mode is praised, but it is **solo-only**, and its subscription locks the back catalogue | Party relay from day one, plus a rotating free song | [TechRadar JD2026](https://www.techradar.com/gaming/just-dance-2026-edition-review) |
| VR fitness content is costly to keep fresh: Meta stopped new Supernatural content in Jan 2026 | Content is JSON plus stems, at a planned cadence | [Road to VR](https://www.roadtovr.com/meta-spins-out-supernatural/) |
| Kinect and Wii faded once novelty and tracking precision ran out | Generous windows, end-pose detection, honest feedback | [Contains Moderate Peril](https://www.containsmoderateperil.com/blog/2018/5/4/motion-control-gaming) |
| Mobile sessions: median about 5–6 min, top tier about 8–9 min | About 3 min rounds, chained into 9–15 min sessions | [GameAnalytics 2025](https://gameindustrylibrary.com/documents/gameanalytics-mobile-gaming-benchmarks-2025) |
| India discovery runs through social (58.7 %), short video (46.6 %) and influencers (45.3 %). Reels is the default feed | A private, shareable clip, plus original audio in the Reels library | [Niko via Outlook Respawn](https://respawn.outlookindia.com/amp/story/gaming/gaming-news/niko-partners-why-its-time-to-enter-indias-gaming-market), [afaqs](https://www.afaqs.com/news/digital/five-years-of-reels-how-instagrams-algorithm-became-indias-tastemaker-10464781) |
| ARPU is about $2–3, small payments are normal, and 80 % pay with UPI | Low Play subscription price, no paid currency | [Business Today](https://www.businesstoday.in/tech-today/news/story/non-rmg-games-set-to-surge-in-india-3-in-4-gamers-already-spending-arpu-just-3-says-report-496006-2025-09-27) |
| Women are 26–45 % of Indian gamers (estimates vary) | Dance mode is a broad-appeal priority | [Lumikai via Outlook Respawn](https://respawn.outlookindia.com/gaming/gaming-news/lumikai-women-now-make-up-45-of-indias-gamers) |

Caveats: none of these products publishes independent retention data. Fitness-game virality through Reels is an
**untested hypothesis**, so measure it (§4.12).

### 2.2 Exercise science (general fitness information, not advice)

| Finding | Consequence | Source |
|---|---|---|
| Active video games usually reach light to moderate intensity, with wide variation. Dance and boxing games run higher | Describe intensity in talk-test terms only, and never show METs or kcal | [AVG umbrella review 2025](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12666624/) |
| Zumba-style dance measured about 6.6–8.8 METs in young women, but our low-impact, camera-paced dance will be lower | Play-test it and promise no number | [Luettgen et al., JSSM 2012](https://jssm.org/jssm-11-357.xml-Fulltext) |
| Shadow boxing has almost no direct data, and the pad-boxing data is from trained volunteers | Treat punch intensity as a design target only | [Boxing intensity](https://pmc.ncbi.nlm.nih.gov/articles/PMC6315673) |
| No controlled study of Garba intensity exists (one thin Indian study) | Raas rounds are self-paced, with BPM capped by band | [Garba study](https://pdf.ipinnovative.com/pdf/9575) |
| WHO 2020: 150–300 min/week of moderate activity, muscle strengthening ≥ 2 days a week, and "some activity is better than none" | The only weekly framing used in copy | [WHO 2020, BJSM](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7719906/) |
| Session structure: warm-up, then conditioning, then cool-down. Beginner work:rest of 1:1 to 1:2 | 45 s warm-up and cool-down, breathers by band | [ACSM 2011 (Garber)](https://digitalcommons.uri.edu/kinesiology_facpubs/137), [home HIIT work:rest](https://researchonline.ljmu.ac.uk/id/eprint/14969/) |
| Repetitive arm swinging is the most common overuse pattern in exergames | A soft-elbow cap (elbow ≥ 145°, never 180°), ≥ 700 ms between punches, flurries ≤ 20–30 s | [Exergame injuries](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12014968/) |
| 2024 Adult Compendium (Herrmann et al.) replaces the 2011 edition | Add source key `MET24` (values are internal design targets only) | [Compendium 2024](https://pmc.ncbi.nlm.nih.gov/articles/PMC10818145/) |
| Google Play Health apps declaration plus a "not a medical device" disclaimer. ASCI enforces weight and health claims | Wording rules in §5.5. Legal review before launch | [Play Health apps](https://support.google.com/googleplay/android-developer/answer/14738291), [ASCI](https://indiantelevision.com/mam/60-of-61-nutraceutical-ads-breach-asci-code-report-finds/) |

### 2.3 Tech feasibility (MediaPipe Pose Landmarker Lite, single front camera, 2–2.5 m, budget phone)

| Item | Verdict / number | Source |
|---|---|---|
| BlazePose PCK@0.2: Full 84.1, Lite 79.6. Lite is weaker on wrists and ankles | Judge wrists by **zones relative to the torso**, not fine angles | [BlazePose arXiv 2006.10204](https://arxiv.org/pdf/2006.10204) |
| Normalised z has no consistent scale, and one 2-D projection fits many 3-D poses | **Never threshold absolute z.** At most, use the sign of relative L/R shoulder z as a tie-breaker | [arXiv 2512.06783](https://arxiv.org/pdf/2512.06783) |
| Motion blur at 15–30 fps: no tested pose model was robust to it | **End pose, never velocity** | [arXiv 2303.04566](https://arxiv.org/pdf/2303.04566) |
| Forward punch toward the camera: 2-D reach *shrinks* to about 0.2–0.5, the same as barrier hold | **Not reliable as a move.** Pads go to the side | 3-tech §2 |
| Side or diagonal-out punch, guard, knee lift, side step, raise arms | Reliable | 3-tech §2 |
| Twist: magnitude reliable, direction ambiguous | "Any direction" by default | 3-tech §2 |
| Clap: contact lasts 50–100 ms, which is 0–1 frames at 15 fps | Medium-low. Detect it as approach then close on any frame, ≤ 1 clap per beat | 3-tech §2 |
| Pipeline latency (budget tier): exposure 30–60 ms + inference 30–40 ms + bridge/filter 5–15 ms + 1 confirm frame ≈ **110–180 ms**, jitter ±1 frame | Judge on **capture time**, not arrival time | 3-tech §1 |
| Exergames tolerate more latency than competitive play (≤ 150 ms is acceptable for competitive) | Wide, late-biased windows | [arXiv 2507.06669](https://arxiv.org/pdf/2507.06669) |
| Bluetooth audio adds 150–300 ms | Offset per audio route | 5-game-b §4.1 |
| **The repo stamps frames with `SystemClock.uptimeMillis()` in `PosePipeline.analyze()` (line 170), not the sensor time**, and `RunEngine.input` uses arrival `_wallMs` | M0 adds `captureTsUs` from `ImageProxy.imageInfo.timestamp` | Code read |

---

## 3. Game A: Craftguard Duels

### 3.1 Pitch and pillars
You stand 2 m from the phone. An original craft-construct guardian wakes and attacks to an 8-beat groove. Each
attack is counted in ("ek… do… teen… char… **DUCK!**"). Answering cleanly fills its **Poise** bar. When Poise
breaks it **staggers**: glowing **side pads** open for controlled punches, then a **Charge** (raise arms) fills
the Calm bar. Fill 3 phase bars and the guardian is calmed and becomes a figurine on your Trophy Shelf.

The five pillars:
1. **Readable by ear.** Every attack uses the same 4-count.
2. **Fair by construction.** One ask at a time, fixed lead times, no speed bonus.
3. **Punchy feedback.** Feel comes from rendering (hit-stop, shake on your own hits) and adaptive music layers.
4. **Short.** 3:00–5:00 per duel, with phase checkpoints.
5. **Calm, not kill.** Nothing is destroyed.

### 3.2 Core loop
```
PHRASE (8 beats, the unit of design)
 beat 1      TELEGRAPH  wind-up + 3-pulse rising tone + glyph + voice "ek"
 beats 2..L  COUNT      "do… teen… (char…)"; glyph grows. L = lead beats (§3.6 rule)
 beat L+1    IMPACT     answer: duck / lean / guard / brace (hazard, may cost a Spark)
 beat L+3    COUNTER    optional side pad after a successful answer (never damages)
 last beat   RECOVER    nothing is asked (guaranteed rest)
CYCLE  = 3–6 attack phrases → STAGGER (Poise ≥ 100 or fallback) → OPENING (2–4 pads) → CHARGE → Calm +
PHASE  = 1–3 cycles;  DUEL = 3 phases + Calm finale (the final guardian has 4)
```
The 8-beat phrase grows to 9 or 10 beats when the lead extends. The director stretches the phrase. It never
shortens the recover beat.

**Rule 6 (game state decides).**
- A punch does nothing unless a pad on that side is live.
- Raising the arms does nothing unless a Charge orb is live.
- A guard does nothing outside a strike window.
- A duck with no beam live is ignored, with no "too early" penalty and no nagging.

### 3.3 Moves and encounters

| Kavi says | Move (recogniser) | Encounter (v2 `type`) | Damages | Demanding | Judged by | Low-impact answer |
|---|---|---|---|---|---|---|
| "Duck!" | squat | `beam` | yes | yes | squat held at impact ± squat grace (existing rule) | half squat 45 % |
| "Left!" / "Right!" | lean L/R (side step if enabled) | `dodge {side}` (single-side `laneBlock` semantics, no lanes) | yes | no | lean active at impact | lean |
| "Guard!" | guard (new) | `strike` | yes | yes | guard held ≥ 70 % of the impact window (600 ms × hold scale, 900 ms assist) | one hand |
| "Brace!" | barrierHold (exists, opt-in) | `pushWall` | yes | yes | held ≥ 70 % of `holdMs` × hold scale | `barrierOneHand` |
| "Strike left/right!" | punch L/R (new, **side pads only**) | `pad {hand, zone:"side"}` | **no** | no | onset grade (§5.2 windows) | reach 0.60, elbow ≥ 130° |
| "Charge!" | raiseArms (Q5-fixed) | `charge` | no | no | onset grade; hold 450/540/600 ms by band | one arm |
| bonus chime | raiseArms | `orb` | no | no | onset grade | one arm |

Jumps and calf raises are never used.

**Pad geometry (the forward-punch fix).**
- Projected 2-D reach is roughly `sin θ`, where θ is the angle between the arm and the camera axis.
- With the default reach threshold of 0.75, a punch only registers at θ ≥ 49°. With the low-impact threshold
  of 0.60, it registers at θ ≥ 37°.
- So pads are **drawn at 60–90° out to the player's side** (the avatar's left and right thirds at shoulder
  height). **No authored pad may sit closer than 30° to the forward axis**; the content validator enforces this.
- Only one zone ships, `side`, with the wrist at shoulder height ±0.3 torso. A high diagonal zone would
  collide with raise-arms (wrist above the nose), so it stays out unless recorded data proves otherwise.

**"Duel Stance" calibration add-on (about 20 s, once, re-run from Settings).**
1. Left arm out to the side, held 0.5 s, then the right arm (records `armLengthL/R`).
2. Guard held 1 s (records `guardWristNoseTorso`).
3. The shared **Beat Sync** (§6.4) if the device has no offset for the current audio route yet.

### 3.4 Systems

| System | Rule |
|---|---|
| **Sparks** (lives) | 3 in every band. A hit costs 1, and **at most 1 is lost per 2.0 s**. Gentle **Glancing grace**: a hazard answer that starts ≤ 150 ms after the window closes costs no Spark and adds no Poise. 0 Sparks → **Regroup** (§3.8) |
| **Grades** | Perfect / Good / OK / Miss, using the shared band table (§5.2). Base points: beam 100, dodge 100, strike 125, pushWall 125, pad 75, charge 150, orb 50. Perfect ×1.25. Holding longer earns nothing |
| **Combo** | +1 per successful answer or pad. A hit resets it to 0. A missed pad or tracking pause **freezes** it. Multiplier +10 % per 5 combo, max ×2.0 at combo 50 |
| **Music layers** | Combo 0–4: drums. 5–9: + drone. 10–19: + pluck. 20–34: + flute synth. 35+: full mix plus a crowd "haa!" on Perfects. A hit drops one layer. Layer changes land on **bar lines** |
| **Poise** | Range 0→100. Answer Perfect/Good/OK = 25/20/15. Counter pad +10. Guard deflect +5 bonus. Stagger at ≥ 100, or **fallback opening** when the cycle's script runs out |
| **Opening** | 2 breather beats (1.5–1.8 s) → pads (Gentle 2, Balanced 3, Active 3, and a 4-pad flurry only on Active-advanced phase 3) → Charge orb. Pads are 2 beats apart and never < 700 ms apart (beginner ≥ 1000 ms) |
| **Calm gain** | Pad 20 % of the phase segment, Charge 40 %. Full stagger ×1.5, fallback ×1.0. If the segment isn't full, Poise resets to 50 |
| **Surge** | Range 0→100. +15/+10/+5 per Perfect/Good/OK. When full, the next Charge becomes the **Surge Finisher**: arms held 450/540/600 ms fills the whole segment. It is never required |

### 3.5 Guardian template and roster
Each guardian is a v2 level with `mode: "duel"` (§6.6). Every guardian must pass this checklist:
- A named telegraph with a sound that is unique to the guardian but stays in the right encounter family.
- Phase 1 has 2 attack types. Phase 2 adds 1. Phase 3 combines them.
- Every attack has a low-impact answer.
- The silhouette reads at 48 px, and the wind-up moves ≥ 15 % of screen width.
- A culture review passes (craft, architecture, nature, railways only; no deities, temples, ritual objects or
  devotional music).
- The slow bot finishes on Gentle + beginner + low-impact.

| # | Guardian | Tier / access | Look | Attacks (encounter → telegraph) | Phase-3 twist | Calm | First-calm cosmetic |
|---|---|---|---|---|---|---|---|
| G1 | **Baoli Warden** | 1, Free (tutorial) | A stepwell giant with jaali eyes | Step Sweep (beam: steps light bottom→top, clay-pot rising tone); Ledge Drop (dodge: stair-arm glows on the slam side, two knocks); Stone Fist (strike, phase 2: double drum + shield glyph) | Mirrored repeat of the phase | Sinks into turquoise water | Sandstone figurine, "Stepwell Teal" trim |
| G2 | **Patang Twins** | 1, Free | Magenta and ochre paper-kite spirits on a glowing string | String Cut (dodge: string tightens on one side); Dive (beam: falling whistle); Tangle (pushWall, phase 2: knot wall 1.5 s × hold scale) | Mirrored twin telegraphs 1 phrase apart (anticipation, not speed) | Fold into paper birds | Kite-tail scarf |
| G3 | **Brass Mayur** | 2, Premium | Dokra-style brass peacock automaton | Fan Flash (strike: 3 brass dings, a gold glint with ≤ 3 flashes/s per WCAG 2.3.1); Feather Volley (dodge); Tail Sweep (beam) | "Display": guard → counter → duck → counter | Folds its fan | Brass-feather pad VFX |
| G4 | **Lattoo Titan** | 2, Premium | Channapatna-style lacquered top, 4 m tall | Spin Charge (dodge, rising whirr); Wobble Slam (strike: two wobbles then a thud); Stripe Wall (pushWall); Topple (beam, phase 2) | Stagger shows as the spin stopping; double opening | Spins slowly like a music box | Lacquer wristbands |
| G5 | **Megh Drummer** | 3, Premium | Monsoon cloud with three drum-head chest | Thunder Clap (strike); Rain Wall (pushWall 2.0 s × hold scale, the longest); Lightning Sweep (beam); Gust (dodge) | **Echo**: a 2-attack call replayed once ("same again!") | Rainbow arc | "Monsoon" arena skin (≤ 120 particles) |
| G6 | **Night Mail Colossus** | 4, Premium, final | A steam locomotive that stands up as a guardian of trunks and whistles | Smoke Bar (beam); Signal Swing (dodge); Coupling Punch (strike → counter pad); Steam Wall (pushWall). Named telegraph "Whistle Call" (3 rising notes) | **Tunnel**: arena dims to 40 %, glyphs stay at full contrast (the audio-first showcase); 4th phase "Terminus" | Toy train circling the Trophy Shelf | Lantern trail, "Night Mail" title |

Future roster slots (same template): Kolam Loom (memory sequences), Ikat Mirage, Banyan Keeper.

### 3.6 Difficulty and band numbers
The band sets the floors and ceilings. Difficulty picks a value inside them.

| | Gentle (50+, default) | Balanced (31–50) | Active (18–30) |
|---|---|---|---|
| BPM by difficulty (beginner / intermediate / advanced) | 76 / 80 / 84 | 84 / 88 / 92 | 92 / 96 / 104 |
| Required lead = band warning floor (× 1.25 in assist) + 1.0 s telegraph | 3.0 s | 2.6 s | 2.3 s |
| Lead beats `L = max(4, ceil(requiredLead / beatMs))` | 4 at 76–80 BPM; **5 at 84 BPM** (3.57 s) | 4 | 4 |
| Demanding per minute, max | 8 | 11 | 14 |
| Demanding in a row, max | 2 | 3 | 3 / 5 / 7 (difficulty) |
| Counter pads | after phrases 2 and 4 of each cycle | after every Good-or-better answer | after every answer |
| Pads per opening | 2 | 3 | 3 (4 only Active-advanced phase 3) |
| Pad spacing | 2 beats and ≥ 1000 ms | 2 beats and ≥ 1300 ms | 2 beats and ≥ 1150 ms |
| Guard / brace hold scale | × 0.75 | × 0.9 | × 1.0 |
| Charge / Surge hold | 450 ms | 540 ms | 600 ms |
| Glancing grace | 150 ms | off | off |
| Breather | ≥ 15 s every 60 s, plus 1 extra cycle-length rest before phase 3 | ≥ 12 s every 75 s | ≥ 10 s every 90 s |
| Typical length | 3:00 | 3:30 | 3:45 (final guardian 5:00) |

**Minimum spacing** (applied after band and BPM): each ask comes ≥ 700 ms after the previous answer window
closes. Extra minimums: beam → next ask ≥ 1100 ms (+250 ms low-impact). Lean ≥ 700 ms. Raise ≥ 750 ms. Pad
≥ 700 ms (beginner 1000 ms). Both `content:validate` (statically, for every band × difficulty × assist) and
`BeatDirector` (at run time) enforce the lead and spacing rules.

**Expected moves per duel** (Balanced, 3:30): about 32 squats, 24 leans, 14 guards, 8 braces, 30–40 punches and
12 charges, at roughly 22–28 asks per minute. Described in copy as "light to moderate". No numbers are shown.

### 3.7 Fight scripts (deterministic; same seed + band + difficulty = same phrase list)

**G1 Baoli Warden, Gentle-beginner, 80 BPM** (beat 750 ms, phrase 6.0 s, lead 4 beats = 3.0 s ✔), 3:00.

| Time | Phrases | Content |
|---|---|---|
| 0:00–0:06 | 1 | Intro. Kavi: "Listen for the count. Move on the hit." |
| 0:06–0:24 | 2–4 | Practice (no Spark loss): Step Sweep with hint, Ledge Drop L with hint, Charge |
| 0:24–0:48 | 5–8 | **Phase 1:** duck, lean R (+pad), duck, lean L (+pad). Poise 4×20 + 2×10 = 100 → stagger |
| 0:48–0:54 | 9 | Opening: 2 breather beats, pad L (beat 3), pad R (beat 5), Charge (beat 7) |
| 0:54–1:06 | 10–11 | Breather: orbs only, drums + drone |
| 1:06–1:36 | 12–16 | **Phase 2:** Stone Fist (guard), duck, lean L, Stone Fist (+pad), opening |
| 1:36 | 17 | **Checkpoint**: a lost Spark returns |
| 1:42–1:54 | 18–19 | Gentle extra breather |
| 1:54–2:42 | 20–27 | **Phase 3:** duck → lean pairs, guard + pad, opening; repeated once with sides mirrored |
| 2:42–3:00 | 28–30 | Calm: 3 Charges 6 s apart, then the calm animation and results |

The script peaks at 5 demanding per minute (cap 8 ✔), never more than 2 demanding in a row ✔, and about
22 asks per minute. It has a surprise (the first strike) at 1:06, which meets the QA5 Q5-5 spirit of a twist
inside 45–90 s.

**G6 Night Mail Colossus, Balanced-intermediate, 88 BPM** (beat 682 ms, lead 2.73 s ≥ 2.6 ✔), 5:00.

| Time | Phase | Content |
|---|---|---|
| 0:00–0:22 | Practice | Whistle Call explained; Smoke Bar, Signal Swing, Charge |
| 0:22–1:27 | 1 Departure | 2 cycles: Smoke Bar, Signal L, Smoke Bar, Signal R → opening (3 pads + Charge) |
| 1:27–1:43 | Breather | Orb chimes only |
| 1:43–2:49 | 2 Ghat Climb | 2 cycles adding Coupling Punch (guard → pad) and Steam Wall (1.5 s × 0.9) |
| 2:49 | Checkpoint | A Spark returns; the music lifts a key |
| 2:49–3:05 | Breather | — |
| 3:05–4:22 | 3 Night Run | Tunnel. Combos Smoke→Signal and Coupling→pad→Steam Wall. 2 openings (Active-advanced: one 4-pad flurry) |
| 4:22–5:00 | 4 Terminus | Surge Finisher if the meter is full, otherwise 3 Charges 3 s apart; calm |

G2–G5 follow the phase table in §3.5 (lengths at Balanced: 3:00, 3:30, 3:30, 4:00).

### 3.8 Forgiveness (rule 5 and fairness)
1. **Tracking amber or red.**
   - The guardian freezes mid-wind-up and the music ducks to a held drone loop.
   - Pending hazards resolve as `forgiven` (existing rules: lost at any point from 300 ms before the cue to
     arrival, or less than 800 ms of tracked play since tracking came back, 1200 ms in assist).
   - Kavi names the cause ("I lost your feet. Step back a little.").
   - When tracking returns: a **1-phrase re-count**, then play resumes at the next phrase boundary. The combo
     freezes and is not reset.
2. **A missed pad or Charge** costs no Spark and keeps the combo. It only lowers the Calm gain.
3. **A wrong move** (a guard on a duck) is a Miss: at most 1 Spark per 2 s, plus a specific line ("That was a
   duck, low!").
4. **`tooEarly`, `tooShallow` and `notVisible` rejections** never cost a Spark. In low-impact, a shallow duck
   inside the window grades OK.
5. **0 Sparks → Regroup.**
   - The phase restarts with 3 Sparks. Calm from earlier phases, XP and best combo are kept.
   - After 2 Regroups in the same phase, Assist is offered once and never forced.
   - "Game over" text never appears.
6. **Stuck guard.** If a phase isn't full after its script plus 2 repeat cycles, it completes anyway ("The
   Warden respects your effort"), capped at 1 star.
7. **Struggle rule.** 2 duels in a row with ≥ 2 Sparks lost → offer one step down. Tracking-forgiven
   encounters don't count toward it.
8. **Access** is checked at guardian select only, never mid-run.

### 3.9 Rewards and meta (cosmetic only)
- **Calm Seals**, band-relative: *Clay* (calmed), *Brass* (calmed with ≥ 2 Sparks), *Indigo* (calmed on
  intermediate or harder with best combo ≥ 30).
- **Trophy Shelf**: a figurine per first calm. Tap it to replay the calm animation.
- **Wardrobe**: textile-craft-inspired originals (a Phulkari-style jacket, Ikat sneakers, a Bandhani bandana),
  plus VFX trails.
- No stat boosts, loot boxes or paid currency.
- **XP and crew points**: existing formulas (XP = score/20 + active s/10 + 50 on completion; crew effort
  ≤ 100 per session).
- **Daily Taal.**
  - The IST-date seed picks one unlocked guardian plus a modifier: *Mirror* (L/R swapped), *Echo*, *Lantern
    Night* (dimmed arena), or *Slow Taal* (−8 BPM, holds ×1.1, still capped by band).
  - It runs 2:30–3:00 plus the 45 s warm-up and cool-down.
  - Only the first 3 attempts a day count. 7 stamps (not necessarily consecutive) earn a cosmetic.
  - Leaderboard is opt-in, within the same band and difficulty only.
- **Gym Crew Raid** (weekly, asynchronous, Monday 00:00 to Sunday 23:59 IST).
  - Members' existing crew effort points from duels fill a shared Raid Calm bar.
  - Target = 250 × active members (played in the last 14 days), min 500, max 25,000.
  - Tiers at 50 / 100 / 150 % unlock crew banner pieces.
  - Contributions are private by default, with opt-in "Crew Heroes", and there are no shaming notifications.
  - Server: new read model `raid_week` built from existing data. No real-time networking.

### 3.10 Style
- **Visual: "Craft-punk", flat-shaded 2.5D.**
  - Palette: Indigo `#1F2A5C`, Terracotta `#C4552D`, Brass `#C9A227`, Teal `#1E8C8A`, Cream `#F3E9D2`,
    Kite Magenta `#C2185B`. Every glyph has a 3 px cream outline.
  - Layout (landscape): guardian top-centre at 45 % of screen height; attack glyph at 22 % of height
    (≥ 25 mm); pads at the left and right thirds, at shoulder height, 18 % of height, with an **L/R** letter;
    landmark avatar bottom-centre at 25 %; Sparks top-left; combo top-right; phase bar full width at the top.
  - A count ring pulses on every beat, so the count still reads without sound.
- **Feel.**
  - Render-only hit-stop (Perfect 70 ms, Good 50 ms, stagger 120 ms + 0.5× guardian slow-motion for 300 ms).
    The game clock and music never stop.
  - Shake **only on the player's own hits** (6 / 3 / 10 px, 150 ms decay). Being hit gets a soft vignette
    and a thud, with no red flash.
  - Reduce-motion sets shake and zoom to 0. Flashes ≤ 3/s, particles ≤ 150.
- **Audio.**
  - Original grooves: a dhol-like low drum, tabla-like bols, pluck, and a bansuri-like synth. No devotional
    ragas, bhajans, chants or temple bells.
  - Cue families match the runner: beam = falling whoosh, dodge = two knocks, strike = double drum + "ting" on
    deflect, pushWall = rising rumble, pad = padded "thup" (L pitched lower than R), charge = 3-note bell.
  - Voice: en / hi / Hinglish counts. Guardians make no speech. Captions are always on.
  - **Quiet Mode**: cues at −12 dB, no music, a bigger count ring.

### 3.11 Free / Premium
| | Free | Premium (₹129/month, ₹699/year, Play Billing; gym members free) |
|---|---|---|
| Guardians | Baoli Warden, Patang Twins (all bands and difficulties) | G3–G6 and the future roster |
| Daily Taal | Free roster | All unlocked guardians |
| Modifiers in free play | Mirror | Mirror, Echo, Lantern Night, Slow Taal |
| Crew Raid | Contributes through free duels | Plus Raid Form duels of Premium guardians |
| Cosmetics | Earned, never sold | Earned, never sold |

Access is checked at select only. No countdowns, pop-ups or external links (rule 11).

### 3.12 Metrics (targets)
| Metric | Target |
|---|---|
| First-duel calm rate (G1, Gentle-beginner) | ≥ 85 % |
| "Did that hit feel fair?" (1 tap after a lost Spark, in 1 of 3 runs) | ≥ 85 % yes |
| Telegraph hallway test at 2 m (12 players per band) | ≥ 90 % name the right move within 1 s of the glyph |
| Perfect + Good share per device model | 55–75 % (> 85 % too easy; < 40 % suggests a latency problem) |
| `tooEarly` + `tooShallow` + `notVisible` rejections | < 10 % of answers |
| Tracking-forgiven encounters | < 5 % |
| Time to first stagger | ≤ 45 s |
| Mid-phase quits | < 8 % |
| D7 retention, mode players vs runner-only | +5 percentage points |
| Raid weeks reaching 100 % | 40–60 % |
| CI simulation | Slow bot finishes every guardian on Gentle + beginner + low-impact; competent bot on every combination |

### 3.13 Risks
| Risk | Mitigation |
|---|---|
| Forward punches by habit | Pads are drawn far out to the side; a "punch to the side pad" hint; a forward reach gives `tooShallow` with "reach out to the side" |
| Latency makes rhythm feel off | Capture timestamps, per-route offset, late-biased windows; grades never cost Sparks |
| Flailing punches or shoulder overuse | End pose plus a guard start; ≥ 700 ms spacing; no speed scoring; flurries ≤ 20 s |
| Guard confused with raise arms or barrier | Exclusion rules (§5.3); a Charge never shares a phrase with a strike |
| Small rooms | Default answers fit ≤ 1 m width (lean, not step); arm-span check in Duel Stance |
| Violence perception | Calm, not kill; no blood; guardians become collectibles |
| Cultural sensitivity | Craft and architecture motifs only; 3 regional reviewers; a ban list |
| Looking like Fitness Boxing or Beat Saber | Fixed-camera guardian duel with a 4-count call; no highways, no bags, no ring; originality review (rule 10) |

---

## 4. Game B: Taal Toofan

### 4.1 Pitch and pillars
Move cards fly from the back of a festival stage and land on the body zone that does the move: between your
hands for a clap, at your feet for a step, on a halo for a reach. Hit them on the beat to build the band one
stem at a time, fill the **Josh** meter and trigger **Toofan Time**. The pillars:
1. **The card lands on your body** ("where", not just "what").
2. **A dance-class caller**: every card is called 1 beat early, and every phrase gets a "5, 6, 7, 8".
3. **You build the band**: stems change on bar lines, so latency never makes the music sound late.
4. **One hook step per song**, learnable and shareable.
5. **No failing**: songs always finish, and ranking uses accuracy %, so bands compete fairly.

### 4.2 Core loop
| Loop | Length | Contents |
|---|---|---|
| Micro | 1 beat to 1 bar | Call at beat −1 → card lands at beat 0 → move → grade flash and sound → combo |
| Phrase | 8 bars (about 16 s at 120 BPM) | Count-in → 8-count ×2 → a stem joins or drops → Josh fills |
| Song | 2:00–3:00 | Intro → verse → hook → chill-out → verse → hook ×2 → freeze-pose finale → results → clip offer |
| Session | 3–4 songs, 9–13 min | Optional 45 s warm-up song (march, arm circles), then songs, then a 45 s cool-down at 80 BPM |
| Meta | Day / week / festival | Beat of the Day, weekly Hook Challenge, Dancer Rank, festival packs |

**Josh meter and Toofan Time.**
- Perfect +2, Good +1, OK +0.5, Miss 0. The meter never drains.
- At 32 the gold Toofan card is called ("Toofan! Arms up!") and answered with raise arms. That starts 8 bars of
  ×2 score, all stems on, and a light show.
- If the card isn't answered, the meter stays full until the next phrase (rule 6).

**Score.**
- Card points: Perfect 300, Good 100, OK 50, Miss 0, times the combo multiplier: ×1 (combo 0–9), ×2 (10–24),
  ×3 (25–49), ×4 (50+).
- **Accuracy %** = (P + 0.6·G + 0.25·OK) / scored cards. Skipped cards are excluded.
- Stars at 40 / 55 / 70 / 82 / 92 %. "Full Groove" means no Miss.

### 4.3 Move vocabulary (launch set; specs in §5)
| # | Move (call) | Variants at launch | Behind a replay gate | Stem it drives |
|---|---|---|---|---|
| 1 | Step-touch ("Step left/right") | L, R; low-impact toe-tap | — | dhol |
| 2 | Clap / Taali ("Taali!") | mid (chest) | high (above head), Toofan only | manjira/claps |
| 3 | Arm wave ("Wave!") | L, R, both ("rainbow") | — | melody |
| 4 | Twist ("Twist!") | **any direction** | signed L/R | tumbi/strings |
| 5 | Dip ("Dip!", a mini-squat) | single, ×2 pulse | — | bass drop |
| 6 | Reach ("Reach up/out") | up-L, up-R, out-L, out-R | low-L/R (knee height; never on Gentle or low-impact) | melody |
| 7 | Raise arms / "Hoy!" | both; low-impact one arm | — | Toofan trigger |
| 8 | March ("March 4!") | 2, 4 or 8 beats (warm-up, breathers) | — | none (unscored or lightly scored) |
| 9 | Freeze pose ("Strike a pose!") | 6 original signature poses | — | finale and clip end |

Jumps and hops never appear unless the player has turned jumps on. With jumps off, the director swaps an
authored `hop` for a calf raise, or drops it if calf raise isn't enabled.

**Anti-mash.** A card takes the *first* onset of its move inside its window. Other onsets do nothing. If 3 or
more onsets of the same move fall within 600 ms around a card, the grade is capped at Good, with the tip "Clap
on the beat, not nonstop."

### 4.4 Timing (shared, see §5.2)
Taal Toofan uses the **same band window table** as Craftguard, plus +20 ms on every bound for big moves (step,
dip, twist). Per-move bias defaults (tune from recordings): clap 0, wave 0, raise 0, reach +30, step +50,
twist +60, dip +70 ms.

**Tracking loss (rule 5).**
- Gate fails for 250 ms → the cards in that span are **Skipped** (grey). They aren't Misses, are excluded from
  accuracy, and freeze the combo.
- Gate fails for more than 1 bar → **Groove Hold**: the current 2-bar vamp loops, no cards spawn, and the caller
  explains why.
- After 300 ms of good frames: a 1-bar count-in, then play resumes at the next section boundary.

### 4.5 Songs and chart format
**Music families** (all original commissions, full buyout including sync and social; a musicologist checks for
soundalikes):

| Family | Feel | Authored BPM | Band BPM cap (Gentle / Balanced / Active) | Signature |
|---|---|---|---|---|
| Raas (Garba-inspired) | Circular taali grooves | 100 → 116 → 128 over 3 rounds | 112 / 120 / 128 (rounds stop accelerating at the cap) | "Taali-3" over step-touches |
| Dhol (Bhangra-inspired) | Half-time bounce | 92–104 | all allowed | "Hoy!" arms, dip bounces |
| Filmi (dance-pop) | Synth-pop + tabla | 112–126 | Gentle uses half-time charts above 110 | Waves, twists, freeze |
| Chill (cool-down) | Lo-fi tabla, flute | 78–90 | all | Slow reaches, unscored sway |

**Section template** (2:30 at 112 BPM, about 70 bars): intro and count-in (4 bars, a demo dancer shows the hook,
quality-gate check) → Verse A (16 bars, 2 move families) → pre-hook (4) → **Hook** (8, the 8-count ×2) →
**Chill-out** (8, unscored, ≥ 15 s on Gentle) → Verse B (12, 3 families) → **Hook ×2** (16, ending on the Toofan
card) → finale (2, freeze pose). Raas songs replace the verses with **3 rounds of 16 bars**, separated by 4-bar
breathers.

**Hook referencing.** `hookPattern` picks which of the 8 beats are scored: Light 4, Groove 6, Toofan 8. Every
difficulty dances the same routine.

**Pacing per difficulty** (Light / Groove / Toofan):
- Scored cards per minute: 18–28 / 30–44 / 46–66.
- Move families per song: 3 / 4–5 / 6–7.
- Off-beat cards: 0 / ≤ 5 % / ≤ 15 %.
- Card lead: 6 beats and ≥ 2.0 s / 5 beats and ≥ 1.6 s / 4 beats and ≥ 1.3 s.

**Band caps** (Gentle / Balanced / Active):
- Cards per minute: 30 / 44 / 66.
- Big moves per minute: 12 / 18 / 26.
- Dips in a row: 4 / 6 / 8, then ≥ 4 beats of small moves.
- Dips per minute: 10 / 14 / 20.
- Twists: Gentle ≤ 8 per 16 bars.

**Minimum gap between scored cards** (Active base; Balanced ×1.25, Gentle ×1.5): small moves 500 ms, big moves
750 ms, dip 1000 ms. The director drops violating cards deterministically and keeps beat-1 cards first.

**Audio delivery.**
- Stems are drums, bass, melody, chant, `layer.clap`, `layer.step`, `layer.reach`, `layer.dip` and `vamp`.
  **At most 5 play at once** (§6.5).
- Format is Opus at 48 kHz and 96–128 kbps, about 3.5 MB per 2:30 song, plus pre-rendered 75 %-tempo stems for
  Practice.

**Launch setlist** (working titles, pending legal clearance): *Chakri Chal* (Raas), *Mirror-Work Nights* (Raas),
*Dhol Express* (Dhol 96), *Tumbi Tornado* (Dhol 102), *Neon Thumka* (Filmi 118), *Filmi Flash* (120), *Sangeet
Squad* (112), *Patang Pe Dil* (110), *Gulaal Groove* (120), *Roshni Rush* (108), *Midnight Masti* (124), and
*Chill Chai* (80, cool-down). After launch: +2 songs a month.

### 4.6 Bands and safety
| | Gentle (default) | Balanced | Active |
|---|---|---|---|
| Default difficulty | Light | Light; Groove is *suggested* after 3 clean songs | Groove |
| Low-impact | Locked on (confirm twice to turn off) | On | On, easy to turn off |
| Dip depth | 25 % | 30 % | 35 % |
| Breather | ≥ 15 s per 60 s | ≥ 12 s per 75 s | ≥ 10 s per 90 s |
| Songs before a "take a break" card | 3 | 4 | 5 |

Safety rules:
- No spins or turns (dizziness, and the player leaves the frame).
- No floor touches. Twists keep the hips facing forward.
- 2 × 2 m clear per player, with a fan and ceiling check before overhead reaches.
- Tile-floor tip: "Barefoot or grippy shoes — no socks on tiles."
- Navratri heat tip as general info: "Sip water and rest whenever you like."

### 4.7 Party modes (18+ only)
**Solo.**
- Song select → Beat Sync if this audio route has no offset → song → results (accuracy, stars, best combo,
  moves, active minutes) → clip offer.
- **Practice the Hook**: 75 % tempo, spoken breakdown, no score. Free on every accessible song.

**House Party** (was "Ghar Party", 2–8 players, one tracked body at a time). The phone stays on the floor, so
players swap the spot instead of passing the phone.
- Each guest makes a session-only profile: nickname, colour and band. Nothing else is stored.
- Every guest must confirm **"I'm 18 or older"** at tag-in.
- 6 s mini-calibration on first tag-in: stand 2 s, arms up 1 s, one dip.
- **Relay**: players rotate every 16 bars, with a 2-bar vamp handoff ("Next up: Priya — step in!"). Tracking loss
  when the old player leaves costs nothing.
- **Battle**: everyone dances the same 45 s hook segment, ranked by accuracy %.
- **Teams**: 2 teams, team accuracy is the average.
- End screen: a Party MVP image card with fun awards ("Taali Titan", "Steady Steps").

**18+ positioning.** All copy says "house party with friends (18+)". Store and in-app text never use "family",
"kids" or "all ages". The art is adult-leaning, not cartoon-kiddy. This avoids conflict with Google Play's
Families policy. If the pose model ever reports more than one body, Groove Hold triggers with "Only the dancer
should be in view." No other body is ever scored or recorded.

**Jodi** (2 players in one frame). This is **M5 and optional**, gated on device capability and an owner
decision (§9).
- `numPoses = 2`, and a 10 s device test must hold ≥ 20 fps with both bodies passing the gate. Landscape,
  2.7–3.0 m from the phone, players ≥ 1 m apart.
- Identity by hip-centre continuity (max jump 0.25 of image width per 100 ms).
- Mirror charts are generated deterministically, so players never cross and never touch.
- **Jodi Sync**: both players Perfect on the same card → +50 %.
- Capped at 3 songs in a row (thermal).

### 4.8 Highlight clip (rule 2: landmarks only)
- **Source**: a RAM ring buffer of landmarks (33 × 4 floats × 30 fps × 15 s ≈ 240 KB). **No camera frame is ever
  retained.** The clip window is `highlight.preferSection`, or else the 15 s with the highest Perfect density,
  ending on the freeze pose.
- **Styles**: *Normalised Avatar* (default; joint angles are retargeted onto a standard body, so the player's body
  shape is never revealed), *Neon Lines*, and *Silhouette* (the player's own proportions, opt-in).
- **Render**: offscreen Flame render on device → MediaCodec H.264, 1080×1920 at 30 fps, about 8 Mbps (about
  15 MB), with our own song audio. Overlays: title, hook name and combo pops. Nickname and score are off by
  default. The watermark reads "Taal Toofan · Joynetic", with no link and no price.
- **Consent and storage**:
  - Opt-in per clip. The first time, an explanation reads: "Made from your movement points, not your camera.
    Nothing is uploaded."
  - Sharing goes through the Android share sheet only.
  - The file sits in app cache and is deleted after 24 h unless the player taps Save. Metadata is stripped.
- **Real camera clips are out of scope.** They would require changing rule 2, and the recommendation is not to.

### 4.9 Social loop
1. A **weekly hook-step challenge**, with hashtag #TaalToofan<Song>.
2. **Original audio listed in the Reels and Shorts libraries** through a distributor. Our own channel and our
   users are whitelisted, so there are **no Content ID claims against players**.
3. **Duel links (asynchronous)**: "Beat my 87 % on Neon Thumka (Groove)". The link carries the song, difficulty
   and score only. If the app isn't installed it opens the Play listing, with Install Referrer for attribution.
4. Party MVP image cards.
5. **Crew Raas Nights**: an opt-in gym crew leaderboard (first name plus summaries, existing consent rules).
6. **Invite reward**: an exclusive, non-purchasable hand trail after the friend finishes 3 songs.

### 4.10 Festival calendar (windows are server config; dates checked against an almanac every year)
| Event | Approx. window | Pack | Notes | Access |
|---|---|---|---|---|
| Patang / Harvest Beats | Jan 10–18 | *Patang Pe Dil* + a harvest Dhol track | Kite sky; reach-heavy charts; **closed beta event, Jan 2027** | Premium |
| Holi Colour Clash | Holi ±4 days (Mar 2027) | *Gulaal Groove* + remix | Perfects spray colour; shapes carry meaning (colour-blind safe); **public launch** | Premium |
| Jodi Week | First week of Aug | Duet charts | Only if Jodi ships | Free charts on free songs |
| **Navratri Raas Nights** (tentpole) | 9 nights + 2 encore days (late Sep–Oct 2027) | 3 Raas songs, a new one every 3rd night | Gujarat-first rollout flag; geometric and mirror-work floors; no religious imagery | **Free** (like Garba Quest) |
| Diwali Roshni Rush | Diwali week | *Roshni Rush* + lights remix | No firecrackers or bangs | Premium |
| Sangeet Season | Nov 15–Feb 15 | 3 sangeet-pop songs | House Party focus | Premium (1 song in the Beat of the Day rotation) |
| New Year Countdown | Dec 26–Jan 4 | *Midnight Masti* | No alcohol imagery | Premium |

Diwali 2026 (8 Nov) is too close to ship for.

### 4.11 Progression and Free / Premium
**Dancer Rank and rewards.**
- **Taal XP** per song = 100 × accuracy × difficulty factor (Light 1.0, Groove 1.3, Toofan 1.6) + 25 per star.
- **Dancer Rank** runs 1–50; rank n needs 250 + 50n XP (about 75 h to reach rank 50). Titles: Naya Dancer →
  Thumka Starter → Taali Pro → Dhol Champ → Raas Royal → Toofan Star → Taal Legend.
- Song mastery: 5★ per difficulty, plus a "Hook Mastered" badge (≥ 90 % Perfect in hooks).
- The weekly Hook Challenge (7 tasks) earns a cosmetic. It is free, with no paid pass.
- Any Taal session of 3 minutes or more counts for the existing IST streak.
- Event cosmetics are earned during the event window only and never sold.

| | Free | Premium (same subscription) |
|---|---|---|
| Songs | *Chakri Chal*, *Dhol Express*, *Neon Thumka*, *Chill Chai*, plus **Beat of the Day** (one Premium song a day, rotating) | Full library (12 at launch, +2 a month) |
| Difficulties and Practice the Hook | All | All |
| House Party | Relay and Battle, ≤ 4 players, free songs | ≤ 8 players, Teams, custom setlists |
| Clips | All styles | Plus extra clip frames earned in play |
| Events | Navratri Raas Nights | All events |
| Ads | None | None |

### 4.12 Metrics (targets)
**Detection gates** (replay tests):
- Recall ≥ 95 % for clap-mid, step, dip, reach-out and raise. ≥ 90 % for wave and twist-any. Signed twist needs
  ≥ 85 % before it is enabled.
- False onsets ≤ 1 per minute per move while dancing freely.

**Timing and device:**
- After Beat Sync: median |error| ≤ 40 ms and p95 ≤ 120 ms across a 10-device matrix (Redmi Note, Galaxy A,
  Realme, Moto G, Pixel a).
- ≥ 24 fps on Helio G85 / SD680-class phones. ≤ 8 % battery per 20 min.
- "Did the game miss a move you made?" yes-rate ≤ 8 %.

**Product:**
- D1 / D7 / D30 ≥ 35 / 15 / 6 %.
- ≥ 3 songs per session. Median session ≥ 9 min.
- ≥ 25 % of event-month sessions are House Party. Gentle-Light completion ≥ 90 %.
- Clips generated on ≥ 10 % of completed songs and shared on ≥ 3 %. K-factor ≥ 0.15 during Navratri.
- Premium conversion ≥ 4 % in the event month. Beat of the Day reaches ≥ 30 % of free DAU.

### 4.13 Risks
| Risk | Mitigation |
|---|---|
| Bluetooth party speakers (+150–300 ms) | Beat Sync per route; BT default +220 ms; a "phone speaker or wired is tightest" tip; stems change on bar lines |
| Clap occlusion and blur | Approach-then-close rule using the wrist + index midpoint; mid claps only at launch; no microphone |
| Twist direction is unreliable | "Any" by default; signed twist only after the recall gate |
| Garba is devotional for many | "Festival-inspired" framing; no deities, devotional lyrics or temples; Gujarati and Punjabi advisors; Ahmedabad-first rollout |
| Music soundalikes and Reels muting | Original buyout commissions; musicologist review; distributor whitelist |
| Minors at parties / Play Families policy | 18+ copy and per-guest confirmation; no family framing; adult art; extra bodies trigger Groove Hold |
| Collisions in small rooms | One dancer at a time (except opt-in Jodi); 2 × 2 m prompt; no crossing or contact |
| Overexertion through competition | Accuracy ranking only; band caps; break cards; chill sections |
| Scope (7 recognisers + audio clock + clips) | Phased build (§7); twist and wave can slip to M5 without blocking launch |

---

## 5. Shared new moves and recogniser specs

### 5.1 Principles (apply to every new recogniser)
1. **End pose, never velocity.** A recogniser starts on a pose reached and held for 2 frames, or 1 frame plus a
   max or min taken over the window (clap, dip bottom). It never uses a `d/dt` threshold.
2. **Timing comes from the capture clock.**
   - Every onset carries `hitTsMs`, the interpolated hit point on the **capture clock**: a linear threshold
     crossing between the two frames that straddle it, or a parabolic minimum over 3 frames.
   - `hitTsMs` comes from the raw (unfiltered) feature. The One Euro output is used only for the start/stop
     state.
   - The 2-frame confirm delays *feedback*, not the judged time.
3. **Zones are relative to the torso.**
   - Units: torso T (shoulder-centre to hip-centre), shoulder width SW, and calibrated arm length AL.
   - Never absolute z. Relative z between paired joints is allowed only as a tie-breaker, and only when
     |Δz| > 0.1.
4. **Silent misses are bugs** (QA5 Q5-8). If an attempt started (the feature passed 35 % of its threshold) or a
   card is live, and any joint involved has visibility < 0.5, the recogniser emits `ExtraMoveRejected(notVisible)`
   once per attempt. Likewise `tooShallow` (peak between 35 % and 100 % of the threshold) and `tooEarly`
   (inside the cooldown).
5. **Low-impact variants** come from `BeatThresholds.lowImpact()`. The Gentle band always uses low-impact
   thresholds for punch and reach.
6. **Every recogniser is off by default.** `MotionEngine` enables only the recognisers listed in `level.moves`.

### 5.2 Shared timing window table (one per band, both games)
Judged error:
```
e = (hitTsMs − deviceOffsetMs[route]) − targetHeardMs − moveBiasMs[move]
```
- `targetHeardMs` is the target beat's capture-clock time, from the audio clock (§6.4).
- Negative e means early, positive means late.

| Band | Perfect | Good | OK (still scores) | Miss |
|---|---|---|---|---|
| **Gentle** | −110 / +140 ms | −220 / +280 | −350 / +450 | outside OK |
| **Balanced** | −90 / +120 | −180 / +240 | −300 / +400 | outside OK |
| **Active** | −80 / +100 | −160 / +200 | −250 / +330 | outside OK |

Modifiers, applied in this order:
1. Big moves (step, dip, twist, squat, lean): +20 ms on every bound.
2. Assist: ×1.25 on every bound.
3. FPS guard: every bound is at least `2.5 × measuredFrameIntervalMs`. Below 25 fps, add half a frame interval to
   every bound. Below 20 fps, the content switches to half-time (cards on every 2nd beat) and the HUD says
   "Low frame rate — timing relaxed".
4. Below 15 fps, neither mode is offered and the player is sent to the runner.

**Difficulty never changes windows.** It changes density and variety only, which reconciles 3-tech's per-difficulty
windows with the per-band windows in the two game drafts. Damaging hazards in Craftguard are judged by **state
during the impact window** (held or not), with grades affecting score only. A hazard is never failed because the
player was early.

### 5.3 Recogniser specs
T = torso length, SW = standing shoulder width, AL = arm length on that side. Defaults are listed first,
low-impact values in brackets. **All values are starting points.** Tune them only with recorded clips and
`replay_accuracy_test` passing.

| Move | File / class | Start (2 frames unless noted) | Hit point | End / re-arm | Cooldown | Rejections | Low-impact |
|---|---|---|---|---|---|---|---|
| **Punch L/R** (side pad) | `combat_recognisers.dart` `PunchRecogniser(side)` | Armed only if the wrist was in the guard zone (≤ 0.5 T from faceAnchor) within the last 1000 ms. Start: reach `|wrist−shoulder|/AL` ≥ 0.75 [0.60] AND 2-D elbow angle ≥ 145° [130°] AND wrist y within shoulder ±0.3 T AND wrist x outside the shoulder on that side | First frame reach ≥ threshold (interpolated) | Wrist back in the guard zone or reach < 0.4 | 500 ms per hand [750], 350 ms across hands | Peak 0.5–threshold → `tooShallow` ("reach out to the side"); wrist above nose → no event; any of wrist/elbow/shoulder vis < 0.5 → `notVisible` | reach 0.60, elbow 130°, +250 ms cooldown |
| **Guard** | `GuardRecogniser` | Both wrists ≤ 0.45 T from faceAnchor; wrist y ≥ nose y − 0.15 T (not overhead); elbows below wrists and inside the hip span ±20 % | First frame both wrists are in the zone | False for 150 ms | — | vis < 0.5 → `notVisible` | one hand |
| **Clap** (mid) | `rhythm_recognisers.dart` `ClapRecogniser` | Open: hands ≥ 0.9 SW apart within the last 800 ms (both vis ≥ 0.5). Close: wrist+index midpoints ≤ 0.45 SW [0.55] on ≥ 1 frame, both between hip y and nose y. Close-frame visibility may be ≥ 0.3 | Parabolic minimum of the hand distance | Hands ≥ 0.6 SW apart | 300 ms; at most 1 per beat, ≤ 100 claps/min | No open frame → ignored; open frame vis < 0.5 → `notVisible` | 0.55 SW |
| **Step-touch L/R** | reuse `SideStepRecogniser` + onset tap | `sideStepFraction` ≥ 0.45 [toe-tap: ankle x − hip x ≥ 0.6 × hip width, no weight shift] | First frame ≥ threshold | < 0.25 | none (but a return < 0.25 is needed between steps) | existing | toe-tap |
| **Wave L/R/both** | `WaveRecogniser` | **Positional, no velocity.** Wrist above the shoulder line [chest height allowed] starts ≥ 0.5 SW outside one shoulder and arrives ≥ 0.5 SW outside the other within 1.5 beats | Interpolated frame where the wrist crosses the body midline | Wrist below the shoulder line or travel complete | 1 beat | Travel < 0.8 SW → `tooShallow` | chest-height sweep |
| **Twist (any)** | `TwistRecogniser` | shoulderWidth/SW ≤ 0.80 [0.86] AND hip width ≥ 0.92 of standing AND hip-x shift < 0.25 of step range AND |lean| < 0.4 | Parabolic minimum of the ratio | Ratio ≥ 0.92 | 600 ms | Lean or step present → ignored (not twist) | 0.86 |
| Twist direction | same | The side whose wrist crossed hip-centre x (cue "elbows out, hands at chest"); else the relative shoulder z sign if |Δz| > 0.1; else `any` | — | — | — | — | never asked |
| **Dip** | `DipRecogniser` (squat features) | Span shrink ≥ 35 % of calibrated depth (Gentle 25 %, Balanced 30 %) | Parabolic minimum of hip y | < 15 % | 1 beat | Peak 15 %–threshold → `tooShallow` | 25 % |
| **Reach** zone | `ReachRecogniser` | Wrist inside a circle of radius 0.35 AL [0.45]. Centres (player's side s=±1): out = shoulder + (s·1.0 AL, 0); up = shoulder + (s·0.5 AL, −0.85 AL); low = shoulder + (s·0.4 AL, +1.1 AL) | First frame inside | Leaves the circle | 1 beat | Nearest approach ≤ 1.6 r → `tooShallow` | no low; r 0.45 |
| **Knee lift / march** | `KneeLiftRecogniser` | lift(side) = (standingKneeY − kneeY)/thigh ≥ 0.5 [march 0.30] while the other knee < 0.25 | Knee peak | < 0.2 | — | knee vis < 0.5 → `notVisible` (sarees and loose trousers) | 0.30 |
| **Freeze pose** | `FreezePoseRecogniser` | Joint-angle distance to the template ≤ 25° [35°] per tracked joint, held ≥ 70 % of 2 beats | Hold start | — | — | — | 35° |
| **Raise arms** (Charge, Toofan, orb) | existing, after M0 fixes | Wrists above the nose line; hold = `raiseHoldMs` (Q5-7 fix) | Interpolated nose-line crossing | Wrists below the shoulder line | — | wrist vis < 0.5 → `notVisible` (Q5-9) | one arm |

`faceAnchor` is the nose. When nose visibility is < 0.5 (hands over the face), it falls back to shoulder-centre
− 0.9 T vertically.

### 5.4 Lookalike disambiguation (cross-suppression in `MotionEngine`)
| Pair | Rule |
|---|---|
| Guard vs raise arms | Raise requires the wrists > 0.15 T above the nose and the elbows above the shoulders. Guard requires the wrists below nose + 0.15 T. Content never puts a Charge in the same phrase as a strike |
| Guard vs barrier hold | Disjoint zones: guard is near the face, barrier is in the chest band below the shoulders, with `guardNoseTorso` exclusion 0.4 |
| Punch vs barrier or forward push | A forward push has 2-D reach ≤ 0.55, so it can never reach 0.75. A punch also needs wrist x outside the shoulder |
| Punch vs raise / up-reach | Wrist above the nose → never a punch |
| Punch vs lean | While a punch is active, plus 300 ms after, lean onsets are suppressed. The duel never asks for a lean within 700 ms of a pad |
| Squat or dip vs lean (Q5-10) | While the squat or dip is down, lean, knee and twist onsets are suppressed |
| Twist vs step / lean | Twist requires a stable hip x and |lean| < 0.4. Otherwise the event goes to the step or lean |
| Squat vs knee lift | Knee lift requires the other knee to stay straight (< 0.25); a squat raises both |
| Clap vs arms crossed / guard | A clap needs an open frame ≥ 0.9 SW within 800 ms before the close |
| Wave vs raise | A wave needs ≥ 0.8 SW of lateral travel. A raise needs both wrists above the nose and is only judged when a raise card is live |

### 5.5 Safety and wording
- **Defaults**: march, not jog; step-touch, not lunge; no spins; no jumps; a soft elbow (elbow ≥ 145° is the
  start threshold; nothing rewards locking out at 180°); flurries ≤ 20 s; holds ≤ 10 s early on, with "keep
  breathing".
- **Setup check** before the first duel or dance: 2 × 2 m clear, nothing overhead (fan), a non-slip floor, a
  stable phone stand, no pets in the space.
- **Stop rule on every song and guardian sheet**: "Stop if you feel pain, dizziness, chest discomfort or unusual
  breathlessness." Tapping "This doesn't feel right" ends the run gently and keeps progress.
- **Allowed copy**: "gets your whole body moving", "raises your breathing", "practises balance and coordination",
  "public guidelines such as WHO 2020 suggest 150–300 minutes of moderate activity a week; Joynetic minutes
  can be part of your active time", "not a medical device; consult a healthcare professional for medical
  advice".
- **Forbidden copy**: calories or kcal, METs shown as measured values, "fat-burning", "lose weight", "tone",
  "slim", before/after, treats / cures / prevents / reverses, "clinically proven" or "doctor-approved",
  heart-rate zones, any claim to measure fatigue. Results screens show **moves, active minutes and party
  minutes only**.
- Sources: [WHO 2020](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7719906/), [Play Health apps](https://support.google.com/googleplay/android-developer/answer/14738291), [ASCI](https://www.ascionline.in/wp-content/uploads/2022/09/asci_mar_apr_ccc_pr.pdf). Get legal review before launch.

---

## 6. Technical architecture

### 6.1 Overview
```
CameraX ImageProxy ──(native: latest frame only, frames never leave Kotlin)──► MediaPipe Lite
     │ imageInfo.timestamp (sensor) → captureTsUs (monotonic base)
     ▼
PoseFrame{33 lm, vis, tsMs(MediaPipe), captureTsUs}  ──► Dart  motion_core.MotionEngine
                                                              ├─ existing recognisers
                                                              ├─ combat_recognisers / rhythm_recognisers
                                                              └─ MoveOnset{move, variant, hitTsMs}
StemPlayer (Kotlin AudioTrack) ─ AudioTimestamp{framePos, nanoTime} ─► Dart BeatClock
                                                              ▼
                         game_director.BeatEngine(level v2, BeatPlan) + DuelRules | DanceRules
                                                              ▼
                         app BeatGame (Flame) → DuelPainter | DancePainter + AvatarPainter, HUD, audio cues
```

### 6.2 `packages/motion_core` (tests first)
| File | Add / change |
|---|---|
| `lib/src/recognisers.dart` | **M0**: Q5-7 raise fix (a 400 ms raise must fire), Q5-9 wrist-visibility check, Q5-10 lean suppression while the squat is down, Q5-8 `notVisible` emission |
| `lib/src/quality_gate.dart` | Q5-8: raise `minBodyHeight` 0.35 → 0.42 **or** add a per-attempt `notVisible` path (decide by replay data) |
| `lib/src/calibration.dart` | Q5-10: `Calibrator.build` returns a recoverable `CalibrationResult.failed(reason)` instead of throwing. New optional fields with defaults so old server calibrations still load: `armLengthLeft/Right` (default 1.05 T), `standingShoulderWidth`, `standingHipWidth`, `standingKneeYLeft/Right`, `thighLength` (0.9 T), `kneeLiftRange` (0.35 thigh), `guardWristNoseTorso` |
| `lib/src/landmarks.dart` | `PoseFrame.captureTsUs` (int, nullable for old recordings; fall back to `timestampMs × 1000`) |
| `lib/src/recording.dart` | Recording format v2 stores `captureTsUs`; readers accept v1 |
| `lib/src/features.dart` | Allocation-free helpers: `reach(side, cal)`, `elbowAngle(side)` (2-D atan2), `kneeLift(side, cal)`, `twistRatio(cal)`, `hipWidthRatio(cal)`, `faceAnchor`, `handMid(side)` (wrist+index midpoint), `wristToReachZone(...)` |
| `lib/src/beat_events.dart` (new) | `enum BeatMove { punchLeft, punchRight, guard, clap, stepLeft, stepRight, waveLeft, waveRight, waveBoth, twist, dip, reach, kneeLeft, kneeRight, raiseArms, squat, leanLeft, leanRight, barrierHold, freeze }`; `MoveOnset extends MotionEvent { BeatMove move; String? variant; double hitTsMs; int? direction; }`; `BeatHoldChanged(move, active, ts)` for guard and barrier state |
| `lib/src/onset.dart` (new) | `OnsetInterpolator` (`linearCrossing(prevV, prevT, v, t, threshold)`, `parabolicMin(v0,v1,v2,t0,t1,t2)`) |
| `lib/src/beat_thresholds.dart` (new) | `BeatThresholds` (every number in §5.3) + `.lowImpact()` + `toJson/fromJson` (`MotionThresholds` unchanged) |
| `lib/src/combat_recognisers.dart` (new) | `PunchRecogniser`, `GuardRecogniser` |
| `lib/src/rhythm_recognisers.dart` (new) | `ClapRecogniser`, `WaveRecogniser`, `TwistRecogniser`, `DipRecogniser`, `ReachRecogniser`, `KneeLiftRecogniser`, `FreezePoseRecogniser`, `OnsetTap` (adds `MoveOnset` to existing squat/lean/raise/side-step starts) |
| `lib/src/motion_engine.dart` | `MotionEngine(beatMoves: Set<BeatMove>, beatThresholds: ...)`; enables only those listed; applies the §5.4 cross-suppression |
| `lib/src/testing/` | `SyntheticBody` poses: `guard`, `punch(side, reach, angleDeg)`, `forwardPunch` (decoy), `clap`, `wave(side)`, `twist(dir, ratio)`, `dip(depth)`, `reach(zone)`, `kneeLift(side)`, `freeze(id)` |
| `test/combat_recognisers_test.dart`, `test/rhythm_recognisers_test.dart`, `test/onset_test.dart`, `test/qa5_regression_test.dart` | Matrix: 10/15/24/30 fps × noise σ 0.006/0.01/0.015 × every-3rd frame dropped × occlusion → `notVisible`. Decoys from §5.4 give 0 events. Onset error vs ground truth ≤ ½ frame interval |
| `lib/src/accuracy.dart` + `test/replay_accuracy_test.dart` | Add per-move recall and false-trigger gates for each new move once recorded clips exist (≥ 20 players × each move, 2 phones including 1 budget; recall ≥ 0.9, or the §4.12 gates; ≤ 1 false trigger per 2 min idle) |

### 6.3 `packages/game_director`
| File | Role |
|---|---|
| `lib/src/level_v2.dart` | `BeatLevel` (shared fields), `DuelSpec`, `DanceSpec`, `BeatNote{atBeat, type, hand?, side?, variant?, zone?, durationBeats?, minDifficulty?, windowScale?}`; `LevelLoader.load(json)` branches on `schemaVersion` → `LevelConfig` (v1) or `BeatLevel` (v2) |
| `lib/src/tempo_map.dart` | `TempoMap.beatToMs(beat)` / `msToBeat` with BPM steps (Raas rounds); band BPM cap |
| `lib/src/timing_windows.dart` | `WindowTable.forBand(band)` → `grade(errorMs, {bigMove, assist, frameIntervalMs})` (§5.2) — the **single source** for both games |
| `lib/src/beat_clock.dart` | Maps `AudioTimestamp(framePos, nanoTime)` samples → `heardMs(beat)` on the capture clock; linear fit over the last 2 s; detects stalls and route changes |
| `lib/src/beat_director.dart` | `BeatDirector.plan(level, band, difficulty, lowImpact, jumps, assist, fps)` → `BeatPlan` (deterministic): drop notes above difficulty, lead-beat rule, spacing, band caps, demanding-in-row, half-time thinning, hop→calf raise, hookPattern expansion, mirror for the Daily Mirror modifier |
| `lib/src/beat_judge.dart` | Pure: takes a `MoveOnset` or hold state and the live notes → `Judgement{note, grade, errorMs}`; first-onset rule; anti-mash cap |
| `lib/src/beat_engine.dart` | `BeatEngine` with the RunEngine contract: `input(MotionEvent)`, `advance(dtMs)`, `setLight(TrackingLight)`, `List<RunEvent>` out, `RunResult` at the end. Holds `BeatClock`, `BeatJudge` and a `ModeRules` |
| `lib/src/duel_rules.dart` | `DuelRules implements ModeRules`: Sparks (1 per 2 s), Poise, stagger/fallback, openings, Calm, Surge, combo layers, Regroup, stuck guard, Glancing |
| `lib/src/dance_rules.dart` | `DanceRules implements ModeRules`: Josh, Toofan, stem on/off at bar lines, Skipped, Groove Hold, accuracy and stars, relay handoff |
| `lib/src/beat_events.dart` | `TargetJudged(note, grade, errorMs, points)`, `PoiseChanged`, `Staggered`, `CalmChanged`, `SparksChanged`, `StemChanged(stem, on, atBar)`, `GrooveHold(on, reason)`, `ToofanStarted`; reuses `CuePlayed`, `HintShown`, `TrackingHint`, `RunFinished` |
| `lib/src/beat_simulator.dart` | `simulateBeat(level, settings, BeatBot)`; `BeatBot{latencyMs, jitterSigmaMs, biasMs, fps, dropRate, wrongHandEvery, missEvery, dropouts:[(atMs,durMs)], seed}`; presets `competent` (σ 45, +30, 30 fps), `slow` (+120 late, σ 120, 15 fps), `dropout` (2 s loss per minute) |
| `lib/src/coach.dart` | Kavi keys for the new rejections ("reach out to the side", "clap on the beat") |
| tests | `level_v2_test.dart`, `timing_windows_test.dart`, `beat_director_test.dart` (lead rule, spacing, caps per band × difficulty × assist), `beat_engine_test.dart` (rule 5: dropout never costs a Spark or a combo), `beat_simulation_test.dart` (every v2 level × 3 bands × 3 difficulties × low-impact) |

**Simulation gates.**
- Craftguard: the competent bot calms every guardian on every combination. The slow bot calms every guardian
  on Gentle + beginner + low-impact without assist. The dropout bot never loses a Spark to tracking.
- Taal Toofan: the competent bot reaches ≥ 3★ on every chart in its band, and the slow bot ≥ 2★ on
  Light/Gentle. Skipped cards never count as Misses.

### 6.4 Native bridge and clocks
**`PosePipeline.kt`.**
- Read `image.imageInfo.timestamp` (ns). Look up `CameraCharacteristics.SENSOR_INFO_TIMESTAMP_SOURCE`:
  - **REALTIME** (CLOCK_BOOTTIME) → `captureTsUs = (ts − (elapsedRealtimeNanos() − nanoTime())) / 1000`,
    sampling the offset per frame.
  - **UNKNOWN** → use `uptimeMillis` at `analyze()` entry, minus a configurable `exposureOffsetMs` (default
    33), and flag `tsQuality = estimated`.
- Keep the existing monotonic `ts` for `detectAsync`, which MediaPipe requires to increase strictly.
- Send `captureTsUs` alongside the landmarks. Frames stay native (rule 4).

**Audio clock.**
- New Kotlin plugin `native/beat_audio/` (keeps `pose_bridge` focused on pose).
- `StemPlayer`: ≤ 5 streaming `MediaCodec` Opus decoders → float mix → one `AudioTrack` (`PERFORMANCE_MODE_LOW_LATENCY`, 48 kHz).
- `AudioTrack.getTimestamp(AudioTimestamp)` is polled at 20 Hz and sent to Dart as `(framePosition, nanoTime)`.
  `nanoTime` is CLOCK_MONOTONIC, the **same base as `captureTsUs`**.
- Stem gain changes are scheduled at a frame position (the bar line).
- Methods: `load(stems)`, `play(atFrame)`, `setStemGain(stem, gain, atFrame)`, `loopVamp(startFrame, endFrame)`,
  `route()` (speaker / wired / BT).
- Also hosts `ClipEncoder` (MediaCodec H.264 from a Flutter-rendered RGBA buffer plus song PCM).

**Beat Sync calibration** (shared by both games, about 15 s; runs on first launch of either mode, on any audio
route change, and from Settings):
- A metronome at 100 BPM. "Raise both arms past your nose on every 2nd beat" × 10. Raise is the most reliable
  recogniser; claps are only medium-low.
- Discard the first 2 reps. `deviceOffsetMs[route]` = median error, clamped to ±350 ms.
- If IQR > 120 ms → "Let's try again — more light helps", then fall back to route defaults: speaker +40, wired
  +20, BT +220 ms.
- Stored on the device only. A manual ±10 ms nudge sits in Settings.
- Offsets shift *grading* only, never hazard windows.

### 6.5 Schema v2 (`content/schema/level.schema.json`)
**Structure.**
- Move the current schema body to `$defs.levelV1` unchanged. Root becomes
  `{"oneOf":[{"$ref":"#/$defs/levelV1"},{"$ref":"#/$defs/levelV2"}]}`. `levelV1` keeps `schemaVersion: {"const":1}`,
  and `levelV2` uses `{"const":2}`, so the branches are mutually exclusive.
- All 18 v1 files stay valid; this is a test in M1.
- v2 files live in `content/levels/` with id pattern `^(duel|dance)-[a-z0-9-]+$`.
- `mode` (`duel` | `dance`) uses `if/then` to require `duel` or `dance`.
- `lanes` is forbidden in v2.

**Validator** (`server/src/modules/content/validate-cli.ts`) additions:
- The lead-beat rule and minimum spacing for every band × difficulty × assist.
- Band caps (demanding/min, big/min, dips in a row).
- `moves` ⊇ the moves used by every note.
- Pad zone `side` only (≥ 30° rule).
- No hazard within 2 beats after a `marchTrack`.
- `scored:false` sections meet the band breather rule.
- A **level-similarity check** (type sequence + timestamp similarity < 0.85 against every other level; QA5 Q5-1 and
  Q5-4).

**Duel example** (Craftguard):
```json
{
  "id": "duel-baoli-warden", "version": 1, "schemaVersion": 2, "mode": "duel",
  "name": "Baoli Warden", "access": "free",
  "moves": ["squat", "leanLeft", "leanRight", "guard", "punchLeft", "punchRight", "raiseArms"],
  "music": { "stems": { "drums": "sha256:…", "drone": "sha256:…", "pluck": "sha256:…", "flute": "sha256:…", "vamp": "sha256:…" },
             "firstBeatMs": 1200, "beatsPerBar": 4,
             "bpm": { "gentle": [76, 80, 84], "balanced": [84, 88, 92], "active": [92, 96, 104] } },
  "duel": {
    "guardian": "baoliWarden", "sparks": 3, "checkpointBeforePhase": 3, "gentleExtraBreatherBeforePhase": 3,
    "attacks": [
      { "id": "stepSweep", "type": "beam", "glyph": "chevronDown", "sound": "cue_beam_claypot", "voice": "duck", "phaseMin": 1 },
      { "id": "ledgeDrop", "type": "dodge", "side": "telegraphed", "glyph": "arrowSide", "sound": "cue_dodge_stone", "voice": "leanAway", "phaseMin": 1 },
      { "id": "stoneFist", "type": "strike", "glyph": "shield", "sound": "cue_strike_drum", "voice": "guard", "phaseMin": 2 }
    ],
    "phases": [
      { "name": "Awaken",   "cycles": { "gentle": 1, "balanced": 2, "active": 2 },
        "pattern": ["stepSweep", "ledgeDrop:right+pad", "stepSweep", "ledgeDrop:left+pad"] },
      { "name": "Pressure", "cycles": { "gentle": 1, "balanced": 2, "active": 2 },
        "pattern": ["stoneFist", "stepSweep", "ledgeDrop:left", "stoneFist+pad"] },
      { "name": "Full Taal","cycles": { "gentle": 2, "balanced": 2, "active": 3 }, "minDifficultyExtras": "intermediate",
        "pattern": ["stepSweep", "ledgeDrop:mirror", "stoneFist+pad", "stepSweep"] }
    ],
    "opening": { "pads": { "gentle": 2, "balanced": 3, "active": 3 }, "padZone": "side", "padSpacingBeats": 2, "charge": true },
    "calm": { "animation": "sinksIntoWater", "firstCalmCosmetic": "figurine-baoli-warden" }
  },
  "sections": [
    { "id": "practice", "kind": "practice", "phrases": 3, "scored": true, "damaging": false },
    { "id": "p1", "kind": "phase", "phase": 0 },
    { "id": "rest1", "kind": "breather", "beats": 16, "scored": false },
    { "id": "p2", "kind": "phase", "phase": 1 },
    { "id": "cp", "kind": "checkpoint" },
    { "id": "p3", "kind": "phase", "phase": 2 },
    { "id": "calm", "kind": "finale", "charges": 3, "spacingBeats": 8 }
  ]
}
```

**Dance example** (Taal Toofan):
```json
{
  "id": "dance-neon-thumka", "version": 1, "schemaVersion": 2, "mode": "dance",
  "name": "Neon Thumka", "access": "free", "family": "filmi", "event": null,
  "moves": ["stepLeft", "stepRight", "clap", "reach", "dip", "waveBoth", "raiseArms", "freeze"],
  "music": { "stems": { "drums": "sha256:…", "bass": "sha256:…", "melody": "sha256:…",
             "layer.clap": "sha256:…", "layer.step": "sha256:…", "vamp": "sha256:…" },
             "firstBeatMs": 1840, "beatsPerBar": 4, "practiceTempo": 0.75,
             "tempoMap": [ { "beat": 0, "bpm": 118 } ] },
  "dance": {
    "sections": [
      { "id": "intro",  "kind": "intro",    "startBeat": 0,   "beats": 16, "vampBeat": 0 },
      { "id": "verseA", "kind": "verse",    "startBeat": 16,  "beats": 64, "vampBeat": 16 },
      { "id": "hook1",  "kind": "hook",     "startBeat": 96,  "beats": 32, "hookStep": "neonHook" },
      { "id": "chill",  "kind": "breather", "startBeat": 128, "beats": 32, "scored": false },
      { "id": "finale", "kind": "finale",   "startBeat": 264, "beats": 8,  "freeze": "skyPoint" }
    ],
    "hookSteps": { "neonHook": [
      { "beat": 0, "move": "stepRight" }, { "beat": 1, "move": "clap", "variant": "mid" },
      { "beat": 2, "move": "stepLeft" },  { "beat": 3, "move": "clap", "variant": "mid" },
      { "beat": 4, "move": "reach", "variant": "upRight" }, { "beat": 5, "move": "reach", "variant": "upLeft" },
      { "beat": 6, "move": "dip" }, { "beat": 7, "move": "waveBoth" } ] },
    "charts": {
      "light":  { "notes": [ { "beat": 16, "move": "stepRight" }, { "beat": 18, "move": "clap", "variant": "mid" } ],
                  "hookPattern": { "neonHook": [0, 2, 4, 6] } },
      "groove": { "notes": [], "hookPattern": { "neonHook": [0, 1, 2, 3, 4, 6] } },
      "toofan": { "notes": [ { "beat": 33.5, "move": "clap", "variant": "mid" } ], "hookPattern": { "neonHook": [0, 1, 2, 3, 4, 5, 6, 7] } }
    },
    "stemMap": { "clap": "layer.clap", "stepLeft": "layer.step", "stepRight": "layer.step", "reach": "melody", "dip": "bass" },
    "highlight": { "preferSection": "hook1", "lengthBeats": 30 },
    "calls": { "locale": ["en-IN", "hi-IN", "gu-IN", "pa-IN"] }
  }
}
```

**Note rules.**
- Beats sit on a 0.5 grid. A 0.25 grid is allowed only on `toofan`, and only for clap and wave.
- `move` comes from a closed enum. `hop` requires `"requiresJumps": true`.
- `side` / `variant` are required where §4.3 says so.
- `LevelLoader` converts beats to ms with `TempoMap` at load, so `BeatDirector` and `BeatSimulator` work in ms.

### 6.6 App (`app/`)
| File | Role |
|---|---|
| `lib/game/beat_game.dart` | A FlameGame shell for v2 modes (leave `forest_game.dart` untouched). It owns `BeatEngine`, polls `BeatClock`, and picks the painter by `level.mode` |
| `lib/game/painters/avatar_painter.dart` | Mirrored landmark avatar: ghost (in play), normalised and neon (clips). Shared by both modes |
| `lib/game/painters/duel_painter.dart` | Guardian procedural sprites, glyphs, count ring, side pads at fixed avatar-relative anchors, Poise and phase bars, hit-stop and shake |
| `lib/game/painters/dance_painter.dart` | Stage, approach rings that shrink over the card lead (ring = window), body-zone landing, beat floor pulse, grade popups, stem lights |
| `lib/game/beat_audio.dart` | Dart wrapper over `native/beat_audio` plus cue SFX |
| `lib/game/duel_catalogue.dart`, `lib/game/dance_catalogue.dart` | Lists v2 levels by mode with access flags (checked at select only) |
| `lib/screens/beat_sync_screen.dart`, `duel_stance_screen.dart` | Calibrations (§6.4, §3.3) |
| `lib/screens/duel_select_screen.dart`, `trophy_shelf_screen.dart` | Craftguard meta |
| `lib/screens/dance_select_screen.dart`, `house_party_screen.dart`, `practice_hook_screen.dart` | Taal Toofan flows, including the per-guest 18+ confirmation |
| `lib/clips/clip_recorder.dart`, `clip_renderer.dart` | Landmark ring buffer (RAM), offscreen render → `ClipEncoder`, share sheet, 24 h cache purge |
| `lib/l10n/` | Calls and captions in en, hi and gu (pa for Dhol songs) |

### 6.7 Server
- **Content module**: serves v2 levels and stem hashes, and gates event windows (server config).
- **Progress**: stores mode results (score, accuracy, grade counts, Sparks lost). No landmarks and no clips.
- **Gyms**: `raid_week` read model plus Crew Raas Nights leaderboard (opt-in).
- **Duel links**: store score only.

### 6.8 Performance budgets (on top of `docs/performance.md`)
| Item | Budget |
|---|---|
| Pose fps for duel and dance | ≥ 24 target; 20–24 → half-time; < 15 → not offered (pause path mid-run) |
| New recognisers (Dart) | ≤ 0.02 ms/frame total, zero allocations per frame (`perf_benchmark_test.dart`) |
| Capture → judged feedback | < 150 ms upper-mid tier, < 200 ms budget tier (the judged *time* is compensated anyway) |
| Painter on budget tier | ≤ 6 ms/frame; ≤ 24 visible targets; particles ≤ 150; 600-frame perf test per painter × theme |
| Audio clock drift vs engine | < 20 ms over 3 min (fake-player test) and < 5 ms jitter after the fit |
| StemPlayer CPU | ≤ 8 % of one core with 5 stems (Helio G85) |
| Stems | ≤ 3.5 MB per song (Opus 96–128 kbps), on-demand download via `/content` for event packs; APK budget unchanged |
| Clip render | ≤ 25 s for a 15 s clip on the budget tier, after the song (never during play) |
| Battery | ≤ 8 % per 20 min solo |
| Model | Keep Lite. Full only on upper-mid tier as an A/B behind the replay gate |

---

## 7. Build plan (milestones)

Every milestone ends with: lint clean, all tests green (motion_core, game_director, app, server,
`content:validate`), `docs/progress.md` updated, and thresholds documented in `docs/game-design.md` (security
controls go in `docs/security.md`, stable decisions in `docs/architecture.md`).

### M0 — Motion fixes and capture time (prerequisite, about 1 week)
| Task | Acceptance | Tests |
|---|---|---|
| Q5-7: the raise-arms recogniser fires for a 400 ms raise (fix the hold/confirm path, target ≈ 350 ms minimum) | 5/5 at 400 ms for gaps of 100/250/400 ms; 0 decoy triggers | `qa5_regression_test.dart` rebuilt from QA5 bullets; `replay_accuracy_test` still passes |
| Q5-9: raise requires wrist visibility ≥ 0.5, else `notVisible` | 0 raises when wrists have vis 0.2 | same |
| Q5-8: `notVisible` for attempts on hidden joints; decide gate 0.42 vs per-attempt reject using replay data | Height 0.38 → reject event, not silence; legs or one side hidden → `notVisible` | same + `quality_gate_test.dart` |
| Q5-10: suppress lean while the squat is down; `Calibrator.build` returns a recoverable failure | Squat + lean 0.8 → 2 squats, 0 leans; σ 0.02 → "hold still" state, no throw | `recognisers_test`, `calibration_test` |
| `captureTsUs` in native + `PoseFrame` + recording v2 | Debug screen shows capture→arrival ms; v1 recordings still load | Kotlin unit test (`android/src/test`) for the time-base conversion; `recording_test` |
| Content quick wins Q5-2/Q5-3 in the validator (streak cap, beginner density) | Validator fails over-cap v1 content (fix the levels in a separate content task) | server content tests |

### M1 — Shared beat foundation (about 2–3 weeks)
| Task | Acceptance | Tests |
|---|---|---|
| Schema v2 with `oneOf`; `level_v2.dart`, `TempoMap` | 18 v1 levels valid unchanged; both v2 examples (§6.5) valid; bad v2 files (lanes present, pad zone other than side, missing music) rejected | `level_v2_test`, server validate tests |
| `WindowTable`, `BeatJudge`, `BeatDirector` | Grade boundaries exact per band; lead-beat rule gives 5 beats for Gentle 84 BPM; spacing and caps hold for every band × difficulty × assist | unit tests |
| `native/beat_audio` StemPlayer + `BeatClock` | Drift < 20 ms over 3 min; stem change lands on the bar line ± 1 audio buffer | fake-player Dart test; device check on 2 phones |
| Beat Sync screen | Median offset is repeatable within ±25 ms across 3 runs on the same phone/route | onset-interpolation tests with synthetic jitter |
| `OnsetTap` + `onset.dart` | Onset error ≤ ½ frame interval on synthetic ramps at 15/30 fps | `onset_test` |
| `BeatEngine` + `ModeRules` interface + `beat_simulator` | Dropout bot: 0 Sparks lost, 0 combo resets from tracking | `beat_engine_test` |

### M2 — Craftguard vertical slice (about 3 weeks)
| Task | Acceptance | Tests |
|---|---|---|
| `GuardRecogniser`, `PunchRecogniser` (side only) | Synthetic: 0 events for forward punch, barrier and raise decoys; recorded clips (≥ 20 players, 2 phones) recall ≥ 0.9, ≤ 1 false trigger per 2 min idle | `combat_recognisers_test`, replay gate |
| Duel Stance calibration (arm lengths, guard) | Old calibrations load with defaults | `calibration_test` |
| `DuelRules` (Sparks, Poise, openings, Calm, Surge, Regroup, Glancing, stuck guard) | Spark loss ≤ 1 per 2 s; missed pad never resets the combo | `duel_rules_test` |
| `beat_game.dart`, `duel_painter.dart`, `avatar_painter.dart` | Budget tier ≤ 6 ms/frame; glyph ≥ 25 mm on a 6.5" screen | painter perf test |
| G1 Baoli Warden + G2 Patang Twins JSON, cues, music | Simulation gates (§6.3) pass; hallway test ≥ 90 %; culture review signed off | `beat_simulation_test` |
| Free access + Trophy Shelf + Calm Seals | Access checked at select only | app widget tests |

### M3 — Taal Toofan vertical slice (about 4 weeks)
| Task | Acceptance | Tests |
|---|---|---|
| `ClapRecogniser`, `DipRecogniser`, `ReachRecogniser`, step onset, `FreezePoseRecogniser` | §4.12 recall gates on recorded dance clips | `rhythm_recognisers_test`, replay gate |
| `WaveRecogniser`, `TwistRecogniser` (any direction) | Wave ≥ 0.9, twist-any ≥ 0.9; or ship without them (charts drop the families) | same |
| `DanceRules` (Josh, Toofan, stems, Skipped, Groove Hold, stars) | Skipped never counts as a Miss; Groove Hold loops the vamp and resumes at the section boundary | `dance_rules_test` |
| `dance_painter.dart` (approach rings, body-zone cards) | ≤ 6 ms/frame | perf test |
| 3 free songs + Chill Chai, with 3 charts each; Practice the Hook | Chart linter + bots: competent ≥ 3★, slow ≥ 2★ on Light/Gentle; Raas BPM caps respected | `beat_simulation_test` |
| Timing field check on the 10-device matrix | Median |error| ≤ 40 ms, p95 ≤ 120 ms after Beat Sync | field protocol, results in `docs/performance.md` |

### M4 — Social and meta (about 3 weeks)
| Task | Acceptance | Tests |
|---|---|---|
| Clip recorder/renderer/encoder (landmarks only) | No camera frame reachable from the Dart clip path (code review + test); 24 h purge; opt-in screen; ≤ 25 s render | `clip_recorder_test` (RAM ring buffer size), security review → `docs/security.md` |
| House Party Relay/Battle/Teams with per-guest 18+ confirmation | Guest data never persisted; handoff costs nothing | widget + engine tests |
| Daily Taal, Beat of the Day, weekly Hook Challenge, Dancer Rank, Calm Seals | Seeds deterministic for each IST date | director/seed tests |
| Crew Raid (`raid_week`) + Crew Raas Nights + duel links | Contributions private by default; links carry score only | server integration tests |

### M5 — Content scale and events (ongoing)
| Task | Acceptance |
|---|---|
| G3–G6 Premium guardians | Each passes the §3.5 checklist and the simulation gates |
| 8 Premium songs + Patang beta (Jan 2027) → Holi public launch (Mar 2027) → Navratri (Sep–Oct 2027) | Event windows set in server config; packs downloadable on demand |
| Signed twist, high clap, low reach | Only after their replay recall gates pass |
| Jodi (optional; owner decision §9) | Capability test ≥ 20 fps with 2 bodies; mirror charts; thermal cap |

---

## 8. Content pipeline and authoring checklists

**Pipeline.**
1. Brief: theme, band fit and move families.
2. Music commission (stems, vamp, 75 % stems) and a musicologist soundalike check.
3. Author the JSON in `content/levels/`.
4. `npm run content:validate` (schema, rules, similarity).
5. `dart test` in `game_director` (bots × bands × difficulties).
6. Culture review and copy/claims review.
7. Hallway playtest at 2 m.
8. Upload stems via `/content` (content-hashed).
9. Set the server event window.
10. Release.

**Guardian checklist (Craftguard).**
- [ ] A named telegraph, plus sound, glyph and voice for every attack; cue family matches the encounter type.
- [ ] Phase 1 = 2 types; phase 2 adds 1; phase 3 combines; first surprise within 45–90 s.
- [ ] Lead-beat rule and spacing pass for every band × difficulty × assist (validator).
- [ ] Pads `side` only (≥ 30°, drawn 60–90°); never a Charge in a strike phrase.
- [ ] Every attack has a low-impact answer; no jumps; Gentle extra breather before phase 3.
- [ ] Silhouette readable at 48 px; wind-up ≥ 15 % of screen width; ≤ 3 flashes/s; particles ≤ 150.
- [ ] Culture review (3 regional reviewers): craft, architecture, nature or railway only.
- [ ] Simulation gates pass; similarity < 0.85 against every other level.

**Song checklist (Taal Toofan).**
- [ ] Original composition with full buyout (sync + social); musicologist check passed; distributor whitelist set.
- [ ] Stems ≤ 5 concurrent; vamp loop per section; 75 % practice stems; ≤ 3.5 MB.
- [ ] One hook step (8 counts) with a spoken breakdown; Light/Groove/Toofan `hookPattern`.
- [ ] Pacing within §4.5 per difficulty; band caps; chill section meets the breather rule; Raas BPM capped by band.
- [ ] No spins, floor touches, contact moves, or jumps unless `requiresJumps`.
- [ ] Lyrics and art: no deities, devotional lines, temples, aarti, firecrackers or alcohol.
- [ ] Bots: competent ≥ 3★, slow ≥ 2★ on Light/Gentle.
- [ ] Calls localised (en, hi, gu; pa for Dhol).

**Copy checklist (every screen, store text, clip overlay).**
- [ ] No kcal, weight, tone, slim, treat/cure, "clinically proven", heart rate or fatigue claims.
- [ ] Says 18+ and "friends", never "family" or "kids".
- [ ] No payment nudges or external links.
- [ ] "Not a medical device" on the Play listing and in the stop-rule sheet.

---

## 9. Open questions and decisions for the owner

| # | Question | Recommendation |
|---|---|---|
| 1 | Final names: "Craftguard Duels" and "Taal Toofan"? | Approve as working names; run the TM search (India classes 9/28/41 and Play) before beta |
| 2 | Quality gate: raise `minBodyHeight` to 0.42 or add per-attempt `notVisible`? | Decide in M0 from replay data; prefer the per-attempt reject (fewer false pauses) |
| 3 | Is Jodi (`numPoses = 2`) in scope? It doubles inference cost and raises bystander and minor-detection questions | Defer to M5; launch with House Party relay only |
| 4 | Bystander detection needs `numPoses ≥ 2` even in solo (cost) | Run `numPoses = 2` at a 1-in-10 frame rate only during House Party, or skip it and rely on the gate |
| 5 | New native plugin `native/beat_audio` vs extending `pose_bridge` | New plugin (separation, testability) |
| 6 | Music budget: 12 commissioned songs with full buyout plus 2/month, and the stems/distributor deal | Needs a budget line; launch with 4 songs if needed (3 free + Chill) |
| 7 | Allow Bluetooth speakers or warn only? | Allow, with Beat Sync per route and a one-time tip |
| 8 | Clip styles: ship Silhouette (own proportions)? | Ship Normalised and Neon first; Silhouette opt-in after privacy review |
| 9 | Navratri Raas Nights free, like Garba Quest? | Yes; it is the free tentpole |
| 10 | Server leaderboards for Daily Taal and songs: friends/gym only, or public per band? | Friends and gym only at launch (anti-mash, privacy) |
| 11 | Should results in these modes count toward the runner's World unlocks or XP? | Shared XP and streak; separate unlock tracks |
| 12 | PAR-Q+ readiness prompt (licence check needed) vs the simple notice | Keep the simple notice plus stop rules; legal to confirm |
| 13 | Gujarat-first rollout flag for Raas content | Yes, as Garba Quest does |
| 14 | Legal review of claims copy (ASCI, Drugs and Magic Remedies Act) before Holi 2027 | Required gate for public launch |
