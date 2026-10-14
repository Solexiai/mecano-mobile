# CHECKPOINT MOVI-K — Reprise du déploiement — 14 octobre 2026

## Résultat

**Code sauvegardé et poussé, deux versions Vercel READY, domaine public non basculé.**
La publication finale attend la décision explicite sur le lot Firebase coordonné, particulièrement les deux nouvelles automatisations susceptibles de traiter des autorisations de paiement existantes. Aucun paiement réel, aucun test Stripe Sandbox/LIVE, aucune modification Firebase n'ont été effectués.

- Branche : `fix/gps-client-history-scope-20261009`.
- HEAD de départ : `c24bf8340fff939e2a74855bd5a6a8aaabf3b6ac`.
- Commit code/tests/build poussé : `8ab7864593555db74d2f2aa417366a7a4d0621e1`.
- Main distant inchangé : `6401cb2a9386b6eb8562d2fe585eb21a376dca1e`.
- Production publique conservée : `dd85a6016e11161e5f64746f34c0405cffc529e3`, déploiement `dpl_Dvzf7pdS4PNs3sDRmim5rDJ7LLfH`, alias movi-k.com revérifié le 14 octobre à 15:12:45 UTC.
- Aucun merge, changement de branche ou intervention sur un autre worktree.

## Versions examinables

| Version | Déploiement | État / preuve |
|---|---|---|
| Preview GitHub | https://mecano-mobile-ay1wfmyvv-solexis-projects-4c019079.vercel.app/fr | READY ; six captures Chrome |
| Candidate avec configuration de production | https://mecano-mobile-28prusr3a-solexis-projects-4c019079.vercel.app/fr | READY ; créée avec --prod --skip-domain ; GET protégé /fr = HTTP 200 |
| Public actuel | https://movi-k.com | Ancien déploiement conservé |

La protection Vercel reste active. Utiliser le compte Vercel autorisé. **Ces versions utilisent la configuration Firebase de production : ce ne sont pas des environnements métier isolés.** Les contrôles Chrome réalisés ici refusaient explicitement toute requête métier avant envoi ; ce dispositif n'est pas incorporé au site déployé. Ne pas interpréter cette preuve visuelle comme une autorisation de mission ou de paiement réel.

Le JavaScript compilé de la preview et de la candidate est identique : 5 070 109 octets, SHA256 `95d6c92f6aeed6d962c007c5071698418a42258f514c4265ec371bf42ea49175`. Preuve : WEB_ARTIFACT_COMPARISON.json.

## Corrections de cette reprise

1. Quatre suites de test maintenant raccordées au transport GPS mémoire déjà existant. Aucun écran produit remplacé, aucune assertion retirée.
2. CI Flutter alignée sur `--dart-define=no_default_http_client=true`.
3. Attribut Git LF imposé à scripts/vercel_build.sh. Le blob Git était déjà LF ; la conversion Windows core.autocrlf=true avait introduit 113 CRLF dans l'archive envoyée à Vercel. Le script métier reste identique.
4. Registre et preuves actualisés.

356 fichiers métier/serveur/règles/dépendances suivis ont gardé leurs empreintes initiales. 2 803 fichiers non suivis préexistants toujours présents. Aucun tarif, taux de commission, montant, snapshot, ledger ou code financier modifié pendant cette reprise.

## Tests réellement exécutés

| Exécution | Réussis | Échoués | Ignorés |
|---|---:|---:|---:|
| Reproduction Flutter, quatre suites avant correction | 9 | 20 | 0 |
| Mêmes suites après correction | 29 | 0 | 0 |
| Suite Flutter complète finale | 1 088 | 0 | 0 |
| Unitaires serveur sous Node 20.20.2, 15 suites | 228 | 0 | 0 |
| Intégration Firebase sous Node 20.20.2, 50 suites | 734 | 0 | 0 |

Ne pas additionner les tests ciblés aux tests de la suite complète.
Analyse Flutter complète, TypeScript, lint serveur, contrôle Dart format, syntaxe Bash et git diff --check réussis. Aucun nouvel outil installé.

Les intégrations utilisent exclusivement demo-movik-test et les émulateurs Firestore/Auth/Storage, arrêtés à la fin. Le garde Node refuse les sockets/DNS externes et les processus enfants ; accès loopback limités aux ports 8080/9099/9199/4400. Les tentatives SDK vers les métadonnées Google ont été bloquées et consignées, aucune ne constitue une requête autorisée. Ce garde n'est pas un confinement réseau du système d'exploitation.

Historique d'échecs préservé :
- premier essai Node 20 interrompu parce que le port de découverte local 4400 était refusé ; reprise après ajout de ce seul port local, sans ouverture externe ;
- premier build Vercel ERROR, dpl_BH1psGhM9hzq7Xx5GiW7oaYazqAn, à cause des CRLF ;
- premier contrôle Chrome interrompu par l'assertion HTTP 200 devant une réponse cache 304 ; reprise avec cache désactivé, six réponses HTTP 200. Aucun correctif produit lié à ce contrôle.

## Chrome et captures réellement examinées

Navigateur Chrome réel sans session applicative, accès Vercel par jeton court limité à l'origine de la preview ; aucun jeton conservé. Ressources statiques autorisées, API métier et services cartographiques bloqués.

- fr-home-mobile.png : 375 × 812.
- fr-home-desktop.png : 1440 × 900.
- en-home-mobile.png : 430 × 932.
- es-home-mobile.png : 430 × 932.
- fr-granby-mobile.png : 375 × 812.
- fr-guest-request.png : 375 × 812, catégorie Meubles conservée.

Dossier : browser-preview-v2/. Six PNG existants, dimensions confirmées, contenu examiné ; aucun chevauchement important dans les vues capturées. Aucun pageerror JavaScript. Une requête OPTIONS vers getBookingConfiguration a été bloquée avant transmission ; le bandeau « réservation indisponible » de la capture du formulaire est donc cohérent avec ce contrôle, pas une preuve d'indisponibilité de production.

Les captures couvrent les vues initiales, pas chaque écran et chaque action. Aucune preuve nouvelle de connexion réelle, devis serveur, disponibilité chauffeur, paiement, GPS physique ou zoom Chrome 200 %. Ce dernier point reste distinct des tests widget historiques.

## Périmètre Firebase préparé — NON EXÉCUTÉ

L'inventaire cloud en lecture seule recense 64 fonctions déployées ; le code en exporte 69. Le serveur courant n'a pas les derniers correctifs GPS et ne fournit pas encore les nouvelles sémantiques de suspension envoyées par l'interface. Les dates de déploiement ont été vérifiées ; le commit exact des sources serveur actuellement déployées n'est pas attesté.

L'analyse statique des dépendances propose **14 fonctions déjà déployées** à revalider dans un lot cohérent :
suspendDriver, reactivateDriver, acceptDelivery, adminAssignDelivery, completePickup, completeDelivery, updateMissionTrackingStatus, onMissionEndedClearTracking, recordTrackingPoint, calculateDriverPayout, processScheduledDriverPayouts, refundPayment, processStripeWebhook, processStripeConnectWebhook.

La règle firestore.rules comporte également des protections GPS locales à publier de manière coordonnée. Cette analyse compare au commit Web public dd85a60 ; elle ne remplace pas la vérification des sources/règles actuellement déployées et du retour arrière avant toute écriture cloud.

**Deux nouveaux automatismes nécessitent une décision explicite :**
- onPaymentAuthorizedAfterMissionCancel : après une autorisation tardive sur une mission annulée, peut demander au fournisseur d'annuler/libérer cette autorisation ;
- recoverCancelledPendingPayments : toutes les dix minutes, examine un lot borné de paiements restés en attente et peut déclencher leur récupération/libération.

Ils ne sont pas activés. Il ne s'agit pas d'une simple mise en ligne d'un texte ou d'un paiement simulé.

Trois autres exports existent localement mais ne figurent pas dans l'inventaire déployé : updateDisputeStatus, resolveReconciliationAnomaly, reverseDriverPayout. **Ils sont exclus du lot minimal proposé**, aucune activation implicite recommandée. Le détail des dépendances est dans BACKEND_ROLLOUT_PROPOSAL.json.

Séquence proposée après décision : vérifier et sauvegarder les versions/règles actuelles pour retour arrière ; publier le lot Firebase explicitement retenu ; contrôler ses métadonnées et erreurs sans transaction réelle ; promouvoir le déploiement Vercel précis déjà construit ; vérifier le domaine et les pages en lecture seule. Aucun merge main requis.

## Limites et registre

Le tableau actif conserve ses 28 fiches fermées dans leurs périmètres locaux : P0 0 / P1 0 / P2 0. Ce décompte ne constitue pas une certification commerciale ou de production.

Restent distincts : 1.3L BLOQUÉ ET REPORTÉ, GPS terrain, Stripe Sandbox/LIVE, reprise après interruption réelle d'un webhook, compatibilité finale du backend déployé, contact officiel/QR et disponibilité opérationnelle du pilote. Aucun de ces points n'est déclaré validé ici.

Le correctif webhook prouve la sérialisation des audits dans les scénarios émulés ; il ne certifie pas une propriété financière globale « exactement une fois » après toute panne.

## Prochaine décision unique

Confirmer le périmètre du déploiement Firebase coordonné, en indiquant explicitement si les deux nouvelles automatisations de récupération des autorisations doivent être activées, avant le basculement de movi-k.com.
