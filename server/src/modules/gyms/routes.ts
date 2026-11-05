import type { FastifyInstance } from 'fastify';
import QRCode from 'qrcode';
import { z } from 'zod';

import type { AppContext } from '../../context.js';
import { requireAdmin, requireUser } from '../../lib/auth.js';
import { gymCode, keyedHash, randomToken, safeEqual } from '../../lib/crypto.js';
import { badRequest, forbidden, notFound } from '../../lib/errors.js';
import { addDays, isoWeek } from '../../lib/time.js';
import { parse } from '../../lib/validate.js';
import { gymPriceInPaise } from '../billing/service.js';
import { buildWeeklyReport, formatReport } from '../reports/service.js';
import { activeMembership, crewBoard, joinGym, leaveGym } from './service.js';

const hex = z.string().regex(/^#[0-9a-fA-F]{6}$/);

export async function gymRoutes(app: FastifyInstance, ctx: AppContext) {
  const auth = requireUser(ctx);
  const admin = requireAdmin(ctx);

  app.post('/gyms/join', { preHandler: auth }, async (req) => {
    const body = parse(z.object({ code: z.string().min(4).max(20), shareActivity: z.boolean() }), req.body);
    const m = await joinGym(ctx, req.userId, body.code, body.shareActivity);
    return { gym: m && branding(m) };
  });

  app.delete('/gyms/membership', { preHandler: auth }, async (req, reply) => {
    await leaveGym(ctx, req.userId);
    return reply.code(204).send();
  });

  app.get('/gyms/mine', { preHandler: auth }, async (req) => {
    const m = await activeMembership(ctx, req.userId);
    if (!m) return { gym: null, quests: [] };
    const quests = await ctx.db
      .selectFrom('trainer_quests')
      .select(['id', 'level_id', 'title', 'due_at'])
      .where('gym_id', '=', m.id)
      .where('due_at', '>=', ctx.now())
      .orderBy('due_at')
      .limit(5)
      .execute();
    return {
      gym: branding(m),
      quests: quests.map((q) => ({ id: q.id, levelId: q.level_id, title: q.title, dueAt: q.due_at })),
    };
  });

  app.get('/crews/:gymId/board', { preHandler: auth }, async (req) => {
    const { gymId } = parse(z.object({ gymId: z.string().uuid() }), req.params);
    const { week } = parse(z.object({ week: z.string().regex(/^\d{4}-W\d{2}$/).optional() }), req.query);
    const m = await activeMembership(ctx, req.userId);
    if (!m || m.id !== gymId) throw forbidden('not_a_member');
    const w = week ?? isoWeek(ctx.now());
    return { week: w, entries: await crewBoard(ctx, gymId, w, req.userId) };
  });

  // ---------- Gym admin (operator tooling, x-admin-key) ----------

  app.post('/admin/gyms', { preHandler: admin }, async (req, reply) => {
    const body = parse(
      z.object({
        name: z.string().min(2).max(80),
        city: z.string().min(2).max(40),
        logoUrl: z.string().url().nullish(),
        colours: z.object({ primary: hex, secondary: hex }),
        plan: z.enum(['pilot', 'founding', 'starter', 'growth', 'chain']).default('pilot'),
        licenceDays: z.number().int().min(1).max(800).default(56),
        ownerName: z.string().max(80).nullish(),
        ownerPhone: z.string().regex(/^\+91[6-9]\d{9}$/).nullish(),
      }),
      req.body,
    );
    const trainerKey = randomToken(18);
    const gym = await ctx.db
      .insertInto('gyms')
      .values({
        name: body.name,
        city: body.city,
        logo_url: body.logoUrl ?? null,
        colours: JSON.stringify(body.colours),
        plan: body.plan,
        status: body.plan === 'pilot' ? 'pilot' : 'active',
        licence_until: addDays(ctx.now(), body.licenceDays),
        owner_name: body.ownerName ?? null,
        owner_phone_enc: body.ownerPhone ? ctx.pii.encrypt(body.ownerPhone) : null,
        trainer_key_hash: keyedHash(ctx.config.PII_HASH_PEPPER, trainerKey),
      })
      .returning(['id', 'name', 'licence_until', 'status'])
      .executeTakeFirstOrThrow();
    // The trainer key is shown once; only its hash is stored.
    return reply.code(201).send({ ...gym, trainerKey });
  });

  app.post('/admin/gyms/:id/codes', { preHandler: admin }, async (req, reply) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    const body = parse(z.object({ maxMembers: z.number().int().min(1).max(5000).default(300), validDays: z.number().int().min(1).max(800).default(365) }), req.body ?? {});
    const gym = await ctx.db.selectFrom('gyms').select(['id', 'name']).where('id', '=', id).executeTakeFirst();
    if (!gym) throw notFound('gym_not_found');
    const code = gymCode(gym.name);
    await ctx.db
      .insertInto('gym_codes')
      .values({ code, gym_id: id, max_members: body.maxMembers, expires_at: addDays(ctx.now(), body.validDays) })
      .execute();
    return reply.code(201).send({ code, maxMembers: body.maxMembers });
  });

  /** Printable A4 QR poster for the reception desk (SVG). */
  app.get('/admin/gyms/:id/poster', { preHandler: admin }, async (req, reply) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    const { code } = parse(z.object({ code: z.string().min(4) }), req.query);
    const gym = await ctx.db.selectFrom('gyms').select(['name', 'colours']).where('id', '=', id).executeTakeFirst();
    const c = await ctx.db.selectFrom('gym_codes').select('code').where('code', '=', code).where('gym_id', '=', id).executeTakeFirst();
    if (!gym || !c) throw notFound();
    const link = `${ctx.config.PUBLIC_BASE_URL}/join?code=${encodeURIComponent(c.code)}`;
    const qr = await QRCode.toString(link, { type: 'svg', margin: 0, width: 360 });
    return reply.type('image/svg+xml').send(posterSvg(gym.name, gym.colours.primary, c.code, qr));
  });

  /** Payment link for a gym licence (paid outside the app via Razorpay). */
  app.post('/admin/gyms/:id/payment-links', { preHandler: admin }, async (req, reply) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    const body = parse(z.object({ plan: z.enum(['founding', 'starter', 'growth']), period: z.enum(['monthly', 'yearly']) }), req.body);
    const price = gymPriceInPaise(body.plan, body.period);
    if (!price) throw badRequest('plan_period_unavailable');
    const gym = await ctx.db.selectFrom('gyms').select(['name', 'owner_name', 'owner_phone_enc']).where('id', '=', id).executeTakeFirst();
    if (!gym) throw notFound('gym_not_found');
    const link = await ctx.providers.paymentLinks.create({
      amountPaise: price.total,
      description: `MotionQuest ${body.plan} licence (${body.period}) for ${gym.name}, incl. 18% GST`,
      customer: { name: gym.owner_name ?? undefined, contact: gym.owner_phone_enc ? ctx.pii.decrypt(gym.owner_phone_enc) : undefined },
      notes: { gym_id: id, plan: body.plan, period: body.period },
    });
    return reply.code(201).send({ ...link, amountPaise: price.total, basePaise: price.base, gstPaise: price.gst });
  });

  app.post('/admin/gyms/:id/quests', { preHandler: admin }, async (req, reply) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    const gym = await ctx.db.selectFrom('gyms').select('id').where('id', '=', id).executeTakeFirst();
    if (!gym) throw notFound('gym_not_found');
    const q = await createQuest(ctx, id, req.body);
    return reply.code(201).send(q);
  });

  app.get('/admin/gyms/:id/report', { preHandler: admin }, async (req) => {
    const { id } = parse(z.object({ id: z.string().uuid() }), req.params);
    const report = await buildWeeklyReport(ctx, id, ctx.now());
    return { report, text: formatReport(report) };
  });

  // ---------- Trainer quests page (per-gym trainer key) ----------

  app.get('/trainer/:gymId', async (req, reply) => {
    const { gymId } = parse(z.object({ gymId: z.string().uuid() }), req.params);
    const { key } = parse(z.object({ key: z.string().min(10) }), req.query);
    const gym = await trainerGym(ctx, gymId, key);
    const quests = await ctx.db.selectFrom('trainer_quests').selectAll().where('gym_id', '=', gymId).orderBy('due_at', 'desc').limit(20).execute();
    return reply.type('text/html; charset=utf-8').send(trainerPage(gym.name, gymId, key, quests));
  });

  app.post('/trainer/:gymId/quests', async (req, reply) => {
    const { gymId } = parse(z.object({ gymId: z.string().uuid() }), req.params);
    const { key } = parse(z.object({ key: z.string().min(10) }), req.query);
    await trainerGym(ctx, gymId, key);
    const q = await createQuest(ctx, gymId, req.body);
    return reply.code(201).send(q);
  });
}

async function trainerGym(ctx: AppContext, gymId: string, key: string) {
  const gym = await ctx.db.selectFrom('gyms').select(['name', 'trainer_key_hash']).where('id', '=', gymId).executeTakeFirst();
  if (!gym?.trainer_key_hash || !safeEqual(gym.trainer_key_hash, keyedHash(ctx.config.PII_HASH_PEPPER, key))) throw forbidden();
  return gym;
}

async function createQuest(ctx: AppContext, gymId: string, raw: unknown) {
  const body = parse(
    z.object({ levelId: z.string().regex(/^w\d+-[a-z0-9-]+$/), title: z.string().min(2).max(80), dueAt: z.string().datetime() }),
    raw,
  );
  const level = await ctx.db.selectFrom('content_versions').select('level_id').where('level_id', '=', body.levelId).executeTakeFirst();
  if (!level) throw notFound('level_not_found');
  return ctx.db
    .insertInto('trainer_quests')
    .values({ gym_id: gymId, level_id: body.levelId, title: body.title, due_at: body.dueAt })
    .returning(['id', 'level_id', 'title', 'due_at'])
    .executeTakeFirstOrThrow();
}

function branding(m: { id: string; name: string; logo_url: string | null; colours: { primary: string; secondary: string } }) {
  return { id: m.id, name: m.name, logoUrl: m.logo_url, colours: m.colours };
}

const esc = (s: string) => s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);

function posterSvg(gymName: string, colour: string, code: string, qrSvg: string) {
  const inner = qrSvg.replace(/^<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');
  return `<svg xmlns="http://www.w3.org/2000/svg" width="595" height="842" viewBox="0 0 595 842">
  <rect width="595" height="842" fill="#ffffff"/>
  <rect width="595" height="150" fill="${esc(colour)}"/>
  <text x="297" y="70" font-family="sans-serif" font-size="34" font-weight="700" fill="#fff" text-anchor="middle">${esc(gymName)}</text>
  <text x="297" y="115" font-family="sans-serif" font-size="22" fill="#fff" text-anchor="middle">Crew on MotionQuest</text>
  <text x="297" y="210" font-family="sans-serif" font-size="24" fill="#222" text-anchor="middle">Keep moving on rest days. Play with your body.</text>
  <g transform="translate(117,250)"><svg viewBox="0 0 360 360" width="360" height="360">${inner}</svg></g>
  <text x="297" y="660" font-family="sans-serif" font-size="20" fill="#444" text-anchor="middle">Scan, install, and enter your gym code:</text>
  <text x="297" y="715" font-family="monospace" font-size="44" font-weight="700" fill="#111" text-anchor="middle">${esc(code)}</text>
  <text x="297" y="790" font-family="sans-serif" font-size="14" fill="#777" text-anchor="middle">Adults 18+. A game for general fitness, not medical advice. Video never leaves your phone.</text>
</svg>`;
}

function trainerPage(gymName: string, gymId: string, key: string, quests: { title: string; level_id: string; due_at: Date | string }[]) {
  const rows = quests.map((q) => `<li><b>${esc(q.title)}</b> — ${esc(q.level_id)}, due ${esc(new Date(q.due_at).toDateString())}</li>`).join('');
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Trainer quests</title><style>body{font-family:system-ui,sans-serif;max-width:560px;margin:24px auto;padding:0 16px}
input,select,button{font-size:18px;padding:10px;width:100%;margin:6px 0;box-sizing:border-box}button{background:#1b5e20;color:#fff;border:0;border-radius:8px}</style></head>
<body><h1>${esc(gymName)}: home quests</h1><p>Assign a rest-day quest to your members.</p>
<form id="f"><label>Title<input name="title" required maxlength="80" placeholder="Rest-day forest run"></label>
<label>Level<select name="levelId"><option value="w1-forest-escape">Forest Escape</option></select></label>
<label>Due<input name="dueAt" type="datetime-local" required></label><button>Assign quest</button></form><p id="msg"></p>
<h2>Recent quests</h2><ul>${rows || '<li>None yet</li>'}</ul>
<script>document.getElementById('f').onsubmit=async(e)=>{e.preventDefault();const d=Object.fromEntries(new FormData(e.target));
d.dueAt=new Date(d.dueAt).toISOString();const r=await fetch('/v1/trainer/${gymId}/quests?key=${encodeURIComponent(key)}',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify(d)});
document.getElementById('msg').textContent=r.ok?'Quest assigned.':'Could not assign the quest.';if(r.ok)location.reload();};</script></body></html>`;
}
