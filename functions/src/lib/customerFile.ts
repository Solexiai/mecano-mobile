// -----------------------------------------------------------------------------
// customerFile.ts — fiche client du service client (Daniel, 2026-11-10).
//
// Calculs purs (testés en unitaire) à partir des documents lus par
// getAdminCustomerFile : chiffres clés, pastilles (Nouveau / Fidèle /
// À surveiller) et mise en forme des livraisons, paiements et devis.
// Lecture seulement : rien ici ne modifie un paiement, un tarif ou une mission.
// -----------------------------------------------------------------------------

type Doc = Record<string, any>;

export type CustomerBadge = "new" | "loyal" | "watch";

export type CustomerPaymentKind =
  | "deposit"
  | "delivery"
  | "tip"
  | "late_cancellation"
  | "failed_delivery"
  | "fee";

const PAID_STATUSES = ["captured", "partially_refunded", "refunded"];

export function millisOf(value: unknown): number | null {
  if (!value) return null;
  const v = value as { toMillis?: () => number };
  if (typeof v.toMillis === "function") return v.toMillis();
  if (typeof value === "string") {
    const ms = Date.parse(value);
    return Number.isFinite(ms) ? ms : null;
  }
  return null;
}

export function isoOf(value: unknown): string | null {
  const ms = millisOf(value);
  return ms === null ? null : new Date(ms).toISOString();
}

function int(value: unknown): number {
  return Number.isSafeInteger(value) ? (value as number) : 0;
}

export function paymentKind(payment: Doc): CustomerPaymentKind {
  if (payment.purpose === "deposit") return "deposit";
  if (payment.purpose === "tip") return "tip";
  if (payment.capture_purpose === "mission_fee") {
    if (payment.fee_kind === "late_cancellation") return "late_cancellation";
    if (payment.fee_kind === "customer_failed_delivery") return "failed_delivery";
    return "fee";
  }
  return "delivery";
}

/** Paiement à surveiller : capture refusée ou abandonnée après relances. */
export function isProblemPayment(payment: Doc): boolean {
  return payment.status === "capture_failed" ||
    (payment.status === "failed" && payment.failure_code === "capture_abandoned_after_retries");
}

/** « 12 rue Principale, Granby », ou la ville seule pour un analyste. */
export function addressText(address: unknown, cityOnly: boolean): string {
  if (!address || typeof address !== "object") return "";
  const a = address as Doc;
  const city = typeof a.city === "string" ? a.city.trim() : "";
  if (cityOnly) return city;
  return [a.line1, city].filter((v) => typeof v === "string" && v.trim()).join(", ");
}

/** « ••• ••• 1234 » : un analyste voit seulement les 4 derniers chiffres. */
export function maskPhone(phone: unknown): string | null {
  if (typeof phone !== "string" || !phone.trim()) return null;
  const digits = phone.replace(/\D/g, "");
  return digits.length >= 4 ? `••• ••• ${digits.slice(-4)}` : "•••";
}

export function stripePaymentUrl(payment: Doc): string | null {
  const pi = payment.provider_payment_intent_id;
  if (typeof pi !== "string" || !pi.startsWith("pi_")) return null;
  const test = payment.stripe_environment === "test" ? "test/" : "";
  return `https://dashboard.stripe.com/${test}payments/${pi}`;
}

export interface CustomerStats {
  deliveries: number;
  completed: number;
  cancelled: number;
  active: number;
  spentMinor: number;
  tipsMinor: number;
  refundedMinor: number;
  lateCancellations: number;
  problemPayments: number;
  ratingsGiven: number;
  averageRatingGiven: number | null;
  quotesNotBooked: number;
}

/** Chiffres clés. Les livraisons de test interne ne comptent pas. */
export function summarizeCustomer(params: {
  missions: Doc[];
  payments: Doc[];
  ratings: Doc[];
  quotesNotBooked: number;
}): CustomerStats {
  const real = params.missions.filter((m) => m.assignment_mode !== "internal_test");
  const paid = params.payments.filter((p) => PAID_STATUSES.includes(p.status));
  const net = (p: Doc) => Math.max(0, int(p.amount_captured_minor) - int(p.amount_refunded_minor));
  const stars = params.ratings
    .map((r) => r.stars)
    .filter((s) => Number.isInteger(s) && s >= 1 && s <= 5) as number[];
  return {
    deliveries: real.length,
    completed: real.filter((m) => m.status === "completed").length,
    cancelled: real.filter((m) => m.status === "cancelled").length,
    active: real.filter((m) => !["completed", "cancelled", "failed", "payment_failed"].includes(m.status)).length,
    spentMinor: paid.reduce((sum, p) => sum + net(p), 0),
    tipsMinor: paid.filter((p) => paymentKind(p) === "tip").reduce((sum, p) => sum + net(p), 0),
    refundedMinor: params.payments.reduce((sum, p) => sum + int(p.amount_refunded_minor), 0),
    lateCancellations: paid.filter((p) => paymentKind(p) === "late_cancellation").length,
    problemPayments: params.payments.filter(isProblemPayment).length,
    ratingsGiven: stars.length,
    averageRatingGiven: stars.length ? Math.round((stars.reduce((a, b) => a + b, 0) / stars.length) * 10) / 10 : null,
    quotesNotBooked: params.quotesNotBooked,
  };
}

/** Pastilles : Nouveau (moins de 30 jours, au plus 1 livraison), Fidèle (3+), À surveiller. */
export function customerBadges(stats: CustomerStats, createdAtMs: number | null, nowMs = Date.now()): CustomerBadge[] {
  const badges: CustomerBadge[] = [];
  if (createdAtMs !== null && nowMs - createdAtMs < 30 * 24 * 3600_000 && stats.completed <= 1) badges.push("new");
  if (stats.completed >= 3) badges.push("loyal");
  if (stats.problemPayments > 0 || stats.lateCancellations >= 2) badges.push("watch");
  return badges;
}

function itemsText(mission: Doc): string {
  const items = mission.booking_snapshot?.load?.items;
  if (Array.isArray(items) && items.length) {
    return items
      .filter((i) => i && typeof i === "object")
      .map((i) => `${Number(i.quantity) || 1} × ${String(i.label ?? "").trim()}`)
      .join(", ");
  }
  return typeof mission.description === "string" ? mission.description.replace(/;\s*/g, ", ") : "";
}

export function missionRow(id: string, mission: Doc, cityOnly: boolean) {
  const requested = mission.booking_snapshot?.load?.requested_at;
  return {
    id,
    status: String(mission.status ?? ""),
    internalTest: mission.assignment_mode === "internal_test",
    createdAt: isoOf(mission.created_at),
    pickupAt: typeof requested === "string" ? requested : null,
    immediate: mission.booking_snapshot?.load?.timing_mode === "immediate",
    pickup: addressText(mission.pickup_address, cityOnly),
    dropoff: addressText(mission.dropoff_address, cityOnly),
    items: itemsText(mission),
    totalMinor: int(mission.customer_total_minor),
    depositStatus: typeof mission.deposit?.status === "string" ? mission.deposit.status : null,
    tipMinor: mission.tip?.status === "paid" ? int(mission.tip.amount_minor) : 0,
    driverName: typeof mission.driver_display_name === "string" ? mission.driver_display_name : null,
    completedAt: isoOf(mission.completed_at),
    cancelledAt: isoOf(mission.cancelled_at),
    cancellationReason: typeof mission.cancellation_reason === "string" ? mission.cancellation_reason : null,
  };
}

export function paymentRow(id: string, payment: Doc) {
  return {
    id,
    missionId: typeof payment.mission_id === "string" ? payment.mission_id : null,
    kind: paymentKind(payment),
    status: String(payment.status ?? ""),
    authorizedMinor: int(payment.amount_authorized_minor),
    capturedMinor: int(payment.amount_captured_minor),
    refundedMinor: int(payment.amount_refunded_minor),
    createdAt: isoOf(payment.created_at),
    capturedAt: isoOf(payment.captured_at),
    environment: typeof payment.stripe_environment === "string" ? payment.stripe_environment : null,
    hasReceipt: typeof payment.provider_charge_id === "string" && PAID_STATUSES.includes(payment.status),
    problem: isProblemPayment(payment),
    stripeUrl: stripePaymentUrl(payment),
  };
}

export function quoteRow(id: string, quote: Doc, cityOnly: boolean) {
  const stops = Array.isArray(quote.stops) ? quote.stops : [];
  return {
    id,
    createdAt: isoOf(quote.created_at),
    expiresAt: isoOf(quote.expires_at),
    totalMinor: int(quote.customer_total_minor),
    pickup: addressText(stops[0]?.address, cityOnly),
    dropoff: addressText(stops[stops.length - 1]?.address, cityOnly),
  };
}

/** Plus récent d'abord. */
export function byNewest<T extends { createdAt: string | null }>(rows: T[]): T[] {
  return [...rows].sort((a, b) => (b.createdAt ?? "").localeCompare(a.createdAt ?? ""));
}
