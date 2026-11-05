# QA pass 1: onboarding, sign-in, settings, crew

Scope: `onboarding_screens.dart`, `setup_screen.dart`, `calibration_screen.dart`, `sign_in_screen.dart`,
`settings_screen.dart`, `crew_screen.dart`, `app/router.dart`, `services/settings.dart`, `local_data.dart`,
`api_client.dart`. This was a review only; no app code was changed. Line numbers refer to `app/lib/...`.
One throwaway widget test (`app/test/_qa1_test.dart`, now deleted) confirmed Q1-1: after a tap, the
"Anonymous analytics" switch still reads `false`.

All `tr('...')` literals in scope have an entry in `l10n/tr.dart`. The untranslated text comes from
plain string literals that never go through `tr()` (Q1-4).

---

### Q1-1: Consent switches are hardcoded off, so a consent can never be shown or withdrawn (High)
- **File:** `screens/settings_screen.dart:151` and `:158` (`value: false`)
- **Repro:** Sign in. Open Settings, then tap "Back up calibration" or "Anonymous analytics".
- **Expected:** The switch moves to On and stays On after a successful call. Reopening Settings shows the
  saved consent, and the player can turn it Off again.
- **Actual:** The snackbar says "Turned on", but the switch snaps back to Off (confirmed by widget test).
  Consent state is never read from the server and never stored locally. The player cannot see what they
  agreed to, and the only way to withdraw is to tap a switch that already shows Off.
- **Fix:** Keep consent state in a provider. Seed it from `/me` or the consents endpoint, and update it
  optimistically after `setConsents` succeeds. Bind `value:` to that state.

### Q1-2: Sign-in dead end after "Send code": the number cannot be changed and a new code cannot be requested (High)
- **File:** `screens/sign_in_screen.dart:83` (`enabled: !_sent`), `:111-140`
- **Repro:** Type a wrong number and tap "Send code". Or wait until the code expires, so the screen
  shows "The code expired. Ask for a new one."
- **Expected:** "Change number" and "Resend code" actions (resend with a cooldown).
- **Actual:** The phone field is disabled and only "Verify" is shown. Nothing resets `_sent`. The only
  ways out are "Play offline" or leaving the screen. The error text itself tells the player to do
  something the UI does not allow.
- **Fix:** Add "Change number" (sets `_sent=false` and clears `_code`) and "Resend code" buttons. Also
  validate the 10-digit number before sending. Today an empty field sends `+91`.

### Q1-3: Calibration leaks the camera session and can call `setState` after dispose (High: privacy and crash)
- **File:** `screens/calibration_screen.dart:48-61`, `:71`
- **Repro:** Open Calibrate and leave (back gesture or app switch) while `voice.init` or `session.start`
  is still awaiting.
- **Expected:** The camera stops and no callbacks run.
- **Actual:** `_start` never checks `mounted` after its awaits. `dispose()` has already run with
  `_session == null`, so the session that starts afterwards is assigned and never disposed. The camera
  stays on, and `_onFrame` calls `setState` and `ref.read` on a disposed State, which throws. Compare
  `setup_screen.dart:41`, which handles this correctly.
- **Fix:** After each await, add `if (!mounted) { await session.dispose(); return; }`. In `_onFrame`,
  guard `setState` with `mounted`.

### Q1-4: Many player-facing strings bypass `tr()`, so hi/gu players see English (Medium)
- **Files:**
  - `settings_screen.dart:30,36,43,46,52-55,80-82,88-89,94,124,134,145,147,154,159,165,173,188,190,195,199,235,242,247,253` (title "Settings", Difficulty labels, Low-impact/Assist, Language, Recalibrate, Redo space setup, Privacy, consent texts, Download/Delete and the dialog, Sign in, grievance line)
  - `crew_screen.dart:68,75,113,130,133`
  - `sign_in_screen.dart:45` ("Something went wrong (code)")
  - `home_screen.dart:155`
- **Repro:** Set Language to हिन्दी or ગુજરાતી and open Settings, or enter an unknown gym code.
- **Expected:** Translated text.
- **Actual:** Mixed English and Hindi/Gujarati on one screen. Settings is mostly English. Raw server
  error codes such as `(gym_code_bad_format)` reach the player.
- **Fix:** Wrap each of these in `tr()` and add entries to `l10n/tr.dart`. Replace raw-code fallbacks
  with a generic translated message.

### Q1-5: "Download my data" and "Delete my account" fail silently (Medium)
- **File:** `screens/settings_screen.dart:177` and `:211` (`catch (_) {}`)
- **Repro:** Go offline, or let the token expire, then tap either button.
- **Expected:** An error snackbar, for example "Needs a connection and sign-in".
- **Actual:** Nothing happens and there is no feedback. For a DPDP data-rights action, the player cannot
  tell whether the request went through. Neither button is disabled while the request runs, so repeated
  taps send repeated requests.
- **Fix:** Show a translated error snackbar in the catch blocks, and add a busy state.

### Q1-6: `signedIn` flag drifts from the token store when token refresh fails (Medium)
- **File:** `services/api_client.dart:100-104` (`_refresh` clears tokens), `services/settings.dart` (`signedIn`)
- **Repro:** Let the refresh token become invalid. This can happen when two calls race to refresh with
  the same rotating token, for example parallel home/crew loads.
- **Expected:** The app notices and shows a signed-out state with a Sign in button.
- **Actual:** The tokens are cleared, but `Settings.signedIn` stays `true`. Settings keeps showing the
  signed-in actions, which now always fail (silently, per Q1-5). Home routes to `/crew`, which shows a
  misleading "Needs a connection." There is no way to sign in again except "Sign out" first.
- **Fix:** Derive signed-in state from `TokenStore.hasSession`, or flip `signedIn=false` when refresh
  fails. Run refreshes one at a time with a shared in-flight Future.

### Q1-7: "Leave this gym" runs on one tap with no confirmation (Medium)
- **File:** `screens/crew_screen.dart:156-174`
- **Repro:** On the crew board, tap "Leave this gym".
- **Expected:** A confirm dialog. The membership gives Premium free, and getting back in needs the
  poster code.
- **Actual:** The player leaves at once and their place on the board is gone.
- **Fix:** Add a confirm dialog like the delete-account one, with translated text.

### Q1-8: Setup and Calibrate camera views have no exit or skip; Calibrate re-runs on "Redo space setup" (Medium)
- **Files:** `screens/setup_screen.dart:147-189`, `screens/calibration_screen.dart:107-188`,
  `screens/settings_screen.dart:126-133`
- **Repro:** Tap Settings, then "Redo space setup". The live view has no app bar or back button, and
  because the route was opened with `go`, the system back gesture leaves the app. "Next" stays disabled
  until the player has been visible for 1.5 s. Finishing setup always goes to `/calibrate`, which
  overwrites the existing calibration without asking. Calibration also has no exit for a player who
  cannot do the squat or lean steps.
- **Expected:** A back or "Not now" action. Redoing setup keeps the existing calibration (or asks first).
- **Actual:** The only way out is to finish the flow or close the app.
- **Fix:** Add a back action, and use `push` from Settings. In `_finish`, go to `/calibrate` only when
  `calibration == null`.

### Q1-9: "Allow camera and start" and "Join crew" can be tapped twice; a duplicate camera session leaks (Low-Med)
- **Files:** `screens/setup_screen.dart:139` (no busy guard; the second `MotionSession` overwrites
  `_session` and the first is never disposed), `screens/crew_screen.dart:125` (a second join returns
  `already_in_a_gym`, so the board shows "Leave your current gym first.")
- **Fix:** Add a `_busy` flag that disables the button while the request is in flight.

### Q1-10: Sign-in from Home's crew card lands on Home, not Crew; a pending gym code is dropped when offline (Low)
- **Files:** `screens/sign_in_screen.dart:66` (`/crew` only when a pending code exists),
  `screens/crew_screen.dart:32-35` (the pending code is removed from prefs before the load or join
  succeeds)
- **Repro (sign-in):** Not signed in, tap the Home crew card, then sign in. The player is sent to
  `/home`.
- **Repro (pending code):** Open a QR deep link while offline, then leave Crew. The code is gone.
- **Fix:** Return to the caller with `context.pop()` when the screen was pushed. Remove the pending code
  only after a successful join.

---

**Checked and OK:**
- Router `nextOnboardingStep` ordering.
- `/join` code validation.
- Readiness answers are not stored.
- Low-impact is forced when any readiness answer is Yes.
- `wipeLocalData` covers the keys it documents.
- The "me" row on the crew board uses an icon as well as colour.
- `TrackingDot` has shape and semantics.

---

**Fixes (agent pass):**
- ✅ Fixed: Q1-3 — `calibration_screen.dart` checks `mounted` after every await in `_start`, disposes a late or failed session, guards `_onFrame`, and saves calibration before the async teardown in `_finish`.
- ✅ Fixed: Q1-1 — Settings is now stateful; consents load from `GET /me/consents` (`ApiClient.consents()`), switches bind to that state, toggle optimistically and revert with a snackbar on failure; switches are disabled until loaded and while a write is in flight.
- ✅ Fixed: Q1-2 — Sign-in has "Resend code" (30 s cooldown) and "Change number"; "Send code" stays disabled until a valid 10-digit Indian mobile number (starts 6–9) is entered; raw error codes replaced by a generic message.
- ✅ Fixed: Q1-5 — "Download my data" / "Delete my account" show "Needs a connection and sign-in" on failure and are disabled while busy.
- ✅ Fixed: Q1-6 — `ApiClient.onSessionExpired` fires when refresh fails; `apiProvider` flips `Settings.signedIn=false`. Refreshes are single-flight (shared Future). Settings also requires `TokenStore.hasSession` to show signed-in actions.
- ✅ Fixed: Q1-7 — "Leave this gym" asks for confirmation first.
- ✅ Fixed: Q1-9 — Setup "Allow camera and start" and Crew "Join crew"/"Leave this gym" are guarded by busy flags; setup disposes a failed session.
- ✅ Fixed (partial): Q1-8 — redoing setup keeps an existing calibration (goes to `/calibrate` only when none). No back action added yet.
- ✅ Fixed (partial): Q1-10 — pending gym code is removed only after a successful join. Sign-in return-to-caller not changed.
- ✅ Fixed (partial): Q1-4 — new and touched strings in settings, crew and sign-in go through `tr()`; `l10n/tr.dart` entries not added (owned by another agent), so hi/gu fall back to English for these.
