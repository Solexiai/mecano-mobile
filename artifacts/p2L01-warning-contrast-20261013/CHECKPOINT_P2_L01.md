# MOVI-K — CHECKPOINT P2-L-01 — CONTRASTE DES BADGES WARNING
Date : 13 octobre 2026, Québec (heure locale).

## Verdict
**FERMÉ — PÉRIMÈTRE WIDGET/CONTRASTE WCAG LOCAL VALIDÉ — NON DÉPLOYÉ.**

## Git et sécurité
- Dépôt : Solexiai/mecano-mobile.
- Worktree : `C:\Users\Utilisateur\movik-gps-history-fix-20261009`.
- Branche : `fix/gps-client-history-scope-20261009`.
- HEAD initial : `82d1ebf029b03958a7f7796df0ddf7d8ef391fae`.
- Aucun push, merge, déploiement ni changement à la production.
- Aucun tarif, commission, calcul en cents, statut métier, snapshot, ledger, Stripe, Firestore rules, service serveur ou i18n métier modifié.

## Cause confirmée
`AppColors.warning` (ambre #F59E0B) était utilisé comme couleur de TEXTE dans certains badges financiers, chauffeurs et fournisseurs, sur fond clair fortement transparent. Les rapports Phase7 signalaient un contraste insuffisant (environ 1,96:1 dans certains contextes), distinct de BUG-L6-01 déjà réglé sur le texte GPS.

## Correction locale
- `lib/core/app_colors.dart` : ajout de deux couleurs de texte lisibles pour les badges d'avertissement : `warningBadgeTextLight` (#92400E) et `warningBadgeTextDark` (#FDE68A). La couleur décorative `warning` conserve son code d'origine. Le helper `statusBadgeTextColor` remplace le texte warning seulement, sans toucher aux statuts success/error/info.
- `statusBadgeBackground` compose un fond warning opaque compatible avec le thème, permettant un contraste vérifiable même si un parent legacy utilise un fond clair en mode sombre. Les autres tons n'ont pas été modifiés par cette branche conditionnelle.
- Les textes des badges `StatusBadge` (finance admin), `ComingSoonBadge`, dossiers chauffeur, profil fournisseur, versements et revenus, onboarding Stripe Connect et blog appliquent cette teinte conditionnelle.
- La mention d'avertissement réservée à l'admin dans la politique de versements utilise le texte approprié au thème. Les indicateurs visuels restent accompagnés de libellés. L'écran DocumentTile à fond clair fixe garde le texte warning clair/foncé adapté à son fond réel, même dans le thème sombre.
- Aucune règle d'accès ni représentation comptable modifiée. Les couleurs de fond et bordure des statuts continuent à refléter le statut existant.

## Mesures et validations
- Test permanent `test/accessibility/p2_warning_badges_contrast_test.dart` : **5/5 réussis**, mesure la luminance/rapport de contraste WCAG avec la fonction sRGB standard, incluant le fond de badge réellement défini dans le widget. Exige un rapport d'au moins **4,5:1** sur les deux surfaces light/dark de StatusBadge et ComingSoonBadge ; confirme que la couleur warning initiale ne satisfait pas l'objectif de texte normal sur la surface claire.
- Test complémentaire : les couleurs success/error non ciblées sont renvoyées inchangées.
- `dart analyze --fatal-infos` ciblé sur les sources et le nouveau test : **No issues found** après correction d'un `const TextStyle` qui utilisait un calcul de couleur dynamique.
- Suite Flutter finale exécutée une nouvelle fois après la dernière modification : **243 tests réussis / 0 échec**, huit suites widgets (contraste, accessibilité, finance admin, i18n finance, versements fournisseur, Stripe Connect fournisseur, écran statut chauffeur, tableau de bord fournisseur).
- Preuves locales de commande : `artifacts/p2L01-warning-contrast-20261013/flutter-regression.log` (non versionné), rapport et tests permanents dans le commit.
- Les résultats sont des contrôles Flutter locaux sans navigateur Chrome/Safari ni appareil physique. Les contrastes de tous les autres tons et composants hors warning ne sont PAS certifiés par ce lot.

## Limites de lancement
- Le contraste ciblé est conforme aux surfaces testées localement ; les écrans complets en mode sombre/clair, appareils physiques et lecteurs d'écran réels restent à valider.
- Le test réseau des tuiles cartographiques/GPS 1.3L reste BLOQUÉ ET REPORTÉ.
- Les coûts Firestore réels, les paiements Stripe réels, la télémétrie, les permissions de lecture GPS et les essais complets navigateur restent des prérequis distincts.
- Les anciens P3 et anomalies historiques sans clôture confirmée ne disparaissent pas parce que le registre courant P0/P1/P2 atteint zéro.

## Registre
**27 fiches conservées ; 27 fermées dans leurs périmètres documentés.**
P0 0 / P1 0 / P2 0 ouverts dans le registre actuel.
**AUCUN GO de mise en production ou lancement Granby.**
