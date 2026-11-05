import { loadConfig } from '../config.js';
import { createDb, migrateToLatest } from './database.js';

const config = loadConfig();
const db = createDb(config.DATABASE_URL);
await migrateToLatest(db);
await db.destroy();
process.stdout.write('migrations applied\n');
