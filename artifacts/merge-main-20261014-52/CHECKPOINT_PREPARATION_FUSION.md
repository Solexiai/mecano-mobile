# Movi-K ? preparation de fusion GitHub ? 2026-10-14

PR: https://github.com/Solexiai/mecano-mobile/pull/52

## Etat initial

Branche fix/gps-client-history-scope-20261009, HEAD 00097449c1ce10a82347519525079e06f18d769e. Main distant 6401cb2a9386b6eb8562d2fe585eb21a376dca1e, ancetre du HEAD (39 commits). Index et fichiers suivis propres. 3359 fichiers non suivis preserves.

## CI avant fusion

Flutter run 38609096196: analyse et build Web reussis, 1036 controles reussis / 18 echecs. Quinze echecs: fixtures de dates exigeant explicitement un runner Eastern, alors que GitHub execute en UTC. Trois echecs setUpAll: Roboto absent du cache SDK vierge. Les anciens resultats locaux restent historiques, pas une preuve Linux.

Firebase run 38609096387: 228 tests unitaires (15 suites) et 734 integrations en emulateurs demo (50 suites) reussis. Lint et compilation reussis.

## Correction de l'environnement de test

TZ=America/Toronto est limite a l'etape Flutter du runner Linux. Les quatre polices Roboto locales deja utilisees par les audits sont conservees sous test/fixtures/fonts avec leur licence originale et leurs empreintes dans CI_REPRODUCTION.json. Le chargeur commun est reutilise par les tests Marketplace. Aucune assertion supprimee, aucun skip, aucun changement produit/financier/Firebase.

## Executions locales distinctes

Premiere execution des cinq suites: 84 reussis, 15 echecs, 0 ignore. Une variable TZ IANA avait ete appliquee a tort au processus Windows; le runtime affichait UTC. Ce resultat est conserve. Aucun parametre Windows n'a ete modifie.

Seconde execution confirmation, TZ absent et fuseau Windows Eastern Standard Time: 54 reussis, 0 echec, 0 ignore. Les trois suites publiques et les tests de frontiere temporelle reussissaient deja dans la premiere execution.

Analyse ciblee reussie. Dart format: 0 fichier a reformater. git diff --check du correctif: reussi. Les journaux complets restent locaux; aucune sauvegarde privee n'est ajoutee.

## Limites et suite

Validation complete GitHub Linux du nouveau commit encore requise avant fusion. Aucun nouveau test Stripe ou operation metier. Le push main declenchera Vercel; aucun workflow ne deploie Firebase. Les ventes restent desactivees et les configurations de lancement manquantes ne sont pas inventees. 1.3L reste bloque/reporte.
