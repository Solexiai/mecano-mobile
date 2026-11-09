// -----------------------------------------------------------------------------
// driverTip.ts — pourboire au chauffeur (décision Daniel, 2026-11-09).
//
// Règles :
//   - Proposé après la livraison, avec la note : 10 %, 15 % ou 20 % du prix
//     de la livraison avant taxes, ou un montant au choix.
//   - 100 % au chauffeur : débit Stripe « destination charge » vers son
//     compte connecté SANS frais de plateforme. Les frais Stripe du
//     pourboire sont absorbés par Movi-K (prélevés sur le solde plateforme).
//   - Aucune taxe sur le pourboire (types.ts : TaxableComponents.TIP n'est
//     jamais taxé par défaut). Ne touche ni aux tarifs, ni à la commission,
//     ni au snapshot financier (immuable) : le pourboire est un paiement et
//     une entrée de registre séparés.
//   - Un seul pourboire par livraison, dans les 30 jours qui suivent.
//
// Ce module ne contient que des calculs purs (testés en unitaire) ; le débit
// est dans payment/driverTipOrchestration.ts.
// -----------------------------------------------------------------------------

import { toMinorUnits } from "./money";

export const DRIVER_TIP_POLICY = Object.freeze({
  version: "MOVIK-TIP-20261109-001",
  percentages: Object.freeze([10, 15, 20]) as readonly number[],
  /** Montant au choix : de 1 $ à 100 $ (borne contre une faute de frappe). */
  min_minor: 100,
  max_minor: 10000,
  /** Le pourboire reste possible 30 jours après la livraison. */
  window_ms: 30 * 24 * 60 * 60 * 1000,
});

/** Paiement du pourboire : `tip_<mission>`, puis `tip_<mission>_2`… après un refus. */
export function tipPaymentId(missionId: string, sequence = 1): string {
  return sequence <= 1 ? `tip_${missionId}` : `tip_${missionId}_${sequence}`;
}

/**
 * Prix de la livraison avant taxes (cents) : la base des pourcentages. Le
 * total payé moins les taxes du devis verrouillé ; le total s'il n'y a pas
 * de ventilation lisible. Même calcul dans l'app (DeliveryMission.tipBaseMinor).
 */
export function tipBaseMinor(mission: Record<string, unknown>): number {
  const totalMinor = Number.isSafeInteger(mission.customer_total_minor)
    ? (mission.customer_total_minor as number)
    : typeof mission.customer_total === "number" && Number.isFinite(mission.customer_total)
      ? toMinorUnits(mission.customer_total as number)
      : 0;
  if (totalMinor <= 0) return 0;
  const breakdown = mission.quote_breakdown as Record<string, unknown> | null | undefined;
  const tax = breakdown?.taxAmount;
  if (typeof tax !== "number" || !Number.isFinite(tax) || tax <= 0) return totalMinor;
  const taxMinor = toMinorUnits(tax);
  return taxMinor < totalMinor ? totalMinor - taxMinor : totalMinor;
}

export type TipChoice =
  | { kind: "percent"; percent: number }
  | { kind: "amount"; amountMinor: number };

/** Lit le choix du client : exactement un pourcentage proposé OU un montant entier en cents. */
export function parseTipChoice(data: { percent?: unknown; amountMinor?: unknown }): TipChoice | null {
  const hasPercent = data.percent !== undefined && data.percent !== null;
  const hasAmount = data.amountMinor !== undefined && data.amountMinor !== null;
  if (hasPercent === hasAmount) return null;
  if (hasPercent) {
    return typeof data.percent === "number" && DRIVER_TIP_POLICY.percentages.includes(data.percent)
      ? { kind: "percent", percent: data.percent }
      : null;
  }
  return Number.isSafeInteger(data.amountMinor) &&
    (data.amountMinor as number) >= DRIVER_TIP_POLICY.min_minor &&
    (data.amountMinor as number) <= DRIVER_TIP_POLICY.max_minor
    ? { kind: "amount", amountMinor: data.amountMinor as number }
    : null;
}

/** Montant du pourboire en cents (un pourcentage n'est jamais sous 1 $ ni au-dessus de 100 $). */
export function tipAmountMinor(choice: TipChoice, baseMinor: number): number {
  if (choice.kind === "amount") return choice.amountMinor;
  const raw = Math.round((Math.max(0, baseMinor) * choice.percent) / 100);
  return Math.min(DRIVER_TIP_POLICY.max_minor, Math.max(DRIVER_TIP_POLICY.min_minor, raw));
}
