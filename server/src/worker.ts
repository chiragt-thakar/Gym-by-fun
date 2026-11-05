// Background jobs: Monday WhatsApp gym reports and the nightly deletion purge.
import { buildApp } from './app.js';
import { loadConfig } from './config.js';
import { onShutdown } from './lib/shutdown.js';
import { scheduleJobs, startWorker } from './modules/reports/queue.js';

const config = loadConfig();
const { app, ctx } = await buildApp({ config });
const queue = await scheduleJobs(config.REDIS_URL);
const worker = startWorker(ctx);
worker.on('completed', (job, result) => app.log.info({ job: job.name, result }, 'job completed'));
worker.on('failed', (job, err) => app.log.error({ job: job?.name, err }, 'job failed'));

// worker.close() waits for the running job to finish before the DB/Redis close.
onShutdown(app.log, async () => {
  await worker.close();
  await queue.close();
  await app.close();
}, 60_000);
