// ---------------------------------------------------------------------------
// Fixture partagée — runtime flags (`system_config/runtime_flags`) pour les
// tests d'intégration (émulateur Firestore).
//
// CONTEXTE (Bloc X) : depuis X-1→X-10, plusieurs Cloud Functions protégées
// (createDeliveryRequest, acceptDelivery, createAndAuthorizeMissionPayment,
// submitDriverPayout via processScheduledDriverPayouts/calculateDriverPayout)
// lisent `system_config/runtime_flags` et échouent FERMÉ
// (`service_temporarily_unavailable`) si ce document est absent, invalide ou
// si un flag est à `false` — comportement PRODUIT VOULU (voir
// `src/lib/runtimeFlags.ts`), jamais modifié par cette fixture.
//
// Les suites d'intégration historiques (créées avant le Bloc X) ne
// connaissaient pas ce document et échouaient donc désormais par défaut.
// Ce fichier fournit le seed standard : "Movi-K fonctionne normalement, tous
// les services critiques sont actifs" — à appeler explicitement par chaque
// suite qui exerce un chemin protégé et ne teste PAS elle-même le
// comportement des kill switches (c'est le rôle exclusif de
// `test/integration/runtimeFlags.test.ts`, qui NE réutilise PAS ce module
// comme un seed automatique caché — il garde la maîtrise explicite de
// l'absence/présence/validité du document via ses propres helpers locaux
// `seedAllFlagsOn`/`deleteRuntimeFlagsDoc`).
//
// Option A (voir directive) : ce module est un helper explicite, appelé
// volontairement par les suites historiques (`beforeEach`) — PAS un hook
// global Jest (`setupFilesAfterEach`) qui s'appliquerait aveuglément à tous
// les fichiers, y compris `runtimeFlags.test.ts` lui-même. Aucun deuxième
// framework de test créé : réutilisation directe de `db` (Admin SDK, même
// pattern que `test/testUtils/fakePaymentProvider.ts`).
// ---------------------------------------------------------------------------

import { admin, db } from "../../src/lib/admin";
import { RUNTIME_FLAGS_COLLECTION, RUNTIME_FLAGS_DOC_ID } from "../../src/lib/runtimeFlags";

export function runtimeFlagsDocRef(): admin.firestore.DocumentReference {
  return db.collection(RUNTIME_FLAGS_COLLECTION).doc(RUNTIME_FLAGS_DOC_ID);
}

/**
 * Écrit (Admin SDK, contourne les Security Rules — usage test only) un
 * document `system_config/runtime_flags` complet et valide. Tous les 4
 * flags à `true` par défaut, `overrides` permet de forcer un sous-ensemble
 * à `false` (utilisé par `runtimeFlags.test.ts` lui-même).
 */
export async function seedRuntimeFlags(overrides: Partial<Record<string, boolean>> = {}): Promise<void> {
  await runtimeFlagsDocRef().set({
    accept_new_delivery_requests: true,
    allow_driver_acceptance: true,
    payments_enabled: true,
    driver_payouts_enabled: true,
    updated_at: admin.firestore.Timestamp.now(),
    updated_by_user_id: "test_fixture_default",
    ...overrides,
  });
}

/**
 * Seed standard pour les suites d'intégration HISTORIQUES (pré-Bloc X) qui
 * exercent un chemin protégé sans vouloir tester elles-mêmes le comportement
 * des kill switches : "tous les services critiques sont actifs". À appeler
 * en `beforeEach`/`beforeAll` selon le style déjà utilisé dans le fichier.
 */
export async function seedDefaultRuntimeFlagsEnabled(): Promise<void> {
  return seedRuntimeFlags();
}

/**
 * Supprime le document — utilisé par `runtimeFlags.test.ts` pour prouver le
 * comportement fail-closed sur config absente (section A/K). Exporté ici
 * uniquement pour éviter une seconde définition ad hoc ; ne PAS appeler
 * depuis les suites historiques (elles doivent rester en état "flags ON").
 */
export async function deleteRuntimeFlagsDoc(): Promise<void> {
  await runtimeFlagsDocRef().delete();
}
