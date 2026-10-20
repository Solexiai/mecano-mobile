# Movi-K — Publication de l’agenda chauffeur — 20 octobre 2026

## Résultat
La version driver-agenda-v1 est publiée sur https://movi-k.com et https://www.movi-k.com. Agenda et disponibilités déployés ; ouverture des réservations et connexions Google/Outlook toujours désactivées.
Autorisation primaire : Daniel, message « pousse sur movi-k.com », le 20 octobre 2026 à 13:00:48 America/Toronto. Cette autorisation de publication ne choisit pas un horizon de réservation et ne vaut pas consentement OAuth.
Contrôle public terminé : 2026-10-20T17:21:21.341Z (UTC).

## Versions vérifiées
- Vercel : dpl_5WQLUCk21nw6np7gyogsg3viAN7s ; état READY.
- URL de déploiement : https://mecano-mobile-k1i2hxzj7-solexis-projects-4c019079.vercel.app.
- Source Web : 469b6a3b1caed6da855ad97344cb0fc139df3a07 ; build réutilisé sans modification Flutter.
- Source serveur : 55ba38da3ade62bbdae0adbd336e175eda117e06.
- Bundle SHA256 : ec49b5c0d8e7a139a326ad376a6afc0b535fb0342a84964257cf4fd6fed3ee9e.
- Branche : feat/driver-agenda-20261020 ; worktree : C:/Users/Utilisateur/movik-admin-action-center-20261019.
- Ancienne production : dpl_7Uthx9F6xcSwZVP5Kwm6KGjWLRex, source Web f11e24342b1b721a41eb1143fa4e47d821faf61e.

Le build a été publié sans basculer le domaine, contrôlé avec l’authentification Vercel existante, puis promu après les contrôles serveur. Les octets main.dart.js servis sur les deux domaines ont été hachés et correspondent au build testé.
Les routes /fr, /fr/provider/dashboard et /fr/livraison/demande répondent HTTP 200 sur les deux domaines. Cela vérifie leur desserte Web, pas le parcours authentifié d’un chauffeur réel.

## Périmètre serveur publié
19 fonctions ACTIVE ; les 14 fonctions appelables refusent un appel anonyme (HTTP 401). Aucun compte réel n’a été utilisé pour les tester.

| Fonction | Révision vérifiée | Contrôle anonyme |
|---|---|---|
| acceptDelivery | acceptdelivery-00010-duw | 401 |
| adjustDriverMissionSlot | adjustdrivermissionslot-00001-pub | 401 |
| adminAssignDelivery | adminassigndelivery-00007-wab | 401 |
| declineDeliveryOffer | declinedeliveryoffer-00002-tag | 401 |
| exportDriverCalendar | exportdrivercalendar-00001-kuj | 401 |
| getDriverAgenda | getdriveragenda-00001-gep | 401 |
| getDriverCalendars | getdrivercalendars-00001-cuc | 401 |
| maintainDriverOffers | maintaindriveroffers-00001-gur | Déclencheur/planificateur |
| onDriverBecameAvailableDispatch | ondriverbecameavailabledispatch-00005-jub | Déclencheur/planificateur |
| onMissionCreatedDispatch | onmissioncreateddispatch-00008-yed | Déclencheur/planificateur |
| onMissionReopenedDispatch | onmissionreopeneddispatch-00008-pup | Déclencheur/planificateur |
| onMissionScheduleChanged | onmissionschedulechanged-00001-pol | Déclencheur/planificateur |
| prepareDriverMissionAcceptance | preparedrivermissionacceptance-00001-git | 401 |
| previewDriverAvailability | previewdriveravailability-00001-jet | 401 |
| retryDriverCalendarSync | retrydrivercalendarsync-00001-tak | 401 |
| retryDriverSearch | retrydriversearch-00001-doh | 401 |
| saveDriverAgenda | savedriveragenda-00001-fus | 401 |
| updateMissionTrackingStatus | updatemissiontrackingstatus-00003-dav | 401 |
| verifyDriverServiceBase | verifydriverservicebase-00001-hep | 401 |

Les trois déclencheurs de dispatch ont été publiés ensemble : création de mission, réouverture et disponibilité du chauffeur. Le lot préparatoire n’en listait initialement qu’un ; la portée a été complétée après lecture des exports existants.
Règles Firestore et Storage publiées après les fonctions, relues via l’API et comparées au contenu local testé. Les protections préexistantes sont conservées.
Règles Firestore : projects/movik-connect-prod/rulesets/5f2beb66-bfac-4de9-b319-6b7a8735b99d.
Règles Storage : projects/movik-connect-prod/rulesets/6e6dcf59-5ff3-4403-bb72-e14f78246c29.
Trois index ajoutés, tous READY ; aucun index supprimé. Le planificateur maintainDriverOffers est ENABLED, mais son traitement s’arrête tant que la politique de planification est absente.

## Fonctions non publiées
- startDriverCalendarConnection
- calendarOAuthCallback
- finishDriverCalendarConnection
- listDriverCalendars
- selectDriverCalendars
- disconnectDriverCalendar
- refreshDriverCalendars
- maintainDriverCalendars

Les trois secrets OAuth/chiffrement requis sont absents. Aucun identifiant fictif, aucune clé et aucun consentement utilisateur n’ont été créés. getDriverCalendars annonce la disponibilité réelle et l’interface désactive les boutons de connexion.
Apple reste un export .ics manuel ; aucune synchronisation automatique ni lecture du calendrier Apple.

## Configurations relues, inchangées
- accept_new_delivery_requests = false.
- allow_driver_acceptance = false.
- payments_enabled = false.
- driver_payouts_enabled = false.
- system_config/driver_scheduling absent ; system_config/calendar_oauth absent ; system_config/booking_policy absent.
- Dates de mise à jour des configurations présentes comparées avant/après ; aucune écriture de configuration effectuée.
La règle de confirmation de toute la période par le chauffeur est approuvée dans DRIVER_DURATION_APPROVAL_20261020.md. Son approbation ne détermine pas l’horizon maximal et n’active pas la politique.

## Corrections nécessaires avant publication
1. Refus d’offre : le code réellement publié comportait des contrôles de statut chauffeur, documents, état de mission et expiration que le nouveau module ne conservait pas. Reproduction : 23 tests existants réussis et 4 nouveaux échecs. Restauration des protections, puis 27/27 scénarios d’intégration réussis sur Firestore Emulator, avec fournisseur de paiement fictif. Commit ff697629795cfa8092e7b5a8f853d3775a29c88a.
2. Secrets optionnels : le premier déploiement a été refusé avant publication des fonctions, car defineSecret enregistrait globalement les secrets des connecteurs pourtant exclus. Quatre tests ajoutés ont échoué avant correction. Raccordement via les noms Secret Manager dans les seules fonctions OAuth, selon le mécanisme Firebase documenté ; lecture à l’exécution qui échoue explicitement si une valeur manque. Aucune valeur substituée, aucune protection supprimée. 76/76 tests unitaires serveur, TypeScript et lint réussis. Commit 55ba38da3ade62bbdae0adbd336e175eda117e06. Deuxième déploiement : code de sortie 0.

Fichiers applicatifs/test modifiés dans cette intervention :
- functions/src/functions/driverScheduleLifecycle.ts
- functions/test/integration/driverScheduling.test.ts
- functions/src/lib/calendarProviders.ts
- functions/test/unit/calendarProviders.test.ts
Les documents DRIVER_AGENDA_COMPLETE_20261020.md, DRIVER_AGENDA_RELEASE_20261020.md et REGISTRE_BOGUES_MOVIK.md sont mis à jour avec ce rapport.

## Tests et limites de preuve
- Réutilisation des preuves antérieures : 111 scénarios Flutter distincts, analyse Flutter complète et build Web réussis. Aucun changement Flutter dans ce bloc de publication.
- Nouvelle exécution : 27 tests d’intégration ciblés réussis (23 antérieurs + 4 nouveaux). Elle ne s’ajoute pas intégralement aux 347 scénarios d’intégration antérieurs.
- Nouvelle exécution : 76 tests unitaires serveur réussis (72 antérieurs + 4 nouveaux), compilation TypeScript et lint réussis.
- Contrôles réels : états des 19 fonctions, refus anonyme des 14 callables, règles publiées, index, configuration, empreintes du build et réponses HTTP publiques.
- Aucun parcours chauffeur connecté, lecteur d’écran réel, import Apple, connexion Google/Outlook, mission, paiement, notification chauffeur ou carte réelle utilisé pour la validation.
- Aucun tarif, commission, taxe, capture, ledger, payout ou règle financière changé. Les contrôles financiers existants restent en place.
- Journalisation : 0 événement ERROR ou supérieur sur les 19 révisions publiées entre 2026-10-20T17:15:44.850Z et 2026-10-20T17:21:47.434Z ; contrôle borné, pas une validation métier ni une garantie de surveillance continue.

## Incidents de contrôle conservés
Le premier relevé parcourait plusieurs releases de règles et retenait cloud.firestore/default à la place de cloud.firestore. Le script a été corrigé avant toute publication des règles ; le relevé corrigé concordait avec la source publique. Les deux relevés restent conservés et identifiés.
Le premier appel de liste d’index demandait une taille de page non prise en charge ; taille de page corrigée à 0, puis création explicite des trois seuls index manquants. Une erreur de syntaxe PowerShell intermédiaire n’a effectué aucune modification.
Le connecteur Vercel a refusé la portée d’équipe ; le CLI déjà authentifié pour cette même équipe/projet a été utilisé comme repli autorisé. La protection Vercel n’a pas été désactivée.
Les avertissements Firebase existants de règles inutilisées ont été conservés. Firebase signale également la fin de déploiement du runtime Node.js 20 le 30 octobre 2026 : migration technique à planifier séparément, sans changement de runtime dans cette publication.

## Git et suite
Commits locaux conservés sur la branche dédiée, aucun push Git ni fusion. Les quatre fichiers déjà signalés par Git à la reprise ont été conservés ; leur diff de contenu était nul. Les autres worktrees et répertoires d’artefacts ont été préservés.
Le résultat du commit documentaire final est enregistré dans artifacts/driver-agenda-release-20261020/documentation-commit.json. Aucun ancien incident fermé : 31 fiches, P0 0 / P1 1 / P2 2 ; P1-BOOKING-CONFIG-01 ouvert ; test 1.3L bloqué/reporté.
Prochaine action de validation : ouvrir l’espace chauffeur et vérifier l’onglet Agenda avec son compte habituel. L’horizon commercial, les prérequis de réservation et les connexions OAuth nécessitent encore leur validation distincte.

## Sources et preuves
- Autorisation de Daniel dans cette conversation, 20 octobre 2026 à 13:00:48 Toronto.
- Dossier artifacts/driver-agenda-release-20261020 : release-before-corrected.json, red-result.json, green-result.json, secrets-red-result.json, unit-release-result.json, firebase-deploy-result.json (échec initial), firebase-deploy-retry-result.json, rules-deploy-result.json, indexes-apply.json, indexes-verify.json, staged-verification.json, ready-for-promotion.json, web-promote-result.json, runtime-error-scan.json.
- Sources techniques officielles consultées le 20 octobre 2026 : https://firebase.google.com/docs/functions/config-env#secret-manager et https://docs.cloud.google.com/firestore/docs/reference/rest/v1/projects.databases.collectionGroups.indexes/create.
