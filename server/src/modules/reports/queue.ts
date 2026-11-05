import { Queue, Worker } from 'bullmq';

import type { AppContext } from '../../context.js';
import { purgeDeletedAccounts } from '../identity/routes.js';
import { sendWeeklyReports } from './service.js';

export const QUEUE = 'motionquest-jobs';

function connection(url: string) {
  const u = new URL(url);
  return { host: u.hostname, port: Number(u.port || 6379), password: u.password || undefined, maxRetriesPerRequest: null };
}

/** Registers the repeatable jobs: Monday reports and nightly deletion purge. */
export async function scheduleJobs(redisUrl: string) {
  const q = new Queue(QUEUE, { connection: connection(redisUrl) });
  await q.upsertJobScheduler('weekly-gym-reports', { pattern: '0 9 * * 1', tz: 'Asia/Kolkata' }, { name: 'weekly-gym-reports' });
  await q.upsertJobScheduler('purge-deleted-accounts', { pattern: '30 2 * * *', tz: 'Asia/Kolkata' }, { name: 'purge-deleted-accounts' });
  return q;
}

/** Dispatches a job by name. Pure so it can be tested without BullMQ. */
export async function runJob(ctx: AppContext, name: string) {
  if (name === 'weekly-gym-reports') return sendWeeklyReports(ctx);
  if (name === 'purge-deleted-accounts') return { purged: await purgeDeletedAccounts(ctx) };
  throw new Error(`Unknown job ${name}`);
}

export function startWorker(ctx: AppContext) {
  return new Worker(
    QUEUE,
    async (job) => runJob(ctx, job.name),
    { connection: connection(ctx.config.REDIS_URL), concurrency: 1 },
  );
}
