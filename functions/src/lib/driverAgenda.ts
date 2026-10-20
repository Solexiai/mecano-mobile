import { invalidArgument } from './errors';
export interface AgendaInterval { start: string; end: string }
export interface DriverAgenda { windows: AgendaInterval[]; blocked: AgendaInterval[] }
// Resource limits, not commercial booking limits.
const MAX_INTERVALS = 200;
function instant(v: unknown): number {
  if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{1,3})?(Z|[+-]\d{2}:\d{2})$/.test(v)) {
    throw invalidArgument('Date avec fuseau horaire requise.');
  }
  const day = v.slice(0, 10);
  const calendarDay = new Date(day + 'T00:00:00Z');
  if (!Number.isFinite(calendarDay.getTime()) || calendarDay.toISOString().slice(0, 10) !== day) {
    throw invalidArgument('Date invalide.');
  }
  const time = Date.parse(v);
  if (!Number.isFinite(time)) throw invalidArgument('Date invalide.');
  return time;
}
function interval(raw: unknown): AgendaInterval {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw invalidArgument('Plage invalide.');
  const v = raw as Record<string, unknown>, start = instant(v.start), end = instant(v.end);
  if (start >= end) throw invalidArgument('La fin doit suivre le début.');
  return { start: new Date(start).toISOString(), end: new Date(end).toISOString() };
}
function intervals(raw: unknown): AgendaInterval[] {
  if (!Array.isArray(raw) || raw.length > MAX_INTERVALS) throw invalidArgument('Liste de plages invalide (maximum 200).');
  const sorted = raw.map(interval).sort((a,b) => a.start.localeCompare(b.start));
  const merged: AgendaInterval[] = [];
  for (const next of sorted) {
    const previous = merged[merged.length - 1];
    if (previous && next.start <= previous.end) {
      if (next.end > previous.end) previous.end = next.end;
    } else merged.push({ ...next });
  }
  return merged;
}
export function normalizeDriverAgenda(raw: unknown): DriverAgenda {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw invalidArgument('Agenda invalide.');
  const data = raw as Record<string, unknown>;
  return { windows: intervals(data.windows), blocked: intervals(data.blocked) };
}
/** Pure evaluation only. No route duration is silently treated as total occupancy.
 * Wiring to dispatch requires an authoritative full occupancy interval. */
export function intervalIsAvailable(agenda: DriverAgenda, requested: AgendaInterval): boolean {
  const slot = interval(requested);
  return agenda.windows.some(w => w.start <= slot.start && w.end >= slot.end) &&
    !agenda.blocked.some(b => b.start < slot.end && slot.start < b.end);
}
