// -----------------------------------------------------------------------------
// missionFees.ts — Late cancellation and wasted-trip fees (owner decision
// 2026-10-22).
//
// Policy:
//   - free before a driver accepts;
//   - after acceptance, free when the pickup is more than 2 hours away;
//     otherwise a late cancellation fee;
//   - a travel fee when the delivery cannot happen on site because of the
//     customer (confirmed by Movi-K, never on the driver's word alone).
// Amount: 30 $ charged to the customer = 25 $ for the driver + 5 $ Movi-K
// administration fee. Taxes are deliberately NOT added here (owner: do not
// touch taxes) — to be validated with the accountant.
//
// The fee is collected by a PARTIAL CAPTURE of the card hold placed when the
// driver accepted (destination charge: the Movi-K share is the Stripe
// application fee, the rest is transferred to the driver's connected
// account). No new card authorization is ever created for a fee.
//
// Owner decision 2026-10-23: the fee is always the full 30 $, even when the
// delivery costs less. The card hold is therefore at least 30 $
// (cardHoldMinor); at completion only the delivery price is captured and the
// rest of the hold is released.
// -----------------------------------------------------------------------------

export const MISSION_FEE_POLICY = Object.freeze({
  version: "MOVIK-FEES-20261023-001",
  total_minor: 3000,
  driver_minor: 2500,
  platform_minor: 500,
  late_cancellation_window_ms: 2 * 60 * 60 * 1000,
});

export type MissionFeeKind = "late_cancellation" | "customer_failed_delivery";

/** Statuses a customer may cancel from (same list as firestore.rules SEC-S1). */
export const CUSTOMER_CANCELLABLE_STATUSES: readonly string[] = [
  "draft", "quoted", "searching_driver", "offered",
  "assigned", "driver_to_pickup", "arrived_at_pickup", "payment_failed",
];

/** A driver has accepted and the pickup has not happened yet. */
export const DRIVER_COMMITTED_STATUSES: readonly string[] = [
  "assigned", "driver_to_pickup", "arrived_at_pickup",
];

export interface MissionFeeAmounts {
  total_minor: number;
  driver_minor: number;
  platform_minor: number;
}

/**
 * Fee amounts in force for one card hold. Since 2026-10-24 the amounts can be
 * set in the admin pricing grid (`pricing_versions/{v}.mission_fee_policy`).
 * They are FROZEN on the payment when the hold is placed
 * (`payments/{id}.mission_fee_policy`), so a later change never alters a
 * booking already accepted. Payments created before that carry nothing and
 * use the 2026-10-23 defaults (30 $ = 25 $ driver + 5 $ Movi-K).
 */
export interface MissionFeePolicy {
  version: string;
  total_minor: number;
  driver_minor: number;
  platform_minor: number;
}

export const DEFAULT_MISSION_FEE_POLICY: MissionFeePolicy = Object.freeze({
  version: MISSION_FEE_POLICY.version,
  total_minor: MISSION_FEE_POLICY.total_minor,
  driver_minor: MISSION_FEE_POLICY.driver_minor,
  platform_minor: MISSION_FEE_POLICY.platform_minor,
});

/** Bounds accepted by the admin pricing grid (cents). */
export const MISSION_FEE_LIMITS = Object.freeze({ min_total_minor: 500, max_total_minor: 10000 });

/**
 * Validates fee amounts (cents). Returns a French message, or null when valid.
 * Same checks for the pricing grid and for any stored policy.
 */
export function missionFeeAmountsError(raw: unknown): string | null {
  if (!raw || typeof raw !== "object") return "Frais d'annulation absents.";
  const r = raw as Record<string, unknown>;
  const total = r.total_minor;
  const driver = r.driver_minor;
  const platform = r.platform_minor;
  if (![total, driver, platform].every((v) => Number.isSafeInteger(v) && (v as number) >= 0)) {
    return "Les frais d'annulation doivent être des montants positifs en cents.";
  }
  if ((total as number) < MISSION_FEE_LIMITS.min_total_minor ||
      (total as number) > MISSION_FEE_LIMITS.max_total_minor) {
    return "Les frais d'annulation doivent être entre 5 $ et 100 $.";
  }
  if ((driver as number) + (platform as number) !== total) {
    return "Part chauffeur + part Movi-K doit égaler exactement les frais d'annulation.";
  }
  if ((driver as number) <= 0) return "Le chauffeur doit recevoir une part des frais d'annulation.";
  return null;
}

/**
 * Policy to use: `raw` when it is a valid policy, else the defaults.
 * `version` falls back to `fallbackVersion`, then to the default version.
 */
export function missionFeePolicyFrom(raw: unknown, fallbackVersion?: string): MissionFeePolicy {
  if (missionFeeAmountsError(raw) !== null) return DEFAULT_MISSION_FEE_POLICY;
  const r = raw as Record<string, unknown>;
  const version = typeof r.version === "string" && r.version.trim()
    ? r.version.trim()
    : fallbackVersion?.trim() || DEFAULT_MISSION_FEE_POLICY.version;
  return {
    version,
    total_minor: r.total_minor as number,
    driver_minor: r.driver_minor as number,
    platform_minor: r.platform_minor as number,
  };
}

/** Card hold placed at driver acceptance: the price, never less than the fee. */
export function cardHoldMinor(
  priceMinor: number,
  policy: MissionFeePolicy = DEFAULT_MISSION_FEE_POLICY
): number {
  if (!Number.isSafeInteger(priceMinor) || priceMinor <= 0) return priceMinor;
  return Math.max(priceMinor, policy.total_minor);
}

/**
 * Splits the fee. The capture can never exceed the card hold: if the hold is
 * below the fee, the fee is reduced to the hold and split in the same ratio.
 */
export function missionFeeAmounts(
  authorizedMinor: number,
  policy: MissionFeePolicy = DEFAULT_MISSION_FEE_POLICY
): MissionFeeAmounts {
  const p = policy;
  if (!Number.isSafeInteger(authorizedMinor) || authorizedMinor <= 0) {
    return { total_minor: 0, driver_minor: 0, platform_minor: 0 };
  }
  if (authorizedMinor >= p.total_minor) {
    return { total_minor: p.total_minor, driver_minor: p.driver_minor, platform_minor: p.platform_minor };
  }
  const platform = Math.round((authorizedMinor * p.platform_minor) / p.total_minor);
  return { total_minor: authorizedMinor, driver_minor: authorizedMinor - platform, platform_minor: platform };
}

/** Planned pickup: the reserved agenda slot, else the requested time, else null (as soon as possible). */
export function missionPickupAtMs(mission: Record<string, any>): number | null {
  // Same sources as driverScheduling.missionRequestedAt (kept dependency-free).
  const raw = mission.scheduling?.pickup_at ?? mission.booking_snapshot?.load?.requested_at ??
    mission.pricing_snapshot?.pre_assignment?.load?.requested_at ?? mission.requested_at ?? null;
  if (typeof raw !== "string") return null;
  const ms = Date.parse(raw);
  return Number.isFinite(ms) ? ms : null;
}

/**
 * True when a customer cancellation is late:
 *   - a driver has accepted (committed status), and
 *   - the driver is already on the way / on site, or the delivery is "as soon
 *     as possible", or the planned pickup is less than 2 hours away.
 * Internal test missions never carry a fee.
 */
export function isLateCancellation(mission: Record<string, any>, nowMs = Date.now()): boolean {
  if (mission.assignment_mode === "internal_test") return false;
  if (typeof mission.driver_id !== "string" || !mission.driver_id) return false;
  if (!DRIVER_COMMITTED_STATUSES.includes(String(mission.status))) return false;
  if (mission.status === "driver_to_pickup" || mission.status === "arrived_at_pickup") return true;
  const pickup = missionPickupAtMs(mission);
  if (pickup === null) return true;
  return pickup - nowMs < MISSION_FEE_POLICY.late_cancellation_window_ms;
}
