# MOVI-K — QC26-V2 — Fixture GPS et analyse Flutter
Date : 14 octobre 2026, fuseau du Québec

## Verdict
**DEUX BLOCAGES DE QUALIFICATION CORRIGÉS ET TESTÉS LOCALEMENT.**
**NO-GO DE PROMOTION / PAIEMENTS RÉELS** : une autre anomalie financière de concurrence a été reproduite en émulateur ; les 20 échecs antérieurs des tests Flutter/GPS réseau, Node20 réel et la recette navigateur restent hors de ce lot.

## Git, périmètre, sécurité
- Dépôt : Solexiai/mecano-mobile.
- Worktree : C:\Users\Utilisateur\movik-gps-history-fix-20261009.
- Branche : fix/gps-client-history-scope-20261009.
- HEAD initial : e84a1c02ff911c4ce413d9e49e510a9c0eb2c89a.
- Branche release contrôlée séparément, non modifiée.
- Aucun push, fusion, déploiement, modification de tarifs, commissions, Stripe, snapshots, ledger, sécurité serveur ou production.
- Correction limitée à `functions/test/integration/loadMvpBlocT.test.ts`, `analysis_options.yaml`, déclencheur PR de `.github/workflows/flutter-validation.yml`, registre et checkpoint.

## Blocage 1 : fixture tracking / rôle chauffeur
Cause antérieure : `trackingRequest` de `loadMvpBlocT.test.ts` insérait un token vide pour `recordTrackingPoint`, fonction exigeant le claim driver. Le test T-3 échouait sur `permission-denied` ; aucun produit défectueux n'était prouvé.
- **Avant** : exécution T-3 sur émulateurs Firestore/Auth avec projet demo-movik-test : 1 échoué, 3 autres tests exclus du filtre.
- **Après** : la seule fixture tracking porte `role: "driver"` et `roles: ["driver"]`. Les fixtures client et autres activités de paiement restent inchangées.
- Un test négatif permanent a été ajouté : même requête avec token sans rôle -> `permission-denied`, sans écritures GPS.
- **Après ciblé : 2 tests réussis**, 3 exclus par filtre.
- **Après suite complète loadMvpBlocT : 5 tests réussis sur 5**, sans argent réel.
- Aucune modification de `recordTrackingPoint`, aucun assouplissement de permissions.

## Blocage 2 : analyse Flutter globale
Cause antérieure : `flutter analyze --no-pub` à la racine échouait avec 133 diagnostics liés surtout à des copies historiques de harnais Dart sous `artifacts/**`. Ces fichiers sont des preuves non destinées à l'analyse du code actif.
- Ajout de `artifacts/**` aux exclusions de `analysis_options.yaml`, sans déplacer, supprimer ou retoucher les archives.
- `lib/**` et `test/**` demeurent entièrement analysés.
- **Après : `flutter --no-version-check analyze --no-pub` à la racine, code 0, `No issues found`.**
- Le déclencheur pull_request du workflow Flutter tient maintenant compte d'un changement à `analysis_options.yaml`. YAML relu via le module local js-yaml ; analyse_options est bien inclus dans paths.
- Le workflow distant GitHub Actions n'a PAS été déclenché : aucun push ni pull request. La réussite CI Cloud ne peut être inférée du seul test local.

## Nouvelle anomalie P1-WEBHOOK-01 identifiée par non-régression
L'exécution complète Firebase a révélé une autre anomalie, sans lien causal démontré avec la fixture T-3 :
- **49 suites réussies / 1 suite en échec** ; **730 tests réussis / 1 test échoué**, sur 50 suites et 731 tests au total.
- `processStripeWebhook.test.ts` : le scénario `WEBHOOK DUPLIQUÉ CONCURRENT` attend une réponse initiale et une réponse `alreadyProcessed`. Deux réponses considérées initiales ont été observées (`freshCount=2` au lieu de 1).
- Le cas a été réexécuté **seul** sur les émulateurs : même résultat `Expected: 1; Received: 2` (1 échec, 27 tests exclus).
- Les assertions d'audit réel, `attempt_count` et d'effet financier sont en aval de cette première assertion et n'ont PAS été atteintes. **Aucune double capture, ni double ledger, ni incident Stripe production ne sont démontrés**. L'anomalie est qualifiée P1 provisoire pour son risque financier et requiert une analyse spécifique du contrat d'idempotence.
- Aucun fichier financier ou provider n'a été modifié. Enregistrement distinct `P1-WEBHOOK-01` ouvert dans le registre.

## Conclusions et suites
- QC26-V2 confirme que les deux corrections demandées sont validées dans leur périmètre local.
- Le registre passe des 27 fiches historiques fermées à **28 fiches (27 historiques fermées + P1-WEBHOOK-01 ouverte)** ; P0 0 / P1 1 / P2 0. Les P3 et prérequis demeurent.
- Le lancement reste NO-GO à cause du P1 webhook, des 20 tests Flutter/GPS réseau du bilan QC26, du test GPS 1.3L reporté et des validations navigateur, Node20, Stripe Sandbox et Firebase réellement déployé manquantes.
- Une intervention FINANCIÈRE DISTINCTE doit être autorisée avant correction de `processStripeWebhook` ou d'autres règles financières. Ne pas modifier le contrat ou supprimer l'assertion du test simplement pour obtenir une suite verte.

## Preuves locales
Les journaux du lot sont dans `artifacts/qc26-fixture-and-analyzer-20261014/` :
`baseline-t3.log`, `after-t3.log`, `after-load-full.log`, `analyzer-after.log`, `after-integration-full.log`, `webhook-isolated.log`, scripts `run-*.cmd` et copies .before.txt.
Tous les tests sont restés sur le projet fictif demo-movik-test et les émulateurs localhost. Node local 24 (Node20 déclaré, pas encore certifié).

**Aucun GO GitHub, Vercel, Firebase Production ou paiements en argent réel.**
