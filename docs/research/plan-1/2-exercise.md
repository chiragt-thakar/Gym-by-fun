# 2. Exercise-science research: Joynetic candidate moves

Scope: adults 18+, low impact by default, 2x2 m home space, camera-only. Everything here is
**general fitness information for design**, not advice and not a measurement. It builds on
`docs/stages-roadmap.md` §3 (moves) and §8 (body targets and sources). It uses the same body-region
keys as §8 (`quads`, `glutes`, `hamstrings`, `calves`, `hipAbductors`, `hipFlexors`, `core`, `obliques`,
`shoulders`, `upperBack`, `chest`, `arms`, `ankles`). (Lateral lunge also trains the adductors, but
§8 has no key for them yet.)

## A. Intensity vocabulary (what we can say)

| Term | WHO 2020 meaning (general info) | Talk-test wording for in-game copy |
|---|---|---|
| Light | Below moderate (about 1.5 to <3 METs) | "Easy: you can sing or chat freely" |
| Moderate | About 3 to <6 METs; breathing and heart rate noticeably higher | "You can talk, but not sing" |
| Vigorous | 6 METs or more | "Only a few words between breaths" (never the default) |

Evidence on how hard games like ours are:
- Active video games usually reach **light to moderate** intensity (often called about 3 to 6 METs).
  Dance and boxing games are higher than balance-only or arm-only games. Results vary widely
  with game design and player (2025 umbrella review: 20 reviews, 418 studies; only 30% of
  reviews reported adverse events systematically).
- Fitness-boxing on pads or bags (not shadow boxing) reached about 68 to 72% VO2max in trained
  volunteers. Studies that measure **shadow boxing** directly are scarce (one 2025 conference abstract
  found VR boxing about equal to shadow boxing). So our punch intensity is a **design target only**.
- Zumba-style dance fitness in young women measured about 6.6 to 8.8 METs, with heart-rate traces
  that looked like intervals. Our low-impact, camera-paced dance will likely be lower. Play-test it;
  don't promise a number.
- Garba: no controlled study of Garba intensity was found. One small Indian study calls it
  "comparable to aerobic exercise" but has thin data. Treat it as **light to moderate, depending
  on pace**. Press reports of cardiac events at Garba events are commentary, not evidence: don't cite them
  in the app, but they support keeping festival stages self-paced with built-in rests.
- MET values: the **2024 Adult Compendium** (Herrmann et al., third update, ages 19 to 59, adds a
  Video Games heading) replaces the 2011 Compendium (§8 key MET11). Suggest adding it as `MET24`.
  Values are design targets only and are never shown to players.

## B. Per-move table

Fit for 2x2 m: OK = fits a standing footprint about 1 m wide; Tight = needs most of the 2 m width or arm span.

| Move | Primary / secondary (§8 keys) | Intensity alone | Safety cautions (joints, impact, space) | Low-impact / easier alternative | 2x2 m |
|---|---|---|---|---|---|
| Shadow punch (jab/cross) | shoulders, arms / obliques, core, chest | light to moderate; moderate in flurries | Don't snap the elbow straight (keep the soft-elbow cap, recogniser ≥145°, not 180°). Repetitive arm swinging is the most common exergame overuse pattern (shoulder, upper limb). Arm span is about 1.7 to 1.9 m, so watch for furniture and the phone stand. Pivot the back foot on smooth floors only. | Slower tempo, shorter reach (60%), no trunk turn, seated punches | Tight (front clearance) |
| Guard hold | shoulders, upperBack / core | light | Keep holds short (≤10 s at a time early on) and keep breathing (no breath-holding). Shoulders down. | One hand, or hands lower (chest height) | OK |
| Side step | hipAbductors, glutes / quads, calves | light to moderate | Lateral ankle roll. **Slippery tiles and socks** are common in Indian homes: suggest barefoot or non-slip shoes. Limit the step to about 0.5 m from centre. | Step-touch (small step, 45% range) | OK if step ≤0.5 m |
| March in place | hipFlexors, quads / calves, core | light to moderate | Minimal impact. Default aerobic move. | Seated march, or heel taps | OK |
| Jog in place | hipFlexors, quads, calves / core | moderate | Impact on knees and ankles. Floor bounce can shake the phone stand. Noise for neighbours. Make it opt-in or a "jog or march" choice. | March (30% lift) | OK |
| Knee lift (high march) | hipFlexors, core / quads, ankles | light to moderate | Balance on one leg; lift only as high as feels comfortable. Hold a wall or chair if needed. | Lower lift, or alternating toe tap | OK |
| Squat-to-reach | quads, glutes, shoulders / hamstrings, core | light to moderate | Partial depth, in a pain-free range. Knees follow the toes (no caving in). Heels down. Slow descent. Keep a chair behind as an option. | Mini-squat, or sit-to-stand to a chair | OK (overhead clearance) |
| Lateral lunge (low) | quads, glutes, hipAbductors / hamstrings, core | light to moderate | Inner-thigh (adductor) strain, knee caving in. Keep it shallow, the bent knee over the toes, the straight leg soft. Needs about 1.2 to 1.5 m width. | Side step with a slight knee bend | Tight (width) |
| Torso twist | obliques, core / upperBack | light | **Controlled, not ballistic.** Let the hips and feet pivot slightly to spare the low back. No fast end-range twisting. | Smaller range, slower tempo, arms crossed | OK |
| Overhead reach | shoulders, upperBack / core | light | Shoulder pinching at end range: reach only as high as comfortable. **Ceiling fans and low ceilings** in Indian homes: add a setup check. | Reach to shoulder height, or one arm at a time | OK (vertical clearance) |
| Calf raise | calves / ankles | light | Balance: hold a wall. Slow lowering protects the Achilles. | Two-hand support, smaller rise | OK |
| Garba-style step-clap | hipAbductors, shoulders, calves / glutes, core, arms | light to moderate (pace-dependent) | **No spins or turns** (dizziness, plus the player leaves the camera frame). Tempo creep raises effort, so cap BPM by band. Festival fasting and heat (Navratri): show hydration and self-pacing tips as general info, not medical advice. | Step-touch with a clap at chest height, half tempo | OK |
| Arm circles | shoulders, upperBack / arms | light | Start small, grow gradually, go both directions. Stop if it pinches. | Shoulder rolls, small circles | Tight (arm span) |

## C. Session structure (design rules, general guidance)

| Phase | Recommendation | Basis |
|---|---|---|
| Warm-up | 3 to 5 min in-app (ACSM-style guidance is 5 to 10 min; short game sessions scale it down): march, arm circles (small to large), gentle reach, mini-squats. Light effort. | ACSM GETP / common ACSM-derived session model: warm-up, conditioning, cool-down |
| Conditioning | 6 to 20 min in waves. **Beginner work:rest 20 to 30 s : 20 to 40 s (1:1 to 1:2)**; later 30 to 45 s : 15 to 30 s. Punch "flurries" ≤20 to 30 s. Alternate upper-body and lower-body blocks so muscles recover. | Home bodyweight HIIT: 30:120 gave lower HR and less aversive feelings; 60:60 improved fitness. Pick by band. Keep vigorous bursts optional. |
| Rest beats | Active rest (march or breathe) or still rest. Never punish a pause. | AGENTS rule 5; ACSM individualisation |
| Cool-down | 2 to 5 min: slow march, overhead reach, torso twist (slow), calf stretch. Bring breathing back to easy. | ACSM-derived guidance (5 to 10 min, gradual) |
| Same-muscle strength work | Not on consecutive days at high volume. Rotate stage emphasis. | ACSM resistance-training guidance (about 48 h between hard sessions for the same muscle group) |
| Progression | Raise one variable at a time (duration, then density, then range), in small steps. Add deload stages. | ACSM 2011 (Garber): gradual progression, individualise |

Weekly framing (general info, WHO 2020):
- 150 to 300 min/week moderate aerobic activity, or 75 to 150 min vigorous, or a mix.
- Muscle-strengthening on 2 or more days per week.
- For 65+: varied multicomponent activity with balance on 3 or more days.
- Reduce sitting. "Some activity is better than none."
- Copy example: "Public guidelines such as the WHO 2020 guidelines suggest adults aim for 150 to 300
  minutes of moderate activity a week. Joynetic minutes can be part of your active time."

## D. Claims: safe vs forbidden

| Safe ("general fitness information") | Forbidden |
|---|---|
| "Gets your whole body moving", "raises your breathing" | "Burns X calories", "fat-burning", "lose weight", "tone", "slim" |
| "Works the leg muscles used for standing up" | "Treats / cures / prevents / reverses" any condition (diabetes, back pain, PCOS, BP) |
| "Practises balance and coordination" | "Clinically proven", "doctor-approved", "scientifically proven" (unless substantiated and approved by a reviewer) |
| "Public guidelines such as WHO 2020 describe…" | "Studies prove this app…", displaying MET or kcal as a measured value |
| "Stop if you feel pain, dizziness or unusual breathlessness" | Diagnosing, rehab or therapy framing, heart-rate "zones" from the camera |
| "Not a medical device; consult a healthcare professional for medical advice" (Play disclaimer) | Before/after body claims, any weight-loss timelines ("6 kg in 60 days") |

Regulatory notes:
- Google Play requires the Health apps declaration for every app. Non-medical-device health and
  fitness apps need a description disclaimer saying the app is not a medical device and doesn't
  diagnose, treat, cure or prevent any condition, plus a reminder to consult a professional.
- In India, ASCI's code requires claims to be truthful and substantiated. ASCI found all 60
  completed weight-management nutraceutical ads it reviewed in violation. Weight-loss claims
  are a top enforcement area. Some health claims also breach the Drugs and Magic Remedies Act.
  Get legal review before launch.

## E. Safety UX recommendations (derived)

1. **Setup check:** 2x2 m clear, nothing overhead (fan), non-slip floor, phone stand stable, no pets or children in the space.
2. **Optional readiness prompt:** a pre-participation questionnaire (for example the PAR-Q+, which is a validated
   tool; check its licence before use) or a simple "if you have a health condition, check with a professional" notice.
3. **Stop rules on every stage sheet:** pain, dizziness, chest discomfort, unusual breathlessness, so stop and rest.
4. **Defaults:** march not jog, step-touch not lunge, no spins, no jumps (opt-in only), soft-elbow punches.
5. **Effort self-report** (easy / OK / hard) after each wave feeds the deterministic director. No HR inference from the camera.

## F. Evidence gaps (be honest in docs)

- No direct measurement of shadow boxing METs for non-boxers. No controlled Garba intensity study.
- The exergame injury literature is thin and mostly Wii-era (shoulder, knee, hand). No good data on home
  collisions. Treat the space rules as precaution, not evidence-based thresholds.
- I didn't verify specific Compendium codes and values for each move in this pass. Check them on pacompendium.com.

## Sources

- WHO 2020 guidelines (Bull et al., BJSM 2020;54:1451–62): https://www.ncbi.nlm.nih.gov/pmc/articles/PMC7719906/ · https://bjsm.bmj.com/node/121498.full
- 2024 Adult Compendium of Physical Activities (Herrmann et al., JSHS 2024): https://pmc.ncbi.nlm.nih.gov/articles/PMC10818145/ · https://pubmed.ncbi.nlm.nih.gov/38242596/
- AVG umbrella review 2025: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12666624/ · https://www.frontiersin.org/journals/sports-and-active-living/articles/10.3389/fspor.2025.1706145/abstract
- Exergaming in healthy adults, systematic review: https://libmast.utm.my/Record/ntu-10356%2F70137/Description
- Boxing intensity (pads, sparring, fitness-boxing tempo): https://pmc.ncbi.nlm.nih.gov/articles/PMC6315673 · https://www.mdpi.com/2075-4663/6/4/119
- VR boxing vs shadowboxing (2025 abstract): https://www.exhibit.xavier.edu/summer_symposium/2025/schedule/6
- Zumba energy cost (Luettgen et al., JSSM 2012): https://jssm.org/jssm-11-357.xml-Fulltext · https://www.acefitness.org/certifiednewsarticle/2813/
- Garba and fitness (small Indian study): https://pdf.ipinnovative.com/pdf/9575
- Home bodyweight HIIT work:rest (Church et al.): https://researchonline.ljmu.ac.uk/id/eprint/14969/ · https://www.physoc.org/abstracts/longer-home-based-hiit-intervals-elicit-a-greater-improvement-in-aerobic-capacity-a-6-week-intervention-study/
- ACSM 2011 position stand (Garber et al.): https://digitalcommons.uri.edu/kinesiology_facpubs/137 · https://www.unm.edu/~lkravitz/Article%20folder/ACSMGuidelinesUNM.pdf
- Session structure (ACSM-derived handouts; secondary): https://brownhealth.org/sites/default/files/lifespan-files/documents/centers/cardiovascular-institute/components-of-exercise-op.pdf
- Gaming and exergame injuries: https://www.ncbi.nlm.nih.gov/pmc/articles/PMC12014968/ · https://mtprehabjournal.emnuvens.com.br/revista/article/download/1112/485/4831
- Google Play Health apps declaration and policy: https://support.google.com/googleplay/android-developer/answer/14738291 · https://support.google.com/googleplay/android-developer/answer/13996367
- ASCI enforcement on weight and health claims: https://indiantelevision.com/mam/60-of-61-nutraceutical-ads-breach-asci-code-report-finds/ · https://www.ascionline.in/wp-content/uploads/2022/09/asci_mar_apr_ccc_pr.pdf
