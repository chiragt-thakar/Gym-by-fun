# 5 — GAME D: "Tapeball Tamasha" (self-view street cricket + India casual sports) — design brief (2026-11-05)

Read: AGENTS.md, docs/stages-roadmap.md (§2 World 5 Stadium Nights, §3.6 swing, §3.7 bowl, §6 bands, §7 Free/Premium),
scratchpad/research/3-tech.md (front-camera limits). No repo edits. Numbers marked *est.* need device/replay confirmation.

## 0. One line
A self-view backyard/gully cricket game: you see your own mirrored silhouette (stylised, never raw video — rule 2) standing on a
taped-up lane pitch; you **bat, bowl and field with body moves**, plus two India-loved casual mini-modes: **Raid Rush**
(kabaddi-style raid with side steps) and **Shuttle Rally** (badminton-style overhead reaches). Low-impact by default, no jumps,
no running toward the phone, empty hands always.

**Name:** *Tapeball Tamasha* (tape-ball = generic street-cricket term; "tamasha" = spectacle). Backups: *Backyard Boundary*,
*Gully Games Night*. Run a trademark + Play Store search before lock-in. **Avoid "Chhakka"** as a title word (also used as a slur
in parts of India). Avoid "Premier", "League", "IPL", "T20 World", "Super Kings", "Indians", "Royals", "Knight", "Titans",
"Capitals", "Sunrisers", "Giants" in any title, mode, crew or cosmetic name.

## 1. Fit with what exists
- Reuses roadmap moves: batting swing (§3.6, `ball`), bowling action (§3.7, `wicket`), squat, lean, side step, raise arms,
  barrier hold, march/knee lift (3-tech §4.1). New: `catchZone` (end-pose reach), `overheadReach` (one-arm high side zone).
- Engine: a judged-target engine like 3-tech's `BeatEngine` contract (`input`, `advance`, `RunEvent` out) — a **delivery is a
  target with `atMs`**; no lanes needed. Level schema v2 `mode: "cricket" | "raid" | "shuttle"` plus a `match` block
  (`balls`, `targetRuns`, `wicketsAllowed`, `bowlerSeed`). All formats are JSON configs (rule 7); director deterministic and
  seeded (rule 8) so crew tournaments are fair (same seed = same deliveries for everyone).
- Visual: reuse `SceneTheme.stadium` colours for the Stadium Nights theme; new gully/terrace/maidan themes as palettes.
- World 5 Stadium Nights stays as the runner world; Game D is a **separate mode hub** ("Sports" tab) that shares recognisers.

## 2. Core loop (one delivery ≈ 10–14 s)
1. **Set** (2 s): stand on the crease marker (centre). HUD shows a mirrored silhouette + "space ring".
2. **Delivery telegraph** (band warning time: Gentle ≥ 2.0 s, Balanced ≥ 1.6, Active ≥ 1.3): stylised original bowler
   (a cartoon neighbourhood character or the original "bowling machine" from w5) runs in; **approach ring** shrinks onto the
   hit zone — the ring *is* the timing window (3-tech §4.5).
3. **Shot** (player): backlift → swing (or leave / defend). Graded Perfect/Good/OK/Miss on capture timestamp with latency
   compensation (3-tech §3.2).
4. **Outcome** (game state decides, rule 6): grade + chosen shot + fielder layout (seeded) → 0/1/2/4/6 or caught.
5. **Run between wickets** (cardio beat, optional by band): on 1s/2s the HUD says "Run!" → **march in place**; every 4 steps
   = 1 run before the throw-in bar fills. Never forward running, never a sprint (cadence target ≤ 2 Hz *est.*).
6. **Reset / breather** (2–3 s): replay of your shot as a stylised animation (no video), commentary line.
Bowling innings mirror the loop (you bowl, AI bats, then you **field** the ball it hits).

## 3. Move → action mapping (front camera, 2.0–2.5 m, Lite model)
All recognisers fire on **end states held ≥ 2 frames**, never on velocity (3-tech §3.1). Every reject emits a reason
(`notVisible | tooShallow | tooEarly`) so the HUD can explain (rule 5, Q5-8).

| Action | Move | Detection notes | Verdict |
|---|---|---|---|
| **Drive / ground shot** | Batting swing §3.6: wrists together (< 0.3 torso), backlift at/above trailing shoulder held 100 ms, wrist midpoint travels ≥ 1.0 shoulder width (low-impact 0.6, no rotation) to front hip, 250–1200 ms | Use **wrist midpoint**, not L/R wrist — avoids MediaPipe L/R swap when wrists cross. Swing is lateral/in-plane (across body), not toward camera. Hips within 0.5 torso = no lunge. 1.5 s cooldown. | Reliable (end states) |
| **Lofted shot** (bonus, can give 6) | Same swing, but end zone is **shoulder height or above** on the front side, held 2 frames | End-zone y relative to shoulder line is coarse and robust. Ship as bonus only until replay data confirms. | Medium |
| **Leave** | Both hands high: wrists above nose ≥ 0.15 torso (raise-arms) during the ball window | Existing `raiseArms`. Engine resolves by encounter: during a delivery window, raise = leave. Leaving a wide ball = good judgement bonus. | Reliable |
| **Defend / block** | Barrier hold at chest (existing `BarrierHoldRecogniser`) across arrival ±200 ms | Already shipped; foreshortened push is *only* used as a static hold, never as a punch-like strike. | Reliable |
| **Bowl** | Bowling action §3.7: standing, straight arm (≥ 150°, low-impact 130°) above nose ≥ 0.3 torso → wrist below hip on front side in 400–1500 ms | No run-up, no step. Overhead-only start state, sweep down is in-plane. 1.5 s cooldown. | Reliable |
| **Line choice (bowling)** | Side step L / centre / R before the "ready" tone | Existing `SideStepRecogniser`. Picks off/middle/leg target. | Reliable |
| **Pace vs slower ball** | Tempo of the bowl: start→complete ≤ 800 ms = pace, 900–1500 ms = slower ball | Duration between two end states (frame-quantised ±67 ms at 15 fps) — not a velocity threshold. Wide gap between bands absorbs jitter. | Medium (ship as "bonus") |
| **Catch (high)** | `catchZone`: both wrists together (< 0.35 torso) in a lit zone — high-left / high-centre / high-right — held 2 frames before ball lands | Zones are relative to torso (3-tech: wrists marginal in px → zones, not angles). High-centre collides with raise-arms: wrists-together distinguishes it. | Reliable *est.* |
| **Catch (low) / ground stop** | Half squat (hip drop ≥ low-impact squat) + both wrists below hip, on the side the ball comes (lean or side step first) | Squat + lean already shipped. **No dives**, no lunges — "step and get low". | Reliable |
| **Throw-in** | Raise one arm overhead (bowl start state) and hold 300 ms → "throw" | End state only; a gentle overhead hold, not a fling. Counts toward overhead cap (§9). | Reliable |
| **Celebrate** (optional, no score) | Both arms up held 1 s | Flavour only; never required. | Reliable |
| **Raid Rush: dodge** | Side step L/R | Existing. | Reliable |
| **Raid Rush: touch** | Lateral open-hand reach to the side: reach ≥ 0.75 armLength (low-impact 0.6), elbow ≥ 145°, wrist at shoulder ±0.3 torso, held 2 frames | Same signal as lateral punch (3-tech §2) but **slow and held** — no punching motion. Targets placed ≥ 30° off-axis so reach is in-plane. | Reliable |
| **Raid Rush: duck the chain** | Squat (low-impact half squat) | Existing. | Reliable |
| **Raid Rush: bonus line** | Toe-tap reach (Gentle) / knee lift (Active) | Knee lift recogniser (3-tech §4.1). No hops. | Reliable |
| **Shuttle Rally: smash / clear** | `overheadReach`: one wrist above nose ≥ 0.3 torso **and** offset to the shuttle side (wrist x beyond shoulder), held 2 frames | Distinct from bowl (no sweep-down needed) and from raise-arms (one arm, side offset). Engine resolves by encounter; never place a `wicket` and a shuttle within 2 s. | Reliable *est.* |
| **Shuttle Rally: net drop** | Side step + mid-height reach on that side | No lunges toward the net (= toward the camera). | Reliable |
| **Shuttle Rally: move across** | Side step | Existing. | Reliable |

**Explicitly banned (detection + safety):** forward lunges, steps or runs toward the phone; punch or swing *at* the camera;
dives; jumps (unless the player enables them, and then only in Raid Rush as a "small hop"); wrist flicks for spin (undetectable
at 8–12 px wrists); fast repeated swings (blur); twisting under load (rotation requirement off in low-impact).

## 4. Match formats (all JSON configs, all ≤ 4 min of play)
| Format | Rules | Length | Bands |
|---|---|---|---|
| **Nets** | Free practice, 12 balls, hints, no outs; shows grade + "why" for every miss | 2–3 min | All; Free |
| **Super Over** | Bat 6 balls, 2 wickets max (beginner: no wickets — misses are dots), then bowl 6 balls to defend your total; fielding in between | 2 × ~75 s + breaks ≈ 3:30 | All |
| **3-Minute Chase** | Need *T* runs in 18 balls (T seeded by difficulty: 18 / 26 / 34 *est.*); timer only runs while tracking is green | 3:00 | All; Premium |
| **Bowl-Out** | 6 deliveries at lit stumps (line + tempo variety), AI defends | ~90 s | All; warm-up friendly |
| **Fielding Drill** | 10 catches / stops, zones random-seeded, march-back between | ~2 min | All |
| **Gully Match** | 2 overs bat + 2 overs bowl vs AI side, breather card between innings | ~8 min | Balanced/Active only, Premium |
| **Raid Rush** | 3 raids × 30 s "breath bar"; tag defenders (touch), dodge, return to midline (side step centre) | ~2:30 | All |
| **Shuttle Rally** | Rally to 11 (best of 1), rally continues until a miss; shuttle hang time 1.6–2.4 s | ~3 min | All; Premium |

Rules that keep it fair and safe:
- **Tracking failure (rule 5):** any delivery whose window overlaps amber/red tracking is a **"dead ball"** — re-bowled, no run,
  no wicket, the chase timer pauses, HUD explains ("Step back — I lost your hands").
- **Rule 6:** a swing with no ball in window does nothing. A swing out of timing just misses.
- Wickets only on intermediate+; a wicket is only possible on a ball telegraphed "stumps lit" (bowled) or a catch the AI fielder
  takes from an OK-grade lofted shot. Never more than 2 wickets lost per Super Over.
- Deliveries of one over never mix a `ball` and a `wicket` within 3 s (w5 rule); after a bowl or overhead, 2 s empty.

## 5. Difficulty × age bands (compose with §6 of the roadmap)
| | Gentle (default) | Balanced | Active |
|---|---|---|---|
| Warning (ball telegraph) | ≥ 2.0 s | ≥ 1.6 s | ≥ 1.3 s |
| Swing window | ±550 ms (assist) | ±350 → ±300 | ±300 → ±250 |
| Swing thresholds | low-impact (0.6 width, no rotation) | low-impact until calibrated twice | standard (1.0 width, ≥ 15 % rotation) |
| Bowls per session (max) | 12 | 18 | 24 |
| Overhead moves / min (bowl + smash + throw) | ≤ 4 | ≤ 6 | ≤ 8 |
| Run-between-wickets march | off (auto-run) | on, 4 steps/run | on, 4 steps/run, longer chases |
| Wickets | none on beginner | 2 | 2 (3 in Gully Match) |
| Raid Rush bonus line | toe-tap | toe-tap | knee lift |
| Rally speed | hang time 2.4 s | 2.0 s | 1.6 s |
Safe-progression rules (one step per week of play, deload every 4th, struggle and comeback rules) apply as written in §6.

## 6. Commentary and voice (en / hi / gu)
- **Original pre-recorded voice actors** (one male, one female per language) — no TTS of real commentators, no imitation of
  famous voices, catchphrases or broadcast jingles. ~250 lines per language at launch, keyed by event
  (`perfect_drive`, `lofted_six`, `dot`, `dead_ball_tracking`, `wicket_bowled`, `catch_taken`, `run_call`, `chase_close`,
  `streak_5`, `warmup`, `space_check`). Deterministic picker with a no-repeat window of 20 lines (seeded, rule 8).
- Hindi and Gujarati use natural code-switching ("Kya timing hai!", "Shabash, ekdum seedha bat!", Gujarati:
  "Wah, jordar shot!", "Dhire dhire, saras!"). Native-speaker review for slang that is crude in one region.
- Tone: neighbourhood "mohalla" commentator, warm and funny about *the game*, never about the body. No weight, calorie or
  health lines (AGENTS.md). Allowed: "Nice rhythm!", "Great balance!". Banned: "burn", "tone", "fat", "lose".
- Tracking lines blame the camera, never the player: "Arre, the camera lost you — take one step back."
- Audio-only cues for every ball (whistle on delivery, "thwock" on hit) so the game is playable by ear. Subtitles always on.
- **No microphone**: no voice shot-calling, no chant detection (new permission, privacy surface).
- Crowd = generated murmur, no real chants or team songs; swell on 5+ streak (w5 rule).

## 7. Progression and cosmetics
- **Player card** (no real-player likeness): level 1–50 from "Gully Rookie" to "Maidan Legend" (original titles); XP from
  balls faced, catches, raids — not from minutes (avoid encouraging overplay; daily XP soft cap after 3 sessions).
- **Skill badges** (end-state skills): "Straight Bat" (10 Perfect drives), "Safe Hands" (20 catches), "Line & Length"
  (6 bowl-out hits), "Raid Ninja", "Shuttle Wall".
- **Cosmetics — all earned by play, none sold individually, no loot boxes, no random drops:**
  - Bats: tape-ball bat with coloured grip tape, plank bat, painted-stripes bat, glow bat (Stadium Nights), monsoon bat.
  - Kits: original colour palettes reviewed against a **deny-list of franchise colour combos** (two-colour primary pairs in
    current pro-league use); patterns: block-print border, kite-festival stripes, plain whites for "Classic".
  - Stadium themes: *Gully Lane* (scooters, parked cycles, a water tank as stumps), *Terrace Top* (washing lines, kites),
    *School Maidan*, *Beach Evening*, *Monsoon Ground* (rain shimmer), *Stadium Nights* (reuse `SceneTheme.stadium`).
    No real grounds or skylines; no deity imagery or religious symbols (roadmap rule).
  - Mini-mode skins: kabaddi mat colours, shuttle trails.
- **Avatar:** the self-view silhouette wears the kit as a stylised overlay drawn from landmarks only (no camera pixels shown,
  stored or uploaded — rules 2/4).

## 8. Gym crew tournaments (server gyms + progress + reports modules)
- A gym creates a **crew** (4–11 members) or joins a gym league; members are verified gym members (entitlement → Premium free).
- **Format:** weekly "Crew Cup". Every member plays the **same seeded Super Over / Chase** (deterministic director → identical
  deliveries). Crew score = sum of each member's best 2 counted attempts that week; **max 3 counted attempts per day** and
  every attempt ≥ 4 h apart (stops grinding; no "no breaks" mode).
- **Divisions by band** (Gentle / Balanced / Active) so a 55-year-old member is never ranked against a 22-year-old's
  thresholds; crew score normalises each attempt to its band par.
- Knockout bracket: 8 crews, quarter/semi/final over 3 weeks; async within a 48 h window per round.
- Anti-cheat without video: server plausibility checks on uploaded **event summaries** (grades, timing deltas, landmark
  quality stats, fps) — impossible-timing streaks or fps anomalies flag for review; tracking-forgiven balls are excluded.
- Gym owner dashboard (reports module): participation, attendance-linked streaks — no individual body metrics shown.
- No prizes of monetary value; trophies are in-app cosmetics + gym wall certificate (avoid prize-competition / real-money
  gaming rules; keep clear of India's 2025 online gaming law on real-money games).

## 9. Space and injury safety (the biggest real risk)
Indian homes: small rooms, **ceiling fans at 2.4–2.7 m**, glass cabinets, TVs, children and pets walking in.
- **Space check before every cricket/shuttle session** (≈ 15 s, mandatory first time each day):
  1. "Stand where you'll play" — QualityGate full-body-in-frame at ≥ 2.0 m (body ≤ 65 % frame height *est.*).
  2. "Arms out wide" (T-pose) and "both arms up": both wrists must stay inside the frame with ≥ 8 % margin — proves the player is
     far enough from the phone; also calibrates arm length/shoulder width for the swing.
  3. Self-checklist (tap each): **Fan switched off** · **1 m clear on each side and above your hands** · **Nothing breakable
     within reach** · **No real bat, racket or ball in your hands** · **Dry, non-slip floor / bare feet or trainers**.
  4. If the check fails or is skipped, only *Nets (low-impact, no overhead)* and Raid Rush (side steps) are offered.
- **Empty hands rule:** pose models can't see objects reliably, so the game never asks for props; loading tips repeat it.
- **Intruder pause:** if a second person enters the frame (Pose Landmarker `numPoses = 2` on upper-mid devices; on budget, sudden
  landmark jumps / quality drop) → instant pause "Someone's in your play space." Tracking loss pause already covers the rest.
- **Overhead shoulder load:** per-band caps (§5); optional "switch arm" every over in bowl-out (balanced load, also helps
  left/right symmetry); 2 s empty after every overhead move.
- **Back:** rotation requirement off in low-impact; swing hips-stable guard prevents lunge; no full-power "slog" bonus.
- **No forward motion toward the camera** anywhere (detection *and* tripping/phone-knock safety).
- "This doesn't feel right" button on pause → end gently, keep progress, standard disclaimer (§6 rule 6).
- Warm-up (45 s: arm circles, gentle trunk turns, march) and cool-down auto-inserted around the first session of the day.

## 10. Cricket-season timing without IP
- Run a **"Summer Cricket Fest"** event window roughly mid-March → early June (when the big domestic T20 season and exam-free
  evenings coincide) and short "Cricket Fever Week" windows around major international tournaments — all named generically.
- Never use league/tournament/team/player names, trophies, fixtures, match results, scores or broadcaster graphics
  (score-bug layouts, replay wipes, sponsor-style overlays). No "official", no "live match" tie-ins, **no prediction or
  "pick the winner of tonight's match" features** (fantasy/real-money adjacency).
- Play Store listing and ASO: no trademarked league or team names as keywords (Play metadata policy + trademark risk).
- Evening-friendly: Daily "Over of the Day" refreshes at 18:00 IST so a 3-min session fits before evening matches; no push
  notifications timed to real match starts.
- Festival crossovers reuse existing event rules (Diwali lights theme for Stadium Nights, Holi colour bats) — no religious symbols.

## 11. Free vs Premium (Google Play Billing only, access checked at mode select, never mid-match — §7 rules)
| Free | Premium (₹129/mo, ₹699/yr; gym members free) |
|---|---|
| Nets, daily Super Over ("Over of the Day"), Bowl-Out, Raid Rush taster (1 raid set), Gully Lane theme, 3 bats, 2 kits, joining a gym crew if their gym grants it | 3-Minute Chase, Gully Match, Fielding Drill, full Raid Rush, Shuttle Rally, all themes, all cosmetic tracks, creating private crews/leagues, Festival events |
No ads with payment nudges, no links outside Google Play (rule 11), no paywall on a results screen after a loss.

## 12. Metrics
- **Fun/retention:** D1 / D7 / D30; sessions per active week; Super Overs per session; % chases finished; mode mix.
- **Motion quality (from replay + telemetry, no video):** swing recall ≥ 0.9 and false-trigger ≤ 1 / 2 min idle (replay gate,
  ≥ 20 players, 2 phones incl. budget); reject-reason rates per move (notVisible / tooShallow / tooEarly); dead-ball rate
  (target < 5 % of deliveries); median latency-compensated timing delta and spread; fps distribution.
- **Fairness:** win rate of seeded chases by band (target 55–75 % beginner); simulator bots (`competent`, `slow` 200 ms/15 fps,
  dropout) all pass feasibility gates before a config ships.
- **Safety:** space-check completion and failure rate; "doesn't feel right" taps per 1 000 sessions; intruder pauses per session;
  overhead-cap hits; support tickets tagged injury/property (target ~0; any → review).
- **Business:** Free → Premium conversion from Sports hub; crew participation (% gym members playing weekly Crew Cup); crew
  retention vs solo.
- "Active minutes" only — never calories or fitness outcomes.

## 13. Risks and mitigations
| Risk | Mitigation |
|---|---|
| **IP / trademark** (league, franchises, players' likeness, stadiums, trophy shapes, broadcaster look, commentator voices, team colours) | Original characters, grounds and voices; colour deny-list; legal review of name, icons, commentary script; no real-match tie-ins; generic event names. |
| **Real-money / gambling adjacency** | No predictions, no cash/coupon prizes, no betting language ("odds", "stake"). |
| **Injury from swinging in small rooms** (fans, furniture, glass, kids/pets) | Mandatory space check, fan-off checklist, frame-margin distance test, empty-hands rule, intruder pause, low-impact default, overhead caps. |
| **Shoulder/back strain** from repeated bowling, smashes or rotation | Per-band overhead caps, 2 s gaps, no rotation in low-impact, warm-up, deload rules. |
| **Detection: L/R wrist swap** when hands cross the body in a swing | Use wrist midpoint + wrists-together, not per-wrist identity. |
| **Detection: blur on fast swings** (15–30 fps) | End-state backlift + end-zone detection; travel window 250–1200 ms; no speed bonus. |
| **Overlap between raise-arms / bowl / overhead reach / catch-high** | Engine resolves by active encounter; never two overhead-family targets within 2 s; wrists-together disambiguates catch. |
| **Latency makes timing feel unfair** | Latency compensation on capture timestamp, wide windows, approach ring visualises window, dead-ball on tracking loss. |
| **Loose clothing / saree / dupatta hides wrists or knees** | `notVisible` reason + hint; low-impact thresholds; march detection falls back to auto-run. |
| **Low intensity** (cricket is mostly standing) | Run-between-wickets march, fielding drills, Raid Rush; keep it fun-first, not a fitness claim. |
| **Repetition boredom** | Seeded bowler variety (line, slower balls, "googly" visual-only fake-outs), themes, mini-modes, weekly Crew Cup. |

## 14. Build order (smallest valuable slice first)
1. Nets + Super Over (bat only) on existing swing/raise/barrier recognisers + space check + commentary (en).
2. Bowl-Out (bowl + side-step line) and fielding (`catchZone`, low stop), then full Super Over.
3. Crew Cup (seeded attempts, server summaries, plausibility checks).
4. Raid Rush (side step, lateral touch, squat), then Shuttle Rally (`overheadReach`).
5. hi/gu voice, Summer Cricket Fest themes, Chase and Gully Match.
Each step: recorded-data replay gate for any new recogniser (AGENTS.md: tests first, no threshold change without replay pass).
