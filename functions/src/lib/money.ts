// -----------------------------------------------------------------------------
// money.ts — Utilitaires monétaires PHASE 6.
//
// EXIGENCE EXPLICITE (point 32) : « Ne jamais utiliser les nombres flottants
// binaires pour les calculs monétaires. » Toutes les nouvelles données
// financières introduites en Phase 6 (PaymentDoc, RefundDoc, DriverPayoutDoc
// amounts, ledger amounts pour les nouveaux mouvements) utilisent des
// UNITÉS MINEURES ENTIÈRES (cents) — `amount_minor: number` (integer).
//
// PÉRIMÈTRE : le moteur de pricing existant (`pricingEngine.ts`,
// `financial_snapshots`) continue de produire des `number` (dollars,
// virgule flottante) — c'est un contrat déjà utilisé par des dizaines de
// tests Phase 1-5 validés, et le modifier rétroactivement sortirait du
// périmètre « ne pas revisiter les phases 2-5 sauf bug réel ». La frontière
// est donc : toute nouvelle donnée Phase 6 (paiement réel, refund, payout,
// dispute) est en cents entiers ; la conversion depuis un montant en dollars
// du snapshot se fait via `toMinorUnits()` au moment de la création du
// PaymentDoc / RefundDoc / DriverPayoutDoc, une seule fois, à la frontière.
//
// MULTI-DEVISE : `Currency` est un type ouvert pour préparer d'autres
// devises futures (non activées maintenant, voir point 32).
// -----------------------------------------------------------------------------

export type Currency = "CAD";

export const DEFAULT_CURRENCY: Currency = "CAD";

/** Nombre de décimales mineures pour chaque devise supportée (CAD = cents). */
const MINOR_UNIT_EXPONENT: Record<Currency, number> = {
  CAD: 2,
};

/**
 * Convertit un montant en unité majeure (ex: 105.99 CAD) en unité mineure
 * entière (10599). Arrondit au cent le plus proche pour éviter toute dérive
 * d'arrondi binaire IEEE-754 lors de la conversion.
 */
export function toMinorUnits(amountMajor: number, currency: Currency = DEFAULT_CURRENCY): number {
  const exponent = MINOR_UNIT_EXPONENT[currency];
  const factor = Math.pow(10, exponent);
  // Math.round après multiplication : la SEULE opération flottante autorisée
  // est cette conversion ponctuelle à la frontière ; tout calcul ultérieur
  // sur le résultat reste en entiers.
  return Math.round(amountMajor * factor);
}

/** Convertit une unité mineure entière en unité majeure (pour affichage uniquement). */
export function toMajorUnits(amountMinor: number, currency: Currency = DEFAULT_CURRENCY): number {
  const exponent = MINOR_UNIT_EXPONENT[currency];
  const factor = Math.pow(10, exponent);
  return amountMinor / factor;
}

/** Addition entière sûre (garde-fou explicite, évite tout piège de type). */
export function addMinor(...amounts: number[]): number {
  return amounts.reduce((sum, a) => {
    if (!Number.isInteger(a)) {
      throw new Error(`Montant non entier détecté dans un calcul en cents: ${a}`);
    }
    return sum + a;
  }, 0);
}

export function subtractMinor(a: number, b: number): number {
  if (!Number.isInteger(a) || !Number.isInteger(b)) {
    throw new Error(`Montant non entier détecté dans une soustraction en cents: ${a}, ${b}`);
  }
  return a - b;
}

/** Applique un taux (0..1) à un montant en cents, arrondi au cent le plus proche. */
export function applyRateMinor(amountMinor: number, rate: number): number {
  if (!Number.isInteger(amountMinor)) {
    throw new Error(`Montant non entier détecté: ${amountMinor}`);
  }
  return Math.round(amountMinor * rate);
}

export function isNonNegativeInteger(value: unknown): value is number {
  return typeof value === "number" && Number.isInteger(value) && value >= 0;
}

export function assertValidMinorAmount(value: number, label: string): void {
  if (!isNonNegativeInteger(value)) {
    throw new Error(`${label} doit être un entier >= 0 (cents). Reçu: ${value}`);
  }
}
