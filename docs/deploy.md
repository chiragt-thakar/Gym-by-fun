# Production deploy (India)

Target: one API process plus one worker process. They run on a VM in an Indian region, behind a TLS reverse proxy. Postgres is managed and Redis is managed or runs on the VM. All data stays in India.

## 1. Provision
1. **VM**: AWS `ap-south-1` (Mumbai), GCP `asia-south1` or Azure Central India. Start with 2 vCPU / 4 GB and Ubuntu LTS. Install Docker and the compose plugin.
   - Firewall: allow 80 and 443 from anywhere, and 22 from the admin IPs only.
2. **Postgres 16+**: RDS, Cloud SQL or Azure Flexible Server, in the same region.
   - Use a private network only and require TLS (`?sslmode=require`).
   - Turn on automated daily backups with 7–30 day retention and point-in-time recovery (PITR).
   - Create a database `motionquest` and an app role that owns it.
3. **Redis 7**: ElastiCache, Memorystore, or a `redis:7-alpine` container with `appendonly yes`. It holds rate limits and BullMQ jobs, so it needs no backups.
4. **DNS**: point `api.motionquest.app` (and `PUBLIC_BASE_URL`'s host) at the VM.

## 2. Environment
Create `/srv/motionquest/.env` with mode 600, owned by root. Never commit it. Keep the master copy in a secrets manager.

```
NODE_ENV=production
PORT=8080
DATABASE_URL=postgres://mq_app:***@<pg-host>:5432/motionquest?sslmode=require
REDIS_URL=redis://<redis-host>:6379
JWT_SECRET=<openssl rand -base64 48>
PII_ENCRYPTION_KEY=<openssl rand -base64 32>     # exactly 32 bytes; losing it loses phone numbers
PII_HASH_PEPPER=<openssl rand -base64 24>        # never rotate (phone lookup hashes depend on it)
ADMIN_API_KEY=<openssl rand -base64 32>
GOOGLE_CLIENT_ID=<oauth client id>
REVENUECAT_WEBHOOK_AUTH=<openssl rand -base64 24>
RAZORPAY_WEBHOOK_SECRET=<set in Razorpay dashboard>
RAZORPAY_KEY_ID=...  RAZORPAY_KEY_SECRET=...
SMS_PROVIDER=msg91            MSG91_AUTH_KEY=...  MSG91_TEMPLATE_ID=...   # console is refused in production
WHATSAPP_PROVIDER=http        WHATSAPP_API_URL=...  WHATSAPP_API_TOKEN=...
MIGRATE_ON_BOOT=false         # migrations run as a separate deploy step
CORS_ORIGINS=                 # empty: the app needs none
RATE_LIMIT_PER_MIN=300
PUBLIC_BASE_URL=https://api.motionquest.app
PLAY_STORE_URL=https://play.google.com/store/apps/details?id=app.motionquest
GRIEVANCE_EMAIL=grievance@motionquest.app
CONTENT_DIR=../content/levels
```

The schema is in `server/src/config.ts`. A missing or invalid value stops boot with a list of the problems.

## 3. Build
Run this from the repository root. The build context must be the root, because the image includes `content/`:
```
docker build -f server/Dockerfile -t motionquest-server:$(git rev-parse --short HEAD) .
```
Push the image to a registry in the same region (ECR, Artifact Registry or ACR).

## 4. Migrate (every deploy, before starting new processes)
```
docker run --rm --env-file /srv/motionquest/.env motionquest-server:<tag> node dist/db/migrate.js
```
- Prints `migrations applied`.
- Migrations are forward-only, so take a snapshot first if a release changes the schema.
- Content levels are seeded on boot only when `MIGRATE_ON_BOOT=true`. Otherwise, publish them through `POST /v1/admin/content/levels`, or run the first boot once with `MIGRATE_ON_BOOT=true`.

## 5. Run API and worker
`/srv/motionquest/compose.yml`:
```yaml
services:
  api:
    image: motionquest-server:<tag>
    env_file: .env
    command: ["node", "dist/server.js"]
    ports: ["127.0.0.1:8080:8080"]
    restart: unless-stopped
    stop_grace_period: 20s
  worker:
    image: motionquest-server:<tag>
    env_file: .env
    command: ["node", "dist/worker.js"]
    restart: unless-stopped
    stop_grace_period: 70s
```

Run exactly **one** worker. It schedules the jobs: the Monday WhatsApp gym reports and the nightly deletion purge.

Shutdown on SIGTERM:
- **API**: stops accepting new requests (503 while closing), drains in-flight requests, then closes Postgres and Redis. It force-exits after 15 s.
- **Worker**: waits for the current job, then closes. It force-exits after 60 s. Keep `stop_grace_period` above these limits.

The image `HEALTHCHECK` probes `/livez` with Node's `fetch`.

Deploy procedure: pull the image, run the migration, then `docker compose up -d`.
Rollback: re-deploy the previous tag. Schema changes must stay backwards compatible for one release.

## 6. TLS reverse proxy
Use Caddy, which provides automatic Let's Encrypt certificates. `/etc/caddy/Caddyfile`:
```
api.motionquest.app {
  encode gzip
  request_body { max_size 1MB }
  reverse_proxy 127.0.0.1:8080 {
    header_up X-Request-Id {http.request.uuid}
  }
}
```
- The app sets `trustProxy: true`, so `req.ip` comes from `X-Forwarded-For`. Expose port 8080 only on localhost.
- The proxy's `X-Request-Id` is reused in app logs and echoed back in the response.
- With nginx: use `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for; proxy_set_header X-Request-Id $request_id;` plus certbot.

## 7. Webhooks
| Provider | URL | Configure |
|---|---|---|
| RevenueCat | `https://api.motionquest.app/v1/webhooks/revenuecat` | Project → Integrations → Webhooks. Set the Authorization header value to `Bearer <REVENUECAT_WEBHOOK_AUTH>`. |
| Razorpay | `https://api.motionquest.app/v1/webhooks/razorpay` | Dashboard → Webhooks. Secret = `RAZORPAY_WEBHOOK_SECRET`. Events: `payment_link.paid`, `invoice.paid`, `subscription.charged`. |

Both endpoints are idempotent per event id. Send a test event from each dashboard and check that the logs show `revenuecat event` / `razorpay event`.

## 8. Backups
- **Postgres**: use the managed daily snapshots and PITR. Add a weekly `pg_dump -Fc`, encrypted with age or gpg, to an object-storage bucket in the same region (S3 Mumbai or GCS asia-south1). Set a lifecycle rule of 90 days.
  - Run a restore drill every quarter into a scratch instance.
- Back up `PII_ENCRYPTION_KEY`, `PII_HASH_PEPPER` and `JWT_SECRET` in the secrets manager. A database backup cannot be used without the PII key.
- Account deletion: the nightly purge hard-deletes rows after `DELETION_GRACE_DAYS`. Backups older than the retention window must expire, so deleted data does not live on.

## 9. Monitoring
- **Uptime**: an external check on `https://api.motionquest.app/healthz` (Postgres and Redis) every minute, alerting on 2 failures.
  - `/livez` is used for container health only.
- **Logs**: pino JSON goes to stdout. Ship it with Docker's `awslogs` or `gcplogs` driver, or Vector/Promtail.
  - Search by `reqId`. Authorization and `x-admin-key` headers are redacted.
  - Alert on `unhandled error` and on `job failed`.
  - Review `pain report received` entries within 7 days.
- **Database**: alert on CPU above 80%, storage above 80%, connection count, and replication or backup failures.
- **Worker**: alert if the Monday report run is missing (no `job completed` for `weekly-reports` by Monday 12:00 IST).
