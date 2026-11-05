# MotionQuest REST API

Source of truth: `server/src/modules/**/routes.ts`. All `/v1` bodies are JSON (`content-type: application/json`, max 512 KB).

## Conventions

- **Auth**
  - `user`: `Authorization: Bearer <accessToken>` (JWT, `ACCESS_TOKEN_TTL_S`, default 15 min). If the token is missing or bad you get `401 unauthorized` / `invalid_token`. If the account is deleted you get `401 account_deleted`.
  - `admin`: `x-admin-key: <ADMIN_API_KEY>`. If it is missing or wrong you get `403 forbidden`.
  - `trainer`: `?key=<trainerKey>` query parameter (the key is shown once when the gym is created). If it is wrong you get `403 forbidden`.
  - `webhook`: a provider signature (see Billing).
  - `none`: public.
- **Errors**: `{ "error": "<code>", "message"?: "<detail>" }`.
  - Validation failure: `400 invalid_request`, where `message` = `"<field path>: <reason>"`.
  - Malformed JSON: `400 invalid_json`.
  - Global rate limit (`RATE_LIMIT_PER_MIN` per IP, default 300): `429 rate_limited`.
  - Unexpected failure: `500 internal`.
- **Request id**: every response carries `x-request-id`. A well-formed incoming `x-request-id` (`[A-Za-z0-9._:-]{1,64}`) is reused. Otherwise the server mints a UUID. The id is logged as `reqId`.
- Phone numbers: `+91` followed by a 10-digit mobile number starting 6–9 (`^\+91[6-9]\d{9}$`).
- Level ids: `^w\d+-[a-z0-9-]+$` (for example `w1-forest-escape`).

## Health (no prefix)

| Method | Path | Auth | Response |
|---|---|---|---|
| GET | `/livez` | none | `{ ok: true }`. The process is up. |
| GET | `/healthz` | none | `{ ok: true }`. Postgres and Redis are reachable, otherwise 500. Exempt from rate limiting. |

## Identity

### POST `/v1/auth/otp/start` — none
Body: `{ phone }`.
→ `202 { sent: true, expiresIn: 300 }`.
Errors: `400 invalid_request`; `429 otp_rate_limited` (3 per phone per 10 min, 10 per IP per hour).

### POST `/v1/auth/otp/verify` — none
Body: `{ phone, code: "6 digits", ageConfirmed?: boolean, language?: "en"|"hi"|"gu" }`.
→ `200 { accessToken, refreshToken, expiresIn, isNew, user }`.

Errors:
- `401 otp_expired`: no live challenge.
- `429 otp_attempts_exceeded`: 5 attempts used.
- `401 otp_invalid`.
- `400 age_confirmation_required`: new account without `ageConfirmed: true`.
- `401 account_deleted`.

### POST `/v1/auth/google` — none
Body: `{ idToken, ageConfirmed?, language? }`.
→ The same shape as OTP verify.
Errors: `401 google_invalid`, `400 age_confirmation_required`, `401 account_deleted`.

### POST `/v1/auth/refresh` — none
Body: `{ refreshToken }`.
→ `{ accessToken, refreshToken, expiresIn }`. The refresh token rotates on every call.

Errors:
- `401 invalid_refresh`.
- `401 refresh_reused`: the whole token family is revoked.
- `401 refresh_expired`.

### `user` object
`{ id, name|null, language, phone: "+91******1234"|null, google: boolean, createdAt }`

| Method | Path | Auth | Body | Response / errors |
|---|---|---|---|---|
| GET | `/v1/me` | user | — | `user` |
| PATCH | `/v1/me` | user | `{ name?: 1–40 chars, language?: en\|hi\|gu }` | `user` |
| GET | `/v1/me/consents` | user | — | `{ consents: [{ purpose, version, grantedAt, withdrawnAt }] }` |
| PUT | `/v1/me/consents` | user | `{ consents: [{ purpose: gym_sharing\|analytics\|calibration_backup, granted: boolean }] }` (min 1) | `{ ok: true }`. Withdrawing `gym_sharing` stops activity sharing. Withdrawing `calibration_backup` deletes backed-up calibrations. |
| GET | `/v1/me/export` | user | — | DPDP data export (see below) |
| DELETE | `/v1/me` | user | — | `202 { deleted: true, hardDeleteAfterDays }` (see below) |

`GET /v1/me/export` returns the following keys:
- `exportedAt`, `note`, `user`
- `consents`, `devices`, `calibrations`
- `sessions`, `sessionMoves`, `progress`
- `memberships`, `entitlements`, `billing[]`
- `painReports`, `crewScores`, `signInSessions[]` (metadata only)

`DELETE /v1/me` removes or anonymises the account immediately: it scrubs identifiers, deletes activity data and revokes tokens. The row is hard-deleted by the nightly job after `DELETION_GRACE_DAYS`.

## Progress

| Method | Path | Auth | Body | Response / errors |
|---|---|---|---|---|
| POST | `/v1/devices` | user | `{ model: 1–80, perfTier: upper_mid\|mid\|budget, appVersion: 1–20 }` | `201 { id }` |
| PUT | `/v1/me/calibration` | user | `{ deviceId: uuid, profile: { [name]: number } (≤20 keys) }` | `{ ok: true }`. `403 calibration_backup_not_enabled` (no consent), `403 unknown_device` |
| GET | `/v1/me/calibration` | user | — | `{ calibrations: [{ deviceId, profile, updatedAt }] }` |
| POST | `/v1/sessions` | user | `{ sessions: Session[] }` (1–50) | `{ accepted: clientId[], duplicates: clientId[], flagged: clientId[], progress }` |
| GET | `/v1/progress` | user | — | `progress` + `{ personalBests: { [levelId]: score }, recent: [{ clientId, levelId, startedAt, score, activeS, completed, difficulty }] }` (last 20) |
| POST | `/v1/me/pain-reports` | user | `{ sessionClientId?: ≤64, area: knees\|back\|hips\|shoulders\|neck\|ankles\|other, note?: ≤500 }` | `201 { ok: true, advice }` |

### `Session` object

| Field | Type |
|---|---|
| `clientId` | 8–64 chars, idempotency key |
| `levelId` | level id |
| `deviceId?` | uuid |
| `startedAt` | ISO datetime |
| `durationS` | 1–3600 |
| `activeS` | 0–3600 |
| `score` | 0–1,000,000 |
| `difficulty` | `beginner`, `intermediate` or `advanced` |
| `lowImpact` | boolean |
| `completed` | boolean |
| `effortRating?` | 1–5 |
| `moves?` | ≤10 items: `{ move: squat\|leanLeft\|leanRight\|raiseArms, attempts, recognised, falseTriggers, avgLatencyMs? }` |

Re-sending a `clientId` is a no-op and is reported in `duplicates`. Implausible sessions are stored, earn 0 effort and are reported in `flagged`.

### `progress` object
`{ xp, heroLevel, worlds: number[], streak, bestStreak, shields, lastPlayedOn, sessions, activeMinutes }`

## Gyms

`gym` = `{ id, name, logoUrl, colours: { primary, secondary } }`

| Method | Path | Auth | Body / query | Response / errors |
|---|---|---|---|---|
| POST | `/v1/gyms/join` | user | `{ code: 4–20, shareActivity: boolean }` | `{ gym }`. Errors: `404 gym_code_unknown`, `409 gym_code_expired`, `409 gym_inactive`, `409 already_in_a_gym`, `409 gym_code_full` |
| DELETE | `/v1/gyms/membership` | user | — | `204` |
| GET | `/v1/gyms/mine` | user | — | `{ gym|null, quests: [{ id, levelId, title, dueAt }] }` (next 5) |
| GET | `/v1/crews/:gymId/board` | user | `?week=YYYY-Www` (default: current ISO week) | `{ week, entries }`. `403 not_a_member` |
| POST | `/v1/admin/gyms` | admin | `{ name: 2–80, city: 2–40, logoUrl?, colours: { primary: #rrggbb, secondary: #rrggbb }, plan?: pilot\|founding\|starter\|growth\|chain (pilot), licenceDays?: 1–800 (56), ownerName?, ownerPhone? }` | `201 { id, name, licence_until, status, trainerKey }`. `trainerKey` is shown once. |
| POST | `/v1/admin/gyms/:id/codes` | admin | `{ maxMembers?: 1–5000 (300), validDays?: 1–800 (365) }` | `201 { code, maxMembers }`. `404 gym_not_found` |
| GET | `/v1/admin/gyms/:id/poster` | admin | `?code=` | `image/svg+xml` A4 QR poster. `404 not_found` |
| POST | `/v1/admin/gyms/:id/payment-links` | admin | `{ plan: founding\|starter\|growth, period: monthly\|yearly }` | `201 { ...providerLink, amountPaise, basePaise, gstPaise }`. `400 plan_period_unavailable`, `404 gym_not_found` |
| POST | `/v1/admin/gyms/:id/quests` | admin | `{ levelId, title: 2–80, dueAt: ISO datetime }` | `201 { id, level_id, title, due_at }`. `404 level_not_found` |
| GET | `/v1/admin/gyms/:id/report` | admin | — | `{ report, text }` (the weekly report and its WhatsApp text) |
| GET | `/v1/trainer/:gymId` | trainer | `?key=` | HTML quest page. `403 forbidden` |
| POST | `/v1/trainer/:gymId/quests` | trainer | `?key=`, body as in admin quests | `201` quest. `403 forbidden`, `404 level_not_found` |

## Billing

| Method | Path | Auth | Body | Response / errors |
|---|---|---|---|---|
| GET | `/v1/entitlements` | user | — | `{ premium: boolean, source: play\|gym\|promo\|null, activeUntil: ISO\|null }` |
| POST | `/v1/webhooks/revenuecat` | webhook: `Authorization: Bearer <REVENUECAT_WEBHOOK_AUTH>` | `{ event: { id, type, app_user_id, product_id?, expiration_at_ms?, original_transaction_id?, ... } }` | `{ status }`. Duplicate event ids are processed once. Errors: `401 bad_webhook_auth`, `400 bad_payload` |
| POST | `/v1/webhooks/razorpay` | webhook: `x-razorpay-signature` = HMAC-SHA256(raw body, `RAZORPAY_WEBHOOK_SECRET`) | Razorpay event (`payment_link.paid`, `invoice.paid` or `subscription.charged` is applied using `notes.gym_id/plan/period`) | `{ status }`, or `{ status: "ignored" }` for other events. Dedupe key: `x-razorpay-event-id`. Errors: `401 bad_signature`, `400 bad_payload` |

## Content

### `manifest entry` object

| Field | Notes |
|---|---|
| `levelId` | |
| `version` | |
| `schemaVersion` | |
| `sha256` | |
| `url` | |
| `publishedAt` | |
| `world` | number |
| `access` | `"free"` or `"premium"`: world 1 is free, every later world is premium |

| Method | Path | Auth | Body / query | Response / errors |
|---|---|---|---|---|
| GET | `/v1/content/manifest` | none | — | `{ levels: manifestEntry[] }` (latest version of each level). `cache-control: public, max-age=300` |
| GET | `/v1/content/levels/:id` | none | `?version=n` | Level JSON. `etag` = sha256. Versioned requests are cached immutable. `404 level_not_found` |
| POST | `/v1/admin/content/levels` | admin | Level JSON (validated against `content/schema/level.schema.json` + invariants) | `201 { levelId, version, unchanged: false }`, or `200 { ..., unchanged: true }` if identical. `400 invalid_level`, `409 version_exists_with_different_content` |

## Web pages (no prefix, HTML)

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/legal/privacy` | none | Privacy policy |
| GET | `/legal/terms` | none | Terms of use |
| GET | `/join?code=ABCD-XXXXXX` | none | QR-poster target: opens the app via an intent link, or falls back to Play Store. `400 invalid_request` on a bad code |
