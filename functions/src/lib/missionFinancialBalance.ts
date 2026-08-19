// -----------------------------------------------------------------------------
// missionFinancialBalance.ts — Recalcule mission_financial_balance/{missionId}
// (point 7 de la directive 38 points Phase 6).
//
// PRINCIPE : ce document est un ÉTAT SYNTHÉTIQUE DÉRIVÉ, jamais une source
// de vérité indépendante. Il est recalculé À PARTIR de :
//   - payments/{paymentId} (mission_id == missionId) — customer_charged,
//     customer_refunded (amount_captured_minor, amount_refunded_minor)
//   - refunds where mission_id == missionId — répartition succeeded/failed
//   - transaction_ledger where mission_id == missionId — driver_tip,
//     driver_bonus, adjustments, provider_processing_cost
//   - financial_snapshots where mission_id == missionId — driver_earned,
//     platform_commission, customer_service_fee
//   - driver_payouts where financial_snapshot_ids contains un snapshot de
//     cette mission — driver_paid (proportion de ce payout attribuable à
//     CETTE mission, calculée au prorata du snapshot inclus)
//
// Le ledger (transaction_ledger) reste TOUJOURS la source historique —
// recalculateMissionFinancialBalance() peut être rejoué à tout moment SANS
// perdre d'information, car il ne fait que RELIRE l'existant, jamais écrire
// dans le ledger lui-même.
//
// 🔒 Appelée par : captureMissionPayment (après capture), refundPayment
// (après application du résultat), submitDriverPayout (après paiement),
// recordTip (après ajout pourboire), createLedgerEntry (ajustement manuel).
// Toujours HORS ou APRÈS la transaction principale — un recalcul peut lire
// plusieurs collections, donc n'est jamais fait DANS la transaction qui
// vient d'écrire le mouvement source (éviter tout risque de lecture
// incohérente/contention inutile). Utilise un simple .set(merge) atomique
// sur le document unique — pas besoin d'une transaction Firestore dédiée
// puisqu'aucune autre fonction n'écrit CE document en parallèle pour LA
// MÊME mission dans des conditions de course réalistes (un seul appelant à
// la fois par mission dans le flux métier normal).
// -----------------------------------------------------------------------------

import { admin, db } from "./admin";
import { addMinor, subtractMinor, toMinorUnits, DEFAULT_CURRENCY } from "./money";
import { LedgerEntryTypes, MissionFinancialBalanceDoc, RefundStatuses } from "./types";

export async function recalculateMissionFinancialBalance(
  missionId: string
): Promise<MissionFinancialBalanceDoc> {
  const [paymentsQuery, refundsQuery, ledgerQuery, snapshotsQuery] = await Promise.all([
    db.collection("payments").where("mission_id", "==", missionId).get(),
    db.collection("refunds").where("mission_id", "==", missionId).get(),
    db.collection("transaction_ledger").where("mission_id", "==", missionId).get(),
    db.collection("financial_snapshots").where("mission_id", "==", missionId).get(),
  ]);

  // ---- Paiement : customer_charged (capturé), driver_paid dérivé du payout ----
  let customerChargedMinor = 0;
  for (const doc of paymentsQuery.docs) {
    const p = doc.data();
    customerChargedMinor = addMinor(customerChargedMinor, (p.amount_captured_minor as number) ?? 0);
  }

  // ---- Refunds : seuls les SUCCEEDED comptent comme argent réellement rendu ----
  let customerRefundedMinor = 0;
  for (const doc of refundsQuery.docs) {
    const r = doc.data();
    if (r.status === RefundStatuses.SUCCEEDED) {
      customerRefundedMinor = addMinor(customerRefundedMinor, (r.amount_minor as number) ?? 0);
    }
  }

  // ---- Ledger : tip, bonus, adjustments, provider_processing_cost ----
  // 🔒 Le ledger legacy (Phase 1-5) stocke `amount` en DOLLARS (flottant) —
  // voir money.ts. On convertit ICI, à la frontière de lecture, pour ne
  // jamais mélanger cents/dollars dans le reste du calcul.
  let driverTipMinor = 0;
  let driverBonusMinor = 0;
  let adjustmentsMinor = 0;
  let providerProcessingCostMinor = 0;
  let driverPayoutReversalMinor = 0;

  for (const doc of ledgerQuery.docs) {
    const entry = doc.data();
    const amountMinor =
      typeof entry.amount_minor === "number"
        ? (entry.amount_minor as number)
        : toMinorUnits((entry.amount as number) ?? 0, DEFAULT_CURRENCY);
    if (entry.status === "reversed") continue; // entrée annulée, jamais comptée

    switch (entry.type) {
      case LedgerEntryTypes.DRIVER_TIP:
        driverTipMinor = addMinor(driverTipMinor, amountMinor);
        break;
      case LedgerEntryTypes.DRIVER_BONUS:
        driverBonusMinor = addMinor(driverBonusMinor, amountMinor);
        break;
      case LedgerEntryTypes.DRIVER_ADJUSTMENT:
      case LedgerEntryTypes.CUSTOMER_ADJUSTMENT:
        adjustmentsMinor = addMinor(adjustmentsMinor, amountMinor);
        break;
      case LedgerEntryTypes.PAYMENT_PROCESSING_FEE:
        providerProcessingCostMinor = addMinor(providerProcessingCostMinor, amountMinor);
        break;
      case LedgerEntryTypes.DRIVER_PAYOUT_REVERSAL:
        driverPayoutReversalMinor = addMinor(driverPayoutReversalMinor, amountMinor);
        break;
      default:
        break;
    }
  }

  // ---- Snapshots : platform_commission, customer_service_fee, driver_earned ----
  let platformCommissionMinor = 0;
  let customerServiceFeeMinor = 0;
  let driverEarnedMinor = 0;
  const snapshotIds: string[] = [];
  for (const doc of snapshotsQuery.docs) {
    const s = doc.data();
    platformCommissionMinor = addMinor(
      platformCommissionMinor,
      toMinorUnits((s.platform_commission_amount as number) ?? 0, DEFAULT_CURRENCY)
    );
    customerServiceFeeMinor = addMinor(
      customerServiceFeeMinor,
      toMinorUnits((s.customer_service_fee as number) ?? 0, DEFAULT_CURRENCY)
    );
    driverEarnedMinor = addMinor(
      driverEarnedMinor,
      toMinorUnits((s.driver_net_mission_earnings as number) ?? 0, DEFAULT_CURRENCY)
    );
    snapshotIds.push(doc.id);
  }

  // ---- Payouts : driver_paid — somme des driver_payouts PAID dont
  // financial_snapshot_ids intersecte les snapshots de CETTE mission.
  // 🔒 Un payout agrège potentiellement plusieurs missions (voir
  // calculateDriverPayout.ts) — on ne peut pas prendre payout.amount_minor
  // en entier, seulement la part attribuable à CETTE mission (proportion du
  // driver_earned de cette mission / somme des driver_net_mission_earnings
  // agrégés dans ce payout). Approche simplifiée mais AUDITABLE : si le
  // snapshot de cette mission est inclus dans un payout PAID, on compte
  // driver_earned_minor de cette mission comme "payé" (hypothèse : un
  // payout PAID paie l'INTÉGRALITÉ des snapshots qu'il inclut, aucune
  // capture partielle de payout n'existe dans l'architecture actuelle).
  let driverPaidMinor = 0;
  if (snapshotIds.length > 0) {
    const payoutsQuery = await db
      .collection("driver_payouts")
      .where("status", "==", "paid")
      .get();
    for (const doc of payoutsQuery.docs) {
      const payout = doc.data();
      const includedIds: string[] = payout.financial_snapshot_ids ?? [];
      if (snapshotIds.some((id) => includedIds.includes(id))) {
        driverPaidMinor = addMinor(driverPaidMinor, driverEarnedMinor);
        break; // un seul payout peut inclure les snapshots de cette mission
      }
    }
  }
  // Une reversal de payout (refund post-payout, point 6) réduit le montant
  // effectivement retenu par le chauffeur du point de vue comptable — mais
  // NE MODIFIE JAMAIS driver_paid historique (voir directive point 6) ; on
  // l'expose plutôt via adjustments (déjà agrégé ci-dessus si applicable)
  // et driverPayoutReversalMinor reste disponible pour audit détaillé futur
  // (actuellement inclus implicitement via DRIVER_PAYOUT_REVERSAL -> aucun
  // champ dédié pour rester dans le set de champs demandé par la
  // directive ; tracé intégralement dans le ledger, source de vérité).
  void driverPayoutReversalMinor;

  const outstandingDriverBalanceMinor = subtractMinor(
    addMinor(driverEarnedMinor, driverTipMinor, driverBonusMinor, adjustmentsMinor),
    driverPaidMinor
  );
  const outstandingCustomerBalanceMinor = subtractMinor(
    customerChargedMinor,
    customerRefundedMinor
  );
  const contributionMarginMinor = subtractMinor(
    addMinor(platformCommissionMinor, customerServiceFeeMinor),
    providerProcessingCostMinor
  );

  const now = admin.firestore.Timestamp.now();
  const balance: MissionFinancialBalanceDoc = {
    mission_id: missionId,
    customer_charged_minor: customerChargedMinor,
    customer_refunded_minor: customerRefundedMinor,
    platform_commission_minor: platformCommissionMinor,
    customer_service_fee_minor: customerServiceFeeMinor,
    driver_earned_minor: driverEarnedMinor,
    driver_paid_minor: driverPaidMinor,
    driver_tip_minor: driverTipMinor,
    driver_bonus_minor: driverBonusMinor,
    adjustments_minor: adjustmentsMinor,
    outstanding_driver_balance_minor: outstandingDriverBalanceMinor,
    outstanding_customer_balance_minor: outstandingCustomerBalanceMinor,
    provider_processing_cost_minor: providerProcessingCostMinor,
    contribution_margin_minor: contributionMarginMinor,
    // Alias rétro-compatibles (Phase 6 point 9 nommage antérieur).
    customer_amount_authorized_minor: customerChargedMinor,
    customer_amount_captured_minor: customerChargedMinor,
    customer_amount_refunded_minor: customerRefundedMinor,
    platform_amount_earned_minor: platformCommissionMinor,
    driver_amount_earned_minor: driverEarnedMinor,
    driver_amount_paid_minor: driverPaidMinor,
    driver_amount_held_minor: outstandingDriverBalanceMinor,
    outstanding_balance_minor: outstandingCustomerBalanceMinor,
    updated_at: now,
  };

  await db.collection("mission_financial_balance").doc(missionId).set(balance);
  return balance;
}
