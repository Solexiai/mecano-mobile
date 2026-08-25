# PHASE 7 — QA GLOBALE, DURCISSEMENT PRÉPRODUCTION ET PILOTE

**Point de départ** : `HEAD == origin/main == d51ce30` (Phase 6 ✅ TERMINÉE)
**Objectif** : Tester Movi-K comme un vrai produit multi-utilisateur, casser les parcours,
trouver et corriger les bugs, durcir sécurité/résilience/performance, préparer un pilote réel.
**Priorité absolue** : TROUVER LES PROBLÈMES AVANT LES VRAIS UTILISATEURS (pas de documentation
pour la documentation — TEST → FAIL → FIX → RETEST en priorité).

Ce fichier est la **roadmap persistante** de la Phase 7. Il DOIT être mis à jour à chaque
fermeture de bloc pour survivre à une compaction de contexte.

## Légende des statuts
- `DONE` — bloc fermé, tests/preuves en place, commité+poussé
- `IN PROGRESS` — travail en cours actuellement
- `NEXT` — prochain bloc à traiter, pas encore commencé
- `BLOCKED EXTERNAL` — nécessite une action de Daniel (compte/accès/billing/légal)
- `DEFERRED NON-BLOCKING` — reporté car non bloquant pour le pilote, documenté

## Repères d'infrastructure de test existants (Phases 2-6, ne pas ré-auditer)
- Emulators: `firebase emulators:exec --only firestore,auth,storage --project demo-movik-test`
- Integration: 27 suites / 444 tests (`functions/test/integration/*.test.ts`)
- Unit: 6 suites / 109 tests (`functions/test/unit/*.test.ts`)
- Security Rules: 180 tests (`securityRules.test.ts`) — DENY BY DEFAULT confirmé sur toutes
  collections financières (Phase 6 Bloc T)
- Storage Rules: 16 tests (`storageRules.test.ts`) — stable, non flaky (6 runs consécutifs verts)
- Flutter: 316 tests (`flutter test`), 19 fichiers sous `test/`
- Cloud Functions déployées: 44 fonctions dans `functions/src/functions/`
- Flutter router: `lib/router/app_router.dart`
- Écrans par domaine: `lib/screens/{auth,customer,dashboard/{admin,customer,provider},delivery,driver,home,info,legal,mechanic,mechanic_provider,notifications}`

## Documents à produire pendant la Phase 7
| Document | Bloc | Statut |
|---|---|---|
| `docs/PHASE7_QA_PLAN.md` (ce fichier) | Règle 3 | DONE |
| `docs/PHASE7_QA_MATRIX.md` | A | NEXT |
| `docs/DATA_MIGRATION_PLAN.md` | R2 | NEXT |
| `docs/PHASE7_LOAD_RESULTS.md` | T | NEXT |
| `docs/PHASE7_BUG_REPORT.md` | U | NEXT |
| `docs/MONITORING_PLAN.md` | Y | NEXT |
| `docs/DATA_RETENTION_TECHNICAL_PLAN.md` | Z | NEXT |
| `docs/DISASTER_RECOVERY_PLAN.md` | AA | NEXT |
| `docs/PILOT_READINESS.md` | AC | NEXT |

## Tableau des blocs

| Bloc | Titre | Statut | Notes / Bugs liés |
|---|---|---|---|
| Règle 3 | Créer PHASE7_QA_PLAN.md | DONE | ce fichier |
| A | Matrice QA Produit | DONE (v1) | `docs/PHASE7_QA_MATRIX.md` créée, sera enrichie en continu |
| B | E2E Client complet | DONE | BUG-001 (P1, CORRIGÉ), BUG-002 (P3, CORRIGÉ), BUG-003 (P1, CORRIGÉ) |
| C | E2E Chauffeur complet | DONE | BUG-003 occurrence DriverOnboarding (P1, CORRIGÉ), BUG payout rollback (P0, CORRIGÉ), BUG stream ProviderJobsTab (P1, CORRIGÉ), BUG boucle GPS infinie (P1, CORRIGÉ) |
| D | Analyste/Admin/Super Admin | NEXT | permissions réelles uniquement |
| E | Auth/Session/Claims | NEXT | vérifier révocation rôle admin |
| F | Routing/Deep Links | DONE | F-1/F-2/ROUTE-F-01..06/F-3 — BUG-007 (P2, CORRIGÉ) |
| G | Offline/Réseau/Retry | DONE | pas de perte de mission financière |
| H | GPS/Tracking | NEXT | doit s'arrêter après completed/cancelled |
| I | Notifications | NEXT | isolation, dédoublonnage |
| J | Responsive | NEXT | tailles réalistes mobile/tablette/desktop |
| K | I18N Global | NEXT | FR/EN/ES runtime |
| K2 | Date/Heure/Timezone | NEXT | logique serveur indépendante UI |
| L | Accessibilité MVP | NEXT | corriger bloquant seulement |
| M | Performance | NEXT | mesurer avant d'optimiser |
| N | Firestore/Indexes | NEXT | ajouter seulement si nécessaire |
| O | Cloud Functions Hardening | NEXT | inputs invalides/absents/mauvais rôle |
| P | Storage (audit final Phase 7) | NEXT | s'appuie sur storageRules.test.ts existant |
| Q | Sécurité Application | NEXT | privilege escalation, spoofing |
| Q2 | App Check / Anti-abus | NEXT | documenter état + plan Phase 8 |
| R | Rétrocompatibilité | NEXT | anciens documents, pas de crash |
| R2 | Migrations | NEXT | DATA_MIGRATION_PLAN.md |
| S | Multi-utilisateurs | NEXT | isolation entre acteurs |
| T | Charge MVP | NEXT | PHASE7_LOAD_RESULTS.md |
| T2 | Profil de coût Firebase | NEXT | volumes mesurés, pas de prix inventés |
| U | Bug Bash | NEXT | PHASE7_BUG_REPORT.md — P0=0/P1=0 |
| V | Validation Globale | NEXT | cascade complète + confirmations |
| W | Nettoyage | NEXT | risques réels seulement |
| X | Feature Flags / Kill Switches | NEXT | config serveur/admin |
| Y | Monitoring/Alertes | NEXT | MONITORING_PLAN.md |
| Z | Privacy/Data Retention | NEXT | DATA_RETENTION_TECHNICAL_PLAN.md |
| AA | Disaster Recovery | NEXT | DISASTER_RECOVERY_PLAN.md |
| AB | First User Experience | NEXT | simulation client/chauffeur novice |
| AC | Pilot Readiness | NEXT | PILOT_READINESS.md |

## Règles opérationnelles rappelées
1. Mode autonome — décisions techniques uniquement, pas de questions à Daniel sauf blocage externe réel.
2. Anti-boucle — max 20% du budget d'un bloc en reconnaissance, puis TEST→FAIL→FIX→RETEST.
3. Cette roadmap doit être mise à jour à chaque fermeture de bloc.
4. Ne pas rouvrir les audits complets Phases 2-6. Bug trouvé → fix + regression test + doc, puis continuer.
5. Interdiction de `dart format .` global. Formatter uniquement les fichiers modifiés.
6. Chaque bloc/groupe logique important → commit + push. Avant clôture Phase 7 : `HEAD==origin/main`, working tree clean.

## BLOC B : ✅ FERMÉ

**Critères de clôture vérifiés** :
- MIS-C-09 (dernier scénario ouvert du Bloc B) : **DONE** — Cas A (UI double submit, 2/2 PASS),
  Cas B (backend retry séquentiel, PASS), Cas C (backend concurrence stricte, PASS). Voir détail
  ci-dessous.
- `flutter analyze` (projet complet) : 0 erreur (3 `info`/`deprecated_member_use` pré-existants,
  hors périmètre Bloc B, non régressés).
- `flutter test` (suite complète, aucun fichier ciblé) : **323 passed, 0 failed** — aucune
  régression, aucun test skip/supprimé.
- Aucun P0/P1 ouvert dans le Bloc B : BUG-001 (P1, CORRIGÉ), BUG-002 (P3, CORRIGÉ), BUG-003 (P1,
  CORRIGÉ). Tous fermés.

## Point de reprise actuel (mis à jour après BUG-001/002/003 corrigés + MIS-C-02/04/06/07/08/09 traités)

**Dernière action complétée** :
- **BUG-001 CORRIGÉ** ✅ : `cancelAuthorization()` maintenant appelé correctement à l'annulation
  client post-assignation (voir `PHASE7_BUG_REPORT.md`). Bug secondaire découvert et corrigé
  pendant l'implémentation (violation Firestore "reads before writes" dans la transaction
  d'application de `cancelMissionPaymentAuthorization()`). Test dédié :
  `missionCancellationPaymentRelease.test.ts` → **3/3 PASS**. Régression complète (Security
  Rules 196/196, `onMissionEndedClearTracking.test.ts` 10/10, `tsc --noEmit` 0 erreur, lint 0
  erreur) → **aucune régression**.
- **MIS-C-02** (aucun chauffeur dispo) : nouveau test `dispatchNoDriverAvailable.test.ts`
  (2/2 PASS) — comportement documenté déjà correct, coverage gap comblé, **aucun bug réel**.
- **MIS-C-04** (paiement refusé à l'acceptation) : nouveau test
  `acceptDeliveryPaymentFailure.test.ts` (2/2 PASS) — mécanisme de compensation déjà correct
  (mission `payment_failed`, driver redevient `online`, retry possible), **aucun bug réel**.
- **MIS-C-06** (session expirée) : investigation de code (pas de nouveau test — les deux seuls
  écrans appelant des Cloud Functions, `delivery_request_flow_screen.dart` et
  `driver_active_mission_screen.dart`, catchent déjà `CloudFunctionException` de façon uniforme
  et affichent un message actionnable, jamais un crash) → conclu **DONE, déjà adéquat**.
- **MIS-C-07** (accès non authentifié à l'écran de suivi) : **BUG-002 (P3, UX mineur) trouvé et
  CORRIGÉ** — `CustomerTrackingScreen` n'avait pas la garde d'auth de ses écrans frères,
  affichait un message "erreur réseau" trompeur au lieu de "connectez-vous". Corrigé (nouvelle
  clé i18n `tracking_locked_message` + garde `!auth.isSignedIn` dans `build()`, pattern identique
  à `CustomerDashboardShell`). AUCUNE faille de sécurité (firestore.rules déjà scopée
  correctement, 196/196 tests). Test : `customer_tracking_screen_auth_test.dart` (2/2 PASS).
- **MIS-C-08** (ancienne mission, données partielles) : nouveau test
  `delivery_mission_partial_data_test.dart` (3/3 PASS) prouvant que `DeliveryMission.fromJson`
  gère sans exception un document pré-Phase-4/5 sans `pickup_address`/`dropoff_address`/
  timestamps ; inspection de code confirme tous les force-unwraps (`!`) dans les écrans concernés
  sont gardés par `if (x != null)` — **aucun bug réel**.

**MIS-C-09 — traitement complet** :
- **Backend (Cas B + Cas C)** : `createDeliveryRequest.ts` s'appuie déjà sur une transaction
  Firestore unique (lecture du devis + écriture mission + consommation `is_consumed` atomiques) —
  le contrôle de concurrence optimiste Firestore empêche nativement toute double mission sur
  retry séquentiel OU concurrence stricte. Nouveau test
  `createDeliveryRequestIdempotency.test.ts` (Cas B retry, Cas C `Promise.allSettled`) →
  **2/2 PASS**. **Aucun bug backend** — architecture déjà sûre.
- **UI (Cas A) — BUG-003 (P1) trouvé et CORRIGÉ** : en écrivant le test du double-tap, découverte
  qu'une saisie catégorie-puis-description (étape 1) ou remplissage des champs d'adresse
  (étape 2) ne déclenchait jamais de rebuild du parent (`TextEditingController` sans `onChanged`
  reliant à `setState`), figeant `canProceed` sur `false` et bloquant tout le funnel. Corrigé par
  ajout de `onDescriptionChanged`/`onAddressFieldChanged` (`onChanged: (_) => setState(() {})`)
  sur les champs concernés — voir `PHASE7_BUG_REPORT.md`. Garde de réentrance explicite déjà
  ajoutée dans `_createMission()` (`if (_phase == creating || _phase == created) return;`) +
  seams de test (`BackendLocator.missionRepositoryOverride`,
  `FirebaseAuthProvider.debugForceSignedIn` etc.). Test
  `delivery_request_flow_double_submit_test.dart` → **2/2 PASS** (double-tap rapide : une seule
  création ; bouton devient `onPressed == null` dès la phase `creating`).
- **MIS-C-09 → DONE** dans `PHASE7_QA_MATRIX.md`.

**Validation de clôture Bloc B (une seule fois, non une reconnaissance)** :
- `flutter analyze` (projet complet) → 0 erreur (3 `info` pré-existants hors périmètre).
- `flutter test` (suite complète) → **323 passed, 0 failed**.
- Backend : `createDeliveryRequestIdempotency.test.ts` reconfirmé isolément → 2/2 PASS.

**PROCHAINE ACTION EXACTE (reprise ici, pas de nouvel audit)** :
1. **Bloc B est FERMÉ** (voir déclaration ci-dessus). Commit + push de ce cycle (garde
   double-submit, seams de test, fix rebuild BUG-003, tests UI + backend, documentation Phase 7).
2. Enchaîner directement **Bloc C — E2E CHAUFFEUR** (parcours complet : signup → profil →
   véhicule → documents → submit review → analyst approve → online → reçoit mission → accepte →
   GPS → pickup → in transit → destination → proof → completed → revenus → payout ; puis cas
   négatifs déjà définis : chauffeur non approuvé, document manquant, véhicule non vérifié,
   compte suspendu, mission déjà acceptée, GPS refusé, GPS désactivé, upload preuve échoue,
   payout échoue) sans audit général préalable.

**Fichiers créés/modifiés cette session, tous committés/pushés dans ce cycle** :
- `functions/src/payment/paymentOrchestration.ts` (fix BUG-001 + fix reads-before-writes)
- `functions/test/integration/missionCancellationPaymentRelease.test.ts` (BUG-001, 3/3 PASS)
- `functions/test/integration/acceptDeliveryPaymentFailure.test.ts` (MIS-C-04, 2/2 PASS)
- `functions/test/integration/dispatchNoDriverAvailable.test.ts` (MIS-C-02, 2/2 PASS)
- `lib/l10n/app_strings.dart` (clé `tracking_locked_message`, MIS-C-07/BUG-002)
- `lib/screens/customer/customer_tracking_screen.dart` (garde auth, MIS-C-07/BUG-002)
- `test/customer/customer_tracking_screen_auth_test.dart` (MIS-C-07, 2/2 PASS)
- `test/customer/delivery_mission_partial_data_test.dart` (MIS-C-08, 3/3 PASS)
- `docs/PHASE7_BUG_REPORT.md` (BUG-001 CORRIGÉ, BUG-002 ajouté et CORRIGÉ)
- `docs/PHASE7_QA_MATRIX.md` (lignes MIS-C-02/04/05/06/07/08 mises à jour)

**Fichiers créés/modifiés ce cycle (MIS-C-09, clôture Bloc B)** :
- `lib/screens/delivery/delivery_request_flow_screen.dart` (garde de réentrance
  `_createMission()` ; fix BUG-003 : `onDescriptionChanged`/`onAddressFieldChanged` sur les
  champs texte des étapes 1 et 2 ; usage de `auth.effectiveUid/effectiveDisplayName/effectiveEmail`)
- `lib/backend/backend_locator.dart` (seam de test `missionRepositoryOverride`)
- `lib/providers/firebase_auth_provider.dart` (seams de test `debugForceSignedIn` etc. +
  getters `effectiveUid/effectiveDisplayName/effectiveEmail`)
- `functions/test/integration/createDeliveryRequestIdempotency.test.ts` (MIS-C-09 Cas B+C,
  2/2 PASS)
- `test/customer/delivery_request_flow_double_submit_test.dart` (MIS-C-09 Cas A, 2/2 PASS)
- `docs/PHASE7_BUG_REPORT.md` (BUG-003 ajouté et CORRIGÉ)
- `docs/PHASE7_QA_MATRIX.md` (ligne MIS-C-09 → DONE)
- `docs/PHASE7_QA_PLAN.md` (ce fichier — clôture Bloc B)

**Vérification finale de clôture** : `flutter test` complet exécuté → **323 passed, 0 failed**.
`flutter analyze` complet exécuté → 0 erreur (3 `info` pré-existants, hors périmètre).

## BLOC C : ✅ FERMÉ

**Périmètre couvert** : onboarding chauffeur (BUG-003 occurrence confirmée+corrigée), E2E
chauffeur complet (registerAsDriver → payout, 5/5 PASS), GPS/location reporter (cas négatifs
refus/désactivation/échec rapport + fix boucle infinie), proof upload failure (échec Storage +
retry), payout submission failure (fix rollback silencieux P0), `ProviderJobsTab` (fix stream
recréé à chaque `setState`, P1), `DriverActiveMissionScreen` gaps (statuts trajet, GPS,
double-tap), `DriverStatusScreen` (7 statuts + cas transverses).

**Bugs fermés dans ce bloc** :
- **P0** — payout rollback silencieux (`b4b79fd`) — voir `PHASE7_BUG_REPORT.md`.
- **P1** — stream `ProviderJobsTab` recréé à chaque rebuild (`0259619`).
- **P1** — boucle GPS infinie sur échec permanent de rapport de position (`19942c2`).
- **P1** — BUG-003 occurrence `DriverOnboardingScreen` (même cause racine que l'occurrence
  originale Bloc B, champs texte sans `onChanged`/`setState`) (`698831f`).

**Validation de clôture (une seule fois, non une reconnaissance)** :
- `npx tsc --noEmit` (functions) → 0 erreur.
- `npm run lint` (functions) → clean.
- Jest unit (functions) → **109/109 PASS**.
- Jest intégration pertinente Bloc C (émulateurs firestore+auth+storage,
  `demo-movik-test`) → **56/56 PASS** : `submitDriverPayoutFailure`,
  `e2eDriverOnboardingToPayout`, `acceptDeliveryConcurrency`, `calculateDriverPayout`,
  `reverseDriverPayout`, `foundingDriverCommission`, `financialConcurrency`,
  `dispatchNoDriverAvailable`, `e2eRefundPostPayoutLifecycle`.
- `flutter analyze` (projet complet) → 0 erreur nouvelle (3 `info` pré-existants inchangés).
- `flutter test` (suite complète) → **371/371 PASS** (353 pré-existants + 18 nouveaux
  `driver_status_screen_test.dart`), aucune régression, aucun skip/suppression.

**Fichiers créés/modifiés dans ce bloc** (voir `PHASE7_QA_MATRIX.md` MIS-D-05 à MIS-D-10 et
`PHASE7_BUG_REPORT.md` pour le détail complet) :
- `test/driver/driver_onboarding_step0_rebuild_test.dart`, fix
  `lib/screens/driver/driver_onboarding_screen.dart` (BUG-003 occurrence).
- `functions/test/integration/e2eDriverOnboardingToPayout.test.ts` (E2E chauffeur, 5/5 PASS).
- `test/driver/driver_location_reporter_test.dart`, fix
  `lib/services/driver_location_reporter.dart` (boucle GPS infinie).
- `lib/backend/repositories/proof_upload_repository.dart` (seam),
  `test/driver/driver_active_mission_proof_upload_test.dart` (proof upload failure).
- `functions/test/integration/submitDriverPayoutFailure.test.ts`, fix
  `functions/src/payment/*` (payout rollback P0).
- `lib/backend/backend_locator.dart` (seam `driverRepositoryOverride`), fix
  `lib/screens/mechanic_provider/provider_jobs_tab.dart` (stream recréé),
  `test/driver/provider_jobs_tab_test.dart`.
- `test/driver/driver_active_mission_status_gaps_test.dart` (gaps statuts trajet).
- `test/driver/driver_status_screen_test.dart` (18/18 PASS, 7 statuts + cas transverses).
- `docs/PHASE7_QA_MATRIX.md` (MIS-D-05 à MIS-D-10 → DONE, clôture Bloc C).
- `docs/PHASE7_BUG_REPORT.md` (BUG-003 occurrence DriverOnboarding + bugs P0/P1 Bloc C).
- `docs/PHASE7_QA_PLAN.md` (ce fichier — clôture Bloc C).

## BLOC D : ✅ FERMÉ

**Périmètre couvert** : gaps de couverture Cloud-Function-callable pour ANALYSTE/ADMIN/SUPER ADMIN.
Ne PAS avoir refait l'audit Security Rules général (déjà 196/196 PASS, Phase 6/Bloc T) — uniquement
identifié et comblé les gaps à la couche callable (surface d'autorisation distincte des Security
Rules Firestore, car les repositories Flutter appellent ces callables plutôt que d'écrire
directement dans Firestore pour les actions sensibles).

**Gap identifié** (reconnaissance exhaustive via `grep -rl "<fn>.run(" test/`) : **0 test existant**
pour `setUserRole` (super_admin exclusif — SEUL point d'entrée d'élévation de privilège),
`suspendDriver`, `reactivateDriver`, `requestDriverDocuments`, `updatePricingConfiguration`,
`applyDriverPromotion`, `qualifyFoundingDriver`, `revokeFoundingDriverStatus`,
`createFinancialSnapshot`, `logDriverReviewOpened` ; couverture **success-path uniquement** (aucun
test de refus par mauvais rôle) pour `validateDriverDocument` et `rejectDriver`.
`addDriverInternalNote` avait une couverture Security-Rules (lecture) mais 0 test callable.

**Fichier créé** : `functions/test/integration/adminPrivilegedActions.test.ts` — 36 tests couvrant,
pour chaque fonction listée ci-dessus : (a) chemin de succès avec le rôle minimal requis, (b) refus
`permission-denied` pour au moins un rôle insuffisant (souvent plusieurs : customer/driver/analyst
selon le seuil réel de la fonction), (c) cas négatifs métier propres à la fonction déjà couverts par
le code (failed-precondition sur double-suspension, immutabilité pricing_version/financial_snapshot,
quota Founding Driver complet, invalid-argument sur rôle/plage invalide).

**Résultat** : **36/36 PASS au premier essai — AUCUN bug trouvé**. Chaque garde
`requireAdminOrAbove()`/`requireAnalystOrAbove()`/`requireSuperAdmin()` réellement présente dans le
code source refuse correctement tout rôle insuffisant, exactement comme documenté dans
`functions/src/lib/auth.ts`. Aucun P0/P1 à corriger pour ce bloc.

**Cas négatifs transversaux (directive Bloc D)** — déjà exhaustivement couverts par
`securityRules.test.ts` (196/196 PASS, Phase 6), RÉFÉRENCÉS et non redupliqués : écriture Firestore
directe sur `transaction_ledger` (append-only, aucun rôle), `disputes`/`reconciliation_reports`/
`payout_policy_configs` (admin+ lecture seule, jamais écriture directe), `payment_profiles` (même
super_admin ne peut pas écrire directement), `driver_internal_notes` (Cloud-Function-only),
`users/{uid}.roles` (un customer ne peut pas s'auto-élever).

**Validation de clôture** :
- `npx tsc --noEmit` (functions) → 0 erreur.
- Jest unit (functions) → **109/109 PASS** (aucune régression).
- Jest intégration Bloc D (émulateurs firestore+auth+storage, `demo-movik-test`) →
  **36/36 PASS** (`adminPrivilegedActions.test.ts`, nouveau fichier).
- `npm run lint` (functions, cible `src/` selon script du projet) → clean.

**Fichiers créés/modifiés** :
- `functions/test/integration/adminPrivilegedActions.test.ts` (nouveau, 36 tests).
- `docs/PHASE7_QA_MATRIX.md` (ADM-01 à ADM-06, clôture Bloc D).
- `docs/PHASE7_QA_PLAN.md` (ce fichier — clôture Bloc D).
- `docs/PHASE7_BUG_REPORT.md` (note : aucun nouveau bug — Bloc D n'ajoute aucune entrée BUG-007+).

**PROCHAINE ACTION EXACTE (reprise ici, pas de nouvel audit général)** :
1. **Bloc D est FERMÉ**. Commit + push de ce cycle effectués (voir historique git).
2. Enchaîner directement **Bloc E — AUTH/SESSION/CLAIMS** (NEXT — non commencé ce cycle par
   manque de budget d'itérations, PAS par choix d'arrêt volontaire après un seul bloc) :
   - Gaps réels signup/login/logout/session persistante/expirée/refresh token/mauvais mot de
     passe/utilisateur désactivé/`user == null`/route protégée/refresh navigateur/fermeture-
     réouverture app.
   - CLAIMS/RÔLES : réutiliser le nouveau `setUserRole` test (Bloc D) comme brique pour tester
     analyst→promotion admin→refresh claims→droits effectifs ; admin→downgrade→refresh/révocation
     →privilèges refusés ; super_admin downgrade ; ancien token privilégié après changement de
     rôle ; callable sensible après changement de rôle ; UI avec ancien rôle temporaire.
   - Principe explicite à prouver par du code, pas seulement affirmé : "le frontend n'est jamais
     l'autorité finale" — même avec un token/état UI périmé, le backend doit refuser une action
     non autorisée côté serveur (candidat naturel : appeler un callable admin-only avec un token
     construit avec un ANCIEN rôle après un `setUserRole` downgrade réel — vérifier que le
     nouveau claims prévaut si le token est réellement rafraîchi, ET que même un token non
     rafraîchi ne peut PAS obtenir un accès que les Custom Claims serveur actuels n'autorisent
     plus, puisque `requireSignedIn()` lit `request.auth.token` — à vérifier précisément comment
     l'émulateur/production réévalue ce token par requête).
   - Réutiliser les tests Auth existants (`registerAsDriver`/`submitDriverForReview` chain,
     `AdminAuthGate`/`AdminLoginScreen` déjà lus en Bloc D) où suffisants ; créer uniquement les
     gaps réels.
3. Puis **Bloc F — ROUTING/DEEP LINKS**, sans s'arrêter entre E et F (directive : "ne t'arrête pas
   après E").
4. **Ne pas refaire d'audit général** pour D (fermé), ni pour Security Rules (déjà 196/196 PASS).

## BLOC E : ✅ FERMÉ

**Périmètre couvert** : gaps de couverture AUTH/SESSION/CLAIMS, uniquement — pas de nouvel audit
général du système Auth existant.

**Gaps identifiés** :
- Flutter : aucun seam pour simuler un jeu de rôles/claims arbitraire dans `FirebaseAuthProvider`
  (`debugForceRoles`/`debugForceClaimsLoaded`/`debugForceClaimsFetchFailed` absents) ; 0 test
  dédié pour `AdminAuthGate`/`AdminLoginScreen` (session/claims states, downgrade round-trip).
- Cloud Functions : 0 fichier de test dédié Auth/session/claims. Les tests Bloc D
  (`buildRequest()`) prouvent uniquement l'autorisation par SNAPSHOT de claims — ils ne passent
  jamais par `verifyIdToken()` réel (le `onCall` HTTP réel). Gap réel : aucune preuve end-to-end
  que le token serveur réel (Identity Toolkit REST, comme un vrai client Flutter) est bien vérifié,
  et aucune preuve empirique du comportement de fraîcheur des claims après `setUserRole`.

**Fichiers créés** :
- `test/auth/admin_auth_gate_session_claims_test.dart` — 13 tests (AUTH-E-01 à AUTH-E-08) :
  session (signed-out/signed-in), claims (loading/loaded/fetch-failed avec écran "Réessayer" sans
  déconnexion forcée), rôle insuffisant → login, rôle suffisant → dashboard, downgrade analyst
  après promotion admin via les nouveaux seams. **13/13 PASS**.
- `functions/test/integration/authSessionClaims.test.ts` — 16 tests en 3 niveaux :
  - NIVEAU 1 (S01-S09) : session réelle via Identity Toolkit REST contre l'émulateur Auth
    (signup, login, mauvais mot de passe, email inconnu, refresh token, claims dans le token
    décodé) — exerce réellement `verifyIdToken()`, contrairement au pattern `buildRequest()`.
  - NIVEAU 2 (C01-C06) : round-trip claims via `setUserRole` (Bloc D) — analyst→admin→droits
    effectifs ; admin→downgrade→refus ; rôle retiré ; super_admin downgrade ; callable sensible
    (`suspendDriver`, `requestDriverDocuments`) après changement de rôle.
  - NIVEAU 3 (U01) : callable sans authentification → `unauthenticated`.
  **16/16 PASS** (après 2 corrections TEST→FAIL→FIX→RETEST documentées inline, voir
  `docs/PHASE7_BUG_REPORT.md`).

**Durcissement proactif appliqué** : `functions/src/functions/setUserRole.ts` appelle désormais
`authAdmin.revokeRefreshTokens(targetUid)` immédiatement après `setCustomUserClaims()` (défense en
profondeur). Limitation documentée en commentaire : ceci n'invalide PAS rétroactivement un ID token
déjà émis et non expiré, car `onCall` (SDK `firebase-functions`) appelle `verifyIdToken()` SANS
`checkRevoked: true` (confirmé par inspection de
`firebase-functions/lib/common/providers/https.js` et par sonde empirique contre l'émulateur Auth).
Un token privilégié déjà émis reste donc valide jusqu'à son expiration naturelle (≤ 1h) — risque
résiduel connu et documenté, hors périmètre d'un correctif ciblé (remplacer `onCall` par un handler
HTTPS personnalisé sur chaque fonction sensible serait disproportionné).

**Principe "le frontend n'est jamais l'autorité finale"** : prouvé par AUTH-E-C02/C03/C05/C06 —
même avec un token construit avec un rôle désormais révoqué côté serveur (`buildRequest` avec
rôle périmé), le callable réévalue les Custom Claims effectifs et refuse `permission-denied` ;
et côté UI, `debugForceClaimsFetchFailed`/`debugForceRoles` prouvent que l'écran ne fait jamais
confiance à un état de claims obsolète pour accorder un accès qu'il n'a pas — l'affichage seul
n'autorise jamais une action serveur.

**Bugs découverts** : **aucun bug applicatif P0/P1**. Deux corrections de type "test-authoring"
dans le nouveau fichier lui-même (assertion erronée AUTH-E-S06 due à une particularité de
l'émulateur — JWT non signés déterministes ; UID cible non créé avant l'appel `setUserRole` dans
AUTH-E-C04) — corrigées via TEST→FAIL→FIX→RETEST, documentées inline et dans le Bug Report.

**Validation de clôture** :
- `flutter analyze` (fichiers touchés) → clean.
- `flutter test test/auth/ test/customer/customer_tracking_screen_auth_test.dart test/finance/ test/driver/`
  → 378/378 PASS (aucune régression).
- `npx tsc --noEmit` (functions) → 0 erreur.
- `npm run lint` (functions) → clean.
- Jest unit (functions) → 109/109 PASS.
- Jest intégration Bloc E (émulateurs firestore+auth+storage, `demo-movik-test`) →
  `authSessionClaims.test.ts` **16/16 PASS**.
- Jest intégration Bloc D régression → `adminPrivilegedActions.test.ts` **36/36 PASS** (confirme
  l'absence de régression suite au durcissement `setUserRole.ts`).

**Fichiers créés/modifiés** :
- `lib/providers/firebase_auth_provider.dart` (3 nouveaux seams `@visibleForTesting`).
- `functions/src/functions/setUserRole.ts` (durcissement `revokeRefreshTokens`).
- `test/auth/admin_auth_gate_session_claims_test.dart` (nouveau, 13 tests).
- `functions/test/integration/authSessionClaims.test.ts` (nouveau, 16 tests).
- `docs/PHASE7_QA_MATRIX.md` (AUTH-E-*, clôture Bloc E).
- `docs/PHASE7_BUG_REPORT.md` (note Bloc E — aucun bug applicatif, 1 durcissement proactif).
- `docs/PHASE7_QA_PLAN.md` (ce fichier — clôture Bloc E).

**PROCHAINE ACTION EXACTE (reprise ici, pas de nouvel audit général)** :
1. **Bloc E est FERMÉ.**
2. Enchaîner directement **Bloc F — ROUTING/DEEP LINKS**.
3. Puis **Bloc G — OFFLINE/RÉSEAU/RETRY**, sans s'arrêter entre F et G.
4. **Ne pas refaire d'audit général** pour E (fermé), D (fermé), ni Security Rules (196/196 PASS).

---

## BLOC F : ✅ FERMÉ

**Périmètre couvert** :
- **F-1 — cross-customer** : client A tente d'accéder à `/livraison/suivi/:id` d'une mission
  appartenant à client B. Protection existante (`mission.customerId != auth.effectiveUid`) dans
  `CustomerTrackingScreen` déjà en place et prouvée par `customer_tracking_cross_customer_test.dart`
  (3/3 PASS, déjà committé). Aucune reprise/duplication effectuée ce bloc — référencé uniquement.
- **F-2 — chauffeur pending_review/suspended** : le Switch "en ligne" de `ProviderDashboardShell`
  reste désactivé pour tout statut != `approved`, avec régression positive pour `approved` et
  défense de niveau 2 en cas de contournement. Couvert par
  `provider_dashboard_shell_status_gate_test.dart` (4/4 PASS, déjà committé). Un bug UI a été
  trouvé et corrigé pendant la clôture de F-2 : dépassement (`overflow`) de l'AppBar — voir
  `PHASE7_BUG_REPORT.md` BUG-007. Référencé uniquement, non redupliqué.
- **ROUTE-F-01 à ROUTE-F-06 — routes invalides/paramètres invalides** : route totalement inconnue
  (fallback GoRouter par défaut "Page Not Found"), paramètre `missionId` manquant (trailing
  slash), route admin sans rôle privilégié (`AdminAuthGate` → `AdminLoginScreen`, aucune fuite),
  paramètre `:type` légal malformé (`LegalScreen` retombe sur son `default`), mission
  chauffeur/client inexistante (fallback "introuvable" existant réutilisé). Couvert par
  `test/routing/app_router_invalid_routes_test.dart` (6/6 PASS, déjà committé à `b8eb381`).
  Confirmation explicite : `lib/router/app_router.dart` n'a AUCUN `errorBuilder`/`onUnknownRoute`
  personnalisé — c'est le fallback par défaut de `MaterialApp.router`/GoRouter qui est exercé et
  validé comme suffisant (pas d'écran blanc, pas d'exception, pas de fuite d'autorisation).
  Référencé uniquement, non redupliqué.
- **F-3 — deep-link notification → mission (NOUVEAU ce tour)** : ajout du seam
  `BackendLocator.notificationRepositoryOverride` (même pattern exact que
  `missionRepositoryOverride`/`driverRepositoryOverride`/`locationRepositoryOverride`/
  `proofUploadRepositoryOverride` — aucun refactor du système notifications). Nouveau fichier
  `test/notifications/notifications_deep_link_test.dart` (7 tests, 7/7 PASS) couvrant :
  - **F-3.1** : notification client valide → `markAsRead` → navigation
    `/livraison/suivi/X` → `CustomerTrackingScreen` reçoit exactement X.
  - **F-3.2** : notification pointant vers une mission supprimée (`watchMission` → `null`) →
    fallback EXISTANT réutilisé (`driver_active_mission_not_found`), aucune nouvelle logique
    métier créée.
  - **F-3.3** : notification pointant vers une mission d'un autre utilisateur, côté client
    (réutilise strictement la protection F-1) ET côté chauffeur (réutilise strictement la
    protection existante `mission.driverId != uid` de `DriverActiveMissionScreen`) — aucune
    duplication de ces contrôles.
  - **Cas nominal chauffeur** : prouve que le branchement `auth.hasRole(PlatformRole.driver)`
    de `NotificationsScreen` route bien vers `/fournisseur/mission/X` (pas la route client).
  - **missionId null/vide** : comportement actuel (skip silencieux de la navigation, `markAsRead`
    quand même appelé) documenté et prouvé stable, AUCUNE modification de comportement car aucun
    bug démontré.

**Bugs fermés dans ce bloc** : BUG-007 (P2, AppBar overflow F-2, CORRIGÉ). **F-3 n'a révélé
AUCUN nouveau bug** — chaque scénario a atteint une protection déjà correcte sans qu'aucun code
de production n'ait besoin d'être modifié.

**Validation de clôture** :
- `flutter test test/notifications/notifications_deep_link_test.dart
  test/customer/customer_tracking_cross_customer_test.dart
  test/driver/provider_dashboard_shell_status_gate_test.dart
  test/driver/driver_active_mission_status_gaps_test.dart
  test/driver/driver_active_mission_proof_upload_test.dart
  test/routing/app_router_invalid_routes_test.dart` → **32/32 PASS** (aucune régression).
- `flutter analyze` (projet complet) → 0 souci nouveau (3 issues `info` pré-existantes et non
  liées : `deprecated_member_use` x2 dans `mechanic_request_flow_screen.dart`,
  `unintended_html_in_doc_comment` dans `storage_service.dart` — identiques à toutes les
  validations précédentes, non régressées).

**Fichiers créés/modifiés (F-3, ce tour)** :
- `lib/backend/backend_locator.dart` (seam `notificationRepositoryOverride`, +11 lignes).
- `test/notifications/notifications_deep_link_test.dart` (nouveau, 7 tests).
- `docs/PHASE7_QA_MATRIX.md` (section "Routing / Deep Links (Bloc F)" — F-1/F-2/ROUTE-F-01..06/F-3).
- `docs/PHASE7_BUG_REPORT.md` (section "Bloc F" — BUG-007, note F-3 sans nouveau bug).
- `docs/PHASE7_QA_PLAN.md` (ce fichier — clôture Bloc F).

**Fichiers déjà committés précédemment, référencés sans modification** :
`test/customer/customer_tracking_cross_customer_test.dart`,
`test/driver/provider_dashboard_shell_status_gate_test.dart`,
`test/routing/app_router_invalid_routes_test.dart`.

---

## BLOC G : ✅ FERMÉ

**Périmètre couvert** — matrice courte requirement→test existant→COUVERT/GAP effectuée en premier
(voir `docs/PHASE7_QA_MATRIX.md`, section "Offline / Réseau / Retry (Bloc G)"), puis codage des
3 seuls GAPS réels identifiés :
- **G-1/G-2 — Cloud Function `unavailable` + retry idempotent** : nouveau fichier
  `test/network/driver_action_cloud_function_unavailable_test.dart` (2 tests) sur
  `DriverActiveMissionScreen` (`_FlakyMissionRepository` fake qui échoue N fois puis réussit).
  Prouve : aucun faux succès, message traduit affiché, bouton redevient actionnable, aucun crash
  (G-1) ; retry réussit avec exactement 2 appels au total (1 échec + 1 succès), aucune duplication
  de transition (G-2).
- **G-3 — Firestore listener error + reprise** : nouveau fichier
  `test/network/mission_tracking_listener_error_test.dart` (2 tests) sur `CustomerTrackingScreen`
  (`StreamController.addError()` sur `watchMission()`). Prouve : aucun crash, aucun écran blanc,
  message réseau cohérent, aucune ancienne donnée (nom du chauffeur) présentée comme encore valide
  (G-3.1) ; reprise naturelle après nouvelle émission valide sur le même flux, sans couche offline
  additionnelle (G-3.2).
- **G-4 — Firestore write failure** : nouveau fichier
  `test/network/notification_mark_as_read_write_failure_test.dart` (2 tests) sur
  `NotificationsScreen`/`markAsRead()`. **Bug réel P2 trouvé et corrigé** : `NotificationsScreen.
  onTap` appelait `markAsRead()` sans catcher l'échec → exception non gérée remontant jusqu'au
  binding Flutter. Fix : `.catchError((_) {})` ajouté (le marquage lu/non-lu est un confort UX
  secondaire, son échec ne doit jamais bloquer la navigation vers la mission liée). Après fix :
  aucun faux succès, navigation continue de fonctionner, retry possible (G-4.1/G-4.2).
- **G-5 — réutilisation des preuves existantes** : mission creation (MIS-C-09), proof upload
  (`driver_active_mission_proof_upload_test.dart`), GPS (`driver_location_reporter_test.dart`),
  paiement/refund/payout (Phase 6 + `submitDriverPayoutFailure.test.ts`) — tous référencés dans la
  matrice, aucune duplication.

**Bug fermé dans ce bloc** : nouveau bug **P2** (markAsRead non catché, `NotificationsScreen`),
découvert par TEST → FAIL → FIX → RETEST pendant G-4, CORRIGÉ. Voir `PHASE7_BUG_REPORT.md`
BUG-008. Aucun bug P0/P1.

**Validation de clôture (exécutée réellement, pas seulement rédigée)** :
- `flutter test test/network/` → **6/6 PASS**.
- `flutter analyze` (projet complet) → 3 issues `info` pré-existantes non liées, 0 souci nouveau.
- `flutter test` (suite complète du projet) → **410/410 PASS, aucune régression**.

**Fichiers créés/modifiés (Bloc G, ce tour)** :
- `test/network/driver_action_cloud_function_unavailable_test.dart` (nouveau, 2 tests).
- `test/network/mission_tracking_listener_error_test.dart` (nouveau, 2 tests).
- `test/network/notification_mark_as_read_write_failure_test.dart` (nouveau, 2 tests).
- `lib/screens/notifications/notifications_screen.dart` (fix BUG-008 : `.catchError((_) {})`).
- `docs/PHASE7_QA_MATRIX.md` (section "Offline / Réseau / Retry (Bloc G)").
- `docs/PHASE7_BUG_REPORT.md` (section Bloc G, BUG-008).
- `docs/PHASE7_QA_PLAN.md` (ce fichier — clôture Bloc G).

**PROCHAINE ACTION EXACTE (reprise ici, pas de nouvel audit général)** :
1. **Bloc G est FERMÉ.**
2. **Bloc H est FERMÉ** (voir section dédiée ci-dessous).
3. Enchaîner **Bloc I — NOTIFICATIONS** (création, read/unread, badge, realtime, duplication —
   réutiliser F-3 pour navigation, ne pas la redupliquer ; documenter I-7 push externe/FCM comme
   `DEFERRED / Phase 8` si non prêt en production).
4. **Ne pas refaire d'audit général** pour G/F/E/D/H (fermés), ni Security Rules (196/196 PASS +
   16 tests `driver_locations` référencés au Bloc H).
5. Une fois I et J fermés : validation croisée (`flutter analyze`, `flutter test`,
   `npx tsc --noEmit`, `npm run lint` si backend touché), mise à jour finale des 3 docs QA,
   commit+push final, puis rapport unique `# PHASE 7 — BLOCS H → I → J`.

---

## BLOC H : ✅ FERMÉ

**Périmètre couvert** — matrice courte requirement→test existant→COUVERT/GAP effectuée en premier
(voir `docs/PHASE7_QA_MATRIX.md`, section "GPS / Tracking durcissement (Bloc H)"), puis codage du
seul GAP réel identifié :
- **H-1 — Permissions GPS** : déjà entièrement couvert par `driver_location_reporter_test.dart`
  (9 tests, isolé au niveau de la classe `DriverLocationReporter` — service désactivé, permission
  denied/deniedForever, refus-puis-accord, échec `getCurrentPosition`/`reportDriverLocation`,
  idempotence de `start()`, `stop()` isolé). Référencé, non redupliqué.
- **H-2 — Lifecycle tracking au niveau écran (GAP comblé ce bloc)** : nouveau fichier
  `test/driver/driver_active_mission_gps_lifecycle_test.dart` (6 tests) prouvant, au niveau
  `DriverActiveMissionScreen` (pas seulement de la classe isolée) : CAS 1 mission `assigned` →
  partage démarre réellement (1 rapport immédiat, `checkPermission()` appelé 1 fois) ; CAS 2
  `inTransit` → `completed` → partage s'arrête (aucun nouveau rapport/vérification après 5 pumps
  supplémentaires) ; CAS 3 `driverToPickup` → `cancelled` → même exigence ; idempotence lifecycle
  (`assigned → driverToPickup → arrivedAtPickup`, toutes des transitions "partage actif" : une
  seule vérification de permission au total, jamais de 2e boucle démarrée) ; nettoyage `dispose()`
  pendant partage actif (`stop()` sans exception, aucun rapport résiduel) ; idempotence
  `stop()`/`stop()` isolée (aucune exception, état propre).
- **H-3 — BUG-006 (boucle infinie GPS)** : réexécuté (pas recréé) —
  `driver_active_mission_status_gaps_test.dart` + `driver_location_reporter_test.dart` →
  **18/18 PASS**, toujours vert.
- **H-4 — Sécurité tracking** : déjà entièrement couvert par
  `functions/test/integration/securityRules.test.ts` (16 tests ciblés sur `driver_locations/
  {driverId}` + `driver_locations/{driverId}/history/{eventId}` : write self OK, write autre
  chauffeur DENIED, read sans mission active DENIED, read avec mission active assignée OK, read
  mission active mais autre chauffeur DENIED, read après nettoyage `active_delivery_id=null`
  DENIED, analyste read tout OK, non-authentifié DENIED (read+write), écriture directe historique
  interdite même pour super_admin, lecture historique propriétaire/tiers/analyste). Référencé, non
  redupliqué — aucune réexécution intégrale des 196 Security Rules nécessaire.
- **H-5 — Background/Foreground** : **DEFERRED NON-BLOCKING → Phase 8**, documenté honnêtement.
  Confirmé par lecture directe : `AndroidManifest.xml` ne demande PAS
  `ACCESS_BACKGROUND_LOCATION` (commentaire explicite dans le fichier), et
  `driver_location_reporter.dart` documente lui-même "Ne tourne jamais en arrière-plan". Aucune
  architecture de background tracking construite ce bloc — dépend de permissions OS avancées et
  de configuration Android/iOS production, hors périmètre MVP actuel.
- **H-6 — Position stale/invalide** : **N/A**, documenté. Grep exhaustif confirme qu'aucun
  consommateur actuel (`LiveTrackingMap`, écrans client/chauffeur) ne lit/valide
  `DriverLocation.updatedAt` pour détecter une position périmée — aucun moteur de validation
  construit arbitrairement pour satisfaire une checklist théorique.

**Bugs trouvés dans ce bloc** : **AUCUN** (P0/P1/P2/P3 = 0). Le code de production
(`_syncGpsSharing()`, `_syncGpsSharingIfStatusChanged()`, `DriverLocationReporter.start()/stop()`)
se comporte exactement comme attendu au niveau écran — chaque scénario testé (start/stop selon
statut, idempotence, dispose) a directement validé le comportement existant sans qu'aucune
correction de code de production n'ait été nécessaire.

**Validation de clôture (exécutée réellement, pas seulement rédigée)** :
- `flutter test test/driver/driver_active_mission_gps_lifecycle_test.dart` → **6/6 PASS**.
- `flutter test test/driver/driver_active_mission_status_gaps_test.dart
  test/driver/driver_location_reporter_test.dart` → **18/18 PASS** (BUG-006 confirmé toujours
  vert, aucune régression).
- `flutter analyze` (projet complet) → 3 issues `info` pré-existantes non liées, 0 souci nouveau.
- `flutter test` (suite complète du projet) → **416/416 PASS** (410 précédents + 6 nouveaux,
  aucune régression).
- Security Rules `driver_locations` : référencées sans réexécution isolée nécessaire (aucune
  modification de `firestore.rules` ni de `securityRules.test.ts` ce bloc — `npx tsc --noEmit`/
  `npm run lint` non requis, backend non touché).

**Fichiers créés/modifiés (Bloc H, ce tour)** :
- `test/driver/driver_active_mission_gps_lifecycle_test.dart` (nouveau, 6 tests).
- `docs/PHASE7_QA_MATRIX.md` (section "GPS / Tracking durcissement (Bloc H)").
- `docs/PHASE7_BUG_REPORT.md` (section Bloc H — aucun bug, bilan explicite).
- `docs/PHASE7_QA_PLAN.md` (ce fichier — clôture Bloc H).

## BLOC I : ✅ FERMÉ

**Périmètre couvert** :
- I-1 création (8 transitions statut) : COUVERT, référencé sans duplication
  (`functions/test/integration/onMissionStatusChangeNotifyCustomer.test.ts`, 15 cas).
- I-1 secondaire (`detectExpiringDocuments`, `transitionFoundingDriverPeriods`) : aucun test
  dédié trouvé ; logique simple (même schéma d'écriture `users/{uid}/notifications/{id}` déjà
  validé par le trigger principal), aucun bug démontré → documenté non-bloquant, pas de nouveau
  test construit arbitrairement pour satisfaire le plan.
- I-2 read/unread + badge (`NotificationBell`, `markAsRead` idempotence) : GAP confirmé (le test
  G-4 note explicitement "hors périmètre... cf. Bloc I") → COMBLÉ.
- I-3 realtime + listener error sur `NotificationsScreen.watchNotifications()` : GAP confirmé
  (le pattern G-3 n'existait que sur `CustomerTrackingScreen`) → COMBLÉ.
- I-4 duplication/idempotence : architecture par `onDocumentUpdated`, un déclenchement = une
  écriture réelle de transition de statut ; aucun scénario de duplication réelle démontrable en
  usage normal → pas de nouveau système de dédup construit arbitrairement.
- I-5 navigation post-tap : COUVERT, référencé Bloc F (`notifications_deep_link_test.dart`),
  non dupliqué.
- I-6 FR/EN/ES notifications : COUVERT via audit direct des clés `notif_*`/`notifications_*`
  dans `lib/l10n/app_strings.dart` — toutes présentes en FR/EN/ES, aucune chaîne en dur.
- I-7 push mobile externe (FCM/APNs) : aucune dépendance `firebase_messaging`/FCM/APNs dans le
  projet → documenté `DEFERRED / Phase 8`.

**Bugs trouvés (Bloc I)** : AUCUN. Les gaps I-2/I-3 comblés ont prouvé un comportement déjà
correct (badge temps réel, idempotence markAsRead, gestion d'erreur listener déjà implémentée
dans `NotificationsScreen` via `snap.hasError`).

**Validation de clôture** :
- Nouveau test : `flutter test test/notifications/notifications_realtime_and_unread_test.dart`
  → 6/6 PASS.
- Suite complète : `flutter test` → 422/422 PASS (+6 vs 416 post-Bloc H, aucune régression).
- `flutter analyze` → 0 souci nouveau (mêmes 3 `info` préexistants et non liés).
- Backend non touché ce bloc → `npx tsc --noEmit`/`npm run lint` non requis.

**Fichiers créés/modifiés (Bloc I, ce tour)** :
- `test/notifications/notifications_realtime_and_unread_test.dart` (nouveau, 6 tests).
- `docs/PHASE7_QA_MATRIX.md` (section "Notifications (Bloc I)").
- `docs/PHASE7_BUG_REPORT.md` (section Bloc I — aucun bug, bilan explicite).
- `docs/PHASE7_QA_PLAN.md` (ce fichier — clôture Bloc I).

**PROCHAINE ACTION EXACTE (reprise ici si interruption, pas de nouvel audit général)** :
1. **Blocs H et I sont FERMÉS.**
2. Enchaîner **Bloc J — RESPONSIVE/VIEWPORTS** (non démarré) : J-0 matrice écrans MVP critiques
   (Auth/Client/Driver/Admin) ; J-1 viewports (petit ~320-360px, standard ~390-430px, grand
   ~430-480px, tablette/desktop si prévu) ; J-2 référencer/réexécuter BUG-007 (regression
   AppBar overflow) sans le redupliquer ; J-3 effet FR/EN/ES sur écrans critiques ; J-4
   clavier/formulaires (login, signup, création mission, onboarding chauffeur) ; J-5
   modals/dialogs critiques ; J-6 web/desktop uniquement si des écrans web sont réellement
   prévus. RÈGLE OVERFLOW stricte (jamais masquer `tester.takeException()`, jamais élargir
   artificiellement le viewport pour faire passer un test).
3. Une fois J fermé : validation croisée H→I→J (`flutter analyze`, `flutter test` complet,
   backend si touché), mise à jour finale des 3 docs QA, commit+push, puis rapport final unique
   `# PHASE 7 — BLOCS H → I → J`.
