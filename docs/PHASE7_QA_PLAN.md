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
| F | Routing/Deep Links | NEXT | pas de redirection infinie |
| G | Offline/Réseau/Retry | NEXT | pas de perte de mission financière |
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
