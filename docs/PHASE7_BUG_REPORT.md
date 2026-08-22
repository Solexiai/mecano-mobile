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
- **Correctif requis (NON encore appliqué — prochaine étape)** : Ajouter dans
  `onMissionEndedClearTracking.ts` (ou une fonction dédiée appelée par lui) une étape qui,
  lorsque `after.status === 'cancelled'` (transition entrante) ET qu'un `active_payment_id`
  existe ET que `payments/{id}.status === 'authorized'` :
  1. Transaction Firestore n°1 : lit le paiement, vérifie son statut, passe en état
     intermédiaire si nécessaire (suivre EXACTEMENT le schéma en 3 temps déjà établi dans
     `paymentOrchestration.ts` — jamais d'appel provider dans une transaction Firestore).
  2. Appel `provider.cancelAuthorization()` HORS transaction, avec une `idempotencyKey`
     déterministe (`buildIdempotencyKey("cancelAuthorization", paymentId)`).
  3. Transaction Firestore n°2 : applique le résultat
     (`payments/{id}.status = CANCELLED`, `cancelled_at`, et `delivery_requests/{missionId}.payment_status = CANCELLED`),
     via `assertValidPaymentTransition()`.
  4. `writeAuditLog()` avec `action: "payment_authorization_cancelled"`.
  5. Ne JAMAIS toucher un paiement déjà `CAPTURED`/`REFUNDED`/etc. (seul `AUTHORIZED` est
     concerné — le remboursement post-capture reste le chemin `refundPayment()` existant,
     inchangé).
  6. Idempotence : si `payments/{id}.status` est déjà `CANCELLED` au moment du (ré)traitement du
     trigger (livraison at-least-once), ne rien refaire (pas de second appel provider, pas de
     second audit_log).
- **Test de régression** : déjà écrit et committé
  (`missionCancellationPaymentRelease.test.ts`, 3 tests) — servira à valider le correctif
  (les 2 tests actuellement rouges doivent passer au vert après implémentation, sans régression
  sur le 3e test négatif déjà vert).
- **Statut** : **OUVERT — correctif à implémenter à la prochaine session** (voir point de
  reprise dans `docs/PHASE7_QA_PLAN.md`).

---

*Ce fichier sera enrichi au fil des blocs B à W avec tout nouveau bug découvert (ID
séquentiel BUG-002, BUG-003, ...), classé P0/P1/P2/P3, avec cause, correctif, test de
régression et statut.*
