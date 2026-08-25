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

*Ce fichier sera enrichi au fil des blocs G à W avec tout nouveau bug découvert (ID
séquentiel BUG-008, ...), classé P0/P1/P2/P3, avec cause, correctif, test de
régression et statut.*
