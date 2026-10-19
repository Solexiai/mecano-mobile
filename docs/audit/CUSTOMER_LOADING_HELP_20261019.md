# Movi-K — aide au chargement et au déchargement
Intervention du 19 octobre 2026. Verdict : prêt à valider en développement ; non déployé.

## État et sources
- Dépôt existant : Solexiai/mecano-mobile.
- Worktree : C:/Users/Utilisateur/movik-admin-action-center-20261019.
- Base vérifiée : 0e3579207bde0bcdadb43ee7b8b6908de728a97d. Index vide, aucun fichier suivi modifié avant intervention ; artifacts préexistants conservés.
- Branche dédiée : feat/customer-loading-help-20261019.
- Cadrage : demande et deux captures fournies par Daniel le 19 octobre 2026.
- Sources techniques lues : lib/services/booking/booking_draft.dart ; lib/screens/delivery/delivery_request_flow_screen.dart ; functions/src/lib/booking.ts ; functions/src/lib/quoteBeforeAssignment.ts ; functions/src/functions/bookingJourney.ts ; lib/widgets/address_autocomplete_field.dart ; lib/core/app_theme.dart.
- État antérieur : le champ help était initialisé à true, affiché dans un panneau replié et décrit comme aide sur place. Le serveur l’utilisait déjà comme needsLoading / needsUnloading dans les options tarifaires. Les réponses étage et escaliers avaient aussi des valeurs initiales sans confirmation.
- Une copie détachée du commit de base, C:/Users/Utilisateur/movik-help-before-20261019, sert uniquement au rendu avant. Aucun autre worktree préexistant modifié.

## Réalisation
Deux blocs toujours dépliés sous les adresses, chacun avec ses propres cartes « Sans aide Movi-K » et « Avec aide Movi-K ». Fond bleu pâle, cartes blanches, contour et indicateur de sélection, clic sur toute la carte et activation au clavier. Deux petits pictogrammes vectoriels assortis sont dessinés par Flutter, sans dépendance externe.

Aucun choix d’aide ni accès factuel n’est initialisé pour une nouvelle demande. Les booléens help déjà enregistrés dans un brouillon sont conservés dans leur sens tarifaire historique ; ils ne sont jamais convertis en présence d’une aide sur place. Les anciens étages et escaliers n’ont pas de preuve de confirmation : le résumé indique « Accès à préciser » et demande une confirmation avant un nouveau devis. Un devis historique verrouillé n’est pas réécrit.

Les réponses séparées onsite_help (oui/non/à confirmer), inside, customer_handles_inside et notes sont conservées dans le brouillon et normalisées dans le contexte serveur du devis. L’aide sur place ne déduit aucun nombre de manutentionnaires. Intérieur + sans aide Movi-K demande de confirmer que le client organise ce déplacement, sans sélectionner ni facturer un service automatiquement.

Les panneaux « Accès au ramassage » / « Accès à la livraison » restent indépendants. Niveau, marches et ascenseur sont explicitement renseignés ; marches et ascenseur peuvent être présents simultanément. Fermer le panneau conserve les réponses. Un nouveau devis nécessite les réponses existantes utilisées dans le calcul ; aucune configuration tarifaire supplémentaire n’a été ajoutée.

L’adresse restaurée est reconnue par le champ d’autocomplétion : le message de début de saisie disparaît ; le champ reste modifiable et toute édition invalide les coordonnées et le devis.

Le bouton partagé devient « Obtenir mon prix » (équivalents EN/ES). Le panneau « Dimensions et précautions (facultatif) » est retiré pour les objets ordinaires, sans effacer leurs données enregistrées. Les précisions restent accessibles pour les objets spéciaux, car le contrat serveur existant les exige. Aucun contournement de cette revue.

## Intégrité financière
Le champ help conserve exactement sa correspondance avec les frais de chargement/déchargement existants. La modification d’une réponse utilise _changed / BookingDraft.changed : effacement du devis local et de l’acceptation, puis nouveau calcul serveur et présentation du montant officiel. Ni tarifs, commission, taxes, seuils, Stripe, ledger, payouts, ni formules de manutention modifiés.

La normalisation ajoute uniquement les nouvelles métadonnées validées lorsqu’une version de réponses est présente. Les anciens contrats sans cette version gardent leur forme exacte. Le client et les fonctions utilisant ce contrat doivent être publiés ensemble lors d’une future autorisation ; ne pas publier seulement l’interface avec un serveur qui ignorerait ces réponses.

## Vérification réelle effectuée localement
- Reproduction initiale : deux assertions Flutter échouent (aide présélectionnée, blocs absents). Journal initial.log conservé.
- Reproduction serveur : 7 échecs / 10 succès avant correction, notamment métadonnées perdues et contradiction acceptée. server-initial.log conservé.
- 96 scénarios Flutter distincts réussis dans leurs dernières exécutions. La suite finale avait 95 succès et un défaut de nettoyage du test sémantique ; les 18 scénarios d’interaction/rendu concernés ont ensuite tous réussi. Ne pas additionner les suites recouvrantes.
- 68 tests serveur simulés réussis : bookingAccessAnswers, booking, quoteIntegrity, quoteBeforeAssignmentCallable, quoteBeforeAssignmentJourney.
- Tests UI : indépendance, questions conditionnelles, sauvegarde/recréation, retour, transmission au devis, devis invalidé, contradiction clarifiée sans frais automatiques, coexistence escaliers/ascenseur, clavier, sémantique de sélection, FR/EN/ES, largeur 375/1440 et texte à 200 %.
- Non-régression : préparation du brouillon indisponibilité du service, photo, adresses, navigation vers connexion, reprise, prix avant affectation.
- TypeScript --noEmit, ESLint du fichier serveur, Flutter analyze intégral, git diff --check et build Web release réussis.
- Les erreurs intermédiaires (commande, rendu des polices et assertions) restent dans les journaux. Aucun test simulé n’est une validation en production.

## Captures
Rendus locaux Flutter du véritable écran, données fictives, thème partagé Movi-K. Ce ne sont pas des captures de production ni un test Chrome réel. Roboto est chargé depuis le SDK pour rendre les textes du test lisibles ; les styles de boutons gardent leurs propriétés, avec famille de police explicite dans le test uniquement.
- Avant mobile : artifacts/customer-loading-help-20261019/before-375.png
- Après mobile : artifacts/customer-loading-help-20261019/after-375.png
- Avant ordinateur : artifacts/customer-loading-help-20261019/before-1440.png
- Après ordinateur : artifacts/customer-loading-help-20261019/after-1440.png
Le mobile nécessite le défilement normal pour consulter l’ensemble des deux blocs.

## Fichiers modifiés
Production :
- lib/widgets/booking_access_section.dart (nouveau)
- lib/screens/delivery/delivery_request_flow_screen.dart
- lib/services/booking/booking_draft.dart
- lib/widgets/address_autocomplete_field.dart
- lib/widgets/booking_load_summary.dart
- lib/widgets/photo_booking_item.dart
- lib/l10n/home_copy.dart
- functions/src/lib/booking.ts

Tests :
- functions/test/unit/bookingAccessAnswers.test.ts (nouveau)
- test/customer/loading_help_test.dart (nouveau)
- test/customer/loading_help_interaction_test.dart (nouveau)
- test/helpers/booking_test_harness.dart
- test/customer/photo_booking_ui_test.dart
- test/customer/photo_booking_flow_test.dart
- test/customer/photo_booking_rendering_test.dart
- test/customer/delivery_address_autocomplete_test.dart

Audit : ce rapport et docs/audit/REGISTRE_BOGUES_MOVIK.md.
Les anciennes attentes de tests ont été alignées avec le retrait du panneau facultatif et avec l’API de prix avant affectation déjà présente, sans modifier ce cycle.

## Limites et prochaine action
Aucun déploiement, push, fusion, changement Firebase ni transaction réelle. Les essais réseau et financiers sont simulés. Le tactile est vérifié par événements de test, pas sur un téléphone physique ; aucune validation avec lecteur d’écran réel n’est revendiquée. Les captures et tests de sémantique fournissent une validation locale.
Aucune nouvelle décision tarifaire nécessaire pour cette refonte. Les protections et prérequis commerciaux antérieurs demeurent hors périmètre.
Prochaine action : validation visuelle par Daniel des captures avant toute autorisation de publication.
