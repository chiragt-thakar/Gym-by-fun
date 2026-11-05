# QA 4 — server end-to-end + malformed-input sweep

Date: 2026-11-05. Method: temporary `server/test/_qa4.test.ts` (deleted) using `app.inject` against real Postgres/Redis via `test/helpers.ts`. ~80 requests: sign up, device, sessions (50-batch, 51-batch, duplicate, flagged), progress, join gym, board, weekly report, payment link, Razorpay webhook, entitlements, export, delete, plus malformed bodies on every route.

**What passed:** 50-session batch accepted, 51 rejected with 400. Re-sending a session is idempotent, and implausible sessions are flagged and earn 0 points. Bodies that are `null`, `[]`, a bare string or invalid JSON get 400 on every user route. Bad Razorpay signature returns 401, and a replay returns `duplicate`. Payment link works, and monthly founding returns 400. The board returns 403 for outsiders. After `DELETE /me`, the access token (401 `account_deleted`) and the refresh token are both dead. Export holds no token hashes or `phone_hash`. Content path traversal returns 400.

## Findings

### Q4-1 — High — POST /v1/sessions, src/modules/progress/routes.ts:91-128 (moves insert)
- Repro: one session with `moves: [{move:'squat',...},{move:'squat',...}]`.
- Expected 400 (or merged). Actual **500 `internal`**: the unique (session_id, move) constraint is violated. The whole transaction rolls back, so one bad session makes the phone's offline queue retry the batch forever.
- Fix: add `.refine(ms => new Set(ms.map(m=>m.move)).size === ms.length)` to `moves` in `sessionSchema`.

### Q4-2 — High — POST /v1/sessions, routes.ts:104 (`device_id`)
- Repro A: `deviceId` = a random valid UUID gives **500** (FK violation).
- Repro B: `deviceId` = **another user's** device id gives **200 accepted**, and the session is linked to someone else's device. There is no ownership check (cross-tenant integrity problem; the victim's device appears in the attacker's export).
- Expected 400/403 `unknown_device`. Fix: look up the user's own device ids once per batch. Reject or null out unknown ones, as `/me/calibration` already does.

### Q4-3 — High — POST /v1/webhooks/razorpay, src/modules/billing/routes.ts:46-60 and billing/service.ts:122
- Repro A: signed body `null` gives **500** (`body.event` on null).
- Repro B: signed `payment_link.paid` with `notes.gym_id` = 36 dashes (passes `/^[0-9a-f-]{36}$/`) gives **500** (Postgres invalid uuid).
- A 500 makes Razorpay keep retrying, then it disables the webhook. Fix: validate the body with zod (`event: string`, `payload: record`) and return 400. Validate `gym_id` with `z.string().uuid()`. That also accepts uppercase UUIDs, which the current regex wrongly ignores.

### Q4-4 — Medium — POST /v1/webhooks/razorpay, billing/routes.ts:51 (eventId fallback)
- Repro: without an `x-razorpay-event-id` header, send `{"event":"payment_link.paid","payload":"x"}` (recorded as `ignored`). Then send any later paid event whose entity has no `id`. Actual: `duplicate`, and the payment is silently dropped, because every such event collapses to the eventId `payment_link.paid:`.
- Fix: require the `x-razorpay-event-id` header (400 if missing), or fall back to a hash of the raw body.

### Q4-5 — High — POST /v1/webhooks/revenuecat, billing/service.ts:96-100
- Repro A: `app_user_id: 'not-a-uuid'` (RevenueCat anonymous ids look like `$RCAnonymousID:...`) gives **500**.
- Repro B: `expiration_at_ms: 9e18` gives **500** (invalid Date sent to pg).
- Expected 200 `ignored` / 400. RevenueCat retries 500s. Fix: return ignored if `app_user_id` is not a UUID, and bound `expiration_at_ms` in zod (`.int().positive().max(8.64e15)`).

### Q4-6 — Medium — GET /v1/admin/gyms/:id/report, src/modules/reports/service.ts:29
- Repro: a valid but unknown gym UUID gives **500** (`executeTakeFirstOrThrow`). Expected 404 `gym_not_found`.
- Fix: use `executeTakeFirst` and throw `notFound`. The worker should also skip rather than crash.

### Q4-7 — Medium — POST /v1/admin/gyms/:id/quests, src/modules/gyms/routes.ts:137 / createQuest :174
- Repro: a valid but unknown gym UUID gives **500** (FK violation). Expected 404. Fix: check that the gym exists in the admin route before calling `createQuest`.

### Q4-8 — Medium — POST /v1/sessions, progress/routes.ts:21-33 (missing validation)
- `startedAt: '2031-01-01'` is **accepted**. It sets `lastPlayedOn` to 2031, and the streak, shields and crew week are computed from the future date. A real session played afterwards would then look "earlier" and could break the streak.
- `levelId: 'w9-nope'` (a level that does not exist) is accepted and shows in `personalBests`.
- Fix: reject `startedAt > now + 10min` (and older than about 60 days). Check `levelId` against `content_versions`, or flag the session.

### Q4-9 — Low — POST /v1/sessions, routes.ts:181-183
- A duplicate `clientId` within one batch is reported in both `accepted` and `duplicates`. That is harmless, but the client cannot tell which outcome is real. `recordCrewEffort` also runs outside the session transaction: if it fails after commit, the request returns 500 while the session is already stored. A retry then reports `duplicate`, and the crew points are lost for good.
- Fix: dedupe `clientId` before the loop, and move `recordCrewEffort` into the transaction (`tx`).

### Q4-10 — Low — POST /v1/gyms/join (re-join)
- Joining the same gym twice returns 200 with no indication. Behaviour looks correct, but there is no test covering "already a member of gym B, join gym A". Worth adding a test that confirms the old membership is closed and the gym entitlement moves.

## Summary
There are 6 distinct server 500s (Q4-1, 2, 3, 5, 6, 7). Three of them are on webhooks, where a 500 makes the provider retry forever. One is a cross-user data-integrity gap (Q4-2B). One is validation that lets a future `startedAt` corrupt streak and progress (Q4-8). No PII leak was found in the export, the board, or the error bodies (errors are generic `internal`). The Q4-1/2/3/5 fixes are each a few lines of zod, plus an ownership check for devices.
