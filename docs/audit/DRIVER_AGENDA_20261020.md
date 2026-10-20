# Agenda chauffeur — premier bloc de développement, 20 octobre 2026

## État vérifié avant modification
Worktree C:\Users\Utilisateur\movik-admin-action-center-20261019, branche feat/customer-loading-help-20261019, HEAD 7743437f7c93c878648ab83a07228a455ea4f96c. Index et fichiers suivis propres ; anciens dossiers artifacts non suivis conservés. Nouvelle branche feat/driver-agenda-20261020 depuis ce HEAD. Aucun autre worktree modifié.

Capture client fournie : choix immédiat/programmé et avertissement « date et heure expriment votre souhait ». Elle ne prouve pas une réservation de créneau. L'onglet fournisseur existant n'avait qu'une grille mensuelle et une annonce de fonctionnalités à venir.

## Fonctionnement réellement observé dans le code
- dispatchMissionToDrivers.ts : filtre de statut/document/véhicule puis préfixe geohash de trois caractères, plafond de candidats. Ce filtre grossier ne prouve pas le respect d'un rayon exact ni de la région du ramassage. Aucun agenda consulté.
- Les snapshots pre_assignment empêchent actuellement le dispatch automatique ; acceptDelivery refuse aussi leur acceptation commerciale sans validation opérationnelle. Aucune suppression de ces protections.
- acceptDelivery.ts : attribution par transaction, un seul gagnant ; statut chauffeur on_mission et GPS actif dès acceptation. Ce mécanisme n'est pas un cycle complet pour plusieurs réservations futures.
- paymentOrchestration : acceptDelivery appelle l'autorisation après sa transaction. Aucun changement au cycle, montant, devis, snapshot ni commission.
- createDeliveryRequest.ts : estimated_duration_minutes vient du devis/itinéraire ; aucun contrat explicite de durée totale d'occupation comprenant trajet d'approche, chargement et déchargement trouvé dans les fichiers examinés. Il serait incorrect d'en faire une garantie de non-chevauchement.
- requested_at est une heure souhaitée du snapshot. Aucun renommage en heure confirmée.

## Bloc réalisé localement
- L'onglet Mon agenda lit les missions attribuées au chauffeur en flux Firestore, filtrées par mois. Mise à jour sans copie indépendante de la mission ; retrait d'une affectation reflété par le flux. Dates inconnues signalées, statuts traduits, heure demandée distincte d'une confirmation.
- Plages de disponibilité et périodes bloquées explicites, ajout/retrait et sauvegarde. Aucun horaire inventé, liste vide non assimilée à une disponibilité.
- Conversion des instants locaux en UTC et restauration dans le fuseau de l'appareil.
- Deux callables authentifiées getDriverAgenda/saveDriverAgenda : rôle chauffeur depuis les claims, propriétaire depuis UID authentifié, profil obligatoire, horodatage serveur, revision contrôlée dans une transaction. Une révision obsolète est refusée.
- driver_agendas est interdit aux accès directs par les règles deny-by-default existantes ; aucun changement de règles nécessaire pour ces callables.
- Erreurs distinctes d'un agenda vide ; les modifications restent en mémoire après échec de sauvegarde ; rechargement destructif confirmé.
- Évaluateur pur de disponibilité d'un intervalle complet : plages contiguës fusionnées, périodes bloquées prioritaires, refus des dates invalides. Non raccordé au dispatch faute de contrat de durée totale.
- FR/EN/ES et thème partagé. Aucun calendrier Google/Outlook/Apple connecté. La bannière de développement indique explicitement que les disponibilités ne filtrent pas encore les offres.

## Validation
- Le premier lancement du test serveur échoue à la compilation parce que le nouveau module n'existe pas encore : zéro scénario exécuté, pas une reproduction d'un défaut métier.
- 23 tests unitaires serveur simulés réussis : validation, fuseaux/changement d'heure, chevauchements, bornes, identité serveur, rôles, révision.
- 3 tests d'intégration Firestore Emulator réussis : persistance avec date serveur, deux sauvegardes simultanées/un seul gagnant, profil absent refusé. Projet demo-movik-agenda, ports locaux ; aucun accès aux données de production.
- 11 tests d'acceptation existants réexécutés avec Firestore Emulator et FakePaymentProvider : un seul gagnant simultané, refus des profils non admissibles et cas internes. Ce n'est ni un test Stripe réel ni une validation en production.
- 21 tests Flutter distincts réussis : agenda, actualisation, persistance/sauvegarde simulée, erreur conservant les réponses, non-régression du tableau de bord, rendu 375/1440, FR/EN/ES et texte 200 %.
- Flutter analyze intégral sans problème ; TypeScript --noEmit et ESLint ciblé réussis. Journaux initiaux conservés (notamment configuration de règles d'émulateur hors répertoire, corrigée par copie locale des règles).
- Captures agenda-375.png et agenda-1440.png : rendus Flutter locaux, données fictives, pas captures d'un compte réel. Pas de test sur téléphone physique ni lecteur d'écran réel revendiqué.
- Preuves : artifacts/driver-agenda-20261020/. Les exécutions recouvrantes ne sont pas additionnées.

## Fichiers
- lib/screens/dashboard/provider/tabs/provider_calendar_tab.dart
- lib/backend/repositories/driver_agenda_repository.dart
- functions/src/lib/driverAgenda.ts
- functions/src/functions/driverAgenda.ts
- functions/src/index.ts
- functions/test/unit/driverAgenda.test.ts
- functions/test/unit/driverAgendaCallable.test.ts
- functions/test/integration/driverAgenda.test.ts
- test/driver/provider_agenda_test.dart
- test/driver/provider_agenda_rendering_test.dart
- Ce rapport et REGISTRE_BOGUES_MOVIK.md.

## Reste à réaliser avant fonctionnement complet
1. Définir qui confirme la durée totale occupée par une mission. Proposition à approuver : le chauffeur confirme son créneau complet avant acceptation, incluant sa manutention et ses déplacements nécessaires, sans ajouter de question au client et sans frais automatiques. Aucun nombre de minutes arbitraire.
2. Raccorder ce créneau aux offres et à la transaction d'acceptation : verrouiller aussi l'agenda du chauffeur afin de refuser deux missions qui se chevauchent. Les tests actuels prouvent un gagnant pour une même mission, pas cette autre garantie.
3. Distinguer réservation future et mission en cours, y compris présence, GPS, départ, annulation et éventuel échec de paiement ; respecter le cycle financier approuvé et ses limites pour les missions lointaines.
4. Remplacer la seule approximation geohash par la zone de service réelle au ramassage et gérer la diffusion des réservations futures sans assimiler présence en ligne et disponibilité future.
5. Résoudre les prérequis commerciaux pre_assignment par le processus existant, sans les contourner. Aucun état courant Firebase de configuration commerciale n'a été relu dans ce bloc.
6. Si la demande concerne aussi des calendriers externes, préciser le fournisseur et la direction de synchronisation ; une importation/exportation ponctuelle ne serait pas une synchronisation.

## Verdict
Premier bloc développé et testé localement. Le parcours complet agenda → diffusion régionale → acceptation sans conflit reste incomplet et non publié. Aucun push, fusion, déploiement, offre réelle ni transaction réelle. Aucun incident antérieur fermé.

Vérification finale : build Web release local réussi (81,3 s), git diff --check réussi. Le build local ne prouve aucun déploiement. Les captures ont été inspectées sur les deux largeurs ; elles utilisent les polices de test et portent le bandeau debug Flutter.
