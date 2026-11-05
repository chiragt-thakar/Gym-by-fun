import type { Redis } from 'ioredis';

import type { Config } from './config.js';
import type { DB } from './db/database.js';
import { PiiCipher } from './lib/crypto.js';
import type { Providers } from './lib/providers.js';

/** Everything a module needs. Modules call each other in-process. */
export interface AppContext {
  config: Config;
  db: DB;
  redis: Redis;
  providers: Providers;
  pii: PiiCipher;
  now: () => Date;
}

export function makeCipher(config: Config) {
  return new PiiCipher(config.PII_ENCRYPTION_KEY);
}
