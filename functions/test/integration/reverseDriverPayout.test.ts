// ---------------------------------------------------------------------------
// Test d'intégration — reverseDriverPayout() (Bloc H, Tâche 3).
//
// PHASE 6 (payoutStateMachine.ts, transition PAID -> REVERSED, point 20) :
// compensation comptable administrative d'un versement DÉJÀ payé au
// chauffeur. Un versement Stripe déjà PAID ne peut pas être annulé via
// l'API Stripe elle-même (les fonds ont quitté le compte connecté) — cette
// fonction documente un recouvrement négocié hors-bande et crée les entrées
// ledger DRIVER_PAYOUT_REVERSAL correspondantes.
//
// Couvre AU MINIMUM (directive utilisateur) :
//   - payout PAID -> REVERSED valide
//   - mauvais statut refusé (ex: PENDING -> REVERSED)
//   - payout inexistant
//   - utilisateur non-admin refusé
//   - transition répétée refusée proprement (REVERSED est terminal dans la
//     machine d'état — ce n'est PAS idempotent, un second appel DOIT échouer)
//   - audit `payout_reversed` créé
//   - ledger / balance restent cohérents (mission_financial_balance
//     recalculé, driver_paid_minor retombe à 0 pour les missions concernées)
//   - aucun double effet financier (un seul ledger DRIVER_PAYOUT_REVERSAL
//     par mission, jamais recréé si l'appel échoue en second lieu)
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { reverseDriverPayout, ReverseDriverPayoutRequest } from "../../src/functions/reverseDriverPayout";
import { admin, db } from "../../src/lib/admin";
import { LedgerEntryTypes, PayoutStatuses } from "../../src/lib/types";
import { recalculateMissionFinancialBalance } from "../../src/lib/missionFinancialBalance";

const DRIVER_ID = "reversal_driver_001";
const ADMIN_ID = "reversal_admin_001";
const NON_ADMIN_ID = "reversal_stranger_001";
const MISSION_A = "reversal_mission_a";
const MISSION_B = "reversal_mission_b";
const SNAPSHOT_A = "reversal_snapshot_a";
const SNAPSHOT_B = "reversal_snapshot_b";

function buildRequest<T>(uid: string, role: string, data: T): CallableRequest<T> {
  return {
    data,
    auth: {
      uid,
      token: { role } as unknown as DecodedIdToken,
      rawToken: "fake-raw-token-for-emulator-test",
    },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

async function seedSnapshot(
  id: string,
  missionId: string,
  driverNetMissionEarnings: number,
  payoutId: string
): Promise<void> {
  await db.collection("financial_snapshots").doc(id).set({
    snapshot_id: id,
    mission_id: missionId,
    driver_id: DRIVER_ID,
    status: "confirmed",
    driver_net_mission_earnings: driverNetMissionEarnings,
    included_in_payout_id: payoutId,
    created_at: admin.firestore.Timestamp.now(),
  });
}

async function seedPaidPayout(
  payoutId: string,
  snapshotIds: string[],
  amountMinor: number
): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  await db.collection("driver_payouts").doc(payoutId).set({
    driver_id: DRIVER_ID,
    financial_snapshot_ids: snapshotIds,
    amount_minor: amountMinor,
    currency: "CAD",
    status: PayoutStatuses.PAID,
    payout_hold_period_hours: 0,
    payout_eligible_at: now,
    provider_payout_id: "fake_po_seeded",
    connected_account_id: "fake_acct_seeded",
    created_at: now,
    scheduled_at: now,
    processing_at: now,
    paid_at: now,
    failed_at: null,
    failure_reason: null,
    reversed_at: null,
    reversal_reason: null,
    idempotency_key: `seed_${payoutId}`,
  });
}

async function seedPendingPayout(payoutId: string): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  await db.collection("driver_payouts").doc(payoutId).set({
    driver_id: DRIVER_ID,
    financial_snapshot_ids: [],
    amount_minor: 1000,
    currency: "CAD",
    status: PayoutStatuses.PENDING,
    payout_hold_period_hours: 72,
    payout_eligible_at: now,
    provider_payout_id: null,
    connected_account_id: null,
    created_at: now,
    scheduled_at: null,
    processing_at: null,
    paid_at: null,
    failed_at: null,
    failure_reason: null,
    reversed_at: null,
    reversal_reason: null,
    idempotency_key: `seed_pending_${payoutId}`,
  });
}

async function cleanup(payoutIds: string[], missionIds: string[], snapshotIds: string[]): Promise<void> {
  const batch = db.batch();
  payoutIds.forEach((id) => batch.delete(db.collection("driver_payouts").doc(id)));
  snapshotIds.forEach((id) => batch.delete(db.collection("financial_snapshots").doc(id)));
  for (const missionId of missionIds) {
    batch.delete(db.collection("mission_financial_balance").doc(missionId));
  }
  await batch.commit();

  const ledgerAndAudit = await Promise.all([
    Promise.all(
      missionIds.map((mid) => db.collection("transaction_ledger").where("mission_id", "==", mid).get())
    ),
    db.collection("audit_logs").where("source_function", "==", "reverseDriverPayout").get(),
  ]);
  const batch2 = db.batch();
  ledgerAndAudit[0].forEach((snap) => snap.docs.forEach((d) => batch2.delete(d.ref)));
  ledgerAndAudit[1].docs.forEach((d) => {
    const targetId = d.data().target_id as string | undefined;
    if (targetId && payoutIds.includes(targetId)) batch2.delete(d.ref);
  });
  await batch2.commit();
}

describe("reverseDriverPayout — reversal administratif PAID -> REVERSED", () => {
  const payoutId = "reversal_payout_paid_001";

  afterEach(async () => {
    await cleanup([payoutId], [MISSION_A, MISSION_B], [SNAPSHOT_A, SNAPSHOT_B]);
  });

  it("transitionne un payout PAID -> REVERSED, crée le ledger DRIVER_PAYOUT_REVERSAL par mission avec le montant RÉEL (jamais une répartition égale), et journalise payout_reversed", async () => {
    await seedSnapshot(SNAPSHOT_A, MISSION_A, 42.5, payoutId);
    await seedSnapshot(SNAPSHOT_B, MISSION_B, 17.25, payoutId);
    await seedPaidPayout(payoutId, [SNAPSHOT_A, SNAPSHOT_B], 5975);
    await recalculateMissionFinancialBalance(MISSION_A);
    await recalculateMissionFinancialBalance(MISSION_B);

    // Précondition : avant reversal, driver_paid_minor doit refléter le payout PAID.
    const balanceABefore = (await db.collection("mission_financial_balance").doc(MISSION_A).get()).data()!;
    expect(balanceABefore.driver_paid_minor).toBe(4250);

    const outcome = await reverseDriverPayout.run(
      buildRequest<ReverseDriverPayoutRequest>(ADMIN_ID, "admin", {
        payoutId,
        reason: "Recouvrement négocié hors-bande avec le chauffeur.",
      })
    );

    expect(outcome.status).toBe(PayoutStatuses.REVERSED);
    expect(outcome.payoutId).toBe(payoutId);
    expect(new Set(outcome.missionIds)).toEqual(new Set([MISSION_A, MISSION_B]));

    // ---- Le document payout est bien REVERSED avec les métadonnées de reversal.
    const payoutSnap = await db.collection("driver_payouts").doc(payoutId).get();
    const payout = payoutSnap.data()!;
    expect(payout.status).toBe(PayoutStatuses.REVERSED);
    expect(payout.reversed_at).toBeTruthy();
    expect(payout.reversal_reason).toBe("Recouvrement négocié hors-bande avec le chauffeur.");

    // ---- Une entrée ledger DRIVER_PAYOUT_REVERSAL par mission, montant RÉEL
    // (driver_net_mission_earnings de CHAQUE snapshot), jamais une répartition égale.
    const ledgerA = await db
      .collection("transaction_ledger")
      .where("mission_id", "==", MISSION_A)
      .where("type", "==", LedgerEntryTypes.DRIVER_PAYOUT_REVERSAL)
      .get();
    expect(ledgerA.size).toBe(1);
    expect(ledgerA.docs[0].data().amount_minor).toBe(4250); // 42.50$ -> 4250 cents, PAS 2987 (moitié de 5975)

    const ledgerB = await db
      .collection("transaction_ledger")
      .where("mission_id", "==", MISSION_B)
      .where("type", "==", LedgerEntryTypes.DRIVER_PAYOUT_REVERSAL)
      .get();
    expect(ledgerB.size).toBe(1);
    expect(ledgerB.docs[0].data().amount_minor).toBe(1725); // 17.25$ -> 1725 cents

    // ---- L'audit `payout_reversed` a bien été créé (pas seulement une couverture indirecte).
    const auditSnap = await db
      .collection("audit_logs")
      .where("action", "==", "payout_reversed")
      .where("target_id", "==", payoutId)
      .get();
    expect(auditSnap.size).toBe(1);
    const auditEntry = auditSnap.docs[0].data();
    expect(auditEntry.actor_user_id).toBe(ADMIN_ID);
    expect(auditEntry.source_function).toBe("reverseDriverPayout");
    expect(auditEntry.metadata.reason).toBe("Recouvrement négocié hors-bande avec le chauffeur.");
    expect(new Set(auditEntry.metadata.missionIds as string[])).toEqual(new Set([MISSION_A, MISSION_B]));

    // ---- mission_financial_balance recalculé : driver_paid_minor retombe à 0
    // (le payout n'est plus "paid", donc plus compté comme versé) — cohérence
    // ledger/balance vérifiée après reversal.
    const balanceAAfter = (await db.collection("mission_financial_balance").doc(MISSION_A).get()).data()!;
    expect(balanceAAfter.driver_paid_minor).toBe(0);
    const balanceBAfter = (await db.collection("mission_financial_balance").doc(MISSION_B).get()).data()!;
    expect(balanceBAfter.driver_paid_minor).toBe(0);
  });

  it("refuse (permission-denied) si l'appelant n'est pas admin/super_admin", async () => {
    await seedSnapshot(SNAPSHOT_A, MISSION_A, 10, payoutId);
    await seedPaidPayout(payoutId, [SNAPSHOT_A], 1000);

    await expect(
      reverseDriverPayout.run(
        buildRequest<ReverseDriverPayoutRequest>(NON_ADMIN_ID, "driver", {
          payoutId,
          reason: "Tentative non autorisée.",
        })
      )
    ).rejects.toThrow();

    // Aucun effet de bord : le payout reste PAID, aucun ledger créé.
    const payoutSnap = await db.collection("driver_payouts").doc(payoutId).get();
    expect(payoutSnap.data()!.status).toBe(PayoutStatuses.PAID);
    const ledger = await db
      .collection("transaction_ledger")
      .where("mission_id", "==", MISSION_A)
      .where("type", "==", LedgerEntryTypes.DRIVER_PAYOUT_REVERSAL)
      .get();
    expect(ledger.size).toBe(0);
  });

  it("refuse (not-found) si le payout n'existe pas", async () => {
    await expect(
      reverseDriverPayout.run(
        buildRequest<ReverseDriverPayoutRequest>(ADMIN_ID, "admin", {
          payoutId: "payout_does_not_exist_xyz",
          reason: "N'existe pas.",
        })
      )
    ).rejects.toThrow();
  });

  it("refuse (invalid-argument) si reason est manquant ou vide", async () => {
    await seedSnapshot(SNAPSHOT_A, MISSION_A, 10, payoutId);
    await seedPaidPayout(payoutId, [SNAPSHOT_A], 1000);

    await expect(
      reverseDriverPayout.run(
        buildRequest<ReverseDriverPayoutRequest>(ADMIN_ID, "admin", {
          payoutId,
          reason: "",
        })
      )
    ).rejects.toThrow();

    await expect(
      reverseDriverPayout.run(
        buildRequest<ReverseDriverPayoutRequest>(ADMIN_ID, "admin", {
          payoutId,
          reason: "   ",
        })
      )
    ).rejects.toThrow();

    // Le payout reste inchangé (PAID) après ces tentatives refusées.
    const payoutSnap = await db.collection("driver_payouts").doc(payoutId).get();
    expect(payoutSnap.data()!.status).toBe(PayoutStatuses.PAID);
  });

  it("refuse (mauvais statut, ex: PENDING) une tentative de reversal — la transition n'est valide que depuis PAID", async () => {
    await seedPendingPayout(payoutId);

    await expect(
      reverseDriverPayout.run(
        buildRequest<ReverseDriverPayoutRequest>(ADMIN_ID, "admin", {
          payoutId,
          reason: "Tentative sur un statut invalide.",
        })
      )
    ).rejects.toThrow();

    const payoutSnap = await db.collection("driver_payouts").doc(payoutId).get();
    expect(payoutSnap.data()!.status).toBe(PayoutStatuses.PENDING); // inchangé
  });

  it(
    "refuse proprement une transition RÉPÉTÉE (REVERSED est un état TERMINAL dans la machine " +
      "d'état — ce n'est PAS idempotent : un second appel doit être rejeté, jamais silencieusement " +
      "accepté) — et ne crée AUCUN double effet financier (un seul ledger par mission, montant inchangé)",
    async () => {
      await seedSnapshot(SNAPSHOT_A, MISSION_A, 30, payoutId);
      await seedPaidPayout(payoutId, [SNAPSHOT_A], 3000);

      // Premier appel : succès.
      const first = await reverseDriverPayout.run(
        buildRequest<ReverseDriverPayoutRequest>(ADMIN_ID, "admin", {
          payoutId,
          reason: "Premier reversal.",
        })
      );
      expect(first.status).toBe(PayoutStatuses.REVERSED);

      // Second appel sur le MÊME payout déjà REVERSED : doit être REJETÉ
      // (InvalidPayoutTransitionError via assertValidPayoutTransition, car
      // TRANSITIONS[REVERSED] === [] dans payoutStateMachine.ts).
      await expect(
        reverseDriverPayout.run(
          buildRequest<ReverseDriverPayoutRequest>(ADMIN_ID, "admin", {
            payoutId,
            reason: "Second reversal (doit échouer).",
          })
        )
      ).rejects.toThrow();

      // Aucun double effet financier : toujours EXACTEMENT une seule entrée
      // ledger DRIVER_PAYOUT_REVERSAL pour cette mission, montant inchangé.
      const ledger = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", MISSION_A)
        .where("type", "==", LedgerEntryTypes.DRIVER_PAYOUT_REVERSAL)
        .get();
      expect(ledger.size).toBe(1);
      expect(ledger.docs[0].data().amount_minor).toBe(3000);

      // Toujours exactement une seule entrée d'audit payout_reversed pour ce payout.
      const auditSnap = await db
        .collection("audit_logs")
        .where("action", "==", "payout_reversed")
        .where("target_id", "==", payoutId)
        .get();
      expect(auditSnap.size).toBe(1);

      // Le motif original de reversal reste celui du PREMIER appel (jamais
      // réécrit par la tentative refusée).
      const payoutSnap = await db.collection("driver_payouts").doc(payoutId).get();
      expect(payoutSnap.data()!.reversal_reason).toBe("Premier reversal.");
    }
  );
});
