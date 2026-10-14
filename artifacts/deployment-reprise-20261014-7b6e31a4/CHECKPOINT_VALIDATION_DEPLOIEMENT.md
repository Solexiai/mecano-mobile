# CHECKPOINT MOVI-K — Reprise du déploiement — 14 octobre 2026

Branche : fix/gps-client-history-scope-20261009. HEAD de départ : c24bf8340fff939e2a74855bd5a6a8aaabf3b6ac. Index initial vide. Autorisation utilisateur : pousser pour essai sur movi-k.com ; aucun paiement de test réel.

## Correctifs de préparation

Quatre suites Flutter utilisaient le client HTTP par défaut malgré no_default_http_client=true. Reproduction : 9 réussis / 20 échoués / 0 ignoré. Raccordement au transport mémoire GPS existant, sans retirer aucune assertion ni remplacer les écrans réels. Après : 29/0/0. Suite Flutter complète : 1088/0/0. CI Flutter reçoit désormais le même dart-define. Analyse complète sans problème, format stable, diff check propre.

Le premier build Vercel isolé dpl_BH1psGhM9hzq7Xx5GiW7oaYazqAn a échoué : scripts/vercel_build.sh contient 113 CRLF ; Bash Linux refuse set pipefail. Correction strictement des fins de ligne et attribut Git eol=lf pour ce fichier. Syntaxe Bash locale validée ; nouveau build distant à contrôler. Aucun contenu métier du script changé.

## Serveur et isolation

Node 20.20.2 déjà présent utilisé sans installation. 228/228 tests unitaires (15 suites) et 734/734 tests intégration (50 suites), aucun échec ni ignoré final. TypeScript et ESLint : 0. Projet demo-movik-test, émulateurs Auth/Firestore/Storage seuls. Fournisseurs de paiement fictifs ; signatures Stripe calculées localement, aucun appel Stripe Sandbox/LIVE. Garde Node refuse sockets/DNS externes et processus enfants ; seules connexions loopback 8080/9099/9199/4400 permises. Les tentatives de métadonnées Google et de processus enfant ont été refusées, pas transmises. Le premier essai sous garde omettait le hub 4400 ; il a été interrompu, ses erreurs sont conservées, pas réécrites en succès. Les émulateurs de cette intervention ont été arrêtés.

## Production et décision restante

movi-k.com pointe sur dpl_Dvzf7pdS4PNs3sDRmim5rDJ7LLfH, commit dd85a6016e11161e5f64746f34c0405cffc529e3. Projet prj_yM2CwOXyXjbdpaHNRE1m850jpYtg, équipe team_38WgzxHilyBpZczgig872vPV. Branche Git de production : main. La branche courante peut être poussée séparément sans merge. Firebase contient encore les anciennes versions GPS (recordTrackingPoint daté du 17 août) et paiements (6 octobre), constat de métadonnées, pas comparaison binaire exhaustive.

Le nouvel écran administrateur envoie suspensionMode ; le serveur actuel ne fournit pas la nouvelle sémantique ordinaire/urgente. Publier le front seul ne valide pas cette compatibilité. Le lot serveur ajoute onPaymentAuthorizedAfterMissionCancel et recoverCancelledPendingPayments (toutes les 10 minutes) : ils peuvent contacter le fournisseur réel pour libérer une autorisation de mission annulée. Leur activation sur les paiements existants exige une décision distincte et informée avant basculement coordonné. Aucun changement de montant, tarif, commission, snapshot ou ledger effectué pendant cette reprise.

## Preuves et limites

VALIDATION_RESULTS.json contient les comptes exacts, empreintes, contrôles et refus réseau. CHANGE_INTEGRITY_FINAL.json compare les tests à leur source avant modification et scanne 400 blobs de l’historique non publié pour formes usuelles de secrets : aucun signal, sans certification exhaustive. BUILD_LINE_ENDINGS.json conserve les empreintes du script. Journaux complets locaux préservés et exclus du commit. 356 sources métier inchangées ; 2803 fichiers non suivis préexistants toujours présents.

Le registre reste à 28 fiches fermées dans leurs seuls périmètres documentés : P0 0 / P1 0 / P2 0 dans ce tableau, pas un GO commercial global. Contact/QR, GPS terrain, reprise réelle après crash webhook, Stripe réel et recette Firebase déployée non validés. Test autonome de tuiles 1.3L BLOQUÉ ET REPORTÉ.

## Étape suivante

Sauvegarde et push de la branche autorisés ; build Vercel --prod --skip-domain puis contrôles de la candidate. Ne pas promouvoir une combinaison frontend/backend non validée ni activer implicitement les deux nouvelles automatisations financières.

Précision de diagnostic : le blob Git du script était déjà en LF. La conversion Windows core.autocrlf=true lors de la préparation de l’archive a produit les 113 CRLF rejetés par Vercel. Le contenu versionné du script reste identique ; seule .gitattributes ajoute la protection eol=lf et le fichier local est normalisé. Aucun changement Bash métier.
