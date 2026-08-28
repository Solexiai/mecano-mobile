// ---------------------------------------------------------------------------
// Test d'intégration — Phase 7, Bloc AA (AA-9) : DR EXERCISE non destructif.
//
// OBJECTIF (AA-9) : prouver, sur l'émulateur Firestore (JAMAIS de données de
// production), que Movi-K se comporte de façon sûre lors d'un incident
// simulé, en réutilisant EXCLUSIVEMENT les mécanismes déjà existants
// (kill switches Bloc X, moteur de réconciliation Bloc G/Phase 6) — aucun
// nouveau mécanisme de "réparation" n'est créé ici.
//
// SCÉNARIO A — Config runtime absente/corrompue -> fail closed :
//   1. Supprimer `system_config/runtime_flags` (simule une perte de config).
//   2. Vérifier que les 4 flags résolvent `enabled: false` (fail closed —
//      aucune opération risquée n'est permise par accident).
//   3. Restaurer une config valide (seed standard "tous les flags ON").
//   4. Vérifier que la résolution repasse immédiatement à `true` (pas de
//      cache, effet immédiat au prochain appel — cohérent avec X-12).
//
// SCÉNARIO B — Incohérence financière réconciliable (webhook_unprocessed) :
//   1. Seed un `provider_webhook_events` avec `processing_status: "received"`
//      (jamais passé à `processed`) dans la fenêtre de réconciliation.
//   2. Exécuter `runReconciliation()` (mécanisme EXISTANT, jamais modifié
//      ici) sur cette fenêtre.
//   3. Vérifier qu'il détecte l'anomalie `webhook_unprocessed` SANS modifier
//      le document `provider_webhook_events` source (immutabilité de la
//      source), et sans écrire ailleurs qu'un nouveau
//      `reconciliation_reports/{id}` (append-only).
//   4. Vérifier qu'aucune entrée `transaction_ledger` n'est créée, modifiée
//      ou supprimée par ce mécanisme (aucune "correction silencieuse" —
//      principe non négociable de reconciliationEngine.ts).
//
// Aucune donnée de production n'est utilisée ni requise — projet
// `demo-movik-test` (émulateurs uniquement, voir test/integration/setup.ts).
// ---------------------------------------------------------------------------

import { admin, db } from "../../src/lib/admin";
import {
  RuntimeFlagKeys,
  resolveRuntimeFlag,
  isRuntimeFlagEnabled,
} from "../../src/lib/runtimeFlags";
import { runReconciliation, ReconciliationAnomalyTypes } from "../../src/lib/reconciliationEngine";
import { ReconciliationStatuses, WebhookProcessingStatuses } from "../../src/lib/types";
import {
  seedRuntimeFlags,
  deleteRuntimeFlagsDoc,
} from "../testUtils/runtimeFlagsFixture";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider } from "../testUtils/fakePaymentProvider";

const DR_WEBHOOK_ID = "dr_exercise_webhook_stuck_001";

describe("Phase 7 — Bloc AA (AA-9) : DR Exercise non destructif — émulateur uniquement", () => {
  afterEach(async () => {
    await deleteRuntimeFlagsDoc();
  });

  describe("Scénario A — runtime flags : config absente -> fail closed -> restauration -> fail open", () => {
    it("config absente : les 4 flags résolvent enabled=false (fail closed, aucune opération risquée permise)", async () => {
      // 1. Simule une perte de config (incident : document supprimé/corrompu).
      await deleteRuntimeFlagsDoc();

      for (const key of [
        RuntimeFlagKeys.ACCEPT_NEW_DELIVERY_REQUESTS,
        RuntimeFlagKeys.ALLOW_DRIVER_ACCEPTANCE,
        RuntimeFlagKeys.PAYMENTS_ENABLED,
        RuntimeFlagKeys.DRIVER_PAYOUTS_ENABLED,
      ]) {
        const resolution = await resolveRuntimeFlag(key);
        expect(resolution.enabled).toBe(false);
        expect(resolution.reason).toBe("document_missing");
      }
    });

    it("restauration de la config -> effet immédiat, aucun flag ne reste bloqué par un cache", async () => {
      // 2. Incident confirmé (config absente).
      await deleteRuntimeFlagsDoc();
      expect(await isRuntimeFlagEnabled(RuntimeFlagKeys.PAYMENTS_ENABLED)).toBe(false);

      // 3. Restauration — un admin re-seed la config (procédure AA-5/AA-3).
      await seedRuntimeFlags();

      // 4. Effet immédiat au prochain appel (pas de TTL/cache — X-12, réutilisé
      // tel quel, non modifié).
      expect(await isRuntimeFlagEnabled(RuntimeFlagKeys.PAYMENTS_ENABLED)).toBe(true);
      expect(await isRuntimeFlagEnabled(RuntimeFlagKeys.DRIVER_PAYOUTS_ENABLED)).toBe(true);
      expect(await isRuntimeFlagEnabled(RuntimeFlagKeys.ACCEPT_NEW_DELIVERY_REQUESTS)).toBe(true);
      expect(await isRuntimeFlagEnabled(RuntimeFlagKeys.ALLOW_DRIVER_ACCEPTANCE)).toBe(true);
    });
  });

  describe("Scénario B — incohérence financière réconciliable (webhook_unprocessed), aucune correction silencieuse", () => {
    let createdReportId: string | null = null;

    beforeEach(() => {
      // Provider sans paiements/refunds/payouts déclarés -> les vérifications
      // provider (1/2/3/4/5/8) sont marquées `provider_checks_skipped`, mais
      // les vérifications internes (dont webhook_unprocessed, #11) restent
      // exécutées — comportement EXISTANT de reconciliationEngine.ts, non modifié.
      setPaymentProviderForTesting(new FakePaymentProvider());
    });

    afterEach(async () => {
      setPaymentProviderForTesting(null);
      await db.collection("provider_webhook_events").doc(DR_WEBHOOK_ID).delete();
      if (createdReportId) {
        await db.collection("reconciliation_reports").doc(createdReportId).delete();
        createdReportId = null;
      }
    });

    it("détecte webhook_unprocessed SANS modifier la source ni créer d'entrée ledger", async () => {
      const periodStart = Date.now() - 3600 * 1000;
      const periodEnd = Date.now() + 3600 * 1000;
      // Le moteur de réconciliation ne signale un webhook "coincé" qu'après
      // un seuil de 15 minutes (marge de sécurité contre un retry Stripe
      // normal, voir reconciliationEngine.ts) — on simule donc un webhook
      // reçu il y a 20 minutes, toujours dans la fenêtre [periodStart, periodEnd].
      const receivedAt = admin.firestore.Timestamp.fromMillis(Date.now() - 20 * 60 * 1000);

      // 1. Seed un webhook "coincé" (jamais passé à processed) — simule un
      // incident réel (ex: Cloud Function en erreur pendant le traitement).
      await db.collection("provider_webhook_events").doc(DR_WEBHOOK_ID).set({
        provider: "stripe",
        provider_event_id: DR_WEBHOOK_ID,
        event_type: "payment_intent.succeeded",
        received_at: receivedAt,
        processed_at: null,
        processing_status: WebhookProcessingStatuses.RECEIVED,
        attempt_count: 1,
        related_payment_id: null,
        related_payout_id: null,
        related_refund_id: null,
        related_dispute_id: null,
        related_mission_id: null,
      });

      const ledgerCountBefore = (await db.collection("transaction_ledger").get()).size;

      // 2. Exécute le mécanisme de réconciliation EXISTANT (jamais modifié).
      const { reportId, report } = await runReconciliation({
        periodStartMillis: periodStart,
        periodEndMillis: periodEnd,
        correlationId: "dr_exercise_correlation_001",
      });
      createdReportId = reportId;

      // 3. Anomalie détectée, rapportée — jamais "corrigée" automatiquement.
      const webhookAnomalies = report.anomalies.filter(
        (a) => a.type === ReconciliationAnomalyTypes.WEBHOOK_UNPROCESSED
      );
      expect(webhookAnomalies.length).toBeGreaterThanOrEqual(1);
      expect(report.status).toBe(ReconciliationStatuses.ANOMALY);

      // 4. La SOURCE (`provider_webhook_events`) n'a JAMAIS été modifiée par
      // le moteur de réconciliation — toujours `received`, jamais forcé à
      // `processed` par une "correction silencieuse".
      const webhookAfter = await db.collection("provider_webhook_events").doc(DR_WEBHOOK_ID).get();
      expect(webhookAfter.data()!.processing_status).toBe(WebhookProcessingStatuses.RECEIVED);
      expect(webhookAfter.data()!.processed_at).toBeNull();

      // 5. Aucune entrée `transaction_ledger` créée par ce mécanisme — la
      // réconciliation ne fait QUE comparer/rapporter, jamais écrire de
      // correction financière (principe non négociable, réutilisé tel quel).
      const ledgerCountAfter = (await db.collection("transaction_ledger").get()).size;
      expect(ledgerCountAfter).toBe(ledgerCountBefore);

      // 6. Une seule écriture produite par ce mécanisme : le rapport lui-même
      // (append-only, jamais modifié après création — voir firestore.rules).
      const reportSnap = await db.collection("reconciliation_reports").doc(reportId).get();
      expect(reportSnap.exists).toBe(true);
      expect(reportSnap.data()!.report_id).toBe(reportId);
    });
  });
});
