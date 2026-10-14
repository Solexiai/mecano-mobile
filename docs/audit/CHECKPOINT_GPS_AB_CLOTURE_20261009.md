# Movi-K — Checkpoint GPS A/B et fermeture documentaire — 9 octobre 2026

## Périmètre et source de vérité

- Dépôt : `Solexiai/mecano-mobile`, branche `fix/gps-client-history-scope-20261009`.
- Point de départ : commit `75ce4393d94c6fb12ecffcc95a4976b93b826b3e` (correctif P1-M-01).
- Registre unique : `docs/audit/REGISTRE_BOGUES_MOVIK.md`.
- Décision approuvée : R-K-03-A et R-K-03-B fermés **uniquement dans le périmètre local/émulateur validé — non déployés**. P1-M-01 était déjà fermé dans son périmètre simulé.

## Corrections enregistrées dans cette sauvegarde

- `firestore.rules` : écriture GPS directe refusée ; lecture de position client conditionnée à une mission réellement active.
- `recordTrackingPoint.ts` : rôle chauffeur, statut approuvé et mission active ; rapport/position/géohash/historique transactionnels, sans restaurer un ancien lien.
- `onMissionEndedClearTracking.ts`, `completeDelivery.ts` : nettoyage conditionnel atomique préservant une nouvelle mission B.
- `paymentOrchestration.ts` : lors de l'échec tardif du paiement A, la libération GPS et la disponibilité ne modifient pas B ; transactions et effets financiers de A préservés dans les tests locaux.
- Tests permanents correspondants intégrés aux chemins `functions/test/integration/` ; code financier/tarifaire général, commissions, snapshots, ledger et index inchangés sauf le correctif ciblé ci-dessus.

## Preuves historiques (ne pas additionner entre exécutions)

- 1.3M-E : 64 réussites / 10 échecs après les premières protections GPS.
- 1.3M-F : 126 contrôles ciblés réussis / 0 échec après transactionnalisation.
- 1.3M-G : 26 réussites / 2 échecs ; mise en évidence du défaut résiduel `failMissionPayment()`.
- 1.3M-H : **75 contrôles ciblés réussis / 0 échec** après correction de compensation, dont neuf cas permanents ; TypeScript, lint ciblé et diff check réussis.
- Rapport H archivé : `artifacts/corrections-1-3M-H-20261009-c871eb62/CHECKPOINT_MOVIK_1_3M_H_GPS_COMPENSATION_TARDIVE.md`.
- Preuves brutes et résultats JSON supplémentaires préservés sur le disque dans les dossiers E/F/G/H ; non inclus systématiquement au commit.

## Statut et limites

Le registre a **27 fiches, dont 3 fermées dans leur périmètre limité ; P0 ouverts 0, P1 ouverts 3, P2 ouverts 21**. Les P1 restants sont R-K-03-C, P1-HOME-001, P1-COPY-001. P2, P3 historiques et prérequis du pilote préservés.

Les validations locales n'établissent **ni le fonctionnement Firebase déployé, ni Node 20, ni les notifications automatiques de triggers, ni Stripe Sandbox/LIVE, ni le GPS réel**. Test de tuiles 1.3L toujours bloqué/reporté. R-K-03-C (provenance et fraîcheur des positions) reste ouvert. **NO-GO pour lancement public** jusqu'aux validations opérationnelles et externes.

Cette sauvegarde n'autorise **aucun push, merge, déploiement ou action de production**.
