# CHECKPOINT MOVI-K — 1.3M-O
## SUIVI CLIENT — P2-J-01

**STATUT : TERMINÉ dans le périmètre simulé.** P2-J-01 : **FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ.**

Date effective : **11 octobre 2026, America/Toronto**. Le dossier conserve le préfixe 20261010 demandé. Ce checkpoint ne valide ni la production, ni Chrome, ni le GPS physique.

## 1. Reprise et protection Git

- Dépôt : Solexiai/mecano-mobile.
- Worktree exclusivement utilisé : `C:\Users\Utilisateur\movik-gps-history-fix-20261009`.
- Branche initiale et finale : `fix/gps-client-history-scope-20261009`.
- HEAD initial et final : `540352c98fa2e6132a0828069583c25f0802592c`.
- Sixième commit confirmé : `fix(booking): clarify card readiness and localize confirmation dates`.
- Index vide avant et après ; aucun commit, push, merge, changement de branche ou déploiement.
- Initialement, aucun changement de fichier suivi ; les nombreux artefacts non suivis préexistants ont été conservés.
- Empreintes de **2 677 fichiers initiaux** contrôlées : aucun fichier supprimé ; seuls les trois fichiers préexistants autorisés ci-dessous diffèrent. Aucune nouvelle entrée hors du dossier de preuves O et du nouveau test permanent.
- P2-I-01/I-02 fermés au départ ; aucun autre statut du tableau actif modifié.

Sources : `git-initial.json`, `git-final.json`, `final.diff`, `registry-counts.json` dans le dossier de preuves.

## 2. Défaut reproduit et source de la référence

Le code initial ne présentait pas la référence dans le suivi. Il regroupait la recherche, l’absence de chauffeur et les statuts non suivables sous le message générique `tracking_not_available`. La navigation déjà testée à 1.3J ne démontrait donc pas une présentation correcte.

La reproduction contre le code initial a donné **9 réussites, 50 échecs, 0 ignoré**. Ce sont des cas de test, pas 50 bogues distincts. Ils couvrent notamment la référence manquante, l’absence de statut explicite, les états inconnus et les changements de mission. Le test de mission incompatible utilise volontairement un faux repository incorrect : il prouve une protection Flutter manquante, pas une fuite démontrée en production.

Source de vérité constatée dans le code :

| Maillon | Source vérifiée |
|---|---|
| Identifiant retourné après création | `functions/src/functions/createDeliveryRequest.ts:413` renvoie `missionId: resolvedMissionId`. Fonction non modifiée/non appelée réellement. |
| Reçu et navigation | `delivery_request_flow_screen.dart:550,553,698,714` conserve le résultat, affiche la référence et construit la route de suivi. |
| Document suivi | `firebase_mission_repository.dart:126–129` lit le document demandé et construit `DeliveryMission.fromJson(missionId, ...)`. |
| Modèle | `delivery_mission.dart:32,142` : `id` provient de l’identifiant du document ; aucun autre numéro public n’est introduit. |
| Affichage corrigé | `customer_tracking_screen.dart:157,165,172,302` vérifie le client, la présence/concordance de l’identifiant puis affiche `DeliveryMission.id`. |

Le reçu conserve son comportement. **Aucun identifiant n’est fabriqué**, tronqué ou reconstruit depuis une autre mission. Si l’identifiant du modèle manque, la vue indique « Référence indisponible » sans carte. Si un modèle B est reçu pour la route A, ses informations ne sont pas affichées.

## 3. Statuts réellement disponibles et rendu

L’énumération `lib/models/enums.dart:323` contient : draft, quoted, searchingDriver, offered, assigned, driverToPickup, arrivedAtPickup, pickedUp, inTransit, arrivedAtDropoff, delivered, completed, cancelled, disputed, refunded.

| Données reçues | Présentation |
|---|---|
| Flux en attente | Indicateur de chargement, sans référence non vérifiée. |
| Mission absente | Message existant de mission introuvable. |
| Erreur du flux | Message d’erreur existant ; aucune exception brute ou ancienne référence présentée comme valide. |
| searchingDriver/offered, sans chauffeur | « Nous recherchons un chauffeur pour votre livraison. » Pas de carte ni de chauffeur inventé. |
| Statut actif mais chauffeur null/vide/espaces | Absence d’assignation indiquée explicitement. |
| Chauffeur valide, statut suivable | Identité et statut existants conservés ; référence ajoutée ; vrai composant GPS inchangé. |
| completed | Vue de mission terminée existante, référence ajoutée, sans carte active. |
| cancelled/delivered/disputed/refunded/quoted | Libellé existant du statut, référence et absence de carte active. |
| draft ou combinaison recherche + chauffeur incohérente | État du suivi indisponible ; aucune promesse d’assignation ou de recherche. |

**Limite connue conservée :** le modèle convertit tout statut brut non reconnu en `draft` (`enums.dart:350`), notamment `payment_failed`, qui ne figure pas dans cette enum Flutter. Les tests vérifient un message neutre dans ces cas ; aucune nouvelle machine à états ni correction serveur n’a été ajoutée.

## 4. Correction minimale et fichiers

1. `lib/screens/customer/customer_tracking_screen.dart`
   - Référence dans les vues recherche/absence, assignée et terminée.
   - Messages selon les données de mission, sans délai ou disponibilité inventés.
   - Contrôle défensif de concordance entre mission reçue et route.
   - Clé client+mission sur le StreamBuilder pour réinitialiser le snapshot lors du passage A→B.
   - Titre court « Suivi » / « Tracking » / « Seguimiento » et hauteur d’en-tête adaptée à l’agrandissement du texte. Les tests avaient démontré une troncature du titre précédent.
2. `lib/l10n/app_strings.dart`
   - Six clés FR/EN/ES ajoutées (titre, référence, référence indisponible, recherche, absence de chauffeur, état indisponible).
   - Les traductions préexistantes sont identiques, vérification automatique effectuée.
3. `test/customer/customer_tracking_presentation_test.dart`
   - Nouvelle suite permanente de 59 tests utilisant les vrais widgets et des services fictifs.
4. `docs/audit/REGISTRE_BOGUES_MOVIK.md`
   - Fermeture limitée de P2-J-01, historique et preuves conservés, décompte recalculé.

Le diff des fichiers suivis représente 173 insertions et 10 suppressions ; le nouveau test non suivi est à ajouter séparément lors d’un futur commit autorisé. Les règles Firestore, fonctions, modèles, repositories, composant GPS, formulaire, paiement, tarifs, commissions, snapshots et ledger n’ont pas été modifiés.

## 5. Tests exécutés — historique conservé

| Exécution | Réussis | Échoués | Ignorés | Preuve |
|---|---:|---:|---:|---|
| Code initial | 9 | 50 | 0 | before.jsonl |
| Première correction | 38 | 21 | 0 | after.jsonl |
| Suite ciblée finale | 59 | 0 | 0 | final.jsonl |
| Premier lanceur de non-régression | 16 | 3 | 0 | regression.jsonl |
| Non-régression finale | 19 | 0 | 0 | regression-final.jsonl |
| Fraîcheur GPS sélectionnée | 7 | 0 | 0 | gps-freshness.jsonl |
| Erreurs/reprise GPS sélectionnées | 8 | 0 | 0 | gps-errors.jsonl |

**Résultat final : 93 tests distincts réussis, 0 échec, 0 ignoré.** Les essais intermédiaires ne sont pas additionnés à ce total et restent dans les preuves.

Les 21 échecs intermédiaires se répartissaient en 18 contrôles de troncature du titre et 3 assertions du test de navigation faites avant la fin de transition des routes. L’en-tête a été corrigé ; le test attend désormais la fin de transition avant de compter la référence. Aucune assertion pertinente supprimée.

Les trois échecs du premier lanceur de non-régression étaient : le cas autorisé du client A et deux cas d’erreur/reprise du listener. Message exact :
`Bad state: no_default_http_client was defined but runWithClient was not used to configure a Client implementation.`
Le transport réseau par défaut a bien été refusé. Le harnais final applique le transport mémoire au corps de ces anciens tests, dans deux copies temporaires ; seul `testWidgets` devient `offlineWidgetTest`, avec son import. Le reste des sources et assertions est contrôlé identique dans `regression-adaptation.json`. Les fichiers de tests originaux sont intacts. Les hooks des suites sont également séparés par groupe.

Une information initiale d’analyse `prefer_interpolation_to_compose_strings` a été corrigée dans le nouveau test uniquement ; remplacement d’une concaténation par une interpolation équivalente, après les 59 tests. Aucun changement d’assertion ou de comportement produit à cette étape.

## 6. Couverture fonctionnelle et non-régressions

Les 59 tests incluent :

- Transport mémoire, backend non configuré et absence d’application Firebase.
- Réel formulaire de confirmation simulée → reçu → suivi, référence et route identiques en FR/EN/ES ; retour à l’espace client et reconstruction.
- Recherche, absence de chauffeur (null/vide/espaces), assignation.
- Chargement, erreur de lecture, mission disparue, annulée ou terminée.
- Statuts supplémentaires, référence absente et statut inconnu.
- Refus d’un autre client ; refus d’une mission B retournée pour A.
- Passage A→B, y compris événement tardif de A.
- Vrai LiveTrackingMap : mauvais chauffeur/mauvaise mission sans marqueur, position fraîche compatible affichée.

Les 19 non-régressions comprennent les suites existantes d’authentification du suivi (2), d’appartenance client (3), de vue terminée/notation (6), de listener erreur/reprise (2), de double soumission (2) et d’erreurs de réservation simulées (4).

Les 15 tests GPS sélectionnés vérifient 59/60/61 secondes, frontière stricte, rejeu d’ancienne mesure, changements de mission/chauffeur, permission-denied/unavailable de position et d’historique, reprise et erreur répétée. Aucun compteur de fraîcheur ou garde GPS n’a été changé.

P1-M-01 et R-K-03-A/B restent fermés dans leurs périmètres antérieurs. Leurs suites serveur/émulateur n’ont pas été réexécutées : aucun de leurs fichiers n’a changé. Les consommateurs Flutter pertinents ont été testés. Aucun nouveau test financier serveur n’est revendiqué.

## 7. Langues et dimensions

**36 cas automatiques sur les vrais widgets** : FR/EN/ES × recherche/assignation/erreur × quatre configurations :

- 375 × 812 ;
- 430 × 932 ;
- 1440 × 900 ;
- 375 × 812 avec texte à 200 %.

Contrôles : libellés attendus, longue référence, absence de texte tronqué (`RenderParagraph.didExceedMaxLines`), limites horizontales et absence d’exception Flutter. Tous réussis. Les trois parcours reçu→suivi vérifient aussi la langue et l’identité de référence.

Il s’agit du rendu **Flutter widget de test**, avec police de test, pas d’une inspection Chrome ou d’une validation visuelle sur téléphone physique. Aucune nouvelle capture PNG ni capture navigateur n’a été créée dans cette intervention.

## 8. Commandes et qualité

Les commandes exactes sont conservées dans `run-before.ps1`, `run-after.ps1`, `run-final.ps1`, `run-regression.ps1`, `run-regression-final.ps1` et `run-gps.ps1`.

Préfixe de toutes les exécutions Flutter test :
`flutter.bat --no-version-check test --no-pub --dart-define=no_default_http_client=true --reporter=json --concurrency=1`

Cibles finales :

- `test/customer/customer_tracking_presentation_test.dart`
- `artifacts/corrections-1-3M-O-20261010-a64e9b12/offline_regression_final_test.dart` + `test/customer/delivery_request_flow_double_submit_test.dart` + `test/customer/delivery_request_flow_error_messages_test.dart`
- `test/customer/live_tracking_freshness_test.dart --name "J age|J strict boundary|J replaying|J scope change"`
- `test/customer/live_tracking_errors_test.dart --name "typed classification (permission|unavailable)|L error then recovery|L old measure after error|L scope change"`

Les tests hors sélection ne sont pas présentés comme exécutés ou ignorés.

| Contrôle final | Résultat |
|---|---|
| Flutter analyze ciblé sur les 3 fichiers Dart | Aucun problème ; code de sortie 0 |
| Dart format --output=none --set-exit-if-changed | 3 fichiers, 0 changement ; code 0 |
| git diff --check | Aucun défaut ; code 0 |
| État Git / index / HEAD | Branche et HEAD inchangés, index vide |
| Traductions existantes | Identiques après retrait des six nouvelles clés |
| Registre | 27 lignes conservées ; 26 autres lignes actives strictement identiques |
| Empreintes initiales | Aucun fichier manquant ou modification imprévue |
| Recherche de motifs de secrets dans les fichiers Dart concernés | Aucune correspondance ; aucun secret ajouté/utilisé |

L’avertissement Git LF→CRLF concerne la normalisation Windows lors d’une future opération Git ; il n’est pas un échec de `diff --check`.

## 9. Isolation et limites

Auth, stockage, API de réservation, repository de missions et flux GPS sont fictifs. Aucun appel métier vers Firebase Production, Stripe, Google ou OpenStreetMap. Aucun paiement, notification, GPS physique, clé ou mission réelle.

Le transport mémoire existant répond aux URI de tuiles autorisées avec un PNG local en mémoire ; aucune délégation réseau. Les journaux finaux indiquent :
- ciblés : 52 chargements mémoire, 0 chemin inattendu ;
- non-régression : 24 chargements mémoire, 0 chemin inattendu ;
- fraîcheur : 312 chargements mémoire, 0 chemin inattendu ;
- erreurs : 384 chargements mémoire, 0 chemin inattendu ;
- tous : `external_transport=none`.

Ces compteurs complètent l’inspection du transport, les fakes, le refus de HttpClient et la désactivation du client HTTP par défaut ; une simple absence de requête observée n’est pas utilisée comme seule preuve. Aucun confinement réseau global Windows n’est revendiqué. Analytics désactivées, CI=true, --no-pub, --no-version-check ; aucune installation.

**1.3L demeure BLOQUÉ ET REPORTÉ.** Non testés ici : tuiles Internet, Chrome, GPS terrain, Firebase déployé, notifications, intégrité financière de bout en bout, paiement réel ou Sandbox. Les essais ne prouvent pas la disponibilité effective d’un chauffeur ni une politique de recherche. R-K-04 n’a pas été corrigé ou audité.

## 10. Décision et registre

P2-J-01 satisfait les critères autorisés : reproduction conservée, correction présente, tests ciblés/non-régression réussis, référence conforme, états honnêtes, langues/dimensions vérifiées et limites documentées.

**Statut final : FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ.**

Décompte calculé à partir du tableau actif, sans recopier les chiffres attendus :

| Priorité | Ouverts |
|---|---:|
| P0 | 0 |
| P1 | 2 |
| P2 | 15 |

27 fiches préservées, 17 ouvertes. Les P1 sont P1-HOME-001 et P1-COPY-001. Tous les autres P2, les historiques/P3 et les prérequis du pilote sont conservés. Aucun autre dossier fermé.

## 11. Fichiers proposés pour une future sauvegarde Git

Aucune sélection dans l’index et aucun commit effectués. Liste proposée :

1. `lib/screens/customer/customer_tracking_screen.dart`
2. `lib/l10n/app_strings.dart`
3. `test/customer/customer_tracking_presentation_test.dart`
4. `docs/audit/REGISTRE_BOGUES_MOVIK.md`
5. `artifacts/corrections-1-3M-O-20261010-a64e9b12/CHECKPOINT_MOVIK_1_3M_O.md`
6. `artifacts/corrections-1-3M-O-20261010-a64e9b12/ISOLATION.md`
7. `artifacts/corrections-1-3M-O-20261010-a64e9b12/RESULTATS.json`
8. `artifacts/corrections-1-3M-O-20261010-a64e9b12/VALIDATION_SOURCES.json`
9. `artifacts/corrections-1-3M-O-20261010-a64e9b12/regression-adaptation.json`
10. `artifacts/corrections-1-3M-O-20261010-a64e9b12/network-proofs.json`

Les logs détaillés, copies temporaires, scripts de diagnostic, inventaires complets et preuves des anciennes étapes restent conservés localement et sont exclus de cette proposition de commit. Aucun cache/build, secret ou fichier personnel proposé.

## 12. Prochaine action unique

**Obtenir l’autorisation de créer le commit local de P2-J-01 avec cette sélection, après revue du diff.** Message proposé : `fix(customer): show reliable tracking reference and mission status`.

Arrêt au checkpoint 1.3M-O. Aucun démarrage de R-K-04 ou d’une autre correction.

Dossier de preuves : `C:\Users\Utilisateur\movik-gps-history-fix-20261009\artifacts\corrections-1-3M-O-20261010-a64e9b12`.
