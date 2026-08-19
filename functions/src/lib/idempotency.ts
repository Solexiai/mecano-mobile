// -----------------------------------------------------------------------------
// idempotency.ts — Primitive d'idempotence pour TOUTE opération financière
// critique (point 12 du cahier des charges Phase 6).
//
// PRINCIPE : chaque opération financière critique (capture, refund, payout,
// traitement webhook) doit fournir une clé déterministe (jamais un UUID
// aléatoire généré à chaque tentative — la clé doit être la MÊME si la même
// opération logique est réessayée). La primitive garantit qu'une seule
// exécution "gagne" et que les tentatives suivantes renvoient le résultat
// déjà obtenu plutôt que de ré-exécuter l'effet financier.
//
// IMPLÉMENTATION : un document `idempotency_keys/{key}` créé de façon
// atomique DANS la même transaction Firestore que l'opération protégée.
// Si le document existe déjà avec status='completed', l'appelant doit
// renvoyer le résultat stocké sans ré-exécuter l'opération. Si
// status='in_progress' (opération concurrente en cours), lève une erreur
// `aborted` — le client retente plus tard plutôt que de dupliquer l'effet.
// -----------------------------------------------------------------------------

import { admin, db } from "./admin";
import { aborted } from "./errors";

/**
 * Construit une clé d'idempotence déterministe à partir de composants
 * métier stables (jamais un timestamp ou un random). Exemple :
 * `buildIdempotencyKey("capturePayment", paymentId)` ->
 * "capturePayment:pay_abc123".
 */
export function buildIdempotencyKey(operation: string, ...parts: string[]): string {
  return `${operation}:${parts.join(":")}`;
}

/**
 * Vérifie/acquiert un verrou d'idempotence DANS une transaction Firestore
 * déjà ouverte. Retourne:
 *  - { alreadyCompleted: true, result } si l'opération a déjà été exécutée
 *    avec succès pour cette clé (l'appelant doit renvoyer `result` sans
 *    ré-exécuter l'effet financier) ;
 *  - { alreadyCompleted: false } si le verrou vient d'être acquis (l'appelant
 *    doit exécuter l'opération puis appeler `completeIdempotencyKey`).
 * Lève `aborted` si une autre exécution est `in_progress` pour la même clé.
 */
export async function acquireIdempotencyLockInTransaction(
  tx: FirebaseFirestore.Transaction,
  key: string,
  operation: string
): Promise<{ alreadyCompleted: boolean; result?: Record<string, unknown> | null }> {
  const ref = db.collection("idempotency_keys").doc(key);
  const snap = await tx.get(ref);

  if (snap.exists) {
    const data = snap.data()!;
    if (data.status === "completed") {
      return { alreadyCompleted: true, result: data.result ?? null };
    }
    if (data.status === "in_progress") {
      throw aborted(
        `Une opération identique (${operation}) est déjà en cours pour la clé ${key}.`
      );
    }
    // status === 'failed' : on autorise une nouvelle tentative, on réécrit
    // le verrou en in_progress.
  }

  tx.set(ref, {
    key,
    operation,
    status: "in_progress",
    result: null,
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    completed_at: null,
  });

  return { alreadyCompleted: false };
}

export function completeIdempotencyKeyInTransaction(
  tx: FirebaseFirestore.Transaction,
  key: string,
  result: Record<string, unknown>
): void {
  const ref = db.collection("idempotency_keys").doc(key);
  tx.set(
    ref,
    {
      status: "completed",
      result,
      completed_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

export function failIdempotencyKeyInTransaction(
  tx: FirebaseFirestore.Transaction,
  key: string,
  errorMessage: string
): void {
  const ref = db.collection("idempotency_keys").doc(key);
  tx.set(
    ref,
    {
      status: "failed",
      result: { error: errorMessage },
      completed_at: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );
}

/**
 * Variante hors-transaction, utilisée par les webhooks (idempotence sur
 * `provider_event_id`, voir processPaymentWebhook.ts) où l'écriture de
 * l'évènement lui-même EST le verrou d'idempotence (get-or-create atomique
 * via une transaction dédiée courte).
 */
export async function isProviderEventAlreadyProcessed(providerEventId: string): Promise<boolean> {
  const ref = db.collection("provider_webhook_events").doc(providerEventId);
  const snap = await ref.get();
  return snap.exists && snap.data()?.processing_status === "processed";
}
