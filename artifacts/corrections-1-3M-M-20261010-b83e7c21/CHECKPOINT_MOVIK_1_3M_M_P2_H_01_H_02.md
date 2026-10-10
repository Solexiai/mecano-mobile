# CHECKPOINT MOVI-K — 1.3M-M
## CORRECTION P2-H-01 / P2-H-02

Date : 10 octobre 2026, America/Toronto. Dernier contrôle Git : 10:06:27 (14:06:27 UTC).
**Verdict : corrections locales terminées et validées dans le périmètre simulé ; H-01 et H-02 restent NON FERMÉS, NON DÉPLOYÉS.**

## 1. Reprise et état Git

- Dépôt : Solexiai/mecano-mobile.
- Worktree exclusivement utilisé : C:\Users\Utilisateur\movik-gps-history-fix-20261009.
- Branche initiale et finale : fix/gps-client-history-scope-20261009.
- HEAD initial et final : **2df26054e0fb3491cdc75cfbef3f551fab07e1f5**.
- Quatrième commit GPS présent : 2df2605, « fix(gps): distinguish live tracking stream errors from missing signal ».
- Commits précédents relevés : 980a9da (identité/fraîcheur), 7a0d60f (autorité/concurrence/libération).
- Initial : aucun diff suivi, index vide ; 1972 fichiers non suivis inventoriés, tous sous artifacts. 2552 fichiers préexistants suivis ou non ignorés empreintés.
- Final : deux fichiers suivis modifiés et un test nouveau ; index toujours vide, aucun fichier préexistant manquant, 2550 empreintes préexistantes inchangées.
- Les seuls fichiers préexistants inventoriés modifiés sont le formulaire et le registre ; les caches ignorés de Flutter ne font pas partie de cet inventaire.
- Statuts complets, inventaires et empreintes : git-initial.json et git-final.json. Résumé contrôlé : CONTROLES_FINAUX.json, safe=true.
- Aucun changement de branche, reset, stash, clean, commit, push, merge ou déploiement. Aucun autre worktree modifié.

## 2. Composants et contrat réels

Le formulaire « Mes coordonnées » est **DeliveryRequestFlowScreen._details**, dans lib/screens/delivery/delivery_request_flow_screen.dart. Il contient deux noms, deux téléphones et les instructions facultatives.
Les tests existants utilisent test/helpers/booking_test_harness.dart ; le nouveau test réutilise BookingTestAuth, MemoryBookingStorage, TestBookingApi, testDraft et pumpBooking.

Source serveur examinée, non modifiée : functions/src/lib/bookingServer.ts:66–71, normalizeContacts. Appel réel repéré dans functions/src/functions/createDeliveryRequest.ts:240.

| Champ | Contrat serveur lu | État frontend initial | État corrigé |
|---|---|---|---|
| Téléphones | Au moins 8 chiffres ASCII ; 8–25 caractères parmi chiffres, espaces, parenthèses, tirets ; + initial optionnel en dehors de cette longueur | Regex seule ; maxLength 120 | Même regex + au moins 8 chiffres ; compteur 25 ou 26 avec + initial |
| Noms | Non vides après trim ; longueur maximum 120 | Requis, maxLength 120 | Inchangé |
| Instructions | Chaîne, maximum 1200, vide autorisé | Facultatif, maxLength 1200 | Inchangé ; libellé raccourci |

**Le + initial est optionnel et ne compte pas dans les 25 caractères de la regex existante.** Le correctif conserve ainsi le format international déjà permis, sans imposer un numéro canadien.
Aucun validateur partagé concurrent trouvé pour ce champ. La correction complète le validateur existant ; elle ne modifie pas le contrat serveur.

## 3. Reproduction avant correction

Exécution complète contre le code initial : **23 réussis, 23 échoués, 0 ignoré** (RESULT-before.jsonl).

Défauts démontrés :
- Les valeurs --------, ()----() et 1------- permettent de passer à la confirmation sur chacun des deux téléphones malgré moins de huit chiffres.
- Le contrôle du compteur attend 25 mais lit **120**.
- Les consignes de format et l’explicitation des quatre champs obligatoires manquent.
- Le test de navigation avec correction d’une valeur invalide échoue d’abord parce que la valeur invalide permet déjà d’avancer.

Les formats valides, les champs vides, les longueurs excessives et plusieurs non-régressions passaient déjà : ils n’ont pas été présentés comme de nouveaux bogues.
Un test supplémentaire exigeant le message explicatif complet a été exécuté avant correction : **0 réussi, 1 échoué**, preuve RESULT-before-guidance.jsonl.

## 4. Corrections apportées

### P2-H-01 — téléphone

- Ajout du contrôle du nombre de chiffres à la regex existante.
- Refus des chaînes de séparateurs et des numéros insuffisants.
- Maintien des espaces, tirets, parenthèses et du + initial autorisés.
- Aucun retrait ou transformation des séparateurs avant transmission au faux serveur.
- Valeurs invalides conservées dans le champ et le brouillon pour correction.

### P2-H-02 — compteur et consignes

- Téléphone : maximum affiché 25, ou 26 avec + au début.
- La valeur collée trop longue n’est pas tronquée silencieusement ; elle reste modifiable et bloque la progression.
- Consignes et erreur détaillée FR/EN/ES via le mécanisme tr déjà utilisé dans cet écran.
- Obligation des deux noms et deux téléphones explicitée ; instructions indiquées facultatives.
- Libellés au-dessus des champs, avec étiquettes sémantiques, pour éviter leur troncature et chevauchement à 200 %.
- Messages autorisés sur plusieurs lignes ; aucune refonte des autres écrans.

Localisation finale : _contactPhoneHint vers ligne 1563, indications vers 1619, libellés vers 1675, validation vers 1713–1716.

## 5. Fichiers modifiés

1. lib/screens/delivery/delivery_request_flow_screen.dart — unique fichier produit modifié, imports et section des coordonnées.
2. test/customer/delivery_contact_validation_test.dart — nouveau test permanent.
3. docs/audit/REGISTRE_BOGUES_MOVIK.md — fiches H-01/H-02, historique, preuves ; aucune fermeture.

Le contrôle du code avant la section coordonnées et à partir de _confirmation démontre leur conservation exacte après normalisation des fins de ligne et exclusion du seul nouvel import services.
Aucun fichier GPS, modèle GPS, fonction serveur, règle Firestore ou fichier financier modifié. Tarifs, commission, Stripe, snapshots et ledger préservés.

## 6. Exécutions réellement effectuées

Les nombres ci-dessous désignent les cas terminés ; une erreur de chargement est distinguée d’un test applicatif échoué. Aucun skip.

| Journal RESULT-*.jsonl | Réussis | Échoués | Ignorés | Explication |
|---|---:|---:|---:|---|
| isolation | 0 | 0 | 0 | Une erreur de compilation/chargement du nouveau test |
| isolation-v2 | 1 | 0 | 0 | Sonde HTTP/Firebase après correction du test |
| before | 23 | 23 | 0 | Reproduction complète avant correction |
| before-guidance | 0 | 1 | 0 | Message explicatif absent avant correction |
| after | 34 | 12 | 0 | Validation fonctionnelle corrigée, problèmes de mise en page restants |
| after-labels | 0 | 1 | 0 | Message encore tronqué à 200 % |
| after-messages | 0 | 1 | 0 | Libellé instructions encore tronqué |
| after-optional | 1 | 0 | 0 | Sonde mobile FR ; antérieure au contrôle renforcé de chevauchement |
| final | 40 | 6 | 0 | Contrôle renforcé révélant le chevauchement des libellés flottants à 200 % |
| after-static-labels | 1 | 0 | 0 | Sonde après positionnement des libellés au-dessus |
| **final-v2** | **46** | **0** | **0** | **Dernière suite ciblée complète** |
| **regression** | **20** | **0** | **0** | **Dernières non-régressions existantes** |

**Total final distinct : 66 réussis, 0 échoué, 0 ignoré.**
Les essais intermédiaires ne sont pas additionnés au résultat final ; leurs journaux restent conservés.

Incidents d’outillage documentés :
- Le nouveau test tentait initialement de lire maxLength/decoration sur TextFormField ; lecture corrigée sur le TextField interne, sans retrait des assertions.
- La mesure brute d’un RenderParagraph flottant ne tenait pas compte de sa transformation ; les dimensions globales affichées sont maintenant vérifiées. Le contrôle de troncature reste présent ; un contrôle de chevauchement supplémentaire a révélé les six échecs de « final ».
- Une garde d’ancre a arrêté un premier script de modification sans écriture. Une substitution JavaScript interprétant le motif dollar-apostrophe a ensuite produit un source intermédiaire invalide : formatage bloqué et aucun test applicatif exécuté sur ce source. Remplacement littéral corrigé, état intermédiaire sauvegardé, diff final limité contrôlé.
- La première tentative d’écriture du script d’inventaire précédait la création du dossier de preuves : ENOENT/MODULE_NOT_FOUND, puis dossier créé et inventaire réussi. Aucun fichier préexistant touché par cet incident.

## 7. Couverture et non-régressions

Les 46 nouveaux cas couvrent :
- Les deux téléphones : tirets seuls, espaces seuls, parenthèses/tirets, sept chiffres, un chiffre complété par tirets, lettres et séparateurs interdits.
- Les quatre champs obligatoires vides, leur correction et la progression.
- Huit chiffres, formats locaux avec séparateurs, indicatif international, bornes de 25 et 26 avec +.
- Dépassement des deux limites, copier-coller non tronqué, erreur puis correction.
- Noms et instructions : limites ASCII existantes et conservation du comportement de troncature antérieur ; instructions vides acceptées.
- Retour vers Mon prix, reprise des coordonnées, recréation du widget, conservation des objets et du devis fictif.
- Confirmation exclusivement simulée, un appel createDeliveryRequest, coordonnées transmises identiques et quoteId inchangé.
- FR/EN/ES et géométrie mobile/desktop détaillées ci-dessous.
- Sonde d’isolation.

Suites existantes exécutées (20 cas) :
- delivery_request_draft_resume_test.dart : 4.
- delivery_request_draft_test.dart : 6.
- delivery_request_auth_navigation_test.dart : 2.
- delivery_request_flow_double_submit_test.dart : 2.
- delivery_request_flow_error_messages_test.dart : 4.
- booking_service_availability_test.dart : 2.

Les suites GPS n’ont pas été relancées : aucun de leurs fichiers ni composant partagé n’a changé ; leurs empreintes sont conservées. Aucun dossier GPS fermé n’est rouvert.

## 8. Langues et affichage

**Validation par widgets Flutter réels, pas par Chrome.**

| Format | FR | EN | ES |
|---|---|---|---|
| 375 × 812, 100 % | Réussi | Réussi | Réussi |
| 430 × 932, 100 % | Réussi | Réussi | Réussi |
| 1440 × 900, 100 % | Réussi | Réussi | Réussi |
| 375 × 812, 200 % | Réussi | Réussi | Réussi |
| 430 × 932, 200 % | Réussi | Réussi | Réussi |

Chaque cas affiche les consignes puis les erreurs, vérifie l’absence de texte tronqué dans les paragraphes contrôlés, les limites horizontales, l’absence de chevauchement libellé/champ et champs voisins, puis corrige les téléphones et atteint la confirmation.
Aucune capture PNG ou inspection visuelle Chrome revendiquée. Ce sont des vérifications automatisées de rendu et de géométrie, avec la police du harnais Flutter.

## 9. Qualité et commandes

- Analyse ciblée : **No issues found!**, code 0.
- Format : **2 files, 0 changed**, code 0.
- git diff --check : code 0, y compris après actualisation du registre.
- Index final vide ; HEAD inchangé.

Commandes réellement exécutées, scripts complets conservés :
- run-tests.ps1 : flutter.bat --no-version-check test --no-pub --dart-define=no_default_http_client=true --reporter=json --concurrency=1, avec la suite ciblée et, pour certaines sondes, --plain-name.
- run-final-v2.ps1 : suite ciblée finale, six suites de non-régression puis analyse/format/diff.
- flutter.bat --no-version-check analyze --no-pub lib/screens/delivery/delivery_request_flow_screen.dart test/customer/delivery_contact_validation_test.dart test/helpers/booking_test_harness.dart.
- dart.exe format --output=none --set-exit-if-changed sur les deux fichiers Dart modifiés.
- verify-final.cjs : comparaison des empreintes, index, HEAD, diff et sections hors coordonnées.

SDK local existant : C:\Users\Utilisateur\mecano-mobile\.flutter.
Aucune installation, téléchargement, compilation Web ou exécution de test serveur.

## 10. Isolation et limites

Preuve détaillée : ISOLATION.md et code du harnais examiné.
- Authentification, stockage, brouillon, compte, devis et réponses serveur fictifs.
- TestBookingApi ne délègue aucun appel réseau ; nouvelle sous-classe restreint les méthodes attendues.
- Aucun Firebase initialisé ; Firebase.apps vide vérifié.
- Client HTTP par défaut désactivé, interception HTTP des tests Flutter ; sonde IO limitée à sa zone de test, pas présentée comme un pare-feu OS.
- Aucun appel à Firebase Production, Stripe, Google Places/Routes, OpenStreetMap, notification ou GPS physique. Aucun émulateur nécessaire.
- Aucune action photo, lien juridique externe ou enregistrement de carte exercée.
- Le faux montant et test_mission ne prouvent ni devis serveur réel, ni paiement, ni réservation réelle.
- Le contrat serveur a été lu ; son chemin déployé n’a pas été exécuté.
- Recréation du widget validée ; rafraîchissement Chrome réel non testé.
- Téléphone physique, lecteur d’écran, joignabilité réelle et cas Unicode extrêmes des limites de noms ne sont pas certifiés par ces tests.
- **1.3L, test autonome de tuiles, reste BLOQUÉ ET REPORTÉ.**
- Aucun défaut restant démontré dans les assertions finales H-01/H-02 ; aucune garantie globale de lancement.

## 11. Registre et décisions

Registre central unique : docs/audit/REGISTRE_BOGUES_MOVIK.md.
Les statuts historiques, toutes les anomalies P3, les prérequis du pilote et les reports sont conservés.

| Fiche | Statut actuel | Décision proposée |
|---|---|---|
| P2-H-01 | CORRIGÉ ET VALIDÉ DANS LE PÉRIMÈTRE SIMULÉ — NON FERMÉ — NON DÉPLOYÉ | Fermeture documentaire limitée recommandée |
| P2-H-02 | CORRIGÉ ET VALIDÉ DANS LE PÉRIMÈTRE SIMULÉ — NON FERMÉ — NON DÉPLOYÉ | Fermeture documentaire limitée recommandée |

Décompte recalculé : **P0 0, P1 2, P2 20 ouverts**.
27 entrées, 5 fermées antérieurement, 22 ouvertes. Aucune fermeture appliquée dans cette intervention.
P1 ouverts : P1-HOME-001 et P1-COPY-001. P2-I-01/I-02 et autres fiches non traités.

## 12. Liste exacte proposée pour un futur commit

Chemins relatifs au worktree, **15 fichiers proposés**, aucune mise à l’index :
1. lib/screens/delivery/delivery_request_flow_screen.dart
2. test/customer/delivery_contact_validation_test.dart
3. docs/audit/REGISTRE_BOGUES_MOVIK.md
4. artifacts/corrections-1-3M-M-20261010-b83e7c21/CHECKPOINT_MOVIK_1_3M_M_P2_H_01_H_02.md
5. artifacts/corrections-1-3M-M-20261010-b83e7c21/ISOLATION.md
6. artifacts/corrections-1-3M-M-20261010-b83e7c21/RESULTATS.json
7. artifacts/corrections-1-3M-M-20261010-b83e7c21/RESULT-before.jsonl
8. artifacts/corrections-1-3M-M-20261010-b83e7c21/RESULT-before-guidance.jsonl
9. artifacts/corrections-1-3M-M-20261010-b83e7c21/RESULT-final-v2.jsonl
10. artifacts/corrections-1-3M-M-20261010-b83e7c21/RESULT-regression.jsonl
11. artifacts/corrections-1-3M-M-20261010-b83e7c21/analyze.txt
12. artifacts/corrections-1-3M-M-20261010-b83e7c21/format.txt
13. artifacts/corrections-1-3M-M-20261010-b83e7c21/quality-exits.json
14. artifacts/corrections-1-3M-M-20261010-b83e7c21/CONTROLES_FINAUX.json
15. artifacts/corrections-1-3M-M-20261010-b83e7c21/MANIFESTE_SAUVEGARDE_1_3M_M.json

Le manifeste contient tailles et SHA-256 des fichiers proposés, sauf sa propre empreinte.
Les journaux intermédiaires, sauvegardes et scripts restent conservés dans le dossier de preuves, mais ne sont pas proposés au commit. Aucun cache, dépendance, build, donnée personnelle ou ancien artifact sans lien inclus.
Une éventuelle fermeture documentaire modifierait le registre ; ses empreintes devront être actualisées avant tout commit autorisé.

## 13. Prochaine action unique

**Obtenir l’approbation explicite de Daniel pour la fermeture documentaire limitée de P2-H-01 et P2-H-02.**
Aucun commit sans autorisation distincte. Aucune autre correction commencée ; arrêt au checkpoint 1.3M-M.

## Sources et preuves — 10 octobre 2026

Dossier canonique :
C:\Users\Utilisateur\movik-gps-history-fix-20261009\artifacts\corrections-1-3M-M-20261010-b83e7c21

- Code réel au HEAD cité : formulaire, normalizeContacts, createDeliveryRequest, BookingDraft et harnais ; diff-final.patch pour la correction.
- git-initial.json, git-final.json, CONTROLES_FINAUX.json : états et intégrité.
- RESULT-before.jsonl, RESULT-before-guidance.jsonl : défauts avant correction.
- RESULT-final-v2.jsonl et RESULT-regression.jsonl : 66 succès finaux distincts.
- Autres RESULT-*.jsonl, RESULTATS.json et result-counts.json : historique complet des exécutions, échecs non masqués.
- analyze.txt, format.txt, quality-exits.json, diff-check.txt : qualité.
- registry-counts.json et registre maître : fiches, historique et décompte.
