// Validates every level JSON in a folder against the schema. Used in CI.
import { readdirSync, readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';

import { validateLevel } from './validator.js';

const dir = resolve(process.argv[2] ?? '../content/levels');
let failed = 0;
for (const f of readdirSync(dir).filter((n) => n.endsWith('.json')).sort()) {
  const errors = validateLevel(JSON.parse(readFileSync(join(dir, f), 'utf8')));
  if (errors.length) {
    failed++;
    process.stderr.write(`✗ ${f}\n  ${errors.join('\n  ')}\n`);
  } else process.stdout.write(`✓ ${f}\n`);
}
process.exit(failed ? 1 : 0);
