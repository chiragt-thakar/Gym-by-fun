import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { setup, type TestApp } from './helpers.js';

let t: TestApp;
beforeAll(async () => {
  t = await setup();
});
afterAll(async () => t.close());

describe('ops', () => {
  it('mints and echoes a request id', async () => {
    const r = await t.app.inject({ method: 'GET', url: '/livez' });
    expect(r.headers['x-request-id']).toMatch(/^[0-9a-f-]{36}$/);
  });

  it('reuses a well-formed incoming x-request-id', async () => {
    const r = await t.app.inject({ method: 'GET', url: '/livez', headers: { 'x-request-id': 'edge-abc.123' } });
    expect(r.headers['x-request-id']).toBe('edge-abc.123');
  });

  it('replaces a malformed incoming x-request-id', async () => {
    const r = await t.app.inject({ method: 'GET', url: '/livez', headers: { 'x-request-id': 'bad id <script>' } });
    expect(r.headers['x-request-id']).not.toBe('bad id <script>');
    expect(r.headers['x-request-id']).toMatch(/^[0-9a-f-]{36}$/);
  });

  it('echoes the request id on errors too', async () => {
    const r = await t.app.inject({ method: 'GET', url: '/v1/me', headers: { 'x-request-id': 'err-1' } });
    expect(r.statusCode).toBe(401);
    expect(r.headers['x-request-id']).toBe('err-1');
  });
});
