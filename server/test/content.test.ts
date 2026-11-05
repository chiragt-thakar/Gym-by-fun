import { readFileSync } from 'node:fs';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { accessForWorld } from '../src/modules/content/service.js';
import { validateLevel } from '../src/modules/content/validator.js';
import { admin, setup, type TestApp } from './helpers.js';

let t: TestApp;
beforeAll(async () => {
  t = await setup();
});
afterAll(async () => t.close());

const forest = () => JSON.parse(readFileSync('../content/levels/w1-forest-escape.json', 'utf8'));

describe('content', () => {
  it('shipped levels pass the schema and invariants', () => {
    expect(validateLevel(forest())).toEqual([]);
  });

  it('catches broken levels', () => {
    const l = forest();
    l.encounters.push({ atS: 95, type: 'beam' });
    expect(validateLevel(l).join()).toMatch(/breather/);
    const m = forest();
    m.encounters[0].type = 'jump';
    expect(validateLevel(m).length).toBeGreaterThan(0);
  });

  it('serves the manifest and immutable versioned levels', async () => {
    const man = await t.app.inject({ method: 'GET', url: '/v1/content/manifest' });
    const lvl = man.json().levels.find((l: { levelId: string }) => l.levelId === 'w1-forest-escape');
    expect(lvl).toMatchObject({ levelId: 'w1-forest-escape', version: 1, schemaVersion: 1, world: 1, access: 'free' });
    const r = await t.app.inject({ method: 'GET', url: lvl.url });
    expect(r.json().name).toBe('Forest Escape');
    expect(r.headers['cache-control']).toContain('immutable');
  });

  it('publishes a new version only after validation', async () => {
    const bad = { ...forest(), version: 2, lanes: 4 };
    expect((await t.app.inject({ method: 'POST', url: '/v1/admin/content/levels', headers: admin, payload: bad })).statusCode).toBe(400);
    const good = { ...forest(), version: 2 };
    expect((await t.app.inject({ method: 'POST', url: '/v1/admin/content/levels', headers: admin, payload: good })).statusCode).toBe(201);
    const man = await t.app.inject({ method: 'GET', url: '/v1/content/manifest' });
    expect(man.json().levels.find((l: { levelId: string }) => l.levelId === 'w1-forest-escape').version).toBe(2);
    const changed = { ...forest(), version: 2, name: 'Changed' };
    expect((await t.app.inject({ method: 'POST', url: '/v1/admin/content/levels', headers: admin, payload: changed })).statusCode).toBe(409);
  });

  it('marks world 1 levels free and later worlds premium in the manifest', async () => {
    const desert = JSON.parse(readFileSync('../content/levels/w2-desert-dunes.json', 'utf8'));
    expect((await t.app.inject({ method: 'POST', url: '/v1/admin/content/levels', headers: admin, payload: desert })).statusCode).toBeLessThan(300);
    const levels = (await t.app.inject({ method: 'GET', url: '/v1/content/manifest' })).json().levels as { levelId: string; world: number; access: string }[];
    expect(levels.find((l) => l.levelId === 'w2-desert-dunes')).toMatchObject({ world: 2, access: 'premium' });
    for (const l of levels) expect(l.access).toBe(l.world === 1 ? 'free' : 'premium');
    expect(accessForWorld(1)).toBe('free');
    expect(accessForWorld(3)).toBe('premium');
  });

  it('health check', async () => {
    expect((await t.app.inject({ method: 'GET', url: '/healthz' })).json()).toEqual({ ok: true });
  });
});
