# CHECKPOINT CORRECTIONS MOVI-K — P1-M-01 ET REGISTRE MAÎTRE

Date : 9 octobre 2026, America/Toronto. Intervention commencée vers11h10 ; validations finales vers11h31.
Étape : 1.3M-B uniquement.
**VERDICT : registre consolidé ; permissions P1-M-01 VALIDÉES EN ÉMULATEUR. Correction TESTÉE, validation globale PARTIELLE, NON FERMÉE.**
Aucune nouvelle correction métier. Aucun commit, push, merge, changement de branche ni déploiement.

## 1. Reprise et état Git

Rapports lus avant actions :
- C:\Users\Utilisateur\mecano-mobile\artifacts\gps-history-P1-M-01-fix-20261009\CHECKPOINT_CORRECTIF_P1_M_01.md
- C:\Users\Utilisateur\mecano-mobile\artifacts\audit-1-3M-20261009-db5485cc\CHECKPOINT_PHASE1_1_3M.md

| Worktree | Branche initiale/finale | HEAD initial/final | Intégrité |
|---|---|---|---|
| C:\Users\Utilisateur\movik-gps-history-fix-20261009 | fix/gps-client-history-scope-20261009 | 77c3c61534d1300ddc0eab5585f78b9662a69537 | 8 modifications préexistantes préservées byte pour byte (SHA256) ; nouveau docs/audit et dossier preuves |
| C:\Users\Utilisateur\movik-live-release-dd85a60 | release/live-backend-granby-20261006 | 77c3c61534d1300ddc0eab5585f78b9662a69537 | Propre avant/après, état inchangé |
| C:\Users\Utilisateur\mecano-mobile | feature/homepage-reference-20260929 | 91b5fd3249608174be7f9140feb8752deff04866 | État et empreintes suivies inchangés |

Dépôt principal conservé :
~~~text
 M .gitignore
?? artifacts/
?? storage.cors.local-backup.json
?? test/driver/driver_status_screen_test.dart.pre-modernisation.bak
~~~

Worktree de correction avant/après : les8 fichiers suivants restent modifiés, mêmes empreintes :
- functions/test/integration/securityRules.test.ts
- lib/backend/repositories/firebase_location_repository.dart
- lib/backend/repositories/location_repository.dart
- lib/widgets/live_tracking_map.dart
- test/driver/driver_active_mission_gps_lifecycle_test.dart
- test/driver/driver_active_mission_status_gaps_test.dart
- test/driver/driver_location_reporter_test.dart
- test/responsive/bloc_u_mobile_sanity_test.dart

Seuls ajouts de cette intervention :
- docs/audit/REGISTRE_BOGUES_MOVIK.md
- artifacts/corrections-1-3M-B-20261009-1110/ : rapports, snapshots, scripts temporaires, résultats/logs et caches de ce test.

git diff --check : sortie0 à la reprise et à la fin. Aucun diff firestore.rules, pubspec.lock ou functions/package-lock.json.
Les dépendances du worktree release sont lues uniquement ; les écritures/caches de l'essai se trouvent dans le worktree de correction.
Pas de GitHub/main/deploiement live revérifié : ce checkpoint traite les fichiers locaux de ces worktrees, pas la production.

## 2. Registre central durable

Emplacement :
C:\Users\Utilisateur\movik-gps-history-fix-20261009\docs\audit\REGISTRE_BOGUES_MOVIK.md

Aucun registre maître à ce chemin n'existait lors de la vérification ; création neuve. Les registres antérieurs ne sont ni écrasés ni remplacés.
Cycle permanent : IDENTIFIÉ → QUALIFIÉ → CORRECTION CODÉE → TESTÉ → VALIDÉ → FERMÉ.
Les nouvelles transitions et résultats sont datés dans un addendum ; tableau P1-M-01 actualisé.
Aucun ticket nouvellement FERMÉ.

Sources : checkpoints locaux Phase1 disponibles (inventaire/snapshot sous checkpoints-origines.json), PHASE7_BUG_REPORT, PHASE7_QA_MATRIX, PILOT_READINESS, PUBLIC_REVIEW_20261006, code/tests concernés.
Les documents historiques sont conservés littéralement en annexes, avec index d'IDs ; leurs CORRIGÉ/FERMÉ et totaux verts sont des citations historiques, pas des validations actuelles.

Limite de durabilité : fichier conservé localement dans le worktree Git ; non committé et non poussé conformément à l'interdiction. Il devra accompagner les prochaines transmissions ; sa synchronisation Git attend une autorisation. Aucune garantie que des rapports/conversations inaccessibles aient été recensés.

### Décompte actif non fermé

| Priorité | Nombre | Qualification |
|---|---:|---|
| P0 | 0 | Aucun P0 actif confirmé par les sources de cet audit ; ne prouve pas absence globale/production |
| P1 | 6 | P1-M-01 testé partiellement ; R-K-03-A/B/C (3 risques qualifiés/provisoires) ; P1-HOME-001/P1-COPY-001 corrigés et validés visuellement historiquement, clôture nouvelle règle à revoir |
| P2 | 21 | Bugs UX, risques, avertissement build, dettes et gaps de couverture/décision, distingués dans chaque fiche |

IDs P2 comptés :
P2-H-01/H-02/I-01/I-02/J-01/K-01 ; R-K-04 ; P2-FORM-001/002/003/004 ; P2-G-02 ; P2-I18N-001/002 ; P2-BUILD-001 ; P2-COPY-001 ; P2-L-01 ; GAP-M-05/M-06/S-02/S-04.

R-K-02 = alias P1-M-01, pas second ticket ; R-K-03 parent, pas quatrième risque ; P2-G-01 relié à P2-FORM-001 sans double décompte.
Le décompte inclut3 tickets déjà validés visuellement sur release, mais non déclarés FERMÉS sous la règle actuelle. Ils ne doivent pas être recodés arbitrairement.
Archives Phase7 corrigées/testées rapportées restent séparées : BUG-001..010, BUG-L6-01, BUG-M-01..04, BUG-N-01/02, BUG-O-01, BUG-U-01..03, BUG-V-01, BUG-X-01, BUG-AB-08-01/09-01/09-02, GAP-R-01/02, K2-3, GAP-U-MECHANIC. Les occurrences BUG-003 client/chauffeur/mécanicien restent liées.
BUG-004 conserve sa priorité P0 historique et son correctif rapporté ; il n'est ni nouvellement fermé ni réouvert sans preuve. BUG-L2-01 et BUG-L3-01 P3 reportés sont préservés avec les autres dettes/vigilances P-6/P-7/index/anti-abus/reconciliation.
Les anciennes affirmations Phase7 « aucun consommateur GPS stale » ou « push absent » ne font pas foi pour la release : les audits récents et registre8A–8L qualifient ces constats.
Signal profil chauffeur legacy6401cb2 conservé comme historique non revérifié dans cette intervention.

## 3. Correctif P1-M-01 revérifié

Comparaison des8 fichiers et recherche de tous les appels watchDriverLocationHistory :
1. Contrat exige String missionId nommé et obligatoire.
2. FirebaseLocationRepository applique where('delivery_id', isEqualTo: missionId) AVANT snapshots().
3. LiveTrackingMap ne demande pas l'historique si widget.missionId est null ou vide ; flux vide local.
4. _routePoints conserve filtre mission et tri chronologique défensifs.
5. Quatre repositories fictifs de tests adaptés ; NotConfiguredLocationRepository également compatible.
6. firestore.rules inchangé : aucune autorisation élargie.
7. Analyse des7 Dart modifiés sans anomalie ; reporter chauffeur simulé9/9.

La signature obligatoire ne refuse pas toute chaîne invalide à tous les appelants : la garde null/vide examinée est celle de la carte. Ne pas surinterpréter.
Compatibilité de compilation démontrée pour les fichiers ciblés, pas validation complète des écrans chauffeurs actifs ou de l'affichage des tuiles.
Aucun calcul client de prix, moteur tarifaire, commission, snapshot ou traitement Stripe changé.

## 4. Isolation du test Firestore

Conditions réellement utilisées :
- Projet demo-movik-test codé dans le setup, paramètres Java single_project_mode et single_project_mode_error.
- Firestore uniquement : Java/JAR local déjà en cache, écoute127.0.0.1:8080 ; canaux127.0.0.1:8081/8082.
- Pas de Firebase CLI exécutée : pas de découverte cloud, téléchargement automatique ni lancement des scripts serve/test:integration/deploy.
- Auth, Storage, Functions NON démarrés. Aucun trigger/callable métier importé/exécuté.
- Test ciblé importe rules-unit-testing, firebase/firestore et setup local ; aucun module Admin/Stripe/Routes/SecretManager/app serveur.
- Garde testUtils/emulatorSafety existante réutilisée : demo explicite, endpoints loopback cohérents, rejet des clés LIVE.
- Variables de projet process-local explicites ; variables de credentials/Stripe/Maps retirées du processus test sans lire/exposer leur contenu.
- Données hist_customer_A/B, hist_driver_scope, supp_client_A/B/supp_driver et coordonnées fictives. Aucun compte, mission métier ou paiement réel.
- Garde Node complémentaire refuse les sockets hors loopback8080, DNS non local et processus enfants. Sonde198.51.100.1:443 bloquée AVANT connexion ; journaux conservés.
- Les BLOCKED_CHILD execFile observés dans Jest sont des refus de processus enfants ; ils n'ont pas été contournés.
- Aucune carte ni tile OpenStreetMap, notification, GPS physique ou Google utilisé.

Ce mécanisme n'est PAS un confinement réseau OS complet. Il ne valide pas1.3L et ne permet pas de reprendre les tuiles sur cette seule preuve. La sécurité de cet essai découle aussi des seuls modules exécutés et du projet/endpoint explicitement locaux, pas simplement de « zéro requête observée ».
Ports inspectés disponibles avant lancement. L'émulateur créé pour cette intervention a été arrêté après validation ; aucun service préexistant arrêté.

### Harnais temporaire

Worktree de correction sans modification des8 fichiers :
- prepare-rules-only*.cjs : transpilation locale TypeScript→CommonJS du test existant ; règles lues depuis worktree fix ; chemin relocalisé dans le seul setup temporaire.
- supplemental*.ts :2 tests additionnels (rôles/collections et listeners).
- rules-only-v3/ : version finale assemblée avant transpilation pour conserver les imports partagés.
- jest.rules-only-v3.cjs : Node, runInBand, setupSafety dédié, moduleDirectories standard + modulePaths fallback ; pas setupRouteMock (import calculateRoute inutile exclu).
- deny-external-node.cjs : garde complémentaire documentée.

Aucune assertion du test TypeScript existant supprimée/modifiée. Il a été exécuté après transpilation, ce n'est plus une simple vérification syntaxique. Pas de nouvelle analyse TypeScript complète des types revendiquée.
Les2 tests temporaires supplémentaires complètent sans affaiblir le scénario existant.
La garde du listener v3 ignore les snapshots fromCache pour attendre le verdict serveur, avec includeMetadataChanges:true. Les assertions sur l'ID propre et permission-denied restent. Cette adaptation ne corrige pas le cache du produit et ne ferme pas R-K-03-C.

## 5. Commandes et résultats réels

Commandes exactes/process-env : commandes-validation.txt ; scripts de préparation et configs conservés.
Commandes principales :
~~~powershell
flutter analyze --no-pub <les 7 fichiers Dart modifiés>
flutter test --no-pub test/driver/driver_location_reporter_test.dart --reporter expanded
node prepare-rules-only-v3.cjs
java '-Duser.language=en' '-Duser.country=US' -jar <JAR local> --host 127.0.0.1 --port 8080 --webchannel_port 8081 --websocket_port 8082 --project_id demo-movik-test --single_project_mode true --single_project_mode_error true --rules <worktree correction>/firestore.rules
node -r deny-external-node.cjs <Jest local>/bin/jest.js --config jest.rules-only-v3.cjs --runInBand --testNamePattern P1-M-01 --json --outputFile rules-results-fifth.json
~~~
Chemins complets et variables d'environnement dans commandes-validation.txt ; aucun secret.

| Nouvelle exécution | Réussis | Échoués | Ignorés | Résultat |
|---|---:|---:|---:|---|
| Flutter analyse ciblée | n/a | n/a | n/a | No issues found, sortie0 |
| Flutter reporter | 9 | 0 | 0 | All tests passed, sortie0 |
| Firestore essai1 | 0 | 3 | 197 | Échec initialisation, locale fr_CA |
| Firestore essai2 | 0 | 3 | 197 | Java non lancé / ECONNREFUSED |
| Firestore essai3 | 0 | 3 | 197 | Résolution modules temporaire + portée test ajouté |
| Firestore essai4 | 2 | 1 | 197 | Requêtes/rôles OK ; cache listener pris pour verdict serveur |
| Firestore essai5 FINAL | 3 | 0 | 197 | Suite ciblée PASS, success=true |

Ne pas additionner ces réexécutions. Les197 tests ignorés sont les autres cas de la suite exclus par filtre. Ils ne sont pas validés ici.
Résultats historiques distincts : ancien analyse0/reporter9/9/transpilationTS propre dans rapport de correction ; 1.3M avait0 test. Leur historique reste intact.

### Erreurs conservées et qualification

1. Java : MissingResourceException, "Can't find bundle for base name com.google.firebase.rules.validations.JValidationMessages_messages, locale fr_CA". HTTP500UNKNOWN lors loadFirestoreRules ; assertions pas atteintes ; clearFirestore/cleanup undefined secondaires.
   Relance avec locale anglaise process-local ; aucun changement Windows.
2. Mauvaise citation PowerShell de -Duser.language=en : "impossible de trouver ou de charger la classe principale .language=en", ClassNotFoundException /language=en ; essai Jest lancé trop tôt, ECONNREFUSED127.0.0.1:8080. Erreur de mon orchestration, pas bug Movi-K ; toutes preuves conservées, readiness ensuite vérifiée avant relance.
3. Harnais temporaire : util$1.isCloudWorkstation is not a function.
   FirebaseFirestore4.17/compat0.4.12 demandent util1.15.2, mais config Jest choisissait util1.10.0 racine. Lecture Node normale trouve nested util1.15.2 avec fonction présente. Pas besoin d'installation : corriger configuration temporaire, ne pas déclarer les dépendances du produit cassées.
   Autre erreur de ma préparation : setDoc is not defined, tests additionnels compilés séparément des imports. Corrigée dans nouvelle copie temporaire par compilation commune.
4. Listener : "Received promise resolved instead of rejected" au test non filtré. Première émission de cache ne constitue pas verdict de permissions. Test v3 attend réponse serveur ou erreur et conserve contrôle strict.

Les erreurs de harnais/commande ne deviennent pas des P0/P1 produit. Aucun échec transformé rétroactivement en succès. Tous journaux et JSON distincts préservés.

## 6. Permissions effectivement démontrées

| Contrôle final | Résultat |
|---|---|
| A getDoc point propre A | Autorisé |
| A getDoc point B | Refusé |
| A getDocs collection sans filtre | Refusé |
| A query where delivery_id=A | Autorisé,2 points, IDs mission conformes |
| A query where delivery_id=B | Refusé |
| B query where delivery_id=B | Autorisé,1 point |
| Chauffeur propriétaire collection complète | Autorisé,3 points |
| Analyst/admin/super_admin collection | Autorisé dans fixture supplémentaire |
| Autre chauffeur/anonyme collection | Refusé |
| Listener A filtré propre mission, réponse serveur | Autorisé, point A1 |
| Listener A filtré autre mission | permission-denied |
| Listener A sans filtre, verdict serveur | permission-denied |

Preuves : rules-results-fifth.json et rules-tests-fifth.log ; règles inchangées ; firestore-emulator-fourth.log ; scripts V3.
Les refus attendus sont des réussites d'assertion, pas des échecs de l'application.
Cela prouve les règles locales au HEAD77c3c615 et les fixtures examinées ; pas les règles déployées ni l'application live.

## 7. Limites, bogues conservés et ordre

P1-M-01 a franchi la preuve de permission manquante ; reste NON FERMÉ par prudence de périmètre :
- garde missionId null/vide et filtrage défensif examinés dans le code mais pas testés au rendu ;
- écrans de mission chauffeur/consommateurs de carte : compilation ciblée + reporter, pas non-régression visuelle complète ;
- build Web complet, rendu Chrome, tuiles/carte active, dispositifs/GPS réel et règles live NON TESTÉS.
La partie permissions n'est plus BLOQUÉE. Ne pas confondre la validation partielle locale avec validation produit complète.

R-K-03-A/B/C et R-K-04 conservés, pas de fuite réelle ni concurrence reproduite.
P2-H-01/H-02/I-01/I-02/J-01/K-01 tous ouverts ; les anciens P2 formulaire/i18n/performance/contraste/décision ne disparaissent plus.
1.3L BLOQUÉ ET REPORTÉ, un test de tuile non validé. Aucun travail Windows repris.
Contact officiel/QR et preuves Stripe/règles déployées/pilote restent des prérequis externes, pas inventés comme nouveaux bugs.
Aucune validation financière : devis officiel = mission = snapshot financier = montant Stripe en cents NON TESTÉ dans cette intervention ; aucun montant/règle financière modifié.

Ordre proposé, sans exécution :
1. Finaliser les preuves de contrat/guard et consommateurs P1-M-01 avant clôture.
2. R-K-03-A (autorité/lifecycle/accès), puis B (atomicité), puis C (association/fraîcheur approuvée).
3. P2-K-01 ; coordonnées H ; carte/date I ; référence/statut J.
4. Localisation/contraintes/formats/badges/build, dettes M/S avec politique suspension.
5. Recette E2E approuvée et vérifications externes, sans recoder les correctifs historiques déjà présents.
Aucun P0 actif nouvellement identifié ; les archives financières requièrent leur revue dédiée avant un GO global.

## 8. Preuves et arrêt

Dossier :
C:\Users\Utilisateur\movik-gps-history-fix-20261009\artifacts\corrections-1-3M-B-20261009-1110

Documents principaux :
- docs/audit/REGISTRE_BOGUES_MOVIK.md : registre canonique local, tableau/fiches/cycle/addendum/index/annexes historiques.
- CHECKPOINT_CORRECTIONS_MOVIK_P1_M_01_REGISTRE.md
- git-initial.json, git-final-definitif.json, git-comparison-definitif.json, diff-initial.patch
- checkpoints-origines.json et4 copies des sources documentaires historiques
- commandes-validation.txt, scripts/configs/versions temporaires
- flutter-analyze.log, flutter-reporter.log
- rules-results*.json/rules-tests*.log (essais conservés séparément)
- firestore-emulator*.log, network-node.jsonl, emulator-final-stop.json

Vérification Git finale : mêmes branches/HEAD/empreintes des8 modifications ; release et dépôt principal identiques avant/après. Les seuls nouveaux statuts du fix sont docs/audit/ et nouveau dossier artifacts. Les écritures finales de rapports ne touchent pas les fichiers suivis.
Aucune installation, configuration Windows, activation Sandbox, connexion aux données production, transaction réelle, commit, push, merge ni déploiement.
Les historiques ne sont pas écrasés.

**Prochaine action unique recommandée : préparer une validation Flutter ciblée du contrat d'historique et de la garde missionId, sans chargement de tuiles, avant décider la fermeture de P1-M-01.** Si cette isolation ne peut être garantie, rester NON FERMÉ et préparer R-K-03-A seulement après nouvelle autorisation.

**ARRÊT APRÈS 1.3M-B. Aucun1.3N ni correction suivante commencée.**
