# MOVI-K — P1-WEBHOOK-01 — IDempotence concurrente Stripe (émulateur)
Date : 14 octobre 2026 — Québec.

## Verdict
**FERMÉ — PÉRIMÈTRE CONCURRENCE DE WEBHOOKS ÉMULÉE VALIDÉ — NON DÉPLOYÉ.**
Ce verdict ne prouve pas les propriétés d'idempotence en cas d'interruption physique ni le fonctionnement Stripe LIVE/Sandbox. Le lancement Granby reste NO-GO.

## État et périmètre de départ
- Dépôt : Solexiai/mecano-mobile.
- Worktree : `C:\Users\Utilisateur\movik-gps-history-fix-20261009`.
- Branche : `fix/gps-client-history-scope-20261009`.
- HEAD avant correction : `925204d4eb1ea19e1e75cb4a67d8f98b326937c2`.
- Autorisation explicite de corriger localement avec le dispositif de paiement fictif existant, sans modifier tarifs, taux de commission, montants en cents, snapshots, ledger, ni déployer.
- HEAD après correction : enregistré par Git dans le commit local `fix(finance): serialize concurrent Stripe webhook processing` ; consulter `git log -1` pour la SHA exacte.

## Défaut AVANT correction, prouvé en émulateur
Le test existant `WEBHOOK DUPLIQUÉ CONCURRENT` observait deux réponses de traitement initial au lieu d'une, sans forcément atteindre ses assertions d'audit. Un test d'interleaving déterministe a donc bloqué l'audit métier du premier appel après la réservation Firestore, pendant que le second appel acquérait le même `provider_event_id`.
**Mesures avant correction :** `attempt_count=2`, **2 audits `payment_captured`**, **2 audits `webhook_event_processed`**, contre 1 de chaque attendu. Ce sont des doublons de journaux de webhook en émulateur ; aucun second débit/capture Stripe ni incident de production ne sont démontrés. La suite ciblée avec assertions d'effets échouait, voir `before-forced.log`.

## Correction ciblée
Fichier `functions/src/functions/processStripeWebhook.ts` :
- Acquisition transactionnelle de `provider_webhook_events/{event.id}` avec un champ `processing_lease_until` de durée limitée (10 minutes), avant tout dispatch métier.
- Un deuxième appel observant `received` avec un bail non expiré **n'entre pas dans `dispatchStripeEvent`**. Il attend le résultat pendant une fenêtre bornée de 10 secondes. Si le premier est marqué `processed`, il renvoie HTTP 200 `alreadyProcessed` ; si `failed` ou encore en cours, il retourne HTTP 503 `retryable` et laisse Stripe retenter. Un traitement incomplet n'est pas accusé comme définitivement réussi.
- Les événements `failed` restent retraitables. Un bail expiré peut être repris par transaction. Pour les anciennes entrées `received` sans `processing_lease_until`, le délai est calculé depuis `received_at` (pas d'hypothèse silencieuse de succès).
- Suppression du champ de bail à la finalisation `processed` / `failed`. Le schéma optionnel est ajouté à `functions/src/lib/types.ts`.
- Les fonctions partagées `processStripeWebhook` et `processStripeConnectWebhook` bénéficient du même garde, sans changer les secrets, signatures, montants, commissions ou orchestration des paiements.

## Tests APRÈS correction
- **Scénario de concurrence forcée** avec paquets fictifs signés localement : 1/1 réussi ; deux réponses HTTP 200, exactement 1 `fresh`, 1 `alreadyProcessed`, `attempt_count=1`, 1 audit métier, 1 audit d'événement. `after-forced.log`.
- **Suite webhook entière** : **31/31 tests réussis**, sans aucun test ignoré. Couvre signatures, événement traité/rejoué, attente de bail actif avec 503, bail expiré repris, échec temporaire puis retry, autres types de webhooks. `after-webhook-suite.log`.
- **Suite d'intégration Firebase complète** : **50/50 suites, 734/734 tests réussis**, projet fictif `demo-movik-test`, émulateurs Firestore/Auth/Storage en boucle locale. `full-integration.log`.
- **Tests unitaires serveur** : **15/15 suites, 228/228 tests réussis**. `unit-regression.log`.
- TypeScript `tsc --noEmit --pretty false` : code 0. ESLint ciblé des sources : code 0. Diff Git sans erreurs d'espaces.
- Les tests utilisent une signature Stripe d'essai entièrement locale pour exercer les handlers, sans appeler les endpoints Stripe ni manipuler des fonds réels.

## Points non démontrés et risques de lancement
- L'exécution de Cloud Functions avec les délais et la concurrence réels, l'intégration Stripe Sandbox/LIVE et la disponibilité Node20 ne sont pas validées.
- **Crash après un audit métier mais avant l'enregistrement `processed`** : même avec un bail temporaire, une reprise ultérieure peut nécessiter une déduplication plus stricte des effets d'audit ou une procédure de réconciliation. Aucune panne physique injectée n'a été testée ; ne pas présenter ce lot comme la preuve d'une « exactly-once » financière globale sous toute panne.
- Un bail expiré ne garantit pas, à lui seul, l'absence de chevauchement avec un ancien processus anormalement encore vivant. Valider les délais réels Cloud Functions et la supervision avant activation des paiements.
- Les 20 échecs des tests Flutter/GPS en mode HTTP interdit (QC26) et la validation de tuiles 1.3L restent ouverts comme prérequis distincts.
- Le registre 28/28 fermé est limité au périmètre des tests locaux de concurrence ; **aucun GO production**.
- Aucun changement aux règles Firestore, ledger, snapshots, Stripe, prix ou commissions ; aucun push, merge, déploiement ou paiement réel.
