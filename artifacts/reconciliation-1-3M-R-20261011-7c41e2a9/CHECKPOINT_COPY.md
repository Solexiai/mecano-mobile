# CHECKPOINT MOVI-K — 1.3M-R — P1-COPY-001

Date : 11 octobre 2026. Branche fix/gps-client-history-scope-20261009. HEAD avant commit COPY : 7fc5a04cdf3ad421cccfa78b3cded73666903fb4. HOME est sauvegardé dans ce commit. Index vide avant cette sous-étape, aucun changement produit.

## État historique et correctif déjà présent

Ancienne affirmation « Service partout / Partout au Québec et ses environs » retrouvée par git show d563be2:lib/screens/home/home_screen.dart. Retrait/harmonisation présents dans 49e865c, les sources publiques actuelles sont identiques à la release 77c3c615 sur le périmètre comparé. Le rapport 1.3B et cinq captures historiques sont référencés avec SHA-256 dans HISTORICAL_AND_SOURCES.json. Aucune nouvelle modification commerciale ni fonctionnelle nécessaire.

## Texte actuel et contrat vérifié en lecture seule

| Sujet | Preuve actuelle | Limite conservée |
|---|---|---|
| Géographie | Accueil : lancement à Granby/environs et pré-lancement ; page Granby : Zone prévue | system_config/service_zones est dynamique, valeur live NON VÉRIFIÉE. serviceZones.ts a un repli historique permissif mais reviewBooking qualifie service_area_unconfigured si absent/désactivé. Aucun état de production déduit. |
| Chauffeurs | Disponibilité à confirmer, chauffeur admissible pouvant accepter, dossier à approuver | Dispatch sélectionne approved/online/documents validés/véhicule compatible ; absence de candidat laisse searching_driver. Aucune flotte réellement disponible prouvée. |
| Date / créneau | Préférence de date/heure, pas de créneau confirmé | requested_at ne prouve pas une réservation de capacité. Aucun délai garanti ajouté. |
| Devis / connexion | Préparer sans compte, connexion pour devis officiel, prix avant confirmation | Parcours invité testé en simulation HOME ; calcul financier réel non réexécuté. Aucun changement de calcul. |
| GPS | Suivi des étapes distingué du GPS actif ; validation appareils réels encore requise | Les corrections GPS locales antérieures et leur limite terrain restent inchangées. |
| Paiement | Disponibilité publique du moyen de paiement soumise à activation réellement confirmée | Ni Stripe LIVE ni Sandbox consulté/testé ; aucun prix, commission, snapshot ou ledger modifié. |
| Contact / QR | Contact à venir ; Granby ne promet ni réservation ni disponibilité ni transaction réelle | QR non prêt pour distribution publique tant que le canal fonctionnel n’est pas fourni et validé ; pas de changement prod. |

Le libellé chauffeur « Dossiers chauffeurs vérifiés » est rapproché des conditions d’approbation/documents dans acceptDelivery et du contexte explicite de pré-lancement, pas d’une affirmation qu’une flotte live existe. Les extraits et lignes sont dans COPY_CONTRACT_EVIDENCE.json. L’illustration française sur EN/ES et l’infobulle anglaise restent les P2 connus, non fermés.

## Tests réellement exécutés

- flutter --no-version-check test --no-pub --reporter=json --concurrency=1 test/public/public_launch_pages_test.dart --plain-name "public launch pages render in" : **3 réussis, 0 échoué, 0 ignoré** ; huit routes publiques réelles par langue (livraison, chauffeur, tarifs, fonctionnement, sécurité, FAQ, à propos, Granby). Les autres tests de ce fichier sont exclus par sélection, pas comptés comme réussis ni ignorés.
- flutter --no-version-check test --no-pub --reporter=json --concurrency=1 test/public/public_launch_copy_contract_test.dart : **12 réussis, 0 échoué, 0 ignoré** ; trois langues × 375×812, 430×932, 1440×900, 375×812 texte200%. Accueil, fonctionnement, FAQ réellement dépliée, Granby, chauffeur et tarifs ; clauses prudentes présentes, anciennes affirmations interdites absentes, aucune exception Flutter.
- HOME : 49 tests distincts réussis, dont les CTA devis/chauffeur, catégorie, brouillon et reprise après connexion simulée. Aucun code produit partagé changé ensuite, donc pas de relance GPS/finance.
- Analyse Flutter des douze fichiers COPY ciblés : aucune anomalie. Format des deux tests modifiés : aucun changement. git diff --check avant et après staging exigé.

## Isolation

Transport existant withOfflineTransport / offlineWidgetTest : HttpClient refusé et package:http client mémoire sans délégation ; aucun appel de tuile, aucune demande inattendue. Les tests vérifient Firebase.apps vide avant/après, auth backendConfigured:false et SharedPreferences fictif. Ces tests ne demandent aucun devis, n’appellent pas la réservation et n’initialisent aucun backend. Aucun lien externe cliqué. Le code serveur a seulement été lu. Ce n’est pas une preuve de confinement réseau OS, et 1.3L reste bloqué/reporté.

## Décision et limites

P1-COPY-001 : **FERMÉ — PÉRIMÈTRE LOCAL VALIDÉ — NON DÉPLOYÉ**. Défaut historique identifié, correction déjà présente et vérifiée dans trois langues, non-régressions pertinentes réussies ; fermeture autorisée par Daniel. Registre recalculé : **P0 0 / P1 0 / P2 10**, 27 fiches conservées. Les 10 P2, P3 historiques et prérequis du pilote restent intacts. Ni disponibilité live, ni paiement, ni créneau réel, ni conformité globale du lancement annoncée. Aucun nouveau Chrome, Web build, appareil physique ou consultation production.

Fichiers sauvegardés explicitement via VALIDATION_COPY.json : tests permanents, registre, synthèse de contrats, résultats et checkpoint. Bruts volumineux, captures historiques dupliquées, caches, builds, sauvegardes personnelles exclus. Aucun produit, finance, GPS, règle ou fonction serveur modifié. Prochaine séquence recommandée, non commencée : P2-G-02, localisation des montants/distances affichés, sans toucher aux calculs.
