# Échecs confirmés par l'administration — décision approuvée et réalisation locale

## Source de décision

Le 19 octobre 2026 à 15:46:55 (America/Toronto), le propriétaire approuve : « ouais, vas y avec ta proposition ». La proposition distinguait une livraison non réalisée, dont l'échec est confirmé par l'administration, d'une annulation ; elle n'attribuait pas automatiquement la responsabilité au chauffeur. Version enregistrée : MOVIK-FAILURE-REVIEW-20261019-001.

Cette approbation résout le point « classification des missions échouées » du rapport ADMIN_DRIVER_ACTIVITY_20261019.md. Elle n'autorise ni nouveau déploiement, ni sanction automatique, ni changement financier.

État initial vérifié : branche feat/admin-driver-activity-20261019, HEAD d6da50386f464ad6539d9fb8dc8fe77ebb38c225, index et fichiers suivis propres ; les deux dossiers d'artefacts précédents conservés. Aucun autre worktree modifié.

## Comportement intégré

- Dans la liste administrative des missions existante, le détail d'une mission propose un constat d'échec. Confirmation réservée aux rôles admin/super_admin ; l'analyste peut consulter.
- Case non cochée par défaut : après vérification, la livraison n'a pas été réalisée. Motif obligatoire ; date serveur et administrateur enregistrés.
- Le constat est stocké dans mission_outcome_reviews, séparément du statut opérationnel et des collections financières. Il n'annule pas et ne clôture pas une mission. Aucun remboursement, capture, versement, sanction ou changement de disponibilité n'est déclenché.
- Refus des missions annulées, livrées, terminées, non assignées, de test interne ou comportant une preuve de livraison/achèvement. Un remboursement seul n'établit pas l'échec : pour une mission remboursée sans preuve d'achèvement, une confirmation administrative explicite reste nécessaire.
- Garde de concurrence sur statut observé, chauffeur assigné et révision du constat. Une demande périmée est refusée ; une confirmation déjà enregistrée n'est pas dupliquée.
- Constat et audit immuable sont écrits dans la même transaction. L'administration peut retirer un constat avec un motif ; la trace antérieure reste dans audit_logs. Responsabilité conservée à not_determined.
- Le compteur des chauffeurs utilise les constats confirmés encore compatibles avec la mission courante ; les annulations restent distinctes. Une mission devenue livrée/terminée ne reste pas un échec compté. Le compteur absent d'un ancien serveur reste « — ».
- Les règles Firestore refusent toute écriture directe dans mission_outcome_reviews, même depuis un client administrateur. Les actions passent par reviewMissionFailure et ses contrôles serveur.

## Reproduction et preuves

Échec initial conservé : failureActivity.test.ts attendait un compteur réel à zéro après approbation, mais recevait null. Correction puis tests de classement, droits, concurrence, correction et intégrité des écritures. Un avertissement de style Flutter a été corrigé sans assouplir les tests.

Dernières exécutions de ce périmètre :
- 38 scénarios Flutter distincts réussis : 11 constat administratif, 11 activité chauffeur et 16 bloc admin. Les reprises recouvrantes ne sont pas additionnées. Mobile 375 px, desktop 1440 px, FR/EN/ES et texte 200 % couverts par widgets simulés.
- 54 tests serveur unitaires simulés réussis : classification, statistiques, droits réels issus des claims simulés, transaction simulée, absence d'écriture sur mission/paiement, audit obligatoire, réaffectation et requête périmée, révocation.
- 5 tests de règles réussis dans les émulateurs du projet demo-movik-test : lecture des rôles habilités et refus des écritures directes ; refus client/chauffeur.
- Analyse Flutter intégrale : aucun problème. TypeScript et ESLint source vérifiés ; codes de sortie et compilation Web consignés dans les artefacts.

Journaux : artifacts/mission-failure-review-20261019/. Ce sont des validations locales et en émulateur, pas une validation en production. Aucun constat réel, paiement ou mission réelle créé/modifié.

## Fichiers

Serveur : reviewMissionFailure.ts, missionFailureReview.ts, driverActivity.ts, getAdminDriverActivity.ts, index.ts et firestore.rules.
Interface : admin_mission_failure_review.dart, admin_missions_screen.dart et admin_driver_activity_summary.dart.
Tests : missionFailureReview.test.ts, reviewMissionFailure.test.ts, failureActivity.test.ts, driverActivity.test.ts, missionFailureReviewRules.test.ts et admin_mission_failure_review_test.dart.
Registre unique mis à jour sans fermer un ancien blocage ni réviser son décompte.

## Suite

Non déployé. Une publication coordonnée de l'ajout présence/avis et de ce complément nécessite le frontend, les règles et les deux fonctions getAdminDriverActivity/reviewMissionFailure. L'approbation de mise en production et la validation connectée réelle restent à obtenir ; la décision de classification elle-même est désormais approuvée.

Vérification finale à 19:57 UTC : codes de sortie 0 pour TypeScript, ESLint source, analyse Flutter, tests finaux, règles en émulateur, compilation Web et git diff --check. Synthèse : artifacts/mission-failure-review-20261019/validation-summary.json. Échec initial et journaux intermédiaires conservés.


### Publication activité chauffeurs et constats administratifs — 2026-10-19T20:07:31.706Z
Source : 3763edfb6cdf7d3cb9dea0d814cc48b17210cbdb ; branche feat/admin-driver-activity-20261019. Vercel : dpl_F9g1fAHbU5xn7rcv8yp34uofFoQf. Empreinte main.dart.js : 814698fc8a4c43e3ea433a92b8fe6253ce01fe22fa816fda7d2d002ae7da1cf6. Les deux domaines publics servent le bundle attendu ; /fr/admin répond HTTP 200. Fonctions getAdminDriverActivity et reviewMissionFailure ACTIVE, accès non authentifié refusé (401). Règles publiées vérifiées égales au fichier local, avec conservation des protections préexistantes des véhicules vérifiés.
Validation locale antérieure : 38 tests Flutter et 54 tests serveur simulés ; contrôle complémentaire des règles fusionnées : 14 tests réussis en émulateur. Build production réussi. Aucune mission ni aucun paiement réel créé, aucun constat administratif réel enregistré. Parcours privé administrateur et présence multi-appareils non validés en production authentifiée. Aucun ancien bogue fermé. Preuves : artifacts/admin-driver-activity-release-20261019/.
