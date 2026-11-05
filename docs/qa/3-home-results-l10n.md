# QA 3 — Home, Results, Stage info, Coach, l10n (review only, no code changed)

Date: 2026-11-05. Method: static review + throwaway scripts
(`/tmp/claude-0/-home-user-Gym-by-fun/fc067a71-4314-57a0-b0b3-5304bfb87adc/scratchpad/l10n.py`, `l10n2.py`)
that extract literals in `Text(...)`/`tr(...)` from `app/lib/screens` + `app/lib/widgets`
(excluding debug/recorder) and from `game/stages.dart`, and diff against the `_t` keys in `app/lib/l10n/tr.dart` (186 keys).

## Q3-1 — High — l10n/tr.dart (missing entries) + several screens
Visible English strings with no hi/gu entry (fall back to English, or are not wrapped in `tr()` at all):
- **Stage content (game/stages.dart, shown via `tr(st.title)`, `tr(st.description)`, `tr(stage.worldName)`) — none translated:** all 18 titles (Forest Escape, River Crossing, Guardian Grove, Firefly Trail, Garba Quest, Monsoon Meadow, Desert Dunes, Sandstorm Temple, Oasis Caravan, Mirage Maze, Neon City Rooftops, Neon City Chase, Neon Night Market, Skyline Finale, Mountain Trail, Summit Storm, Glacier Pass, Sunrise Summit), all 18 descriptions, world names (Forest Awakening, Desert Trials, Neon City, Mountain Expedition, Stadium Nights, Ancient Temple, Shadow Arena, Cosmic Journey, Final Guardian).
- home_screen.dart: `tr('Warm-up')`, `tr('Cool-down')` (:91-92; tr.dart only has the old combined key 'Warm-up · Forest Escape · Cool-down'), 'Finish the previous stage to unlock' (:267); not wrapped: `'${gym['name']} crew'` (:146), "See this week's crew board" (:155), 'Trainer quest: …' (:156), world.name `Text(world.name)` (:223, :236 — no tr()).
- results_screen.dart: pain areas 'Knees/Back/Hips/Shoulders/Neck/Ankles/Other' (:149, built by capitalising ids), pain dialog body 'We review every report within a week. Stop if it hurts, rest, and if pain continues please see a doctor. Low-impact mode keeps moves gentler.' (:172), 'OK' (:177), '${r.forgiven} obstacle(s) were skipped because tracking dropped — no hearts lost.' (:246).
- stage_info_sheet.dart: 'Regular muscle-strengthening and aerobic activity is part of general fitness guidance from:' (:117, wrapped in tr() but no key).
- settings_screen.dart (plain `Text`, no tr()): Difficulty, Beginner, Medium, Advanced, Needs a connection and sign-in, Low-impact mode, Half squats count, one arm is enough, no jumps., Assist mode, More warning time and wider timing windows., Language, Back up calibration, Store your movement range on our server for a new phone. Off by default., Anonymous analytics, Crash and usage counts to improve the game., Your data was copied to the clipboard., Delete your account?, Your progress, gym membership and any backups are removed. This cannot be undone., Cancel, Delete, Grievances and data requests: grievance@motionquest.app — we respond within 30 days.
- crew_screen.dart (plain `Text`): "This week's board — effort, not raw reps, so everyone can compete." (:132), "Your first name, sessions and effort points appear on the crew board and the owner's weekly report. Never body measurements. You can turn this off any time." (:112).
- Fix: add hi/gu entries (native review) and wrap the plain `Text` literals in `tr()`; use interpolation-safe keys for the crew/forgiven/pain strings. Add a unit test that every `Stage.title/description/worldName` has a `_t` key.

## Q3-2 — Medium — app/lib/screens/results_screen.dart:214
Headline is always 'You escaped the forest!' for every completed stage, including desert, neon and mountain stages. Fix: per-world/neutral copy (e.g. 'Stage complete!' or a per-theme line from Stage).

## Q3-3 — High (when PAYMENTS=true) — app/lib/game/stages.dart:242-259 + stage_info.dart
Unlocking is strictly linear over `stages`; all of World 1 is free and every w2+ stage is premium. `isUnlocked` ignores tier, so a free player's progression dead-ends at the first premium stage; `nextStage(premiumLocked: true)` then skips every remaining stage and falls back to `stages.first` — the Daily Quest silently replays Forest Escape forever with no explanation. Fix: when premiumLocked and no free stage remains, surface "All free stages done" / paywall moment `lockedWorld` instead of replaying stage 1; add a test.

## Q3-4 — Medium — app/lib/screens/home_screen.dart:248-276
Home stage tiles do not show a Premium/lock state; a premium stage looks "open" (play icon, chevron) and only the info sheet's disabled button reveals it is locked. Fix: pass premium state into `_WorldCard` and show the premium icon/badge when `paymentsEnabled && info.premium && !premium.premium`.

## Q3-5 — Medium — app/lib/screens/home_screen.dart:114-124
Stats mismatch when offline/signed out: Streak shows '–' but Shields shows a hardcoded `2` and Hero level `1`, presenting fake values as real progress. Fix: use '–' for all three when `progress == null`.

## Q3-6 — Low — app/lib/screens/home_screen.dart:128-139
Premium chip text: any non-'gym' source ('play', 'promo') shows plain 'Premium'; fine, but `activeUntil` is never checked client-side, so a stale cached `premium:true` (e.g. expired promo, server returns premium with past activeUntil) still shows the badge. Fix: treat `activeUntil` in the past as not premium in `PremiumState.fromJson`.

## Q3-7 — Medium — app/lib/screens/results_screen.dart:81-123
Effort rating can be lost: the run is saved on first frame without effort; effort is only re-saved when the user taps "Done". Leaving via system back / app kill after choosing effort drops it from both coach history and the upload queue. Fix: call `_persist(flush: false)` inside `onSelectionChanged` (record() and queue add are both idempotent by clientId).

## Q3-8 — Low — app/lib/screens/results_screen.dart:184-193
`_applyCoach` also silently turns on low-impact (`suggestLowImpact`) while the button only says "Try <level>" / "Try assist". Coach.difficultyAdvice sets suggestLowImpact on any failed/hard run, so the user's settings change beyond what they agreed to. Fix: only apply what the button names, or mention low-impact in the button/reason text.

## Q3-9 — Low — app/lib/services/session_queue.dart:183-190
On a non-retryable 4xx the batch is dropped but still counted in `synced` (returned to callers as "synced"). Also any non-Socket/non-ApiException (e.g. TimeoutException, HandshakeException) escapes `flush()`; homeDataProvider then returns null and hides gym/progress for that load. Fix: count only successful uploads; catch TimeoutException/IOException as retryable.

## Q3-10 — Low — app/lib/screens/home_screen.dart:57-60 vs stage_info_sheet.dart:36,50
Daily Quest button bypasses the stage info sheet and the premium lock (pushes `/quest?level=` directly). Currently safe because `nextStage(premiumLocked:)` filters premium, but the two lock rules are computed separately; keep one helper (e.g. `isPlayable(stage, premium)`) to avoid drift.

## Verification
- Re-run `python3 -I /tmp/claude-0/-home-user-Gym-by-fun/fc067a71-4314-57a0-b0b3-5304bfb87adc/scratchpad/l10n.py` after fixes; expect only interpolation/number literals.
- Switch language to Hindi, open Home and a stage sheet: stage titles/descriptions currently remain English.
