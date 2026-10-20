import { invalidArgument } from './errors';
import { AgendaInterval } from './driverAgenda';
export interface WeeklyWindow {
    day: number;
    start_minute: number;
    end_minute: number;
}
export interface DayException {
    date: string;
    windows: {
        start_minute: number;
        end_minute: number;
    }[];
}
export interface Recurrence {
    time_zone: string;
    weekly: WeeklyWindow[];
    exceptions: DayException[];
    pause_before_minutes: number;
    pause_after_minutes: number;
}
export function validDay(v: unknown): v is string {
    if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(v))
        return false;
    const d = new Date(v + 'T00:00:00Z');
    return Number.isFinite(d.getTime()) && d.toISOString().slice(0, 10) === v;
}
function integer(v: unknown, min: number, max: number): number {
    if (typeof v !== 'number' || !Number.isSafeInteger(v) || v < min || v > max)
        throw invalidArgument('Valeur d’horaire invalide.');
    return v;
}
function minuteWindow(raw: unknown) {
    const v = raw as Record<string, unknown>;
    if (!v || typeof v !== 'object')
        throw invalidArgument('Plage récurrente invalide.');
    const start_minute = integer(v.start_minute, 0, 1439), end_minute = integer(v.end_minute, 1, 1440);
    if (end_minute <= start_minute)
        throw invalidArgument('Séparez les plages traversant minuit en deux journées.');
    return { start_minute, end_minute };
}
export function normalizeRecurrence(raw: unknown): Recurrence {
    const r = raw as Record<string, unknown>;
    if (!r || typeof r !== 'object' || Array.isArray(r))
        throw invalidArgument('Récurrence invalide.');
    if (typeof r.time_zone !== 'string')
        throw invalidArgument('Fuseau horaire requis.');
    try {
        new Intl.DateTimeFormat('en', { timeZone: r.time_zone }).format();
    }
    catch {
        throw invalidArgument('Fuseau horaire invalide.');
    }
    if (!Array.isArray(r.weekly) || r.weekly.length > 70 || !Array.isArray(r.exceptions) || r.exceptions.length > 366)
        throw invalidArgument('Trop de plages.');
    const weekly = r.weekly.map(v => ({ ...minuteWindow(v), day: integer(v?.day, 1, 7) }));
    const dates = new Set<string>();
    const exceptions: DayException[] = r.exceptions.map(v => {
        if (!validDay(v?.date) || dates.has(v.date) || !Array.isArray(v.windows) || v.windows.length > 10)
            throw invalidArgument('Exception de date invalide ou doublonnée.');
        dates.add(v.date);
        return { date: v.date, windows: v.windows.map(minuteWindow) };
    });
    for (const windows of [...Array.from({ length: 7 }, (_, i) => weekly.filter(w => w.day === i + 1)), ...exceptions.map(e => e.windows)]) {
        windows.sort((a, b) => a.start_minute - b.start_minute);
        if (windows.some((w, i) => i > 0 && windows[i - 1].end_minute > w.start_minute))
            throw invalidArgument('Plages récurrentes superposées.');
    }
    return { time_zone: r.time_zone, weekly, exceptions,
        pause_before_minutes: integer(r.pause_before_minutes ?? 0, 0, 1440),
        pause_after_minutes: integer(r.pause_after_minutes ?? 0, 0, 1440) };
}
function wallParts(ms: number, timeZone: string): number {
    const parts = new Intl.DateTimeFormat('en-CA', { timeZone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23' }).formatToParts(ms);
    const p = Object.fromEntries(parts.map(x => [x.type, x.value]));
    return Date.UTC(+p.year, +p.month - 1, +p.day, +p.hour, +p.minute, +p.second);
}
/** Both UTC occurrences of a repeated wall time are retained. Nonexistent
 * spring-forward boundaries produce no window, never an invented time. */
export function wallInstants(day: string, minute: number, zone: string): number[] {
    const target = Date.parse(day + 'T00:00:00Z') + minute * 60000;
    const offsets = new Set([-36, -12, 0, 12, 36].map(h => {
        const ms = target + h * 3600000;
        return wallParts(ms, zone) - ms;
    }));
    return [...offsets].map(o => target - o).filter(ms => wallParts(ms, zone) === target).sort((a, b) => a - b);
}
export function expandRecurrence(r: Recurrence, slot: AgendaInterval): AgendaInterval[] {
    const from = Date.parse(slot.start) - 86400000, to = Date.parse(slot.end) + 86400000;
    if (!Number.isFinite(from) || !Number.isFinite(to) || to - from > 370 * 86400000)
        throw invalidArgument('Période de consultation trop grande.');
    const result: AgendaInterval[] = [];
    for (let ms = Date.parse(new Date(from).toISOString().slice(0, 10) + 'T00:00:00Z'); ms <= to; ms += 86400000) {
        const d = new Date(ms), day = d.toISOString().slice(0, 10), weekday = d.getUTCDay() || 7;
        const exception = r.exceptions.find(e => e.date === day);
        for (const w of exception ? exception.windows : r.weekly.filter(w => w.day === weekday)) {
            const starts = wallInstants(day, w.start_minute, r.time_zone), ends = wallInstants(day, w.end_minute, r.time_zone);
            if (starts.length && ends.length)
                result.push({ start: new Date(starts[0]).toISOString(), end: new Date(ends[ends.length - 1]).toISOString() });
        }
    }
    return result;
}
