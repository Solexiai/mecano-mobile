# CHECKPOINT MOVI-K — 1.3M-I — R-K-03-C

Date : 9 octobre 2026, America/Toronto.
**Intervention autorisée terminée. R-K-03-C : CORRIGÉ ET TESTÉ LOCALEMENT — VALIDATION PARTIELLE — NON FERMÉ — NON DÉPLOYÉ.**

## 1. Reprise et intégrité Git

- Dépôt visé : Solexiai/mecano-mobile.
- Worktree travaillé exclusivement : `C:\Users\Utilisateur\movik-gps-history-fix-20261009`.
- Branche initiale/finale : `fix/gps-client-history-scope-20261009`.
- HEAD initial/final : `7a0d60f5d556001705460f005ed8c7d1f268460d`.
- Checkpoint de reprise lu : `docs/audit/CHECKPOINT_GPS_AB_CLOTURE_20261009.md`.
- À l’arrivée : aucun changement suivi, index vide ; nombreux dossiers/fichiers de preuves non suivis préexistants.
- 2 363 fichiers suivis ou non suivis préexistants recensés par empreinte. Contrôle final : aucun fichier manquant, aucune modification inattendue, seuls les sept fichiers autorisés ci-dessous ont changé ; deux nouveaux tests/helpers hors dossier de preuves.
- Index toujours vide ; aucun commit, push, merge, changement de branche ou déploiement.
- P1-M-01, R-K-03-A et R-K-03-B restent fermés dans leurs périmètres approuvés. Aucun fichier functions/ ni firestore.rules modifié. Aucun autre worktree modifié.
- Preuves : `git-initial.json`, `git-final-definitive.json`, `diff-final-definitive.patch`, `RESULTATS_DEFINITIFS.json`.

Dossier canonique de cette intervention :
`C:\Users\Utilisateur\movik-gps-history-fix-20261009\artifacts\corrections-1-3M-I-20261009-6a91c2de`

## 2. Qualification des risques et scénarios A–J

Ces résultats portent sur les vrais composants Flutter avec données fictives, pas sur des incidents observés en production.

| Scénario | Avant correction | Après correction / limite |
|---|---|---|
| A — Bon chauffeur, bonne mission | Déjà réussi | Marqueur réel du composant conservé, bonnes coordonnées |
| B — Autre chauffeur | Marqueur incompatible reproduit | Aucun marqueur, attente de signal |
| C — Autre mission, lien absent, contexte mission absent/vide | Marqueur trompeur reproduit | Marqueur rejeté ; aucun historique sans mission |
| D — A remplacée par B | Ancien marqueur retenu reproduit | Snapshot et trajet supprimés au changement ; B affichée à réception d’un point compatible |
| D — Lien B mais coordonnées antérieures à l’assignation | Reproduit sur CustomerTrackingScreen réel | Refus avant acceptedAt ; point postérieur accepté |
| E — Date absente, chaîne invalide, type numérique non pris en charge | Modèles fabriquaient DateTime.now(), six assertions en échec | Null conservé ; sérialisation courante null ; marqueur non présenté comme actuel |
| F — Date future | Marqueur affiché reproduit | Date postérieure à l’horloge locale écartée, aucune tolérance arbitraire |
| G — Position ancienne | Pas de date/qualification de dernière position connue | Date et heure visibles ; aucun statut automatique « périmée » avant décision du seuil |
| H — GPS absent | Déjà réussi | État d’attente conservé, aucun faux marqueur |
| I — Historique A/B | Filtre de mission et tri déjà réussis | Conservés ; points sans date/futurs rejetés après reproduction distincte |
| J — Nouveau chauffeur / flux incompatible | Ancien marqueur retenu ou nouveau point incompatible affiché | Données incompatibles supprimées, ancien flux sans effet sur nouvelle carte |

Confiance élevée sur ces assertions exécutées. La disparition de la polyline lors du changement d’identité est vérifiée après correction ; les tests initiaux s’arrêtaient à l’assertion de marqueur, donc aucune reproduction indépendante de chaque forme de cache historique n’est revendiquée.

Le contrôle de propriété client existe dans CustomerTrackingScreen et ses tests de non-régression. Le modèle historique n’a pas de driverId : le chauffeur est déterminé par le chemin du repository et son abonnement, complétés par les règles déjà validées ; aucun champ fictif n’a été inventé.

## 3. Corrections appliquées

1. **Dates honnêtes** : updatedAt et recordedAt deviennent nullable. Suppression des deux replis DateTime.now() à la désérialisation.
2. **Identité et mission** : LiveTrackingMap vérifie driverId, missionId et activeDeliveryId avant d’afficher le marqueur.
3. **Borne d’assignation existante** : les écrans client/chauffeur transmettent mission.acceptedAt. Une date de position antérieure est refusée. Les fonctions acceptDelivery/adminAssignDelivery écrivent déjà accepted_at et changent le lien actif sans nécessairement renouveler les coordonnées ; elles sont laissées intactes.
4. **Changement de contexte** : abonnements conservés pour une identité stable ; renouvelés si chauffeur, mission ou acceptedAt changent. Clés de snapshots/carte fondées sur cette identité, recentrage réinitialisé, callback ancien neutralisé.
5. **Historique** : filtre défensif de mission, exclusion des dates inconnues/futures/antérieures à l’assignation connue, tri chronologique. La requête Firestore filtrée P1-M-01 n’est pas modifiée.
6. **Présentation prudente** : « Dernière position connue » en FR/EN/ES avec date locale numérique jour/mois/année et heure. Une ancienne position compatible peut rester visible avec cette qualification ; aucun délai de péremption n’a été choisi ou activé.

Composants principaux : `live_tracking_map.dart` (_bindStreams, _usableDate, _compatibleLocation, _routePoints, _lastKnownLabel), modèles DriverLocation/DriverLocationHistoryPoint et deux appels LiveTrackingMap des écrans consommateurs.

## 4. Tests avant/après et historique des échecs

| Exécution | Réussis | Échoués | Ignorés |
|---|---:|---:|---:|
| Sonde d’isolation initiale | 1 | 0 | 0 |
| Avant correction, premier ensemble (22 cas) | 4 | 18 | 0 |
| Avant correction, historique sans date/futur supplémentaire | 0 | 1 | 0 |
| Après premier correctif (23 cas) | 23 | 0 | 0 |
| Non-régressions consommateurs/repository/reporter | 37 | 0 | 0 |
| Test de présentation numérique ajouté avant ajustement | 0 | 1 | 0 |
| Après ajustement de présentation (24 cas) | 24 | 0 | 0 |
| Régression intermédiaire détectée : heure du filtre historique | 0 | 1 | 0 |
| **Suite ciblée définitive (25 cas)** | **25** | **0** | **0** |
| Contrat repository/carte/consommateurs rejoué après dernier ajustement | 7 | 0 | 0 |

**Bilan : 62 cas distincts réussis, aucun échec final, aucun ignoré.**
25 ciblés + 37 non-régressions. Les répétitions des sept tests de contrat, les passages intermédiaires, les sondes répétées et les chargements/tearDownAll ne sont pas additionnés.

Les 19 échecs du code de départ sont les 18 du premier ensemble plus le test historique supplémentaire. Les deux échecs de présentation/horloge concernent des versions intermédiaires de cette intervention et ne sont pas attribués rétrospectivement au commit initial.

Régression intermédiaire corrigée : le filtre historique utilisait l’heure capturée par le précédent rendu de position. Un point reçu ensuite pouvait être refusé comme futur. Le test attendait une PolylineLayer mais n’en trouvait aucune. Le filtre utilise maintenant l’heure du rendu de l’événement historique. Cas ajouté et réussi, puis contrat rejoué.

Preuves :
- `RESULT-before.jsonl`, `RESULT-before-history.jsonl`.
- `RESULT-after.jsonl`, `RESULT-before-label.jsonl`, `RESULT-final.jsonl`.
- `RESULT-before-history-clock.jsonl`, `RESULT-definitive.jsonl`.
- `RESULT-regression.jsonl`, `RESULT-contract-definitive.jsonl`.
- Résumés homonymes `.summary.json` ; agrégat `RESULTATS_DEFINITIFS.json`.

Deux scripts préparatoires ont échoué avant application complète : ReferenceError widget (interpolation JavaScript), puis cible multiline absente à cause des fins de ligne CRLF. Les versions v1/v2 sont conservées ; v3 a appliqué les changements. Ce ne sont pas des tests Flutter ni des défauts de production. Le premier comptage documentaire non borné incluait deux lignes d’annexes historiques ; le compteur canonique a été réconcilié sur le seul tableau actif (27 fiches). Preuve erronée conservée sous `registry-counts-unscoped.json`, résultat corrigé dans `registry-counts.json`.

## 5. Non-régression A/B et P1-M-01

Les 37 cas comprennent :
- 8 contrôles contrat/isolation : vrai FirebaseLocationRepository avec spies SDK, filtre where avant snapshots, garde mission nulle/vide, tri/filtre, vrais consommateurs client et chauffeur.
- 2 contrôles authentification client.
- 3 contrôles propriété client, y compris mission d’un autre client.
- 6 contrôles cycle GPS chauffeur et arrêt sur terminaison/démontage.
- 9 contrôles statuts et actions chauffeur.
- 9 contrôles DriverLocationReporter avec Geolocator et repository simulés.

Après la dernière modification, les 7 contrôles fonctionnels du contrat sont rejoués et réussis.
Aucune preuve nouvelle ne rouvre A/B/P1-M-01. Leurs fonctions/règles/tests serveur sont inchangés par empreinte. Les permissions et courses Firestore restent couvertes par les preuves historiques approuvées ; aucun nouveau test serveur ou émulateur n’est revendiqué ici.

## 6. Isolation

Méthode de 1.3M-C réutilisée :
- Vrai LiveTrackingMap / FlutterMap ; repositories et Auth fictifs.
- MemoryOnlyClient retourne uniquement le PNG mémoire embarqué pour les chemins de tuiles attendus ; aucune délégation réseau.
- `--dart-define=no_default_http_client=true` interdit le client HTTP de repli.
- HttpOverrides refuse aussi dart:io HttpClient. Sonde exécutée avant les cartes.
- Tentative de transport inattendue : exception et échec de suite, pas repli réseau.
- Suite définitive : 732 chargements mémoire, zéro demande inattendue ; non-régressions : 192 chargements mémoire ; contrat rejoué : 120. Ces nombres ne sont pas des appels OpenStreetMap.
- BackendBootstrap non configuré dans les nouveaux tests ; FirebaseAuthProvider fictif ; Geolocator simulé pour le chauffeur ; aucun bootstrap Firebase, émulateur, compte ou mission réelle.
- Aucun Stripe, Google Maps/Routes, GPS physique ou notification réelle.

Cette garantie concerne les chemins inspectés et exécutés. **Ce n’est pas un confinement réseau OS de tous les processus** : 1.3L reste BLOQUÉ ET REPORTÉ. Aucun changement Windows.

## 7. Qualité et présentation

- Analyse Flutter ciblée de onze fichiers : aucune anomalie, sortie 0 (`analyze.log`).
- Analyse finale des deux fichiers retouchés : aucune anomalie, sortie 0 (`analyze-definitive.log`).
- `git diff --check` : sortie 0.
- La nouvelle date reprend une convention numérique du suivi existant : main.dart ne configure pas les delegates Material, donc le format Material pouvait introduire un mois anglais sous le libellé FR. Le test de régression échoué puis réussi reste dans les preuves.
- Contrôle widget à 200 % : FR 375×932, EN 430×932, ES 1440×932, date/heure exactes présentes, absence d’exception Flutter. Il ne s’agit pas d’un audit complet de tous les croisements langue/format.
- Aucune capture PNG créée ; aucune inspection Chrome ni validation visuelle d’un fond réel revendiquée. Les assertions portent sur les vrais widgets/marqueurs/polylines avec tuiles mémoire.

## 8. Commandes exécutées et reproductibilité

SDK local utilisé :
`C:\Users\Utilisateur\mecano-mobile\.flutter\bin\flutter.bat`.
Aucun pub get, téléchargement ni installation.

Commande de base :
```powershell
flutter.bat --no-version-check test --no-pub --dart-define=no_default_http_client=true --reporter=json --concurrency=1 test/customer/live_tracking_identity_test.dart
```

Les scripts exacts avec répertoire, variables de processus et destinations de journaux sont dans :
- `run-tests.ps1` (phases isolation, before, before-history, after, before-label, final, before-history-clock, definitive ; --plain-name utilisé pour les contrôles seuls).
- `run-regression.ps1` (six suites existantes, sans sélection cachant des échecs).
- `analyze.ps1`, `analyze-final.ps1`, `finish-validation.ps1`.
- `snapshot.cjs`, `summarize.cjs`, `verify-definitive.cjs`.

Le harnais existant se trouve sous `artifacts/corrections-1-3M-C-20261009-1158/test/`. Aucun de ces anciens tests ni leurs assertions n’a été modifié.

## 9. Seuil de fraîcheur — décision encore requise

**Proposition : 60 secondes sans position plus récente. Non activée.**

Fondement vérifiable : DriverLocationReporter utilise une période nominale de huit secondes (lib/services/driver_location_reporter.dart). 60 / 8 = 7,5 périodes. Ce délai laisserait passer plusieurs interruptions courtes avant d’avertir ; c’est une proposition de compromis, pas une mesure terrain ni une garantie de précision.

Comportement proposé à approuver : au-delà de 60 secondes, retirer le marqueur actif et afficher « Position non actualisée » avec la date de la dernière position connue ; conserver le trajet historique identifié. Une future correction devra tester le passage du temps sans événement, le rétablissement, l’horloge et le démontage du temporisateur.

Aujourd’hui : date affichée honnêtement, identités et bornes temporelles vérifiées, mais **aucun classement automatique « périmée » ni temporisateur d’obsolescence**.

## 10. Limites et risques résiduels

- acceptedAt absent sur une mission ancienne : impossible de démontrer la borne d’assignation. Le contrôle d’identité/mission reste présent, aucune date n’est inventée.
- updated_at/recorded_at sont des heures d’enregistrement serveur dans recordTrackingPoint ; elles ne prouvent pas l’instant physique de mesure GPS.
- Date future : rejet conservateur dès qu’elle dépasse l’horloge locale. Une désynchronisation de l’appareil peut masquer un point serveur valide ; aucune tolérance métier arbitraire n’a été introduite.
- La reprise du cache natif Firestore, le fonctionnement déployé, Chrome, GPS physique et les interruptions réseau réelles restent NON TESTÉS.
- P2-K-01 reste ouvert : erreurs de flux non différenciées explicitement.
- R-K-04 (centre Montréal), 1.3L, toutes les autres anomalies/prérequis restent ouverts selon leur statut.
- Aucun calcul tarifaire, commission, paiement, snapshot ou ledger modifié/testé dans cette étape.

## 11. Registre et statut

Registre unique : `docs/audit/REGISTRE_BOGUES_MOVIK.md`.
Historique précédent conservé, addendum I et complément final ajoutés, aucune fermeture.

- P0 ouverts : **0**
- P1 ouverts : **3** — R-K-03-C, P1-HOME-001, P1-COPY-001
- P2 ouverts : **21**
- 27 fiches actives au tableau, 3 fermées dans leurs périmètres limités, 24 non fermées.
- P3 historiques, gaps et prérequis de lancement conservés.

Statut R-K-03-C : **CORRIGÉ ET TESTÉ LOCALEMENT — VALIDATION PARTIELLE — NON FERMÉ — NON DÉPLOYÉ**.
Identité, lien, date inconnue/future et renouvellement des snapshots sont corrigés dans les scénarios simulés. La décision d’obsolescence et ses tests restent à compléter ; fermeture documentaire séparée indispensable.

## 12. Liste exacte des fichiers modifiés

Racine commune : `C:\Users\Utilisateur\movik-gps-history-fix-20261009\`.

Modifiés :
1. `lib/backend/models/driver_location.dart`
2. `lib/backend/models/driver_location_history_point.dart`
3. `lib/widgets/live_tracking_map.dart`
4. `lib/screens/customer/customer_tracking_screen.dart`
5. `lib/screens/driver/driver_active_mission_screen.dart`
6. `lib/l10n/app_strings.dart`
7. `docs/audit/REGISTRE_BOGUES_MOVIK.md`

Nouveaux :
8. `test/customer/live_tracking_identity_test.dart`
9. `test/helpers/gps_offline_transport.dart`

Preuves nouvelles exclusivement dans `artifacts/corrections-1-3M-I-20261009-6a91c2de/`.
Diff et empreintes dans `diff-final-definitive.patch` / `git-final-definitive.json`. Aucun fichier préexistant supprimé. Aucun ajout à l’index.

## 13. Prochaine action unique

**Décider du seuil proposé de 60 secondes et du comportement « Position non actualisée » décrit ci-dessus.**

Aucune implémentation de ce seuil, fermeture documentaire, sauvegarde Git ou autre correction ne sera engagée dans cette intervention. Arrêt au présent checkpoint.
