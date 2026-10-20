# Décision produit — confirmation de la période complète par le chauffeur

- Version : MOVIK-DURATION-CONFIRMATION-20261020-001.
- Statut : APPROUVÉE par Daniel dans cette conversation.
- Date de l'approbation : 20 octobre 2026 à 12:56:15, America/Toronto (UTC−04:00).
- Source primaire : message utilisateur du propriétaire, reproduit ci-dessous.
- Code examiné : commit local a8674e3d4e628851f9cdf9a882282e108ccb02c7, branche feat/driver-agenda-20261020.

## Approbation exacte

> oui j'approuves que le chauffeur confirme, avant d’accepter, toute la période nécessaire à la mission — chargement, trajet et déchargement compris — afin de réserver ce créneau dans son agenda

## Règle approuvée

Avant d'accepter une mission, le chauffeur confirme explicitement toute la période nécessaire au chargement, au trajet et au déchargement. Le créneau confirmé est réservé dans son agenda au moment de l'attribution, avec les contrôles serveur existants de disponibilité et de concurrence.

Le code préparé présente aussi les contraintes d'accès pour aider le chauffeur à évaluer cette période. Il conserve l'heure de ramassage demandée par le client et n'assimile pas la durée estimée du trajet à la durée totale. Aucun forfait de manutention ni seuil de durée n'est créé par cette décision.

## Portée de cette décision

Cette approbation résout uniquement la décision produit de confirmation de durée. Elle ne vaut pas :
- autorisation de push, de fusion, de déploiement ou d'activation dans Firebase ;
- approbation de l'horizon maximal de réservation ou d'un nouveau cycle de paiement ;
- consentement OAuth, approbation des textes de confidentialité ou validation d'un véhicule ;
- autorisation de mission, notification chauffeur ou transaction réelle.

Le paramètre duration_confirmation_approved peut donc être préparé à true dans l'exemple documentaire. enabled et approved restent false ; max_advance_minutes reste null tant que l'horizon commercial n'a pas été décidé. Aucun document Firebase n'est écrit.

## Vérification de concordance

- lib/widgets/driver_slot_confirmation.dart : affichage de la période complète et confirmation explicite.
- functions/src/lib/driverScheduling.ts : confirmedSlot refuse l'absence de full_duration_confirmed ; prepareReservation contrôle et réserve l'intervalle dans la transaction.
- functions/test/unit/agendaScheduling.test.ts : scénario existant de refus sans confirmation explicite.

Intervention documentaire uniquement ; aucun code applicatif modifié, aucune suite réexécutée. Les résultats du rapport DRIVER_AGENDA_COMPLETE_20261020.md restent des validations locales antérieures, sans nouvelle validation de production.

Prochaine décision commerciale : horizon maximal de réservation, à rendre compatible avec le cycle de paiement existant. P1-BOOKING-CONFIG-01 demeure ouvert ; aucun décompte historique n'est modifié.
