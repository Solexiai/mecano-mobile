# Présence et évaluations des chauffeurs — 19 octobre 2026

## État et périmètre

Base inspectée : 318846a0cc62153a30bf3d18d7baf810e5d928bf, index vide ; seul artifacts/admin-action-center-20261019/ préexistait non suivi. Branche dédiée créée : feat/admin-driver-activity-20261019 dans le worktree movik-admin-action-center-20261019. Aucun autre worktree modifié. Aucune publication, fusion, écriture de données métier de production ou transaction réelle dans ce chantier.

Demande : compteur cliquable des chauffeurs connectés, liste existante avec recherche ville/connexion, résultats de missions et avis sur cinq étoiles ; sollicitation de l'avis après chaque mission.

## Diagnostic et corrections

- online_status décrit la disponibilité de dispatch et n'est pas une preuve de connexion récente. Ajout d'une présence séparée driver_presence, sans modifier dispatch, disponibilité, GPS ni paiements.
- Un signal par session au premier plan toutes les 30 secondes, timestamp serveur ; expiration logique après 90 secondes, réévaluée toutes les 15 secondes dans l'administration. Plusieurs onglets sont dédupliqués par chauffeur ; fermer un onglet ne déconnecte pas les autres. Suppression au passage en arrière-plan lorsque possible ; expiration en cas de coupure brutale.
- Les instantanés provenant du cache ou une erreur de lecture produisent une présence inconnue, jamais un zéro ou un statut hors ligne inventé. Le compteur ouvre /fr/admin/chauffeurs?filter=connected. Il ne signifie pas « disponible pour une mission ».
- Recherche par ville insensible à la casse et aux principaux accents français, combinable avec les filtres connecté/hors ligne et les statuts administratifs. Fenêtres bornées existantes préservées ; le texte indique explicitement la recherche parmi les dossiers chargés et l'action Charger plus.
- getAdminDriverActivity est en lecture seule et réservé aux analystes/admins. Statistiques issues des missions réelles et notes clients vérifiées ; exclusion internal_test, déduplication historique par mission avec priorité à l'identifiant canonique, aucune moyenne inventée en l'absence d'avis.
- MissionStatus ne contient pas « failed ». Réalisées, annulées et en litige sont distinctes ; failed reste null et l'interface indique une classification non définie. Une annulation n'est pas attribuée automatiquement au chauffeur.
- Le formulaire de notation existait dans le suivi d'une livraison terminée. Mes demandes n'offrait plus de bouton pour y revenir après achèvement. Lien ajouté pour chaque mission completed réelle avec chauffeur, avec consultation de l'avis déjà envoyé. Notification de fin enrichie en FR/EN/ES pour demander une note sur 5.
- Les règles imposent désormais l'identifiant mission_role, une note entière 1–5 et une date serveur. Immutabilité, propriété et état completed conservés ; les anciens documents restent lisibles. Les avis historiques dupliqués ne multiplient pas le poids d'une mission.
- Une invitation est présentée après chaque livraison terminée. Aucun blocage d'une future réservation, du paiement ou de l'accès client n'a été ajouté pour contraindre une personne à répondre.

## Reproduction et validations locales

Échec initial : le filtre connected ouvrait pendingReview. Test corrigé avec l'implémentation. Échec intermédiaire du test d'expiration : la fixture future devenait valide après avancement de l'horloge ; séparation des assertions sans supprimer la vérification du rejet d'une date future. Deux débordements réels à 375 px / texte 200 % ont été reproduits puis corrigés : rangée de fiche et métadonnées non flexibles.

39 scénarios Flutter distincts réussis dans leurs dernières exécutions : 11 activité, 16 bloc admin, 3 pagination chauffeurs, 6 notation client, 3 navigation/recherche/affichage de la liste. Aucun scénario ignoré. Ne pas additionner les reprises recouvrantes.

18 tests serveur unitaires simulés réussis : 11 calcul/éligibilité/déduplication, 7 garde d'accès/validation d'identifiant. 9 tests de règles réussis dans les émulateurs du projet demo-movik-test : usurpation de présence, timestamp futur, lecture administrative, note unique, bornes et propriété, statut et exclusion internal_test. La première tentative des tests de règles a été refusée par la protection d'isolation parce que seul Firestore avait été démarré ; reprise avec Auth/Firestore/Storage, sans contourner la protection.

Flutter analyze intégral sans problème, TypeScript --noEmit, ESLint source et git diff --check réussis. Build Web local initial réussi. Journaux et codes de sortie conservés dans artifacts/admin-driver-activity-20261019/. Les tests widgets ne sont pas une validation sur mobile physique ni en production.

## Limites et décision restante

- Décision produit : définir l'événement « mission échouée » et son autorité de constat. Proposition à approuver : livraison non réalisée dont l'échec est confirmé par l'administration ; annulations conservées séparément. Aucun nouveau statut métier, compteur fictif ou sanction ajouté.
- Présence : approximation explicitement affichée, session au premier plan uniquement, dépendant d'une horloge administrateur correcte ; pas une garantie d'exécution en arrière-plan sur téléphone. Validation connectée multi-appareils et réseau réel à faire avant de présenter cela comme une preuve production.
- Bornes de lecture : au-delà de 2 000 sessions dans la fenêtre, présence inconnue ; au-delà de 500 missions pour un chauffeur ou 1 000 avis par lot interrogé, statistiques indisponibles plutôt que total tronqué. Une pagination serveur de ces statistiques sera nécessaire à cette échelle.
- Publication future coordonnée nécessaire : règles Firestore, getAdminDriverActivity et frontend. Aucun changement financier. L'autorisation du déploiement précédent concernait le bloc À traiter, déjà livré ; ce nouvel ajout n'a pas été publié.

## Fichiers et écrans

Administration : admin_dashboard_shell.dart, admin_drivers_list_screen.dart, nouveaux admin_driver_presence_card.dart et admin_driver_activity_summary.dart.
Client : customer_requests_tab.dart, app_strings.dart ; formulaire/référentiel de notation existants réutilisés.
Présence : main.dart, nouveau services/driver_presence.dart.
Serveur : firestore.rules, functions/src/index.ts, nouveaux getAdminDriverActivity.ts et lib/driverActivity.ts.
Tests : admin_driver_activity_test.dart, admin_driver_directory_ui_test.dart, driverActivity.test.ts, adminDriverActivityAccess.test.ts et driverPresenceRatingsRules.test.ts.
Sources : code du dépôt et journaux ci-dessus examinés le 19 octobre 2026. Aucun relevé des données personnelles de production effectué.

Validation finale après correction de la disposition et des métadonnées : analyze-release.exit = 0 (aucun problème), build-release.exit = 0 ; compilation Web finale réussie. Synthèse machine : artifacts/admin-driver-activity-20261019/validation-summary.json. Les échecs initiaux et intermédiaires demeurent conservés.

## Décision ultérieure approuvée — 19 octobre 2026, 15:46 Toronto
Le propriétaire approuve la distinction proposée : livraison non réalisée dont l'échec est confirmé par l'administration, annulations séparées, aucune responsabilité automatique du chauffeur. Le point de décision ci-dessus est résolu par MOVIK-FAILURE-REVIEW-20261019-001. Réalisation locale, contrôles serveur et preuves : docs/audit/MISSION_FAILURE_REVIEW_20261019.md. Aucune nouvelle publication à ce stade.
