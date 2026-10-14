# CHECKPOINT MOVI-K — 1.3M-N
## CONFIRMATION CLIENT — P2-I-01 / P2-I-02

**Date : 10 octobre 2026. Verdict : TERMINÉ dans le périmètre simulé autorisé.**
Les deux fiches sont fermées documentairement : **FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ**.
Aucun commit, push, merge, déploiement ou changement de production effectué.

## 1. Référence et état Git

- Dépôt : Solexiai/mecano-mobile.
- Worktree exclusif : `C:\Users\Utilisateur\movik-gps-history-fix-20261009`.
- Branche vérifiée avant et après : `fix/gps-client-history-scope-20261009`.
- HEAD inchangé : `7fd6a905fe8f99e0bf3be3b4bb95a115d62bd395`.
- Cinquième commit présent : `fix(booking): validate contact phones and clarify field guidance`.
- Index vide, aucun fichier suivi modifié au départ. Nombreux artifacts non suivis antérieurs conservés.
- P2-H-01/H-02 déjà fermés au départ, contrôlé dans le registre ; les correctifs GPS et leurs fermetures conservés.
- Final : deux fichiers suivis modifiés (écran et registre), un nouveau test permanent, nouvelles preuves dans ce seul dossier.
- Inventaire initial de 2 624 fichiers suivis/non ignorés avec empreintes. Comparaison finale : aucun fichier initial manquant ; seuls l’écran autorisé et le registre ont changé parmi les fichiers préexistants hors dossier de preuves courant.
- Les autres worktrees n’ont pas été modifiés. Preuves exactes : `git-initial.json`, `CONTROLES_FINAUX.json`, `diff-final.patch`.

## 2. Causes démontrées

### P2-I-01

Dans `lib/screens/delivery/delivery_request_flow_screen.dart`, la confirmation rendait inconditionnellement « Votre carte est enregistrée chez Stripe ». La branche `_cardReady` rendait également « Carte enregistrée ».
Le booléen est issu de `getBookingCardStatus` ou d’une réponse `startBookingCardSetup` avec `ready=true`.

Lecture statique de `functions/src/functions/bookingCardSetup.ts:17–88` et `functions/src/lib/bookingPayment.ts:1–6` :
- le statut prêt vérifie l’existence d’un identifiant de moyen de paiement et l’environnement du provider ;
- la vérification d’une nouvelle session contrôle client, utilisateur, devis et environnement ;
- ce statut ne représente ni autorisation de paiement ni capture ;
- aucun état Stripe réel n’a été interrogé pendant l’intervention.

Les tests avant correction montrent bien l’affirmation mensongère pour `cardReady=false`. Les tests refusent aussi l’affirmation excessive « carte enregistrée » pour le booléen prêt.

### P2-I-02

La qualification historique « date technique » a été précisée, sans supposer un ISO brut dans tous les cas.
Le HEAD utilisait déjà `_formatTime` : `DateTime.tryParse(...).toLocal()`, puis `MaterialLocalizations.of(context).formatMediumDate` et `TimeOfDay.format`.
Dans le vrai widget français, le résultat reproduit est notamment **« Créneau demandé : Thu, Jan 1 · 7:00 AM »** : langue du contexte Material par défaut, année absente.
Une valeur invalide était affichée brute ; une valeur absente n’avait aucune indication.

Sources :
- `requested_at` : chaîne de date dans BookingDraft, choisie et persistée par le parcours existant ;
- `expiresAtMillis` : instant numérique du devis reçu, résumé partagé Mon prix/confirmation ;
- conversion locale déjà appliquée. Aucun instant, valeur persistée ou donnée envoyée au serveur n’est changé.

## 3. Reproduction et résultats exacts

| Exécution | Réussis | Échoués | Ignorés | Résultat |
|---|---:|---:|---:|---|
| Première tentative de chargement | 0 | 0 | 0 | 1 erreur de compilation du nouveau test ; aucun test exécuté |
| Avant correction produit | 2 | 52 | 0 | Défauts reproduits |
| Première exécution après correction | 53 | 1 | 0 | Écart de fixture sur l’expiration du devis |
| Exécution ciblée finale | 54 | 0 | 0 | Réussie |
| Non-régressions | 66 | 0 | 0 | Réussies |

**Total final distinct : 120 tests réussis, 0 échec, 0 ignoré.** Les anciennes exécutions ne sont pas additionnées.

Erreurs intermédiaires conservées :
- `before-compile-error.jsonl` : paramètre obligatoire `message` absent dans la construction de l’exception fictive FirebaseFunctionsException ; ajouté au test uniquement.
- `before.jsonl` : assertions de messages/dates échouées avant modification.
- `after.jsonl` : deux appels à testQuote généraient des expirations différentes de 1 ms. Le brouillon et le faux serveur partagent désormais le même devis complet ; comparaison stricte conservée. Aucun correctif produit appliqué pour satisfaire cette fixture.
- Analyse initiale : deux infos de style dans le nouveau test. Ajout d’accolades, sans modification des assertions, puis analyse finale propre.
- `final.jsonl`, `regression.jsonl`, `RESULTATS.json` : résultats finaux et historiques.

## 4. Corrections effectuées

### Messages de paiement

Uniquement la présentation :
- note générale distinguant préparation, autorisation et paiement final ;
- préparation non confirmée lorsque le booléen n’est pas prêt ;
- moyen de paiement prêt pour la confirmation lorsque le booléen le confirme, sans en déduire une autorisation ou un paiement ;
- traductions FR/EN/ES via le mécanisme `tr` existant.

Les appels API, gardes, liens de préparation, montants, consentements, boutons de confirmation, traitement des erreurs et double soumission sont inchangés.

### Dates

Ajout d’un petit formateur widget `_localizedTime` utilisant **flutter_localizations déjà déclaré et installé** :
- langue explicite du formulaire ;
- date complète avec année, heure 24 h, décalage UTC correspondant à l’instant ;
- valeur absente/invalide signalée, jamais remplacée par maintenant ;
- application au créneau de confirmation et à l’expiration du devis dans le résumé partagé ;
- conversion locale existante préservée.

Pas de nouvelle bibliothèque ni installation. Les sélecteurs et le résumé de date de l’étape Ma livraison ne sont pas refondus ; P2-FORM-001 reste ouvert.

## 5. Couverture des vrais widgets

`test/customer/delivery_confirmation_presentation_test.dart` :

- 1 contrôle d’isolation.
- 24 combinaisons : FR/EN/ES × prêt/non prêt × 375×812, 430×932, 1440×900, 375×812 avec texte200%.
- 3 scénarios : chargement puis réponse prête explicite ; préparation échouée puis reprise ; vérification de statut échouée sans moyen préparé.
- 15 dates : cinq cas par langue, hiver/été, fin de mois, changement d’année, chaîne avec décalage explicite.
- 9 valeurs absentes/invalides : null, chaîne vide, texte invalide, dans les trois langues.
- 1 navigation/reconstruction conservant date, contacts et devis.
- 1 confirmation fictive avec double appel du callback : une seule demande, contacts et quoteId inchangés, aucun customerTotal calculé ou ajouté au payload.

Formatage observé via les widgets réels : mois localisés, année, heures et décalages vérifiés. Exemple d’instant `2099-03-01T02:15:00Z` affiché le 28 février à21:15 avec UTC-05:00 sur ce runner.
Le PC est configuré **Eastern Standard Time**. Les contrôles UTC-05 hiver / UTC-04 été sont réellement exécutés. La suite de dates ciblée requiert ce fuseau de runner ; sur un autre environnement, prévoir un runner America/Toronto sans modifier la logique du produit. Le produit continue d’afficher l’heure locale de l’appareil avec son décalage explicite.

Les contrôles de rendu vérifient les paragraphes non tronqués, leurs bornes horizontales et les exceptions Flutter. Aucune exception ni débordement détecté dans les scénarios testés.
**Aucune capture Chrome ou preuve sur téléphone physique ; aucun PNG produit par cette étape.**

## 6. Non-régressions exécutées

| Suite existante | Réussis |
|---|---:|
| delivery_contact_validation_test.dart | 46 |
| delivery_request_draft_resume_test.dart | 4 |
| delivery_request_draft_test.dart | 6 |
| delivery_request_auth_navigation_test.dart | 2 |
| delivery_request_flow_double_submit_test.dart | 2 |
| delivery_request_flow_error_messages_test.dart | 4 |
| booking_service_availability_test.dart | 2 |

Les données du devis et des contacts sont conservées. Les erreurs fictives et reprises, brouillons privés, navigation, indisponibilité et confirmations restent couverts.
Les suites GPS n’ont pas été relancées inutilement : aucun fichier GPS ou composant partagé GPS modifié.

## 7. Commandes et qualité

Commandes réellement exécutées depuis le worktree, avec Flutter existant :
`C:\Users\Utilisateur\mecano-mobile\.flutter\bin\flutter.bat`.

```text
flutter --no-version-check test --no-pub --dart-define=no_default_http_client=true --reporter=json --concurrency=1 test/customer/delivery_confirmation_presentation_test.dart
flutter --no-version-check test --no-pub --dart-define=no_default_http_client=true --reporter=json --concurrency=1 [les sept suites explicites du tableau ci-dessus]
flutter --no-version-check analyze --no-pub lib/screens/delivery/delivery_request_flow_screen.dart test/customer/delivery_confirmation_presentation_test.dart test/customer/delivery_contact_validation_test.dart
dart format --output=none --set-exit-if-changed lib/screens/delivery/delivery_request_flow_screen.dart test/customer/delivery_confirmation_presentation_test.dart
git diff --check
```

Les scripts `run-before.ps1`, `run-after.ps1`, `run-final.ps1`, `run-regression.ps1` et `quality-final.ps1` conservent les arguments complets.
Analyse finale : **3 fichiers, aucun problème**, code0.
Format final : **2 fichiers, aucun changement**, code0.
Diff check après registre : **code0**. Avertissement Git LF→CRLF observé, aucune erreur de whitespace.
Index toujours vide.

## 8. Sécurité et intégrité financière

Services exclusivement fictifs : TestBookingApi/ConfirmationApi, MemoryBookingStorage, BookingTestAuth sans backend configuré. Aucun Firebase.initializeApp, émulateur ou service métier réel.
Pas de clic externe, Google Places/Routes, carte OSM, upload, GPS, Stripe Sandbox/LIVE ou notification.
HTTP par défaut désactivé et contrôlé ; neutralisation HTTP du binding Flutter et contrôle HttpOverrides. **Pas de confinement réseau global Windows revendiqué.** Détail dans ISOLATION.md.

Les montants 123.45/100/5/18.45 sont des fixtures, pas des devis officiels validés.
La comparaison des empreintes et du diff confirme :
- aucun fichier serveur, Firestore rules, GPS, Stripe, snapshot, ledger ou tarification modifié ;
- les méthodes _refreshCard/_setupCard/_confirm et les coordonnées sont conservées ;
- aucune nouvelle validation de la concordance financière réelle devis=mission=snapshot=Stripe n’est revendiquée.

## 9. Fermetures et registre

| Fiche | Décision |
|---|---|
| P2-I-01 | FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ |
| P2-I-02 | FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ |

Fermetures appliquées conformément à l’autorisation conditionnelle de la mission.
Registre unique actualisé, statuts antérieurs et preuves conservés : `docs/audit/REGISTRE_BOGUES_MOVIK.md`.

**Décompte recalculé : P0 0 / P1 2 / P2 16 ; 27 fiches conservées, 18 non fermées.**
P1-HOME-001 et P1-COPY-001 restent ouverts.
Aucune autre fermeture, aucun retrait de P3 historique ni de prérequis du pilote. Test autonome de tuiles1.3L toujours BLOQUÉ ET REPORTÉ.

## 10. Fichiers à sauvegarder ultérieurement

Trois fichiers de travail :
1. `lib/screens/delivery/delivery_request_flow_screen.dart`
2. `test/customer/delivery_confirmation_presentation_test.dart`
3. `docs/audit/REGISTRE_BOGUES_MOVIK.md`

Preuves essentielles proposées, toutes sous `artifacts/corrections-1-3M-N-20261010-d927c861/` :
4. `CHECKPOINT_MOVIK_1_3M_N_P2_I_01_I_02.md`
5. `RESULTATS.json`
6. `CONTROLES_FINAUX.json`
7. `ISOLATION.md`
8. `run-before.ps1`
9. `run-after.ps1`
10. `run-final.ps1`
11. `run-regression.ps1`
12. `analyze-final.txt`
13. `format-final.txt`
14. `diff-check-final.txt`

Liste et empreintes dans `MANIFESTE_SAUVEGARDE_1_3M_N.json`.
Journaux bruts, sauvegardes avant modification, scripts de patch/diagnostic, inventaire volumineux et preuves antérieures conservés localement, exclus de cette proposition. Aucun cache, build, secret, fichier personnel ou configuration inclus.

## 11. Limites et prochaine action

Non testés : navigateur Chrome, build Web, téléphones réels, fuseaux d’appareils autres que celui du runner, provider de paiement réel, Firebase déployé, backend financier réel.
La gestion d’erreur existante de getBookingCardStatus n’a pas été refondue. Une préparation non confirmée n’est plus présentée comme une carte enregistrée.
Les libellés de conditions renvoyés par le serveur sont simulés ; leur contenu réel n’est pas validé.

**Prochaine action unique : approuver la sauvegarde Git locale de cette sélection.**
Aucun commit effectué. P2-J-01 et toutes les autres corrections attendent une nouvelle instruction.
