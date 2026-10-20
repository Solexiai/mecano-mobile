# Photo choisie mais refusée — 20 octobre 2026

## Diagnostic vérifié

Reprise sur feat/driver-agenda-20261020, HEAD initial efa93cb3e538b973e30f58392c21073670f56fb6, index vide. Les quatre fichiers de widgets préexistants signalés modifiés et les autres worktrees ont été préservés.

La production relue sert photo-picker-v1 (source 526c39d, Vercel dpl_7vxoKNbq5BoYQD686c4JDUPFWXjk). Aucune CSP bloquant les blob URLs n'a été observée dans l'en-tête de la route.

Défaut démontré dans lib/services/booking/booking_photos.dart : imageQuality:100 sur le Web n'est pas une absence de conversion. image_picker_for_web 3.1.1 réencode à pleine résolution avant de retourner XFile. Le garde-fou de 20 MiB vérifie alors le fichier agrandi par le sélecteur, avant le réducteur Movi-K.

Reproduction réelle dans le code Flutter compilé en release, sélecteur natif Chrome piloté par CDP et pixels synthétiques déterministes de 4000 × 3000 :
- JPEG original : 7 956 158 octets, sous 20 MiB.
- JPEG retourné par l'ancien sélecteur : 26 679 875 octets, au-dessus de 20 MiB.
- Ancien chemin complet selectBookingPhotoUpload : refus.
- Convertisseur Movi-K capable de produire 686 044 octets à partir du JPEG intermédiaire.
- Après correction, même entrée et même sélecteur : préparation réussie, action d'envoi disponible mais jamais exécutée.

Preuves avant/après : artifacts/photo-import-20261020/RED-full-photo-pipeline.json et GREEN-full-photo-pipeline.json. Dans ces deux sondes, select-raw conserve volontairement l'ancienne qualité 100 comme témoin ; select-photo appelle la vraie fonction applicative.

La copie reçue du fauteuil (JPEG 303 982 octets, 1157 × 1536) est acceptée avant et après. Elle n'est pas nécessairement identique au fichier original du téléphone. Le défaut ci-dessus explique un refus reproductible de photos valides ; il ne prouve pas à lui seul la cause exacte de chaque signalement mobile.

## Correction ciblée

- booking_photos.dart : aucune conversion par le sélecteur Web ; contrôle de la taille originale, puis une seule préparation JPEG existante, dimension maximale 1600 pixels et qualité 82. Réglages natifs Android/iOS inchangés.
- booking_photo_preparation.dart : raisons distinctes pour format non pris en charge, entrée dépassant 20 MiB, erreur de préparation et sortie dépassant 5 MiB. Les erreurs techniques ne sont plus présentées comme un HEIC supposé.
- delivery_request_flow_screen.dart : messages FR/EN/ES correspondant à ces causes, retour possible à la sélection.
- booking_photo_errors_test.dart : 7 scénarios de classification, conservation et réessai.

Limites de 20 MiB en entrée, 5 MiB stockés, 48 millions de pixels, types autorisés, validation JPEG et protections de sauvegarde/envoi conservées. Aucun tarif, devis officiel, choix de véhicule, règle de manutention, paiement, règle Firebase ou analyse IA serveur modifié.

## Vérifications réellement exécutées

- 38 tests Flutter distincts réussis dans regression.log, sans échec ni test ignoré : nouvelles erreurs, préparation photo, ordre sélection/sauvegarde, bouton, retrait/remplacement, échec IA avec photo conservée et brouillon/récapitulatif FR/EN/ES mobile/tablette/ordinateur.
- Analyse Flutter intégrale : No issues found.
- git diff --check valide.
- Build release de la sonde Flutter réussi.
- 16/16 cas navigateur réels : JPEG reçu, JPEG 12 MP, PNG, WebP, format non autorisé, entrée >20 MiB, JPEG corrompu et annulation, chacun à 1280 × 900 puis 393 × 852 avec émulation tactile. Sélecteur image/* sans capture imposée. Aucun Firebase Storage/OpenAI ni envoi réel appelé.
- browser-matrix.json contient les résultats ; browser-matrix.cjs et full-probe.dart permettent de reprendre la vérification avec la copie locale privée.
- Le test Flutter Chrome initial resté au chargement n'est pas compté comme réussi. Les premières sondes dump-dom et l'échec de compilation du banc de test restent dans les artefacts, sans être comptés.

## Limites et suite

Pas d'appareil Android ou iPhone physique connecté : caméra, photothèque, permissions OS et navigateur intégré du téléphone restent à vérifier réellement. L'émulation Chrome n'est pas Safari iOS. HEIC non décodable dans le parcours actuel reste non pris en charge ; aucune promesse de compatibilité universelle.

Incident mobile non clos avant confirmation sur le téléphone du client. P1-BOOKING-CONFIG-01 reste ouvert ; test cartographique 1.3L bloqué/reporté ; aucun ancien décompte modifié.

Publication du même correctif photo préparée dans la continuité de l'autorisation « Pouse sur movi-k et donne moi le lien ». Aucune fusion, aucun push Git ni transaction réelle. Les identifiants de publication et la vérification des deux domaines seront consignés après succès.
