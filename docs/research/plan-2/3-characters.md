# 3 — Characters, avatar/AR costumes, animation pipeline (research + design notes)

Status: research notes only, repo not edited. `docs/new-games-plan.md` does not exist; the cast below is
mapped to roles (rhythm/dance, pad-boxing, runner/race, balance/cooldown) so it can attach to whichever three
new games are chosen. Existing facts: Kavi is "an original fox-orange runner's guide" (`docs/game-design.md`
§AI coach); lines live in `app/lib/l10n/coach_strings.dart` (en/hi/gu); current Hindi lines use masculine first
person ("मैं सुझाव दूँगा"). App assets today = 320 KB. Deps: flame 1.38, no Rive/Lottie/Spine.

## A. What research says makes companions work (with caveats)
1. **Story and characters drive longer sessions.** Interviews with 30 *Zombies, Run!* users found narrative/characters were the
   favourite feature and made sessions longer and use longer-term (qualitative, small n) — Faric et al., Games for Health J. 2021:
   https://discovery.ucl.ac.uk/id/eprint/10139156/ . Trial protocol NCT02341235 reports "high levels of parasocial interaction
   with the two main NPCs": https://cdn.clinicaltrials.gov/large-docs/35/NCT02341235/Prot_SAP_000.pdf
   → Give each game one named voice that talks *to "you"*, in short barks, not cutscenes.
2. **Second-person voice draws in less-active people** (Lyons, UTMB): https://chairsearches.utmb.edu/newsroom/article8962.aspx
3. **Companion turns exercise into game verbs.** Ring Fit's Ring is a chatty partner and its moves become attacks
   (review: https://news.yahoo.com/ring-fit-adventure-review-nintendo-113006617.html ; design analysis:
   https://ceeol.com/search/article-detail?id=1009100 ). → Our rule 6 already fits: the companion reacts to *game outcomes*, not raw reps.
4. **Guilt-trip mascots backfire for some users.** Duo's evolution into a passive-aggressive streak nag is credited with engagement,
   but users report streak anxiety / "letting Duo down"; Duolingo added Streak Freeze. Sources are weak (blogs):
   https://desirabilitylab.com/backfill/backfill-2025-46-duolingo-streak-design ,
   https://mojo.iimu.ac.in/2026/meet-the-loveable-language-learners-unlocking-the-secret-to-duolingos-success.html
   (the "J. Educational Computing Research" claim there could not be verified — do not cite it).
   → **Rule for our cast: warm teasing about the game, never guilt, never about the body, never streak shame.** Matches AGENTS rule 5
   and the no-medical/no-weight-claims rule.
5. Design takeaways (synthesis, not sourced): one strong silhouette + one colour per character; 3–5 expressions beat many frames;
   personality shown through *reaction timing* (cheer within 200 ms of a game outcome); recurring catchphrase per character;
   characters remember things (best score, favourite world) from local run summaries — cheap "relationship" with no cloud.

## B. Animation pipeline for Flutter/Flame, small install, budget phones
| Option | Install cost | Runtime cost | Fit |
|---|---|---|---|
| **Cut-out rig in Flame** (layered PNG/WebP parts + `Effect`s/`EffectController` tweens, data in JSON) | ~0 new code; ~80–200 KB per character atlas | Very low: a few sprites + transforms | **Recommended default** for all characters in-run and in menus |
| **Sprite sheets** (`SpriteAnimation` + `flame_texturepacker`, multi-page, load groups on demand: https://pub.dev/documentation/flame_texturepacker/latest/) | 0 new native code; PNG/WebP on disk | Flutter decodes to RGBA: 2048² atlas ≈ 16 MB RAM (cf. https://forum.unity.com/threads/sprite-atlas-etc2-fallback.723944/) | FX (sparks, aura loops, trails), short bursts; keep atlases ≤1024² |
| **Rive** (`rive`/`rive_native`, `flame_rive`: https://pub-web-s1.flutter-io.cn/packages/flame_rive) | Native `.so` per ABI; one dev reports APK bloat of ~80 MB attributed to Rive (https://itnext.io/how-i-drastically-reduced-my-flutter-app-size-by-80mb-with-just-one-line-of-code-967ba19cef98); Rive lists `librive-android.so` + C++ stdlib and size-reduction flags (https://rive.app/docs/runtimes/runtime-sizes.md — host blocked here, not read in full) | Fast GPU renderer; state machines + inputs; .riv files tiny (vendor claims 10–15x smaller than Lottie: https://rive.app/blog/rive-as-a-lottie-alternative) | Best tool for an *interactive* coach portrait (idle/cheer/think + lip-flap) — adopt only if `flutter build appbundle --analyze-size` shows acceptable per-ABI delta (target ≤3 MB) |
| **Lottie** | Pure Dart pkg, small | JSON parse at load, CPU-heavy for complex files; no state machines (https://www.tillitsdone.com/blogs/rive-vs-lottie--flutter-animations) | Only for 1–2 UI flourishes (results screen confetti); not in-run |
| **Spine** (`flame_spine` is still 0.4.0-dev: https://pub.dev/packages/flame_spine/versions/0.4.0-dev.0+7/install ; spine-flutter on spine-c FFI: https://www.esotericsoftware.com/spine-flutter ) | Native lib + paid Spine editor licence (runtime use requires a licence — verify terms) | Good; prefer binary `.skel`, share skeleton data across instances | Overkill for us; skip unless an animator insists |

**Decision proposal:** cut-out rigs for characters (deterministic, data-driven, no deps), sprite sheets for FX, Lottie/Rive
deferred. Measure on the budget reference phone with the camera + pose running (pose already eats GPU/CPU): character layer
budget ≤2 ms/frame, ≤12 MB texture RAM total at any time, unload per-world assets between runs.
Use WebP (lossless or q≈90) for atlases; `flutter build appbundle` + Play splits by ABI/density.

## C. Coach Kavi, refined
- **Who:** an original anthropomorphic **Bengal fox** (Indian native species; big ears, black-tipped tail, slim legs) — keeps the existing
  "fox-orange" identity and is distinct from other fox mascots. Wears a sleeveless teal running vest with a single white stripe,
  wristbands, no logos. Silhouette: ears + tail S-curve. *(If the team meant "fox-orange" as colour only, the same palette works on a
  human coach; flag for product owner.)*
- **Palette:** fox orange `#E8742A`, cream `#F6E7D0`, ink `#2B2230`, vest teal `#1E8C8A`, accent marigold `#F5B700`.
- **Personality:** calm senior teammate, dry humour, notices effort and smart play; never a drill sergeant. Catchphrase: "Chalo, ek aur!"
  (EN: "One more go?") — game-invitation, not a demand. Celebrates choices (taking assist mode, low-impact) as *smart*.
- **Voice rules (all languages):** ≤8 words per bark; second person; game verbs only (gate, pad, beat, gem, rival); never body,
  weight, calories, "burn", "tone", pain, health; tracking problems are *Kavi's/the camera's* fault ("I lost you — step back a bit");
  respectful **आप** register in Hindi, **તમે** in Gujarati; Hinglish allowed only in EN-UI mode as flavour; native-speaker review.
- **Gender/grammar:** Hindi first-person verbs gender the speaker (दूँगा/दूँगी). Either fix Kavi as he (current strings) or ship a
  Kavi-voice setting; for addressing the *player*, prefer imperative/present forms that are gender-neutral in आप
  ("चलिए!", "बहुत बढ़िया!") and avoid gendered past tense ("आप जीत गए/गईं") unless the player set pronouns.
- **Line style examples:** start "Ready? Squat through the first gate." / "तैयार? पहले गेट पर स्क्वॉट कीजिए।" / "તૈયાર? પહેલા ગેટ પર સ્ક્વોટ કરો."
  Good play "Clean line! Keep that rhythm." / "शानदार! यही लय रखिए।" / "સરસ! આ જ લય રાખો."
  Tracking "I can't see your feet — step back." / "पैर नहीं दिख रहे — थोड़ा पीछे हटिए।" / "પગ દેખાતા નથી — થોડા પાછળ જાઓ."
  Rest "Nice run. Shall we try a lighter one next?" (offer, never instruct).
- **Expressions (6):** neutral, smile, big cheer, thinking (paw to chin), pointing, concerned-kind (for tracking loss).

## D. Companion & rival cast (original; Indian fauna; no deities' vahanas or sacred animals)
Avoid as characters: cow, elephant (Ganesha), monkey (Hanuman), peacock (Krishna/Kartikeya), cobra/naga, owl (Lakshmi), swan,
tiger-with-rider, any halo, third eye, tilak, om/swastika/crescent/cross, temple bells as "power-ups". Also avoid Bholu (Indian
Railways elephant) and Shera (CWG tiger) look-alikes.

| Name | What | Role / game slot | Look & palette | Personality / catchphrase |
|---|---|---|---|---|
| **Mithu** | Rose-ringed parakeet | MC/DJ of the rhythm/dance game; calls beats, combo hype | Leaf green `#3DAA4A`, red beak `#D7263D`, pink-black neck ring, oversized headphones | Loud, joyful, puns on beats; "Beat pakdo!" ("Catch the beat!") |
| **Golu** | Young Indian one-horned rhino | Pad-holder trainer in the boxing/pad game; holds the punch pads | Slate grey `#7A8490`, warm pink ears, red pads `#E63946` with white rims, sweatband | Gentle giant, proud of your aim, over-dramatic "oof!" when hit; "Ek, do — combo!" |
| **Neela** | Smooth-coated otter | Balance/cool-down host; slow breathing and stretch segments; low-impact champion | River teal `#2A9D8F`, sand belly `#E9C46A`, flower-print towel | Unhurried, kind, quiet jokes; "Aaraam se." ("Easy does it.") |
| **Chikki** | Indian palm squirrel | **Rival** racer: animates your own best-run ghost and taunts the *race*, never you | Tawny `#B5835A`, three cream back stripes, tiny goggles, scarf `#F4A261` | Cheeky, competitive, a good loser who gives a high-five; "Pakad sako toh pakdo!" ("Catch me if you can!") |
| **Baadal** | Mischievous monsoon cloud creature (not a spirit/god) | **Boss / prankster rival**: steals the sun, rains obstacles; reformed after the world boss | Storm blue `#4A5A8C` to lilac `#9D8DF1`, puffy, two lightning-shaped eyebrows | Theatrical, sulky, secretly lonely; "Garaj garaj!" |
| **Jugnu** | Firefly sprite helper | Tracking-help companion across all games: glows where the camera loses you, lights a framing outline; turns rule 5 into a character | Glow yellow `#FFE45E`, tiny | Says almost nothing; chirps + points; text hints carry meaning |

Relationship hooks (local only): Mithu remembers your best combo, Chikki's ghost improves when you beat it, Golu keeps a "pad wall"
of your best accuracy, Baadal sends a sheepish postcard after defeat. All driven by local run summaries + JSON content, no cloud.

## E. Player avatar & AR costume system
**Avatar (in the 2.5D world, and on share cards):**
- Built from independent pickers — no "male/female" gate: body shape (5 presets: slim, average, broad, curvy, larger), height (3),
  skin tone (10 swatches spanning very light to very deep, inspired by the open Monk Skin Tone scale), hair (12 styles incl. buzz,
  braid, bun, curls, long straight, bald), facial hair (optional), outfit sets (athleisure, kurta-style top + joggers, salwar-style
  joggers, tee + shorts, full-sleeve modest set), shoe colour.
- Optional pronoun setting (he/she/they/none) only changes grammar of a few Hindi/Gujarati lines; default "none" (neutral forms).
- Player-chosen headwear may include respectful sport headwear (e.g., sports hijab, patka) as *inclusion options*; never as costume
  items, never on NPCs, never as unlockables/joke items — confirm with cultural reviewers.
- No body-changing rewards (no "slimmer avatar after X runs"). Body shape is cosmetic and never tied to progress.

**AR costume over self-view (body-anchored, landmark-only):**
- Pose Landmarker gives 33 points (no face mesh), so anchor to: head = nose (0) + ears (7/8) → hats, crowns-of-leaves, headphones;
  shoulders (11/12) → capes, back aura, shoulder pads; wrists (15/16) → glove glows + motion trails; hips (23/24) → belt glow;
  ankles (27/28) → footstep sparks.
- Scale every item by shoulder width; rotate by ear/shoulder line; smooth with the existing One Euro filter; fade out (not snap) when
  landmark visibility < threshold; mirror for selfie preview.
- Draw in Flutter/Flame over the native preview texture — only landmarks cross into Dart (rule 4); never compose a camera frame +
  costume into an image; **no photo/video capture of self-view** (rule 2). Sharing uses the avatar-only card.
- Keep the face visible: no masks over eyes/mouth; hats sit above the ear line, auras behind the body.
- Item types (all original): 6 hats (marigold-leaf band, kite cap, star headband, cloud puff from Baadal, Mithu headphones, Kavi ears),
  4 auras (sunrise, monsoon, firefly ring, rangoli-geometry halo-free ring behind shoulders — *not* a halo above the head),
  5 trails (ribbon, sparkle, kite string, rain drops, diya-free ember), 3 footstep FX. Unlock via play, never pay-only nudges.

## F. Asset list and size budget (install, compressed WebP/OGG)
| Asset | Spec | Est. size |
|---|---|---|
| Kavi cut-out rig: ~18 parts + 6 expression heads | 1 atlas 1024² | 250 KB |
| 5 companions/rivals rigs (Mithu, Golu, Neela, Chikki, Baadal) | 1 atlas 512–1024² each | 5 × 150 KB = 750 KB |
| Jugnu + UI glow | 256² sheet | 30 KB |
| Rig animation data (JSON keyframes: idle, cheer, point, think, react-hit, react-miss, wave) | per character | 7 × 15 KB ≈ 100 KB |
| Avatar parts: 5 bodies × 3 heights as scalable parts, 12 hair, 5 outfits × 4 colourways, faces | 2–3 atlases 1024², palette-swapped skin via shader/tint (no per-tone art) | 700 KB |
| AR costume items (18) + FX sheets (trails/sparks) | 2 atlases 1024² | 400 KB |
| Portraits for menus/dialogs (7 characters × 2 sizes) | 512² | 400 KB |
| VO barks: ~40 lines × 3 langs × 7 chars max (Opus/OGG ~32 kbps, ~1.5 s) — or non-verbal chirps + text | ~6 KB each | 1.5–2.5 MB (or ~300 KB chirps only) |
| **Total character budget** | | **≈ 3–5 MB**, keep total app assets under ~10 MB |
Runtime RAM ceiling for character/costume textures: ≤12 MB resident (each 1024² atlas ≈ 4 MB decoded).

## G. Art production plan and freelancer briefs
Phases (≈8–10 weeks, parallel where possible):
1. **Wk 1–2 Character design** (1 illustrator): silhouettes → 3 options per character → pick → turnaround + 6-expression sheet + palette.
   Cultural/sensitivity review (2 native reviewers: Hindi, Gujarati; plus one inclusion reviewer) before lock.
2. **Wk 3–5 Rig parts + animation** (1 2D game animator): cut-out parts exported to atlas (TexturePacker or free equivalent),
   keyframes as JSON matching a small schema we define (`content/schema/character.schema.json` — validate like levels, rule 7).
3. **Wk 3–6 Avatar & costume kit** (illustrator #2): modular avatar parts, skin via tint mask, 18 costume items with anchor points
   documented per landmark.
4. **Wk 5–7 VO** (3 voice actors per language or 1 multilingual per character; studio or remote): record barks; deliver 48 kHz WAV
   masters + OGG. Optional: non-verbal chirps first, full VO later.
5. **Wk 7–8 Integration + device test** on budget phone; size gate in CI (`--analyze-size`), texture RAM check.

Brief template (every freelancer):
- Deliverables, formats (layered PSD/Krita/Affinity source, PNG @2x, atlas + JSON), naming, colour tokens above.
- **Original work only**: no tracing/referencing existing mascots (Duo, Ring, Pokémon, Sonic, IPL/team mascots, Bholu, Shera); provide
  sketches/process files as provenance; disclose any AI tools (recommend none for final art) — supports AGENTS rule 10.
- Full IP assignment / work-for-hire, moral-rights waiver where allowed, model releases for voice actors, perpetual worldwide licence.
- Content rules: no religious symbols or deity references, no flags/real teams/brands, no body-shaming or weight humour, no medical
  claims, adults 18+ tone but family-safe; diverse body/skin representation in key art.
- Technical limits: max atlas 1024², ≤ part counts above, transparent padding 2 px, pivot points marked, 60 fps-safe (≤24 keyed fps OK).
- Acceptance: review rounds (2), sensitivity sign-off, on-device check.

Rough budget (India freelance rates vary widely; assumption, not researched): design ₹1.5–3 L, animation ₹1.5–3 L, avatar/costume
₹1–2 L, VO ₹0.5–1.5 L.

## Open questions for the product owner
1. Is Kavi a fox character or a human coach with a fox-orange brand colour? (Notes assume Bengal fox.)
2. Fix Kavi's Hindi grammatical gender, or offer a voice setting?
3. Accept Rive's native lib size for an interactive coach portrait, or stay deps-free with cut-out rigs?
4. Inclusion headwear options: approve with reviewers?
