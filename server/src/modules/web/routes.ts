import type { FastifyInstance } from 'fastify';
import { z } from 'zod';

import type { AppContext } from '../../context.js';
import { parse } from '../../lib/validate.js';
import { privacyPolicy, termsOfUse } from './legal.js';

const esc = (s: string) => s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

export function page(title: string, body: string) {
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(title)} · Joynetic</title><style>body{font-family:system-ui,sans-serif;max-width:720px;margin:24px auto;padding:0 16px;line-height:1.55;color:#1b1b1b}
h1{font-size:28px}h2{font-size:20px;margin-top:28px}a.btn{display:block;text-align:center;background:#1b5e20;color:#fff;padding:16px;border-radius:12px;text-decoration:none;font-size:20px;margin:12px 0}
code{font-size:24px;letter-spacing:2px}</style></head><body>${body}</body></html>`;
}

/** Public web pages: legal documents and the QR-poster join link. */
export async function webRoutes(app: FastifyInstance, ctx: AppContext) {
  const { GRIEVANCE_EMAIL: email, PLAY_STORE_URL: store } = ctx.config;

  app.get('/legal/privacy', async (_req, reply) => reply.type('text/html; charset=utf-8').send(page('Privacy policy', privacyPolicy(email))));
  app.get('/legal/terms', async (_req, reply) => reply.type('text/html; charset=utf-8').send(page('Terms of use', termsOfUse(email))));

  /**
   * Target of the gym QR poster. Opens the app with the code filled in if it
   * is installed, otherwise shows the Play Store link and the code.
   */
  app.get('/join', async (req, reply) => {
    const { code } = parse(z.object({ code: z.string().regex(/^[A-Za-z]{1,4}-[A-Za-z0-9]{6}$/) }), req.query);
    const c = code.toUpperCase();
    const intent = `intent://join?code=${encodeURIComponent(c)}#Intent;scheme=motionquest;package=app.motionquest;S.browser_fallback_url=${encodeURIComponent(store)};end`;
    return reply.type('text/html; charset=utf-8').send(
      page(
        'Join your gym crew',
        `<h1>Join your gym crew on Joynetic</h1>
<p>Your gym code:</p><p><code>${esc(c)}</code></p>
<a class="btn" href="${esc(intent)}">Open in Joynetic</a>
<a class="btn" href="${esc(store)}">Get Joynetic on Google Play</a>
<p>After installing, open <b>Gym Crew</b> and enter the code above. Members of partner gyms get Premium free.</p>
<p style="color:#666;font-size:14px">Adults 18+. A game for general fitness, not medical advice. Video never leaves your phone.</p>`,
      ),
    );
  });
}
