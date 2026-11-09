// Validates every arcade game JSON in a folder against the arcade schema.
// Deeper invariants (solvable boards, playable songs) are checked by the
// game_director Dart tests, which run the real engines.
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { Ajv2020 } from 'ajv/dist/2020.js';

const here = dirname(fileURLToPath(import.meta.url));
const schema = JSON.parse(
  readFileSync(resolve(here, '../../../../content/schema/arcade.schema.json'), 'utf8'),
);
const ajv = new Ajv2020({ allErrors: true, strict: true, strictRequired: false, strictTypes: false });
const validate = ajv.compile(schema);

const dir = resolve(process.argv[2] ?? '../content/arcade');
let failed = 0;
for (const f of readdirSync(dir).filter((n) => n.endsWith('.json')).sort()) {
  const data: unknown = JSON.parse(readFileSync(join(dir, f), 'utf8'));
  const errors: string[] = [];
  if (!validate(data)) {
    for (const e of validate.errors ?? []) errors.push(`${e.instancePath || '/'} ${e.message ?? ''}`.trim());
  } else {
    const game = (data as { game: string }).game;
    if (`${game}.json` !== f) errors.push(`file name must be ${game}.json`);
  }
  if (errors.length) {
    failed++;
    process.stderr.write(`✗ ${f}\n  ${errors.slice(0, 12).join('\n  ')}\n`);
  } else process.stdout.write(`✓ ${f}\n`);
}
process.exit(failed ? 1 : 0);
