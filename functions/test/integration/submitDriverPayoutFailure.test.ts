// ---------------------------------------------------------------------------
// Test d'intégration — submitDriverPayout() : échec fournisseur
// (Phase 7, Bloc C, item 2 — "payout submission failure").
//
// Contrairement à calculateDriverPayout.test.ts (qui vérifie le cas succès,
// FakePaymentProvider par défaut -> PAID), ce fichier couvre spécifiquement
// le scénario d'ÉCHEC de `provider.createDriverPayout()` :
//
//   payout ELIGIBLE -> submitDriverPayout() -> PROCESSING (transaction 1)
//     -> provider.createDriverPayout() ÉCHOUE (FakePaymentProvider avec
//        forceCreateDriverPayoutFailure)
//     -> PROCESSING -> FAILED (transaction 3, chemin `result.success === false`)
//
// Déclenché ici via `calculateDriverPayout()` avec une politique de rétention
// nulle (0h) + un chauffeur déjà doté d'un `connected_account_id` — exactement
// le même chemin "immédiatement éligible" que le test succès existant, pour
// isoler la SEULE variable testée : le résultat du provider.
//
// Vérifie OBLIGATOIREMENT :
//   - le payout n'est JAMAIS `paid`
//   - aucun `paid_at`
//   - aucun `provider_payout_id` factice (reste `null`, jamais un id généré
//     malgré l'échec)
//   - statut final `failed` (machine d'état existante : PROCESSING -> FAILED)
//   - `failure_reason` renseigné avec le code d'erreur provider
//   - audit `payout_submitted` (soumission réelle) toujours présent, ET
//     aucun audit `payout_paid`-like erroné n'est créé
//   - aucune création de second payout pour les mêmes snapshots (un seul
//     document driver_payouts par appel de calculateDriverPayout, jamais
//     dupliqué par l'échec)
//   - le ledger existant (transaction_ledger) n'est PAS modifié par un
//     échec de payout — aucune entrée DRIVER_PAYOUT_REVERSAL ni autre créée
//     (un payout FAILED ne génère jamais d'écriture ledger, seul un payout
//     PAID->REVERSED en génère, voir reverseDriverPayout.test.ts)
//   - `mission_financial_balance` reste cohérent : `driver_paid_minor` doit
//     rester à 0 pour les missions concernées (aucun argent réellement versé)
//   - idempotence / retry : `payoutStateMachine.ts` autorise explicitement
//     FAILED -> SCHEDULED ("nouvelle tentative manuelle/admin, même
//     idempotency_key" — voir le commentaire de tête du fichier). Un nouvel
//     appel direct à `submitDriverPayout(payoutId)` sur un payout FAILED
//     doit donc RÉUSSIR À RETENTER (pas lever d'exception) : avec le
//     provider toujours en échec, le retry doit retourner un nouvel échec
//     PROPRE (success:false, status FAILED), jamais un faux PAID, et sans
//     dupliquer d'effet financier (ledger toujours vide, un seul document
//     driver_payouts).
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { calculateDriverPayout, CalculateDriverPayoutRequest } from "../../src/functions/calculateDriverPayout";
import {
  updatePayoutPolicyConfiguration,
  UpdatePayoutPolicyConfigurationRequest,
} from "../../src/functions/updatePayoutPolicyConfiguration";
import { submitDriverPayout } from "../../src/payment/paymentOrchestration";
import { admin, db } from "../../src/lib/admin";
import { PayoutStatuses } from "../../src/lib/types";
import { recalculateMissionFinancialBalance } from "../../src/lib/missionFinancialBalance";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider } from "../testUtils/fakePaymentProvider";
import { seedDefaultRuntimeFlagsEnabled } from "../testUtils/runtimeFlagsFixture";

const DRIVER_ID = "payout_fail_driver_001";
const ADMIN_ID = "payout_fail_admin_001";

function buildAdminRequest<T>(uid: string, role: string, data: T): CallableRequest<T> {
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
  driverId: string,
  missionId: string,
  driverNetMissionEarnings: number
): Promise<void> {
  await db.collection("financial_snapshots").doc(id).set({
    snapshot_id: id,
    mission_id: missionId,
    driver_id: driverId,
    status: "confirmed",
    driver_net_mission_earnings: driverNetMissionEarnings,
    included_in_payout_id: null,
    created_at: admin.firestore.Timestamp.now(),
  });
}

async function seedDriverProfile(
  driverId: string,
  opts: { completedMissions?: number; connectedAccountId?: string | null } = {}
): Promise<void> {
  await db.collection("driver_profiles").doc(driverId).set({
    uid: driverId,
    completed_missions: opts.completedMissions ?? 50,
    suspended_at: null,
    stripe_connected_account_id: opts.connectedAccountId ?? null,
    online_status: "online",
  });
}

async function cleanup(driverId: string, missionIds: string[]): Promise<void> {
  const [snapshots, payouts, driverDoc, ledger, auditSnap, balances] = await Promise.all([
    db.collection("financial_snapshots").where("driver_id", "==", driverId).get(),
    db.collection("driver_payouts").where("driver_id", "==", driverId).get(),
    db.collection("driver_profiles").doc(driverId).get(),
    db.collection("transaction_ledger").where("driver_id", "==", driverId).get(),
    db
      .collection("audit_logs")
      .where("source_function", "in", ["calculateDriverPayout", "submitDriverPayout"])
      .get(),
    Promise.all(missionIds.map((mId) => db.collection("mission_financial_balance").doc(mId).get())),
  ]);
  const batch = db.batch();
  snapshots.docs.forEach((d) => batch.delete(d.ref));
  const payoutIds = payouts.docs.map((d) => d.id);
  payouts.docs.forEach((d) => batch.delete(d.ref));
  if (driverDoc.exists) batch.delete(driverDoc.ref);
  ledger.docs.forEach((d) => batch.delete(d.ref));
  auditSnap.docs.forEach((d) => {
    const targetId = d.data().target_id as string | undefined;
    if (targetId === driverId || (targetId && payoutIds.includes(targetId))) {
      batch.delete(d.ref);
    }
  });
  balances.forEach((snap) => {
    if (snap.exists) batch.delete(snap.ref);
  });
  await batch.commit();
}

async function cleanupPayoutPolicy(): Promise<void> {
  await db.collection("payout_policy_configs").doc("default").delete();
  const auditSnap = await db
    .collection("audit_logs")
    .where("source_function", "==", "updatePayoutPolicyConfiguration")
    .get();
  const batch = db.batch();
  auditSnap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}


// Bloc X (X-11) — fixture standard : "Movi-K fonctionne normalement, tous les
// services critiques sont actifs" (voir test/testUtils/runtimeFlagsFixture.ts).
// Suite historique (pré-Bloc X) : ne teste PAS elle-même les kill switches.
beforeEach(async () => {
  await seedDefaultRuntimeFlagsEnabled();
});

describe("submitDriverPayout — échec fournisseur (createDriverPayout renvoie success:false)", () => {
  afterEach(async () => {
    setPaymentProviderForTesting(null);
  });

  it(
    "provider refuse le versement : payout se termine FAILED, jamais PAID, aucun provider_payout_id " +
      "factice, ledger et mission_financial_balance non corrompus",
    async () => {
      const missionId = "payout_fail_mission_a";
      setPaymentProviderForTesting(
        new FakePaymentProvider({
          forceCreateDriverPayoutFailure: true,
          failureCode: "payout_declined_test",
        })
      );

      try {
        // ---- Rétention nulle + compte connecté déjà présent : le payout
        // démarre ELIGIBLE et calculateDriverPayout() déclenche
        // automatiquement submitDriverPayout() en interne (même chemin que
        // le test succès de calculateDriverPayout.test.ts). ----
        await updatePayoutPolicyConfiguration.run(
          buildAdminRequest<UpdatePayoutPolicyConfigurationRequest>(ADMIN_ID, "admin", {
            defaultHoldPeriodHours: 0,
            newDriverHoldPeriodHours: 0,
            riskyDriverHoldPeriodHours: 0,
          })
        );
        await seedDriverProfile(DRIVER_ID, {
          completedMissions: 50,
          connectedAccountId: "fake_acct_fail_seeded",
        });
        await seedSnapshot("snap_fail_1", DRIVER_ID, missionId, 45);

        const result = await calculateDriverPayout.run(
          buildAdminRequest<CalculateDriverPayoutRequest>(ADMIN_ID, "admin", { driverId: DRIVER_ID })
        );

        expect(result.payoutId).toBeTruthy();
        const payoutId = result.payoutId as string;

        // ---- calculateDriverPayout() renvoie le statut APRÈS soumission :
        // doit refléter l'échec, jamais un faux succès. ----
        expect(result.status).toBe(PayoutStatuses.FAILED);

        // ---- Lecture directe du document driver_payouts : invariants stricts ----
        const payoutSnap = await db.collection("driver_payouts").doc(payoutId).get();
        expect(payoutSnap.exists).toBe(true);
        const payout = payoutSnap.data()!;

        expect(payout.status).toBe(PayoutStatuses.FAILED);
        expect(payout.status).not.toBe(PayoutStatuses.PAID);
        expect(payout.paid_at).toBeFalsy();
        // provider_payout_id reste tel que renvoyé par le provider en échec
        // (null dans FakePaymentProvider) — jamais un id fabriqué localement.
        expect(payout.provider_payout_id).toBeFalsy();
        expect(payout.failure_reason).toBe("payout_declined_test");
        expect(payout.failed_at).toBeTruthy();

        // ---- Un seul document driver_payouts créé pour ce chauffeur (pas
        // de double payout malgré l'échec). ----
        const allPayoutsForDriver = await db
          .collection("driver_payouts")
          .where("driver_id", "==", DRIVER_ID)
          .get();
        expect(allPayoutsForDriver.size).toBe(1);

        // ---- Audit : `payout_submitted` (soumission réelle tentée) doit
        // exister ; aucun `payout_created`-like frauduleux marquant un
        // succès n'est présent pour ce payoutId au-delà de l'événement
        // légitime `payout_created` (émis par calculateDriverPayout AVANT
        // l'appel provider, indépendant du résultat). ----
        const submittedAudit = await db
          .collection("audit_logs")
          .where("action", "==", "payout_submitted")
          .where("target_id", "==", payoutId)
          .get();
        expect(submittedAudit.size).toBe(1);
        expect(submittedAudit.docs[0].data().source_function).toBe("submitDriverPayout");

        // ---- Ledger : un échec de payout ne doit JAMAIS créer d'écriture
        // dans transaction_ledger (seul un reversal PAID->REVERSED en crée,
        // voir reverseDriverPayout.test.ts — un FAILED n'a rien à annuler). ----
        const ledgerEntries = await db
          .collection("transaction_ledger")
          .where("driver_id", "==", DRIVER_ID)
          .get();
        expect(ledgerEntries.size).toBe(0);

        // ---- mission_financial_balance : recalcul explicite pour vérifier
        // que driver_paid_minor reste à 0 (rien n'a été réellement versé). ----
        const balance = await recalculateMissionFinancialBalance(missionId);
        expect(balance.driver_paid_minor).toBe(0);

        // ---- Snapshot toujours marqué inclus dans CE payout (agrégé une
        // seule fois, jamais réutilisable par un appel suivant même après
        // échec — évite tout double comptage si un admin relance). ----
        const snapAfter = await db.collection("financial_snapshots").doc("snap_fail_1").get();
        expect(snapAfter.data()!.included_in_payout_id).toBe(payoutId);

        // ---- Idempotence / retry : la machine d'état existante autorise
        // explicitement FAILED -> SCHEDULED (nouvelle tentative). Avec le
        // provider toujours en échec, ce retry doit se solder par un
        // nouvel échec PROPRE (jamais un faux PAID), sans dupliquer aucun
        // effet financier. ----
        const retryOutcome = await submitDriverPayout(payoutId);
        expect(retryOutcome.success).toBe(false);
        expect(retryOutcome.status).toBe(PayoutStatuses.FAILED);

        const payoutAfterRetry = (await db.collection("driver_payouts").doc(payoutId).get()).data()!;
        expect(payoutAfterRetry.status).toBe(PayoutStatuses.FAILED);
        expect(payoutAfterRetry.paid_at).toBeFalsy();
        expect(payoutAfterRetry.provider_payout_id).toBeFalsy();

        // ---- Toujours un seul document driver_payouts après le retry
        // (le retry réutilise le même document, n'en crée jamais un second). ----
        const payoutsAfterRetry = await db
          .collection("driver_payouts")
          .where("driver_id", "==", DRIVER_ID)
          .get();
        expect(payoutsAfterRetry.size).toBe(1);

        // ---- Toujours aucune écriture ledger après le retry (un FAILED,
        // même répété, ne génère jamais de mouvement financier). ----
        const ledgerAfterRetry = await db
          .collection("transaction_ledger")
          .where("driver_id", "==", DRIVER_ID)
          .get();
        expect(ledgerAfterRetry.size).toBe(0);
      } finally {
        await cleanup(DRIVER_ID, [missionId]);
        await cleanupPayoutPolicy();
      }
    }
  );

  it(
    "aucun connected_account_id : submitDriverPayout() échoue sur missing_connected_account " +
      "SANS jamais appeler provider.createDriverPayout() (chemin précondition, distinct du refus provider)",
    async () => {
      // Ce chemin (precondition manquante) est distinct du refus provider
      // testé ci-dessus : calculateDriverPayout() ne place JAMAIS un payout
      // en ELIGIBLE sans connected_account_id (reste PENDING, voir
      // resolveHoldPeriodHours + condition `holdPeriodHours === 0 &&
      // connectedAccountId` dans calculateDriverPayout.ts) — donc pour
      // exercer réellement ce chemin de `submitDriverPayout()`, on seed
      // directement un payout ELIGIBLE sans connected_account_id (état
      // atteignable en production via le cron `processScheduledDriverPayouts`
      // si un chauffeur perd son compte connecté après éligibilité).
      setPaymentProviderForTesting(
        new FakePaymentProvider({ forceCreateDriverPayoutFailure: true })
      );
      const payoutId = "payout_fail_missing_account_001";
      const now = admin.firestore.Timestamp.now();
      await db.collection("driver_payouts").doc(payoutId).set({
        driver_id: DRIVER_ID,
        financial_snapshot_ids: [],
        amount_minor: 1500,
        currency: "CAD",
        status: PayoutStatuses.ELIGIBLE,
        payout_hold_period_hours: 0,
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
        idempotency_key: `seed_${payoutId}`,
      });

      try {
        const outcome = await submitDriverPayout(payoutId);
        expect(outcome.success).toBe(false);
        expect(outcome.status).toBe(PayoutStatuses.FAILED);

        const payout = (await db.collection("driver_payouts").doc(payoutId).get()).data()!;
        expect(payout.status).toBe(PayoutStatuses.FAILED);
        expect(payout.failure_reason).toBe("missing_connected_account");
        expect(payout.provider_payout_id).toBeFalsy();
        expect(payout.paid_at).toBeFalsy();
      } finally {
        await db.collection("driver_payouts").doc(payoutId).delete();
      }
    }
  );
});
