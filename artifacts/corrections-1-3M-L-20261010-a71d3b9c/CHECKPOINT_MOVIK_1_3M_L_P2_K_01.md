# CHECKPOINT MOVI-K — 1.3M-L — P2-K-01

Date : **10 octobre 2026**, America/Toronto. Contrôle final Git à 09:04:11 (13:04:11 UTC).
**Verdict : correction terminée et validée dans le périmètre simulé — NON FERMÉE, NON COMMITÉE, NON DÉPLOYÉE.**

## 1. Reprise, branche et état Git

Worktree : `C:\Users\Utilisateur\movik-gps-history-fix-20261009`.
Branche initiale et finale : `fix/gps-client-history-scope-20261009`.
HEAD initial et final : **`980a9dab54353a99315fa78fd4487c77396042f4`**.
Index vide avant et après. Aucun changement de branche, stage, commit, push, merge ou déploiement.

Le checkpoint K existant a été lu dans :
`artifacts/preparation-1-3M-K-20261010-0833/POINT_APPROBATION_GIT_MOVIK_1_3M_K_FINAL.md`.
Il n’a pas été recréé ni remplacé.

À l’entrée : aucun diff suivi, mais nombreuses preuves non suivies préexistantes.
À la sortie : trois fichiers suivis modifiés et un nouveau test ; toutes les preuves restent présentes.
Sur **2 496 fichiers préexistants**, **2 493 sont inchangés** ; seuls carte, traductions et registre ont évolué. Le seul nouveau fichier hors dossier de preuves est le test d’erreurs GPS.

Source : `git-initial.json`, `git-final.json`, `CONTROLES_FINAUX.json`. Ce dernier confirme `safe=true`, index vide et `git diff --check` code 0.
Aucune intervention sur les autres worktrees.

## 2. Reproduction et cause démontrée

P2-K-01 était une lacune statique ; les tests de cette intervention la reproduisent sur les vrais composants Flutter.

Avant correction, LiveTrackingMap :
- lisait `snap.data` sans état explicite pour `snap.hasError` ;
- lisait `historySnap.data ?? []` sans distinguer erreur et trajet vide ;
- sélectionnait le message d’attente GPS en l’absence de position.

Les tests avant correction constatent notamment :
`Expected: exactly one matching candidate; Found 0 widgets with text "Accès à la position refusé."`
dans le scénario d’injection `FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied')`.
Les messages d’indisponibilité d’historique et de position sont également absents. Les 21 échecs de la reproduction complète portent sur les états d’erreur et leurs parcours dépendants ; ils ne correspondent pas à 21 nouveaux bogues.

Le chemin statique explique la confusion avec une absence GPS ou un historique vide. Aucun incident de production n’est affirmé.
Preuves : `RESULT-before-complete.jsonl`, son résumé et `errors-test-before-product-fix.dart.txt`.

## 3. Correctif appliqué

### Position courante

- Une erreur exclut explicitement la position de l’affichage courant.
- Un refus typé `cloud_firestore / permission-denied` reçoit un message d’accès refusé.
- Toute autre erreur, y compris `unavailable`, une chaîne libre contenant « permission-denied » ou un autre plugin, reçoit un message d’indisponibilité.
- Aucune exception brute ou information interne n’est affichée.
- Une erreur ne signifie pas que la connexion Internet du client est nécessairement coupée.

### Historique

- Une erreur retire la polyline issue de ce flux et affiche un message dédié sous la carte.
- Une position fraîche issue d’un flux position valide reste visible.
- Son expiration continue normalement après 60 secondes.
- Si seul le flux position échoue, l’historique valide de la bonne mission peut rester présent.

### Reprise et préservation

- Une nouvelle donnée valide efface l’état d’erreur et retrouve l’affichage normal.
- Réémettre une ancienne mesure ne remet pas son âge à zéro.
- Les changements de mission/chauffeur réinitialisent les snapshots ; les anciens événements incompatibles ne contaminent pas le nouvel affichage.
- Aucun retry automatique, nouveau repository, changement d’interface, règle Firestore ou fonction serveur ajouté.
- NotConfiguredLocationRepository conserve son comportement volontaire d’attente.
- Le seuil reste strictement **60 secondes incluses pour une position fraîche**, puis position non actualisée.
- La carte garde ses dimensions et composants ; le texte d’historique est placé dans le flux de mise en page pour ne pas recouvrir la date. Une partie du diff provient de la réindentation associée.

## 4. Fichiers réellement modifiés

Préfixe commun : `C:\Users\Utilisateur\movik-gps-history-fix-20261009\`.

| Fichier | Modification |
|---|---|
| lib/widgets/live_tracking_map.dart | Classification des erreurs typées, garde d’affichage et messages distincts des deux flux. |
| lib/l10n/app_strings.dart | Quatre clés d’erreur FR/EN/ES. |
| test/customer/live_tracking_errors_test.dart | Nouveau test permanent : 28 cas simulés et transport mémoire existant. |
| docs/audit/REGISTRE_BOGUES_MOVIK.md | P2-K-01 confirmé par tests, correction/validation et limites ; reste ouvert. |

Les tests I/J et le helper de transport n’ont pas changé.
Les repositories, modèles, écrans client/chauffeur, fonctions serveur, règles, tarifs, commissions, Stripe, snapshots et ledger n’ont pas été modifiés.

## 5. Résultats exacts des exécutions

| Exécution | Réussis | Échoués | Ignorés | État |
|---|---:|---:|---:|---|
| Vérification d’isolation seule | 1 | 0 | 0 | Terminée |
| Première reproduction | 6 | 17 | 0 | Incomplète, interrompue au nettoyage |
| Diagnostic du nettoyage après adaptation | 0 | 1 | 0 | Terminé, assertion produit toujours échouée |
| Reproduction complète avant correction produit | 7 | 21 | 0 | Terminée |
| Première exécution après correction | 28 | 0 | 0 | Terminée |
| Finale : erreurs L + identité I + fraîcheur J | 73 | 0 | 0 | Terminée |
| Non-régressions contrat/client/chauffeur/reporter | 37 | 0 | 0 | Terminée |

**Validation finale : 110 tests distincts réussis, 0 échoué, 0 ignoré.**
Les reprises ne sont pas additionnées ; aucun résultat historique n’est présenté comme une nouvelle exécution.

La première tentative a démarré 24 des 28 tests : 23 possèdent un résultat final, un autre a signalé une assertion en erreur sans `testDone`, et quatre n’ont pas démarré. La session lancée ici a été arrêtée après immobilisation du nettoyage. Ce journal reste conservé et n’est pas présenté comme une suite terminée.

Le nouveau harnais tentait de refermer les contrôleurs déjà fermés par le scénario dans la zone du test. Le nettoyage ne ferme maintenant que les contrôleurs encore ouverts et vérifie l’absence d’abonné. Le diagnostic se termine alors normalement, en conservant l’échec produit attendu. La cause interne précise du blocage asynchrone Flutter n’est pas établie. Aucune assertion métier supprimée, aucun skip introduit, aucun test existant affaibli.

Preuves : tous les `RESULT-*.jsonl`, leurs résumés et `RESULTATS.json`.

## 6. Couverture fonctionnelle vérifiée

| Scénario | Résultat final |
|---|---|
| Chargement initial | Indicateur normal, aucune fausse erreur ni attente GPS prématurée. |
| Position null / repository non configuré | Attente GPS conservée, sans message d’erreur inventé. |
| Position fraîche / historique vide normal | Marqueur présent, absence de fausse erreur. |
| Position >60 secondes | Marqueur absent, date et historique valides conservés. |
| Refus Firestore typé | Message d’autorisation adapté, pas de faux « aucun signal ». |
| unavailable / erreur générique | Message d’indisponibilité, sans diagnostic de connexion Internet. |
| Texte libre permission-denied / autre plugin | Aucune classification abusive en refus Firestore. |
| Erreur position seulement | Aucun marqueur courant ; historique valide indépendant préservé. |
| Erreur historique seulement | Message de trajet, position valide préservée ; expiration normale. |
| Erreur après position/route valides | États d’erreur explicites, pas de maintien trompeur du marqueur/du trajet concerné. |
| Reprise puis nouvelle erreur | Affichage normal rétabli, puis nouvelle erreur correctement affichée. |
| Reprise d’une ancienne mesure | Âge d’origine conservé ; pas de fraîcheur artificielle. |
| Changement de mission ou chauffeur pendant erreur | Ancien état et anciens événements incompatibles exclus. |
| Fermeture d’un flux en erreur | Erreur explicite persistante, pas de spinner infini ni retry automatique. |
| Fermeture d’un flux valide | Expiration après 60 secondes sans nouvel événement. |
| Démontage | Abonnements libérés, pas d’exception après cinq minutes simulées. |

## 7. FR/EN/ES et mobile

Les quatre messages sont réellement rendus dans chacune des trois langues, à **375×812** et texte **200 %** :
- refus de position ;
- indisponibilité de suivi ;
- refus de trajet ;
- indisponibilité de trajet.

Les tests vérifient leur présence, l’absence de détail brut d’exception, les limites horizontales/verticales des rectangles, l’absence de chevauchement entre les deux messages et l’absence d’exception de débordement.
**Ce sont des tests widget Flutter, pas des captures Chrome. Aucune nouvelle capture PNG n’a été produite.**

## 8. Non-régressions GPS et qualité

Les 45 cas I/J ont été réexécutés : 25 identité et 20 fraîcheur.
Les 37 contrôles complémentaires couvrent le contrat P1-M-01 (8), auth client (2), propriété client (3), cycle chauffeur (6), statuts chauffeur (9) et reporter GPS (9), via les suites isolées déjà présentes.

Comparaison exacte du code avant/après : les sections de liaison des flux, validation des dates/identités, planification du timer, changement de scope, démontage et filtrage/tri d’historique sont conservées. Résultat dans `CONTROLES_FINAUX.json`.

Analyse Flutter ciblée sur dix fichiers :
- Première analyse : une information de style `prefer_interpolation_to_compose_strings` dans le nom d’un nouveau test, code 1.
- Correction limitée à l’écriture de ce nom par interpolation ; libellé généré et assertions identiques.
- **Analyse finale : No issues found!, code 0.**
- Les 110 tests précèdent uniquement cette modification de style du nom ; le code produit n’a plus changé. La suite n’a pas été relancée pour ce nom équivalent ; l’analyse finale a été exécutée après.
- **git diff --check final : code 0**, y compris après mise à jour du registre.

Aucune modification des corrections serveur A/B ; leurs preuves historiques restent distinctes de ces nouvelles non-régressions Flutter. Aucun test financier ou Firestore Emulator exécuté ici.

Commandes intégrales réellement utilisées : `run-tests.ps1`, `run-final-validation.ps1`, `run-analysis-final.ps1`.
Exemple de la validation ciblée exécutée :

```powershell
flutter.bat --no-version-check test --no-pub --dart-define=no_default_http_client=true --reporter=json --concurrency=1 test/customer/live_tracking_errors_test.dart test/customer/live_tracking_identity_test.dart test/customer/live_tracking_freshness_test.dart
```

Aucun téléchargement ni installation ; SDK existant, télémétrie désactivée dans les processus de validation.

## 9. Isolation et limites

- Composants réels ; repositories, flux, coordonnées et réponses fictifs.
- Aucun backend initialisé.
- Harnais GPS mémoire I/J inchangé : URL cartographique utilisée comme clé de fixture, PNG en mémoire sans délégation réseau.
- `no_default_http_client=true` ; création HttpClient et fallback IOClient refusés et testés.
- Journaux finaux : `unexpected=0`, `external_transport=none`.
- Aucun Firebase Production, Stripe, service Google, OpenStreetMap réel, GPS physique, notification ou émulateur sollicité.
- Ce contrôle des voies du harnais ne constitue pas un confinement réseau global OS. **Le test autonome 1.3L reste BLOQUÉ ET REPORTÉ**, distinct de la présente étape **1.3M-L**.

Limites restantes :
- Chrome, téléphone physique, lecteur d’écran et transport Firestore réel non testés.
- La reprise démontrée provient d’une nouvelle donnée sur un flux encore ouvert ou d’un nouveau scope. Un flux définitivement fermé reste en erreur ; aucun bouton de réabonnement ni retry infini n’a été ajouté.
- Les contraintes d’horloge locale, de date serveur versus mesure physique et de suspension de l’application documentées pour C demeurent.
- Aucun nouveau défaut produit supplémentaire démontré après validation finale.
- Aucun retour en production ou promesse de lancement déduit de ces tests.

## 10. Registre et statut recommandé

Registre unique : `docs/audit/REGISTRE_BOGUES_MOVIK.md`.

**P2-K-01 : CORRIGÉ ET VALIDÉ DANS LE PÉRIMÈTRE SIMULÉ — NON FERMÉ — NON DÉPLOYÉ.**
Fermeture documentaire limitée recommandée, **non appliquée**.

Décompte inchangé :
- **P0 : 0**
- **P1 : 2** — P1-HOME-001, P1-COPY-001
- **P2 : 21**, dont P2-K-01 toujours ouvert

27 entrées dans le tableau central, 4 fermetures GPS antérieures et 23 entrées ouvertes. P3 historiques, prérequis pilote et reports conservés. Aucun dossier P1-M-01/A/B/C rouvert.

## 11. Liste exacte proposée pour une sauvegarde ultérieure

Dossier de preuves :
`C:\Users\Utilisateur\movik-gps-history-fix-20261009\artifacts\corrections-1-3M-L-20261010-a71d3b9c`.

Fichiers proposés, relatifs au worktree :
1. lib/widgets/live_tracking_map.dart
2. lib/l10n/app_strings.dart
3. test/customer/live_tracking_errors_test.dart
4. docs/audit/REGISTRE_BOGUES_MOVIK.md
5. artifacts/corrections-1-3M-L-20261010-a71d3b9c/CHECKPOINT_MOVIK_1_3M_L_P2_K_01.md
6. artifacts/corrections-1-3M-L-20261010-a71d3b9c/RESULTATS.json
7. artifacts/corrections-1-3M-L-20261010-a71d3b9c/RESULT-before-complete.jsonl
8. artifacts/corrections-1-3M-L-20261010-a71d3b9c/RESULT-final-targeted.jsonl
9. artifacts/corrections-1-3M-L-20261010-a71d3b9c/RESULT-regression.jsonl
10. artifacts/corrections-1-3M-L-20261010-a71d3b9c/analyze-final.txt
11. artifacts/corrections-1-3M-L-20261010-a71d3b9c/MANIFESTE_SAUVEGARDE_1_3M_L.json

Les originaux intermédiaires, sauvegardes, scripts et inventaires restent conservés localement ; aucune inclusion de cache, build, dépendance ou secret. Le manifeste n’est pas une mise à l’index. Aucun commit effectué. Toute fermeture ultérieure devra actualiser les empreintes du registre avant commit.

## 12. Prochaine étape unique et arrêt

**Demander l’approbation de la fermeture documentaire limitée de P2-K-01 et de sa sauvegarde par commit local**, avec recontrôle des fichiers/index/HEAD avant toute opération.
Aucun push, merge ou déploiement associé.

Arrêt à ce checkpoint ; aucune autre correction lancée.

## Sources vérifiables

- Inspection Git et code du 10 octobre 2026 : git-initial.json, git-final.json, CONTROLES_FINAUX.json, diff-final.patch.
- Tests du 10 octobre 2026 : journaux bruts et RESULTATS.json, commandes PowerShell conservées dans le dossier L.
- Qualité : analyze.txt (première remarque conservée), analyze-final.txt, analysis-final-exit.json, contrôle final de diff.
- Continuité : checkpoint K existant, commit 980a9dab54353a99315fa78fd4487c77396042f4 et registre maître avec historique I/J/C.
