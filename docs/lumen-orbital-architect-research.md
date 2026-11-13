# LUMEN: Orbital Architect

> **Implementation note (2026-11-09):** a first playable version of the games in this document now ships in the app (v2). See [progress.md](progress.md) for what was built, what deliberately differs, and what is still open; rules live in [game-design.md](game-design.md#arcade-games-v2-2026-11-09).

Research and design proposal for Joynetic | 9 November 2026

**Status: proposal only. Await the owner's explicit instruction to start implementation.**
No game, recogniser, onboarding, calibration or phone installation changes are authorised by this document itself. The explore-first flow below belongs to the same proposed implementation, pending that instruction.

## The recommendation

Add one separate game: a body-controlled construction puzzle in which the player restores a damaged orbital garden. Reach to choose a conduit, gently lean to turn it, then complete a comfortable movement to bring the connected system to life. Energy flows through the player's design; windows illuminate, water returns and plants unfold. Each completed repair becomes a permanent part of their habitat.

The player makes decisions about a system, rather than following a stream of exercise commands. Movement operates tools in a meaningful game state. There is no advancing obstacle wall, chase, required jump, beat deadline or penalty for thinking.

Also let adults explore Joynetic before camera setup. Ask for movement preparation when they choose **Play**, retain the exact game/stage/pace they selected, and return them there after preparation. Browsing must never start the camera.

This concept was developed from the current implementation and external research. Existing future-game proposal documents were not opened or used as design inputs. The name is a working title, not a trademark-clearance claim. This is an original proposed combination, not a claim to have invented motion-controlled puzzles.

## Why this could add value

The current app provides runner stages with different worlds and missions. A restoration puzzle would give a different reason to open it: a quiet, deliberate movement break that produces something the player can revisit. It could appeal to adults who dislike reaction pressure or exercise repetition counters. That audience preference is a hypothesis to test, not established market demand.

| Current experience | Proposed addition | Why a player might care |
| --- | --- | --- |
| Progress along a runner route | Manipulate an energy network in a stationary diorama | Different decisions and a different pace |
| React to authored encounters | Choose which component to repair and how | Ownership of the solution |
| Stage completion and mission stars | A persistent, visibly restored habitat | A tangible reason to return |
| Camera preparation before normal browsing | Explore first; prepare at Play | Understand the value before moving the phone |
| Broad movement feedback | A clear tool preview and a specific consequence | Understand what a movement will do |

Active games already span music, sports and puzzles; Nex's official catalogue explicitly includes these categories. The opportunity is execution for our adult phone audience: forgiving body control, thoughtful construction, offline play and visible restoration. A new genre label alone will not win users. [Nex game catalogue](https://www.nexplayground.com/games).

I cannot honestly predict that people will uninstall competitors. The first proof should be that people understand this control scheme, enjoy the puzzle and voluntarily return after the novelty wears off.

## The world and the first playable experience

The setting is an abandoned ring habitat above Earth. Its engineering is advanced, but its spaces feel lived in: curved glass, warm interior light, seed trays, small repair drones and quiet machinery. Futuristic does not have to mean a dark room full of neon HUD elements.

The first destination is **First Light Conservatory**. It contains four small restoration puzzles in one continuous scene. The player restores a light circuit, a water pump, an air circulation unit and finally the conservatory canopy. These are four repairs within this one game, not four separate game proposals.

Tara can appear as the familiar guide. The controlled object is the selected construction tool and its conduit, not a runner character moving between lanes. Existing explorer cosmetics must not affect control accuracy or puzzle difficulty.

### A typical visit

1. From Home, inspect the habitat, movement guide and approximate visit length without camera permission.
2. Press **Play**. Complete only the missing preparation steps, then a brief real framing check.
3. Watch a short, skippable demonstration of one broken connection. Receive the objective in voice, text and a simple animation.
4. Select a conduit, turn it, observe the energy preview and revise the route. Thinking takes no game time and consumes no resource.
5. When the route connects correctly, complete the weld action. The repair is saved once, then the room changes visibly.
6. Rest with arms down between repairs. Continue, save and leave, or finish the visit.
7. See the changed conservatory and a factual movement recap. Choose the next restoration when ready.

Target a roughly 4–6 minute puzzle visit, plus the app's existing 75-second warm-up and 60-second cool-down when both are taken. Show those separately in the duration estimate; do not sell a six-minute total and quietly add preparation. Actual completion time depends on thinking and rests. No forced finish at a timer deadline.

### What makes the puzzle interesting

Each board has a source, receivers, fixed conduits and at most three editable conduits. The player sees the objective before acting. The first board teaches one corner; later boards require a short route through several corners. A later authored board may have two valid solutions, both earning the same completion reward.

The preview travels only as far as the current route allows. A broken join produces a gentle spark and outlines the disconnected ports. Testing and undoing are free. No oxygen countdown, lethal explosion, heart deduction or purchased retry is needed.

The first release uses only one energy type and one receiver per board. Multi-colour mixing, branching circuits and competitive modes are outside the initial scope. Depth should come from understandable topology before adding more rules.

## Exact controls and state rules

Use three large numbered tool cards linked to the editable conduits. The board is a readable display, not nine tiny hand targets. Selection zones are fitted to the player's comfortable reach envelope below shoulder height; the user does not have to physically reach toward the screen or walk around the room.

**Recommended first control scheme:** reach-select, lean-turn, shallow-squat weld. A no-squat option replaces only the weld action with a deliberate central reach-and-return. This is not a promise of seated or universal accessibility: both profiles still require tested standing framing and comfortable lateral control.

| State | Deliberate input | Outcome | Protection against accidental actions |
| --- | --- | --- | --- |
| Inspect | Wrist enters an enabled large selection zone, dwells, then returns to its neutral region | Select that numbered conduit; enter Edit | Visible wrist and torso required; ambiguous two-wrist input cancels selection |
| Edit | Existing recognised left/right lean, with neutral rearming | Rotate selected conduit one quarter-turn counterclockwise/clockwise | One step per completed activation; held lean does not spin it repeatedly |
| Edit | Fresh reach-select cycle | Change selected conduit | A hand already outside neutral cannot select another card |
| Route connected | All controls return to neutral | Show the distinct Ready to weld state | Suppress rotation/selection while changing state; announce the new action |
| Ready to weld | Fresh comfortable squat down-and-up cycle, or the explicitly selected no-squat reach cycle | Commit this valid repair once | Movement begun before Ready cannot commit; invalid routes cannot be welded |
| Restoration animation | Any movement | No construction action | No extra rewards or queued commands |
| Rest | Arms down; Continue by fresh selection after the rest prompt | Start the next board | No passive arm hold required |
| Tracking interrupted | Any uncertain movement | Freeze interaction and retain board state; show framing help | Discard incomplete gesture; require good tracking and neutral before rearming |

Provisional targeting values for a prototype are a 450 ms selection dwell and a 300 ms neutral rearm. These are **unvalidated interaction candidates**, not clinical guidance and not replacements for existing recogniser thresholds. Use elapsed landmark timestamps, not frame counts; long gaps invalidate a partial dwell. Final values require the tests in the validation section.

Left and right mean the player's visible mirrored directions. Prefer the same-side wrist for a side card to reduce cross-body occlusion. Permit left- or right-hand preference and enlarge targets inside the calibrated envelope. If three zones cannot be separated reliably within a comfortable envelope, offer two cards per page or block that control profile with an explanation; never ask for a painful wider reach.

There is no finger pinch, fist, palm-open, gaze or forward-depth push requirement. Pose landmarks are not a detailed hand controller. The app's current raise-arms recogniser requires wrists above the nose; it is **not** a suitable shortcut for the proposed below-shoulder selection gesture. A new, isolated reach-selection recogniser and reach capability calibration are required. [MediaPipe's official landmark specification](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker).

### A worked board, rather than just a theme

Coordinates are `(row, column)`, starting at zero. Directions name the ports a conduit connects.

```text
       column 0    column 1    column 2
row 0   empty      B: corner   C: corner
row 1   SOURCE ->  A: corner   D: fixed N-S
row 2   empty      empty       RECEIVER
```

The source emits east. The receiver accepts from north. Conduits are bidirectional. A corner's clockwise orientation order is `N-E`, `E-S`, `S-W`, `W-N`.

| Component | Initial ports | Correct ports | One solution |
| --- | --- | --- | --- |
| A at (1,1) | S-W | W-N | Select A; one clockwise turn |
| B at (0,1) | W-N | E-S | Select B; two clockwise turns |
| C at (0,2) | N-E | S-W | Select C; two clockwise turns |
| D at (1,2) | N-S, fixed | N-S | No edit |

The resulting route is `source → A → B → C → D → receiver`. One valid solution takes three selections, five turns and one weld. A failed connection simply leaves the board editable. The first tutorial is simpler than this example; it teaches one action at a time.

A roughly 60–90 second demonstration could show selecting A, watching the preview climb upward, discovering B's mismatch, completing B and C, then welding the connection and seeing the pump start. That is a demonstration target, not a completion deadline.

## What the body actually does, and what we can claim

This is proposed as **light movement and coordination play**. There is no trial of LUMEN because it has not been built. The evidence below supports design constraints and modest positioning; it does not validate this game as an exercise treatment.

| Movement | Plausible body involvement | Honest player-facing explanation | Important limit |
| --- | --- | --- | --- |
| Comfortable reach and return | Shoulder and elbow movement; shoulder/arm muscles position the limb | “Move your arms through a comfortable range to choose a tool.” | No measured strength, mobility or rehabilitation outcome for this game |
| Gentle lateral lean with feet planted | Lateral trunk movement and postural control | “Use a small comfortable lean to turn the conduit, then return to centre.” | Not a proven balance or fall-prevention programme; no deep side bend required |
| Shallow squat and return | Hip/knee movement; thigh and hip muscles contribute to lowering and rising | “A comfortable bend-and-rise finishes the repair.” | Four repairs mean only four weld repetitions; this is not sufficient evidence of strength training |
| Rest and reposition | Interrupts a period of stationary play | “Rest your arms whenever you need; your repair waits.” | Standing alone and occasional gestures must not be counted automatically as moderate exercise |

The anatomical descriptions are design interpretation, not muscle activation measurements. A camera skeleton cannot measure muscle recruitment, joint loading, calories, heart rate or training adaptation.

### Evidence and how it changes this design

| Source and type | What the source supports | Design consequence and boundary |
| --- | --- | --- |
| WHO adult activity guidance; public-health guideline | Regular activity matters; adults should accumulate at least 150 minutes of moderate activity weekly and major-muscle strengthening on at least two days | Encourage movement as part of a broader active life. Do not present one light puzzle visit as meeting those recommendations. [WHO guidance](https://www.who.int/initiatives/behealthy/physical-activity) |
| Dunstan et al., 2012; acute randomised crossover, 19 adults aged 45–65 with overweight/obesity | Two-minute light or moderate walking breaks every 20 minutes reduced post-meal glucose and insulin responses versus uninterrupted sitting in that experiment | A reason to investigate enjoyable sitting interruptions. Walking, dose and population differ from this game; no glucose or diabetes claim belongs in the product. [Original trial](https://pubmed.ncbi.nlm.nih.gov/22374636/) |
| Hansen et al., 2016; randomised crossover, 14 healthy young normal-weight adults | Two-minute walking breaks every 20 minutes during a 2.5-hour experiment did not change the measured post-meal glucose response | Include contrary evidence: a metabolic effect cannot be generalised to everyone. This paper has a linked correction, and we rely only on its broad reported finding. [Original study and correction link](https://pubmed.ncbi.nlm.nih.gov/27716865/) |
| NHS home strength exercise guidance | Mini-squats are described as slow, comfortable movements, with support available; progression is gradual | Keep bend depth comfortable and repetitions modest. A supported exercise illustration is not validation of camera-controlled unsupported squats. Users needing support can choose no-squat play; that option is not a medical adaptation. [NHS exercises](https://www.nhs.uk/live-well/exercise/strength-exercises/) |
| Repetitive upper-limb fatigue study, 2021; 40 healthy participants assigned to fatigue/control groups | Induced shoulder fatigue changed movement strategy during elevated-arm reaching, including trunk/shoulder compensation | Avoid sustained elevated-arm controls; require neutral returns and rests. Its fatiguing protocol and elevated targets differ from our proposed controls; it establishes no universally safe angle or time limit. [Original PLOS study](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0249403) |
| Teixeira et al., 2012; systematic review of 66 empirical studies | More autonomous motivation was generally associated with exercise participation; evidence included observational designs and predominantly Western samples | Offer choice, understandable mastery and forgiving retries. This is a design inference, not evidence that orbital restoration improves retention in India. [Review](https://pmc.ncbi.nlm.nih.gov/articles/PMC3441783/) |
| “Can Gaming Get You Fit?”, 2020; six-month randomised trial, 52 inactive adults | Access to a cycling exergame did not produce a significant between-group fitness improvement; use frequency was low despite reported enjoyment | Attractive art and enjoyment are insufficient. Test voluntary repeat use and actual movement, not just first-session ratings. Different hardware and exercise dose prevent direct prediction for us. [Original trial](https://pmc.ncbi.nlm.nih.gov/articles/PMC7468464/) |

Research was checked on 9 November 2026 using official guidance, original studies, an explicitly labelled evidence review, the official competing catalogue and official pose documentation. This is a focused product research pass, not a systematic literature review or clinical assessment. No single paper establishes the correct exercise dose for this game.

### Session load and comfort

For the first four-repair visit, target approximately 12–20 deliberate selections and 4 welds; turns vary with the puzzle and the player's revisions. These are interaction estimates, not prescribed exercise doses. Never force extra squats or reaches to fill a quota after a puzzle is solved.

Offer a 15–20 second arms-down rest between boards, extendable without limit. After repeated edits, suggest a rest instead of pushing the player to move faster. Track commanded actions and elapsed interaction time only; stillness can mean thinking, and tracking noise can mean poor lighting. Neither is a reliable fatigue diagnosis.

Keep feet on the floor. No jumping, backward stepping, single-leg holds, rapid twists, weights or long overhead reaches. A stable phone, clear floor and comfortable range remain necessary. Stop for pain, dizziness or feeling unwell; a health concern belongs with an appropriate professional, not a camera-generated diagnosis.

No-squat mode earns the same repair completion and cosmetic rewards. Its recap must show its actual movements. Do not advertise it as providing the same lower-body load. Seated control, one-arm control and broader mobility adaptations need separate validation before being labelled supported.

### Allowed product copy

- “Build a little. Move a little. Bring your garden back to life.”
- “Gentle movement and thoughtful puzzles. Rest whenever you need.”
- “This repair uses comfortable reaches, small leans and an optional shallow bend.”

Do not claim calorie burn, weight loss, corrected posture, cognitive improvement, stronger muscles, treated joint conditions or prevention of disease. Show the body guide as **movement involved**, not a heat map implying measured muscle activation.

## The premium feeling

### Before play: let the player want the place

The game card shows the actual conservatory state, a concise objective, movement involved and visit length. Tapping it opens a stage detail sheet with a small authored before/after illustration. This is a content preview, clearly distinct from a live camera or simulated pose feed. No fake game achievements are awarded for viewing it.

### During play: make control legible

Use a clean 2.5D cutaway room. Keep the puzzle central, three large tool cards low on screen, the objective at the top and the confidence guide away from the working route. The active conduit brightens and its number matches its tool card. Shape/number plus colour identifies components; colour alone is insufficient.

The hand-controlled cursor appears only when relevant landmarks are trustworthy. It snaps gently to an eligible large zone; a short ring shows the dwell. Do not smooth or animate it through tracking loss as if a real hand were still detected. Distinguish selection, rotation and weld with different short sounds. Provide captions and a mute path; voice must not be necessary to solve a board.

The most satisfying moment is the consequence: the completed energy route lights sequentially, a pump turns, water moves and a plant opens. Reduced-motion mode substitutes short fades and a static completed state. Effects never hide the next required action or camouflage tracking trouble.

### After play: preserve something meaningful

Restore the conservatory locally and visibly. Keep a small repair journal showing completed modules, without a daily decay mechanic. Missing a day never makes plants die or removes a repair. Replaying offers a different authored board variant or another valid route, not mandatory repetition to keep an object alive.

The recap separates puzzles restored, deliberate tool actions and interaction time. It must not call wall-clock thinking time “active exercise minutes.” Even interaction time is not a measured exercise intensity. Any broader health benefit needs separate evidence.

EN/HI/GU text and voice hooks belong in the first implementation. Use plain language, short text, readable icons and real small-phone layout checks. Have fluent speakers review the translations before release. Cultural familiarity should come through warm details and language, not assumptions that all Indian users share a festival or aesthetic preference.

## Explore first; prepare when Play is pressed

### What is wrong in the current implementation

`app/lib/app/router.dart` redirects ordinary routes through `nextOnboardingStep`: age, readiness, setup, calibration, then tutorial. Consequently, missing calibration prevents opening Home and other normal exploration destinations. Optional offline sign-in still leads into setup. The setup and calibration completion routes do not carry a selected stage back to the player. `QuestScreen._prepare` also redirects a missing profile to calibration without retaining the chosen level and gentle pace.

This is a routing and continuation problem, not a reason to create fake calibration defaults or remove the real preparation gate from gameplay.

### Proposed first-launch journey

```text
Welcome / language
        |
Confirm adult eligibility (18+)
        |
Home: explore games, stages, explorers, body guides and settings
        |
Play a chosen game/stage
        |
Access/unlock check -> missing readiness -> space/camera setup
        |
Missing or incompatible movement calibration -> required game tutorial
        |
Brief real framing check -> chosen game, stage and pace
```

After confirming age, offer **Explore games** as the primary action and **Prepare to play** as an optional action. Existing adults with a saved age confirmation go straight Home. Keep sign-in optional; do not make account creation a prerequisite for local play or exploration. Under-18 users retain the current eligibility block.

Home can show a small dismissible “Set up movement control when you're ready to play” note. Avoid a recurring full-screen reminder or an alarming red “incomplete” state. The Play action can say “Play · quick setup needed” when appropriate, with no unvalidated promise that everybody finishes setup in a specific number of seconds.

### What is available without calibration

Game catalogue, unlocked and locked stage descriptions, movement guides, existing local progress, explorer selection, language/accessibility settings and relevant crew/account screens can be explored. A locked stage may be inspected, but its Play action retains the actual progression and entitlement rules. Existing user progress must remain intact.

Camera permission is requested only when the player deliberately enters camera preparation or another explicit camera feature. Home, previews and settings browsing must not instantiate a native pose session. Previously granted camera permission does not justify starting the camera while browsing.

### The Play gate must remember intent

Retain a typed local intent containing known game ID, valid stage ID and allowlisted pace/control-profile values. For example, selecting a gentle runner stage must survive setup and tutorial as that exact stage with gentle pace. Selecting LUMEN must not fall into Forest Escape just because it was the previous tutorial destination.

Resolve the intent through a single preparation decision path, with equivalent validation at game entry. Apply it to Home, stage sheets, replay buttons and direct/deep links. Verify access again on final entry. Never accept arbitrary external return URLs, nested redirect strings or unknown game IDs. An intent is a navigation instruction, not proof of ownership or an unlocked stage.

Preserve the intent through the tutorial and its results screen, which currently returns to Home. A runner can retain its existing practice tutorial; LUMEN needs a short game-specific tool lesson. Completing one game's tutorial must not silently mark the other tutorial complete. A failed or cancelled tutorial does not set its completion flag.

Use explicit state for tutorial completion per game and calibration capabilities, with migration of the existing runner tutorial flag and profile. Keep the preparation logic small and concrete; do not create a generic workflow framework for two games.

### Missing calibration versus returning player

| Player state | Pressing Play should do |
| --- | --- |
| New adult, no readiness/setup/profile | Readiness, camera/space preparation, real calibration and relevant tutorial; then selected play intent |
| Existing runner profile and completed runner tutorial | Brief live framing/quality check, then selected runner stage |
| Existing runner profile, first LUMEN visit | Ask only for missing comfortable-reach capability plus its tool tutorial; preserve runner calibration |
| Partial/corrupt/incompatible stored profile | Explain what needs rechecking; run the missing preparation rather than crashing |
| Camera permission denied | Explain camera control, offer retry/settings as appropriate and Explore games; never trap them in setup |
| Calibration cancelled or framing cannot complete | Stop camera/voice, retain completed game progress and return to browsing; no fabricated completion flag |
| User deliberately selects Recalibrate from settings | Run calibration and return to its caller; do not auto-start an unrelated pending game |

Do not invent a fixed profile expiry date. A valid stored profile can be reused, with a brief framing check and a clear recalibration option if placement or comfortable range changes. The new reach capability must not force every existing runner player to redo everything.

The current calibration flow can fall back to gentle defaults after enough trustworthy in-frame time. That is not the same as skipping camera setup. Preserve that distinction; LUMEN's new reach targets require a measured usable envelope or a separately validated fallback. Do not assume the existing squat/lean defaults prove that three reachable hand zones exist.

### Leaving preparation must be safe and ordinary

Every preparation screen needs Back and an **Explore games** exit. Cancelling stops the native session, preview, voice and countdown, cancels timers/delayed callbacks and prevents late navigation or writes. Setup's hands-free countdown should still work after deliberate entry into preparation; it must never start from a Home preview.

Review the delayed calibration fallback voice callback for lifecycle safety when adding exits. Clear or explicitly suspend the pending Play intent when exiting so a later settings visit cannot unexpectedly launch a game. If the process dies during preparation, return safely to browsing and offer to resume the selected play intent after revalidation; never resume directly into a live camera game in the background.

Gym QR joining must retain its pending code across age confirmation and optional sign-in without requiring fitness calibration merely to view/join a crew. It must not consume or overwrite a pending game selection accidentally.

## Implementation fit and boundaries, after approval

Reuse native CameraX/MediaPipe, the quality/framing gate, landmark filtering, the local settings store and the established Flame rendering approach. MediaPipe provides the wrist, elbow, shoulder, hip and leg landmarks needed to prototype the proposed controls. That establishes available inputs, not production targeting accuracy. [Official pose documentation](https://developers.google.com/edge/mediapipe/solutions/vision/pose_landmarker).

Keep frames native and ephemeral, process only the latest frame, and pass only the existing landmark contract to Dart. No segmentation masks, video recordings, uploaded frames or cloud decision service are required. No new Android permission is justified by this concept.

Add a small pure-Dart puzzle state/controller alongside the director's existing code and a separate game view in the app. Do not force the board into runner lanes or pretend the current runner encounter schema already describes it. Extend the content contract deliberately for this game and keep the existing runner loader compatible. Authored levels, tutorial instructions, dwell candidates, rests and variants belong in validated configuration; render components display state rather than deciding puzzle rules.

Reach selection is the one new motion capability. Implement tests before its production code. Reuse existing squat and lean recognisers unchanged unless recorded-data tests justify a separately reviewed change. Do not globally lower thresholds to make a prototype seem responsive.

### Illustrative content contract — not an existing supported level

```json
{
  "schemaVersion": 1,
  "game": "orbitalArchitect",
  "id": "lumen-first-light-01",
  "board": {
    "rows": 3,
    "columns": 3,
    "source": {"cell": [1, 0], "output": "E"},
    "receiver": {"cell": [2, 2], "input": "N"},
    "conduits": [
      {"id": "A", "cell": [1, 1], "ports": ["S", "W"], "editable": true},
      {"id": "B", "cell": [0, 1], "ports": ["W", "N"], "editable": true},
      {"id": "C", "cell": [0, 2], "ports": ["N", "E"], "editable": true},
      {"id": "D", "cell": [1, 2], "ports": ["N", "S"], "editable": false}
    ]
  },
  "controls": {"selectionDwellMs": 450, "neutralRearmMs": 300},
  "restAfterRepairSeconds": 20,
  "reward": {"restoreModule": "conservatory-water"}
}
```

Schema validation must reject invalid cells, duplicate occupied cells/IDs, unsupported port pairs, missing endpoints, more editable components than control slots, impossible timing values and unknown rewards. Semantic validation must confirm a reachable solution, reciprocal ports and a route without a cycle. Reject invalid content before gameplay rather than guessing a correction on the phone.

Use authored variants and stable IDs initially. The same level, control profile and timestamped valid inputs must produce the same actions, route and reward. Restoration commits are idempotent; repeating a weld callback, replaying a board or resuming a checkpoint cannot duplicate rewards. Persist completed repairs and a versioned current board at discrete edits, never every frame. Corrupt drafts may be discarded with an explanation while retaining completed repairs.

Thinking, user pause, lifecycle pause and tracking interruption are separate states. Tracking interruption preserves every completed edit and cancels an incomplete gesture. Recovery never rewinds a restored module, consumes a life or fast-forwards through queued movement. When tracking returns, explain and rearm from neutral before accepting new input.

Start with original vector/code art, limited particles and cached scene layers. Graceful effects reduction must preserve tool feedback and the finished habitat. Target the current supported device tiers; measure sustained frame times, thermal behaviour and pose-to-feedback latency on real devices before promising performance. The renderer must not create a frame queue or block the native analysis loop.

## Prototype proof and release criteria

The biggest uncertainty is whether comfortable hand targeting feels dependable at the existing phone distance. Solve that before spending heavily on habitat art. A beautiful scene with unreliable controls would make the app worse.

### Automated verification

- Motion tests first: visible/occluded wrists, mirror directions, jitter at zone boundaries, two hands moving, neutral returns, insufficient reach envelope, missing frames, stale timestamps, cancellation mid-dwell and recovery. Existing recogniser replay gates must still pass unchanged.
- Director tests: the worked solution, wrong joins, every quarter-turn, cycles, solver termination, deterministic replay, state-specific input rejection, no double weld/reward, save/resume compatibility and tracking forgiveness.
- Content checks: new schema and semantic validation, canonical/bundled consistency and unchanged validation of all existing runner content.
- Router/widget tests: fresh install can browse with null calibration and zero pose-session starts; every gameplay entry is guarded; stage and gentle pace survive preparation; under-18 block; camera denial; Back/Explore from every step; lifecycle cancellation; QR continuation; independent tutorial flags and legacy profile migration.
- UI checks: small displays, large text, EN/HI/GU, mute, reduced motion, colour-independent ports, long instructions and no overlays hiding the working board.

### Human and device pilot

Recruit a small formative group of 8–12 consenting adults, with varied heights, handedness, clothing and phone tiers, including people who do not already enjoy runners. This is usability work, not a powered health study. No camera frames are stored. Use consented timestamped landmarks only where needed for replay work, with explicit recording consent and deletion controls; ordinary play requires no recording.

Compare two counterbalanced short sessions: the existing runner and the new puzzle. Ask participants to explain the tool actions before coaching them. Record intentional selection success, accidental actions, recovery time, discomfort reports, assisted explanations and whether they choose to play another repair. Include varied lighting and camera placement; do not attribute poor results to “the user doing it wrong.”

Proposed engineering acceptance targets, to be confirmed during the prototype:

| Gate | Initial target | If it fails |
| --- | --- | --- |
| Intentional selection | At least 95% accepted correctly on first attempt, reported per participant/device condition | Enlarge/reduce zones or simplify input; do not hide low-performing groups in the average |
| Accidental edits | No more than one per five-minute play visit | Fix state gating and neutral rearming before adding content |
| Tracking interruption | Zero lost edits, repairs or rewards across interruption tests | Release blocker |
| Discoverability | At least 8 of 10 participants can complete the introductory repair after its in-app lesson without researcher coaching | Rewrite lesson or simplify controls |
| Comfort | No participant is pushed to continue through discomfort; repeated discomfort with a required input triggers redesign | Remove/rework that input; no claim of universal safety from a small pilot |
| Responsiveness | Target p95 rotation feedback within 200 ms after a recognised event; show selection dwell separately | Instrument and optimise; do not pretend a deliberate 450 ms dwell is zero-latency input |

Log these locally for the pilot or collect them under existing consented analytics; do not add camera or body-data uploads as a side effect. Report small-sample counts and failures, not false statistical certainty.

Then run a longer voluntary-use pilot over at least two weeks. Measure repeat sessions and chosen next repairs, alongside comparable runner use, rather than making a retention promise from a single enjoyable demo. Health or fitness efficacy would require a separate appropriately designed study; it is not a release claim for this game.

I can automate logic, replay, UI, build, installation and runtime checks on the connected phone. I cannot independently supply a real moving human, reposition the phone physically or validate perceived comfort. Synthetic fixtures are test evidence, not proof of live movement quality. Physical-control and comfort sign-off require consenting participants.

## Bounded delivery sequence after “start implementing”

1. **Explore-first flow:** route separation, typed continuation, safe exits, denied-permission handling and regression tests. This provides useful UX improvement independently of the new game.
2. **Control proof:** comfortable reach capability, test-first targeting recogniser and one plain board driven by real landmarks. Test on the connected phone with a participant before expanding the art scope.
3. **One complete game visit:** four authored repair boards, deterministic controller, validated content, game-specific tutorial, rest/save/recap and no-squat weld option.
4. **Visual and release pass:** original conservatory art/audio, persistent restoration, EN/HI/GU review, accessibility and device-tier testing. Record stable approved decisions in architecture, security and game-design docs as appropriate.

Do not begin with procedural endless content, online multiplayer, leaderboards, extra sensors, AI-generated workout prescriptions or a large virtual economy. No additional dependency or network service is assumed. Existing paid-access rules must remain intact; any future purchase flow stays within Google Play policy and the project's rules.

The first approval should authorise this bounded vertical slice and the exploration flow. If targeting fails its prototype gates, revise the controls before treating the whole concept as production-ready. There is no honest fixed delivery estimate before that uncertainty is measured.

**Decision requested after review:** say **“start implementing”** to begin. Until then, this file is a researched proposal and the running app remains unchanged.
