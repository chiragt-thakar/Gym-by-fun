import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';

import { purgeDeletedAccounts } from '../src/modules/identity/routes.js';
import { runJob } from '../src/modules/reports/queue.js';
import { buildWeeklyReport, formatReport, sendWeeklyReports } from '../src/modules/reports/service.js';
import { setup, type TestApp } from './helpers.js';

let t: TestApp;
const START = new Date('2026-11-04T10:00:00Z');
const DAY = 86_400_000;

beforeAll(async () => {
  t = await setup();
});
afterAll(async () => t.close());
beforeEach(async () => {
  t.clock.now = START;
  t.whatsapp.length = 0;
  await t.ctx.db.deleteFrom('report_runs').execute();
  await t.ctx.db.deleteFrom('gyms').execute();
});

async function addGym(over: { name?: string; status?: string; licenceUntil?: Date; phone?: string | null } = {}) {
  const phone = over.phone === undefined ? '+919800000001' : over.phone;
  const g = await t.ctx.db
    .insertInto('gyms')
    .values({
      name: over.name ?? 'Iron Temple',
      city: 'Pune',
      colours: JSON.stringify({ primary: '#123456' }),
      plan: 'starter',
      status: over.status ?? 'active',
      licence_until: over.licenceUntil ?? new Date(START.getTime() + 90 * DAY),
      owner_phone_enc: phone ? t.ctx.pii.encrypt(phone) : null,
    } as never)
    .returning('id')
    .executeTakeFirstOrThrow();
  return g.id;
}

async function addUser(deletedAt: Date | null) {
  const u = await t.ctx.db
    .insertInto('users')
    .values({ age_confirmed_at: START, deleted_at: deletedAt } as never)
    .returning('id')
    .executeTakeFirstOrThrow();
  return u.id;
}

describe('purgeDeletedAccounts', () => {
  it('hard-deletes only accounts past the grace window', async () => {
    const grace = t.ctx.config.DELETION_GRACE_DAYS;
    const live = await addUser(null);
    const old = await addUser(new Date(START.getTime() - (grace + 1) * DAY));
    const recent = await addUser(new Date(START.getTime() - (grace - 1) * DAY));

    expect(await purgeDeletedAccounts(t.ctx)).toBe(1);
    const left = (await t.ctx.db.selectFrom('users').select('id').execute()).map((u) => u.id);
    expect(left).toContain(live);
    expect(left).toContain(recent);
    expect(left).not.toContain(old);

    // Advance the test clock past the recent account's window.
    t.clock.now = new Date(START.getTime() + 2 * DAY);
    expect(await purgeDeletedAccounts(t.ctx)).toBe(1);
    const after = (await t.ctx.db.selectFrom('users').select('id').execute()).map((u) => u.id);
    expect(after).toContain(live);
    expect(after).not.toContain(recent);
  });
});

describe('sendWeeklyReports', () => {
  it('skips gyms without an owner phone', async () => {
    await addGym({ phone: null });
    await addGym({ name: 'Has Phone' });
    expect(await sendWeeklyReports(t.ctx)).toEqual({ sent: 1, skipped: 1 });
    expect(t.whatsapp).toHaveLength(1);
    expect(t.whatsapp[0]!.phone).toBe('+919800000001');
  });

  it('ignores lapsed and cancelled gyms and expired licences', async () => {
    await addGym({ status: 'lapsed' });
    await addGym({ status: 'cancelled' });
    await addGym({ status: 'active', licenceUntil: new Date(START.getTime() - DAY) });
    await addGym({ status: 'pilot', name: 'Pilot Gym' });
    expect(await sendWeeklyReports(t.ctx)).toEqual({ sent: 1, skipped: 0 });
    expect(t.whatsapp).toHaveLength(1);
    expect(t.whatsapp[0]!.body).toContain('Pilot Gym');
  });

  it('sends once per week when re-run', async () => {
    await addGym();
    expect(await sendWeeklyReports(t.ctx)).toEqual({ sent: 1, skipped: 0 });
    expect(await sendWeeklyReports(t.ctx)).toEqual({ sent: 0, skipped: 1 });
    expect(t.whatsapp).toHaveLength(1);
  });

  it('releases the claim when the provider throws so a retry sends', async () => {
    const gymId = await addGym();
    const real = t.ctx.providers.whatsapp;
    t.ctx.providers.whatsapp = {
      sendText: async () => {
        throw new Error('provider down');
      },
    };
    try {
      await expect(sendWeeklyReports(t.ctx)).rejects.toThrow('provider down');
    } finally {
      t.ctx.providers.whatsapp = real;
    }
    const runs = await t.ctx.db.selectFrom('report_runs').selectAll().where('gym_id', '=', gymId).execute();
    expect(runs).toHaveLength(0);

    expect(await sendWeeklyReports(t.ctx)).toEqual({ sent: 1, skipped: 0 });
    expect(t.whatsapp).toHaveLength(1);
  });
});

describe('formatReport', () => {
  it('renders an empty gym with only the headline lines', async () => {
    const gymId = await addGym({ name: 'Quiet Gym' });
    const r = await buildWeeklyReport(t.ctx, gymId, START);
    expect(r).toMatchObject({ members: 0, activeMembers: 0, sessions: 0, activeMinutes: 0, goingQuiet: [], topPlayers: [], quests: [] });
    expect(formatReport(r)).toBe(
      [`*Quiet Gym — Joynetic weekly report (${r.week})*`, '', 'Active members: 0 of 0 sharing', 'Home sessions: 0 · 0 active minutes'].join(
        '\n',
      ),
    );
  });
});

describe('runJob', () => {
  it('dispatches weekly-gym-reports to sendWeeklyReports', async () => {
    await addGym();
    expect(await runJob(t.ctx, 'weekly-gym-reports')).toEqual({ sent: 1, skipped: 0 });
    expect(t.whatsapp).toHaveLength(1);
  });

  it('dispatches purge-deleted-accounts to purgeDeletedAccounts', async () => {
    const old = await addUser(new Date(START.getTime() - (t.ctx.config.DELETION_GRACE_DAYS + 5) * DAY));
    const r = await runJob(t.ctx, 'purge-deleted-accounts');
    expect(r).toEqual({ purged: 1 });
    expect(await t.ctx.db.selectFrom('users').select('id').where('id', '=', old).executeTakeFirst()).toBeUndefined();
    expect(t.whatsapp).toHaveLength(0);
  });

  it('rejects unknown job names', async () => {
    await expect(runJob(t.ctx, 'nope')).rejects.toThrow('Unknown job nope');
  });
});
