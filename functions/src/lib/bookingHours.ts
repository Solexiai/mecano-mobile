// -----------------------------------------------------------------------------
// Booking hours (Centre de commande > Où et quand ?, owner decision
// 2026-10-26). system_config/booking_hours, edited by adminServiceSettings.
// Without the document, the launch rules apply unchanged (slots 9 h to 19 h
// shown by the app, 1 h lead, 4 days ahead, every day) and the server checks
// only the past and the 4-day window, as before.
// -----------------------------------------------------------------------------
import { db } from "./admin";

/**
 * PAY-08 (2026-10-27) — borne dure sur la fenêtre de réservation. La carte
 * est autorisée à l'acceptation et débitée à la livraison ; une autorisation
 * Stripe expire après ~7 jours (Visa ~5). Au-delà de 5 jours, la capture
 * échouerait systématiquement. Décision de Daniel : 4 jours par défaut, 5 au
 * maximum, sans tâche de ré-autorisation.
 */
export const MAX_BOOKING_DAYS_AHEAD = 5;

export interface BookingHours {
  /** Hours offered, local Québec time (6 to 21). */
  slot_hours: number[];
  /** Minimum notice before a slot. */
  lead_minutes: number;
  /** Days offered, today included (1 to MAX_BOOKING_DAYS_AHEAD). */
  days_ahead: number;
  /** 1 = Monday ... 7 = Sunday. */
  open_weekdays: number[];
}

export const DEFAULT_BOOKING_HOURS: BookingHours = Object.freeze({
  slot_hours: [9, 11, 13, 15, 17, 19],
  lead_minutes: 60,
  days_ahead: 4,
  open_weekdays: [1, 2, 3, 4, 5, 6, 7],
}) as BookingHours;

export const BOOKING_HOURS_DOC = "system_config/booking_hours";
const ZONE = "America/Toronto";

export function parseBookingHours(raw: unknown, errors: string[]): BookingHours {
  const r = raw && typeof raw === "object" && !Array.isArray(raw) ? (raw as Record<string, unknown>) : null;
  if (!r) {
    errors.push("Heures : réglages absents.");
    return { ...DEFAULT_BOOKING_HOURS };
  }
  const ints = (v: unknown, min: number, max: number, label: string): number[] => {
    if (!Array.isArray(v) || v.length === 0 || v.length > 24 ||
        v.some((x) => !Number.isSafeInteger(x) || (x as number) < min || (x as number) > max)) {
      errors.push(`${label} : au moins un choix, entre ${min} et ${max}.`);
      return [];
    }
    return [...new Set(v as number[])].sort((a, b) => a - b);
  };
  const int = (v: unknown, min: number, max: number, label: string): number => {
    if (!Number.isSafeInteger(v) || (v as number) < min || (v as number) > max) {
      errors.push(`${label} : entre ${min} et ${max}.`);
      return min;
    }
    return v as number;
  };
  return {
    slot_hours: ints(r.slot_hours, 6, 21, "Heures offertes"),
    lead_minutes: int(r.lead_minutes, 0, 1440, "Délai minimum (minutes)"),
    days_ahead: int(r.days_ahead, 1, MAX_BOOKING_DAYS_AHEAD, "Jours à l'avance"),
    open_weekdays: ints(r.open_weekdays, 1, 7, "Jours ouverts"),
  };
}

/** The saved hours, or null when the admin never saved any. */
export async function getSavedBookingHours(): Promise<BookingHours | null> {
  const data = (await db.doc(BOOKING_HOURS_DOC).get()).data();
  if (!data) return null;
  const errors: string[] = [];
  const parsed = parseBookingHours(data, errors);
  return errors.length ? null : parsed;
}

function localParts(atMillis: number): { weekday: number; hour: number; minute: number } {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: ZONE, weekday: "short", hour: "2-digit", minute: "2-digit", hourCycle: "h23",
  }).formatToParts(new Date(atMillis));
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? "";
  const weekday = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].indexOf(get("weekday")) + 1;
  return { weekday, hour: Number(get("hour")), minute: Number(get("minute")) };
}

/** Why a scheduled time is refused under the saved hours, or null. */
export function bookingHoursReason(
  requestedAt: string | null | undefined,
  hours: BookingHours,
  now = Date.now()
): "requested_time_past" | "requested_time_too_far" | "requested_time_closed" | null {
  if (!requestedAt) return null;
  const at = Date.parse(requestedAt);
  if (!Number.isFinite(at) || at <= now + hours.lead_minutes * 60_000) return "requested_time_past";
  if (at - now > hours.days_ahead * 24 * 60 * 60_000) return "requested_time_too_far";
  const local = localParts(at);
  if (!hours.open_weekdays.includes(local.weekday) || !hours.slot_hours.includes(local.hour) || local.minute !== 0) {
    return "requested_time_closed";
  }
  return null;
}
