import type { FastifyBaseLogger } from 'fastify';

/**
 * Runs `close` once on SIGINT/SIGTERM, then exits. A second signal or a
 * close that takes longer than `timeoutMs` forces exit with code 1.
 */
export function onShutdown(log: FastifyBaseLogger, close: () => Promise<unknown>, timeoutMs = 15_000) {
  let closing = false;
  for (const sig of ['SIGINT', 'SIGTERM'] as const) {
    process.on(sig, () => {
      if (closing) {
        log.warn({ sig }, 'second signal, forcing exit');
        process.exit(1);
      }
      closing = true;
      log.info({ sig }, 'shutting down');
      const timer = setTimeout(() => {
        log.error('graceful shutdown timed out, forcing exit');
        process.exit(1);
      }, timeoutMs);
      timer.unref();
      close().then(
        () => process.exit(0),
        (err: unknown) => {
          log.error({ err }, 'error during shutdown');
          process.exit(1);
        },
      );
    });
  }
}
