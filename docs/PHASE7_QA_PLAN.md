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
| B | E2E Client complet | IN PROGRESS | BUG-001 découvert+confirmé par test (voir ci-dessous). Correctif à implémenter ensuite. |
| C | E2E Chauffeur complet | NEXT | parcours + cas négatifs |
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

## Point de reprise actuel (mis à jour après BUG-001 corrigé + MIS-C-02/04/06/07/08 traités)

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

**PROCHAINE ACTION EXACTE (reprise ici, pas de nouvel audit)** :
1. **MIS-C-09** (déconnexion réseau pendant requête, pas de double mission) : reste **NON
   TRAITÉ**. Piste identifiée mais pas encore vérifiée : `createMissionFromQuote()` (client) ->
   Cloud Function `createDeliveryRequest` — vérifier si un retry réseau côté client (bouton
   toujours actif pendant `_phase == _FlowPhase.creating` ? à confirmer dans
   `step_progress_form.dart`/`delivery_request_flow_screen.dart`) peut créer 2 missions pour le
   même `quoteId`, et si le serveur a une protection idempotente sur `quoteId` déjà consommé.
   TEST → possible FAIL → FIX → RETEST.
2. Une fois MIS-C-09 traité : exécuter `flutter test` complet (suite entière, pas seulement les
   fichiers ciblés — pas fait depuis le début de la Phase 7, à faire UNE FOIS avant la clôture du
   Bloc B, cf. Règle 2 anti-boucle : c'est la vérification de clôture, pas une reconnaissance).
3. Déclarer **"BLOC B : ✅ FERMÉ"** dans ce fichier.
4. Enchaîner directement **Bloc C — E2E CHAUFFEUR** (parcours complet + cas négatifs : chauffeur
   non approuvé, document manquant, véhicule non vérifié, compte suspendu, course de
   double-acceptation, GPS refusé/désactivé, échec upload preuve, échec payout) sans audit
   général préalable.

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

**Important pour la prochaine session** : `flutter test` complet et `flutter analyze` complet du
projet n'ont PAS été ré-exécutés dans ce cycle (seuls les fichiers modifiés ont été vérifiés
individuellement, conformément à la règle "pas de `dart format .` global"). À faire une seule
fois, à la clôture du Bloc B (voir étape 2 ci-dessus).
