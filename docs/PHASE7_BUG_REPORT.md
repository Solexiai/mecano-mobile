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

## BUG-002 — `CustomerTrackingScreen` sans garde d'authentification (message trompeur)

- **Composant** : `lib/screens/customer/customer_tracking_screen.dart`.
- **Sévérité** : **P3 (UX mineur)** — AUCUN impact sécurité : `firestore.rules` sur
  `delivery_requests/{missionId}` est déjà correctement scopée (confirmé par la suite Security
  Rules, 196/196 PASS) — un utilisateur non authentifié n'a jamais accès aux données réelles,
  le flux échoue toujours côté serveur avant toute fuite. Le seul défaut est côté présentation.
- **Découvert pendant** : Phase 7, Bloc B, scénario MIS-C-07 (accès non authentifié à l'écran de
  suivi de mission).
- **Cause** : contrairement à ses écrans « frères » protégés (`CustomerDashboardShell`,
  `ProviderDashboardShell`, `DriverActiveMissionScreen`), `CustomerTrackingScreen` n'implémentait
  aucune garde `FirebaseAuthProvider.isSignedIn` — un utilisateur déconnecté voyait le message
  générique `driver_active_mission_network_error` ("erreur réseau"), incohérent et trompeur.
- **Correctif appliqué** :
  1. Nouvelle clé i18n `tracking_locked_message` (fr/en/es) dans `lib/l10n/app_strings.dart`.
  2. Garde ajoutée au tout début de `build()` : si `!auth.isSignedIn`, affiche un `Scaffold` dédié
     (icône verrou, message clair, bouton "se connecter" -> `/$locale/connexion`), suivant
     exactement le pattern déjà établi dans `CustomerDashboardShell`.
  3. Le reste du flux (StreamBuilder Firestore, timeline, preuve de livraison, section
     financière) reste strictement inchangé pour un utilisateur authentifié.
- **Test de régression** : `test/customer/customer_tracking_screen_auth_test.dart` (2 tests,
  widget-test pur avec `FirebaseAuthProvider(backendConfigured: false)`, aucun émulateur requis)
  → **2 passed, 2 total**.
- **Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc B).

---

## BUG-003 — `DeliveryRequestFlowScreen` : bouton "Suivant" figé désactivé selon l'ordre de saisie (étapes 1 et 2)

- **Composant** : `lib/screens/delivery/delivery_request_flow_screen.dart` (`_Step1ItemInfo`,
  `_Step2Addresses`).
- **Sévérité** : **P1** — blocage total possible de la création d'une mission client sur un
  parcours utilisateur courant (aucun contournement UI disponible une fois le bouton figé
  désactivé ; seul un redémarrage du flux, potentiellement inefficace selon l'ordre de saisie
  répété, permettrait de s'en sortir).
- **Découvert pendant** : Phase 7, Bloc B, MIS-C-09 (E2E client — double soumission réseau),
  en construisant le widget test du Cas A (double-tap UI) : un test de diagnostic minimal a
  révélé que le formulaire ne progressait jamais au-delà de l'étape 1 malgré catégorie et
  description valides.
- **Cause racine** : `StepProgressForm.canProceed(step)` (callback fourni par
  `_DeliveryRequestFlowScreenState.build()`) lit directement `_descController.text` (étape 0)
  et les `.text` de 10 `TextEditingController` d'adresse (étape 1, pickup + dropoff). Ces
  contrôleurs sont passés à des `TextField` dans des widgets enfants `StatelessWidget`
  (`_Step1ItemInfo`, `_Step2Addresses`) **sans aucun callback `onChanged` déclenchant un
  `setState()` sur le parent**. Un `TextEditingController` ne provoque par lui-même aucun
  rebuild de `StepProgressForm` (qui ne l'écoute pas) : `canProceed` n'est donc réévalué que
  lors d'un `setState` déclenché par ailleurs (ex. sélection d'une catégorie/`ChoiceChip`).
  Concrètement : si l'utilisateur (1) choisit la catégorie, PUIS (2) saisit la description, le
  dernier `setState` a eu lieu à l'étape (1) — où la description était encore vide — et
  `canProceed` reste figé sur `false` en permanence, même une fois la description remplie,
  car aucun événement ne redéclenche le calcul. Même mécanisme pour les 10 champs d'adresse de
  l'étape 2 (`pickupLine1/City/Postal/Lat/Lng`, `dropoffLine1/City/Postal/Lat/Lng` — les champs
  optionnels `contactController`/`accessController` ne sont pas concernés, absents de
  `canProceed`).
- **Reproduction** : test de diagnostic ad hoc (widget test minimal, non conservé) confirmant
  `nextBtn.onPressed == null` après saisie catégorie + description complètes, chip bien
  `selected: true`, texte bien présent dans le controller (`tf.controller?.text == "Canape"`)
  — élimine toute cause côté validation elle-même, isole strictement l'absence de rebuild.
- **Correctif appliqué** :
  1. `_Step1ItemInfo` : ajout du paramètre `onDescriptionChanged` (`VoidCallback`), branché sur
     `TextField(controller: descController, onChanged: (_) => onDescriptionChanged())`. Site
     d'appel (`build()` du parent) : `onDescriptionChanged: () => setState(() {})`.
  2. `_Step2Addresses` : ajout du paramètre `onAddressFieldChanged` (`VoidCallback`), branché en
     `onChanged` sur les 10 `TextField` participant à `canProceed(step == 1)` (pickup et dropoff
     : line1, city, postal, lat, lng). Site d'appel : `onAddressFieldChanged: () => setState(() {})`.
  3. Aucune refonte : le pattern déjà utilisé pour les autres callbacks (`onCategorySelected`,
     `onQuantityChanged`, etc.) est simplement étendu aux champs texte concernés.
- **Test de régression** : `test/customer/delivery_request_flow_double_submit_test.dart` —
  le scénario `_fillFormAndReachQuoteStep`/`fillFormAndReachQuoteStep` reproduit exactement
  l'ordre catégorie-puis-description (étape 1) et la saisie des 10 champs d'adresse (étape 2) ;
  sans le correctif, ce helper bloque indéfiniment dès l'étape 1 (bouton "Suivant" jamais
  actif) et les deux tests du fichier échouent avant même d'atteindre l'assertion de
  double-submit. Après correctif : **2 passed, 2 total**.
- **Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc B, MIS-C-09).

---

## BUG-003 — occurrence DriverOnboarding (récurrence confirmée, même cause racine)

- **Composant** : `lib/screens/driver/driver_onboarding_screen.dart` (étape 0 — Profil,
  `_DriverOnboardingScreenState.build()`).
- **Sévérité** : **P1** — même impact que l'occurrence originale (blocage total du funnel
  d'inscription chauffeur si nom/email/password sont saisis sans déclencher un autre
  `setState`).
- **Découvert pendant** : Phase 7, Bloc C, ACTION 1 (test de diagnostic ciblé explicitement
  demandé pour vérifier si `DriverOnboardingScreen` était affecté par le même pattern que
  BUG-003 sur `DeliveryRequestFlowScreen`).
- **Cause racine** : identique à BUG-003 original — `canProceed(0)` lit directement
  `_nameController.text` / `_emailController.text` / `_passwordController.text`, mais les 3
  `TextField` correspondants n'avaient aucun `onChanged` déclenchant un `setState()` du
  parent. Différence structurelle avec l'occurrence originale : ici les champs sont inline
  dans `build()` (pas dans un `StatelessWidget` enfant séparé), donc le correctif n'a pas eu
  besoin d'introduire un nouveau paramètre `VoidCallback`.
- **Reproduction** : `test/driver/driver_onboarding_step0_rebuild_test.dart` — avant
  correctif, `nextButton.onPressed` restait `null` après saisie complète des 3 champs (aucune
  autre action `setState`) → **FAIL** confirmé.
- **Correctif appliqué** : ajout de `onChanged: (_) => setState(() {})` directement sur les 3
  `TextField` (nom, email, password) de l'étape 0, avec commentaire renvoyant explicitement à
  BUG-003.
- **Test de régression** : même fichier, retesté après correctif → **1 passed, 1 total**.
- **Classification** : rattaché à **BUG-003** (pas de nouveau BUG-004 créé, cause racine
  identique, conformément à la consigne explicite du Bloc C/ACTION 1).
- **Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc C, ACTION 1).

---

## BUG-004 — Rollback silencieux à l'échec de versement chauffeur (`submitDriverPayout`)

- **Composant** : `functions/src/payment/paymentOrchestration.ts` (`submitDriverPayout`).
- **Sévérité** : **P0** — risque financier : un échec du provider de paiement lors du
  versement (`provider.createDriverPayout()`) pouvait laisser le payout dans un état
  incohérent (transition partielle) sans que l'échec ne soit répercuté de façon fiable et
  re-tentable, avec risque de double versement ou de perte de traçabilité.
- **Découvert pendant** : Phase 7, Bloc C, item 2 (payout submission failure), en écrivant
  `submitDriverPayoutFailure.test.ts` (ajout de `forceCreateDriverPayoutFailure` sur
  `FakePaymentProvider`, même pattern que `forceAuthorizeFailure`/`forceCaptureFailure`).
- **Cause racine** : le chemin d'échec de `submitDriverPayout()` ne garantissait pas de façon
  systématique la transition `PROCESSING -> FAILED` avec `failure_reason` renseigné avant tout
  autre effet (ledger, audit `payout_paid`) ; un échec provider pouvait laisser le payout dans
  un état ambigu, empêchant un retry propre (`FAILED -> SCHEDULED`, transition valide dans
  `payoutStateMachine.ts`).
- **Correctif appliqué** : garantie que `provider.createDriverPayout()` en échec produit
  toujours `status: FAILED`, `failure_reason` renseigné, aucun `paid_at`/`provider_payout_id`
  factice, aucune écriture `transaction_ledger`, `mission_financial_balance.driver_paid_minor`
  inchangé (reste à 0), un seul document `driver_payouts` (pas de duplication), et retry
  (`submitDriverPayout` rejoué sur un payout `FAILED`) qui échoue proprement à nouveau sans
  dupliquer d'effet financier.
- **Test de régression** : `functions/test/integration/submitDriverPayoutFailure.test.ts` —
  couvre échec provider (FAILED, pas PAID, audit `payout_submitted` présent, ledger vide,
  balance à 0, retry propre) + cas `missing_connected_account` (échec avant tout appel
  provider). Résultat : **PASS** (suite intégrée dans le run global Bloc C, 56/56 PASS avec les
  8 autres suites d'intégration pertinentes).
- **Commit** : `b4b79fd` ("Phase 7 Bloc C item 2: test payout submission failure + fix BUG P0
  rollback silencieux").
- **Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc C, item 2).

---

## BUG-005 — `ProviderJobsTab` : Stream Firestore recréé à chaque `setState()`

- **Composant** : `lib/screens/mechanic_provider/provider_jobs_tab.dart`.
- **Sévérité** : **P1** — UX dégradée + charge Firestore inutile : la carte "Acceptation en
  cours..." disparaissait au profit de l'écran de chargement générique pendant une action
  utilisateur normale, et un nouvel abonnement Firestore était recréé à chaque frame.
- **Découvert pendant** : Phase 7, Bloc C, item 3 (1/3), en écrivant
  `provider_jobs_tab_test.dart` après ajout du seam `driverRepositoryOverride`.
- **Cause racine** : `watchAvailableMissionsForDriver()` et `watchActiveMissionForDriver()`
  étaient appelés directement dans `build()`. Le `setState()` synchrone de `_accept()`
  (passage `isAccepting=true`) déclenchait un rebuild immédiat → nouveau `Stream` à chaque
  frame → le `StreamBuilder` repassait en `ConnectionState.waiting`, masquant la carte
  "Acceptation en cours..." et recréant un abonnement Firestore inutile à chaque frappe.
- **Correctif appliqué** : streams mémorisés par `driverId` (`_ensureStreams()`), jamais
  recréés tant que le `driverId` ne change pas.
- **Test de régression** : `test/driver/provider_jobs_tab_test.dart` (8 tests) — mission
  admissible visible avec offre, liste vide, acceptation réussie + navigation, loading pendant
  la requête (bouton désactivé + carte visible), stream non recréé pendant `setState`. Résultat :
  **8/8 PASS**.
- **Commit** : `0259619` ("Phase 7 Bloc C item 3 (1/3): seam driverRepositoryOverride + tests
  ProviderJobsTab + fix BUG P1 (Stream recréé à chaque setState)").
- **Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc C, item 3).

---

## BUG-006 — `DriverActiveMissionScreen` : boucle infinie de resynchronisation GPS sur échec permanent

- **Composant** : `lib/screens/driver/driver_active_mission_screen.dart` (`_syncGpsSharing()`).
- **Sévérité** : **P1** — martèlement du service de localisation natif à chaque frame en cas
  d'échec GPS permanent (service désactivé / permission refusée), avec risque de dégradation de
  performance et de batterie sur un vrai appareil.
- **Découvert pendant** : Phase 7, Bloc C, item 3 (2/3), en écrivant
  `driver_active_mission_status_gaps_test.dart` (test de sonde comptant les appels
  `isLocationServiceEnabled`).
- **Cause racine** : `_syncGpsSharing()` était rappelé via `addPostFrameCallback` à CHAQUE
  `build()`. Si le GPS échoue durablement, `isRunning` restait `false` indéfiniment → chaque
  build retentait `start()` → `onError` → `setState()` → nouveau build → boucle infinie
  (confirmé par test de sonde : 10 appels `isLocationServiceEnabled` en 20 frames).
- **Correctif appliqué** : `_syncGpsSharingIfStatusChanged()` ne resynchronise que lorsque le
  statut GPS change réellement (mémoïsation du dernier statut connu), au lieu de retenter à
  chaque frame.
- **Test de régression** : `test/driver/driver_active_mission_status_gaps_test.dart` (9 tests) —
  couvre les 7 statuts de trajet (assigned → completed), disponibilité exclusive des actions
  par statut, erreur GPS pendant le trajet (pas de boucle, bandeau affiché une fois), double-tap
  protégé. Résultat : **9/9 PASS**.
- **Commit** : `19942c2` ("Phase 7 Bloc C item 3 (2/3): tests gaps DriverActiveMissionScreen
  (statuts trajet, GPS, double-tap) + fix BUG P1 (boucle infinie GPS sur echec permanent)").
- **Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc C, item 3).

---

## Bloc D — ANALYSTE/ADMIN/SUPER ADMIN : aucun nouveau bug

**Résultat** : 36 nouveaux tests (`functions/test/integration/adminPrivilegedActions.test.ts`)
couvrant les 10 Cloud Functions callables jusque-là non testées (`setUserRole`, `suspendDriver`,
`reactivateDriver`, `requestDriverDocuments`, `updatePricingConfiguration`, `applyDriverPromotion`,
`qualifyFoundingDriver`, `revokeFoundingDriverStatus`, `createFinancialSnapshot`,
`logDriverReviewOpened`) plus le gap "permission-denied" sur `validateDriverDocument`/
`rejectDriver` — **36/36 PASS au premier essai, aucun bug trouvé**. Chaque garde de rôle
(`requireAdminOrAbove`/`requireAnalystOrAbove`/`requireSuperAdmin`) fonctionne exactement comme
prévu par le code source. **Aucune entrée BUG-007+ à ajouter pour ce bloc.**

---

## Bloc E — AUTH/SESSION/CLAIMS : aucun nouveau bug applicatif

**Résultat** : 29 nouveaux tests (`test/auth/admin_auth_gate_session_claims_test.dart` 13/13 PASS +
`functions/test/integration/authSessionClaims.test.ts` 16/16 PASS) couvrant session (signup/login/
logout/mauvais mot de passe/email inconnu/refresh token), claims (chargement/échec réseau/
downgrade), et round-trip de rôles via `setUserRole` (Bloc D) sur des callables sensibles
(`suspendDriver`, `requestDriverDocuments`). **Aucun bug P0/P1 applicatif trouvé.**

Deux corrections de type "erreur d'écriture de test" (pas des bugs produit) ont eu lieu via
TEST→FAIL→FIX→RETEST DANS le nouveau fichier lui-même, documentées en commentaire inline :
1. AUTH-E-S06 : assertion `id_token` forcément différent après refresh — invalide car l'émulateur
   Auth émet des JWT non signés (`alg: none`) et déterministes ; si signup+refresh ont lieu dans la
   même seconde sans changement de claims, le texte du token peut être identique. Assertion
   retirée, les assertions significatives (`claims.user_id === localId`) conservées.
2. AUTH-E-C04 : `setUserRole` ciblait un UID Auth jamais créé → `"There is no user record..."`.
   Corrigé par l'ajout d'un `authAdmin.createUser()` préalable dans le test.

**Durcissement proactif (pas un correctif de bug)** : `functions/src/functions/setUserRole.ts`
appelle désormais `authAdmin.revokeRefreshTokens(targetUid)` après `setCustomUserClaims()`, en
défense en profondeur. Limitation documentée : n'invalide pas un ID token déjà émis et non expiré
(`onCall` n'utilise pas `checkRevoked: true`) — risque résiduel connu, hors périmètre d'un
correctif ciblé. Aucune régression sur les 36 tests Bloc D (`adminPrivilegedActions.test.ts`).

**Aucune entrée BUG-007+ à ajouter pour ce bloc.**

---

## Bloc F — ROUTING/DEEP LINKS

### BUG-007 (P2, CORRIGÉ) — Overflow AppBar `ProviderDashboardShell` sur téléphone étroit

**Contexte** : découvert en écrivant le test de non-régression du Switch online/offline (gap F-2,
`provider_dashboard_shell_status_gate_test.dart`), PAS un bug pré-existant connu.

**Cause** : sur téléphone étroit (320-428px de large, iPhone SE jusqu'à iPhone Pro Max), l'AppBar
de `ProviderDashboardShell` (bouton retour + titre "Espace fournisseur" + libellé statut
"Disponible"/"Hors ligne" + Switch online/offline + cloche notifications + sélecteur de langue +
bouton déconnexion) dépassait l'espace horizontal disponible → `RenderFlex` overflow reproductible
sur toutes les largeurs de téléphone testées (320/390/412/428px), sauf 360px. Confirmé via
`tester.view.physicalSize` (API correcte dans ce contexte de test ; `setSurfaceSize()` est
deprecated et ne propage pas fidèlement `MediaQuery.size`).

**Correctif** : AppBar responsive sous 480px de large (`isNarrowPhone = screenWidth < 480`) —
masque UNIQUEMENT les libellés texte décoratifs ("Espace fournisseur", "Disponible"/"Hors ligne",
sélecteur de langue compact). **Aucune action essentielle n'est masquée** : le Switch
online/offline (action de sécurité critique du gap F-2) reste TOUJOURS visible et fonctionnel sur
toutes les largeurs, avec un `Tooltip` préservant l'information de statut de façon accessible même
sans le texte.

**Fichier modifié** : `lib/screens/dashboard/provider/provider_dashboard_shell.dart`
(58 insertions / 22 suppressions).

**Test de régression** : `test/driver/provider_dashboard_shell_status_gate_test.dart` (4/4 PASS —
pending_review → Switch désactivé, suspended → Switch désactivé, approved → Switch actif
(régression), défense niveau 2 backend). Revérifié manuellement : 0 overflow sur
320/360/390/412/428/600px après correction. `flutter analyze` : clean sur le fichier impacté.

**Statut** : CORRIGÉ, aucune régression détectée.

### F-3 (deep-link notification → mission) : aucun nouveau bug

**Résultat** : nouveau fichier `test/notifications/notifications_deep_link_test.dart` (7 tests,
7/7 PASS au premier essai) couvrant notification client valide (F-3.1), mission
supprimée/inexistante (F-3.2), mission d'un autre utilisateur côté client et côté chauffeur
(F-3.3), branchement client/chauffeur nominal, et `missionId` null/vide. Chaque scénario a atteint
une protection déjà correcte et existante (F-1 côté client, `mission.driverId != uid` côté
chauffeur, fallback `mission == null`) **sans qu'aucune modification de code de production n'ait
été nécessaire**. Ajout technique associé : seam `BackendLocator.notificationRepositoryOverride`
(infrastructure de test uniquement, même pattern que les seams existants) — pas un correctif de
bug.

### ROUTE-F-01 à ROUTE-F-06 (routes invalides/paramètres invalides) : aucun nouveau bug

**Résultat** : `test/routing/app_router_invalid_routes_test.dart` (6/6 PASS) confirme que
l'absence volontaire de `errorBuilder`/`onUnknownRoute` personnalisé dans
`lib/router/app_router.dart` n'est PAS un défaut : le fallback par défaut de
`MaterialApp.router`/GoRouter ("Page Not Found" + bouton Home) gère proprement toute route
inconnue ou paramètre manquant, sans écran blanc, sans exception, sans fuite d'autorisation
(routes admin protégées redirigent vers `AdminLoginScreen`) et sans boucle de redirection.

**Bilan Bloc F** : 1 bug trouvé et corrigé (BUG-007, P2, UI uniquement — aucun impact
sécurité/données). F-1, F-3, et ROUTE-F-01..06 n'ont révélé aucun nouveau bug.

---

## BUG-008 — `NotificationsScreen` : échec de `markAsRead()` jamais catché (exception non gérée)

- **Composant** : `lib/screens/notifications/notifications_screen.dart` (callback `onTap` de
  `_NotificationTile`).
- **Sévérité** : **P2** — `markAsRead()` est une écriture Firestore directe (pas de Cloud
  Function) protégée uniquement par firestore.rules ; en cas d'échec (permission-denied
  transitoire, coupure réseau), le `Future` rejeté n'était jamais `await`é ni catché par l'appelant
  → l'exception remonte comme erreur non gérée jusqu'au binding Flutter (crash potentiel en
  production selon la politique de zone d'erreur de l'app ; dans le test, elle fait planter la
  suite avec `CloudFunctionException` non catchée).
- **Découvert pendant** : Phase 7, Bloc G, gap G-4 (Firestore write failure), en écrivant
  `test/network/notification_mark_as_read_write_failure_test.dart` avec un
  `_FlakyNotificationRepository` qui fait échouer `markAsRead()`.
- **Cause racine** : `BackendLocator.notificationRepository.markAsRead(userId, n.id);` appelé
  en "fire-and-forget" sans `.catchError(...)` ni `try/catch`.
- **Correctif appliqué** : ajout de `.catchError((_) {})` sur l'appel, avec commentaire explicite
  documentant l'intention : le marquage lu/non-lu est un confort UX secondaire, son échec ne doit
  jamais bloquer la navigation vers la mission liée (action principale du tap).
- **Test de régression** : `test/network/notification_mark_as_read_write_failure_test.dart`
  (2 tests) — G-4.1 (échec initial : aucun faux succès, aucun crash, navigation vers la mission
  reste fonctionnelle malgré l'échec de l'écriture) et G-4.2 (retry après échec : nouvel essai
  possible, succès confirmé, aucun état bloqué). Résultat : **2/2 PASS** après correctif.
- **Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc G, gap G-4).

---

## Bloc G — bilan

**Résultat** : 6 tests créés sur les 3 gaps réels identifiés (G-1/G-2, G-3, G-4), **6/6 PASS**.
1 bug trouvé et corrigé (BUG-008, P2). Aucun bug P0/P1. `flutter test` complet du projet :
**410/410 PASS, aucune régression**. `flutter analyze` : 0 souci nouveau.

---

## Bloc H — GPS / Tracking durcissement : aucun nouveau bug

**Résultat** : 1 seul GAP réel identifié (H-2 — lifecycle GPS au niveau
`DriverActiveMissionScreen`, jusqu'ici non prouvé explicitement bien que le code existant
(`_syncGpsSharing()`/`_syncGpsSharingIfStatusChanged()`) le gère déjà correctement depuis le fix
BUG-006). Nouveau fichier `test/driver/driver_active_mission_gps_lifecycle_test.dart` (6 tests,
**6/6 PASS au premier essai**) prouvant : démarrage réel du partage sur statut de trajet actif,
arrêt réel sur `completed`/`cancelled`, idempotence (aucune 2e boucle démarrée sur transitions
internes "partage actif"), nettoyage propre au `dispose()`, idempotence `stop()`/`stop()` isolée.
**Aucun bug trouvé** — chaque assertion a directement validé le comportement déjà correct du code
de production, sans qu'aucune correction n'ait été nécessaire.

H-1 (permissions GPS) et H-4 (sécurité tracking `driver_locations`) étaient déjà entièrement
couverts par des tests existants (`driver_location_reporter_test.dart` et
`securityRules.test.ts`) — référencés sans duplication. H-3 (BUG-006) réexécuté : reste
**18/18 PASS**, aucune régression. H-5 (background/foreground) documenté honnêtement
`DEFERRED NON-BLOCKING → Phase 8` (non implémenté, aucune architecture construite arbitrairement).
H-6 (position stale/invalide) documenté `N/A` (aucun consommateur actuel n'en dépend).

**Bilan** : Aucun bug P0/P1/P2/P3 pour ce bloc. `flutter test` complet du projet :
**416/416 PASS, aucune régression** (410 précédents + 6 nouveaux). `flutter analyze` : 0 souci
nouveau (3 issues `info` pré-existantes non liées, inchangées).

---

## Bloc I — Notifications : aucun nouveau bug

**Résultat** : 2 GAPS réels identifiés — I-2 (read/unread + badge `NotificationBell`, jamais
testé dédiée, explicitement noté "hors périmètre... cf. Bloc I" par le test G-4) et I-3
(gestion d'erreur du listener `NotificationsScreen.watchNotifications()`, le pattern G-3
n'existant jusqu'ici que sur `CustomerTrackingScreen`). Nouveau fichier
`test/notifications/notifications_realtime_and_unread_test.dart` (6 tests, **6/6 PASS**)
prouvant : badge temps réel qui reflète le compteur non-lu (incrément/décrément/plafond "99+"),
idempotence de `markAsRead()` appelé deux fois sur la même notification (aucune exception,
aucun état incohérent), mise à jour temps réel de la liste de notifications, gestion propre
d'une erreur de listener (aucun crash, contenu non trompeur, message d'erreur affiché), et
reprise normale après une nouvelle émission valide sur le même flux.

**Aucun bug trouvé** — chaque assertion a validé un comportement déjà correct du code de
production (`NotificationBell`, `NotificationsScreen`).

I-1 (création — 8 transitions de statut via `onMissionStatusChangeNotifyCustomer`) était déjà
entièrement couvert par `functions/test/integration/onMissionStatusChangeNotifyCustomer.test.ts`
(15 cas) — référencé sans duplication. I-1 secondaire (`detectExpiringDocuments.ts`,
`transitionFoundingDriverPeriods.ts`) n'a pas de test dédié mais réutilise le même schéma
d'écriture déjà validé ; aucun bug démontré → non-bloquant, documenté. I-4 (duplication) :
architecture par `onDocumentUpdated`, aucun scénario de duplication réelle démontrable en usage
normal → pas de nouveau système de dédup construit arbitrairement. I-5 (navigation) référencé
Bloc F sans duplication. I-6 (FR/EN/ES notifications) confirmé COUVERT par audit direct des clés
`notif_*`/`notifications_*` dans `app_strings.dart`. I-7 (push mobile FCM/APNs réel) documenté
`DEFERRED / Phase 8` — aucune dépendance `firebase_messaging`/FCM/APNs dans le projet.

**Bilan** : Aucun bug P0/P1/P2/P3 pour ce bloc. `flutter test` complet du projet :
**422/422 PASS, aucune régression** (416 précédents + 6 nouveaux). `flutter analyze` : 0 souci
nouveau (3 issues `info` pré-existantes non liées, inchangées).

---

## BUG-009 (P2, CORRIGÉ) — Overflow bandeau signalement `SafetyScreen` sur téléphone étroit

- **Composant** : `lib/screens/info/safety_screen.dart` (bandeau "Signaler un problème" en haut
  de l'écran Sécurité).
- **Découvert pendant** : Phase 7, Bloc J, gap J-5 (modals/dialogs sur écran critique), en
  écrivant `test/responsive/critical_screens_viewport_test.dart` à 320px de large — PAS un bug
  pré-existant connu, jamais testé à une largeur de téléphone étroite auparavant.

**Contexte** : le bandeau d'alerte en haut de `SafetyScreen` combine une icône, un message
texte explicatif et un bouton "Signaler un problème" dans une seule `Row` horizontale, à
l'intérieur d'un `Container` à fond dégradé.

**Cause** : contrairement à `ProviderDashboardShell` (déjà corrigé en BUG-007), ce bandeau
n'avait aucune logique responsive pour les largeurs étroites. À 320px de large (iPhone SE),
la somme des largeurs minimales de l'icône + `Expanded(message)` + bouton dépassait l'espace
disponible → `RenderFlex overflowed by 146 pixels on the right`, reproductible à 100 % à cette
largeur. Le test a intentionnellement refusé d'ignorer `tester.takeException()` ou d'élargir
artificiellement le viewport (règle anti-triche J), révélant ainsi un bug réel de layout.

**Correctif** : application du même seuil que BUG-007 (`isNarrow = MediaQuery.of(context).size.width
< 480`) via un `Builder` englobant le bandeau. Sous ce seuil, l'icône + le message restent sur une
première ligne (`Row` avec `Expanded` sur le texte) et le bouton "Signaler un problème" est
déplacé sur sa propre ligne en dessous (`Column` en pleine largeur), au lieu d'être compressé à
côté du texte. **Aucun contenu ni action n'est masqué** — seule la disposition change ; le bouton
reste pleinement visible, lisible et actionnable à toutes les largeurs testées.

**Fichier modifié** : `lib/screens/info/safety_screen.dart`.

**Test de régression** : `test/responsive/critical_screens_viewport_test.dart` (groupe J-5,
1 test) — dialog "Signaler un problème" à 320px de large : contenu du bandeau visible sans
overflow, ouverture du dialogue de signalement (`AlertDialog` + `TextField` + boutons
"Annuler"/"Envoyer") entièrement accessible, fermeture via "Annuler" sans exception. Revérifié :
0 overflow après correction, `tester.takeException()` nul. `flutter analyze` sur le fichier
impacté : clean ("No issues found!").

**Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc J, gap J-5).

---

## Bloc J — Responsive / Viewports : 1 bug trouvé et corrigé (BUG-009)

**Résultat** : nouveau fichier `test/responsive/critical_screens_viewport_test.dart`
(11 tests, **10/11 PASS au premier essai puis 11/11 PASS après correctif**) couvrant :

- **J-1/J-2** (régression BUG-007 + matrice de viewports) : `ProviderDashboardShell` testé aux
  largeurs 320/360/390/430/480px (Switch online/offline toujours visible et fonctionnel, aucun
  overflow) + 600px (libellés décoratifs réapparaissent, `isNarrowPhone == false` confirmé) —
  **6/6 PASS, aucune régression, aucun nouveau bug** : le correctif BUG-007 tient toujours sur
  l'ensemble de la matrice de largeurs.
- **J-3** (effet FR/EN/ES sur écran critique) : `AuthScreen` testé dans les 3 langues à 320px
  (largeur la plus contraignante) — **3/3 PASS**, aucun overflow, aucune régression liée à la
  longueur variable des chaînes traduites.
- **J-4** (clavier/formulaires) : `AuthScreen` en mode inscription sous hauteur verticale
  réduite (simulation clavier virtuel, 375×320) — **1/1 PASS**, les 3 champs et le bouton CTA
  final restent atteignables via `ensureVisible`/scroll, aucun contenu bloqué hors écran.
- **J-5** (modals/dialogs) : `SafetyScreen`, dialogue de signalement à 320px — **a révélé
  BUG-009** (voir ci-dessus), corrigé, puis **1/1 PASS**.
- **J-6** (web/desktop) : déjà couvert par `test/finance/admin_finance_ui_test.dart`
  (`NavigationRail` desktop à 1200×900) — référencé sans duplication, aucun écran supplémentaire
  n'est prévu en usage desktop dans le périmètre actuel.

**Bilan** : 1 bug trouvé et corrigé (BUG-009, P2, UI uniquement — aucun impact
sécurité/données, même classe de sévérité que BUG-007). Aucun bug P0/P1. `flutter test` complet
du projet : **433/433 PASS, aucune régression** (422 précédents + 11 nouveaux). `flutter
analyze` : 0 souci nouveau (3 issues `info` pré-existantes non liées, inchangées).

---

## BUG-010 (P2, CORRIGÉ) — Messages d'exception brute affichés à l'utilisateur admin (finance)

- **Composant** : 5 fichiers `lib/screens/dashboard/admin/finance/tabs/` :
  `admin_finance_payouts_tab.dart`, `admin_finance_ledger_tab.dart`,
  `admin_finance_reconciliation_tab.dart` (2 occurrences, 2 State classes distinctes),
  `admin_finance_taxes_tab.dart`, `admin_finance_payout_policy_tab.dart`.
- **Sévérité** : **P2** — pas de risque sécurité/données, mais violation directe de la règle
  K-6 (aucun texte technique/anglais forcé visible en FR/ES) : un admin francophone ou
  hispanophone voyait le `toString()` brut de l'exception attrapée (potentiellement
  `CloudFunctionException`/`FirebaseException` en anglais ou message technique) au lieu d'un
  message localisé.
- **Découvert pendant** : Phase 7, Bloc K, gap K-6 (audit ciblé des patterns
  `catch (e)` + `Text('$e')`/`SnackBar` dans `lib/`).
- **Cause racine** : `SnackBar(content: Text('$e'), backgroundColor: AppColors.error)` dans 6
  blocs `catch` d'actions admin (reverse payout, ajustement ledger, relance réconciliation,
  résolution anomalie, recalcul taxes, sauvegarde politique de payout), affichant directement
  l'exception interceptée sans passer par `LocaleProvider`.
- **Correctif appliqué** : remplacement des 6 occurrences par
  `Text(t('admin_action_error'))` (ou `Text(widget.t('admin_action_error'))` selon
  l'accesseur de traduction déjà en portée dans chaque méthode), en réutilisant la clé i18n
  **déjà existante et complète FR/EN/ES** `admin_action_error` — aucune nouvelle clé requise.
  Le détail technique de l'exception reste disponible en log développeur (non supprimé), seul
  l'affichage utilisateur est corrigé.
- **Test de régression** : validation ciblée via `flutter analyze` (scope
  `lib/screens/dashboard/admin/finance/tabs/` → "No issues found!", puis full-projet → 0 souci
  nouveau) + `flutter test test/finance/` (53/53 PASS sur le domaine impacté) + `flutter test`
  complet du projet : **433/433 PASS, aucune régression**.
- **Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc K, gap K-6).

---

## Bloc K — I18N GLOBAL : EN COURS (fermeture partielle honnête à date de ce commit)

**Reconnaissance effectuée** (K-0, K-7, K-8) :

- **K-0** : audit programmatique du dictionnaire `lib/l10n/app_strings.dart` (753 clés) via
  script Python de parsing du littéral `_t` — **0 clé avec locale manquante, 0 doublon**. Le
  dictionnaire lui-même est structurellement sain.
- **K-8** : cross-référence des 426 appels `t('clé')` trouvés dans `lib/` contre les 753 clés
  définies — **0 clé utilisée mais non définie**. Aucun risque de fallback accidentel côté
  dictionnaire.
- **K-7** : recherche ciblée des chaînes visibles codées en dur (`grep` sur les patterns
  `Text('...')`/`labelText:`/`SnackBar`) — 41 candidats initiaux triés en faux positifs
  (ex. `language_selector.dart` : noms de langue en écriture native, par conception, pas un
  bug ; `admin_finance_reconciliation_tab.dart` lignes 321-449 et
  `admin_driver_detail_screen.dart` lignes 420/424 : déjà `widget.t(...)`, faux positifs de
  grep) et **GAPS RÉELS CONFIRMÉS** (fichiers entiers sans aucun usage de `LocaleProvider`,
  donc 100% hardcodés en français indépendamment de la langue choisie) :
  - `lib/screens/auth/admin_login_screen.dart` (CRITIQUE — écran de connexion admin, 0 usage
    `LocaleProvider` sur 351 lignes).
  - `lib/screens/dashboard/customer/tabs/customer_profile_tab.dart` (0 usage, 182 lignes).
  - `lib/screens/dashboard/provider/tabs/provider_profile_tab.dart` (0 usage, 182 lignes,
    inclut une méthode `_statusLabel()` qui duplique en dur des libellés alors que les clés
    `driver_status_*` existent déjà et sont complètes FR/EN/ES).
  - `lib/screens/dashboard/customer/tabs/customer_messages_tab.dart` (0 usage, 32 lignes,
    écran "bientôt disponible").
  Et des **GAPS PARTIELS** (fichiers utilisant déjà `LocaleProvider` mais avec des chaînes
  résiduelles non traduites) : `lib/screens/auth/auth_screen.dart`,
  `lib/screens/driver/driver_onboarding_screen.dart`,
  `lib/screens/mechanic_provider/mechanic_onboarding_screen.dart`,
  `lib/screens/mechanic/mechanic_request_flow_screen.dart`, `lib/widgets/app_shell.dart`,
  `lib/screens/dashboard/admin/admin_dashboard_shell.dart`,
  `lib/screens/dashboard/admin/drivers/admin_drivers_list_screen.dart` (1 seul mot, "Retry",
  à remplacer par la clé existante `common_retry`).
- **K-6** : audit et **correction complète** des messages d'exception brute → voir BUG-010
  ci-dessus. **Fermé.**

**Non encore fait à ce commit** : correction effective des GAPS listés ci-dessus (K-1
Auth, K-2 Client, K-3 Chauffeur, K-4 Admin partiels), ajout des nouvelles clés i18n
nécessaires, écriture des tests K-9 (détection automatisée des écrans sans `LocaleProvider`
et/ou des clés manquantes), audit K-5 (Notifications) non encore mené explicitement.

**PROCHAINE ACTION EXACTE** : corriger dans l'ordre `admin_login_screen.dart` →
`customer_profile_tab.dart` → `provider_profile_tab.dart` → `customer_messages_tab.dart` →
restes de `auth_screen.dart`/`driver_onboarding_screen.dart`/
`mechanic_onboarding_screen.dart`/`mechanic_request_flow_screen.dart`/`app_shell.dart`/
`admin_dashboard_shell.dart`/`admin_drivers_list_screen.dart` (méthode TEST→FAIL→FIX→RETEST
par fichier, ajout des clés i18n manquantes dans `app_strings.dart`), puis K-5, puis K-9,
avant de pouvoir déclarer "BLOC K : ✅ FERMÉ" et poursuivre K2 → L.

**Bloc K n'est PAS fermé à ce commit — poursuite prévue à la prochaine session, limite de
budget d'itérations atteinte honnêtement documentée.**

---

*Ce fichier sera enrichi au fil des blocs K à W avec tout nouveau bug découvert (ID
séquentiel BUG-011, ...), classé P0/P1/P2/P3, avec cause, correctif, test de
régression et statut.*

---

## MISE À JOUR — Bloc K fermé ce tour

Aucun nouveau bug P0/P1/P2 découvert lors de la fermeture des résidus K-5 (4/7 à 7/7) et de
l'audit Notifications : tous les gaps traités étaient des chaînes non traduites (dette i18n),
pas des bugs fonctionnels. Un gap mineur a été noté et corrigé au passage : la clé
`notifications_open_tooltip` existait dans le dictionnaire mais n'était câblée nulle part
(`NotificationBell` sans `tooltip:`) — corrigé, pas de ticket dédié (trivial, même nature que
BUG-010).

**BLOC K : ✅ FERMÉ.** P0 ouverts = 0. P1 ouverts = 0.

---

## MISE À JOUR — Bloc K2 (Timezone/Date) : EN COURS (ce tour)

3 gaps réels trouvés et **corrigés** (P2, affichage uniquement, aucune donnée métier fausse) :
1. `admin_driver_detail_screen.dart` : Timestamp brut tronqué affiché à l'admin
   (`"2026-08-26 12:24:28"`) au lieu d'un format localisé → corrigé (`formatDisplayDate()`).
2. `admin_drivers_list_screen.dart::_formatDate()` : composants de date extraits SANS
   `.toLocal()` préalable → corrigé.
3. `provider_earnings_tab.dart` : même gap (extraction date sans `.toLocal()`) → corrigé.

1 gap réel identifié mais **PAS ENCORE corrigé** (P3, cosmétique) : connecteur `'à'` codé en dur
dans le formatage date/heure (au lieu de `'at'`/`'a las'` en EN/ES) — 3 fonctions concernées,
voir détail et plan de correction dans `docs/PHASE7_QA_PLAN.md`.

`flutter analyze` → 3 infos pré-existantes non liées, 0 erreur. `flutter test` → 469/469 PASS
(464 Bloc K + 5 nouveaux `k2_utc_local_boundary_test.dart`), 0 régression.

**BLOC K2 : ⚠️ PAS ENCORE FERMÉ.** P0 ouverts = 0. P1 ouverts = 0. P2 = 0 (les 3 gaps trouvés
ont été corrigés). P3 ouvert = 1 (connecteur `'à'` codé en dur, K2-3).

**Reprise prévue** : terminer K2-3 (connecteur i18n date/heure) puis K2-7 (confirmer N/A DST ou
traiter), déclarer BLOC K2 fermé, puis démarrer Bloc L (Accessibilité MVP) sans s'arrêter.

---

## MISE À JOUR — Bloc K2 : ✅ FERMÉ (K2-3 corrigé + K2-7 documenté N/A, ce tour)

**K2-3 (P3, cosmétique) résolu** : nouvelle clé i18n `datetime_connector_at` (fr='à', en='at',
es='a las') créée et câblée dans tous les points d'appel identifiés (`money_format.dart`,
`mission_finance_section.dart`, `notifications_screen.dart`, et propagation à
`provider_payouts_section.dart`, `admin_payment_detail_screen.dart`,
`admin_driver_detail_screen.dart`). Plus aucun `'à'` codé en dur dans les chemins de production
identifiés. 2 nouveaux tests ajoutés (`test/timezone/k2_utc_local_boundary_test.dart`), PASS.

**K2-7 (DST) — N/A, aucun bug** : grep ciblé confirme l'absence de calcul de durée basé sur
l'heure locale dans les 4 fichiers d'expiration/durée déjà identifiés — 0 occurrence de
`Duration(days`/`Duration(hours`/`add(const Duration`/`subtract(const Duration`.

> K2-7 : N/A — les décisions métier utilisent des instants/timestamps absolus; aucun calcul
> métier DST-sensitive identifié.

**Validation** : `flutter analyze` → 3 infos pré-existantes non liées, 0 erreur. `flutter test`
complet → **471/471 PASS** (469 + 2 nouveaux), 0 régression.

**BLOC K2 : ✅ FERMÉ.** P0 ouverts = 0. P1 ouverts = 0. P2 ouverts = 0. P3 ouverts = 0 (le seul
P3 identifié, connecteur codé en dur, est maintenant corrigé).

## MISE À JOUR — Bloc L (session en cours, PARTIEL)

Nouveaux gaps réels trouvés par tests (P3, DEFERRED NON-BLOCKING) :

- **BUG-L2-01** (P3) : `AuthScreen` à 320px de largeur avec text scale 1.5x/2.0x produit un `RenderFlex overflow` réel (confirmé par `tester.takeException()`). DEFERRED NON-BLOCKING — nécessite refonte layout (scroll/flexible) hors budget session actuelle. Non bloquant : app reste utilisable à l'échelle système par défaut (1.0x).
- **BUG-L3-01** (P3) : au moins une carte de sélection de rôle (`InkWell`) sur `AuthScreen` mesure ~38px de hauteur, sous la recommandation Android de 48x48 (ou seuil test 44px). DEFERRED NON-BLOCKING — correction simple (augmenter min-height) à planifier en session suivante, aucun impact fonctionnel bloquant identifié.

Tally après cette session : P0 = 0, P1 = 0, P2 = 0, P3 = 2 (nouveaux, tous deux DEFERRED NON-BLOCKING, non bloquants pour MVP).

Non traité cette session (reporté, pas de bug identifié encore) : L-5 (clavier web), L-6 (contraste), L-7 (photo/preuve), L-8 (loading states).

## MISE À JOUR — Bloc L (suite et clôture partielle, cette session)

**BUG-L6-01 (P1, contraste) — CORRIGÉ** : `AppColors.warning` (0xF59E0B) utilisé comme couleur de
TEXTE (pas juste badge décoratif) donnait un contraste ~2.15:1 sur fond blanc/clair — sous le
seuil WCAG AA (4.5:1 texte normal, 3:1 icône/large text). Cas réel identifié : message
d'avertissement GPS dans `DriverActiveMissionScreen` (information de sécurité potentiellement
critique pour le chauffeur). Nouvelle couleur `AppColors.warningText` (0xB45309, ambre plus
foncé) ajoutée dans `app_colors.dart`, contraste ~5.0:1 sur blanc / ~4.7:1 sur `background` —
respecte AA. Câblée dans le message + icône GPS de `driver_active_mission_screen.dart`. Les
badges/pastilles décoratifs existants (`StatusBadge`, `ComingSoonBadge`, cartes statut chauffeur)
qui utilisent encore `AppColors.warning` brut sur fond teinté (~1.96:1) sont **DEFERRED NON-
BLOCKING (P2)** : ce sont des labels courts systématiquement accompagnés d'un intitulé de champ
explicite ailleurs dans l'écran (pas la seule source d'information), non bloquants pour le MVP,
mais à corriger en Phase 8 (remplacer `AppColors.warning` par `AppColors.warningText` dans tous
les usages "texte de statut" identifiés : `finance_ui_helpers.dart`, `admin_drivers_list_screen.dart`,
`admin_driver_detail_screen.dart`, `provider_earnings_tab.dart`, `provider_payouts_section.dart`,
`provider_profile_tab.dart`, `admin_finance_payout_policy_tab.dart`).

**L-5 (clavier web)** : reconnaissance ciblée — `AdminLoginScreen` a déjà `onSubmitted` sur le
champ mot de passe (soumission par Entrée). Les formulaires admin finance (`TextField` de
filtres/montants) sont des champs de saisie simples sans action de soumission critique liée à la
touche Entrée (pas de gap identifié). **DEFERRED NON-BLOCKING** : audit exhaustif de l'ordre de
tabulation (`FocusTraversalOrder`) sur tous les écrans admin, hors budget session actuelle — aucun
P0/P1 identifié par la reconnaissance faite.

**L-7 (photo/preuve)** : confirmé — le flux de capture de preuve de livraison
(`driver_active_mission_screen.dart::_ProofPreviewDialog`) utilise déjà des labels texte explicites
pour tous ses contrôles (`driver_active_mission_confirm_proof`, `driver_active_mission_retake_photo`,
pas de bouton icon-only). Aucun gap trouvé. **COUVERT**.

**L-8 (loading states)** : référence confirmée aux tests existants de double-soumission
(`test/customer/delivery_request_flow_double_submit_test.dart`,
`test/driver/driver_active_mission_proof_upload_test.dart`,
`test/driver/driver_status_screen_test.dart`) qui prouvent déjà que les boutons d'action async
sont désactivés (`onPressed: null`) pendant le chargement, empêchant tout double-tap. **COUVERT
(référencé, pas dupliqué)**.

**Validation finale Bloc L** : `flutter analyze` → 3 infos + 2 warnings pré-existants (assets
`images/`/`icons/` non liés à ce bloc), 0 erreur. `flutter test` complet → **479/479 PASS** (478
précédents + 1 nouveau test de régression contraste BUG-L6-01), 0 régression.

**BLOC L : ✅ FERMÉ.**
- L-0 à L-4 : FAIT (session précédente).
- L-5 : reconnaissance faite, aucun P0/P1, reste DEFERRED NON-BLOCKING pour audit exhaustif.
- L-6 : 1 gap réel P1 corrigé (BUG-L6-01) ; gap P2 restant sur badges décoratifs documenté DEFERRED.
- L-7 : COUVERT, aucun gap.
- L-8 : COUVERT (référencé aux tests Bloc B/C existants).
- L-2/L-3 : gaps P3 déjà documentés DEFERRED NON-BLOCKING (session précédente, AuthScreen 320px/
  text scale 2.0 overflow ; carte rôle 38px < 48px).

P0 ouverts = 0. P1 ouverts = 0 (BUG-L6-01 corrigé). P2 ouverts = 1 (badges décoratifs warning,
DEFERRED). P3 ouverts = 2 (déjà documentés session précédente, DEFERRED).

**PROCHAINE ACTION** : démarrer Bloc M (Performance), puis N (Firestore/Indexes), puis O (Cloud
Functions hardening).

## MISE À JOUR — Bloc M (Performance MVP, cette session)

**BUG-M-01 (P1, corrigé)** — `provider_dashboard_shell.dart` : `watchDriverProfile()`
instancié dans `build()`, recréé à chaque `setState()` de `_toggleAvailability`
(flicker + re-souscription Firestore). Fix : mémoïsation par `driverId` (pattern
Bloc C). Test de régression ajouté (`provider_dashboard_shell_status_gate_test.dart`).

**BUG-M-02 (P1, corrigé)** — `driver_status_screen.dart` : même pattern, recréé à
chaque `_runAction()` (resoumission dossier / toggle en ligne). Fix : mémoïsé par `uid`.

**BUG-M-03 (P1, corrigé)** — `admin_driver_detail_screen.dart` : StreamBuilder
(`watchDriverProfile`) + 2 FutureBuilder (`users/{id}.get()`, `getDriverVehicles()`)
recréés/refetchés à chaque action admin (`_actionInProgress` toggle via Approuver/
Refuser/Suspendre/Réactiver/Documents). Fix : capturés en `late final` (driverId
stable pour la durée de vie de l'écran) — 1 seul appel réseau désormais par ouverture
d'écran au lieu d'un par clic d'action.

**BUG-M-04 (P1, corrigé)** — `customer_tracking_screen.dart` : `Image.network` de la
preuve de livraison sans `cacheWidth`/`cacheHeight` malgré un affichage fixe 220px vs
source jusqu'à 1600px (décodage pleine résolution gaspillé). Fix : `cacheHeight` ajouté.

**GAP-M-05 (P2, DEFERRED NON-BLOCKING)** — `tabs[_index]` (indexation directe, pas
`IndexedStack`) détruit/recrée le State d'onglet non affiché à chaque changement
d'onglet dans `provider_dashboard_shell.dart`. Un remplacement par `IndexedStack` a
été tenté puis **reverté** : il construit les 4 onglets dès le premier rendu, créant
des souscriptions Firestore supplémentaires immédiates (Earnings/Calendar/Profile)
même quand l'utilisateur reste sur le premier onglet — un coût réseau ajouté au
démarrage, pire que le gap initial pour l'usage MVP typique (rester sur "Missions
disponibles"). Un vrai correctif nécessiterait une construction paresseuse par onglet
(ex: garder chaque tab vivant seulement après sa première visite). Non-bloquant :
n'affecte que la fraîcheur du flux après un retour d'onglet, pas de fuite ni de crash.

**GAP-M-06 (P2, DEFERRED NON-BLOCKING)** — `watchNotifications()` et
`watchDriversByStatus()` sans `.limit()`. Sous-collection par utilisateur / liste
admin-only, volumes MVP faibles, non mesurés comme un risque réel à ce stade.

**BLOC M : ✅ FERMÉ** — P0=0, P1=0 (4 corrigés), P2=2 (DEFERRED documentés).
Validation finale : `flutter analyze` 0 erreur, `flutter test` 480/480 PASS.

## MISE À JOUR — Bloc N (Firestore/Indexes, cette session)

**BUG-N-01 (P1, corrigé)** — `firestore.indexes.json` : l'index composite collectionGroup
`history(recorded_at asc)` — requis par la Cloud Function planifiée
`cleanupExpiredTrackingHistory` (purge GPS quotidienne, cron 02:00 America/Toronto) et
documenté depuis l'étape 10 (`docs/FIRESTORE_INDEXES.md` entrée #20) — était en réalité
**absent** du fichier de configuration réel (confirmé par énumération programmatique :
seulement 20 entrées, la dernière étant `audit_logs`). Ce job aurait échoué avec
`FAILED_PRECONDITION` dès sa première exécution contre un vrai Firestore en production
(`movik-connect-prod`), silencieusement (job planifié, pas de retour utilisateur direct) —
avec pour conséquence une accumulation indéfinie de points GPS historiques jamais purgés
(coût de stockage croissant, violation de la politique de rétention 30 jours). Fix : entrée
ajoutée à `firestore.indexes.json`, validée comme JSON syntaxiquement correct.

**BUG-N-02 (P1, corrigé)** — `functions/src/lib/missionFinancialBalance.ts` : la recherche
du `driver_payout` `paid` incluant le snapshot financier d'une mission donnée lisait
**tous** les `driver_payouts` `status=='paid'` de la **plateforme entière**, sans `.limit()`
ni filtre par chauffeur — un scan qui grossit avec le volume total de payouts payés
tous-chauffeurs-confondus au fil du temps, alors que seul le `driver_id` du chauffeur de
CETTE mission peut jamais être pertinent. Ce chemin est exécuté à chaque recalcul de
solde financier de mission (après capture paiement, refund, tip, ajustement ledger,
payout) — donc potentiellement très fréquent. Fix : requête bornée par
`where('driver_id', '==', snapshotsDriverId)` en plus de `status=='paid'`, réutilisant
l'index composite existant #16 (`driver_payouts(driver_id, created_at desc)`, dont le
préfixe `driver_id` suffit pour cette equality-only query — pas de nouvel index requis).
Fallback conservé sur le comportement historique (scan status-only) si `driver_id` n'a pas
pu être résolu à partir des snapshots (cas théorique). Tests : `missionFinancialBalance.
test.ts` (24 tests incl. le scénario #6 multi-snapshots/même-payout qui exerce exactement
ce chemin) + suite intégration complète (512/512) → PASS, 0 régression.

**Réaffirmés DEFERRED (aucune preuve nouvelle Bloc N)** :
- `watchNotifications()` sans `.limit()` (P2, déjà documenté Bloc M).
- `watchDriversByStatus()` sans `.limit()` (P2, déjà documenté Bloc M).

**Nouveau P3 documenté (non-bloquant)** : index Firestore #4
(`delivery_requests(customer_id, created_at desc)`) non consommé par l'implémentation
réelle de `watchCustomerMissions()` (tri en mémoire côté client, pas de `.orderBy()`
serveur) — inoffensif, juste sur-provisionné ; note ajoutée à
`docs/FIRESTORE_INDEXES.md`.

**BLOC N : ✅ FERMÉ** — P0=0, P1=0 (2 corrigés : BUG-N-01, BUG-N-02), P2=2 (réaffirmés
DEFERRED), P3=1 (nouveau, documenté). Validation : `npx tsc --noEmit` 0 erreur,
`npm run lint` 0 erreur, Jest unit 109/109 PASS, Jest integration 512/512 PASS.

## MISE À JOUR — Bloc O (Cloud Functions Hardening, cette session)

**BUG-O-01 (P2, corrigé)** : `functions/src/functions/createDeliveryRequest.ts` acceptait
`distanceKm`/`estimatedDurationMinutes` sans AUCUNE validation runtime — seul
`calculateDeliveryQuote.ts` (le devis, en amont) validait ces champs (`typeof === "number" &&
>= 0`). Or `createDeliveryRequest` est le SEUL point d'écriture réel de `delivery_requests`
(`firestore.rules` interdit `create` direct), et ces valeurs sont relues plus tard par
`acceptDelivery()` pour le recalcul serveur du prix (`calculateCustomerQuote()`). Un client
pouvait donc persister une distance/durée négative ou non-numérique. Impact financier réel
NUL aujourd'hui (`missionBaseValue` est plancherée par `rule.minimum_charge` dans
`pricingEngine.ts` — un `rawBase` négatif est simplement remplacé par le minimum), mais il
s'agit d'une donnée métier incohérente à rejeter explicitement plutôt que de la tolérer
silencieusement. **Fix** : ajout des mêmes gardes que `calculateDeliveryQuote.ts`
(`typeof input.X !== "number" || !Number.isFinite(input.X) || input.X < 0` → `invalid-argument`).
**Tests** : 3 nouveaux cas dans `createDeliveryRequest.test.ts` (distanceKm négatif,
estimatedDurationMinutes négatif, distanceKm non-numérique) — chacun prouve qu'aucune mission
n'est créée et que le devis reste non consommé (`is_consumed: false`). 16/16 tests du fichier
PASS (13 existants + 3 nouveaux) via émulateur Firestore/Auth.

**Autres analyses O-1 à O-8** : voir la matrice consolidée complète dans
`docs/PHASE7_QA_MATRIX.md` (section "BLOC O"). Résumé : 16/18 fonctions critiques listées
étaient déjà couvertes par des tests d'idempotence/retry/auth EXISTANTS (référencés, non
dupliqués, conformément à la consigne de vitesse de cette session) ; aucun autre gap P0/P1/P2
trouvé. 2 points P3 documentés (non-bloquants, DEFERRED) : message d'erreur `acceptDelivery`
sur un retry même-chauffeur (imprécis mais fonctionnellement sûr — la garde
`if (mission.driver_id) throw failed-precondition` s'exécute avant toute écriture) ; absence
d'un type d'anomalie `payment_stuck_authorized` dans `reconciliationEngine.ts` (DEFERRED →
Phase 8). Scan de secrets (O-8) : PASS, aucun secret réel trouvé (uniquement des valeurs
fictives dans des tests dédiés à prouver l'absence de fuite).

**BLOC O : ✅ FERMÉ** — P0=0, P1=0, P2=1 corrigé (BUG-O-01), P3=2 documentés (non-bloquants).
Validation : `npx tsc --noEmit` 0 erreur, `npm run lint` 0 erreur, Jest unit 109/109 PASS,
intégration ciblée 16/16 PASS (suite complète ré-exécutée en validation finale groupée).

## MISE À JOUR — Bloc P (Storage Hardening, cette session)

**Aucun P0/P1 trouvé.** Toutes les protections attendues (driver documents propriétaire-only,
proof de livraison chauffeur-assigné-only, immutabilité, cross-user denied, unauthenticated
denied, content-type restreint, tailles limitées) étaient déjà implémentées correctement dans
`storage.rules` (Phase 3) — le travail de ce bloc a consisté à PROUVER cette couverture, pas à
la corriger.

**Gap de PREUVE comblé (pas un bug de règle)** : `storageRules.test.ts` (15 tests) ne contenait
aucun test exerçant un rejet pour taille de fichier, malgré des limites numériques déjà définies
dans `storage.rules` (`isValidDocumentUpload()` : 10 Mo, `isValidImageUpload()` : 5 Mo). 2 tests
ajoutés (`5bis`, `11bis`) confirment par exécution réelle contre l'émulateur que ces limites
fonctionnent bien (`assertFails` sur un upload de `10*1024*1024+1`/`5*1024*1024+1` octets). Un
3e test (`5ter`) réaffirme explicitement pour `driver_documents` (déjà implicite par la règle,
mais non testé explicitement) qu'un client (customer) et qu'un utilisateur non authentifié sont
DENIED en lecture ET en écriture — symétrique au comportement déjà prouvé pour `delivery_proofs`
(tests 9/10/12).

**P-6 (download access, "très important")** : recherche externe confirme que
`getDownloadURL()` génère une URL dont le token bypass les Security Rules une fois connu — fait
plateforme Firebase documenté (GitHub firebase-js-sdk #5342, docs officielles), pas un bug
applicatif. Audit complet de tous les points d'usage réel dans le repo :
- `driver_documents` : AUCUN appel `getDownloadURL()` nulle part — fonctionnalité non construite
  (bouton "voir document" admin est un placeholder explicite dans le code). Aucune exposition
  possible aujourd'hui.
- `delivery_proofs` : le seul `getDownloadURL()` du repo (`firebase_proof_upload_repository.
  dart:38`) produit une URL dénormalisée sur `delivery_requests/{id}.proof_of_delivery_url` et
  `tracking_events/{id}.metadata.proof_of_delivery_url` — tous deux lisibles EXACTEMENT par le
  même ensemble de parties (`customer_id==uid() || driver_id==uid() || isAnalystOrAbove()`) déjà
  autorisées à lire le fichier directement via la règle Storage elle-même. Aucune surface
  d'exposition supplémentaire créée.
- `disputes/{id}.proof_of_delivery_url` : toujours `null` (jamais réassigné dans
  `disputeOrchestration.ts`), et la collection `disputes` est lisible uniquement par
  `isAnalystOrAbove()` — sous-ensemble strict des lecteurs Storage.
- `profile_photos` : lecture publique par design (`allow read: if true`) — un token ne réduit
  aucune sécurité déjà nulle par choix produit (avatar non sensible).

**Conclusion P-6 : COUVERT**, aucun fix requis. Point de vigilance documenté pour toute future
fonctionnalité qui transmettrait cette URL vers un canal externe (export admin, webhook,
notification push) — à réévaluer à ce moment, non-bloquant aujourd'hui.

**P-7 (orphan files)** : séquence `completeDelivery.ts` confirmée — upload Storage réussi PUIS
appel `completeDelivery()` PUIS transaction Firestore. Si la transaction échoue (contention,
statut déjà avancé), le fichier Storage reste sans référence Firestore. Fréquence attendue très
faible (fenêtre de contention étroite), aucune fuite de sécurité (fichier orphelin reste protégé
par les mêmes règles Storage restrictives), coût de stockage négligeable (photo unique).
**Classé `DEFERRED NON-BLOCKING → Phase 8 cleanup`** — candidat pour une future Cloud Function
de nettoyage périodique, hors scope Phase 7 (pas de garbage collector construit maintenant).

**BLOC P : ✅ FERMÉ** — P0=0, P1=0, aucun bug de règle trouvé (3 tests de preuve ajoutés :
`5bis`, `5ter`, `11bis`). P2/P3 : 1 point de vigilance future documenté (P-6) + 1 DEFERRED →
Phase 8 (P-7), ni l'un ni l'autre bloquant. Validation : suite `storageRules.test.ts` 19/19 PASS
(15 préexistants + 4 nouveaux assertions, 0 régression) via émulateur Firestore+Auth+Storage.
