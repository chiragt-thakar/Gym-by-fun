# Security, privacy and safety controls

## Gameplay/body-avatar update (2026-11-09)

The live body avatar is drawn exclusively from the latest visible landmarks;
it is not a segmentation mask, a camera image or a fabricated motion source.
Mirror-off still leaves native Preview unbound. No camera captures were used
for `gameplay-*.png`: these are opt-in test renders with synthetic fixtures.
Recognition thresholds, frame lifetime, on-device processing and native secure
preview handling are unchanged. New `heroLook` and `missionLevels` values are
local cosmetic preferences/progress in the existing settings record; account
switch reset and local deletion cover them. Mission progress derives only from
resolved encounters and never penalises camera-forgiven opportunities.

## Account isolation and honest save status (2026-11-09)

- Offline queue entries carry a local account owner, stripped before upload.
  Another account's entries are not submitted or shown as that player's pending
  activity. Legacy records are stamped before a known account's tokens change.
  Existing access-token subjects can supply a migration label; this is not
  authentication and never replaces the server's JWT verification.
- Authenticated requests detect account changes across awaits and cannot retry
  an old player's upload using a new player's token. Refresh responses also
  cannot overwrite or clear a newer sign-in. Queue clearing shares the upload
  lock, preventing a sign-out/flush race.
- Explicit sign-out clears pending/rejected queue files, coach history, activity
  dates and pending gym code. If unsynced runs exist, the app explains that they
  will be removed and offers Cancel. Stage progress stays on the phone; switching
  to a different known account resets that progress and requires that player's
  own calibration/tutorial. Full local deletion also removes ownership metadata.
- Validation failures are split to individual records; valid neighbours sync,
  while rejected activity remains in a local review file. Auth, permission,
  throttle, timeout and service errors keep the queue for retry. Rejected runs
  are not counted as synced. Unreadable activity files are preserved and report
  a save error instead of being silently overwritten.
- Results distinguish a completed local write from a failed write, allow Retry,
  and save changed effort ratings locally as they are selected. Counts and date
  labels are the only added activity data; no video or camera pixels are stored.
- Foreground pause keeps native tracking available for an explicitly described
  gesture confirmation. Gameplay and workout counters ignore menu movements.
  Backgrounding stops the camera. No camera data is used in the widget-preview
  exports, which are generated only by opt-in test code with fixture activity.

Server refresh-token revocation on explicit logout remains the separate R3-4
review item; local account isolation does not implement server token revocation.

## Privacy (India DPDP)

| Control | Where |
|---|---|
| Video processed on device only; frames never stored or uploaded | `native/pose_bridge` (pixels released after inference); only landmarks reach Dart |
| Camera permission screen says video never leaves the phone | `app/lib/screens/setup_screen.dart` |
| Camera mirror (self-view) is drawn natively: camera → `PreviewView` → screen. No pixel or texture handle reaches Dart; nothing is recorded or stored. The CameraX `Preview` is not even bound when Settings → "Show camera mirror" is off | `native/pose_bridge/.../SelfView.kt`, `PosePipeline.kt` (`selfView`) |
| `FLAG_SECURE` while any mirror is on screen: no screenshots, screen recordings or recents thumbnails of the camera image | `PoseBridgePlugin.updateSecure()` |
| Landmark recordings contain no images | `motion_core/lib/src/recording.dart`, recorder screen |
| Consent per purpose (account, gym_sharing, analytics, calibration_backup), versioned, withdrawable | `server/src/modules/identity/routes.ts` |
| Calibration (body measurements) stays on device unless backup consent is on; withdrawing deletes the backup | `PUT /me/calibration`, `PUT /me/consents` |
| Gyms see only members who opted in to sharing, first names and activity summaries — never body measurements | `gyms/service.ts` `crewBoard`, `reports/service.ts` |
| Data export in settings: every user-linked table (incl. crew scores, entitlements/billing linkage, sign-in session metadata — never token or phone hashes); a test fails if a new `user_id` table is not exported | `GET /me/export` |
| Account deletion in settings. Immediate scrub: name, phone, Google id cleared; tokens revoked; gym sharing stopped; pain reports, devices, calibrations, sessions (+ moves), progress and crew scores deleted. Kept until the hard delete after `DELETION_GRACE_DAYS`, linked only to the scrubbed user id: entitlements (billing/accounting linkage), withdrawn consent records, memberships marked left, revoked refresh tokens | `DELETE /me`, nightly `purgeDeletedAccounts` |
| Adults only: 18+ confirmation before an account is created | app age gate + `age_confirmation_required` on the server |
| Readiness answers are never stored | `ReadinessScreen` keeps them in widget state only |
| Phone numbers encrypted at rest (AES-256-GCM) with keyed-hash lookup | `server/src/lib/crypto.ts` |
| Host in an Indian region; TLS in transit; encrypted managed Postgres at rest | deployment |
| Grievance contact published in the app | Settings → About |

## Security

| Control | Where |
|---|---|
| Every webhook verified: RevenueCat shared auth header, Razorpay HMAC-SHA256 over the raw body; constant-time compare | `billing/routes.ts` |
| Each webhook event processed exactly once: the `billing_events` marker and the change it records commit in one transaction, so a failed apply leaves no marker and the provider retry succeeds; unhandled Razorpay event types are not recorded | `billing/service.ts processWebhookOnce` |
| Premium decided on the server only | `GET /entitlements` |
| OTP: 6 digits, 5-minute expiry, 5 attempts, hashed at rest, rate-limited per phone (3/10 min) and per IP (10/h) | `identity/routes.ts` |
| Short-lived access JWTs (15 min); opaque rotating refresh tokens stored hashed; reuse revokes the whole family | `identity/tokens.ts` |
| Gym codes have member limits and expiry dates | `gyms/service.ts joinGym` |
| Admin endpoints behind `x-admin-key`; trainer page behind a per-gym key stored hashed | `lib/auth.ts`, `gyms/routes.ts` |
| Secrets only from environment; production refuses console SMS/WhatsApp providers | `config.ts` |
| Logs redact authorization and admin headers; OTP codes are logged only by the dev console provider | `app.ts`, `lib/providers.ts` |
| Light anti-cheat: impossible rep rates flagged and excluded from progress and boards | `progress/service.ts isImplausible` |
| Input validation with Zod on every route; 512 KB body limit | routes |
| Least-privilege DB roles; daily backups with a monthly restore test | operations (to set up at deployment) |

## Player safety

- Low-impact by default (half squat counts, one arm is enough, no jumps).
- Warm-up and cool-down in every Daily Quest.
- Moves are measured against the player's own calibrated range.
- Stop-if-it-hurts reminders and a pain report button on results; reports
  are logged at warn level for review within a week.
- A tracking failure never costs a heart (`RunEngine` forgives, `Pacer` slows/stops).
- No medical or weight-loss claims anywhere; "a game for general fitness, not
  medical advice" on the age gate, home and settings. Complete the Play Console
  Health apps declaration before release.
- No in-app links or nudges toward payment outside Google Play.
