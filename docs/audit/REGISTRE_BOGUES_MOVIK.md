# REGISTRE MAÎTRE DES BOGUES MOVI-K

Date de consolidation : 9 octobre 2026, America/Toronto. Étape 1.3M-B. Dernière mise à jour : clôture documentaire R-K-03-B, 9 octobre 2026.
Branche : fix/gps-client-history-scope-20261009 ; base 77c3c61534d1300ddc0eab5585f78b9662a69537.

## Règle permanente

IDENTIFIÉ → QUALIFIÉ → CORRECTION CODÉE → TESTÉ → VALIDÉ → FERMÉ.
Une correction non testée reste CORRIGÉ — NON VALIDÉ. BLOQUÉ/REPORTÉ est un état complémentaire, jamais une fermeture. Chaque transition exige date, version, commande, résultat et preuve. Toute fermeture exige correction présente, analyse réussie, non-régression pertinente, permissions/intégration si nécessaire, preuve et parcours existants préservés. Fermeture ciblée P1-M-01 approuvée le 9 octobre 2026 à l'étape 1.3M-D ; fermeture ciblée R-K-03-A approuvée explicitement par Daniel le 9 octobre 2026 à l'étape 1.3M-H. Fermeture ciblée R-K-03-B approuvée explicitement le 9 octobre 2026, limitée aux défauts d’atomicité et de nettoyage GPS validés en émulateur, non déployée ; R-K-03-C reste ouvert.

## Périmètre et décompte

Anomalies actives non fermées issues de Phase1 et dettes reportées : **P0 0, P1 3, P2 21** (recalcul après fermeture documentaire ciblée de R-K-03-B, 9 octobre 2026). P1-M-01, R-K-03-A et R-K-03-B sont conservés avec leurs fermetures limitées ; 27 entrées au total, dont 24 non fermées. Cela inclut 2 P1 et 1 P2 déjà validés visuellement historiquement mais non fermés selon la nouvelle règle. R-K-03-C reste ouvert en P1 ; A et B sont fermés exclusivement dans leurs périmètres locaux/émulateur validés, non déployés. La fermeture limitée de B a été approuvée après la validation H des compensations tardives ; C demeure un risque provisoire à qualifier. Les trois P1 ouverts sont R-K-03-C, P1-HOME-001 et P1-COPY-001. Aucun incident réel de production démontré. Les gaps de couverture/décision sont inclus en P2 et explicitement distingués des bugs.
Les correctifs historiques Phase7 importés en annexe conservent leur état rapporté : ils ne sont ni nouvellement fermés ni arbitrairement réouverts. Leur correspondance actuelle/test de fermeture doit être réconciliée avant annoncer P0/P1=0 global. BUG-004 P0 historique est rapporté corrigé/testé ; aucun P0 actif nouvellement confirmé. Pas de garantie d'exhaustivité des conversations/fichiers inaccessibles ou de production.

Alias : R-K-02 = P1-M-01 ; R-K-03 parent des sous-cas A/B/C (pas quatrième compteur) ; P2-G-01 observation simulée reliée à P2-FORM-001 (pas doublon du compte), contexte Material du harnais distinct de Chrome. Les deux listes sans limit restent un seul GAP-M-06. BUG-003 conserve ses occurrences client/chauffeur/mécanicien. Les identifiants de scénarios sans bug ne deviennent pas des anomalies.

## Tableau de suivi

| ID | Priorité | Nature | Statut | Problème |
|---|---|---|---|---|
| P1-M-01 | P1 | Bug de requête, correctif testé | FERMÉ — PÉRIMÈTRE SIMULÉ VALIDÉ — NON DÉPLOYÉ | Historique GPS sans filtre serveur de mission ; refus attendu pour client ordinaire. |
| R-K-03-A | P1 | Défauts corrigés et testés en émulateur | FERMÉ — PÉRIMÈTRE LOCAL/ÉMULATEUR VALIDÉ — NON DÉPLOYÉ | Autorité GPS et refus missions terminales/profils non approuvés uniquement ; fermeture approuvée en H. |
| R-K-03-B | P1 | Défauts d’atomicité et de nettoyage GPS corrigés et testés localement | FERMÉ — PÉRIMÈTRE LOCAL/ÉMULATEUR VALIDÉ — NON DÉPLOYÉ | Rapport GPS, fin/compensation/nettoyage tardif de A ne libèrent plus l’assignation B dans les scénarios locaux validés. |
| R-K-03-C | P1 | Risque provisoire ; contrôles absents | QUALIFIÉ | Marqueur sans contrôle driverId/activeDeliveryId/date ; date invalide remplacée par maintenant ; coordonnées anciennes après assignation. |
| P2-H-01 | P2 | Bug simulé confirmé | QUALIFIÉ | Téléphone -------- accepté par Flutter ; serveur normalizeContacts exige au moins huit chiffres. |
| P2-H-02 | P2 | Bug UX confirmé | QUALIFIÉ | Compteur /120 incohérent avec regex 8–25 caractères ; obligations peu explicites. |
| P2-I-01 | P2 | Bug simulé confirmé | QUALIFIÉ | Carte annoncée enregistrée alors que cardReady=false. |
| P2-I-02 | P2 | Bug simulé confirmé | QUALIFIÉ | Date détaillée en format technique dans confirmation. |
| P2-J-01 | P2 | Bug simulé confirmé | QUALIFIÉ | Suivi en recherche sans référence ni statut métier explicitement affichés. |
| P2-K-01 | P2 | Lacune statique | QUALIFIÉ | Flux position/historique sans hasError, refus pouvant paraître absence signal/trajet. |
| R-K-04 | P2 | Risque visuel provisoire | QUALIFIÉ | Centre de repli Montréal sans position/adresse ; pas de faux marqueur démontré. |
| P2-FORM-001 | P2 | Bug visuel historique | QUALIFIÉ | Sélecteurs date/heure et date résumée anglais sur /fr. |
| P2-FORM-002 | P2 | Bug visuel historique | QUALIFIÉ | Libellé Unité de poids tronqué, largeur fixe 120. |
| P2-FORM-003 | P2 | Bug historique / besoin produit | QUALIFIÉ | Adresse saisie non résolue perdue après refresh ; objet conservé. |
| P2-FORM-004 | P2 | Bug visuel historique | QUALIFIÉ | 190 cm convertis affichés 74.803149606… in. |
| P2-G-02 | P2 | Bug de présentation simulé | QUALIFIÉ | Format monétaire/distance non localisé FR : décimales point, suffixe CAD, 10.0 km. |
| P2-I18N-001 | P2 | Signal historique | IDENTIFIÉ | Illustration hero_clean en français sur EN/ES. |
| P2-I18N-002 | P2 | Bug visuel historique | QUALIFIÉ | Infobulle Open navigation menu anglais sur /fr. |
| P2-BUILD-001 | P2 | Avertissement build | QUALIFIÉ | CupertinoIcons attendu mais non inclus ; icône manquante pas démontrée. |
| P1-HOME-001 | P1 | Bug ancien branche septembre | VALIDÉ — HISTORIQUE, NON FERMÉ | Chevauchement hero desktop corrigé structurellement et non reproduit release trois formats. |
| P1-COPY-001 | P1 | Bug ancien branche septembre/main | VALIDÉ — HISTORIQUE, NON FERMÉ | Anciennes promesses couverture/créneau retirées accueil release. |
| P2-COPY-001 | P2 | Bug ancien | VALIDÉ — HISTORIQUE, NON FERMÉ | Leboncoin absent accueil release observé ; anciennement présent. |
| P2-L-01 | P2 | Dette historique (nouvel ID permanent) | QUALIFIÉ | Contraste texte de badges warning faible ; distinct BUG-L6-01 GPS déjà corrigé. |
| GAP-M-05 | P2 | Dette historique | QUALIFIÉ | State des onglets provider détruit/recréé par tabs[index]. |
| GAP-M-06 | P2 | Risque coût historique | QUALIFIÉ | watchNotifications/watchDriversByStatus sans limit. |
| GAP-S-02 | P2 | Couverture manquante | QUALIFIÉ | Pas de test ciblé annulation/acceptation simultanées. |
| GAP-S-04 | P2 | Décision produit / risque | QUALIFIÉ | Chauffeur suspendu en mission peut progresser completePickup/Delivery. |

## Fiches actives

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
