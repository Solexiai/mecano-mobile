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

## Auth / Session / Claims

| ID | Scénario | Étapes | Résultat attendu | Test | Statut |
|---|---|---|---|---|---|
| AUTH-E-01..08 | session/claims UI | signed-out, signed-in, claims loading/loaded/fetch-failed, rôle insuffisant, rôle suffisant, downgrade analyst après promotion admin | login screen / spinner / écran "Réessayer" (sans déconnexion forcée) / dashboard selon état ; jamais d'accès UI non autorisé par le backend | `test/auth/admin_auth_gate_session_claims_test.dart` (13/13 PASS, nouveaux seams `debugForceRoles`/`debugForceClaimsLoaded`/`debugForceClaimsFetchFailed`) | DONE |
| AUTH-E-S01..09 | session réelle (Identity Toolkit REST, émulateur) | signup, login, mauvais mot de passe, email inconnu, refresh token, claims dans token décodé | succès/échec HTTP corrects (`INVALID_PASSWORD`, `EMAIL_NOT_FOUND`), `verifyIdToken()` réellement exercé (pas de bypass `buildRequest`) | `functions/test/integration/authSessionClaims.test.ts` NIVEAU 1 | DONE |
| AUTH-E-C01..06 | claims round-trip | analyst→promotion admin (`setUserRole`)→droits effectifs ; admin→downgrade→refus ; rôle retiré ; super_admin downgrade ; callable sensible (`suspendDriver`/`requestDriverDocuments`) après changement de rôle | droits accordés/refusés exactement selon les claims actuels, jamais selon un état UI/token périmé | `functions/test/integration/authSessionClaims.test.ts` NIVEAU 2 | DONE |
| AUTH-E-U01 | callable sans authentification | appel direct sans `auth` | `unauthenticated` | `functions/test/integration/authSessionClaims.test.ts` NIVEAU 3 | DONE |

**Bloc E — clôture** : gaps identifiés (aucun seam claims/rôles arbitraire côté Flutter ; aucun
test dédié `AdminAuthGate`/`AdminLoginScreen` ; aucun test Cloud Function exerçant réellement
`verifyIdToken()` plutôt que le snapshot `buildRequest()`) comblés par 2 nouveaux fichiers de test
(13 + 16 = 29 tests, tous PASS) et un durcissement proactif (`revokeRefreshTokens` dans
`setUserRole.ts`, sans régression sur les 36 tests Bloc D). Principe "le frontend n'est jamais
l'autorité finale" prouvé par code (AUTH-E-C02/C03/C05/C06). **BLOC E : ✅ FERMÉ.**

## Routing / Deep Links (Bloc F)

| ID | Scénario | Étapes | Résultat attendu | Test | Statut |
|---|---|---|---|---|---|
| F-1 | client A tente d'accéder à une mission de client B | `customerId` de la mission != `auth.effectiveUid` sur `/livraison/suivi/:id` | refus propre (`driver_active_mission_access_denied`), aucune donnée de B affichée, aucun crash | `test/customer/customer_tracking_cross_customer_test.dart` (3/3 PASS) | **DONE** |
| F-2 | chauffeur `pending_review`/`suspended` tente de passer en ligne | `ProviderDashboardShell` avec statut chauffeur non `approved` | Switch "en ligne" désactivé (jamais actionnable), régression vérifiée pour `approved` (switch actif), défense niveau 2 si contournement | `test/driver/provider_dashboard_shell_status_gate_test.dart` (4/4 PASS) | **DONE — bug AppBar overflow CORRIGÉ (BUG-007)** |
| ROUTE-F-01 | route totalement inconnue | navigation vers une URL non déclarée dans `AppRouter.router` | fallback GoRouter par défaut ("Page Not Found" + bouton Home), pas d'écran blanc, pas d'exception | `test/routing/app_router_invalid_routes_test.dart` (1/6) | **DONE** |
| ROUTE-F-02 | paramètre `missionId` manquant | `/livraison/suivi/` (trailing slash, sans id) | fallback propre (route paramétrée non matchée), pas d'écran blanc | `test/routing/app_router_invalid_routes_test.dart` (2/6) | **DONE** |
| ROUTE-F-03 | route admin sans rôle privilégié | `/admin/chauffeurs/` avec rôle insuffisant | `AdminAuthGate` redirige vers `AdminLoginScreen`, aucune fuite de la liste chauffeurs | `test/routing/app_router_invalid_routes_test.dart` (3/6) | **DONE** |
| ROUTE-F-04 | paramètre `:type` malformé | `/legal/:type` avec type inconnu | `LegalScreen` retombe sur son cas `default` (politique de confidentialité), pas d'écran blanc | `test/routing/app_router_invalid_routes_test.dart` (4/6) | **DONE** |
| ROUTE-F-05 | mission chauffeur inexistante | `/provider/mission/:id` avec id inexistant | message "introuvable" (fallback existant réutilisé), pas d'écran blanc | `test/routing/app_router_invalid_routes_test.dart` (5/6) | **DONE** |
| ROUTE-F-06 | mission client inexistante | `/livraison/suivi/:id` avec id inexistant | message "introuvable" (fallback existant réutilisé), pas d'écran blanc | `test/routing/app_router_invalid_routes_test.dart` (6/6) | **DONE** |
| F-3.1 | deep-link notification client valide | notification contient `missionId` X → tap → `markAsRead` → navigation `/livraison/suivi/X` | `markAsRead` appelé avec le bon id, `CustomerTrackingScreen` reçoit exactement X, navigation unique, aucun crash | `test/notifications/notifications_deep_link_test.dart` groupe F-3.1 (1/7) | **DONE** |
| F-3.2 | deep-link vers mission supprimée/inexistante | tap notification → navigation tracking X → `watchMission` renvoie `null` | fallback EXISTANT réutilisé (`driver_active_mission_not_found`), aucun écran blanc, aucune exception, aucun contenu fictif | `test/notifications/notifications_deep_link_test.dart` groupe F-3.2 (2/7) | **DONE — aucune logique métier recréée** |
| F-3.3 | deep-link vers mission d'un autre utilisateur (client + chauffeur) | tap notification → mission appartient à un autre `customerId`/`driverId` | protection F-1 (client) et protection existante `DriverActiveMissionScreen` (chauffeur) réutilisées telles quelles : refus propre, aucune donnée sensible affichée, aucun crash | `test/notifications/notifications_deep_link_test.dart` groupe F-3.3 (3-4/7) | **DONE — protections F-1/chauffeur réutilisées, non dupliquées** |
| F-3 (nominal chauffeur) | branchement client/chauffeur de `NotificationsScreen` | chauffeur connecté → tap notification mission X | navigation `/fournisseur/mission/X` (pas la route client), `DriverActiveMissionScreen` reçoit X, aucun refus à tort | `test/notifications/notifications_deep_link_test.dart` groupe "Cas nominal chauffeur" (5/7) | **DONE — branchement `auth.hasRole(PlatformRole.driver)` prouvé** |
| F-3 (missionId null/vide) | notification sans mission liée | tap notification sans `missionId` | `markAsRead` appelé, AUCUNE navigation (reste sur `NotificationsScreen`), aucun chevron affiché, aucun crash | `test/notifications/notifications_deep_link_test.dart` groupe "missionId null / vide" (6-7/7) | **DONE — comportement existant (skip silencieux) documenté, non modifié (aucun bug démontré)** |

**Bloc F — clôture** : seam `BackendLocator.notificationRepositoryOverride` ajouté (même pattern que
`missionRepositoryOverride`/`driverRepositoryOverride`/`locationRepositoryOverride`/`proofUploadRepositoryOverride`),
utilisé exclusivement par le nouveau fichier `test/notifications/notifications_deep_link_test.dart`
(7 tests, 7/7 PASS) qui prouve le deep-link notification → navigation → mission, en RÉUTILISANT sans
duplication la protection F-1 (client) et la protection symétrique existante de
`DriverActiveMissionScreen` (chauffeur), ainsi que le fallback `mission == null` déjà en place.
Combiné aux tests F-1/F-2/ROUTE-F-01..06 déjà committés précédemment : **32/32 PASS** au total
sur le périmètre Bloc F. Un seul bug trouvé sur tout le bloc (AppBar overflow, F-2, CORRIGÉ —
voir `PHASE7_BUG_REPORT.md` BUG-007) ; **F-3 n'a révélé aucun nouveau bug** (chaque scénario a
réutilisé une protection déjà correcte sans modification de code de production).
Validation : `flutter analyze` (0 souci nouveau, 3 issues `info` pré-existantes non liées),
`flutter test` (aucune régression). **BLOC F : ✅ FERMÉ.**

## Offline / Réseau / Retry (Bloc G)

Matrice courte (exigence → test existant → COUVERT/GAP), avant codage des GAPS uniquement :

| Exigence G | Test existant | Statut |
|---|---|---|
| Création mission : retry/double-tap/concurrence, une seule mission | `delivery_request_flow_double_submit_test.dart` (2/2 PASS, garde de réentrance) + `createDeliveryRequestIdempotency.test.ts` (2/2 PASS, transaction Firestore atomique) — MIS-C-09 | **COUVERT** (référencé, non dupliqué) |
| Proof upload : échec, mission non completed, retry réussi | `driver_active_mission_proof_upload_test.dart` (Storage throw, `markDeliveryCompleted` jamais appelé, retry possible) | **COUVERT** (référencé, non dupliqué) |
| GPS : service désactivé/permission refusée/rapport échoue | `driver_location_reporter_test.dart` + `driver_active_mission_status_gaps_test.dart` (bandeau GPS) | **COUVERT** (référencé, non dupliqué) |
| Paiement : authorize/capture failure, idempotence, concurrence | Tests Phase 6 (`acceptDeliveryPaymentFailure.test.ts`, `financialConcurrency.test.ts`, etc.) | **COUVERT** (référencé, non dupliqué) |
| Refund : state machine / E2E | Phase 6 (`refundStateMachine.test.ts`, `e2eRefundLifecycle.test.ts`, `e2eRefundPostPayoutLifecycle.test.ts`) | **COUVERT** (référencé, non dupliqué) |
| Payout : provider failure, retry/idempotence, aucun double payout | `submitDriverPayoutFailure.test.ts` (Bloc C, BUG P0 CORRIGÉ) | **COUVERT** (référencé, non dupliqué) |
| Cloud Function `unavailable`/timeout sur une action chauffeur (trajet) | aucun (grep exhaustif `test/` : aucune occurrence de `CloudFunctionException(` avant ce bloc) | **GAP → G-1/G-2** |
| Firestore listener error (`StreamBuilder.hasError`) sur un écran temps réel + reprise après erreur | `snap.hasError` déjà géré dans le code (`CustomerTrackingScreen`, `DriverActiveMissionScreen`, `NotificationsScreen`, tabs admin finance) mais **aucun test ne l'exerce réellement** | **GAP → G-3** |
| Firestore write failure (écriture directe, hors Cloud Function) | `markAsRead`/`markAllAsRead` (`FirebaseNotificationRepository`) sont des écritures directes Firestore jamais testées en échec | **GAP → G-4** |

Budget reconnaissance : ~15% du bloc (une seule passe de grep + lecture ciblée des écrans/repos concernés, aucun audit général).

### G-1 / G-2 — Cloud Function `unavailable` + retry idempotent (chauffeur, trajet)

| ID | Scénario | Étapes | Résultat attendu | Test | Statut |
|---|---|---|---|---|---|
| G-1 | action chauffeur (`updateTrackingStatus`) → CF `unavailable` | tap "partir vers le pickup" → `CloudFunctionException('unavailable', ...)` | aucun faux succès (statut mission inchangé), message d'erreur traduit (`driver_active_mission_cf_error`) affiché, `_actionInProgress` nettoyé, bouton redevient actionnable, aucun crash | `test/network/driver_action_cloud_function_unavailable_test.dart` (1/2) | **DONE** |
| G-2 | retry après échec (même action) → succès, sans duplication | 2e tap sur le même bouton après l'échec | `updateTrackingStatus` rappelé, mission avance correctement au nouveau statut (une seule fois), aucune transition dupliquée/sautée, erreur effacée | `test/network/driver_action_cloud_function_unavailable_test.dart` (2/2) | **DONE** |

### G-3 — Firestore listener error + reprise

| ID | Scénario | Étapes | Résultat attendu | Test | Statut |
|---|---|---|---|---|---|
| G-3.1 | `watchMission` émet une erreur (listener) | `StreamController.addError(...)` sur le stream écouté par `CustomerTrackingScreen` | fallback existant affiché (`driver_active_mission_network_error`), aucun crash, aucun écran blanc, aucune ancienne donnée mission présentée comme valide | `test/network/mission_tracking_listener_error_test.dart` (1/2) | **DONE** |
| G-3.2 | reprise après erreur (nouvelle donnée valide sur le même stream) | après l'erreur, le même `StreamController` émet la mission réelle | `CustomerTrackingScreen` affiche normalement la mission, sans nécessiter un remount de l'écran | `test/network/mission_tracking_listener_error_test.dart` (2/2) | **DONE — reprise naturelle de l'architecture existante, aucune couche offline ajoutée** |

### G-4 — Firestore write failure (écriture directe)

| ID | Scénario | Étapes | Résultat attendu | Test | Statut |
|---|---|---|---|---|---|
| G-4.1 | `markAsRead` (écriture directe Firestore, pas de Cloud Function) échoue au tap sur une notification non lue | tap notification → `NotificationRepository.markAsRead()` throw `CloudFunctionException` | aucun faux succès (le point non-lu ne disparaît pas côté fake, état `_isRead` réellement inchangé), aucun crash de l'app, navigation vers la mission reste fonctionnelle (dégradation acceptable : l'échec de `markAsRead` n'empêche jamais l'accès à la mission) | `test/network/notification_mark_as_read_write_failure_test.dart` (1/2) | **DONE — BUG P2 trouvé + CORRIGÉ (voir ci-dessous)** |
| G-4.2 | retry après échec de `markAsRead` → succès, aucun état bloqué | 2e appel après le 1er échec | l'écriture réussit, compteurs cohérents (1 échec + 1 succès), aucune exception résiduelle | `test/network/notification_mark_as_read_write_failure_test.dart` (2/2) | **DONE** |

**Bug réel trouvé pendant G-4 (TEST → FAIL → FIX → RETEST) — P2, CORRIGÉ** :
`NotificationsScreen.onTap` appelait `BackendLocator.notificationRepository.markAsRead(...)` sans
jamais catcher l'échec (`Future` rejetée non awaited/non catchée) → toute panne réseau/Firestore
transitoire pendant ce tap remontait comme exception non gérée jusqu'au binding Flutter (crash
potentiel en release selon la politique de zone d'erreur de l'app). AVANT le fix : le test G-4.1
faisait planter la suite (`CloudFunctionException` non catchée remontée au test harness). APRÈS le
fix (`.catchError((_) {})` ajouté sur l'appel dans `notifications_screen.dart`, commenté en detail
sur l'intention : le marquage lu/non-lu est un confort UX secondaire, son échec ne doit jamais
bloquer la navigation vers la mission liée) : G-4.1 et G-4.2 PASS, navigation post-tap toujours
fonctionnelle malgré l'échec de l'écriture. Voir `PHASE7_BUG_REPORT.md` pour le détail complet.

**Bloc G — clôture** : 6 tests créés sur les 3 GAPS réels identifiés (G-1+G-2 dans un seul
fichier, G-3.1+G-3.2 dans un seul fichier, G-4.1+G-4.2 dans un seul fichier), **6/6 PASS**
(vérifiés par exécution réelle, pas seulement rédigés). 1 bug P2 réel trouvé et corrigé (détaillé
ci-dessus). Aucune double mission/paiement/payout/ledger possible : ces protections sont déjà
prouvées par les preuves référencées (MIS-C-09, Phase 6 finance, `submitDriverPayoutFailure.test.ts`)
— le Bloc G n'a pas eu besoin de les re-tester, seulement de combler les 3 gaps UI Flutter
identifiés. Aucun bug P0/P1 trouvé. Validation réelle exécutée : `flutter test test/network/`
(6/6 PASS), `flutter analyze` (3 issues `info` pré-existantes non liées, 0 souci nouveau),
`flutter test` complet du projet (**410/410 PASS, aucune régression**).
**BLOC G : ✅ FERMÉ.**

## GPS / Tracking durcissement (Bloc H)

Matrice courte (exigence → test existant → COUVERT/GAP), avant codage du gap réel uniquement :

| Exigence H | Test existant | Statut |
|---|---|---|
| H-1 — GPS désactivé / permission denied / deniedForever / refus-puis-accord / échec `getCurrentPosition`/`reportDriverLocation` | `driver_location_reporter_test.dart` (9 tests, isolé classe `DriverLocationReporter`) | **COUVERT** (référencé, non dupliqué) |
| H-2 — Lifecycle écran : mission active → start ; completed/cancelled → stop ; idempotence start/start et stop/stop | Aucun test existant ne liait le statut mission au lifecycle réel de `DriverLocationReporter` AU NIVEAU `DriverActiveMissionScreen` (seul le bandeau d'erreur GPS et BUG-006 étaient couverts, pas le lifecycle start/stop lui-même) | **GAP → H-2 (comblé ce bloc)** |
| H-3 — BUG-006 (boucle infinie de resynchronisation GPS sur échec permanent) | `driver_active_mission_status_gaps_test.dart` (9 tests, sonde `isLocationServiceEnabled`) | **COUVERT** (réexécuté : 18/18 PASS avec `driver_location_reporter_test.dart`, toujours vert) |
| H-4 — Sécurité tracking : chauffeur assigné write autorisé / autre chauffeur DENIED / client propriétaire read autorisé / autre client DENIED / non authentifié DENIED / historique trajet écriture directe interdite (Cloud Function only) | `functions/test/integration/securityRules.test.ts` lignes ~1513-1750, describe \"driver_locations/{driverId}\" + \"driver_locations/{driverId}/history/{eventId}\" (16 tests ciblés : write self OK, write autre chauffeur DENIED, read sans mission active DENIED, read avec mission active assignée OK, read mission active mais autre chauffeur DENIED, read après nettoyage `active_delivery_id=null` DENIED, analyste read tout OK, non-authentifié DENIED (read+write), écriture directe historique interdite même pour super_admin, lecture historique propriétaire/tiers/analyste) | **COUVERT** (référencé, non dupliqué — aucun gap réel identifié) |
| H-5 — Background/Foreground (tracking continue hors écran actif / app en arrière-plan) | Aucune implémentation : `AndroidManifest.xml` ne demande PAS `ACCESS_BACKGROUND_LOCATION` (commenté explicitement), `driver_location_reporter.dart` documente \"Ne tourne jamais en arrière-plan\" | **DEFERRED NON-BLOCKING → Phase 8** (non implémenté, dépend de permissions OS avancées + configuration Android/iOS production ; documentation uniquement, aucun code construit ce bloc) |
| H-6 — Position stale/invalide (âge de la position, coordonnées invalides) | Grep exhaustif : aucun consommateur (`LiveTrackingMap`, écrans client/chauffeur) ne lit/valide `DriverLocation.updatedAt` pour détecter une position périmée | **N/A — architecture actuelle ne dépend pas de cette validation** (aucun moteur de validation construit arbitrairement, conformément à la consigne) |

Budget reconnaissance : ~15-20% du bloc (lecture ciblée de `driver_location_reporter.dart`,
`driver_location_reporter_test.dart`, `driver_active_mission_status_gaps_test.dart`,
`driver_active_mission_screen.dart`, `securityRules.test.ts` section driver_locations,
`AndroidManifest.xml`). Aucun audit général, aucune relecture redondante.

### H-2 — Lifecycle GPS écran (nouveau test)

| ID | Scénario | Étapes | Résultat attendu | Test | Statut |
|---|---|---|---|---|---|
| H-2.1 | CAS 1 — mission dans un statut de partage (`assigned`) | montage `DriverActiveMissionScreen` | 1 rapport de position immédiat, `checkPermission()` appelé une seule fois | `driver_active_mission_gps_lifecycle_test.dart` | **DONE** |
| H-2.2 | CAS 2 — mission `inTransit` → `completed` | `advanceTo(completed)` puis 5 pumps supplémentaires | aucun nouveau rapport, aucune nouvelle vérification de permission, écran \"déjà complétée\" affiché | `driver_active_mission_gps_lifecycle_test.dart` | **DONE** |
| H-2.3 | CAS 3 — mission `driverToPickup` → `cancelled` | `advanceTo(cancelled)` puis 5 pumps supplémentaires | même exigence que CAS 2, écran \"annulée\" affiché | `driver_active_mission_gps_lifecycle_test.dart` | **DONE** |
| H-2.4 | Idempotence lifecycle (transitions internes toutes \"partage actif\") | `assigned → driverToPickup → arrivedAtPickup` | `checkPermission()` appelé UNE SEULE fois au total (jamais de 2e boucle démarrée) | `driver_active_mission_gps_lifecycle_test.dart` | **DONE** |
| H-2.5 | Nettoyage dispose() | démontage de l'écran pendant partage actif | `stop()` exécuté sans exception (`tester.takeException()` == null), aucun rapport résiduel | `driver_active_mission_gps_lifecycle_test.dart` | **DONE** |
| H-2.6 | Idempotence `stop()`/`stop()` isolée | `DriverLocationReporter().stop()` appelé deux fois de suite, jamais démarré | aucune exception (`returnsNormally`), `isRunning` reste `false` | `driver_active_mission_gps_lifecycle_test.dart` | **DONE** |

**Bloc H — clôture** : 1 nouveau fichier créé (`test/driver/driver_active_mission_gps_lifecycle_test.dart`,
6 tests), comblant le seul GAP réel identifié (H-2). H-1/H-3/H-4 référencés sans duplication
(réexécutés pour H-3 : 18/18 PASS). H-5 documenté `DEFERRED NON-BLOCKING → Phase 8`. H-6 documenté
`N/A`. Aucun bug P0/P1/P2/P3 trouvé pendant ce bloc — le code de production (`_syncGpsSharing()`,
`DriverLocationReporter.start()/stop()`) se comporte exactement comme attendu au niveau écran, sans
qu'aucune correction n'ait été nécessaire. Validation réelle exécutée : `flutter test
test/driver/driver_active_mission_gps_lifecycle_test.dart` (6/6 PASS), `flutter test
test/driver/driver_active_mission_status_gaps_test.dart test/driver/driver_location_reporter_test.dart`
(18/18 PASS, aucune régression BUG-006), `flutter analyze` (0 souci nouveau), `flutter test` complet
(voir validation croisée finale). **BLOC H : ✅ FERMÉ.**

## Notifications (Bloc I)

| Exigence I | Test existant | Statut |
|---|---|---|
| I-1 création (8 transitions statut) | `functions/test/integration/onMissionStatusChangeNotifyCustomer.test.ts` (15 cas : 8 transitions + garde-fous + anti-fuite croisée) | COUVERT (référencé, non dupliqué) |
| I-1 création secondaire (`detectExpiringDocuments`, `transitionFoundingDriverPeriods`) | Aucun test dédié trouvé | GAP mineur documenté DEFERRED (logique simple, même schéma déjà validé par le trigger principal ; pas de bug démontré) |
| I-2 read/unread + badge | **GAP** avant ce tour | COMBLÉ : `test/notifications/notifications_realtime_and_unread_test.dart` (I-2.1/I-2.2/I-2.3, 3 tests) |
| I-3 realtime + listener error (`NotificationsScreen`) | **GAP** avant ce tour (pattern G-3 existait seulement sur `CustomerTrackingScreen`) | COMBLÉ : même fichier (I-3.1/I-3.2/I-3.3, 3 tests) |
| I-4 duplication/idempotence notification création | Architecture par `onDocumentUpdated` : un déclenchement = une écriture réelle de statut ; aucun scénario de duplication réelle démontré en usage normal | Non-bloquant, pas de nouveau système construit arbitrairement |
| I-5 navigation post-tap | Bloc F, `notifications_deep_link_test.dart` | COUVERT (référencé, non dupliqué) |
| I-6 FR/EN/ES notifications | Audit direct `lib/l10n/app_strings.dart` (toutes clés `notif_*`/`notifications_*` présentes en FR/EN/ES) | COUVERT |
| I-7 push mobile externe (FCM/APNs) | Aucune dépendance `firebase_messaging`/FCM/APNs dans le projet | DEFERRED / Phase 8 |

Nouveau fichier : `test/notifications/notifications_realtime_and_unread_test.dart` (6 tests, 6/6 PASS).
Validation : `flutter test` complet 422/422 PASS (+6 vs 416 post-Bloc H), `flutter analyze` 0 souci nouveau.
**BLOC I : ✅ FERMÉ.**

## Responsive / Viewports (Bloc J)

**Matrice de couverture d'écrans J-0** (AUTH : Login/Signup ; CLIENT : création demande/devis/
recherche chauffeur/tracking/complétée/notifications ; DRIVER : onboarding/statut/dashboard/
jobs/mission active/preuve/gains ; ADMIN : login/revue chauffeurs/missions/dashboard finance) —
3 écrans critiques sélectionnés pour test réel ce bloc (représentatifs de chaque famille de
layout à risque : AppBar dense, formulaire, dialogue modal) :

| Exigence J | Test existant | Statut |
|---|---|---|
| J-1/J-2 — matrice de viewports (320/360/390/430/480px) + non-régression BUG-007 | Aucun test existant ne faisait varier la largeur de `ProviderDashboardShell` au-delà du défaut 800×600 (`provider_dashboard_shell_status_gate_test.dart` relu, confirmé) | **GAP → comblé ce bloc** |
| J-3 — effet FR/EN/ES sur écran critique | Aucun test de largeur+langue combinées sur `AuthScreen` | **GAP → comblé ce bloc** |
| J-4 — clavier/formulaires (CTA accessible/scrollable) | Scrollabilité de `AuthScreen` héritée de `AppShell`/`SingleChildScrollView`, jamais prouvée sous hauteur réduite (clavier virtuel) | **GAP → comblé ce bloc** |
| J-5 — modals/dialogs (contenu visible, boutons accessibles, sans overflow) | Aucun test de `SafetyScreen`/dialogue de signalement à largeur étroite | **GAP → comblé ce bloc, a révélé BUG-009** |
| J-6 — web/desktop (écrans réellement prévus en web) | `test/finance/admin_finance_ui_test.dart` (`NavigationRail` desktop 1200×900) | **COUVERT** (référencé, non dupliqué — aucun autre écran n'est prévu en usage desktop dans le périmètre actuel) |

Budget reconnaissance : ~15-20% du bloc (relecture ciblée de
`provider_dashboard_shell_status_gate_test.dart`, `admin_finance_ui_test.dart`,
`provider_dashboard_shell.dart`, `auth_screen.dart`, `app_shell.dart`, `safety_screen.dart`).
Aucun audit général, aucune relecture redondante.

### J-1/J-2/J-3/J-4/J-5 — nouveau test `critical_screens_viewport_test.dart`

| ID | Scénario | Étapes | Résultat attendu | Statut |
|---|---|---|---|---|
| J-1/J-2.1-5 | `ProviderDashboardShell` à 320/360/390/430/480px | montage + mesure overflow + tap Switch | 0 overflow, Switch toujours visible et fonctionnel (régression BUG-007 vérifiée sur toute la matrice) | **DONE** (5/5 PASS) |
| J-1/J-2.6 | `ProviderDashboardShell` à 600px (phablette) | montage | 0 overflow, libellés décoratifs réapparaissent (`isNarrowPhone == false`) | **DONE** |
| J-3.1-3 | `AuthScreen` en fr/en/es à 320px | montage par langue | 0 overflow, textes `auth_welcome`/`auth_choose_role` trouvés | **DONE** (3/3 PASS) |
| J-4.1 | `AuthScreen` mode inscription, hauteur réduite (375×320, clavier simulé) | bascule inscription + `ensureVisible` sur 3 champs + CTA final | tous les champs et le CTA restent atteignables via scroll | **DONE** |
| J-5.1 | `SafetyScreen`, dialogue de signalement à 320px | tap "Signaler un problème" → vérifier `AlertDialog` → tap "Annuler" | contenu visible, champ texte + boutons accessibles, 0 overflow, fermeture sans exception | **DONE après correctif BUG-009** (échec au 1er essai : overflow 146px détecté et corrigé) |

**Bug trouvé** : **BUG-009** (P2, CORRIGÉ) — overflow du bandeau "Signaler un problème" dans
`SafetyScreen` à 320px de large (voir `docs/PHASE7_BUG_REPORT.md` pour le détail complet
Contexte/Cause/Correctif/Test de régression).

**Bloc J — clôture** : 1 nouveau fichier créé (`test/responsive/critical_screens_viewport_test.dart`,
11 tests), comblant les 4 GAPS réels identifiés (J-1/J-2, J-3, J-4, J-5). J-6 référencé sans
duplication. 1 bug trouvé et corrigé (BUG-009, P2, UI uniquement). Aucun bug P0/P1. Validation
réelle exécutée : `flutter test test/responsive/critical_screens_viewport_test.dart` (10/11 puis
11/11 PASS après correctif), `flutter analyze` (0 souci nouveau, y compris sur
`safety_screen.dart` modifié), `flutter test` complet du projet (**433/433 PASS**, +11 vs 422
post-Bloc I, aucune régression). **BLOC J : ✅ FERMÉ.**

## I18N Global (Bloc K) — EN COURS

| Zone / écran | Couverture i18n existante | Statut |
|---|---|---|
| Dictionnaire `app_strings.dart` (753 clés) | 0 clé avec locale manquante, 0 doublon (audit programmatique) | COUVERT |
| Cohérence clés utilisées vs définies (426 appels `t()`) | 0 clé utilisée non définie | COUVERT |
| Auth — `admin_login_screen.dart` | 0 usage `LocaleProvider`, tout FR codé en dur | **GAP (critique)** |
| Auth — `auth_screen.dart` | `t()` utilisé mais ~10 chaînes résiduelles (redirections, labels, erreurs validation) | **GAP (partiel)** |
| Client — `customer_profile_tab.dart` | 0 usage `LocaleProvider` | **GAP** |
| Client — `customer_messages_tab.dart` | 0 usage `LocaleProvider` (écran placeholder) | **GAP (mineur)** |
| Client — `mechanic_request_flow_screen.dart` (Steps 2-4) | `t()` en tête de fichier mais sous-widgets Step2/3/4 hardcodés | **GAP (partiel)** |
| Chauffeur — `provider_profile_tab.dart` | 0 usage `LocaleProvider`, `_statusLabel()` duplique les clés `driver_status_*` existantes | **GAP** |
| Chauffeur — `driver_onboarding_screen.dart` | `t()` utilisé mais ~14 `labelText`/titres résiduels | **GAP (partiel)** |
| Chauffeur — `mechanic_onboarding_screen.dart` | 1 usage `LocaleProvider`, 2 chaînes résiduelles | **GAP (mineur)** |
| Admin — `app_shell.dart` | Majoritairement `t()`, 2 `PopupMenuItem` résiduels | **GAP (mineur)** |
| Admin — `admin_dashboard_shell.dart` | `NavigationRail` labels + "Activer la commission" hardcodés | **GAP (partiel)** |
| Admin — `admin_drivers_list_screen.dart` | 1 seul mot "Retry" à remplacer par `common_retry` | **GAP (trivial)** |
| Admin — finance tabs (erreurs K-6) | 6 messages d'exception brute → **corrigés (BUG-010)**, réutilisation de `admin_action_error` | COUVERT (après correctif) |
| Notifications (K-5, référence Bloc I) | Clés `notif_*`/`notifications_*` déjà confirmées COUVERT en Bloc I | COUVERT (référencé, pas dupliqué) |

**Bilan intermédiaire** : dictionnaire et cohérence des clés sains ; le GAP réel se situe dans
plusieurs écrans/fichiers qui n'appellent jamais `LocaleProvider.t()` ou n'en font qu'un usage
partiel. 1 bug corrigé ce tour (BUG-010, P2). Bloc K reste **EN COURS** — voir
`docs/PHASE7_QA_PLAN.md` et `docs/PHASE7_BUG_REPORT.md` pour le point de reprise exact.

## Timezone / Date (Bloc K2) et Accessibilité MVP (Bloc L)
Non démarrés à ce commit — prochaine session.

## Sécurité / Performance
Voir blocs dédiés Q, M — matrice à enrichir au fur et à mesure des tests réels.

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

## MISE À JOUR — Bloc K FERMÉ (reprise K-5 résidus 4/7→7/7 + Notifications + K-9)

| Écran / zone | État | Statut |
|---|---|---|
| `mechanic_request_flow_screen.dart` (résidu 4/7) | Toutes chaînes Steps 2-4 + résumé corrigées | **COUVERT** |
| `app_shell.dart` (résidu 5/7) | PopupMenu + footer corrigés | **COUVERT** |
| `admin_dashboard_shell.dart` (résidu 6/7) | Titre/nav/overview/settings corrigés | **COUVERT** |
| `admin_drivers_list_screen.dart` (résidu 7/7) | "Retry" → `common_retry` | **COUVERT** |
| Notifications (K-5, contenu) | 9 paires `notif_*` FR/EN/ES complètes ; tooltip bell câblé | **COUVERT** |
| K-9 tests structurels | `app_strings_structural_test.dart` (dictionnaire + scan statique 592 appels) + 2 widget tests ciblés | **EN PLACE** |

**Bloc K : ✅ FERMÉ.** `flutter analyze` 3 infos pré-existantes / 0 erreur. `flutter test` 464/464 PASS.

**Gap différé (hors K, documenté pour K2-3)** : connecteur `'à'` codé en dur dans le formatage
date/heure local (`notifications_screen.dart` + 4 autres fichiers) — comparaison sur instants
réels non affectée, uniquement l'affichage textuel du connecteur.

## Timezone / Date (Bloc K2) et Accessibilité MVP (Bloc L)
Toujours NON DÉMARRÉS à ce commit — reprise prévue en priorité sur K2-0.
