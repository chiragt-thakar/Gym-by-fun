# Security, privacy and safety controls

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
