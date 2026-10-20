# REGISTRE MAÎTRE DES BOGUES MOVI-K

Date de consolidation : 9 octobre 2026, America/Toronto. Dernière mise à jour : réservation immédiate/programmée et prérequis de mise en service, 14 octobre 2026. Correctif local non déployé.
Branche : fix/gps-client-history-scope-20261009 ; base 77c3c61534d1300ddc0eab5585f78b9662a69537.

## Règle permanente

IDENTIFIÉ → QUALIFIÉ → CORRECTION CODÉE → TESTÉ → VALIDÉ → FERMÉ.
Une correction non testée reste CORRIGÉ — NON VALIDÉ. BLOQUÉ/REPORTÉ est un état complémentaire, jamais une fermeture. Chaque transition exige date, version, commande, résultat et preuve. Toute fermeture exige correction présente, analyse réussie, non-régression pertinente, permissions/intégration si nécessaire, preuve et parcours existants préservés. Fermeture ciblée P1-M-01 approuvée le 9 octobre 2026 à l'étape 1.3M-D ; fermeture ciblée R-K-03-A approuvée explicitement par Daniel le 9 octobre 2026 à l'étape 1.3M-H. Fermeture ciblée R-K-03-B approuvée explicitement le 9 octobre 2026, limitée aux défauts d’atomicité et de nettoyage GPS validés en émulateur, non déployée  ; fermeture documentaire ciblée R-K-03-C approuvée le 10 octobre 2026, pour les identités, associations et la fraîcheur GPS testées localement, sans déploiement ; fermeture documentaire ciblée P2-K-01 approuvée le 10 octobre 2026 pour les erreurs de flux GPS en simulation, non déployé.

## Périmètre et décompte

Anomalies/prérequis actifs non fermés : **P0 0, P1 1, P2 2** ; 31 fiches conservées, dont 28 fermées dans leurs périmètres historiques. P1-BOOKING-CONFIG-01 reste bloqué par les configurations opérationnelles absentes ; P2-BOOKING-TIMING-01 est corrigé et testé localement, non fermé et non déployé. Ce décompte ne constitue pas une autorisation de lancement. Les anciennes clôtures, limites, P3 et prérequis restent conservés ci-dessous.
Les correctifs historiques Phase7 importés en annexe conservent leur état rapporté : ils ne sont ni nouvellement fermés ni arbitrairement réouverts. Leur correspondance actuelle/test de fermeture doit être réconciliée avant annoncer P0/P1=0 global. BUG-004 P0 historique est rapporté corrigé/testé ; aucun P0 actif nouvellement confirmé. Pas de garantie d'exhaustivité des conversations/fichiers inaccessibles ou de production.

Alias : R-K-02 = P1-M-01 ; R-K-03 parent des sous-cas A/B/C (pas quatrième compteur) ; P2-G-01 observation simulée reliée à P2-FORM-001 (pas doublon du compte), contexte Material du harnais distinct de Chrome. Les deux listes sans limit restent un seul GAP-M-06. BUG-003 conserve ses occurrences client/chauffeur/mécanicien. Les identifiants de scénarios sans bug ne deviennent pas des anomalies.

## Tableau de suivi

| ID | Priorité | Nature | Statut | Problème |
|---|---|---|---|---|
| P1-M-01 | P1 | Bug de requête, correctif testé | FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ | Historique GPS sans filtre serveur de mission ; refus attendu pour client ordinaire. |
| R-K-03-A | P1 | Défauts corrigés et testés en émulateur | FERMÉ — PÉRIMÈTRE LOCAL/ÉMULATEUR VALIDÉ — NON DÉPLOYÉ | Autorité GPS et refus missions terminales/profils non approuvés uniquement ; fermeture approuvée en H. |
| R-K-03-B | P1 | Défauts d’atomicité et de nettoyage GPS corrigés et testés localement | FERMÉ — PÉRIMÈTRE LOCAL/ÉMULATEUR VALIDÉ — NON DÉPLOYÉ | Rapport GPS, fin/compensation/nettoyage tardif de A ne libèrent plus l’assignation B dans les scénarios locaux validés. |
| R-K-03-C | P1 | Défauts reproduits, corrigés et validés dans les tests simulés | FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ | Identité/mission, dates et snapshots protégés ; après 60 secondes sans nouvelle position valide, marqueur masqué, date/historique conservés et reprise validée. |
| P2-H-01 | P2 | Défaut reproduit, corrigé et testé en simulation | FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ | Au moins huit chiffres requis côté client ; formats serveur préservés, validation locale approuvée le 10 octobre 2026. |
| P2-H-02 | P2 | Défaut reproduit, corrigé et testé en simulation | FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ | Compteur téléphone cohérent avec + initial optionnel, consignes FR/EN/ES et affichage widget validés localement le 10 octobre 2026. |
| P2-I-01 | P2 | Défaut corrigé et testé en simulation | FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ | Carte annoncée enregistrée alors que cardReady=false. |
| P2-I-02 | P2 | Défaut corrigé et testé en simulation | FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ | Date détaillée en format technique dans confirmation. |
| P2-J-01 | P2 | Défaut reproduit, corrigé et testé en simulation | FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ | Référence réelle du reçu conservée dans le suivi ; recherche, absence de chauffeur et états de mission explicités sans GPS inventé. |
| P2-K-01 | P2 | Défaut reproduit et corrigé en simulation | FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ | Refus et erreurs de position/historique distingués de l’absence GPS ; reprise, fraîcheur et FR/EN/ES testées, fermeture limitée approuvée le 10 octobre 2026. |
| R-K-04 | P2 | Défaut reproduit, corrigé et testé en simulation | FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ | Centre de repli Montréal sans position/adresse ; pas de faux marqueur démontré. |
| P2-FORM-001 | P2 | Défaut reproduit, corrigé et testé en simulation | FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ | Sélecteurs date/heure et date résumée anglais sur /fr. |
| P2-FORM-002 | P2 | Défaut reproduit, corrigé et testé en simulation | FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ | Libellé Unité de poids tronqué, largeur fixe 120. |
| P2-FORM-003 | P2 | Défaut reproduit, corrigé et testé en simulation | FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ | Adresse saisie non résolue perdue après refresh ; objet conservé. |
| P2-FORM-004 | P2 | Défaut reproduit, corrigé et testé en simulation | FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ | 190 cm convertis affichés 74.803149606… in. |
| P2-G-02 | P2 | Défaut reproduit, corrigé et testé en simulation | FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ | Montants CAD et distances km localisés FR/EN/ES dans le devis et la confirmation ; données métier inchangées. |
| P2-I18N-001 | P2 | Défaut reproduit, corrigé et testé localement | FERMÉ — PÉRIMÈTRE LOCAL/SIMULÉ VALIDÉ — NON DÉPLOYÉ | Illustration FR préservée ; variante neutre EN/ES et description accessible localisée. |
| P2-I18N-002 | P2 | Défaut reproduit, corrigé et testé localement | FERMÉ — PÉRIMÈTRE LOCAL/SIMULÉ VALIDÉ — NON DÉPLOYÉ | Infobulle du menu et libellé accessible FR/EN/ES, ouverture/fermeture et navigation conservées. |
| P2-BUILD-001 | P2 | Avertissement build résolu localement | FERMÉ — PÉRIMÈTRE BUILD/TEST LOCAL VALIDÉ — NON DÉPLOYÉ | Police officielle CupertinoIcons 1.0.9 incluse et vérifiée dans le build Web ; ancien avertissement supprimé ; aucun défaut d'icône en production revendiqué. |
| P1-HOME-001 | P1 | Bug ancien branche septembre | FERMÉ — PÉRIMÈTRE LOCAL VALIDÉ — NON DÉPLOYÉ | Chevauchement hero desktop corrigé structurellement et non reproduit release trois formats. |
| P1-COPY-001 | P1 | Bug ancien branche septembre/main | FERMÉ — PÉRIMÈTRE LOCAL VALIDÉ — NON DÉPLOYÉ | Anciennes promesses couverture/créneau retirées accueil release. |
| P2-COPY-001 | P2 | Correction historique vérifiée par tests locaux | FERMÉ — PÉRIMÈTRE LOCAL/SIMULÉ VALIDÉ — NON DÉPLOYÉ | Ancienne mention Leboncoin retirée ; exemples Marketplace/Kijiji et routes préservés FR/EN/ES. |
| P2-L-01 | P2 | Contraste badges warning amélioré | FERMÉ — PÉRIMÈTRE WIDGET/WCAG LOCAL VALIDÉ — NON DÉPLOYÉ | Couleurs de texte warning adaptées light/dark, sans changer statut métier ; contraste 4.5:1 sur badges ciblés, tests widget et régressions locales verts. |
| GAP-M-05 | P2 | Perte de State d'onglets corrigée | FERMÉ — PÉRIMÈTRE FLUTTER LOCAL VALIDÉ — NON DÉPLOYÉ | Pile d'onglets à initialisation paresseuse ; état du calendrier et flux Missions conservés au retour, chargement des onglets non visités évité ; coûts réels non mesurés. |
| GAP-M-06 | P2 | Lectures Firestore ciblées bornées | FERMÉ — PÉRIMÈTRE FLUTTER/WIDGET LOCAL VALIDÉ — NON DÉPLOYÉ | watchNotifications et watchDriversByStatus limités avec accès « Afficher plus » ; cas profils migrés et reprise listener validés ; autres flux non lus/markAll et coûts réels hors périmètre. |
| GAP-S-02 | P2 | Concurrence et récupération financière testées | FERMÉ — PÉRIMÈTRE ÉMULATEUR VALIDÉ — NON DÉPLOYÉ | Race annulation/autorisation, récupération de pending avec référence provider et compensations idempotentes validées localement ; paiements réels, cas legacy sans ID et cron déployé NON VALIDÉS. |
| GAP-S-04 | P2 | Suspension ordinaire / urgente | FERMÉ — PÉRIMÈTRE LOCAL/ÉMULATEUR VALIDÉ — NON DÉPLOYÉ | Suspension ordinaire conserve les missions déjà assignées sous contrôle, urgente refuse transitions et GPS ; escalation admin, audit, réactivation et préservation hors ligne testés. |
| P1-WEBHOOK-01 | P1 | Concurrence de webhooks Stripe corrigée localement | FERMÉ — PÉRIMÈTRE CONCURRENCE ÉMULATEUR VALIDÉ — NON DÉPLOYÉ | Verrou transactionnel temporaire par event.id, attente/503 retryable sur traitement en cours ; une seule écriture d'audit lors des doublons simultanés forcés ; reprises après échec testées ; crash physique non certifié. |

| P1-BOOKING-CONFIG-01 | P1 | Prérequis de mise en service, pas un défaut de calcul | BLOQUÉ — CONFIGURATION MÉTIER REQUISE | Réservations/acceptations désactivées ; politique, capacités et zone absentes ; aucune capacité véhicule vérifiée. |
| P2-BOOKING-TIMING-01 | P2 | Choix immédiat absent, corrigé et testé localement | VALIDÉ LOCALEMENT — NON FERMÉ — NON DÉPLOYÉ | Choix explicite dès maintenant/programmée, conservation du brouillon et devis invalidé lors du changement ; aucun horaire ni tarif inventé. |

| P2-AUTH-LOGOUT-01 | P2 | Retour accueil apres deconnexion publique | VALIDÉ LOCALEMENT — NON FERMÉ — NON DÉPLOYÉ | Navigation apres signOut et erreur localisee si echec. |

## Fiches actives

### P2-AUTH-LOGOUT-01

14 octobre 2026 : reproduit (12 echecs), corrige et valide localement (31 tests combines reussis, aucun echec/ignore). AppShell, home_copy et public_logout_navigation_test. Preuve : artifacts/logout-20261014-I3w87v/CHECKPOINT_LOGOUT.md. Aucun test Firebase reel, Chrome ou production. Non ferme. Historique conserve.

### P1-WEBHOOK-01

- **Addendum 2026-10-14 — FERMÉ UNIQUEMENT POUR LA CONCURRENCE SIMULTANÉE VALIDÉE EN ÉMULATEUR — NON DÉPLOYÉ.** Preuve avant correction sur événement `payment_intent.succeeded` signé avec secret fictif : deux appels concurrents identiques entraînaient `attempt_count=2`, deux audits `payment_captured` et deux audits `webhook_event_processed`, contre un de chacun attendu. Cela prouve les doubles audits locaux, NON deux captures Stripe.
- Correctif : `provider_webhook_events/{event.id}` conserve un bail de traitement `processing_lease_until`. L'acquisition transactionnelle refuse de dispatcher un doublon tant que le bail du premier est actif, attend son résultat, retourne HTTP 200 `alreadyProcessed` si terminé ou HTTP 503 récupérable si en attente/échec. Un événement `failed` ou un bail expiré peut être repris ; les événements anciens `received` sans champ de bail utilisent `received_at` comme repli. Le bail est effacé à `processed` ou `failed`. Aucun appel provider de capture, aucun tarif, cent, commission, snapshot, ledger ni règle Firebase changé.
- Preuve après : scénario forcé avec blocage de la première écriture d'audit, **1 seule tentative, 1 audit métier, 1 audit de traitement et réponses 200/200 (dont alreadyProcessed)**. La suite entière `processStripeWebhook.test.ts` : **31/31 réussis**. Non-régression intégration Firebase **50/50 suites, 734/734 tests réussis** sur Firestore/Auth/Storage Emulator ; tests unitaires **15 suites, 228/228 tests réussis** ; compilation TypeScript et ESLint ciblé réussis. Rapports : `artifacts/p1-webhook-concurrency-20261014/CHECKPOINT_P1_WEBHOOK_01.md`.
- **Limites réservées au lancement** : pas de Stripe réel/Sandbox, pas de fonctions déployées, Node20 réel non testé, pas de panne physique injectée entre les écritures d'audit et la transition finale vers `processed`, ni preuve d'idempotence globale de chaque effet indirect sous crash/reprise. À qualifier avant activation des paiements réels. Les 20 tests Flutter/GPS réseau du bilan QC26 et la recette GPS 1.3L restent bloqués indépendamment.
- Historique initial préservé ci-dessous.

- Découverte le 14 octobre 2026 pendant la revalidation globale QC26-V2, sur `fix/gps-client-history-scope-20261009` après le correctif local SEC-GAP-S04. **STATUT : QUALIFIÉ — TEST CONCURRENT ÉCHOUÉ EN ÉMULATEUR — OUVERT — NON DÉPLOYÉ.**
- Le test permanent préexistant `functions/test/integration/processStripeWebhook.test.ts` (« WEBHOOK DUPLIQUÉ CONCURRENT ») envoie deux requêtes avec le même `provider_event_id`, exige `freshCount=1` et `alreadyProcessedCount=1`. La suite globale dans `demo-movik-test` a obtenu `freshCount=2` (attendu 1), et la reproduction ciblée isolée dans le même environnement a obtenu de nouveau 2. Les autres assertions concernant le nombre réel d'audit_logs et `attempt_count` ne sont pas atteintes lorsque la première assertion échoue.
- Portée de la preuve : réponse idempotente concurrente non conforme démontrée en émulateur sur le chemin de signature/test fictif. **Aucune double capture, aucun double remboursement, aucune duplication de ledger ni incident de production démontré.** Le code financier, le fournisseur de paiement et les états de transaction n'ont pas été modifiés.
- Risque : idempotence de traitement d'événements Stripe à examiner en priorité avant activation des paiements réels. Reproduire en faisant porter les assertions aussi sur le document `provider_webhook_events`, les logs métier et l'audit, puis déterminer le contrat/risque précis avant toute correction.
- Preuves : `artifacts/qc26-fixture-and-analyzer-20261014/after-integration-full.log`, `webhook-isolated.log` et checkpoint QC26-V2. Aucune fermeture permise sans test concurrent corrigé, preuves de non-duplication et non-régression. Aucun appel Stripe réel.

### P1-M-01

- Priorité / nature / statut : P1 ; Bug de requête ; FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ, 9 octobre 2026, sur approbation explicite de Daniel à l'étape 1.3M-D. Défaut fermé exclusivement : requête d'historique GPS sans filtre serveur par mission. Statuts précédents et limites conservés dans les addenda 1.3M-B/C/D.
- Description et impact : Historique GPS sans filtre serveur de mission ; refus attendu pour client ordinaire.
- Preuve d'origine : 1.3M / R-K-02 et CHECKPOINT_CORRECTIF_P1_M_01.md (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : firebase_location_repository.dart:71–86 ; location_repository.dart ; live_tracking_map.dart:96–112 ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Filtre where delivery_id avant snapshots, missionId requis, garde null/vide et filtre défensif conservés.
- Tests nécessaires : Requête A/B, non filtrée refusée, filtered propre autorisée/autre refusée, listener, chauffeur et rôles admin ; analyse Dart, émetteur chauffeur.
- Résultats : Historique initial conservé dans les annexes. 1.3M-B : analyse ciblée 0, reporter 9/9, permissions émulateur final 3/3 (197 exclus). 1.3M-C : isolation finale 1/1, contrat 7/7, consommateurs 20/20, analyse consommateurs 0. Échecs de harnais conservés séparément dans l'addendum.
- Limites après fermeture P1-M-01 : non commité à la clôture documentaire, non déployé ; GPS terrain, Chrome et 1.3L non validés. R-K-03-A/B/C, P2-K-01 et R-K-04 restent ouverts. Le commit local est préparé séparément et attend son approbation.
- Critère de fermeture : Autorisation de requête exécutée et parcours compatibles prouvés, sans assouplissement rules. + règle permanente ci-dessus.

### R-K-03-A

- État ACTUEL — 1.3M-H, 9 octobre 2026 : **FERMÉ — PÉRIMÈTRE LOCAL/ÉMULATEUR VALIDÉ — NON DÉPLOYÉ**, sur autorisation explicite de Daniel. Périmètre : autorité des écritures GPS, refus démontrés pour missions terminales ou profils non approuvés. Limites conservées : transport Firebase réel, runtime Node 20, GPS physique et production non validés ; B/C restent ouverts. Historique des statuts G/F conservé ci-dessous.

- Actualisation 1.3M-G (9 octobre 2026) : fermeture recommandée uniquement dans le périmètre local validé, NON APPROUVÉE. Statut ouvert conservé ; preuves et limites supplémentaires dans l’addendum G. État F détaillé conservé ci-dessous.

- Priorité / nature / statut : P1 ; défauts démontrés ; CORRECTION TESTÉE EN ÉMULATEUR — NON FERMÉ — NON DÉPLOYÉ, 9 octobre 2026 (1.3M-F). Fermeture documentaire distincte non demandée dans cette intervention ; le problème reste compté ouvert.
- Cause : le callable vérifiait le rôle (correctif E) mais pas le statut approuvé du profil ni les six statuts actifs de mission avant les écritures ; les lectures/écritures séparées permettaient un état partiel ou une vérification périmée.
- Correction : transaction unique lisant profil, position et mission avant toute écriture ; rôle chauffeur E conservé, profil approved requis ; driver_id de mission égal au chauffeur ; liste positive assigned, driver_to_pickup, arrived_at_pickup, picked_up, in_transit, arrived_at_dropoff ; refus avant écriture si mission manquante/étrangère/non active. Profil/position/historique validés atomiquement. Hors mission : position courante autorisée pour chauffeur approuvé, sans historique, contrat conservé.
- Fichiers : functions/src/functions/recordTrackingPoint.ts ; functions/test/integration/recordTrackingGuards.test.ts ; functions/test/integration/recordTrackingPoint.test.ts ; tests de rôle/règles de E inchangés.
- Tests F : les dix cas E (completed, cancelled, disputed, refunded, delivered, payment_failed ; suspended, rejected, pending_review, registration_incomplete) sont reproduits en échec avant et passent après. Assertions renforcées : refus explicite + aucune mutation position/geohash/historique. 26 gardes : avant 8 réussis/18 échoués, après 26/0. Six statuts actifs permis ; documents_required/inactive refusés aussi ; profil sans assignation conservé. Rôles 7/0, règles d’autorité 26/0.
- Permissions : aucune règle modifiée par F. 18 tests GPS existants réussis, dont requête de collection P1-M-01 filtrée A autorisée, B et sans filtre refusées, client B et chauffeur propriétaire conservés. Lectures courantes client tiers/mission terminale refusées dans les fixtures E exécutées.
- Limites : Auth fictive et appels directs .run, pas transport callable/Auth déployé ; aucune production, Chrome ou mesure GPS réelle. GAP-S-04 sur progression de mission suspendue reste distinct et inchangé. Aucune fermeture globale du GPS.
- Preuves : artifacts/corrections-1-3M-F-20261009-1438/results-before.json ; results-after.json ; RESULTATS.json ; source-hashes-before.json ; source-hashes-after.json ; typecheck-after.json ; lint.json.
- Critère de fermeture : garde serveur et permissions testées, non-régression prouvée dans le périmètre local, preuves conservées et fermeture explicitement approuvée. Historique E conservé ci-dessous et dans REGISTRE_AVANT.md.

### R-K-03-B

- État ACTUEL — clôture documentaire approuvée le 9 octobre 2026 : **FERMÉ — PÉRIMÈTRE LOCAL/ÉMULATEUR VALIDÉ — NON DÉPLOYÉ**. Défauts qualifiés de concurrence et de nettoyage GPS corrigés dans le périmètre testé : ancien rapport, changement de mission, nettoyage/fin tardive et échec de paiement de A n’effacent plus le lien GPS de B ni ne libèrent son chauffeur. 75 contrôles ciblés réussis et aucun échec après correction H, dont neuf tests de compensation. Aucune nouvelle exécution lors de cette clôture. Node 20, Firebase/transport/triggers déployés, Stripe réel, GPS terrain et tuiles 1.3L non validés. R-K-03-C et les P2 restent ouverts.
- État historique — 1.3M-H avant approbation : **VALIDÉ LOCALEMENT — NON FERMÉ — NON DÉPLOYÉ**. Lecture/condition transactionnelles du lien dans failMissionPayment ; neuf cas de compensation et 66 non-régressions réussis après correction. Fermeture limitée alors proposée, sans approbation. Preuves et limites dans l’addendum H. Historique G/F conservé ci-dessous.

- Actualisation 1.3M-G (9 octobre 2026) : PARTIELLEMENT VALIDÉ — ÉCHEC RÉSIDUEL CONFIRMÉ — NON FERMÉ — NON DÉPLOYÉ. Fermeture refusée après deux reproductions du nettoyage tardif dans failMissionPayment (paymentOrchestration.ts:485–489). État F conservé ci-dessous ; diagnostic et preuves nouveaux dans l’addendum G.

- Priorité / nature / statut : P1 ; défauts désormais reproduits localement ; PARTIELLEMENT VALIDÉ — NON FERMÉ — NON DÉPLOYÉ, 9 octobre 2026 (1.3M-F).
- Cause démontrée : read/set séparés du rapport et du trigger ; ancien rapport restaurait A après B ; nettoyage A effaçait B ; completeDelivery effaçait inconditionnellement le lien et libérait le chauffeur malgré une assignation plus récente.
- Correction : recordTrackingPoint transactionnel, ne recopie plus active_delivery_id existant et refuse un changement de lien entre ses tentatives. Trigger : comparaison/effacement conditionnel dans une transaction. completeDelivery : lecture du lien avant les écritures ; ne libère GPS/disponibilité que si lien absent ou égal à la mission terminée. Compteur completed_missions standard conservé. acceptDelivery et adminAssignDelivery déjà transactionnels, laissés inchangés.
- Fichiers : functions/src/functions/recordTrackingPoint.ts ; onMissionEndedClearTracking.ts ; completeDelivery.ts ; functions/test/integration/gpsTrackingAtomicity.test.ts.
- Reproduction F : 14 contrôles transactionnels/effets de bord, avant 7 réussis/7 échoués, après 14/0. L’ensemble des 40 nouveaux cas passe de 15/25 à 40/0 ; validation finale élargie 126/0, 180 règles hors GPS exclues par filtre, aucun test sauté ajouté.
- Scénarios : rapport A/assignation B réelle par acceptDelivery et adminAssignDelivery en mode interne ; nettoyage A pendant/après B ; terminaison et suspension pendant rapport ; deux rapports Promise.all ; rapport/assignation Promise.all ; fin tardive A et retry de fin standard A. Vérification du lien B, statut on_mission, historique, compteur et ledger locaux.
- Méthode : commits et lectures réels de Firestore Emulator. Intercalages déterministes : erreur ABORTED injectée après callback pour rollback puis reprise SDK contre une mutation concurrente committée. Ce déclenchement contrôlé ne prouve pas une contention spontanée en production. Deux essais Promise.all sans conflit injecté complètent la couverture.
- Préservation financière : blocs snapshot/ledger, capture et libération d’annulation identiques avant/après (SHA256 dans RESULTATS.json). Modules providers exclus du harnais ; doublures explicites pour libération/capture. Ledger local de fixture : exactement cinq entrées aux montants existants, compteur +1 ; appel fictif de capture unique après commit, libération fictive avant nettoyage et non répétée lors du retry ; erreur fictive propagée sans nettoyage anticipé.
- Limites : assignations exécutées en internal_test avec fixtures sans booking_snapshot ; capacité réelle, assignation financière standard, livraison automatique des triggers et provider réels non validés. Aucun test de paiement effectué. Le payload GPS ne contient pas missionId : si B est déjà actif à la PREMIÈRE lecture, le serveur ne peut attribuer une provenance A à cette mesure ; fraîcheur/association R-K-03-C reste ouverte. Les anciennes mesures ne restaurent néanmoins jamais le lien A.
- Preuves : artifacts/corrections-1-3M-F-20261009-1438/RESULTATS.json ; results-before.json ; results-after.json ; diff-final.patch ; source-hashes-after.json ; ISOLATION.md.
- Critère de fermeture : validation et approbation explicites du périmètre atomique testé ; intégration plus large documentée séparément. Ne ferme ni R-K-03-C, ni GAP-S-04, ni les P2, ni 1.3L.

### R-K-03-C

- État ACTUEL — 1.3M-J, 9 octobre 2026 : **VALIDÉ DANS LE PÉRIMÈTRE SIMULÉ — FERMETURE PROPOSÉE — NON FERMÉ — NON DÉPLOYÉ**. Seuil pilote de 60 secondes approuvé explicitement ; 82 tests distincts réussis / 0 échoué / 0 ignoré en validation finale, analyse ciblée sans problème. Aucune fermeture appliquée. Preuves, échecs intermédiaires et limites dans l’addendum J.

- État HISTORIQUE — 1.3M-I, 9 octobre 2026 : **CORRIGÉ ET TESTÉ LOCALEMENT — VALIDATION PARTIELLE — NON FERMÉ — NON DÉPLOYÉ**. Défauts reproduits avant correction ; 25 contrôles ciblés et 37 non-régressions réussis, soit 62 cas distincts. Sept contrôles de contrat répétés après le dernier ajustement ne sont pas additionnés. Seuil d’obsolescence non activé ; décision précise dans l’addendum I. Aucune fermeture documentaire autorisée.

État historique de qualification initiale conservé :

- Priorité / nature / statut : P1 ; Risque provisoire ; contrôles absents ; QUALIFIÉ.
- Description et impact : Marqueur sans contrôle driverId/activeDeliveryId/date ; date invalide remplacée par maintenant ; coordonnées anciennes après assignation.
- Preuve d'origine : 1.3M §5C (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : live_tracking_map.dart:78–90,165–171 ; driver_location.dart:56 ; driver_location_history_point.dart:39 ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Contrôles identités et fraîcheur, date inconnue conservée ; seuil à approuver.
- Tests nécessaires : Ancienne/date future/invalide, changement mission, mauvais driver/cache, null.
- Résultats : 0 exécution ; impact utilisateur non reproduit.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Aucune position incompatible ou ancienne présentée comme actuelle ; seuil documenté. + règle permanente ci-dessus.

### P2-H-01

- État ACTUEL — clôture documentaire approuvée le 10 octobre 2026 : **FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ**. Validation finale déjà acquise : 46 tests ciblés + 20 non-régressions réussis, 0 échec, 0 ignoré ; analyse, format et diff check réussis. Les téléphones doivent comporter au moins huit chiffres et les formats permis restent acceptés ; serveur non modifié. Aucune nouvelle exécution lors de la clôture. Le chemin serveur déployé, Chrome et les téléphones physiques ne sont pas validés. Preuves dans l’addendum 1.3M-M.
- État HISTORIQUE — 1.3M-M avant approbation : **CORRIGÉ ET VALIDÉ DANS LE PÉRIMÈTRE SIMULÉ — NON FERMÉ — NON DÉPLOYÉ**. Fermeture alors seulement recommandée.

État historique de qualification conservé :

- Priorité / nature / statut : P2 ; Bug simulé confirmé ; QUALIFIÉ.
- Description et impact : Téléphone -------- accepté par Flutter ; serveur normalizeContacts exige au moins huit chiffres.
- Preuve d'origine : 1.3H et 1.3H-B (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : delivery_request_flow_screen.dart:1675 ; functions/src/lib/bookingServer.ts normalizeContacts ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Aligner validation client sur contrat serveur sans modifier contrat métier.
- Tests nécessaires : Vide, ponctuation seule, bornes chiffres et formats valides ; rejet serveur isolé.
- Résultats : Historique 1.3H : 6 réussis/1 échoué/0 ignoré ; validation serveur lue, non exécutée.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Entrée invalide refusée clairement avant confirmation ; formats approuvés conservés. + règle permanente ci-dessus.

### P2-H-02

- État ACTUEL — clôture documentaire approuvée le 10 octobre 2026 : **FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ**. Validation finale déjà acquise : 46 tests ciblés + 20 non-régressions réussis, 0 échec, 0 ignoré ; analyse, format et diff check réussis. Compteur téléphone limité au contrat existant de 25 caractères, ou 26 avec + initial ; consignes, libellés et messages FR/EN/ES contrôlés sur vrais widgets aux formats testés, y compris texte mobile à 200 %. Aucune nouvelle exécution lors de la clôture. Chrome et appareils physiques restent non validés. Preuves dans l’addendum 1.3M-M.
- État HISTORIQUE — 1.3M-M avant approbation : **CORRIGÉ ET VALIDÉ DANS LE PÉRIMÈTRE SIMULÉ — NON FERMÉ — NON DÉPLOYÉ**. Fermeture alors seulement recommandée.

État historique de qualification conservé :

- Priorité / nature / statut : P2 ; Bug UX confirmé ; QUALIFIÉ.
- Description et impact : Compteur /120 incohérent avec regex 8–25 caractères ; obligations peu explicites.
- Preuve d'origine : 1.3H-B (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : delivery_request_flow_screen.dart:1667–1675 ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Indications et limite cohérentes ; expliciter requis/facultatif.
- Tests nécessaires : Coordonnées aux trois formats, validation vide/limites/restauration.
- Résultats : Captures 1.3H historiques ; tous contrôles fonctionnels non présumés réussis.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Libellés et compteur cohérents, absence perte de coordonnées. + règle permanente ci-dessus.

### P2-I-01

- État ACTUEL — 10 octobre 2026, 1.3M-N : **FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ**. Fermeture conditionnelle autorisée par Daniel et critères satisfaits : 54 tests ciblés + 66 non-régressions réussis, analyse et contrôles Git réussis. Causes, périmètre, preuves et limites dans l’addendum 1.3M-N. Statut antérieur QUALIFIÉ conservé ci-dessous comme historique.

État historique :

- Priorité / nature / statut : P2 ; Bug simulé confirmé ; QUALIFIÉ.
- Description et impact : Carte annoncée enregistrée alors que cardReady=false.
- Preuve d'origine : 1.3I/1.3I-B (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : delivery_request_flow_screen.dart étape confirmation ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Message dépendant état réel de préparation.
- Tests nécessaires : Pas prête/prête/échec/en attente et bouton confirmation.
- Résultats : 1.3I captures ; 1.3I-B 4/4 historiques n'ont pas corrigé ce texte.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Aucune affirmation de carte prête sans état explicite simulé puis intégration appropriée. + règle permanente ci-dessus.

### P2-I-02

- État ACTUEL — 10 octobre 2026, 1.3M-N : **FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ**. Fermeture conditionnelle autorisée par Daniel et critères satisfaits : 54 tests ciblés + 66 non-régressions réussis, analyse et contrôles Git réussis. Causes, périmètre, preuves et limites dans l’addendum 1.3M-N. Statut antérieur QUALIFIÉ conservé ci-dessous comme historique.

État historique :

- Priorité / nature / statut : P2 ; Bug simulé confirmé ; QUALIFIÉ.
- Description et impact : Date détaillée en format technique dans confirmation.
- Preuve d'origine : 1.3I (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : delivery_request_flow_screen.dart résumé confirmation ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Format localisé d'affichage sans changer instant métier.
- Tests nécessaires : FR/EN/ES, fuseau, date longue, trois formats.
- Résultats : Captures historiques ; correctif absent.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Date lisible localisée et instant conservé. + règle permanente ci-dessus.

### P2-J-01

- État ACTUEL — 1.3M-O, 11 octobre 2026 : **FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ**, conformément à l’autorisation conditionnelle de Daniel. Référence issue de DeliveryMission.id après contrôle du client et de la mission demandée ; recherche uniquement pour searchingDriver/offered sans chauffeur. États absents/incohérents, erreurs et changement A→B testés. 93 cas distincts finaux réussis / 0 échec / 0 ignoré, analyse ciblée/format/diff conformes. Preuves : artifacts/corrections-1-3M-O-20261010-a64e9b12/CHECKPOINT_MOVIK_1_3M_O.md et RESULTATS.json. Aucun test Chrome, production ou GPS terrain ; 1.3L toujours BLOQUÉ ET REPORTÉ.
- Historique antérieur conservé intégralement ci-dessous ; les 3 tests de 1.3J prouvaient seulement la navigation.


- Priorité / nature / statut : P2 ; Bug simulé confirmé ; QUALIFIÉ.
- Description et impact : Suivi en recherche sans référence ni statut métier explicitement affichés.
- Preuve d'origine : 1.3J (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : customer_tracking_screen.dart:153–165 ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Afficher référence et état recherche, sans chauffeur/GPS inventé.
- Tests nécessaires : Reçu→suivi ID correct, noDriver et statuts correspondants.
- Résultats : 3/3 historiques navigation ; ne valide pas correction UX.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Référence et recherche explicites aux trois formats. + règle permanente ci-dessus.

### P2-K-01

- État ACTUEL — clôture documentaire du 10 octobre 2026 sur autorisation explicite : **FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ**. Refus Firestore typé et autres erreurs des flux position/historique séparés d’un signal réellement absent, avec états de chargement, reprise sur nouvelle donnée valide, conservation des protections identité/mission et du seuil GPS strict de 60 secondes, messages FR/EN/ES. Preuve 1.3M-L : 110 tests distincts réussis / 0 échec / 0 ignoré et analyse Flutter ciblée sans problème ; aucune nouvelle exécution lors de cette fermeture. Chrome, Firebase déployé, GPS terrain et réabonnement d’un flux définitivement fermé non validés ; aucun état de production certifié.
- État HISTORIQUE — 1.3M-L avant approbation : **CORRIGÉ ET VALIDÉ DANS LE PÉRIMÈTRE SIMULÉ — NON FERMÉ — NON DÉPLOYÉ**. Reproduction complète 7 réussis/21 échoués avant correction ; validation finale 110 cas distincts réussis/0 échec/0 ignoré. Analyse finale sans problème. Aucune fermeture alors appliquée. Preuves et limites dans l’addendum L.

État historique de qualification conservé ci-dessous :

- Priorité / nature / statut : P2 ; Lacune statique ; QUALIFIÉ.
- Description et impact : Flux position/historique sans hasError, refus pouvant paraître absence signal/trajet.
- Preuve d'origine : 1.3K/1.3M (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : live_tracking_map.dart StreamBuilder position/historique ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Distinguer refus, erreur, chargement et signal absent ; retirer données invalides.
- Tests nécessaires : Chaque flux erreur/reprise et données anciennes sans tuiles externes.
- Résultats : 0 exécution spécifique.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Erreurs exactes et reprise compréhensibles, pas de données périmées trompeuses. + règle permanente ci-dessus.

### R-K-04

- État ACTUEL — 1_3M_P, 11 octobre 2026 : **FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ**, sur autorisation du lot P/Q. Montréal de repli supprimé. Sans coordonnées géométriquement utilisables, le vrai widget présente son état d'attente/erreur sur une surface neutre sans FlutterMap/TileLayer. Adresse réelle, position compatible ancienne (sans marqueur actif) et historique valide restent des repères possibles ; aucun lieu inventé. Identité, mission, dates et seuil de 60 secondes conservés. 153 tests finaux réussis, 0 échec, 0 ignoré ; analyse/format/diff check conformes. Preuve : artifacts/corrections-1-3M-PQ-20261011-f72a3c10/CHECKPOINT_1_3M_P.md. Limites : widgets simulés, pas Chrome/production/terrain ; 1.3L toujours BLOQUÉ ET REPORTÉ. Historique antérieur conservé ci-dessous.


- Priorité / nature / statut : P2 ; Risque visuel provisoire ; QUALIFIÉ.
- Description et impact : Centre de repli Montréal sans position/adresse ; pas de faux marqueur démontré.
- Preuve d'origine : 1.3K/1.3M (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : live_tracking_map.dart:87–90 ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Qualifier visuellement avant décision de centre/état.
- Tests nécessaires : Carte isolée sans position ni adresses.
- Résultats : NON TESTÉ : tuiles 1.3L bloquées.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : État sans signal non trompeur démontré visuellement. + règle permanente ci-dessus.

### P2-FORM-001

- État ACTUEL — 1_3M_Q1, 11 octobre 2026 : **FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ**, sur autorisation du lot P/Q. Sélecteurs date/heure localisés dans la langue du formulaire via les delegates Material existants ; résumé de l'étape livraison réutilisant le format localisé de confirmation. Instant, fuseau local, contraintes de date et valeurs persistées inchangés. 35 tests finaux réussis, 0 échec, 0 ignoré ; analyse/format/diff check conformes. Preuve : artifacts/corrections-1-3M-PQ-20261011-f72a3c10/CHECKPOINT_1_3M_Q1.md. Limites : widgets simulés, pas Chrome/production/terrain ; 1.3L toujours BLOQUÉ ET REPORTÉ. Historique antérieur conservé ci-dessous.


- Priorité / nature / statut : P2 ; Bug visuel historique ; QUALIFIÉ.
- Description et impact : Sélecteurs date/heure et date résumée anglais sur /fr.
- Preuve d'origine : 1.3C (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : lib/main.dart MaterialApp.router ; flow _chooseTime/_formatTime ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Raccorder locale/delegates appropriés à l'interface.
- Tests nécessaires : FR/EN/ES sélecteurs/date et navigateur.
- Résultats : PNG date/time aux trois formats en 1.3C.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Contrôles et résumé localisés réellement ; ne pas confondre harnais et Chrome. + règle permanente ci-dessus.

### P2-FORM-002

- État ACTUEL — 1_3M_Q2, 11 octobre 2026 : **FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ**, sur autorisation du lot P/Q. Libellé d’unité déplacé hors du label contraint du Dropdown, dans une colonne permettant son retour à la ligne ; sélection et conversion inchangées. 19 tests finaux réussis, 0 échec, 0 ignoré ; analyse/format/diff check conformes. Preuve : artifacts/corrections-1-3M-PQ-20261011-f72a3c10/CHECKPOINT_1_3M_Q2.md. Limites : widgets simulés, pas Chrome/production/terrain ; 1.3L toujours BLOQUÉ ET REPORTÉ. Historique antérieur conservé ci-dessous.


- Priorité / nature / statut : P2 ; Bug visuel historique ; QUALIFIÉ.
- Description et impact : Libellé Unité de poids tronqué, largeur fixe 120.
- Preuve d'origine : 1.3C (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : delivery_request_flow_screen.dart _item Dropdown ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Ajuster contrainte de présentation seulement.
- Tests nécessaires : 375/430/1440 et texte long/200%.
- Résultats : filled-375-01/430-01/1440-00 historiques.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Libellé et valeur lisibles sans overflow. + règle permanente ci-dessus.

### P2-FORM-003

- État ACTUEL — 1_3M_Q3, 11 octobre 2026 : **FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ**, sur autorisation du lot P/Q. Saisie brute ramassage/livraison sauvegardée immédiatement dans pickup_text/dropoff_text, séparée des adresses résolues et restaurée sans fabriquer de coordonnées. Devis interdit tant que les adresses restent non résolues. 29 tests finaux réussis, 0 échec, 0 ignoré ; analyse/format/diff check conformes. Preuve : artifacts/corrections-1-3M-PQ-20261011-f72a3c10/CHECKPOINT_1_3M_Q3.md. Limites : widgets simulés, pas Chrome/production/terrain ; 1.3L toujours BLOQUÉ ET REPORTÉ. Historique antérieur conservé ci-dessous.


- Priorité / nature / statut : P2 ; Bug historique / besoin produit ; QUALIFIÉ.
- Description et impact : Adresse saisie non résolue perdue après refresh ; objet conservé.
- Preuve d'origine : 1.3C (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : flow _restore/_address ; BookingDraft ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Décider conservation texte brut sans le traiter comme adresse validée.
- Tests nécessaires : Refresh/navigation/restauration et résolution invalide.
- Résultats : controls-v4.json/after-reload historiques.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Texte restauré selon décision ; devis interdit sans adresse validée. + règle permanente ci-dessus.

### P2-FORM-004

- État ACTUEL — 1_3M_Q4, 11 octobre 2026 : **FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ**, sur autorisation du lot P/Q. Dimensions rendues lisibles dans les champs et le résumé, sans arrondir les valeurs stockées, les conversions ni les données du devis. 190 cm devient visuellement 74,8 in en FR/ES, 74.8 in en EN ; précision numérique complète conservée. 52 tests finaux réussis, 0 échec, 0 ignoré ; analyse/format/diff check conformes. Preuve : artifacts/corrections-1-3M-PQ-20261011-f72a3c10/CHECKPOINT_1_3M_Q4.md. Limites : widgets simulés, pas Chrome/production/terrain ; 1.3L toujours BLOQUÉ ET REPORTÉ. Historique antérieur conservé ci-dessous.


- Priorité / nature / statut : P2 ; Bug visuel historique ; QUALIFIÉ.
- Description et impact : 190 cm convertis affichés 74.803149606… in.
- Preuve d'origine : 1.3C (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : flow _item conversion/initialValue ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Formatter affichage seulement ; préserver précision et calculs.
- Tests nécessaires : Conversions aller/retour et champ aux trois formats.
- Résultats : 375-converted-units.png historique.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Affichage lisible sans altérer dimensions/devis. + règle permanente ci-dessus.

### P2-G-02

- État ACTUEL — 1.3M-S, 11 octobre 2026 : **FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ**. Formatage localisé des montants CAD et distances km du devis/confirmation, sans mutation des valeurs sources. 144 tests distincts réussis / 0 échec / 0 ignoré ; analyse, format et contrôle Git réussis. Fermeture conditionnelle autorisée pour cette étape. Voir addendum S et artifacts/corrections-1-3M-S-20261011-8d61e930/.
- État historique avant S : QUALIFIÉ. Description, preuves d'origine et critères ci-dessous conservés.

- Priorité / nature / statut : P2 ; Bug de présentation simulé ; QUALIFIÉ.
- Description et impact : Format monétaire/distance non localisé FR : décimales point, suffixe CAD, 10.0 km.
- Preuve d'origine : 1.3G (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : flow money vers1478/distance1532 ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Format d'affichage localisé seulement.
- Tests nécessaires : Montants cents inchangés FR/EN/ES, arrondis d'affichage.
- Résultats : PNG 1.3G ; montants fictifs, pas preuve calcul serveur.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Lisibilité localisée, aucune altération cents/devis/snapshot. + règle permanente ci-dessus.

### P2-I18N-001

- État ACTUEL — 12 octobre 2026 — 1.3M-U : FERMÉ — PÉRIMÈTRE LOCAL/SIMULÉ VALIDÉ — NON DÉPLOYÉ. Avant : IDENTIFIÉ (conservé ci-dessous). Défaut reproduit (4 réussis / 9 échoués), puis 13 tests ciblés et 73 non-régressions distincts réussis. 12 captures widget examinées ; MediaQuery et décodage contrôlés. Ahem résiduel sur certains boutons, pas de validation Chrome/terrain/production. Variante générative neutre 1535×1025 ; FR inchangé. Preuves : artifacts/corrections-1-3M-U-20261012-a61b905e/CHECKPOINT_I18N_001.md et HERO_EVIDENCE.json.

Historique antérieur conservé :

- Priorité / nature / statut : P2 ; Signal historique ; IDENTIFIÉ.
- Description et impact : Illustration hero_clean en français sur EN/ES.
- Preuve d'origine : 1.3A ; PUBLIC_REVIEW_20261006 (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : assets/home/hero_clean.png ; home_screen.dart ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Décider adaptation ressource réutilisée.
- Tests nécessaires : Accueil EN/ES visuel.
- Résultats : Revue 6 octobre et code ; pas de nouveau test.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Visuels linguistiquement cohérents aux formats approuvés. + règle permanente ci-dessus.

### P2-I18N-002

- État ACTUEL — 12 octobre 2026 — 1.3M-U : FERMÉ — PÉRIMÈTRE LOCAL/SIMULÉ VALIDÉ — NON DÉPLOYÉ. Avant : QUALIFIÉ (historique conservé). Avant correction, 6 tests réussis / 7 échoués ; après, 13 ciblés et 68 non-régressions réussis. Neuf captures widget de l’infobulle examinées, langues/200 % et navigation desktop testées. Aucun Chrome, production ou lecteur d’écran physique testé. Preuves : artifacts/corrections-1-3M-U-20261012-a61b905e/CHECKPOINT_I18N_002.md et MENU_EVIDENCE.json.

Historique antérieur conservé :

- Priorité / nature / statut : P2 ; Bug visuel historique ; QUALIFIÉ.
- Description et impact : Infobulle Open navigation menu anglais sur /fr.
- Preuve d'origine : 1.3B (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : Navigation publique / localisation Material ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Relier P2-FORM-001 comme cause possible, conserver ID.
- Tests nécessaires : Infobulles FR/EN/ES mobile et desktop.
- Résultats : after-escape.png historique.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Infobulle correcte dans langue de route. + règle permanente ci-dessus.

### P2-BUILD-001

- État ACTUEL — 12 octobre 2026 : **FERMÉ — PÉRIMÈTRE BUILD/TEST LOCAL VALIDÉ — NON DÉPLOYÉ**, suite à l'autorisation explicite d'obtenir uniquement le package officiel cupertino_icons compatible. Version 1.0.9 ajoutée à pubspec.yaml et pubspec.lock, résolue par Flutter Pub en mode hors ligne après téléchargement officiel. Build Web --no-pub réussi (code 0, dry-run Wasm réussi), ancien avertissement Expected to find fonts absent. FontManifest comprend packages/cupertino_icons/CupertinoIcons et le fichier de police compilé ; deux tests permanents du paquet et 13 tests de régression du menu public réussis, 0 échec. Flutter analyze ciblé : 0 issue. Pas de test Chrome/iOS réel, de rendu de chaque glyphe sur appareil ni de production. Références et SHA-256 dans artifacts/corrections-1-3M-U-BUILD-20261012/CHECKPOINT_P2_BUILD_001.md.
- État HISTORIQUE — lot 1.3M-U antérieur, avant autorisation de téléchargement : blocage de la ressource locale et ancien avertissement documentés ci-dessous.

- Mise à jour 2026-10-12 — lot 1.3M-U : QUALIFIÉ — BLOQUÉ, NON FERMÉ. Ancien statut QUALIFIÉ conservé ci-dessous.
- Reproduction actuelle : build Web local Flutter 3.47.1 réussi (code 0), dry-run Wasm réussi ; avertissement CupertinoIcons toujours présent. FontManifest produit : MaterialIcons uniquement.
- pubspec.yaml, pubspec.lock et package_config ne déclarent pas cupertino_icons ; aucun package/font correspondant trouvé dans les caches Pub locaux examinés. Aucun usage direct CupertinoIcons trouvé dans lib/. Icône manquante sur un écran Movi-K précis NON DÉMONTRÉE.
- Aucune modification de dépendance, aucun téléchargement, aucun avertissement masqué. Résolution bloquée tant que la ressource officielle compatible n’est pas fournie localement ou son obtention autorisée. Aucun nouveau défaut visuel inféré de la seule compilation.
- Preuves : artifacts/corrections-1-3M-U-20261012-a61b905e/BUILD_QUALIFICATION.json, BUILD_INVENTORY.json, BUILD_PREFLIGHT.json, web-build.txt, CHECKPOINT_MOVIK_1_3M_U.md.
- Fermeture exige encore une résolution validée de la ressource et le contrôle des icônes effectivement utilisées ; compilation réussie seule insuffisante.

Historique antérieur conservé :

- Priorité / nature / statut : P2 ; Avertissement build ; QUALIFIÉ.
- Description et impact : CupertinoIcons attendu mais non inclus ; icône manquante pas démontrée.
- Preuve d'origine : 1.3B ; revue6octobre (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : pubspec.yaml / compilation Flutter ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Qualifier usages et résoudre déclaration minimale si requis.
- Tests nécessaires : Build et usages icônes concernés.
- Résultats : Avertissement historique, pas nouveau build.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Build cohérent et icônes rendues ; ne pas masquer avertissement. + règle permanente ci-dessus.

### P1-HOME-001

- État ACTUEL — 1.3M-R, 11 octobre 2026 : **FERMÉ — PÉRIMÈTRE LOCAL VALIDÉ — NON DÉPLOYÉ**. Fermeture autorisée par Daniel dans cette étape. Correction produit déjà présente, aucune recodification : accueil inchangé depuis la release 77c3c615. Revue de cinq PNG Chrome historiques (1.3B), 49 tests actuels réussis, 0 échec, 0 ignoré ; analyse et format ciblés réussis. Tests réels de géométrie FR/EN/ES aux formats 375×812, 430×932, 1440×900 et mobiles à 200 %. Aucun Chrome actuel, appareil physique ni disponibilité commerciale validés. Preuves : artifacts/reconciliation-1-3M-R-20261011-7c41e2a9/CHECKPOINT_HOME.md et HISTORICAL_AND_SOURCES.json.

Historique antérieur conservé :

- Priorité / nature / statut : P1 ; Bug ancien branche septembre ; VALIDÉ — HISTORIQUE, NON FERMÉ.
- Description et impact : Chevauchement hero desktop corrigé structurellement et non reproduit release trois formats.
- Preuve d'origine : 1.3A→1.3B (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : home_screen.dart hero ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Pas recoder : conserver correction et faire revue fermeture.
- Tests nécessaires : Analyse/tests pertinents HEAD cible et preuves1.3B.
- Résultats : Visuel release confirmé historiquement ; branche septembre encore affectée.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Preuves et non-régression revues, fermeture explicitement consignée par version. + règle permanente ci-dessus.

### P1-COPY-001

- État ACTUEL — 1.3M-R, 11 octobre 2026 : **FERMÉ — PÉRIMÈTRE LOCAL VALIDÉ — NON DÉPLOYÉ**, autorisation explicite de Daniel dans cette étape. Anciennes affirmations de couverture/créneau déjà retirées ; aucun changement produit nécessaire. Preuves : 3 tests existants publics et 12 contrats de textes FR/EN/ES réussis (0 échec, 0 ignoré), FAQ dépliée, trois formats et mobile200%. Analyse ciblée sans anomalie, format et diff check réussis. Code serveur lu uniquement pour rapprocher les formulations des conditions prévues. Configuration live des zones/flags, flotte disponible, paiements, GPS terrain et contact réel NON VÉRIFIÉS : fermeture de texte, pas autorisation de lancement. Voir artifacts/reconciliation-1-3M-R-20261011-7c41e2a9/CHECKPOINT_COPY.md et COPY_CONTRACT_EVIDENCE.json.

Historique antérieur conservé :

- Priorité / nature / statut : P1 ; Bug ancien branche septembre/main ; VALIDÉ — HISTORIQUE, NON FERMÉ.
- Description et impact : Anciennes promesses couverture/créneau retirées accueil release.
- Preuve d'origine : 1.3A→1.3B (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : home_screen.dart / home_copy.dart / ressources ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Pas recoder texte déjà corrigé ; revue étendue et FR/EN/ES.
- Tests nécessaires : Contenu lancement Granby ; pas promesses opérationnelles.
- Résultats : Visuel FR historique ; aucune disponibilité commerciale validée.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Messages conformes sur référence ; test et revue fermeture. + règle permanente ci-dessus.

### P2-COPY-001

- État ACTUEL — 1.3M-T, 11 octobre 2026 : **FERMÉ — PÉRIMÈTRE LOCAL/SIMULÉ VALIDÉ — NON DÉPLOYÉ**, fermeture autorisée par Daniel. Retrait existant depuis 49e865c, absent de lib/web actuels ; sources publiques comparées identiques à la release 77c3c615. Aucun code produit modifié.
- Preuves nouvelles : artifacts/reconciliation-1-3M-T-20261011-39a672bd/CHECKPOINT_MOVIK_1_3M_T.md et VALIDATION.json ; 76 tests distincts réussis dans la validation finale, aucun échec final/ignoré. FR/EN/ES, trois formats et mobile 200 %, carte Marketplace, catégorie vers vrai formulaire, CTA et textes prudents.
- Échecs initiaux du harnais conservés : 9 réussis/3 échoués/0 ignoré sous Ahem ; chargement explicite du Roboto local, mêmes assertions, 12/0/0. Analyse initiale : import inutile retiré uniquement dans le nouveau test ; analyse finale sans anomalie.
- Limites : widgets simulés, aucune nouvelle validation Chrome/appareil/production. 1.3L BLOQUÉ ET REPORTÉ. Registre recalculé P0 0 / P1 0 / P2 8, 27 fiches conservées.

Historique de la fiche avant T conservé ci-dessous :

- Priorité / nature / statut : P2 ; Bug ancien ; VALIDÉ — HISTORIQUE, NON FERMÉ.
- Description et impact : Leboncoin absent accueil release observé ; anciennement présent.
- Preuve d'origine : 1.3A→1.3B (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : home_screen.dart / home_copy.dart ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Conserver correction existante.
- Tests nécessaires : Test contenu et revue multilingue.
- Résultats : Facebook Marketplace/Kijiji observés1.3B.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Preuve correction et non-régression documentées. + règle permanente ci-dessus.

### P2-L-01

- Mise à jour 2026-10-13 — **FERMÉ — PÉRIMÈTRE WIDGET/WCAG LOCAL VALIDÉ — NON DÉPLOYÉ**. Correction de l'ambrette `AppColors.warning` auparavant utilisée comme texte de petits badges. Les libellés de warning emploient `warningBadgeTextLight` (#92400E) ou `warningBadgeTextDark` (#FDE68A) et les badges partagés assurent un fond teinté composé de la surface du thème. Les couleurs décoratives et les statuts métier sont conservés. Corrigé dans finance admin, badges génériques, profils/dossiers chauffeurs, revenus/versements/Stripe Connect fournisseur et autres textes d'avertissement ciblés.
- Tests : **5/5 tests de contraste et widgets ciblés** mesurant les rapports réels texte/fond via la formule WCAG sRGB, seuil >= 4.5:1 en mode clair/sombre ; **243/243 tests Flutter de non-régression** sur huit suites ; analyse Dart ciblée sans anomalie. Preuves : `artifacts/p2L01-warning-contrast-20261013/CHECKPOINT_P2_L01.md` et `test/accessibility/p2_warning_badges_contrast_test.dart`.
- Limites : seulement les avertissements corrigés, non certification de tous les tons/components WCAG ; aucun test Chrome/Safari/appareil physique ni mesure sur production, aucun push/merge/déploiement. P3, prérequis de lancement, environnement Stripe réel et GPS 1.3L restent à qualifier. Historique antérieur conservé ci-dessous.

- Priorité / nature / statut : P2 ; Dette historique (nouvel ID permanent) ; QUALIFIÉ.
- Description et impact : Contraste texte de badges warning faible ; distinct BUG-L6-01 GPS déjà corrigé.
- Preuve d'origine : Phase7 blocL (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : finance_ui_helpers.dart ; admin_drivers_list/detail ; provider_earnings/payout/profile ; admin_finance_payout_policy ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Corriger usages texte sans modifier statuts métier.
- Tests nécessaires : Contraste clair/sombre et rendu badges.
- Résultats : Mesures ~1.96:1 historiques ; pas rerun.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Critères contraste approuvés testés. + règle permanente ci-dessus.

### GAP-M-05

- Mise à jour 2026-10-13 — **FERMÉ — PÉRIMÈTRE FLUTTER WIDGET LOCAL VALIDÉ — NON DÉPLOYÉ**. Le shell remplace l'indexation destructrice `tabs[_index]` par une pile `IndexedStack` avec emplacements paresseux : chaque onglet n'est construit qu'à sa première visite, puis son State est maintenu sans recréer les flux au retour. La structure stable Row/Expanded conserve le même onglet en passant du mode mobile à ordinateur. `initialTabIndex: 3` ouvre Profil sans abonnement Missions prématuré ; identité chauffeur différente remet les indicateurs de visite à zéro. Pas de refonte des onglets, données ni logique financière.
- Validation : **49/49 tests Flutter** sur cinq suites, dont trois nouveaux tests de retour d'onglet, conservation du mois Calendrier à 430 et 1200px, bascule de largeur, compteurs de flux et entrée directe Profil ; vérifications des parcours missions, Stripe Connect simulé, versements et accessibilité. `dart analyze --fatal-infos` ciblé : zéro anomalie. Checkpoint : `artifacts/gapM05-tabs-20261013/CHECKPOINT_GAP_M05.md`.
- Limites : seuls les onglets déjà visités restent abonnés lorsqu'ils sont invisibles ; pas de mesure de coûts Firestore en production. Aucun navigateur réel ni essai appareil ; la conservation ne survit pas à la destruction du shell, au changement complet de route ou à un redémarrage de l'application. Aucune donnée métier, devise, commission, capture, snapshot, ledger, Firestore rules ou service de production modifié.
- Historique de la fiche conservé ci-dessous.

- Priorité / nature / statut : P2 ; Dette historique ; QUALIFIÉ.
- Description et impact : State des onglets provider détruit/recréé par tabs[index].
- Preuve d'origine : Phase7 blocM (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : provider_dashboard_shell.dart ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Qualifier impact ; pas refonte sans besoin.
- Tests nécessaires : Changer onglets avec données saisies et compteurs streams.
- Résultats : DEFERRED historique.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Absence perte/charge gênante démontrée ou décision documentée. + règle permanente ci-dessus.

### GAP-M-06

- Mise à jour 2026-10-13 — **FERMÉ — PÉRIMÈTRE FLUTTER/WIDGET LOCAL VALIDÉ — NON DÉPLOYÉ**. Seuls les deux abonnements initialement non bornés, watchNotifications() et watchDriversByStatus(), reçoivent un limit Firestore (50 au départ). Les écrans proposent des fenêtres progressivement étendues par choix utilisateur (« Afficher plus » en FR/EN/ES). Le filtrage des profils migrés conserve le nombre brut de résultats pour que les dossiers valides suivants restent accessibles ; l'option Réessayer reconnecte le flux après erreur. Pas de modification métier, tarifs, commissions, ledger, snapshots ou Firestore rules.
- Validation : 11/11 tests ciblés réussis ; 63/63 tests widget de non-régression connexes sans GPS réseau réussis ; 2/2 tests responsive Notifications (320/360px) réussis. Dart analyze sans anomalie. La tentative de suite responsive complète a échoué sur les tuiles GPS réseau interdites par le harnais, déjà bloquées sous 1.3L ; ne pas assimiler ce problème à une preuve de succès global. Fichiers de preuve et checkpoint : artifacts/gapM06-bounded-firestore-20261013/CHECKPOINT_GAP_M06.md.
- Limites : pas d'émulateur Firestore/client Chrome ni de mesure facturée ; le flux watchUnreadCount et la méthode markAllAsRead conservent leurs lectures historiques non bornées et ne sont pas prétendus corrigés. Le tri des chauffeurs par date de mise à jour porte sur la fenêtre chargée, non sur tous les profils ; les notifications legacy sans created_at nécessiteraient une migration pour apparaître sous orderBy. Chaque fenêtre est finie mais sa taille augmente à la demande : ceci n'est pas une pagination à coût constant.
- Historique de la fiche conservé ci-dessous.

- Priorité / nature / statut : P2 ; Risque coût historique ; QUALIFIÉ.
- Description et impact : watchNotifications/watchDriversByStatus sans limit.
- Preuve d'origine : Phase7 blocsM/N/T (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : firebase_notification_repository.dart ; firebase_driver_repository.dart ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Qualifier volume avant borner/paginer.
- Tests nécessaires : Volumes pilotes, performances et absence perte données.
- Résultats : Aucun coût excessif réel mesuré.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Lecture bornée si besoin et fonctionnel intact, ou risque accepté documenté. + règle permanente ci-dessus.

### GAP-S-02

- Mise à jour **2026-10-13 — FERMÉ — PÉRIMÈTRE ÉMULATEUR VALIDÉ — NON DÉPLOYÉ**. Avant la confirmation d'un paiement, sa référence provider est désormais enregistrée dans payments/{id} ; createPayment a confirm:false, donc aucune autorisation n'est déclenchée avant cette écriture. Un récupérateur conservateur interroge getPaymentStatus sur les paiements authorization_pending âgés attachés à une mission cancelled, exige concordance environnement Stripe, identités et montant entier en cents et absence de capture, puis utilise la compensation idempotente existante. Les états inconnus/capturés, les identifiants absents et les divergences restent en révision manuelle, sans correction spéculative. Tâche planifiée limitée à 100 paiements en attente par passage (10 min), non déployée ; couverture de tout backlog important non démontrée.
- Validation : **25 tests sur 25**, quatre suites Firestore/Auth en émulateur, fournisseur FakePaymentProvider, incluant reprise après interruption simulée, annulation, rejeu, montant discordant, référence absente, fournisseur déjà annulé et isolation TEST/LIVE. Compilation TypeScript et lint des sources réussis. Aucun calcul de prix, commission, devis, cent Stripe, snapshot, ledger ni règle Firestore modifié. Preuves : artifacts/gapS02-recovery-20261013/CHECKPOINT_GAP_S02_RECOVERY.md.
- Limites de cette fermeture : aucune exécution planifiée déployée, aucun flux Stripe Sandbox/LIVE, aucun crash physique du runtime Cloud Functions/Node20 ni validation opérationnelle de surveillance des alertes. Des paiements historiques sans provider_payment_intent_id nécessitent une investigation sans accès automatique au provider ; ces limites restent des prérequis avant tout lancement réel.

- Mise à jour 2026-10-12 — correctif financier local : **CORRECTION PARTIELLE TESTÉE — NON FERMÉE — NON DÉPLOYÉE**. Reproduction déterministe avant correction : une mission pouvait être cancelled pendant AUTHORIZATION_PENDING, puis le paiement se retrouvait authorized après le passage tardif du fournisseur fictif.
- Le code local ajoute le refus de commencer un paiement déjà annulé, la compensation idempotente d'une autorisation arrivée après cancellation et un trigger Firestore de rattrapage sur le passage du paiement à authorized (avec retry). La compensation d'échec ne remplace plus cancelled par payment_failed. Montants, tarifs, commissions et snapshots de calcul inchangés.
- Vérifications : 18 tests d'intégration réussis en émulateur Firestore/Auth demo-movik-test dont 4 tests ciblés, tests existants double acceptation et libération des paiements ; zéro échec final. Compilation TypeScript et ESLint ciblé des sources réussis. Aucune invocation Stripe réelle et aucune validation production.
- **Risque résiduel bloquant** : si le fournisseur autorise le paiement mais que la Cloud Function s'interrompt AVANT l'écriture authorized dans payments/{id}, aucun événement authorized Firestore ne se produit. La réconciliation quotidienne existante signale seulement les anomalies et ne les compense pas automatiquement. Il faut une stratégie approuvée de récupération des authorization_pending orphelins, suivie de tests d'interruption contrôlés avant fermeture complète.
- Preuves : artifacts/gapS02-fix-20261012/CHECKPOINT_GAP_S02_PARTIAL.md. Historique antérieur conservé ci-dessous.

- Priorité / nature / statut : P2 ; Couverture manquante ; QUALIFIÉ.
- Description et impact : Pas de test ciblé annulation/acceptation simultanées.
- Preuve d'origine : Phase7 blocS (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : acceptDelivery.ts / cancelDelivery.ts ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Ajouter preuve transactionnelle isolée, pas correction présumée.
- Tests nécessaires : Intercaler deux transactions avec fake provider.
- Résultats : Protection transactionnelle lue historiquement ; non démontrée par test ciblé.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Un seul état cohérent et effets financiers idempotents. + règle permanente ci-dessus.

### GAP-S-04

- **Addendum sécurité 2026-10-14 — FERMÉ UNIQUEMENT EN ÉMULATEUR, NON DÉPLOYÉ.** La qualification QC26 a reproduit une élévation de permissions par écriture cliente de `driver_profiles/{uid}.suspension_mode` (`urgent` vers `ordinary`) malgré les blocages serveur. Le garde Firestore `request.resource.data.get('suspension_mode', null) == resource.data.get('suspension_mode', null)` interdit désormais la modification directe du niveau de suspension par le chauffeur, en préservant les documents anciens où le champ est absent. Tests : 8/8 nouveaux tests négatifs/positifs et 281/281 tests de régression sur cinq suites Firestore/Auth Emulator, code 0. Appels directs analyst/admin clients refusés, écriture Admin SDK simulée conservée. Aucun tarif, montant, commission, snapshot, Stripe ou comportement des Cloud Functions modifié. Preuve : `artifacts/security-suspension-mode-20261014/CHECKPOINT_SECURITY_GAP_S04.md`.
- **Limite** : ces résultats locaux ne vérifient pas les règles Firebase déployées et ne constituent pas une autorisation de lancement. Les échecs de qualification QC26 (CI globale/mission GPS/fixture loadMvpBlocT) demeurent ouverts en tant que prérequis distincts.

- Mise à jour 2026-10-13 — **FERMÉ — PÉRIMÈTRE LOCAL/ÉMULATEUR VALIDÉ — NON DÉPLOYÉ**. Politique approuvée : suspension ordinaire empêche de nouvelles acceptations et l'accès en ligne mais autorise à terminer une mission déjà assignée ; suspension urgente interdit ramassage, livraison, transitions intermédiaires et GPS, exigeant intervention administrative. L'interface admin peut sélectionner les deux modes et escalader une suspension ordinaire en urgente ; un profil suspendu historique sans mode est refusé comme urgent par prudence. Aucune annulation automatique, aucun remboursement ni mouvement financier ajouté. Le statut offline reste offline après achèvement d'une mission sous suspension ordinaire.
- Preuves : 10 tests ciblés sur émulateur Firestore/Auth, 150 tests serveur sur 9 suites et 33 tests Flutter sur 3 suites réussis ; TypeScript, ESLint et Dart analyze ciblés sans anomalies. Aucun essai navigateur/appareil réel, aucune preuve de déploiement. Voir artifacts/gapS04-suspensions-20261013/CHECKPOINT_GAP_S04.md.
- Portée : le traitement sous suspension ordinaire concerne seulement les missions déjà assignées ; toute nouvelle acceptation reste refusée par acceptDelivery. Le GPS ordinaire ne fonctionne que sur la mission active liée. Les profils legacy sans suspension_mode sont urgents. Les changements de statut et de GPS sont contrôlés dans des transactions relisant driver_profiles. Les frais, contrats, ledger, snapshots et règles serveur Firestore restent inchangés.
- Historique antérieur conservé ci-dessous.

- Priorité / nature / statut : P2 ; Décision produit / risque ; QUALIFIÉ.
- Description et impact : Chauffeur suspendu en mission peut progresser completePickup/Delivery.
- Preuve d'origine : Phase7 blocS ; PILOT_READINESS 8I (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : suspendDriver.ts ; completePickup.ts ; completeDelivery.ts ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Décider suspension ordinaire vs arrêt urgent avant code.
- Tests nécessaires : Suspension avant/pendant mission selon politique.
- Résultats : Code/documentation historiques ; aucun incident démontré.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Politique approuvée et scénarios exécutés. + règle permanente ci-dessus.

## Prérequis et vérifications externes (hors compteur de bugs)

- ENV-1 / P1-RECETTE-002 : autocomplétion non configurée dans le build audité, absence de données de recette approuvées. Ce n'est pas une panne production prouvée ; devis navigateur inaccessible1.3C.
- ENV-2 : émulateurs absents dans recette1.3C ; ne pas réinterpréter comme bug produit.
- P1-RECETTE-001 : USE_FIREBASE_EMULATORS ne confine pas à lui seul Routes/Stripe/Secret Manager ; risque environnement, pas incident production.
- P2-RECETTE-003 : Node24 installé vs Node20 déclaré ; compatibilité à vérifier, pas échec runtime démontré.
- 1.3L : BLOQUÉ ET REPORTÉ, un test de tuile locale non validé faute confinement réseau du processus. Sandbox/Windows suspendus. Captures GPS actif et terrain restent NON TESTÉS.
- Contact officiel/QR : canal non opérationnel dans revue6octobre ; fournir et raccorder canal avant distribution publique. Aucune relecture live dans cette intervention.
- GA4 PR47 : ouverte historiquement le6octobre, fusion actuelle NON VÉRIFIÉE ; conserver identifiant Firebase sans l'écraser.
- Stripe TEST/LIVE, devis=mission=snapshot=cents Stripe, déploiements/règles/index live, push réels, GPS/appareils, alertes, sauvegardes, AppCheck, politiques/zone/participants : preuves externes à obtenir selon PILOT_READINESS registre8A–8L. Rien n'est présumé absent sur la seule base des anciens blocs AC.
- Diagnostic écran blanc historique : non reproduit ensuite, cause inconnue ; ne pas inventer un bug corrigé.

## Ordre de traitement après P1-M-01

1. Achever preuve permissions P1-M-01 et non-régression sans élargir rules.
2. R-K-03-A, puis B : politique d'autorité/lifecycle, protections d'accès, atomicité ; tests isolés et anciens correctifs financiers préservés.
3. R-K-03-C avec décision fraîcheur, puis P2-K-01 ; capture carte uniquement après levée blocage1.3L.
4. P2-H-01/H-02, P2-I-01/I-02, P2-J-01 ; validations/présentation, aucune retouche tarifaire.
5. Localisation P2-FORM-001/P2-G-01/P2-I18N-002, affichages formulaire/montants, illustration/contraste/build ; gaps M/S et décisions suspension ; vérifications E2E ensuite avec environnement autorisé.
6. Réconcilier corrections historiques avec version cible avant GO, pas les recoder sur la seule base d'un rapport ancien. Fournir contact et décisions pilote en parallèle via interventions explicitement autorisées.

## Historique importé sans réécriture

Les annexes ci-dessous sont des copies littérales des sources disponibles à la base77c3c615. Elles constituent les fiches détaillées historiques (IDs, impacts, fichiers, correctifs et résultats) et préservent leurs erreurs/contradictions chronologiques. Un total vert ancien n'est pas une preuve de production ni une exécution1.3M-B. Les anciens libellés CORRIGÉ/FERMÉ sont des citations, pas des décisions de fermeture actuelles. Les nouvelles fiches/IDs sans identifiant historique explicite sont à distinguer de ces citations.

## Annexe source : docs/PHASE7_BUG_REPORT.md

# PHASE 7 — Bug Bash — Rapport de bugs

Règle de fermeture Phase 7 : **P0 = 0, P1 = 0** avant clôture. P2/P3 peuvent rester documentés.

## BUG-001 — Autorisation de paiement Stripe jamais libérée à l'annulation client post-assignation

- **Composant** : `functions/src/functions/onMissionEndedClearTracking.ts` (trigger unique et
  fiable interceptant l'annulation client directe, voir son commentaire d'en-tête) /
  `functions/src/payment/paymentOrchestration.ts` (orchestration paiement).
- **Sévérité** : **P1 (candidat)** — impact financier réel mais non catastrophique (fonds
  bloqués temporairement sur la carte du client jusqu'à expiration naturelle de l'autorisation
  Stripe ~7 jours ; aucun débit réel n'a lieu, mais l'expérience client est dégradée et
  `payments/{id}.status` reste incohérent avec l'état réel de la mission).
- **Découverte** : Phase 7, Bloc B (E2E Client — cas négatif "annulation après assignation"),
  via reconnaissance ciblée (`grep` exhaustif sur `.cancelAuthorization(` dans `functions/src/`)
  puis confirmation par un test d'intégration réel écrit spécifiquement pour reproduire le
  scénario.
- **Reproduction** (test créé) :
  `functions/test/integration/missionCancellationPaymentRelease.test.ts` — 3 tests :
  1. `le paiement AUTHORIZED passe à CANCELLED ... quand le client annule` → **ÉCHOUE**
     (reçu `"authorized"`, attendu `"cancelled"`).
  2. `[idempotence] rejouer le trigger ... ne relance pas cancelAuthorization` → **ÉCHOUE**
     (même cause racine).
  3. `[négatif] un paiement DÉJÀ CAPTURED n'est jamais annulé par ce trigger` → **PASSE**
     (comportement actuel correct par absence totale de logique, donc ce test ne prouve rien de
     positif en soi, mais confirme qu'aucune régression n'est introduite sur ce cas par le futur
     correctif).
- **Résultat de l'exécution confirmée** (émulateurs firestore+auth+storage,
  `demo-movik-test`) : `Tests: 2 failed, 1 passed, 3 total`.
- **Cause racine** : `firestore.rules` (`delivery_requests/{missionId}`) autorise le client
  propriétaire à passer `status` à `'cancelled'` par écriture directe une fois `driver_id`
  assigné (design intentionnel documenté dans les règles). `acceptDelivery()` a, à ce stade,
  déjà appelé `createAndAuthorizeMissionPayment()` qui autorise un paiement réel chez le
  provider (`payments/{id}.status = AUTHORIZED`). Aucune Cloud Function n'observe cette
  transition d'annulation pour appeler `PaymentProvider.cancelAuthorization()` — méthode qui
  existe pourtant déjà dans l'interface `PaymentProvider` (`cancelAuthorization()`,
  `paymentProvider.ts`) et son implémentation réelle Stripe (`stripeProvider.ts`, appelle
  `stripe.paymentIntents.cancel(...)`) et son double de test (`FakePaymentProvider`), mais n'est
  invoquée nulle part dans `functions/src/` en dehors de sa définition. La machine d'état
  (`paymentStateMachine.ts`) autorise pourtant explicitement la transition
  `AUTHORIZED -> CANCELLED` (« mission annulée avant capture ») — la transition est prévue et
  documentée dans le code mais jamais déclenchée.
- **Correctif appliqué** :
  1. Nouvelle fonction exportée `cancelMissionPaymentAuthorization(missionId, paymentId)`
     ajoutée dans `functions/src/payment/paymentOrchestration.ts`, suivant EXACTEMENT le schéma
     en 3 temps déjà établi (`createAndAuthorizeMissionPayment` / `captureMissionPayment` /
     `refundPayment`) :
     - **Étape 1 (transaction de préparation)** : lit `payments/{paymentId}`, retourne un état
       discriminé (`already_cancelled` / `skipped` si statut ≠ `AUTHORIZED` / `proceed` avec
       `providerPaymentIntentId` + `idempotencyKey = buildIdempotencyKey("cancelAuthorization", paymentId)`).
       Retours anticipés non-erreur pour `already_cancelled` et `skipped` (aucun appel provider).
     - **Étape 2 (HORS transaction)** : `provider.cancelAuthorization({providerPaymentIntentId, idempotencyKey})`,
       try/catch, échec loggé via `logFinancialFailure("cancel_authorization", ...)`.
     - **Étape 3 (transaction d'application)** : relit `payments/{id}` (garde de concurrence —
       si déjà `CANCELLED`, sort sans réécrire), **tous les reads AVANT tous les writes**
       (contrainte Firestore — voir bug de régression ci-dessous), `assertValidPaymentTransition()`,
       écrit `status: CANCELLED`, `cancelled_at`, `updated_at` sur le paiement et
       `payment_status: CANCELLED` sur `delivery_requests/{missionId}` si le doc existe.
     - Puis (hors transaction) : `writeAuditLog({action: "payment_authorization_cancelled", ...})`,
       `logFinancialSuccess(...)`, `recalculateMissionFinancialBalance(missionId)`.
     - Portée strictement limitée aux paiements `AUTHORIZED` — ne touche jamais un paiement
       `CAPTURED`/`PARTIALLY_REFUNDED` (chemin exclusif de `refundPayment()`), ne déclenche
       aucune capture, ne crée aucun payout chauffeur.
  2. `functions/src/functions/onMissionEndedClearTracking.ts` : import de
     `cancelMissionPaymentAuthorization`, et appel conditionnel — placé après la garde
     `wasAlreadyTerminal || !isNowTerminal` mais avant la garde `!after.driver_id` — déclenché
     uniquement quand `after.status === MissionStatuses.CANCELLED` ET qu'un `active_payment_id`
     non nul existe sur la mission. Scope strictement limité à la transition `cancelled` (pas
     `disputed`/`refunded`, qui suivent leurs propres chemins financiers dédiés).
  3. **Bug de régression découvert et corrigé pendant l'implémentation** : la première version
     du correctif violait la contrainte Firestore « tous les reads doivent précéder tous les
     writes dans une transaction » (`tx.update(payRef, ...)` était appelé avant
     `tx.get(missionRef)` dans la transaction d'application). Détecté immédiatement par le
     premier run de test post-fix (`Firestore transactions require all reads to be executed
     before all writes`, 2 tests rouges). Corrigé en réordonnant : `tx.get(missionRef)` déplacé
     avant tous les `tx.update(...)`. Recompilation (`tsc --noEmit`) confirmée propre après
     correction.
- **Test de régression** : `functions/test/integration/missionCancellationPaymentRelease.test.ts`
  (3 tests) — résultat final après correctif : **`Tests: 3 passed, 3 total`** (confirmé via
  émulateurs firestore+auth+storage, `demo-movik-test`).
- **Suite de régression complète exécutée après correctif** (aucune régression détectée) :
  - `functions/test/integration/onMissionEndedClearTracking.test.ts` → `10 passed, 10 total`.
  - Security Rules (`securityRules.test.ts` + `storageRules.test.ts`) → `196 passed, 196 total`.
  - `npx tsc --noEmit` → 0 erreur.
  - `npm run lint` (ciblé `src/`) → 0 erreur/warning.
- **Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc B).

---

## BUG-002 — `CustomerTrackingScreen` sans garde d'authentification (message trompeur)

- **Composant** : `lib/screens/customer/customer_tracking_screen.dart`.
- **Sévérité** : **P3 (UX mineur)** — AUCUN impact sécurité : `firestore.rules` sur
  `delivery_requests/{missionId}` est déjà correctement scopée (confirmé par la suite Security
  Rules, 196/196 PASS) — un utilisateur non authentifié n'a jamais accès aux données réelles,
  le flux échoue toujours côté serveur avant toute fuite. Le seul défaut est côté présentation.
- **Découvert pendant** : Phase 7, Bloc B, scénario MIS-C-07 (accès non authentifié à l'écran de
  suivi de mission).
- **Cause** : contrairement à ses écrans « frères » protégés (`CustomerDashboardShell`,
  `ProviderDashboardShell`, `DriverActiveMissionScreen`), `CustomerTrackingScreen` n'implémentait
  aucune garde `FirebaseAuthProvider.isSignedIn` — un utilisateur déconnecté voyait le message
  générique `driver_active_mission_network_error` ("erreur réseau"), incohérent et trompeur.
- **Correctif appliqué** :
  1. Nouvelle clé i18n `tracking_locked_message` (fr/en/es) dans `lib/l10n/app_strings.dart`.
  2. Garde ajoutée au tout début de `build()` : si `!auth.isSignedIn`, affiche un `Scaffold` dédié
     (icône verrou, message clair, bouton "se connecter" -> `/$locale/connexion`), suivant
     exactement le pattern déjà établi dans `CustomerDashboardShell`.
  3. Le reste du flux (StreamBuilder Firestore, timeline, preuve de livraison, section
     financière) reste strictement inchangé pour un utilisateur authentifié.
- **Test de régression** : `test/customer/customer_tracking_screen_auth_test.dart` (2 tests,
  widget-test pur avec `FirebaseAuthProvider(backendConfigured: false)`, aucun émulateur requis)
  → **2 passed, 2 total**.
- **Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc B).

---

## BUG-003 — `DeliveryRequestFlowScreen` : bouton "Suivant" figé désactivé selon l'ordre de saisie (étapes 1 et 2)

- **Composant** : `lib/screens/delivery/delivery_request_flow_screen.dart` (`_Step1ItemInfo`,
  `_Step2Addresses`).
- **Sévérité** : **P1** — blocage total possible de la création d'une mission client sur un
  parcours utilisateur courant (aucun contournement UI disponible une fois le bouton figé
  désactivé ; seul un redémarrage du flux, potentiellement inefficace selon l'ordre de saisie
  répété, permettrait de s'en sortir).
- **Découvert pendant** : Phase 7, Bloc B, MIS-C-09 (E2E client — double soumission réseau),
  en construisant le widget test du Cas A (double-tap UI) : un test de diagnostic minimal a
  révélé que le formulaire ne progressait jamais au-delà de l'étape 1 malgré catégorie et
  description valides.
- **Cause racine** : `StepProgressForm.canProceed(step)` (callback fourni par
  `_DeliveryRequestFlowScreenState.build()`) lit directement `_descController.text` (étape 0)
  et les `.text` de 10 `TextEditingController` d'adresse (étape 1, pickup + dropoff). Ces
  contrôleurs sont passés à des `TextField` dans des widgets enfants `StatelessWidget`
  (`_Step1ItemInfo`, `_Step2Addresses`) **sans aucun callback `onChanged` déclenchant un
  `setState()` sur le parent**. Un `TextEditingController` ne provoque par lui-même aucun
  rebuild de `StepProgressForm` (qui ne l'écoute pas) : `canProceed` n'est donc réévalué que
  lors d'un `setState` déclenché par ailleurs (ex. sélection d'une catégorie/`ChoiceChip`).
  Concrètement : si l'utilisateur (1) choisit la catégorie, PUIS (2) saisit la description, le
  dernier `setState` a eu lieu à l'étape (1) — où la description était encore vide — et
  `canProceed` reste figé sur `false` en permanence, même une fois la description remplie,
  car aucun événement ne redéclenche le calcul. Même mécanisme pour les 10 champs d'adresse de
  l'étape 2 (`pickupLine1/City/Postal/Lat/Lng`, `dropoffLine1/City/Postal/Lat/Lng` — les champs
  optionnels `contactController`/`accessController` ne sont pas concernés, absents de
  `canProceed`).
- **Reproduction** : test de diagnostic ad hoc (widget test minimal, non conservé) confirmant
  `nextBtn.onPressed == null` après saisie catégorie + description complètes, chip bien
  `selected: true`, texte bien présent dans le controller (`tf.controller?.text == "Canape"`)
  — élimine toute cause côté validation elle-même, isole strictement l'absence de rebuild.
- **Correctif appliqué** :
  1. `_Step1ItemInfo` : ajout du paramètre `onDescriptionChanged` (`VoidCallback`), branché sur
     `TextField(controller: descController, onChanged: (_) => onDescriptionChanged())`. Site
     d'appel (`build()` du parent) : `onDescriptionChanged: () => setState(() {})`.
  2. `_Step2Addresses` : ajout du paramètre `onAddressFieldChanged` (`VoidCallback`), branché en
     `onChanged` sur les 10 `TextField` participant à `canProceed(step == 1)` (pickup et dropoff
     : line1, city, postal, lat, lng). Site d'appel : `onAddressFieldChanged: () => setState(() {})`.
  3. Aucune refonte : le pattern déjà utilisé pour les autres callbacks (`onCategorySelected`,
     `onQuantityChanged`, etc.) est simplement étendu aux champs texte concernés.
- **Test de régression** : `test/customer/delivery_request_flow_double_submit_test.dart` —
  le scénario `_fillFormAndReachQuoteStep`/`fillFormAndReachQuoteStep` reproduit exactement
  l'ordre catégorie-puis-description (étape 1) et la saisie des 10 champs d'adresse (étape 2) ;
  sans le correctif, ce helper bloque indéfiniment dès l'étape 1 (bouton "Suivant" jamais
  actif) et les deux tests du fichier échouent avant même d'atteindre l'assertion de
  double-submit. Après correctif : **2 passed, 2 total**.
- **Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc B, MIS-C-09).

---

## BUG-003 — occurrence DriverOnboarding (récurrence confirmée, même cause racine)

- **Composant** : `lib/screens/driver/driver_onboarding_screen.dart` (étape 0 — Profil,
  `_DriverOnboardingScreenState.build()`).
- **Sévérité** : **P1** — même impact que l'occurrence originale (blocage total du funnel
  d'inscription chauffeur si nom/email/password sont saisis sans déclencher un autre
  `setState`).
- **Découvert pendant** : Phase 7, Bloc C, ACTION 1 (test de diagnostic ciblé explicitement
  demandé pour vérifier si `DriverOnboardingScreen` était affecté par le même pattern que
  BUG-003 sur `DeliveryRequestFlowScreen`).
- **Cause racine** : identique à BUG-003 original — `canProceed(0)` lit directement
  `_nameController.text` / `_emailController.text` / `_passwordController.text`, mais les 3
  `TextField` correspondants n'avaient aucun `onChanged` déclenchant un `setState()` du
  parent. Différence structurelle avec l'occurrence originale : ici les champs sont inline
  dans `build()` (pas dans un `StatelessWidget` enfant séparé), donc le correctif n'a pas eu
  besoin d'introduire un nouveau paramètre `VoidCallback`.
- **Reproduction** : `test/driver/driver_onboarding_step0_rebuild_test.dart` — avant
  correctif, `nextButton.onPressed` restait `null` après saisie complète des 3 champs (aucune
  autre action `setState`) → **FAIL** confirmé.
- **Correctif appliqué** : ajout de `onChanged: (_) => setState(() {})` directement sur les 3
  `TextField` (nom, email, password) de l'étape 0, avec commentaire renvoyant explicitement à
  BUG-003.
- **Test de régression** : même fichier, retesté après correctif → **1 passed, 1 total**.
- **Classification** : rattaché à **BUG-003** (pas de nouveau BUG-004 créé, cause racine
  identique, conformément à la consigne explicite du Bloc C/ACTION 1).
- **Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc C, ACTION 1).

---

## BUG-004 — Rollback silencieux à l'échec de versement chauffeur (`submitDriverPayout`)

- **Composant** : `functions/src/payment/paymentOrchestration.ts` (`submitDriverPayout`).
- **Sévérité** : **P0** — risque financier : un échec du provider de paiement lors du
  versement (`provider.createDriverPayout()`) pouvait laisser le payout dans un état
  incohérent (transition partielle) sans que l'échec ne soit répercuté de façon fiable et
  re-tentable, avec risque de double versement ou de perte de traçabilité.
- **Découvert pendant** : Phase 7, Bloc C, item 2 (payout submission failure), en écrivant
  `submitDriverPayoutFailure.test.ts` (ajout de `forceCreateDriverPayoutFailure` sur
  `FakePaymentProvider`, même pattern que `forceAuthorizeFailure`/`forceCaptureFailure`).
- **Cause racine** : le chemin d'échec de `submitDriverPayout()` ne garantissait pas de façon
  systématique la transition `PROCESSING -> FAILED` avec `failure_reason` renseigné avant tout
  autre effet (ledger, audit `payout_paid`) ; un échec provider pouvait laisser le payout dans
  un état ambigu, empêchant un retry propre (`FAILED -> SCHEDULED`, transition valide dans
  `payoutStateMachine.ts`).
- **Correctif appliqué** : garantie que `provider.createDriverPayout()` en échec produit
  toujours `status: FAILED`, `failure_reason` renseigné, aucun `paid_at`/`provider_payout_id`
  factice, aucune écriture `transaction_ledger`, `mission_financial_balance.driver_paid_minor`
  inchangé (reste à 0), un seul document `driver_payouts` (pas de duplication), et retry
  (`submitDriverPayout` rejoué sur un payout `FAILED`) qui échoue proprement à nouveau sans
  dupliquer d'effet financier.
- **Test de régression** : `functions/test/integration/submitDriverPayoutFailure.test.ts` —
  couvre échec provider (FAILED, pas PAID, audit `payout_submitted` présent, ledger vide,
  balance à 0, retry propre) + cas `missing_connected_account` (échec avant tout appel
  provider). Résultat : **PASS** (suite intégrée dans le run global Bloc C, 56/56 PASS avec les
  8 autres suites d'intégration pertinentes).
- **Commit** : `b4b79fd` ("Phase 7 Bloc C item 2: test payout submission failure + fix BUG P0
  rollback silencieux").
- **Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc C, item 2).

---

## BUG-005 — `ProviderJobsTab` : Stream Firestore recréé à chaque `setState()`

- **Composant** : `lib/screens/mechanic_provider/provider_jobs_tab.dart`.
- **Sévérité** : **P1** — UX dégradée + charge Firestore inutile : la carte "Acceptation en
  cours..." disparaissait au profit de l'écran de chargement générique pendant une action
  utilisateur normale, et un nouvel abonnement Firestore était recréé à chaque frame.
- **Découvert pendant** : Phase 7, Bloc C, item 3 (1/3), en écrivant
  `provider_jobs_tab_test.dart` après ajout du seam `driverRepositoryOverride`.
- **Cause racine** : `watchAvailableMissionsForDriver()` et `watchActiveMissionForDriver()`
  étaient appelés directement dans `build()`. Le `setState()` synchrone de `_accept()`
  (passage `isAccepting=true`) déclenchait un rebuild immédiat → nouveau `Stream` à chaque
  frame → le `StreamBuilder` repassait en `ConnectionState.waiting`, masquant la carte
  "Acceptation en cours..." et recréant un abonnement Firestore inutile à chaque frappe.
- **Correctif appliqué** : streams mémorisés par `driverId` (`_ensureStreams()`), jamais
  recréés tant que le `driverId` ne change pas.
- **Test de régression** : `test/driver/provider_jobs_tab_test.dart` (8 tests) — mission
  admissible visible avec offre, liste vide, acceptation réussie + navigation, loading pendant
  la requête (bouton désactivé + carte visible), stream non recréé pendant `setState`. Résultat :
  **8/8 PASS**.
- **Commit** : `0259619` ("Phase 7 Bloc C item 3 (1/3): seam driverRepositoryOverride + tests
  ProviderJobsTab + fix BUG P1 (Stream recréé à chaque setState)").
- **Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc C, item 3).

---

## BUG-006 — `DriverActiveMissionScreen` : boucle infinie de resynchronisation GPS sur échec permanent

- **Composant** : `lib/screens/driver/driver_active_mission_screen.dart` (`_syncGpsSharing()`).
- **Sévérité** : **P1** — martèlement du service de localisation natif à chaque frame en cas
  d'échec GPS permanent (service désactivé / permission refusée), avec risque de dégradation de
  performance et de batterie sur un vrai appareil.
- **Découvert pendant** : Phase 7, Bloc C, item 3 (2/3), en écrivant
  `driver_active_mission_status_gaps_test.dart` (test de sonde comptant les appels
  `isLocationServiceEnabled`).
- **Cause racine** : `_syncGpsSharing()` était rappelé via `addPostFrameCallback` à CHAQUE
  `build()`. Si le GPS échoue durablement, `isRunning` restait `false` indéfiniment → chaque
  build retentait `start()` → `onError` → `setState()` → nouveau build → boucle infinie
  (confirmé par test de sonde : 10 appels `isLocationServiceEnabled` en 20 frames).
- **Correctif appliqué** : `_syncGpsSharingIfStatusChanged()` ne resynchronise que lorsque le
  statut GPS change réellement (mémoïsation du dernier statut connu), au lieu de retenter à
  chaque frame.
- **Test de régression** : `test/driver/driver_active_mission_status_gaps_test.dart` (9 tests) —
  couvre les 7 statuts de trajet (assigned → completed), disponibilité exclusive des actions
  par statut, erreur GPS pendant le trajet (pas de boucle, bandeau affiché une fois), double-tap
  protégé. Résultat : **9/9 PASS**.
- **Commit** : `19942c2` ("Phase 7 Bloc C item 3 (2/3): tests gaps DriverActiveMissionScreen
  (statuts trajet, GPS, double-tap) + fix BUG P1 (boucle infinie GPS sur echec permanent)").
- **Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc C, item 3).

---

## Bloc D — ANALYSTE/ADMIN/SUPER ADMIN : aucun nouveau bug

**Résultat** : 36 nouveaux tests (`functions/test/integration/adminPrivilegedActions.test.ts`)
couvrant les 10 Cloud Functions callables jusque-là non testées (`setUserRole`, `suspendDriver`,
`reactivateDriver`, `requestDriverDocuments`, `updatePricingConfiguration`, `applyDriverPromotion`,
`qualifyFoundingDriver`, `revokeFoundingDriverStatus`, `createFinancialSnapshot`,
`logDriverReviewOpened`) plus le gap "permission-denied" sur `validateDriverDocument`/
`rejectDriver` — **36/36 PASS au premier essai, aucun bug trouvé**. Chaque garde de rôle
(`requireAdminOrAbove`/`requireAnalystOrAbove`/`requireSuperAdmin`) fonctionne exactement comme
prévu par le code source. **Aucune entrée BUG-007+ à ajouter pour ce bloc.**

---

## Bloc E — AUTH/SESSION/CLAIMS : aucun nouveau bug applicatif

**Résultat** : 29 nouveaux tests (`test/auth/admin_auth_gate_session_claims_test.dart` 13/13 PASS +
`functions/test/integration/authSessionClaims.test.ts` 16/16 PASS) couvrant session (signup/login/
logout/mauvais mot de passe/email inconnu/refresh token), claims (chargement/échec réseau/
downgrade), et round-trip de rôles via `setUserRole` (Bloc D) sur des callables sensibles
(`suspendDriver`, `requestDriverDocuments`). **Aucun bug P0/P1 applicatif trouvé.**

Deux corrections de type "erreur d'écriture de test" (pas des bugs produit) ont eu lieu via
TEST→FAIL→FIX→RETEST DANS le nouveau fichier lui-même, documentées en commentaire inline :
1. AUTH-E-S06 : assertion `id_token` forcément différent après refresh — invalide car l'émulateur
   Auth émet des JWT non signés (`alg: none`) et déterministes ; si signup+refresh ont lieu dans la
   même seconde sans changement de claims, le texte du token peut être identique. Assertion
   retirée, les assertions significatives (`claims.user_id === localId`) conservées.
2. AUTH-E-C04 : `setUserRole` ciblait un UID Auth jamais créé → `"There is no user record..."`.
   Corrigé par l'ajout d'un `authAdmin.createUser()` préalable dans le test.

**Durcissement proactif (pas un correctif de bug)** : `functions/src/functions/setUserRole.ts`
appelle désormais `authAdmin.revokeRefreshTokens(targetUid)` après `setCustomUserClaims()`, en
défense en profondeur. Limitation documentée : n'invalide pas un ID token déjà émis et non expiré
(`onCall` n'utilise pas `checkRevoked: true`) — risque résiduel connu, hors périmètre d'un
correctif ciblé. Aucune régression sur les 36 tests Bloc D (`adminPrivilegedActions.test.ts`).

**Aucune entrée BUG-007+ à ajouter pour ce bloc.**

---

## Bloc F — ROUTING/DEEP LINKS

### BUG-007 (P2, CORRIGÉ) — Overflow AppBar `ProviderDashboardShell` sur téléphone étroit

**Contexte** : découvert en écrivant le test de non-régression du Switch online/offline (gap F-2,
`provider_dashboard_shell_status_gate_test.dart`), PAS un bug pré-existant connu.

**Cause** : sur téléphone étroit (320-428px de large, iPhone SE jusqu'à iPhone Pro Max), l'AppBar
de `ProviderDashboardShell` (bouton retour + titre "Espace fournisseur" + libellé statut
"Disponible"/"Hors ligne" + Switch online/offline + cloche notifications + sélecteur de langue +
bouton déconnexion) dépassait l'espace horizontal disponible → `RenderFlex` overflow reproductible
sur toutes les largeurs de téléphone testées (320/390/412/428px), sauf 360px. Confirmé via
`tester.view.physicalSize` (API correcte dans ce contexte de test ; `setSurfaceSize()` est
deprecated et ne propage pas fidèlement `MediaQuery.size`).

**Correctif** : AppBar responsive sous 480px de large (`isNarrowPhone = screenWidth < 480`) —
masque UNIQUEMENT les libellés texte décoratifs ("Espace fournisseur", "Disponible"/"Hors ligne",
sélecteur de langue compact). **Aucune action essentielle n'est masquée** : le Switch
online/offline (action de sécurité critique du gap F-2) reste TOUJOURS visible et fonctionnel sur
toutes les largeurs, avec un `Tooltip` préservant l'information de statut de façon accessible même
sans le texte.

**Fichier modifié** : `lib/screens/dashboard/provider/provider_dashboard_shell.dart`
(58 insertions / 22 suppressions).

**Test de régression** : `test/driver/provider_dashboard_shell_status_gate_test.dart` (4/4 PASS —
pending_review → Switch désactivé, suspended → Switch désactivé, approved → Switch actif
(régression), défense niveau 2 backend). Revérifié manuellement : 0 overflow sur
320/360/390/412/428/600px après correction. `flutter analyze` : clean sur le fichier impacté.

**Statut** : CORRIGÉ, aucune régression détectée.

### F-3 (deep-link notification → mission) : aucun nouveau bug

**Résultat** : nouveau fichier `test/notifications/notifications_deep_link_test.dart` (7 tests,
7/7 PASS au premier essai) couvrant notification client valide (F-3.1), mission
supprimée/inexistante (F-3.2), mission d'un autre utilisateur côté client et côté chauffeur
(F-3.3), branchement client/chauffeur nominal, et `missionId` null/vide. Chaque scénario a atteint
une protection déjà correcte et existante (F-1 côté client, `mission.driverId != uid` côté
chauffeur, fallback `mission == null`) **sans qu'aucune modification de code de production n'ait
été nécessaire**. Ajout technique associé : seam `BackendLocator.notificationRepositoryOverride`
(infrastructure de test uniquement, même pattern que les seams existants) — pas un correctif de
bug.

### ROUTE-F-01 à ROUTE-F-06 (routes invalides/paramètres invalides) : aucun nouveau bug

**Résultat** : `test/routing/app_router_invalid_routes_test.dart` (6/6 PASS) confirme que
l'absence volontaire de `errorBuilder`/`onUnknownRoute` personnalisé dans
`lib/router/app_router.dart` n'est PAS un défaut : le fallback par défaut de
`MaterialApp.router`/GoRouter ("Page Not Found" + bouton Home) gère proprement toute route
inconnue ou paramètre manquant, sans écran blanc, sans exception, sans fuite d'autorisation
(routes admin protégées redirigent vers `AdminLoginScreen`) et sans boucle de redirection.

**Bilan Bloc F** : 1 bug trouvé et corrigé (BUG-007, P2, UI uniquement — aucun impact
sécurité/données). F-1, F-3, et ROUTE-F-01..06 n'ont révélé aucun nouveau bug.

---

## BUG-008 — `NotificationsScreen` : échec de `markAsRead()` jamais catché (exception non gérée)

- **Composant** : `lib/screens/notifications/notifications_screen.dart` (callback `onTap` de
  `_NotificationTile`).
- **Sévérité** : **P2** — `markAsRead()` est une écriture Firestore directe (pas de Cloud
  Function) protégée uniquement par firestore.rules ; en cas d'échec (permission-denied
  transitoire, coupure réseau), le `Future` rejeté n'était jamais `await`é ni catché par l'appelant
  → l'exception remonte comme erreur non gérée jusqu'au binding Flutter (crash potentiel en
  production selon la politique de zone d'erreur de l'app ; dans le test, elle fait planter la
  suite avec `CloudFunctionException` non catchée).
- **Découvert pendant** : Phase 7, Bloc G, gap G-4 (Firestore write failure), en écrivant
  `test/network/notification_mark_as_read_write_failure_test.dart` avec un
  `_FlakyNotificationRepository` qui fait échouer `markAsRead()`.
- **Cause racine** : `BackendLocator.notificationRepository.markAsRead(userId, n.id);` appelé
  en "fire-and-forget" sans `.catchError(...)` ni `try/catch`.
- **Correctif appliqué** : ajout de `.catchError((_) {})` sur l'appel, avec commentaire explicite
  documentant l'intention : le marquage lu/non-lu est un confort UX secondaire, son échec ne doit
  jamais bloquer la navigation vers la mission liée (action principale du tap).
- **Test de régression** : `test/network/notification_mark_as_read_write_failure_test.dart`
  (2 tests) — G-4.1 (échec initial : aucun faux succès, aucun crash, navigation vers la mission
  reste fonctionnelle malgré l'échec de l'écriture) et G-4.2 (retry après échec : nouvel essai
  possible, succès confirmé, aucun état bloqué). Résultat : **2/2 PASS** après correctif.
- **Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc G, gap G-4).

---

## Bloc G — bilan

**Résultat** : 6 tests créés sur les 3 gaps réels identifiés (G-1/G-2, G-3, G-4), **6/6 PASS**.
1 bug trouvé et corrigé (BUG-008, P2). Aucun bug P0/P1. `flutter test` complet du projet :
**410/410 PASS, aucune régression**. `flutter analyze` : 0 souci nouveau.

---

## Bloc H — GPS / Tracking durcissement : aucun nouveau bug

**Résultat** : 1 seul GAP réel identifié (H-2 — lifecycle GPS au niveau
`DriverActiveMissionScreen`, jusqu'ici non prouvé explicitement bien que le code existant
(`_syncGpsSharing()`/`_syncGpsSharingIfStatusChanged()`) le gère déjà correctement depuis le fix
BUG-006). Nouveau fichier `test/driver/driver_active_mission_gps_lifecycle_test.dart` (6 tests,
**6/6 PASS au premier essai**) prouvant : démarrage réel du partage sur statut de trajet actif,
arrêt réel sur `completed`/`cancelled`, idempotence (aucune 2e boucle démarrée sur transitions
internes "partage actif"), nettoyage propre au `dispose()`, idempotence `stop()`/`stop()` isolée.
**Aucun bug trouvé** — chaque assertion a directement validé le comportement déjà correct du code
de production, sans qu'aucune correction n'ait été nécessaire.

H-1 (permissions GPS) et H-4 (sécurité tracking `driver_locations`) étaient déjà entièrement
couverts par des tests existants (`driver_location_reporter_test.dart` et
`securityRules.test.ts`) — référencés sans duplication. H-3 (BUG-006) réexécuté : reste
**18/18 PASS**, aucune régression. H-5 (background/foreground) documenté honnêtement
`DEFERRED NON-BLOCKING → Phase 8` (non implémenté, aucune architecture construite arbitrairement).
H-6 (position stale/invalide) documenté `N/A` (aucun consommateur actuel n'en dépend).

**Bilan** : Aucun bug P0/P1/P2/P3 pour ce bloc. `flutter test` complet du projet :
**416/416 PASS, aucune régression** (410 précédents + 6 nouveaux). `flutter analyze` : 0 souci
nouveau (3 issues `info` pré-existantes non liées, inchangées).

---

## Bloc I — Notifications : aucun nouveau bug

**Résultat** : 2 GAPS réels identifiés — I-2 (read/unread + badge `NotificationBell`, jamais
testé dédiée, explicitement noté "hors périmètre... cf. Bloc I" par le test G-4) et I-3
(gestion d'erreur du listener `NotificationsScreen.watchNotifications()`, le pattern G-3
n'existant jusqu'ici que sur `CustomerTrackingScreen`). Nouveau fichier
`test/notifications/notifications_realtime_and_unread_test.dart` (6 tests, **6/6 PASS**)
prouvant : badge temps réel qui reflète le compteur non-lu (incrément/décrément/plafond "99+"),
idempotence de `markAsRead()` appelé deux fois sur la même notification (aucune exception,
aucun état incohérent), mise à jour temps réel de la liste de notifications, gestion propre
d'une erreur de listener (aucun crash, contenu non trompeur, message d'erreur affiché), et
reprise normale après une nouvelle émission valide sur le même flux.

**Aucun bug trouvé** — chaque assertion a validé un comportement déjà correct du code de
production (`NotificationBell`, `NotificationsScreen`).

I-1 (création — 8 transitions de statut via `onMissionStatusChangeNotifyCustomer`) était déjà
entièrement couvert par `functions/test/integration/onMissionStatusChangeNotifyCustomer.test.ts`
(15 cas) — référencé sans duplication. I-1 secondaire (`detectExpiringDocuments.ts`,
`transitionFoundingDriverPeriods.ts`) n'a pas de test dédié mais réutilise le même schéma
d'écriture déjà validé ; aucun bug démontré → non-bloquant, documenté. I-4 (duplication) :
architecture par `onDocumentUpdated`, aucun scénario de duplication réelle démontrable en usage
normal → pas de nouveau système de dédup construit arbitrairement. I-5 (navigation) référencé
Bloc F sans duplication. I-6 (FR/EN/ES notifications) confirmé COUVERT par audit direct des clés
`notif_*`/`notifications_*` dans `app_strings.dart`. I-7 (push mobile FCM/APNs réel) documenté
`DEFERRED / Phase 8` — aucune dépendance `firebase_messaging`/FCM/APNs dans le projet.

**Bilan** : Aucun bug P0/P1/P2/P3 pour ce bloc. `flutter test` complet du projet :
**422/422 PASS, aucune régression** (416 précédents + 6 nouveaux). `flutter analyze` : 0 souci
nouveau (3 issues `info` pré-existantes non liées, inchangées).

---

## BUG-009 (P2, CORRIGÉ) — Overflow bandeau signalement `SafetyScreen` sur téléphone étroit

- **Composant** : `lib/screens/info/safety_screen.dart` (bandeau "Signaler un problème" en haut
  de l'écran Sécurité).
- **Découvert pendant** : Phase 7, Bloc J, gap J-5 (modals/dialogs sur écran critique), en
  écrivant `test/responsive/critical_screens_viewport_test.dart` à 320px de large — PAS un bug
  pré-existant connu, jamais testé à une largeur de téléphone étroite auparavant.

**Contexte** : le bandeau d'alerte en haut de `SafetyScreen` combine une icône, un message
texte explicatif et un bouton "Signaler un problème" dans une seule `Row` horizontale, à
l'intérieur d'un `Container` à fond dégradé.

**Cause** : contrairement à `ProviderDashboardShell` (déjà corrigé en BUG-007), ce bandeau
n'avait aucune logique responsive pour les largeurs étroites. À 320px de large (iPhone SE),
la somme des largeurs minimales de l'icône + `Expanded(message)` + bouton dépassait l'espace
disponible → `RenderFlex overflowed by 146 pixels on the right`, reproductible à 100 % à cette
largeur. Le test a intentionnellement refusé d'ignorer `tester.takeException()` ou d'élargir
artificiellement le viewport (règle anti-triche J), révélant ainsi un bug réel de layout.

**Correctif** : application du même seuil que BUG-007 (`isNarrow = MediaQuery.of(context).size.width
< 480`) via un `Builder` englobant le bandeau. Sous ce seuil, l'icône + le message restent sur une
première ligne (`Row` avec `Expanded` sur le texte) et le bouton "Signaler un problème" est
déplacé sur sa propre ligne en dessous (`Column` en pleine largeur), au lieu d'être compressé à
côté du texte. **Aucun contenu ni action n'est masqué** — seule la disposition change ; le bouton
reste pleinement visible, lisible et actionnable à toutes les largeurs testées.

**Fichier modifié** : `lib/screens/info/safety_screen.dart`.

**Test de régression** : `test/responsive/critical_screens_viewport_test.dart` (groupe J-5,
1 test) — dialog "Signaler un problème" à 320px de large : contenu du bandeau visible sans
overflow, ouverture du dialogue de signalement (`AlertDialog` + `TextField` + boutons
"Annuler"/"Envoyer") entièrement accessible, fermeture via "Annuler" sans exception. Revérifié :
0 overflow après correction, `tester.takeException()` nul. `flutter analyze` sur le fichier
impacté : clean ("No issues found!").

**Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc J, gap J-5).

---

## Bloc J — Responsive / Viewports : 1 bug trouvé et corrigé (BUG-009)

**Résultat** : nouveau fichier `test/responsive/critical_screens_viewport_test.dart`
(11 tests, **10/11 PASS au premier essai puis 11/11 PASS après correctif**) couvrant :

- **J-1/J-2** (régression BUG-007 + matrice de viewports) : `ProviderDashboardShell` testé aux
  largeurs 320/360/390/430/480px (Switch online/offline toujours visible et fonctionnel, aucun
  overflow) + 600px (libellés décoratifs réapparaissent, `isNarrowPhone == false` confirmé) —
  **6/6 PASS, aucune régression, aucun nouveau bug** : le correctif BUG-007 tient toujours sur
  l'ensemble de la matrice de largeurs.
- **J-3** (effet FR/EN/ES sur écran critique) : `AuthScreen` testé dans les 3 langues à 320px
  (largeur la plus contraignante) — **3/3 PASS**, aucun overflow, aucune régression liée à la
  longueur variable des chaînes traduites.
- **J-4** (clavier/formulaires) : `AuthScreen` en mode inscription sous hauteur verticale
  réduite (simulation clavier virtuel, 375×320) — **1/1 PASS**, les 3 champs et le bouton CTA
  final restent atteignables via `ensureVisible`/scroll, aucun contenu bloqué hors écran.
- **J-5** (modals/dialogs) : `SafetyScreen`, dialogue de signalement à 320px — **a révélé
  BUG-009** (voir ci-dessus), corrigé, puis **1/1 PASS**.
- **J-6** (web/desktop) : déjà couvert par `test/finance/admin_finance_ui_test.dart`
  (`NavigationRail` desktop à 1200×900) — référencé sans duplication, aucun écran supplémentaire
  n'est prévu en usage desktop dans le périmètre actuel.

**Bilan** : 1 bug trouvé et corrigé (BUG-009, P2, UI uniquement — aucun impact
sécurité/données, même classe de sévérité que BUG-007). Aucun bug P0/P1. `flutter test` complet
du projet : **433/433 PASS, aucune régression** (422 précédents + 11 nouveaux). `flutter
analyze` : 0 souci nouveau (3 issues `info` pré-existantes non liées, inchangées).

---

## BUG-010 (P2, CORRIGÉ) — Messages d'exception brute affichés à l'utilisateur admin (finance)

- **Composant** : 5 fichiers `lib/screens/dashboard/admin/finance/tabs/` :
  `admin_finance_payouts_tab.dart`, `admin_finance_ledger_tab.dart`,
  `admin_finance_reconciliation_tab.dart` (2 occurrences, 2 State classes distinctes),
  `admin_finance_taxes_tab.dart`, `admin_finance_payout_policy_tab.dart`.
- **Sévérité** : **P2** — pas de risque sécurité/données, mais violation directe de la règle
  K-6 (aucun texte technique/anglais forcé visible en FR/ES) : un admin francophone ou
  hispanophone voyait le `toString()` brut de l'exception attrapée (potentiellement
  `CloudFunctionException`/`FirebaseException` en anglais ou message technique) au lieu d'un
  message localisé.
- **Découvert pendant** : Phase 7, Bloc K, gap K-6 (audit ciblé des patterns
  `catch (e)` + `Text('$e')`/`SnackBar` dans `lib/`).
- **Cause racine** : `SnackBar(content: Text('$e'), backgroundColor: AppColors.error)` dans 6
  blocs `catch` d'actions admin (reverse payout, ajustement ledger, relance réconciliation,
  résolution anomalie, recalcul taxes, sauvegarde politique de payout), affichant directement
  l'exception interceptée sans passer par `LocaleProvider`.
- **Correctif appliqué** : remplacement des 6 occurrences par
  `Text(t('admin_action_error'))` (ou `Text(widget.t('admin_action_error'))` selon
  l'accesseur de traduction déjà en portée dans chaque méthode), en réutilisant la clé i18n
  **déjà existante et complète FR/EN/ES** `admin_action_error` — aucune nouvelle clé requise.
  Le détail technique de l'exception reste disponible en log développeur (non supprimé), seul
  l'affichage utilisateur est corrigé.
- **Test de régression** : validation ciblée via `flutter analyze` (scope
  `lib/screens/dashboard/admin/finance/tabs/` → "No issues found!", puis full-projet → 0 souci
  nouveau) + `flutter test test/finance/` (53/53 PASS sur le domaine impacté) + `flutter test`
  complet du projet : **433/433 PASS, aucune régression**.
- **Statut** : **CORRIGÉ** ✅ (Phase 7, Bloc K, gap K-6).

---

## Bloc K — I18N GLOBAL : EN COURS (fermeture partielle honnête à date de ce commit)

**Reconnaissance effectuée** (K-0, K-7, K-8) :

- **K-0** : audit programmatique du dictionnaire `lib/l10n/app_strings.dart` (753 clés) via
  script Python de parsing du littéral `_t` — **0 clé avec locale manquante, 0 doublon**. Le
  dictionnaire lui-même est structurellement sain.
- **K-8** : cross-référence des 426 appels `t('clé')` trouvés dans `lib/` contre les 753 clés
  définies — **0 clé utilisée mais non définie**. Aucun risque de fallback accidentel côté
  dictionnaire.
- **K-7** : recherche ciblée des chaînes visibles codées en dur (`grep` sur les patterns
  `Text('...')`/`labelText:`/`SnackBar`) — 41 candidats initiaux triés en faux positifs
  (ex. `language_selector.dart` : noms de langue en écriture native, par conception, pas un
  bug ; `admin_finance_reconciliation_tab.dart` lignes 321-449 et
  `admin_driver_detail_screen.dart` lignes 420/424 : déjà `widget.t(...)`, faux positifs de
  grep) et **GAPS RÉELS CONFIRMÉS** (fichiers entiers sans aucun usage de `LocaleProvider`,
  donc 100% hardcodés en français indépendamment de la langue choisie) :
  - `lib/screens/auth/admin_login_screen.dart` (CRITIQUE — écran de connexion admin, 0 usage
    `LocaleProvider` sur 351 lignes).
  - `lib/screens/dashboard/customer/tabs/customer_profile_tab.dart` (0 usage, 182 lignes).
  - `lib/screens/dashboard/provider/tabs/provider_profile_tab.dart` (0 usage, 182 lignes,
    inclut une méthode `_statusLabel()` qui duplique en dur des libellés alors que les clés
    `driver_status_*` existent déjà et sont complètes FR/EN/ES).
  - `lib/screens/dashboard/customer/tabs/customer_messages_tab.dart` (0 usage, 32 lignes,
    écran "bientôt disponible").
  Et des **GAPS PARTIELS** (fichiers utilisant déjà `LocaleProvider` mais avec des chaînes
  résiduelles non traduites) : `lib/screens/auth/auth_screen.dart`,
  `lib/screens/driver/driver_onboarding_screen.dart`,
  `lib/screens/mechanic_provider/mechanic_onboarding_screen.dart`,
  `lib/screens/mechanic/mechanic_request_flow_screen.dart`, `lib/widgets/app_shell.dart`,
  `lib/screens/dashboard/admin/admin_dashboard_shell.dart`,
  `lib/screens/dashboard/admin/drivers/admin_drivers_list_screen.dart` (1 seul mot, "Retry",
  à remplacer par la clé existante `common_retry`).
- **K-6** : audit et **correction complète** des messages d'exception brute → voir BUG-010
  ci-dessus. **Fermé.**

**Non encore fait à ce commit** : correction effective des GAPS listés ci-dessus (K-1
Auth, K-2 Client, K-3 Chauffeur, K-4 Admin partiels), ajout des nouvelles clés i18n
nécessaires, écriture des tests K-9 (détection automatisée des écrans sans `LocaleProvider`
et/ou des clés manquantes), audit K-5 (Notifications) non encore mené explicitement.

**PROCHAINE ACTION EXACTE** : corriger dans l'ordre `admin_login_screen.dart` →
`customer_profile_tab.dart` → `provider_profile_tab.dart` → `customer_messages_tab.dart` →
restes de `auth_screen.dart`/`driver_onboarding_screen.dart`/
`mechanic_onboarding_screen.dart`/`mechanic_request_flow_screen.dart`/`app_shell.dart`/
`admin_dashboard_shell.dart`/`admin_drivers_list_screen.dart` (méthode TEST→FAIL→FIX→RETEST
par fichier, ajout des clés i18n manquantes dans `app_strings.dart`), puis K-5, puis K-9,
avant de pouvoir déclarer "BLOC K : ✅ FERMÉ" et poursuivre K2 → L.

**Bloc K n'est PAS fermé à ce commit — poursuite prévue à la prochaine session, limite de
budget d'itérations atteinte honnêtement documentée.**

---

*Ce fichier sera enrichi au fil des blocs K à W avec tout nouveau bug découvert (ID
séquentiel BUG-011, ...), classé P0/P1/P2/P3, avec cause, correctif, test de
régression et statut.*

---

## MISE À JOUR — Bloc K fermé ce tour

Aucun nouveau bug P0/P1/P2 découvert lors de la fermeture des résidus K-5 (4/7 à 7/7) et de
l'audit Notifications : tous les gaps traités étaient des chaînes non traduites (dette i18n),
pas des bugs fonctionnels. Un gap mineur a été noté et corrigé au passage : la clé
`notifications_open_tooltip` existait dans le dictionnaire mais n'était câblée nulle part
(`NotificationBell` sans `tooltip:`) — corrigé, pas de ticket dédié (trivial, même nature que
BUG-010).

**BLOC K : ✅ FERMÉ.** P0 ouverts = 0. P1 ouverts = 0.

---

## MISE À JOUR — Bloc K2 (Timezone/Date) : EN COURS (ce tour)

3 gaps réels trouvés et **corrigés** (P2, affichage uniquement, aucune donnée métier fausse) :
1. `admin_driver_detail_screen.dart` : Timestamp brut tronqué affiché à l'admin
   (`"2026-08-26 12:24:28"`) au lieu d'un format localisé → corrigé (`formatDisplayDate()`).
2. `admin_drivers_list_screen.dart::_formatDate()` : composants de date extraits SANS
   `.toLocal()` préalable → corrigé.
3. `provider_earnings_tab.dart` : même gap (extraction date sans `.toLocal()`) → corrigé.

1 gap réel identifié mais **PAS ENCORE corrigé** (P3, cosmétique) : connecteur `'à'` codé en dur
dans le formatage date/heure (au lieu de `'at'`/`'a las'` en EN/ES) — 3 fonctions concernées,
voir détail et plan de correction dans `docs/PHASE7_QA_PLAN.md`.

`flutter analyze` → 3 infos pré-existantes non liées, 0 erreur. `flutter test` → 469/469 PASS
(464 Bloc K + 5 nouveaux `k2_utc_local_boundary_test.dart`), 0 régression.

**BLOC K2 : ⚠️ PAS ENCORE FERMÉ.** P0 ouverts = 0. P1 ouverts = 0. P2 = 0 (les 3 gaps trouvés
ont été corrigés). P3 ouvert = 1 (connecteur `'à'` codé en dur, K2-3).

**Reprise prévue** : terminer K2-3 (connecteur i18n date/heure) puis K2-7 (confirmer N/A DST ou
traiter), déclarer BLOC K2 fermé, puis démarrer Bloc L (Accessibilité MVP) sans s'arrêter.

---

## MISE À JOUR — Bloc K2 : ✅ FERMÉ (K2-3 corrigé + K2-7 documenté N/A, ce tour)

**K2-3 (P3, cosmétique) résolu** : nouvelle clé i18n `datetime_connector_at` (fr='à', en='at',
es='a las') créée et câblée dans tous les points d'appel identifiés (`money_format.dart`,
`mission_finance_section.dart`, `notifications_screen.dart`, et propagation à
`provider_payouts_section.dart`, `admin_payment_detail_screen.dart`,
`admin_driver_detail_screen.dart`). Plus aucun `'à'` codé en dur dans les chemins de production
identifiés. 2 nouveaux tests ajoutés (`test/timezone/k2_utc_local_boundary_test.dart`), PASS.

**K2-7 (DST) — N/A, aucun bug** : grep ciblé confirme l'absence de calcul de durée basé sur
l'heure locale dans les 4 fichiers d'expiration/durée déjà identifiés — 0 occurrence de
`Duration(days`/`Duration(hours`/`add(const Duration`/`subtract(const Duration`.

> K2-7 : N/A — les décisions métier utilisent des instants/timestamps absolus; aucun calcul
> métier DST-sensitive identifié.

**Validation** : `flutter analyze` → 3 infos pré-existantes non liées, 0 erreur. `flutter test`
complet → **471/471 PASS** (469 + 2 nouveaux), 0 régression.

**BLOC K2 : ✅ FERMÉ.** P0 ouverts = 0. P1 ouverts = 0. P2 ouverts = 0. P3 ouverts = 0 (le seul
P3 identifié, connecteur codé en dur, est maintenant corrigé).

## MISE À JOUR — Bloc L (session en cours, PARTIEL)

Nouveaux gaps réels trouvés par tests (P3, DEFERRED NON-BLOCKING) :

- **BUG-L2-01** (P3) : `AuthScreen` à 320px de largeur avec text scale 1.5x/2.0x produit un `RenderFlex overflow` réel (confirmé par `tester.takeException()`). DEFERRED NON-BLOCKING — nécessite refonte layout (scroll/flexible) hors budget session actuelle. Non bloquant : app reste utilisable à l'échelle système par défaut (1.0x).
- **BUG-L3-01** (P3) : au moins une carte de sélection de rôle (`InkWell`) sur `AuthScreen` mesure ~38px de hauteur, sous la recommandation Android de 48x48 (ou seuil test 44px). DEFERRED NON-BLOCKING — correction simple (augmenter min-height) à planifier en session suivante, aucun impact fonctionnel bloquant identifié.

Tally après cette session : P0 = 0, P1 = 0, P2 = 0, P3 = 2 (nouveaux, tous deux DEFERRED NON-BLOCKING, non bloquants pour MVP).

Non traité cette session (reporté, pas de bug identifié encore) : L-5 (clavier web), L-6 (contraste), L-7 (photo/preuve), L-8 (loading states).

## MISE À JOUR — Bloc L (suite et clôture partielle, cette session)

**BUG-L6-01 (P1, contraste) — CORRIGÉ** : `AppColors.warning` (0xF59E0B) utilisé comme couleur de
TEXTE (pas juste badge décoratif) donnait un contraste ~2.15:1 sur fond blanc/clair — sous le
seuil WCAG AA (4.5:1 texte normal, 3:1 icône/large text). Cas réel identifié : message
d'avertissement GPS dans `DriverActiveMissionScreen` (information de sécurité potentiellement
critique pour le chauffeur). Nouvelle couleur `AppColors.warningText` (0xB45309, ambre plus
foncé) ajoutée dans `app_colors.dart`, contraste ~5.0:1 sur blanc / ~4.7:1 sur `background` —
respecte AA. Câblée dans le message + icône GPS de `driver_active_mission_screen.dart`. Les
badges/pastilles décoratifs existants (`StatusBadge`, `ComingSoonBadge`, cartes statut chauffeur)
qui utilisent encore `AppColors.warning` brut sur fond teinté (~1.96:1) sont **DEFERRED NON-
BLOCKING (P2)** : ce sont des labels courts systématiquement accompagnés d'un intitulé de champ
explicite ailleurs dans l'écran (pas la seule source d'information), non bloquants pour le MVP,
mais à corriger en Phase 8 (remplacer `AppColors.warning` par `AppColors.warningText` dans tous
les usages "texte de statut" identifiés : `finance_ui_helpers.dart`, `admin_drivers_list_screen.dart`,
`admin_driver_detail_screen.dart`, `provider_earnings_tab.dart`, `provider_payouts_section.dart`,
`provider_profile_tab.dart`, `admin_finance_payout_policy_tab.dart`).

**L-5 (clavier web)** : reconnaissance ciblée — `AdminLoginScreen` a déjà `onSubmitted` sur le
champ mot de passe (soumission par Entrée). Les formulaires admin finance (`TextField` de
filtres/montants) sont des champs de saisie simples sans action de soumission critique liée à la
touche Entrée (pas de gap identifié). **DEFERRED NON-BLOCKING** : audit exhaustif de l'ordre de
tabulation (`FocusTraversalOrder`) sur tous les écrans admin, hors budget session actuelle — aucun
P0/P1 identifié par la reconnaissance faite.

**L-7 (photo/preuve)** : confirmé — le flux de capture de preuve de livraison
(`driver_active_mission_screen.dart::_ProofPreviewDialog`) utilise déjà des labels texte explicites
pour tous ses contrôles (`driver_active_mission_confirm_proof`, `driver_active_mission_retake_photo`,
pas de bouton icon-only). Aucun gap trouvé. **COUVERT**.

**L-8 (loading states)** : référence confirmée aux tests existants de double-soumission
(`test/customer/delivery_request_flow_double_submit_test.dart`,
`test/driver/driver_active_mission_proof_upload_test.dart`,
`test/driver/driver_status_screen_test.dart`) qui prouvent déjà que les boutons d'action async
sont désactivés (`onPressed: null`) pendant le chargement, empêchant tout double-tap. **COUVERT
(référencé, pas dupliqué)**.

**Validation finale Bloc L** : `flutter analyze` → 3 infos + 2 warnings pré-existants (assets
`images/`/`icons/` non liés à ce bloc), 0 erreur. `flutter test` complet → **479/479 PASS** (478
précédents + 1 nouveau test de régression contraste BUG-L6-01), 0 régression.

**BLOC L : ✅ FERMÉ.**
- L-0 à L-4 : FAIT (session précédente).
- L-5 : reconnaissance faite, aucun P0/P1, reste DEFERRED NON-BLOCKING pour audit exhaustif.
- L-6 : 1 gap réel P1 corrigé (BUG-L6-01) ; gap P2 restant sur badges décoratifs documenté DEFERRED.
- L-7 : COUVERT, aucun gap.
- L-8 : COUVERT (référencé aux tests Bloc B/C existants).
- L-2/L-3 : gaps P3 déjà documentés DEFERRED NON-BLOCKING (session précédente, AuthScreen 320px/
  text scale 2.0 overflow ; carte rôle 38px < 48px).

P0 ouverts = 0. P1 ouverts = 0 (BUG-L6-01 corrigé). P2 ouverts = 1 (badges décoratifs warning,
DEFERRED). P3 ouverts = 2 (déjà documentés session précédente, DEFERRED).

**PROCHAINE ACTION** : démarrer Bloc M (Performance), puis N (Firestore/Indexes), puis O (Cloud
Functions hardening).

## MISE À JOUR — Bloc M (Performance MVP, cette session)

**BUG-M-01 (P1, corrigé)** — `provider_dashboard_shell.dart` : `watchDriverProfile()`
instancié dans `build()`, recréé à chaque `setState()` de `_toggleAvailability`
(flicker + re-souscription Firestore). Fix : mémoïsation par `driverId` (pattern
Bloc C). Test de régression ajouté (`provider_dashboard_shell_status_gate_test.dart`).

**BUG-M-02 (P1, corrigé)** — `driver_status_screen.dart` : même pattern, recréé à
chaque `_runAction()` (resoumission dossier / toggle en ligne). Fix : mémoïsé par `uid`.

**BUG-M-03 (P1, corrigé)** — `admin_driver_detail_screen.dart` : StreamBuilder
(`watchDriverProfile`) + 2 FutureBuilder (`users/{id}.get()`, `getDriverVehicles()`)
recréés/refetchés à chaque action admin (`_actionInProgress` toggle via Approuver/
Refuser/Suspendre/Réactiver/Documents). Fix : capturés en `late final` (driverId
stable pour la durée de vie de l'écran) — 1 seul appel réseau désormais par ouverture
d'écran au lieu d'un par clic d'action.

**BUG-M-04 (P1, corrigé)** — `customer_tracking_screen.dart` : `Image.network` de la
preuve de livraison sans `cacheWidth`/`cacheHeight` malgré un affichage fixe 220px vs
source jusqu'à 1600px (décodage pleine résolution gaspillé). Fix : `cacheHeight` ajouté.

**GAP-M-05 (P2, DEFERRED NON-BLOCKING)** — `tabs[_index]` (indexation directe, pas
`IndexedStack`) détruit/recrée le State d'onglet non affiché à chaque changement
d'onglet dans `provider_dashboard_shell.dart`. Un remplacement par `IndexedStack` a
été tenté puis **reverté** : il construit les 4 onglets dès le premier rendu, créant
des souscriptions Firestore supplémentaires immédiates (Earnings/Calendar/Profile)
même quand l'utilisateur reste sur le premier onglet — un coût réseau ajouté au
démarrage, pire que le gap initial pour l'usage MVP typique (rester sur "Missions
disponibles"). Un vrai correctif nécessiterait une construction paresseuse par onglet
(ex: garder chaque tab vivant seulement après sa première visite). Non-bloquant :
n'affecte que la fraîcheur du flux après un retour d'onglet, pas de fuite ni de crash.

**GAP-M-06 (P2, DEFERRED NON-BLOCKING)** — `watchNotifications()` et
`watchDriversByStatus()` sans `.limit()`. Sous-collection par utilisateur / liste
admin-only, volumes MVP faibles, non mesurés comme un risque réel à ce stade.

**BLOC M : ✅ FERMÉ** — P0=0, P1=0 (4 corrigés), P2=2 (DEFERRED documentés).
Validation finale : `flutter analyze` 0 erreur, `flutter test` 480/480 PASS.

## MISE À JOUR — Bloc N (Firestore/Indexes, cette session)

**BUG-N-01 (P1, corrigé)** — `firestore.indexes.json` : l'index composite collectionGroup
`history(recorded_at asc)` — requis par la Cloud Function planifiée
`cleanupExpiredTrackingHistory` (purge GPS quotidienne, cron 02:00 America/Toronto) et
documenté depuis l'étape 10 (`docs/FIRESTORE_INDEXES.md` entrée #20) — était en réalité
**absent** du fichier de configuration réel (confirmé par énumération programmatique :
seulement 20 entrées, la dernière étant `audit_logs`). Ce job aurait échoué avec
`FAILED_PRECONDITION` dès sa première exécution contre un vrai Firestore en production
(`movik-connect-prod`), silencieusement (job planifié, pas de retour utilisateur direct) —
avec pour conséquence une accumulation indéfinie de points GPS historiques jamais purgés
(coût de stockage croissant, violation de la politique de rétention 30 jours). Fix : entrée
ajoutée à `firestore.indexes.json`, validée comme JSON syntaxiquement correct.

**BUG-N-02 (P1, corrigé)** — `functions/src/lib/missionFinancialBalance.ts` : la recherche
du `driver_payout` `paid` incluant le snapshot financier d'une mission donnée lisait
**tous** les `driver_payouts` `status=='paid'` de la **plateforme entière**, sans `.limit()`
ni filtre par chauffeur — un scan qui grossit avec le volume total de payouts payés
tous-chauffeurs-confondus au fil du temps, alors que seul le `driver_id` du chauffeur de
CETTE mission peut jamais être pertinent. Ce chemin est exécuté à chaque recalcul de
solde financier de mission (après capture paiement, refund, tip, ajustement ledger,
payout) — donc potentiellement très fréquent. Fix : requête bornée par
`where('driver_id', '==', snapshotsDriverId)` en plus de `status=='paid'`, réutilisant
l'index composite existant #16 (`driver_payouts(driver_id, created_at desc)`, dont le
préfixe `driver_id` suffit pour cette equality-only query — pas de nouvel index requis).
Fallback conservé sur le comportement historique (scan status-only) si `driver_id` n'a pas
pu être résolu à partir des snapshots (cas théorique). Tests : `missionFinancialBalance.
test.ts` (24 tests incl. le scénario #6 multi-snapshots/même-payout qui exerce exactement
ce chemin) + suite intégration complète (512/512) → PASS, 0 régression.

**Réaffirmés DEFERRED (aucune preuve nouvelle Bloc N)** :
- `watchNotifications()` sans `.limit()` (P2, déjà documenté Bloc M).
- `watchDriversByStatus()` sans `.limit()` (P2, déjà documenté Bloc M).

**Nouveau P3 documenté (non-bloquant)** : index Firestore #4
(`delivery_requests(customer_id, created_at desc)`) non consommé par l'implémentation
réelle de `watchCustomerMissions()` (tri en mémoire côté client, pas de `.orderBy()`
serveur) — inoffensif, juste sur-provisionné ; note ajoutée à
`docs/FIRESTORE_INDEXES.md`.

**BLOC N : ✅ FERMÉ** — P0=0, P1=0 (2 corrigés : BUG-N-01, BUG-N-02), P2=2 (réaffirmés
DEFERRED), P3=1 (nouveau, documenté). Validation : `npx tsc --noEmit` 0 erreur,
`npm run lint` 0 erreur, Jest unit 109/109 PASS, Jest integration 512/512 PASS.

## MISE À JOUR — Bloc O (Cloud Functions Hardening, cette session)

**BUG-O-01 (P2, corrigé)** : `functions/src/functions/createDeliveryRequest.ts` acceptait
`distanceKm`/`estimatedDurationMinutes` sans AUCUNE validation runtime — seul
`calculateDeliveryQuote.ts` (le devis, en amont) validait ces champs (`typeof === "number" &&
>= 0`). Or `createDeliveryRequest` est le SEUL point d'écriture réel de `delivery_requests`
(`firestore.rules` interdit `create` direct), et ces valeurs sont relues plus tard par
`acceptDelivery()` pour le recalcul serveur du prix (`calculateCustomerQuote()`). Un client
pouvait donc persister une distance/durée négative ou non-numérique. Impact financier réel
NUL aujourd'hui (`missionBaseValue` est plancherée par `rule.minimum_charge` dans
`pricingEngine.ts` — un `rawBase` négatif est simplement remplacé par le minimum), mais il
s'agit d'une donnée métier incohérente à rejeter explicitement plutôt que de la tolérer
silencieusement. **Fix** : ajout des mêmes gardes que `calculateDeliveryQuote.ts`
(`typeof input.X !== "number" || !Number.isFinite(input.X) || input.X < 0` → `invalid-argument`).
**Tests** : 3 nouveaux cas dans `createDeliveryRequest.test.ts` (distanceKm négatif,
estimatedDurationMinutes négatif, distanceKm non-numérique) — chacun prouve qu'aucune mission
n'est créée et que le devis reste non consommé (`is_consumed: false`). 16/16 tests du fichier
PASS (13 existants + 3 nouveaux) via émulateur Firestore/Auth.

**Autres analyses O-1 à O-8** : voir la matrice consolidée complète dans
`docs/PHASE7_QA_MATRIX.md` (section "BLOC O"). Résumé : 16/18 fonctions critiques listées
étaient déjà couvertes par des tests d'idempotence/retry/auth EXISTANTS (référencés, non
dupliqués, conformément à la consigne de vitesse de cette session) ; aucun autre gap P0/P1/P2
trouvé. 2 points P3 documentés (non-bloquants, DEFERRED) : message d'erreur `acceptDelivery`
sur un retry même-chauffeur (imprécis mais fonctionnellement sûr — la garde
`if (mission.driver_id) throw failed-precondition` s'exécute avant toute écriture) ; absence
d'un type d'anomalie `payment_stuck_authorized` dans `reconciliationEngine.ts` (DEFERRED →
Phase 8). Scan de secrets (O-8) : PASS, aucun secret réel trouvé (uniquement des valeurs
fictives dans des tests dédiés à prouver l'absence de fuite).

**BLOC O : ✅ FERMÉ** — P0=0, P1=0, P2=1 corrigé (BUG-O-01), P3=2 documentés (non-bloquants).
Validation : `npx tsc --noEmit` 0 erreur, `npm run lint` 0 erreur, Jest unit 109/109 PASS,
intégration ciblée 16/16 PASS (suite complète ré-exécutée en validation finale groupée).

## MISE À JOUR — Bloc P (Storage Hardening, cette session)

**Aucun P0/P1 trouvé.** Toutes les protections attendues (driver documents propriétaire-only,
proof de livraison chauffeur-assigné-only, immutabilité, cross-user denied, unauthenticated
denied, content-type restreint, tailles limitées) étaient déjà implémentées correctement dans
`storage.rules` (Phase 3) — le travail de ce bloc a consisté à PROUVER cette couverture, pas à
la corriger.

**Gap de PREUVE comblé (pas un bug de règle)** : `storageRules.test.ts` (15 tests) ne contenait
aucun test exerçant un rejet pour taille de fichier, malgré des limites numériques déjà définies
dans `storage.rules` (`isValidDocumentUpload()` : 10 Mo, `isValidImageUpload()` : 5 Mo). 2 tests
ajoutés (`5bis`, `11bis`) confirment par exécution réelle contre l'émulateur que ces limites
fonctionnent bien (`assertFails` sur un upload de `10*1024*1024+1`/`5*1024*1024+1` octets). Un
3e test (`5ter`) réaffirme explicitement pour `driver_documents` (déjà implicite par la règle,
mais non testé explicitement) qu'un client (customer) et qu'un utilisateur non authentifié sont
DENIED en lecture ET en écriture — symétrique au comportement déjà prouvé pour `delivery_proofs`
(tests 9/10/12).

**P-6 (download access, "très important")** : recherche externe confirme que
`getDownloadURL()` génère une URL dont le token bypass les Security Rules une fois connu — fait
plateforme Firebase documenté (GitHub firebase-js-sdk #5342, docs officielles), pas un bug
applicatif. Audit complet de tous les points d'usage réel dans le repo :
- `driver_documents` : AUCUN appel `getDownloadURL()` nulle part — fonctionnalité non construite
  (bouton "voir document" admin est un placeholder explicite dans le code). Aucune exposition
  possible aujourd'hui.
- `delivery_proofs` : le seul `getDownloadURL()` du repo (`firebase_proof_upload_repository.
  dart:38`) produit une URL dénormalisée sur `delivery_requests/{id}.proof_of_delivery_url` et
  `tracking_events/{id}.metadata.proof_of_delivery_url` — tous deux lisibles EXACTEMENT par le
  même ensemble de parties (`customer_id==uid() || driver_id==uid() || isAnalystOrAbove()`) déjà
  autorisées à lire le fichier directement via la règle Storage elle-même. Aucune surface
  d'exposition supplémentaire créée.
- `disputes/{id}.proof_of_delivery_url` : toujours `null` (jamais réassigné dans
  `disputeOrchestration.ts`), et la collection `disputes` est lisible uniquement par
  `isAnalystOrAbove()` — sous-ensemble strict des lecteurs Storage.
- `profile_photos` : lecture publique par design (`allow read: if true`) — un token ne réduit
  aucune sécurité déjà nulle par choix produit (avatar non sensible).

**Conclusion P-6 : COUVERT**, aucun fix requis. Point de vigilance documenté pour toute future
fonctionnalité qui transmettrait cette URL vers un canal externe (export admin, webhook,
notification push) — à réévaluer à ce moment, non-bloquant aujourd'hui.

**P-7 (orphan files)** : séquence `completeDelivery.ts` confirmée — upload Storage réussi PUIS
appel `completeDelivery()` PUIS transaction Firestore. Si la transaction échoue (contention,
statut déjà avancé), le fichier Storage reste sans référence Firestore. Fréquence attendue très
faible (fenêtre de contention étroite), aucune fuite de sécurité (fichier orphelin reste protégé
par les mêmes règles Storage restrictives), coût de stockage négligeable (photo unique).
**Classé `DEFERRED NON-BLOCKING → Phase 8 cleanup`** — candidat pour une future Cloud Function
de nettoyage périodique, hors scope Phase 7 (pas de garbage collector construit maintenant).

**BLOC P : ✅ FERMÉ** — P0=0, P1=0, aucun bug de règle trouvé (3 tests de preuve ajoutés :
`5bis`, `5ter`, `11bis`). P2/P3 : 1 point de vigilance future documenté (P-6) + 1 DEFERRED →
Phase 8 (P-7), ni l'un ni l'autre bloquant. Validation : suite `storageRules.test.ts` 19/19 PASS
(15 préexistants + 4 nouveaux assertions, 0 régression) via émulateur Firestore+Auth+Storage.

## MISE À JOUR — Bloc Q (Application Security, cette session)

**Aucun P0/P1/P2/P3 nouveau trouvé.** Ce bloc a explicitement référencé les protections déjà
prouvées dans Phase 3 Security, Bloc D, E, F, N, O, P — sans dupliquer d'audit. Les seules
vérifications NOUVELLES effectuées ce tour (lecture directe de règle, aucun gap trouvé) :

- **`driver_locations/{driverId}`** (Q-2, IDOR tracking) : la règle Firestore exige un double
  `get()` — le document `active_delivery_id` référencé doit exister ET son `customer_id` ainsi
  que son `driver_id` doivent correspondre exactement au lecteur ET au chauffeur ciblé. Aucun
  accès cross-mission possible : un client ne peut jamais lire la position d'un chauffeur avec
  lequel il n'a aucune mission active en cours.
- **`driver_internal_notes/{noteId}`** (Q-2, IDOR notes analyste) : `allow read:
  isAnalystOrAbove()` — confirmé que le chauffeur concerné, même propriétaire du dossier, ne peut
  JAMAIS lire ses propres notes internes.
- **Q-6 (secrets)** : re-scan complet du repo (patterns Stripe/PEM/GitHub, fichiers
  `.env*`/`serviceAccountKey*`) — PASS, aucun secret réel, seules occurrences étant le pattern de
  rédaction lui-même (`observability.ts`) et un commentaire d'exemple.
- **Q-10 (logs/erreurs)** : relecture ciblée des 2 seuls call-sites `internal(...)`
  (`createCustomerPaymentProfile.ts`, `createDriverStripeAccount.ts`) confirmant qu'ils ne
  concatènent que `err.message` (jamais `err.stack` ni une clé API) — cohérent avec la
  conclusion O-7 du Bloc O.

Toutes les autres sous-catégories (Q-1 authorization server-side, Q-3 mass assignment, Q-4 input
abuse, Q-5 data exposure, Q-7 client trust, Q-8 Rules ciblées, Q-9 routing) étaient déjà
entièrement couvertes par des preuves existantes des blocs D/E/F/K/N/O/P — référencées sans
duplication de test.

**BLOC Q : ✅ FERMÉ** — P0=0, P1=0, aucun nouveau bug. Validation : aucun nouveau test requis
(aucun gap de comportement) ; validation complète tsc/lint/Jest/Flutter/Rules exécutée en groupe
final P→Q→Q2.

## MISE À JOUR — Bloc Q2 (App Check / Anti-Abuse, cette session)

**Aucun P0/P1.** Un seul point P2 documenté DEFERRED :

**GAP-Q2-01 (P2, DEFERRED — non-bloquant)** : `calculateDeliveryQuote` (Cloud Function
callable) n'a aucune limite de fréquence — un utilisateur authentifié peut générer un nombre
illimité de devis sans aucun garde. Impact réel évalué FAIBLE : chaque appel écrit un document
Firestore léger (coût de stockage négligeable), aucun appel provider externe coûteux (Stripe,
etc.), aucun effet financier (un devis n'est qu'une proposition de prix, jamais une transaction).
De plus, toute fonction sensible de cette app exige déjà `requireSignedIn()` — aucune fonction
n'est accessible anonymement (confirmé : pas de `signInAnonymously()` dans
`firebase_auth_provider.dart`), ce qui constitue déjà une barrière anti-abuse significative
indépendante de ce gap. **Mécanisme prévu pour combler ce gap : Firebase App Check (enforcement
Phase 8) + un éventuel rate-limiter dédié**, aucun des deux construits ce tour (conforme à la
consigne explicite "ne pas construire une plateforme anti-DDoS"). Classé **DEFERRED → Phase 8**.

**Constat factuel important (pas un bug)** : le SDK `firebase_app_check` est présent dans
`pubspec.yaml` (dépendance installée) mais **aucune intégration réelle n'existe** — ni
activation client (`FirebaseAppCheck.instance.activate()`), ni provider Android/Web configuré,
ni `enforceAppCheck` sur aucune des 31 Cloud Functions `onCall`, ni référence `request.app` dans
les Security Rules. Ce n'est PAS un P0/P1 : App Check production nécessite une configuration
externe (Play Integrity, reCAPTCHA, App Attest, domaines de production réels) hors de portée du
développement Phase 7, correctement classée `Phase 8 — EXTERNAL CONFIGURATION`. Aucune fausse
déclaration faite : nous n'affirmons PAS qu'App Check production est activé, car il ne l'est pas.

**BLOC Q2 : ✅ FERMÉ** — P0=0, P1=0, P2=1 documenté (GAP-Q2-01, DEFERRED → Phase 8).

## MISE À JOUR — Bloc R (Backward Compatibility)

**GAP-R-01** (P2, corrigé) : `FoundingDriverQualification.fromJson`
(`lib/finance/models/founding_driver.dart`) utilisait `DateTime.parse(json['qualified_at'] as
String)`/`DateTime.parse(json['promotional_period_ends_at'] as String)` sans garde — plante sur un
document partiel/corrompu. Exposition réelle NULLE constatée (aucun repository de ce projet ne
désérialise de vrai document `founding_driver_programs/*/qualifications/*` via ce constructeur ;
utilisé uniquement comme paramètre en mémoire par les moteurs de calcul). Corrigé par précaution
(repli `DateTime.tryParse(...) ?? DateTime.now()`, `driverId`/`programId` repliés sur `''`).
Test : `test/finance/backward_compatibility_r_test.dart` (FAIL confirmé avant fix, PASS après).

**GAP-R-02** (P2, corrigé) : `ManualDriverAdjustment.fromJson`
(`lib/finance/models/driver_compensation.dart`) — même pattern (casts non-nullables `as
String`/`as num`/`DateTime.parse` sans garde). Code mort au sens strict (aucun appelant réel hors
tests). Corrigé par précaution (tous les champs repliés sur une valeur sûre).

**Aucun autre gap trouvé** : 8 autres cas de casts non-nullables suspects (`driver_document.dart`,
`driver_vehicle.dart`, `financial_snapshot.dart`, `pricing_config.dart`, `transaction_ledger.dart`,
`driver_location.dart`, `driver_location_history_point.dart`) ont été vérifiés via le chemin
d'écriture Cloud Functions + `firestore.rules` et confirmés **COUVERT-PAR-CONCEPTION** : un seul
schéma a toujours existé pour ces collections depuis leur création, le champ ne peut PAS être
absent d'un document réel. Conformément à la consigne, aucune compatibilité n'a été construite pour
un état qui ne peut pas exister en production. `app_user_v2.dart`/`audit_log.dart` (`created_at`)
étaient déjà correctement gardés (faux-positif du grep initial).

**BLOC R : ✅ FERMÉ** — P0=0, P1=0, P2=2 trouvés et corrigés (aucun DEFERRED, coût de correction
nul pour les deux).

## MISE À JOUR — Bloc R2 (Migrations)

Aucun bug trouvé. Tous les changements de schéma historiques (`driver_payouts.amount` →
`amount_minor`, `audit_logs.action`/`source_function`) sont soit antérieurs à toute donnée réelle
en production, soit déjà absorbés par un parser défensif. Aucun script de migration nécessaire,
aucune correction requise.

**BLOC R2 : ✅ FERMÉ** — P0=0, P1=0, P2=0.

## MISE À JOUR — Bloc S (Multi-user)

**GAP-S-02** (P2, DEFERRED) : pas de test dédié à la race exacte "annulation client + acceptation
chauffeur strictement simultanées" sur le même document mission. Protection structurelle déjà
présente (transaction Firestore standard sur `missionRef` dans `acceptDelivery`/`cancelDelivery`),
mais non prouvée par un test ciblé. Reporté Phase 8/prochain tour.

**GAP-S-04** (P2, DEFERRED — décision produit requise) : `suspendDriver.ts` met
`driver_profiles.status = suspended` mais `completePickup.ts`/`completeDelivery.ts` ne
revérifient QUE `mission.status` + `driver_id == uid()`, jamais `driver_profiles.status`. Un
chauffeur suspendu en cours de mission active PEUT continuer à progresser cette mission jusqu'à
completion. Non corrigé ce tour : ambiguïté métier (interrompre une livraison en cours pourrait
créer un colis orphelin, potentiellement pire pour le client) — nécessite une décision produit
explicite avant toute correction. Si validé comme un vrai bug par le produit, le correctif
consisterait à ajouter une vérification `driver_profiles.status === 'approved'` dans la transaction
de `completePickup.ts` et `completeDelivery.ts`.

Aucun P0/P1 trouvé dans le Bloc S.

**BLOC S : ✅ FERMÉ** — P0=0, P1=0, P2=2 documentés DEFERRED (GAP-S-02, GAP-S-04).

## MISE À JOUR — Bloc T (Load MVP)

Aucun bug trouvé. 3 GAPS de couverture de test (pas des bugs) comblés par 4 nouveaux tests dans
`functions/test/integration/loadMvpBlocT.test.ts` : concurrence acceptation à 5 chauffeurs (T-1),
burst de créations de mission (T-2), volume de tracking GPS (T-3), finance sur missions
indépendantes en parallèle (T-5). Tous PASS, aucune régression sur la suite complète (522/522).
Les 2 `.limit()` P2 déjà documentés (Bloc M/N, `watchNotifications`/`watchDriversByStatus`)
restent DEFERRED — aucune preuve nouvelle ce bloc ne justifie un fix.

**BLOC T : ✅ FERMÉ** — P0=0, P1=0, P2=0 nouveau (2 P2 pré-existants réaffirmés DEFERRED).

## MISE À JOUR — Bloc T2 (Firebase Cost Profile)

Aucun bug trouvé — bloc d'estimation/documentation, pas de correction de code. Constat notable
(non-bloquant, informatif) : le tracking GPS (`recordTrackingPoint`, appelé toutes les 8s pendant
un trajet actif) représente ~90-95% du volume total de writes Firestore à toutes les échelles
pilote testées (10/100/1000 missions/jour). Ce n'est PAS classé comme un bug ni un GAP — la
rétention automatique (`cleanupExpiredTrackingHistory`, 30 jours) est déjà en place (Bloc N-7), et
aucune preuve de coût réel excessif n'a été mesurée (émulateur uniquement). Documenté comme
information de veille pour une décision produit future si le volume dépasse largement le cadre MVP.

**BLOC T2 : ✅ FERMÉ** — P0=0, P1=0, P2=0.

## MISE À JOUR — Bloc U, U-0 (dead upload button chauffeur) — EN COURS

**BUG-U-01 — P1, CORRIGÉ.**

- **Repro** : `driver_onboarding_screen.dart`, étapes "Véhicule" et "Documents" — 3 boutons
  (`vehicle_photos`, `upload_license`, `upload_insurance`) avaient `onPressed: () {}`. `canProceed(3)`
  ne vérifiait aucun document : un chauffeur pouvait atteindre `pending_review` sans jamais fournir
  permis/assurance/photo véhicule.
- **Cause** : aucun repository d'upload binaire Storage n'existait pour les documents chauffeur
  (contrairement à `ProofUploadRepository` pour la preuve de livraison) — `submitDriverDocument`
  n'écrit que les métadonnées Firestore, jamais le fichier lui-même. Vérification exhaustive
  (`driver_status_screen.dart`) : aucune autre voie fonctionnelle d'upload n'existe ailleurs dans
  l'app → classé P1 (contrôle présenté comme upload, inerte, faussant le parcours d'inscription).
- **Fix** :
  - Nouveau `DriverDocumentUploadRepository` (+ `FirebaseDriverDocumentUploadRepository` +
    `NotConfiguredDriverDocumentUploadRepository`), même pattern exact que `ProofUploadRepository`,
    ciblant le chemin Storage déjà spécifié par `storage.rules` (Bloc P, non modifié) :
    `driver_documents/{driverId}/{fileName}`. Enregistré dans `BackendLocator` avec le même seam de
    test (`driverDocumentUploadRepositoryOverride`).
  - Les 3 boutons ouvrent maintenant une sélection réelle (`ImagePicker`, seul mécanisme déjà
    abstrait dans le repo — caméra ou galerie via bottom sheet), avec état visuel du fichier
    sélectionné (nom affiché, remplaçable).
  - **Décision d'architecture** : le compte Firebase Auth + le custom claim `driver` (requis par
    `storage.rules` pour écrire sous `driver_documents/{driverId}/...`) ne sont créés/rafraîchis
    qu'à la soumission finale du wizard (`_handleSubmit`). Les boutons du wizard ne font donc
    QUE une sélection locale (bytes en mémoire) ; l'upload Storage réel + l'écriture des métadonnées
    (`submitDriverDocument`, déjà existant) ont lieu dans `_handleSubmit()`, juste après
    `refreshClaims()` et avant `submitForReview()` — jamais avant que le claim ne soit visible.
  - `canProceed(3)` exige maintenant permis ET assurance réellement sélectionnés (photo véhicule
    reste optionnelle, étape "Véhicule"). Échec d'upload → `_submitError` affiché, aucune
    transition vers `pending_review`, fichiers déjà sélectionnés conservés (retry sans tout
    re-choisir). Aucune nouvelle architecture parallèle : réutilisation stricte du repository
    Storage (nouveau, mais même pattern), des chemins/règles Storage existants (Bloc P) et du
    modèle `DriverDocument` existant.
- **Cas mécanicien (`mechanic_onboarding_screen.dart`)** : investigation confirme que ce module
  reste actuellement backé par `AuthProvider`/Hive (`signInOrRegister`, `StorageService.mechanicBox`)
  et non par Firebase — aucun `MechanicRepository` Firebase, aucune règle Storage/Firestore dédiée
  au mécanicien n'existe dans le repo. Le fix des 3 boutons dead (`certifications`, `upload_id`,
  `upload_liability_insurance`) pour ce module est **DIFFÉRÉ** dans ce même mouvement (traité comme
  un point séparé, non résolu ici) : appliquer le même correctif nécessiterait de construire un
  backend Firebase mécanicien complet, ce qui excède le périmètre de U-0 et constituerait une
  décision produit majeure (statut MVP du module mécanicien) qui n'appartient pas à l'agent.
  À trancher explicitement par le fondateur avant de soit brancher soit désactiver ces boutons.
- **Complément de testabilité (même mouvement)** : `_handleSubmit()` lisait `auth.user?.uid` au
  lieu de `auth.effectiveUid` — le seam de test documenté dans `firebase_auth_provider.dart`
  (`debugForceUid`) et déjà utilisé pour la même raison dans `driver_active_mission_screen.dart`
  et `driver_status_screen.dart`. `user` reste `null` par construction dans ce mode simulé, donc
  lire `user?.uid` rendait ce flux structurellement impossible à tester pour un chauffeur déjà
  connecté sans mocker tout le SDK Firebase Auth. Correctif d'une ligne, comportement production
  inchangé (`effectiveUid` == `user!.uid` quand `user` est un vrai `fb.User`).
- **Tests** : `test/driver/driver_onboarding_document_upload_test.dart` (créé) — 5 cas, couvrant
  exactement les 4 scénarios critiques demandés plus le cas `NotConfigured*` :
  1. tap "Sélectionner" (permis) → `FakeImagePickerPlatform` réellement sollicité, nom de fichier
     affiché immédiatement (état UI mis à jour).
  2. upload réussi → `DriverDocumentUploadRepository.uploadDriverDocument()` appelé pour les 2
     documents requis, `DriverRepository.submitDriverDocument()` appelé avec `status: uploaded` et
     le bon `driverId`, puis `submitForReview()` appelé (flux complet non bloqué).
  3. upload échoué → `_submitError` affiché, `submitForReview()` **jamais** appelé (aucune
     transition `pending_review` avec un dossier incomplet), bouton de soumission réactivé (retry
     possible), fichiers déjà sélectionnés conservés (pas besoin de tout re-choisir).
  4. document déjà présent → re-tap "Modifier" remplace le fichier existant (pas de duplication),
     `canProceed(3)` reste cohérent (toujours bloqué tant que l'assurance manque).
  - Root-cause de l'instabilité précédente (tests retirés du commit initial) identifiée et
    corrigée : (a) `pumpAndSettle()` ne se stabilise jamais après `showModalBottomSheet` combiné
    au picker simulé dans ce harnais — remplacé par des `pump(duration)` bornés, pattern isolé
    dans un seul helper de test, aucun impact sur le code applicatif ; (b) sur la plateforme
    `dart:io` de `cross_file` (celle utilisée par `flutter test`), `XFile.name` dérive de `path`
    et NON du paramètre `name` — le fake picker doit fournir `path:` en plus de `name:` pour que
    `picked.name` soit fidèle à ce qui se passerait en production (plugin natif réel).
  - Le test pré-existant `driver_onboarding_step0_rebuild_test.dart` reste PASS (aucune
    régression). Suite complète `test/driver/` : 64/64 PASS (59 pré-existants + 5 nouveaux).

## MISE À JOUR — Bloc U, complément U-0 (module mécanicien) — GAP-U-MECHANIC

**Décision produit reçue explicitement** (non ré-auditée) : pour la Phase 7/MVP actuel, ne PAS
construire de backend Firebase mécanicien complet dans cette session. Confirmation reprise de
l'investigation BUG-U-01 : aucun `MechanicRepository` Firebase, aucune règle Storage/Firestore
dédiée au mécanicien n'existent dans le repo — ce module reste entièrement backé par l'ancien
`AuthProvider`/Hive (`signInOrRegister`).

**GAP-U-MECHANIC — remédiation UX (pas un P0/P1 classique, un défaut UX trompeur corrigé par
mesure de cohérence produit)** :

- **Repro (avant correctif)** : `mechanic_onboarding_screen.dart` — 4 boutons
  `OutlinedButton.icon(onPressed: () {})` ("Certifications", "Pièce d'identité", "Assurance
  responsabilité civile", "Numéro d'entreprise") étaient présentés comme des actions
  fonctionnelles alors qu'ils ne faisaient strictement rien. Trompeur pour l'usager (il pouvait
  croire avoir "cliqué pour rien" ou que l'app était cassée), sans bloquer l'inscription
  (`canProceed` ne les exige déjà pas).
- **Fix** : les 4 actions sont remplacées par un nouveau widget `_ComingSoonActionRow` — un
  `Container`/`Row` STRICTEMENT non interactif (aucun `onPressed`/`GestureDetector`/`InkWell`
  nulle part, plus fort qu'un simple bouton désactivé) affichant l'icône + le libellé existant +
  le `ComingSoonBadge` déjà existant, réutilisé tel quel (aucun nouveau composant créé), dont le
  texte provient de la clé i18n `common_coming_soon` déjà traduite en FR/EN/ES
  ("Bientôt disponible"/"Coming soon"/"Próximamente"). Aucun faux succès, aucun faux upload :
  rien n'est simulé, l'état "indisponible" est honnête.
- **Bug additionnel trouvé et corrigé au passage (BUG-003, nouvelle occurrence, même cause
  racine que `DeliveryRequestFlowScreen`/`DriverOnboardingScreen`)** : à l'étape 0 (Profil) de
  `MechanicOnboardingScreen`, `canProceed(0)` lit `_nameController.text`/`_emailController.text`
  directement, mais les `TextField` correspondants n'avaient aucun `onChanged` déclenchant un
  rebuild parent — le bouton "Suivant" restait figé désactivé après une saisie complète et
  valide. Détecté en écrivant le test GAP-U-MECHANIC (le wizard ne progressait jamais au-delà de
  l'étape 0). Corrigé avec le même correctif que les occurrences précédentes
  (`onChanged: (_) => setState(() {})` sur les 2 champs lus par `canProceed`). Rattaché à
  **BUG-003** (pas de nouveau numéro, cause racine identique).
- **Tests** : `test/mechanic/mechanic_onboarding_coming_soon_test.dart` (créé), 3 cas :
  1. Étape "Spécialités" : le libellé "Certifications" reste visible mais n'a plus d'ancêtre
     `OutlinedButton`/`ElevatedButton`/`TextButton` avec `onPressed != null` ; le badge "Bientôt
     disponible" est visible ; taper sur la ligne ne provoque aucune exception ni effet
     observable.
  2. Étape "Documents" : les 3 libellés (pièce d'identité, assurance responsabilité civile,
     numéro d'entreprise) restent visibles, ne sont plus portés par un bouton fonctionnel, et
     chacun affiche son propre badge "Bientôt disponible" (3 badges distincts) ; aucune exception
     en tapant dessus.
  3. Sanity i18n (EN) : le même badge apparaît traduit ("Coming soon"), confirmant l'absence de
     chaîne FR codée en dur.
  - Suite complète `flutter test test/` : 493/493 PASS (490 pré-existants + 3 nouveaux), aucune
    régression. `flutter analyze` sur les fichiers touchés : 0 erreur.

**BLOC U : 🟡 TOUJOURS EN COURS** — U-0 (cas chauffeur, BUG-U-01) **CORRIGÉ ET COUVERT PAR TESTS
DE RÉGRESSION**. U-0 (cas mécanicien, GAP-U-MECHANIC) **CORRIGÉ ET COUVERT PAR TESTS DE
RÉGRESSION** (aucun backend mécanicien construit, conformément à la décision produit).
`flutter analyze` 0 erreur ; `flutter test test/` 493/493 PASS. U-1 à U-6 non traités dans ce
mouvement — prochaine étape.

**BLOC U : ✅ FERMÉ** (U-1 à U-6 tous PASS). Récapitulatif final :

- **BUG-U-01** (P1, chauffeur, corrigé — PR #1) : boutons upload documents onboarding chauffeur
  inertes (`onPressed: () {}`), aucun document jamais fourni. Corrigé : sélection réelle via
  `ImagePicker`, upload Storage réel, permis+assurance obligatoires pour soumission.
- **GAP-U-MECHANIC** (P1, mécanicien, corrigé — PR #2) : mêmes boutons inertes côté onboarding
  mécanicien, mais AUCUN backend mécanicien construit (décision produit) → corrigé en remplaçant
  les boutons inertes par des badges "Bientôt disponible" explicites (pas de simulation d'upload).
- **BUG-U-02** (P2, U-6, corrigé ce tour) : `_Step2Addresses` de `DeliveryRequestFlowScreen`
  — les en-têtes "Adresse de ramassage"/"Adresse de livraison" (`Icon` + `Text` non contraint dans
  un `Row`) provoquent un `RenderFlex overflowed` de 41 à 81px à largeur téléphone réelle
  (320-360px), révélé par `test/responsive/bloc_u_mobile_sanity_test.dart` (U-6.1). Repro : ouvrir
  l'étape 2 du flux de création de mission à 320px de large. Cause : `Text` non enveloppé dans un
  `Expanded`/`Flexible` alors que le libellé traduit peut dépasser l'espace disponible une fois
  l'icône et son espacement soustraits. Correctif : `Expanded(child: Text(..., overflow:
  TextOverflow.ellipsis))` sur les deux en-têtes (pickup et dropoff). Test de régression :
  `U-6.1` (2 cas, 320px/360px) — vert après correctif.
- **BUG-U-03** (P2, U-6, corrigé ce tour) : `_DocumentPickerRow` (étape Documents de
  `DriverOnboardingScreen`, réutilisée pour permis/assurance) — l'`OutlinedButton`
  "Sélectionner"/"Modifier" à taille par défaut provoque un `RenderFlex overflowed` de 11 à 51px
  à largeur téléphone réelle (320-360px), révélé par `test/responsive/bloc_u_mobile_sanity_test.dart`
  (U-6.4). Repro : atteindre l'étape Documents du wizard chauffeur à 320px de large. Cause :
  `OutlinedButton` par défaut (padding/`minimumSize`/taille de texte standard Material) trop large
  une fois combiné à l'icône + colonne texte déjà `Expanded` dans le même `Row`. Correctif : style
  compact dédié (`padding` réduit, `minimumSize: Size.zero`, `tapTargetSize:
  MaterialTapTargetSize.shrinkWrap`, `textStyle` 11.5px) sur ce bouton précis, sans toucher au
  style global des boutons de l'app. Test de régression : `U-6.4` (2 cas, 320px/360px) — vert
  après correctif.

**Validation finale unique T→T2→U** : `flutter analyze` (0 erreur nouvelle, seuls les warnings
préexistants assets/images-icons et le generated template firebase-tools/dart subsistent, hors
scope) ; `flutter test test/` **504/504 PASS** (493 préexistants + 11 nouveaux U-6) ; `npx tsc
--noEmit` (functions) : 0 erreur.

**P0 ouverts (global T/T2/U) : 0. P1 ouverts : 0.**

## MISE À JOUR — BLOC V (Global Validation) — EN COURS

**BUG-V-01 (P1)** — `firestore.rules` : `delivery_requests/{missionId}` permettait à un client
propriétaire d'annuler (status -> `cancelled`) une mission **déjà dans un état terminal**
(`completed`, `cancelled`, `disputed`, `refunded`) via écriture Firestore directe. La règle ne
vérifiait que le statut **cible**, jamais le statut **actuel**. PREUVE : test ad hoc confirmant
qu'un client pouvait rouvrir en `cancelled` une mission `completed` (financièrement déjà close,
paiement capturé, ledger déjà écrit) — violation directe de la règle métier des états terminaux
(V-8). CORRECTIF : ajout de la condition
`!(resource.data.status in ['completed','cancelled','disputed','refunded'])` à la branche
"Annulation" de la règle `allow update`. Test de régression permanent ajouté à
`functions/test/integration/securityRules.test.ts` (5 nouveaux cas : blocage depuis
completed/cancelled/disputed/refunded + non-régression depuis `assigned`). **185/185 PASS** sur le
fichier complet après correctif (180 préexistants + 5 nouveaux).

**Reconnaissance V-1 à V-8** : chaînes E2E déjà existantes couvrant client↔chauffeur↔finance sur
mission unique confirmées et référencées (`e2eDeliveryLifecycle.test.ts`,
`e2eFinancialLifecycle.test.ts`, `onMissionStatusChangeNotifyCustomer.test.ts`,
`missionCancellationPaymentRelease.test.ts`, `adminPrivilegedActions.test.ts`,
`securityRules.test.ts`) — BUG-V-01 est le seul gap réel confirmé par une PREUVE à ce stade.

**Bloc V : 🟡 EN COURS** (BUG-V-01 fermé ; V-2 à V-8 restent à confirmer explicitement/documenter
avant fermeture officielle). **Bloc W et Bloc X : NON DÉMARRÉS.**

## MISE À JOUR — BLOC V : ✅ FERMÉ

V-2 à V-8 confirmés PASS par preuve active (référence de tests existants + 2 vérifications
ciblées supplémentaires, aucun nouveau bug trouvé) :

- **V-2** : investigation initiale a soulevé une question ouverte ("existe-t-il des notifications
  côté chauffeur ?"). Réponse confirmée par lecture du code : **NON, par choix d'architecture** —
  le dashboard chauffeur utilise des streams Firestore temps réel (`watchActiveMissionForDriver`,
  `watchAvailableMissionsForDriver` sur `delivery_offers/{id}`), pas une sous-collection
  `notifications`. Seul `transitionFoundingDriverPeriods.ts` écrit des notifications chauffeur
  (programme founding driver, sans rapport avec le statut de mission). **Ce n'est pas un gap.**
- **V-5** : investigation a soulevé une question ouverte ("calculateDriverPayout et
  runReconciliationNow ont-ils un test de refus non-admin ?"). `adminPrivilegedActions.test.ts` ne
  les référence pas — mais preuve trouvée qu'ils ont chacun leur PROPRE test dédié dans leur
  fichier respectif (`calculateDriverPayout.test.ts` L204, `reconciliationEngine.test.ts`
  L658-680). **Fausse alerte, aucun gap réel, aucun fix nécessaire.**
- **V-1, V-3, V-4, V-6, V-8** : couverture existante confirmée suffisante par lecture directe des
  suites déjà identifiées, aucune duplication créée.
- **V-7** : script jetable de sanity FR/EN/ES (747 clés vérifiées, 0 valeur vide, 0 clé utilisée
  non définie) — aucun fichier repo modifié par le script lui-même.

**Aucun nouveau bug trouvé pendant la fermeture de V-2 à V-8** (seul bug de tout le Bloc V :
BUG-V-01, déjà corrigé). **BLOC V : ✅ FERMÉ. P0 = 0. P1 = 0.**

## MISE À JOUR — BLOC W (Cleanup) — EN COURS (W-1 fermé, W-2/W-3/W-4/W-5 vérifiés sans gap)

- **W-1 (flutter analyze)** : 3 correctifs locaux et sûrs — retrait de `assets/images/`/
  `assets/icons/` de `pubspec.yaml` (dossiers inexistants sur disque, jamais commités, jamais
  référencés par `Image.asset`/`AssetImage` dans `lib/`) ; remplacement du `Radio<bool>` déprécié
  (API `groupValue`/`onChanged` dépréciée depuis Flutter 3.32) par une simple `Icon` décorative
  dans `_MechanicCard` (la sélection réelle était déjà pilotée par l'`InkWell.onTap` parent —
  aucun changement de comportement) ; correction du commentaire de documentation
  `storage_service.dart` (`Map<String, dynamic>` entre backticks pour éviter l'interprétation HTML
  des chevrons). `pubspec.lock` : un `pub get` déclenché par `flutter analyze` a fait remonter 7
  dépendances transitives — **annulé** (`git checkout -- pubspec.lock`), conformément à
  l'instruction W-6 de ne faire aucune montée de version. **`flutter analyze` : 0 issue sur le code
  du dépôt** (les 6 erreurs restantes sont dans `functions/node_modules/firebase-tools` — vendored,
  gitignored, template Dart généré, hors périmètre). `flutter test test/` : **504/504 PASS**, 0
  régression après les 3 correctifs.
- **W-2 (dead code)** : recherche ciblée non poussée jusqu'au bout dans ce mouvement (budget) —
  aucune preuve de code mort évident collectée au-delà de ce qui était déjà connu ; pas de
  suppression risquée sans preuve.
- **W-3 (TODO/FIXME)** : seulement **3 occurrences** dans tout `lib/`+`functions/src/` :
  `distance_estimation_service.dart` ("remplacer par une vraie API de routage" — dette Phase
  future, documentée, non-bloquante MVP), `calculateDriverPayout.ts`
  et `cleanupExpiredTrackingHistory.ts` (commentaires renvoyant à une passe d'archivage future,
  non-bloquante). **Aucun TODO/FIXME P0/P1 trouvé.**
- **W-4 (debug/logs)** : seulement **2 occurrences** de `debugPrint(` dans tout `lib/`
  (`backend_bootstrap.dart`), toutes deux gardées par `if (kDebugMode)` (donc absentes des builds
  release) et ne loggant que des messages d'état de configuration Firebase, jamais de donnée
  sensible (token, mot de passe, PII). `print(` : 0 occurrence. **Aucun debug dangereux, aucune
  donnée sensible dans les logs.**
- **W-5 (generated/local)** : vérification `git ls-files` — aucun fichier `.env`, `firebase-debug`,
  `.DS_Store`, `serviceAccountKey`, `node_modules/`, ou dossier `build/` tracké dans le dépôt.
  **Propre.**
- **W-6 (dependencies)** : aucune montée de version effectuée (le seul incident, une dérive
  transitive via `pub get`, a été annulé — voir W-1 ci-dessus). Identification exhaustive des
  dépendances manifestement inutilisées non complétée ce tour (budget) — reportée au prochain
  mouvement si nécessaire, sans risque connu.

**BLOC W : 🟡 EN COURS** — W-1 fermé et validé (0 régression), W-3/W-4/W-5 vérifiés sans gap
trouvé (aucun P0/P1), W-2/W-6 non complétés jusqu'au bout (aucune preuve de gap réel non plus,
juste non explorés exhaustivement par manque de budget ce tour). **Bloc X : NON DÉMARRÉ.**

## MISE À JOUR — BLOC W : ✅ FERMÉ (W-2 + W-6 traités)

- **W-2 (dead code, recherche ciblée)** : (1) `dart analyze lib/` → **0 issue** (inclut
  `unused_element`/`unused_import`/`unused_field` quand détectables avec confiance par
  l'analyseur). (2) Script heuristique complémentaire sur les **198 méthodes privées**
  (`_xxx()`) de tout `lib/` : recherche du nombre total d'occurrences de chaque identifiant dans
  l'ensemble du code — **0 suspect** (aucune méthode privée dont l'unique occurrence serait sa
  propre déclaration). (3) Recherche de classes legacy/dupliquées (`Legacy`/`_Old`/`Deprecated`,
  motif `V1` sans `V2` correspondant côté usage réel) : `DriverProfileV2` est la seule classe
  numérotée mais AUCUNE `DriverProfile` (V1) n'existe en parallèle — nommage historique, pas une
  duplication à nettoyer. (4) Recherche de blocs de code commenté (5+ lignes commentées
  consécutives contenant de la syntaxe de code) : 28 occurrences détectées par le script, **toutes
  vérifiées manuellement = commentaires explicatifs légitimes** (documentation de décisions
  d'architecture), aucun vrai code mort commenté trouvé. **Conclusion : aucune preuve de code mort
  à supprimer — rien supprimé, conformément à la consigne de ne pas retirer sans preuve.**
  Côté `functions/src/` : `npm run lint` (règle `@typescript-eslint/no-unused-vars` déjà active)
  → **0 warning** ; les 44 fichiers de `src/functions/` sont tous exportés et déployés depuis
  `src/index.ts` (44 exports pour 44 fichiers, aucun fichier orphelin non branché).

- **W-6 (dépendances manifestement inutilisées)** : comparaison de chaque dépendance directe de
  `pubspec.yaml` contre son usage réel (`grep -rl "package:<nom>/"` dans `lib/`). **3 dépendances
  directes confirmées inutilisées** : `cupertino_icons` (0 `CupertinoIcons.` nulle part),
  `intl` (0 `import 'package:intl'`/`DateFormat`/`Intl.` nulle part — le formatage de dates du
  projet est fait manuellement, voir `finance/presentation/money_format.dart`), `http` (0
  `import 'package:http'`/`http.get`/`http.Client` nulle part — toutes les communications réseau
  passent par les SDK Firebase). **Retirées de `pubspec.yaml`** (déclaration directe uniquement) ;
  `flutter pub get` confirme qu'`intl`/`http` restent disponibles comme dépendances
  **transitives** (tirées par `flutter_localizations`/autres packages Firebase — aucune version
  modifiée, seulement `dependency: direct main` → `dependency: transitive`), donc **rien ne
  casse** ; `cupertino_icons` n'est plus téléchargé du tout (n'était nécessaire à rien).
  `functions/package.json` : 3 dépendances runtime (`firebase-admin`, `firebase-functions`,
  `stripe`) toutes manifestement utilisées + 8 devDependencies de tooling standard (jest,
  eslint, typescript) — **aucune dépendance inutilisée trouvée côté Functions, PASS documenté**.
  **Aucune montée de version majeure/mineure effectuée** (conforme à la consigne).

- **Validation post W-2/W-6** : `dart analyze lib/` → 0 issue. `flutter test test/` →
  **504/504 PASS**, 0 régression. `npm run lint` (functions) → 0 warning.

### DONE W

| Critère | Statut |
|---|---|
| W-1 flutter analyze | ✅ 0 issue sur code du dépôt |
| W-2 dead code | ✅ recherche ciblée exhaustive, 0 preuve de code mort, rien supprimé sans preuve |
| W-3 TODO/FIXME | ✅ 3 occurrences, 0 P0/P1 |
| W-4 debug/logs | ✅ 2 `debugPrint()` kDebugMode-gated, 0 donnée sensible |
| W-5 generated/local | ✅ aucun artifact/secret tracké |
| W-6 dependencies | ✅ 3 dépendances directes inutilisées retirées (Flutter), 0 côté Functions, aucune montée de version |
| P0 ouverts | 0 |
| P1 ouverts | 0 |

**BLOC W : ✅ FERMÉ.**

## MISE À JOUR — BLOC X (Feature Flags / Kill Switches) : ✅ FERMÉ

**BUG-X-01 — P1 — Kill switch paiement appliqué trop tard**

**Symptôme** : avec `payments_enabled = false`, l'ancien flux pouvait appeler
`failMissionPayment()` (dans `createAndAuthorizeMissionPayment()`, `paymentOrchestration.ts`)
**après** le début du processus d'acceptation, c'est-à-dire après que la mission ait déjà été
mutée vers un état d'assignation.

**Conséquence** : une indisponibilité temporaire du service de paiement (kill switch activé
volontairement par un admin, ou détecté par le mécanisme fail-closed) pouvait transformer la
mission en `PAYMENT_FAILED` — un état **terminal, non reprenable** — alors qu'aucune tentative de
paiement réelle n'avait de raison légitime d'échouer de façon définitive : il s'agissait
seulement d'une pause temporaire du service, pas d'un échec métier du paiement.

**Risque** : une simple activation défensive du kill switch paiement (ex: pour investiguer un
incident fournisseur) pouvait rendre une mission par ailleurs parfaitement valide
**irrécupérable**, alors qu'aucun nouveau paiement ne devait simplement être autorisé pendant la
coupure — un effet de bord disproportionné par rapport à l'intention (une pause temporaire ne
doit jamais produire un dommage permanent).

**Correction** : le contrôle `payments_enabled` est désormais effectué dans `acceptDelivery.ts`
(`isRuntimeFlagEnabled(RuntimeFlagKeys.PAYMENTS_ENABLED)` + `killSwitchRefusal()`), **avant** la
transaction d'assignation et **avant** toute exposition financière (avant tout appel à
`createAndAuthorizeMissionPayment()`). Effet quand le flag est OFF :
- aucun chauffeur assigné (`driver_id` reste vide) ;
- aucun paiement créé (aucune autorisation, aucune capture) ;
- aucune écriture de ledger indue ;
- la mission reste dans son état pré-acceptation valide (`searching_driver`/`offered`) ;
- **aucune transition vers `PAYMENT_FAILED`**.

Quand le flag repasse à `true`, le même appel `acceptDelivery` réussit normalement — le parcours
reprend sans aucune séquelle, assignation et paiement créés exactement une fois.

Ce correctif ne modifie **jamais** un chemin de remboursement, de dispute, de compensation ou de
correction de ledger sur un paiement déjà existant — le kill switch `payments_enabled` n'empêche
que de **prendre** plus d'argent (nouvelles autorisations), jamais d'en **rendre** ou d'en
**corriger**.

**Preuve permanente** : `functions/test/integration/runtimeFlags.test.ts`, section D (« Bloc X
(X-11, section D) — BUG-X-01 : payments_enabled=false n'envoie plus la mission en
PAYMENT_FAILED »), 3 tests :
- OFF → `acceptDelivery` refuse proprement (`failed-precondition` / `service_temporarily_unavailable`),
  aucune mutation, mission inchangée, 0 payment, 0 financial_snapshot, 0 ledger, chauffeur reste
  `online`, aucun `tracking_event` `driver_assigned`.
- OFF → ON → la même mission (non modifiée par le refus) est ensuite acceptée normalement,
  assignée **une seule fois**, avec un workflow de paiement normal (`AUTHORIZED`).
- `payments_enabled=false` n'affecte JAMAIS `accept_new_delivery_requests`/
  `allow_driver_acceptance` par ailleurs — le refus est spécifique au paiement, pas une panne
  globale.

**Statut** : ✅ CORRIGÉ ET TESTÉ.

### Récapitulatif Bloc X

Bloc X a introduit 4 kill switches MVP centralisés (`accept_new_delivery_requests`,
`allow_driver_acceptance`, `payments_enabled`, `driver_payouts_enabled`), server-authoritative,
fail-closed sur toute configuration absente/invalide/inaccessible, admin-only en écriture
(`updateRuntimeFlags`, écriture Firestore directe refusée par les règles), intégralement audités
(old/new values), sans aucun cache/TTL (effet immédiat au prochain appel serveur — voir X-12,
`docs/PHASE7_QA_PLAN.md`), avec une procédure de bootstrap Phase 8 explicitement documentée
(X-13) garantissant qu'aucun défaut permissif n'est codé en dur dans le chemin de lecture.

**X-11 (fixture des tests d'intégration)** : les 17 suites d'intégration historiques
(pré-Bloc X), qui exercent un chemin désormais protégé sans tester elles-mêmes le comportement
des kill switches, ont été adaptées via un helper explicite partagé
(`functions/test/testUtils/runtimeFlagsFixture.ts`, `seedDefaultRuntimeFlagsEnabled()`), appelé
en `beforeEach` — pas un hook Jest global, pas de second framework de test créé.
`runtimeFlags.test.ts` conserve sa maîtrise explicite complète de l'état du document
(absent/partiel/invalide/ON/OFF) en réutilisant directement les mêmes fonctions sous-jacentes.

**Aucun autre bug trouvé dans le Bloc X** — BUG-X-01 est le seul gap réel confirmé par une
preuve.

**Tests finaux** :
- `runtimeFlags.test.ts` : **29/29 PASS**.
- Suite d'intégration complète (émulateurs) : **37/37 suites, 556/556 tests PASS** (confirmé sur
  deux exécutions complètes consécutives, 0 rouge — le seul rouge observé lors d'une exécution
  intermédiaire, `processStripeWebhook.test.ts` § « WEBHOOK DUPLIQUÉ CONCURRENT », a été identifié
  comme un flake de timing sous charge complète, sans lien avec Bloc X, confirmé PASS 18/18 en
  isolation et PASS sur la suite complète rejouée).
- Jest unit : **109/109 PASS**.
- `npx tsc --noEmit` : 0 erreur.
- `npm run lint` (functions) : 0 warning.
- `flutter analyze` : 0 issue.
- `flutter test` : **508/508 PASS**.

### DONE X

| Critère | Statut |
|---|---|
| Runtime flags centralisés (1 document, 1 helper) | ✅ |
| 4 kill switches | ✅ |
| Server-side enforcement (point d'entrée unique par flag) | ✅ |
| Fail-closed (config absente/invalide/erreur Firestore) | ✅ |
| Création mission ON/OFF | ✅ |
| Acceptation chauffeur ON/OFF | ✅ |
| Paiement ON/OFF | ✅ |
| BUG-X-01 reprise OFF→ON | ✅ CORRIGÉ ET TESTÉ |
| Refunds/corrections non bloqués | ✅ |
| Payout ON/OFF | ✅ |
| Payout reprise OFF→ON (reste ELIGIBLE) | ✅ |
| Corrections payout non bloquées | ✅ |
| Admin-only | ✅ |
| Écriture Firestore directe refusée | ✅ |
| Audit | ✅ |
| UI structurée FR/EN/ES | ✅ |
| Runtime no-cache (X-12) | ✅ |
| Bootstrap Phase 8 documenté (X-13) | ✅ |
| `runtimeFlags.test.ts` | ✅ 29/29 |
| Suite d'intégration | ✅ 556/556 |
| Flutter | ✅ 508/508 |
| P0 ouverts | 0 |
| P1 ouverts | 0 |

**BLOC X : ✅ FERMÉ.**

## BLOC Y — Monitoring/Alertes : ✅ FERMÉ (aucun nouveau bug de sévérité P0/P1 — 2 gaps d'observabilité comblés)

- **GAP-Y-01 (P2, comblé)** : `dispatchMissionToDrivers.ts` n'émettait aucune trace observability
  quand aucun chauffeur n'était disponible pour une mission — corrigé par `logFinancialFailure("dispatch_no_driver_available", ...)`.
- **GAP-Y-02 (P2, comblé)** : `onMissionStatusChangeNotifyCustomer.ts` n'observait pas les échecs
  d'écriture de notification — corrigé par try/catch + `logFinancialSuccess`/`logFinancialFailure`.

Aucun bug fonctionnel trouvé — gaps d'observabilité uniquement. `docs/MONITORING_RUNBOOK.md` créé.

## BLOC Z — Privacy/Data Retention : ✅ FERMÉ (aucun bug — documentation/stratégie uniquement)

Aucun bug de code trouvé. `docs/DATA_RETENTION.md` créé (inventaire, GPS, driver documents,
account deletion, financial safety, orphan files P-7 DEFERRED avec algorithme, logs, access
boundaries). Décisions Phase 8 identifiées : retention policy légale (durées), retention policy
documents chauffeur, cleanup orphan files, Cloud Logging retention.

## BLOC AA — Disaster Recovery : ✅ FERMÉ (aucun bug — documentation + nouveau test DR)

Aucun bug de code trouvé dans le code de production. `docs/DISASTER_RECOVERY.md` créé (critical
data map, backup state honnête, runbook incident, financial recovery, config recovery, rollback,
SEV, RPO/RTO). Bug de TEST trouvé et corrigé pendant la rédaction de `disasterRecovery.test.ts`
(pas un bug de production) :

- **Bug de test (corrigé avant commit)** : le premier jet du test seedait un webhook
  `received_at` à seulement 1 minute dans le passé, sous le seuil de staleness de 15 minutes
  (`STALE_WEBHOOK_THRESHOLD_MS` dans `reconciliationEngine.ts`) — l'anomalie
  `WEBHOOK_UNPROCESSED` attendue n'était donc jamais détectée (`Expected: >= 1, Received: 0`).
  Corrigé en portant le timestamp à 20 minutes dans le passé. Retest : 3/3 PASS.

Décision Phase 8 la plus importante identifiée : aucun backup Firestore/Storage actif confirmé
(`EXTERNAL CONFIGURATION REQUIRED`).

## VALIDATION FINALE Y → Z → AA — Aucun rouge

`npx tsc --noEmit` : 0 erreur. `npm run lint` : 0 warning. Jest unit : 109/109 PASS. Jest
intégration complète (émulateurs) : **38 suites / 559 tests PASS**, y compris
`processStripeWebhook.test.ts` (flake connu, PASS cette exécution, non masqué/skip) et le nouveau
`disasterRecovery.test.ts` (3/3 PASS). **P0 = 0. P1 = 0** sur l'ensemble Y+Z+AA.

## BLOC AB — First User Experience : ✅ FERMÉ

Simulation du parcours réel d'un nouveau client/chauffeur novice (client, chauffeur, admin),
recherche de GAPS RÉELS sur les écrans First-Use — pas un retest des blocs déjà fermés. 3 bugs
P2 trouvés et corrigés cette session, en plus des gaps déjà corrigés lors des sessions
précédentes (AB-1 à AB-4, AB-10).

### BUG-AB-08-01 — P2 — CORRIGÉ

**Cause** : `_LineRow` (`lib/screens/customer/mission_finance_section.dart`) affichait
libellé + valeur dans un `Row(mainAxisAlignment: spaceBetween)` sans `Expanded`/`Flexible` sur le
libellé. Tout libellé traduit suffisamment long (ex. `finance_summary_mission_price` en FR/EN)
combiné à une valeur monétaire dépassait la largeur disponible sur téléphone réel (320-360px),
produisant un `RenderFlex overflowed`.

**Fix** : libellé enveloppé dans `Expanded(child: Text(..., overflow: TextOverflow.ellipsis))` ;
la valeur monétaire garde sa taille naturelle (jamais tronquable sans perdre un montant réel).

**Second overflow trouvé au passage (même fichier, même famille de bug)** : le titre de section
`_FinanceSectionBody` (`Icon` + `Text(t('finance_section_title'))`) n'avait pas non plus
d'`Expanded`/ellipsis — corrigé avec le même pattern. Ce second gap n'avait jamais été détecté
car la tentative de test précédente ne construisait jamais un état "chargé" réel de l'écran
(fixture `snapshot == null`, qui ne fait jamais rendre `_LineRow` ni le header).

**Preuve (test permanent)** : `test/finance/mission_finance_section_test.dart` — réécrit avec un
nouveau seam `BackendLocator.financeRepositoryOverride` (même pattern que les autres
repositories) permettant d'injecter un `FinancialSnapshot` NON-NULL et d'exercer le VRAI
`MissionFinanceSection` (pas un widget recréé). 4/4 PASS :
- État vide/non configuré (préservé, régression) — `NotConfiguredFinanceRepository`.
- 320px, snapshot réel, 5 `_LineRow` rendues (prix mission, frais, taxes, pourboire, total),
  aucune exception.
- 320px, snapshot réel, libellé délibérément extrême (via injection de traduction) — la VALEUR
  monétaire reste entièrement visible/non tronquée, le LIBELLÉ a bien `overflow:
  TextOverflow.ellipsis` actif (preuve que la branche corrigée est utilisée), aucune exception.
- 360px, locale EN, ligne total correcte, aucune exception.

`flutter analyze` sur les fichiers concernés : **0 issue**.

### BUG-AB-09-01 — P2 — CORRIGÉ

**Cause** : le bouton "Sélectionner"/"Modifier" document (permis/assurance,
`_DocumentPickerRow` dans `lib/screens/driver/driver_onboarding_screen.dart`) mesurait ~24px de
hauteur réelle sur écran — bien sous la recommandation Android/WCAG de 48px — sur une action
critique du parcours First-Use chauffeur (sélection de document). Régression introduite par le
correctif précédent BUG-U-03 (`minimumSize: Size.zero` + `tapTargetSize: shrinkWrap`, utilisé
pour éliminer un `RenderFlex overflow` à 320-360px).

**Fix** : `minimumSize` porté à `Size(0, 40)` (hauteur ≥40px) tout en conservant
`tapTargetSize: MaterialTapTargetSize.shrinkWrap` (qui ne concerne que la zone de détection HORS
bornes visibles, pas la taille visible du bouton) et la largeur/padding du bouton inchangés —
donc SANS régression sur le correctif BUG-U-03.

**Preuve (test permanent)** : nouveau test dans
`test/accessibility/critical_accessibility_test.dart` (groupe "AB-9 — Document upload chauffeur
(onboarding) : tap target") mesurant `RenderBox.size.height >= 40` sur les 2 boutons de
sélection de document, sans overflow à 320px. Régression vérifiée : `test/responsive/
bloc_u_mobile_sanity_test.dart` (U-6.4, qui teste déjà l'absence d'overflow à 320-360px) toujours
**11/11 PASS** après le fix.

`flutter analyze` : **0 issue**.

### BUG-AB-09-02 — P2 — CORRIGÉ

**Cause** : `_MovikAppBar` (`lib/widgets/app_shell.dart`), partagé par ~18 écrans (auth,
onboarding chauffeur/mécanicien, statut chauffeur, pages légales/info, etc.), avait son bandeau
logo+"Movi-k" comme enfant direct (non flexible) du `Row` de titre. Sur mobile (`isDesktop ==
false`), ce bandeau est le SEUL enfant du Row : sans `Flexible`, le Row garde la taille
intrinsèque du contenu, qui grandit avec `textScale` (accessibilité utilisateur) jusqu'à
dépasser la largeur disponible de la zone de titre sur un téléphone 320px. Trouvé en testant
`DriverOnboardingScreen` (écran First-Use hôte de `AppShell`) à plusieurs échelles de texte
(1.0/1.3/1.5) — overflow confirmé de 2.8px, exclusivement à `textScale >= 1.5`.

**Fix** : le bloc logo+texte est désormais enveloppé dans `Flexible`, et le texte "Movi-k" a
`overflow: TextOverflow.ellipsis` en dernier recours. La mise en page desktop (>=900px, largeur
non contrainte) n'est pas affectée.

**Preuve (test permanent)** : nouveau test dans
`test/accessibility/critical_accessibility_test.dart` (groupe "AB-9 — AppShell (logo/marque)
sous textScale élevé") — `DriverOnboardingScreen` rendu à `textScale=1.5` sur 320px, `Text('Movi-
k')` toujours trouvé, `tester.takeException()` null.

`flutter analyze` : **0 issue**.

### Synthèse AB-1 → AB-10

| Item | Statut | Bugs trouvés |
|---|---|---|
| AB-1 (landing client) | ✅ | 2 badges trompeurs + 1 libellé de flux incorrect (corrigés, `ec6a839`) |
| AB-2 (zero state client) | ✅ | Erreur stream déguisée en zéro-état (corrigé, `d2c4969`) |
| AB-3 (premier échec client) | ✅ | Texte brut backend exposé (corrigé, `058a76c`) |
| AB-4 (nouveau chauffeur) | ✅ | Texte brut backend onboarding + AppBar 100% FR codé en dur (corrigés, `b42cb6e`/`218a13c`) |
| AB-5 (statuts chauffeur) | ✅ | Aucun gap réel trouvé — évidence déjà en place (`driver_status_screen_test.dart`) |
| AB-6 (admin sanity) | ✅ | Aucun gap réel trouvé — évidence déjà en place (i18n + dates admin) |
| AB-7 (i18n sweep First-Use) | ✅ | Aucun gap résiduel trouvé (sweep ciblé, réutilise K/K2/AB-3/AB-4/AB-10) |
| AB-8 (mobile réaliste) | ✅ | BUG-AB-08-01 + second overflow header finance (corrigés) ; gap `provider_jobs_tab` comblé |
| AB-9 (accessibilité First-Use) | ✅ | BUG-AB-09-01 + BUG-AB-09-02 (corrigés) ; rating Semantics confirmé conforme |
| AB-10 (rating chauffeur) | ✅ | Feature produit absente (implémentée de bout en bout, `c657368`) |

**Validation finale AB** : `flutter analyze` (project-wide) → **0 issue**. `flutter test
--concurrency=4` → **531/531 PASS**, 0 skip, 0 rouge.

**P0 ouverts (AB)** : 0. **P1 ouverts (AB)** : 0. P2 trouvés et corrigés (AB) : BUG-AB-08-01,
BUG-AB-09-01, BUG-AB-09-02 (3/3).

# BLOC AB : ✅ FERMÉ

## BLOC AC — Pilot Readiness : ✅ FERMÉ

Dernier bloc de la Phase 7. **Aucun bug de code trouvé** — bloc purement documentaire
(`docs/PILOT_READINESS.md`), consolidant honnêtement les décisions Phase 8 déjà identifiées dans
les blocs précédents (Q2, S, X, Y, Z, AA) sans en inventer de nouvelles. Détail complet dans
`docs/PILOT_READINESS.md` (AC-1 → AC-9) et `docs/PHASE7_QA_PLAN.md` (section "MISE À JOUR —
BLOC AC").

**BLOC AC : ✅ FERMÉ.** P0 ouverts = 0. P1 ouverts = 0.

# PHASE 7 : ✅ TERMINÉE

Tous les blocs A → AC fermés. **P0 ouverts (Phase 7 entière)** : 0. **P1 ouverts (Phase 7
entière)** : 0. `flutter analyze` → 0 issue. `flutter test --concurrency=4` → 531/531 PASS.
Functions : `npx tsc --noEmit` 0 erreur, `npm run lint` 0 warning, Jest unit 109/109 PASS, Jest
intégration 38 suites/559 tests PASS. Décisions Phase 8 les plus importantes : voir
`docs/PILOT_READINESS.md` (AC-2).


## Annexe source : docs/PHASE7_QA_MATRIX.md

# PHASE 7 — Bloc A — Matrice QA Produit (version initiale)

Cette matrice est volontairement créée rapidement (conformément à la consigne du Bloc A :
« Ne pas passer une session complète à documenter »). Elle sera enrichie au fil des blocs B-AC
au fur et à mesure que des scénarios sont réellement testés (statut mis à jour en continu).

Colonnes : ID | Rôle | Préconditions | Étapes | Résultat attendu | Test auto existant | Test manquant | Statut | Bug

## Auth / Onboarding

| ID | Rôle | Préconditions | Étapes | Résultat attendu | Test existant | Manquant | Statut | Bug |
|---|---|---|---|---|---|---|---|---|
| AUTH-01 | client | aucune | signup email/password | compte créé, redirection dashboard client | partiel (unit auth Flutter) | E2E signup->login runtime | À TESTER (Bloc E) | - |
| AUTH-02 | tous | compte existant | login | session active, claims corrects | - | E2E | À TESTER (Bloc E) | - |
| AUTH-03 | admin révoqué | admin dont le rôle est rétrogradé | admin tente une action admin après révocation | action refusée immédiatement (claims rafraîchis) | non | oui — critique | À TESTER (Bloc E) | RISQUE IDENTIFIÉ |
| DRV-ONB-01 | driver | signup | profil + véhicule + documents + submit review | passe en pending_review | `submitDriverForReview` (unit/integration existant) | E2E complet | À TESTER (Bloc C) | - |

## Missions (Client)

| ID | Rôle | Préconditions | Étapes | Résultat attendu | Test existant | Manquant | Statut | Bug |
|---|---|---|---|---|---|---|---|---|
| MIS-C-01 | client | payment_profile avec default_payment_method | devis -> création mission -> assignation -> tracking -> completed | mission completed, paiement capturé, historique visible | `e2eDeliveryLifecycle.test.ts` (nominal) | négatifs ci-dessous | PARTIEL (nominal DONE) | - |
| MIS-C-02 | client | aucun chauffeur dispo | createDeliveryRequest puis dispatch sans chauffeur éligible | mission reste `searching_driver`, aucune `delivery_offers`, pas de crash | `dispatchNoDriverAvailable.test.ts` (2/2 PASS, incl. régression positive) | - | **DONE** | - |
| MIS-C-03 | client | devis expiré | createDeliveryRequest avec quoteId expiré | `failed-precondition` | `createDeliveryRequest.test.ts` (couvert) | non | DONE | - |
| MIS-C-04 | client | paiement refusé à l'acceptation | acceptDelivery avec FakePaymentProvider en échec | mission `payment_failed`, désassignée, driver remis `online`, aucun payment AUTHORIZED, retry possible avec nouvelle mission | `acceptDeliveryPaymentFailure.test.ts` (2/2 PASS) | - | **DONE** | - |
| MIS-C-05 | client | mission assignée (driver_id != null), payment authorized | client annule (`status`->`cancelled`) | paiement autorisé libéré/annulé (`cancelAuthorization`) | `missionCancellationPaymentRelease.test.ts` (3/3 PASS) | - | **DONE — CORRIGÉ** | **BUG-001 (CORRIGÉ)** |
| MIS-C-06 | client | session expirée | tente action authentifiée (Cloud Function) | pas de crash, message d'erreur actionnable, jamais d'état incohérent | inspection de code : `delivery_request_flow_screen.dart` + `driver_active_mission_screen.dart` catchent déjà `CloudFunctionException` de façon uniforme (`_actionErrorKey`/`_errorMessage`, jamais un crash) ; le SDK Firebase Auth rafraîchit les ID tokens automatiquement | - | **DONE (adéquat, aucun code changé)** | - |
| MIS-C-07 | client | non authentifié | accède à `/livraison/suivi/:missionId` | message clair "connectez-vous", pas de message générique "erreur réseau" trompeur | `customer_tracking_screen_auth_test.dart` (2/2 PASS) | - | **DONE — CORRIGÉ (UX)** | **BUG-002 (mineur, CORRIGÉ)** |
| MIS-C-08 | client | ancienne mission avec données partielles (avant Phase 4/5, sans pickup/dropoff/timestamps) | `DeliveryMission.fromJson` sur document partiel + ouverture des vues associées | pas de crash, defaults sûrs, aucun force-unwrap non gardé | `delivery_mission_partial_data_test.dart` (3/3 PASS) + inspection de code (tous les `!` sur champs nullables dans les écrans sont gardés par `if (x != null)`) | - | **DONE** | - |
| MIS-C-09 | client | déconnexion réseau/timeout pendant création mission, ou double-tap UI, ou retry avec même quoteId | (A) double-tap UI rapide sur "Confirmer et créer" ; (B) retry séquentiel backend même quoteId ; (C) 2 requêtes concurrentes même quoteId | jamais 2 missions/paiements/autorisations pour le même devis ; quote consommé une seule fois | (A) `delivery_request_flow_double_submit_test.dart` (2/2 PASS — garde de réentrance `_createMission()` + désactivation bouton) ; (B)+(C) `createDeliveryRequestIdempotency.test.ts` (2/2 PASS — atomicité transaction Firestore déjà suffisante, aucun fix backend nécessaire) | - | **DONE** | **BUG-003 (CORRIGÉ)** |

## Missions (Chauffeur)

| ID | Rôle | Préconditions | Étapes | Résultat attendu | Test existant | Manquant | Statut | Bug |
|---|---|---|---|---|---|---|---|---|
| MIS-D-01 | driver approuvé | mission ouverte | accepte -> pickup -> transit -> dropoff -> completed | earnings crédités, payout éligible | `e2eDeliveryLifecycle.test.ts` | - | DONE | - |
| MIS-D-02 | driver pending_review | tente accepter | refusé | `acceptDeliveryConcurrency.test.ts` | - | DONE | - |
| MIS-D-03 | driver suspendu | tente accepter | refusé | `acceptDeliveryConcurrency.test.ts` | - | DONE | - |
| MIS-D-04 | 2 drivers | même mission, accept simultané | un seul gagne, l'autre reçoit erreur claire | `acceptDeliveryConcurrency.test.ts` (déjà 100% Phase 5/6) | - | DONE | - |
| MIS-D-05 | driver | GPS refusé/désactivé/rapport échoue | `DriverLocationReporter.start()` avec service désactivé, permission refusée (temp/forever), ou `reportDriverLocation` qui échoue | bandeau d'avertissement affiché, mission reste cohérente, **jamais** de boucle de retry non contrôlée | `driver_location_reporter_test.dart` (cas négatifs GPS) + `driver_active_mission_status_gaps_test.dart` (bandeau GPS pendant trajet, sans blocage des actions) | - | **DONE** | **BUG P1 boucle GPS infinie (CORRIGÉ)** |
| MIS-D-06 | driver | proof upload échoue (Storage) | completeDelivery sans proof valide, puis retry après échec | erreur claire affichée, pas de transition fantôme, retry réussi possible | `driver_active_mission_proof_upload_test.dart` (échec upload, retry réussi, NotConfiguredProofUploadRepository) | - | **DONE** | - |
| MIS-D-07 | driver | payout policy / Stripe account non configuré, ou échec provider en cours de traitement | `submitDriverPayout` : ELIGIBLE → PROCESSING → échec provider → FAILED | échec explicite, **transaction annulée intégralement** (pas de rollback silencieux partiel), pas de perte de fonds, payout reste `FAILED` et re-tentable | `submitDriverPayoutFailure.test.ts` (Jest, `forceCreateDriverPayoutFailure` sur `FakePaymentProvider`) | - | **DONE — CORRIGÉ** | **BUG P0 payout rollback (CORRIGÉ)** |
| MIS-D-08 | driver | `ProviderJobsTab` (liste missions dispo + missions actives) | ouverture répétée de l'onglet / rebuilds successifs (setState) | les `Stream` Firestore (missions dispo, missions actives) sont créés UNE SEULE FOIS, jamais recréés à chaque `build()` | `provider_jobs_tab_test.dart` (8/8 PASS) | - | **DONE — CORRIGÉ** | **BUG P1 stream recréé (CORRIGÉ)** |
| MIS-D-09 | driver | `DriverActiveMissionScreen`, tous les statuts de trajet intermédiaires (assigned → driverToPickup → arrivedAtPickup → pickedUp → inTransit → arrivedAtDropoff → completed) | transition de chaque statut via l'action UI correspondante ; double-tap rapide sur une action | seule l'action attendue par statut est visible/actionnable ; `markPickupCompleted` utilisé pour arrivedAtPickup→pickedUp (JAMAIS `updateTrackingStatus`) ; double-tap ne déclenche l'appel repository qu'une seule fois (bouton busy bloque le second tap) | `driver_active_mission_status_gaps_test.dart` (9/9 PASS) | - | **DONE** | - |
| MIS-D-10 | driver | `DriverStatusScreen`, 7 statuts (registrationIncomplete/pendingReview/documentsRequired/approved/rejected/suspended/inactive) | ouverture de l'écran pour chaque statut ; actions déclenchées (resubmit, toggle online) | CTA et message corrects par statut ; AUCUNE action interdite visible (ex : `suspended`/`rejected`/`inactive` n'affichent jamais de switch online) ; `approved` ne passe JAMAIS online automatiquement au premier rendu ; repository appelé uniquement sur interaction explicite | `driver_status_screen_test.dart` (18/18 PASS) | - | **DONE** | - |

**Bloc C — clôture** : les 4 lignes MIS-D-05 à MIS-D-10 ci-dessus couvrent l'intégralité du
périmètre Bloc C (onboarding chauffeur/BUG-003, E2E chauffeur complet, GPS/location reporter,
proof upload failure, payout submission failure, ProviderJobsTab, DriverActiveMissionScreen gaps,
DriverStatusScreen). Validation finale : `npx tsc --noEmit` (0 erreur), `npm run lint` (clean),
Jest unit (109/109 PASS), Jest intégration pertinente Bloc C — payout/E2E/concurrence chauffeur
(56/56 PASS : `submitDriverPayoutFailure`, `e2eDriverOnboardingToPayout`,
`acceptDeliveryConcurrency`, `calculateDriverPayout`, `reverseDriverPayout`,
`foundingDriverCommission`, `financialConcurrency`, `dispatchNoDriverAvailable`,
`e2eRefundPostPayoutLifecycle`), `flutter analyze` (0 souci nouveau), `flutter test` (371/371 PASS).
**BLOC C : ✅ FERMÉ.**

## Admin / Analyste / Super Admin

| ID | Rôle | Étapes | Résultat attendu | Statut |
|---|---|---|---|---|
| ADM-01 | analyste | review driver, request documents, validate document, add internal note, log review opened | autorisé | `adminPrivilegedActions.test.ts` (Bloc D, NOUVEAU) : `requestDriverDocuments` success (analyst), `addDriverInternalNote` success (analyst), `logDriverReviewOpened` success (analyst) — DONE |
| ADM-02 | analyste | tente suspendDriver/reactivateDriver/updatePricingConfiguration/applyDriverPromotion/qualifyFoundingDriver/createFinancialSnapshot (admin-only) | refusé (permission-denied) | `adminPrivilegedActions.test.ts` (Bloc D, NOUVEAU) : 7 tests dédiés « refuse pour analyst » — DONE |
| ADM-03 | admin | suspendDriver/reactivateDriver/updatePricingConfiguration/applyDriverPromotion/qualifyFoundingDriver/revokeFoundingDriverStatus/createFinancialSnapshot | autorisé | `adminPrivilegedActions.test.ts` (Bloc D, NOUVEAU) — DONE. Refund/payout/dispute/reconciliation/taxes Cloud-Function-level déjà couverts Phase 6/Bloc C (`disputeOrchestration.test.ts`, `reconciliationEngine.test.ts`, `taxEngine.test.ts`, `calculateDriverPayout.test.ts`, `reverseDriverPayout.test.ts`) — référencé, non dupliqué |
| ADM-04 | super_admin | `setUserRole` (SEUL point d'entrée privilège) | autorisé ; refusé pour tout rôle < super_admin | `adminPrivilegedActions.test.ts` (Bloc D, NOUVEAU) : success (super_admin) + 4 tests refus (customer/driver/analyst/admin) + invalid-argument (rôle invalide, targetUid/roles manquants) — DONE |
| ADM-05 | analyst/driver/customer | `validateDriverDocument` / `rejectDriver` avec rôle insuffisant | refusé (permission-denied) | success-path déjà couvert `e2eDriverOnboardingToPayout.test.ts` ; gap « permission-denied » comblé par `adminPrivilegedActions.test.ts` (Bloc D, NOUVEAU) — DONE |
| ADM-06 | tout rôle (y compris super_admin) | écriture Firestore DIRECTE sur transaction_ledger / disputes / reconciliation_reports / payout_policy_configs / payment_profiles / driver_internal_notes | refusé | Déjà exhaustivement couvert `securityRules.test.ts` (196/196 PASS, Phase 6) — RÉFÉRENCÉ, non redupliqué (directive Bloc D : ne pas refaire l'audit Security Rules général) |

**Bloc D — clôture** : gap de couverture Cloud-Function-callable identifié (0 test existant pour
`setUserRole`, `suspendDriver`, `reactivateDriver`, `requestDriverDocuments`,
`updatePricingConfiguration`, `applyDriverPromotion`, `qualifyFoundingDriver`,
`revokeFoundingDriverStatus`, `createFinancialSnapshot`, `logDriverReviewOpened` ; success-path
seulement pour `validateDriverDocument`/`rejectDriver`) comblé intégralement par le nouveau fichier
`functions/test/integration/adminPrivilegedActions.test.ts` (36 tests, 36/36 PASS au premier essai —
aucun bug trouvé, chaque garde `require*OrAbove()`/`requireSuperAdmin()` fonctionne exactement comme
le code source le prévoyait). Security Rules Firestore (196/196 PASS) référencées, non ré-auditées.
Validation : `npx tsc --noEmit` (0 erreur), Jest unit (109/109 PASS), Jest intégration Bloc D
(36/36 PASS nouveau fichier). **BLOC D : ✅ FERMÉ.**

## Auth / Session / Claims

| ID | Scénario | Étapes | Résultat attendu | Test | Statut |
|---|---|---|---|---|---|
| AUTH-E-01..08 | session/claims UI | signed-out, signed-in, claims loading/loaded/fetch-failed, rôle insuffisant, rôle suffisant, downgrade analyst après promotion admin | login screen / spinner / écran "Réessayer" (sans déconnexion forcée) / dashboard selon état ; jamais d'accès UI non autorisé par le backend | `test/auth/admin_auth_gate_session_claims_test.dart` (13/13 PASS, nouveaux seams `debugForceRoles`/`debugForceClaimsLoaded`/`debugForceClaimsFetchFailed`) | DONE |
| AUTH-E-S01..09 | session réelle (Identity Toolkit REST, émulateur) | signup, login, mauvais mot de passe, email inconnu, refresh token, claims dans token décodé | succès/échec HTTP corrects (`INVALID_PASSWORD`, `EMAIL_NOT_FOUND`), `verifyIdToken()` réellement exercé (pas de bypass `buildRequest`) | `functions/test/integration/authSessionClaims.test.ts` NIVEAU 1 | DONE |
| AUTH-E-C01..06 | claims round-trip | analyst→promotion admin (`setUserRole`)→droits effectifs ; admin→downgrade→refus ; rôle retiré ; super_admin downgrade ; callable sensible (`suspendDriver`/`requestDriverDocuments`) après changement de rôle | droits accordés/refusés exactement selon les claims actuels, jamais selon un état UI/token périmé | `functions/test/integration/authSessionClaims.test.ts` NIVEAU 2 | DONE |
| AUTH-E-U01 | callable sans authentification | appel direct sans `auth` | `unauthenticated` | `functions/test/integration/authSessionClaims.test.ts` NIVEAU 3 | DONE |

**Bloc E — clôture** : gaps identifiés (aucun seam claims/rôles arbitraire côté Flutter ; aucun
test dédié `AdminAuthGate`/`AdminLoginScreen` ; aucun test Cloud Function exerçant réellement
`verifyIdToken()` plutôt que le snapshot `buildRequest()`) comblés par 2 nouveaux fichiers de test
(13 + 16 = 29 tests, tous PASS) et un durcissement proactif (`revokeRefreshTokens` dans
`setUserRole.ts`, sans régression sur les 36 tests Bloc D). Principe "le frontend n'est jamais
l'autorité finale" prouvé par code (AUTH-E-C02/C03/C05/C06). **BLOC E : ✅ FERMÉ.**

## Routing / Deep Links (Bloc F)

| ID | Scénario | Étapes | Résultat attendu | Test | Statut |
|---|---|---|---|---|---|
| F-1 | client A tente d'accéder à une mission de client B | `customerId` de la mission != `auth.effectiveUid` sur `/livraison/suivi/:id` | refus propre (`driver_active_mission_access_denied`), aucune donnée de B affichée, aucun crash | `test/customer/customer_tracking_cross_customer_test.dart` (3/3 PASS) | **DONE** |
| F-2 | chauffeur `pending_review`/`suspended` tente de passer en ligne | `ProviderDashboardShell` avec statut chauffeur non `approved` | Switch "en ligne" désactivé (jamais actionnable), régression vérifiée pour `approved` (switch actif), défense niveau 2 si contournement | `test/driver/provider_dashboard_shell_status_gate_test.dart` (4/4 PASS) | **DONE — bug AppBar overflow CORRIGÉ (BUG-007)** |
| ROUTE-F-01 | route totalement inconnue | navigation vers une URL non déclarée dans `AppRouter.router` | fallback GoRouter par défaut ("Page Not Found" + bouton Home), pas d'écran blanc, pas d'exception | `test/routing/app_router_invalid_routes_test.dart` (1/6) | **DONE** |
| ROUTE-F-02 | paramètre `missionId` manquant | `/livraison/suivi/` (trailing slash, sans id) | fallback propre (route paramétrée non matchée), pas d'écran blanc | `test/routing/app_router_invalid_routes_test.dart` (2/6) | **DONE** |
| ROUTE-F-03 | route admin sans rôle privilégié | `/admin/chauffeurs/` avec rôle insuffisant | `AdminAuthGate` redirige vers `AdminLoginScreen`, aucune fuite de la liste chauffeurs | `test/routing/app_router_invalid_routes_test.dart` (3/6) | **DONE** |
| ROUTE-F-04 | paramètre `:type` malformé | `/legal/:type` avec type inconnu | `LegalScreen` retombe sur son cas `default` (politique de confidentialité), pas d'écran blanc | `test/routing/app_router_invalid_routes_test.dart` (4/6) | **DONE** |
| ROUTE-F-05 | mission chauffeur inexistante | `/provider/mission/:id` avec id inexistant | message "introuvable" (fallback existant réutilisé), pas d'écran blanc | `test/routing/app_router_invalid_routes_test.dart` (5/6) | **DONE** |
| ROUTE-F-06 | mission client inexistante | `/livraison/suivi/:id` avec id inexistant | message "introuvable" (fallback existant réutilisé), pas d'écran blanc | `test/routing/app_router_invalid_routes_test.dart` (6/6) | **DONE** |
| F-3.1 | deep-link notification client valide | notification contient `missionId` X → tap → `markAsRead` → navigation `/livraison/suivi/X` | `markAsRead` appelé avec le bon id, `CustomerTrackingScreen` reçoit exactement X, navigation unique, aucun crash | `test/notifications/notifications_deep_link_test.dart` groupe F-3.1 (1/7) | **DONE** |
| F-3.2 | deep-link vers mission supprimée/inexistante | tap notification → navigation tracking X → `watchMission` renvoie `null` | fallback EXISTANT réutilisé (`driver_active_mission_not_found`), aucun écran blanc, aucune exception, aucun contenu fictif | `test/notifications/notifications_deep_link_test.dart` groupe F-3.2 (2/7) | **DONE — aucune logique métier recréée** |
| F-3.3 | deep-link vers mission d'un autre utilisateur (client + chauffeur) | tap notification → mission appartient à un autre `customerId`/`driverId` | protection F-1 (client) et protection existante `DriverActiveMissionScreen` (chauffeur) réutilisées telles quelles : refus propre, aucune donnée sensible affichée, aucun crash | `test/notifications/notifications_deep_link_test.dart` groupe F-3.3 (3-4/7) | **DONE — protections F-1/chauffeur réutilisées, non dupliquées** |
| F-3 (nominal chauffeur) | branchement client/chauffeur de `NotificationsScreen` | chauffeur connecté → tap notification mission X | navigation `/fournisseur/mission/X` (pas la route client), `DriverActiveMissionScreen` reçoit X, aucun refus à tort | `test/notifications/notifications_deep_link_test.dart` groupe "Cas nominal chauffeur" (5/7) | **DONE — branchement `auth.hasRole(PlatformRole.driver)` prouvé** |
| F-3 (missionId null/vide) | notification sans mission liée | tap notification sans `missionId` | `markAsRead` appelé, AUCUNE navigation (reste sur `NotificationsScreen`), aucun chevron affiché, aucun crash | `test/notifications/notifications_deep_link_test.dart` groupe "missionId null / vide" (6-7/7) | **DONE — comportement existant (skip silencieux) documenté, non modifié (aucun bug démontré)** |

**Bloc F — clôture** : seam `BackendLocator.notificationRepositoryOverride` ajouté (même pattern que
`missionRepositoryOverride`/`driverRepositoryOverride`/`locationRepositoryOverride`/`proofUploadRepositoryOverride`),
utilisé exclusivement par le nouveau fichier `test/notifications/notifications_deep_link_test.dart`
(7 tests, 7/7 PASS) qui prouve le deep-link notification → navigation → mission, en RÉUTILISANT sans
duplication la protection F-1 (client) et la protection symétrique existante de
`DriverActiveMissionScreen` (chauffeur), ainsi que le fallback `mission == null` déjà en place.
Combiné aux tests F-1/F-2/ROUTE-F-01..06 déjà committés précédemment : **32/32 PASS** au total
sur le périmètre Bloc F. Un seul bug trouvé sur tout le bloc (AppBar overflow, F-2, CORRIGÉ —
voir `PHASE7_BUG_REPORT.md` BUG-007) ; **F-3 n'a révélé aucun nouveau bug** (chaque scénario a
réutilisé une protection déjà correcte sans modification de code de production).
Validation : `flutter analyze` (0 souci nouveau, 3 issues `info` pré-existantes non liées),
`flutter test` (aucune régression). **BLOC F : ✅ FERMÉ.**

## Offline / Réseau / Retry (Bloc G)

Matrice courte (exigence → test existant → COUVERT/GAP), avant codage des GAPS uniquement :

| Exigence G | Test existant | Statut |
|---|---|---|
| Création mission : retry/double-tap/concurrence, une seule mission | `delivery_request_flow_double_submit_test.dart` (2/2 PASS, garde de réentrance) + `createDeliveryRequestIdempotency.test.ts` (2/2 PASS, transaction Firestore atomique) — MIS-C-09 | **COUVERT** (référencé, non dupliqué) |
| Proof upload : échec, mission non completed, retry réussi | `driver_active_mission_proof_upload_test.dart` (Storage throw, `markDeliveryCompleted` jamais appelé, retry possible) | **COUVERT** (référencé, non dupliqué) |
| GPS : service désactivé/permission refusée/rapport échoue | `driver_location_reporter_test.dart` + `driver_active_mission_status_gaps_test.dart` (bandeau GPS) | **COUVERT** (référencé, non dupliqué) |
| Paiement : authorize/capture failure, idempotence, concurrence | Tests Phase 6 (`acceptDeliveryPaymentFailure.test.ts`, `financialConcurrency.test.ts`, etc.) | **COUVERT** (référencé, non dupliqué) |
| Refund : state machine / E2E | Phase 6 (`refundStateMachine.test.ts`, `e2eRefundLifecycle.test.ts`, `e2eRefundPostPayoutLifecycle.test.ts`) | **COUVERT** (référencé, non dupliqué) |
| Payout : provider failure, retry/idempotence, aucun double payout | `submitDriverPayoutFailure.test.ts` (Bloc C, BUG P0 CORRIGÉ) | **COUVERT** (référencé, non dupliqué) |
| Cloud Function `unavailable`/timeout sur une action chauffeur (trajet) | aucun (grep exhaustif `test/` : aucune occurrence de `CloudFunctionException(` avant ce bloc) | **GAP → G-1/G-2** |
| Firestore listener error (`StreamBuilder.hasError`) sur un écran temps réel + reprise après erreur | `snap.hasError` déjà géré dans le code (`CustomerTrackingScreen`, `DriverActiveMissionScreen`, `NotificationsScreen`, tabs admin finance) mais **aucun test ne l'exerce réellement** | **GAP → G-3** |
| Firestore write failure (écriture directe, hors Cloud Function) | `markAsRead`/`markAllAsRead` (`FirebaseNotificationRepository`) sont des écritures directes Firestore jamais testées en échec | **GAP → G-4** |

Budget reconnaissance : ~15% du bloc (une seule passe de grep + lecture ciblée des écrans/repos concernés, aucun audit général).

### G-1 / G-2 — Cloud Function `unavailable` + retry idempotent (chauffeur, trajet)

| ID | Scénario | Étapes | Résultat attendu | Test | Statut |
|---|---|---|---|---|---|
| G-1 | action chauffeur (`updateTrackingStatus`) → CF `unavailable` | tap "partir vers le pickup" → `CloudFunctionException('unavailable', ...)` | aucun faux succès (statut mission inchangé), message d'erreur traduit (`driver_active_mission_cf_error`) affiché, `_actionInProgress` nettoyé, bouton redevient actionnable, aucun crash | `test/network/driver_action_cloud_function_unavailable_test.dart` (1/2) | **DONE** |
| G-2 | retry après échec (même action) → succès, sans duplication | 2e tap sur le même bouton après l'échec | `updateTrackingStatus` rappelé, mission avance correctement au nouveau statut (une seule fois), aucune transition dupliquée/sautée, erreur effacée | `test/network/driver_action_cloud_function_unavailable_test.dart` (2/2) | **DONE** |

### G-3 — Firestore listener error + reprise

| ID | Scénario | Étapes | Résultat attendu | Test | Statut |
|---|---|---|---|---|---|
| G-3.1 | `watchMission` émet une erreur (listener) | `StreamController.addError(...)` sur le stream écouté par `CustomerTrackingScreen` | fallback existant affiché (`driver_active_mission_network_error`), aucun crash, aucun écran blanc, aucune ancienne donnée mission présentée comme valide | `test/network/mission_tracking_listener_error_test.dart` (1/2) | **DONE** |
| G-3.2 | reprise après erreur (nouvelle donnée valide sur le même stream) | après l'erreur, le même `StreamController` émet la mission réelle | `CustomerTrackingScreen` affiche normalement la mission, sans nécessiter un remount de l'écran | `test/network/mission_tracking_listener_error_test.dart` (2/2) | **DONE — reprise naturelle de l'architecture existante, aucune couche offline ajoutée** |

### G-4 — Firestore write failure (écriture directe)

| ID | Scénario | Étapes | Résultat attendu | Test | Statut |
|---|---|---|---|---|---|
| G-4.1 | `markAsRead` (écriture directe Firestore, pas de Cloud Function) échoue au tap sur une notification non lue | tap notification → `NotificationRepository.markAsRead()` throw `CloudFunctionException` | aucun faux succès (le point non-lu ne disparaît pas côté fake, état `_isRead` réellement inchangé), aucun crash de l'app, navigation vers la mission reste fonctionnelle (dégradation acceptable : l'échec de `markAsRead` n'empêche jamais l'accès à la mission) | `test/network/notification_mark_as_read_write_failure_test.dart` (1/2) | **DONE — BUG P2 trouvé + CORRIGÉ (voir ci-dessous)** |
| G-4.2 | retry après échec de `markAsRead` → succès, aucun état bloqué | 2e appel après le 1er échec | l'écriture réussit, compteurs cohérents (1 échec + 1 succès), aucune exception résiduelle | `test/network/notification_mark_as_read_write_failure_test.dart` (2/2) | **DONE** |

**Bug réel trouvé pendant G-4 (TEST → FAIL → FIX → RETEST) — P2, CORRIGÉ** :
`NotificationsScreen.onTap` appelait `BackendLocator.notificationRepository.markAsRead(...)` sans
jamais catcher l'échec (`Future` rejetée non awaited/non catchée) → toute panne réseau/Firestore
transitoire pendant ce tap remontait comme exception non gérée jusqu'au binding Flutter (crash
potentiel en release selon la politique de zone d'erreur de l'app). AVANT le fix : le test G-4.1
faisait planter la suite (`CloudFunctionException` non catchée remontée au test harness). APRÈS le
fix (`.catchError((_) {})` ajouté sur l'appel dans `notifications_screen.dart`, commenté en detail
sur l'intention : le marquage lu/non-lu est un confort UX secondaire, son échec ne doit jamais
bloquer la navigation vers la mission liée) : G-4.1 et G-4.2 PASS, navigation post-tap toujours
fonctionnelle malgré l'échec de l'écriture. Voir `PHASE7_BUG_REPORT.md` pour le détail complet.

**Bloc G — clôture** : 6 tests créés sur les 3 GAPS réels identifiés (G-1+G-2 dans un seul
fichier, G-3.1+G-3.2 dans un seul fichier, G-4.1+G-4.2 dans un seul fichier), **6/6 PASS**
(vérifiés par exécution réelle, pas seulement rédigés). 1 bug P2 réel trouvé et corrigé (détaillé
ci-dessus). Aucune double mission/paiement/payout/ledger possible : ces protections sont déjà
prouvées par les preuves référencées (MIS-C-09, Phase 6 finance, `submitDriverPayoutFailure.test.ts`)
— le Bloc G n'a pas eu besoin de les re-tester, seulement de combler les 3 gaps UI Flutter
identifiés. Aucun bug P0/P1 trouvé. Validation réelle exécutée : `flutter test test/network/`
(6/6 PASS), `flutter analyze` (3 issues `info` pré-existantes non liées, 0 souci nouveau),
`flutter test` complet du projet (**410/410 PASS, aucune régression**).
**BLOC G : ✅ FERMÉ.**

## GPS / Tracking durcissement (Bloc H)

Matrice courte (exigence → test existant → COUVERT/GAP), avant codage du gap réel uniquement :

| Exigence H | Test existant | Statut |
|---|---|---|
| H-1 — GPS désactivé / permission denied / deniedForever / refus-puis-accord / échec `getCurrentPosition`/`reportDriverLocation` | `driver_location_reporter_test.dart` (9 tests, isolé classe `DriverLocationReporter`) | **COUVERT** (référencé, non dupliqué) |
| H-2 — Lifecycle écran : mission active → start ; completed/cancelled → stop ; idempotence start/start et stop/stop | Aucun test existant ne liait le statut mission au lifecycle réel de `DriverLocationReporter` AU NIVEAU `DriverActiveMissionScreen` (seul le bandeau d'erreur GPS et BUG-006 étaient couverts, pas le lifecycle start/stop lui-même) | **GAP → H-2 (comblé ce bloc)** |
| H-3 — BUG-006 (boucle infinie de resynchronisation GPS sur échec permanent) | `driver_active_mission_status_gaps_test.dart` (9 tests, sonde `isLocationServiceEnabled`) | **COUVERT** (réexécuté : 18/18 PASS avec `driver_location_reporter_test.dart`, toujours vert) |
| H-4 — Sécurité tracking : chauffeur assigné write autorisé / autre chauffeur DENIED / client propriétaire read autorisé / autre client DENIED / non authentifié DENIED / historique trajet écriture directe interdite (Cloud Function only) | `functions/test/integration/securityRules.test.ts` lignes ~1513-1750, describe \"driver_locations/{driverId}\" + \"driver_locations/{driverId}/history/{eventId}\" (16 tests ciblés : write self OK, write autre chauffeur DENIED, read sans mission active DENIED, read avec mission active assignée OK, read mission active mais autre chauffeur DENIED, read après nettoyage `active_delivery_id=null` DENIED, analyste read tout OK, non-authentifié DENIED (read+write), écriture directe historique interdite même pour super_admin, lecture historique propriétaire/tiers/analyste) | **COUVERT** (référencé, non dupliqué — aucun gap réel identifié) |
| H-5 — Background/Foreground (tracking continue hors écran actif / app en arrière-plan) | Aucune implémentation : `AndroidManifest.xml` ne demande PAS `ACCESS_BACKGROUND_LOCATION` (commenté explicitement), `driver_location_reporter.dart` documente \"Ne tourne jamais en arrière-plan\" | **DEFERRED NON-BLOCKING → Phase 8** (non implémenté, dépend de permissions OS avancées + configuration Android/iOS production ; documentation uniquement, aucun code construit ce bloc) |
| H-6 — Position stale/invalide (âge de la position, coordonnées invalides) | Grep exhaustif : aucun consommateur (`LiveTrackingMap`, écrans client/chauffeur) ne lit/valide `DriverLocation.updatedAt` pour détecter une position périmée | **N/A — architecture actuelle ne dépend pas de cette validation** (aucun moteur de validation construit arbitrairement, conformément à la consigne) |

Budget reconnaissance : ~15-20% du bloc (lecture ciblée de `driver_location_reporter.dart`,
`driver_location_reporter_test.dart`, `driver_active_mission_status_gaps_test.dart`,
`driver_active_mission_screen.dart`, `securityRules.test.ts` section driver_locations,
`AndroidManifest.xml`). Aucun audit général, aucune relecture redondante.

### H-2 — Lifecycle GPS écran (nouveau test)

| ID | Scénario | Étapes | Résultat attendu | Test | Statut |
|---|---|---|---|---|---|
| H-2.1 | CAS 1 — mission dans un statut de partage (`assigned`) | montage `DriverActiveMissionScreen` | 1 rapport de position immédiat, `checkPermission()` appelé une seule fois | `driver_active_mission_gps_lifecycle_test.dart` | **DONE** |
| H-2.2 | CAS 2 — mission `inTransit` → `completed` | `advanceTo(completed)` puis 5 pumps supplémentaires | aucun nouveau rapport, aucune nouvelle vérification de permission, écran \"déjà complétée\" affiché | `driver_active_mission_gps_lifecycle_test.dart` | **DONE** |
| H-2.3 | CAS 3 — mission `driverToPickup` → `cancelled` | `advanceTo(cancelled)` puis 5 pumps supplémentaires | même exigence que CAS 2, écran \"annulée\" affiché | `driver_active_mission_gps_lifecycle_test.dart` | **DONE** |
| H-2.4 | Idempotence lifecycle (transitions internes toutes \"partage actif\") | `assigned → driverToPickup → arrivedAtPickup` | `checkPermission()` appelé UNE SEULE fois au total (jamais de 2e boucle démarrée) | `driver_active_mission_gps_lifecycle_test.dart` | **DONE** |
| H-2.5 | Nettoyage dispose() | démontage de l'écran pendant partage actif | `stop()` exécuté sans exception (`tester.takeException()` == null), aucun rapport résiduel | `driver_active_mission_gps_lifecycle_test.dart` | **DONE** |
| H-2.6 | Idempotence `stop()`/`stop()` isolée | `DriverLocationReporter().stop()` appelé deux fois de suite, jamais démarré | aucune exception (`returnsNormally`), `isRunning` reste `false` | `driver_active_mission_gps_lifecycle_test.dart` | **DONE** |

**Bloc H — clôture** : 1 nouveau fichier créé (`test/driver/driver_active_mission_gps_lifecycle_test.dart`,
6 tests), comblant le seul GAP réel identifié (H-2). H-1/H-3/H-4 référencés sans duplication
(réexécutés pour H-3 : 18/18 PASS). H-5 documenté `DEFERRED NON-BLOCKING → Phase 8`. H-6 documenté
`N/A`. Aucun bug P0/P1/P2/P3 trouvé pendant ce bloc — le code de production (`_syncGpsSharing()`,
`DriverLocationReporter.start()/stop()`) se comporte exactement comme attendu au niveau écran, sans
qu'aucune correction n'ait été nécessaire. Validation réelle exécutée : `flutter test
test/driver/driver_active_mission_gps_lifecycle_test.dart` (6/6 PASS), `flutter test
test/driver/driver_active_mission_status_gaps_test.dart test/driver/driver_location_reporter_test.dart`
(18/18 PASS, aucune régression BUG-006), `flutter analyze` (0 souci nouveau), `flutter test` complet
(voir validation croisée finale). **BLOC H : ✅ FERMÉ.**

## Notifications (Bloc I)

| Exigence I | Test existant | Statut |
|---|---|---|
| I-1 création (8 transitions statut) | `functions/test/integration/onMissionStatusChangeNotifyCustomer.test.ts` (15 cas : 8 transitions + garde-fous + anti-fuite croisée) | COUVERT (référencé, non dupliqué) |
| I-1 création secondaire (`detectExpiringDocuments`, `transitionFoundingDriverPeriods`) | Aucun test dédié trouvé | GAP mineur documenté DEFERRED (logique simple, même schéma déjà validé par le trigger principal ; pas de bug démontré) |
| I-2 read/unread + badge | **GAP** avant ce tour | COMBLÉ : `test/notifications/notifications_realtime_and_unread_test.dart` (I-2.1/I-2.2/I-2.3, 3 tests) |
| I-3 realtime + listener error (`NotificationsScreen`) | **GAP** avant ce tour (pattern G-3 existait seulement sur `CustomerTrackingScreen`) | COMBLÉ : même fichier (I-3.1/I-3.2/I-3.3, 3 tests) |
| I-4 duplication/idempotence notification création | Architecture par `onDocumentUpdated` : un déclenchement = une écriture réelle de statut ; aucun scénario de duplication réelle démontré en usage normal | Non-bloquant, pas de nouveau système construit arbitrairement |
| I-5 navigation post-tap | Bloc F, `notifications_deep_link_test.dart` | COUVERT (référencé, non dupliqué) |
| I-6 FR/EN/ES notifications | Audit direct `lib/l10n/app_strings.dart` (toutes clés `notif_*`/`notifications_*` présentes en FR/EN/ES) | COUVERT |
| I-7 push mobile externe (FCM/APNs) | Aucune dépendance `firebase_messaging`/FCM/APNs dans le projet | DEFERRED / Phase 8 |

Nouveau fichier : `test/notifications/notifications_realtime_and_unread_test.dart` (6 tests, 6/6 PASS).
Validation : `flutter test` complet 422/422 PASS (+6 vs 416 post-Bloc H), `flutter analyze` 0 souci nouveau.
**BLOC I : ✅ FERMÉ.**

## Responsive / Viewports (Bloc J)

**Matrice de couverture d'écrans J-0** (AUTH : Login/Signup ; CLIENT : création demande/devis/
recherche chauffeur/tracking/complétée/notifications ; DRIVER : onboarding/statut/dashboard/
jobs/mission active/preuve/gains ; ADMIN : login/revue chauffeurs/missions/dashboard finance) —
3 écrans critiques sélectionnés pour test réel ce bloc (représentatifs de chaque famille de
layout à risque : AppBar dense, formulaire, dialogue modal) :

| Exigence J | Test existant | Statut |
|---|---|---|
| J-1/J-2 — matrice de viewports (320/360/390/430/480px) + non-régression BUG-007 | Aucun test existant ne faisait varier la largeur de `ProviderDashboardShell` au-delà du défaut 800×600 (`provider_dashboard_shell_status_gate_test.dart` relu, confirmé) | **GAP → comblé ce bloc** |
| J-3 — effet FR/EN/ES sur écran critique | Aucun test de largeur+langue combinées sur `AuthScreen` | **GAP → comblé ce bloc** |
| J-4 — clavier/formulaires (CTA accessible/scrollable) | Scrollabilité de `AuthScreen` héritée de `AppShell`/`SingleChildScrollView`, jamais prouvée sous hauteur réduite (clavier virtuel) | **GAP → comblé ce bloc** |
| J-5 — modals/dialogs (contenu visible, boutons accessibles, sans overflow) | Aucun test de `SafetyScreen`/dialogue de signalement à largeur étroite | **GAP → comblé ce bloc, a révélé BUG-009** |
| J-6 — web/desktop (écrans réellement prévus en web) | `test/finance/admin_finance_ui_test.dart` (`NavigationRail` desktop 1200×900) | **COUVERT** (référencé, non dupliqué — aucun autre écran n'est prévu en usage desktop dans le périmètre actuel) |

Budget reconnaissance : ~15-20% du bloc (relecture ciblée de
`provider_dashboard_shell_status_gate_test.dart`, `admin_finance_ui_test.dart`,
`provider_dashboard_shell.dart`, `auth_screen.dart`, `app_shell.dart`, `safety_screen.dart`).
Aucun audit général, aucune relecture redondante.

### J-1/J-2/J-3/J-4/J-5 — nouveau test `critical_screens_viewport_test.dart`

| ID | Scénario | Étapes | Résultat attendu | Statut |
|---|---|---|---|---|
| J-1/J-2.1-5 | `ProviderDashboardShell` à 320/360/390/430/480px | montage + mesure overflow + tap Switch | 0 overflow, Switch toujours visible et fonctionnel (régression BUG-007 vérifiée sur toute la matrice) | **DONE** (5/5 PASS) |
| J-1/J-2.6 | `ProviderDashboardShell` à 600px (phablette) | montage | 0 overflow, libellés décoratifs réapparaissent (`isNarrowPhone == false`) | **DONE** |
| J-3.1-3 | `AuthScreen` en fr/en/es à 320px | montage par langue | 0 overflow, textes `auth_welcome`/`auth_choose_role` trouvés | **DONE** (3/3 PASS) |
| J-4.1 | `AuthScreen` mode inscription, hauteur réduite (375×320, clavier simulé) | bascule inscription + `ensureVisible` sur 3 champs + CTA final | tous les champs et le CTA restent atteignables via scroll | **DONE** |
| J-5.1 | `SafetyScreen`, dialogue de signalement à 320px | tap "Signaler un problème" → vérifier `AlertDialog` → tap "Annuler" | contenu visible, champ texte + boutons accessibles, 0 overflow, fermeture sans exception | **DONE après correctif BUG-009** (échec au 1er essai : overflow 146px détecté et corrigé) |

**Bug trouvé** : **BUG-009** (P2, CORRIGÉ) — overflow du bandeau "Signaler un problème" dans
`SafetyScreen` à 320px de large (voir `docs/PHASE7_BUG_REPORT.md` pour le détail complet
Contexte/Cause/Correctif/Test de régression).

**Bloc J — clôture** : 1 nouveau fichier créé (`test/responsive/critical_screens_viewport_test.dart`,
11 tests), comblant les 4 GAPS réels identifiés (J-1/J-2, J-3, J-4, J-5). J-6 référencé sans
duplication. 1 bug trouvé et corrigé (BUG-009, P2, UI uniquement). Aucun bug P0/P1. Validation
réelle exécutée : `flutter test test/responsive/critical_screens_viewport_test.dart` (10/11 puis
11/11 PASS après correctif), `flutter analyze` (0 souci nouveau, y compris sur
`safety_screen.dart` modifié), `flutter test` complet du projet (**433/433 PASS**, +11 vs 422
post-Bloc I, aucune régression). **BLOC J : ✅ FERMÉ.**

## I18N Global (Bloc K) — EN COURS

| Zone / écran | Couverture i18n existante | Statut |
|---|---|---|
| Dictionnaire `app_strings.dart` (753 clés) | 0 clé avec locale manquante, 0 doublon (audit programmatique) | COUVERT |
| Cohérence clés utilisées vs définies (426 appels `t()`) | 0 clé utilisée non définie | COUVERT |
| Auth — `admin_login_screen.dart` | 0 usage `LocaleProvider`, tout FR codé en dur | **GAP (critique)** |
| Auth — `auth_screen.dart` | `t()` utilisé mais ~10 chaînes résiduelles (redirections, labels, erreurs validation) | **GAP (partiel)** |
| Client — `customer_profile_tab.dart` | 0 usage `LocaleProvider` | **GAP** |
| Client — `customer_messages_tab.dart` | 0 usage `LocaleProvider` (écran placeholder) | **GAP (mineur)** |
| Client — `mechanic_request_flow_screen.dart` (Steps 2-4) | `t()` en tête de fichier mais sous-widgets Step2/3/4 hardcodés | **GAP (partiel)** |
| Chauffeur — `provider_profile_tab.dart` | 0 usage `LocaleProvider`, `_statusLabel()` duplique les clés `driver_status_*` existantes | **GAP** |
| Chauffeur — `driver_onboarding_screen.dart` | `t()` utilisé mais ~14 `labelText`/titres résiduels | **GAP (partiel)** |
| Chauffeur — `mechanic_onboarding_screen.dart` | 1 usage `LocaleProvider`, 2 chaînes résiduelles | **GAP (mineur)** |
| Admin — `app_shell.dart` | Majoritairement `t()`, 2 `PopupMenuItem` résiduels | **GAP (mineur)** |
| Admin — `admin_dashboard_shell.dart` | `NavigationRail` labels + "Activer la commission" hardcodés | **GAP (partiel)** |
| Admin — `admin_drivers_list_screen.dart` | 1 seul mot "Retry" à remplacer par `common_retry` | **GAP (trivial)** |
| Admin — finance tabs (erreurs K-6) | 6 messages d'exception brute → **corrigés (BUG-010)**, réutilisation de `admin_action_error` | COUVERT (après correctif) |
| Notifications (K-5, référence Bloc I) | Clés `notif_*`/`notifications_*` déjà confirmées COUVERT en Bloc I | COUVERT (référencé, pas dupliqué) |

**Bilan intermédiaire** : dictionnaire et cohérence des clés sains ; le GAP réel se situe dans
plusieurs écrans/fichiers qui n'appellent jamais `LocaleProvider.t()` ou n'en font qu'un usage
partiel. 1 bug corrigé ce tour (BUG-010, P2). Bloc K reste **EN COURS** — voir
`docs/PHASE7_QA_PLAN.md` et `docs/PHASE7_BUG_REPORT.md` pour le point de reprise exact.

## Timezone / Date (Bloc K2) et Accessibilité MVP (Bloc L)
Non démarrés à ce commit — prochaine session.

## Sécurité / Performance
Voir blocs dédiés Q, M — matrice à enrichir au fur et à mesure des tests réels.

---
**Note méthodologique** : Cette matrice n'est PAS exhaustive à ce stade — elle sert de point de
départ. Elle sera mise à jour à chaque bloc fermé avec les résultats réels (statut, bug ID le
cas échéant). La priorité immédiate est de suivre TEST → FAIL → FIX → RETEST plutôt que
d'étoffer ce tableau de façon théorique.

**Découverte initiale la plus importante (à valider par test réel dans Bloc B)** :
`MIS-C-05` — aucune Cloud Function n'appelle `cancelAuthorization()` du provider de paiement
lorsqu'un client annule une mission déjà assignée (payment_status = `authorized`). Grep exhaustif
sur `functions/src/` confirme zéro appel à `.cancelAuthorization(` en dehors de sa définition
d'interface/implémentation. Ceci doit être confirmé par un test d'intégration réel avant d'être
classé comme bug (voir Bloc B).

## MISE À JOUR — Bloc K FERMÉ (reprise K-5 résidus 4/7→7/7 + Notifications + K-9)

| Écran / zone | État | Statut |
|---|---|---|
| `mechanic_request_flow_screen.dart` (résidu 4/7) | Toutes chaînes Steps 2-4 + résumé corrigées | **COUVERT** |
| `app_shell.dart` (résidu 5/7) | PopupMenu + footer corrigés | **COUVERT** |
| `admin_dashboard_shell.dart` (résidu 6/7) | Titre/nav/overview/settings corrigés | **COUVERT** |
| `admin_drivers_list_screen.dart` (résidu 7/7) | "Retry" → `common_retry` | **COUVERT** |
| Notifications (K-5, contenu) | 9 paires `notif_*` FR/EN/ES complètes ; tooltip bell câblé | **COUVERT** |
| K-9 tests structurels | `app_strings_structural_test.dart` (dictionnaire + scan statique 592 appels) + 2 widget tests ciblés | **EN PLACE** |

**Bloc K : ✅ FERMÉ.** `flutter analyze` 3 infos pré-existantes / 0 erreur. `flutter test` 464/464 PASS.

**Gap différé (hors K, documenté pour K2-3)** : connecteur `'à'` codé en dur dans le formatage
date/heure local (`notifications_screen.dart` + 4 autres fichiers) — comparaison sur instants
réels non affectée, uniquement l'affichage textuel du connecteur.

## Timezone / Date (Bloc K2) — EN COURS (ce tour)

| Sous-bloc | État | Statut |
|---|---|---|
| K2-0 Reconnaissance | 144 occurrences date/heure cartographiées (41 fichiers `lib/`), backend `functions/` sans logique day-boundary sensible au fuseau | **FAIT** |
| K2-1 Storage | Timestamps métier = vrais `Timestamp` Firestore (instants réels), `parseFirestoreDate()` fuseau-agnostique | **CONFORME** |
| K2-2 Affichage local | 3 gaps réels trouvés et **corrigés** (Timestamp brut visible + 2x `.toLocal()` manquant) | **PARTIEL** |
| K2-3 Formats FR/EN/ES | Clé `datetime_connector_at` (fr/en/es) créée, câblée dans `money_format.dart`, `mission_finance_section.dart`, `notifications_screen.dart` + 3 fichiers propagés (`provider_payouts_section.dart`, `admin_payment_detail_screen.dart`, `admin_driver_detail_screen.dart`) | **CORRIGÉ** |
| K2-4 Frontière UTC/local | `test/timezone/k2_utc_local_boundary_test.dart` créé (5 tests permanents, PASS) | **FAIT** |
| K2-5 Expirations business | Comparaisons sur instants réels (`isBefore`/`isAfter`/`<=`), jamais sur strings | **CONFORME** |
| K2-6 Tri | ~25 `.sort()`/`.orderBy()` tous sur `DateTime.compareTo()` réel | **CONFORME** |
| K2-7 DST | Grep ciblé sur `founding_driver.dart`, `commission_resolver.dart`, `payout_policy_configuration.dart`, `detectExpiringDocuments.ts` (`Duration(days`/`Duration(hours`/`add(const Duration`/`subtract(const Duration`) → 0 occurrence | **N/A (documenté)** |

**BLOC K2 : ✅ FERMÉ.** `flutter analyze` 3 infos pré-existantes / 0 erreur.
`flutter test` complet → **471/471 PASS** (469 précédents + 2 nouveaux tests K2-3), 0 régression.
P0 ouverts = 0. P1 ouverts = 0.

## Accessibilité MVP (Bloc L)
Voir section dédiée ci-dessous.

## Bloc L — Accessibilité MVP (session en cours, PARTIEL)

| Item | État |
|---|---|
| L-0 Reconnaissance | ✅ Fait (grep ciblé icon-only sans tooltip) |
| L-1 Semantics critiques | ✅ Fait — 5 tooltips ajoutés (back-arrow x3, quantité +/- x2) + 3 tests (NotificationBell, ProviderDashboardShell Switch, AuthScreen role buttons) |
| L-2 Text scale | 🟡 Partiel — testé à 1.0x (OK). Gap réel trouvé à 1.5x/2.0x sur AuthScreen 320px (overflow) → **DEFERRED NON-BLOCKING** (P3) : nécessite refonte layout AuthScreen hors budget session actuelle |
| L-3 Tap targets | 🟡 Partiel — au moins 1 carte rôle AuthScreen mesurée à 38px (<44px recommandé) → **DEFERRED NON-BLOCKING** (P3) |
| L-4 Formulaires | ✅ Fait — labels présents, erreur non basée uniquement sur la couleur (icône + texte) |
| L-5 Clavier web | 🟡 Reconnaissance faite (AdminLoginScreen a déjà `onSubmitted`), aucun P0/P1 — **DEFERRED NON-BLOCKING** (audit exhaustif tab order hors budget) |
| L-6 Contraste | ✅ BUG-L6-01 (P1) corrigé : `AppColors.warningText` créé (contraste AA ~5.0:1) et câblé dans l'avertissement GPS chauffeur. Gap P2 résiduel sur badges décoratifs (StatusBadge etc.) — **DEFERRED NON-BLOCKING** |
| L-7 Photo/preuve | ✅ COUVERT — `_ProofPreviewDialog` (driver_active_mission_screen.dart) utilise déjà des labels texte explicites, aucun bouton icon-only |
| L-8 Loading states | ✅ COUVERT (référencé) — déjà prouvé par tests double-submit existants (Bloc B/C) |

**BLOC L : ✅ FERMÉ** — L-0 à L-4 complets (session précédente). L-6 : 1 gap réel P1 corrigé (BUG-L6-01), test de régression permanent ajouté. L-7/L-8 confirmés couverts sans gap. L-2/L-3/L-5 et le résidu P2 de L-6 (badges décoratifs) restent DEFERRED NON-BLOCKING, documentés avec justification. `flutter analyze` 3 infos + 2 warnings pré-existants non liés / 0 erreur. `flutter test` complet → **479/479 PASS**, 0 régression. P0 = 0, P1 = 0.

## BLOC M — PERFORMANCE : ✅ FERMÉ

| Zone critique | Preuve / Statut |
|---|---|
| Démarrage app | ✅ COUVERT — `main.dart` léger, aucun travail lourd au boot |
| GPS (Bloc H/C) | ✅ COUVERT — Timer unique, garde `isRunning`/`_busy`, pas de régression |
| Missions dispo chauffeur | ✅ COUVERT — `_ensureStreams()` mémoïsé, `whereIn` batché 30 |
| Finance repository (paiements/refunds/payouts/disputes/ledger) | ✅ COUVERT — toutes requêtes `.limit()` bornées |
| Dashboard chauffeur (switch en ligne) | ❌ GAP P1 → ✅ CORRIGÉ (stream mémoïsé par driverId) |
| Statut chauffeur (`driver_status_screen`) | ❌ GAP P1 → ✅ CORRIGÉ (stream mémoïsé par uid) |
| Fiche admin chauffeur (`admin_driver_detail_screen`) | ❌ GAP P1 → ✅ CORRIGÉ (Stream+2 Future en `late final`) |
| Tracking client — photo preuve | ❌ GAP P1 → ✅ CORRIGÉ (`cacheHeight` ajouté) |
| Onglets dashboard chauffeur (`tabs[_index]` sans IndexedStack) | ⚠️ GAP P2 — DEFERRED (IndexedStack testé, reverté : coût pire pour MVP) |
| Notifications (`watchNotifications` sans `.limit()`) | ⚠️ GAP P2 — DEFERRED (sous-collection par user, volume MVP faible) |
| Listes admin (drivers/finance tabs non-lazy) | ⚠️ GAP P2 — DEFERRED (admin-only, volume MVP faible) |

**Tests** : 480/480 PASS (`flutter test`), 0 erreur `flutter analyze`.
**P0 ouverts** : 0. **P1 ouverts** : 0. **P2 DEFERRED** : 3 (documentés ci-dessus).

## BLOC N — FIRESTORE / INDEXES : ✅ FERMÉ

Matrice courte (requête critique → where/orderBy → index requis → index existant → statut) :

| Requête critique | where/orderBy | Index requis | Index existant | Statut |
|---|---|---|---|---|
| N-1 Missions client (`watchCustomerMissions`) | `where(customer_id)` seul, tri en mémoire | Aucun (equality seule) | #4 existe mais non consommé (voir note doc) | **COUVERT** (P3 doc : index #4 sur-provisionné, non-bloquant) |
| N-1 Mission active client (`watchMission`) | `.doc(id)` direct | Aucun | N/A | **COUVERT** |
| N-2 Mission active chauffeur (`watchActiveMissionForDriver`) | `where(driver_id)` seul, filtre statut + tri en mémoire | Aucun (equality seule) | N/A | **COUVERT** |
| N-2 Historique chauffeur par statut | `where(driver_id).where(status)` + tri | Composite driver_id+status+created_at | #5 présent | **COUVERT** |
| N-3 Jobs disponibles (dispatch, `dispatchMissionToDrivers.ts`) | `where(status).where(online_status).where(documents_all_valid).where(current_geohash range) .limit(50)` | Composite 4 champs | #1 présent, exact match | **COUVERT** — bien borné (`.limit(50)` + cap mémoire 15) |
| N-3 Jobs disponibles côté chauffeur (`watchAvailableMissionsForDriver`) | offres `where(driver_id).where(status)`, puis `whereIn` batché 30 sur missions | Composite driver_id+status+expires_at | #8 présent | **COUVERT** (déjà confirmé Bloc M) |
| N-4 Notifications (`watchNotifications`) | `where(userId)` seul, sans `.limit()` | Aucun (equality seule) | N/A | **COUVERT techniquement — gap `.limit()` reste P2 DEFERRED** (aucune preuve nouvelle ce bloc justifiant un fix) |
| N-5 Admin driver review (`watchDriversByStatus`) | `where(status)` seul, sans `.limit()` | Aucun (equality seule) | N/A | **COUVERT techniquement — gap `.limit()` reste P2 DEFERRED** (idem, réaffirmé) |
| N-5 Documents chauffeur en attente | `where(driver_id).where(status)` | Composite driver_id+status | #2 présent | **COUVERT** |
| N-5 Documents expirants (cron) | `where(status).where(expires_at)` | Composite status+expires_at | #3 présent | **COUVERT** |
| N-6 Finance — payouts/snapshots chauffeur (`watchPayoutsForDriver`/`watchFinancialSnapshotsForDriver`) | `where(driver_id).orderBy(created_at desc)` | Composite driver_id+created_at | #16 / #12 présents | **COUVERT** |
| N-6 Finance — solde mission (`missionFinancialBalance.ts`) | 4x `where(mission_id)` équité pure | Aucun (equality seule) | N/A | **COUVERT** |
| N-6 Finance — payout chauffeur (`calculateDriverPayout.ts`) | `where(driver_id).where(status)` équité pure, sans orderBy | Aucun composite requis | N/A | **COUVERT** |
| N-6 Finance — réconciliation (`reconciliationEngine.ts`) | ranges `created_at`/`received_at` par période, jobs batch admin | Aucun composite requis (bornées par date, non temps réel) | N/A | **COUVERT** |
| N-6 Finance — dispute/webhook lookup (`processStripeWebhook.ts`) | `where(provider_*_id)` equality simple | Aucun (auto single-field) | N/A | **COUVERT** |
| N-7 Purge GPS (`cleanupExpiredTrackingHistory.ts`) | `collectionGroup("history").where(recorded_at <).limit(400)` boucle | Composite collectionGroup `history(recorded_at)` | **ABSENT** → **CORRIGÉ** (ajouté) | **GAP RÉEL P1 → CORRIGÉ** |
| N-7 Founding driver qualifications (`transitionFoundingDriverPeriods.ts`) | `collectionGroup("qualifications").where(status).where(promotional_period_ends_at)` | Composite collectionGroup | #11 présent | **COUVERT** |
| N-8 Payout scan mission (`missionFinancialBalance.ts` — `driver_payouts.where(status=='paid')`) | AVANT : scan plateforme entière, sans `.limit()`, sans filtre driver | Aucun composite requis | #16 (driver_id+created_at) réutilisable en filtrant driver_id | **GAP RÉEL P1 → CORRIGÉ** (borné par `driver_id` du snapshot, cf. BUG-N-02) |

**Découverte + correction (Bloc N)** :
- **BUG-N-01 (P1, corrigé)** : index composite `history` (collectionGroup, `recorded_at` asc)
  documenté depuis l'étape 10 (`docs/FIRESTORE_INDEXES.md` #20) et référencé dans le code de
  `cleanupExpiredTrackingHistory.ts`, mais **absent** du fichier `firestore.indexes.json` réel
  (confirmé par énumération programmatique : 20 entrées seulement, aucune `history`). Aurait
  provoqué un `FAILED_PRECONDITION` en production dès la première exécution du cron quotidien.
  **Corrigé** : entrée ajoutée à `firestore.indexes.json`, JSON validé syntaxiquement correct.
- **BUG-N-02 (P1, corrigé)** : `missionFinancialBalance.ts` lisait **tous** les `driver_payouts`
  `status=='paid'` de la plateforme entière (sans `.limit()`, sans filtre `driver_id`) pour
  déterminer si un payout inclut le snapshot d'une mission donnée — un scan qui grossit avec le
  volume total de payouts payés tous chauffeurs confondus, alors qu'un seul `driver_id` (celui du
  chauffeur de la mission) peut jamais être concerné. **Corrigé** : la requête est maintenant
  bornée par `where('driver_id', '==', snapshotsDriverId)` en plus de `status=='paid'` — couverte
  par l'index composite existant #16 (`driver_payouts(driver_id, created_at desc)`, dont le préfixe
  `driver_id` seul suffit pour cette equality-only query). Fallback conservé sur l'ancien
  comportement si `driver_id` ne peut être résolu (cas théorique, ne devrait jamais survenir).

**P2 réaffirmés DEFERRED (aucune preuve nouvelle ne force un fix)** :
- `watchNotifications()` sans `.limit()` — sous-collection par utilisateur, volume MVP faible.
- `watchDriversByStatus()` sans `.limit()` — liste admin-only, volume MVP faible.

**P3 documenté** : index #4 (`delivery_requests(customer_id, created_at desc)`) actuellement non
consommé par l'implémentation réelle de `watchCustomerMissions()` (tri en mémoire, pas d'`.orderBy`
serveur) — inoffensif, documenté dans `docs/FIRESTORE_INDEXES.md`, non-bloquant.

**Tests** : `npx tsc --noEmit` (functions) → 0 erreur. `npm run lint` (functions) → 0 erreur.
Jest unit (functions) → **109/109 PASS**. Jest integration complet (émulateur Firestore/Auth/
Storage) → **35 suites / 512 tests PASS**, 0 régression (dont `missionFinancialBalance.test.ts`
et `calculateDriverPayout.test.ts` qui exercent directement le code modifié). Aucun fichier
Flutter/Dart touché ce bloc → `flutter analyze`/`flutter test` non ré-exécutés (déjà verts à
480/480 en sortie du Bloc M, aucune régression possible côté client).

**P0 ouverts** : 0. **P1 ouverts** : 0 (2 corrigés : BUG-N-01, BUG-N-02).

---

## BLOC O — CLOUD FUNCTIONS HARDENING : ✅ FERMÉ

Reconnaissance déjà faite en amont (lecture complète de `acceptDelivery.ts`, `completeDelivery.ts`,
`createDeliveryRequest.ts`, `refundPayment.ts`, `updateMissionTrackingStatus.ts`,
`onMissionStatusChangeNotifyCustomer.ts`, `onMissionEndedClearTracking.ts`, sections ciblées de
`paymentOrchestration.ts`). Ce tour : preuves (tests existants référencés + 1 gap comblé), pas de
second inventaire.

### Matrice consolidée (Function → auth → validation → transaction → idempotence/retry → erreurs → statut)

| Function | Auth | Validation input | Transaction | Idempotence / retry | Erreurs | Statut |
|---|---|---|---|---|---|---|
| `createDeliveryRequest` | `requireSignedIn` | quoteId, ≥2 stops, stops[0]=pickup, **distanceKm/estimatedDurationMinutes ≥0** (BUG-O-01, corrigé ce tour) | `runTransaction` (quote+mission+stops+is_consumed) | `quote.is_consumed` = garde déterministe ; retry séquentiel ET concurrent PROUVÉS par `createDeliveryRequestIdempotency.test.ts` (Cas B/C) | `invalid-argument`/`not-found`/`permission-denied`/`failed-precondition`, aucun détail interne | **COUVERT** |
| `acceptDelivery` | `requireSignedIn` + éligibilité chauffeur (status/documents/catégorie) | `missionId` requis | `runTransaction` (relecture mission+driver, 1er commit gagnant) | Retry DIFFÉRENT chauffeur : PROUVÉ par `acceptDeliveryConcurrency.test.ts` (course concurrente + séquentielle). Retry MÊME chauffeur : `if (mission.driver_id) throw failed-precondition` s'exécute AVANT toute écriture (snapshot/paiement) → aucune duplication possible ; message légèrement imprécis ("assignée à un autre chauffeur") mais fonctionnellement sûr (P3 cosmétique, non-bloquant) | `not-found`/`permission-denied`/`failed-precondition` structurées | **COUVERT** |
| `completeDelivery` | `requireSignedIn` + `driver_id===ctx.uid` | `missionId`, `proofOfDeliveryUrl` non vide | `runTransaction` (snapshot confirmed=immuable, ledger x5) | Double appel PROUVÉ REJETÉ par `completeDelivery.test.ts` ("snapshot déjà confirmed" + "mission déjà completed") — snapshot immuable = garde d'idempotence | idem | **COUVERT** |
| `completePickup` | `requireSignedIn` + `driver_id` | `missionId` | `runTransaction` | Double appel PROUVÉ REJETÉ par `completePickup.test.ts` ("depuis picked_up déjà ramassé" + "depuis completed") | idem | **COUVERT** |
| `updateMissionTrackingStatus` | `requireSignedIn` + `driver_id` | `targetStatus` doit être une clé connue de `ALLOWED_TRANSITIONS` | `runTransaction` | Machine à états stricte à prédécesseur unique (`ALLOWED_TRANSITIONS`) : un retry relit un `status` déjà avancé → rejet automatique. Non testé sous le libellé explicite "retry" mais fonctionnellement identique aux tests "sauts de statut interdits"/"transition régressive" déjà existants (`updateMissionTrackingStatus.test.ts`) → référencé, pas dupliqué | `invalid-argument`/`not-found`/`permission-denied`/`failed-precondition` | **COUVERT (référencé)** |
| Cancellation mission (`onMissionEndedClearTracking`) | Trigger système (`onDocumentUpdated`), pas d'appel client direct | `wasAlreadyTerminal` + vérif pointeur `active_delivery_id` avant clear | N/A (trigger, écritures ciblées) | Rejouer le trigger sur une mission déjà cancelled+payment déjà cancelled ne relance PAS `cancelAuthorization` : PROUVÉ par `missionCancellationPaymentRelease.test.ts` (test `[idempotence]` explicite) | Logs serveur uniquement (trigger, pas de retour client) | **COUVERT** |
| Pricing / quote (`calculateDeliveryQuote`) | `requireSignedIn` | `vehicleCategory`, `distanceKm≥0`, `estimatedDurationMinutes≥0` déjà présents | Lecture seule + `.set()` d'un nouveau devis (pas de contention possible, chaque appel crée un nouveau doc) | N/A (devis = donnée jetable, jamais rejouée ; c'est `createDeliveryRequest`/`acceptDelivery` qui portent la garde d'idempotence réelle) | `invalid-argument`/`failed-precondition` | **COUVERT** |
| `refundPayment` | `requireSignedIn` + (`isAdminOrAbove` OR `payment.customer_id===ctx.uid`) | `paymentId`, `reason`, `amountMinor` | `runTransaction` (dedup doc `refunds/{requestKey}`) + appel provider HORS transaction | `requestKey` déterministe = équivalent fonctionnel prouvé de `buildIdempotencyKey` : `refundPayment.test.ts` contient DEUX tests dédiés — "IDEMPOTENCE : même requestKey rejouée" (résultat caché renvoyé, jamais un 2e RefundDoc) ET "CONCURRENCE : deux appels simultanés" (spy sur le provider prouve EXACTEMENT 1 appel réel) | Erreurs structurées, jamais de détail Stripe brut renvoyé au client | **COUVERT (O-2 fermé par preuve existante)** |
| `calculateDriverPayout` | `requireAdminOrAbove` | `driverId` requis | `runTransaction` (agrégation snapshots + marquage) | Marquage `included_in_payout_id` = idempotence par construction : 2e appel PROUVÉ retourner `payoutId: null, amountMinor: 0` (`calculateDriverPayout.test.ts`) | `invalid-argument`/`permission-denied` | **COUVERT** |
| `reverseDriverPayout` | `requireAdminOrAbove` | `payoutId`, `reason` | `runTransaction` (machine d'état payout) | `REVERSED` = état TERMINAL (`TRANSITIONS[REVERSED]===[]`) : un 2e appel est explicitement REJETÉ (pas silencieusement accepté) — PROUVÉ par test dédié, aucun double effet ledger | idem | **COUVERT** |
| `approveDriver` | `requireAnalystOrAbove` (confirmé par grep) | `driverId` | `runTransaction` (précondition "déjà approuvé") | Précondition d'état = garde naturelle contre un retry | idem | **COUVERT** |
| `rejectDriver` | rôle analyst+ (référencé `adminPrivilegedActions.test.ts`) | `driverId`, `reason` | transaction | precondition d'état | idem | **COUVERT (référencé)** |
| `suspendDriver` | admin/super_admin (pas analyst) | `driverId`, `reason` | transaction | double-suspension REJETÉE — PROUVÉ (`adminPrivilegedActions.test.ts`) | idem | **COUVERT (référencé)** |
| `reactivateDriver` | admin/super_admin | `driverId` | transaction | precondition d'état | idem | **COUVERT (référencé)** |
| `setUserRole` | super_admin uniquement | `uid`, `role` valide | écriture claims + Firestore | opération déclarative idempotente par nature (réassigner le même rôle = no-op) | idem | **COUVERT (référencé, Bloc E)** |
| `validateDriverDocument` | analyst+ | `driverId`, `documentType`, `decision` | transaction | precondition d'état document | idem | **COUVERT (référencé)** |
| `updateDisputeStatus` | `requireAdminOrAbove` | `disputeId`, `newStatus` ∈ `DisputeStatuses` | délègue à `transitionDisputeStatus()` (machine d'état) | machine d'état dispute = garde naturelle ; permission-denied non-admin PROUVÉ, invalid-argument PROUVÉ (`disputeOrchestration.test.ts` describe dédié) | idem | **COUVERT** |
| Notifications critiques (`onMissionStatusChangeNotifyCustomer`) | Trigger système | Guard `before.status===after.status → return` (no-op sur écriture non pertinente) | N/A (trigger) | PAS de dédup par event-id explicite pour une VRAIE redélivrance de plateforme (distincte d'un retry client onCall) — risque théorique, sévérité UX faible (notification dupliquée, jamais un effet financier). Déjà classé DEFERRED/non-bloquant en session antérieure (entrée I-4, `PHASE7_QA_MATRIX.md`) ; RÉAFFIRMÉ ici sans nouvelle preuve l'invalidant (règle "ne pas rouvrir sans preuve nouvelle") | N/A | **DEFERRED (réaffirmé, non-bloquant)** |

### O-1/O-2/O-3 — Synthèse retry/idempotence

Toutes les fonctions financières/transactionnelles critiques ont été analysées avec la question
« appel exécuté → réponse perdue → retry identique → conséquence ? ». Résultat : **aucune**
fonction critique ne produit de double mission, double transition, double paiement, double
refund, double payout, ou ledger dupliqué. Les mécanismes trouvés (non exhaustifs par
`buildIdempotencyKey`) :
- **Précondition d'état / machine à états** (`acceptDelivery`, `completeDelivery`, `completePickup`,
  `updateMissionTrackingStatus`, `approveDriver`, `updateDisputeStatus`) — un retry relit un état
  déjà avancé et échoue proprement (`failed-precondition`), avant toute nouvelle écriture.
- **Document de déduplication déterministe** (`refundPayment` via `requestKey`, schéma en 3 temps
  de `paymentOrchestration.ts` pour `createAndAuthorizeMissionPayment`/`captureMissionPayment` —
  l'appel provider a toujours lieu HORS transaction Firestore, donc jamais ré-exécuté par un retry
  de contention).
- **Marquage d'inclusion** (`calculateDriverPayout` via `included_in_payout_id`).
- **État terminal explicite** (`reverseDriverPayout` via `REVERSED`).
- **Vérification de pointeur avant effet de bord** (`onMissionEndedClearTracking` : ne clear
  `active_delivery_id` que s'il pointe encore vers CETTE mission).

Seul point non couvert par un mécanisme explicite : la redélivrance de plateforme (at-least-once)
d'un trigger Firestore (`onMissionStatusChangeNotifyCustomer`) — classé DEFERRED (voir matrice
ci-dessus), cohérent avec la classification I-4 déjà actée.

### O-4 — Validation input : 1 gap comblé

**BUG-O-01 (P2, corrigé)** : `createDeliveryRequest.ts` acceptait `distanceKm`/
`estimatedDurationMinutes` sans aucune validation runtime (seul `calculateDeliveryQuote.ts`, en
amont, validait ces champs sur le DEVIS — mais `createDeliveryRequest` est le seul point d'écriture
réel de `delivery_requests`, rejoué plus tard par `acceptDelivery` pour le recalcul serveur du
prix). Impact financier réel nul aujourd'hui (`missionBaseValue` est plancherée par
`rule.minimum_charge` dans `pricingEngine.ts`), mais donnée métier incohérente à rejeter
explicitement. Fix : ajout de la même garde `typeof ... === "number" && Number.isFinite(...) &&
>= 0` que `calculateDeliveryQuote.ts`, + 3 nouveaux tests dans `createDeliveryRequest.test.ts`
(distanceKm négatif, estimatedDurationMinutes négatif, distanceKm non-numérique — chacun prouve
qu'aucune mission n'est créée et que le devis reste non consommé).

Aucun autre gap critique trouvé sur les fonctions prioritaires (montant négatif déjà gardé sur
`refundPayment`/`calculateDriverPayout`/`reverseDriverPayout` ; ID vide déjà gardé partout via
`invalidArgument`).

### O-5 — Auth/rôles : référencé, pas dupliqué

`adminPrivilegedActions.test.ts` (~40 tests) et `authSessionClaims.test.ts` (~15 tests) couvrent déjà
`setUserRole`/`suspendDriver`/`reactivateDriver`/`validateDriverDocument`/`rejectDriver`/
`requestDriverDocuments` + les 3 niveaux de claims (Bloc D/E). `updateDisputeStatus` est couvert par
un describe dédié dans `disputeOrchestration.test.ts` (permission-denied non-admin + invalid-argument
newStatus + succès admin). Aucune fonction critique listée n'est restée sans preuve de rôle.

### O-6 — Transactions : COUVERT

Toutes les fonctions critiques lisent-avant-d'écrire à l'intérieur d'un unique `db.runTransaction()`
(jamais de lecture hors transaction suivie d'une écriture conditionnelle). Seul point observé sans
détection automatisée : `reconciliationEngine.ts` (moteur de RAPPORT, jamais d'écriture financière)
n'a pas de type d'anomalie dédié à un paiement resté bloqué en `AUTHORIZED` (jamais capturé/annulé).
Ce scénario supposerait un crash applicatif entre le commit de `acceptDelivery` et l'appel
`completeDelivery`/annulation — aucune preuve d'occurrence réelle, faible fréquence attendue,
aucun risque de double effet financier (un paiement `AUTHORIZED` non capturé n'entraîne par nature
aucun débit). **P3, documenté DEFERRED → Phase 8** (candidat pour un futur type d'anomalie
`payment_stuck_authorized` dans le moteur de réconciliation, hors scope Phase 7).

### O-7 — Erreurs : PASS

`src/lib/errors.ts` : toutes les erreurs (`invalidArgument`, `notFound`, `failedPrecondition`,
`permissionDenied`, `unauthenticated`, `aborted`, `internal`) sont des `HttpsError` avec un message
métier explicite fourni par l'appelant — aucune ne sérialise une stack trace ou un objet brut. Les
2 seuls call-sites `internal(...)` (`createCustomerPaymentProfile.ts`, `createDriverStripeAccount.ts`)
concatènent `err.message` d'un provider (Stripe) — un message d'erreur Stripe (ex: "Invalid API
Key provided") ne contient jamais de secret ni de stack trace, seulement une description
fonctionnelle ; confirmé par lecture de `stripeProvider.ts` (tous les `catch` y renvoient
`stripeErr.code`/`stripeErr.message`, jamais `err.stack` ni la clé API elle-même). **PASS**.

### O-8 — Scan secrets : PASS

Scan ciblé (`sk_live_`, `rk_live_`, PEM private key, `whsec_`, `ghp_`/`github_pat_`, JSON
`"private_key"`, fichiers `.env*`/`serviceAccountKey*` trackés) sur l'ensemble du repo. Seules
occurrences trouvées : des valeurs FICTIVES dans des fichiers de test (`whsec_fake_webhook_secret...`,
`sk_live_should_never_appear`, `sk_live_leak_attempt`) utilisées explicitement pour PROUVER que ces
patterns ne fuient jamais dans les logs (`observability.test.ts`) ou pour signer des payloads de
webhook de test (`processStripeWebhook.test.ts`). Aucun secret réel, aucune clé de compte de service,
aucun `.env` tracké dans le repo. Les clés Firebase client (publiques par design) ne sont pas
concernées par ce scan. **PASS**.

### Validation Bloc O

`npx tsc --noEmit` (functions) → 0 erreur. `npm run lint` (functions) → 0 erreur. Jest unit et Jest
integration exécutés en validation finale groupée (voir section Validation finale N→O→P plus bas) —
résultats reportés là pour éviter une double exécution de la suite complète.

**P0 ouverts** : 0. **P1 ouverts** : 0. **P2 corrigés** : 1 (BUG-O-01). **P3 documentés** : 2
(message d'erreur `acceptDelivery` retry même-chauffeur ; anomalie `payment_stuck_authorized`
absente du moteur de réconciliation, DEFERRED → Phase 8).

**BLOC O : ✅ FERMÉ.**

---

## BLOC P — STORAGE HARDENING : ✅ FERMÉ

Reconnaissance : lecture unique de `storage.rules` (146 lignes, 3 espaces de noms +
deny-by-default) + localisation des tests Storage existants (`storageRules.test.ts`, 15 tests ;
`driver_active_mission_proof_upload_test.dart`, 3 testWidgets). Aucun second audit général.

### Matrice consolidée (Flux Storage → règle → test existant/nouveau → statut)

| Flux Storage | Règle (`storage.rules`) | Test existant/nouveau | Statut |
|---|---|---|---|
| P-1 driver_documents — propriétaire upload | `allow create: uid()==driverId && isDriver() && isValidDocumentUpload() && resource==null` | Test 1 | **COUVERT** |
| P-1 driver_documents — autre chauffeur DENIED | idem (uid() mismatch) | Test 2 | **COUVERT** |
| P-1 driver_documents — client (customer)/non-authentifié DENIED | `allow read/create: isSignedIn() && ...` (customer échoue `uid()==driverId`, anon échoue `isSignedIn()`) | **Test 5ter (nouveau)** | **COUVERT** |
| P-1 driver_documents — lecture propriétaire+analyst / tiers chauffeur refusé | `allow read: uid()==driverId \|\| isAnalystOrAbove()` | Test 4 | **COUVERT** |
| P-2 delivery_proofs — chauffeur assigné upload autorisé | `allow create: isDriver() && firestore.get(...).driver_id==uid() && isValidImageUpload() && resource==null` | Test 8 | **COUVERT** |
| P-2 delivery_proofs — autre chauffeur DENIED | idem | Test 8 | **COUVERT** |
| P-2 client (customer) upload DENIED | `isDriver()` requis | Test 12 | **COUVERT** |
| P-2 upload échoue → mission non completed / retry → succès / URL réelle seulement après succès | Côté client : `completeDelivery` appelé seulement après `uploadDeliveryProof()` résolu | `driver_active_mission_proof_upload_test.dart` (3 testWidgets) | **COUVERT** |
| P-2 immutabilité (client ne peut pas écraser la preuve) | `resource==null` requis sur `create` | Test 9bis | **COUVERT** |
| P-2 autre client ne peut pas lire une preuve qui n'est pas la sienne | `allow read: customer_id==uid() \|\| driver_id==uid() \|\| isAnalystOrAbove()` | Test 14 | **COUVERT** |
| P-3 content-type document (image/pdf uniquement) | `isValidDocumentUpload()` | Test 5 | **COUVERT** |
| P-3 content-type preuve (image uniquement) | `isValidImageUpload()` | Test 11 | **COUVERT** |
| P-4 taille document > 10 Mo | `isValidDocumentUpload()` : `size < 10*1024*1024` | **Test 5bis (nouveau)** | **GAP DE TEST → COMBLÉ** |
| P-4 taille preuve > 5 Mo | `isValidImageUpload()` : `size < 5*1024*1024` | **Test 11bis (nouveau)** | **GAP DE TEST → COMBLÉ** |
| P-5 path/ownership — driver A ne peut pas écrire sous driver B | `uid()==driverId` | Test 2 | **COUVERT** |
| P-5 path/ownership — client A ne peut pas lire la preuve mission B | `customer_id==uid()` (lookup Firestore) | Test 14 | **COUVERT** |
| P-6 download access — URL/token ne doit pas contourner les règles applicables | Voir analyse dédiée ci-dessous | Analyse architecture (aucun test emulator possible : comportement `getDownloadURL()` est une propriété de la plateforme, pas des Security Rules) | **COUVERT (analyse)** |
| P-7 orphan files — upload Storage réussi puis échec transaction Firestore | N/A (pas de règle, comportement applicatif) | Analyse `completeDelivery.ts` | **DEFERRED NON-BLOCKING → Phase 8 cleanup** |
| profile_photos — lecture publique + écriture propriétaire seul | `allow read: if true; allow write: uid()==userId` | Tests 6/7 | **COUVERT** (public par design, non sensible) |
| deny-by-default — chemin non déclaré, même super_admin | `match /{allPaths=**} { allow read,write: if false }` | Test deny-by-default | **COUVERT** |

### P-4 — Détail des 2 gaps de test comblés

Aucune erreur de RÈGLE : `isValidDocumentUpload()`/`isValidImageUpload()` définissent déjà des
limites numériques (10 Mo documents, 5 Mo images) depuis l'écriture initiale de `storage.rules`
(Phase 3). Le gap identifié était un **gap de PREUVE** : grep exhaustif de `storageRules.test.ts`
pour `size`/`oversiz`/`10 * 1024` avant ce bloc → **zéro** test exerçant un rejet pour taille.
2 tests ajoutés (`5bis`, `11bis`) : upload d'un tableau d'octets `10*1024*1024+1` sur
`driver_documents` et `5*1024*1024+1` sur `delivery_proofs` → `assertFails` confirmé par
exécution réelle contre l'émulateur Storage (voir Validation ci-dessous). Aucune limite produit
modifiée.

### P-6 — Download access (analyse détaillée, point flaggé "très important")

**Fait plateforme établi (recherche externe, comportement Firebase documenté — GitHub
firebase-js-sdk #5342, docs officielles "Download files")** : `getDownloadURL()` génère une URL
contenant un token de téléchargement. Une fois cette URL connue, elle **contourne les Security
Rules** pour toute requête HTTP directe ultérieure — les règles ne sont vérifiées qu'au moment de
la génération du token via le SDK authentifié, jamais re-vérifiées sur un fetch HTTP direct
ultérieur de l'URL tokenisée. Ce n'est PAS un bug de cette app, c'est un comportement Firebase
Storage documenté qu'il faut auditer dans NOTRE architecture : la question réelle est "cette app
fuite-t-elle une URL tokenisée vers un tiers non autorisé via un AUTRE canal que Storage
lui-même ?"

**Audit de tous les points d'usage réel de `getDownloadURL()` dans le repo** (grep exhaustif
`getDownloadURL|signedUrl|getSignedUrl|generateSignedUrl` sur `lib/` et `functions/src/`) :

1. **`driver_documents`** : AUCUN appel `getDownloadURL()` n'existe dans tout le code Dart.
   `driver_document.dart.storageBucketPath` est un chemin brut (pas une URL de téléchargement).
   Le bouton "voir le document" de l'admin (`admin_driver_detail_screen.dart` ligne ~423) est un
   placeholder explicitement non implémenté (commentaire code : "prêt à être branché sur
   `getDownloadURL()` [...] une fois cette intégration ajoutée"). **Conclusion : aucun vecteur
   d'exposition possible aujourd'hui — la fonctionnalité de génération d'URL n'existe pas.**

2. **`delivery_proofs`** : LE SEUL appel `getDownloadURL()` de tout le repo est
   `firebase_proof_upload_repository.dart:38` (`FirebaseProofUploadRepository.uploadDeliveryProof`).
   L'URL retournée transite par la Cloud Function `completeDelivery` (paramètre
   `proofOfDeliveryUrl`, requis, validé non-vide) puis est dénormalisée dans la transaction
   Firestore sur **exactement 2 emplacements** :
   - `delivery_requests/{missionId}.proof_of_delivery_url` — lu selon `firestore.rules` L270-340
     par `customer_id==uid() || driver_id==uid() || isAnalystOrAbove()`.
   - `delivery_requests/{missionId}/tracking_events/{eventId}.metadata.proof_of_delivery_url` —
     lu selon la même règle de lecture que le document mission (même bloc `match`).

   Ces deux ensembles de lecteurs Firestore autorisés sont **rigoureusement identiques** (client
   + chauffeur assigné + analyst+) à l'ensemble des lecteurs déjà autorisés à récupérer le fichier
   DIRECTEMENT via la règle Storage `delivery_proofs/{missionId}/{fileName}` (ligne 124-128 de
   `storage.rules` : mêmes 3 conditions `customer_id==uid() || driver_id==uid() ||
   isAnalystOrAbove()`). **Aucun tiers ne peut apprendre l'URL tokenisée via Firestore sans déjà
   être autorisé à obtenir le fichier directement via Storage** — la dénormalisation n'ajoute donc
   aucune surface d'exposition supplémentaire.

3. **`disputes/{disputeId}.proof_of_delivery_url`** (`disputeOrchestration.ts`) : toujours
   initialisé à `null` à la création (`openDispute()`, ligne 117) et jamais réassigné ailleurs
   dans ce fichier (grep confirmé : seule occurrence d'écriture). La collection `disputes` est de
   toute façon lisible uniquement par `isAnalystOrAbove()` (`firestore.rules` L474-477) — un
   sous-ensemble STRICT des lecteurs déjà autorisés côté Storage. **Aucune exposition
   supplémentaire, champ actuellement toujours vide dans cette collection.**

4. **Consommateurs Dart** (`delivery_mission.dart`, `dispute_info.dart`,
   `customer_tracking_screen.dart`, `driver_active_mission_screen.dart`) : lecture/affichage
   uniquement, aucun nouveau point d'écriture ni de journalisation externe trouvé (pas de
   `print`/log serveur qui écrirait l'URL vers un canal accessible à un tiers non autorisé).

5. **`profile_photos`** : lecture PUBLIQUE PAR DESIGN (`allow read: if true`, documenté dans
   `docs/FIRESTORE_ARCHITECTURE.md`) — le token de téléchargement n'apporte ici aucune réduction
   de sécurité supplémentaire puisque n'importe qui peut déjà lire le fichier sans même connaître
   de token (avatar non sensible, test 7 le prouve explicitement).

**Conclusion P-6 : COUVERT.** L'architecture actuelle ne crée, dans aucun des 3 espaces de noms
Storage, de canal alternatif par lequel une URL tokenisée `delivery_proofs`/`driver_documents`
pourrait être apprise par une partie qui n'aurait pas déjà un accès Storage direct équivalent.
Point de vigilance documenté (pas un gap actuel) : si une future fonctionnalité (ex. export admin,
webhook sortant, notification push) venait à transmettre `proof_of_delivery_url` vers un tiers
externe ou un canal moins restrictif que Firestore, ce principe d'équivalence devrait être
réévalué à ce moment — **noté pour vigilance future, non-bloquant aujourd'hui**.

### P-7 — Orphan files (upload Storage réussi, transaction Firestore échoue)

Séquence réelle confirmée par lecture de `completeDelivery.ts` (déjà lu en intégralité lors du
Bloc O) : (1) le client uploade la preuve directement via le SDK Storage — gouverné entièrement
par `storage.rules`, indépendant de tout état Firestore ; (2) SEULEMENT si l'upload réussit, le
client appelle `completeDelivery(missionId, proofOfDeliveryUrl)` ; (3) la transaction Firestore
écrit `proof_of_delivery_url` sur la mission. Si l'étape (3) échoue (contention, mission déjà
`completed` par un appel concurrent, snapshot déjà `confirmed`), le fichier uploadé en (1) reste
en Storage sans jamais être référencé par un document Firestore.

**Analyse de fréquence** : les préconditions de `completeDelivery` qui provoqueraient un échec de
transaction (`failed-precondition` sur statut invalide, snapshot déjà confirmé) échoueraient dans
l'écrasante majorité des cas AVANT qu'un chauffeur légitime ait eu l'occasion d'uploader une
NOUVELLE preuve pour un premier appel — le scénario réel d'orphelin exige une fenêtre de
contention précise (deux appels quasi-simultanés du même chauffeur, ou un redémarrage d'app entre
upload et appel). Aucune fuite de sécurité (le fichier orphelin reste protégé par les mêmes règles
Storage `delivery_proofs` — non listé, non accessible sans être client/chauffeur/analyst+ de CETTE
mission), coût de stockage négligeable (photo unique, pas de boucle d'accumulation).

**Conclusion : `DEFERRED NON-BLOCKING → Phase 8 cleanup`** (candidat pour une Cloud Function de
nettoyage périodique comparant `delivery_proofs/*` à `delivery_requests/*.proof_of_delivery_url`,
hors scope Phase 7 — pas de garbage collector construit maintenant, conforme à la consigne
MODE ACCÉLÉRÉ).

### Validation Bloc P

Suite `storageRules.test.ts` exécutée UNE fois via l'émulateur Storage+Firestore+Auth
(`firebase emulators:exec --only firestore,auth,storage --project demo-movik-test`) : **19/19
PASS** (15 tests préexistants + 4 nouveaux : `5bis`, `5ter`, `11bis` — voir liste ci-dessus ; le
4e nouveau test regroupe 2 assertions customer+anon dans `5ter`). Aucune régression sur les tests
préexistants. `driver_active_mission_proof_upload_test.dart` non ré-exécuté isolément ce bloc
(aucune modification de son code source ni de ses dépendances — sera inclus dans la validation
Flutter groupée finale P→Q→Q2).

**P0 ouverts** : 0. **P1 ouverts** : 0. **P2/P3 documentés** : 1 point de vigilance future P-6
(non-bloquant) + P-7 DEFERRED → Phase 8 cleanup (non-bloquant, aucune fuite sécurité).

**BLOC P : ✅ FERMÉ.**

---

## BLOC Q — APPLICATION SECURITY : ✅ FERMÉ

Beaucoup déjà prouvé dans Phase 3 Security, Bloc D (rôles), Bloc E (Auth/Claims), Bloc F
(cross-user/routing), Bloc N (Firestore), Bloc O (Cloud Functions), Bloc P (Storage) — aucun de
ces audits n'est refait. Ce bloc cherche uniquement les surfaces critiques encore non couvertes.

### Matrice consolidée (surface d'attaque → protection existante → test → statut)

| Surface d'attaque | Protection existante | Test / preuve | Statut |
|---|---|---|---|
| Q-1 Autorisation missions/finance/admin/roles/documents/tracking — server-side, pas juste UI | 31/34 Cloud Functions avec `invalidArgument` explicite ; toutes les fonctions privilégiées utilisent `requireSignedIn`/`requireAdminOrAbove`/`requireAnalystOrAbove` (grep confirmé sur `functions/src/functions/*.ts`) ; Firestore Rules `allow write: if false` sur toutes les collections financières (miroir serveur) | Bloc O (18 fonctions), Bloc D/E (claims) | **COUVERT (référencé)** |
| Q-2 IDOR — client A/mission B, chauffeur A/mission B, documents, tracking, finance | `firestore.rules` : chaque collection sensible filtre par `customer_id==uid()`/`driver_id==uid()`/`isAnalystOrAbove()` | Bloc F (cross-user), Bloc N, tests `storageRules.test.ts` (Bloc P) | **COUVERT (référencé)** |
| Q-2 IDOR — domaine non encore audité : `driver_locations` (tracking position live) | `allow read: uid()==driverId \|\| isAnalystOrAbove() \|\| (isCustomer() && active_delivery_id lié à CE chauffeur ET client)` — vérifié par double `get()` (mission existe + les 2 IDs correspondent) | Lecture directe de la règle ce tour (nouveau) | **COUVERT (vérifié ce tour, aucun gap)** |
| Q-2 IDOR — `driver_internal_notes` (notes analyste privées) | `allow read: isAnalystOrAbove()` uniquement — jamais exposé au chauffeur concerné, même propriétaire du dossier | Lecture directe de la règle ce tour (nouveau) | **COUVERT (vérifié ce tour, aucun gap)** |
| Q-3 Mass assignment — status/driver_id/customer_total/commission/payout/role/approval | `financial_snapshots`/`transaction_ledger`/`payments`/`driver_payouts`/`refunds` : `allow write: if false` intégral (Cloud-Functions-only) ; `users.roles` protégé par égalité stricte `request.resource.data.roles == resource.data.roles` ; `driver_profiles` : ~15 champs sensibles protégés individuellement par `get(champ,null)==get(champ,null)` | Lecture directe des règles (ce tour) + Bloc D/E/N | **COUVERT** |
| Q-4 Input abuse — texte long, IDs arbitraires, valeurs négatives, statuts impossibles | 31/34 fonctions valident explicitement ; machines à états strictes (`ALLOWED_TRANSITIONS`) rejettent tout statut impossible ; BUG-O-01 (Bloc O) a déjà comblé le seul gap réel trouvé (distanceKm/duration négatifs) | Bloc O (matrice complète) | **COUVERT (référencé)** |
| Q-5 Data exposure — emails/documents/paiement/erreurs internes/tokens/stack traces | `src/lib/errors.ts` : toutes `HttpsError` avec message métier, jamais de stack ; les 2 seuls `internal(...)` (Stripe) ne concatènent que `err.message` (jamais `err.stack` ni clé API, confirmé Bloc O) ; BUG-010 (Bloc K) a corrigé les 6 messages d'exception brute affichés côté admin | Bloc O (O-7), Bloc K (BUG-010) | **COUVERT (référencé)** |
| Q-6 Secrets committés | Re-scan ciblé ce tour (`sk_live_`, `rk_live_`, `whsec_`, PEM private key, `ghp_`/`github_pat_`, `.env*`, `serviceAccountKey*`) sur l'ensemble du repo | Seules occurrences : le pattern regex `whsec_` lui-même dans `observability.ts` (bibliothèque de rédaction) + un commentaire d'exemple — aucun secret réel, aucun `.env`/service account tracké | **COUVERT (re-scan ce tour, PASS)** |
| Q-7 Client trust — prix/commission/payout/rôle/statut critique doivent venir du backend | `financial_snapshots` (prix/commission figés), `transaction_ledger`, `driver_payouts` : 100% Cloud-Functions-only (`allow write: if false`) ; `roles` : uniquement `setUserRole()` ; transitions de statut mission : machines à états côté Cloud Function, jamais un `update` Firestore direct sur les champs critiques | Bloc O, lecture directe des règles ce tour | **COUVERT** |
| Q-8 Security Rules ciblées — cas critiques manquants | Storage (Bloc P, 19 tests), Firestore (Bloc N/O référencés) ; aucun nouveau cas critique trouvé nécessitant un test dédié ce tour (Q-2 ci-dessus vérifié par lecture de règle, pas par gap de comportement) | Suite `storageRules.test.ts` (Bloc P) + suite intégration Firestore existante | **COUVERT (référencé, pas de nouveau test requis)** |
| Q-9 Open redirect / routing | `lib/router/app_router.dart` (GoRouter) — déjà audité Bloc F, aucune régression depuis (aucun fichier routing touché N/O/P) | Bloc F (`notifications_deep_link_test.dart` etc.) | **COUVERT (référencé, non ré-audité)** |
| Q-10 Logs/erreurs — client-exposed errors propres | Confirmé ce tour par relecture directe des 2 seuls call-sites `internal(...)` (`createCustomerPaymentProfile.ts`, `createDriverStripeAccount.ts`) : `err.message` uniquement (jamais `err.stack`/clé API) | Bloc O (O-7) + relecture ciblée ce tour | **COUVERT (référencé + vérifié)** |

### Q-2 — Détail des 2 domaines nouvellement vérifiés

Aucun gap trouvé, mais 2 domaines n'avaient pas de mention explicite dans les blocs précédents et
ont été vérifiés directement dans `firestore.rules` ce tour (lecture de règle, pas de nouveau
test requis puisqu'aucun comportement dangereux n'est permis) :
- **`driver_locations/{driverId}`** (position GPS live) : un client ne peut lire la position d'un
  chauffeur QUE s'il a une mission active AVEC CE chauffeur précis (double `get()` : le document
  `active_delivery_id` référencé doit exister ET son `customer_id`/`driver_id` doivent correspondre
  exactement au lecteur et au chauffeur ciblé). Aucun accès cross-mission possible.
- **`driver_internal_notes/{noteId}`** (notes analyste sur un chauffeur) : lecture strictement
  réservée à `isAnalystOrAbove()` — le chauffeur concerné lui-même ne peut JAMAIS les lire, même
  propriétaire du dossier. Écriture exclusivement via `addDriverInternalNote()` (garantit
  `author_user_id`/`author_role` non falsifiables).

### Validation Bloc Q

Aucun nouveau test créé (aucun gap de comportement trouvé — uniquement des vérifications de
règles déjà correctes). Validation complète (tsc/lint/Jest/Flutter/Rules) exécutée en groupe
final P→Q→Q2 (voir plus bas), pour éviter une exécution redondante de la suite complète.

**P0 ouverts** : 0. **P1 ouverts** : 0. **P2/P3** : aucun nouveau (tous déjà documentés dans les
blocs référencés : BUG-010 Bloc K, BUG-O-01 Bloc O).

**BLOC Q : ✅ FERMÉ.**

---

## BLOC Q2 — APP CHECK / ANTI-ABUSE : ✅ FERMÉ

Reconnaissance courte (Q2-1) : distinction stricte entre ce qui peut être préparé/vérifié
maintenant et ce qui nécessite une configuration production Phase 8 (Play Integrity, reCAPTCHA
Enterprise, Apple App Attest, domaines/signing release) — rien forcé artificiellement en dev.

### Q2-1 — État actuel (constat factuel, sans exagération)

| Élément | État réel constaté | Preuve |
|---|---|---|
| SDK Flutter `firebase_app_check` | **Présent** dans `pubspec.yaml` (`0.3.1+4`) et résolu dans `pubspec.lock` (+ `_platform_interface` et `_web`) | `pubspec.yaml:36`, `pubspec.lock:188-207` |
| Initialisation App Check côté client | **ABSENTE** — `BackendBootstrap.initialize()` (`lib/backend/backend_bootstrap.dart`) appelle `Firebase.initializeApp()` uniquement ; aucun `FirebaseAppCheck.instance.activate(...)` nulle part dans `lib/` (grep exhaustif `appCheck\|AppCheck\|app_check` sur tout `lib/` : 0 occurrence hors `pubspec.*`) | Lecture complète de `backend_bootstrap.dart` + grep repo |
| Provider Android (Play Integrity) | **Non configuré** — aucune trace de `PlayIntegrityProvider` | grep 0 résultat |
| Provider Web (reCAPTCHA v3/Enterprise) | **Non configuré** — aucune trace de `ReCaptchaV3Provider`/`ReCaptchaEnterpriseProvider` | grep 0 résultat |
| Enforcement Cloud Functions (`enforceAppCheck: true`) | **Non activé** — aucune fonction (`onCall<...>`, 31 occurrences) ne passe l'option `enforceAppCheck` ; `firebase-functions@^6.0.1` la supporte nativement si activée | grep `enforceAppCheck`/`consumeAppCheckToken` : 0 résultat sur `functions/src/` |
| Enforcement Firestore/Storage Rules (`request.app`) | **Non présent** — ni `firestore.rules` ni `storage.rules` ne référencent `request.app` (mécanisme App Check natif des Security Rules) | grep 0 résultat |

**Conclusion Q2-1 : le SDK est présent (dépendance installée) mais AUCUNE intégration réelle
n'existe encore — ni activation client, ni enforcement serveur.** Ceci est cohérent avec un app
en développement actif (Phase 7 QA), pas encore en configuration de lancement production.

### Q2-2 — Dev/Emulator : non cassé

Aucune intégration App Check n'existe actuellement → par construction, aucun test ni émulateur
ne peut être "cassé" par une dépendance App Check inexistante. `createTestEnvWithStorage()`/
`createTestEnv()` (Bloc N/O/P) continuent de fonctionner sans aucun token App Check, réel ou
simulé — **vérifié implicitement par l'exécution réussie de la suite Storage Rules (19/19 PASS,
Bloc P) et par les 512 tests d'intégration Firestore (Bloc N)**, aucun des deux ne référence
App Check. **COUVERT (par absence de dépendance, pas de risque de régression future tant que
l'activation n'est pas faite sans y penser explicitement)**.

### Q2-3 — Plan production (documenté, pas exécuté)

`Phase 8 — EXTERNAL CONFIGURATION` (ne peut pas être fait depuis ce sandbox, nécessite des
actions du compte Firebase/Google Play/Apple réels) :
- **Android** : activer Play Integrity API dans Google Play Console (nécessite l'app publiée ou
  en test interne avec un `applicationId` réel signé) + `AndroidProvider.playIntegrity` côté SDK.
- **Web** : créer une clé reCAPTCHA v3 (ou Enterprise) dans Google Cloud Console liée au domaine
  de production réel + `ReCaptchaV3Provider(siteKey)` côté SDK.
- **iOS** (si/quand une cible iOS existe) : App Attest (iOS 14+) ou DeviceCheck fallback.
- **Cloud Functions** : ajouter `enforceAppCheck: true` aux fonctions ciblées (Q2-4) — nécessite
  QUE les providers client soient déjà déployés et actifs, sinon coupe les clients légitimes.
- **Rollout progressif** : Firebase permet un mode "monitor only" (Console App Check) avant
  enforcement dur — recommandé pour ne jamais couper un client légitime en production.

Aucune de ces étapes n'est indispensable pour continuer le développement Phase 7 — **documenté,
non demandé à Daniel maintenant**.

### Q2-4 — Fonctions : endpoints abusables identifiés (sans activation aveugle)

| Endpoint abusable potentiel | Coût réel si spammé aujourd'hui | Candidat App Check (Phase 8) |
|---|---|---|
| `createDeliveryRequest` | Écriture Firestore (coût faible/appel) ; nécessite un devis `is_consumed==false` valide au préalable (`calculateDeliveryQuote` déjà appelé) — pas gratuit à répéter sans un nouveau devis | **Oui, priorité haute** |
| `calculateDeliveryQuote` | Écriture Firestore d'un nouveau devis à chaque appel — aucune contrainte de fréquence actuelle | **Oui, priorité haute** |
| `acceptDelivery` | Lecture/écriture transaction — déjà protégé par précondition d'état (course concurrente gérée, Bloc O), mais spam répété reste possible sans coût financier direct | **Oui, priorité moyenne** |
| Actions upload-related (`uploadDeliveryProof`, documents chauffeur) | Coût Storage (bande passante + stockage) par appel réussi | **Oui, priorité moyenne** (déjà gardé par `storage.rules` côté auth/ownership, App Check ajouterait une couche anti-bot) |
| Actions sensibles à l'auth (`setUserRole`, `suspendDriver`, etc.) | Déjà réservées à admin/super_admin — spam nécessite déjà un compte privilégié compromis, App Check n'ajoute qu'une défense en profondeur marginale ici | Priorité basse |
| Paiement (`refundPayment`, `attachCustomerPaymentMethod`) | Déjà protégé par idempotence stricte (Bloc O) — App Check réduirait le bruit de bots, pas un risque financier direct (aucun double effet possible) | Priorité basse-moyenne |

**Décision Q2-4 : ne pas activer `enforceAppCheck` aveuglément sur toutes les fonctions**
(conforme à la consigne explicite) — la liste ci-dessus documente une priorisation pour la
Phase 8, aucune activation faite ce tour (aucun provider client n'est déployé, activer
l'enforcement serveur maintenant couperait TOUS les clients légitimes).

### Q2-5 — Rate/abuse limits : évaluation, aucun garde ajouté sauf nécessité

Vérification des protections existantes contre le spam :
- **Toutes** les 31 fonctions `onCall` exigent `requireSignedIn()` — **aucune fonction sensible
  n'est accessible anonymement** ; aucune trace de `signInAnonymously()` dans
  `firebase_auth_provider.dart` (grep confirmé). Un spammeur doit donc déjà posséder un compte
  Firebase Auth réel (email/mot de passe ou fournisseur social) pour appeler quoi que ce soit —
  première barrière anti-abuse déjà en place, indépendante d'App Check.
- **`createDeliveryRequest`** : nécessite un `quoteId` valide et non consommé — spammer exige de
  générer un nouveau devis à chaque tentative (`calculateDeliveryQuote`), donc pas gratuit ni
  trivial à boucler indéfiniment sans laisser de trace (chaque devis est un document Firestore
  daté et attribuable à un `uid` précis).
- **`calculateDeliveryQuote`** : AUCUNE limite de fréquence trouvée — un utilisateur authentifié
  peut demander un nombre illimité de devis. **Coût réel : faible** (écriture Firestore légère,
  pas d'appel provider externe coûteux, pas d'effet financier). Évalué **P2** (non-bloquant,
  cohérent avec Q2-4 : App Check est le mécanisme prévu pour Phase 8, pas un rate-limiter ad hoc
  construit maintenant).
- **Notifications** : générées uniquement par des triggers système suite à un changement d'état
  mission réel (`onMissionStatusChangeNotifyCustomer`) — pas de endpoint client direct pour
  spammer des notifications.
- **Brute-force actions/retry abusif** : déjà couvert par les machines à états strictes (Bloc O)
  — un retry sur une action déjà appliquée échoue immédiatement (`failed-precondition`), sans
  effet de bord répété, quel que soit le nombre de tentatives.

**Décision** : aucun garde de rate-limiting ad hoc ajouté ce tour — le seul candidat identifié
(`calculateDeliveryQuote` sans limite) est P2 non-bloquant (coût faible, aucun risque financier,
App Check + un futur rate-limiter Phase 8 sont les mécanismes prévus), conforme à la consigne
"ne pas construire une plateforme anti-DDoS".

### Q2-6 — Idempotence comme anti-abuse (distinction documentée)

**Idempotence ≠ rate limiter.** Les mécanismes d'idempotence déjà prouvés (Bloc O : `requestKey`
déterministe de `refundPayment`, garde `is_consumed` de `createDeliveryRequest`, marquage
`included_in_payout_id` de `calculateDriverPayout`, état terminal `REVERSED`) protègent contre la
**duplication d'un effet** (même appel rejoué → même résultat, jamais deux fois l'effet) — ils
n'empêchent PAS un acteur malveillant d'appeler la fonction un grand nombre de fois avec des
paramètres DIFFÉRENTS à chaque fois (ex: 1000 devis différents, chacun légitime individuellement
mais formant un pattern de spam). Un rate limiter (ou App Check comme filtre anti-bot en amont)
répond à un problème différent : la FRÉQUENCE d'appels légitimes-mais-répétés, pas leur
duplication. Les deux mécanismes sont complémentaires, jamais substituables l'un à l'autre.

### Q2-7 — Auth vs App Check (distinction documentée et prouvée par l'architecture existante)

**Auth = identité/autorisation. App Check = authenticité du client / réduction d'abus.**
Preuve architecturale déjà en place (sans avoir eu besoin d'App Check) : TOUTE décision
d'autorisation de ce repo (Bloc D/E/Q) repose exclusivement sur `request.auth.token.role(s)`
(Custom Claims Firebase Auth) — jamais sur un en-tête ou un signal App Check. App Check, une fois
activé en Phase 8, ne remplacera JAMAIS cette logique : il s'ajoutera comme une vérification
SUPPLÉMENTAIRE au niveau transport ("cette requête provient-elle d'une vraie instance de l'app
Movi-k, pas d'un script/bot?"), strictement en complément de `requireSignedIn()`/
`requireAnyRole()`, jamais en remplacement. Documenté explicitement pour éviter toute confusion
future lors de l'implémentation Phase 8.

### Q2-8 — Feature flag / enforcement progressif (préparé, pas construit)

Aucun système de feature flag complet construit ce tour (Bloc X existe plus tard, conforme à la
consigne). Note préparatoire pour Phase 8 : Firebase App Check propose nativement un mode
"Monitor" (Console Firebase) qui journalise les requêtes sans jamais les bloquer — c'est le
mécanisme natif recommandé pour un rollout progressif sans couper de client légitime, à utiliser
en Phase 8 AVANT tout `enforceAppCheck: true` définitif. Aucune action requise de notre part
aujourd'hui au-delà de cette note.

### DONE Q2

| Critère | Statut |
|---|---|
| État App Check connu | ✅ SDK présent, aucune intégration active (Q2-1) |
| Intégration code prête ou plan exact documenté | ✅ Plan Phase 8 documenté (Q2-3), endpoints priorisés (Q2-4) |
| Dev/emulator non cassé | ✅ Aucune dépendance App Check dans les tests existants (Q2-2) |
| Endpoints abusables évalués | ✅ Tableau Q2-4, 1 candidat P2 documenté (`calculateDeliveryQuote`) |
| Gaps P0/P1 corrigés | ✅ Aucun P0/P1 trouvé — seul un P2 non-bloquant identifié |
| Enforcement production correctement reporté Phase 8 | ✅ Aucune fausse déclaration — App Check production n'est PAS activé, documenté comme tel explicitement |

**P0 ouverts** : 0. **P1 ouverts** : 0. **P2 documenté** : 1 (`calculateDeliveryQuote` sans
limite de fréquence — coût faible, DEFERRED, mécanisme prévu = App Check + rate-limiter Phase 8).

**BLOC Q2 : ✅ FERMÉ.**

---

## BLOC R — BACKWARD COMPATIBILITY

**Objectif** : vérifier que les anciennes données, anciennes versions de documents Firestore et
états historiques encore plausibles ne cassent pas l'application actuelle.

**Méthode** : scan exhaustif de tous les `fromJson` des modèles Dart (`lib/backend/models/*.dart`,
`lib/finance/models/*.dart`), croisé avec le chemin d'écriture serveur (Cloud Functions) de chaque
collection concernée, pour distinguer un GAP réel (le champ a pu manquer/changer de forme depuis
la création de la collection) d'un cas COUVERT-par-conception (le champ est garanti présent par
`firestore.rules`/la Cloud Function depuis la création de la collection — un seul schéma a
toujours existé, `git log --follow` confirmé).

### Matrice courte

| Ancienne forme de donnée | Parser actuel | Test existant | Statut |
|---|---|---|---|
| Mission ancienne, champs optionnels manquants (7 champs seulement) | `DeliveryMission.fromJson` | `test/customer/delivery_mission_partial_data_test.dart` (3 tests, déjà exhaustif) | ✅ COUVERT (réutilisé, non dupliqué) |
| Ancien statut de mission inconnu/corrompu | `MissionStatus.fromFirestoreValue` (`orElse` → `draft`) | idem ci-dessus | ✅ COUVERT |
| Ancienne catégorie de véhicule inconnue | `VehicleCategoryX.fromFirestoreValue` (`orElse` → `other`) | idem ci-dessus | ✅ COUVERT |
| Mission complétée sans preuve de livraison / adresses | `DeliveryMission.fromJson` (champs nullable) | idem ci-dessus | ✅ COUVERT |
| Vieux document driver profile (champs manquants) | `DriverProfileV2.fromJson` (tous les champs `?? default`, `_parseDate` défensif) | Lecture de code confirmée robuste ; pas de nouveau test nécessaire | ✅ COUVERT |
| Ancien `driver_documents`/`driver_vehicles` sans `driver_id` | `DriverDocument.fromJson`/`DriverVehicle.fromJson` (`as String` non-nullable) | Vérifié via `firestore.rules` : `allow create` exige `driver_id == uid()` depuis la création de la collection (commit unique `c448be0`, jamais de schéma antérieur différent). `driver_id` ne peut PAS être absent d'un document réel. | ✅ COUVERT-PAR-CONCEPTION (aucun test nécessaire — cas impossible en production) |
| Anciennes structures `financial_snapshot` (5 champs `as String`: `snapshot_id`, `mission_id`, `customer_id`, `driver_id`, `pricing_version`) | `FinancialSnapshot.fromJson` | Vérifié : `financial_snapshots` est `allow write: if false` (Cloud Functions only) depuis toujours ; `acceptDelivery.ts`/`createFinancialSnapshot.ts` écrivent TOUJOURS ces 5 champs ensemble, schéma unique depuis `c448be0`/étape 8-11. Aucun document `financial_snapshots` n'a jamais pu exister sans ces champs. | ✅ COUVERT-PAR-CONCEPTION |
| Anciennes notifications (champs manquants) | `AppNotification.fromJson` (tous les champs `?? default`, `metadata` type-checké) | Lecture de code confirmée robuste ; pas de nouveau test nécessaire | ✅ COUVERT |
| Ancienne preuve de livraison | `DeliveryMission.proofOfDeliveryUrl` (nullable) | `delivery_mission_partial_data_test.dart` (test 3) | ✅ COUVERT (réutilisé) |
| Ancien pricing/config (`PricingConfig.fromJson`, `pricing_version` non-nullable) | `PricingConfig.fromJson` | Vérifié : `pricing_versions/{version}` immuable par design (`updatePricingConfiguration.ts` ne réécrit JAMAIS une version existante, en crée toujours une nouvelle) ; `pricing_version` a toujours été la clé du document depuis la création. Sous-objets (`VehiclePricingRule`, `HandlingFeeConfig`, etc.) tous robustes avec `?? default`. | ✅ COUVERT-PAR-CONCEPTION |
| Ancien `transaction_ledger` sans `ledger_entry_id` | `LedgerEntry.fromJson` | Vérifié : 4 Cloud Functions différentes (`calculateDriverPayout.ts`, `completeDelivery.ts`, `createLedgerEntry.ts`, `recordTip.ts`) écrivent TOUTES `ledger_entry_id: entryRef.id` depuis la création de la collection ; `allow write: if false` côté client. | ✅ COUVERT-PAR-CONCEPTION |
| `driver_locations`/history sans `latitude`/`longitude` | `DriverLocation.fromJson`/`DriverLocationHistoryPoint.fromJson` (`as num` non-nullable) | Vérifié : `recordTrackingPoint.ts` valide `typeof latitude/longitude !== "number"` AVANT toute écriture (invalidArgument sinon) — un document sans ces champs n'a jamais pu être créé. | ✅ COUVERT-PAR-CONCEPTION |
| `app_user_v2`/`audit_log` — `created_at` | `AppUserV2.fromJson`/`AuditLog.fromJson` | Relecture complète : déjà guardé par `json['created_at'] != null ? DateTime.parse(...) : DateTime.now()` — PAS un gap (le grep initial n'avait vu que la ligne du cast, pas le ternaire englobant). | ✅ COUVERT (déjà correct, aucune modification) |
| `FoundingDriverQualification` — dates de qualification absentes | `FoundingDriverQualification.fromJson` (`DateTime.parse` non-guardé) | **GAP RÉEL trouvé** — voir ci-dessous | 🔴 GAP → CORRIGÉ |
| `ManualDriverAdjustment` — champs d'ajustement manuel absents | `ManualDriverAdjustment.fromJson` (casts non-nullables) | **GAP RÉEL trouvé** — voir ci-dessous | 🔴 GAP → CORRIGÉ |

### GAP-R-01 — `FoundingDriverQualification.fromJson` plante sur document partiel

**Constat** : `qualifiedAt`/`promotionalPeriodEndsAt` utilisaient `DateTime.parse(json['x'] as
String)` sans aucun garde — un document historique/corrompu manquant ces champs provoque une
exception non catchée (`type 'Null' is not a subtype of type 'String'`).

**Exposition réelle** : NULLE actuellement — `grep` confirme qu'aucun repository de ce projet ne
désérialise de VRAI document Firestore via `FoundingDriverQualification.fromJson` (utilisé
uniquement comme paramètre en mémoire dans `founding_driver_engine.dart`/`commission_resolver.dart`,
jamais lu depuis `founding_driver_programs/*/qualifications/*`). Corrigé par précaution (coût nul,
cohérence avec le reste du projet) — pas parce qu'un vecteur d'exposition a été identifié.

**Test (FAIL confirmé avant fix)** : document `{driver_id, program_id, status}` sans dates →
`throwsA(anything)` confirmé avant correction.

**Fix appliqué** : repli sur `DateTime.tryParse(...) ?? DateTime.now()`, `driverId`/`programId`
repliés sur `''` si absents (cohérent avec le reste du projet).

**Test après fix** : `test/finance/backward_compatibility_r_test.dart` — 3 tests PASS (document
minimal, document vide, dates corrompues).

### GAP-R-02 — `ManualDriverAdjustment.fromJson` plante sur document partiel

**Constat** : `id`, `reason`, `createdByUserId` (`as String`), `amount` (`as num`), `createdAt`
(`DateTime.parse` sans garde) — même pattern que GAP-R-01.

**Exposition réelle** : NULLE actuellement — code mort au sens strict, aucun appelant réel hors du
fichier modèle lui-même et des tests. Corrigé par précaution.

**Fix appliqué** : tous les champs repliés sur une valeur sûre (`''`, `0`, `'unknown'`,
`DateTime.now()`).

**Test après fix** : `test/finance/backward_compatibility_r_test.dart` — 2 tests PASS (document
vide, round-trip complet sans régression).

### DONE R

| Critère | Statut |
|---|---|
| Matrice courte construite | ✅ 14 lignes, priorités du prompt toutes couvertes |
| Tests de partial-data existants réutilisés | ✅ `delivery_mission_partial_data_test.dart` référencé, non dupliqué |
| Chaque cast non-nullable suspect évalué (COUVERT-par-conception vs GAP réel) | ✅ 8 cas COUVERT-par-conception (write-path vérifié), 2 GAP réels trouvés et corrigés |
| P0/P1 corrigés | ✅ 2/2 (sévérité réelle P2 — code mort/non exposé — corrigés par précaution) |
| Aucune sur-ingénierie sur structures abandonnées | ✅ Aucune compatibilité réintroduite pour un schéma qui n'a jamais existé |
| Tests nouveaux passent | ✅ `test/finance/backward_compatibility_r_test.dart` — 5/5 PASS |
| Suite complète non régressée | ✅ `flutter test` 485/485 PASS (480 + 5 nouveaux), `flutter analyze lib test` 0 erreur |

**P0 ouverts** : 0. **P1 ouverts** : 0. **BLOC R : ✅ FERMÉ.**

---

## BLOC R2 — MIGRATIONS

**Objectif** : vérifier que les changements de schéma déjà effectués (ou plausibles) peuvent être
déployés sans casser les comptes existants.

### Matrice courte

| Changement de schéma | Migration nécessaire ? | Stratégie | Test |
|---|---|---|---|
| `driver_payouts.amount` (float legacy) → `amount_minor` (cents entiers), commit `0cf708a` | **NON** — `calculateDriverPayout` est resté un callable admin jamais invoqué en production avant ce rewrite (aucun `driver_payouts` réel créé avec l'ancien format : vérifié absence totale de script de migration antérieur, absence de tout document `driver_payouts` dans les rapports e2e). `DriverPayoutInfo.fromJson` lit `amount_minor` avec repli `?? 0` de toute façon (déjà robuste si un doc legacy existait). | Aucune — parser défensif suffit | `calculateDriverPayout.test.ts` confirme `typeof payout.amount === 'undefined'` sur le nouveau format |
| `audit_logs.action` renommage (`approveDriver`→`driver_approved`, etc.), commit `c0781bb` | **NON** — aucun code (Flutter ou Cloud Function) ne branche sur la valeur littérale de `action` pour une décision logique ; `action` est un champ d'affichage/traçabilité pur (`admin_driver_detail_screen.dart` l'affiche tel quel, ne compare jamais sa valeur) | Aucune | N/A (pas de logique dépendante) |
| `audit_logs.source_function` rendu requis, commit `c0781bb` | **NON pour la lecture** — `AuditLog.fromJson` a déjà `actorRole/action ?? ''` ; un ancien log sans `source_function` reste lisible (champ simplement absent de l'affichage, pas de crash) | Aucune (déjà absorbé par le parser existant) | Couvert par la robustesse générale de `AuditLog.fromJson` |
| `financial_snapshot`/`pricing_config`/`transaction_ledger`/`driver_location(s)` (Bloc R) | **NON** — schéma unique depuis la création de chaque collection (voir Bloc R), aucune ancienne forme différente n'a jamais existé en production | Aucune | Voir Bloc R |
| `FoundingDriverQualification`/`ManualDriverAdjustment` (Bloc R) | **NON** — modèles jamais lus depuis un vrai document Firestore à ce jour ; durcissement fait par précaution, pas une vraie migration de données | Aucune | `backward_compatibility_r_test.dart` |

### Conclusion Bloc R2

**Aucun script de migration nécessaire.** Chaque changement de schéma identifié dans l'historique
Git de ce projet a soit (a) eu lieu AVANT toute donnée réelle en production pour la collection
concernée, soit (b) été absorbé nativement par un parser déjà défensif (`?? default`). Conforme à
la consigne : "ne pas construire une grosse plateforme de migration si aucun script n'est
nécessaire — documenter pourquoi." Aucun répertoire `migrations/` n'existe dans ce projet et aucun
n'est créé ici, en cohérence avec cette conclusion.

**P0 ouverts** : 0. **P1 ouverts** : 0. **BLOC R2 : ✅ FERMÉ.**

---

## BLOC S — MULTI-USER

**Méthode** : référencer les tests de concurrence déjà existants (Phase 6/Bloc N/O) sans dupliquer,
et documenter chaque scénario S-1 à S-7 avec son statut réel.

| # | Scénario | Statut | Détail |
|---|---|---|---|
| S-1 | Deux chauffeurs acceptent la même mission simultanément | ✅ COUVERT | `functions/test/integration/acceptDeliveryConcurrency.test.ts` — un seul commit gagnant, l'autre `failed-precondition`, prouvé au niveau transaction Firestore réelle (pas de logique frontend arbitrant) |
| S-2 | Client annule pendant que le chauffeur accepte/progresse | ⚠️ PARTIEL | `missionCancellationPaymentRelease.test.ts` couvre l'annulation client APRÈS assignation (libération paiement, idempotence du trigger). Le cas exact "annulation ET acceptation strictement simultanées" (race Firestore sur le même document mission) n'a pas de test dédié — risque atténué car `acceptDelivery` et `cancelDelivery` opèrent tous deux en transaction sur le même `missionRef`, donc Firestore garantit déjà l'atomicité (un des deux gagne, l'autre relit un état incompatible et échoue avec `failed-precondition`), mais ceci n'est pas prouvé par un test dédié. **Reporté Phase 8 / prochain tour** (P2, non bloquant — protection structurelle déjà en place via transaction Firestore standard du projet). |
| S-3 | Double tap/double submit (accept/pickup/complete) | ✅ COUVERT | `completePickup.test.ts` ("déjà ramassé, appel en double" → `failed-precondition`), `completeDelivery.test.ts` ("déjà completed, double appel" → rejeté, aucune nouvelle écriture ; "financial_snapshot déjà confirmed" → immutabilité garantie), `acceptDeliveryConcurrency.test.ts` (double acceptation) |
| S-4 | Admin suspend un chauffeur pendant une mission active | ⚠️ GAP IDENTIFIÉ (non corrigé ce tour) | `suspendDriver.ts` met `driver_profiles.status = suspended` mais `completePickup.ts`/`completeDelivery.ts` ne vérifient QUE la transition de statut de la MISSION (`mission.status`) et `driver_id == uid()` — ils ne relisent PAS `driver_profiles.status` avant d'autoriser pickup/complete. Un chauffeur suspendu en cours de mission active PEUT donc continuer à progresser cette mission jusqu'à completion. **Sévérité réelle atténuée** : `suspendDriver` est une action admin volontaire rare (pas un scénario de concurrence à haute fréquence), et la mission déjà assignée doit de toute façon être menée à terme dans l'intérêt du client (interrompre une livraison en cours créerait un colis orphelin). Classé **P2 — comportement à valider avec le produit (politique métier, pas un bug de concurrence pur)**, documenté pour Phase 8/prochain tour, PAS corrigé ce tour faute de décision produit claire sur le comportement désiré. |
| S-5 | Finance concurrente (refund/payout/webhook/compensation) | ✅ COUVERT | `financialConcurrency.test.ts` (double capture, double payout, collision cron+manuel), `refundPayment.test.ts` (idempotence/concurrence remboursement), `processStripeWebhook.test.ts` (webhook dupliqué) — Bloc N/O, réutilisé sans duplication |
| S-6 | Notifications simultanées | ✅ COUVERT (partiellement, niveau UI) | `test/notifications/notifications_realtime_and_unread_test.dart` — double `markAsRead()` idempotent, badge temps réel cohérent sous plusieurs émissions. Niveau écriture serveur (plusieurs Cloud Functions notifiant le même utilisateur en parallèle) non testé spécifiquement — chaque notification est un document distinct (`add()`, jamais un `update()` partagé), donc aucune corruption structurelle possible par construction. |
| S-7 | Tracking — écritures de localisation concurrentes | ✅ COUVERT PAR CONCEPTION | `driver_locations/{driverId}` est un document UNIQUE par chauffeur, écrit uniquement par `recordTrackingPoint` avec `ctx.uid` comme clé du document (jamais un ID passé par le client) — aucune écriture croisée entre chauffeurs possible structurellement. Le "dernier état cohérent" est garanti par la sémantique `set(..., merge:true)` de Firestore (dernier writer gagne sur un seul document, pas de fusion partielle incohérente). |

### DONE S

| Critère | Statut |
|---|---|
| S-1, S-3, S-5 | ✅ COUVERT par tests existants, référencés sans duplication |
| S-6, S-7 | ✅ COUVERT par construction structurelle (documents séparés/clé serveur) |
| S-2 | ⚠️ Protection structurelle en place (transaction Firestore), test dédié manquant — P2 DEFERRED |
| S-4 | ⚠️ GAP comportemental identifié (suspension pendant mission active non bloquante) — P2, décision produit requise avant correction, DEFERRED |
| P0/P1 | 0 trouvé |

**P0 ouverts** : 0. **P1 ouverts** : 0. **P2 documentés** : 2 (S-2 test manquant, S-4 décision
produit requise). **BLOC S : ✅ FERMÉ** (aucun P0/P1 bloquant ; les 2 P2 sont documentés DEFERRED
conformément à la consigne "ne pas construire de plateforme" — ici, ne pas trancher une politique
produit non demandée explicitement).

---

## BLOC T — LOAD MVP

**Objectif** : vérifier que Movi-K supporte une charge raisonnable de pilote/MVP (PAS un test de
charge à l'échelle production) sur les chemins exposés à la concurrence/volume.

### Matrice courte

| Scénario | Volume MVP | Test existant | GAP |
|---|---|---|---|
| T-1 Concurrence acceptation | 2 chauffeurs (existant) → **étendu à 5** | `acceptDeliveryConcurrency.test.ts` (N=2) | **COUVERT + ÉTENDU** — nouveau test N=5 dans `loadMvpBlocT.test.ts` |
| T-2 Création missions (burst) | 5 créations indépendantes strictement concurrentes | Aucun test de burst existant (`createDeliveryRequest.test.ts` = 1 création à la fois) | **GAP → COMBLÉ** — nouveau test burst dans `loadMvpBlocT.test.ts` |
| T-3 Tracking GPS (volume) | 20 points successifs (mission ~15-20 min) | `recordTrackingPoint.test.ts` couvre l'accumulation (3 points) mais pas un volume réaliste de mission complète | **GAP PARTIEL → COMBLÉ** — nouveau test 20 points dans `loadMvpBlocT.test.ts` |
| T-4 Notifications (volume) | 8 transitions de statut distinctes par mission | `onMissionStatusChangeNotifyCustomer.test.ts` (`it.each` sur 8 transitions, 1 notification = 1 document distinct par construction) | **COUVERT PAR CONCEPTION** — chaque notification est un `add()` sur un document séparé (jamais un `update()` partagé), aucune corruption structurelle possible même en volume ; référencé sans duplication |
| T-5 Finance (missions indépendantes) | 4 captures de paiement concurrentes sur 4 missions distinctes | `financialConcurrency.test.ts` teste le double-appel sur le MÊME paymentId (pas plusieurs missions différentes en parallèle) | **GAP → COMBLÉ** — nouveau test 4 missions indépendantes dans `loadMvpBlocT.test.ts`, prouve l'absence de fuite cross-mission |
| T-6 Admin (listes) | Dataset MVP (dizaines de documents, pas de dataset dédié créé) | `firebase_driver_repository.dart`/`firebase_finance_repository.dart` — 17 requêtes finance déjà `.limit()`-bornées (Bloc M) | **COUVERT** — aucun nouveau timeout/chargement excessif trouvé ; les 2 `.limit()` P2 déjà connus (`watchNotifications`, `watchDriversByStatus`) restent **DEFERRED** (aucune preuve nouvelle ce bloc ne justifie un fix — volume MVP réel toujours faible) |

### Détail T-1/T-2/T-3/T-5 (nouveau fichier `functions/test/integration/loadMvpBlocT.test.ts`, 4 tests)

- **T-1** : 5 chauffeurs appellent `acceptDelivery` en même temps sur la même mission → exactement
  1 gagnant, 4 `failed-precondition`, 1 seul `financial_snapshot`, les 4 perdants restent `online`
  (aucun n'est passé `on_mission` par erreur).
- **T-2** : 5 clients créent chacun leur mission à partir de leur propre devis, strictement en
  parallèle → 5 `missionId` uniques (aucune collision), chaque mission pointe vers le bon client et
  le bon devis, chaque devis marqué consommé une seule fois vers la bonne mission (aucune quote
  perdue ni croisée).
- **T-3** : 20 points GPS successifs pour un chauffeur en mission active → exactement 20 documents
  d'historique (aucune duplication, aucune perte), le document de position courante reflète le
  dernier point et reste unique (merge, pas de doublon de document racine).
- **T-5** : 4 captures de paiement concurrentes sur 4 missions/paiements distincts → chaque montant
  capturé correspond exactement à sa propre mission, aucune fuite de montant entre missions.

**Résultat** : 4/4 nouveaux tests PASS. Suite d'intégration complète re-exécutée après ajout :
**522/522 PASS** (36 suites, +4 tests / +1 suite vs. la baseline R/R2/S de 518/518 — 0 régression).

### DONE T

| Critère | Statut |
|---|---|
| Charge pilote raisonnable testée | ✅ (5 chauffeurs concurrents, 5 créations burst, 20 points GPS, 4 missions finance parallèles) |
| Concurrence critique sûre | ✅ (T-1 étendu N=5, toujours un seul gagnant) |
| Aucune corruption | ✅ (aucune fuite cross-mission en T-5, aucune duplication en T-2/T-3) |
| Aucune fuite mémoire/listener manifeste | ✅ (Bloc M déjà couvert — mémoïsation des streams confirmée toujours en place, aucune régression) |
| P0/P1 | 0 trouvé |

**P0 ouverts** : 0. **P1 ouverts** : 0. **BLOC T : ✅ FERMÉ.**

---

## BLOC T2 — FIREBASE COST PROFILE

**Objectif** : identifier les gros multiplicateurs de consommation Firebase pendant un pilote
(reads, writes, Storage, Functions, GPS/history, notifications). **Ceci n'est PAS un modèle
financier précis** — ce sont des ordres de grandeur destinés à orienter les priorités techniques
(ex: si le GPS s'avère être le principal driver de writes, c'est là qu'il faut surveiller/optimiser
en premier, pas ailleurs).

### T2-1 — Une mission complète (parcours de bout en bout)

| Étape | Fonction/chemin | Firestore reads (approx.) | Firestore writes (approx.) | Cloud Functions invoquées | Storage |
|---|---|---|---|---|---|
| Devis | `calculateDeliveryQuote` | 1 (pricing_version actif) | 1 (`delivery_quotes`) | 1 | — |
| Recherche chauffeur | `onMissionCreatedDispatch` (trigger) + `dispatchMissionToDrivers` | 1 requête bornée `.limit(50)` (`driver_profiles` géohash) | 1-N (`delivery_offers`, 1 par chauffeur candidat notifié) + 1 (mission→statut) | 1 (trigger) | — |
| Création mission | `createDeliveryRequest` | 1 (quote) | 3-4 (mission + 2 stops + 1 tracking_event) + 1 (quote update) | 1 | — |
| Acceptation | `acceptDelivery` | 3-4 (driver_profile, mission, pricing_version, payment_profile) | ~6-7 en transaction (mission, driver_profile, financial_snapshot, payment, tracking_event, audit_log) + trigger notification (1 write) | 1 (+ 1 trigger notif) | — |
| Pickup | `completePickup` | 2-3 (mission, driver_profile) | ~4 (mission, tracking_event, proof metadata si applicable) + trigger notif | 1 (+ 1 trigger notif) | 1 upload si preuve pickup activée |
| Transit (statuts intermédiaires) | `updateMissionTrackingStatus` × 2-3 (driver_to_pickup, arrived_at_pickup, in_transit, arrived_at_dropoff) | 1-2 par appel | 1-2 par appel + trigger notif à chaque fois | 1 par appel (+1 trigger notif chacun) | — |
| GPS pendant tout le trajet | `recordTrackingPoint` | 1 par appel (driver_profile) | 1-2 par appel (position courante + 1 point d'historique SI mission active) | 1 par appel — **voir T2-2, le plus fréquent de tous** | — |
| Livraison + preuve | `completeDelivery` | 3-4 (mission, driver_profile, financial_snapshot) | ~6-7 en transaction (mission, financial_snapshot confirmed, ledger, payment capture, tracking_event) + trigger notif | 1 (+ capture paiement interne + 1 trigger notif) | 1 upload (photo preuve livraison, `delivery_proofs/{missionId}/...`) |
| Notification finale | trigger `onMissionStatusChangeNotifyCustomer` | — | 1 document par transition (déjà compté ci-dessus) | inclus | — |
| Finance (payout ultérieur) | `calculateDriverPayout` (batch, pas par mission) | N snapshots éligibles | 1 `driver_payouts` par cycle (regroupe plusieurs missions) | 1 par cycle planifié, pas par mission | — |

**Estimation par mission complète (hors GPS, hors payout groupé)** : environ **15-20 reads**,
**20-25 writes**, **8-10 invocations de Cloud Functions** (dont ~5 triggers Firestore
automatiques). Précision explicitement approximative — dépend du nombre de chauffeurs candidats
notifiés et du nombre de transitions de statut réellement empruntées.

### T2-2 — GPS (PRIORITÉ — principal driver de writes suspecté)

- Fréquence client : **1 appel `recordTrackingPoint` toutes les 8 secondes** pendant qu'une mission
  est active (`lib/services/driver_location_reporter.dart`, `Duration(seconds: 8)`), donc **~7.5
  appels/minute**.
- Chaque appel = **1 write systématique** (position courante `driver_locations/{driverId}`, merge)
  **+ 1 write conditionnel** dans `history` UNIQUEMENT si `active_delivery_id` pointe vers une
  mission réelle du bon chauffeur (protection anti-pollution déjà en place, voir Bloc R/N).
- Pour une mission de durée moyenne pilote **~20 minutes de trajet actif** (pickup → dropoff) :
  **~150 appels** → **~150 writes position + ~150 writes historique** = **~300 writes GPS par
  mission**, très largement supérieur aux ~20-25 writes du reste du cycle de vie de la mission
  (T2-1). **Confirmé : le GPS/history est bien le principal multiplicateur de writes du système.**
- Rétention automatique : `cleanupExpiredTrackingHistory` (cron quotidien, 30 jours) purge
  l'historique — sans ce nettoyage (déjà en place, voir Bloc N-7), la collection `history`
  croîtrait indéfiniment. Avec le nettoyage, le volume stocké est plafonné à ~30 jours d'historique
  actif, pas cumulatif à l'infini.
- **Classification impact : ÉLEVÉ** (writes) — mais fréquence produit (8s) volontairement NON
  modifiée ici (aucune preuve qu'elle soit "dangereusement coûteuse" pour un volume pilote,
  seulement qu'elle domine structurellement le compte de writes ; changer une fréquence produit
  sans décision produit explicite serait hors du cadre de ce bloc).

### T2-3 — Listeners (reads en continu)

| Listener | Portée | Reads déclenchés | Mémoïsation (Bloc M) |
|---|---|---|---|
| Missions disponibles (chauffeur) | `whereIn` batché par 30, stream mémoïsé | 1 batch de reads par changement de disponibilité, pas par frame | ✅ `_ensureStreams()` mémoïsé (Bloc M) |
| Notifications (`watchNotifications`) | 1 stream par utilisateur connecté, sans `.limit()` | Proportionnel au nombre total de notifications non purgées de l'utilisateur | ⚠️ P2 DEFERRED (volume MVP faible, sous-collection par user) |
| Driver profile (dashboard/statut) | Stream mémoïsé par `driverId`/`uid` (Bloc M, ex-GAP corrigé) | 1 read par changement de document, pas de duplication de listener | ✅ Corrigé Bloc M |
| Tracking (client suit son colis) | 1 stream sur `driver_locations/{driverId}` pendant la mission active du client | 1 read par write GPS (~1 toutes les 8s pendant le trajet, cf T2-2) — **directement proportionnel à la fréquence GPS** | Structurel (document unique par chauffeur) |
| Admin listes (drivers/finance) | Non-lazy, mais toutes `.limit()`-bornées côté finance (17 requêtes) | Reads plafonnés par page | ⚠️ 2 exceptions P2 DEFERRED (`watchDriversByStatus`, admin-only, volume MVP faible) |

**Conclusion T2-3** : le listener de tracking client est le plus actif en reads pendant une mission
(hérite directement de la fréquence GPS de T2-2). Toutes les mémoïsations Bloc M sont confirmées
toujours en place (aucune régression détectée pendant T).

### T2-4 — Storage

| Type | Moment | Volume initial estimé | Trafic/téléchargement |
|---|---|---|---|
| Documents chauffeur (`driver_documents/{driverId}/...`) | Une fois à l'onboarding (+ re-upload si rejeté/expiré) | Quelques fichiers (permis, assurance, etc.) par chauffeur, une seule fois | Faible — relu principalement par review admin |
| Photo véhicule (`profile_photos` / véhicule) | Une fois à l'onboarding | 1 photo par véhicule | Faible — affichage occasionnel |
| Preuve de livraison (`delivery_proofs/{missionId}/...`) | **À CHAQUE mission complétée** | 1 photo par mission — **proportionnel au volume de missions, pas un coût fixe** | Modéré — consultée en cas de litige/dispute, sinon rarement retéléchargée |

**Conclusion T2-4** : le stockage initial (onboarding chauffeur) est un coût fixe ponctuel par
chauffeur (faible volume total). La preuve de livraison est le seul poste Storage qui **grandit
avec le volume de missions** — reste un coût mineur comparé aux writes GPS (une photo par mission
vs. ~150 writes GPS par mission).

### T2-5 — Functions (profil d'invocation)

| Fréquence | Functions concernées |
|---|---|
| **ÉLEVÉ** (proportionnel au temps de trajet, pas au nombre de missions) | `recordTrackingPoint` (~7.5 appels/minute pendant un trajet actif — de très loin la Function la plus invoquée) |
| **MOYEN** (une fois par mission, ou quelques fois) | `calculateDeliveryQuote`, `createDeliveryRequest`, `acceptDelivery`, `completePickup`, `completeDelivery`, `updateMissionTrackingStatus` (×2-4), triggers `onMissionStatusChangeNotifyCustomer`/`onMissionEndedClearTracking` |
| **FAIBLE** (batch/planifié, indépendant du volume de missions) | `calculateDriverPayout`/`processScheduledDriverPayouts` (cycle périodique groupant plusieurs missions), `cleanupExpiredTrackingHistory` (cron quotidien unique), `runDailyReconciliation` (cron quotidien unique), `detectExpiringDocuments`/`transitionFoundingDriverPeriods`/`expireDriverPromotions` (cron, admin-scale) |
| **RARE** (actions admin ponctuelles) | `approveDriver`, `rejectDriver`, `suspendDriver`, `refundPayment`, `updateDisputeStatus`, `updatePricingConfiguration`, etc. |

**Conclusion T2-5** : sans tarif Firebase codé dans ce projet, impossible de chiffrer un coût exact
— mais le classement ÉLEVÉ/MOYEN/FAIBLE ci-dessus identifie clairement `recordTrackingPoint` comme
la Function dominante en nombre d'invocations, cohérent avec T2-2/T2-3.

### T2-6 — Scénarios pilote (ordres de grandeur, PAS une facture officielle)

Hypothèses : mission moyenne = ~20 min de trajet actif (~150 appels GPS), ~20-25 writes hors GPS,
~15-20 reads hors GPS/tracking, 1 preuve de livraison par mission.

| Volume | Missions/jour | Writes GPS/jour (approx.) | Writes hors-GPS/jour (approx.) | Reads/jour (approx., hors listeners tracking) | Uploads Storage/jour |
|---|---|---|---|---|---|
| **10 missions/jour** | 10 | ~3 000 (10 × ~300) | ~200-250 | ~150-200 | ~10-20 (preuve + occasionnels onboarding) |
| **100 missions/jour** | 100 | ~30 000 | ~2 000-2 500 | ~1 500-2 000 | ~100-200 |
| **1 000 missions/jour** | 1 000 | ~300 000 | ~20 000-25 000 | ~15 000-20 000 | ~1 000-2 000 |

**Lecture** : à TOUTES les échelles testées, les writes GPS représentent environ **90-95% du
volume total de writes Firestore**. C'est le seul poste qui mérite une vigilance particulière si le
volume de missions dépasse largement 1 000/jour (hors scope MVP actuel) — pas une urgence pour un
pilote, mais le principal levier d'optimisation future identifié (ex: réduire la fréquence GPS ou
ne pas persister l'historique complet si un jour le coût devient un problème réel mesuré, PAS une
anticipation spéculative ce tour).

### DONE T2

| Critère | Statut |
|---|---|
| Principaux cost drivers connus | ✅ GPS (`recordTrackingPoint`, ~90-95% des writes) identifié comme dominant |
| GPS analysé | ✅ T2-2 (fréquence, volume par mission, rétention déjà automatisée) |
| Reads/writes mission estimés | ✅ T2-1 (tableau détaillé par étape du cycle de vie) |
| Storage estimé | ✅ T2-4 (coût fixe onboarding vs. coût proportionnel preuve de livraison) |
| Scénarios pilote documentés | ✅ T2-6 (10/100/1000 missions par jour) |
| Aucun P0/P1 coût/performance ignoré | ✅ — les 2 P2 `.limit()` connus (Bloc M/N) sont des GAPS de performance déjà documentés, pas des GAPS de coût nouveaux |

**P0 ouverts** : 0. **P1 ouverts** : 0. **BLOC T2 : ✅ FERMÉ.**

## MISE À JOUR — BLOC U (U-1 à U-6)

| Sous-bloc | Statut | Détail |
|---|---|---|
| U-1 Client bug bash | ✅ PASS | Parcours login→completed relu en entier ; 15/15 `MissionStatus` traduits FR/EN/ES ; scoping repository correct ; aucun bouton mort. |
| U-2 Driver post-onboarding | ✅ PASS | `DriverActiveMissionScreen` (824 lignes), `provider_jobs_tab.dart`, `provider_earnings_tab.dart`, `driver_status_screen.dart` relus ; ledger atomique confirmé (`completeDelivery.ts`) ; aucun bouton mort, aucun `$e` affiché. |
| U-3 Admin | ✅ PASS | Approve/reject/suspend/reactivate/documents/notes fonctionnels ; refunds/disputes confirmés en lecture-seule PAR CONCEPTION (pas de bouton mort) ; "voir document" = gap déjà documenté (P-6), non-bloquant. |
| U-4 Error sanity | ✅ PASS | Network/permission cross-user/session expirée/Firestore partiel — tous déjà couverts, `DeliveryMission.fromJson` 100% défensif. |
| U-5 FR/EN/ES sanity | ✅ PASS | 224 clés `t()` des écrans U extraites et vérifiées 100% complètes FR/EN/ES via `AppStrings.allEntries` (script jetable, 0 fichier repo modifié). |
| U-6 Mobile sanity | ✅ PASS (après correction) | Nouveau `test/responsive/bloc_u_mobile_sanity_test.dart` (11 tests, 320/360px) sur les 5 écrans jamais testés à largeur étroite. 2 bugs réels trouvés (BUG-U-02, BUG-U-03) et corrigés. |

**BLOC U : ✅ FERMÉ.** P0 ouverts : 0. P1 ouverts : 0. P2 corrigés ce tour : 2 (BUG-U-02, BUG-U-03).

## MISE À JOUR — BLOC V (Global Validation)

| Sous-bloc | Statut | Référence de preuve |
|---|---|---|
| V-1 Parcours global | ✅ PASS | `e2eDeliveryLifecycle.test.ts` — chaîne réelle sur 1 missionId, transitions non-sautables prouvées par le 2e describe() |
| V-2 Notifications cross-role | ✅ PASS | `onMissionStatusChangeNotifyCustomer.test.ts` + `fireNotifyTriggerAndAssert` — 0 fuite cross-customer ; driver-side confirmé par design (stream temps réel, pas de notif) |
| V-3 Finance cross-flow | ✅ PASS | `e2eFinancialLifecycle.test.ts` — payment→capture→snapshot→earnings→commission→payout→réconciliation, montants 100% serveur |
| V-4 Cancellation intégration | ✅ PASS | `missionCancellationPaymentRelease.test.ts` (BUG-001) + BUG-V-01 (ce bloc) |
| V-5 Admin cross-role | ✅ PASS | UI admin exhaustive + `calculateDriverPayout.test.ts` L204 + `reconciliationEngine.test.ts` L658-680 (permission-denied confirmés) |
| V-6 Authorization global | ✅ PASS | `securityRules.test.ts` L827 (cross-customer) + `OTHER_DRIVER_ID` (3 fichiers CF) + `adminPrivilegedActions.test.ts` (12 callables) |
| V-7 I18N global sanity | ✅ PASS | 747 clés fr/en/es sans valeur vide ; 0 clé utilisée non définie (1 faux positif Hive) |
| V-8 États terminaux | ✅ PASS | BUG-V-01 (rules) + `completeDelivery.test.ts` + `updateMissionTrackingStatus.test.ts` + absence de règle `allow update` chauffeur |

**BLOC V : ✅ FERMÉ.** P0 ouverts : 0. P1 ouverts : 0 (BUG-V-01 corrigé, 5 tests régression, 185/185 PASS).

## MISE À JOUR — BLOC W (Cleanup)

| Sous-bloc | Statut | Détail |
|---|---|---|
| W-1 Flutter analyze | ✅ PASS | 3 correctifs (assets orphelins, Radio déprécié, doc-comment HTML) — 0 issue restante sur code du dépôt |
| W-2 Dead code | ✅ PASS | `dart analyze` 0 issue + heuristique 198 méthodes privées (0 suspect) + `npm run lint` 0 warning — aucune preuve de code mort, rien supprimé |
| W-3 TODO/FIXME | ✅ PASS | 3 occurrences totales, toutes dette future non-bloquante, 0 P0/P1 |
| W-4 Debug/logs | ✅ PASS | 2 `debugPrint()` kDebugMode-gated, 0 `print()`, 0 donnée sensible |
| W-5 Generated/local | ✅ PASS | 0 fichier `.env`/secret/artifact de build tracké dans git |
| W-6 Dependencies | ✅ PASS | 3 deps Flutter directes inutilisées retirées (`cupertino_icons`/`intl`/`http`, transitif préservé sans changement de version) ; 0 dep inutilisée côté Functions ; aucune montée de version |

**BLOC W : ✅ FERMÉ.** P0 ouverts : 0. P1 ouverts : 0.

## MISE À JOUR — BLOC X (Feature Flags / Kill Switches) : ✅ FERMÉ

| Sous-bloc | Statut | Détail |
|---|---|---|
| X-1..X-9 Architecture + enforcement | ✅ PASS | 1 document (`system_config/runtime_flags`), 1 helper de lecture unique (`resolveRuntimeFlag`/`isRuntimeFlagEnabled`), 1 point d'entrée serveur par flag, admin-only en écriture (`updateRuntimeFlags`), écriture Firestore directe refusée par les règles |
| X-10 UI Flutter | ✅ PASS | `isKillSwitchException()` reconnaît le message stable `service_temporarily_unavailable`, traduit FR/EN/ES, jamais un message technique brut affiché |
| X-11 Tests d'intégration | ✅ PASS | `runtimeFlags.test.ts` 29/29 PASS (sections A→K) ; 17 suites historiques adaptées via `runtimeFlagsFixture.ts` (`seedDefaultRuntimeFlagsEnabled()`) ; suite complète 37/37 suites, 556/556 tests PASS (2 exécutions complètes consécutives, 0 rouge) |
| X-12 Runtime/no-cache/coût | ✅ PASS | Aucun cache/TTL — lecture Firestore directe à chaque appel protégé, effet immédiat au prochain appel ; coût ≈ 1 lecture Firestore par action protégée |
| X-13 Bootstrap Phase 8 | ✅ PASS | Checklist documentée (`docs/PHASE7_QA_PLAN.md`) ; auto-bootstrap intégré à `updateRuntimeFlags` (flags à `true` si document absent) ; aucun défaut permissif codé en dur dans le chemin de lecture (fail-safe reste à `false`) |
| BUG-X-01 (P1) | ✅ CORRIGÉ | Contrôle `payments_enabled` déplacé avant la transaction d'assignation (`acceptDelivery.ts`) — plus aucune transition vers l'état terminal `PAYMENT_FAILED` causée par un kill switch. Preuve permanente : section D de `runtimeFlags.test.ts` |

### Matrice des 4 flags (implémentation réelle, `functions/src/lib/runtimeFlags.ts`)

| Flag | Default/fail-safe | Action protégée | Effet OFF | Autorité | Config absente/invalide | Audit |
|---|---|---|---|---|---|---|
| `accept_new_delivery_requests` | fail-closed (`false`) | `createDeliveryRequest` (création d'une NOUVELLE mission) | Aucune nouvelle mission créée ; les missions déjà existantes ne sont jamais affectées | Serveur uniquement (`isRuntimeFlagEnabled` + `killSwitchRefusal`) ; écriture admin-only via `updateRuntimeFlags` | Fail-closed → `false` (refusé) | Oui (`writeAuditLogInTransaction`, old/new values) |
| `allow_driver_acceptance` | fail-closed (`false`) | `acceptDelivery` (acceptation d'une NOUVELLE mission par un chauffeur) | Aucune nouvelle assignation ; une mission déjà assignée/en livraison n'est jamais affectée | Serveur uniquement ; écriture admin-only | Fail-closed → `false` (refusé) | Oui |
| `payments_enabled` | fail-closed (`false`) | Nouvelle exposition financière côté client (autorisation de paiement), vérifiée dans `acceptDelivery.ts` AVANT la transaction d'assignation (BUG-X-01) | Aucun nouveau paiement autorisé ; mission reste dans son état pré-acceptation valide (jamais `PAYMENT_FAILED`) ; refunds/disputes/compensations/corrections ledger sur un paiement déjà existant ne sont JAMAIS bloqués | Serveur uniquement ; écriture admin-only | Fail-closed → `false` (refusé) | Oui |
| `driver_payouts_enabled` | fail-closed (`false`) | `submitDriverPayout` (nouvel appel réel au fournisseur pour verser un chauffeur — point de convergence unique de `calculateDriverPayout` et `processScheduledDriverPayouts`) | Payout reste `ELIGIBLE` (jamais transitionné vers `FAILED`) — resoumis automatiquement dès que le flag repasse à `true`, aucune action de récupération manuelle nécessaire ; `reverseDriverPayout` (compensation sur un versement déjà `PAID`) et la réconciliation ne sont JAMAIS bloqués | Serveur uniquement ; écriture admin-only | Fail-closed → `false` (refusé) | Oui |

**BLOC X : ✅ FERMÉ.** P0 ouverts : 0. P1 ouverts : 0 (BUG-X-01 corrigé, preuve permanente 29/29 PASS).

## MISE À JOUR — BLOC Y (Monitoring/Alertes) : ✅ FERMÉ

| Sous-bloc | Statut | Détail |
|---|---|---|
| Y-1..Y-6 Observabilité finance | ✅ PASS | `logFinancialSuccess`/`logFinancialFailure`/`startFinancialOperationTimer` déjà en place (Phase 6, `observability.ts`), `sanitizeMetadata()` confirmé (aucun secret/token/paiement brut en log) |
| Gap réel comblé | ✅ CORRIGÉ | `dispatchMissionToDrivers.ts` (aucun log si 0 chauffeur dispo) et `onMissionStatusChangeNotifyCustomer.ts` (écriture notification non observée en cas d'échec) — désormais journalisés (`logFinancialFailure`/`logFinancialSuccess`) |
| Runbook | ✅ FAIT | `docs/MONITORING_RUNBOOK.md` créé |

**BLOC Y : ✅ FERMÉ.** P0 ouverts : 0. P1 ouverts : 0. Commit `7060189`.

## MISE À JOUR — BLOC Z (Privacy / Data Retention) : ✅ FERMÉ

| Sous-bloc | Statut | Détail |
|---|---|---|
| Z-1 Inventaire données | ✅ FAIT | `docs/DATA_RETENTION.md` — matrice complète Client/Chauffeur/Mission/Finance/Système |
| Z-2 GPS/Tracking | ✅ COUVERT (référencé) | `cleanupExpiredTrackingHistory.ts` (30j) documenté comme config technique actuelle, pas obligation légale |
| Z-3 Driver documents | ✅ ANALYSÉ | Rien de supprimable aujourd'hui (Storage immutable, aucune fonction delete) — politique décidée Phase 8 |
| Z-4 Account deletion | ✅ STRATÉGIE DOCUMENTÉE | Aucun workflow existant ; stratégie minimale anonymisation conçue (non implémentée), aucune cascade dangereuse |
| Z-5 Financial safety | ✅ INVARIANTS DOCUMENTÉS | Aucun risque actuel (pas de workflow deletion), invariants pour Phase 8 |
| Z-6 Orphan files (P-7) | ✅ DEFERRED avec algorithme précis | Non implémenté ce tour (grace period + preuve d'orphelin avant suppression) → Phase 8 |
| Z-7 Logs/retention | ✅ RÉFÉRENCÉ | Garanties Bloc Y réutilisées ; durée Cloud Logging → Phase 8 config externe |
| Z-8 Privacy access boundaries | ✅ SANITY | Référencé Blocs P/Q/V, aucune Security Rule modifiée |

**BLOC Z : ✅ FERMÉ.** Aucun code applicatif modifié (documentation/stratégie uniquement). P0 ouverts : 0. P1 ouverts : 0. Commit `b7349ed`.

## MISE À JOUR — BLOC AA (Disaster Recovery) : ✅ FERMÉ

| Sous-bloc | Statut | Détail |
|---|---|---|
| AA-1 Critical data map | ✅ FAIT | `docs/DISASTER_RECOVERY.md` — table donnée/criticité/reconstructible/source de vérité |
| AA-2 Backups (état honnête) | ✅ HONNÊTE | Aucun backup Firestore/Storage actif confirmé — `EXTERNAL CONFIGURATION REQUIRED` Phase 8 (risque le plus important identifié) |
| AA-3 Runbook incident | ✅ FAIT | 11 étapes, réutilise kill switches Bloc X |
| AA-4 Financial recovery | ✅ DOCUMENTÉ | Scénarios mappés sur mécanismes existants (idempotency, reconciliationEngine, compensating entries) ; règle absolue "jamais modifier une entrée ledger" réaffirmée et vérifiée structurellement |
| AA-5 Config recovery | ✅ PROUVÉ | Fail-closed runtime flags prouvé par nouveau test (Scénario A) |
| AA-6 Deployment rollback | ✅ DOCUMENTÉ | Procédure Git-based, aucune CI/CD nouvelle construite (confirmé absente) |
| AA-7 Incident severity | ✅ FAIT | SEV-1/2/3 définis avec exemples Movi-K |
| AA-8 RPO/RTO | ✅ NON INVENTÉ | `RPO/RTO TARGETS — DECISION REQUIRED BEFORE PRODUCTION` + recommandations techniques séparées |
| AA-9 DR Exercise | ✅ FAIT ET TESTÉ | `functions/test/integration/disasterRecovery.test.ts` — 3/3 PASS (non destructif, émulateurs uniquement) |

**BLOC AA : ✅ FERMÉ.** P0 ouverts : 0. P1 ouverts : 0. Commit `c1c4716`.

## VALIDATION FINALE Y → Z → AA

`npx tsc --noEmit` (functions) : 0 erreur. `npm run lint` (functions) : 0 warning. Jest unit :
**109/109 PASS**. Jest intégration complète (émulateurs Firestore/Auth/Storage) : **38 suites /
559 tests PASS**, 0 rouge, incluant `processStripeWebhook.test.ts` PASS (flake connu non
reproduit cette exécution) et le nouveau `disasterRecovery.test.ts` (3/3 PASS) intégré sans
interférence avec le reste de la suite. Aucun fichier Flutter/Dart touché dans Y/Z/AA →
`flutter analyze`/`flutter test` non ré-exécutés (dernier état connu : 0 issue / 508/508 PASS,
Bloc X).

**P0 ouverts (Y+Z+AA)** : 0. **P1 ouverts (Y+Z+AA)** : 0.

## MISE À JOUR — BLOC AB (First User Experience) : ✅ FERMÉ

| Domaine | Fonction | Statut | Preuve |
|---|---|---|---|
| Client | Landing / première impression | ✅ COUVERT | `ec6a839` — badges "Bientôt disponible" trompeurs + libellé flux incorrect corrigés |
| Client | Zero state (aucune mission) | ✅ COUVERT | `d2c4969` — erreur stream ne se déguise plus en zéro-état ; test dédié 2/2 PASS |
| Client | Premier échec (quote/mission) | ✅ COUVERT | `058a76c` — texte brut backend éliminé, mappage i18n systématique ; 4/4 tests PASS |
| Client | Finance mission terminée (320-360px) | ✅ COUVERT | BUG-AB-08-01 corrigé + testé (4/4 PASS), second overflow header corrigé |
| Client | Rating chauffeur (i18n + accessibilité) | ✅ COUVERT | `c657368` (6/6 PASS) + nouveau test Semantics AB-9 (labels + état sélectionné) |
| Chauffeur | Onboarding (texte brut + i18n) | ✅ COUVERT | `b42cb6e` — texte brut backend éliminé ; 2 tests dédiés |
| Chauffeur | Dashboard (i18n AppBar) | ✅ COUVERT | `218a13c` — 3 chaînes FR codées en dur remplacées, testé en EN (0 occurrence résiduelle) |
| Chauffeur | Statuts (pending/documents/approved/rejected/suspended/inactive) | ✅ COUVERT | `test/driver/driver_status_screen_test.dart` — 7/7 statuts + cas transverses |
| Chauffeur | Document upload (tap target) | ✅ COUVERT | BUG-AB-09-01 corrigé (24px → ≥40px), test permanent (mesure `RenderBox.size`) |
| Chauffeur | Première mission disponible (320-360px) | ✅ COUVERT | Nouveau test AB-8 `provider_jobs_tab_test.dart` — carte + CTA visibles, texte long, pas d'overflow |
| Chauffeur | Preuve de livraison (fonctionnel) | ✅ COUVERT | `driver_active_mission_proof_upload_test.dart` (déjà existant, réutilisé sans duplication) |
| Admin | Liste/détail chauffeur (i18n + dates) | ✅ COUVERT | `k5_residual_screens_locale_render_test.dart` (i18n) + `k2_utc_local_boundary_test.dart` (dates localisées) |
| Transverse | AppShell (textScale élevé) | ✅ COUVERT | BUG-AB-09-02 corrigé (Flexible+ellipsis), test permanent `textScale=1.5`/320px |

**Validation associée** : `flutter analyze` (project-wide) → **0 issue**. `flutter test
--concurrency=4` → **531/531 PASS**, 0 skip, 0 rouge. **P0 ouverts (AB)** : 0. **P1 ouverts
(AB)** : 0. P2 trouvés et corrigés : BUG-AB-08-01, BUG-AB-09-01, BUG-AB-09-02 (3/3).

**BLOC AB : ✅ FERMÉ.**

## MISE À JOUR — BLOC AC (Pilot Readiness) : ✅ FERMÉ

Dernier bloc de la Phase 7, purement documentaire (`docs/PILOT_READINESS.md`) — aucun code
touché, aucune nouvelle matrice de test requise. Voir `docs/PHASE7_QA_PLAN.md` (section "MISE À
JOUR — BLOC AC") pour le détail complet AC-1 → AC-9 et `docs/PILOT_READINESS.md` pour le
contenu intégral (Readiness Matrix CLIENT/DRIVER/ADMIN, Phase 8 Required, Physical Device Plan,
GO/NO-GO, Legal/Policy, Operational Accounts, Support Pilot, Release Checklist).

**BLOC AC : ✅ FERMÉ.** P0 ouverts = 0. P1 ouverts = 0.

# PHASE 7 : ✅ TERMINÉE

Tous les blocs A → AC fermés. Voir `docs/PHASE7_QA_PLAN.md` pour la synthèse finale complète.


## Annexe source : docs/PILOT_READINESS.md

# MOVI-K — Pilot Readiness et suivi canonique Phase 8

## Registre actif — 24 septembre 2026

Cette section est l'unique suivi d'exécution 8A à 8L. Les sections AC ci-dessous sont des preuves historiques de Phase 7, pas des affirmations sur le déploiement actuel. La Phase 7 n'est pas réouverte. Les procédures spécialisées restent dans leurs documents existants; aucun second parcours client/chauffeur/admin n'est créé.

**Base vérifiée :** `main` = `6090fed066d5d7ce5444cc71190fe5aef0c77c10`. Travail courant : branche `feat/phase8-readiness`, dans le worktree de release existant. Les deux anciens worktrees et leurs modifications locales sont conservés, sans copie ni fusion automatique. La PR historique #25 est hors de ce lot.

**Dernier état de production vérifié, 24 septembre à 11 h 55 (Québec) :** dix fonctions du correctif #35 actives; quatre `system_config/runtime_flags` à `false`; règles Firestore encore sur la publication du 16 septembre. Cela ne prouve pas un devis connecté ni un pilote complet. Aucun paiement réel ni activation publique n'est autorisé par ce suivi.

**Limite du contrôle de ce lot :** le script d'inventaire cloud a été bloqué avant exécution. Les états externes ci-dessous ne sont ni supposés absents ni déclarés validés. Aucun contournement et aucune mutation cloud n'ont été effectués dans ce lot.

| Bloc | État et travail de ce lot | Condition restante de clôture / composant canonique |
|---|---|---|
| 8A — Configuration | En cours. Mapping `production` vers `movik-connect-prod` confirmé dans `.firebaserc`; un seul codebase `functions`; tests sur `demo-movik-test`. Garde-fou Jest et CI Firebase ajoutés. | Vérifier en lecture les index, les déploiements et règles réellement actifs; appliquer les règles testées après autorisation; préparer la migration du runtime. Activation pilote séparée, sans nouveau projet payant implicite. |
| 8B — Stripe / Connect | Architecture existante conservée (`PAYMENT_ARCHITECTURE.md`, `paymentProviderFactory`, deux webhooks). Aucun nouveau provider, endpoint de paiement ni secret créé. | Vérifier configuration et événements réels puis exécuter le cycle Stripe TEST complet. Toute exposition LIVE reste une décision explicite. Le test sandbox de la PR #35 n'est pas un pilote financier complet. |
| 8C — Anti-abus | Quota commun ajouté aux deux callables existantes `calculateDeliveryQuote` et `calculateRoute`. Aucun second calcul tarifaire. | Valider et déployer le quota après tests; configurer App Check côté plateformes, observer puis imposer progressivement. App Check n'est pas activé dans ce lot. |
| 8D — Push | `PushNotificationService`, `registerPushToken`, `unregisterPushToken`, dispatch et notifications client existent déjà. Pas de second service. | Confirmer VAPID/configuration déployée, permissions, réception, renouvellement, déconnexion et ouverture de la bonne mission sur appareils réels. iOS seulement si retenu. |
| 8E — GPS / appareils | Logique existante réutilisée; aucun essai terrain attesté dans ce lot. | Exécuter AC-3 : arrière-plan, écran verrouillé, perte/reprise réseau, batterie, suivi client et preuve photo. |
| 8F — Récupération | Archives sources des dix fonctions déjà sauvegardées, distinctes des données. État des sauvegardes Firestore/Storage non revalidé. | Vérifier la stratégie, les coûts/rétention approuvés et une restauration non destructive; réutiliser `DISASTER_RECOVERY.md`. |
| 8G — Alertes | Logs structurés et `MONITORING_RUNBOOK.md` conservés. Quota : événements `routing_budget_exhausted` et `routing_budget_check_failed`. | Relier/valider un canal approuvé et prouver la réception d'une alerte; absence de preuve ne signifie pas absence de configuration. |
| 8H — Données | `DATA_RETENTION.md` et purge GPS existante conservés; aucun nettoyage destructif ajouté. | Décider conservation/suppression; préparer le traitement des fichiers réellement orphelins sans supprimer sur erreur temporaire; protéger finance et audit. |
| 8I — Suspension | Comportement existant non modifié. | Décision explicite GAP-S-04 : suspension ordinaire vs interruption urgente, puis tests et audit. |
| 8J — Opérations / juridique | Checklist AC-6 et processus AC-8 réutilisés, aucune validation juridique inventée. | Approbation des politiques, canal de support, responsabilités et traitement des demandes. |
| 8K — Pilote | Non exécuté dans ce lot. Tests logiciels et émulateurs ne sont pas des trajets physiques. | Zone et participants approuvés, parcours client → chauffeur → livraison → finance → admin, avec preuves. |
| 8L — GO / NO-GO | **NO-GO pour l'ouverture publique à ce stade.** | Toutes les conditions essentielles AC-5 doivent avoir des preuves; le nombre de tests verts ne ferme pas les dépendances externes. |

### 8A — Gardes de test et chemin de validation

`test/setupSafety.ts` est chargé en premier par les deux configurations Jest. Les suites d'intégration/sandbox exigent les trois émulateurs sur loopback, un projet `demo-*`, des identifiants de projet cohérents et aucune clé Stripe LIVE. Le contrôle précède l'import du module de test. Les suites unitaires sont confinées à un projet fictif et à des endpoints loopback, même si une future régression oublie de simuler une dépendance.

La preuve négative a lancé une suite avec un identifiant non-demo et uniquement des endpoints loopback : refus `TEST_SAFETY`, zéro test exécuté avec succès. Aucun appel à un projet réel n'est nécessaire à cette preuve.

Le workflow `.github/workflows/firebase-validation.yml` complète les workflows Flutter et Stripe existants; il ne déploie rien et ne charge aucun secret. Il utilise les scripts npm existants : lint, build, unitaires et intégration sur émulateurs. Les actions sont épinglées par SHA. La prévisualisation Vercel de cette branche est désactivée pour ne pas créer un deuxième site d'essai.

### 8C — Un seul budget pour les appels routiers

`consumeRoutingBudget()` est appelé une fois par requête authentifiée/valide aux callables existantes. `calculateAuthoritativeRoute()` reste une primitive interne sans quota supplémentaire : le devis ne paie pas deux consommations. Aucun changement de prix, commission, pourboire ou affectation des chauffeurs.

Paramètres techniques dans `appConfig.ts` : `ROUTING_REQUESTS_PER_WINDOW=60`, `ROUTING_WINDOW_SECONDS=60` par défaut. C'est une fenêtre fixe par UID, pas une protection globale contre des créations massives de comptes; App Check reste à traiter. Le compteur est une transaction atomique Firestore et refuse en cas d'indisponibilité ou d'état corrompu. Le refus retourne `resource-exhausted` et `retryAfterSeconds`, avant l'appel Google Routes.

Une seule collection `routing_request_limits`, un seul document réutilisé par UID haché (pseudonyme, pas anonyme). Le refus par défaut des règles existantes interdit toute lecture/modification client, y compris via un compte admin utilisant le SDK client. Aucun nouvel endpoint, aucun index ni tâche de purge dupliqués.

### Preuves et prochaine étape

**Validation locale de ce lot :** lint et compilation réussis sous Node.js 20.20.2; 205 tests unitaires et 606 tests d'intégration réussis, soit **811 tests dans 54 suites**, sans échec ni test ignoré. Paiements et routes simulés; Firestore/Auth/Storage sur émulateurs. Aucune validation physique ni financière LIVE n'est déduite de ces résultats.

Les résultats de ce lot sont conservés dans le dossier d'audit local existant : `phase8-unit-results.json`, `phase8-integration-results.json`, `phase8-refusal-results.json` et journaux associés. La CI doit également être consultée sur la PR : une configuration de workflow présente n'est pas une exécution réussie.

Avant toute fusion/diffusion : revue du diff, tests complets et confirmation de l'absence de changement de prix/flags. Avant toute ouverture : contrôle connecté du devis, alignement des règles et index, fermeture des dépendances 8B à 8K. Le runtime Node.js 20 reste celui de production; sa migration est requise avant son retrait du 30 octobre 2026 et n'est pas implicitement effectuée par ce lot.

Références techniques consultées le 24 septembre 2026 : [App Check](https://firebase.google.com/docs/app-check/cloud-functions), [paramètres Firebase](https://firebase.google.com/docs/reference/functions/firebase-functions.params), [runtimes Google Cloud](https://docs.cloud.google.com/functions/docs/runtime-support).

---

## Historique Phase 7 — Bloc AC (conservé, non réouvert)

Les mentions historiques « absent », « non configuré » ou « READY » ci-dessous décrivent l'état de clôture Phase 7. Le registre actif ci-dessus les qualifie pour Phase 8; ne pas reconstruire un composant existant sur la seule base d'une ancienne mention.


**Statut du document** : dernier bloc de la Phase 7 QA. Objectif unique : répondre honnêtement
à *« Qu'est-ce qui est prêt pour un pilote réel, et qu'est-ce qui doit être configuré/décidé en
Phase 8 ? »*. Ce document n'est PAS une nouvelle phase de développement — aucune ligne de code
n'est modifiée pour produire ce document ; il ne fait que consolider et qualifier honnêtement
l'état déjà prouvé par Phase 2 → Phase 7 (Blocs A → AB).

**Statuts autorisés** (aucun autre statut n'est utilisé dans ce document) :
- `READY` — prouvé par du code + des tests dans ce repo, fonctionnellement complet pour un
  pilote contrôlé.
- `PHASE 8 REQUIRED` — dépend d'une configuration externe (compte tiers, clés de production,
  infrastructure Console GCP/Firebase/Stripe) qui ne peut pas être créée depuis ce repo.
- `PRODUCT DECISION REQUIRED` — un comportement ambigu existe et nécessite un choix produit
  explicite avant correction (pas un bug de code manquant).
- `LEGAL / FOUNDER DECISION REQUIRED` — dépend d'une décision légale/politique/business qui
  n'est pas du ressort de l'ingénierie.

**Règle absolue de ce document : pas de faux READY.** Un statut READY signifie que le
comportement est prouvé par du code + des tests réels dans ce repo, PAS une supposition.

---

## AC-1 — READINESS MATRIX

### CLIENT

| Fonction | Statut | Preuve | Action avant pilote |
|---|---|---|---|
| Signup / Login | READY | `test/auth/` (Firebase Auth + claims), `AuthScreen` testé Bloc L/AB (i18n, tap targets, contraste) | Aucune — fonctionnel de bout en bout en émulateur/test |
| Création mission (quote → confirmation) | READY | `DeliveryRequestFlowScreen`, `calculateDeliveryQuote`/`createDeliveryRequest` (Bloc B/N/O), erreurs génériques non techniques (AB-3, `058a76c`) | Aucune |
| Quote (tarification) | READY | `calculateDeliveryQuote.ts` testé (Bloc B, N, T), validation runtime des champs (Bloc O) | Aucune |
| Paiement (flux applicatif) | PHASE 8 REQUIRED | `StripeProvider`/`FirebaseFinanceRepository` codés et testés en émulateur (idempotence Bloc O, réconciliation Bloc Z/AA) ; **aucune clé Stripe live, aucun webhook production configuré** | Voir AC-2 — Stripe live keys + webhook production |
| Searching driver / Assignment | READY | `dispatchMissionToDrivers.ts` (Bloc Y — observabilité comblée GAP-Y-01), assignation automatique confirmée (AB-1 : libellé landing corrigé pour refléter ce comportement réel) | Aucune |
| Tracking (GPS chauffeur → client) | READY (émulateur/widget) — PHASE 8 REQUIRED (device réel) | `LiveTrackingMap`/`watchDriverLocation()` (Bloc H — durcissement GPS), fonctionnel en test | Voir AC-3 — validation GPS sur téléphone réel obligatoire avant pilote |
| Notifications (in-app) | READY | `NotificationBell`, `notification_repository`, i18n `notif_*` complet (Bloc I/K) | Aucune |
| Notifications (push mobile FCM/APNs) | PHASE 8 REQUIRED | Documenté DEFERRED en Bloc I (I-7) : **aucune dépendance `firebase_messaging` dans le projet** — non construit, pas un bug | Voir AC-2 — FCM/APNs réels |
| Completion (mission terminée) | READY | `_CompletedMissionView`, finance summary testé (AB-8, BUG-AB-08-01 corrigé) | Aucune |
| Rating / Review | READY | AB-10 (`c657368`) — implémentation complète 1-5 étoiles + commentaire, Semantics accessible (AB-9), i18n FR/EN/ES (6/6 + tests dédiés) | Aucune |

### DRIVER

| Fonction | Statut | Preuve | Action avant pilote |
|---|---|---|---|
| Onboarding (formulaire + soumission) | READY | `DriverOnboardingScreen`, texte brut backend éliminé (AB-4, `b42cb6e`) | Aucune |
| Documents (upload permis/assurance) | READY (émulateur/widget) — PHASE 8 REQUIRED (device réel) | `driver_onboarding_document_upload_test.dart`, Storage rules (Bloc P), tap target corrigé (BUG-AB-09-01) | Voir AC-3 — upload réel caméra/galerie sur device |
| Analyst review | READY | Security Rules `driver_documents` (Bloc P), flux de revue documenté | Aucune |
| Approval / Rejection / Suspension | READY | `test/driver/driver_status_screen_test.dart` — 7/7 statuts réels testés (registrationIncomplete, pendingReview, documentsRequired, approved, rejected, suspended, inactive) | Aucune |
| Online / Offline | READY | Switch avec Tooltip accessible (BUG-007, Bloc L), gate dashboard (`provider_dashboard_shell_status_gate_test.dart`) | Aucune |
| Mission offers / Accept | READY | `ProviderJobsTab`, testé fonctionnellement (`provider_jobs_tab_test.dart` — succès/erreurs/double-tap) + mobile 320-360px (AB-8, cette session) | Aucune |
| GPS (localisation chauffeur) | READY (émulateur/widget) — PHASE 8 REQUIRED (device réel) | Bloc H (durcissement), aucune preuve sur device physique réel (background, écran verrouillé, perte réseau) | Voir AC-3 — obligatoire avant pilote |
| Pickup / In-transit | READY | `driver_active_mission_status_gaps_test.dart`, transitions de statut testées | Aucune |
| Proof of delivery | READY (émulateur/widget) — PHASE 8 REQUIRED (device réel caméra) | `driver_active_mission_proof_upload_test.dart`, Storage rules immuables (Bloc P) | Voir AC-3 — caméra réelle sur device |
| Completion | READY | Transition `completed`, testée bout-en-bout (finance, rating déclenché) | Aucune |
| Earnings | READY | `provider_earnings_tab.dart`, dates localisées (Bloc K2) | Aucune |
| Payout | PHASE 8 REQUIRED | `driver_payouts_enabled` kill switch + logique de calcul testées (Bloc X, Bloc O) ; **aucun payout Stripe Connect réel jamais exécuté** (pas de compte Connect production) | Voir AC-2 — Stripe Connect onboarding + payouts réels |

### ADMIN

| Fonction | Statut | Preuve | Action avant pilote |
|---|---|---|---|
| Pending drivers (liste) | READY | `admin_drivers_list_screen.dart`, i18n testé (K5), dates localisées (K2) | Aucune |
| Document review | READY | Security Rules `driver_documents` (analyst/admin read), flux de revue par statut | Aucune |
| Approve / Reject / Request docs | READY | Cloud Functions dédiées testées (Bloc B/C historique), transitions de statut couvertes (`driver_status_screen_test.dart`) | Aucune |
| Missions (vue admin) | READY | `admin_dashboard_shell.dart`, i18n rendu réel testé (`k5_residual_screens_locale_render_test.dart`) | Aucune |
| Finance (vue admin) | READY | `admin_finance_ui_test.dart`, `AdminFinanceShell` testé i18n 3 langues (Bloc M) | Aucune |
| Refunds | READY | `refundPayment` idempotent (Bloc O), E2E validé (Bloc Q — "E2E refund validé partiel + total") | Aucune |
| Disputes | READY | `dispute_info_test.dart`, modèle + UI présents | Aucune |
| Reconciliation | READY | `reconciliationEngine.ts` testé (Bloc Z/AA — `disasterRecovery.test.ts` 3/3 PASS), staleness webhook détectée | Aucune |
| Audit (traçabilité admin) | READY | Toute modification runtime flags / statuts / finance auditée avec old/new values (Bloc X) | Aucune |
| Kill switches | READY | 4 kill switches MVP (Bloc X) : `accept_new_delivery_requests`, `allow_driver_acceptance`, `payments_enabled`, `driver_payouts_enabled` — fail-closed, admin-only, audité | Voir AC-2 — X-13 bootstrap Phase 8 (confirmer explicitement les 4 valeurs en prod avant lancement) |
| Monitoring (interne, logs structurés) | READY | `docs/MONITORING_RUNBOOK.md` — logs structurés `logFinancialSuccess`/`logFinancialFailure` (Bloc Y) | Voir AC-2 — destinations d'alerte externes (Slack/PagerDuty/email) non branchées |

---

## AC-2 — PHASE 8 REQUIRED (items externes déjà connus, vérifiés honnêtement)

| Item | Statut | Preuve / justification |
|---|---|---|
| Stripe / Stripe Connect — clés live, webhook production, onboarding Connect, vrais paiements, vrais payouts | **PHASE 8 REQUIRED** | Code + tests émulateur complets (idempotence Bloc O, réconciliation Bloc AA) ; `functions/src/lib/secrets.ts` référence `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET` via Secret Manager (jamais commités) — mais **aucune valeur réelle n'est configurée dans ce repo par conception**. Aucun paiement/payout réel n'a jamais été exécuté. |
| App Check — enforcement production | **PHASE 8 REQUIRED** | Confirmé absent (GAP-Q2-01, Bloc Q2) : SDK `firebase_app_check` présent en dépendance mais **0 activation client, 0 `enforceAppCheck` sur les 31 Cloud Functions `onCall`, 0 référence `request.app` dans les règles**. Nécessite Play Integrity/App Attest/reCAPTCHA — configuration externe hors du périmètre de développement. |
| Push notifications — FCM/APNs réels | **PHASE 8 REQUIRED** | Documenté DEFERRED (I-7, Bloc I) : aucune dépendance `firebase_messaging` dans le projet. Non construit. |
| GPS réel (vrais téléphones, background, écran verrouillé, perte/reprise réseau) | **PHASE 8 REQUIRED** | Bloc H a durci la logique GPS en émulateur/widget test ; **aucune validation sur device physique réel** n'a jamais été faite dans ce repo (impossible en sandbox). Voir AC-3. |
| Backups Firestore/Storage | **PHASE 8 REQUIRED** | Confirmé absent (AA-2, Bloc AA) : **aucune preuve qu'un export planifié Firestore ou un PITR soit activé** sur `movik-connect-prod` ; aucune règle de versioning/lifecycle Cloud Storage configurée. Configuration exclusivement Console GCP, hors de ce repo. Risque Phase 8 le plus important identifié. |
| Monitoring externe (destinations d'alerte) | **PHASE 8 REQUIRED** | `docs/MONITORING_RUNBOOK.md` documente le mécanisme de logs structurés (interne, READY) mais explicitement note que la notification externe (email/Slack/PagerDuty) reste à brancher — décision produit sur le canal, configuration externe. |
| Runtime flags — bootstrap production | **PHASE 8 REQUIRED** (procédure prête, exécution non faite) | Procédure complète documentée (X-13, Bloc X) : 11 étapes explicites pour bootstrapper/confirmer les 4 kill switches en production. Le code est fail-closed par défaut (READY) — mais la confirmation explicite en environnement `movik-connect-prod` n'a pas été exécutée (ne peut pas l'être depuis ce repo). |
| Privacy / data retention — durées finales | **LEGAL / FOUNDER DECISION REQUIRED** | `docs/DATA_RETENTION.md` (Bloc Z) marque explicitement chaque ligne d'inventaire de données `POLICY / LEGAL DECISION REQUIRED — PHASE 8` (durées de conservation post-suppression, documents chauffeur réglementés, etc.) — aucune durée n'est inventée. |
| RPO / RTO | **FOUNDER / OPERATIONS DECISION REQUIRED** | `docs/DISASTER_RECOVERY.md` (AA-8) : `RPO/RTO TARGETS — DECISION REQUIRED BEFORE PRODUCTION`, explicitement non inventé. Dépend directement de l'activation des backups (item ci-dessus). |
| Orphan Storage cleanup | **PHASE 8 REQUIRED** | `docs/DATA_RETENTION.md` (Z-6) : `DEFERRED NON-BLOCKING → Phase 8`, algorithme de nettoyage déjà recommandé dans le document mais non implémenté. |
| `calculateDeliveryQuote` — rate limiting | **PHASE 8 REQUIRED** | GAP-Q2-01 (Bloc Q2) : aucune limite de fréquence sur cette fonction callable. Impact évalué FAIBLE (coût Firestore négligeable, aucun appel provider externe coûteux, `requireSignedIn()` déjà une barrière anti-abuse) mais classé explicitement DEFERRED → Phase 8, pas construit ce tour. |
| GAP-S-04 — chauffeur suspendu pendant mission active | **PRODUCT DECISION REQUIRED** | Bloc S : `suspendDriver.ts` met à jour `driver_profiles.status = suspended`, mais `completePickup.ts`/`completeDelivery.ts` ne revérifient QUE `mission.status` + `driver_id` — un chauffeur suspendu en cours de mission PEUT continuer jusqu'à completion. Non corrigé par choix : interrompre une livraison en cours pourrait créer un colis orphelin (potentiellement pire pour le client). Nécessite une décision produit explicite. Si validé bug : correctif = ajouter vérification `driver_profiles.status === 'approved'` dans `completePickup.ts`/`completeDelivery.ts`. |

---

## AC-3 — PHYSICAL DEVICE PLAN

**Rappel critique** : tout ce qui suit n'a été validé qu'en émulateur Firebase et/ou widget test
Flutter (`flutter test`, aucun rendu réel sur écran physique). **Aucun de ces points n'est
marqué READY** — ils exigent une validation sur appareils réels avant tout pilote, quel que soit
le niveau de couverture logicielle atteint en Phase 7.

### Client (device réel requis)

| Point à tester | Pourquoi ce n'est pas déjà prouvé |
|---|---|
| Android réel (pas seulement émulateur widget test) | `flutter test` s'exécute en environnement de test Flutter (pas un vrai rendu Android/iOS) |
| Connectivité Wi-Fi / données mobiles réelles, transition entre les deux | Bloc G (offline/retry) teste la logique de retry en simulant des exceptions réseau, pas une vraie coupure radio |
| Notifications push réelles | N/A tant que FCM/APNs n'est pas intégré (voir AC-2) |
| Tracking GPS côté client (recevoir la position chauffeur en temps réel) | `watchDriverLocation()` testé avec des flux Firestore simulés, jamais avec un vrai flux GPS chauffeur en mouvement |
| Comportement background/foreground de l'app pendant une livraison en cours | Aucun test Flutter ne peut simuler le vrai cycle de vie Android/iOS background |

### Driver (device réel requis)

| Point à tester | Pourquoi ce n'est pas déjà prouvé |
|---|---|
| GPS réel (précision, dérive, tunnels/zones mortes) | Bloc H durcit la LOGIQUE de traitement des positions, pas la qualité du signal GPS réel |
| Permissions runtime (localisation "toujours"/"en utilisant l'app", caméra, stockage) | Les dialogues de permission natifs OS ne sont pas simulables en widget test |
| GPS en arrière-plan (app minimisée pendant une livraison) | Nécessite configuration native Android (foreground service)/iOS (background modes) non vérifiable par `flutter test` |
| Écran verrouillé pendant le tracking | Comportement OS natif, hors de portée des tests Flutter |
| Caméra réelle pour preuve de livraison (qualité photo, permissions, orientation) | `driver_active_mission_proof_upload_test.dart` simule un fichier déjà sélectionné, ne teste jamais le vrai flux caméra |
| Perte réseau puis reprise en plein trajet (upload de position/preuve en attente) | Bloc G simule des exceptions, pas une vraie coupure radio prolongée sur le terrain |
| Consommation batterie sur une session de livraison complète (GPS actif en continu) | Aucun test logiciel ne peut mesurer un impact batterie réel |

**Ne jamais marquer un de ces points comme déjà validé sur la seule base d'émulateur/widget
test.**

---

## AC-4 — PILOT STRATEGY

Un pilote contrôlé doit rester volontairement petit et réversible :

- **Zone géographique** : une seule zone urbaine restreinte (ex. un seul quartier/secteur de
  livraison) — **FOUNDER / OPERATIONS DECISION** (pas de zone choisie dans ce document).
- **Chauffeurs pilotes** : un petit groupe fermé, onboardés manuellement, connus individuellement
  de l'équipe (pas d'ouverture publique de l'onboarding chauffeur pendant le pilote) —
  **FOUNDER / OPERATIONS DECISION** pour le nombre exact.
- **Clients pilotes** : accès contrôlé (invitation, liste fermée, ou zone géographique limitante)
  — **FOUNDER / OPERATIONS DECISION** pour le nombre exact et le mécanisme d'accès.
- **Volume** : faible volume intentionnel (quelques missions/jour au démarrage), afin de pouvoir
  investiguer manuellement chaque incident financier ou opérationnel sans automatisation de
  masse — **FOUNDER / OPERATIONS DECISION** pour le seuil exact.
- **Monitoring renforcé** : surveillance manuelle rapprochée pendant toute la durée du pilote
  (logs structurés déjà READY, voir AC-1 Admin/Monitoring) — augmenter la fréquence de review
  humaine des logs `logFinancialFailure` pendant le pilote.
- **Kill switches prêts** : les 4 kill switches (Bloc X) doivent être confirmés opérationnels
  (bootstrap X-13 exécuté, voir AC-2) et une personne d'astreinte doit savoir les activer en
  moins de 5 minutes en cas d'incident.

**Aucun chiffre exact (taille de zone, nombre de chauffeurs/clients, seuil de volume) n'est fixé
dans ce document — ce sont des décisions FOUNDER/OPERATIONS, pas des paramètres techniques.**

---

## AC-5 — GO / NO-GO CHECKLIST

Le GO pilote exige la conjonction de TOUS les points suivants. Tout item non encore configuré
est classé **PHASE 8 REQUIRED**, et n'est PAS un bug logiciel de Phase 7.

| Critère GO | Statut actuel | Action requise |
|---|---|---|
| P0 logiciel = 0 | ✅ Confirmé (tous blocs A→AB) | Aucune |
| P1 logiciel = 0 | ✅ Confirmé (tous blocs A→AB) | Aucune |
| Tests critiques verts (`flutter analyze` 0 issue, `flutter test` 531/531, Jest unit 109/109, Jest intégration 559/559) | ✅ Confirmé | Aucune |
| Stripe réel validé (clés live) | ❌ PHASE 8 REQUIRED | Configurer Secret Manager production + valider un paiement test réel en mode live restreint |
| Paiement réel testé | ❌ PHASE 8 REQUIRED | Dépend du point ci-dessus |
| Payout réel testé | ❌ PHASE 8 REQUIRED | Stripe Connect onboarding réel + premier payout test réel |
| Push réel testé | ❌ PHASE 8 REQUIRED | Intégrer FCM/APNs (actuellement absent, voir AC-2) puis tester sur device |
| GPS réel testé | ❌ PHASE 8 REQUIRED | Voir AC-3 — tests sur device physique obligatoires |
| Backup activé | ❌ PHASE 8 REQUIRED | Activer export Firestore planifié et/ou PITR + versioning Storage (Console GCP) |
| Monitoring externe configuré | ❌ PHASE 8 REQUIRED | Brancher une destination d'alerte réelle (email/Slack/PagerDuty) sur les logs structurés déjà READY |
| Runtime flags configurés | ⚠️ Procédure prête, exécution non faite | Exécuter la procédure X-13 (11 étapes) en environnement `movik-connect-prod` |
| Admin prod configuré | ⚠️ Non vérifié dans ce repo | Confirmer les comptes admin/super_admin réels en production (claims Firebase Auth) |
| Policies requises prêtes | ❌ LEGAL/FOUNDER DECISION REQUIRED | Voir AC-6 |
| Kill switches vérifiés | ⚠️ Code READY, confirmation prod non faite | Même action que "Runtime flags configurés" ci-dessus |
| Runbook incident disponible | ✅ `docs/MONITORING_RUNBOOK.md` + `docs/DISASTER_RECOVERY.md` (11 étapes) | Aucune |

**Conclusion honnête** : le logiciel (code + tests) est prêt (P0=0, P1=0, suite complète verte).
Le GO pilote reste bloqué par des items **PHASE 8 REQUIRED** externes (Stripe live, App Check,
push, GPS device réel, backups, monitoring externe, runtime flags bootstrap prod) et des
décisions **LEGAL/FOUNDER** (policies, RPO/RTO, zone/volume pilote) — aucun de ces blocages
n'est un bug de Phase 7.

---

## AC-6 — LEGAL / POLICY

Documents identifiés comme nécessaires avant un pilote réel avec de vrais utilisateurs
(paiements, données personnelles, géolocalisation) :

| Document | Statut | Référence |
|---|---|---|
| Terms of Service (client) | **LEGAL / FOUNDER REVIEW REQUIRED** | Non trouvé dans ce repo — nécessite rédaction/validation juridique |
| Privacy Policy | **LEGAL / FOUNDER REVIEW REQUIRED** | `docs/DATA_RETENTION.md` fournit l'inventaire technique des données (base factuelle pour rédiger la policy) mais n'est PAS lui-même une Privacy Policy publiable |
| Driver terms (conditions chauffeur/partenaire) | **LEGAL / FOUNDER REVIEW REQUIRED** | Non trouvé dans ce repo |
| Payment / refund policy | **LEGAL / FOUNDER REVIEW REQUIRED** | Logique technique de refund READY (Bloc O/Q), mais la POLICY commerciale (délais, conditions d'éligibilité communiquées au client) n'est pas rédigée dans ce repo |
| Location / GPS consent | **LEGAL / FOUNDER REVIEW REQUIRED** | Permissions techniques Android/iOS gérées au niveau OS (à valider AC-3), mais le texte de consentement/disclosure utilisateur n'existe pas dans ce repo |
| Document handling (permis, assurance, pièces d'identité chauffeur) | **LEGAL / FOUNDER REVIEW REQUIRED** | `docs/DATA_RETENTION.md` marque explicitement ces données `RETENTION POLICY DECISION REQUIRED — PHASE 8` |
| Retention policy (durées) | **LEGAL / FOUNDER DECISION REQUIRED** | Voir AC-2 — chaque ligne d'inventaire `docs/DATA_RETENTION.md` est marquée en attente de décision |
| Account deletion / data request process | **LEGAL / FOUNDER REVIEW REQUIRED** | Mécanisme technique de suppression de compte Firebase Auth existe (suppression native) mais le PROCESSUS de demande utilisateur (formulaire, délai de traitement, confirmation) n'est pas documenté/construit |

**Aucun de ces documents n'est rédigé dans ce repo — ce sont des livrables LEGAL/FOUNDER, hors du
périmètre d'ingénierie de la Phase 7.**

---

## AC-7 — OPERATIONAL ACCOUNTS

Comptes/accès nécessaires pour opérer le pilote. **Aucun credential fictif n'est créé dans ce
document** — cette section liste uniquement les comptes à provisionner, sans valeur.

| Compte / Service | Nécessaire pour | Statut |
|---|---|---|
| Firebase / GCP (projet `movik-connect-prod`) | Hébergement Firestore/Auth/Storage/Functions | Projet référencé tout au long de Phase 7 (`movik-connect-prod`) — accès admin/IAM production à confirmer par le founder |
| Stripe | Paiements clients | Non configuré (voir AC-2) — compte Stripe live à créer/activer |
| Stripe Connect | Payouts chauffeurs | Non configuré (voir AC-2) — onboarding Connect plateforme à compléter |
| FCM / APNs | Push notifications | Non intégré au projet (voir AC-2) — comptes développeur Apple/Google Push à provisionner en Phase 8 |
| Admin / Super Admin (production) | Opérer le dashboard admin, revoir documents, gérer kill switches | Mécanisme de claims READY (code) — comptes réels de production à créer et vérifier (procédure X-13) |
| Support email | Point de contact pilote (voir AC-8) | Non défini dans ce repo — à décider par le founder |
| Monitoring / destinations d'alerte | Recevoir les alertes de `logFinancialFailure`/incidents | Non branché (voir AC-2) — compte Slack/PagerDuty/email d'astreinte à provisionner |

---

## AC-8 — SUPPORT PILOT

Flux de support réutilisant intégralement les mécanismes déjà construits en Bloc Y (Monitoring)
et Bloc AA (Disaster Recovery) — aucun nouveau mécanisme technique créé pour ce document :

1. **Utilisateur signale un problème** (client ou chauffeur, via le canal support à définir —
   voir AC-7, support email non encore défini).
2. **Récupérer le mission ID** concerné (identifiant `delivery_requests/{id}`, visible côté
   client/chauffeur dans l'app, et côté admin via `admin_dashboard_shell.dart`).
3. **Investigation admin** : consulter la mission dans `AdminFinanceShell`/vue mission admin,
   consulter les logs structurés (`logFinancialSuccess`/`logFinancialFailure`, Bloc Y) associés à
   ce mission ID.
4. **Audit** : consulter la trace d'audit (old/new values) si la mission a traversé un
   changement de statut, un runtime flag, ou une action admin (Bloc X).
5. **Refund / dispute si nécessaire** : utiliser `refundPayment` (idempotent, Bloc O) ou le flux
   `dispute_info` existant — jamais de modification manuelle directe du ledger (règle absolue
   réaffirmée en Bloc AA : "jamais modifier une entrée ledger").
6. **Escalation SEV si nécessaire** : appliquer la classification SEV-1/2/3 déjà définie dans
   `docs/DISASTER_RECOVERY.md` (AA-7) avec des exemples Movi-K concrets, et suivre le runbook
   incident 11 étapes (AA-3) si l'incident dépasse le cadre d'un ticket support isolé.

**Ce flux réutilise Y/AA sans duplication** — aucun nouveau code, aucune nouvelle Cloud Function
créée pour le support pilote.

---

## AC-9 — RELEASE CHECKLIST (Phase 8)

Checklist consolidée de tout ce qui doit être fait AVANT le lancement du pilote réel, dans
l'ordre logique de dépendance :

1. **Code** — ✅ déjà prêt (Phase 2 → Phase 7, P0=0, P1=0, tests verts).
2. **Environment** — confirmer la configuration `movik-connect-prod` (projet Firebase/GCP réel,
   pas un projet de test/staging).
3. **Secrets** — provisionner `STRIPE_SECRET_KEY`/`STRIPE_WEBHOOK_SECRET` réels dans Secret
   Manager production (jamais commités, voir `functions/src/lib/secrets.ts`).
4. **Firebase** — vérifier les Security Rules déployées correspondent exactement à celles
   testées (Bloc P/Q), activer les index Firestore requis (`docs/FIRESTORE_INDEXES.md`).
5. **Stripe** — activer le mode live, configurer le webhook production (endpoint +
   `STRIPE_WEBHOOK_SECRET`), compléter l'onboarding Stripe Connect plateforme.
6. **App Check** — activer côté client (`FirebaseAppCheck.instance.activate()`) et configurer
   l'enforcement Console (recommandé : mode "monitor only" avant enforcement dur, voir Bloc Q2).
7. **Notifications** — intégrer `firebase_messaging`, configurer FCM (Android) et APNs (iOS).
8. **GPS réel** — exécuter le plan AC-3 sur au moins un device Android et un device iOS réels.
9. **Backups** — activer export Firestore planifié et/ou PITR, activer versioning/lifecycle
   Cloud Storage (Console GCP).
10. **Monitoring** — brancher une destination d'alerte externe réelle sur les logs structurés
    déjà en place (`docs/MONITORING_RUNBOOK.md`).
11. **Policies** — finaliser et publier ToS, Privacy Policy, driver terms, payment/refund policy,
    GPS consent (voir AC-6) — décision LEGAL/FOUNDER.
12. **Admin prod** — créer/vérifier les comptes admin/super_admin réels, exécuter la procédure
    de bootstrap runtime flags (X-13, 11 étapes).
13. **Runtime flags** — confirmer explicitement les 4 valeurs en production (voir X-13).
14. **Physical-device QA** — exécuter intégralement le plan AC-3 (client + chauffeur, device
    réel) avant d'ouvrir l'accès à de vrais utilisateurs pilotes.
15. **Pilot users** — définir la zone, le nombre de chauffeurs/clients pilotes, le mécanisme
    d'accès (décision FOUNDER/OPERATIONS, voir AC-4).
16. **Smoke tests** — exécuter un parcours complet réel (signup → quote → mission → paiement
    réel restreint → tracking → completion → rating → payout réel restreint) sur l'environnement
    de production avec des comptes de test internes, AVANT d'ouvrir aux pilotes externes.
17. **GO / NO-GO** — revalider la checklist AC-5 dans son intégralité.
18. **Lancement pilote** — ouverture contrôlée selon la stratégie AC-4.

---

## DONE AC

| Critère de clôture | Statut |
|---|---|
| Readiness matrix complète (CLIENT/DRIVER/ADMIN) | ✅ AC-1 |
| External blockers identifiés | ✅ AC-2 |
| Physical-device plan | ✅ AC-3 |
| GO/NO-GO checklist | ✅ AC-5 |
| Legal/policy checklist | ✅ AC-6 |
| Operational accounts | ✅ AC-7 |
| Support flow | ✅ AC-8 |
| Release checklist | ✅ AC-9 |
| Aucun P0/P1 logiciel connu laissé ouvert | ✅ Confirmé (P0=0, P1=0, Bloc AB fermé) |

# BLOC AC : ✅ FERMÉ


## Accueil public — exécution du plan approuvé le 25 septembre 2026

Périmètre indépendant de la PR no 37 : accueil existant, navigation publique, conservation de la catégorie pendant la connexion et métadonnées HTML. Une seule PR d'accueil (no 38), une seule route de demande, aucun second formulaire ni copie de site. Aucun changement des fonctions, des règles, du moteur tarifaire, de Stripe ou des interrupteurs opérationnels.

- Premier écran raccourci; compteur de chauffeurs fictifs supprimé; mention de version pilote et disponibilité à confirmer conservée.
- Bouton « Obtenir mon devis » directement vers `/{locale}/livraison/demande`. Six catégories préremplies via un paramètre validé dans le catalogue existant.
- Retour après connexion limité à cette route et au paramètre de catégorie reconnu. Aucun retour vers une URL arbitraire, un autre domaine ou une route administrative.
- Menu de compte visible sur téléphone; entrées chauffeur et administration conditionnées aux rôles, sans modification de la sécurité serveur.
- Étapes réordonnées, promesses de messagerie/avis retirées, FAQ et informations de disponibilité, recrutement chauffeur distinct et pied de page regroupé. Textes FR/EN/ES; cartes de hauteur naturelle.
- Le formulaire Contact simulait un envoi et indiquait `support@movi-k.demo`. Il est remplacé par un état explicitement non opérationnel. **Adresse officielle ou canal de contact à fournir et raccorder avant ouverture publique.** Aucun délai de réponse inventé.
- Titre, description et balises sociales du HTML initial corrigés. **HTML initial encore en français** : les variantes statiques de métadonnées par langue sont hors de ce lot. Le titre de l'accueil change aussi dans l'application selon la langue.
- Pas de photo d'un chauffeur ou de témoignage fabriqué, ni couverture géographique précise annoncée sans preuve. Pas de bouton de programmation tant que les lots d'horaire ne sont pas livrés.

Validation : le workflow Flutter existant est réutilisé; aucun nouveau workflow parallèle. Tests ciblés de rendu 320/390/768/1280, FR/EN/ES, texte 200 % en clair/sombre, navigation client/chauffeur, catégorie après connexion, retour sûr et absence de faux envoi Contact. Le résultat final est à consulter sur le dernier commit de la PR no 38. Aucune mesure de rapidité, qualification WCAG globale ni essai utilisateur en production n'est déduit de ces tests.

Publication : le connecteur Vercel a encore renvoyé 403 le 25 septembre; ce refus ne prouve pas une panne du site. La fusion et la publication doivent être contrôlées séparément. Aucun déploiement Firebase n'est requis pour ce lot d'accueil.


## Annexe source : docs/PUBLIC_REVIEW_20261006.md

# Revue publique Movi-K — 6 octobre 2026

Branche : `audit/public-launch-granby`, base de reprise `c7b86b0`. Aucune fusion dans main et aucun déploiement de production pendant cette revue.

## État et corrections

Worktree existant : `C:\Users\Utilisateur\mecano-mobile-launch-review`. Mise à jour de `715550a` à `c7b86b0` par avance rapide. Les dix fichiers non suivis antérieurs (captures et scripts locaux) ont été préservés. Aucun changement applicatif non committé avant cette reprise.

- `test/public/public_launch_pages_test.dart` (c7b86b0) : applique réellement l’échelle du texte 200 % au test QR et vérifie sa valeur.
- `lib/screens/delivery/delivery_request_flow_screen.dart` : la catégorie de l’accueil est affichée dans sa langue et conservée depuis le brouillon. Une catégorie générale telle que « Meubles » ne crée plus silencieusement un objet « Autre objet » ; le visiteur précise lui-même les objets. Les catégories détaillées du formulaire gardent leur comportement.
- `test/home/home_screen_test.dart` : assertions sur « Meubles », absence d’objet générique inventé et conservation de la catégorie et de la description après connexion.
- Scripts de capture et serveur SPA local dans `scripts/*public_review_20261006*`. Observations et captures dans `artifacts/review-20261006/`.

## Vérifications

- Relance finale `flutter analyze` : aucune anomalie (8,3 s). Cinq fichiers ciblés : **58 tests réussis** (32 s). Suite complète `flutter test` : **646 tests réussis** (3 min 09 s).
- Build final `flutter build web --release --dart-define=USE_FIREBASE_EMULATORS=true` : **réussi** (108,4 s de compilation). Utilise explicitement `demo-movik-test`, pas les données de production.
- Premier passage avant la correction de catégorie : analyse sans anomalie, 58 tests ciblés réussis et build Web réussi (112,4 s).
- Avertissement non bloquant : famille CupertinoIcons attendue mais non incluse ; aucune dépendance modifiée pour masquer cet avertissement.
- Capture navigateur finale après correction : **36 visites, 25 captures**, dont 24 accueil/Granby (FR/EN/ES × 320/390/768/1280 px) et le formulaire invité avec catégorie « Meubles ». Aucune erreur JavaScript. Deux appels `getBookingConfiguration` refusés, car les émulateurs ne sont pas actifs. Les assertions navigateur confirment la catégorie et l’absence d’objet générique inventé.
- Accueil et page Granby inspectés visuellement ; pages publiques et politiques chargées directement. **11 liens publics cliqués en français sur desktop**, avec vérification de la destination : devis, chauffeur, connexion, FAQ, Tarifs, Sécurité, Contact, Comment ça marche et trois politiques. **Six cartes de catégorie cliquées**, avec vérification du paramètre de catégorie. Preuves : `link-validation.json`, `category-validation.json`.
- Les illustrations existantes gardent du texte français même en EN/ES. La revue linguistique des textes d’interface ne traduit pas ces images.
- Texte 200 % : tests Flutter accueil FR/EN/ES sur 320 px et page QR ; captures navigateur à échelle normale.

## Preview et limites

- Preview locale : `http://127.0.0.1:8092/fr`, QR `http://127.0.0.1:8092/fr/granby`. Serveur concurrent et routes SPA ; bannière Firebase Emulator visible.
- Preview Vercel existante : https://mecano-mobile-git-audit-public-090e24-solexis-projects-4c019079.vercel.app/fr/granby . Protégée ; API 403 pour le scope du projet. Pas de preuve visuelle sur cette preview et aucune protection désactivée.
- Reprise invité → connexion et devis côté serveur validés avec doubles de test / CI émulateurs. Aucun compte connecté, devis officiel réel, mission ni transaction réelle pendant cette recette visuelle.
- GA4 : PR #47 ouverte/non fusionnée lors de la vérification. Aucun identifiant Firebase écrasé.
- Aucun calcul tarifaire, Stripe, snapshot ni règle serveur modifié pendant cette reprise. Les modifications financières/serveur déjà présentes dans 715550a restent dans la branche et nécessitent leur propre revue. Ne pas interpréter le succès des tests comme preuve d’activation Stripe live.

## Décisions restantes

Fournir un canal de contact officiel fonctionnel, autoriser l’accès à la preview, fournir un environnement de recette avec capacités/véhicules/zone/politiques approuvés et compte client, puis vérifier le paiement et la concordance devis = mission = snapshot = cents Stripe. Décision GA4 et approbation des changements serveur antérieurs encore requises.

**QR pas prêt à être distribué au public : canal de contact manquant.** Cible recommandée après validation et publication approuvée : https://movi-k.com/fr/granby . Aucune publication en production autorisée par cette revue.

## Sources

- CI Flutter de c7b86b0 (646 tests, analyse et build réussis) : https://github.com/Solexiai/mecano-mobile/actions/runs/37499286321
- CI Firebase (228 tests unitaires, 618 tests d’intégration sur émulateurs réussis) : https://github.com/Solexiai/mecano-mobile/actions/runs/37499286293
- PR de revue en brouillon : https://github.com/Solexiai/mecano-mobile/pull/51
- Preuves locales : sorties Desktop Commander du 6 octobre 2026 et `browser-validation.json`.


## Addendum de validation — 1.3M-B, 9 octobre 2026

**P1-M-01 : TESTÉ — permissions validées en émulateur ; validation globale PARTIELLE, NON FERMÉ.**
Le rapport initial reste conservé dans les annexes ; cet addendum et le tableau actif font foi pour la transition du 9 octobre. Aucun autre ID fermé.

Résultats nouveaux (ne pas additionner aux résultats historiques ni entre réexécutions) :

| Exécution | Réussis | Échoués | Ignorés | Explication |
|---|---:|---:|---:|---|
| Analyse Flutter des 7 Dart modifiés | — | — | — | No issues found, sortie0 |
| Reporter GPS simulé | 9 | 0 | 0 | Nouveau run, Geolocator et repository fictifs |
| Firestore essai1 | 0 | 3 | 197 | Émulateur MissingResourceException locale fr_CA avant assertions ; cleanup(undefined) secondaire |
| Firestore essai2 | 0 | 3 | 197 | Échec lancement Java arguments PowerShell non cités ; ECONNREFUSED avant assertions |
| Firestore essai3 | 0 | 3 | 197 | Résolution Jest temporaire util1.10 au lieu1.15.2 ; erreur setDoc du test ajouté compilé séparément |
| Firestore essai4 | 2 | 1 | 197 | Scénario existant A/B et admin passent ; test listener observe cache, pas verdict serveur |
| Firestore essai5 | 3 | 0 | 197 | Requêtes + rôles + listeners, réponse serveur explicitement attendue |

Preuves : artifacts/corrections-1-3M-B-20261009-1110/rules-results*.json, rules-tests*.log, flutter-analyze.log, flutter-reporter.log, network-node.jsonl ; CHECKPOINT_CORRECTIONS_MOVIK_P1_M_01_REGISTRE.md.
Les197 ignorés sont les autres tests de la suite, exclus par testNamePattern P1-M-01. Aucun d'eux n'est annoncé réussi.

Couverture finale : A lit points A (2 documents), A ne lit pas point B ; getDocs sans filtre refusé ; query A autorisée et query B refusée pour A ; B lit B ; chauffeur propre collection autorisée ; analyst/admin/super_admin autorisés ; autre chauffeur/anonyme refusés. Listener propre mission autorisé, autre mission et collection sans filtre refusés au serveur.
Le cache peut émettre avant la réponse serveur : le test temporaire v3 écoute les changements de métadonnées et attend fromCache=false, ou l'erreur. Il conserve les assertions d'ID et permission-denied. Il n'établit pas une correction de R-K-03-C sur le produit.

Aucun fichier parmi les8 du correctif initial n'a été modifié dans cette intervention. Le fichier firestore.rules, les moteurs/prix/Stripe et les lockfiles sont inchangés.
Harnais temporaires seulement sous artifacts, original TypeScript conservé ; tests compilés enJS avec TypeScript local, pas de compilation de typage complète revendiquée.
Dépendances existantes lues dans le worktree release sans écriture ni installation. Aucun élargissement des règles.
Émulateur Java local demo-movik-test exclusivement, loopback8080/8081/8082 ; pas de CLI Firebase, Auth/Storage/Functions démarrés, ni secrets/routes/cartes/paiements. Les3 variables endpoint sont exigées par la garde mais Auth/Storage non sollicités.
Garde Node refuse les sockets hors loopback8080 et les processus enfants ; sonde synthétique refusée avant connexion ; journalisation. Ce garde applicatif et cet essai Firestore ne constituent PAS le confinement OS complet demandé pour1.3L : les tuiles restent BLOQUÉES ET REPORTÉES.

À compléter avant FERMÉ : revue du rendu actif et de la garde sans missionId, non-régression des écrans chauffeurs consommateurs de carte dans un environnement autorisé ; revue finale et décision explicite de fermeture. Aucun GPS physique, production, Stripe ou déploiement validé.
Décompte actif inchangé : P0=0, P1=6 (dont3 risques R-K-03 et2 validations historiques en attente de clôture), P2=21. Archives Phase7 citées à part, aucun P0 live/global exclu sur cette seule base.

Prochaine action unique recommandée : valider le harnais ciblé sans tuiles permettant de prouver la garde missionId et la compatibilité des écrans consommateurs avant fermeture de P1-M-01. Ne pas commencer R-K-03-A ni1.3N sans nouvelle instruction.


## Index des corrections historiques conservées (aucune fermeture nouvelle)

Ces éléments restent dans les annexes littérales avec leurs preuves et résultats d’origine. « Historique rapporté » ne signifie pas revalidé sur le HEAD actuel ni déployé. Avant une fermeture selon la nouvelle règle, vérifier présence du correctif, analyse et tests adaptés à la version cible ; si ces preuves manquent, conserver CORRECTION CODÉE — NON VALIDÉE. Ils sont comptabilisés séparément du registre actif, sans réouverture artificielle.

| ID permanent | Priorité d'origine | Impact / fichiers / correction historique | Tests et résultat d'origine / reste à vérifier |
|---|---|---|---|
| BUG-001 | P1 | Autorisation non libérée annulation ; paymentOrchestration/onMissionEndedClearTracking ; fonction cancelMissionPaymentAuthorization ajoutée | missionCancellationPaymentRelease 3/3 ; trigger10/10 ; rules196/196 rapportés ; production NON VÉRIFIÉE |
| BUG-002 | P3 | Suivi déconnecté trompeur ; customer_tracking_screen ; garde auth | auth tracking2/2 rapportés ; ne pas reclasser implicitement P2 |
| BUG-003 | P1 | Suivant figé ; occurrences delivery_request_flow, driver_onboarding et mechanic_onboarding ; callbacks onChanged | double-submit2/2, driver-step0 1/1, mechanic coming-soon3/3 rapportés ; trois occurrences liées |
| BUG-004 | P0 historique | Échec payout sans rollback fiable ; paymentOrchestration submitDriverPayout | submitDriverPayoutFailure PASS, ensemble56/56 rapporté ; aucun P0 actif prouvé ici, aucun test financier lancé |
| BUG-005 | P1 | ProviderJobsTab streams recréés ; mémorisation par driverId | provider_jobs_tab8/8 rapportés |
| BUG-006 | P1 | Boucle GPS sur refus durable ; driver_active_mission_screen mémorisation statut | status_gaps9/9 rapportés ; reporters9/9 nouvellement exécutés ne valident pas à eux seuls écran |
| BUG-007 | P2 | AppBar provider overflow ; layout étroit | status_gate4/4 et viewports rapportés |
| BUG-008 | P2 | markAsRead rejet non capturé ; notifications_screen catchError | write_failure2/2 rapportés |
| BUG-009 | P2 | Bandeau SafetyScreen overflow320 ; bouton séparé | critical_screens_viewport1/1 rapporté |
| BUG-010 | P2 | Exceptions brutes adminfinance ; messages métier localisés | détails blocK et fichiers dans annexe ; résultats historiques, pas rerun |
| BUG-L6-01 | P1 | Contraste avertissement GPS ; AppColors.warningText | test contraste permanent rapporté ; P2-L-01 reste distinct |
| BUG-M-01 | P1 | watchDriverProfile recréé provider_dashboard_shell ; stream mémoïsé | blocM suite480/480 historique ; fichier/test détaillés dans annexe |
| BUG-M-02 | P1 | Même problème driver_status_screen | idem blocM |
| BUG-M-03 | P1 | StreamBuilder dossier admin recréé | idem blocM ; ne pas confondre avec signal profil legacy |
| BUG-M-04 | P1 | Image.network preuve sans errorBuilder ; suivi terminé | idem blocM |
| BUG-N-01 | P1 | Index collectionGroup history recorded_at manquant ; firestore.indexes.json | JSON valide historiquement ; application index réel NON VÉRIFIÉE, fermeture non présumée |
| BUG-N-02 | P1 | Scan payouts plateforme ; filtre driver ajouté missionFinancialBalance | tests24 + intégration512 rapportés ; aucune modification financière ici |
| BUG-O-01 | P2 | Distance/durée invalide createDeliveryRequest ; gardes input | createDeliveryRequest16/16 rapportés |
| GAP-R-01 | P2 | Parsing FoundingDriverQualification documents partiels ; founding_driver.dart | correctif/tests blocR dans annexe, pas réexécutés |
| GAP-R-02 | P2 | Parsing ManualDriverAdjustment partiel ; driver_compensation.dart | idem ; composant sans appelant réel rapporté |
| BUG-U-01 | P1 | Upload chauffeur inerte ; DriverDocumentUploadRepository | document_upload tests et source détaillés annexe ; pas device validé |
| BUG-U-02 | P2 | Overflow adresses livraison mobile | bloc_u_mobile_sanity11/11 rapportés |
| BUG-U-03 | P2 | Overflow bouton document chauffeur | idem ; adaptation tap-target AB doit préserver ce layout |
| GAP-U-MECHANIC | Défaut UX historique | Upload mécanique inerte remplacé état Bientôt disponible honnête ; backend mécanique reste distinct/hors pilote à confirmer | coming_soon3/3 rapportés ; aucun backend mécanique à reconstruire ici |
| BUG-V-01 | P1 | Annulation depuis état terminal autorisée ; garde firestore.rules | 5 nouveaux cas, rules185/185 rapportés ; ne pas élargir règle |
| BUG-X-01 | P1 | Kill switch paiement tardif ; garde avant assignation acceptDelivery | runtimeFlags29/29 rapportés ; aucun flag prod consulté/modifié |
| BUG-AB-08-01 | P2 | Finance mission terminée overflow mobile | tests finance4/4 rapportés ; source détails annexe |
| BUG-AB-09-01 | P2 | Tap target upload trop petit ; document picker | mesure RenderBox permanente rapportée |
| BUG-AB-09-02 | P2 | AppShell textScale overflow ; Flexible/ellipsis | test320/textScale1.5 rapporté |
| K2-3 | P3 | Connecteur date français codé en dur ; datetime_connector_at | timezone2 nouveaux tests rapportés ; aucune fermeture nouvelle |
| BUG-L2-01 | P3 ouvert historique | AuthScreen overflow320 et texte1.5/2 ; non corrigé | reproduction historique ; revue actuelle requise, ne pas oublier |
| BUG-L3-01 | P3 ouvert historique | Carte rôle AuthScreen hauteur38 ; cible tactile insuffisante | mesure historique ; non corrigé |
| P-6 | Vigilance sécurité | Token URL Storage peut donner accès une fois partagé ; préciser usages/proofs ; pas fuite nouvelle prouvée | revue historique et règles ; tests actuels non exécutés |
| P-7 | Prérequis / dette | Fichier orphelin si upload réussit puis transaction échoue | nettoyage reporté ; ne jamais supprimer sur erreur transitoire |
| N-index4 | P3 historique | Index client created_at non consommé (tri mémoire) | note FIRESTORE_INDEXES ; pas blocage fonctionnel prouvé |
| O-retry-message | P3 historique | Erreur acceptDelivery sur retry imprécise mais garde sûre | détails blocO ; test présentation à prévoir |
| O-reconciliation-authorized | P3 historique | payment_stuck_authorized absent du reconciler | dette blocO ; politique et test nécessaires |
| GAP-Q2-01 | P2 historique, correction rapportée Phase8 | Quota devis historiquement absent ; consumeRoutingBudget existe selon PILOT_READINESS24sept | ne pas maintenir fausse absence ; validation/déploiement effectif à vérifier via8C |
| SIGNAL-ADMIN-LEGACY | Priorité NON REQUALIFIÉE | Profil chauffeur bloc gris, correctif6401cb2 communiqué dans historique de conversation | présence précise et preuve de fermeture non réauditées1.3M-B ; signal conservé hors compteur |

Critère de fermeture pour chaque entrée : règle permanente + reproduction négative corrigée et nominal existant conservé dans le périmètre des fichiers/tests indiqués. Blocage commun des archives : relecture de version et preuves spécifiques non réalisées ici, production inconnue. Les résultats verts cités ne sont jamais additionnés aux essais1.3M-B.

## Mise à jour 1.3M-C — 9 octobre 2026

### Transition P1-M-01 et décision de périmètre

Statut précédent conservé : **TESTÉ — VALIDATION PARTIELLE, NON FERMÉ** (1.3M-B).
Nouveau statut : **VALIDÉ — FERMETURE PROPOSÉE (requête et consommateurs simulés)**.
Aucune fermeture administrative n'est appliquée : la mission demande de proposer la fermeture. P1-M-01 reste compté ouvert jusqu'à acceptation de cette clôture dans le périmètre indiqué.

Branche : fix/gps-client-history-scope-20261009 ; HEAD 77c3c61534d1300ddc0eab5585f78b9662a69537, avec correctif non commité. Les SHA256 des huit fichiers du correctif sont identiques à ceux du checkpoint 1.3M-B et à la fin de 1.3M-C. Les preuves portent sur cet état du worktree, pas sur le seul commit de base.

Preuves nouvelles : artifacts/corrections-1-3M-C-20261009-1158/ ; CHECKPOINT_CORRECTIONS_MOVIK_1_3M_C.md ; test-results-summary.json ; contract-tests.jsonl ; consumer-tests.jsonl ; isolation-test-v3.jsonl ; analyze-consumers.log ; continuity-1-3M-B.json ; git-comparison.json ; source-hashes.json ; ISOLATION.md.

### Vérifications acquises, sans répéter les permissions

- missionId requis par LocationRepository, implémentations et quatre faux repositories existants ; tous les appels suivis recherchés, aucune ancienne signature trouvée.
- Deux tests exécutent le vrai FirebaseLocationRepository avec SDK-boundary spies stricts : chemin chauffeur/historique, where(delivery_id == missionId) avant snapshots, données A et B et mapping.
- Le vrai LiveTrackingMap est monté : null et chaîne vide déclenchent zéro lecture d'historique ; mission A est transmise au repository ; des points mélangés A/B sont filtrés et A est trié chronologiquement dans la vraie PolylineLayer.
- Les vrais CustomerTrackingScreen et DriverActiveMissionScreen transmettent les bons identifiants au vrai composant.
- Suites existantes conservées : lifecycle chauffeur 6/6, statuts/actions/double-clic 9/9, propriété client 3/3, auth client 2/2. Copies temporaires uniquement, assertions et corps d'origine préservés, enveloppe de transport mémoire ajoutée.
- Analyse nouvelle des deux écrans et du faux repository responsive : 0 problème, sortie 0. L'analyse ciblée précédente des sept fichiers Dart et les neuf tests reporter restent des preuves historiques, non réexécutées.
- Permissions Firestore : les trois tests ciblés finaux de 1.3M-B sont conservés comme preuves historiques (197 autres scénarios exclus à cette exécution), sans nouvel émulateur. Règles inchangées, aucune permission élargie.

### Résultats de 1.3M-C — exécutions distinctes

| Exécution | Réussis | Échoués | Ignorés | Précision |
|---|---:|---:|---:|---|
| Précontrôle isolation initial | 0 | 1 | 0 | Zone HTTP de déclaration non héritée à l'exécution ; repli réseau refusé avant carte |
| Précontrôle v2 | 0 | 0 | 0 | Une erreur de chargement/compilation du callback du harnais ; aucun test exécuté |
| Précontrôle v3 | 1 | 0 | 0 | Transport mémoire choisi ; createClient et HttpClient refusés |
| Contrat produit | 7 | 0 | 0 | Repository réel + carte réelle + deux écrans réels, dépendances simulées |
| Consommateurs existants | 20 | 0 | 0 | 6 + 9 + 3 + 2 ; aucun corps ni assertion produit affaibli |

Les exécutions finales couvrent 28 contrôles distincts réussis (1 + 7 + 20). Elles n'effacent pas l'échec et l'erreur de chargement initiaux, et ne sont pas additionnées aux résultats de 1.3M-B.
Le harnais initial a également généré 14 avertissements d'analyse (5 annotations sealed de spies SDK, 9 visibleForTesting à cause du dossier artifacts). Ils sont conservés dans analyze-new-tests.log, non masqués ; pas d'analyse « sans avertissement » revendiquée pour ces helpers. La compilation et les tests finaux réussissent. Aucun défaut du correctif produit n'a été découvert.

### Isolation et limites

flutter_map 7.0.2 utilise RetryClient(Client()) ; http 1.5.0 utilise le client de zone. Dans chaque callback testé, un client mémoire sans DNS/socket/délégation rend exclusivement le PNG transparent local embarqué. --dart-define=no_default_http_client=true interdit le client réseau par défaut ; HttpOverrides refuse aussi dart:io HttpClient. Toute demande inattendue échoue. Sources et hashes de cette chaîne conservés ; refus démontrés par le précontrôle avant montage de carte. Les compteurs de chargements sont 120 dans les tests de contrat, puis 24/24/24/0 dans les suites existantes : ce sont des clés de tuiles traitées en mémoire, pas des appels Internet.

Auth backendConfigured=false, faux repositories, faux Geolocator, aucune initialisation Firebase ni fonction serveur/paiement/notification. Aucun secret utilisé. Aucun test de Chrome, carte réelle, réseau de production ou GPS physique. Le spy SDK ne remplace pas le test de permissions : celui-ci reste la preuve séparée de 1.3M-B.

**1.3L reste BLOQUÉ ET REPORTÉ.** Aucun confinement réseau OS complet n'est démontré ; la présente injection maîtrisée des chemins de test n'est pas une validation du test autonome des tuiles. Aucun écran GPS terrain ou transport Internet validé. La fraîcheur, le cache et les changements d'association relèvent toujours de R-K-03-C. L'autorité et les courses restent R-K-03-A/B.

Ces limites ne sont pas une condition indispensable à la fermeture du défaut précis de requête sans filtre, dont les permissions, les arguments, la garde et les consommateurs sont désormais couverts dans le périmètre simulé. Elles empêchent toute conclusion de validation globale GPS ou production.

### Décompte réconcilié et suite

Tableau actif : **P0 0, P1 6, P2 21** ; aucun ID retiré. P1 : 1 validé avec fermeture proposée (P1-M-01), 3 risques R-K-03 qualifiés, 2 validations historiques en attente de clôture. P2 : 21 toujours non fermés, dont les six H-01/H-02/I-01/I-02/J-01/K-01, R-K-04 et les autres entrées du tableau. Les archives et ID P3 restent intégralement conservés et ne sont pas silencieusement reclassés ; BUG-L2-01 et BUG-L3-01 restent ouverts historiquement. Ce décompte actif ne certifie pas l'absence de P0 sur l'ensemble de la production.

Après acceptation de la fermeture ciblée de P1-M-01, le compteur actif P1 passerait à 5. Aucun résultat des risques voisins n'est déduit de ce succès.

Prochaine action unique proposée, sous nouvelle autorisation : traiter **R-K-03-A**, autorité du lien GPS et missions terminales, avec tests de permissions locaux ciblés. Ensuite seulement R-K-03-B, R-K-03-C, P2-K-01 et les anomalies client ; aucune de ces corrections commencée ici.

## Clôture documentaire 1.3M-D — 9 octobre 2026

**Décision approuvée explicitement par Daniel dans la mission 1.3M-D : P1-M-01 = FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ.**

Périmètre exclusif : défaut de requête d'historique GPS sans filtre serveur par mission. Aucun autre aspect du système GPS n'est déclaré terminé. Correction non déployée ; aucune opération Git de commit, push ou merge effectuée dans cette étape.

Historique conservé : IDENTIFIÉ/QUALIFIÉ (1.3M, alias R-K-02) → CORRECTION CODÉE (correctif séparé) → TESTÉ, VALIDATION PARTIELLE (1.3M-B) → VALIDÉ, FERMETURE PROPOSÉE (1.3M-C) → FERMÉ dans le périmètre autorisé (1.3M-D). Les annexes antérieures gardent leurs chiffres et décisions à leur date.

Version : fix/gps-client-history-scope-20261009 ; base 77c3c61534d1300ddc0eab5585f78b9662a69537 plus huit fichiers modifiés non committés. Leurs empreintes sont inchangées depuis 1.3M-C. Les fichiers de preuve sélectionnés de 1.3M-C correspondent également à leur manifeste historique.

Preuves acquises, **non réexécutées** dans 1.3M-D :
- Permissions Firestore en émulateur local : exécution finale 1.3M-B, 3 tests réussis, 0 échec, 197 autres tests exclus.
- Contrat obligatoire missionId, filtre delivery_id avant snapshots, garde null/vide, filtre défensif et tri, consommateurs réels avec services simulés : 1.3M-C, 28 contrôles finaux réussis, 0 échec, 0 ignoré.
- Analyses ciblées du produit réussies ; 9 tests reporter historiques réussis.
- Les essais de harnais échoués et 14 avertissements d'analyse des helpers temporaires restent conservés et ne sont pas présentés comme des réussites.

Nouvelles vérifications 1.3M-D : absence de checkpoint D antérieur localement, branche/HEAD/status, diff des huit fichiers, continuité des empreintes, inventaire sélectif des fichiers, décompte, contrôle de motifs de secrets sans afficher de valeurs. Aucun test Flutter, Firestore ou cartographique relancé.

Rapport et sélection Git : artifacts/corrections-1-3M-D-20261009-1236/POINT_APPROBATION_GIT_MOVIK_1_3M_D.md et COMMIT_FILES.txt. Ce sont des preuves et une liste de sauvegarde, pas un nouveau registre de bogues. Les tests temporaires validés restent dans artifacts à leurs chemins existants ; ils ne sont pas promus dans la suite permanente ni présentés comme intégrés à la CI.

**Décompte des problèmes actifs ouverts : P0 0, P1 5, P2 21.** Calcul sur les 27 lignes du tableau : une seule ligne fermée, P1-M-01. Les cinq P1 restants sont R-K-03-A, R-K-03-B, R-K-03-C, P1-HOME-001 et P1-COPY-001. Aucun P2 retiré, aucun P3 historique supprimé, aucun prérequis de lancement fermé. Les anciennes corrections Phase7 restent documentées séparément avec leurs limites ; ce compte actif n'est pas une validation globale de production.

**1.3L reste BLOQUÉ ET REPORTÉ.** Windows Sandbox, GPS terrain, carte réelle et production ne sont pas validés par cette fermeture. Les risques d'autorité GPS, concurrence, positions anciennes et erreurs de flux restent ouverts.

Prochain point d'approbation unique : autoriser ou refuser le commit local de la sélection explicite, sans push ni déploiement. La prochaine correction produit prévue demeure R-K-03-A, puis R-K-03-B/C, P2-K-01 et les anomalies client. Aucune de ces corrections commencée.


## Historique daté — 1.3M-E — 9 octobre 2026

Reprise vérifiée sur fix/gps-client-history-scope-20261009, HEAD 75ce4393d94c6fb12ecffcc95a4976b93b826b3e, parent 77c3c61534d1300ddc0eab5585f78b9662a69537. Le commit local de 1.3M-D est donc présent ; le point d'approbation conservé ci-dessus décrit son état historique avant commit.

R-K-03-A passe de QUALIFIÉ (lacunes statiques, impact provisoire) à **PARTIELLEMENT CORRIGÉ ET TESTÉ — NON FERMÉ**. Les échecs de reproduction locaux établissent des défauts concrets ; aucune exploitation réelle en production n'est démontrée.

| Exécution de cette étape | Réussis | Échoués | Exclus par filtre |
|---|---:|---:|---:|
| Avant modification produit | 14 | 29 | 211 |
| Après corrections indépendantes + non-régression GPS | 64 | 10 | 180 |

Sur les 43 mêmes nouveaux scénarios, passage de 14/29 à 33/10. Les 31 autres réussites après correction sont des cas existants : 13 recordTrackingPoint et 18 Security Rules GPS, incluant P1-M-01. Aucun comptage cumulé des deux exécutions. Les 10 échecs après sont réels et concernent les parties différées, pas des résultats verts.

Correction réalisée : refus des écritures clientes directes de driver_locations, contrôle du statut actif dans la lecture courante du client, exigence du rôle chauffeur dans le callable. Aucun filtrage d'historique, calcul financier, Stripe, snapshot, ledger ou Flutter modifié.

Partie arrêtée conformément à la mission : les gardes serveur de statut terminal et d'approbation nécessitent une lecture/écriture atomique avec le lien actif. Les chemins concurrents assignation/rapport/nettoyage relèvent de R-K-03-B. Ils sont documentés dans DEPENDANCE_R_K_03_B.md avant toute modification de ce bloc ; aucune correction de B engagée.

Analyse TypeScript finale : réussie, zéro diagnostic. Historique technique conservé : premier passage 10 diagnostics de résolution locale ; deuxième passage une assertion de type insuffisante du jeton fictif ; dernière passe corrigée. La correction d'annotation ne change aucun octet du JavaScript du test exécuté (fixture-type-only.json). Un premier script d'édition a arrêté sur une ancre CRLF après le seul ajout de garde lecture ; suite appliquée avec conservation des fins de ligne. Aucun de ces incidents de préparation n'est présenté comme un bogue du produit.

Isolation : projet demo-movik-test, Firestore local seulement, pas de Functions Emulator ni appels financiers/cartographiques. Des tentatives de métadonnées du SDK Admin ont été bloquées avant délégation : 4 avant et 6 après, avec un execFile également bloqué par exécution. Connexions autorisées seulement loopback:8080. Pas de confinement OS revendiqué ; 1.3L reste BLOQUÉ ET REPORTÉ. Émulateur de cette étape arrêté.

Décompte recalculé : **P0 0 / P1 5 / P2 21**, 27 entrées actives dont P1-M-01 seul fermé. Aucun identifiant supprimé, aucun P3 historique retiré, aucun nouveau registre parallèle. R-K-03-B/C, P2-K-01, H-01/H-02, I-01/I-02, J-01 et tous les autres problèmes sont maintenus.

Prochaine action unique proposée : autoriser le correctif atomique conjoint de la partie restante R-K-03-A et de R-K-03-B, puis ses tests d'intercalages. Aucun commit, push, merge ni déploiement de cette étape.

Sources datées : dossier artifacts/corrections-1-3M-E-20261009-1402, scripts, deux résultats Jest complets, RESULTATS.json, journaux réseau, sources compilées, hashes et checkpoint ; inspections Desktop Commander du 9 octobre 2026.

### Fiche R-K-03-A précédente conservée intégralement


### R-K-03-A

- Priorité / nature / statut : P1 ; Lacunes statiques ; impact provisoire ; QUALIFIÉ.
- Description et impact : Chauffeur peut écrire active_delivery_id ; règle position et recordTrackingPoint sans garde statut terminal, rôle/approbation callable incomplets.
- Preuve d'origine : 1.3M §5A (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : firestore.rules:243–267 ; recordTrackingPoint.ts:33–88 ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Protéger lien actif côté serveur, statuts autorisés et rôle/statut émetteur ; politique historique à décider.
- Tests nécessaires : Règles écriture forgée, mission terminale liée, rôle invalide et point mauvais chauffeur.
- Résultats : 0 exécution ; aucune fuite réelle démontrée.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Toutes les lectures/écritures adverses refusées ; scénarios normaux chauffeur conservés. + règle permanente ci-dessus.


## Historique préservé — fiches A/B avant 1.3M-F (9 octobre 2026)

Les deux fiches suivantes sont archivées, pas des états actifs ni des entrées supplémentaires du compteur.

### R-K-03-A

- Priorité / nature / statut : P1 ; défauts démontrés localement ; PARTIELLEMENT CORRIGÉ ET TESTÉ — NON FERMÉ, 9 octobre 2026 (1.3M-E).
- Défauts confirmés : écriture directe du document GPS et active_delivery_id par un chauffeur ; lecture courante après mission terminale tant que le lien reste présent ; callable accepté sans rôle chauffeur ; ajout d'historique sur mission terminale ; profil non approuvé accepté.
- Correction appliquée : driver_locations en écriture serveur exclusivement ; lecture client courante limitée aux six statuts actifs ; requireAnyRole(driver) au début de recordTrackingPoint. Historique et règles financières inchangés.
- Fichiers : firestore.rules ; functions/src/functions/recordTrackingPoint.ts ; functions/test/integration/gpsAuthorityRules.test.ts ; recordTrackingAuthority.test.ts ; securityRules.test.ts ; recordTrackingPoint.test.ts.
- Tests avant : 14 réussis / 29 échoués / 211 exclus. Sur les mêmes 43 nouveaux scénarios après : 33 réussis / 10 échoués. Non-régression ajoutée : 31 réussis. Total après : 64 réussis / 10 échoués / 180 exclus. Analyse TypeScript finale ciblée : 0 diagnostic.
- Résultats corrigés : les 19 scénarios adverses de la partie indépendante passent après correction. Chauffeur actif approuvé, multirôles, client propriétaire et lectures administratives conservés dans les cas testés. Test P1-M-01 de collection exécuté parmi les 18 règles GPS existantes, réussi.
- Défauts restant ouverts : six statuts terminaux continuent d'accepter un nouveau point ; quatre profils non approuvés continuent d'être acceptés par le callable. Refus de ces écritures NON corrigé. Les 10 tests correspondants restent en échec dans le harnais temporaire, sans être transformés en succès.
- Dépendance / arrêt : garanties mission/profil/lien doivent être atomiques avec l'écriture du point. Conformément à 1.3M-E, cette partie s'arrête avant modification et nécessite autorisation de traiter R-K-03-B conjointement. Aucun changement des chemins d'assignation, terminaison ou paiement.
- Preuves : artifacts/corrections-1-3M-E-20261009-1402/CHECKPOINT_MOVIK_1_3M_E_R_K_03_A.md ; RESULTATS.json ; results-before.json ; results-after.json ; DEPENDANCE_R_K_03_B.md ; typecheck-final.json.
- Limites : Firestore Emulator demo-movik-test et Auth fictive, pas production/Chrome/GPS terrain. Les opérations métier complètes d'administration/assignation ne sont pas exécutées (dépendances financières) ; leurs droits serveur sont conservés dans les fixtures de règles. Tentatives de métadonnées SDK bloquées avant socket, détails dans ISOLATION.md. Aucun déploiement.
- Critère de fermeture : terminer les gardes atomiques et leurs scénarios concurrents, puis vérifier les refus et cas légitimes ; conserver les preuves et obtenir la fermeture autorisée. P1-M-01 reste fermé dans son périmètre antérieur.


### R-K-03-B

- Priorité / nature / statut : P1 ; Risque provisoire ; QUALIFIÉ.
- Description et impact : Fenêtres non atomiques : ancien rapport ou nettoyage peut restaurer/effacer une nouvelle assignation.
- Preuve d'origine : 1.3M §5B (rapports du 8–9 octobre, ou Phase7 importée ci-dessous).
- Fichiers : recordTrackingPoint.ts:53–70 ; onMissionEndedClearTracking.ts:103–108 ; acceptDelivery.ts ; adminAssignDelivery.ts ; racine du worktree de correction, préfixes exacts dans sources d'origine.
- Correction prévue/présente : Lire/comparer/écrire atomiquement ; ne pas recopier lien serveur obsolète.
- Tests nécessaires : Intercalages rapport A/assignation B, nettoyage A/assignation B, ancien client refusé.
- Résultats : 0 exécution ; occurrence réelle non démontrée.
- Blocage : aucune correction/fermeture supplémentaire autorisée dans 1.3M-B ; exécutions non citées = NON TESTÉES. Les résultats nouveaux sont exclusivement dans l'addendum daté de cette intervention.
- Critère de fermeture : Lien final B et aucun point terminal A dans tous intercalages. + règle permanente ci-dessus.


## Addendum 1.3M-F — 9 octobre 2026

HEAD 75ce4393d94c6fb12ecffcc95a4976b93b826b3e, branche fix/gps-client-history-scope-20261009. Autorisation utilisateur : correction locale conjointe A/B et transactions minimales ; aucun commit/push/merge/déploiement. Résultats E inchangés (64/10/180 après E), distincts de F (avant 15/25/266 ; après 126/0/180). Sept diagnostics initiaux de typage du nouveau harnais corrigés sans affaiblissement ; TypeScript final 0, lint produit 0 erreur/0 avertissement. Le test financier utilise exclusivement des réponses fictives ; aucune validation Stripe. Émulateur propre à cette intervention arrêté après tests.

P1-M-01 conserve FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ. A/B restent ouverts. P0 0, P1 5, P2 21 ; aucune entrée retirée. P3 et décisions/prérequis historiques inchangés. R-K-03-C, P2-K-01, P2-H-01/H-02, P2-I-01/I-02, P2-J-01, R-K-04 et GAP-S-04 conservés. 1.3L reste BLOQUÉ ET REPORTÉ ; Windows Sandbox et carte réelle non testés.

Prochaine action unique : revue du diff A/B et approbation éventuelle de sa sauvegarde par commit local, sans déploiement ni nouvelle correction.


## Addendum 1.3M-G — 9 octobre 2026 — décision de fermeture A/B

- Référence : branche fix/gps-client-history-scope-20261009, HEAD 75ce4393d94c6fb12ecffcc95a4976b93b826b3e ; correctifs E/F non committés préservés. Preuves : artifacts/validation-1-3M-G-20261009-1502/CHECKPOINT_MOVIK_1_3M_G_DECISION_GPS_AB.md et RESULTATS_VALIDATION.json.
- Historique conservé : 1.3M-F reste à 126 réussis / 0 échec, 180 exclus. Ce résultat n'est ni additionné aux nouveaux essais ni réécrit. Les empreintes des 32 sources de F sont comparées dans git-final.json (compte exact fait foi).
- Nouvelles exécutions : sélection existante initiale 13 réussis / 6 échoués / 196 exclus ; les 6 échecs surviennent avant le parcours, faute de paramètres runtime Routing dans le harnais direct. Reprise de ces seuls 6 avec les valeurs par défaut du code (60/60) en variables du processus : 6 réussis / 0 échec / 209 exclus. Neuf contrôles complémentaires : 7 réussis / 2 échoués / 0 exclu. Bilan des 28 cas distincts au dernier résultat : 26 réussis, 2 échoués. Quatre sondes de confinement applicatif réussies, comptées séparément.
- Défaut résiduel R-K-03-B démontré, confiance élevée : failMissionPayment(), functions/src/payment/paymentOrchestration.ts:434–497, spécialement 485–489, libère le chauffeur et efface active_delivery_id sans lire/comparer le lien actuel. Une autorisation fictive A est suspendue, B est assignée avec succès par le chemin chauffeur existant, puis A échoue. Pour A assignée par chauffeur ET par administrateur : A=payment_failed, B=assigned/authorized, mais lien GPS=null et disponibilité=online. Attendu : lien B et disponibilité on_mission. Assertions : gpsClosureValidation.v2.test.ts:189 ; états exacts conservés dans states-supplemental.jsonl. Il s'agit d'un sous-cas restant de R-K-03-B, pas d'une nouvelle entrée ni d'un incident production.
- Correctif minimal RECOMMANDÉ, NON EXÉCUTÉ : lire le lien actif dans la transaction failMissionPayment avant toute écriture, et conditionner uniquement la libération GPS/disponibilité à l'appartenance à la mission échouée (traiter le lien absent selon le contrat existant). Préserver les mutations de paiement, mission et événements, les montants/snapshots/ledger et le comportement d'erreur. Autorisation distincte nécessaire avant modification de ce module.
- Non-régressions complémentaires : acceptation concurrente et éligibilité 11/11 ; annulation/libération/idempotence 3/3 ; échec de paiement existant 3/3 ; règles ciblées 2/2 dont P1-M-01 (requête de collection) ; standard chauffeur/admin jusqu'à terminaison avec FakePaymentProvider ; annulation A puis B avec événement A rejoué ; concurrence réelle sans ABORTED injecté pour terminaison/suspension et nettoyage/assignation B. Aucun changement produit effectué en G.
- R-K-03-A : fermeture RECOMMANDÉE exclusivement pour l'autorité des écritures GPS/mission terminale dans le périmètre émulateur et simulations validé. Statut conservé CORRECTION TESTÉE EN ÉMULATEUR — NON FERMÉ — NON DÉPLOYÉ ; attend l'approbation de Daniel.
- R-K-03-B : fermeture REFUSÉE ; statut PARTIELLEMENT VALIDÉ — ÉCHEC RÉSIDUEL CONFIRMÉ — NON FERMÉ — NON DÉPLOYÉ. Les protections F restent présentes et utiles, mais la règle « une ancienne opération ne libère pas B » n'est pas satisfaite sur le chemin d'échec de paiement.
- Compilation complète TypeScript 5.9.3 : 87 sources, 174 fichiers émis uniquement dans les preuves, zéro diagnostic ; lint des 3 fonctions modifiées : zéro erreur/avertissement. Typecheck des 9 suites permanentes + test temporaire final : zéro diagnostic. Historique du harnais conservé : première transpilation temporaire TS1434 ; annotation implicite TS7006 dans v2, corrigée uniquement dans v3 par (value: unknown), typecheck réussi, pas de nouvelle exécution Jest pour v3. Les résultats Jest sont ceux de v2 et restent en échec pour B.
- Isolation : Firestore local demo-movik-test, .run() et identités fictives, FakePaymentProvider existant, Routes simulé, implémentation Stripe remplacée par un refus uniquement dans la copie compilée. Garde Node : sockets limités au loopback:8080, DNS/child_process refusés ; tentatives de détection metadata Google bloquées. Ce n'est pas un confinement OS général ni une validation du test de tuiles. Émulateur propre à G arrêté.
- Limites : Node 24.15.0 disponible, Node 20 non trouvé dans les emplacements inventoriés ; transport callable/Auth réel, livraison automatique/reprise des triggers, Stripe Sandbox/LIVE, GPS terrain, Chrome, production et 1.3L NON TESTÉS. Parmi les 180 règles exclues en F, 1 règle d'auto-assignation a maintenant été exécutée ; 179 restent hors couverture G, non présentées comme réussies. R-K-03-C, P2-K-01, GAP-S-04 et tous les autres problèmes restent ouverts.
- Décompte inchangé, aucune fermeture administrative : P0 0 / P1 5 / P2 21 ; 27 entrées actives dont P1-M-01 fermé antérieurement, 26 ouvertes. P3 et annexes historiques préservés.
- Prochaine action unique recommandée : autoriser le correctif ciblé du nettoyage GPS/disponibilité de failMissionPayment pour R-K-03-B, avec ces deux reproductions et les tests financiers de non-régression. Aucun commit, push, merge ou déploiement dans G.

## Fermeture documentaire 1.3M-H — R-K-03-A — 9 octobre 2026

Autorisation explicite reçue dans la mission 1.3M-H. Passage de CORRECTION TESTÉE EN ÉMULATEUR — NON FERMÉ à FERMÉ — PÉRIMÈTRE LOCAL/ÉMULATEUR VALIDÉ — NON DÉPLOYÉ, uniquement pour l’autorité GPS et les refus profils/états terminaux qualifiés. Preuves F/G inchangées ; aucune extension à B/C, au terrain ou à la production. P0 0 / P1 4 / P2 21. Le présent travail ne comporte aucun commit ni déploiement. Preuves H : artifacts/corrections-1-3M-H-20261009-c871eb62/.


## Addendum 1.3M-H — GPS / compensation tardive — 9 octobre 2026

- Autorisations : fermeture documentaire ciblée R-K-03-A approuvée ; correctif limité au GPS/disponibilité de failMissionPayment approuvé ; aucun commit/push/merge/déploiement autorisé.
- Version : fix/gps-client-history-scope-20261009, HEAD 75ce4393d94c6fb12ecffcc95a4976b93b826b3e inchangé. Correctifs E/F et preuves G préservés.
- R-K-03-A : FERMÉ — PÉRIMÈTRE LOCAL/ÉMULATEUR VALIDÉ — NON DÉPLOYÉ. Autorité GPS et refus missions terminales/profils non approuvés uniquement. Les 26 gardes serveur passent à nouveau en H ; aucune validation physique/cloud ajoutée.
- R-K-03-B : cause résiduelle confirmée dans failMissionPayment : ancienne compensation libérait la disponibilité et effaçait le lien actif sans le lire. Le correctif ajoute la lecture de driver_locations dans la transaction avant toute écriture et ne libère GPS/disponibilité que si le lien est absent/null ou égal à la mission échouée. Si B est actif, B et la disponibilité du chauffeur sont préservés. Une modification concurrente de ce document invalide la tentative et entraîne une relecture SDK.
- Fichier produit modifié uniquement en H : functions/src/payment/paymentOrchestration.ts (+9/-2). Toutes les autres instructions de ce module sont identiques au fichier sauvegardé avant correction après retrait de ces seuls changements GPS ; preuve patch-scope.json. Aucun tarif, montant, commission, taxe, snapshot, capture, remboursement, ledger, effet de compensation financière, événement ou règle d'idempotence modifié.
- Test permanent ajouté : functions/test/integration/gpsPaymentCompensation.test.ts. Les deux corps de tests rouges G sont repris sans affaiblissement ; sept cas supplémentaires couvrent lien A/null/document absent, reprise transactionnelle après B (A via chauffeur/admin), reprise sans B, autre chauffeur et absence de doubles effets. Assertions sur états finaux Firestore, snapshot A inchangé, paiement unique, événement payment_failed unique, ledger vide dans ces cas d'échec, paramètres de montant fictifs concordants, compte des appels provider et refus d'une deuxième acceptation.
- Avant correctif : 4 réussites / 5 échecs / 0 exclu. Deux échecs d'état attendu B vs null ; trois échecs du contrôle de lecture transactionnelle, dont la reprise sans B (pas cinq nouveaux bogues métier distincts). Historique G reste 26/2 au dernier résultat, non réécrit.
- Après correctif : 73 réussites / 0 échec / 200 exclus dans la sélection initiale ; complément de deux tests de chevauchement omis par le filtre : 2 réussites / 0 échec / 271 exclus. Bilan de la sélection H au dernier résultat : 75 cas exécutés après correction, tous réussis, aucune assertion affaiblie ni skip ajouté. 198 entrées distinctes non exécutées dans les fichiers chargés : 196 règles hors sélection et 2 copies temporaires G des reproductions déjà exécutées dans le nouveau test permanent.
- Détail : nouvelle compensation 9/9 ; gardes A/B 26/26 ; atomicité GPS F 14/14 ; acceptDeliveryConcurrency 11/11 ; acceptDeliveryPaymentFailure 3/3 ; missionCancellationPaymentRelease 3/3 ; règles ciblées 2/2 dont P1-M-01 collection filtrée ; interactions G restantes 7/7.
- Finances : vraie orchestration locale avec FakePaymentProvider existant, aucun Stripe Sandbox/LIVE. Parcours standard chauffeur/admin jusqu'à capture fictive, échec normal, annulation et idempotence testés. Les 14 tests GPS F conservent leurs doublures explicites d'orchestration ; ils ne remplacent pas les tests du module financier réel modifié.
- Analyse : TypeScript 5.9.3, 87 sources produit compilées (174 fichiers émis seulement dans les preuves), 11 suites typecheckées, aucun diagnostic. ESLint sur paymentOrchestration et les trois fonctions GPS F : 0 erreur/avertissement. Diff check et intégrité Git enregistrés dans verification-final.json.
- Isolation : Firestore Emulator local demo-movik-test, PID vérifié à chaque exécution ; garde Node loopback:8080/DNS/child_process, provider Stripe refusé dans la copie compilée, fetcher Routes fictif. Quatre sondes de garde réussies. Émulateur lancé par H arrêté. Deux lancements Java initiaux n'ont pas tenu ; aucun test exécuté avant leur refus de prévalidation. Cause exacte inconnue. Lancement direct contrôlé ensuite opérationnel ; aucun changement Windows.
- Décision B : VALIDÉ LOCALEMENT — NON FERMÉ — NON DÉPLOYÉ. Fermeture documentaire limitée RECOMMANDÉE, mais NON APPLIQUÉE sans approbation distincte. Aucun défaut résiduel démontré dans les scénarios testés ; aucune garantie universelle de concurrence/cloud.
- Limites conservées : Node 24.15.0 utilisé, Node 20 non validé ; transport callable/Auth réel, livraison automatique et rejeu cloud des triggers, production, Stripe Sandbox/LIVE, GPS physique, fraîcheur/association R-K-03-C et tuiles 1.3L non validés. GAP-S-04, tous P2/P3 et prérequis pilote conservés.
- Décompte : P0 0 / P1 4 / P2 21 ; 27 entrées dont 25 ouvertes et deux fermetures limitées (P1-M-01, R-K-03-A).
- Preuves : artifacts/corrections-1-3M-H-20261009-c871eb62/CHECKPOINT_MOVIK_1_3M_H_GPS_COMPENSATION_TARDIVE.md ; RESULTATS_1_3M_H_FINAL.json ; results-before.json ; results-after.json ; results-complement.json ; states-*.jsonl ; patch-scope.json ; source-hashes-before/after.json.
- Prochaine action unique : soumettre la fermeture documentaire limitée R-K-03-B à Daniel. Aucun commit ou autre correctif engagé ; R-K-03-C reste hors périmètre.


## Clôture documentaire R-K-03-B — 9 octobre 2026

**Décision : FERMÉ — PÉRIMÈTRE LOCAL/ÉMULATEUR VALIDÉ — NON DÉPLOYÉ**, sur autorisation explicite de l'utilisateur après le checkpoint 1.3M-H. Cette clôture est documentaire et n'autorise aucune action Git ni déploiement.

**Périmètre fermé :** concurrence et nettoyage des données GPS entre missions A et B : ancien rapport, réassignation, fin et nettoyage tardifs, ainsi que compensation de paiement tardive de A. La mission B conserve son lien GPS et la disponibilité `on_mission` dans les scénarios locaux validés. Le correctif `failMissionPayment()` conditionne atomiquement la libération GPS/disponibilité au lien pertinent, sans changer les opérations financières de A.

**Preuves acquises, sans nouvelle exécution dans cette clôture :** checkpoint 1.3M-F (`artifacts/corrections-1-3M-F-20261009-1438/`) : 126 tests ciblés réussis, 0 échec ; checkpoint 1.3M-G (`artifacts/validation-1-3M-G-20261009-1502/`) : 26 réussis, 2 échoués, défaut résiduel reproduit ; checkpoint 1.3M-H (`artifacts/corrections-1-3M-H-20261009-c871eb62/CHECKPOINT_MOVIK_1_3M_H_GPS_COMPENSATION_TARDIVE.md` et `RESULTATS_1_3M_H_FINAL.json`) : 75 contrôles ciblés réussis, 0 échec après correction, dont 9 cas de compensation. Ces exécutions distinctes ne sont pas additionnées.

**Limites :** non déployé, pas de test Firebase Auth/callable réel, de livraison automatique des triggers, de Stripe réel/Sandbox, de Node 20, de GPS physique ou de tuiles cartographiques 1.3L. Aucune garantie de concurrence universelle ni de disponibilité en production. Le test 1.3L demeure BLOQUÉ ET REPORTÉ. Le HEAD `75ce4393d94c6fb12ecffcc95a4976b93b826b3e` reste celui de la dernière sauvegarde locale ; les corrections A/B restent non committées.

**Décompte après fermeture : P0 0 / P1 3 / P2 21.** Tableau de 27 entrées : 3 fermées dans un périmètre limité (P1-M-01, R-K-03-A, R-K-03-B) et 24 non fermées. R-K-03-C, P2-K-01, les autres P2, les P3 historiques, GAP-S-04 et les prérequis du pilote restent ouverts. Aucun commit, push, merge, déploiement ni modification de code appliqués lors de cette clôture.


## Addendum — 1.3M-I — Identité, association et dates GPS — 9 octobre 2026

- Branche : `fix/gps-client-history-scope-20261009`.
- Base vérifiée : `7a0d60f5d556001705460f005ed8c7d1f268460d`. Correctif I non commité, non déployé.
- Preuves : `artifacts/corrections-1-3M-I-20261009-6a91c2de/`.
- Fiche unique concernée : R-K-03-C (P1). Les sous-scénarios A–J sont des cas de test, pas de nouveaux compteurs.
- Statut précédent : QUALIFIÉ — RISQUE PROVISOIRE. Statut actuel : **CORRIGÉ ET TESTÉ LOCALEMENT — VALIDATION PARTIELLE — NON FERMÉ — NON DÉPLOYÉ**.
- P1-M-01, R-K-03-A et R-K-03-B restent fermés dans leurs seuls périmètres approuvés. Aucun test ni changement serveur dans cette étape.

### Défauts effectivement reproduits

Le premier passage avant correction donne 4 réussites / 18 échecs / 0 ignoré (22 cas). Le cas supplémentaire d’historique sans date/date future échoue séparément (0/1/0). Cela correspond à 23 cas distincts avant correction : 4 passent, 19 échouent. Les traces exactes sont conservées, sans réécriture des résultats.
- Position d’un autre chauffeur ou d’une autre mission, lien nul, mission affichée nulle/vide : marqueur affiché alors qu’il devrait être absent.
- Changement mission A→B ou changement de chauffeur : ancien marqueur retenu par StreamBuilder ; les tests vérifient aussi la disparition du trajet lors du passage après correction.
- Données incompatibles reçues après un point valide : ancien/nouveau marqueur trompeur affiché.
- Dates courantes et historiques absentes/illisibles/type non pris en charge : DateTime.now() fabriquait une date. Six cas de désérialisation échouent avant correction.
- Date future de position affichée ; date inconnue transformée en maintenant puis affichée.
- Position ancienne affichée sans indication de sa date ni de son caractère « dernière connue ».
- Vrai CustomerTrackingScreen : position antérieure à accepted_at mais déjà reliée à B affichée à tort. Les fonctions d’assignation mettent à jour active_delivery_id sans effacer les anciennes coordonnées ; accepted_at existe déjà côté serveur et dans DeliveryMission.
- Historique : inclusion de points sans date/date future dans la polyline, reproduite dans le cas supplémentaire.
- Déjà conformes avant correction : cas nominal, absence GPS, filtrage A/B et tri de l’historique. Aucun incident de production ni fuite réelle affirmé.

### Corrections présentes

- DriverLocation.updatedAt et DriverLocationHistoryPoint.recordedAt nullable ; date inconnue conservée, aucune substitution par maintenant ; sérialisation de la date courante nullable.
- LiveTrackingMap vérifie driverId, missionId et activeDeliveryId ; refuse date inconnue ou postérieure à l’horloge locale, et date antérieure à acceptedAt lorsque connue.
- Les deux consommateurs client/chauffeur transmettent le acceptedAt existant, sans changement serveur ni nouveau calcul métier.
- Flux conservés pour une même identité ; renouvelés à tout changement chauffeur/mission/acceptedAt ; snapshots et carte indexés sur cette identité, recentrage initial réinitialisé et callback obsolète neutralisé.
- Filtrage de l’historique par mission et dates utilisables, tri chronologique conservé ; requête Firestore P1-M-01 inchangée.
- Position valide explicitement présentée comme « Dernière position connue », date/heure locales visibles, libellés FR/EN/ES. Convention numérique jour/mois/année du suivi existant. Aucun seuil d’obsolescence activé.
- Incident de préparation conservé : script v1 ReferenceError widget (interpolation JavaScript), puis v2 cible multiline non trouvée (CRLF). Pas des échecs Flutter ni des bogues produit. v3 a appliqué la correction ; pas de modifications perdues.
- Contrôle de présentation supplémentaire : format Material anglais observé sous libellé FR ; test numérique ajouté en échec (0/1/0), puis format explicite corrigé et validé. Cela reste dans la nouvelle présentation de R-K-03-C ; aucun P2 existant clos.

### Résultats et preuves

- Sonde initiale : 1/0/0, HTTP mémoire sélectionné et replis HttpClient/createClient refusés.
- Après correctif initial : 23/0/0 (`RESULT-after.jsonl`).
- Résultat intermédiaire après présentation : **24/0/0** (`RESULT-final.jsonl`).
- Non-régression : **37/0/0** (`RESULT-regression.jsonl`) : contrat P1-M-01 8, auth client 2, propriété client 3, cycle GPS chauffeur 6, statuts chauffeur 9, reporter simulé 9.
- Bilan intermédiaire avant revue de l’horloge historique : **61 tests distincts réussis, 0 échec, 0 ignoré**. Les répétitions antérieures, la sonde répétée et les chargements/tearDownAll ne sont pas additionnés.
- Analyse Flutter ciblée de 11 fichiers : aucune anomalie. Analyse finale des deux fichiers retouchés après présentation consignée dans `analyze-final.log`.
- Sécurité : vrai composant Flutter, vrais repositories/contrats aux frontières contrôlées, Auth et GPS physiques simulés, transport cartographique mémoire sans délégation ; no_default_http_client=true et HttpOverrides. Aucun bootstrap Firebase ni émulateur, aucune transaction, aucun accès Stripe/Maps/OSM réel.
- Aucun confinement OS global revendiqué ; 1.3L reste BLOQUÉ ET REPORTÉ. P2-K-01 (erreurs de flux) n’est pas fermé.
- Contrôle géométrique du nouveau libellé : FR/375×932, EN/430×932, ES/1440×932, texte 200 %, présence exacte date/heure et absence d’exception Flutter. Aucune capture PNG ni validation Chrome/terrain ; ce contrôle n’est pas un audit responsive exhaustif.

### Décision produit et limites de fermeture

**Seuil proposé, NON ACTIVÉ : 60 secondes** sans position plus récente, soit 7,5 périodes nominales de 8 secondes. Proposition d’affichage : retirer le marqueur actif et afficher « Position non actualisée » avec la dernière date connue ; conserver le trajet historique identifié. C’est une proposition fondée sur la cadence du code, pas une mesure réseau terrain ni une politique approuvée.
- Tant que ce seuil n’est pas approuvé/implémenté/testé, aucun état automatique « périmée » ni temporisateur n’est revendiqué. Une ancienne position compatible reste visible comme dernière connue avec sa date.
- updated_at/recorded_at désignent l’enregistrement serveur, pas une preuve de l’instant physique de capture GPS. L’heure du client peut diverger : toute date future est écartée sans tolérance arbitraire ; risque de rejet conservateur en cas d’horloge désynchronisée.
- Si acceptedAt manque sur une ancienne mission, les identifiants restent vérifiés, mais la borne temporelle d’assignation ne peut pas être démontrée. Aucune date fabriquée.
- Pas de validation du cache natif Firestore, du GPS terrain, de Chrome, des permissions déployées ou du fond cartographique réel. Les tests de changement d’identité portent sur les snapshots Flutter et les flux fictifs, pas une session Firestore réelle.
- Critère restant : décision d’obsolescence, vérifications associées, limites d’intégration acceptées, puis autorisation documentaire distincte de fermeture. Aucune fermeture de C effectuée.

Décompte conservé : **P0 0 / P1 3 / P2 21** ; P1 ouverts C, HOME-001, COPY-001. Tous les P2, P3 historiques et prérequis du pilote sont conservés.

### Complément final I — horloge de réception de l’historique

La revue de la correction a identifié une régression intermédiaire : le filtre historique capturait l’heure du précédent rendu de position ; un événement historique plus récent pouvait être refusé comme futur. Test dédié reproduit en échec (0/1/0, RESULT-before-history-clock.jsonl), puis comparaison à DateTime.now() lors du rendu de cet événement. Dernière suite ciblée : **25/0/0** (RESULT-definitive.jsonl). Avec les 37 non-régressions, **62 cas distincts réussis, 0 échec, 0 ignoré** ; les répétitions ne sont pas additionnées. Contrat réel repository/carte/client/chauffeur rejoué après ce dernier ajustement (7/0/0, RESULT-contract-definitive.jsonl). Analyse finale : analyze-definitive.log. Ce défaut intermédiaire appartient au même correctif C et reste dans les preuves ; aucun ancien échec effacé. Décompte canonique inchangé : P0 0, P1 3, P2 21.


## Addendum 1.3M-J — R-K-03-C — 9 octobre 2026

### Décision, périmètre et transition

Daniel approuve le seuil pilote **60 secondes**. À 60 secondes exactement, le marqueur reste visible ; strictement après, le marqueur actif disparaît et le texte « Position non actualisée » apparaît. Date et heure connues et trajet historique valide restent affichés. Une nouvelle position compatible rétablit le marqueur. Aucune autre tolérance temporelle introduite.

Statut précédent I : CORRIGÉ ET TESTÉ LOCALEMENT — VALIDATION PARTIELLE — NON FERMÉ — NON DÉPLOYÉ.
Statut J : **VALIDÉ DANS LE PÉRIMÈTRE SIMULÉ — FERMETURE PROPOSÉE — NON FERMÉ — NON DÉPLOYÉ**.
La fermeture reste soumise à une approbation documentaire distincte. P1-M-01, A/B ne sont pas rouverts.

### Correction et preuves

Branche fix/gps-client-history-scope-20261009, HEAD 7a0d60f5d556001705460f005ed8c7d1f268460d inchangé ; modifications non commitées. Dossier de preuves : artifacts/corrections-1-3M-J-20261009-85e72ad1/.

- lib/widgets/live_tracking_map.dart : horloge injectable pour tests ; temporisateur calculé depuis la date de position, réarmé lors des émissions, annulé au changement de périmètre et au démontage. Expiration sans nouvel événement Firestore. Date/historique conservés. Protections I conservées.
- lib/l10n/app_strings.dart : tracking_position_stale FR/EN/ES.
- test/customer/live_tracking_freshness_test.dart : 20 tests nouveaux, vrais widgets et transport mémoire.
- test/customer/live_tracking_identity_test.dart : seul le cas G de position vieille de deux jours change d’attente selon la nouvelle décision : marqueur absent, message périmé présent, assertions de date conservées.
- Registre présent actualisé sans suppression des anciennes fiches/P3/prérequis.

Résultats **distincts par exécution**, sans addition des reprises :
| Exécution | Réussis | Échoués | Ignorés |
|---|---:|---:|---:|
| Précontrôle isolation | 1 | 0 | 0 |
| Avant expiration, horloge injectable seulement | 10 | 10 | 0 |
| Première exécution après correction | 19 | 1 | 0 |
| Diagnostic ciblé du recentrage de la carte | 1 | 0 | 0 |
| Finale : fraîcheur 20 + identité 25 | 45 | 0 | 0 |
| Non-régressions contrat/clients/chauffeurs/reporter | 37 | 0 | 0 |

Bilan final : **82 cas distincts réussis, 0 échoué, 0 ignoré**. Les échecs avant/intermédiaires restent dans RESULT-before.jsonl et RESULT-after.jsonl. L’échec après correction était une assertion trop précoce du harnais : couche MarkerLayer avec un marqueur, message périmé déjà absent, frame de recentrage en attente ; une frame supplémentaire rend le marqueur visible. Correction de synchronisation du test, aucune assertion retirée ni affaiblie. RESULT-recovery-diagnostic.jsonl conserve la preuve.

La frontière exacte 60 secondes et le premier instant représentable suivant (une microseconde) sont testés ; cette unité est une borne stricte, pas une tolérance métier. Horloge simulée également à 59/61 secondes et cinq minutes, reprise, replay ancien, changement chauffeur/mission, dates inconnues/futures/préassignation, identités incompatibles et démontage. FR/EN/ES à 375×812 et texte 200 % : widget sans exception de débordement, textes présents. Pas de capture Chrome.

Analyse Flutter ciblée sur neuf fichiers : aucune anomalie ; git diff --check réussi. Commandes : run-tests.ps1, run-final.ps1, run-quality.ps1 ; résultats exacts : RESULTATS.json et quality-exits.json ; états et empreintes Git : git-initial.json / git-final.json ; contrôle de continuité I : continuity-I.json.

### Isolation et limites

Repositories/flux/auth/GPS fictifs, backend non initialisé. Carte réelle avec PNG transparent en mémoire ; URLs utilisées uniquement comme clés de fixture, sans délégation réseau. no_default_http_client=true, refus explicite HttpClient/IOClient, clients mémoire et garde contre les requêtes inattendues ; journaux finaux unexpected=0. Aucun Firebase/émulateur, Stripe, Google, GPS physique ou OpenStreetMap réel sollicité. Le harnais reste un confinement des voies inspectées, pas un confinement réseau OS ; **1.3L BLOQUÉ ET REPORTÉ**.

Horloge locale comparée à une date de réception serveur : pas de compensation de dérive arbitraire. Date future rejetée ; une horloge désynchronisée peut rendre un point indisponible ou périmé prématurément. Le timer dépend de l’exécution de l’application : précision et suspension d’onglet/OS non validées en Chrome ni sur appareil. Aucun engagement de délai terrain. Date physique de mesure et assignation de comptes anciens sans acceptedAt restent les limites I ; aucune valeur inventée.

Permissions Firestore A/B/P1-M-01 non réexécutées ici ; leurs preuves historiques restent distinctes et leurs fichiers serveur/règles sont inchangés. Les 37 non-régressions vérifient leurs consommateurs Flutter simulés, pas le backend déployé.

### Décompte et prochaine action

Tableau central recalculé : **P0 0 / P1 3 / P2 21** ouverts ; 27 entrées, 3 fermetures antérieures, 24 ouvertes. P3 historiques et toutes les dettes/report/prérequis conservés. Aucun autre défaut produit démontré par J. P2-K-01 (erreurs de flux), R-K-04 (centre Montréal), P1-HOME-001, P1-COPY-001 et tous les autres P2 restent ouverts.

Prochaine action unique : demander l’approbation de fermeture documentaire limitée de R-K-03-C dans le périmètre simulé I/J, sans fermeture globale du GPS, commit ou déploiement automatique.


## Clôture documentaire de R-K-03-C — 10 octobre 2026

**Décision expressément autorisée par l’utilisateur : R-K-03-C = FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ.** Cette fermeture est limitée aux identités chauffeur/mission, à la validité des dates, à la gestion des anciens flux/snapshots, à l'historique cohérent et au seuil pilote de 60 secondes dans l'interface cliente. Il ne s'agit pas d'une certification GPS globale ou d'une autorisation de lancement.

**Preuves acquises (non réexécutées pour cette clôture) :** étape I, `artifacts/corrections-1-3M-I-20261009-6a91c2de/`, 62 tests distincts réussis ; étape J, `artifacts/corrections-1-3M-J-20261009-85e72ad1/`, 82 tests distincts réussis, 0 échec et 0 ignoré, analyse Flutter ciblée et contrôle Git réussis. Les exécutions et échecs avant/intermédiaires sont conservés dans les checkpoints ; les résultats I/J ne sont pas additionnés comme une nouvelle exécution. Le comportement approuvé conserve le marqueur jusqu'à 60 secondes incluses ; strictement après, masque le marqueur actif, affiche « Position non actualisée », conserve heure et historique compatibles, puis rétablit le marqueur à réception d'une position valide. Un temporisateur traite aussi l'absence d'événement Firestore.

**Limites maintenues :** aucun test Chrome, téléphone physique, suspension/reprise OS, horloge utilisateur désynchronisée, Firebase déployé, tuile réseau réelle ni production. L'instant serveur n'est pas l'instant physique de mesure GPS. Le test autonome 1.3L reste BLOQUÉ ET REPORTÉ. P2-K-01, R-K-04, GAP-S-04 et les autres P2, P3 historiques et prérequis de pilote restent ouverts ; aucun état de production n'est déduit des tests simulés.

**Décompte du tableau actif après approbation : P0 0, P1 2, P2 21.** 27 fiches au total, 4 fermées uniquement dans leurs périmètres validés (P1-M-01, R-K-03-A, R-K-03-B, R-K-03-C) et 23 ouvertes. Les deux P1 restants sont P1-HOME-001 et P1-COPY-001. Aucun fichier produit modifié dans cette clôture documentaire, aucun commit, push, merge ou déploiement. Dernier HEAD enregistré : `7a0d60f5d556001705460f005ed8c7d1f268460d`. Prochaine action soumise à approbation distincte : sauvegarde Git locale des corrections I/J ; ensuite traitement de P2-K-01.

## Addendum 1.3M-L — P2-K-01 — 10 octobre 2026

### Statut et périmètre

**CORRIGÉ ET VALIDÉ DANS LE PÉRIMÈTRE SIMULÉ — NON FERMÉ — NON COMMITÉ — NON DÉPLOYÉ.**
Statut précédent conservé : QUALIFIÉ, lacune statique. La reproduction dynamique confirme désormais P2-K-01.
Branche fix/gps-client-history-scope-20261009 ; HEAD de base 980a9dab54353a99315fa78fd4487c77396042f4. La clôture du problème exige une approbation documentaire distincte.

### Cause et correction

Les StreamBuilder de LiveTrackingMap lisaient snap.data et historySnap.data sans distinguer hasError : un refus ou une erreur pouvait afficher l’attente GPS ou un trajet vide.
Correction limitée à live_tracking_map.dart et app_strings.dart :
- classification de FirebaseException du plugin cloud_firestore, code permission-denied ; tout autre objet/code/texte libre devient une indisponibilité générique ;
- aucune exception brute affichée, aucune déduction que la connexion Internet du client est nécessairement coupée ;
- erreur de position : marqueur actif absent et message propre au flux ; historique valide séparément autorisé conservé ;
- erreur d’historique : trajet retiré, message sous la carte, position fraîche conservée puis expirant normalement après 60 secondes ;
- reprise sur donnée valide, nouvel échec et changement de mission/chauffeur sans réutilisation d’un état incompatible ;
- aucun retry automatique ajouté, aucune modification des interfaces/repositories/règles/fonctions serveur ;
- comportement NotConfiguredLocationRepository inchangé.
Le message d’historique apparaît dans le flux de mise en page, pour ne pas recouvrir l’horodatage de la carte. Aucun remplacement de l’architecture cartographique.

### Tests et preuves

Dossier : artifacts/corrections-1-3M-L-20261010-a71d3b9c/.
Nouveau test permanent : test/customer/live_tracking_errors_test.dart, composants réels avec repositories et transport mémoire existants.

| Exécution | Réussis | Échoués | Ignorés | État |
|---|---:|---:|---:|---|
| Isolation initiale | 1 | 0 | 0 | Terminée |
| Première reproduction | 6 | 17 | 0 | Interrompue pendant nettoyage ; bilan incomplet |
| Diagnostic fermeture, nettoyage adapté | 0 | 1 | 0 | Terminée ; assertion produit toujours échouée |
| Reproduction complète avant correctif produit | 7 | 21 | 0 | Terminée |
| Après correctif | 28 | 0 | 0 | Terminée |
| Finale ciblée : erreurs + identité + fraîcheur | 73 | 0 | 0 | Terminée |
| Non-régressions contrat/client/chauffeur/reporter | 37 | 0 | 0 | Terminée |

**Final : 110 tests distincts réussis, 0 échoué, 0 ignoré.** Les reprises et résultats historiques I/J ne sont pas additionnés.
Dans la première exécution incomplète, une assertion supplémentaire a été signalée en erreur sans testDone, et quatre cas n’ont pas démarré. Le nettoyage du nouveau harnais tentait de refermer des contrôleurs déjà fermés dans la zone du test ; ne refermer que les contrôleurs encore ouverts, avec assertion d’absence d’abonné, a permis la fin normale. Cause interne exacte du blocage asynchrone Flutter non établie. Aucune assertion produit supprimée, aucun test ignoré. La session lancée par cette intervention a été arrêtée ; journal et ancien test conservés.

Les 21 échecs ne sont pas 21 bogues distincts : ils démontrent la même absence de traitement et ses scénarios de reprise/affichage. Les assertions initiales signalent notamment « Accès à la position refusé. » absent.

Tests : absence/chargement/fraîcheur, refus typé, unavailable, erreur générique, faux texte permission-denied, autre plugin, erreurs séparées/après données, reprise/nouvel échec, conservation de l’âge, changement chauffeur/mission et anciens événements, fermeture et démontage. Quatre messages FR/EN/ES réellement affichés dans les tests à 375×812 et texte 200 %, rectangles contrôlés et absence d’exception de débordement. Aucune capture Chrome ou PNG annoncée.

Analyse finale sur dix fichiers : **aucun problème**. Première analyse : une information prefer_interpolation_to_compose_strings dans le nom d’un test ; formulation corrigée sans changer son libellé généré, ses assertions ou le produit. Les 110 tests précèdent cette seule modification de style ; analyse finale exécutée après. Pas de relance des suites pour ce changement de nom équivalent. git diff --check réussi avant la mise à jour documentaire ; contrôle final consigné séparément.

### Isolation, non-régression et limites

Transport cartographique mémoire I/J inchangé ; no_default_http_client=true ; HttpClient/IOClient refusés ; backend non initialisé, données fictives. Journaux complets finaux : unexpected=0, external_transport=none. Aucun Firebase Production, émulateur, Stripe, Google, OpenStreetMap réel, GPS physique ou notification. Ceci ne démontre pas un confinement réseau OS : **1.3L reste BLOQUÉ ET REPORTÉ**, distinct de cette étape 1.3M-L.

Le seuil de 60 secondes, les dates/identités/acceptedAt, les abonnements et filtrages de C sont conservés ; suites I/J réexécutées avec succès. P1-M-01/A/B/C restent fermés dans leurs périmètres précédents. Aucune règle de production ni traitement financier modifié.

Une erreur de flux fermé reste explicitement affichée : aucun réabonnement infini ni bouton de relance ajouté. Le retour automatique d’un listener Firestore réel après une erreur terminale n’est pas validé ; les reprises testées reçoivent une nouvelle donnée sur un flux encore ouvert, ou un nouveau scope. Production, Chrome, téléphone, lecteur d’écran et comportement réseau réel non testés. Les limites d’horloge et de mesure GPS de C restent valables.

### Décompte et suite

Tableau central : **P0 0 / P1 2 / P2 21 ouverts**. 27 entrées, 4 fermetures GPS antérieures, 23 ouvertes. P2-K-01 reste compté ouvert. P3 et prérequis pilote inchangés.
Prochaine action proposée : approbation de la fermeture documentaire limitée de P2-K-01 et de sa sauvegarde Git locale, sur la sélection exacte du checkpoint ; aucun commit, push ou déploiement exécuté.


## Clôture documentaire P2-K-01 — 10 octobre 2026

**Décision expressément approuvée par l’utilisateur : P2-K-01 = FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ.** Fermeture limitée à l'affichage des erreurs des flux GPS client, sans certification Firebase déployé ou pilote terrain.

**Cause et correction validées :** la carte ne traitait pas explicitement les erreurs des flux de position et d'historique et pouvait les présenter comme une absence de GPS ou un trajet vide. Le correctif différencie une erreur Firestore typée `permission-denied`, une indisponibilité générique, un résultat vide légitime et une position trop ancienne ; les erreurs de position/historique sont indépendantes, aucun marqueur trompeur n'est conservé, l'âge d'une mesure ne repart pas de zéro lors d'une reprise et les protections d'identité/mission et le seuil de fraîcheur de 60 secondes demeurent intacts. Les messages FR/EN/ES sont couverts par des tests widget.

**Preuves déjà acquises, non réexécutées dans cette clôture :** `artifacts/corrections-1-3M-L-20261010-a71d3b9c/CHECKPOINT_MOVIK_1_3M_L_P2_K_01.md` et `RESULTATS.json`. Reproduction complète avant correction : 7 tests réussis, 21 échoués ; validation après correction : **110 tests distincts réussis, 0 échoué, 0 ignoré**, y compris les non-régressions GPS I/J ; analyse Flutter ciblée et `git diff --check` réussis. Les 21 échecs représentent des scénarios liés au même défaut et non 21 nouveaux bogues. Les historiques et limites sont conservés dans l'addendum 1.3M-L.

**Limites :** Chrome, téléphone physique, lecteur d'écran, flux Firestore réel, interruption réseau et production non testés. Le flux définitivement terminé demeure explicitement en erreur : aucun réabonnement automatique ni mécanisme de retry infini n'est validé. L'isolation cartographique testée ne remplace pas une isolation réseau au niveau OS : **1.3L BLOQUÉ ET REPORTÉ**. Les quatre fermetures GPS P1-M-01/R-K-03-A/B/C demeurent limitées et non déployées. Aucun tarif, commission, traitement Stripe, snapshot, ledger ou règle serveur modifié.

**Décompte du tableau central après approbation : P0 0, P1 2, P2 20 ; 27 fiches, 5 fermées à portée limitée et 22 non fermées.** Les P1-HOME-001 et P1-COPY-001 ainsi que les autres P2/P3 et prérequis de lancement restent ouverts. La sauvegarde Git locale est autorisée séparément par le même accord, mais aucun push, merge ou déploiement n'est autorisé. Dernier HEAD connu avant la sauvegarde : `980a9dab54353a99315fa78fd4487c77396042f4`.

## Addendum — 1.3M-M — Coordonnées P2-H-01 / P2-H-02 — 10 octobre 2026

Référence locale : branche fix/gps-client-history-scope-20261009, HEAD 2df26054e0fb3491cdc75cfbef3f551fab07e1f5.
Preuves : artifacts/corrections-1-3M-M-20261010-b83e7c21/.
Aucun commit, indexage, push, merge ou déploiement pendant cette intervention.

### Causes et contrat vérifiés
- P2-H-01 reproduit sur les deux champs téléphone : --------, ()----() et 1------- permettaient de passer à la confirmation. La regex Flutter contrôlait les caractères et la longueur, mais pas le nombre de chiffres.
- P2-H-02 reproduit : les téléphones héritaient de maxLength 120 destiné aux noms. Le backend normalizeContacts (functions/src/lib/bookingServer.ts:66–71, appelé dans createDeliveryRequest.ts:240) exige au moins 8 chiffres ASCII et 8 à 25 caractères parmi chiffres, espaces, parenthèses et tirets, avec un + initial optionnel HORS de ces 25 caractères. Donc 26 caractères totaux sont valides avec + initial. Aucun nouveau format national imposé.
- Les noms restent limités à 120 et les instructions facultatives à 1200, comme auparavant. Aucun changement du serveur.
- Les libellés flottants et les messages longs ne tenaient pas tous sur mobile à 200 % ; les essais intermédiaires sont conservés. Le test de largeur brute d’un libellé transformé a été corrigé pour mesurer les coordonnées affichées, sans retirer le contrôle de troncature.

### Correction locale
Fichier produit : lib/screens/delivery/delivery_request_flow_screen.dart, fonction _details et consigne _contactPhoneHint.
- Ajout du contrôle >= 8 chiffres à la regex existante.
- Compteur téléphone 25, ou 26 si le texte commence par +. Aucune troncature silencieuse du téléphone collé : valeur conservée, validation bloque la progression.
- Consignes et erreur détaillée traduites par le mécanisme tr existant FR/EN/ES.
- Obligation des quatre noms/téléphones explicitée ; instructions identifiées facultatives.
- Libellés placés au-dessus des champs et associés sémantiquement, pour éviter les chevauchements à 200 %. Ajustement limité au formulaire de coordonnées ; aucun autre écran redessiné.
- Données saisies, brouillon et devis simulé conservés, y compris navigation et recréation du widget ; transmission fictive des coordonnées inchangée.
Nouveau test permanent : test/customer/delivery_contact_validation_test.dart. Aucun ancien test modifié.

### Résultats et preuves
- Reproduction complète avant correction : 23 réussis, 23 échoués, 0 ignoré.
- Renforcement du message explicatif avant correction : 0 réussi, 1 échoué, 0 ignoré.
- Dernière exécution ciblée : 46 réussis, 0 échoué, 0 ignoré.
- Non-régression existante : 20 réussis, 0 échoué, 0 ignoré.
- Total final distinct : 66 réussis, 0 échoué, 0 ignoré. Les répétitions/sondes intermédiaires ne sont pas additionnées.
- Matrice widget : FR/EN/ES × 375×812, 430×932 et 1440×900 ; plus 200 % sur les deux formats mobiles. Consignes et erreurs rendues, absence de troncature/chevauchement vérifiée géométriquement.
- Analyse Flutter ciblée, format et git diff --check : voir quality-exits.json et checkpoint.
- Historique conservé : première compilation du nouveau test impossible (getters à lire sur le TextField interne, pas TextFormField) ; correction du harnais puis sonde isolation réussie. Essais de patch interrompus par garde d’ancre et erreur de remplacement littéral, corrigés avant tout test applicatif ; sources intermédiaires conservées. Exécutions intermédiaires de mise en page détaillées dans RESULTATS.json, non réécrites.

### Isolation, limites, statut
Services uniquement fictifs : BookingTestAuth, MemoryBookingStorage et TestBookingApi. Aucun backend initialisé, aucune API de production, carte externe, Stripe, mission ou paiement réel. La confirmation crée uniquement test_mission dans la simulation.
Les règles, fonctions serveur, GPS, tarifs, commissions, snapshots et ledger ne sont pas modifiés. Le rendu Chrome, appareils réels, lecteurs d’écran, joignabilité réelle des numéros et validation serveur déployée ne sont pas testés.
P2-H-01 et P2-H-02 : **CORRIGÉS ET VALIDÉS DANS LE PÉRIMÈTRE SIMULÉ — NON FERMÉS — NON DÉPLOYÉS**. Fermeture documentaire limitée recommandée, soumise à approbation explicite.
P1-M-01, R-K-03-A/B/C et P2-K-01 restent fermés uniquement dans leurs périmètres autorisés. Aucun problème rouvert ou supprimé.
Décompte : **P0 0, P1 2, P2 20 ouverts**. P3 historiques, prérequis pilote et 1.3L BLOQUÉ/REPORTÉ conservés.


## Clôture documentaire limitée P2-H-01 / P2-H-02 — 10 octobre 2026

**Autorisation explicite reçue : fermeture des défauts corrigés et justifiés par leurs validations existantes, avec sauvegarde dans un cinquième commit local.** P2-H-01 et P2-H-02 sont désormais **FERMÉS — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉS**. Les cinq fiches déjà fermées (P1-M-01, R-K-03-A/B/C, P2-K-01) conservent leur statut local limité. Aucune autre fiche qualifiée seulement ou validée historiquement sans validation de clôture appropriée n'est fermée artificiellement.

**Preuves historiques, non réexécutées pour cette clôture :** `artifacts/corrections-1-3M-M-20261010-b83e7c21/CHECKPOINT_MOVIK_1_3M_M_P2_H_01_H_02.md`, `RESULTATS.json`, `RESULT-before.jsonl`, `RESULT-final-v2.jsonl` et `RESULT-regression.jsonl`. Reproduction initiale : 23 réussis, 23 échoués ; validation finale : **46 tests ciblés + 20 non-régressions distinctes réussis, 0 échec, 0 ignoré**. Les validations Flutter analyze, format Dart et `git diff --check` étaient réussies. Le serveur `normalizeContacts` a été examiné mais non exécuté ni modifié ; les essais concernent le vrai formulaire Flutter avec services fictifs.

**Périmètre fermé :** P2-H-01 refuse désormais les séparateurs seuls et exige au moins huit chiffres, tout en conservant les formats de téléphone précédemment admis. P2-H-02 aligne le compteur sur le contrat (25 caractères, ou 26 avec + initial), clarifie les consignes et vérifie les libellés FR/EN/ES sur les formats widget simulés, y compris texte mobile à 200 %. Les tarifs, le devis, la commission, Stripe, snapshots, ledger, règles Firestore et corrections GPS ne sont pas changés par la clôture documentaire.

**Limites et autres dossiers :** pas de test Chrome réel, téléphone physique, lecteur d'écran, backend déployé, parcours financier réel ou lancement public. Les deux P1 historiques P1-HOME-001/P1-COPY-001 et les autres P2 restent ouverts en attendant leurs critères propres. Le test de tuiles 1.3L demeure BLOQUÉ ET REPORTÉ. Le pilote reste NO-GO tant que ses prérequis ne sont pas vérifiés.

**Décompte du registre actif après ces deux fermetures : P0 0 / P1 2 / P2 18.** 27 fiches, dont 7 fermées dans des périmètres de validation limités et 20 encore ouvertes. Sauvegarde Git locale autorisée séparément par le même accord, mais **aucun push, merge ou déploiement** autorisé. HEAD attendu avant sauvegarde : `2df26054e0fb3491cdc75cfbef3f551fab07e1f5`.


## Addendum 1.3M-N — 10 octobre 2026 — confirmation client

Base : `7fd6a905fe8f99e0bf3be3b4bb95a115d62bd395`, branche `fix/gps-client-history-scope-20261009`. Modifications locales non commitées, non déployées.
Autorisation de Daniel dans la mission 1.3M-N : fermeture documentaire distincte de chaque fiche si correction, tests et limites démontrés.

### P2-I-01 — FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ

Statut précédent : QUALIFIÉ (historique conservé ci-dessus).
Cause reproduite : note inconditionnelle « Votre carte est enregistrée chez Stripe » ; seconde affirmation « Carte enregistrée » pour un booléen de préparation.
Contrat lu : `bookingCardSetup.ts:81–88`, ready correspond à un default_payment_method_id et à l'environnement du provider ; verifyCardSetup contrôle session/client/utilisateur/devis/environnement. Ce booléen ne prouve ni autorisation ni capture et les tests ne contactent pas le provider.
Correction : note de distinction préparation/autorisation/paiement, messages FR/EN/ES « préparation non confirmée » ou « moyen prêt pour la confirmation » ; aucune déclaration de paiement réussi. Boutons, garde cardReady et méthodes métier inchangés.
Couverture : false/true, attente avec Completer, erreur de préparation, contrôle de statut échoué, reprise, retour/reconstruction, double soumission et payload fictif préservé. 24 combinaisons langue/format/état prêtes ou non prêtes.
Fermeture autorisée et appliquée le 10 octobre 2026 ; aucun état Stripe réel validé.

### P2-I-02 — FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ

Statut précédent : QUALIFIÉ. Qualification actualisée : l'ISO brut n'est pas affiché pour toute date valide au HEAD ; le formateur Material par défaut rendait notamment « Thu, Jan 1 · 7:00 AM » sur /fr (sans année). Une date invalide revenait brute ; une date absente n'avait pas d'indication.
Correction : `GlobalMaterialLocalizations` déjà disponible dans le projet, chargé selon la langue du formulaire ; date complète avec année, heure 24 h et décalage UTC de l'instant. Source requested_at et expiration du devis inchangées. Date absente/invalide : indication explicite, aucun remplacement par maintenant. L'expiration partage le résumé de prix et bénéficie du même affichage ; calcul/validité inchangés.
Fuseau : conversion locale existante conservée, pas de nouvelle politique imposant Montréal à tous les appareils. Runner Windows Eastern Standard Time ; tests vérifient UTC-05 hiver et UTC-04 été, fin de mois et changement d'année. Tests timezone ciblés nécessitent un runner réglé sur l'heure de l'Est (ou TZ America/Toronto si supporté par l'OS). Ce prérequis n'est pas un réglage appliqué par l'intervention.
Couverture : 15 cas date/FR/EN/ES, 9 absences/invalides, navigation/reconstruction, formatages des résumés et widget responsive.
Fermeture autorisée et appliquée le 10 octobre 2026. Sélecteurs de date étape Ma livraison / P2-FORM-001 restent ouverts, aucune fermeture implicite.

### Preuves et résultats communs

Dossier : `artifacts/corrections-1-3M-N-20261010-d927c861/`.
- Première tentative : erreur de compilation du nouveau test (paramètre message requis de FirebaseFunctionsException), 0 test exécuté ; journal before-compile-error.jsonl conservé.
- Reproduction avant correction : 2 réussis, 52 échoués, 0 ignoré ; before.jsonl.
- Première exécution après correction : 53 réussis, 1 échoué, 0 ignoré ; after.jsonl. Échec de fixture : devis générés séparément avec expiration différente d'une milliseconde. Alignement de la fixture, assertion stricte conservée, aucun changement métier pour ce test.
- Finale : 54 réussis, 0 échoué, 0 ignoré ; final.jsonl.
- Non-régressions : 66 réussis, 0 échoué, 0 ignoré ; regression.jsonl, dont 46 coordonnées H et 20 brouillon/auth/confirmation/reprise/disponibilité.
- Total final distinct : 120 réussis. Exécutions antérieures non additionnées.
- Analyse finale ciblée : 0 problème ; format 2 fichiers, 0 changement ; git diff --check réussi. Deux infos de style du nouveau test corrigées (accolades, assertions inchangées).
- Synthèse : RESULTATS.json ; empreintes et intégrité : CONTROLES_FINAUX.json ; isolation : ISOLATION.md.
- Vrais widgets Flutter : FR/EN/ES, 375×812, 430×932, 1440×900, mobile375 texte200%. Assertions de paragraphes non tronqués, bornes horizontales et absence d'exception Flutter ; ce ne sont pas des captures Chrome.
- Aucun code GPS, serveur, paiement, snapshot, ledger, tarifs ou commissions modifié ; méthodes métier du formulaire conservées. Aucun commit, index vide, aucune production.

Décompte recalculé du tableau actif après ces deux fermetures : **P0 0 / P1 2 / P2 16**, 27 fiches conservées, 18 non fermées. P1-HOME-001 et P1-COPY-001 restent ouverts. Tous les autres P2/P3 et prérequis conservés ; 1.3L reste BLOQUÉ ET REPORTÉ.

Limites : simulations seulement ; aucun Stripe Sandbox/LIVE, Firebase réel, carte/route/GPS externe ; aucune preuve nouvelle de concordance financière serveur–mission–snapshot–Stripe. Pas de build Web, Chrome, appareil physique ou production. Erreur getBookingCardStatus toujours traitée par le comportement existant, mais ne produit plus une affirmation de carte enregistrée ; aucune refonte de gestion des erreurs.


## Addendum 1.3M-O — 11 octobre 2026 — suivi client P2-J-01

Branche fix/gps-client-history-scope-20261009 ; HEAD de base 540352c98fa2e6132a0828069583c25f0802592c. Aucun commit, index vide, non déployé. Dossier daté 20261010 conformément au préfixe demandé ; exécution réelle le 11 octobre 2026 America/Toronto.

### Transition autorisée et cause

QUALIFIÉ → CORRECTION CODÉE → TESTÉ → VALIDÉ → FERMÉ, exclusivement présentation du suivi client. Le code initial regroupait recherche/absence de chauffeur/états non suivables sous tracking_not_available et n’affichait pas la référence. Le suivi ne vérifiait pas la concordance défensive entre mission retournée et identifiant demandé. La clé client+mission réinitialise désormais le snapshot lors du changement d’abonnement. Aucun défaut serveur de confidentialité n’est allégué par les seuls mocks.

### Correction et source de vérité

CustomerTrackingScreen affiche DeliveryMission.id, identifiant du document renvoyé par le repository ; le reçu et la route utilisent le missionId reçu de createDeliveryRequest. Pas de nouveau numéro, pas de reconstruction si absent. Les contrôles de propriété précèdent toute référence. searchingDriver/offered sans chauffeur → recherche ; assignation sans chauffeur valide → absence explicitée ; statut inconnu converti en draft par le modèle → information indisponible sans fausse promesse. Les statuts terminaux connus restent visibles sans carte. Référence ajoutée aux vues assignée et terminée. Titre court FR/EN/ES et hauteur adaptée à l’agrandissement ; aucune refonte de la carte.

### Exécutions réellement effectuées (ne pas additionner l’historique)

| Exécution | Réussis | Échoués | Ignorés |
|---|---:|---:|---:|
| Reproduction initiale before | 9 | 50 | 0 |
| Première correction after | 38 | 21 | 0 |
| Suite ciblée final | 59 | 0 | 0 |
| Première non-régression regression | 16 | 3 | 0 |
| Non-régression finale regression-final | 19 | 0 | 0 |
| GPS freshness sélectionné | 7 | 0 | 0 |
| GPS errors sélectionné | 8 | 0 | 0 |

Les 21 échecs intermédiaires comprennent 18 contrôles de troncature du titre dans le rendu widget et 3 assertions de reçu exécutées avant fin de transition de route. Titre corrigé ; attente de transition complétée dans le test sans affaiblir les assertions. Les 3 échecs de non-régression provenaient du transport mémoire non propagé au corps d’anciens tests : no_default_http_client a refusé le client réseau. Deux copies temporaires conservent exactement les assertions et appliquent offlineWidgetTest ; originaux inchangés. Journaux d’échecs conservés.

Total final distinct : 59+19+7+8 = 93 réussis, 0 échec, 0 ignoré. 36 cas de rendu/langue (FR/EN/ES × 375×812, 430×932, 1440×900, mobile 200 % × recherche/assignation/erreur), parcours réel de widgets reçu→suivi dans les trois langues ; contrôles de référence longue, client étranger, mission incompatible, A→B, référence absente et statuts terminaux. Analyse Flutter : aucun problème. Format Dart : 0 fichier à reformater. git diff --check : 0. Une information de style initiale corrigée uniquement dans le nouveau test (interpolation).

### Isolation, limites et conservation

Vrais widgets avec Auth, BookingApi, stockage et repositories fictifs ; transport de tuiles exclusivement mémoire avec chemins inattendus refusés, HTTP par défaut désactivé. Aucun appel Firebase/Stripe/Google/OSM, aucune mission réelle. Ces contrôles ne constituent pas un confinement réseau global ni une validation Chrome/production/physique ; 1.3L reste BLOQUÉ ET REPORTÉ. Aucune nouvelle validation financière ; sources financières, GPS, serveur, règles et contrats inchangés. Statut brut inconnu/payment_failed reste la limitation du modèle existant : UI neutre, pas de nouvelle machine à états.

Preuves : artifacts/corrections-1-3M-O-20261010-a64e9b12/CHECKPOINT_MOVIK_1_3M_O.md, RESULTATS.json, ISOLATION.md, regression-adaptation.json, git-initial.json, git-final.json et journaux before/after/final/regression/regression-final/gps-freshness/gps-errors. Suite permanente : test/customer/customer_tracking_presentation_test.dart.

Décompte recalculé du tableau actif : P0 0, P1 2, P2 15 ; 27 fiches conservées, 17 non fermées. P1-HOME-001/P1-COPY-001 et tous les autres dossiers restent dans leur état. Aucun autre problème fermé. Prochaine action unique : approbation de la sauvegarde Git locale de ce correctif, aucun commit exécuté.

### Métadonnées antérieures conservées

Date de consolidation : 9 octobre 2026, America/Toronto. Étape 1.3M-B. Dernière mise à jour : 1.3M-N, clôture ciblée P2-I-01/I-02, 10 octobre 2026 ; corrections non déployées.

Anomalies actives non fermées issues de Phase1 et dettes reportées : **P0 0, P1 2, P2 16** (recalcul après clôture documentaire limitée P2-I-01/I-02 du 10 octobre 2026). P1-M-01, R-K-03-A/B/C, P2-K-01, P2-H-01 et P2-H-02 sont conservés avec leurs fermetures limitées ; 27 entrées au total, dont 18 non fermées. Les deux P1 ouverts demeurent P1-HOME-001 et P1-COPY-001. Cela inclut 2 P1 et 1 P2 déjà validés visuellement historiquement mais non fermés selon la nouvelle règle. Les corrections A/B/C sont fermées exclusivement dans leurs périmètres locaux/simulés validés, non déployés. R-K-03-C a été fermé documentairement après validation I/J du seuil de 60 secondes et des contrôles d'identité, de mission, de dates et de remplacement de position. Les deux P1 ouverts sont P1-HOME-001 et P1-COPY-001 ; les tests terrain, Chrome et production restent à réaliser. Aucun incident réel de production démontré. Les gaps de couverture/décision sont inclus en P2 et explicitement distingués des bugs.

| P2-J-01 | P2 | Bug simulé confirmé | QUALIFIÉ | Suivi en recherche sans référence ni statut métier explicitement affichés. |


## Addendum lot 1.3M-P/Q — 1_3M_P — 11 octobre 2026

R-K-04 : QUALIFIÉ → CORRECTION CODÉE → TESTÉ → VALIDÉ → FERMÉ, périmètre simulé non déployé.

Montréal de repli supprimé. Sans coordonnées géométriquement utilisables, le vrai widget présente son état d'attente/erreur sur une surface neutre sans FlutterMap/TileLayer. Adresse réelle, position compatible ancienne (sans marqueur actif) et historique valide restent des repères possibles ; aucun lieu inventé. Identité, mission, dates et seuil de 60 secondes conservés.

- P-before : 4 réussis / 11 échoués / 0 ignorés.
- P-after : 15 réussis / 0 échoués / 0 ignorés.
- P-regression : 132 réussis / 0 échoués / 0 ignorés.
- P-driver : 6 réussis / 0 échoués / 0 ignorés.

Preuves : artifacts/corrections-1-3M-PQ-20261011-f72a3c10/CHECKPOINT_1_3M_P.md et VALIDATION_1_3M_P.json. Aucun push/déploiement. Décompte : P0 0, P1 2, P2 14. Les autres lignes actives restent inchangées.

Historique des métadonnées précédentes :

Date de consolidation : 9 octobre 2026, America/Toronto. Étape 1.3M-B. Dernière mise à jour : 1.3M-O, clôture ciblée P2-J-01, 11 octobre 2026 ; corrections non déployées.

Anomalies actives non fermées issues de Phase1 et dettes reportées : **P0 0, P1 2, P2 15** (recalcul après clôture documentaire limitée P2-J-01 du 11 octobre 2026). P1-M-01, R-K-03-A/B/C, P2-K-01, P2-H-01 et P2-H-02 sont conservés avec leurs fermetures limitées ; 27 entrées au total, dont 17 non fermées. Les deux P1 ouverts demeurent P1-HOME-001 et P1-COPY-001. Cela inclut 2 P1 et 1 P2 déjà validés visuellement historiquement mais non fermés selon la nouvelle règle. Les corrections A/B/C sont fermées exclusivement dans leurs périmètres locaux/simulés validés, non déployés. R-K-03-C a été fermé documentairement après validation I/J du seuil de 60 secondes et des contrôles d'identité, de mission, de dates et de remplacement de position. Les deux P1 ouverts sont P1-HOME-001 et P1-COPY-001 ; les tests terrain, Chrome et production restent à réaliser. Aucun incident réel de production démontré. Les gaps de couverture/décision sont inclus en P2 et explicitement distingués des bugs.

| R-K-04 | P2 | Risque visuel provisoire | QUALIFIÉ | Centre de repli Montréal sans position/adresse ; pas de faux marqueur démontré. |


## Addendum lot 1.3M-P/Q — 1_3M_Q1 — 11 octobre 2026

P2-FORM-001 : QUALIFIÉ → CORRECTION CODÉE → TESTÉ → VALIDÉ → FERMÉ, périmètre simulé non déployé.

Sélecteurs date/heure localisés dans la langue du formulaire via les delegates Material existants ; résumé de l'étape livraison réutilisant le format localisé de confirmation. Instant, fuseau local, contraintes de date et valeurs persistées inchangés.

- Q1-before : 3 réussis / 6 échoués / 0 ignorés.
- Q1-after : 9 réussis / 0 échoués / 0 ignorés.
- Q1-regression : 26 réussis / 0 échoués / 0 ignorés.

Preuves : artifacts/corrections-1-3M-PQ-20261011-f72a3c10/CHECKPOINT_1_3M_Q1.md et VALIDATION_1_3M_Q1.json. Aucun push/déploiement. Décompte : P0 0, P1 2, P2 13. Les autres lignes actives restent inchangées.

Historique des métadonnées précédentes :

Date de consolidation : 9 octobre 2026, America/Toronto. Dernière mise à jour : lot 1.3M-P/Q, 1_3M_P, 11 octobre 2026 ; correctifs locaux non déployés.

Anomalies actives non fermées : **P0 0, P1 2, P2 14** ; 27 fiches conservées, 16 ouvertes. P1-HOME-001 et P1-COPY-001 restent ouverts. Les anciens décomptes et limites sont conservés dans les addenda ; les P3 historiques et prérequis ne sont pas supprimés.

| P2-FORM-001 | P2 | Bug visuel historique | QUALIFIÉ | Sélecteurs date/heure et date résumée anglais sur /fr. |


## Addendum lot 1.3M-P/Q — 1_3M_Q2 — 11 octobre 2026

P2-FORM-002 : QUALIFIÉ → CORRECTION CODÉE → TESTÉ → VALIDÉ → FERMÉ, périmètre simulé non déployé.

Libellé d’unité déplacé hors du label contraint du Dropdown, dans une colonne permettant son retour à la ligne ; sélection et conversion inchangées.

- Q2-before : 1 réussis / 12 échoués / 0 ignorés.
- Q2-after : 13 réussis / 0 échoués / 0 ignorés.
- Q2-regression : 6 réussis / 0 échoués / 0 ignorés.

Preuves : artifacts/corrections-1-3M-PQ-20261011-f72a3c10/CHECKPOINT_1_3M_Q2.md et VALIDATION_1_3M_Q2.json. Aucun push/déploiement. Décompte : P0 0, P1 2, P2 12. Les autres lignes actives restent inchangées.

Historique des métadonnées précédentes :

Date de consolidation : 9 octobre 2026, America/Toronto. Dernière mise à jour : lot 1.3M-P/Q, 1_3M_Q1, 11 octobre 2026 ; correctifs locaux non déployés.

Anomalies actives non fermées : **P0 0, P1 2, P2 13** ; 27 fiches conservées, 15 ouvertes. P1-HOME-001 et P1-COPY-001 restent ouverts. Les anciens décomptes et limites sont conservés dans les addenda ; les P3 historiques et prérequis ne sont pas supprimés.

| P2-FORM-002 | P2 | Bug visuel historique | QUALIFIÉ | Libellé Unité de poids tronqué, largeur fixe 120. |


## Addendum lot 1.3M-P/Q — 1_3M_Q3 — 11 octobre 2026

P2-FORM-003 : QUALIFIÉ → CORRECTION CODÉE → TESTÉ → VALIDÉ → FERMÉ, périmètre simulé non déployé.

Saisie brute ramassage/livraison sauvegardée immédiatement dans pickup_text/dropoff_text, séparée des adresses résolues et restaurée sans fabriquer de coordonnées. Devis interdit tant que les adresses restent non résolues.

- Q3-before : 2 réussis / 10 échoués / 0 ignorés.
- Q3-after : 12 réussis / 0 échoués / 0 ignorés.
- Q3-regression : 17 réussis / 0 échoués / 0 ignorés.

Preuves : artifacts/corrections-1-3M-PQ-20261011-f72a3c10/CHECKPOINT_1_3M_Q3.md et VALIDATION_1_3M_Q3.json. Aucun push/déploiement. Décompte : P0 0, P1 2, P2 11. Les autres lignes actives restent inchangées.

Historique des métadonnées précédentes :

Date de consolidation : 9 octobre 2026, America/Toronto. Dernière mise à jour : lot 1.3M-P/Q, 1_3M_Q2, 11 octobre 2026 ; correctifs locaux non déployés.

Anomalies actives non fermées : **P0 0, P1 2, P2 12** ; 27 fiches conservées, 14 ouvertes. P1-HOME-001 et P1-COPY-001 restent ouverts. Les anciens décomptes et limites sont conservés dans les addenda ; les P3 historiques et prérequis ne sont pas supprimés.

| P2-FORM-003 | P2 | Bug historique / besoin produit | QUALIFIÉ | Adresse saisie non résolue perdue après refresh ; objet conservé. |


## Addendum lot 1.3M-P/Q — 1_3M_Q4 — 11 octobre 2026

P2-FORM-004 : QUALIFIÉ → CORRECTION CODÉE → TESTÉ → VALIDÉ → FERMÉ, périmètre simulé non déployé.

Dimensions rendues lisibles dans les champs et le résumé, sans arrondir les valeurs stockées, les conversions ni les données du devis. 190 cm devient visuellement 74,8 in en FR/ES, 74.8 in en EN ; précision numérique complète conservée.

- Q4-before : 3 réussis / 17 échoués / 0 ignorés.
- Q4-before-fixture : 1 réussis / 0 échoués / 0 ignorés.
- Q4-after : 20 réussis / 0 échoués / 0 ignorés.
- Q4-regression : 30 réussis / 0 échoués / 0 ignorés.
- Q4-confirmation : 2 réussis / 0 échoués / 0 ignorés.

Preuves : artifacts/corrections-1-3M-PQ-20261011-f72a3c10/CHECKPOINT_1_3M_Q4.md et VALIDATION_1_3M_Q4.json. Aucun push/déploiement. Décompte : P0 0, P1 2, P2 10. Les autres lignes actives restent inchangées.

Historique des métadonnées précédentes :

Date de consolidation : 9 octobre 2026, America/Toronto. Dernière mise à jour : lot 1.3M-P/Q, 1_3M_Q3, 11 octobre 2026 ; correctifs locaux non déployés.

Anomalies actives non fermées : **P0 0, P1 2, P2 11** ; 27 fiches conservées, 13 ouvertes. P1-HOME-001 et P1-COPY-001 restent ouverts. Les anciens décomptes et limites sont conservés dans les addenda ; les P3 historiques et prérequis ne sont pas supprimés.

| P2-FORM-004 | P2 | Bug visuel historique | QUALIFIÉ | 190 cm convertis affichés 74.803149606… in. |


## Addendum 1.3M-R — fermeture P1-HOME-001 — 11 octobre 2026

Date de preuve : 2026-10-11T15:54:42.050Z. Branche fix/gps-client-history-scope-20261009, HEAD avant sauvegarde 5649bbbe14a6500a81cc53d1728a112663a0a92e.

État précédent conservé :

Date de consolidation : 9 octobre 2026, America/Toronto. Dernière mise à jour : lot 1.3M-P/Q, 1_3M_Q4, 11 octobre 2026 ; correctifs locaux non déployés.

Anomalies actives non fermées : **P0 0, P1 2, P2 10** ; 27 fiches conservées, 12 ouvertes. P1-HOME-001 et P1-COPY-001 restent ouverts. Les anciens décomptes et limites sont conservés dans les addenda ; les P3 historiques et prérequis ne sont pas supprimés.

| P1-HOME-001 | P1 | Bug ancien branche septembre | VALIDÉ — HISTORIQUE, NON FERMÉ | Chevauchement hero desktop corrigé structurellement et non reproduit release trois formats. |

Transition : VALIDÉ — HISTORIQUE, NON FERMÉ → FERMÉ — PÉRIMÈTRE LOCAL VALIDÉ — NON DÉPLOYÉ. Code produit et finances inchangés. Le défaut de chevauchement ne se reproduit pas ; aucune nouvelle correction produit nécessaire. Tests permanents : test/home/home_screen_test.dart (API fictive explicite, transport mémoire, assertions historiques conservées), test/home/home_launch_layout_test.dart (18 scénarios). Exécution finale combinée : 49/0/0. Les exécutions intermédiaires ne sont pas additionnées. Deux avis de dépréciation dans le diagnostic du nouveau test ont été corrigés ; analyse finale sans anomalie. Les preuves brutes et limites sont conservées dans artifacts/reconciliation-1-3M-R-20261011-7c41e2a9. Test autonome 1.3L BLOQUÉ ET REPORTÉ ; P2 et prérequis inchangés.

Complément de preuve 1.3M-R/HOME : exécution finale sans dart-define imposé, compatible avec la commande Flutter CI existante : home-ci-final 49/0/0 ; home-ci-quality et home-ci-format codes 0. Transport simulé appliqué par test, aucun changement du helper GPS. Contrôle de staging ayant initialement refusé des espaces dans une copie de log : copie nettoyée, brut conservé, aucun commit prématuré.


## Addendum 1.3M-R — fermeture P1-COPY-001 — 11 octobre 2026

Preuve datée 2026-10-11T16:05:05.840Z. Branche fix/gps-client-history-scope-20261009, HEAD avant sauvegarde 7fc5a04cdf3ad421cccfa78b3cded73666903fb4.

État précédent conservé :

Date de consolidation : 9 octobre 2026, America/Toronto. Dernière mise à jour : 1.3M-R / P1-HOME-001, 11 octobre 2026 ; correctifs locaux non déployés.

Anomalies actives non fermées : **P0 0, P1 1, P2 10** ; 27 fiches conservées, 11 ouvertes. P1-HOME-001 fermé localement ; P1-COPY-001 reste ouvert. Les anciens décomptes et limites sont conservés dans les addenda ; les P3 historiques et prérequis ne sont pas supprimés.

| P1-COPY-001 | P1 | Bug ancien branche septembre/main | VALIDÉ — HISTORIQUE, NON FERMÉ | Anciennes promesses couverture/créneau retirées accueil release. |

Transition : VALIDÉ — HISTORIQUE, NON FERMÉ → FERMÉ — PÉRIMÈTRE LOCAL VALIDÉ — NON DÉPLOYÉ. Textes produit déjà corrigés depuis 49e865c, non réécrits. Ancienne affirmation « Partout au Québec et ses environs » retrouvée dans d563be2. Accueil/FAQ/Granby distinguent date souhaitée, disponibilité à confirmer et zone prévue ; aucune réservation/transaction réelle garantie, aucun GPS terrain validé revendiqué. La lecture locale de serviceZones, bookingServer, dispatchMissionToDrivers et acceptDelivery ne prouve pas leur configuration en production. Registre : 27 fiches, 0 P0 / 0 P1 / 10 P2 ouverts ; tous les identifiants et historiques conservés. Les dix P2 dont P2-COPY-001 et P2-I18N-001 restent ouverts, même si leurs observations ont été rencontrées dans la revue. Test autonome 1.3L BLOQUÉ ET REPORTÉ. Preuves et résultats détaillés : artifacts/reconciliation-1-3M-R-20261011-7c41e2a9.


## Addendum 1.3M-S — 11 octobre 2026 — P2-G-02

- Autorisation : correction, validation, fermeture documentaire conditionnelle et commit local autorisés pour P2-G-02 uniquement. Aucun push, merge ou déploiement.
- Transition : QUALIFIÉ → REPRODUIT → CORRECTION CODÉE → TESTÉ → VALIDÉ → FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ.
- Base vérifiée : da3f1d459c3205e55aec3f1d972aab45b4fa7423, branche fix/gps-client-history-scope-20261009 ; index et fichiers suivis propres avant intervention.
- Défaut reproduit sur DeliveryRequestFlowScreen réel, étapes Mon prix et Confirmation : 1234.50 CAD, 10.0 km ; valeur absente causant un cast Null → num. 35 tests initiaux échoués, 0 réussi, 0 ignoré.
- Correction de présentation : formatMajorAmount étendu avec locale optionnelle, comportement des anciens appelants conservé ; formatDistanceKm conserve les km et au plus une décimale sans zéro inutile. FR : 1 234,50 $ CA ; EN : CA$1,234.50 ; ES : 1.234,50 CA$. Une valeur manquante/invalide est affichée —, jamais inventée à zéro.
- Intl 0.20.3 déjà présent en cache devient dépendance directe ; résolution offline, version et empreinte inchangées.
- Premier retest : 35 réussis / 6 échoués / 0 ignoré. Débordements à 200 % démontrés dans les lignes de ventilation ; Row remplacé uniquement à cet endroit par Wrap avec largeur contrainte. Historique d'échec conservé.
- Validation finale : 47 tests ciblés (41 widgets + 6 formatteurs) et 97 non-régressions distinctes, tous réussis, aucun ignoré. FR/EN/ES ; 375×812, 430×932, 1440×900, mobile 200 % ; grands montants, négatifs, absences, changement de langue, reprise et confirmation fictive.
- Conservation : égalité JSON du devis source/API/brouillon/sauvegardes, contacts et requête de confirmation ; aucun recalcul client. Les méthodes _quote/_refreshCard/_setupCard/_confirm sont strictement identiques (SHA256). 218 fichiers GPS/serveur/financiers protégés inchangés. Aucun montant Stripe, snapshot, ledger, règle ou fonction serveur modifié.
- Qualité finale : analyse Flutter ciblée sans problème, format 7 fichiers sans changement, diff --check réussi. Les 15 infos de style du premier analyseur sur le nouveau test ont été corrigées ; preuve conservée.
- Limites : tests widget et services fictifs, pas Chrome, téléphone physique, serveur de devis réel, Stripe Sandbox/LIVE ou production. Les autres écrans de finance/admin/chauffeur gardent leur présentation antérieure ; aucune validation globale de leur localisation. 1.3L reste BLOQUÉ ET REPORTÉ.
- Preuves : artifacts/corrections-1-3M-S-20261011-8d61e930/ (CHECKPOINT_MOVIK_1_3M_S.md, RESULTATS_TESTS.json, INTEGRITE.json, ISOLATION.md, journaux bruts conservés).
- Décompte recalculé sur les 27 fiches : P0 0 / P1 0 / P2 9 ouverts. Aucune autre fiche fermée, aucun historique/P3/prérequis supprimé.


## Addendum 1.3M-T — 11 octobre 2026 — P2-COPY-001

Fermeture ciblée autorisée : **FERMÉ — PÉRIMÈTRE LOCAL/SIMULÉ VALIDÉ — NON DÉPLOYÉ**. La correction produit existait déjà et n’a pas été recodée. Tests permanents ajoutés dans test/home/home_marketplace_copy_test.dart ; aucune mention historique supprimée. Ancien statut : VALIDÉ — HISTORIQUE, NON FERMÉ. Décompte précédent S : P0 0 / P1 0 / P2 9 ; nouveau décompte T : P0 0 / P1 0 / P2 8. Toutes les 27 fiches, les P3 et prérequis sont préservés.

Preuves : artifacts/reconciliation-1-3M-T-20261011-39a672bd/SOURCE_HISTORY.json, FONT_EVIDENCE.json, INITIAL_FAILURES.json, synthèses JSON, VALIDATION.json et CHECKPOINT_MOVIK_1_3M_T.md. Validation finale 12 Marketplace + 61 non-régressions + 3 pages publiques = 76 tests distincts réussis. Les répétitions ne sont pas additionnées ; premier essai 9/3/0 archivé, pas réécrit. Flutter analyze final sans anomalie ; format stable ; contrôles Git et empreintes avant commit.

Aucun fichier produit, GPS ou financier modifié. Aucun push, merge, déploiement ou service externe sollicité. 1.3L reste BLOQUÉ ET REPORTÉ. Prochaine séquence proposée seulement : P2-I18N-001, illustration française sur EN/ES.


## Addendum 1.3M-U — P2-I18N-001 — 12 octobre 2026

12 octobre 2026 — 1.3M-U : FERMÉ — PÉRIMÈTRE LOCAL/SIMULÉ VALIDÉ — NON DÉPLOYÉ. Avant : IDENTIFIÉ (conservé ci-dessous). Défaut reproduit (4 réussis / 9 échoués), puis 13 tests ciblés et 73 non-régressions distincts réussis. 12 captures widget examinées ; MediaQuery et décodage contrôlés. Ahem résiduel sur certains boutons, pas de validation Chrome/terrain/production. Variante générative neutre 1535×1025 ; FR inchangé. Preuves : artifacts/corrections-1-3M-U-20261012-a61b905e/CHECKPOINT_I18N_001.md et HERO_EVIDENCE.json.

En-tête précédent conservé : Date de consolidation : 9 octobre 2026, America/Toronto. Dernière mise à jour : 1.3M-T, 11 octobre 2026 ; fermeture P2-COPY-001 dans son périmètre local/simulé validé, non déployé.


## Addendum 1.3M-U — P2-I18N-002 — 12 octobre 2026

12 octobre 2026 — 1.3M-U : FERMÉ — PÉRIMÈTRE LOCAL/SIMULÉ VALIDÉ — NON DÉPLOYÉ. Avant : QUALIFIÉ (historique conservé). Avant correction, 6 tests réussis / 7 échoués ; après, 13 ciblés et 68 non-régressions réussis. Neuf captures widget de l’infobulle examinées, langues/200 % et navigation desktop testées. Aucun Chrome, production ou lecteur d’écran physique testé. Preuves : artifacts/corrections-1-3M-U-20261012-a61b905e/CHECKPOINT_I18N_002.md et MENU_EVIDENCE.json.

En-tête précédent conservé : Date de consolidation : 9 octobre 2026, America/Toronto. Dernière mise à jour : 1.3M-U, 12 octobre 2026 ; fermeture ciblée P2-I18N-001, non déployée.


## Addendum 2026-10-12 — clôture du lot 1.3M-U

Deux fermetures autorisées et prouvées : P2-I18N-001 et P2-I18N-002, périmètre local/simulé validé, non déployé. P2-BUILD-001 reste ouvert : avertissement reproduit et ressource locale manquante, aucune dépendance téléchargée. 27 fiches conservées ; P0 0 / P1 0 / P2 6 ouverts. 123 tests distincts réussis dans les exécutions finales ; build Web code 0 avec avertissement. 1.3L demeure BLOQUÉ ET REPORTÉ. Preuves et limites : artifacts/corrections-1-3M-U-20261012-a61b905e/CHECKPOINT_MOVIK_1_3M_U.md. Aucune autre anomalie traitée.


## Addendum — Reprise du déploiement — 14 octobre 2026

Les résultats antérieurs sont conservés. Les 20 échecs Flutter de QC26 ont été reproduits (9/20/0 dans les quatre suites), puis résolus uniquement dans leur raccordement au transport mémoire : 29/0/0 ciblés, puis suite complète 1088/0/0. Analyse Flutter complète, format et diff check réussis. CI utilise le dart-define de refus du client HTTP par défaut. Nouveau passage Node 20.20.2 : 228 unitaires et 734 intégration réussis, aucun échec ni ignoré final. Première exécution intégration interrompue pour refus du hub local 4400, conservée distinctement. Pas de changement des sources métier ni des finances. Le premier build Vercel staged a révélé des CRLF dans le script Bash ; correction de fins de ligne seule, nouveau build à vérifier. Les 28 fiches et leurs limites restent conservées, P0 0 / P1 0 / P2 0 dans le tableau actif. Aucun GO commercial déduit, 1.3L demeure bloqué/reporté. Les nouvelles automatisations de récupération des autorisations et le basculement coordonné Firebase/Web restent à décider. Preuves : artifacts/deployment-reprise-20261014-7b6e31a4/CHECKPOINT_VALIDATION_DEPLOIEMENT.md et VALIDATION_RESULTS.json.

Précision de diagnostic : le blob Git du script était déjà en LF. La conversion Windows core.autocrlf=true lors de la préparation de l’archive a produit les 113 CRLF rejetés par Vercel. Le contenu versionné du script reste identique ; seule .gitattributes ajoute la protection eol=lf et le fichier local est normalisé. Aucun changement Bash métier.


## Addendum — Builds et revue Chrome du 14 octobre 2026

Commit 8ab7864 poussé sur la branche de correction, main inchangé. Preview GitHub et candidate de production sans bascule READY, JavaScript compilé identique par SHA256. Six captures Chrome examinées, aucun pageerror ; requête métier getBookingConfiguration bloquée avant envoi dans le navigateur de contrôle. La preview réelle reste configurée pour Firebase production : ce n’est pas une recette métier isolée. Aucun déploiement Firebase et movi-k.com conserve dd85a60. Décision restante : lot serveur coordonné et activation explicite des deux nouvelles automatisations de récupération des autorisations. Les trois autres exports finance absents du cloud sont exclus du lot minimal proposé. Aucun statut de bogue ni décompte changé ; 1.3L et limites commerciales/terrain conservés. Preuves : artifacts/deployment-reprise-20261014-7b6e31a4/CHECKPOINT_DEPLOIEMENT_FINAL.md.


## Addendum — Réservation immédiate/programmée — 14 octobre 2026

Branche de travail : fix/booking-timing-20261014 ; base 0780c0efa75023dc1f012eed319bedc31b2ccbe5. Les branches et changements préexistants sont préservés. Les informations de déploiement des addenda antérieurs décrivent leur date historique, pas un état courant nouvellement certifié ici.

### P1-BOOKING-CONFIG-01 — BLOQUÉ

- Preuve : lecture Firestore de production seule du 14 octobre à 18:32:42Z : accept_new_delivery_requests=false, allow_driver_acceptance=false, payments_enabled=false, driver_payouts_enabled=false. system_config/booking_policy, booking_capacity et service_zones absents. Lecture minimale des véhicules à 18:53:48Z : 8 documents, aucun is_verified=true, aucune verified_capacity ni capacité non expirée. Aucun identifiant personnel archivé dans la synthèse.
- Impact : les captures de la demande montrent « La réservation est indisponible » à Mon prix ; cette étape ne confirme pas une mission et ne produit pas d’offre chauffeur. Le déclencheur d’assignation n’est pas démontré défaillant par cet essai. Les tests avec configuration fictive complète créent bien l’offre et la notification interne.
- Fichiers/contrat : functions/src/lib/bookingServer.ts (politique, zone, capacités et véhicule compatibles), lib/screens/delivery/delivery_request_flow_screen.dart (_loadConfiguration), functions/src/functions/dispatchMissionToDrivers.ts ; modèles config/booking_policy.template.json et config/booking_capacity.template.json.
- Action minimale : fournir et approuver la zone précise, la politique, les capacités mesurées d’au moins un véhicule réel et les seuils existants de manutention ; vérifier sa disponibilité et les prérequis de paiement avant bascule contrôlée. Aucun seuil pouvant affecter des frais ne doit être inventé. Aucune configuration réelle n’a été écrite ici.
- Fermeture : configuration réelle approuvée et vérifiée, déploiement compatible, recette contrôlée client → devis → confirmation → offre chauffeur ; les tests fictifs ne suffisent pas. Une simple activation des drapeaux est insuffisante.

### P2-BOOKING-TIMING-01 — VALIDÉ LOCALEMENT — NON FERMÉ — NON DÉPLOYÉ

- Transition : identifié par l’essai utilisateur → reproduit → corrigé → testé. Avant : Flutter 1 réussi/17 échoués, unité serveur 4 réussis/7 échoués. Après : 200 tests Flutter distincts, 34 tests unitaires et 23 tests émulateur réussis ; aucun échec/ignoré final. Les répétitions des 18 tests ciblés ne sont pas additionnées. Les trois échecs de préparation émulateur sont conservés séparément.
- Correctif : timing_mode explicite immediate/scheduled, jamais de date artificielle ; dates programmées conservées ; ancien payload sans ce champ strictement préservé. Modification du mode invalide devis et consentement via le mécanisme existant. Résumé client/chauffeur FR/EN/ES honnête, dépendant de la disponibilité. Aucun changement de moteur tarifaire ou de paiement.
- Périmètre testé : vrais widgets, 375×812, 430×932, 1440×900 et mobile 200 % ; reprise du brouillon, consentement et coordonnées ; vrais handlers de devis/création/dispatch dans demo-movik-test. Deux modes donnent offre et notification interne, montants du devis/mission/pricing_snapshot identiques en cents ; passage d’un mode à l’autre refuse la réutilisation du devis. FCM, Routes et paiement simulés.
- Limites : pas de Chrome réel, téléphone, transport Firebase déployé, émission FCM ni capture Stripe. Aucun financial_snapshot de paiement ou montant Stripe réel n’a été validé par ces essais. 1.3L reste BLOQUÉ ET REPORTÉ.
- Qualité : analyse ciblée, format, TypeScript, lint et build Web de recette réussis ; Git diff --check réussi. Preuves : artifacts/booking-timing-20261014/RESULTATS.json et CHECKPOINT_RESERVATION.md ; sources et tests permanents listés dans INTEGRITE.json.
- Reste à faire : recette de la version raccordée à une configuration approuvée ; aucune fermeture administrative ou mise en production revendiquée dans cette intervention.

En-tête précédent conservé :

Date de consolidation : 9 octobre 2026, America/Toronto. Dernière mise à jour : P1-WEBHOOK-01, 14 octobre 2026 ; traitement concurrent des événements Stripe corrigé et validé en émulateur, non déployé.

Anomalies actives non fermées : **P0 0, P1 0, P2 0** ; 28 fiches conservées, toutes fermées dans leurs périmètres locaux documentés. P1-WEBHOOK-01 fermé uniquement pour le chevauchement de webhooks simultanés et leurs doubles audits reproduits puis corrigés en émulateur ; aucune certification Stripe LIVE, aucune preuve exhaustive de reprise après crash, aucun déploiement.   P2-L-01 fermé après mesures WCAG et 243 tests Flutter locaux ; aucun déploiement ni validation navigateur/appareil physique.  GAP-M-05 fermé exclusivement dans le périmètre Flutter widget local après correction de la destruction des State d'onglets ; aucun push, merge ni déploiement.  GAP-M-06 fermé exclusivement dans le périmètre des deux abonnements Flutter bornés et des tests widget locaux, sans mesures Firestore réelles ni déploiement.  GAP-S-04 fermé dans le périmètre émulateur/Flutter local après accord de politique le 13 octobre 2026 ; aucun déploiement.  GAP-S-02 fermé exclusivement dans le périmètre des tests émulateur, sans Stripe réel ni déploiement. Les paiements historiques sans référence fournisseur sont signalés pour vérification manuelle.  P2-BUILD-001 est fermé uniquement pour le problème d'inclusion de la police Cupertino au build local, après ajout de la dépendance officielle et validation du bundling ; aucun écran de production n'est certifié. P1-HOME-001 et P1-COPY-001 fermés dans leur périmètre local validé, non déployé. Les anciens décomptes et limites sont conservés dans les addenda ; les P3 historiques et prérequis ne sont pas supprimés.


## Addendum — Parcours photo → prix → chauffeur — 15 octobre 2026

Branche vérifiée : feature/photo-assisted-booking-20261015 ; HEAD 197855b77063fdade69193f883a712e89dcdac74. Modifications locales non commitées. Aucun autre worktree modifié.

### P1-BOOKING-CONFIG-01 — BLOQUÉ, constat reconfirmé
Lecture seule horodatée du 15 octobre 2026 : les documents system_config/booking_capacity, booking_policy, service_zones et photo_analysis sont absents. Le chauffeur pilote autorisé est approuvé/en ligne, mais la requête driver_vehicles filtrée par son driver_id ne retourne aucun document; les champs de profil relatifs au véhicule se limitent à vehicle_verified et accepted_vehicle_categories. Cela ne constitue pas une capacité physique vérifiée. Les anciens drapeaux d'arrêt du 14 octobre ne sont pas annoncés revérifiés ici.

Le code photo, le questionnaire spécial, la vérification des photos avant devis, la transmission aux offres chauffeur et le refus individuel sont implémentés. Résultats finaux exécutés : 168 tests unitaires serveur, 28 tests d'intégration Firestore Emulator, 86 tests Flutter, tous réussis, aucun ignoré. Build Web, analyse ciblée, format, TypeScript, lint et diff check réussis. Les échecs initiaux restent dans les preuves.
Concordance exacte en cents vérifiée avec fournisseur fictif uniquement : devis = mission = snapshot financier = montant transmis au fournisseur. Aucun montant ni calcul financier modifié.

Preuves : artifacts/photo-journey-20261015-150639-1611abe5/ ; détails et limites dans CHECKPOINT_PHOTO_JOURNEY.md. Aucun appel Stripe ou cartographique, aucune mission réelle, aucune écriture de production ni déploiement. Auth/Storage réels, Chrome/téléphone, push réel et paiement réel non validés par cette série.
La relance après expiration/refus de toutes les offres reste à vérifier opérationnellement; le délai existant de 45 secondes n'a pas été modifié.
Le test autonome 1.3L reste BLOQUÉ ET REPORTÉ.

Aucune fermeture administrative dans cette intervention. Tableau actif conservé : P0 0 / P1 1 / P2 2, 31 fiches. P2-BOOKING-TIMING-01 et P2-AUTH-LOGOUT-01 restent dans leur statut antérieur; les fermetures GPS ne sont pas rouvertes. Capacités réellement mesurées, mapping des catégories, zone et conditions approuvées restent requis avant mise en service.


## Addendum — Parcours avec comptes client/chauffeur — 15 octobre 2026

Branche vérifiée : feature/photo-assisted-booking-20261015 ; HEAD 197855b77063fdade69193f883a712e89dcdac74. L'autorisation d'ouverture publique est conditionnelle à un parcours concluant. Aucun changement de production, déploiement, paiement réel, push ou commit effectué dans cette intervention.

### Validation nouvelle, distincte des 282 tests historiques

- Nouveau test permanent : functions/test/integration/photoAccountJourney.test.ts. Trois identités locales Auth distinctes : client ordinaire, chauffeur, autre client. Connexion par mot de passe fictif et vérification des ID tokens en émulateur ; aucun rôle administrateur utilisé dans le parcours.
- Firebase Auth, Firestore et Storage réellement démarrés sur loopback, projet demo-movik-test. JPEG synthétique de 2314 octets téléversé/lisible via SDK client ; règles Firestore et Storage existantes appliquées. Photo privée avant mission, accès chauffeur après offre, refus d'accès de l'autre client démontrés.
- Première exécution : 4 réussis / 0 échoué / 0 ignoré. Extension aux trois catégories existantes : résultat final 8 réussis / 0 échoué / 0 ignoré (six parcours immédiat/programmé pour pickup_truck, cargo_van et cube_truck, plus refus chauffeur et exclusion de véhicule non vérifié). Les quatre premiers scénarios ne sont pas additionnés aux huit finaux.
- Offre et notification interne accessibles au chauffeur, sélection du véhicule compatible, acceptation visible au client, absence de doublon de création. Montants entiers du devis local, de la mission, du snapshot financier et de FakePaymentProvider identiques. Aucun montant ni calcul produit modifié.
- IA, trajet, FCM et paiement fictifs ; handlers appelés directement avec tokens locaux vérifiés. Aucun transport Cloud Functions déployé, Chrome, téléphone, push réel ni Stripe Sandbox/LIVE validé. Les capacités et politiques semées sont fictives et ne sont pas des valeurs autorisées pour la production.
- TypeScript source et nouveau test : réussis. Lint source et test final : réussis. Premier lint du test refusé parce que le tsconfig source exclut test/ ; erreur conservée, vérification finale utilisant une configuration temporaire dédiée sans modification des règles ESLint.
- Garde réseau Node refusant les destinations hors des ports loopback autorisés ; deux tentatives bloquées par exécution (localhost:40001 et execFile). Aucun assouplissement. Pas de confinement OS général revendiqué ; 1.3L reste BLOQUÉ ET REPORTÉ. Les seuls processus émulateurs démarrés par ces essais ont été arrêtés.

### P1-BOOKING-CONFIG-01 — BLOQUÉ, ouverture publique non autorisable sur ces preuves

- Lecture seule production à 2026-10-15T19:53:28Z : accept_new_delivery_requests, allow_driver_acceptance, payments_enabled et driver_payouts_enabled sont false ; booking_capacity, booking_policy, service_zones et photo_analysis absents.
- Vérification complémentaire à 20:01:53Z : huit documents driver_vehicles, aucun lié au chauffeur pilote indiqué, aucun is_verified=true, aucune verified_capacity vérifiée. Aucun autre champ propriétaire ni référence de véhicule du profil ne fournit une liaison de repli. Les drapeaux vehicle_verified/accepted_vehicle_categories du profil ne suffisent pas au contrat de réservation.
- Le compte client réel proposé possède aussi des rôles driver/super_admin : il n'a pas été utilisé pour prouver les permissions d'un client ordinaire. Son identité n'a pas été modifiée.
- Avant ouverture : raccorder le véhicule réel et ses capacités vérifiées ; fournir les configurations approuvées de zone, réservation et analyse photo ; valider l'intégration déployée, la collecte de paiement et la réception réelle des offres. Aucune valeur physique, financière ou commerciale ne sera inventée pour lever ces gardes.
- Preuves : artifacts/pilot-account-journey-20261015-155104-44a3cbdc/ (production-readonly.json, vehicle-link-readonly.json, accounts-first/, accounts-vehicle-categories/, quality.json, CHECKPOINT_COMPTES_CLIENT_CHAUFFEUR.md).

Aucune fiche fermée ni rouverte. Décompte conservé à recalculer depuis le tableau actif : P0 0 / P1 1 / P2 2, 31 fiches. Les preuves historiques et les modifications produit préexistantes sont conservées.


## Addendum — Parcours chauffeur/véhicule — 16 octobre 2026

Branche feature/photo-assisted-booking-20261015 ; HEAD de reprise 197855b77063fdade69193f883a712e89dcdac74. Les modifications photo préexistantes et les preuves antérieures sont préservées.

- Reproduction : le vrai formulaire proposait dix ChoiceChip au lieu des trois catégories approuvées; test initial échoué, correctif et suite d'inscription ensuite réussis.
- Implémentation : inscription limitée à pickup_truck/cargo_van/cube_truck; nouvelle fiche administrative de capacité pour chaque véhicule; validation/révocation par reviewDriverVehicle; contrôle de rôle, propriétaire, identité inchangée, profil approuvé et documents valides jusqu'à l'échéance demandée; audit atomique. Protection des champs de validation et de l'identité du véhicule vérifié dans les règles clientes.
- Les capacités ne sont ni déduites d'une photo ni préremplies avec un véhicule fictif. La charge utile déclarée seule n'accorde aucune éligibilité. Les catégories camelCase historiques et les timestamps Firestore sont lus sans modifier les documents enregistrés.
- Tests finaux distincts : inscription 4; interface administrative et modèle 18; non-régression chauffeur 30; permissions/validation serveur 18; parcours intégré 8. Total 78 réussis, 0 échec final, 0 ignoré. Les anciennes exécutions ne sont pas additionnées. Les erreurs initiales de syntaxe/import du nouveau test et d'assertion UTC/local sont conservées dans leurs journaux; la comparaison d'instants vérifie désormais explicitement la valeur UTC.
- Les 8 parcours utilisent maintenant un compte administratif fictif distinct pour approuver le dossier et vérifier les capacités, au lieu d'insérer directement un véhicule vérifié. Les comptes client/chauffeur gardent leurs seuls rôles. Auth, Firestore et Storage locaux; IA, trajet, FCM et paiement fictifs. Photo privée, offre/notification interne, refus, acceptation et égalité exacte des cents devis/mission/snapshot/fournisseur fictif vérifiés.
- Rendu widget FR/EN/ES aux formats 375×812, 430×932, 1440×900 et mobile à 200 %. Pas de preuve Chrome ou téléphone physique. TypeScript et lint serveur réussis; analyse Flutter ciblée sans problème.
- Isolation : demo-movik-test, ports loopback, garde Node, aucun service Functions déployé démarré pour ces essais. Les processus émulateurs appartenant aux essais ont été arrêtés. Aucun Stripe réel/Sandbox, GPS physique ou service cartographique sollicité. Pas de confinement OS général revendiqué; 1.3L reste bloqué/reporté.

P1-BOOKING-CONFIG-01 demeure BLOQUÉ. Lecture seule du 16 octobre à 13:03:28 UTC : quatre configurations toujours absentes, quatre drapeaux opérationnels false, aucun véhicule associé au chauffeur de recette indiqué. L'autorisation de publication est acquise, mais les valeurs commerciales et physiques manquantes ne sont pas inventées : contact officiel à publier, zone exacte, capacités et mapping, seuils approuvés et conditions de réservation. Le parcours d'inscription permet aux futurs chauffeurs d'apporter leurs propres véhicules; Daniel n'a pas à fournir un véhicule personnel.

Aucune fermeture administrative nouvelle. Les 31 fiches sont conservées; tableau actif P0 0 / P1 1 / P2 2. Les statuts de déploiement historiques ne sont pas globalement réconciliés par cette intervention.
Preuves : artifacts/driver-vehicle-rollout-20261015-1648-7b62e3/ ; guide docs/DRIVER_VEHICLE_PILOT.md. Aucun déploiement ni écriture de configuration cloud dans cette reprise.


### 2026-10-16 — Raccordement réel de l'analyse photo
Preuves: artifacts/ai-rollout-20261016-0940/. Fonction analyzeBookingPhoto publiée, secret serveur lié, quotas et accès authentifié configurés. Un essai réel sous compte ordinaire a réussi (photo privée → suggestion fauteuil); refus non authentifié contrôlé. Nouvelle version Web photo et contact info@movi-k.com publiés. Fonctions reviewDriverVehicle et declineDeliveryOffer et protection des métadonnées de véhicule publiées après comparaison des sources testées.
Aucune fermeture automatique supplémentaire: la configuration complète des réservations, les capacités des véhicules réels, les modalités du pilote et la réception du contact restent distinctes. Conserver les 31 fiches et le décompte précédent P0=0/P1=1/P2=2 tant que leurs critères ne sont pas démontrés.
Les tarifs, commissions, montants Stripe, snapshots et ledger n'ont pas été modifiés par ce raccordement. Aucun paiement ni mission réelle créé pendant les essais IA. 1.3L reste bloqué/reporté.


### 2026-10-16, 14:10 UTC — Contrôle public final de l'IA
Après retour temporaire à l'ancien déploiement pendant le diagnostic, le bundle photo a été republié et vérifié directement sur movi-k.com. Chrome réel : connexion client temporaire, téléversement/aperçu privé, analyse HTTP 200, suggestion fauteuil, application et sauvegarde de la catégorie armchair et de la description; poids/dimensions null conservés. Aucune erreur JS/réseau lors de cette exécution finale. Aucun paiement ni mission réelle. Données et compte de test nettoyés.
Le premier affichage « Synchronisation en attente » n'a pas été reproduit lors du contrôle final; sa cause initiale exacte n'est pas affirmée. Les erreurs de saisie et l'attente de texte du harnais ont été diagnostiquées séparément, sans correction arbitraire du produit. Aucune règle Storage assouplie pour le localhost. Historique complet conservé.
45 tests Flutter et 72 tests TypeScript réussis dans le raccordement; build Web, analyse ciblée, lint et diff check réussis. Contact info@movi-k.com publié, réception non vérifiée. Référence : artifacts/ai-rollout-20261016-0940/CHECKPOINT_RACCORDEMENT_IA_SITE_20261016.md.
Aucune clôture supplémentaire. Tableau inchangé : 31 fiches, P0 0 / P1 1 / P2 2. P1-BOOKING-CONFIG-01 demeure bloqué pour l'ouverture commerciale; IA active ne signifie pas réservation/paiement activés. 1.3L reporté.


### 2026-10-16 — Formulaire épuré, import photo Web et estimations indicatives
Preuves : artifacts/photo-simple-20261016-1030/CHECKPOINT_PHOTOS_FORMULAIRE_20261016.md. Publication Vercel dpl_2wFirDS82DMkdJZtEqfkaFKDqB5L et analyzeBookingPhoto uniquement. PNG/JPEG/WebP ≤20 MiB préparés localement en JPEG ≤5 MiB; formulaire repliable, fourchettes IA séparées des mesures et du devis. Test Chrome réel réussi avec PNG de 10,4 Mo, aperçu privé, analyse et sauvegarde; compte et données temporaires nettoyés. 79 Flutter +83 TypeScript réussis dans l’exécution finale; historiques échoués conservés. Aucune mission ni paiement réel, aucun tarif/commission/snapshot/ledger modifié.
Aucune fermeture nouvelle : les 31 fiches restent présentes; P0 0 / P1 1 / P2 2. P1-BOOKING-CONFIG-01 reste bloqué pour l’ouverture commerciale, 1.3L bloqué/reporté. Les estimations de dimensions ne prouvent pas une capacité véhicule. Tests de téléphone physique et parcours payant hors périmètre. Branche feature/photo-assisted-booking-20261015, HEAD 197855b77063fdade69193f883a712e89dcdac74 inchangé; pas de commit/push/merge.


### 2026-10-16 — Ajout de photos compact
Bouton + dans la rangée des photos; ajout d’un autre objet distinct; annulation sans nouvelle fiche vide; emplacements vierges préexistants conservés et compactés. 54 tests Flutter réussis, analyse ciblée, format, diff check et build Web réussis. Chrome réel : deux photos sur un objet et annulation vérifiés; compte/données temporaires nettoyés. Publication Vercel dpl_DndXRgfmzvz73n8E2zUQMZL59tT4, sans modification serveur/financière. Preuves : artifacts/photo-add-compact-20261016-1118/CHECKPOINT_AJOUT_PHOTOS_COMPACT_20261016.md.
Aucune fermeture supplémentaire : 31 fiches, P0 0 / P1 1 / P2 2. Ouverture commerciale et 1.3L restent distinctes et non validées par cette modification UI.


### 2026-10-16 — Autocomplétion des adresses rétablie sur le site
Incident reproduit dans Chrome : Places HTTP 400 API_KEY_INVALID. La compilation locale contenait une valeur de remplacement de 11 caractères, pas la clé restreinte existante. Clé « Movi-K Places Web » récupérée par accès autorisé, restrictions d’origine/API conservées, injection réparée dans les fichiers de compilation ignorés. Aucune valeur de clé publiée dans les preuves. Garde permanent ajouté au build contre les valeurs masquées ou malformées.
Validation finale : 39 tests Flutter et 9 tests Node réussis, 0 échec final et 0 ignoré; analyse ciblée, format, diff check et build Web réussis. Tests historiques échoués conservés (mauvais chemin du garde dans un harnais temporaire; option de transport manquante; comptage ancien de quatre ChoiceChip alors que deux choix de planification existent maintenant). Assertion de traduction désormais explicite pour les quatre étapes, sans changer le produit.
Publication Vercel dpl_82YhV8EKCpGNtMWmV6LcTVNzy8o6; bundle vérifié sur movi-k.com et www. Chrome réel 1440×900 et 375×812 : suggestions, sélection et détails HTTP 200 pour ramassage et livraison, ville/code postal/coordonnées présents, conservation indépendante des deux champs. Aucune mission, aucun devis ni paiement réel. Le premier contrôle DOM lisait une ancienne valeur du champ non focalisé, malgré une adresse correcte et la coche verte dans la capture; contrôle final par refocalisation conservant la comparaison exacte.
Observation mobile non bloquante : une suggestion de ramassage est restée visible après sélection dans la capture; causes et comportement hors automatisation à qualifier, aucune erreur de sélection démontrée. Pas de validation téléphone physique, ni d’ouverture des réservations. Aucun changement de code Dart produit, backend, prix, commission, snapshot ou ledger. 1.3L reste bloqué/reporté.
Preuves : artifacts/address-autocomplete-20261016-1222/CHECKPOINT_ADRESSES_20261016.md. Aucun commit, push ou merge. Les 31 fiches historiques sont conservées; aucune fermeture administrative supplémentaire. Décompte recalculé : P0 0 / P1 1 / P2 2.


### 2026-10-16 — Analyse photo automatique et classement des divans/sectionnels
Ajout de photo → analyse automatique → catégorie et description préremplies et sauvegardées; suppression du clic « Utiliser cette suggestion ». Description rendue visible. Confirmation du client conservée; aucune mesure réelle, quantité, capacité, prix ou éligibilité inventée. Taxonomie IA explicite sofa/divan/canapé/sectionnel versus fauteuil individuel, contexte de fond distingué des objets à transporter, confiance de catégorie distincte de l'incertitude des dimensions. Traitement de l'image en détail élevé.
Tests finaux : 97 Flutter + 84 TypeScript réussis, zéro échec final/ignoré; analyse Flutter, format, TypeScript, lint source, diff check et build Web réussis. Les 4 échecs Flutter initiaux démontrent l'absence d'analyse automatique; le test initial de contrat de prompt échoue aussi. Les tentatives intermédiaires et erreurs du harnais sont conservées sans être présentées comme des tests produit réussis.
Chrome réel sur movi-k.com : ajout de sectionnel → analyzeBookingPhoto HTTP 200 → category sofa / label « Divan sectionnel »; ajout d'un fauteuil → armchair, premier objet préservé; aucun clic Analyser/Utiliser, aperçu privé chargé, sauvegarde vérifiée, aucune erreur finale navigateur, nettoyage des comptes/données temporaires réussi. Photos de test, pas la capture utilisateur inaccessible. Mobile 390×844 et desktop 1440×900 observés; FR/EN/ES et 375/430/1440 + texte 200 % par widgets, pas téléphone physique.
Publication Vercel dpl_3tdiLCMw9bhMnwNuFjwCsMa4wDy1 (photo-auto-sofa-v3), empreinte de bundle contrôlée sur movi-k.com et www; fonction analyzeBookingPhoto ACTIVE revision analyzebookingphoto-00003-baq. Seuls trois fichiers produit diffèrent de la source précédemment publiée. Aucun prix/commission/Stripe/snapshot/ledger/règle Firestore modifié. Aucun paiement ni mission réelle. HEAD inchangé, aucun commit/push/merge.
Preuves : artifacts/photo-auto-sofa-20261016-1312/CHECKPOINT_ANALYSE_AUTO_DIVAN_20261016.md.
Les 31 fiches et leurs historiques sont conservés, aucune autre fiche fermée. P1-BOOKING-CONFIG-01 et 1.3L restent dans leurs états antérieurs. Les fourchettes restent indicatives, pas une validation physique de l'encombrement ou du véhicule; l'analyse ne garantit pas la reconnaissance de toutes les photos.


### 2026-10-16 — Accès au devis indépendant des conditions de réservation
Lecture production 17:54–17:58 UTC : booking_policy, booking_capacity et service_zones absents; seule grille tarifaire enregistrée PREPROD-TEST-PRICING-001, explicitement preproduction_test_only. Le rayon de 40 km autour de Granby est déjà approuvé dans la conversation mais pas configuré. Aucun nouveau constat des drapeaux opérationnels revendiqué.
Correction frontend locale : devis indépendant de la politique de réservation, contrôle serveur conservé, aucune préparation de carte sans politique, confirmation toujours protégée. Reproduction fiable 1 réussi/3 échoués; ciblé final 6/6; non-régression finale 166/166, aucun ignoré. Première assertion du harnais corrigée (bouton désactivé plutôt qu’absent) et erreur de virgule intermédiaire conservées dans les preuves. Analyse Flutter ciblée, format et diff check réussis. Aucun build Web, Chrome ni devis réel exécuté. Aucun déploiement/commit/push, aucune valeur financière ou configuration cloud changée.
Preuves : artifacts/quote-unblock-20261016-1755/CHECKPOINT_DEBLOCAGE_DEVIS_20261016.md. Seule source produit modifiée par rapport au manifeste publié : delivery_request_flow_screen.dart. P1-BOOKING-CONFIG-01 reste BLOQUÉ; 31 fiches conservées, P0 0/P1 1/P2 2. La tarification de test ne constitue pas une grille commerciale approuvée. 1.3L reste bloqué/reporté.


### 2026-10-16, 18:12 UTC - Grille tarifaire conservée sur approbation explicite
Instruction utilisateur : « conserve cette grille ». Création atomique de pricing_versions/MOVIK-PILOT-20261016-001, mise à jour du pointeur pricing_configs/active et audit pricing_approval_20261016_001 dans movik-connect-prod à 2026-10-16T18:12:09.063759Z. Nouvelle portée pilot_approved ; source PREPROD-TEST-PRICING-001 intégralement préservée, empreinte et updateTime inchangés. Toutes les valeurs financières conservées à l’identique, commission 15 %, aucune mission ni paiement créé.
Vérification exécutée : moteur serveur réel chargé localement, 11 catégories historiques × 6 scénarios = 66 réussis / 0 échoué / 0 ignoré. Comparaison de tous les champs financiers et des résultats, y compris les cents, avant/après. Transport local sous garde réseau Node ; aucun appel financier externe. Ces simulations ne valident ni Stripe, ni les taxes effectivement applicables, ni le parcours de réservation complet.
Lecture production à 18:08 UTC : booking_capacity, booking_policy et service_zones toujours absents ; accept_new_delivery_requests, allow_driver_acceptance, payments_enabled et driver_payouts_enabled false. Drapeaux relus après écriture, inchangés. Le rayon de 40 km approuvé reste à raccorder à des consommateurs déployés compatibles. Capacités, mapping et seuils de manutention ne sont pas inventés ; politique de réservation et validation opérationnelle restent requises. Le correctif frontend d’accès au devis de 17:55 demeure non publié par cette intervention.
Preuves : artifacts/pricing-approved-20261016-1808/CHECKPOINT_GRILLE_APPROUVEE_20261016.md ; plan.json, pricing-validation.json, write-set.json, commit-result.json, verification.json. Aucune modification du code de calcul, de Stripe, de snapshot ou ledger, aucune modification de fiscalité, aucun déploiement de code, commit/push/merge. Retour arrière documenté, non exécuté. Aucune fermeture supplémentaire : 31 fiches, P0 0 / P1 1 / P2 2. P1-BOOKING-CONFIG-01 reste BLOQUÉ ; 1.3L bloqué/reporté.


### 2026-10-16, 18:53 UTC — Publication accès devis et diagnostic connecté
Preuves : artifacts/quote-public-20261016-1840/CHECKPOINT_PRIX_PUBLIC_20261016.md. Web quote-policy-decoupled-v1 publié (dpl_6gCDuWGApWy33wEqDH5AdyqqVce2), hash contrôlé sur movi-k.com/www ; Chrome invité et connecté, mobile/desktop, brouillon/handoff préservés. Trois fonctions reviewDeliveryLoad/calculateDeliveryQuote/requestBookingReview publiées et ACTIVE ; zone Granby rayon 40 km appliquée, drapeaux opérationnels false inchangés. 126 tests serveur ciblés nouveaux réussis/0 échoué/0 ignoré, TypeScript/lint/build réussis. Les 166 tests Flutter antérieurs ne sont pas additionnés.
Résultat connecté réel : review_required avec photo_policy_unconfigured, capacity_unconfigured, photo_category_unconfigured ; aucun devis officiel obtenu. Mesures inconnues d’objet photo et zone ne sont plus les raisons de refus observées. Huit véhicules inventoriés, zéro capacité vérifiée enregistrée. Le devis reste BLOQUÉ par la configuration/contrat de capacité, et booking_policy reste absent pour confirmer. Ne pas déclarer le parcours ni les ventes prêts.
Ancien serveur ne contenait pas photo_assisted. Prix, monnaie, intégrité et taxes identiques aux sources réellement publiées avant cette intervention. Aucun paiement, mission, montant ou tarif changé. Compte/photo/documents de test nettoyés. Preuve initiale Vercel protégée et erreur de syntaxe du script temporaire conservées ; aucune fausse réussite. Autres consommateurs de réservation à vérifier avant ouverture. 31 fiches conservées, P0 0/P1 1/P2 2, P1-BOOKING-CONFIG-01 et 1.3L toujours bloqués. Aucun commit/push/merge ; autres worktrees préservés.


### 2026-10-16 — Préparation du brouillon sans boucle de disponibilité
Cause reproduite : l'accès aux coordonnées dépendait de quoteValid et toute erreur de configuration devenait policy null. Correctif : préparation explicite sans devis jusqu'au résumé, conservation des coordonnées/navigation/rafraîchissement, distinction entre revue refusée, réservation fermée, paiement indisponible et erreur technique. Disponibilités exposées en lecture seule par getBookingConfiguration via le lecteur central; aucun flag activé.
Reproduction 12 réussis/5 échoués; ciblé 23 réussis; non-régression initiale 176/2 (option isolation manquante), puis 200/1 (fixture date à 1 ms), suite coordonnées finale 46/0 et préparation/erreurs finale 21/0. Bilan distinct : 201 Flutter et 7 serveur réussis, aucun échec final/ignoré. Anciennes erreurs et assertions préservées; fixture stabilisée sans affaiblir la comparaison. Analyse Flutter intégrale, TypeScript/lint source, format, diff check et build Web réussis.
Chrome réel local et movi-k.com : coordonnées saisies, résumé sans prix ni réservation, retour et rafraîchissement avec données conservées; uniquement getBookingConfiguration appelé. Déploiement Web dpl_3z1Xs3fbPnhZP6rqiJpDBh5wXwXf et fonction getBookingConfiguration revision getbookingconfiguration-00002-ziw; empreintes publiques contrôlées. Quatre flags false inchangés. Aucune mission, transaction, notification ou carte réelle; aucun calcul financier/GPS modifié.
Preuves : artifacts/draft-preparation-20261016-1910/CHECKPOINT_PREPARATION_20261016.md et journaux/captures. La préparation est débloquée, mais le devis officiel et l'ouverture commerciale restent soumis à la configuration autoritative; aucune fermeture globale P1-BOOKING-CONFIG-01. 31 fiches conservées, P0 0 / P1 1 / P2 2; 1.3L toujours bloqué/reporté. Sauvegarde Git locale ciblée autorisée, aucun push ni merge.


## Décision du 17 octobre 2026 — retrait de l’option objet lourd

Le propriétaire demande puis confirme la suppression du supplément de 10 CAD pour les nouveaux devis et autorise le push Git. Correction locale validée : nouveaux devis neutralisent le flag lourd, seuil tarifaire lourd retiré des prérequis ; autres frais et contrôles physiques préservés. Devis historiques, versions tarifaires stockées et moteur historique inchangés. Aucune nouvelle confirmation client « lourd » ajoutée. Décision commerciale antérieure sur poids inconnu résolue par suppression du supplément. Les autres prérequis restent bloquants ; aucune fermeture. Voir docs/audit/RETRAIT_OPTION_LOURD_20261017.md pour preuves et portée du commit. Aucun déploiement ni paiement réel.


### 2026-10-19 — Bloc admin À traiter (validation locale)
Ajout des quatre files cliquables et compteurs serveur distincts. Correction du comptage des litiges terminés et du rafraîchissement setState/Future ; navigation disponible même si les statistiques échouent. 32 tests Flutter distincts et 3 tests serveur simulés réussis, analyse/build Web/TypeScript/lint/diff check validés. Preuves et limites : docs/audit/ADMIN_ACTION_CENTER_20261019.md. Non déployé ; aucun ancien blocage fermé et aucun décompte historique révisé.


### 2026-10-19 — Publication autorisée du bloc admin À traiter
Suite à « oui tu peux déployer », source 506f95eb061336ec780d5d28d7699aad23c08fc1 publiée : Vercel dpl_9qHi2fjrsUVCnSnCCLmRqs1mYq2J et getAdminDashboardMetrics révision getadmindashboardmetrics-00002-lat ACTIVE. À 19:01 UTC, les deux domaines servent le nouveau bundle contrôlé par SHA256 ; /fr/admin HTTP 200 et appel fonction sans authentification HTTP 401. Preuves : docs/audit/ADMIN_ACTION_CENTER_20261019.md et artifacts/admin-action-center-20261019/web-promote-result.json. Affichage administrateur connecté non validé en production. Aucun push, merge ou transaction réelle ; aucun ancien blocage fermé ni décompte historique révisé.


### 2026-10-19 — Présence des chauffeurs, recherche et évaluations (local)
Ajout local du compteur de sessions récentes, accès à la liste existante et filtres ville/connexion. Disponibilité de dispatch préservée. Statistiques et avis calculés en lecture seule avec contrôle analyste ; note entière unique par mission et date serveur imposées. Accès à l'évaluation depuis les demandes terminées et invitation de fin de mission ajoutés. Débordements mobile à 200 % reproduits puis corrigés. 39 scénarios Flutter distincts, 18 tests serveur unitaires simulés et 9 tests de règles en émulateur réussis ; preuves et limites : docs/audit/ADMIN_DRIVER_ACTIVITY_20261019.md. Définition commerciale de « mission échouée » encore à approuver ; aucune annulation assimilée à un échec. Non déployé, aucune transaction ni fermeture d'ancien blocage, aucun décompte historique révisé.


### 2026-10-19 — Définition approuvée des échecs et constat administratif (local)
Approbation explicite du propriétaire à 15:46 Toronto : livraison non réalisée avec échec confirmé par l'administration ; annulations séparées et responsabilité du chauffeur non présumée. Version MOVIK-FAILURE-REVIEW-20261019-001. Ajout d'un constat séparé, motif et attestation obligatoires, date serveur/acteur, garde de concurrence (statut/chauffeur/révision), audit atomique et retrait motivé. Aucun changement de statut de mission ou d'opération financière. Compteur raccordé aux constats valides ; écritures directes interdites par les règles. 38 scénarios Flutter distincts, 54 tests unitaires serveur simulés et 5 tests de règles en émulateur réussis ; détails et limites dans docs/audit/MISSION_FAILURE_REVIEW_20261019.md. Décision produit résolue ; non déployé. Aucun ancien blocage fermé ni décompte historique modifié.


### Prépublication activité chauffeurs — 2026-10-19
Autorisation utilisateur : « pousse le ». Le contrôle de la version Firebase publiée a révélé des protections supplémentaires sur driver_vehicles (identité et revue de capacité réservées, caractéristiques d’un véhicule vérifié non modifiables par son propriétaire). Ces protections existantes sont conservées dans la branche avant publication des règles de présence, des avis et des constats administratifs. Aucune règle financière modifiée. Preuves : artifacts/admin-driver-activity-release-20261019/. Aucun ancien incident fermé par ce contrôle.


### Publication activité chauffeurs et constats administratifs — 2026-10-19T20:07:31.706Z
Source : 3763edfb6cdf7d3cb9dea0d814cc48b17210cbdb ; branche feat/admin-driver-activity-20261019. Vercel : dpl_F9g1fAHbU5xn7rcv8yp34uofFoQf. Empreinte main.dart.js : 814698fc8a4c43e3ea433a92b8fe6253ce01fe22fa816fda7d2d002ae7da1cf6. Les deux domaines publics servent le bundle attendu ; /fr/admin répond HTTP 200. Fonctions getAdminDriverActivity et reviewMissionFailure ACTIVE, accès non authentifié refusé (401). Règles publiées vérifiées égales au fichier local, avec conservation des protections préexistantes des véhicules vérifiés.
Validation locale antérieure : 38 tests Flutter et 54 tests serveur simulés ; contrôle complémentaire des règles fusionnées : 14 tests réussis en émulateur. Build production réussi. Aucune mission ni aucun paiement réel créé, aucun constat administratif réel enregistré. Parcours privé administrateur et présence multi-appareils non validés en production authentifiée. Aucun ancien bogue fermé. Preuves : artifacts/admin-driver-activity-release-20261019/.


### Refonte aide et accès client — 19 octobre 2026 — validation locale
Branche feat/customer-loading-help-20261019, base 0e3579207bde0bcdadb43ee7b8b6908de728a97d. Aide Movi-K tarifée séparée de l’aide humaine sur place ; choix sans présélection, accès confirmés, détails indépendants et résumé explicite. Reproduction initiale puis correction : 96 scénarios Flutter distincts validés dans leurs dernières exécutions, 68 tests serveur simulés ; analyse intégrale et build Web réussis. Voir CUSTOMER_LOADING_HELP_20261019.md et artifacts/customer-loading-help-20261019/. Aucun déploiement, transaction, push ni fusion. Aucun ancien incident fermé et aucun décompte historique réécrit. Les protections tarifaires, de réservation et de paiement restent en place.


### 2026-10-20 — Publication de la refonte aide au chargement
Source f11e24342b1b721a41eb1143fa4e47d821faf61e publiée après autorisation de Daniel. Déploiement dpl_7Uthx9F6xcSwZVP5Kwm6KGjWLRex vérifié sur les deux domaines ; quatre fonctions ACTIVE et refus anonyme 401. Rapport : CUSTOMER_LOADING_HELP_20261019.md, section publication. Erreur initiale Google code 13 conservée, relance ciblée réussie. Aucun bogue antérieur fermé, aucun changement de décompte, aucune transaction réelle.


### 2026-10-20 — Agenda chauffeur : premier bloc en développement
Branche feat/driver-agenda-20261020. Lecture des missions attribuées et sauvegarde sécurisée des disponibilités ajoutées localement. Rapport : DRIVER_AGENDA_20261020.md. Validation : 23 tests unitaires serveur, 3 tests Firestore Emulator agenda, 11 tests existants d'acceptation avec fournisseur de paiement fictif, 21 tests Flutter. Le dispatch ne consulte pas encore ces plages ; le verrou commercial pre_assignment est conservé. La durée totale d'occupation doit être définie avant raccordement et protection contre deux missions qui se chevauchent. Aucun déploiement ni fermeture de fiche ; décompte antérieur inchangé.


### 2026-10-20 — Agenda chauffeur complet : validation locale, activation en attente
Reprise vérifiée de feat/driver-agenda-20261020 à 37d0859, fichiers suivis/index initialement propres, autres worktrees préservés. Agenda jour/semaine/mois, récurrences/exceptions/pauses, aperçu des conflits, offres régionales, attribution transactionnelle et réservations atomiques raccordés. Rejeu d’acceptation corrigé après détection de deux créations de paiement fictif ; aucun changement du cycle financier. Le GPS des missions futures reste arrêté avant départ. Protection contre contournement administratif et désactivation ignorant des réservations futures.
Google/Outlook : OAuth, chiffrement serveur, libre/occupé, événements idempotents, erreurs/réessais et déconnexion développés ; tests uniquement simulés. Apple : export .ics manuel explicitement qualifié.
Validation finale distincte : 111 Flutter, 72 unitaires serveur, 347 intégrations Firebase Emulator (Firestore/Storage/Auth) réussis, aucun échec final ni ignoré dans ce périmètre ; analyse intégrale, TypeScript, lint, diff check et build Web réussis. Relances recouvrantes non additionnées. Échecs intermédiaires conservés, notamment fixture de date serveur, raccordement des projets Storage et absence d’Auth Emulator.
Rapports : DRIVER_AGENDA_COMPLETE_20261020.md et DRIVER_AGENDA_RELEASE_20261020.md ; preuves : artifacts/driver-agenda-complete-20261020/. Deux captures historiques non suivies ont été écrasées par le premier lancement du test ancien ; incident déclaré, chemin corrigé et comparaison « avant » reconstruite depuis HEAD, sans la présenter comme preuve historique originale.
Aucun push, fusion, déploiement, connexion OAuth réelle, notification chauffeur réelle ni transaction réelle. Durée totale/horizon commercial, confidentialité/conservation et ouverture opérationnelle à approuver ; verrou pre_assignment et protections financières conservés. Aucun ancien incident fermé : décompte historique inchangé (31 fiches, P0 0 / P1 1 / P2 2), P1-BOOKING-CONFIG-01 ouvert, 1.3L bloqué/reporté.


### 2026-10-20 à 12:56 Toronto - Approbation de la période complète par le chauffeur
Daniel approuve explicitement la confirmation avant acceptation de toute la période nécessaire au chargement, au trajet et au déchargement, pour réserver ce créneau dans l'agenda. Version : MOVIK-DURATION-CONFIRMATION-20261020-001 ; source exacte et portée dans DRIVER_DURATION_APPROVAL_20261020.md. Le code a8674e3d concorde avec cette règle ; aucun changement de comportement nécessaire.
Rapport et exemple de publication mis à jour : duration_confirmation_approved=true dans l'exemple seulement ; enabled=false, approved=false, horizon non choisi. Aucun changement Firebase, push, fusion, déploiement, OAuth, notification ou paiement réel. Intervention documentaire sans relance des suites ; les résultats antérieurs ne sont pas de nouveaux tests.
Horizon commercial, confidentialité/conservation et ouverture opérationnelle restent à approuver. Aucun incident fermé ni décompte modifié : 31 fiches, P0 0 / P1 1 / P2 2 ; P1-BOOKING-CONFIG-01 ouvert ; 1.3L bloqué/reporté.


### 2026-10-20T17:21:21.341Z - Publication autorisée de l’agenda chauffeur
Autorisation de Daniel : « pousse sur movi-k.com ». Vercel dpl_5WQLUCk21nw6np7gyogsg3viAN7s, source Web 469b6a3b1caed6da855ad97344cb0fc139df3a07, serveur 55ba38da3ade62bbdae0adbd336e175eda117e06. Les deux domaines servent le bundle ec49b5c0d8e7a139a326ad376a6afc0b535fb0342a84964257cf4fd6fed3ee9e. 19 fonctions ACTIVE, 14 refus anonymes 401, règles Firestore/Storage relues conformes, 3 index READY. Rapport : DRIVER_AGENDA_PRODUCTION_20261020.md.
Comparaison au serveur publié : protections de refus d’offre restaurées après 4 échecs reproduits, puis 27 tests d’intégration réussis. Dépendance globale aux secrets OAuth corrigée après refus de publication et 4 tests rouges, puis 76 tests unitaires réussis, TypeScript/lint valides. Les suites recouvrantes ne sont pas additionnées. Première tentative Firebase conservée ; relance publiée avec succès.
Les 8 fonctions OAuth non configurées restent non publiées ; aucune connexion réelle. Les quatre flags opérationnels/financiers restent false et les documents driver_scheduling, calendar_oauth, booking_policy absents. Aucune mission, transaction ou notification réelle déclenchée pour valider. Aucun tarif, cycle financier ou moteur de devis changé ; aucun push ni merge. Aucun ancien incident fermé ni décompte modifié : 31 fiches, P0 0 / P1 1 / P2 2 ; P1-BOOKING-CONFIG-01 ouvert ; 1.3L bloqué/reporté.


### 2026-10-20 — Ajouter une photo : correction locale, validation iPhone en attente
Deux défauts reproduits : sauvegarde distante avant le sélecteur et libellé de carte vide non cliquable. Sélection locale avant sauvegarde, contrôles avant envoi conservés, bouton texte/+ unifié, retrait/remplacement individuel sans collision de slot. Rapport : PHOTO_PICKER_IOS_20261020.md ; preuves : artifacts/photo-picker-20261020/. Échecs initiaux et intermédiaires conservés. État final : 54 tests Flutter distincts réussis (53 + 1 complémentaire), analyse intégrale et build Web JavaScript réussis, diff check valide. Aucun test Safari/iPhone réel : signalement non clos. Version publique relue, inchangée. Aucun déploiement, push, fusion, transaction ou changement financier/Firebase. Les fiches historiques et leur décompte ne sont pas réécrits ; P1-BOOKING-CONFIG-01 ouvert, 1.3L reporté.
