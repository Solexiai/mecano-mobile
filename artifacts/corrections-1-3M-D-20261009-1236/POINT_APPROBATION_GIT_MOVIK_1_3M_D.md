# POINT D'APPROBATION GIT — MOVI-K 1.3M-D

Date : 9 octobre 2026, America/Toronto.
**STATUT : préparation terminée — COMMIT LOCAL EN ATTENTE D'APPROBATION.**

## 1. Reprise et version

Aucun rapport 1.3M-D ni mention de cette étape n'a été trouvé avant intervention dans les dossiers artifacts/docs du worktree. La recherche locale n'a donc pas révélé une étape déjà effectuée.

- Dépôt : Solexiai/mecano-mobile.
- Worktree : C:\Users\Utilisateur\movik-gps-history-fix-20261009
- Branche initiale et finale : fix/gps-client-history-scope-20261009.
- HEAD initial et final : 77c3c61534d1300ddc0eab5585f78b9662a69537.
- Aucun fichier dans l'index au début ni à la fin. Aucun git add, commit, push, merge ou changement de branche.
- Aucun autre worktree modifié ou utilisé pour une écriture.

Les huit fichiers du correctif sont identiques, par SHA256, à la fin de 1.3M-C. Les 19 fichiers sélectionnés dans le dossier 1.3M-C correspondent à son manifeste historique. Le correctif validé est le HEAD plus les modifications existantes, pas le HEAD seul.

Sources : git-initial.json, continuity-1-3M-C.json, security-and-proof-review.json et git-final.json dans ce dossier.

## 2. Fermeture documentaire approuvée

**P1-M-01 : FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ.**

Fermeture appliquée uniquement au défaut de requête d'historique GPS sans filtre serveur par mission, conformément à l'approbation explicite de Daniel dans la mission 1.3M-D.

Les statuts précédents restent dans l'historique. Le registre conserve les preuves de permissions Firestore, du contrat obligatoire missionId, du filtre avant snapshots, de la garde sans mission, du filtrage défensif et de la compatibilité des consommateurs testés.

Cette fermeture ne valide pas tout le GPS, la production, le GPS physique, le cache, la fraîcheur des positions ou les courses d'assignation. **1.3L reste BLOQUÉ ET REPORTÉ.**

## 3. Registre maître et compte recalculé

Seul registre de référence :
docs/audit/REGISTRE_BOGUES_MOVIK.md

Sauvegarde intégrale avant clôture : REGISTRE_AVANT_FERMETURE.md, conservée localement dans ce dossier, exclue du commit proposé pour éviter de dupliquer le registre.

Calcul : lecture du tableau de suivi, exclusion des seules lignes dont le statut commence par FERMÉ. Résultat : 27 entrées, une fermée, 26 non fermées.

| Priorité | Ouverts |
|---|---:|
| P0 | 0 |
| P1 | 5 |
| P2 | 21 |

Les cinq P1 restants : R-K-03-A, R-K-03-B, R-K-03-C, P1-HOME-001 et P1-COPY-001. Les deux derniers ont des validations historiques mais restent non fermés.

Tous les P2 restent présents, notamment H-01/H-02, I-01/I-02, J-01 et K-01. Les P3 historiques, risques provisoires, archives, prérequis de contact/lancement et décisions reportées sont conservés. Le compte du tableau actif n'est pas une garantie d'absence de P0 sur toute la production.

Preuve : closure-counts.json. Les anciens addenda 1.3M-B et 1.3M-C sont conservés intégralement avec leurs comptes à leur date.

## 4. Résumé du diff inspecté

Les changements de code existaient avant 1.3M-D : **8 fichiers suivis, 79 insertions et 29 suppressions**. git diff --check retourne 0.

| Fichier | Changement présent |
|---|---|
| lib/backend/repositories/location_repository.dart | missionId requis dans l'interface et l'implémentation non configurée |
| lib/backend/repositories/firebase_location_repository.dart | where('delivery_id', isEqualTo: missionId) avant snapshots |
| lib/widgets/live_tracking_map.dart | pas d'historique avec missionId nul/vide ; passage de la mission au repository |
| functions/test/integration/securityRules.test.ts | scénario permanent de requêtes de collection A/B, refus sans filtre et droits du chauffeur |
| test/driver/driver_active_mission_gps_lifecycle_test.dart | adaptation de signature du faux repository |
| test/driver/driver_active_mission_status_gaps_test.dart | même adaptation |
| test/driver/driver_location_reporter_test.dart | même adaptation |
| test/responsive/bloc_u_mobile_sanity_test.dart | même adaptation |

Aucune modification de firestore.rules, du moteur tarifaire, de Stripe, des snapshots ou des lockfiles. Dans cette étape, seules la documentation de clôture et les nouvelles preuves de préparation sont écrites.

Le registre est nouveau pour Git, mais préexistait sur disque : il sera sauvegardé intégralement, avec ses archives. Aucune refonte documentaire ni registre parallèle.

## 5. Liste exacte proposée pour le commit

**36 fichiers : 8 fichiers déjà suivis modifiés et 28 fichiers non suivis à ajouter.**
Les 28 ajouts comprennent le registre et 27 fichiers de tests/preuves/documentation sélectionnés.

Les chemins ci-dessous sont relatifs au worktree de correction. Aucune sélection globale de artifacts ou de docs n'est proposée.

```text
functions/test/integration/securityRules.test.ts
lib/backend/repositories/firebase_location_repository.dart
lib/backend/repositories/location_repository.dart
lib/widgets/live_tracking_map.dart
test/driver/driver_active_mission_gps_lifecycle_test.dart
test/driver/driver_active_mission_status_gaps_test.dart
test/driver/driver_location_reporter_test.dart
test/responsive/bloc_u_mobile_sanity_test.dart
docs/audit/REGISTRE_BOGUES_MOVIK.md
artifacts/corrections-1-3M-B-20261009-1110/CHECKPOINT_CORRECTIONS_MOVIK_P1_M_01_REGISTRE.md
artifacts/corrections-1-3M-B-20261009-1110/supplemental-v3.ts
artifacts/corrections-1-3M-B-20261009-1110/flutter-analyze.log
artifacts/corrections-1-3M-B-20261009-1110/flutter-reporter.log
artifacts/corrections-1-3M-C-20261009-1158/CHECKPOINT_CORRECTIONS_MOVIK_1_3M_C.md
artifacts/corrections-1-3M-C-20261009-1158/ISOLATION.md
artifacts/corrections-1-3M-C-20261009-1158/COMMANDES_TESTS.ps1.txt
artifacts/corrections-1-3M-C-20261009-1158/test-results-summary.json
artifacts/corrections-1-3M-C-20261009-1158/source-hashes.json
artifacts/corrections-1-3M-C-20261009-1158/existing-tests-copy-verification.json
artifacts/corrections-1-3M-C-20261009-1158/analyze-consumers.log
artifacts/corrections-1-3M-C-20261009-1158/analyze-new-tests.log
artifacts/corrections-1-3M-C-20261009-1158/contract-tests.jsonl
artifacts/corrections-1-3M-C-20261009-1158/consumer-tests.jsonl
artifacts/corrections-1-3M-C-20261009-1158/isolation-test.jsonl
artifacts/corrections-1-3M-C-20261009-1158/isolation-test-v2.jsonl
artifacts/corrections-1-3M-C-20261009-1158/isolation-test-v3.jsonl
artifacts/corrections-1-3M-C-20261009-1158/test/gps_history_contract_test.dart
artifacts/corrections-1-3M-C-20261009-1158/test/offline_transport.dart
artifacts/corrections-1-3M-C-20261009-1158/test/isolated_driver_lifecycle_test.dart
artifacts/corrections-1-3M-C-20261009-1158/test/isolated_driver_status_test.dart
artifacts/corrections-1-3M-C-20261009-1158/test/isolated_customer_ownership_test.dart
artifacts/corrections-1-3M-C-20261009-1158/test/isolated_customer_auth_test.dart
artifacts/corrections-1-3M-D-20261009-1236/POINT_APPROBATION_GIT_MOVIK_1_3M_D.md
artifacts/corrections-1-3M-D-20261009-1236/COMMIT_FILES.txt
artifacts/corrections-1-3M-D-20261009-1236/VALIDATION_ACQUISE.json
artifacts/corrections-1-3M-D-20261009-1236/MANIFEST_COMMIT.json
```

COMMIT_FILES.txt est la liste de référence pour préparer l'index après approbation. MANIFEST_COMMIT.json fournit les empreintes des 35 autres fichiers ; il ne peut contenir son propre hash. Tout changement ultérieur des fichiers impose de vérifier à nouveau la sélection avant commit.

Les six fichiers Dart sous artifacts sont conservés à leurs chemins déjà testés. Leur inclusion est une sauvegarde des tests temporaires validés, pas une promotion dans test/ ni une activation automatique en CI.

## 6. Tests permanents, temporaires et preuves conservées

Aucun test Flutter/Firestore/cartographique exécuté dans 1.3M-D. Les contrôles Git, de contenu, de hash, de décompte et de motifs sensibles ne sont pas comptés comme nouveaux tests fonctionnels.

| Preuve historique | Résultat conservé |
|---|---|
| Firestore 1.3M-B, exécution finale | 3 réussis, 0 échoué, 197 autres tests exclus |
| Reporter GPS 1.3M-B | 9 réussis |
| Contrôles finaux 1.3M-C | 28 réussis, 0 échoué, 0 ignoré : isolation 1 + contrat 7 + consommateurs 20 |
| Analyses ciblées du produit | Réussies dans les périmètres décrits par les checkpoints |
| Harnais temporaire, analyse initiale | 14 avertissements, conservés ; pas d'analyse sans avertissement revendiquée |
| Essais antérieurs infructueux | Conservés et distingués des exécutions finales |

VALIDATION_ACQUISE.json est une extraction des anciens résultats avec chemins et empreintes des sources. Il inclut les cinq essais Firestore successifs, sans réécrire les échecs, ainsi que les résultats Flutter. Les gros résultats JSON Firestore et journaux d'origine restent sur disque, inchangés, hors de la sélection Git.

### Intégration permanente à envisager séparément

- gps_history_contract_test.dart et offline_transport.dart : candidats nécessaires pour conserver automatiquement la garde missionId nul/vide, la requête filtrée, le tri, le filtre défensif et le passage d'identifiants dans les consommateurs. Déplacement, imports, choix d'exécution CI et avertissements devront être traités puis validés dans une intervention autorisée. Rien déplacé ici.
- Les quatre isolated_* sont des copies d'exécution dont les assertions et corps originaux ont été conservés. Ne pas créer quatre suites permanentes en double ; conserver/reprendre les suites existantes avec une isolation validée.
- supplemental-v3.ts : archive des deux contrôles complémentaires Firestore (rôles et listeners). Ce fragment dépend du contexte du harnais 1.3M-B ; ce n'est pas un nouveau test autonome prêt à exécuter. Son éventuelle intégration dans securityRules.test.ts nécessitera analyse et nouvelle validation isolée.
- Le scénario permanent déjà ajouté à securityRules.test.ts teste getDocs sur la collection, et pas seulement getDoc.

Les scripts de commandes historiques contiennent des chemins Windows locaux. Les preuves restent traçables ; leur présence dans Git ne garantit pas une exécution automatique sur une autre machine.

## 7. Exclusions du commit proposé

Tout fichier absent de COMMIT_FILES.txt est exclu, sans suppression du disque. Notamment :

- Caches Jest jest-cache*, sorties rules-only*/ en JavaScript compilé et fichiers .map.
- .dart_tool, build, node_modules, SDK Flutter, caches Pub, émulateurs et dépendances.
- rules-results*.json et rules-tests*.log de 1.3M-B, journaux d'émulateur, traces réseau brutes ; synthèse et empreintes conservées dans VALIDATION_ACQUISE.json.
- checkpoints-origines.json et copies Phase7/PILOT_READINESS/PUBLIC_REVIEW déjà reprises dans le registre ; pas de duplication volumineuse.
- Sauvegardes REGISTRE_BOGUES_AVANT.md / REGISTRE_AVANT_FERMETURE.md, versions préliminaires du harnais, wrappers existing_* jamais exécutés, scripts de préparation et doublons de diff.
- transport-sources.json, copie des sources de dépendances, conservée localement.
- Captures, fichiers personnels, configuration .env, clés, jetons, comptes de service, fichiers locaux des autres worktrees.
- Preuves diagnostiques locales de cette préparation non énumérées dans la liste.

Les petits journaux Flutter retenus documentent le succès final, les erreurs initiales et les avertissements ; aucun journal retenu n'atteint 42 Ko. Le registre reste le plus gros document sélectionné afin de préserver tout l'historique demandé.

Contrôle sensible : neuf familles de motifs recherchées sur le contenu des fichiers proposés (clés privées, Stripe, GitHub, Google/OAuth, comptes de service, JWT, accès AWS et URL Storage avec token). Aucune valeur de secret détectée ou imprimée par cette vérification. Revue du diff et des fichiers de test : données fictives et sources techniques ; aucun fichier personnel sélectionné. Cette vérification locale ne revendique pas une certification exhaustive de sécurité.

git check-ignore sur la liste : aucune entrée ignorée détectée, sortie 1 signifiant absence de correspondance. Aucun besoin de forcer l'ajout global de fichiers ignorés.

## 8. Git initial et final

État initial :

    ## fix/gps-client-history-scope-20261009
     M functions/test/integration/securityRules.test.ts
     M lib/backend/repositories/firebase_location_repository.dart
     M lib/backend/repositories/location_repository.dart
     M lib/widgets/live_tracking_map.dart
     M test/driver/driver_active_mission_gps_lifecycle_test.dart
     M test/driver/driver_active_mission_status_gaps_test.dart
     M test/driver/driver_location_reporter_test.dart
     M test/responsive/bloc_u_mobile_sanity_test.dart
    ?? artifacts/corrections-1-3M-B-20261009-1110/
    ?? artifacts/corrections-1-3M-C-20261009-1158/
    ?? docs/audit/

État final : mêmes entrées, avec le registre actualisé à l'intérieur de docs/audit et ce nouveau dossier :

    ?? artifacts/corrections-1-3M-D-20261009-1236/

Aucun changement de HEAD ou de branche ; huit empreintes de sources existantes inchangées. Index toujours vide. Les autres worktrees n'ont pas été modifiés. Aucune publication ou configuration système modifiée.

## 9. Risques et blocages toujours ouverts

- R-K-03-A : autorité d'écriture GPS et missions terminales.
- R-K-03-B : concurrence des écritures et nettoyage.
- R-K-03-C : fraîcheur et association chauffeur/mission.
- P2-K-01 : présentation des erreurs GPS ; P2 clients et autres entrées du registre.
- 1.3L : test des tuiles BLOQUÉ ET REPORTÉ.
- GPS terrain, Chrome, production et déploiement du correctif : NON VALIDÉS ici.
- Harnais temporaires non intégrés à la suite permanente ; cette étape les archive seulement.
- Tant que le commit n'est pas autorisé puis réalisé, les changements restent non committés. Un commit local ne constituera pas une sauvegarde distante.

Aucune correction R-K-03-A commencée. Les garde-fous financiers et les règles de production n'ont pas été modifiés.

## 10. Approbation demandée — une seule prochaine action

Message de commit proposé :

    fix(gps): scope client history by mission and preserve validation evidence

**Daniel, autorises-tu le commit local des seuls 36 fichiers listés, sur fix/gps-client-history-scope-20261009, sans push, merge ni déploiement ?**

L'approbation de fermeture documentaire P1-M-01 a déjà été utilisée. L'autorisation de commit est distincte, explicitement requise par la mission 1.3M-D. Aucun commit exécuté à ce point d'approbation.

Après cette sauvegarde, la prochaine correction produit prévue est R-K-03-A ; elle nécessitera sa propre autorisation. Arrêt ici.

## Sources de cette décision

- Mission 1.3M-D et approbation explicite de Daniel, 9 octobre 2026.
- CHECKPOINT_CORRECTIONS_MOVIK_1_3M_C.md, preuves et manifeste du 9 octobre 2026, conservés dans le dossier 1.3M-C.
- CHECKPOINT_CORRECTIONS_MOVIK_P1_M_01_REGISTRE.md et résultats d'émulateur du 9 octobre 2026, dossier 1.3M-B.
- Inspection locale Desktop Commander du 9 octobre 2026 : diff, HEAD/status, empreintes, registre, liste de fichiers, résultats historiques et contrôles sensibles. Pas de consultation ni de modification de production.
