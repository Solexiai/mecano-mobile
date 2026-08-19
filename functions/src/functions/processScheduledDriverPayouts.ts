// -----------------------------------------------------------------------------
// processScheduledDriverPayouts — Cloud Function PLANIFIÉE (cron horaire).
//
// Complète le cycle de vie amorcé par `calculateDriverPayout.ts` (point 9) :
// un versement créé en PENDING/HELD reste bloqué tant que
// `payout_eligible_at` n'est pas atteint. Ce job :
//
//   1. Fait transiter PENDING|HELD -> ELIGIBLE tout `driver_payouts` dont
//      `payout_eligible_at <= now` ET qui possède désormais un
//      `connected_account_id` (le chauffeur a pu compléter son onboarding
//      Stripe Connect APRÈS la création du payout — on relit le profil à
//      chaque passage plutôt que de figer une valeur obsolète).
//   2. Pour chaque versement qui devient (ou était déjà) ELIGIBLE, appelle
//      `submitDriverPayout()` (paymentOrchestration.ts) — le SEUL point du
//      système qui déclenche l'appel réel PaymentProvider.createDriverPayout(),
//      toujours HORS transaction Firestore, protégé par l'idempotency_key
//      déterministe déjà figé à la création du payout.
//
// Comme `submitDriverPayout()` gère lui-même intégralement la machine
// d'état (ELIGIBLE -> SCHEDULED -> PROCESSING -> PAID|FAILED), ce job ne
// fait JAMAIS d'écriture financière directe — il se contente d'identifier
// les candidats et de déléguer.
// -----------------------------------------------------------------------------

import { onSchedule } from "firebase-functions/v2/scheduler";
import { admin, db } from "../lib/admin";
import { writeAuditLog } from "../lib/audit";
import { DriverPayoutDoc, DriverProfileDoc, PayoutStatuses } from "../lib/types";
import { submitDriverPayout } from "../payment/paymentOrchestration";

const BATCH_LIMIT = 100;

export const processScheduledDriverPayouts = onSchedule(
  { schedule: "every 60 minutes" },
  async () => {
    const now = admin.firestore.Timestamp.now();

    // ---- Étape A : PENDING|HELD -> ELIGIBLE (rétention écoulée) ----
    const pendingQuery = await db
      .collection("driver_payouts")
      .where("status", "==", PayoutStatuses.PENDING)
      .where("payout_eligible_at", "<=", now)
      .limit(BATCH_LIMIT)
      .get();
    const heldQuery = await db
      .collection("driver_payouts")
      .where("status", "==", PayoutStatuses.HELD)
      .where("payout_eligible_at", "<=", now)
      .limit(BATCH_LIMIT)
      .get();

    const readyDocs = [...pendingQuery.docs, ...heldQuery.docs];
    const promotedPayoutIds: string[] = [];

    for (const docSnap of readyDocs) {
      const payout = docSnap.data() as DriverPayoutDoc;
      if (!payout.connected_account_id) {
        // Rétention écoulée mais le chauffeur n'a toujours pas de compte
        // connecté valide : on tente de rafraîchir depuis driver_profiles
        // (peut avoir été complété après la création du payout).
        const driverSnap = await db.collection("driver_profiles").doc(payout.driver_id).get();
        const driver = driverSnap.data() as DriverProfileDoc | undefined;
        if (driver?.stripe_connected_account_id) {
          await docSnap.ref.update({
            status: PayoutStatuses.ELIGIBLE,
            connected_account_id: driver.stripe_connected_account_id,
          });
          promotedPayoutIds.push(docSnap.id);
        }
        // Sinon : reste bloqué (PENDING/HELD) jusqu'au prochain passage —
        // pas d'échec forcé, l'onboarding Stripe Connect peut survenir
        // à tout moment.
        continue;
      }
      await docSnap.ref.update({ status: PayoutStatuses.ELIGIBLE });
      promotedPayoutIds.push(docSnap.id);
    }

    // ---- Étape B : soumet tout versement ELIGIBLE (nouveau ou préexistant) ----
    const eligibleQuery = await db
      .collection("driver_payouts")
      .where("status", "==", PayoutStatuses.ELIGIBLE)
      .limit(BATCH_LIMIT)
      .get();

    const results = await Promise.all(
      eligibleQuery.docs.map(async (docSnap) => {
        try {
          const outcome = await submitDriverPayout(docSnap.id);
          return { payoutId: docSnap.id, success: outcome.success, status: outcome.status };
        } catch (err) {
          const message = err instanceof Error ? err.message : String(err);
          return { payoutId: docSnap.id, success: false, status: "error", error: message };
        }
      })
    );

    if (promotedPayoutIds.length === 0 && results.length === 0) return;

    await writeAuditLog({
      actorUserId: "system",
      actorRole: "system",
      action: "processScheduledDriverPayouts",
      sourceFunction: "processScheduledDriverPayouts",
      metadata: { promotedPayoutIds, submittedCount: results.length, results },
    });
  }
);
