/** Calendar helpers in India Standard Time (UTC+05:30, no DST). */
const IST_OFFSET_MS = 330 * 60 * 1000;

export function istDate(d: Date): string {
  return new Date(d.getTime() + IST_OFFSET_MS).toISOString().slice(0, 10);
}

export function istMonth(d: Date): string {
  return istDate(d).slice(0, 7);
}

export function daysBetween(a: string, b: string): number {
  return Math.round((Date.parse(`${b}T00:00:00Z`) - Date.parse(`${a}T00:00:00Z`)) / 86_400_000);
}

/** ISO week label like 2026-W45, in IST. */
export function isoWeek(d: Date): string {
  const ist = new Date(d.getTime() + IST_OFFSET_MS);
  const t = new Date(Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate()));
  const day = t.getUTCDay() || 7;
  t.setUTCDate(t.getUTCDate() + 4 - day);
  const yearStart = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((t.getTime() - yearStart.getTime()) / 86_400_000 + 1) / 7);
  return `${t.getUTCFullYear()}-W${String(week).padStart(2, '0')}`;
}

/** Start (Monday 00:00 IST) of the ISO week containing d, as a UTC Date. */
export function weekStart(d: Date): Date {
  const ist = new Date(d.getTime() + IST_OFFSET_MS);
  const day = ist.getUTCDay() || 7;
  const monday = Date.UTC(ist.getUTCFullYear(), ist.getUTCMonth(), ist.getUTCDate() - (day - 1));
  return new Date(monday - IST_OFFSET_MS);
}

export function addDays(d: Date, n: number): Date {
  return new Date(d.getTime() + n * 86_400_000);
}

export function addMonths(d: Date, n: number): Date {
  const r = new Date(d);
  r.setUTCMonth(r.getUTCMonth() + n);
  return r;
}
