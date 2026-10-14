# CHECKPOINT MOVI-K — GAP-S-02 — RECOVERY
Date : 2026-10-13 (America/Toronto)

## Verdict
**FERMÉ — PÉRIMÈTRE ÉMULATEUR VALIDÉ — NON DÉPLOYÉ.**
Ce verdict ne certifie ni Stripe Sandbox/LIVE, ni les fonctions planifiées déployées, ni une interruption physique du runtime. Aucune autorisation d'activer les paiements réels.

## État de départ
- Dépôt : Solexiai/mecano-mobile.
- Worktree : C:\Users\Utilisateur\movik-gps-history-fix-20261009.
- Branche : fix/gps-client-history-scope-20261009.
- HEAD initial : `e2171fe4221442b303693f05d748a3cd72e0ef59`.
- Branche release et autres worktrees non modifiés ; aucun push, merge ou déploiement.
- Correction partielle précédente et reproduction du cas GAP-S-02 conservées dans artifacts/gapS02-fix-20261012 et artifacts/gapS02-diagnostic-20261012.

## Cause et nouvelle protection
Avant cette intervention, acceptDelivery créait un document payments/{id} AUTHORIZATION_PENDING mais n'y conservait provider_payment_intent_id qu'APRÈS l'autorisation externe. Si Cloud Functions tombait après la confirmation du fournisseur mais avant le commit Firestore du succès, aucune transition vers AUTHORIZED ne déclenchait le rattrapage déjà ajouté.

1. `paymentOrchestration.ts` conserve maintenant provider_payment_intent_id dans une transaction Firestore AVANT l'appel provider.authorizePayment. StripeProvider.createPayment utilise `confirm:false` ; une interruption entre création du PaymentIntent et enregistrement de son ID ne peut donc pas avoir déclenché une autorisation par le chemin normal.
2. `recoverCancelledPendingAuthorization.ts` inspecte un paiement pending rattaché à une mission réellement cancelled et à un identifiant provider authentique. Il compare l'environnement Stripe à celui du provider actif, consulte `getPaymentStatus`, et refuse toute supposition de montant ou statut.
3. Pour `requires_capture`, il exige le même montant entier en cents que `amount_requested_minor` et zéro capture ; la transition transactionnelle pending -> authorized est immédiatement suivie de `cancelMissionPaymentAuthorization` (idempotent). Si l'exécution s'arrête après cette transition, le trigger existant `onPaymentAuthorizedAfterMissionCancel` assure le chemin de reprise.
4. Pour un PaymentIntent déjà `canceled`, la transaction pending -> cancelled réconcilie le document et le statut de paiement de la mission sans deuxième appel provider.
5. Pour un ID provider manquant, `succeeded`/capturé, un montant discordant, un environnement Stripe divergent ou un état inconnu : aucune compensation spéculative ; exception ou retour `needs_manual_review`.
6. `recoverCancelledPendingPayments` : fonction planifiée toutes les 10 minutes, filtre uniquement status=authorization_pending, traitement borné à 100 paiements par passage et délai d'âge minimum de cinq minutes. Aucun déploiement de ce cron effectué. Les alertes reposent actuellement sur la journalisation console ; une supervision opérationnelle sera nécessaire pour le lancement.

Aucune modification des tarifs, taux de commission, règles d'arrondissement, valeurs financières, contrat devis/mission/snapshot, ledger, Firestore rules ou fournisseur Stripe. Aucune nouvelle bibliothèque ni API financière introduite.

## Tests — déroulement et portée
- Première validation : 24/24 réussis ; elle couvrait récupération conservatrice, réconciliation avec statut fournisseur `requires_capture`, montant divergent, paiement capturé, ID absent, statut déjà `canceled`, batch âgé, double acceptation, annulation et rejeu.
- Test additionnel TEST/LIVE et assertion que provider_payment_intent_id est persisté AVANT authorizePayment : ajoutés après la première passe.
- Dernière validation : **25 tests réussis / 0 échec / 0 ignoré**, quatre suites :
  - gapS02PendingRecovery.test.ts (7 cas nouveaux)
  - gapS02CancellationRace.test.ts (scénarios précédents, avec assertion de référence)
  - acceptDeliveryConcurrency.test.ts (non-régression)
  - missionCancellationPaymentRelease.test.ts (non-régression)
- Environnement : Firebase Auth et Firestore Emulator sur loopback, projet fictif `demo-movik-test`, vrai code serveur et `FakePaymentProvider` injecté. Aucun compte Stripe, aucune carte réelle, aucun service Firebase de production.
- La panne est simulée en replaçant une fixture de paiement déjà autorisé dans l'état Firestore `authorization_pending`, pendant que le fournisseur fictif renvoie `requires_capture` ; **aucune interruption de processus Cloud Functions réelle** n'est revendiquée.
- TypeScript `tsc --noEmit` et ESLint ciblé source réussis avant la validation finale ; contrôles de qualité finaux et Git effectués séparément.

## Limites connues et conditions de lancement
- Les anciens paiements `authorization_pending` sans `provider_payment_intent_id` ne peuvent pas être automatiquement appariés à un PaymentIntent. Le récupérateur les signale pour examen manuel au lieu d'inventer une référence.
- Les états provider capturés/inconnus restent en attente d'une investigation plutôt qu'un remboursement ou une annulation automatique.
- Une tâche bornée à 100 éléments n'est pas une preuve de traitement de très gros backlogs. Supervision des logs, alarmes, configuration du job, fonctionnement Cloud Scheduler et vérification Node20 doivent être qualifiés avant production.
- Aucun paiement réel, webhooks réels, charge Stripe, émulateur Functions ou déploiement effectué.
- Le test autonome GPS/tuiles 1.3L reste BLOQUÉ ET REPORTÉ.
- GAP-S-04 (politique de suspension urgente des chauffeurs) n'est pas modifié.

## Registre
Sur 27 fiches : **P0=0, P1=0, P2=4 ouverts**, avec GAP-S-02 fermé seulement pour le périmètre local émulé. Restent P2-L-01, GAP-M-05, GAP-M-06 et GAP-S-04. Les P3 historiques et prérequis de pilote restent distincts. Aucun feu vert de lancement.
