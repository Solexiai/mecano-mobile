# CHECKPOINT MOVI-K — 1.3M-J — VALIDATION FINALE R-K-03-C

Date : 9 octobre 2026. Vérifications finales vers 21:33 UTC / 17:33 America/Toronto.
**Verdict : TERMINÉ dans le périmètre local simulé. Fermeture documentaire recommandée, NON appliquée. Non commité, non déployé.**

## 1. Reprise et intégrité Git

- Worktree exclusivement utilisé : `C:\Users\Utilisateur\movik-gps-history-fix-20261009`.
- Branche initiale/finale : `fix/gps-client-history-scope-20261009`.
- HEAD initial/final : `7a0d60f5d556001705460f005ed8c7d1f268460d`.
- Index vide avant/après ; aucune opération de stage, commit, push, merge, changement de branche ou déploiement.
- Checkpoint I et registre lus. Aucune divergence depuis les empreintes finales I sur les fichiers comparés : `continuity-I.json`.
- Sept fichiers suivis déjà modifiés à l’entrée ; ils restent les mêmes à la sortie. Les nouveaux tests/helpers et nombreuses preuves antérieures non suivies restent présents.
- Empreintes de **2 427 fichiers préexistants** comparées : 2 423 identiques ; seuls quatre fichiers autorisés évoluent pendant J. Un nouveau test est ajouté, hors nouveau dossier de preuves.
- Aucun fichier serveur, règle Firestore, paiement, tarif, commission, snapshot ou ledger modifié. Aucun travail effectué dans les autres worktrees.

États complets et empreintes : `git-initial.json`, `git-final.json`. Le statut Git complet est inclus dans ces fichiers, sans omettre les fichiers non suivis. Le diff total depuis HEAD inclut les corrections I préexistantes ; les trois fichiers `*.J.patch` isolent les changements produit/test de J.

## 2. Comportement implémenté

Le seuil de **60 secondes** a été approuvé explicitement par Daniel pour le pilote.

- À 59 secondes et à 60 secondes exactement : marqueur normal.
- Strictement après 60 secondes : marqueur actif retiré, texte **« Position non actualisée »**.
- Date/heure de dernière position connue et trajet historique valide conservés.
- Nouvelle position valide : message retiré, marqueur rétabli, échéance recalculée depuis sa date.
- Réémission d’une vieille date : aucune prolongation artificielle.
- Temporisateur indépendant des émissions Firestore ; annulation au changement de chauffeur/mission/assignation et au démontage.
- Identités chauffeur/mission, date inconnue/future, date antérieure à l’assignation et filtrage historique de I conservés.

Une horloge injectable a été ajoutée avant les reproductions ; par défaut, le produit conserve DateTime.now(). Aucune expiration n’était codée à cette première exécution. Le timer vise la première unité temporelle représentable strictement après la frontière, soit une microseconde après 60 secondes : ce n’est pas une tolérance métier supplémentaire. La précision effective du système reste une limite de validation.

## 3. Fichiers modifiés par J

Préfixe absolu commun : `C:\Users\Utilisateur\movik-gps-history-fix-20261009\`.

| Fichier | Changement J |
|---|---|
| lib/widgets/live_tracking_map.dart | Horloge de test, seuil 60 s, timer, retrait/rétablissement du marqueur, date conservée, libération du timer et du contrôleur. |
| lib/l10n/app_strings.dart | Clé tracking_position_stale en français, anglais et espagnol. |
| test/customer/live_tracking_freshness_test.dart | Nouveau fichier : 20 tests de fraîcheur, reprise, invalidité, cycle de vie, isolation et mobile multilingue. |
| test/customer/live_tracking_identity_test.dart | Cas G adapté à la décision approuvée : marqueur d’une position vieille de deux jours absent, message périmé présent ; contrôles de date inchangés. |
| docs/audit/REGISTRE_BOGUES_MOVIK.md | Statut actuel C, seuil approuvé, historique et addendum J avec preuves et décompte. |

Fichiers I préexistants préservés sans modification supplémentaire J : les deux modèles DriverLocation/DriverLocationHistoryPoint, CustomerTrackingScreen et DriverActiveMissionScreen. Le helper `test/helpers/gps_offline_transport.dart` reste inchangé.

Nouvelles preuves/scripts uniquement dans :
`C:\Users\Utilisateur\movik-gps-history-fix-20261009\artifacts\corrections-1-3M-J-20261009-85e72ad1\`.

## 4. Résultats réels avant/après

| Exécution | Réussis | Échoués | Ignorés | Preuve |
|---|---:|---:|---:|---|
| Précontrôle d’isolation | 1 | 0 | 0 | RESULT-isolation.jsonl |
| Avant expiration, horloge injectable seulement | 10 | 10 | 0 | RESULT-before.jsonl |
| Première exécution après correction | 19 | 1 | 0 | RESULT-after.jsonl |
| Diagnostic de la reprise | 1 | 0 | 0 | RESULT-recovery-diagnostic.jsonl |
| Finale : fraîcheur + identité | 45 | 0 | 0 | RESULT-final-targeted.jsonl |
| Non-régressions des consommateurs GPS | 37 | 0 | 0 | RESULT-regression.jsonl |

**Validation finale : 82 tests distincts réussis, 0 échoué, 0 ignoré.** Les reprises ne sont pas additionnées à ce total. Les 62 succès historiques I ne sont pas annoncés comme des tests nouveaux supplémentaires.

L’échec intermédiaire après correction était :
`Expected: exactly one matching candidate; Found 0 widgets with icon IconData(U+0E3A6)`,
dans le scénario de reprise du nouveau test, ancienne ligne 105.

La preuve diagnostique montre `layer markers=1 visible=0 stale=0 scheduled=true`, puis `extra frame visible=1`. Le marqueur existait dans la couche cartographique et le texte périmé avait disparu ; le recentrage post-frame demandait une frame supplémentaire. Le helper du test attend maintenant cette frame, sans délai arbitraire, sans suppression d’assertion, sans changement produit pour faire réussir le test. Les journaux d’échec sont conservés.

### Couverture détaillée

| Contrôle demandé | Résultat constaté |
|---|---|
| 59 / 60 / 61 secondes | Validé ; marqueur aux deux premières bornes, message périmé à 61. |
| Expiration sans nouvelle émission | Validée à la borne stricte suivante et après cinq minutes. |
| Date et trajet conservés | Texte initial daté conservé ; deux points d’historique valides restent dans PolylineLayer. |
| Nouvelle position et réarmement | Marqueur rétabli ; ancienne échéance n’expire pas le nouveau point. |
| Réémission ancienne | Ne remet pas l’âge à zéro. |
| Changement de mission/chauffeur | Ancien marqueur retiré ; ancien timer annulé ; nouveau point régi par sa propre date. |
| Dates inconnues, futures, préassignation | Aucun marqueur courant trompeur ; état d’attente honnête. Parsing invalide couvert aussi par les tests I réexécutés. |
| Mauvais chauffeur/mauvaise mission | Aucun point incompatible présenté comme courant. |
| Démontage | Abonnement retiré, timer annulé, aucune exception après cinq minutes simulées. |
| FR/EN/ES mobile | Textes exacts présents à 375×812, texte 200 %, aucune exception de débordement Flutter. |
| Écrans client/chauffeur | Non-régressions simulées du contrat, auth, propriété, cycle GPS, statuts et reporter réussies. |

Les 37 non-régressions correspondent aux suites existantes isolées du checkpoint C : contrat GPS (8), auth client (2), propriété client (3), cycle chauffeur (6), statuts chauffeur (9), reporter (9). Les fichiers exacts sont dans `run-quality.ps1`.

## 5. Commandes et qualité

Commandes réellement exécutées, SDK Windows déjà installé, sans installation ni téléchargement :

```powershell
# Lancées depuis le worktree ; scripts et sorties conservés dans le dossier J.
flutter.bat --no-version-check test --no-pub --dart-define=no_default_http_client=true --reporter=json --concurrency=1 test/customer/live_tracking_freshness_test.dart test/customer/live_tracking_identity_test.dart

# Six suites de non-régression : liste complète dans run-quality.ps1.
# Analyse ciblée : neuf fichiers, liste complète dans le même script.
flutter.bat --no-version-check analyze --no-pub <les neuf fichiers ciblés>
git diff --check
```

Les lignes exécutables intégrales sont conservées dans `run-tests.ps1`, `run-final.ps1` et `run-quality.ps1` ; les arguments abrégés ci-dessus ne prétendent pas constituer une commande autonome.

- Analyse de neuf fichiers : **No issues found!**, code 0, `analyze.txt`.
- Formatage Dart : carte et nouveau test formatés ; trois fichiers examinés.
- Diff check code/test : code 0.
- Après ajout documentaire, une ligne vide surnuméraire en fin de registre a été signalée ; seule cette ligne a été retirée. Preuve intermédiaire préservée : `before-eof-fix-diff-check-final.json`.
- Diff check final après registre : **code 0**, `diff-check-final.json`.

## 6. Isolation

Vrais LiveTrackingMap, FlutterMap, écrans et modèles ; seules les frontières de données et de transport sont simulées. Aucun composant réel remplacé par un widget factice pour annoncer sa validation.

- Backend non initialisé ; repositories/flux et authentification fictifs.
- GPS physique remplacé par le fake existant dans les tests reporter.
- `http.Client` fourni par MemoryOnlyClient ; PNG transparent renvoyé en mémoire sans socket, DNS ni délégation à un client réseau.
- Les URL OpenStreetMap servent uniquement de clés au transport fictif.
- `no_default_http_client=true` obligatoire ; création HttpClient et fallback IOClient explicitement refusés et testés.
- Requêtes inattendues refusées et faisant échouer la suite.
- Journaux finaux : 672 + 680 chargements mémoire pour les deux suites ciblées ; zéro tentative inattendue. Les suites de régression cartographiques rapportent également zéro tentative inattendue.
- Aucun service Firebase/Stripe/Google/OpenStreetMap réel ni notification réelle ; aucun émulateur démarré.

Cela démontre l’isolation des voies inspectées du harnais, **pas** une politique réseau OS universelle. **1.3L reste BLOQUÉ ET REPORTÉ**, inchangé.

## 7. Limites et défauts restants

- Aucun défaut supplémentaire démontré dans le périmètre J après validation finale.
- Tests Flutter widget, pas un rendu réel Chrome ; aucune nouvelle capture PNG, aucun build Web ni essai terrain effectué dans cette étape.
- Horloge locale comparée à la date de réception serveur. Aucune marge de dérive inventée. Une horloge mal réglée peut produire une indisponibilité ou une expiration anticipée ; date future rejetée.
- Le timer dépend de l’exécution de l’application. Suspension d’onglet/OS, délai réel de rendu et reprise sur appareil non validés ; aucune garantie de précision temporelle terrain.
- La date serveur n’est pas une preuve de date physique de mesure GPS. Les missions anciennes sans acceptedAt gardent la limite temporelle documentée en I.
- Permissions Firestore, concurrence et règles A/B/P1-M-01 : preuves historiques conservées, non réexécutées ici. Les consommateurs Flutter sont revérifiés ; aucun fichier serveur/règle modifié.
- Gestion des erreurs de flux P2-K-01, centre Montréal R-K-04 et autres anomalies restent ouverts. Aucun élargissement à leur correction.
- Aucun paiement ni calcul financier testé ou modifié.

## 8. Registre et décision

Registre maître actualisé : `docs/audit/REGISTRE_BOGUES_MOVIK.md`.
Recalcul du tableau central : **P0 0 / P1 3 / P2 21 ouverts** ; 27 entrées, 3 fermetures antérieures, 24 ouvertes. P3 historiques, prérequis pilote, anciennes preuves et problèmes reportés préservés.

P1 ouverts : R-K-03-C, P1-HOME-001, P1-COPY-001.

**R-K-03-C : VALIDÉ DANS LE PÉRIMÈTRE SIMULÉ — FERMETURE PROPOSÉE — NON FERMÉ — NON DÉPLOYÉ.**

Les critères d’identité, association, dates et obsolescence approuvée sont satisfaits dans les scénarios simulés I/J. Je recommande une fermeture documentaire limitée à ce périmètre, sans annoncer la validation GPS terrain, de la production ou du transport cartographique externe.

**Prochaine action unique : obtenir l’approbation de Daniel pour cette fermeture documentaire limitée.** Aucun commit, push, merge ou déploiement n’est effectué ni autorisé implicitement. Arrêt à ce checkpoint.
