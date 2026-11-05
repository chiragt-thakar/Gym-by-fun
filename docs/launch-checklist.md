# Production launch checklist

Tick each item before the Play Store closed test, then before public launch.
"Code" items are in this repo; "You" items need your accounts, people or money.

## 1. Accounts and paperwork (You)
- [ ] Business entity + bank KYC (needed for Razorpay); GST decision with a chartered accountant
- [ ] Google Play developer account (US$25, once)
- [ ] Domain (`motionquest.app` is a placeholder — check the name and trademark first)
- [ ] Grievance Officer email published (replace `grievance@motionquest.app` via `GRIEVANCE_EMAIL`)
- [ ] Lawyer review of `/legal/privacy` and `/legal/terms` (DPDP Act 2023 / Rules 2025)
- [ ] Native-speaker review of Hindi and Gujarati (`app/lib/l10n/`)

## 2. Server deployment (You + Code)
- [ ] Server and managed PostgreSQL in an Indian region; Redis
- [ ] Secrets set (see `server/.env.example`): `JWT_SECRET`, `PII_ENCRYPTION_KEY` (32 bytes),
      `PII_HASH_PEPPER`, `ADMIN_API_KEY`, webhook secrets, `GOOGLE_CLIENT_ID`
- [ ] `SMS_PROVIDER=msg91` with an approved DLT template; `WHATSAPP_PROVIDER=http` with a BSP
      and an approved utility template for the Monday report
- [ ] `MIGRATE_ON_BOOT=false` and run `node dist/db/migrate.js` as a deploy step
- [ ] Start both processes: `node dist/server.js` (API) and `node dist/worker.js` (jobs)
- [ ] TLS in front (load balancer or Caddy); `PUBLIC_BASE_URL` set to the real https domain
- [ ] Least-privilege DB role for the app; daily backups; test a restore monthly
- [ ] Uptime check on `/healthz`; logs shipped somewhere searchable

## 3. Android release (You + Code)
- [ ] Create an upload key: `keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
- [ ] Put it in `app/android/key.properties` (git-ignored) or CI secrets `MQ_KEYSTORE_*`
- [ ] Build: `flutter build appbundle --release --dart-define=API_BASE=https://api.<your-domain>`
- [ ] Bump `version:` in `app/pubspec.yaml` for every upload
- [ ] Enable Play App Signing
- [ ] Play Console: Health apps declaration, Data safety form (see §5), content rating, 18+ target audience
- [ ] Store listing: video of real camera play, Hindi listing, "home workout game" keywords;
      no medical or weight-loss claims

## 4. Gate checks before public launch (You, with Code tools)
- [ ] Record ≥ 5 consenting people with the in-app recorder (heights, kurta/saree/track pants,
      tube and evening light); add files to `packages/motion_core/test/recordings/`; CI gate passes
- [ ] On budget, mid and upper-mid phones (debug screen): ≥ 90 % recognition per move,
      < 1 false trigger/min, capture→event < ~150 ms, ≥ 24 fps for 15 min without overheating
- [ ] 5–10 home playtests; fix every "unfair" moment
- [ ] Closed testing track; crash-free sessions ≥ 99.5 %
- [ ] Original or licensed art and recorded voice lines replace the procedural placeholders

## 5. Data safety form (answers from the code)
| Question | Answer |
|---|---|
| Data collected | Phone number (account), name (optional), app activity (sessions, progress), device model, optional calibration backup, pain reports |
| Photos/videos | **Not collected** — camera frames are processed on device only and never stored or sent |
| Shared with third parties | Gym (only with member consent: first name, sessions, effort points); SMS/WhatsApp providers for delivery; payment processors |
| Encrypted in transit | Yes (HTTPS) |
| Deletion | Yes — in-app account deletion (Settings), plus email request |

## 6. Phase 3 (payments) — before turning on Premium
- [ ] RevenueCat project + Play products (₹129 monthly, ₹699 yearly with 7-day trial)
- [ ] App: RevenueCat SDK + paywall after the 3rd session or a locked world, never mid-run
- [ ] RevenueCat webhook → `POST /v1/webhooks/revenuecat` with `REVENUECAT_WEBHOOK_AUTH`
- [ ] Razorpay webhook → `POST /v1/webhooks/razorpay`; create gym links with
      `POST /v1/admin/gyms/:id/payment-links`
- [ ] Test purchases, renewals, cancellations and gym activations in Play's test environment
