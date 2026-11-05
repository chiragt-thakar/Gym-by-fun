import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { gymPriceInPaise } from '../src/modules/billing/service.js';
import { admin, paymentLinkRequests, setup, type TestApp } from './helpers.js';

let t: TestApp;
beforeAll(async () => {
  t = await setup();
});
afterAll(async () => t.close());

describe('public web pages', () => {
  it('serves privacy policy and terms with the grievance contact', async () => {
    const p = await t.app.inject({ method: 'GET', url: '/legal/privacy' });
    expect(p.headers['content-type']).toContain('text/html');
    expect(p.body).toContain('never saved');
    expect(p.body).toContain('grievance@motionquest.app');
    const terms = await t.app.inject({ method: 'GET', url: '/legal/terms' });
    expect(terms.body).toContain('not medical advice');
  });

  it('the QR join page opens the app with the code', async () => {
    const r = await t.app.inject({ method: 'GET', url: '/join?code=iron-ab12cd' });
    expect(r.body).toContain('IRON-AB12CD');
    expect(r.body).toContain('intent://join?code=IRON-AB12CD');
    expect((await t.app.inject({ method: 'GET', url: '/join?code=<script>' })).statusCode).toBe(400);
  });

  it('sets security headers and keeps liveness/readiness separate', async () => {
    const r = await t.app.inject({ method: 'GET', url: '/healthz' });
    expect(r.json()).toEqual({ ok: true });
    expect(r.headers['x-content-type-options']).toBe('nosniff');
    expect((await t.app.inject({ method: 'GET', url: '/livez' })).statusCode).toBe(200);
  });
});

describe('gym payment links', () => {
  it('prices include 18% GST', () => {
    expect(gymPriceInPaise('starter', 'monthly')).toEqual({ base: 99900, gst: 17982, total: 117882 });
    expect(gymPriceInPaise('founding', 'monthly')).toBeNull();
  });

  it('creates a Razorpay link carrying the gym id in notes', async () => {
    const g = await t.app.inject({
      method: 'POST',
      url: '/v1/admin/gyms',
      headers: admin,
      payload: { name: 'Core Gym', city: 'Ahmedabad', colours: { primary: '#000000', secondary: '#ffffff' }, ownerPhone: '+919825000002' },
    });
    const id = g.json().id;
    const r = await t.app.inject({ method: 'POST', url: `/v1/admin/gyms/${id}/payment-links`, headers: admin, payload: { plan: 'founding', period: 'yearly' } });
    expect(r.statusCode).toBe(201);
    expect(r.json()).toMatchObject({ shortUrl: 'https://rzp.io/i/test', amountPaise: 943882 });
    expect(paymentLinkRequests.at(-1)).toMatchObject({ notes: { gym_id: id, plan: 'founding', period: 'yearly' }, customer: { contact: '+919825000002' } });
  });
});
