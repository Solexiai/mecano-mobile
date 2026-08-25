# PHASE 7 — Bloc A — Matrice QA Produit (version initiale)

Cette matrice est volontairement créée rapidement (conformément à la consigne du Bloc A :
« Ne pas passer une session complète à documenter »). Elle sera enrichie au fil des blocs B-AC
au fur et à mesure que des scénarios sont réellement testés (statut mis à jour en continu).

Colonnes : ID | Rôle | Préconditions | Étapes | Résultat attendu | Test auto existant | Test manquant | Statut | Bug

## Auth / Onboarding

| ID | Rôle | Préconditions | Étapes | Résultat attendu | Test existant | Manquant | Statut | Bug |
|---|---|---|---|---|---|---|---|---|
| AUTH-01 | client | aucune | signup email/password | compte créé, redirection dashboard client | partiel (unit auth Flutter) | E2E signup->login runtime | À TESTER (Bloc E) | - |
| AUTH-02 | tous | compte existant | login | session active, claims corrects | - | E2E | À TESTER (Bloc E) | - |
| AUTH-03 | admin révoqué | admin dont le rôle est rétrogradé | admin tente une action admin après révocation | action refusée immédiatement (claims rafraîchis) | non | oui — critique | À TESTER (Bloc E) | RISQUE IDENTIFIÉ |
| DRV-ONB-01 | driver | signup | profil + véhicule + documents + submit review | passe en pending_review | `submitDriverForReview` (unit/integration existant) | E2E complet | À TESTER (Bloc C) | - |

## Missions (Client)

| ID | Rôle | Préconditions | Étapes | Résultat attendu | Test existant | Manquant | Statut | Bug |
|---|---|---|---|---|---|---|---|---|
| MIS-C-01 | client | payment_profile avec default_payment_method | devis -> création mission -> assignation -> tracking -> completed | mission completed, paiement capturé, historique visible | `e2eDeliveryLifecycle.test.ts` (nominal) | négatifs ci-dessous | PARTIEL (nominal DONE) | - |
| MIS-C-02 | client | aucun chauffeur dispo | createDeliveryRequest puis dispatch sans chauffeur éligible | mission reste `searching_driver`, aucune `delivery_offers`, pas de crash | `dispatchNoDriverAvailable.test.ts` (2/2 PASS, incl. régression positive) | - | **DONE** | - |
| MIS-C-03 | client | devis expiré | createDeliveryRequest avec quoteId expiré | `failed-precondition` | `createDeliveryRequest.test.ts` (couvert) | non | DONE | - |
| MIS-C-04 | client | paiement refusé à l'acceptation | acceptDelivery avec FakePaymentProvider en échec | mission `payment_failed`, désassignée, driver remis `online`, aucun payment AUTHORIZED, retry possible avec nouvelle mission | `acceptDeliveryPaymentFailure.test.ts` (2/2 PASS) | - | **DONE** | - |
| MIS-C-05 | client | mission assignée (driver_id != null), payment authorized | client annule (`status`->`cancelled`) | paiement autorisé libéré/annulé (`cancelAuthorization`) | `missionCancellationPaymentRelease.test.ts` (3/3 PASS) | - | **DONE — CORRIGÉ** | **BUG-001 (CORRIGÉ)** |
| MIS-C-06 | client | session expirée | tente action authentifiée (Cloud Function) | pas de crash, message d'erreur actionnable, jamais d'état incohérent | inspection de code : `delivery_request_flow_screen.dart` + `driver_active_mission_screen.dart` catchent déjà `CloudFunctionException` de façon uniforme (`_actionErrorKey`/`_errorMessage`, jamais un crash) ; le SDK Firebase Auth rafraîchit les ID tokens automatiquement | - | **DONE (adéquat, aucun code changé)** | - |
| MIS-C-07 | client | non authentifié | accède à `/livraison/suivi/:missionId` | message clair "connectez-vous", pas de message générique "erreur réseau" trompeur | `customer_tracking_screen_auth_test.dart` (2/2 PASS) | - | **DONE — CORRIGÉ (UX)** | **BUG-002 (mineur, CORRIGÉ)** |
| MIS-C-08 | client | ancienne mission avec données partielles (avant Phase 4/5, sans pickup/dropoff/timestamps) | `DeliveryMission.fromJson` sur document partiel + ouverture des vues associées | pas de crash, defaults sûrs, aucun force-unwrap non gardé | `delivery_mission_partial_data_test.dart` (3/3 PASS) + inspection de code (tous les `!` sur champs nullables dans les écrans sont gardés par `if (x != null)`) | - | **DONE** | - |
| MIS-C-09 | client | déconnexion réseau/timeout pendant création mission, ou double-tap UI, ou retry avec même quoteId | (A) double-tap UI rapide sur "Confirmer et créer" ; (B) retry séquentiel backend même quoteId ; (C) 2 requêtes concurrentes même quoteId | jamais 2 missions/paiements/autorisations pour le même devis ; quote consommé une seule fois | (A) `delivery_request_flow_double_submit_test.dart` (2/2 PASS — garde de réentrance `_createMission()` + désactivation bouton) ; (B)+(C) `createDeliveryRequestIdempotency.test.ts` (2/2 PASS — atomicité transaction Firestore déjà suffisante, aucun fix backend nécessaire) | - | **DONE** | **BUG-003 (CORRIGÉ)** |

## Missions (Chauffeur)

| ID | Rôle | Préconditions | Étapes | Résultat attendu | Test existant | Manquant | Statut | Bug |
|---|---|---|---|---|---|---|---|---|
| MIS-D-01 | driver approuvé | mission ouverte | accepte -> pickup -> transit -> dropoff -> completed | earnings crédités, payout éligible | `e2eDeliveryLifecycle.test.ts` | - | DONE | - |
| MIS-D-02 | driver pending_review | tente accepter | refusé | `acceptDeliveryConcurrency.test.ts` | - | DONE | - |
| MIS-D-03 | driver suspendu | tente accepter | refusé | `acceptDeliveryConcurrency.test.ts` | - | DONE | - |
| MIS-D-04 | 2 drivers | même mission, accept simultané | un seul gagne, l'autre reçoit erreur claire | `acceptDeliveryConcurrency.test.ts` (déjà 100% Phase 5/6) | - | DONE | - |
| MIS-D-05 | driver | GPS refusé/désactivé/rapport échoue | `DriverLocationReporter.start()` avec service désactivé, permission refusée (temp/forever), ou `reportDriverLocation` qui échoue | bandeau d'avertissement affiché, mission reste cohérente, **jamais** de boucle de retry non contrôlée | `driver_location_reporter_test.dart` (cas négatifs GPS) + `driver_active_mission_status_gaps_test.dart` (bandeau GPS pendant trajet, sans blocage des actions) | - | **DONE** | **BUG P1 boucle GPS infinie (CORRIGÉ)** |
| MIS-D-06 | driver | proof upload échoue (Storage) | completeDelivery sans proof valide, puis retry après échec | erreur claire affichée, pas de transition fantôme, retry réussi possible | `driver_active_mission_proof_upload_test.dart` (échec upload, retry réussi, NotConfiguredProofUploadRepository) | - | **DONE** | - |
| MIS-D-07 | driver | payout policy / Stripe account non configuré, ou échec provider en cours de traitement | `submitDriverPayout` : ELIGIBLE → PROCESSING → échec provider → FAILED | échec explicite, **transaction annulée intégralement** (pas de rollback silencieux partiel), pas de perte de fonds, payout reste `FAILED` et re-tentable | `submitDriverPayoutFailure.test.ts` (Jest, `forceCreateDriverPayoutFailure` sur `FakePaymentProvider`) | - | **DONE — CORRIGÉ** | **BUG P0 payout rollback (CORRIGÉ)** |
| MIS-D-08 | driver | `ProviderJobsTab` (liste missions dispo + missions actives) | ouverture répétée de l'onglet / rebuilds successifs (setState) | les `Stream` Firestore (missions dispo, missions actives) sont créés UNE SEULE FOIS, jamais recréés à chaque `build()` | `provider_jobs_tab_test.dart` (8/8 PASS) | - | **DONE — CORRIGÉ** | **BUG P1 stream recréé (CORRIGÉ)** |
| MIS-D-09 | driver | `DriverActiveMissionScreen`, tous les statuts de trajet intermédiaires (assigned → driverToPickup → arrivedAtPickup → pickedUp → inTransit → arrivedAtDropoff → completed) | transition de chaque statut via l'action UI correspondante ; double-tap rapide sur une action | seule l'action attendue par statut est visible/actionnable ; `markPickupCompleted` utilisé pour arrivedAtPickup→pickedUp (JAMAIS `updateTrackingStatus`) ; double-tap ne déclenche l'appel repository qu'une seule fois (bouton busy bloque le second tap) | `driver_active_mission_status_gaps_test.dart` (9/9 PASS) | - | **DONE** | - |
| MIS-D-10 | driver | `DriverStatusScreen`, 7 statuts (registrationIncomplete/pendingReview/documentsRequired/approved/rejected/suspended/inactive) | ouverture de l'écran pour chaque statut ; actions déclenchées (resubmit, toggle online) | CTA et message corrects par statut ; AUCUNE action interdite visible (ex : `suspended`/`rejected`/`inactive` n'affichent jamais de switch online) ; `approved` ne passe JAMAIS online automatiquement au premier rendu ; repository appelé uniquement sur interaction explicite | `driver_status_screen_test.dart` (18/18 PASS) | - | **DONE** | - |

**Bloc C — clôture** : les 4 lignes MIS-D-05 à MIS-D-10 ci-dessus couvrent l'intégralité du
périmètre Bloc C (onboarding chauffeur/BUG-003, E2E chauffeur complet, GPS/location reporter,
proof upload failure, payout submission failure, ProviderJobsTab, DriverActiveMissionScreen gaps,
DriverStatusScreen). Validation finale : `npx tsc --noEmit` (0 erreur), `npm run lint` (clean),
Jest unit (109/109 PASS), Jest intégration pertinente Bloc C — payout/E2E/concurrence chauffeur
(56/56 PASS : `submitDriverPayoutFailure`, `e2eDriverOnboardingToPayout`,
`acceptDeliveryConcurrency`, `calculateDriverPayout`, `reverseDriverPayout`,
`foundingDriverCommission`, `financialConcurrency`, `dispatchNoDriverAvailable`,
`e2eRefundPostPayoutLifecycle`), `flutter analyze` (0 souci nouveau), `flutter test` (371/371 PASS).
**BLOC C : ✅ FERMÉ.**

## Admin / Analyste / Super Admin

| ID | Rôle | Étapes | Résultat attendu | Statut |
|---|---|---|---|---|
| ADM-01 | analyste | review driver, request documents, validate document, add internal note, log review opened | autorisé | `adminPrivilegedActions.test.ts` (Bloc D, NOUVEAU) : `requestDriverDocuments` success (analyst), `addDriverInternalNote` success (analyst), `logDriverReviewOpened` success (analyst) — DONE |
| ADM-02 | analyste | tente suspendDriver/reactivateDriver/updatePricingConfiguration/applyDriverPromotion/qualifyFoundingDriver/createFinancialSnapshot (admin-only) | refusé (permission-denied) | `adminPrivilegedActions.test.ts` (Bloc D, NOUVEAU) : 7 tests dédiés « refuse pour analyst » — DONE |
| ADM-03 | admin | suspendDriver/reactivateDriver/updatePricingConfiguration/applyDriverPromotion/qualifyFoundingDriver/revokeFoundingDriverStatus/createFinancialSnapshot | autorisé | `adminPrivilegedActions.test.ts` (Bloc D, NOUVEAU) — DONE. Refund/payout/dispute/reconciliation/taxes Cloud-Function-level déjà couverts Phase 6/Bloc C (`disputeOrchestration.test.ts`, `reconciliationEngine.test.ts`, `taxEngine.test.ts`, `calculateDriverPayout.test.ts`, `reverseDriverPayout.test.ts`) — référencé, non dupliqué |
| ADM-04 | super_admin | `setUserRole` (SEUL point d'entrée privilège) | autorisé ; refusé pour tout rôle < super_admin | `adminPrivilegedActions.test.ts` (Bloc D, NOUVEAU) : success (super_admin) + 4 tests refus (customer/driver/analyst/admin) + invalid-argument (rôle invalide, targetUid/roles manquants) — DONE |
| ADM-05 | analyst/driver/customer | `validateDriverDocument` / `rejectDriver` avec rôle insuffisant | refusé (permission-denied) | success-path déjà couvert `e2eDriverOnboardingToPayout.test.ts` ; gap « permission-denied » comblé par `adminPrivilegedActions.test.ts` (Bloc D, NOUVEAU) — DONE |
| ADM-06 | tout rôle (y compris super_admin) | écriture Firestore DIRECTE sur transaction_ledger / disputes / reconciliation_reports / payout_policy_configs / payment_profiles / driver_internal_notes | refusé | Déjà exhaustivement couvert `securityRules.test.ts` (196/196 PASS, Phase 6) — RÉFÉRENCÉ, non redupliqué (directive Bloc D : ne pas refaire l'audit Security Rules général) |

**Bloc D — clôture** : gap de couverture Cloud-Function-callable identifié (0 test existant pour
`setUserRole`, `suspendDriver`, `reactivateDriver`, `requestDriverDocuments`,
`updatePricingConfiguration`, `applyDriverPromotion`, `qualifyFoundingDriver`,
`revokeFoundingDriverStatus`, `createFinancialSnapshot`, `logDriverReviewOpened` ; success-path
seulement pour `validateDriverDocument`/`rejectDriver`) comblé intégralement par le nouveau fichier
`functions/test/integration/adminPrivilegedActions.test.ts` (36 tests, 36/36 PASS au premier essai —
aucun bug trouvé, chaque garde `require*OrAbove()`/`requireSuperAdmin()` fonctionne exactement comme
le code source le prévoyait). Security Rules Firestore (196/196 PASS) référencées, non ré-auditées.
Validation : `npx tsc --noEmit` (0 erreur), Jest unit (109/109 PASS), Jest intégration Bloc D
(36/36 PASS nouveau fichier). **BLOC D : ✅ FERMÉ.**

## GPS / Notifications / Responsive / I18N / Sécurité / Performance
Voir blocs dédiés H, I, J, K, Q, M — matrice à enrichir au fur et à mesure des tests réels.

---
**Note méthodologique** : Cette matrice n'est PAS exhaustive à ce stade — elle sert de point de
départ. Elle sera mise à jour à chaque bloc fermé avec les résultats réels (statut, bug ID le
cas échéant). La priorité immédiate est de suivre TEST → FAIL → FIX → RETEST plutôt que
d'étoffer ce tableau de façon théorique.

**Découverte initiale la plus importante (à valider par test réel dans Bloc B)** :
`MIS-C-05` — aucune Cloud Function n'appelle `cancelAuthorization()` du provider de paiement
lorsqu'un client annule une mission déjà assignée (payment_status = `authorized`). Grep exhaustif
sur `functions/src/` confirme zéro appel à `.cancelAuthorization(` en dehors de sa définition
d'interface/implémentation. Ceci doit être confirmé par un test d'intégration réel avant d'être
classé comme bug (voir Bloc B).
