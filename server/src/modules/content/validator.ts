import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { Ajv2020 } from 'ajv/dist/2020.js';

const here = dirname(fileURLToPath(import.meta.url));
export const SCHEMA_PATH = resolve(here, '../../../../content/schema/level.schema.json');

const ajv = new Ajv2020({ allErrors: true, strict: true, strictRequired: false });
const validateSchema = ajv.compile(JSON.parse(readFileSync(SCHEMA_PATH, 'utf8')));

export interface LevelJson {
  id: string;
  version: number;
  schemaVersion: number;
  durationS: number;
  gameplay?: { scene: string; mission: 'lights' | 'gates' | 'path'; targetFraction: number; atmosphere: string };
  segments: { id: string; startS: number; endS: number; kind: string }[];
  encounters: { atS: number; type: string; lanes?: number[]; minDifficulty?: string }[];
  [k: string]: unknown;
}

/** JSON Schema + the invariants the game relies on. Returns error strings. */
export function validateLevel(level: unknown): string[] {
  if (!validateSchema(level)) {
    return (validateSchema.errors ?? []).map((e) => `${e.instancePath || '/'} ${e.message ?? ''}`.trim());
  }
  const l = level as LevelJson;
  const errors: string[] = [];
  if (l.gameplay && !l.encounters.some((e) =>
    (!e.minDifficulty || e.minDifficulty === 'beginner') &&
    (l.gameplay!.mission === 'lights' ? e.type === 'orb' :
      l.gameplay!.mission === 'gates' ? e.type === 'gate' : e.type !== 'orb'))) {
    errors.push('mission needs a beginner-level opportunity');
  }
  for (const s of l.segments) {
    if (s.endS <= s.startS) errors.push(`segment ${s.id} is empty`);
    if (s.endS > l.durationS) errors.push(`segment ${s.id} ends after the level`);
  }
  for (const e of l.encounters) {
    if (e.atS > l.durationS) errors.push(`encounter at ${e.atS}s is after the level ends`);
    const seg = l.segments.find((s) => e.atS >= s.startS && e.atS < s.endS);
    if (seg?.kind === 'breather' && e.type !== 'orb') errors.push(`breather ${seg.id} holds a ${e.type} at ${e.atS}s`);
  }
  if (!l.segments.some((s) => s.kind === 'checkpoint') && l.durationS > 120) errors.push('levels over 2 minutes need a checkpoint');
  return errors;
}
