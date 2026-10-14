# CHECKPOINT MOVI-K — 1.3M-H — GPS / COMPENSATION TARDIVE

**Date : 9 octobre 2026, America/Toronto. Statut de l'étape : TERMINÉ.**

**R-K-03-A est fermé selon l'autorisation reçue, exclusivement dans son périmètre local/émulateur validé, non déployé. R-K-03-B est corrigé et validé dans le périmètre local testé ; sa fermeture limitée est recommandée mais NON APPLIQUÉE.**

Après correction : **75 tests sélectionnés réussis, 0 échec**. Aucun commit, push, merge, déploiement ou changement de production.

## 1. État Git et reprise

- Dépôt : Solexiai/mecano-mobile.
- Worktree : `C:\Users\Utilisateur\movik-gps-history-fix-20261009`.
- Branche avant/après : `fix/gps-client-history-scope-20261009`.
- HEAD avant/après : `75ce4393d94c6fb12ecffcc95a4976b93b826b3e`.
- Index avant/après : vide ; aucun staging.
- Reprise : checkpoint G, registre courant, correctifs et tests directement concernés. Pas de nouvel audit général.
- **1 178 fichiers préexistants recensés conservés**, aucun supprimé. Seul le registre change parmi ces fichiers déjà modifiés/non suivis. Le module de paiement, initialement non modifié, reçoit le correctif autorisé ; un nouveau test est ajouté.
- Les **32 sources des preuves F sont inchangées**. Les anciens tests/pertes/échecs et rapports G restent conservés.
- Aucun autre worktree modifié ; les dépendances déjà installées dans le worktree release sont lues seulement.

Fichiers suivis modifiés à la fin :

```text
 M docs/audit/REGISTRE_BOGUES_MOVIK.md
 M firestore.rules
 M functions/src/functions/completeDelivery.ts
 M functions/src/functions/onMissionEndedClearTracking.ts
 M functions/src/functions/recordTrackingPoint.ts
 M functions/src/payment/paymentOrchestration.ts
 M functions/test/integration/recordTrackingPoint.test.ts
 M functions/test/integration/securityRules.test.ts
```

Les quatre tests E/F non suivis restent présents. Nouveau test non suivi : `functions/test/integration/gpsPaymentCompensation.test.ts`. Les autres preuves non suivies sont préservées. Détail complet : git-initial.json et git-final.json ; comparaison compacte : verification-final.json.

## 2. Fermeture ciblée de R-K-03-A

Statut désormais inscrit dans le registre :

**FERMÉ — PÉRIMÈTRE LOCAL/ÉMULATEUR VALIDÉ — NON DÉPLOYÉ.**

Autorisation explicite de Daniel dans la mission H. Périmètre : autorité des écritures GPS et refus démontrés pour missions terminales ou profils non approuvés. Les 26 gardes serveur réussissent à nouveau dans cette intervention.

Les validations Firebase déployé, transport Auth/callable réel, GPS physique et Node 20 restent absentes. Cette fermeture ne concerne ni B, ni C, ni l'ensemble du système GPS. Statuts antérieurs et preuves F/G conservés.

## 3. Cause et correctif R-K-03-B

L'ancienne transaction de `failMissionPayment()` lisait la mission et le paiement, puis effaçait le lien GPS et remettait le chauffeur disponible sans vérifier à quelle mission appartenait désormais ce lien.

Une autorisation fictive de A pouvait donc échouer après l'assignation réussie de B : B restait assignée tandis que son lien était effacé et son chauffeur redevenait disponible. Les deux reproductions G, assignation initiale chauffeur et administrateur, ont été reprises sans affaiblissement dans le nouveau test permanent.

**Modification produit unique en H :** `functions/src/payment/paymentOrchestration.ts`, dans `failMissionPayment()`, lignes 461–496 après correction.

- Lire le document `driver_locations/{driverId}` dans la transaction, avant toute écriture.
- Déterminer si `active_delivery_id` est absent/null ou égal à A.
- Libérer le GPS et la disponibilité uniquement dans ce cas.
- Préserver B et la disponibilité lorsque B est le lien actif.
- En cas de changement concurrent du document lu, la transaction reprend et réévalue le lien.

Diff produit : **9 lignes ajoutées, 2 retirées**, dont commentaires ; aucun déplacement de bloc financier.

```typescript
const driverLocationRef = driverId ? db.collection("driver_locations").doc(driverId) : null;
const driverLocation = driverLocationRef ? await tx.get(driverLocationRef) : null;
const activeDeliveryId = driverLocation?.get("active_delivery_id") ?? null;
const releasesDriver = activeDeliveryId === null || activeDeliveryId === missionId;

// Après les écritures financières existantes, inchangées :
if (driverId && driverLocationRef && releasesDriver) {
  const driverRef = db.collection("driver_profiles").doc(driverId);
  tx.update(driverRef, { online_status: "online" });
  tx.set(driverLocationRef, { active_delivery_id: null }, { merge: true });
}
```

Fichiers créés/modifiés par H, hors preuves :

| Fichier | Intervention |
|---|---|
| functions/src/payment/paymentOrchestration.ts | Garde transactionnelle GPS/disponibilité uniquement |
| functions/test/integration/gpsPaymentCompensation.test.ts | Nouveau test permanent : 2 reproductions G + 7 cas ciblés |
| docs/audit/REGISTRE_BOGUES_MOVIK.md | Fermeture A approuvée ; validation B proposée ; historique et compte conservés |

Les correctifs préexistants des autres fonctions et des règles Firestore ne sont pas modifiés par H.

## 4. Tests avant/après

| Exécution | Réussis | Échoués | Exclus par sélection |
|---|---:|---:|---:|
| Nouveau test de compensation AVANT correctif | 4 | 5 | 0 |
| Sélection élargie APRÈS correctif | 73 | 0 | 200 |
| Complément de deux contrôles de concurrence | 2 | 0 | 271 |

**Bilan après correction : 75 cas distincts exécutés, 75 réussis, 0 échec.** Les cinq échecs initiaux restent dans results-before.json et tests-before.log ; ils ne deviennent pas des réussites historiques.

Les deux erreurs G reproduites avant correction étaient :

```text
Expected: "g_gps_B"
Received: null
gpsPaymentCompensation.test.ts:105:42
```

Les trois autres échecs avant correction étaient le contrôle `sawActiveRead` attendu true et observé false dans les reprises transactionnelles. Il ne s'agit pas de cinq nouveaux bogues indépendants. En particulier, la reprise sans B avait une issue fonctionnelle normale mais ne lisait pas encore le lien dans la transaction.

Deux contrôles de chevauchement de G n'avaient pas été sélectionnés par le premier filtre ; le complément ASCII `1.3M-G.*rapport` les a exécutés séparément. Aucun test ni assertion modifié pour obtenir un succès, aucun skip ajouté. Parmi les entrées chargées, 198 restent non exécutées après les deux sélections : 196 règles hors périmètre et 2 copies temporaires G des reproductions désormais exécutées dans le test permanent. Ces entrées ne sont pas annoncées réussies.

### Neuf scénarios du nouveau test permanent

| Cas | Après correctif |
|---|---|
| A assignée par chauffeur, B ensuite, échec tardif A | Réussi : lien B et on_mission conservés |
| A assignée par administrateur, B ensuite, échec tardif A | Réussi : même résultat |
| Échec normal A, lien toujours A | Réussi : libération conforme |
| Échec normal A, lien null | Réussi : comportement existant conservé |
| Échec normal A, document GPS absent | Réussi : comportement existant conservé |
| Reprise transactionnelle A via chauffeur après assignation B | Réussi : relecture du lien, B intacte |
| Reprise transactionnelle A via administrateur après B | Réussi : même résultat |
| Reprise transactionnelle sans B | Réussi : un seul événement/effet committé |
| B appartient à un autre chauffeur | Réussi : mission B, position et disponibilité de cet autre chauffeur inchangées |

Les corps des deux tests rouges G sont conservés textuellement dans la nouvelle suite ; contrôle automatique `originalGTestBodiesPreserved: true`.

Les tests de reprise injectent ABORTED après un premier callback annulé ; la mutation concurrente est réellement committée avant la reprise SDK et l'état final de Firestore Emulator est vérifié. Ce mécanisme est documenté ; il ne prouve pas à lui seul toutes les courses spontanées d'un service cloud. Les essais G de chevauchement sans ABORTED injecté complètent cette couverture.

## 5. Non-régressions exécutées

| Suite/périmètre | Réussites |
|---|---:|
| gpsPaymentCompensation — nouveau | 9 |
| recordTrackingGuards — profils et états GPS A/B | 26 |
| gpsTrackingAtomicity — courses et effets de bord F | 14 |
| acceptDeliveryConcurrency | 11 |
| acceptDeliveryPaymentFailure | 3 |
| missionCancellationPaymentRelease | 3 |
| securityRules — deux cas ciblés, dont P1-M-01 | 2 |
| Interactions G restantes, incluant les deux compléments | 7 |
| **Total après correction** | **75** |

P1-M-01 : la requête de collection d'historique filtrée par mission est exécutée ; ce n'est pas seulement un getDoc. La règle interdisant l'auto-assignation directe du chauffeur est également exécutée.

Les sept interactions G couvrent les assignations standards chauffeur/admin jusqu'à la terminaison et capture fictive, l'annulation A puis B et rejeu de l'événement A, la suspension/terminaison pendant le rapport, et les nettoyages concurrents à l'assignation B.

Les quatorze tests d'atomicité F conservent leurs doublures d'orchestration explicites. Ils ne valident pas à eux seuls le module financier modifié ; les neuf nouveaux cas et les suites financières/G utilisent la vraie orchestration locale avec FakePaymentProvider.

## 6. Effets financiers conservés

Deux niveaux de preuve :

1. **Code :** après retrait des seules insertions/conditions GPS autorisées, le module reconstitué est identique à sa sauvegarde avant correction. Le changement est limité au bloc privé failMissionPayment ; les autres fonctions, transitions financières, événements et règles d'idempotence sont inchangés. Preuve : patch-scope.json et payment-fix.patch.
2. **Tests :** snapshot A comparé avant/après, paiement unique et événement payment_failed unique, ledger vide dans ces cas d'échec, montants demandés fictifs concordants avec la mission, compte des appels au fournisseur, refus d'une deuxième acceptation et absence de nouvelle écriture GPS/disponibilité. Après reprise, les appels fictifs de création/autorisation ne se répètent pas ; aucune capture, annulation ou demande de remboursement n'est ajoutée dans ces scénarios.

Les tests existants de capture fictive, annulation, libération et idempotence réussissent. Aucun tarif, commission, montant, taxe, snapshot, capture Stripe, remboursement ou ledger de production modifié.

**Ces preuves ne valident pas Stripe Sandbox/LIVE ni la concordance financière en production.** Tous les documents et appels de paiement sont fictifs dans l'émulateur.

## 7. TypeScript, lint et intégrité du diff

- Node exécuté : **24.15.0** ; Node 20 reste **NON TESTÉ**. Aucune installation, inventaire G non recommencé.
- TypeScript **5.9.3** : compilation complète des **87 sources produit**, **174 fichiers JS/maps émis exclusivement dans les preuves**, **0 diagnostic**.
- Typecheck de **11 suites** pertinentes, incluant le nouveau test : **0 diagnostic avant et après**.
- ESLint : paymentOrchestration, recordTrackingPoint, completeDelivery, onMissionEndedClearTracking : **0 erreur, 0 avertissement**. Pas de lint global annoncé.
- `git diff --check` : **0**, sortie vide.
- Source du nouveau test identique entre les exécutions avant/après ; seule source commune modifiée : paymentOrchestration.ts.
- Empreintes des sources exécutées après correction toujours identiques aux fichiers finaux.

## 8. Isolation et incidents d'environnement

- Firestore Emulator local, projet fictif **demo-movik-test**, adresse **127.0.0.1:8080**, mode mono-projet strict.
- Aucun émulateur Functions/Auth/Storage démarré. Appels directs .run() et identités fictives ; contextes locaux de règles pour securityRules.
- FakePaymentProvider existant ; vraie implémentation Stripe exclue de la copie exécutée et remplacée par un constructeur qui refuse l'utilisation.
- Routes simulé par setupRouteMock existant. Aucun navigateur, carte, GPS physique ou notification réelle.
- Garde Node chargée avant Jest : uniquement sockets loopback:8080, DNS externe et processus enfants refusés. **Quatre sondes d'isolation réussies**, distinctes des 75 tests métier.
- Les tentatives de détection metadata Google et de processus enfant consignées sont **bloquées** ; elles ne sont pas des connexions réussies. Aucune connexion externe autorisée par la garde.
- Ce confinement applicatif du graphe inspecté n'est pas un pare-feu général de l'OS et ne valide pas le test de tuiles 1.3L.
- Paramètres runtime de quotas 60/60, identiques aux valeurs par défaut du code, définis uniquement pour le processus de test ; aucune configuration cloud ou Windows modifiée.

Deux lancements Java initiaux n'ont pas tenu. Les prévalidations ont refusé de lancer Jest lorsque le PID/port n'était pas confirmé : **aucun test exécuté à ces tentatives**. La cause exacte de ces arrêts n'est pas établie. Le lancement direct suivant a maintenu l'émulateur disponible avec les mêmes paramètres d'isolation.

Émulateur utilisé : **PID 23904**, parent 29728, identité vérifiée. Il a été arrêté par H après les tests, sans arrêter de service préexistant. Les tentatives initiales et les journaux sont conservés, pas réinterprétés comme des bogues Movi-K.

## 9. Statut proposé de R-K-03-B

| Critère | Résultat |
|---|---|
| Correctif effectivement présent | Oui |
| Deux échecs G reproduits puis corrigés | Oui, 2/2 réussis après correctif |
| Cas normaux et lien absent conservés | Oui, 3/3 |
| Nouvelle assignation protégée après reprise | Oui, chauffeur/admin |
| Aucun effet répété dans les scénarios testés | Oui, compte des appels et documents committés |
| Autre chauffeur préservé | Oui |
| Gardes GPS A et P1-M-01 | Non-régressions ciblées réussies |
| Effets financiers conservés | Comparaison de code et tests locaux réussis |
| Preuves conservées et sources finales identiques | Oui |
| Transport Firebase/cloud/Node 20/terrain | Non validés, hors fermeture locale proposée |
| Approbation de fermeture B | **Non reçue ; aucune fermeture appliquée** |

**Statut enregistré : VALIDÉ LOCALEMENT — NON FERMÉ — NON DÉPLOYÉ.**

**Fermeture documentaire limitée recommandée** pour les défauts d'atomicité et de nettoyage GPS qualifiés A/B dans le périmètre local/émulateur testé, incluant désormais la compensation tardive. Aucun défaut résiduel n'est démontré dans ces scénarios. Cette recommandation ne constitue pas une garantie universelle de concurrence ni une validation du GPS complet.

## 10. Registre et décompte

Registre unique : `docs/audit/REGISTRE_BOGUES_MOVIK.md`.

**P0 : 0 — P1 : 4 — P2 : 21.**

27 entrées conservées, 25 ouvertes. Fermetures limitées : P1-M-01 et R-K-03-A. P1 ouverts : R-K-03-B, R-K-03-C, P1-HOME-001, P1-COPY-001. Tous les P2/P3 historiques et prérequis du pilote restent présents.

R-K-03-C, P2-K-01, GAP-S-04 et le test de tuiles 1.3L ne sont ni corrigés ni fermés par cette étape. 1.3L reste BLOQUÉ ET REPORTÉ. Les totaux F/G antérieurs ne sont pas réécrits.

## 11. Fichiers proposés pour une future sauvegarde Git

Liste produit/tests/registre exacte, comprenant le travail E/F/G préservé et H :

1. docs/audit/REGISTRE_BOGUES_MOVIK.md
2. firestore.rules
3. functions/src/functions/recordTrackingPoint.ts
4. functions/src/functions/onMissionEndedClearTracking.ts
5. functions/src/functions/completeDelivery.ts
6. functions/src/payment/paymentOrchestration.ts
7. functions/test/integration/recordTrackingPoint.test.ts
8. functions/test/integration/securityRules.test.ts
9. functions/test/integration/gpsAuthorityRules.test.ts
10. functions/test/integration/recordTrackingAuthority.test.ts
11. functions/test/integration/recordTrackingGuards.test.ts
12. functions/test/integration/gpsTrackingAtomicity.test.ts
13. functions/test/integration/gpsPaymentCompensation.test.ts

La liste exhaustive des preuves sélectionnées, avec tailles et SHA256, figure dans **MANIFESTE_COMMIT_1_3M_H.json**. Le manifeste G reste historique ; utiliser celui de H pour une éventuelle sauvegarde future.

Exclus : caches, node_modules, copies compiled-*, typescript-build, journaux volumineux, fichiers personnels et autres preuves non sélectionnées. Aucune preuve n'est supprimée. Aucun secret ajouté. Aucun git add ou commit effectué.

## 12. Commandes, preuves et prochaine action

Commandes de validation principales réellement exécutées depuis ce dossier de preuves :

```powershell
node verify-typescript.cjs before
node prepare-tests.cjs before
node -r ./deny-external-node.cjs ./guard-probe.cjs
# Après les prévalidations refusées des deux premiers lancements :
& ./start-emulator-v3.ps1
& ./run-tests-v3.ps1 before
node apply-targeted-fix.cjs
node prepare-tests.cjs after
& ./run-tests-v3.ps1 after
node verify-typescript.cjs after
node lint.cjs
& ./run-complement.ps1 complement
git -c core.safecrlf=false diff --check
```

Les scripts refusent certains écrasements : ne pas les relancer aveuglément. Les sorties exactes se trouvent dans results-before/after/complement.json, tests-*.log et RESULTATS_1_3M_H_FINAL.json. États Firestore fictifs : states-*.jsonl. Environnement et réseau : emulator-*.json/log, network-*.jsonl, preflight-initial.txt. Contrôle final : verification-final.json.

Dossier canonique : `C:\Users\Utilisateur\movik-gps-history-fix-20261009\artifacts\corrections-1-3M-H-20261009-c871eb62`.

**Prochaine action unique : obtenir l'approbation de Daniel pour fermer documentairement R-K-03-B dans ce périmètre local/émulateur validé, non déployé.**

Toute sauvegarde Git nécessitera aussi une autorisation distincte. Arrêt après ce checkpoint ; aucune autre correction ni étape commencée.
