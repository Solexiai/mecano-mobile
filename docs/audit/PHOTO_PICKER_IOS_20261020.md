# MOVI-K — Bouton « Ajouter une photo »
Date : 20 octobre 2026. Statut : correction locale testée, non déployée ; validation iPhone réelle encore nécessaire.

## Constats et preuves
Worktree inspecté : C:\Users\Utilisateur\movik-admin-action-center-20261019.
Branche conservée : feat/driver-agenda-20261020.
HEAD : 5f9f721aaaaa7be6bf9fa8b60cde6470a246b0c2. Index vide au départ.
La version publique a été relue sur les deux domaines : driver-agenda-v1, source Web 469b6a3b1caed6da855ad97344cb0fc139df3a07, SHA256 main.dart.js ec49b5c0d8e7a139a326ad376a6afc0b535fb0342a84964257cf4fd6fed3ee9e. Les trois fichiers concernés sont identiques entre cette source publiée et HEAD, avant correction.

Deux défauts démontrés :
1. Dans lib/screens/delivery/delivery_request_flow_screen.dart, _addPhoto attendait _save avant uploadBookingPhoto. _save attend la sauvegarde locale puis saveBookingDraft côté serveur. Le sélecteur ImagePicker ne se trouvait qu'à l'intérieur de uploadBookingPhoto. Une sauvegarde refusée empêchait donc toute ouverture ; une attente distante peut aussi faire perdre l'activation temporaire requise par Safari. Les deux tests d'ordre échouaient avant correction : événement « save » reçu avant « picker ».
2. Dans lib/widgets/photo_booking_item.dart, la carte vide contenait un IconButton pour le « + », suivi d'un simple Text « Ajouter une photo ». Appuyer sur le texte ne déclenchait aucune action. Le test reproduit zéro appel au lieu d'un.

Ces défauts sont prouvés dans le code et les tests. Leur contribution exacte au signalement sur l'iPhone du client n'a pas été observée sur cet appareil. Aucun test Safari iOS réel n'a été exécuté.

## Contrôles ciblés
- Le « + » possède bien onPressed -> onAddPhoto -> _run -> _addPhoto.
- Dépendances installées : image_picker 1.2.2 et image_picker_for_web 3.1.1.
- Le plugin Web crée un input natif, l'attache au document puis appelle element.click(). accept=image/* ; capture absent avec ImageSource.gallery. Le navigateur reste libre de proposer caméra et photothèque.
- Aucune couche CSS bloquante n'a été identifiée dans le code inspecté. Le hit-test du bouton et du libellé a été testé en Flutter, pas dans Safari réel ; une erreur JavaScript propre à l'appareil n'est pas exclue par cette inspection.
- _busy empêche les actions concurrentes. Les limites existantes (3 photos par objet, 20 objets) sont conservées.
- L'analyse OpenAI intervient après l'envoi. Elle ne commande pas l'ouverture du sélecteur.
- Le parcours d'authentification invité reste inchangé. La correction n'autorise aucun envoi anonyme et ne modifie aucune règle Firebase.

Références techniques consultées :
https://webkit.org/blog/13862/the-user-activation-api/
https://bugs.webkit.org/show_bug.cgi?id=234566
Le comportement précis a été confronté à la source du plugin installé, sans mise à jour de dépendance.

## Corrections
- Sélection et préparation locales appelées depuis le geste utilisateur, avant toute sauvegarde attendue.
- L'action d'envoi est différée : sauvegarde réussie et contrôles utilisateur/brouillon/époque/composant toujours obligatoires avant Firebase Storage.
- Le texte et le « + » de la carte vide constituent désormais un seul bouton.
- Ajout de « Retirer cette photo » sous chaque aperçu. Le client peut retirer puis ajouter une photo sans supprimer les informations de l'objet.
- L'emplacement libre est choisi parmi 0, 1, 2 : retirer la première photo ne provoque plus l'écrasement d'une autre lors du remplacement.
- Retirer une photo invalide le devis par le mécanisme existant et remet l'identification à confirmer. Il s'agit du retrait de la référence du brouillon ; aucune nouvelle politique de suppression physique Storage n'est introduite.
- Le comportement existant conserve les photos lors d'un échec de l'analyse IA et affiche « Analyse indisponible… ». Vérification automatisée ajoutée, avec second objet et rechargement du brouillon.

## Fichiers
Code :
- lib/screens/delivery/delivery_request_flow_screen.dart
- lib/services/booking/booking_photos.dart
- lib/widgets/photo_booking_item.dart

Tests ajoutés :
- test/customer/booking_photo_picker_order_test.dart
- test/customer/booking_photo_label_test.dart
- test/customer/booking_photo_replacement_test.dart
- test/customer/booking_photo_analysis_failure_test.dart

Documentation :
- docs/audit/PHOTO_PICKER_IOS_20261020.md
- docs/audit/REGISTRE_BOGUES_MOVIK.md

Preuves : artifacts/photo-picker-20261020/.

## Validation exécutée
- Reproduction initiale : 2 échecs d'ordre sélecteur/sauvegarde ; 1 échec du clic sur le libellé. Un test de refus de permission/reprise réussissait déjà.
- Exécution intermédiaire conservée : 51 réussites et 1 échec, le correctif du libellé n'ayant pas été appliqué à cause d'une erreur du script de modification. Script corrigé et test relancé.
- État final : 54 scénarios Flutter distincts réussis, aucun échec final ni ignoré : 53 dans final-tests.log et 1 supplémentaire dans analysis-failure-tests.log. Les relances recouvrantes ne sont pas additionnées.
- Couverture : annulation du sélecteur, refus de permission simulé puis reprise, ordre d'ouverture malgré une sauvegarde indisponible, clic sur le texte, retrait/remplacement sans collision, invalidation du devis, formats invalides/SVG et taille excessive, conversion des formats admis, photo vers devis simulé, conservation du brouillon et protections de réservation/paiement, échec IA avec second objet et rechargement, rendus FR/EN/ES mobile/ordinateur et texte agrandi dans les tests existants.
- Flutter analyze intégral : No issues found.
- Build Web JavaScript local : réussi, code retour 0. Avertissements du diagnostic Wasm conservés ; ce n'est pas une validation Wasm.
- git diff --check : réussi.
- Aucun test ne représente un devis, une mission, un paiement ou une analyse OpenAI réellement effectués en production.

## Limites et risques
- À vérifier sur iPhone Safari réel : ouverture native, caméra, photothèque, choix/annulation, permissions système, aperçu, retrait/remplacement et ajout de plusieurs objets. Android réel également non testé.
- Le refus de permission a été simulé ; le dialogue système et son libellé réel n'ont pas été vus.
- HEIC non pris en charge directement par la préparation existante : le message demande un export JPG. Aucune promesse de prise en charge HEIC n'est ajoutée.
- Si la sauvegarde ou l'envoi échoue après sélection, le fichier local n'est pas persisté pour reprise après rafraîchissement. La garantie testée de conservation concerne la photo déjà envoyée lorsque l'analyse IA échoue.
- Aucun tarif, sélection de véhicule, capacité, taxe, appel Stripe, snapshot financier, règle Firebase ou backend modifié.
- Risque restant principal : comportement natif du sélecteur sur les appareils réels, non couvert par les tests Flutter.

## État et prochaine action
Modifications locales non commitées ; branche et HEAD conservés, index vide. Les quatre modifications suivies préexistantes et les anciens dossiers artifacts sont préservés. Aucun push, merge, déploiement ni transaction réelle.
Aucun incident historique fermé ; P1-BOOKING-CONFIG-01 reste ouvert et le contrôle cartographique 1.3L reste reporté.
Prochaine action : valider ce correctif sur un iPhone réel via une version de test autorisée, avant toute demande de publication en production.


### Publication autorisée — 2026-10-20T22:58:01.590Z
Daniel autorise « Pouse sur movi-k et donne moi le lien ». Correctif Web publié : 526c39dca93d1fbb61dbe460ccf8ff18383020c4 ; Vercel dpl_7vxoKNbq5BoYQD686c4JDUPFWXjk ; https://mecano-mobile-717lpzu69-solexis-projects-4c019079.vercel.app. Les deux domaines servent photo-picker-v1, SHA256 0a8a4b9aee368f1e3d7c2f0f9f1078f631c252be9d38b10c847b85580c7d13c7. Route /fr/livraison/demande HTTP 200. Build production réussi avec les paramètres existants, déploiement préparé puis empreinte contrôlée avant promotion. Aucun backend, règle Firebase, paiement ou activation opérationnelle modifié. Aucun push Git ni merge. Les 54 tests locaux antérieurs sont réutilisés, non comptés comme de nouveaux tests. Validation native iPhone/caméra/photothèque toujours à effectuer : incident non clos.
