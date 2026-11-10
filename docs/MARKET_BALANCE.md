# Équilibre offre / demande par ville

Ajouté le 10 novembre 2026, à la demande de Daniel. Le tableau dit, ville par ville et semaine par semaine, **s'il manque des chauffeurs, s'il manque des clients, ou si la ville est en équilibre**.

## Où le voir

Admin › **Équilibre par ville** (`/fr/admin/equilibre`). Les analystes et les administrateurs y ont accès. Les flèches changent de semaine (du lundi au dimanche, heure locale).

## Les deux signaux

| Signal | Calcul | S'il baisse |
|---|---|---|
| Taux d'acceptation | demandes prises ÷ (prises + restées « aucun chauffeur ») | il manque des chauffeurs |
| Livraisons par chauffeur | livraisons terminées ÷ chauffeurs approuvés de la ville, ramenées à 7 jours | il manque des clients |

Seuils de départ (`MARKET_BALANCE_THRESHOLDS`, `functions/src/lib/marketBalance.ts`), à ajuster après le pilote de Granby :

- il manque des chauffeurs sous **85 %** d'acceptation (dès 5 demandes tranchées), dès qu'une demande sur 10 reste sans chauffeur, ou s'il y a des demandes dans une ville sans chauffeur approuvé ;
- il manque des clients sous **2 livraisons par chauffeur approuvé et par semaine**.

La ville d'une demande vient de son adresse de ramassage ; celle d'un chauffeur, de la ville de son adresse de service. « Ville de Granby », « granby » et « GRANBY » sont la même ville. Les missions `internal_test` sont exclues.

## Ce qui est enregistré

| Donnée | Où | Depuis |
|---|---|---|
| Passages en ligne / hors ligne / en mission des chauffeurs | `market_balance_events` (`type: driver_status`) | déploiement de cette PR |
| Moment où une demande passe « aucun chauffeur » | `market_balance_events` (`type: mission_no_driver`) | déploiement de cette PR |
| Raison facultative d'un refus (trop loin, prix trop bas, pas de place, pas disponible, autre) | `delivery_offers.decline_reason` | déploiement de cette PR |
| Demandes, offres, acceptations, annulations, livraisons, devis | déjà enregistrés | avant |

Les heures en ligne n'apparaissent qu'à partir de la première semaine entièrement couverte par le journal. Elles mesurent le temps où le chauffeur s'est mis « en ligne » dans l'app, pas forcément le temps où il regardait son écran.

## Ce qui ne change pas

Le dispatch, les offres, les paiements, les taxes et les règles d'écriture des missions ne changent pas. Les triggers écrivent seulement dans `market_balance_events`. Le refus d'une offre fonctionne comme avant ; la raison est demandée **après** le refus et peut être passée.

## Suite prévue

Les robots (analyste, recrutement, pub) viendront ensuite. Ils liront les mêmes chiffres que ce tableau.
