// -----------------------------------------------------------------------------
// Special conditions (Centre de commande > 5, owner decision 2026-10-26).
// system_config/special_conditions, edited by adminSpecialConditions:
//   - a "difficult conditions" supplement (storm, ice, heavy rain, event),
//     a percentage or a fixed amount, for a period, with a reason shown to
//     the customer before paying; it ends by itself;
//   - a service pause: no new price or booking, with a message.
// A quote already given keeps its price (the supplement is locked in it).
// -----------------------------------------------------------------------------
import { db } from "./admin";
import { SurchargeRuleDoc } from "./types";

export const CONDITION_REASONS = ["snow", "ice", "rain", "event"] as const;
export type ConditionReason = typeof CONDITION_REASONS[number];

export const CONDITION_LABELS: Record<ConditionReason, { fr: string; en: string; es: string }> = {
  snow: { fr: "Tempête de neige", en: "Snowstorm", es: "Tormenta de nieve" },
  ice: { fr: "Verglas", en: "Freezing rain", es: "Hielo" },
  rain: { fr: "Pluie forte", en: "Heavy rain", es: "Lluvia fuerte" },
  event: { fr: "Événement", en: "Event", es: "Evento" },
};

export interface SpecialConditionsDoc {
  surcharge: {
    active: boolean;
    reason: ConditionReason;
    mode: "percentage" | "fixed_amount";
    /** Fraction (0.15 = 15 %) or dollars. */
    value: number;
    starts_at_ms: number;
    ends_at_ms: number;
  };
  pause: { active: boolean; message: string };
}

export const SPECIAL_CONDITIONS_DOC = "system_config/special_conditions";
export const CONDITION_LIMITS = Object.freeze({ percentage: 0.5, fixed: 100, max_hours: 72 });

export function defaultSpecialConditions(): SpecialConditionsDoc {
  return {
    surcharge: { active: false, reason: "snow", mode: "percentage", value: 0, starts_at_ms: 0, ends_at_ms: 0 },
    pause: { active: false, message: "" },
  };
}

export function parseSpecialConditions(raw: unknown, errors: string[]): SpecialConditionsDoc {
  const out = defaultSpecialConditions();
  const r = raw && typeof raw === "object" && !Array.isArray(raw) ? (raw as Record<string, unknown>) : null;
  if (!r) {
    errors.push("Conditions spéciales : réglages absents.");
    return out;
  }
  const s = (r.surcharge && typeof r.surcharge === "object" ? r.surcharge : {}) as Record<string, unknown>;
  const p = (r.pause && typeof r.pause === "object" ? r.pause : {}) as Record<string, unknown>;
  out.surcharge.active = s.active === true;
  if (!(CONDITION_REASONS as readonly unknown[]).includes(s.reason)) {
    if (out.surcharge.active) errors.push("Supplément : raison invalide.");
  } else out.surcharge.reason = s.reason as ConditionReason;
  out.surcharge.mode = s.mode === "fixed_amount" ? "fixed_amount" : "percentage";
  const max = out.surcharge.mode === "percentage" ? CONDITION_LIMITS.percentage : CONDITION_LIMITS.fixed;
  if (typeof s.value === "number" && Number.isFinite(s.value) && s.value >= 0 && s.value <= max) {
    out.surcharge.value = Math.round(s.value * 10000) / 10000;
  } else if (out.surcharge.active) {
    errors.push(out.surcharge.mode === "percentage"
      ? "Supplément : pourcentage entre 0 et 50 %." : "Supplément : montant entre 0 et 100 $.");
  }
  const start = s.starts_at_ms, end = s.ends_at_ms;
  if (Number.isSafeInteger(start) && Number.isSafeInteger(end) && (end as number) > (start as number) &&
      (end as number) - (start as number) <= CONDITION_LIMITS.max_hours * 3600_000) {
    out.surcharge.starts_at_ms = start as number;
    out.surcharge.ends_at_ms = end as number;
  } else if (out.surcharge.active) {
    errors.push(`Supplément : une fin après le début, ${CONDITION_LIMITS.max_hours} h au plus.`);
  }
  if (out.surcharge.active && out.surcharge.value <= 0) errors.push("Supplément : montant requis.");
  out.pause.active = p.active === true;
  out.pause.message = typeof p.message === "string" ? p.message.trim().slice(0, 300) : "";
  if (out.pause.active && !out.pause.message) errors.push("Pause : message au client requis.");
  return out;
}

export async function getSpecialConditions(): Promise<SpecialConditionsDoc | null> {
  const data = (await db.doc(SPECIAL_CONDITIONS_DOC).get()).data();
  if (!data) return null;
  const errors: string[] = [];
  const parsed = parseSpecialConditions(data, errors);
  return errors.length ? null : parsed;
}

/** The supplement rule in force now, or null. */
export function activeConditionSurcharge(
  conditions: SpecialConditionsDoc | null,
  now = Date.now()
): (SurchargeRuleDoc & { reason: ConditionReason }) | null {
  const s = conditions?.surcharge;
  if (!s?.active || s.value <= 0 || now < s.starts_at_ms || now >= s.ends_at_ms) return null;
  return { id: `condition_${s.reason}`, mode: s.mode, value: s.value, enabled: true, reason: s.reason };
}

/** The pause message when the service is paused, or null. */
export function pauseMessage(conditions: SpecialConditionsDoc | null): string | null {
  return conditions?.pause.active ? conditions.pause.message : null;
}
