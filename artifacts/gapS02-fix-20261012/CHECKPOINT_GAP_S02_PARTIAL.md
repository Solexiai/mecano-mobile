# MOVI-K — CHECKPOINT GAP-S-02 — CORRECTION PARTIELLE VALIDÉE

Date : 12 octobre 2026, America/Toronto.

**Verdict : CORRECTION PARTIELLE TESTÉE — NON FERMÉE — NON DÉPLOYÉE.**

## Reprise et périmètre
- Dépôt : Solexiai/mecano-mobile.
- Worktree unique : C:\Users\Utilisateur\movik-gps-history-fix-20261009.
- Branche : fix/gps-client-history-scope-20261009.
- HEAD de départ : `97ac7d7f5697729301e83829af6ba1a8552af380`.
- Aucun push, merge, déploiement ni accès réel à Stripe/Firebase Production.
- Autorisation explicite obtenue de corriger localement le défaut de concurrence financier, en conservant tarifs, commissions, montants et snapshots.

## Reproduction avant correction
- Cas conservé dans `artifacts/gapS02-diagnostic-20261012/gapS02CancellationRace.diagnostic.test.ts.txt`.
- Un client annule sa mission depuis Firestore pendant que `authorizePayment` est suspendu dans `FakePaymentProvider`.
- Le trigger d'annulation ne libère pas le paiement encore `authorization_pending`.
- L'autorisation fictive s'achève : le paiement devient `authorized` malgré une mission `cancelled`.
- Le test avant correction a échoué sur la valeur `authorized` (1 échec de règle de sécurité ; 11 tests hors sélection).

## Correction locale contrôlée
- `functions/src/payment/paymentOrchestration.ts` : contrôle d'annulation avant création de paiement ; détection transactionnelle d'une annulation arrivée pendant l'autorisation ; stockage de la référence provider ; compensation externe utilisant le chemin idempotent existant ; une mission terminale n'est pas rouverte comme `payment_failed` lors d'un refus tardif.
- `functions/src/functions/acceptDelivery.ts` : distinction explicite entre paiement annulé et échec de paiement normal.
- Nouveau `functions/src/functions/onPaymentAuthorizedAfterMissionCancel.ts` : événement Firestore `payments/{paymentId}` à l'autorisation ; si la mission liée est annulée, appel de compensation ; `retry: true` en cas d'échec de libération.
- `functions/src/index.ts` : export de l'événement sans déploiement.
- Nouveau `functions/test/integration/gapS02CancellationRace.test.ts` : scénarios de concurrence, rattrapage, rejeu, premier refus de compensation, et refus d'autorisation pendant l'annulation.

## Tests et résultats
- Test ciblé après première correction : 1/1 réussi.
- Suite ciblée étendue ensuite : 3/3 réussis ; première tentative intermédiaire bloquée par deux erreurs de typage de fixture, corrigées sans changer le produit ni les assertions métier.
- Validation finale consolidée en émulateurs Firestore/Auth : **18 tests réussis / 0 échec / 0 ignoré** dans 3 suites :
  - gapS02CancellationRace.test.ts ;
  - acceptDeliveryConcurrency.test.ts ;
  - missionCancellationPaymentRelease.test.ts.
- Tests émulés sur projet fictif `demo-movik-test`, services locaux `127.0.0.1:8080` et `127.0.0.1:9099`.
- Paiement : `FakePaymentProvider` uniquement, aucune clé réelle et aucune transaction monétaire.
- `tsc --noEmit --pretty false` : réussi, code 0.
- ESLint ciblé sources : réussi, code 0 ; le test est hors du tsconfig utilisé par l'ESLint du projet (essai de lint de test non pris comme validation).
- Compétence runtime Node 20 non vérifiée : le poste exécute Node 24.15.0 ; seule l'exécution locale est prouvée.

## Risque résiduel — empêche la fermeture définitive
**Interruption après que le provider a réellement autorisé mais avant le commit Firestore `authorized`.**
Dans cet intervalle, la mission est `cancelled`, mais le paiement Firestore peut rester `authorization_pending` alors que le provider conserve une autorisation. Le nouveau trigger écoutant le passage Firestore à `authorized` ne se déclenche pas si ce passage n'a pas eu lieu. Le moteur de réconciliation quotidien actuel détecte les anomalies sans effectuer de compensation automatique. Cette fenêtre exige une procédure de récupération autorisée et des tests d'interruption supplémentaires ; elle n'a pas été validée ni corrigée ici.

La fiabilité d'invocation automatique du nouveau trigger en Cloud Functions déployées (dont retry) n'a pas été testée avec Functions Emulator ou en production : seuls les handlers ont été exercés directement contre les émulateurs Firestore/Auth.

## Intégrité et limites
- Aucune modification des règles Firestore, calculs devis, montants en cents, commissions, tarifs, snapshots, ledger ou fournisseurs de paiement réels.
- Les chemins de mission, autorisation, annulation et écriture restent audités via les fonctions existantes.
- Aucun essai Stripe Sandbox/LIVE, Chrome ou téléphone ; aucune preuve de protection totale contre les crashs.
- `GAP-S-04` (chauffeur suspendu) n'a pas été modifié : décision produit toujours requise.
- Registre : 27 fiches, P0=0, P1=0, **P2=5 toujours ouverts**, notamment GAP-S-02.
- 1.3L reste BLOQUÉ ET REPORTÉ.

**Aucun feu vert pour les paiements réels ni pour un déploiement.**
