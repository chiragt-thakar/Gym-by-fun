# Game Mode A: TAALBOUND, the Craft Guardian duels

*Tagline: "Calm the guardians on the beat."* A rhythm-timed, face-to-face duel against
original craft-construct guardians. It is not a lane runner: the camera is fixed, the
guardian faces you, and every attack is a **4-count** you can hear coming.
(Working name. Run a trademark search before launch.)

Grounded in: AGENTS.md rules 1–11, `docs/game-design.md` (moves, windows, spacing,
difficulty), `docs/stages-roadmap.md` §3.4 punch, §3.5 guard, §5 boss rules, §6 bands,
§7 Free vs Premium.

---

## 1. Pitch and pillars

You stand 2 m from the phone. A guardian (a living stepwell, a brass peacock automaton,
a night-mail steam colossus) wakes up and attacks to an original 8-beat groove. Kavi
counts each attack in, "ek… do… teen… **DUCK!**", and you duck, lean, guard or brace
on the hit beat. Clean answers break the guardian's **Poise**. When Poise breaks it
**staggers** and glowing **pads** open, which you punch with smooth, controlled reaches.
Then you raise both arms to **charge** a Resonance that fills the **Calm bar**. Fill
three phase bars and the guardian is calmed, not destroyed. It shrinks into a
collectible figurine on your Trophy Shelf.

Pillars:
1. **Readable by ear.** Every attack follows the same 4-count. You can play with your
   eyes half on the screen.
2. **Fair by construction.** One ask at a time, at least 700 ms apart. Fixed lead
   times. Tracking loss pauses everything. No mashing and no speed bonus.
3. **Punchy feedback.** Hit-stop, shake, adaptive music layers and big readable
   numbers. No haptics, because the phone is on the floor.
4. **Short.** Duels last 3:00–5:00, with phase checkpoints.
5. **Calm, not kill.** Fits the §5 boss tone. Nothing bleeds or dies.

---

## 2. Core loop

```
PHRASE (8 beats, the unit of design)
 beat 1   TELEGRAPH  guardian winds up + 3-pulse rising tone + glyph + voice count "ek"
 beat 2-4 COUNT      "do… teen…" ; glyph grows; lead ≥ band warning + 1.0 s telegraph
 beat 5   IMPACT     answer window (duck / lean / guard / brace)
 beat 7   COUNTER    optional non-damaging pad (punch) after a successful answer
 beat 8   RECOVER    nothing asked (guaranteed rest)

CYCLE = 3–6 attack phrases → STAGGER (Poise ≥ 100) → OPENING (2–4 pads) → CHARGE
        (raise arms) → Calm segment fills
PHASE = 1–3 cycles ; DUEL = 3 phases + Calm finale (4 phases for the final guardian)
```

Why a 4-count: at the band BPM ranges below, 4 beats always lands at or above the band's
warning floor plus the §5 extra 1.0 s telegraph (checked in §6). So one rule ("hit on
5") holds for every guardian, band and difficulty. Harder play adds variety, not
speed (§5).

### 2.1 Game-state dependence (rule 6)
- A punch does nothing unless a pad is live and on that side.
- Raised arms do nothing unless a Charge orb is live.
- A guard does nothing outside a strike's impact window.
- A duck with no beam live gives no points and no "too early" penalty. It is ignored,
  and Kavi does not nag.

---

## 3. Controls → moves → encounter types (no new recognisers needed)

All moves already exist in `motion_core` or roadmap §3. Taalbound is a presentation and
content layer over the same `RunEngine` encounter types.

| Player action (what Kavi says) | Move | Encounter type reused | Damaging | Window | Low-impact answer |
|---|---|---|---|---|---|
| "Duck!" under a sweep | squat | `beam` | yes | existing beam window | half squat (45 %) |
| "Left!" / "Right!" dodge a slam | lean L/R (or side step if enabled) | `laneBlock` (single lane) | yes, not demanding | existing | lean (default) |
| "Guard!" block a strike | guard hold | `strike` | yes, demanding | 600 ms impact window (900 assist); hold ≥ 70 % × hold scale | one hand |
| "Brace!" hold back a wall | barrier hold | `pushWall` | yes, demanding | hold ≥ 70 % of `holdMs` × hold scale | one hand (`barrierOneHand`) |
| "Strike left/right!" opening pad | punch L/R | `padLeft` / `padRight` | **no** | ±400 ms (±600 assist) | reach 0.60, elbow ≥ 130° |
| "Charge!" Resonance | raise arms | `gate` (non-damaging variant `charge`) | no | 900 ms raise window | one arm |
| Bonus chime | raise arms or lean | `orb` | no | existing | same |

Jumps are never used (rule 9). Calf raise is not used in combat.

**Calibration add-on, "Duel Stance" (≈20 s, once, re-run from Settings):** reach left arm
out 0.5 s, then right arm 0.5 s (arm length, per §3.4) → guard hold 1 s → **beat sync**:
"raise your arms on the 4th beat" ×4. The median offset becomes `latencyOffsetMs`
(clamped to 0–250 ms). It is stored on device and only shifts timing *grades*, never
windows.

---

## 4. Systems

### 4.1 Sparks (lives)
- 3 Sparks in every band. Taking a hit costs 1. **At most 1 Spark is lost per 2.0 s**,
  so a hit can never pile onto another.
- **Glancing grace (Gentle only):** a guard, brace or duck that starts ≤ 150 ms after
  the window closes counts as "Glancing". No Spark is lost, and there is no Poise gain.
- 0 Sparks → **Regroup** (see §9): the current phase restarts with full Sparks. Calm
  from earlier phases is kept.

### 4.2 Timing grades (accuracy, not speed)
Measured from the beat after `latencyOffsetMs`:

| Grade | Offset from beat | Score | Poise damage | Surge |
|---|---|---|---|---|
| Perfect | ≤ 150 ms | base × 1.25 | 25 | +15 |
| Good | ≤ 300 ms | base | 20 | +10 |
| OK | anywhere else in the window | base | 15 | +5 |

Base points come from `game-design.md`: beam 100, lane block 100, strike 125, pad 75,
gate 150, orb 50. Holding a move longer earns nothing extra, and nothing rewards speed.

### 4.3 Combo meter
- +1 for each successful answer and for each pad landed. A hit resets it to 0. A missed
  pad or a tracking pause does **not** reset it; the combo freezes instead.
- Score multiplier is +10 % per 5 combo, capped at ×2.0 at combo 50. The step is
  gentler than the runner's because the duel asks for more moves.
- **Adaptive music layers:** combo 0–4: drums only. 5–9: + bass drone. 10–19: + plucked
  lead. 20–34: + bansuri-like synth flute melody. 35+: full mix plus a crowd "haa!" on
  every Perfect. A hit drops the music one layer, not to zero.

### 4.4 Poise, stagger and openings
- Guardian Poise runs 0→100. A counter pad adds 10. A guard deflect adds +5 on top of
  its grade value (the "riposte" feel).
- **Stagger** triggers at Poise ≥ 100, or when the cycle's scripted attacks run out
  (*fallback opening*, see §9). Sequence: 2 beats of breather (1.5–1.8 s, per §5) →
  pads → Charge orb.
- **Pads per opening:** Gentle 2, Balanced 3, Active 3. Active + advanced may use a
  4-pad flurry in phase 3 only (per §5). Pads are always ≥ 2 beats apart and never
  < 700 ms (beginner ≥ 1000 ms).
- **Calm gain per opening:** each pad 20 % of the segment, Charge 40 %. A full stagger
  (Poise ≥ 100) multiplies the gain ×1.5. A fallback opening multiplies it ×1.0.
- If the segment isn't full after the opening, Poise resets to 50, not 0, so the next
  stagger comes about twice as fast.

### 4.5 Surge (the big charge)
- The Surge meter runs 0→100 and fills from grades (above). When full, the next
  opening's Charge becomes a **Surge Finisher**: hold arms up 600 ms (Gentle 450 ms,
  Balanced 540 ms, the §6 hold scale). It fills the whole remaining segment, with a
  0.5× slow motion on the guardian's render for 400 ms and a full-screen ring burst.
- Surge is a reward for clean play. It is never required to finish.

---

## 5. Enemy design template

Every guardian is one JSON file (rule 7). Proposed `content/duels/<id>.json`, validated
by a new `duel.schema.json` that extends `level.schema.json`. The director stays
deterministic (rule 8): the same seed, band and difficulty always give the same phrase
list.

```jsonc
{
  "id": "duel-baoli-warden",
  "name": "Baoli Warden",
  "tier": 1,                      // 1 tutorial … 4 final
  "access": "free",               // map hint only; server entitlement decides (§7)
  "bpm": { "gentle": 80, "balanced": 88, "active": 96 },
  "durationS": 180,
  "sparks": 3,
  "attacks": [
    { "id": "stepSweep", "encounter": "beam", "telegraph": { "visual": "steps glow bottom→top",
      "sound": "3-pulse rising clay-pot tone", "glyph": "chevronDown" },
      "voice": "duck", "phaseMin": 1 },
    { "id": "ledgeDrop", "encounter": "laneBlock", "side": "fromRaisedArm", "glyph": "arrowSide",
      "voice": "leanAway", "phaseMin": 1 },
    { "id": "stoneFist", "encounter": "strike", "glyph": "shield", "voice": "guard", "phaseMin": 2 }
  ],
  "phases": [
    { "name": "Awaken",   "cycles": { "gentle": 1, "balanced": 2, "active": 2 }, "pattern": ["stepSweep","ledgeDrop","stepSweep","ledgeDrop"] },
    { "name": "Pressure", "cycles": { "gentle": 1, "balanced": 2, "active": 2 }, "pattern": ["stoneFist","stepSweep","ledgeDrop","stoneFist"] },
    { "name": "Full Taal","cycles": { "gentle": 2, "balanced": 2, "active": 3 }, "pattern": ["stepSweep+ledgeDrop","stoneFist+counter","ledgeDrop","stepSweep"] }
  ],
  "checkpointBeforePhase": 3,
  "gentleExtraBreatherBeforePhase": 3,
  "calm": { "gates": 3, "spacingBeats": 8, "animation": "sinksIntoWater" },
  "firstCalmCosmetic": "figurine-baoli-warden",
  "lowImpact": { "replace": { } }  // every attack already has a low-impact answer
}
```

Design checklist for each new guardian (review gate):
1. A **named telegraph** (§5 fun rule), with a sound distinct from other guardians but
   the same family per encounter type (beam = falling whoosh layer, strike = double
   drum, etc.).
2. Two attacks in phase 1. Phase 2 adds **one** type. Phase 3 combines them.
3. Every attack has a low-impact answer, and none needs a jump.
4. A silhouette readable as a thumbnail at 48 px. The attack wind-up moves ≥ 15 % of
   screen width.
5. A culture review: craft-, architecture- or nature-inspired. No deities, temples,
   ritual objects, scripture, devotional music or regional caricature.
6. Simulation: the slow bot finishes on beginner + low-impact + Gentle without assist.

---

## 6. Difficulty tuning (numbers)

The band sets the ceiling and floor; difficulty picks inside them (§6 of the roadmap).

| | Gentle (default) | Balanced | Active |
|---|---|---|---|
| BPM (beginner / intermediate / advanced) | 76 / 80 / 84 | 84 / 88 / 92 | 92 / 96 / 104 |
| Beat length | 789–714 ms | 714–652 ms | 652–577 ms |
| Lead (4 beats) | 3.16–2.86 s (needs ≥ 3.0 s); 84 BPM auto-extends to 5 beats = 3.57 s (see note) | 2.86–2.61 s (needs ≥ 2.6 s) ✔ | 2.61–2.31 s (needs ≥ 2.3 s) ✔ |
| Warning floor + telegraph | 2.0 + 1.0 s | 1.6 + 1.0 s | 1.3 + 1.0 s |
| Attack phrases per minute | 7.6–10.5 (1 per phrase, every 2nd phrase may be a rest phrase on beginner) | 10.5–11.5 | 11.5–13 |
| Demanding per minute cap (§6) | 8 | 11 | 14 |
| Demanding in a row | 2 | 3 | difficulty value (3/5/7) |
| Counter pads | after phrases 2 and 4 of each cycle | after every Good+ answer | after every answer |
| Pads per opening | 2 | 3 | 3 (4-pad flurry: advanced, phase 3 only) |
| Pad spacing | 2 beats, ≥ 1000 ms | 2 beats (≥ 1300 ms) | 2 beats (≥ 1150 ms) |
| Guard / brace hold scale | × 0.75 | × 0.9 | × 1.0 |
| Charge hold (raise arms) | 450 ms | 540 ms | 600 ms |
| Glancing grace | 150 ms | off | off |
| Breather | 1 rest bar (≥ 15 s total) every 60 s | ≥ 12 s every 75 s | ≥ 10 s every 90 s |
| Extra breather before phase 3 | +1 cycle-length rest (§5) | — | — |
| Typical duel length | 3:00 | 3:30 | 3:45 (final: 5:00) |

**Lead-time note (a hard rule for the director):** lead = 4 beats, and it must be
≥ warning floor + 1.0 s. Gentle at 84 BPM gives 2.86 s < 3.0 s, so the director
**auto-extends the lead to 5 beats** (3.57 s; "ek… do… teen… char… DUCK") whenever
4 × beat < required lead. The same rule covers any BPM and assist mode (+25 % warning).
It is checked statically in `content:validate` and at run time. Rule: lead beats =
ceil(required / beat), minimum 4.

**Minimum spacing, enforced after band and BPM are applied:** each ask ≥ 700 ms after
the previous answer window closes. Beam answer → next ask ≥ 1100 ms (+250 ms
low-impact). Lean ≥ 700 ms (the duel raises the runner's 650 ms to 700). Raise ≥ 750 ms.
Pads ≥ 700 ms (beginner 1000).

**Expected moves per duel (Balanced, 3:30):** about 32 squats, 24 leans, 14 guards,
8 braces, 30–40 punches and 12 charges, at roughly 22–28 asks per minute. That is
"light–moderate", in line with the §8 body-target language. No calorie or medical
claims.

---

## 7. The roster: six original guardians

Every guardian is an original *craft construct*. The inspiration comes from Indian
architecture, toys, textiles, weather and railways, never from religion. Each has a
named telegraph and a calm animation.

### G1. Baoli Warden (Tier 1, FREE, tutorial)
- **Look:** a stepwell come alive. Sandstone steps stack into a seated giant, with
  water glinting in the stair geometry and jaali-lattice eyes.
- **Attacks:** *Step Sweep* (beam → duck). The steps light bottom→top over 3 beats,
  with a hollow clay-pot rising tone. *Ledge Drop* (laneBlock → lean away). It raises
  one stair-arm, which glows on the side it will slam. *Stone Fist* (phase 2, strike →
  guard). A double drum, then a fist with a shield glyph.
- **Pattern:** strict alternation in phase 1 (duck, lean, duck, lean), so new players
  learn the 4-count.
- **Calm:** it sinks back into the well and the water lights up turquoise.
- **Cosmetic:** sandstone figurine and "Stepwell Teal" hero trim.

### G2. Patang Twins (Tier 1, FREE)
- **Look:** two giant paper-kite spirits, magenta and ochre, tied by a
  glowing string.
- **Attacks:** *String Cut* (laneBlock). The string tightens on one side and that kite
  flutters; lean away. *Dive* (beam → duck). Both kites pull back and a falling whistle
  plays. Phase 2 adds *Tangle* (pushWall → brace): the string knots into a wall that
  pushes forward for 1.5 s (hold scale applies).
- **Pattern:** L/R reading drills. In phase 3 the twins mirror each other (left kite
  telegraphs, right kite follows 1 phrase later). That teaches anticipation without
  adding speed.
- **Calm:** the kites drift down and fold into paper birds.
- **Cosmetic:** kite-tail scarf.

### G3. Brass Mayur (Tier 2, Premium)
- **Look:** a Dokra-style lost-wax brass peacock automaton with clockwork gears and a
  fan of hammered brass feathers.
- **Attacks:** *Fan Flash* (strike → guard). The fan opens with 3 rising brass dings.
  Visually it's a gold glint, never a strobe (≤ 3 flashes/s, WCAG 2.3.1). *Feather
  Volley* (laneBlock). The feathers tilt to one side. *Tail Sweep* (beam → duck).
  Phase 2 adds counter pads after each guard (deflect → riposte).
- **Pattern:** phase 3 "Display": guard → counter → duck → counter, repeated. This is
  the first guardian where the counter pads are the star.
- **Calm:** it folds its fan and preens.
- **Cosmetic:** brass-feather pad-hit VFX.

### G4. Lattoo Titan (Tier 2, Premium)
- **Look:** a Channapatna-style lacquered spinning top, 4 m tall, in candy stripes,
  with a wooden-toy face.
- **Attacks:** *Spin Charge* (laneBlock → lean or side step). It drifts to one side
  with a rising whirr. *Wobble Slam* (strike → guard). It wobbles twice, then lands a
  thud. *Stripe Wall* (pushWall → brace). Phase 2 adds *Topple* (beam → duck): it tips
  forward and the stripe unrolls overhead.
- **Pattern:** the spin speed is visual only; the BPM never changes. Its Poise bar
  shows as the spin slowing. A stagger means it stops spinning and wobbles, which is
  very readable.
- **Calm:** it settles on its point and spins slowly, like a music box.
- **Cosmetic:** lacquer-stripe wristbands on the hero.

### G5. Megh Drummer (Tier 3, Premium)
- **Look:** a monsoon cloud construct with three drum-heads for a chest, rain-bead
  hair and lightning-filament arms.
- **Attacks:** *Thunder Clap* (strike → guard), using the double drum family sound.
  *Rain Wall* (pushWall → brace, longest hold in the roster, 2.0 s × hold scale).
  *Lightning Sweep* (beam → duck), a crackle plus falling whoosh. *Gust* (laneBlock).
- **Pattern:** "call and response". In phase 3 it plays a 2-attack rhythm, then replays
  it once (an *Echo*, telegraphed with the voice line "same again!"). That is memory
  play, still one ask at a time and still on a 4-count.
- **Calm:** the rain softens and a rainbow arcs over the arena.
- **Cosmetic:** "Monsoon" arena skin (rain particles, cap 120).

### G6. Night Mail Colossus (Tier 4, Premium, FINAL)
- **Look:** a steam locomotive that stands up into a guardian of luggage trunks,
  brass whistles and a lantern headlamp. Railway heritage, painted in indigo and cream.
- **Attacks:** *Smoke Bar* (beam → duck). *Signal Swing* (laneBlock: the signal arm
  drops on one side). *Coupling Punch* (strike → guard, then a counter pad). *Steam
  Wall* (pushWall → brace). *Tunnel* (phase 3 modifier, not an attack): the arena
  dims to 40 % and glyphs stay at full contrast. The audio-first showcase.
- **Named telegraph:** "Whistle Call", 3 rising whistle notes.
- **Calm:** it settles as a toy train circling the hero's Trophy Shelf.
- **Cosmetic:** conductor's lantern trail and "Night Mail" title.

**Future roster slots** (same template): Kolam Loom (dot-grid pattern construct with
memory sequences), Ikat Mirage (desert textile shimmer), Banyan Keeper (root-arm giant;
it fits the World 1 Guardian Grove tone).

---

## 8. Boss scripts (deterministic phrase timelines)

### 8.1 Baoli Warden: Gentle, beginner, 80 BPM (beat 750 ms, phrase 6.0 s), 3:00
Lead is 4 beats = 3.0 s (= 2.0 + 1.0 floor ✔).

| Time | Phrases | Content |
|---|---|---|
| 0:00–0:06 | 1 | Intro. The Warden rises; Kavi: "Listen for the count. Move on the hit." |
| 0:06–0:24 | 2–4 | **Practice** (no Spark loss): Step Sweep with hint, Ledge Drop L with hint, Charge orb |
| 0:24–0:48 | 5–8 | **Phase 1 Awaken:** duck, lean R (+counter pad), duck, lean L (+counter pad). Poise 4×20 + 2×10 = 100 → stagger |
| 0:48–0:54 | 9 | Opening: breather 2 beats, pad L (beat 3), pad R (beat 5, 1.5 s later), Charge (beat 7) |
| 0:54–1:06 | 10–11 | Breather (orbs only, music drops to drums + drone) |
| 1:06–1:36 | 12–16 | **Phase 2 Pressure:** Stone Fist (guard), duck, lean L, Stone Fist (+counter), opening |
| 1:36–1:42 | 17 | **Checkpoint**: a lost Spark returns |
| 1:42–1:54 | 18–19 | Gentle extra breather (§5) |
| 1:54–2:42 | 20–27 | **Phase 3 Full Taal:** duck → lean pairs (2 phrases), guard + counter, opening; repeat once with mirrored sides |
| 2:42–3:00 | 28–30 | **Calm:** 3 Charge orbs, one per phrase (6 s apart), phase bar "almost there" glow, calm animation, results |

Demanding per minute peaks at 5 (cap 8 ✔). At most 2 demanding in a row ✔. About 22
asks per minute.

### 8.2 Night Mail Colossus: Balanced, intermediate, 88 BPM (beat 682 ms, phrase 5.45 s), 5:00
Lead is 4 beats = 2.73 s (≥ 2.6 ✔).

| Time | Phase | Content |
|---|---|---|
| 0:00–0:22 | Practice | Whistle Call explained; Smoke Bar, Signal Swing, Charge (no Spark loss) |
| 0:22–1:27 | **1 Departure** | 2 cycles: Smoke Bar, Signal Swing L, Smoke Bar, Signal Swing R → opening (3 pads on the boiler grates + Charge) |
| 1:27–1:43 | Breather | Station platform; orb chimes only |
| 1:43–2:49 | **2 Ghat Climb** | 2 cycles adding Coupling Punch (guard → counter) and Steam Wall (brace 1.5 s × 0.9) |
| 2:49 | Checkpoint | A Spark returns; music lifts a key |
| 2:49–3:05 | Breather | (Gentle: +1 cycle-length breather) |
| 3:05–4:22 | **3 Night Run** | **Tunnel** dims the arena. Combos: Smoke Bar→Signal Swing; Coupling Punch→counter→Steam Wall. 2 openings (advanced Active: one 4-pad flurry) |
| 4:22–5:00 | **4 Terminus (finale)** | Surge Finisher offered if the meter is full, else 3 Charge orbs 3 s apart; the Colossus calms; Trophy Shelf animation |

### 8.3 Phase summaries for G2–G5
| Guardian | Phase 1 | Phase 2 adds | Phase 3 twist | Length (Balanced) |
|---|---|---|---|---|
| Patang Twins | String Cut, Dive | Tangle (brace) | Mirrored twin telegraphs, 1 phrase apart | 3:00 |
| Brass Mayur | Feather Volley, Tail Sweep | Fan Flash (guard) + riposte | "Display" guard→counter→duck→counter | 3:30 |
| Lattoo Titan | Spin Charge, Wobble Slam | Stripe Wall (brace), Topple | Stagger = spin stops; double opening | 3:30 |
| Megh Drummer | Thunder Clap, Gust | Rain Wall (2.0 s brace) | Echo: 2-attack call, replayed once | 4:00 |

---

## 9. Failure and forgiveness rules

1. **Tracking loss (rule 5):** the guardian freezes mid-wind-up. The music ducks to a
   held drone, the world slows via the `Pacer` (60 % on amber, stop on red), and Kavi
   explains: "I lost your feet. Step back a little." Pending attacks are forgiven under
   the existing rules (300 ms before cue, 800 ms reaction, 1200 ms in assist). After
   tracking resumes there is a 1-phrase re-count before the next attack. The combo
   freezes and is not reset.
2. **Missed pad or Charge:** no damage and no combo reset. It only lowers calm gain
   (§5: the weak point never damages).
3. **Wrong move** (e.g. guard on a duck): it counts as a miss, at most 1 Spark per
   2.0 s. Kavi gives a short, specific line: "That was a duck, low!"
4. **`tooEarly` / `tooShallow` rejections** never cost a Spark. A shallow duck still
   inside the window is graded OK in low-impact.
5. **0 Sparks → Regroup.** The phase restarts from its first phrase with 3 Sparks. Calm
   from earlier phases, XP and combo-best are kept. After **2 Regroups in the same
   phase**, the game offers Assist once (+25 % warning). It is never forced, and no
   "game over" text appears.
6. **Fallback opening:** if a cycle's scripted attacks run out before Poise reaches 100,
   the opening still happens at ×1.0. **Stuck guard:** if a phase bar isn't full after
   its scripted cycles plus 2 repeat cycles, it completes anyway ("The Warden respects
   your effort"). That run earns 1 star max.
7. **Checkpoint before the final phase** returns a Spark. A checkpoint restart follows
   the existing reset semantics.
8. **Struggle rule** (§6): two duels in a row with 2+ Sparks lost → offer one step down.
   This is never automatic.
9. **Never mid-run paywall.** Access is checked only at guardian select (§7).

---

## 10. Progression and rewards (cosmetics only)

- **Calm Seals** per guardian, in three tiers: *Clay* (calmed), *Brass* (calmed with
  ≥ 2 Sparks), *Indigo* (calmed on Balanced or harder with combo-best ≥ 30). The tier
  is band-relative, so Gentle players can earn Indigo on Gentle advanced.
- **Trophy Shelf:** a figurine for each first calm (§5 unique cosmetic). Tapping one
  replays the calm animation.
- **Hero wardrobe** from textile crafts (all original patterns): Phulkari-style jacket,
  Ikat sneakers, Bandhani bandana, Ajrakh-style scarf. Unlocked by seals, the hero
  level (existing XP formula) and daily stamps.
- **VFX unlocks:** pad-hit sparks (brass, paper confetti, rain beads) and Surge rings.
- **No stat boosts, no loot boxes, no paid currency.** Everything is earned by play.
  Premium unlocks guardians, not power.
- XP uses the existing rule (score/20 + active s/10 + 50 on completion). Crew effort
  points are unchanged (max 100 per session).

---

## 11. Meta

### 11.1 Daily Taal (daily challenge)
- Seeded by IST date (deterministic). It picks one unlocked guardian plus one modifier:
  *Mirror* (L/R swapped), *Echo* (one replay phrase per cycle), *Lantern Night*
  (dimmed arena, glyphs at full contrast), *Slow Taal* (−8 BPM, longer holds ×1.1,
  hold scale still capped by band).
- 2:30–3:00, one guardian phase set. Only the **first 3 attempts per day** count, to
  discourage over-play. The 45 s warm-up and cool-down are included (§6).
- Each completion earns a stamp; 7 stamps (not necessarily consecutive) give a
  cosmetic. Streaks follow the existing IST/shield rules.
- Optional leaderboard: opt-in, only within the same band + difficulty, scores only. No
  body data and no video.

### 11.2 Gym Crew Raid (weekly, async)
- Monday 00:00 – Sunday 23:59 IST. The crew faces a **Raid Form** guardian (it rotates
  weekly: Colossus, Megh, Lattoo…).
- The shared Raid Calm bar is filled by members' existing crew effort points from any
  Taalbound duel. The target is 250 × active members (played in the last 14 days),
  min 500, max 25,000.
- Tiers at 50 / 100 / 150 % give crew banner pieces and a crew-wide figurine paint
  variant.
- Individual contributions are private by default. "Crew Heroes" names show only for
  members who opt in. No per-player shaming and no "you let your crew down"
  notifications.
- Server: reuses gyms + progress modules. A new read model, `raid_week`, aggregates the
  effort points that already exist. No real-time networking.

---

## 12. Audio and visual direction ("Craft-punk")

**Visual:** hand-crafted materials in a clean, flat-shaded 2.5D style. Sandstone,
lacquered wood, hammered brass, paper and indigo-dyed cloth. Motifs: jaali lattice,
kolam dot-grids (as geometry only), block-print borders, paisley (ambi) curves. Palette
tokens: Indigo `#1F2A5C`, Terracotta `#C4552D`, Brass `#C9A227`, Teal `#1E8C8A`, Cream
`#F3E9D2`, Kite Magenta `#C2185B`. Every glyph has a 3 px cream outline on any
background.

**Readable from 2 m on a 6.5" phone (landscape on the floor):**
- The guardian sits top-centre at 45 % of screen height. The attack glyph is centred at
  **22 % of screen height (≥ 25 mm)**, high-contrast, with shape + position + sound and
  never colour alone.
- Pads sit at the left/right thirds, at the avatar's shoulder height, 18 % of height,
  with a large **L/R** letter.
- The hero ghost avatar (from landmarks) sits bottom-centre at 25 % of height,
  mirrored.
- The combo number sits top-right at 10 % of height. The phase bar runs the full width
  at the top (6 %). Sparks sit top-left.
- The count-in ring pulses on every beat, so players without sound still get the 4-count.

**Feel (no haptics):**
- **Hit-stop** is render-only. The game clock and music never pause, so windows stay
  exact. Perfect pad 70 ms, Good 50 ms, stagger 120 ms + guardian 0.5× slow-mo for
  300 ms.
- **Screen shake** only on *your* hits, never when you are hit. Perfect 6 px, Good
  3 px, stagger 10 px, 150 ms exponential decay. Plus a 3 % zoom punch on stagger.
  "Reduce motion" sets shake and zoom to 0.
- Being hit shows a brief vignette and a soft "thud". No red flash and no shake.
- Flashes are capped at 3 per second. Particles are capped at 150 on screen (low-end
  device floor of 30 fps).

**Audio:**
- Original 8-beat grooves at the BPMs above (composed or generated in-house, e.g.
  extending `tools/gen_cues.py`). Synth dhol-like low drum, tabla-like bol patterns,
  plucked lead and a bansuri-like synth flute.
- **No devotional ragas, bhajans, chants or temple bells.**
- Cue families match the runner (§5): beam = falling whoosh, lane block = two knocks,
  strike = double drum + whoosh + "ting" on deflect, pushWall = rising rumble, pad =
  padded "thup" (L lower than R), gate/charge = 3-note bell. Each guardian adds a
  timbre layer on top.
- **Voice:** Kavi calls the count in English, Hindi or Hinglish ("ek, do, teen —
  DUCK"), with Tamil, Telugu, Marathi and Bengali counts as packs later. Guardians make
  non-verbal sounds only (creaks, brass hums, whistles).
- Every voice line is captioned. **Quiet Mode** (for shared homes) removes the music,
  keeps the cues at −12 dB and enlarges the visual count ring.

---

## 13. Free vs Premium (consistent with roadmap §7, AGENTS rule 11)

| | Free | Premium (₹129/mo, ₹699/yr, Google Play Billing only; gym members free) |
|---|---|---|
| Guardians | Baoli Warden, Patang Twins (all bands, all difficulties) | Brass Mayur, Lattoo Titan, Megh Drummer, Night Mail Colossus, future roster |
| Daily Taal | Draws from the free roster | Draws from all unlocked guardians |
| Crew Raid | Contributes via free duels | Same, plus Raid Form duels of Premium guardians |
| Cosmetics | Earned from free guardians, stamps, raid | Also earned from Premium guardians. Never sold directly |
| Modifiers | Mirror | Mirror, Echo, Lantern Night, Slow Taal in free play |

Access is checked at guardian select only. No countdowns, no pop-ups, no external links.

---

## 14. Metrics to validate fun (and targets)

| Metric | Target | How |
|---|---|---|
| First-duel calm rate (Baoli, Gentle beginner) | ≥ 85 % | analytics event `duel_calm` |
| "Did that hit feel fair?" (1-tap, after a lost Spark, 1 in 3 runs) | ≥ 85 % "yes" | on-device survey, opt-in sync |
| Telegraph readability hallway test at 2 m (12 players per band) | ≥ 90 % name the right move ≤ 1 s after the glyph | playtest protocol |
| Effort "How did that feel?" Easy / Just right / Hard | ≥ 60 % "Just right"; < 15 % "Hard" on Gentle | post-run |
| `tooEarly` + `tooShallow` rejections | < 10 % of answers | recorder accuracy reports |
| Tracking-forgiven encounters | < 5 % of encounters | `RunEngine` logs |
| Perfect + Good share | 55–75 % (> 85 % = too easy, < 40 % = latency problem) | grade histogram per device model |
| Time to first stagger | ≤ 45 s | timeline |
| Mid-phase quits | < 8 % of runs | `duel_abandon` with phase |
| Same-day replay | ≥ 30 % of players | sessions |
| D7 retention, mode players vs runner-only | +5 pp | cohort |
| Daily Taal 7-stamp completion within 14 days | ≥ 25 % | stamps |
| Raid weeks reaching 100 % | 40–60 % (higher = target too low) | server |
| Active seconds per duel | ≥ 150 (3:00 duel) | existing XP input |
| Simulation | slow bot finishes every guardian on beginner + LI + Gentle; competent bot on all | CI test (same as stage sims) |

---

## 15. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Pose latency (60–150 ms) makes rhythm feel "off" | `latencyOffsetMs` beat-sync calibration; generous windows; grades only change score, never Sparks; monitor the grade histogram per device |
| Punches become flailing | §3.4 controlled-reach rules, a pad must be live, ≥ 700 ms spacing, no speed scoring, "smooth and controlled" hint |
| Guard vs raise-arms confusion | Existing §3.5 exclusion; Charge never shares a phrase with a strike; distinct glyphs (shield vs up-arrow) |
| Small Indian living rooms | Default answers need ≤ 1 m width (lean, not side step); side step opt-in only; space check during calibration |
| Shared homes / noise | Quiet Mode, captions, visual count ring |
| Cultural / religious sensitivity | Craft and architecture motifs only; external review by 3 reviewers from different regions; ban list (deities, temples, ritual items, devotional music); avoid saffron-green flag palettes on guardians |
| Violence perception | "Calm, not kill", no blood, guardians end peaceful and collectible |
| Overexertion | Band caps, breathers, 3 counted daily attempts, "take a break" card after the band's max stages, no "no-breaks" mode |
| Motion discomfort from shake/flash | Shake only on player hits, reduce-motion toggle, ≤ 3 flashes/s |
| Looking like Beat Saber / Fitness Boxing / Ring Fit | Fixed-camera guardian duel with a 4-count call, original constructs, no blocks or highways, no ring; art and music reviewed for originality (rule 10) |
| Low-end performance | Particle cap 150, procedural sprites like the existing painter, 30 fps floor; 4-count timing is audio-clock driven |
| Scope creep | Ship G1 + G2 first. They reuse existing encounter types; new work is the duel scene, `duel.schema.json`, Poise/Surge state and the beat-sync calibration |
| Name collision | Trademark search on "Taalbound" before store use |

---

## 16. Build order (smallest valuable slice)

1. `duel.schema.json` + Baoli Warden JSON + `content:validate` lead-time rule
   (lead beats = ceil(required/beat), min 4).
2. A duel Flame scene: fixed camera, guardian painter, glyphs, count ring. It reads
   `RunEngine` outcomes, and Poise/Surge/combo are pure Dart in `game_director`.
3. Beat-sync step in calibration (`latencyOffsetMs`), tested on recorded landmark
   fixtures.
4. Simulation tests: slow and competent bots × 3 bands × 3 difficulties.
5. Patang Twins, the Daily Taal seed, and the cosmetics shelf. Then the Premium roster
   and Crew Raid.
