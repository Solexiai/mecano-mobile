# CHECKPOINT CORRECTIONS MOVI-K — ÉTAPE 1.3M-C

Date : 9 octobre 2026, America/Toronto.
**VERDICT : TERMINÉ dans le périmètre autorisé.**
**P1-M-01 : VALIDÉ — FERMETURE PROPOSÉE pour la requête d'historique et ses consommateurs simulés.**
Aucune fermeture globale GPS, aucune validation de production. Aucun autre correctif commencé.

## 1. Version et état Git

- Dépôt : Solexiai/mecano-mobile.
- Worktree travaillé : C:\Users\Utilisateur\movik-gps-history-fix-20261009
- Branche initiale et finale : fix/gps-client-history-scope-20261009.
- HEAD initial et final : 77c3c61534d1300ddc0eab5585f78b9662a69537.
- Le correctif est non commité. Les preuves s'appliquent au HEAD plus les huit fichiers modifiés existants, identifiés par SHA256, pas au seul commit de base.

État initial conservé, huit fichiers déjà modifiés :

    M functions/test/integration/securityRules.test.ts
    M lib/backend/repositories/firebase_location_repository.dart
    M lib/backend/repositories/location_repository.dart
    M lib/widgets/live_tracking_map.dart
    M test/driver/driver_active_mission_gps_lifecycle_test.dart
    M test/driver/driver_active_mission_status_gaps_test.dart
    M test/driver/driver_location_reporter_test.dart
    M test/responsive/bloc_u_mobile_sanity_test.dart
    ?? artifacts/corrections-1-3M-B-20261009-1110/
    ?? docs/audit/

État final : mêmes entrées, plus :

    ?? artifacts/corrections-1-3M-C-20261009-1158/

Le registre, déjà non suivi, a été actualisé. **Aucun des huit fichiers existants n'a changé.** Les quinze sources/lockfile/règles recensés sont également identiques avant/après. Continuité SHA256 des huit fichiers confirmée avec la fin de 1.3M-B.

La release reste propre sur release/live-backend-granby-20261006 au même HEAD. Le worktree principal reste sur feature/homepage-reference-20260929, HEAD 91b5fd3249608174be7f9140feb8752deff04866, avec son .gitignore modifié et ses trois entrées non suivies inchangées. Contrôlés en lecture seule ; aucune écriture dans ces worktrees.

Preuves : git-initial.json, git-final.json, git-comparison.json, source-hashes.json, source-comparison.json, continuity-1-3M-B.json, diff-initial.patch.

## 2. Contrat GPS réellement vérifié

| Contrôle | Résultat et niveau de preuve |
|---|---|
| missionId obligatoire | Signature required String dans LocationRepository:23–26, NotConfigured:41–44 et FirebaseLocationRepository:71–74. Quatre faux repositories compatibles ; recherche exhaustive des fichiers Dart suivis, aucune ancienne signature trouvée. |
| Filtre avant abonnement | Deux tests du vrai FirebaseLocationRepository avec spies stricts du SDK vérifient collection → doc chauffeur → history → where(delivery_id == missionId) → snapshots ; cas A et B, mapping contrôlé. Source:77–86. |
| missionId absent/vide | Deux widget tests montent le vrai LiveTrackingMap ; zéro appel à watchDriverLocationHistory, carte présente, aucune polyline. Source:96–106. |
| Bon identifiant transmis | Spy reçoit uniquement sim-driver/sim-A ; vrais écrans client et chauffeur montés, champs missionId/driverId et appels contrôlés. Sources customer_tracking_screen:215–220 et driver_active_mission_screen:652–657. |
| Filtre défensif et tri | Points A tardif, B, A ancien injectés ; la vraie PolylineLayer contient seulement A ancien puis A tardif. Source live_tracking_map:67–73. |
| Compatibilité client/chauffeur | Deux tests de passage d'identifiants + vingt tests existants : accès client, transitions chauffeur, arrêt du reporter, double-clic et démontage. |
| Aucun appel ancien oublié | contract-all-callsites.txt et callsites.txt ; quatre faux repositories, deux implémentations et un appel produit. Analyse ciblée du consommateur responsive et des écrans réussie. |

Il ne s'agit pas d'une réimplémentation de LiveTrackingMap par un faux widget. Le composant, sa polyline et les écrans réels sont utilisés. Les repositories de données, l'authentification et le transport d'images sont simulés.

## 3. Tests et analyses de cette intervention

| Exécution | Réussis | Échoués | Ignorés | Résultat |
|---|---:|---:|---:|---|
| Isolation, essai initial | 0 | 1 | 0 | Échec du harnais avant montage de carte : zone du client non héritée lors de l'exécution ; garde réseau refuse le repli. |
| Isolation, v2 | 0 | 0 | 0 | Une erreur de chargement/compilation du callback Future<void> ; aucun test exécuté. |
| Isolation, v3 | 1 | 0 | 0 | Client mémoire sélectionné ; createClient et HttpClient refusés. |
| Contrat ciblé | 7 | 0 | 0 | Repository, garde null/vide, filtrage/tri, consommateurs client/chauffeur. |
| Suites consommateurs existantes | 20 | 0 | 0 | Lifecycle 6 ; statuts 9 ; propriété client 3 ; auth 2. |

**Exécutions finales : 28 contrôles distincts réussis, 0 échec, 0 ignoré.**
Les deux essais initiaux restent explicitement conservés et ne sont pas transformés en réussite. Les comptes excluent chargements et tearDownAll cachés du protocole Flutter. Les scénarios écartés par --name ne sont pas comptés comme exécutés.

- Analyse des deux écrans consommateurs et de test/responsive/bloc_u_mobile_sanity_test.dart : **No issues found**, sortie 0.
- Analyse initiale des nouveaux helpers sous artifacts : **14 avertissements**, sortie 1, aucun diagnostic error (5 annotations sealed des spies SDK, 9 usages visibleForTesting hors test/ racine). Aucun avertissement supprimé. Pas d'analyse sans avertissement revendiquée pour ces helpers. Les compilations/tests finaux ont réussi.
- Échec initial exact : « Bad state: no_default_http_client was defined but runWithClient was not used to configure a Client implementation. » gps_history_contract_test.dart:154, première version.
- Erreur v2 exacte : « A non-null value must be returned since the return type 'Future<void>' doesn't allow null. » ligne152 de la version v2.
- Corrections limitées au harnais : zone installée autour de chaque callback exécuté, puis callback de sonde rendu async. Versions antérieures sauvegardées. Aucun changement du comportement produit.
- Aucun nouveau bogue produit démontré.

Preuves complètes : isolation-test.jsonl, isolation-test-v2.jsonl, isolation-test-v3.jsonl, contract-tests.jsonl, consumer-tests.jsonl, test-results-summary.json, analyze-new-tests.log et analyze-consumers.log.

### Preuves antérieures conservées, non réexécutées

1.3M-B : trois tests finaux Firestore Emulator local réussis, 197 autres scénarios exclus ; analyse ciblée de sept fichiers Dart réussie ; neuf tests reporter réussis. Les anciennes tentatives échouées de cet épisode restent dans son dossier.

Les permissions précédentes couvrent réellement getDocs et onSnapshot : A lit A, A ne lit pas B, B lit B, collection non filtrée refusée pour A, chauffeur propriétaire et rôles admin autorisés, autre chauffeur/anonyme refusés. Le listener attend une réponse serveur, pas seulement le cache. Aucun nouveau test d'émulateur n'était nécessaire ici puisque règles et fichiers du correctif sont inchangés.

## 4. Commandes exécutées

Répertoire de travail : worktree de correction. Aucun pub get ni téléchargement.

    flutter.bat --no-version-check analyze --no-pub artifacts/corrections-1-3M-C-20261009-1158/test

Sonde exécutée trois fois, journaux distincts :

    flutter.bat --no-version-check test --no-pub --dart-define=no_default_http_client=true --reporter=json --plain-name "isolation: injected transport and forbidden network fallback" artifacts/corrections-1-3M-C-20261009-1158/test/gps_history_contract_test.dart

Contrat après réussite de la sonde :

    flutter.bat --no-version-check test --no-pub --dart-define=no_default_http_client=true --reporter=json --fail-fast --name "^real " artifacts/corrections-1-3M-C-20261009-1158/test/gps_history_contract_test.dart

Suites existantes : même commande test avec --fail-fast --concurrency=1 et les quatre copies isolated_* listées ci-dessous, sans filtre de nom.

    flutter.bat --no-version-check analyze --no-pub lib/screens/customer/customer_tracking_screen.dart lib/screens/driver/driver_active_mission_screen.dart test/responsive/bloc_u_mobile_sanity_test.dart

Le chemin du SDK réellement utilisé et les commandes PowerShell complètes avec redirections sont dans COMMANDES_TESTS.ps1.txt. GIT_OPTIONAL_LOCKS=0, CI=true et suppression d'analytique sont limités aux processus. Inspections : git branch --show-current, rev-parse HEAD, status --short --branch, diff, grep et Get-FileHash.

## 5. Garanties d'isolation et limites

Chaîne inspectée : TileLayer → NetworkTileProvider → RetryClient(Client()) → client mémoire du harnais. flutter_map 7.0.2 et http 1.5.0, sources et SHA256 conservés dans transport-sources.json.

Le client fictif n'a aucune délégation réseau, socket ou DNS. Il accepte seulement les clés de tuiles attendues et retourne le PNG transparent déjà embarqué dans la dépendance. --dart-define=no_default_http_client=true interdit le client réseau de repli ; HttpOverrides interdit aussi dart:io HttpClient. Le précontrôle le prouve avant le montage des cartes. Une demande imprévue fait échouer la suite. Ce n'est donc pas une conclusion fondée uniquement sur zéro requête observée.

Compteurs : 120 chargements traités en mémoire pour le contrat, puis 24/24/24/0 pour les quatre suites consommateurs ; aucune demande imprévue. Ces nombres ne désignent pas des requêtes vers OpenStreetMap.

Auth fictive backendConfigured=false ; overrides MissionRepository/LocationRepository ; faux Geolocator ; SDK-boundary spies pour le vrai FirebaseLocationRepository. Aucun bootstrap Firebase, compte réel, fonction serveur, notification, GPS physique, Stripe ou API cartographique réelle. Aucun émulateur démarré pendant 1.3M-C.

**1.3L demeure BLOQUÉ ET REPORTÉ.** Ces tests contrôlés ne constituent pas un confinement OS de Flutter et de ses processus enfants. Aucune capture de tuile, capture Chrome ou validation visuelle d'un vrai fond cartographique n'est produite ici.

Restent NON TESTÉS : GPS physique, Chrome/production, réseau cartographique réel, nouveau cycle Firebase Flutter natif → émulateur, fraîcheur/cache/association de la position courante, concurrence et autorité d'écriture. Le spy SDK prouve l'appel Dart, pas les permissions ; la preuve des permissions est celle de 1.3M-B.

Aucune validation financière dans cette étape : devis = mission = snapshot = cents Stripe n'a pas été retesté.

## 6. Décision sur P1-M-01

| Critère de fermeture | État |
|---|---|
| Correctif présent | OUI, huit fichiers identiques aux preuves de 1.3M-B |
| Analyse du code | OUI, ciblée antérieure + consommateurs nouvellement analysés |
| Permissions réelles en émulateur | OUI, historique traçable 1.3M-B, non répété |
| Contrat Flutter et garde missionId | OUI, tests du vrai repository et de la vraie carte |
| Non-régression des consommateurs | OUI dans le périmètre des vingt tests existants et des deux contrôles de passage d'identifiants |
| Absence de mélange d'historique intermission | OUI, filtre/tri Flutter + requêtes/rôles testés en émulateur |
| Validation globale GPS/terrain/production | NON ; hors de la fermeture du défaut précis P1-M-01 |

**Fermeture proposée du seul défaut de requête d'historique sans filtre serveur.**
Ce résultat ne ferme pas R-K-03-A/B/C, P2-K-01, R-K-04 ni 1.3L. Le rendu cartographique réel n'est pas une condition manquante indispensable pour ce défaut précis, puisque la garde, les arguments, la polyline et les consommateurs réels ont été exercés avec transport fictif.

Le registre passe de TESTÉ — VALIDATION PARTIELLE, NON FERMÉ à VALIDÉ — FERMETURE PROPOSÉE. La fermeture formelle n'est pas appliquée : la consigne demande une proposition de fermeture. Aucun bogue n'est effacé.

## 7. Registre et décompte

Registre canonique :
C:\Users\Utilisateur\movik-gps-history-fix-20261009\docs\audit\REGISTRE_BOGUES_MOVIK.md

Sauvegarde avant modification : REGISTRE_BOGUES_AVANT.md dans ce dossier. Transitions datées, statut antérieur conservé, preuves reliées. Annexes et tous les identifiants préservés.

Décompte recalculé à partir des 27 lignes du tableau actif :

- **P0 : 0** actif recensé, sans garantie globale de production.
- **P1 : 6** non fermés : P1-M-01 validé avec fermeture proposée ; R-K-03-A/B/C qualifiés ; P1-HOME-001 et P1-COPY-001 validés historiquement, non fermés.
- **P2 : 21** non fermés ; aucun retiré.
- Les archives/P3 restent conservés séparément, dont BUG-L2-01 et BUG-L3-01 ouverts historiquement.

Les P2 restants : P2-H-01, P2-H-02, P2-I-01, P2-I-02, P2-J-01, P2-K-01, R-K-04, P2-FORM-001/002/003/004, P2-G-02, P2-I18N-001/002, P2-BUILD-001, P2-COPY-001, P2-L-01, GAP-M-05/06, GAP-S-02/04.

Après acceptation de la fermeture ciblée proposée, P1 passerait de 6 à 5. Aucun compteur réduit prématurément. Preuve : registry-counts.json.

## 8. Fichiers créés ou actualisés

- Actualisé : docs/audit/REGISTRE_BOGUES_MOVIK.md.
- Nouveau dossier de preuves : artifacts/corrections-1-3M-C-20261009-1158/.
- Tests temporaires actifs : test/offline_transport.dart ; test/gps_history_contract_test.dart ; test/isolated_driver_lifecycle_test.dart ; test/isolated_driver_status_test.dart ; test/isolated_customer_ownership_test.dart ; test/isolated_customer_auth_test.dart, sous ce dossier uniquement.
- Les copies isolated_* conservent les corps et assertions des quatre originaux ; comparaison inverse vérifiée (existing-tests-copy-verification.json). Seuls imports/point d'entrée/enveloppe de transport sont ajoutés.
- Les quatre petits wrappers existing_* initiaux sont conservés comme préparation non exécutée ; les anciennes versions du harnais restent sauvegardées.
- Journaux, hashes, commandes, registre avant modification, règles de transport et présent checkpoint conservés dans le nouveau dossier.
- **Aucun code produit ni test original modifié ; aucun commit, push, merge ou déploiement.**

## 9. Prochaine action unique

**Traiter R-K-03-A : contrôle d'autorité du GPS et missions terminales, avec tests de permissions locaux ciblés, après nouvelle autorisation.**

Les dépendances suivantes restent B → C → P2-K-01 et anomalies client. Aucune commencée dans cette intervention. Arrêt après ce checkpoint.
