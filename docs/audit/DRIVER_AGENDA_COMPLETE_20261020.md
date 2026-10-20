# Movi-K — Agenda, disponibilités et calendriers — 20 octobre 2026

## Verdict
Mise à jour du 20 octobre 2026 à 12:56 Toronto : Daniel approuve la confirmation de la période complète par le chauffeur. Source et portée : DRIVER_DURATION_APPROVAL_20261020.md. Aucun déploiement ni activation autorisés par cette approbation.
Qualification locale initiale terminée. **Publication contrôlée autorisée puis réalisée le 20 octobre 2026, sans activation commerciale.** Résultat et limites actualisés : DRIVER_AGENDA_PRODUCTION_20261020.md. Les validations locales décrites ci-dessous restent distinctes des contrôles réels de publication.
Les fonctions d’agenda, de recherche et d’attribution ont été raccordées au dépôt existant.
Google et Microsoft sont implémentés et testés avec des réponses contrôlées ; aucune connexion réelle n’est attestée.
Les réservations réelles restent bloquées par les approbations et protections décrites ci-dessous.

## État de départ vérifié
- Ordinateur : LAPTOP-R0DMP4TG.
- Worktree : C:\Users\Utilisateur\movik-admin-action-center-20261019.
- Branche : feat/driver-agenda-20261020.
- HEAD de reprise : 37d0859aafbed981023950d4df6a2f25de36e8ff.
- Index et fichiers suivis propres au début de cette intervention.
- Les autres worktrees ont été inventoriés et préservés. Aucun changement de branche, fusion, push ou déploiement.
- Les répertoires artifacts/admin-action-center-20261019, admin-driver-activity-20261019, admin-driver-activity-release-20261019, customer-help-release-20261020, customer-loading-help-20261019, driver-agenda-20261020 et mission-failure-review-20261019 étaient déjà non suivis.
- Rapport de reprise lu : DRIVER_AGENDA_20261020.md. Le socle du commit initial n’est pas présenté comme nouveau.
- Mandat : document fourni « MISSION COMPLÈTE A À Z », daté du 20 octobre 2026.
- Aucun relevé des données privées Firebase de production n’a servi de fixture. Les références de publication antérieures restent historiques.

## Fonctionnement réalisé
### Agenda et disponibilité
Vues jour, semaine et mois, navigation, heure locale explicitée, détails des missions attribuées, récurrences par fuseau IANA, plusieurs plages par jour, exceptions et congés, blocages manuels, pauses avant/après et aperçu des périodes/conflits.
Les horaires d’exemple ne sont jamais enregistrés par défaut. Les heures inexistantes lors du changement d’heure sont refusées ; les heures répétées sont traitées de façon conservatrice.
La révision empêche un écrasement concurrent. Les erreurs de sauvegarde conservent les modifications. Une modification ne peut rendre incompatible une mission déjà réservée ; les nouvelles pauses sont répercutées sur ses intervalles occupés.

### Offre, acceptation et départ
Le serveur filtre selon la zone de ramassage configurée, la base vérifiée et le rayon du chauffeur, sa position récente lorsqu’elle est exploitable, son statut, ses documents, sa catégorie et les exigences réelles de véhicule/services du contrat existant.
La vérification de base est liée aux coordonnées effectivement examinées par l’administration ; un changement de coordonnées invalide son utilisation. Aucun véhicule, base ou capacité de production n’a été déclaré vérifié.
L’estimation du trajet sert seulement à éliminer des incompatibilités évidentes au dispatch. Le chauffeur doit confirmer un intervalle complet avant l’attribution lorsque la politique approuvée est activée.
Les offres et leur expiration sont revalidées dans la transaction. La transaction verrouille l’agenda, revalide l’intervalle, les blocages et la fraîcheur externe, réserve le créneau, attribue la mission et ferme les offres concurrentes.
Un identifiant de demande conserve l’acceptation après une erreur réseau. Son rejeu ne réexécute pas l’orchestration financière. Le cas « validation encore en cours » est affiché explicitement.
Une mission future apparaît dans l’agenda sans démarrer le partage GPS. Le départ explicite exige un créneau valide, les documents et le véhicule encore admissibles et la validation de paiement existante.
L’affectation administrative directe ne peut pas contourner la confirmation du créneau lorsque la planification est active. Une désactivation ne permet pas au parcours historique d’ignorer les réservations futures déjà présentes.

### Cycle de vie et absence de chauffeur
Refus idempotent, expiration, recherche bornée et état explicite d’absence d’acceptation. Les limites techniques sont visibles dans les données serveur : trois tours, quinze offres maximum par tour, pages de deux cents candidats avec curseur. Ces limites ne modifient aucun tarif.
La maintenance parcourt les missions et connexions par curseur afin de ne pas traiter indéfiniment les seuls premiers documents.
Un chauffeur peut ajuster son temps d’occupation avec contrôle de concurrence ; l’heure du rendez-vous client reste verrouillée. Un autre rendez-vous exige le parcours de demande/devis révisé et les règles commerciales applicables.
Les annulations et états terminaux libèrent les réservations ; la réconciliation relit la mission actuelle afin qu’un événement retardé ne rétablisse pas un ancien état.
Les règles et opérations financières d’annulation, libération d’autorisation, remboursement et capture restent celles du dépôt.
Aucune disponibilité alternative ni nouveau rendez-vous n’est promis au client sans nouvelle validation. Le message d’absence de chauffeur permet la relance et indique le contact officiel.

### Calendriers
- OAuth officiel avec état à usage unique, PKCE et consentement explicite. Le callback produit un code temporaire qui doit être confirmé par le même compte Firebase chauffeur.
- Jetons chiffrés AES-256-GCM côté serveur, liés au propriétaire et au fournisseur. Renouvellement et rotation sérialisés. Aucun jeton transmis à Flutter.
- Sélection des calendriers personnels à consulter ; lecture limitée aux périodes occupées. Les titres, descriptions et participants ne sont pas stockés dans la disponibilité.
- Écriture facultative dans un calendrier Movi-K dédié. Les événements n’incluent pas les adresses ni les renseignements du client.
- Identifiants persistants, reprise après réponse perdue, mise à jour, suppression, réessais bornés, états d’échec et reconnexion.
- Google : identifiants déterministes et remplacement après suppression ; Microsoft : transactionId et propriété persistante permettant de retrouver une création dont la réponse a été perdue.
- Réconciliation périodique à partir de l’état interne, sans modification d’une mission depuis un événement externe. Les changements externes de contenu ne bouclent pas vers Movi-K.
- Libre/occupé actualisé par fenêtre bornée, avec pagination. Pas de webhooks ni de promesse de synchronisation instantanée : une fraîcheur maximale de 60 secondes et une couverture complète du créneau sont exigées à l’acceptation.
- Une synchronisation externe qui échoue bloque l’acceptation concernée et reste visible ; elle n’efface jamais la mission interne.
- Un compte sans écriture autorisée n’est pas déclaré synchronisé. Aucun événement confirmé n’est écrit avant la validation financière existante. Les missions internes fictives sont exclues des écritures externes.
- Déconnexion : suppression des identifiants de connexion ; révocation Google tentée. Microsoft exige aussi le retrait de l’autorisation dans les paramètres du compte. Les copies déjà présentes restent chez le fournisseur, ce que précise l’interface.
- Apple : export iCalendar manuel. Il ne bloque pas les disponibilités avec les rendez-vous Apple et ne synchronise pas les modifications ultérieures. Sur le Web, téléchargement .ics ; sur les plateformes sans téléchargement intégré, copie du contenu explicitement signalée.

## Intégrité et sécurité
Le moteur de devis, les tarifs, taxes, commission, pourboires, Stripe, ledger, payouts et structures de snapshot n’ont pas été modifiés.
Les scénarios synthétiques complets contrôlent l’égalité en cents devis = mission = snapshot financier = montant envoyé au fournisseur de paiement fictif.
Les nouveaux callables utilisent l’identité authentifiée ; aucune cible chauffeur fournie librement n’est utilisée pour lire un agenda privé.
Les données de connexion, réservations, clés temporaires et états de synchronisation restent interdites aux accès directs client.
Les missions ouvertes et photos ne deviennent accessibles qu’aux chauffeurs destinataires d’une offre encore valide, au propriétaire, au chauffeur assigné et aux rôles administratifs autorisés selon les règles.
Le code conserve les protections physiques existantes et le verrou commercial pre_assignment.
Le refus « service indisponible » reste distinct d’une mission remportée par un autre chauffeur.
Le callback, les erreurs et les audits évitent les contenus privés et secrets. Les traces de paiement présentes dans les tests utilisent exclusivement FakePaymentProvider.
Cette validation technique ne constitue pas une validation juridique de la politique de confidentialité ou de conservation.

## Tableau de livraison
« Local » = tests contrôlés et/ou émulateurs ; « réel » = compte fournisseur ou production autorisée.

| Fonctionnalité | Code terminé | Tests validés | Test réel | Bloquant |
|---|---|---|---|---|
| Agenda interne | Oui | Local | Non | Publication non autorisée |
| Disponibilités | Oui | Local | Non | Activation opérationnelle |
| Horaires récurrents | Oui | Local, fuseaux/DST | Non | Aucun pour validation locale |
| Périodes bloquées | Oui | Local | Non | Aucun pour validation locale |
| Google Calendar | Oui | OAuth/API simulés + émulateur | Non | Application OAuth, secrets, consentement, essai autorisé |
| Outlook | Oui | OAuth/API simulés + émulateur | Non | Application Entra, secrets, consentement, essai autorisé |
| Apple Calendar | Export manuel | Format ICS testé | Import Apple non testé | Pas de synchronisation bidirectionnelle annoncée |
| Recherche régionale | Oui | Local | Non | Bases et véhicules réels admissibles |
| Filtrage horaire | Oui | Local | Non | Politique approuvée puis activée |
| Offre chauffeur | Oui | Local, push interceptés | Non | Aucun envoi réel autorisé |
| Premier acceptant | Oui | Transactions concurrentes | Non | Aucun contrat réel autorisé |
| Anti-double réservation | Oui | Concurrence, pauses, ancien actif | Non | Garanties internes, pas atomicité Google/Firestore |
| Durée totale | Schéma/contrôles/UI, règle approuvée le 20 octobre | Local | Non | Horizon commercial restant à approuver |
| Événement automatique | Oui | API simulées, reprise/idempotence | Non | Connexion consentie et test fournisseur |
| Annulation | Réconciliation ajoutée | Local, finance existante préservée | Non | Règles commerciales existantes inchangées |
| Synchronisation externe | Oui | Erreurs/reprise/révocation simulées | Non | Validation fournisseur et politique de conservation |

## Validation et preuves
Dernières validations applicables, sans additionner les relances :
- **111 scénarios Flutter distincts réussis** : 99 réussis hors fichier d’offres dans flutter-5.log, puis 12 scénarios d’offres réussis dans flutter-6.log. Cette dernière exécution revalide aussi 16 scénarios agenda/GPS déjà comptés (28 réussis au total dans ce fichier de log).
- **72 tests unitaires serveur réussis**, quatre suites : unit-final.log.
- **347 tests d’intégration distincts réussis** : 305 dans emulator-6.log ; les trois nouveaux contrôles administratifs/désactivation sont inclus dans les 23 scénarios driverScheduling réussis dans emulator-7-result.json ; les 39 tests adminPrivilegedActions passent finalement avec Auth Emulator dans emulator-8-result.json. Les 11 tests de concurrence relancés ne sont pas ajoutés une seconde fois.
- TypeScript sans émission et lint source : codes de sortie 0 (typescript-final.exit, lint-final.exit).
- Flutter analyze intégral : No issues found (flutter-analyze-5.log).
- Build Web release : réussi, code 0 (flutter-build-3.log/.exit). Aucun déploiement.
- git diff --check : réussi.
- Les neuf échecs intermédiaires de la suite administrative venaient de l’absence volontaire d’Auth Emulator (connexion locale refusée sur le port 1). L’émulateur Auth a été ajouté au runner de test et les 39 cas passent. Aucune règle métier n’a été modifiée pour les faire passer.
- Mobile 375 px, tablette 768 px et ordinateur 1440 px ; FR/EN/ES ; textes 200 % sur les écrans ciblés ; navigation clavier testée. L’usage réel de lecteurs d’écran matériels n’a pas été attesté.
- Les captures du composant initial (5 tests séparés) ne sont pas comptées comme nouvelle couverture fonctionnelle.
- Aucun échec final ni test ignoré dans ce périmètre. Le test cartographique autonome 1.3L demeure bloqué/reporté hors périmètre.

Les dernières exécutions remplacent les précédentes dans les décomptes : les exécutions recouvrantes ne sont pas additionnées.
Les cinq tests de capture du composant initial servent seulement à reconstituer la comparaison ; ils ne sont pas ajoutés au total fonctionnel du nouveau code.
Aucun test Stripe réel, aucune carte réelle, aucune offre à un chauffeur réel, aucun compte OAuth réel.
Les suites appellent les véritables handlers et transactions avec Firestore/Storage Emulator ; Eventarc, les tâches Cloud Scheduler déployées et les fournisseurs externes ne sont pas validés en production.
Les mocks des fournisseurs, données de capacité, règles commerciales et adresses des fixtures sont explicitement synthétiques.

### Échecs initiaux conservés et corrections
- Fixtures de transaction et données d’heure souhaitée : contrats complétés, sans assouplir les validations serveur.
- Rejeu d’acceptation : un test a détecté deux créations de paiement fictif ; le rejeu consulte désormais le résultat sans relancer l’orchestration.
- Champ contrôlé d’un dialogue détruit avant sa fermeture : échec Flutter reproduit ; attente de la fin de la route avant libération des contrôleurs.
- États vides de l’agenda, injection du faux backend et commande de transport hors ligne : corrections ciblées.
- Test d’avis client : remplacement d’une date locale par serverTimestamp dans la fixture, conformément à la règle déjà existante.
- Démarrages d’émulateur échoués avec chemins de règles incorrects : configuration de test corrigée ; aucune règle de production modifiée pour contourner cet échec.
- Six erreurs Storage causées par des projets de test discordants : même projet demo pour Firestore et Storage, puis suite complète réussie.
- Erreur de compilation intermédiaire du mapping d’erreur d’acceptation : identifiant corrigé, puis tests et analyse relancés.
- Inspection de sécurité complémentaire : blocage du contournement administratif, politique active invalide refusée, protection des réservations existantes lors d’une désactivation, revalidation des pauses.
- Les journaux intermédiaires sont conservés dans artifacts/driver-agenda-complete-20261020. Un test non exécuté avant un correctif d’inspection n’est pas présenté comme une reproduction rouge.

### Captures
- agenda-375.png et agenda-1440.png : nouveau composant.
- settings-375.png, settings-768.png, settings-1440.png : disponibilités et connexions.
- before-recreated-375.png et before-recreated-1440.png : composant initial reconstruit depuis HEAD 37d0859, pas capture de production.
- Les captures utilisent des données synthétiques et les polices Flutter chargées dans les tests.
- Incident de preuve déclaré : la première exécution du test historique a écrasé les deux images agenda-375.png/agenda-1440.png du répertoire ancien non suivi. Les autres preuves ont été conservées. Le chemin de sortie est corrigé ; les images « avant » sont explicitement des reconstitutions et ne sont pas présentées comme les fichiers historiques originaux.

## Ce qui exige encore une décision ou une action externe
1. **Règle produit approuvée** le 20 octobre 2026 à 12:56 Toronto : confirmation avant acceptation de toute la période nécessaire au chargement, au trajet et au déchargement. Source : DRIVER_DURATION_APPROVAL_20261020.md. Aucune activation effectuée.
2. **Horizon commercial** : préciser jusqu’à combien de temps à l’avance une mission peut être acceptée, en cohérence avec le cycle d’autorisation bancaire actuel. Aucun nombre arbitraire n’a été fixé en production.
3. **Ouverture opérationnelle** : lever séparément les prérequis déjà existants, notamment le verrou pre_assignment et l’admissibilité réelle des véhicules. Aucun raccordement automatique aux autres worktrees.
4. **Google/Microsoft** : configurer les applications, secrets, redirect URI et accès de test ; obtenir le consentement personnel des propriétaires puis tester connexion, renouvellement, déconnexion, créations/modifications/suppressions réelles.
5. **Confidentialité** : faire approuver la présentation, le périmètre et la durée de conservation des données de calendrier, connexions et historiques. L’activation OAuth exige privacy_approved.
6. **Publication** : autorisation explicite ultérieure pour le lot vérifié. Ni ce rapport ni un succès de test n’autorisent un push ou un déploiement.

Le cas d’une interruption du processus après attribution mais avant fin du paiement reste signalé « validation en cours » et relève des mécanismes financiers de rapprochement existants. Le nouveau bouton ne tente pas un deuxième paiement pour masquer cette situation.
La recherche est bornée et observe une disponibilité récente, sans garantir qu’un fournisseur externe ne changera pas après son dernier relevé.

## État Git et prochaine action
Branche : feat/driver-agenda-20261020. HEAD de reprise : 37d0859aafbed981023950d4df6a2f25de36e8ff.
Le lot de 54 fichiers a été sauvegardé dans le commit local a8674e3d4e628851f9cdf9a882282e108ccb02c7 ; résultat dans artifacts/driver-agenda-complete-20261020/commit-result.json. Cette approbation documentaire ultérieure est sauvegardée séparément.
Les répertoires d’artefacts préexistants restent non suivis. Aucune publication. Le lot de publication est décrit dans DRIVER_AGENDA_RELEASE_20261020.md.
Le manifeste source et les empreintes sont conservés dans artifacts/driver-agenda-complete-20261020/source-manifest.json.
La confirmation de durée totale est approuvée. Prochaine décision commerciale : **l'horizon maximal de réservation**, à rendre compatible avec le cycle de paiement existant. L'approbation de durée ne vaut ni autorisation de publication ni consentement de connexion de comptes.

## Références techniques officielles consultées
- Google OAuth : https://developers.google.com/identity/protocols/oauth2/web-server
- Google OAuth bonnes pratiques : https://developers.google.com/identity/protocols/oauth2/resources/best-practices
- Google scopes : https://developers.google.com/workspace/calendar/api/auth
- Google freeBusy : https://developers.google.com/workspace/calendar/api/v3/reference/freebusy/query
- Google événements : https://developers.google.com/workspace/calendar/api/v3/reference/events/insert
- Microsoft OAuth/PKCE : https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-auth-code-flow
- Microsoft calendarView : https://learn.microsoft.com/en-us/graph/api/user-list-calendarview?view=graph-rest-1.0
- Microsoft propriétés persistantes : https://learn.microsoft.com/en-us/graph/api/singlevaluelegacyextendedproperty-get?view=graph-rest-1.0
- Apple calendriers : https://support.apple.com/en-us/102301

## Fichiers inclus dans le lot local
- docs/audit/DRIVER_AGENDA_COMPLETE_20261020.md
- docs/audit/DRIVER_AGENDA_RELEASE_20261020.md
- docs/audit/REGISTRE_BOGUES_MOVIK.md
- firestore.indexes.json
- firestore.rules
- functions/src/functions/acceptDelivery.ts
- functions/src/functions/adminAssignDelivery.ts
- functions/src/functions/calendarSync.ts
- functions/src/functions/dispatchMissionToDrivers.ts
- functions/src/functions/driverAgenda.ts
- functions/src/functions/driverAgendaPreview.ts
- functions/src/functions/driverCalendars.ts
- functions/src/functions/driverScheduleLifecycle.ts
- functions/src/functions/updateMissionTrackingStatus.ts
- functions/src/functions/verifyDriverServiceBase.ts
- functions/src/index.ts
- functions/src/lib/agendaRecurrence.ts
- functions/src/lib/calendarConnections.ts
- functions/src/lib/calendarProviders.ts
- functions/src/lib/driverAgenda.ts
- functions/src/lib/driverScheduling.ts
- functions/src/lib/scheduledDispatch.ts
- functions/test/integration/bookingTimingDispatch.test.ts
- functions/test/integration/driverCalendars.test.ts
- functions/test/integration/driverScheduling.test.ts
- functions/test/integration/securityRules.test.ts
- functions/test/integration/setup.ts
- functions/test/integration/storageRules.test.ts
- functions/test/unit/agendaScheduling.test.ts
- functions/test/unit/calendarProviders.test.ts
- functions/test/unit/driverAgendaCallable.test.ts
- lib/backend/models/delivery_mission.dart
- lib/backend/repositories/driver_agenda_repository.dart
- lib/backend/repositories/firebase_mission_repository.dart
- lib/l10n/app_strings.dart
- lib/screens/customer/customer_tracking_screen.dart
- lib/screens/dashboard/provider/tabs/provider_calendar_tab.dart
- lib/screens/dashboard/provider/tabs/provider_jobs_tab.dart
- lib/screens/driver/driver_active_mission_screen.dart
- lib/services/calendar_export.dart
- lib/services/calendar_export_stub.dart
- lib/services/calendar_export_web.dart
- lib/widgets/driver_availability_preview.dart
- lib/widgets/driver_calendars_panel.dart
- lib/widgets/driver_dialog.dart
- lib/widgets/driver_recurrence_editor.dart
- lib/widgets/driver_search_status.dart
- lib/widgets/driver_slot_confirmation.dart
- lib/widgets/scheduled_mission_panel.dart
- storage.rules
- test/driver/driver_active_mission_gps_lifecycle_test.dart
- test/driver/driver_agenda_advanced_test.dart
- test/driver/provider_agenda_rendering_test.dart
- test/driver/provider_jobs_tab_test.dart
