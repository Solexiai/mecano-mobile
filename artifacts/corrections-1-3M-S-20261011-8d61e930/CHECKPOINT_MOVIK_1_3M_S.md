# CHECKPOINT MOVI-K — 1.3M-S — P2-G-02

Date : 11 octobre 2026 (America/Toronto). Statut : **TERMINÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ**.

## 1. Git et reprise

- Worktree : C:\Users\Utilisateur\movik-gps-history-fix-20261009.
- Branche : fix/gps-client-history-scope-20261009.
- HEAD initial vérifié : da3f1d459c3205e55aec3f1d972aab45b4fa7423.
- Deux commits R confirmés : 7fc5a04cdf3ad421cccfa78b3cded73666903fb4 (HOME), puis da3f1d459c3205e55aec3f1d972aab45b4fa7423 (COPY).
- Index et fichiers suivis propres au départ ; preuves non suivies conservées. Le relevé initial inventorie 2 978 fichiers avec SHA256, dont le script de relevé créé pour cette intervention. Aucun fichier préexistant supprimé.
- Ce checkpoint est préparé pour le commit local autorisé, après validation. Le HEAD final et l'index après commit seront consignés dans COMMIT_LOCAL.json et CHECKPOINT_MOVIK_1_3M_S_FINAL.md, sans créer un second commit uniquement pour inscrire le hash du premier.

## 2. Diagnostic démontré

Le vrai DeliveryRequestFlowScreen réutilise _quoteSummary pour « Mon prix » et « Confirmation et paiement ». À la base auditée :
- ligne 1542 : toStringAsFixed(2) suivi de CAD, sans locale ;
- ligne 1596 : toStringAsFixed(1) suivi de km, sans locale ;
- un total absent provoquait « type 'Null' is not a subtype of type 'num' in type cast ».

Les tests avant correction affichent notamment **1234.50 CAD** et **10.0 km** en français. Résultat initial : **0 réussi / 35 échoués / 0 ignoré**. Les erreurs initiales sont conservées, pas transformées en réussites.

Source des unités vérifiée en lecture seule : functions/src/functions/calculateDeliveryQuote.ts, lignes 254–260 et 340–350. Le serveur renvoie customerTotal en unités majeures après normalisation depuis les cents ; distanceKm est déjà en kilomètres. Le client n'a pas à recalculer le montant.

## 3. Correction minimale

- Extension du formatteur de présentation existant formatMajorAmount : locale optionnelle ; anciens appels sans locale inchangés pour les valeurs valides.
- Devis/confirmation : FR fr_CA, EN en_CA, ES es, monnaie CAD explicitement identifiable.
- Nouvelle aide formatDistanceKm dans le même module de présentation : km conservés, au plus une décimale, suppression du zéro décimal inutile.
- Donnée absente/invalide : tiret long — ; aucun zéro ou montant inventé. Les objets sources restent intacts. Ce comportement d'affichage ne modifie pas les règles serveur de validité du devis.
- Ventilation : remplacement local du Row rigide par un Wrap contraint. Les six débordements à 200 % du premier retest sont ainsi corrigés, sans réduction du texte ni refonte.
- intl 0.20.3 était déjà une dépendance transitive disponible dans le cache. Déclaration directe et résolution offline ; aucune version ni empreinte de package changée.

| Source | Français | Anglais | Espagnol |
|---|---|---|---|
| 1234.5 dollars CAD | 1 234,50 $ CA | CA$1,234.50 | 1.234,50 CA$ |
| 10 kilomètres | 10 km | 10 km | 10 km |
| 10.5 kilomètres | 10,5 km | 10.5 km | 10,5 km |

Les espaces de groupement monétaire sont insécables selon intl.

## 4. Exécutions et résultats exacts

| Exécution | Réussis | Échoués | Ignorés | Conclusion |
|---|---:|---:|---:|---|
| before | 0 | 35 | 0 | Défaut reproduit avant modification produit |
| after-1 | 35 | 6 | 0 | Formats corrigés ; débordements à 200 % encore présents |
| after-2 | 47 | 0 | 0 | Validation ciblée finale |
| regression | 97 | 0 | 0 | Non-régressions sélectionnées |

**Bilan final : 144 tests distincts réussis, 0 échec, 0 ignoré.** Les anciennes exécutions ne sont pas additionnées à ce total.

Détail final :
- delivery_quote_display_test.dart : 41 tests widget.
- money_format_localization_test.dart : 6 tests de présentation et compatibilité.
- delivery_confirmation_presentation_test.dart : 54.
- delivery_request_flow_double_submit_test.dart : 2.
- delivery_request_flow_error_messages_test.dart : 4.
- delivery_request_draft_resume_test.dart : 4.
- booking_service_availability_test.dart : 2.
- delivery_dimension_display_test.dart : 20.
- delivery_address_autocomplete_test.dart : 11.

Trois tests historiques contenant l'ancienne chaîne « 123.45 CAD » ont été adaptés à la sortie localisée attendue. Leurs assertions de données, erreurs, précision et navigation sont conservées.

## 5. Langues et responsive

Vrais widgets Flutter, FR/EN/ES, étapes prix et confirmation :
- 375 × 812, 430 × 932, 1440 × 900 ;
- mobile 375 × 812 avec texte à 200 % ;
- six contrôles supplémentaires de grands montants à 200 % (deux étapes, trois langues).

Les tests vérifient les textes complets, l'absence de dépassement des RenderParagraph et d'exception Flutter. Les montants jusqu'à 1 234 567,89, valeurs négatives, zéros, absences et distances jusqu'à 12 345,67 sont couverts. Changement de langue sur le même état du vrai widget, navigation, reconstruction et remise affichée sont testés.

Il s'agit de rendu widget automatisé, **pas de validation visuelle Chrome, ni de téléphone physique**. Aucune capture PNG ou preview navigateur n'est annoncée.

## 6. Conservation métier

- Égalité JSON du devis fictif avant/après affichage, navigation, langue, reconstruction et sauvegardes vers l'API simulée.
- Total indépendant des lignes de ventilation dans la fixture : l'interface affiche le total reçu, sans le recomposer.
- distanceKm=10.54 demeure exactement 10.54 dans la source, alors que la chaîne française affiche 10,5 km.
- Un test conserve explicitement customerTotalMinor=123450 dans la fixture ; aucune conversion d'affichage n'écrit dans celle-ci.
- La confirmation simulée transmet le même quoteId, chargement, coordonnées et adresses ; aucun total ni distance reformatée ajouté au payload. Double clic : une seule demande fictive.
- Les corps _quote, _refreshCard, _setupCard, _confirm sont strictement inchangés par comparaison et SHA256.
- 218 fichiers GPS/serveur/financiers protégés sont inchangés ; aucune modification des fonctions, règles, tarifs, commissions, taxes, Stripe, snapshots ou ledger.

Cela prouve la non-mutation dans le périmètre simulé ; **pas une nouvelle validation du calcul serveur, de l'égalité mission/snapshot/Stripe en production ou d'un paiement**.

## 7. Qualité

- Analyse Flutter finale ciblée sur les sept fichiers Dart modifiés/créés : **No issues found**, code 0.
- Première analyse : 15 infos de style dans le nouveau test ; corrigées, journal historique conservé.
- Dart format : sept fichiers, zéro changement lors du contrôle final, code 0.
- git diff --check : code 0 ; avertissements LF/CRLF de la configuration existante, aucune erreur de whitespace.
- Contrôle final des empreintes, du périmètre et des motifs de secrets : INTEGRITE.json. Aucun fichier protégé changé, aucune suppression, aucun changement préexistant inattendu ni motif de secret détecté dans la sélection inspectée.

## 8. Fichiers produit, tests et registre à sauvegarder

1. lib/finance/presentation/money_format.dart
2. lib/screens/delivery/delivery_request_flow_screen.dart
3. pubspec.yaml
4. pubspec.lock
5. test/customer/delivery_quote_display_test.dart (nouveau)
6. test/finance/money_format_localization_test.dart (nouveau)
7. test/customer/delivery_address_autocomplete_test.dart (attente monétaire)
8. test/customer/delivery_dimension_display_test.dart (attentes monétaires)
9. test/customer/delivery_request_flow_error_messages_test.dart (attente monétaire)
10. docs/audit/REGISTRE_BOGUES_MOVIK.md

Preuves essentielles sélectionnées dans ce dossier : ce checkpoint, RESULTATS_TESTS.json, INTEGRITE.json, REGISTRE_DECOMPTE.json, ISOLATION.md, COMMANDES.md, ECHECS_REPRODUITS.md et TEST_REPRODUCTION_AVANT.dart.txt.

Exclus du commit mais conservés localement : journaux JSONL complets, sauvegardes .before, scripts intermédiaires, relevé exhaustif initial, fichiers de build/cache, anciennes preuves non suivies et rapport final post-commit. Aucun secret ni donnée client réelle dans les fixtures.

Message prévu : **fix(customer): localize quote amounts and distances**.

## 9. Registre et limites

**P2-G-02 : FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ**, conformément à l'autorisation de cette étape.

Décompte recalculé sur les **27 fiches conservées : P0 0 / P1 0 / P2 9 ouverts**. Aucun autre dossier fermé. Historiques, P3 et prérequis du pilote conservés.

P2 restants : P2-I18N-001, P2-I18N-002, P2-BUILD-001, P2-COPY-001, P2-L-01, GAP-M-05, GAP-M-06, GAP-S-02, GAP-S-04.

Les autres écrans finance/admin/chauffeur conservent leur format antérieur sans locale ; ils n'ont pas fait l'objet d'une migration ou d'un audit de localisation global dans cette intervention. Les consommateurs existants du helper gardent la sortie antérieure, vérifiée par test de compatibilité.

Aucun test serveur, émulateur, GPS, Stripe Sandbox/LIVE, Chrome, build Web ou production exécuté. Aucun push, merge ou déploiement. **1.3L reste BLOQUÉ ET REPORTÉ** ; l'isolation des doublures de ces tests ne vaut pas confinement réseau du système d'exploitation.

## 10. Prochaine séquence unique proposée

Réconcilier **P2-COPY-001 (ancienne présence de Leboncoin)** à partir de ses preuves historiques, sans refaire les corrections déjà présentes. Cette proposition n'est pas commencée ici.

Arrêt au checkpoint 1.3M-S.
