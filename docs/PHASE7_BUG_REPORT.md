# PHASE 7 — Bug Bash — Rapport de bugs

Règle de fermeture Phase 7 : **P0 = 0, P1 = 0** avant clôture. P2/P3 peuvent rester documentés.

## BUG-001 — Autorisation de paiement Stripe jamais libérée à l'annulation client post-assignation

- **Composant** : `functions/src/functions/onMissionEndedClearTracking.ts` (trigger unique et
  fiable interceptant l'annulation client directe, voir son commentaire d'en-tête) /
  `functions/src/payment/paymentOrchestration.ts` (orchestration paiement).
- **Sévérité** : **P1 (candidat)** — impact financier réel mais non catastrophique (fonds
  bloqués temporairement sur la carte du client jusqu'à expiration naturelle de l'autorisation
  Stripe ~7 jours ; aucun débit réel n'a lieu, mais l'expérience client est dégradée et
  `payments/{id}.status` reste incohérent avec l'état réel de la mission).
- **Découverte** : Phase 7, Bloc B (E2E Client — cas négatif "annulation après assignation"),
  via reconnaissance ciblée (`grep` exhaustif sur `.cancelAuthorization(` dans `functions/src/`)
  puis confirmation par un test d'intégration réel écrit spécifiquement pour reproduire le
  scénario.
- **Reproduction** (test créé) :
  `functions/test/integration/missionCancellationPaymentRelease.test.ts` — 3 tests :
  1. `le paiement AUTHORIZED passe à CANCELLED ... quand le client annule` → **ÉCHOUE**
     (reçu `"authorized"`, attendu `"cancelled"`).
  2. `[idempotence] rejouer le trigger ... ne relance pas cancelAuthorization` → **ÉCHOUE**
     (même cause racine).
  3. `[négatif] un paiement DÉJÀ CAPTURED n'est jamais annulé par ce trigger` → **PASSE**
     (comportement actuel correct par absence totale de logique, donc ce test ne prouve rien de
     positif en soi, mais confirme qu'aucune régression n'est introduite sur ce cas par le futur
     correctif).
- **Résultat de l'exécution confirmée** (émulateurs firestore+auth+storage,
  `demo-movik-test`) : `Tests: 2 failed, 1 passed, 3 total`.
- **Cause racine** : `firestore.rules` (`delivery_requests/{missionId}`) autorise le client
  propriétaire à passer `status` à `'cancelled'` par écriture directe une fois `driver_id`
  assigné (design intentionnel documenté dans les règles). `acceptDelivery()` a, à ce stade,
  déjà appelé `createAndAuthorizeMissionPayment()` qui autorise un paiement réel chez le
  provider (`payments/{id}.status = AUTHORIZED`). Aucune Cloud Function n'observe cette
  transition d'annulation pour appeler `PaymentProvider.cancelAuthorization()` — méthode qui
  existe pourtant déjà dans l'interface `PaymentProvider` (`cancelAuthorization()`,
  `paymentProvider.ts`) et son implémentation réelle Stripe (`stripeProvider.ts`, appelle
  `stripe.paymentIntents.cancel(...)`) et son double de test (`FakePaymentProvider`), mais n'est
  invoquée nulle part dans `functions/src/` en dehors de sa définition. La machine d'état
  (`paymentStateMachine.ts`) autorise pourtant explicitement la transition
  `AUTHORIZED -> CANCELLED` (« mission annulée avant capture ») — la transition est prévue et
  documentée dans le code mais jamais déclenchée.
- **Correctif appliqué** :
  1. Nouvelle fonction exportée `cancelMissionPaymentAuthorization(missionId, paymentId)`
     ajoutée dans `functions/src/payment/paymentOrchestration.ts`, suivant EXACTEMENT le schéma
     en 3 temps déjà établi (`createAndAuthorizeMissionPayment` / `captureMissionPayment` /
     `refundPayment`) :
     - **Étape 1 (transaction de préparation)** : lit `payments/{paymentId}`, retourne un état
       discriminé (`already_cancelled` / `skipped` si statut ≠ `AUTHORIZED` / `proceed` avec
       `providerPaymentIntentId` + `idempotencyKey = buildIdempotencyKey("cancelAuthorization", paymentId)`).
       Retours anticipés non-erreur pour `already_cancelled` et `skipped` (aucun appel provider).
     - **Étape 2 (HORS transaction)** : `provider.cancelAuthorization({providerPaymentIntentId, idempotencyKey})`,
       try/catch, échec loggé via `logFinancialFailure("cancel_authorization", ...)`.
     - **Étape 3 (transaction d'application)** : relit `payments/{id}` (garde de concurrence —
       si déjà `CANCELLED`, sort sans réécrire), **tous les reads AVANT tous les writes**
       (contrainte Firestore — voir bug de régression ci-dessous), `assertValidPaymentTransition()`,
       écrit `status: CANCELLED`, `cancelled_at`, `updated_at` sur le paiement et
       `payment_status: CANCELLED` sur `delivery_requests/{missionId}` si le doc existe.
     - Puis (hors transaction) : `writeAuditLog({action: "payment_authorization_cancelled", ...})`,
       `logFinancialSuccess(...)`, `recalculateMissionFinancialBalance(missionId)`.
     - Portée strictement limitée aux paiements `AUTHORIZED` — ne touche jamais un paiement
       `CAPTURED`/`PARTIALLY_REFUNDED` (chemin exclusif de `refundPayment()`), ne déclenche
       aucune capture, ne crée aucun payout chauffeur.
  2. `functions/src/functions/onMissionEndedClearTracking.ts` : import de
     `cancelMissionPaymentAuthorization`, et appel conditionnel — placé après la garde
     `wasAlreadyTerminal || !isNowTerminal` mais avant la garde `!after.driver_id` — déclenché
     uniquement quand `after.status === MissionStatuses.CANCELLED` ET qu'un `active_payment_id`
     non nul existe sur la mission. Scope strictement limité à la transition `cancelled` (pas
     `disputed`/`refunded`, qui suivent leurs propres chemins financiers dédiés).
  3. **Bug de régression découvert et corrigé pendant l'implémentation** : la première version
     du correctif violait la contrainte Firestore « tous les reads doivent précéder tous les
     writes dans une transaction » (`tx.update(payRef, ...)` était appelé avant
     `tx.get(missionRef)` dans la transaction d'application). Détecté immédiatement par le
     premier run de test post-fix (`Firestore transactions require all reads to be executed
     before all writes`, 2 tests rouges). Corrigé en réordonnant : `tx.get(missionRef)` déplacé
     avant tous les `tx.update(...)`. Recompilation (`tsc --noEmit`) confirmée propre après
     correction.
- **Test de régression** : `functions/test/integration/missionCancellationPaymentRelease.test.ts`
  (3 tests) — résultat final après correctif : **`Tests: 3 passed, 3 total`** (confirmé via
  émulateurs firestore+auth+storage, `demo-movik-test`).
- **Suite de régression complète exécutée après correctif** (aucune régression détectée) :
  - `functions/test/integration/onMissionEndedClearTracking.test.ts` → `10 passed, 10 total`.
  - Security Rules (`securityRules.test.ts` + `storageRules.test.ts`) → `196 passed, 196 total`.
  - `npx tsc --noEmit` → 0 erreur.
  - `npm run lint` (ciblé `src/`) → 0 erreur/warning.
- **Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc B).

---

*Ce fichier sera enrichi au fil des blocs B à W avec tout nouveau bug découvert (ID
séquentiel BUG-002, BUG-003, ...), classé P0/P1/P2/P3, avec cause, correctif, test de
régression et statut.*
