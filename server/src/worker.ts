// Background jobs: Monday WhatsApp gym reports and the nightly deletion purge.
import { buildApp } from './app.js';
import { loadConfig } from './config.js';
import { scheduleJobs, startWorker } from './modules/reports/queue.js';

const config = loadConfig();
const { app, ctx } = await buildApp({ config });
const queue = await scheduleJobs(config.REDIS_URL);
const worker = startWorker(ctx);
worker.on('completed', (job, result) => app.log.info({ job: job.name, result }, 'job completed'));
worker.on('failed', (job, err) => app.log.error({ job: job?.name, err }, 'job failed'));

for (const sig of ['SIGINT', 'SIGTERM'] as const) {
  process.on(sig, () => {
    void Promise.all([worker.close(), queue.close(), app.close()]).then(() => process.exit(0));
  });
}
