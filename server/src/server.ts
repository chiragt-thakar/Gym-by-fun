import { buildApp } from './app.js';
import { loadConfig } from './config.js';
import { onShutdown } from './lib/shutdown.js';

const config = loadConfig();
const { app } = await buildApp({ config });
await app.listen({ port: config.PORT, host: '0.0.0.0' });

// app.close() stops accepting connections (new requests get 503), waits for
// in-flight requests, then closes Postgres and Redis via the onClose hook.
onShutdown(app.log, () => app.close());
