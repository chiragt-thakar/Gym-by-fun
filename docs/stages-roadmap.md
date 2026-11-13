# Stages roadmap: design spec for the remaining worlds

This document is the design spec for every stage still to build. A developer or coding
agent should be able to implement any stage from it without other context. Read
`AGENTS.md`, `docs/game-design.md` and `docs/progress.md` first. If this document and
`docs/game-design.md` disagree, `game-design.md` wins for anything already implemented.
Copy a value into `game-design.md` once it ships.

All thresholds here are **starting values**. Tune them only with recorded data, and only
while `packages/motion_core/test/replay_accuracy_test.dart` passes.

Hard rules that apply to every stage below (from `AGENTS.md`):

- Low-impact is the default. No jumps unless the player turns jumps on. Every new move
  has a low-impact alternative, and the calf raise stands in for any jump.
- A tracking failure never costs a heart or progress. The encounter is forgiven and the
  `Pacer` slows the world.
- A recognised move does nothing on its own. Only `RunEngine` decides outcomes, from
  game state.
- Level content lives in JSON (`content/levels/`), validated by
  `content/schema/level.schema.json`. Do not hardcode level content in Flame components.
- Original art and sound only. No real teams, leagues, players, logos, kits or brand
  colours (this matters most in Stadium Nights). No deity imagery or religious symbols
  in the festival events.
- No medical, fitness-outcome or weight-loss claims in hints, titles or descriptions.
  Do not write "burn calories" or "tone"; "Nice rhythm!" is fine.
- No payment nudges and no links outside Google Play. Access (Free / Premium) is checked
  only at stage select, never mid-run (§7).
- Every stage has an info sheet entry (§8, §9): body targets, intensity wording and
  approved benefit copy, plus the standard disclaimer.

**Map of this document:** §1 status · §2 stages by world · §3 new moves · §4 checklist ·
§5 boss rules · §6 player journey and age bands · §7 Free vs Premium · §8 body targets,
benefits and sources · §9 stage info sheet · §10 fun and anti-boredom rules.

---

## 1. Status of the existing stages

Code world numbering follows `app/lib/game/stages.dart`, where `_laterWorlds` fills
worlds 5 to 9 in order. **Stadium Nights is world 5**, so the plan's "5 Ancient Temple ...
8 Final Guardian" become code worlds 6 to 9. Level ids use the code number.

| # | Level id | World | Stage | Length | Focus | Status |
|---|---|---|---|---|---|---|
| 1 | `w1-forest-escape` | 1 Forest Awakening | 1-1 Forest Escape | 3:01 (181 s, 56 enc.) | Tutorial: squat, lean, raise arms, gates | Implemented |
| 2 | `w1-river-crossing` | 1 Forest Awakening | 1-2 River Crossing | 3:00 (180 s, 68) | Lean-then-squat combos | Implemented |
| 3 | `w1-guardian-grove` | 1 Forest Awakening | 1-3 Guardian Grove | 3:30 (210 s, 82) | Mini-boss: sweeping branches, root walls, gate calm | Implemented |
| 3a | `w1-firefly-trail` | 1 Forest Awakening | 1-4 Firefly Trail | 3:00 (180 s, 67) | Gentle reach-heavy replay: firefly orbs, deer bonus trail (~45 s), glade breather (~90 s), golden gate + "almost there" (135 s), checkpoint 140 s | Implemented |
| 3b | `w1-garba-quest-event` | 1 Forest Awakening (event slot) | 1-5 Garba Quest | 3:00 (180 s, 74) | Navratri rhythm event (interim): orbs, arches and circling lean patterns on a 4-beat taali (2.5 s → 2.2 s → 2.0 s), checkpoint 125 s; `SceneTheme.neon`. Ships in World 1 because the schema allows world 1–8 only; becomes `w0-garba-quest` once world 0 + event windows exist | Implemented |
| 4 | `w2-desert-dunes` | 2 Desert Trials | 2-1 Desert Dunes | 3:00 (180 s, 68) | Desert theme, mirage orbs | Implemented |
| 5 | `w2-sandstorm-temple` | 2 Desert Trials | 2-2 Sandstorm Temple | 3:30 (210 s, 82) | Two-lane walls, harder combos | Implemented |
| 5a | `w2-oasis-caravan` | 2 Desert Trials | 2-3 Oasis Caravan | 3:00 (180 s, 66) | Existing types only (beam, laneBlock ≤ 2 lanes, orb, gate): caravan bell gate surprise (~46 s), palm-shade breather 90–106 (orbs only), golden palm gate + "almost there" (~134 s), checkpoint 150 s. Premium | Implemented |
| 6 | `w3-neon-city-rooftops` | 3 Neon City | 3-1 Neon City Rooftops | 3:00 (180 s, 53) | Neon signs (beams), drones (blocks), power cells (orbs) | Implemented |
| 7 | `w3-neon-city-chase` | 3 Neon City | 3-2 Neon City Chase | 3:30 (210 s, 68) | Drone chase, gate dash | Implemented |
| 7a | `w3-neon-night-market` | 3 Neon City | 3-3 Neon Night Market | 3:00 (180 s, 66) | Existing types only: market scan-gate surprise (~46 s), quiet-alley breather 90–106 (orbs only), lantern gate + "almost there" (~134 s), checkpoint 150 s. Premium | Implemented |
| 8 | `w4-mountain-trail` | 4 Mountain Expedition | 4-1 Mountain Trail | 3:00 (180 s, 49) | Gentle trail, low density | Implemented |
| 9 | `w4-summit-storm` | 4 Mountain Expedition | 4-2 Summit Storm | 3:30 (210 s, 62) | Wind gusts, rockfall | Implemented |

Access: World 1 stages are **Free**; World 2–4 stages become **Premium** when billing
ships (§7). Stages 4, 8 and 12 in play order (`w2-desert-dunes`, `w3-neon-city-rooftops`,
`w4-mountain-trail`) are the deload stages for their worlds (§6).

Existing `SceneTheme`s (in `app/lib/game/forest_game.dart`): `forest`, `desert`, `neon`,
`mountain`. Existing `SceneProps`: `trees`, `cacti`, plus whatever the neon and mountain
themes use.

Two schema limits block the roadmap and must be lifted first (see §3.11). `world` is
capped at `maximum: 8`, but Final Guardian is world 9 and events need their own number.
The encounter `type` enum has only four values.

---

## 2. Roadmap by world

### Conventions used below

- **Standard segment plan (S3)** for a 3:00 stage: practice 0–30, learn 30–90,
  breather 90–105 (orbs only), combo 105–150, checkpoint 150–151, finale 151–180.
- **Standard segment plan (S3.5)** for a 3:30 stage: practice 0–30, learn 30–100,
  breather 100–115, combo 115–170, checkpoint 170–171, finale 171–210.
- **Boss plan (B4)** for a 4:00 boss stage: practice 0–25, learn 25–85, breather 85–100,
  combo 100–150, checkpoint 150–151, boss finale 151–240 (see §5).
- New encounter type names (`slideWall`, `pushWall`, `jogTrack`, `padLeft` and
  `padRight`, `strike`, `ball`, `wicket`, `balanceBeam`, `hurdle`) are specified in §3.
- "Mix" percentages are shares of encounters in the learn and combo segments.
- Every stage needs `minDifficulty` extras for intermediate and advanced. These are
  mostly centre-lane orbs placed mid-gap, as in the existing stages. Every stage must pass
  the simulation at every difficulty, low-impact on and off, with the competent and slow
  bots.
- Hints: `maxLength` 80. Use them on the first encounter of each new type and on segment
  starts.

---

### World 1: Forest Awakening (`SceneTheme.forest`). Implemented, one optional stage

**Theme:** a waking forest of warm dawn light, mossy logs and fireflies.
**Moves:** squat, lean, raise arms.

| Id | Title | Length | Segments | Mix | Notes |
|---|---|---|---|---|---|
| `w1-forest-escape` | Forest Escape | 3:01 | S3 | existing | Implemented |
| `w1-river-crossing` | River Crossing | 3:00 | S3 | existing | Implemented |
| `w1-guardian-grove` | Guardian Grove | 3:30 | S3.5 | existing | Implemented (mini-boss) |
| `w1-firefly-trail` | Firefly Trail | 3:00 (Implemented as 1-4) | practice 0–20, learn 20–80, breather 80–100, combo 100–130, checkpoint 130–131, finale 131–150 | beam 30 %, laneBlock 35 %, orb 35 % | A relaxed replay stage for beginners. Warning 2.2 s on beginner. Not required for unlocks; insert it after 1-3 only if the team wants a softer bridge. |

**Sound ideas:** soft wooden whoosh (beam), bird flutter on checkpoint.
**Hints:** "Fireflies love raised arms." / "Lean early, stay smooth."

---

### World 2: Desert Trials (`SceneTheme.desert`). Two stages implemented, two to build

**Theme:** golden dunes, a buried temple and heat shimmer.
**New move:** side step (§3.1) as a full move, with the encounter `slideWall`.

| Id | Title | Length | Segment plan | Mix | Difficulty notes |
|---|---|---|---|---|---|
| `w2-desert-dunes` | Desert Dunes | 3:00 | S3 | existing | Implemented |
| `w2-sandstorm-temple` | Sandstorm Temple | 3:30 | S3.5 | existing | Implemented |
| `w2-oasis-caravan` | Oasis Caravan | 3:00 | S3 | beam / laneBlock / orb / gate | Implemented as 2-3 (bridge stage before side step ships) |
| `w2-shifting-sands` | Shifting Sands | 3:00 | S3; practice introduces `slideWall` at 10 s and 20 s, both with hints | slideWall 20 %, laneBlock 25 %, beam 25 %, orb 30 % | First stage with side step. Beginner gets at most one slideWall per 8 s, and never a slideWall directly before a two-lane block. |
| `w2-scorpion-king` | Scorpion Guardian | 4:00 | B4 | slideWall 20 %, beam 30 %, laneBlock 25 %, orb/gate 25 % | Mini-boss: a stone scorpion (original design, not a creature from any game). Its tail sweep is a telegraphed `beam` (1 s extra cue). Its claw swipe is a `slideWall` from the side it raises. Gates calm it. Three phases of 25 s, each one encounter denser. |

**Colours:** reuse `SceneTheme.desert`. Optionally add `desertNight` for the boss:
background `0xFF1E1426`, skyTop `0xFF2B2250`, skyBottom `0xFFB86B4B`, sun `0xFFFFE9C4`,
ground `0xFF9C7448`, beam `0xFFD9A55B`, block `0xFF6E4A2B`.
**Sound:** slideWall = rising sand hiss with a left or right stereo pan (the pan tells
the side; never rely on the pan alone). Boss telegraph = low clay drum.
**Hints:** "Sand wall sliding in! Step your whole body aside." / "Watch the tail — duck
when it glows."

---

### World 3: Neon City (`SceneTheme.neon`). Two stages implemented, two to build

**Theme:** night rooftops, holo signs and friendly-but-rogue delivery drones.
**New move:** barrier hold (§3.2), with the encounter `pushWall`.

| Id | Title | Length | Segment plan | Mix | Difficulty notes |
|---|---|---|---|---|---|
| `w3-neon-city-rooftops` | Neon City Rooftops | 3:00 | S3 | existing | Implemented |
| `w3-neon-city-chase` | Neon City Chase | 3:30 | S3.5 | existing | Implemented |
| `w3-neon-night-market` | Neon Night Market | 3:00 | S3 | beam / laneBlock / orb / gate | Implemented as 3-3 (bridge stage before barrier hold ships) |
| `w3-hologram-wall` | Hologram Walls | 3:00 | S3; first `pushWall` at 12 s (hold 1.5 s) | pushWall 15 %, beam 25 %, laneBlock 30 %, orb 30 % | Holds: 1.5 s beginner, 2.0 s intermediate, 2.5 s advanced, set by `holdMs` plus a difficulty scale. Leave ≥ 2.5 s after each pushWall before anything demanding. pushWall counts as demanding. |
| `w3-drone-core` | Drone Core | 4:00 | B4 | pushWall 15 %, beam 25 %, laneBlock 25 %, slideWall 10 %, orb/gate 25 % | Boss: the drone hub. Phase 1 sweeps scanner beams (duck). Phase 2 fires a pulse (pushWall). In phase 3 the core opens (raise-arms charge on a gate). §5 pattern without the punch, since punch is not taught until world 7. |

**Colours:** `SceneTheme.neon`.
**Sound:** pushWall = electric hum that rises in pitch while held and resolves in a
chord when it breaks. Drone = two-tone chirp.
**Hints:** "Hologram wall! Push both palms forward and hold." / "Keep holding… it's
breaking!"

---

### World 4: Mountain Expedition (`SceneTheme.mountain`). Two stages implemented, two to build

**Theme:** a Himalaya-inspired trail with original peaks, prayer-flag-like bunting in
abstract colours and no real place names. Snow and pine.
**New moves:** jog in place (§3.3), with `jogTrack`; calf raise (§3.9), with `hurdle`.

| Id | Title | Length | Segment plan | Mix | Difficulty notes |
|---|---|---|---|---|---|
| `w4-mountain-trail` | Mountain Trail | 3:00 | S3 | existing | Implemented |
| `w4-summit-storm` | Summit Storm | 3:30 | S3.5 | existing | Implemented |
| `w4-glacier-run` | Glacier Run | 3:00 | S3; the breather becomes a 15 s `jogTrack` (march in low-impact) | hurdle 20 %, beam 25 %, laneBlock 25 %, orb 20 %, jogTrack 2 per run | `jogTrack` never damages: it fills a boost meter that adds score. In the 2 s after a jogTrack ends, place only orbs. Hurdles are answered by a calf raise, or by a jump if the player turned jumps on. |
| `w4-yeti-pass` | Snow Guardian | 4:00 | B4 | hurdle 15 %, beam 25 %, laneBlock 25 %, pushWall 10 %, orb/gate 25 % | Mini-boss: a gentle snow guardian (original, friendly). It rolls snowballs (laneBlock), blows gusts (pushWall) and drops ice ledges (hurdle). Gates calm it. |

**Colours:** `SceneTheme.mountain`.
**Sound:** hurdle = short wooden "tock-tock" rising, with a different interval from the
laneBlock knocks. jogTrack = steady footstep loop at music BPM.
**Hints:** "Ice ledge! Rise up on your toes." / "Jog track — march in place to fill the
boost."

---

### World 5: Stadium Nights (new `SceneTheme.stadium`). Four stages

**Theme:** an original floodlit cricket ground at night with a fictional crowd and
abstract banners. **No league, team, player names, logos, kit colours or trophies.**
Crowd sound is a generated murmur. Do not use real commentary or chants.
**New moves:** batting swing (§3.6), with `ball`; bowling action (§3.7), with `wicket`.
Handedness comes from Settings (right or left).

| Id | Title | Length | Segment plan | Mix | Difficulty notes |
|---|---|---|---|---|---|
| `w5-nets-practice` | Nets Practice | 3:00 | S3; practice has 3 slow balls at 8, 16, 24 s with hints | ball 30 %, beam 20 %, laneBlock 20 %, orb 30 % | Ball warning 2.5 s on beginner. A missed ball costs nothing (like an orb). |
| `w5-floodlight-run` | Floodlight Run | 3:00 | S3; learn introduces `wicket` at 35 s | ball 20 %, wicket 15 %, beam 20 %, laneBlock 25 %, orb 20 % | Never a ball and a wicket within 3 s of each other (both are big upper-body moves). |
| `w5-super-over` | Super Over | 3:30 | S3.5; the finale is "6 balls": alternating ball and gate | ball 25 %, wicket 15 %, beam 20 %, laneBlock 20 %, orb/gate 20 % | The score multiplier shows as "runs". That is flavour only and does not change the scoring rules. |
| `w5-stadium-final` | Stadium Final | 4:00 | B4 | ball, wicket, beam, laneBlock, slideWall | Mini-boss: a giant mechanical bowling machine (original). It telegraphs (light flash) then delivers a ball (swing), a bouncer (beam: duck) or a wide sweep (slideWall). In the weak-point phase you bowl at its target (wicket ×3). No punch here. |

**Colours (`SceneTheme.stadium`):** background `0xFF0A1A12`, skyTop `0xFF060B1E`,
skyBottom `0xFF1E3A5F`, sun (floodlight) `0xFFF5F9FF`, hillFar (stands) `0xFF2A2F45`,
hillNear `0xFF1E2236`, ground `0xFF2F7D3A`, road (pitch) `0xFFC8B27A`, propTrunk (light
pylons) `0xFF8E99A8`, propCrown `0xFFFFF6C8`, beam `0xFFE0E0E0`, block `0xFF3B6EA8`.
New `SceneProps.floodlights`.
**Sound:** ball = leather "thwock" on contact plus a soft whistle on delivery. Wicket =
wooden stumps clatter. Crowd swell on a streak of 5 or more.
**Hints:** "Ball coming! Swing through with both hands together." / "Stumps lit — bowl
over the top."

---

### World 6: Ancient Temple (new `SceneTheme.temple`). Four stages

**Theme:** an original jungle temple with carved geometric stonework, water channels and
lamps. The architecture is fictional, with no real monuments and no deity carvings.
**New move:** balance (§3.8), with `balanceBeam`. It reuses side step and barrier hold.

| Id | Title | Length | Segment plan | Mix | Difficulty notes |
|---|---|---|---|---|---|
| `w6-temple-steps` | Temple Steps | 3:00 | S3 | beam 25 %, laneBlock 25 %, slideWall 15 %, hurdle 10 %, orb 25 % | Recap world: all moves so far, gentle density. |
| `w6-stone-bridge` | Stone Bridge | 3:00 | S3; first `balanceBeam` at 14 s (2 s hold) | balanceBeam 10 %, pushWall 10 %, beam 25 %, laneBlock 25 %, orb 30 % | Balance holds: 2 s beginner, 3 s intermediate, 4 s advanced. Low-impact uses the toe-tap stance. After a balanceBeam, the next 2 s are empty. |
| `w6-hall-of-echoes` | Hall of Echoes | 3:30 | S3.5; a "call and answer" combo segment: a cue sound plays and the same move is asked 1.5 s later | mixed | Teaches playing by ear: each type's sound is the hint. |
| `w6-temple-guardian` | Temple Guardian | 4:00 | B4 | beam, slideWall, pushWall, balanceBeam, gate | Mini-boss: a stone sentinel (original). Telegraph glow → slam (beam) → shockwave (pushWall) → the floor tilts (balanceBeam) → a weak point (a gem) opens to a raise-arms charge on a gate. |

**Colours (`SceneTheme.temple`):** background `0xFF1A1F14`, skyTop `0xFFF2C46D`,
skyBottom `0xFF7BAF8A`, sun `0xFFFFF0C9`, hillFar `0xFF4D5B3A`, hillNear `0xFF3A4A2C`,
ground `0xFF7C7461`, road `0xFFA89A7C`, propTrunk `0xFF5E5544`, propCrown `0xFF2F5A34`,
beam `0xFF8B6B4A`, block `0xFF6F6A5E`. New `SceneProps.pillars`.
**Sound:** balanceBeam = sustained low flute note that wobbles if the player wobbles.
Temple gate = deep gong-like bell (generated).
**Hints:** "Narrow bridge! Lift one foot and hold steady." / "Toe-tap counts too — keep
it calm."

---

### World 7: Shadow Arena (new `SceneTheme.arena`). Four stages

**Theme:** a stylised training dojo arena of ink-wash shadows and paper lanterns.
Sparring is with shadow "echo" figures, which are abstract silhouettes and not people.
Controlled technique only.
**New moves:** punch (§3.4), with `padLeft` and `padRight`; guard hold (§3.5), with
`strike`.

| Id | Title | Length | Segment plan | Mix | Difficulty notes |
|---|---|---|---|---|---|
| `w7-shadow-dojo` | Shadow Dojo | 3:00 | S3; practice: 4 pads at 6, 11, 16, 21 s, then a guard at 26 s | pads 30 %, strike 15 %, beam 20 %, laneBlock 15 %, orb 20 % | Pads are rhythm targets and never damage. Minimum 700 ms between pads (beginner 1000 ms). No pads in the breather. |
| `w7-lantern-alley` | Lantern Alley | 3:00 | S3 | pads 20 %, strike 15 %, beam 20 %, laneBlock 20 %, slideWall 10 %, orb 15 % | Guard after a pad needs ≥ 1.2 s. |
| `w7-echo-duel` | Echo Duel | 3:30 | S3.5; the combo segment is "1-2-guard" (pad L, pad R, strike) | as above | Advanced only: a 4-pad flurry at ≥ 700 ms spacing. Never faster. |
| `w7-shadow-master` | Shadow Master | 4:00 | B4 | all world 7 moves plus beam | Boss: the Shadow Master echo. This is the first full §5 pattern: telegraph → duck → weak point → raise-arms charge → punch. |

**Colours (`SceneTheme.arena`):** background `0xFF120E14`, skyTop `0xFF2B1B2E`,
skyBottom `0xFF6B2E3A`, sun (moon) `0xFFF3E6D0`, hillFar `0xFF2A2230`, hillNear
`0xFF1E1822`, ground `0xFF3B2F2A`, road `0xFF6E5A48`, propTrunk `0xFF2A1E18`, propCrown
(lantern) `0xFFE85D3A`, beam `0xFF8C3B3B`, block `0xFF4A3F55`. New `SceneProps.lanterns`.
**Sound:** pad hit = padded "thup" (left a lower pitch than right). Strike telegraph =
taiko-like double hit, then a whoosh. Guard success = deflect "ting".
**Hints:** "Pad on the left — punch with your left hand, smooth and controlled." /
"Strike coming! Guard up, hands by your face."

---

### World 8: Cosmic Journey (new `SceneTheme.cosmic`). Four stages

**Theme:** low-gravity planets, crystal arches and a friendly star-whale companion
(original). The low gravity is the story reason for balance and slow, controlled moves.

| Id | Title | Length | Segment plan | Mix | Difficulty notes |
|---|---|---|---|---|---|
| `w8-orbit-launch` | Orbit Launch | 3:00 | S3; a jogTrack launch at 0–10 s inside the practice segment | jogTrack, beam, laneBlock, orb, hurdle | Recap. |
| `w8-crystal-field` | Crystal Field | 3:30 | S3.5 | balanceBeam 10 %, pushWall 10 %, slideWall 15 %, beam 20 %, laneBlock 20 %, orb 25 % | Low-gravity flavour: the visual speed is 85 %, and warnings are the same as normal. |
| `w8-meteor-storm` | Meteor Storm | 3:30 | S3.5 | strike 10 %, pads 15 %, hurdle 10 %, beam 20 %, laneBlock 25 %, orb 20 % | Meteors = strike (guard). Small rocks = pads (punch to break them). |
| `w8-nebula-gate` | Nebula Gate | 4:00 | B4 | all moves | Mini-boss: a nebula serpent. Ball and wicket are not used (they stay in Stadium only). |

**Colours (`SceneTheme.cosmic`):** background `0xFF050816`, skyTop `0xFF0B0F2E`,
skyBottom `0xFF3A1F6B`, sun (planet) `0xFF8FE3FF`, hillFar `0xFF1F2A5A`, hillNear
`0xFF141C44`, ground `0xFF2A2350`, road `0xFF4B3F8A`, propTrunk `0xFF7FDBFF`, propCrown
`0xFFB388FF`, beam `0xFF64FFDA`, block `0xFFFF8A80`. New `SceneProps.crystals`.
**Sound:** chimes and pads. Meteor = descending filtered noise.
**Hints:** "Low gravity — move slow and steady." / "Meteor! Guard up."

---

### World 9: Final Guardian (new `SceneTheme.finale`). Three stages

**Theme:** the Guardian's citadel, where every world's colours return. The Guardian is an
original masked construct that is calmed, not destroyed.

| Id | Title | Length | Segment plan | Mix | Difficulty notes |
|---|---|---|---|---|---|
| `w9-citadel-approach` | Citadel Approach | 3:30 | S3.5 | all moves except ball and wicket, evenly | Each 15 s block uses one previous world's prop style (visual only). |
| `w9-trial-of-worlds` | Trial of Worlds | 4:00 | practice 0–20, then 4 × 50 s "trials" (each with its own learn and combo), breather 110–125, checkpoint 180, finale 181–240 | per trial: forest, desert/neon, mountain/temple, arena/cosmic | Two checkpoints (at 120 and 180) because the stage is long. **Schema:** multiple checkpoint segments are already allowed. |
| `w9-final-guardian` | The Final Guardian | 5:00 | practice 0–20, phase 1 20–90, breather 90–110, phase 2 110–170, checkpoint 170–171, phase 3 171–260, finale 260–300 | boss | Full §5 boss. Phase 1: duck and lean. Phase 2: guard, push and side step. Phase 3: weak points with raise-arms charge then punch, finishing with the gate sequence. `durationS` 300 is within the schema maximum of 900. |

**Colours (`SceneTheme.finale`):** background `0xFF101018`, skyTop `0xFF3B1E54`,
skyBottom `0xFFFF9E5E`, sun `0xFFFFD54F`, hillFar `0xFF2E2A48`, hillNear `0xFF221F38`,
ground `0xFF3A344F`, road `0xFF7A6A8F`, propTrunk `0xFFB0A8C8`, propCrown `0xFFFFC27A`,
beam `0xFFFFB74D`, block `0xFF7E57C2`.
**Sound:** the Guardian's leitmotif is one 4-note phrase that each world's music hinted
at. Telegraphs are always the same 3-pulse rise.
**Hints:** "Every move you've learned — one last run." / "The Guardian's core is open!
Arms up to charge."

---

### Limited-time events (world 0)

Events are optional and never gate progress. **Garba Quest is free** (the one free
festival event); the other events are Premium (§7). Event cosmetics are earned, never sold. The server
delivers event levels through the content API (`server/` content module) with a
date window in IST. The app hides them outside the window. They never ship in the APK.
Imagery is celebratory and secular: lights, colour, music and dance. Do not use deities,
religious symbols or ritual depictions. Run copy past a cultural reviewer before launch.

| Id | Title | Window | Length | Segment plan | Mix | Notes |
|---|---|---|---|---|---|---|
| `w0-garba-quest` (interim: `w1-garba-quest-event`, Implemented) | Garba Quest | Navratri, 9 nights. Launch in Ahmedabad first (geo/locale flag on the server), then Gujarat, then India | 3:00 | practice 0–20, then 3 × "rounds" 20–70, 75–125 (breather 70–75), 130–175, finale 175–180 | slideWall (side step on the beat) 35 %, orb (arms up on the beat) 35 %, hurdle (calf raise on the beat) 15 %, gate 15 % | A rhythm event. Encounters sit exactly on beats of the music BPM (beginner 96, intermediate 108, advanced 120). Rounds speed up by one BPM step. Nothing damages in round 1. Circular dance-floor prop with original geometric patterns. Gujarati and Hindi hints. |
| `w0-garba-quest-night2` *(optional)* | Garba Quest: Raas Night | Same window | 3:00 | as above | adds pads (a stylised "clap" target, answered by a punch at low reach) | Only if punch is shipped. |
| `w0-diwali-lights-run` | Diwali Lights Run | Diwali week | 3:00 | S3 | orb 35 % ("light the lamps"), beam 20 %, laneBlock 20 %, gate 15 %, jogTrack ×1 | The street lights up as orbs are collected (score unchanged). **No firecracker imagery or loud bangs.** Sounds are soft bells and sparkles. |
| `w0-holi-colour-dash` | Holi Colour Dash | Holi weekend | 3:00 | S3 | slideWall 20 % (colour clouds), beam 20 %, laneBlock 20 %, orb 30 % (colour bursts), gate 10 % | The runner and road get "painted" by cleared encounters. Use the high-contrast palette; shape cues stay. |

**Event colours:** Garba (`SceneTheme.garba`) background `0xFF1A0F2E`, skyTop
`0xFF2E1A5C`, skyBottom `0xFFE65100`, ground `0xFF4A2C6B`, road `0xFFFFB300`, beam
`0xFFFF4081`, block `0xFF00BFA5`. Diwali (`diwali`) background `0xFF0D0A1F`, skyBottom
`0xFF3D2470`, sun `0xFFFFD54F`, beam `0xFFFFB300`, block `0xFF8E24AA`. Holi (`holi`)
skyTop `0xFF81D4FA`, skyBottom `0xFFFFF59D`, ground `0xFFA5D6A7`, beam `0xFFE91E63`,
block `0xFF3F51B5`. Fill the remaining fields to match the world's mood. Contrast
between beam or block and road must be ≥ 3:1.

---

## 3. New moves and encounter types

The existing moves (squat, lean, raise arms) are specified in `docs/game-design.md`. New
moves use the same `Recogniser` interface (`update`, `interrupt`, `state`, `measure`) in
`packages/motion_core/lib/src/recognisers.dart`. They emit `MoveStarted`, `MoveHeld`,
`MoveEnded`, `RepCompleted` and `MoveRejected` with reasons `tooShallow`, `notVisible`
and `tooEarly`. Add new reasons only where noted. All measures are relative to the
calibrated body (torso length, shoulder width, standing pose), never to raw pixels.

MediaPipe landmark indices used: 0 nose; 11/12 shoulders L/R; 13/14 elbows; 15/16 wrists;
23/24 hips; 25/26 knees; 27/28 ankles; 29/30 heels; 31/32 foot index. "Above" means a
smaller image y. Every recogniser requires visibility ≥ 0.5 on the landmarks it reads,
or it emits `notVisible` once per attempt.

Tests come first (AGENTS.md). For each move, add synthetic `BodyFeatures` unit tests and
at least one recorded landmark clip (`tools/recorder`) to the replay accuracy test before
the move is used in content.

### Summary

| Move (`Move` enum) | Measure | Start | End / re-arm | Hold | Low-impact alternative | Answers encounter | Damages? |
|---|---|---|---|---|---|---|---|
| `stepLeft` / `stepRight` | Hip-centre x shift vs standing, % of calibrated step range | ≥ 60 %, 2 frames, **and** lean fraction < 40 % | < 25 % | — | Smaller step: 45 % | `slideWall` | yes |
| `barrierHold` | Both wrists at chest height, inside shoulder span, arms forward | conditions true for 2 frames | conditions false for 200 ms | `holdMs` (1.5–3 s) | One hand accepted | `pushWall` | yes, unless held ≥ 70 % |
| `jog` | Alternating knee lift, % of calibrated lift | each knee ≥ 50 % alternately | cadence < 40 steps/min | sustained | March: 30 %, no cadence floor beyond 30/min | `jogTrack` | no |
| `punchLeft` / `punchRight` | Wrist reach from guard, % of arm length, plus elbow angle | reach ≥ 75 %, elbow ≥ 145° | wrist back in guard zone | — | Reach 60 %, elbow ≥ 130° | `padLeft` / `padRight` | no |
| `guard` | Both wrists near the face, elbows below wrists | true for 2 frames | false for 150 ms | through the impact window | One hand accepted | `strike` | yes |
| `swing` | Wrist pair travel across the body plus shoulder rotation | path complete within 250–1200 ms | wrists back near the hip | — | Half swing: 60 % travel | `ball` | no |
| `bowl` | Bowling wrist above the head with a straight arm, then down past the hip | full arc within 400–1500 ms | wrist below the hip | — | Arm only, no step: always (no run-up ever) | `wicket` | no |
| `balance` | One ankle lifted vs the other, % of shin length, with hip wander bounded | lift ≥ 25 % plus wander guard | foot down for 300 ms | `holdMs` (2–4 s) | Toe-tap: lift ≥ 8 % (heel up) | `balanceBeam` | no (slows) |
| `calfRaise` | Heel lift and nose rise vs standing | rise ≥ 3 % body height for 2 frames | < 1 % | 150 ms | It is itself the low-impact alternative to `jump` | `hurdle` | yes |
| `jump` *(opt-in only)* | Both ankles leave the standing line | ankles rise ≥ 6 % body height | land | — | Disabled by default; `calfRaise` answers instead | `hurdle` | yes |

### 3.1 Side step (`stepLeft`, `stepRight`)

- **Measure:** `BodyFeatures.sideStepFraction(cal)` already exists (hip-centre x minus
  standing, over the calibrated side-step range). Promote it from a lane-change mode to
  its own move.
- **Start:** |fraction| ≥ 0.60 for 2 frames **and** `leanFraction` < 0.40. Requiring a
  small lean stops a torso lean from counting as a step.
- **End / re-arm:** |fraction| < 0.25. Cooldown 400 ms.
- **Guards:** ankles and hips visibility ≥ 0.5. Feet must move: the ankle centre shifts
  ≥ 50 % as far as the hips. Otherwise reject `tooShallow`.
- **Calibration:** add "step left, hold 0.5 s; step right, hold 0.5 s". Minimum range
  20 % of torso.
- **Low-impact:** start 0.45, end 0.20.
- **Encounter `slideWall`:** a wall slides in from one side across two lanes and back.
  The player must side-step **away** to the far lane and return after it passes. The
  outcome is resolved by position at arrival: hip-centre lane (from step fraction) not in
  `lanes`. `lanes` is required (1–2). Damages: yes. Demanding: no. Sound: sand or wind
  hiss with a directional pan. Shape: a tall slab with horizontal motion streaks and a
  side arrow. Scoring key `slideWall` (100).
- **Difference from laneBlock:** a laneBlock accepts a lean, while a slideWall needs the
  step. The guard is the lean < 40 % condition, plus the feet-moved condition.

### 3.2 Barrier hold (`barrierHold`)

- **Measure:** both wrists (15, 16) between the shoulder line and 0.6 torso below it,
  both wrists' x inside the shoulder span ±10 %, and arms forward. Forward is measured in
  2D as wrist-to-shoulder distance ≤ 0.55 × calibrated arm length (foreshortening), with
  elbow y between wrist and hip. Optional: MediaPipe z of the wrists < shoulder z by
  ≥ 0.1. Use it only if recorded data shows it is reliable.
- **Start:** all conditions true for 2 frames. **End:** any condition false for 200 ms
  (grace for jitter).
- **Hold:** emits `MoveHeld` every 100 ms. The engine compares held time against the
  encounter's `holdMs`.
- **Guards:** must not overlap `guard` (wrists near the face). If the wrists are within
  0.4 torso of the nose, it is a guard, not a barrier.
- **Calibration:** "push palms forward, hold 1 s" records arm length.
- **Low-impact:** one hand is enough. `holdMs` is scaled × 0.75.
- **Encounter `pushWall`:** an energy wall that pushes against the runner. The world
  slows to 40 % while the wall is in contact, so no other encounter can arrive. Outcome:
  held ≥ 70 % of `holdMs` within the contact window → cleared. Otherwise you lose a heart.
  Tracking loss during contact → forgiven. Fields: `holdMs` (1000–4000, default 1500).
  Damages: yes. Demanding: yes. Sound: hum rising in pitch while held, then a chord on
  success. Shape: a translucent hexagon wall with a palm icon. Score 150.

### 3.3 Jog in place (`jog`)

- **Measure:** knee lift per side = (standing knee y − knee y) / calibrated thigh length
  (hip to knee). A step counts when one knee passes the threshold while the other knee is
  below 20 %, and sides alternate.
- **Start:** 2 alternating steps within 1.5 s → `MoveStarted`. **Held:** while steps keep
  coming. **End:** no step for 1.5 s, or cadence < 40 steps/min.
- **Thresholds:** standard 50 % lift. Low-impact march 30 % lift with no flight phase.
  Never require both feet off the ground. Low-impact is the default.
- **Guards:** knees and ankles visibility ≥ 0.5. Hip-centre vertical bounce is ignored.
  Bounce is not required and not scored.
- **Calibration:** "march in place for 4 steps" records the comfortable knee lift.
- **Encounter `jogTrack`:** a highlighted track stretch of `durationMs` (5000–20000). No
  lane decisions, and nothing else may be scheduled inside it. A boost meter fills per
  step, up to a target of `durationMs / 600` steps. Score = 10 per step, capped. Damages:
  **no** (like an orb). Demanding: no. It may sit in breathers. Sound: footstep loop at
  BPM. Shape: chevron-striped track with a meter. Never show a speed or "faster" goal.
  Cadence beyond the cap earns nothing extra.

### 3.4 Punch (`punchLeft`, `punchRight`)

- **Controlled, never rapid.** The point is a smooth reach to a target pad. Speed earns
  nothing.
- **Measure:** reach = wrist-to-shoulder distance / calibrated arm length on that side.
  The elbow angle (shoulder–elbow–wrist, 2D) must also be met. The punch must start from
  the guard zone (wrist within 0.5 torso of the nose) within the last 1.0 s.
- **Start:** reach ≥ 0.75 **and** elbow ≥ 145° for 2 frames, wrist at shoulder height
  ±0.3 torso. **End / re-arm:** wrist back in the guard zone.
- **Guards:** cooldown 500 ms per hand and 350 ms across hands. A punch within the
  cooldown → `tooEarly`. A wrist above the nose is a raise, not a punch. Reach peaking at
  0.5–0.75 → `tooShallow`.
- **Calibration:** "reach your left arm out to the side, then the right, hold 0.5 s"
  records arm length.
- **Low-impact:** reach 0.60, elbow ≥ 130°. Cooldown +250 ms.
- **Encounters `padLeft` / `padRight`:** a floating target pad on that side. The punch
  must use the matching hand (mirrored for the selfie preview: `padLeft` is on the
  player's left as they see it). Window ±400 ms around arrival (±600 ms in assist).
  Damages: **no**. Demanding: no. Minimum spacing 700 ms (beginner 1000 ms). Sound:
  padded "thup", with left lower than right. Shape: a round pad with a fist icon and an
  L or R letter. Score 75. Hint style: "smooth and controlled".

### 3.5 Guard hold (`guard`)

- **Measure:** both wrists within 0.45 torso of the nose and above the shoulder line −0.1
  torso, with both elbows below their wrists and inside the hip span ±20 %.
- **Start:** 2 frames. **End:** false for 150 ms.
- **Guards:** distinguished from raise arms (wrists above the nose by > 0.15 torso and
  elbows above the shoulders) and from barrier hold (wrists below the shoulders). Arms
  raised overhead never count as a guard.
- **Low-impact:** one hand is accepted.
- **Encounter `strike`:** a shadow echo telegraphs (wind-up glow, then the cue), then
  strikes. Guard must be held through an impact window of 600 ms (900 ms in assist)
  centred on arrival. Damages: yes. Demanding: yes. Sound: double drum hit, then a whoosh,
  then a "ting" when deflected. Shape: a slanted slash arc with a shield icon. Score 125.
  Cue it at least the normal warning plus 400 ms early.

### 3.6 Batting swing (`swing`)

- **Original sport flavour only. No branding** (§2, world 5).
- **Measure:** both wrists together (distance < 0.3 torso). The wrist midpoint must
  travel from the back side (trailing shoulder, at or above shoulder height: the
  "backlift") across and down to the front hip side. Travel ≥ 1.0 calibrated shoulder
  width. Shoulder rotation also counts: the 2D shoulder width shrinks ≥ 15 % at some point
  in the path. Handedness comes from Settings and flips the direction.
- **Start (`MoveStarted`):** backlift reached and held ≥ 100 ms. **Complete
  (`RepCompleted`):** travel done within 250–1200 ms of leaving the backlift. Too slow →
  `tooShallow`; faster than 250 ms is still accepted but scores the same, with no
  speed bonus. **End:** wrists back near the hip line.
- **Guards:** wrists must stay together. A one-arm flail is rejected. Hips must stay
  within 0.5 torso of standing, so there is no lunging. 1.5 s cooldown.
- **Low-impact:** travel ≥ 0.6 shoulder width, no rotation requirement.
- **Encounter `ball`:** a ball is delivered down a lane (`lanes`: 1). The swing must
  complete within ±350 ms of arrival (±550 ms in assist). A swing on the wrong timing
  just misses. Damages: **no**. Demanding: no. Sound: whistle on delivery, then "thwock"
  on hit. Shape: a small sphere with a seam line and a trail. Score 100 (flavour: "4
  runs").

### 3.7 Bowling action (`bowl`)

- **Standing delivery. No run-up, no step, no jump.**
- **Measure:** the bowling arm (from handedness) wrist rises above the nose by ≥ 0.3
  torso with elbow ≥ 150° (straight arm overhead), then comes down in front to below the
  hip line on the opposite or front side within 400–1500 ms. The non-bowling wrist being
  raised as "aim" is optional and gives no bonus.
- **Start:** straight arm overhead for 2 frames. **Complete:** wrist below the hip
  within the window. **End:** wrist below the hip.
- **Guards:** differs from raise arms because only one arm is up and then sweeps down.
  The raise-arms recogniser must not fire for a single arm unless `allowOneArm`. In
  low-impact, `allowOneArm` is on, so the engine resolves by encounter: a `wicket`
  accepts `bowl`, and a `gate` or `orb` accepts `raiseArms`. Never place both within
  2 s. Cooldown 1.5 s.
- **Low-impact:** elbow ≥ 130°, height ≥ the nose line.
- **Encounter `wicket`:** a stumps target lights up for a window of 1500 ms (2000 ms in
  assist). Any completed bowl inside the window → clear. Damages: **no**. Demanding: no.
  Sound: rising "ready" tone, then wooden clatter on success. Shape: three upright bars
  with bails and a target ring. Score 100.

### 3.8 Balance (`balance`)

- **Measure:** lift = (other ankle y − lifted ankle y) / calibrated shin length (knee to
  ankle). Wander = hip-centre x movement vs the 0.5 s running mean, as % of torso.
- **Start:** lift ≥ 0.25 for 3 frames. **Held:** while lift ≥ 0.15 **and** wander < 15 %
  of torso. **End:** foot down (lift < 0.10) for 300 ms. A short touch-down of under
  300 ms does not end the hold, which makes it forgiving.
- **Low-impact alternative (default in beginner and low-impact):** toe-tap stance. The
  heel (29/30) lifts relative to the foot index (31/32) by ≥ 8 % of shin length, and the
  toes may stay down. Holding onto a chair is fine and cannot be detected. A hint says
  so.
- **Guards:** both legs visible. Either foot is accepted. No eyes-closed or one-foot
  hopping prompts, ever.
- **Encounter `balanceBeam`:** a narrow bridge with `holdMs` (1500–5000). The world runs
  at 70 % during it. Outcome: balance held ≥ 70 % of `holdMs` → clear and score 150.
  Otherwise the runner "wobbles" and the world slows more. **Damages: no** (balance
  failure must never cost hearts). Demanding: yes, so it counts in the in-a-row cap.
  Sound: a sustained note that wobbles with the wander measure. Shape: a thin plank with
  a one-foot icon.

### 3.9 Calf raise (`calfRaise`) and optional `jump`

- **Measure:** rise = (standing nose y − nose y) / calibrated body height, cross-checked
  by heel lift (heel above the foot index). Both are needed, so a neck stretch does not
  count.
- **Start:** rise ≥ 0.03 and heel lift ≥ 6 % of shin length for 2 frames, held ≥ 150 ms.
  **End:** rise < 0.01.
- **Guards:** knees straight-ish (hip-to-ankle span ≥ 90 % of standing) so a squat
  rebound does not count. Cooldown 600 ms.
- **Jump (opt-in only):** both ankles rise ≥ 6 % of body height above the standing ankle
  line. Enabled only when the player turns on Settings → "Allow jumps" (default off; not
  offered in low-impact). When jumps are off, `hurdle` accepts only `calfRaise`. When on,
  it accepts either.
- **Encounter `hurdle`:** a low ground obstacle (ice ledge, root, log) across all lanes.
  The calf raise must be held during the 350 ms arrival window (550 ms in assist).
  Damages: yes. Demanding: yes. Minimum spacing after: 900 ms (+250 ms in low-impact).
  Sound: rising "tock-tock". Shape: a low bar with an up-arrow and a heel icon. It must
  look distinct from the beam: a beam is high with down chevrons, a hurdle is low with up
  arrows. Score 100.

### 3.10 New `MoveRejected` reasons (optional)

- `tooFast` for a swing or punch faster than a safety cap, if recorded data shows players
  flail. It gives a hint, never a penalty.
- `wrongHand` for a pad punched with the other hand. Coach Kavi form tip: "match the pad
  side".

### 3.11 Code changes required (do these once, before the first stage that uses them)

**Schema (`content/schema/level.schema.json`):**
1. `world`: `minimum: 0` (0 = event), `maximum: 9`.
2. `schemaVersion`: change to `{ "enum": [1, 2] }`. Levels that use any new type must
   declare `2`. Older app builds request only `schemaVersion` 1 from the content API.
   The server must filter by the client's supported version.
3. `encounters.items.properties.type.enum`: add `slideWall`, `pushWall`, `jogTrack`,
   `padLeft`, `padRight`, `strike`, `ball`, `wicket`, `balanceBeam`, `hurdle`.
4. New optional encounter fields: `holdMs` (integer 1000–5000; required for `pushWall`
   and `balanceBeam` via `if/then`) and `durationMs` (integer 5000–20000; required for
   `jogTrack`). `lanes` is required for `slideWall` and `ball` (`maxItems` 2 and 1).
5. `scoring`: keep the four required keys and add optional integer keys for each new
   type. LevelConfig falls back to the defaults in §3 when a key is missing.
6. Optional top-level `requiredMoves` (array of move names). The app runs the extra
   calibration steps (§3.1–3.9) before the stage if they are missing from the profile.
7. Optional top-level `event`: `{ "key": string, "startsIst": date-time, "endsIst":
   date-time, "regions": [string] }`. Required when `world` is 0. The server enforces it.
8. Optional encounter `phase` (string, e.g. `"telegraph"`, `"weakPoint"`), used only by
   the boss painter for visuals. It never changes the outcome logic.

9. Age bands are **not** level content. `game_director` gets a deterministic
   `BandModifiers` (warning multiplier and floor, demanding-per-minute cap, demanding-in-row
   cap, hold scale, breather floor) applied after difficulty, from the §6 table. The
   simulator runs every level × difficulty × band × low-impact on/off.
10. Optional top-level `access` (`"free"` | `"premium"`), `deload` (boolean) and `info`:
    `{ "patterns": [string], "bodyTargets": { "primary": [key], "secondary": [key] },
    "intensity": "light" | "lightModerate" | "moderate", "benefitKeys": [string],
    "sourceKeys": [string], "bands": ["gentle" | "balanced" | "active"] }`. Body-region and
    source keys are enums (§8). Benefit text lives in l10n as approved copy, never free text
    in JSON. `access` is a UI hint; the server entitlement decides.
11. Optional segment `rhythm` (boolean) and encounter `tag` (`"surprise"`) for the
    §10.2 content lint (variety cap, surprise spacing, wave length). Add the lint to
    `server` `content:validate` or to the game_director tests.

**`packages/motion_core`:**
- `Move` enum (`events.dart`): add the moves in §3 summary.
- `MotionThresholds`: add fields per move, plus `.lowImpact()` values and `allowJumps`
  (default false). `toJson` gets them too.
- `features.dart`: add `kneeLiftFraction`, `armReach`, `elbowAngle`, `wristsTogether`,
  `heelLift`, `noseRise` and `ankleLift`.
- `calibration.dart`: optional steps per move. Store values in `CalibrationProfile`;
  missing values mean the move is not calibrated.
- One recogniser per move. Mutual exclusion lives in a small arbiter. The priority is
  guard > barrierHold > raiseArms > punch when the wrist zones overlap, so one pose emits
  only one move.
- Tests: unit tests plus replay clips per move. `replay_accuracy_test.dart` must stay
  green.

**`packages/game_director`:**
- `EncounterType` (`level.dart`): add the types. Extend the `move`, `demanding`,
  `damages` and `soundCue` switches per §3. Add `holdMs` and `durationMs` to the
  encounter model, and `LevelConfig.decode` support for the new fields and `scoring`
  defaults.
- `RunEngine` (`run_engine.dart`): track state for the new moves, such as held-time
  accumulators for `pushWall` and `balanceBeam`, the step lane for `slideWall`, the last
  punch hand and time, the last swing, bowl or calf-raise completion, and the jog step
  count. Add resolution rules in the outcome switch (currently around line 285). Contact
  segments (`pushWall`, `balanceBeam`, `jogTrack`) set a speed multiplier that composes
  with the `Pacer`. Tracking loss inside a contact window → forgiven.
- `director.dart`: minimum-spacing table entries for each new type (pads 700 ms, strike
  1200 ms, hurdle 900 ms, swing/bowl 1500 ms, pushWall/balance = hold + 2000 ms, jogTrack =
  duration + 2000 ms; +250 ms in low-impact). Breathers may contain only `orb` and
  `jogTrack`. A `hurdle` never follows a `beam` within 1.5 s.
- `simulator.dart`: `BotProfile` must be able to answer every new type (a competent bot
  and a slow bot with reaction delay). The simulation test (`test/simulation_test.dart`)
  automatically covers every JSON file in `content/levels`.
- Coach (`coach.dart`): form-tip keys for the new rejection reasons, and strings in
  `app/lib/l10n/coach_strings.dart` (en, hi, gu).

**`app/`:**
- `SceneTheme` (`app/lib/game/forest_game.dart`): add `stadium`, `temple`, `arena`,
  `cosmic` and `finale` (and `garba`, `diwali` and `holi` for events), with colours from
  §2, plus new `SceneProps` (`floodlights`, `pillars`, `lanterns`, `crystals`).
- `ForestPainter`: shape painters per new type (§3 shapes). Shapes must differ, never
  colour alone. Boss sprites are procedural, like the rest of the painter.
- Sound cues: add generators to `tools/gen_cues.py` (`cue_<type>`), so they are
  original and generated.
- Settings: "Allow jumps" (default off), and handedness for swing and bowl.
- `stages.dart`: when a world gets its first stage, remove its name from `_laterWorlds`.
  The `worlds` getter numbers later worlds by position, so the order must stay Stadium
  Nights, Ancient Temple, Shadow Arena, Cosmic Journey, Final Guardian. Events go in a
  separate `events` list that is not part of the unlock chain.
- Server content module: serve event levels inside their window only, filtered by
  `schemaVersion` support.

---

## 4. Implementation checklist and priority

### Per stage (repeat for each)

1. Write `content/levels/<id>.json` (id matches `^w[0-9]+-[a-z0-9-]+$`; `world` and
   `name` set; `schemaVersion` 2 if it uses new types). Follow the segment plan and mix
   in §2. Hints on the first encounter of each type.
2. `tools/sync_content.sh` copies it into `app/assets/levels/`.
3. Add a `Stage(...)` entry to `app/lib/game/stages.dart` in play order, with
   `worldName`, `stageNumber`, `title`, `description` (no medical claims) and the
   `SceneTheme`. Remove the world name from `_laterWorlds` if this is its first stage.
4. `cd server && npm run content:validate` (schema validation).
5. `cd packages/game_director && dart pub get && dart analyze && dart test`. The
   simulation must pass at all difficulties, low-impact on and off, with competent and
   slow bots.
6. `cd app && flutter pub get && flutter analyze && flutter test` (`stages_test.dart`
   checks the order, unlocks and that assets exist).
7. Update the stage table in `docs/game-design.md` and add an entry to
   `docs/progress.md`. Mark the stage Implemented in §1 of this file.
8. Play-test on a device with the debug overlay: each new encounter is answerable on
   beginner with low-impact on, in the Gentle band.
9. Fill `access`, `deload` and `info` (§3.11 item 10) from §7 and §8.2. Benefit copy must
   come from the approved-copy table; no new claims without review.
10. Pass the §10.2 anti-boredom lint: variety cap, waves 20–30 s, a surprise every
    35–55 s, an "almost there" cue at 75 %, an end-of-stage reward.
11. Deload stages (§6 rule 2): demanding density ≤ 80 % of the previous stage and a
    breather ≥ 20 s.

### Per new move (once, before its first stage)

1. Tests first: synthetic feature tests, then recorded clips (`tools/recorder`), then the
   recogniser.
2. Calibration step, thresholds plus the low-impact profile, and the arbiter priority.
3. Schema, `EncounterType`, `LevelConfig`, `RunEngine`, director spacing, simulator bot,
   painter shape, sound cue and coach strings (§3.11).
4. `docs/game-design.md`: move table row, encounter rule and sound/shape line.

### Priority order

| # | Work | Why first |
|---|---|---|
| 1 | Schema groundwork (§3.11 items 1–5, 8) plus `schemaVersion` 2 filtering on the server | Unblocks everything, and stays safe for old clients |
| 2 | Side step + `slideWall` → `w2-shifting-sands`, `w2-scorpion-king` | `sideStepFraction` already exists; lowest risk |
| 3 | Barrier hold + `pushWall` → `w3-hologram-wall`, `w3-drone-core` | Simple static pose; introduces the contact-window engine logic |
| 4 | Calf raise + `hurdle`, jog + `jogTrack` → `w4-glacier-run`, `w4-yeti-pass` | Lower-body variety; settles the jump opt-in setting |
| 5 | Event infrastructure (`world` 0, `event` window) → `w0-garba-quest` | Time-boxed to Navratri; uses only moves from 2–4 |
| 6 | Swing + bowl → world 5 Stadium Nights (4 stages) | Needs handedness and new theme and props |
| 7 | Balance → world 6 Ancient Temple (4 stages) | Needs careful forgiveness tuning |
| 8 | Punch + guard → world 7 Shadow Arena (4 stages), first full boss pattern | Arbiter between wrist poses must be solid |
| 9 | World 8 Cosmic Journey | Recombines existing moves only |
| 10 | World 9 Final Guardian | Needs every move |
| 11 | `w0-diwali-lights-run`, `w0-holi-colour-dash` | Schedule to their dates; existing moves only |
| — | `w1-firefly-trail` (optional) | Any time |

---

## 5. Boss battle design rules

The boss is a normal level JSON. Its "behaviour" is only encounter placement plus
`phase` tags for visuals. All outcomes go through `RunEngine` like any other encounter.

**Core loop** (each cycle 12–20 s, repeated 3–4 times per phase):

1. **Telegraph** (≥ 1.0 s on top of the normal warning). The boss glows or winds up,
   always with the same 3-pulse rising sound and a visible shape cue. Never an untelegraphed
   hit.
2. **Duck.** The attack is a `beam` (sweep) or `strike` (guard, from world 7 on). One
   attack at a time.
3. **Weak point opens** after a successful dodge. A breather of 1.5–2 s, then the weak
   point appears (a gem or core) with a hint on the first cycle.
4. **Raise-arms charge.** A `gate` (or a `pushWall` hold in worlds 3 and 6) charges the
   hero's light.
5. **Punch** (world 7 and later): one `padLeft` or `padRight` on the weak point, or
   `wicket` in Stadium Nights. Before world 7, the charge itself finishes the cycle.

**Rules:**

- **Never rapid, uncontrolled moves.** No more than one move asked per 700 ms at any
  difficulty. Pads are ≥ 700 ms apart and capped at a 4-pad flurry on advanced only.
  There is no "mash" mechanic and no speed bonus.
- **The weak point never damages.** Missing it only repeats the cycle. A boss cannot cost
  more hearts than its attacks, and attacks are capped by `maxDemandingInRow`.
- **Phases escalate by variety, not speed.** Phase 2 adds one move type; phase 3 combines
  them. The warning time never drops below the difficulty's `warningMs`.
- **A checkpoint before the final phase.** A lost heart comes back.
- **Bosses are calmed, not killed.** They are friendly constructs or guardians. The end
  is the gate sequence and a calm animation.
- **Tracking loss** pauses the boss's attack timeline along with the world (via the
  `Pacer`), and the pending attack is forgiven.
- **Low-impact:** every attack has a low-impact answer, and no attack requires a jump.
  Balance and hold durations are scaled × 0.75.
- **Sound and shape:** each attack has the same sound and shape as its normal encounter
  type, so players can read bosses by ear.
- **Simulation:** the slow bot must finish every boss on beginner, low-impact on, Gentle
  band, without assist.
- **Age bands:** Gentle adds one breather cycle before phase 3 and uses hold scale × 0.75;
  band caps on demanding encounters per minute apply to bosses too.
- **Access:** Guardian Grove (World 1) is the only free boss. All later bosses are
  Premium, checked at stage select only.
- **Fun:** every boss has a named telegraph (§10.1), a visible phase bar with an "almost
  there" glow before the calm, and a unique cosmetic for the first calm.

**Template phase table for a B4 boss finale (151–240 s):**

| Time | Phase | Content |
|---|---|---|
| 151–175 | 1: Awaken | 2 cycles: telegraph → beam → weak point → gate |
| 175–205 | 2: Pressure | 2 cycles adding the world's new move (slideWall, pushWall, hurdle, balanceBeam, strike) |
| 205–230 | 3: Open core | 2 cycles with the full loop (+ punch or wicket where available) |
| 230–240 | Calm | Gate sequence (3 gates, 3 s apart), then results |

---

## 6. Player journey and age bands

Joynetic is for adults (18+) only. Age band is an **optional preset the player picks**
in onboarding or Settings ("How do you like to play?"). We never ask for a date of birth
and never infer age from the camera. Only the band key is stored (on device, and synced
with progress if signed in). **No pick = Gentle.** The player can change band at any
time; the change applies from the next run, never mid-run.

Bands compose with difficulty (beginner / intermediate / advanced): the band sets
*ceilings and floors*, difficulty picks a value inside them. The director applies them
deterministically (see §3.11 item 9).

| | Gentle (50+, and the default) | Balanced (31–50) | Active (18–30) |
|---|---|---|---|
| Warning time | difficulty value × 1.3, floor 2.0 s | × 1.15, floor 1.6 s | × 1.0, floor 1.3 s |
| Demanding encounters (beam, two-lane block, strike, pushWall) per minute, max | 8 | 11 | 14 |
| Demanding in a row, max | 2 | 3 | difficulty value |
| Low-impact | On, locked on unless the player confirms twice | On by default | On by default, easy to turn off |
| Jumps | Toggle hidden; calf raise always | Off by default | Off by default (opt-in) |
| Hold scale (pushWall, balanceBeam, guard window) | × 0.75 | × 0.9 | × 1.0 |
| Balance stance | Toe-tap by default, wall-or-chair support hint shown | Toe-tap until 3 clean holds | Full lift |
| Punch / swing reach thresholds | Low-impact values | Low-impact values until calibrated twice | Standard |
| Breather between waves | ≥ 15 s every 60 s | ≥ 12 s every 75 s | ≥ 10 s every 90 s |
| Suggested session (Daily Quest) | 6–8 min (2 stages + warm-up/cool-down) | 8–12 min | 10–15 min |
| Max stages before "take a break" card | 3 | 4 | 5 |
| Boss stages | Allowed, but phase 3 gets +1 breather cycle | Standard | Standard (advanced may add the 4-pad flurry) |

**Warm-up and cool-down.** Every Daily Quest and every first run of the day opens with a
45 s warm-up (march, arm circles, gentle lean) and closes with a 45 s cool-down (slow
reach, breathing beat). They score no points and never fail. ACSM guidance recommends a
warm-up and cool-down around each session [ACSM-GETP].

### Which stages suit which band

| Band | Recommended path | Treat with care |
|---|---|---|
| Gentle | Worlds 1, 2, 4 first (squat, lean, side step, calf raise, march). Firefly Trail as a replay. Temple Steps and Stone Bridge (toe-tap balance) are a good fit: WHO 2020 advises balance work for older adults [WHO20]. | Shadow Arena pads at standard reach; Stadium swing at full rotation. Both stay available, with low-impact thresholds. |
| Balanced | Play order as built. Hall of Echoes and Crystal Field are good "focus" stages. | Back-to-back bosses: suggest a non-boss stage between. |
| Active | Play order; advanced difficulty; Echo Duel flurries; Trial of Worlds. | Never offer a "no breaks" mode. Rapid-move caps (§5) apply to everyone. |

### Safe progression rules (all bands)

1. **One step per week of play.** A "step" is exactly one of: difficulty up one level,
   +10 % demanding density, −0.1 s warning, +0.5 s hold. A "week of play" is 3 completed
   runs on 3 different IST days within 7 days. The app may *suggest* a step; the player
   accepts it. Steps down are always immediate and free.
2. **Deload every 4th stage.** In play order, stages 4, 8, 12, … (the first stage of each
   world from World 2 on, see §7) are deload stages: demanding density ≤ 80 % of the
   previous stage, one breather ≥ 20 s, no new *damaging* encounter type. A new move may
   be introduced there only as non-damaging (orb-like) or with hints and doubled warning.
3. **New move = slow first.** The first stage that uses a new move uses it at most 20 %
   of the mix, with hints, and never in the first 10 s.
4. **Struggle rule.** Two runs in a row with 2+ hearts lost → offer one step down (never
   automatic, never a nag). Tracking-loss forgiveness does not count as struggling.
5. **Comeback rule.** After 14+ days without play, the next run starts one step down and
   restores the step after one completed run.
6. **No pain prompts, no diagnosis.** If the player taps "This doesn't feel right", end the
   run gently, keep progress, show the standard disclaimer (§9) and suggest a lighter stage.

---

## 7. Free vs Premium access

**Free:** Daily Quest, World 1 (including its mini-boss and Firefly Trail), and one
festival event (Garba Quest). **Premium** (₹129/month, ₹699/year, Google Play Billing
only): Worlds 2–9, all boss battles from World 2 on, and the other events.
**Gym members get Premium free** through the server entitlement (gyms module).

Rules:
- Access is checked **only at stage select**. A run that has started always finishes and
  saves, even if the subscription lapses mid-run. Never paywall mid-run, never on the
  results screen after a fail.
- The server entitlement is authoritative. The `access` field in level JSON (§3.11 item 10)
  is a hint for the map UI only.
- Locked stages show the stage info sheet (§9) and a single lock label. No countdowns, no
  pop-ups, no links outside Google Play (AGENTS.md rule 11).
- Worlds 2–4 are free in current builds. When billing ships they become Premium; players
  keep all records, stars and cosmetics already earned, and finish any in-progress stage
  for free.
- Daily Quest for free players draws only from World 1 moves (squat, lean, raise arms)
  plus warm-up march; for Premium it draws from every move the player has calibrated.

### Full stage list: order, access, deload, band fit

`D` = deload stage. Band fit: G = Gentle, B = Balanced, A = Active (all bands may play
everything; this is the recommendation shown on the info sheet).

| Order | Id | Title | Access | Why | D | Band fit |
|---|---|---|---|---|---|---|
| — | `daily-quest` | Daily Quest | Free | Daily habit loop for everyone | | G B A |
| 1 | `w1-forest-escape` | Forest Escape | Free | Tutorial | | G B A |
| 2 | `w1-river-crossing` | River Crossing | Free | Core combos | | G B A |
| 3 | `w1-guardian-grove` | Guardian Grove | Free | The one free taste of a boss | | G B A |
| opt | `w1-firefly-trail` | Firefly Trail | Free | Gentle replay, beginners | | G B |
| 4 | `w2-desert-dunes` | Desert Dunes | Premium | Later world | D | G B A |
| 5 | `w2-sandstorm-temple` | Sandstorm Temple | Premium | Later world | | G B A |
| 6 | `w2-shifting-sands` | Shifting Sands | Premium | New move | | G B A |
| 7 | `w2-scorpion-king` | Scorpion Guardian | Premium | Boss | | B A (G with care) |
| 8 | `w3-neon-city-rooftops` | Neon City Rooftops | Premium | Later world | D | G B A |
| 9 | `w3-neon-city-chase` | Neon City Chase | Premium | Later world | | B A |
| 10 | `w3-hologram-wall` | Hologram Walls | Premium | New move | | G B A |
| 11 | `w3-drone-core` | Drone Core | Premium | Boss | | B A |
| 12 | `w4-mountain-trail` | Mountain Trail | Premium | Later world | D | G B A |
| 13 | `w4-summit-storm` | Summit Storm | Premium | Later world | | B A |
| 14 | `w4-glacier-run` | Glacier Run | Premium | New moves | | G B A |
| 15 | `w4-yeti-pass` | Snow Guardian | Premium | Boss | | B A |
| 16 | `w5-nets-practice` | Nets Practice | Premium | New move (non-damaging) | D | G B A |
| 17 | `w5-floodlight-run` | Floodlight Run | Premium | | | B A |
| 18 | `w5-super-over` | Super Over | Premium | | | B A |
| 19 | `w5-stadium-final` | Stadium Final | Premium | Boss | | B A |
| 20 | `w6-temple-steps` | Temple Steps | Premium | Recap | D | G B A |
| 21 | `w6-stone-bridge` | Stone Bridge | Premium | New move | | G B A |
| 22 | `w6-hall-of-echoes` | Hall of Echoes | Premium | Focus stage | | G B A |
| 23 | `w6-temple-guardian` | Temple Guardian | Premium | Boss | | B A |
| 24 | `w7-shadow-dojo` | Shadow Dojo | Premium | New moves (pads non-damaging) | D | B A (G with care) |
| 25 | `w7-lantern-alley` | Lantern Alley | Premium | | | B A |
| 26 | `w7-echo-duel` | Echo Duel | Premium | | | A B |
| 27 | `w7-shadow-master` | Shadow Master | Premium | Boss | | A B |
| 28 | `w8-orbit-launch` | Orbit Launch | Premium | Recap | D | G B A |
| 29 | `w8-crystal-field` | Crystal Field | Premium | | | G B A |
| 30 | `w8-meteor-storm` | Meteor Storm | Premium | | | B A |
| 31 | `w8-nebula-gate` | Nebula Gate | Premium | Boss | | B A |
| 32 | `w9-citadel-approach` | Citadel Approach | Premium | Calm before the end | D | G B A |
| 33 | `w9-trial-of-worlds` | Trial of Worlds | Premium | Long stage | | A B |
| 34 | `w9-final-guardian` | The Final Guardian | Premium | Final boss | | A B (G with care) |
| ev | `w0-garba-quest` | Garba Quest | **Free** | The free festival event; India-first launch moment | | G B A |
| ev | `w0-garba-quest-night2` | Raas Night | Premium | Extra event night | | B A |
| ev | `w0-diwali-lights-run` | Diwali Lights Run | Premium | Event | | G B A |
| ev | `w0-holi-colour-dash` | Holi Colour Dash | Premium | Event | | G B A |

---

## 8. Body targets, intensity and benefits per stage

This is **general fitness information** for the stage info sheet, not a measurement and
not advice. Intensity uses WHO wording: *light* (below moderate), *moderate* (noticeably
raises breathing and heart rate) [WHO20]. MET-style ranges are design targets from
comparable activities in the Compendium [MET11] and active-video-game studies [EXG1,
EXG2]; they are checked in play-tests and **never shown as a measured value**. Copy must
never claim calorie burn, weight loss, toning or any health outcome for the player.

Body-region keys (use these exact keys in `info.bodyTargets`): `quads`, `glutes`,
`hamstrings`, `calves`, `hipAbductors`, `hipFlexors`, `core`, `obliques`, `shoulders`,
`upperBack`, `chest`, `arms`, `ankles` (stability).

### 8.1 Per move

| Move | Pattern | Primary | Secondary | Intensity alone | Plain-language benefits (approved copy) | Sources |
|---|---|---|---|---|---|---|
| Squat (partial) | Squat / knee-hip hinge | quads, glutes | hamstrings, core | light–moderate | Works the big leg muscles used for sitting and standing. Practises a controlled down-and-up. | WHO20 (muscle-strengthening), ACSM-PS11, ACSM-GETP |
| Lean | Lateral flexion | obliques, core | hipAbductors | light | Moves the sides of the trunk. Practises balance while shifting weight. | ACSM-PS11 (flexibility, neuromotor) |
| Raise arms | Overhead reach | shoulders, upperBack | core | light | Reaches through the shoulders. Breaks up long sitting with a full stretch. | WHO20 (reduce sedentary time), ACSM-PS11 |
| Side step | Lateral step | hipAbductors, glutes | quads, calves | light–moderate | Sideways movement most daily walking skips. Gets the whole body moving. | ACSM-PS11 (neuromotor), WHO20 |
| Barrier hold | Isometric push / anti-extension | shoulders, chest, core | arms | light | A steady hold that asks the shoulders and trunk to stay still. | ACSM-RT09 (isometric), ACSM-GETP |
| Jog / march in place | Locomotion, knee lift | hipFlexors, quads, calves | core | moderate (jog), light–moderate (march) | Raises breathing and heart rate. Counts toward weekly active minutes. | WHO20 (aerobic), MET11 (marching/jogging in place) |
| Calf raise | Ankle plantar flexion | calves | ankles | light | Works the lower legs used in walking and stairs. A low-impact stand-in for jumping. | ACSM-PS11, ACSM-OA09 |
| Punch (controlled) | Push / trunk rotation | shoulders, arms | obliques, core | light–moderate (moderate in flurries) | Quick, controlled arm reach with trunk turn. Practises timing and coordination. | ACSM-PS11 (neuromotor), EXG1 |
| Guard hold | Isometric arm hold | shoulders, upperBack | core | light | A short brace that asks the shoulders to hold position. | ACSM-RT09 |
| Batting swing | Rotation | obliques, core, shoulders | glutes, hipAbductors | light–moderate | Turns the trunk through a full swing. Practises timing to a moving cue. | ACSM-PS11, EXG2 |
| Bowling action | Overhead arc + rotation | shoulders, upperBack | obliques, core | light–moderate | A big, smooth overhead arc. Mobility for the shoulders. | ACSM-PS11 |
| Balance (one-foot / toe-tap) | Single-leg stance | ankles, glutes, hipAbductors | core, calves | light | Practises standing steady on one foot. | WHO20 (balance for older adults), ACSM-OA09, ACSM-PS11 |
| Jump *(opt-in)* | Plyometric | calves, quads, glutes | core | moderate–vigorous | Short bursts of effort for players who choose them. | ACSM-PS11 |

### 8.2 Per stage

Intensity: L = light, L–M = light to moderate, M = moderate (design target, §8 note).

| Id | Patterns | Primary | Secondary | Int. | Benefits (2–3, approved copy) |
|---|---|---|---|---|---|
| `daily-quest` | warm-up march, mixed, cool-down reach | quads, glutes, shoulders | core, obliques | L–M | A short daily session. Builds a regular movement habit. Includes warm-up and cool-down. |
| `w1-forest-escape` | squat, lateral flexion, overhead reach | quads, glutes | obliques, shoulders | L | Learn the three core moves. Gentle full-body movement. |
| `w1-river-crossing` | lean→squat combos | quads, obliques | glutes, core | L–M | Links side-bends with squats. Practises quick, controlled changes. |
| `w1-guardian-grove` | squat, lean, reach (boss rhythm) | quads, glutes, obliques | shoulders, core | L–M | Longer effort with planned rest beats. Reaction timing. |
| `w1-firefly-trail` | reach-heavy, squat, lean | shoulders, upperBack | quads, obliques | L | A calm replay. Lots of reaching to open the shoulders. |
| `w2-desert-dunes` (D) | squat, lean, reach | quads, glutes | obliques, shoulders | L | Easy re-start in a new world. Steady leg work. |
| `w2-sandstorm-temple` | squat, two-lane leans | quads, obliques | glutes, core | L–M | Bigger side-to-side moves. Sustained leg work. |
| `w2-shifting-sands` | lateral step, squat | hipAbductors, glutes | quads, obliques | L–M | Sideways stepping. Whole-body movement. |
| `w2-scorpion-king` | step, squat, lean | hipAbductors, quads, glutes | obliques, core | M | Longer effort in waves. Reacting to cues on both sides. |
| `w3-neon-city-rooftops` (D) | squat, lean, reach | quads, obliques | shoulders | L | Gentle new-world start. Steady rhythm. |
| `w3-neon-city-chase` | squat, lean, gate reach | quads, glutes, obliques | shoulders, core | L–M | Faster combos with rest beats. Coordination. |
| `w3-hologram-wall` | isometric push, squat, lean | shoulders, chest, core | quads | L–M | Steady holds for the upper body. Mixes holds with moves. |
| `w3-drone-core` | duck, push hold, reach | quads, shoulders, core | chest, obliques | M | Upper- and lower-body mix. Boss rhythm with rests. |
| `w4-mountain-trail` (D) | squat, lean, reach | quads, glutes | obliques | L | Low-density recovery stage. Easy pacing. |
| `w4-summit-storm` | squat, lean (gusts) | quads, obliques | glutes, core | L–M | Sustained leg work. Changes of direction. |
| `w4-glacier-run` | march/jog, calf raise, squat | hipFlexors, calves, quads | glutes, core | M | Raises breathing and heart rate. Lower-leg work. |
| `w4-yeti-pass` | march, calf raise, push hold, squat | quads, calves, shoulders | core, glutes | M | Full-body boss in waves. Holds plus steps. |
| `w5-nets-practice` (D) | rotation (swing), squat | obliques, core, shoulders | glutes | L | Learn to turn through the trunk. Timing practice. |
| `w5-floodlight-run` | swing, overhead arc, squat | obliques, shoulders, upperBack | quads, core | L–M | Big upper-body arcs. Trunk rotation both ways (handedness swap in replays). |
| `w5-super-over` | swing, bowl, lean | obliques, shoulders | quads, core | L–M | Rhythmic rotation. Coordination under a fun count. |
| `w5-stadium-final` | swing, bowl, step, squat | obliques, shoulders, hipAbductors | quads, core | M | Whole-body boss. Rotation plus side steps. |
| `w6-temple-steps` (D) | mixed recap, calf raise | quads, hipAbductors, calves | obliques | L | Easy recap of every move so far. |
| `w6-stone-bridge` | single-leg / toe-tap stance, push hold | ankles, glutes, hipAbductors | core, shoulders | L | Practises steadiness on one foot. Calm focus. |
| `w6-hall-of-echoes` | mixed, cue-by-ear | quads, obliques, hipAbductors | shoulders, core | L–M | Listening and reacting. Varied whole-body movement. |
| `w6-temple-guardian` | squat, step, push, balance, reach | quads, glutes, shoulders, ankles | core | M | Strength-style holds plus balance in one boss. |
| `w7-shadow-dojo` (D) | controlled punch, guard hold | shoulders, arms | obliques, core | L–M | Learn controlled punches. Shoulder and arm work. |
| `w7-lantern-alley` | punch, guard, step | shoulders, arms, hipAbductors | obliques, core | M | Upper body with footwork. Coordination. |
| `w7-echo-duel` | punch combos, guard | shoulders, arms, obliques | core | M | Combo timing. Raises breathing in short bursts. |
| `w7-shadow-master` | punch, guard, duck, reach | shoulders, arms, quads | obliques, core | M | Full boss loop. Upper- and lower-body mix. |
| `w8-orbit-launch` (D) | march, calf raise, squat | hipFlexors, calves, quads | core | L–M | Easy recap with a march launch. |
| `w8-crystal-field` | balance, push, step | ankles, hipAbductors, shoulders | core, glutes | L–M | Slow, controlled moves. Steadiness and holds. |
| `w8-meteor-storm` | guard, punch, calf raise, squat | shoulders, arms, calves | quads, core | M | Fast reactions with planned rests. Whole-body mix. |
| `w8-nebula-gate` | all except swing/bowl | full body | core | M | Long whole-body boss in waves. |
| `w9-citadel-approach` (D) | all except swing/bowl, gentle | full body | core | L–M | A calm tour of every move. |
| `w9-trial-of-worlds` | all, four trials | full body | core | M | The longest effort, broken into trials with rest. |
| `w9-final-guardian` | all, boss | full body | core | M | Finale with three phases and a checkpoint. |
| `w0-garba-quest` | lateral step, overhead reach, calf raise to a beat | hipAbductors, shoulders, calves | glutes, core | L–M | Dance-style moves to music. Rhythm and coordination. |
| `w0-garba-quest-night2` | step, low punch "clap", reach | hipAbductors, shoulders, arms | core | L–M | More dance rhythm with arm work. |
| `w0-diwali-lights-run` | reach, squat, lean, march | shoulders, quads | obliques, hipFlexors | L–M | Lots of reaching. A festive whole-body run. |
| `w0-holi-colour-dash` | step, squat, lean, reach | hipAbductors, quads | obliques, shoulders | L–M | Side-to-side play. Whole-body movement. |

### 8.3 Sources (cite by key; titles exactly as below)

| Key | Source | Used for |
|---|---|---|
| WHO20 | World Health Organization. *WHO guidelines on physical activity and sedentary behaviour.* Geneva: WHO, 2020. Summary: Bull FC et al., "World Health Organization 2020 guidelines on physical activity and sedentary behaviour", *Br J Sports Med* 2020;54:1451–1462. | Weekly activity amounts, light/moderate wording, muscle-strengthening and balance for adults/older adults, "every move counts", reducing sedentary time |
| ACSM-GETP | American College of Sports Medicine. *ACSM's Guidelines for Exercise Testing and Prescription*, 11th ed. Wolters Kluwer, 2021. | Warm-up/cool-down, gradual progression, intensity terms |
| ACSM-PS11 | Garber CE et al. "Quantity and quality of exercise for developing and maintaining cardiorespiratory, musculoskeletal, and neuromotor fitness in apparently healthy adults: guidance for prescribing exercise." ACSM position stand, *Med Sci Sports Exerc* 2011;43(7):1334–1359. | Neuromotor (balance, coordination, agility) training, flexibility, progression |
| ACSM-RT09 | American College of Sports Medicine. "Progression models in resistance training for healthy adults." Position stand, *Med Sci Sports Exerc* 2009;41(3):687–708. | Holds and gradual load progression |
| ACSM-OA09 | Chodzko-Zajko WJ et al. "Exercise and physical activity for older adults." ACSM position stand, *Med Sci Sports Exerc* 2009;41(7):1510–1530. | Gentle band: balance, lower-leg work, conservative progression |
| HHS18 | U.S. Department of Health and Human Services. *Physical Activity Guidelines for Americans*, 2nd ed., 2018. | Secondary reference for the same activity messages |
| MET11 | Ainsworth BE et al. "2011 Compendium of Physical Activities: a second update of codes and MET values." *Med Sci Sports Exerc* 2011;43(8):1575–1581. | Design-target intensity ranges only (never displayed as measured) |
| EXG1 | Peng W, Lin J-H, Crouse J. "Is playing exergames really exercising? A meta-analysis of energy expenditure in active video games." *Cyberpsychology, Behavior, and Social Networking* 2011;14(11):681–688. | Active video games can reach light-to-moderate intensity, depending on game design |
| EXG2 | Biddiss E, Irwin J. "Active video games to promote physical activity in children and youth: a systematic review." *Arch Pediatr Adolesc Med* 2010;164(7):664–672. | Background only (youth sample): whole-body, lower-body-heavy games produce more activity than upper-body-only games; novelty wears off, so variety matters. **Do not show in app** (our players are adults). |

Rules for sources: cite only these unless a reviewer adds one after reading it. Phrase as
"Public guidelines such as the WHO 2020 guidelines describe…", never "studies prove this
app…". Before launch, a qualified reviewer checks every sentence of approved copy against
the cited source.

---

## 9. How the app should show this (stage info sheet)

Opened from the "i" on a stage card (map) and from the pause menu. Also shown on locked
Premium stages, without any price pop-up.

| Element | Content | Rules |
|---|---|---|
| Header | Title, world, length, intensity chip (Light / Light–moderate / Moderate), Free or Premium tag, "Recommended for: Gentle/Balanced/Active" | Intensity chip is "designed to be", never "you burned" |
| Body map | Front and back outline; primary regions filled, secondary hatched (shape + label, not colour alone) | Labels in plain words: "front of thighs (quadriceps)" |
| Moves | Icons of moves used, with the low-impact alternative named | Shows "Jumps off" when relevant |
| Benefits | 2–3 lines from §8.2, from the approved-copy table only (l10n keys) | No outcome promises, no numbers about the body |
| Why it helps | One sentence per move + source names, e.g. "Public guidelines (WHO 2020; ACSM) describe muscle-strengthening and balance activities as part of general fitness." | Source names only; a "Sources" link expands to the full titles in §8.3 (in-app text, no external link required) |
| Disclaimer | Fixed text below | Always visible on the sheet, and on first launch |

**Standard disclaimer (en; translate for hi, gu):**
> Joynetic is a game for general fitness and fun. It is not a medical product and does
> not diagnose, treat or prevent any condition. The information here is general fitness
> information. Move within your comfort, stop if something hurts or feels wrong, and talk
> to a doctor before starting if you have a health condition, an injury or are pregnant.

---

## 10. Fun and focus

### 10.1 Per-world fun hooks

| World | Story beat | Collectible | Surprise mechanic | Rhythm / music | Combo | Rest-beat breather | Boss telegraph | Cosmetic reward |
|---|---|---|---|---|---|---|---|---|
| 1 Forest | The forest wakes as you run; the Grove guardian is soothed | Firefly jars (orbs) | A deer crosses: a bonus orb trail appears | Wooden percussion, 96 BPM | Squat-lean "river hop" | Firefly glade: slow breathing cue, orbs only | Branch glow + 3-pulse rise | Leaf trail |
| 2 Desert | Find the buried temple's three seals | Sun seals | Mirage: an encounter turns out to be an orb (announced by shimmer, never a trick hit) | Clay drum, hand claps | Step-squat "dune slide" | Oasis shade | Tail glow, clay drum | Sand-dune cape |
| 3 Neon | Reboot the drone hub | Power cells | Blackout: lights dim, sounds lead for 5 s (warning +0.5 s) | Synth, beat-synced signs | Push-hold → duck "firewall" | Rooftop garden | Scanner sweep line | Neon visor |
| 4 Mountain | Reach the summit flag-line | Cairn stones | Snow guardian waves from a ridge, drops a boost orb | Footstep loop at BPM | March → calf raise "ice ledge" | Tea-stop hut (march slows to stillness) | Ridge rumble | Woollen scarf |
| 5 Stadium | Win over the night crowd | Match balls | "Free hit": next ball scores double | Crowd claps on beat | Swing-swing-gate "over" | Drinks break | Floodlight flash | Floodlight trail |
| 6 Temple | Relight the water lamps | Lamp flames | Echo: a sound plays alone, move by ear | Flute and bells | Balance → push "bridge" | Still pool (balance-free) | Gem glow | Stone-pattern sash |
| 7 Arena | Earn the shadow master's respect | Lantern tokens | Mirror echo copies your last combo as pads | Taiko-style pulse | 1-2-guard | Lantern meditation | Double drum + whoosh | Ink-wash gloves |
| 8 Cosmic | Guide the star-whale home | Star shards | Low-gravity lane drift (visual only) | Chimes, slow pads | Guard-punch "meteor break" | Floating calm | Nebula swirl | Comet tail |
| 9 Finale | Calm the Guardian with every world's light | World sigils | One previous world's prop style returns | Leitmotif returns | Cross-world combos | Memory room (replays past worlds' music) | Same 3-pulse rise every time | Guardian crown (calm-coloured) |
| Events | Festival story card | Festival tokens | Beat drop: one bonus round | Event BPM | Event dance combos | Short "sip water" beat | — | Festival outfit (event-only, never paid) |

### 10.2 Anti-boredom rule set (applies to every stage; checkable by a content lint)

1. **Variety cap.** No encounter type more than 3 times in a row, except inside a segment
   tagged `rhythm: true` (Garba rounds, pad flurries, the "6 balls" finale).
2. **Pacing waves.** Intensity alternates every 20–30 s: build (denser) → peak → ease.
   No wave longer than 30 s at peak density; at least one ease section per minute.
3. **Surprise every ~45 s** (window 35–55 s). A surprise is a visual or scoring moment from
   §10.1 (bonus orb trail, golden gate, companion cameo, free hit). Surprises are **never
   damaging and never untelegraphed**. Tag them `tag: "surprise"`.
4. **New thing per stage.** Every stage introduces at least one of: a new move, a new
   encounter combo, a new surprise, or a new music layer.
5. **"Almost there" moments.** At 75 % of the run the progress bar glows and Coach Kavi
   says one line ("Last stretch!"); in the final 20 s the music adds a layer. Before the
   boss checkpoint: "Checkpoint ahead — hearts refill."
6. **Streak feedback.** Combo streak of 5/10/20 gets sound + visual swells (crowd, fireflies,
   lights). Breaking a streak is silent; never a negative sound beyond the normal miss cue.
7. **End-of-stage reward.** Every completed stage gives stars (1–3), one collectible and
   progress toward the world's cosmetic. Cosmetics are earned only, never sold.
8. **Rest beats are content.** Breathers have their own scenery moment and a breathing cue
   ("breathe in… and out") so they feel designed, not empty.
9. **Replay variety.** Replays may mirror lanes and swap handedness (deterministic seed from
   stage id + replay count), never change difficulty.

---

> **Next up (not yet built):** `w1-lotus-lake` — an attempt reused Monsoon Meadow's exact encounter timings with new hints only, so it was rejected as a duplicate. Build it with its own layout (lotus-leaf orbs, bamboo beams, lily-pad blocks, surprises at ~45/90/135 s).
> **Also next up:** `w2-sun-temple-run`, `w3-arcade-rush`, `w4-cloud-ridge` — first attempts reused existing stages' encounter layouts (Oasis Caravan, Neon Night Market, Glacier Pass) and were rejected as duplicates. Each needs its own layout. Check with a duplicate-layout comparison before adding to the catalogue.
