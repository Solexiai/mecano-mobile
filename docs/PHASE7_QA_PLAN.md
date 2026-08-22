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

## Point de reprise actuel (mis à jour après le 1er cycle TEST→FAIL de cette session)

**Dernière action complétée** :
- Règle 3 : `docs/PHASE7_QA_PLAN.md` créé.
- Bloc A : `docs/PHASE7_QA_MATRIX.md` créé (v1, sera enrichi en continu).
- Bloc B (démarré) : reconnaissance ciblée sur le flux d'annulation client post-assignation →
  découverte d'un bug financier réel (**BUG-001**, voir `docs/PHASE7_BUG_REPORT.md`) :
  aucune Cloud Function n'appelle `PaymentProvider.cancelAuthorization()` quand un client annule
  une mission déjà assignée avec paiement `AUTHORIZED`. Confirmé par un test d'intégration réel
  (`functions/test/integration/missionCancellationPaymentRelease.test.ts`, 3 tests, exécuté
  contre les émulateurs : **2 failed / 1 passed** — le FAIL est confirmé et reproductible).

**PROCHAINE ACTION EXACTE (reprise ici, pas de nouvel audit)** :
1. Implémenter le correctif dans `onMissionEndedClearTracking.ts` (ou fonction dédiée appelée
   par lui) suivant EXACTEMENT le schéma en 3 temps déjà établi dans `paymentOrchestration.ts`
   (transaction Firestore → appel provider HORS transaction avec idempotencyKey déterministe
   `buildIdempotencyKey("cancelAuthorization", paymentId)` → transaction Firestore appliquant le
   résultat + `writeAuditLog({action: "payment_authorization_cancelled"})`). Détail complet du
   correctif attendu déjà rédigé dans `docs/PHASE7_BUG_REPORT.md` (BUG-001).
2. Relancer `missionCancellationPaymentRelease.test.ts` → les 3 tests doivent passer au vert
   (RETEST).
3. Relancer la suite Security Rules (180 tests) + `onMissionEndedClearTracking.test.ts` existant
   pour zéro régression.
4. `npx tsc --noEmit` + `npm run lint` (uniquement `src/`, ne pas toucher au formatage global).
5. Commit + push (message référencant BUG-001), mettre à jour `docs/PHASE7_BUG_REPORT.md`
   (statut OUVERT → CORRIGÉ) et ce fichier (Bloc B toujours IN PROGRESS, poursuivre avec les
   autres cas négatifs listés dans `PHASE7_QA_MATRIX.md` : MIS-C-02 aucun chauffeur dispo,
   MIS-C-04 paiement refusé, MIS-C-06/07 session expirée/non authentifié, MIS-C-08 ancienne
   mission, MIS-C-09 retry réseau).
6. Une fois Bloc B (E2E Client) réellement clos (nominal + tous les cas négatifs testés),
   enchaîner Bloc C (E2E Chauffeur).

**Fichiers déjà créés/modifiés cette session (non encore commités au moment de la rédaction de
cette note — à committer avec le message ci-dessous)** :
- `docs/PHASE7_QA_PLAN.md` (nouveau)
- `docs/PHASE7_QA_MATRIX.md` (nouveau)
- `docs/PHASE7_BUG_REPORT.md` (nouveau)
- `functions/test/integration/missionCancellationPaymentRelease.test.ts` (nouveau — test de
  régression pour BUG-001, actuellement 2/3 rouge, C'EST ATTENDU tant que le correctif n'est pas
  implémenté — NE PAS interpréter ce rouge comme une régression d'un autre bloc)

**Important pour la prochaine session** : `flutter test`/`test:unit`/`test:integration` complets
n'ont PAS été ré-exécutés dans ce cycle (seul le test ciblé BUG-001 a tourné) — à faire lors de
la clôture du Bloc B, pas avant (éviter la sur-vérification prématurée, cf. Règle 2 anti-boucle).
