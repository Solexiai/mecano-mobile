# Lot de publication à autoriser — agenda chauffeur — 20 octobre 2026

Ce document préparait le lot. **Daniel a ensuite autorisé sa publication le 20 octobre 2026 à 13:00 Toronto.** Le résultat effectif, les 19 fonctions publiées et les 8 fonctions de calendrier exclues sont documentés dans DRIVER_AGENDA_PRODUCTION_20261020.md. Aucune activation commerciale.
Rapport : DRIVER_AGENDA_COMPLETE_20261020.md. Sources conservées sur feat/driver-agenda-20261020, à partir de 37d0859.

## Décisions avant activation
La confirmation de la période complète par le chauffeur est approuvée par Daniel le 20 octobre 2026 à 12:56 Toronto (DRIVER_DURATION_APPROVAL_20261020.md). L’horizon de réservation compatible avec l’autorisation de paiement actuelle, la confidentialité/conservation et l’ouverture opérationnelle restent à approuver séparément.
Le devis ne consulte pas le nouvel agenda. Le verrou commercial pre_assignment est maintenu ; la revue de son ouverture doit être coordonnée avec les travaux existants sans fusion automatique.

## Configuration nouvelle, laissée absente ou désactivée
Exemple de revue uniquement ; ce n’est pas une configuration opérationnelle à copier en production :
```json
{
  "enabled": false,
  "approved": false,
  "duration_confirmation_approved": true,
  "version": "MOVIK-SCHEDULING-PROPOSAL-20261020-001",
  "max_advance_minutes": null
}
```
Document concerné : system_config/driver_scheduling. Seule l'approbation de durée est acquise ; la version complète de planification reste une proposition. Cet exemple documentaire n'a pas été appliqué à Firebase.
La valeur nulle doit être remplacée seulement après décision commerciale. Si enabled=true avec une approbation/version/horizon manquants, le serveur refuse l’opération. Une désactivation conserve la protection des réservations déjà créées.

system_config/calendar_oauth attend : enabled, privacy_approved, google_client_id, microsoft_client_id, callback_url et return_url.
Les identifiants de clients sont fournis par les projets autorisés. Les secrets ne vont jamais dans ce document.
Callback prévu, non attesté comme déployé :
```text
https://us-central1-movik-connect-prod.cloudfunctions.net/calendarOAuthCallback
```
L’URL de retour doit avoir exactement l’origine https://www.movi-k.com, sans paramètres, fragment ou identifiants.
Le callback demande ensuite de coller un code temporaire dans le même compte chauffeur ; il ne connecte pas automatiquement une session du navigateur.

Secret Manager, après autorisation :
- CALENDAR_TOKEN_ENCRYPTION_KEY : clé de 32 octets encodée en Base64.
- GOOGLE_CALENDAR_CLIENT_SECRET.
- MICROSOFT_CALENDAR_CLIENT_SECRET.

Aucune valeur réelle n’est incluse dans ce lot. La rotation de la clé de chiffrement nécessite une migration contrôlée des jetons existants ; ne pas remplacer la clé seule.

## Autorisations fournisseurs
Google : OAuth Web, callback exact, accès Calendar, identité et écran de consentement approuvés ; accès de test tant que la publication OAuth n’est pas validée.
Lecture libre/occupé et liste des calendriers ; écriture facultative limitée au calendrier créé par l’application.
Microsoft : application Entra permettant les comptes effectivement retenus pour le pilote, callback Web exact, autorisations déléguées Calendars.ReadBasic ou Calendars.ReadWrite selon le choix d’écriture, offline_access.
Les besoins éventuels de consentement administrateur de l’organisation doivent être traités par le propriétaire du compte.
La révocation Microsoft doit aussi être effectuée dans les autorisations du compte ; elle n’est pas annoncée comme effectuée à distance par Movi-K.

## Lot serveur
Fonctions existantes modifiées :
- acceptDelivery, adminAssignDelivery.
- onMissionCreatedDispatch, onMissionReopenedDispatch, onDriverBecameAvailableDispatch.
- getDriverAgenda, saveDriverAgenda.
- updateMissionTrackingStatus.

Fonctions ajoutées :
- previewDriverAvailability, verifyDriverServiceBase.
- declineDeliveryOffer, adjustDriverMissionSlot, retryDriverSearch.
- onMissionScheduleChanged, maintainDriverOffers.
- getDriverCalendars, prepareDriverMissionAcceptance.
- startDriverCalendarConnection, calendarOAuthCallback, finishDriverCalendarConnection.
- listDriverCalendars, selectDriverCalendars, disconnectDriverCalendar, refreshDriverCalendars.
- maintainDriverCalendars, retryDriverCalendarSync, exportDriverCalendar.

Les fonctions OAuth et maintainDriverCalendars nécessitent les secrets configurés. Le cœur d’acceptation et la préparation du prix chauffeur n’en dépendent pas lorsqu’aucun calendrier n’est connecté.
Déployer uniquement des fonctions explicitement listées et approuvées ; aucune commande de publication n’a été lancée.

## Ordre proposé après approbation de publication
1. Relire HEAD, worktrees, règles actuellement publiées et leurs protections concurrentes ; interrompre si une différence non examinée apparaît.
2. Préparer les index et fonctions du lot, nouvelles configurations désactivées. Préserver les quatre interrupteurs financiers/opérationnels existants.
3. Déployer les fonctions de dispatch qui écrivent les destinataires d’offres avant de restreindre les lectures aux destinataires.
4. Publier les règles Firestore/Storage et vérifier que les protections des autres chantiers sont toujours présentes.
5. Publier le build Web vérifié, sans activer automatiquement la politique ni OAuth.
6. Dans un environnement de test autorisé, connecter un compte Google et un compte Outlook consentants ; vérifier renouvellement, suppression, édition, panne et reconnexion.
7. Obtenir l’autorisation opérationnelle séparée, vérifier les bases/véhicules réellement admissibles, puis activer seulement les paramètres approuvés.
8. Surveiller refus, fraîcheur libre/occupé, curseurs, états de recherche et travaux calendar_sync_jobs en erreur.

Une publication du code ne vaut pas ouverture des ventes. Une activation ne doit pas supprimer les contrôles de paiement existants.
En cas de retour arrière, suspendre les nouvelles opérations de façon contrôlée et conserver les fonctions/règles nécessaires aux missions déjà acceptées. Ne pas restaurer un ancien acceptDelivery qui ignore leurs réservations.

## Données nouvelles
- driver_agendas/{uid} : révision utilisateur, mutex, plages et récurrence.
- driver_agendas/{uid}/reservations/{missionId} : créneau de mission et intervalle occupé incluant les pauses.
- driver_calendar_connections/{uid}/providers/{provider} : jetons chiffrés, génération, permissions, sélection, verrou de renouvellement.
- driver_calendar_busy/{uid} : périodes occupées, couverture temporelle, état et date du contrôle.
- calendar_sync_jobs/{missionId} et sous-collection events : génération, reprise, lien fournisseur et statut.
- calendar_oauth_states / calendar_oauth_claims : codes temporaires, expiration et usage unique.
- calendar_worker_state : curseurs de maintenance.
- driver_profiles/{uid}/service_base_reviews : preuve administrative privée de base examinée.
- Mission : scheduling, schedule_state, duration_confirmation, identifiant/empreinte de confirmation, état de recherche, destinataires et expiration des offres.

Aucune migration ne fabrique des disponibilités, confirmations, capacités ou véhicules. Les périodes inconnues restent inconnues.
Les données externes et historiques restent soumis à une politique de conservation à approuver ; l’expiration des codes temporaires répond uniquement à la sécurité OAuth.

## Vérifications externes encore nécessaires
- Eventarc et Cloud Scheduler réellement déployés, IAM et index effectifs.
- Connexion, révocation et réconciliation sur les véritables API avec comptes autorisés.
- Notifications push sur appareils de test consentants ; aucun envoi aux chauffeurs existants pour ce chantier.
- Import .ics sur Apple, sans promesse de synchronisation.
- Cycle complet autorisé dans l’environnement adéquat avant toute vente ; les validations locales ne sont pas une preuve de production.
