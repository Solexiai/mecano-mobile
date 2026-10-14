# MOVI-K — SEC-GAP-S04 — Protection de suspension_mode
Date : 14 octobre 2026 (Québec)

## Verdict
**DÉFAUT DE RÈGLE FIRESTORE REPRODUIT AVANT, CORRIGÉ ET VALIDÉ EN ÉMULATEUR APRÈS — NON DÉPLOYÉ.**

## Dépôt et autorisation
Dépôt : Solexiai/mecano-mobile.
Worktree : C:\Users\Utilisateur\movik-gps-history-fix-20261009.
Branche : fix/gps-client-history-scope-20261009.
HEAD initial : 468b630dcad1a7dc95677b92ba46c0edbb6cf66a.
Autorisation reçue pour correction locale et émulateurs, avec commit local après validation.
Aucun push GitHub, merge ou déploiement Firebase Production.

## Défaut initial — preuve
La qualification QC26 avait démontré, par l'émulateur Firestore et un chauffeur fictif avec claim driver, que `driver_profiles/{uid}.suspension_mode` pouvait être modifié directement de `urgent` vers `ordinary`. Le document `artifacts/qualification-QC26-20261013/suspension-rules-result.json` indique `ALLOWED_SECURITY_BYPASS`.
Le tableau 27/27 fermé du registre était une fermeture de périmètres antérieurs, et non la preuve du refus de cette écriture directe.
Une reproduction permanente a été créée dans `functions/test/integration/suspensionModeRules.test.ts`. La tentative ciblée sur les règles non corrigées produisait une suite Jest en échec.

## Correction très ciblée
Dans `firestore.rules`, au niveau de `match /driver_profiles/{driverId}` / `allow update`, ajout du garde :
`request.resource.data.get('suspension_mode', null) == resource.data.get('suspension_mode', null)`.
Il protège ce champ d'autorité contre les changements directs par le chauffeur : ordinaire, urgent, suppression, création d'une valeur ordinaire sur profil suspendu historique.
Le `.get(..., null)` préserve la compatibilité des documents anciens où le champ n'existe pas. Le flux d'écriture administrative via Firebase Admin SDK/Cloud Functions reste distinct des Security Rules client.
Pas de modification aux statuts métier, aux fonctions, aux tarifs, aux commissions, à Stripe, aux snapshots ou au ledger.

## Validation
- Firebase Emulator Suite : projet exclusivement fictif `demo-movik-test`, Firestore/Auth sur `127.0.0.1`.
- 8 nouveaux tests ciblés : **8/8 réussis**.
- Non-régression étendue : **5 suites Jest / 281 tests réussis, 0 échec**, code de sortie 0, couvrant suspensionModeRules, securityRules, gpsAuthorityRules, suspensionMissionPolicy et adminPrivilegedActions.
- Cas négatifs : downgrade urgent→ordinary, suppression du mode, injection d'un mode sur profil legacy, modification ordinary→urgent par le client, écritures de rôle analyst/admin/super_admin directement sur Firestore.
- Cas positifs : modification légitime de ville par chauffeur suspendu, absence du champ optionnel dans un document historique, chauffeur approuvé qui se met en ligne sans champ optionnel, mise à jour administrative simulée via contexte sans règles.
- Avertissement non bloquant Jest : handles asynchrones encore ouverts à la fin; 281 tests ont toutefois terminé avec un code de sortie 0.
- Logs : `after-targeted.log` et `after-regression.log`. Les échecs de la version précédente sont aussi étayés par la preuve QC26.
- Aucune vérification en Firebase Production ni accès à un compte client réel.

## Points non résolus hors du correctif
Le commit consolidé QC26 conserve ses propres blocages : analyse Flutter globale des preuves archivées, 20 tests de mission/GPS bloqués par l'absence de transport HTTP autorisé, fixture `loadMvpBlocT` sans claim chauffeur, recette GPS 1.3L, intégrations réelles et Node20 non validés.
Le code et les règles réellement déployés ne sont pas vérifiés par le résultat des émulateurs. **Aucun feu vert pour fusion, preview ni production.**
