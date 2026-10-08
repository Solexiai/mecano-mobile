# Reprise Movi-K — vérification distante du 8 octobre 2026

## Périmètre et sécurité
Audit en lecture seule de GitHub/Vercel et du code de la branche de production. Aucun déploiement, fusion, modification Stripe, tarifaire, Firebase ou transaction. Nouvelle branche isolée basée sur dd85a6016e11161e5f64746f34c0405cffc529e3; l'ordinateur Windows est hors ligne, donc son worktree et ses fichiers non suivis n'ont pas été modifiés.

## État constaté
- GitHub main: 6401cb2a9386b6eb8562d2fe585eb21a376dca1e.
- PR #51 ouverte, draft, head 083572bf2f136af8ed375e1f7c6824d1e4462b79; CI runs 37506202201 et 37506202216 complétés avec succès.
- PR #47 GA4 ouverte, non fusionnée: ne pas écraser l'identifiant Firebase historique.
- Vercel movi-k.com: déploiement READY dpl_Dvzf7pdS4PNs3sDRmim5rDJ7LLfH, commit dd85a6016e11161e5f64746f34c0405cffc529e3 sur validation/private-granby-final-20261006.
- Preview PR #51: déploiement READY dpl_B4CSJJZ1CFXpSKMpzKp43CbEVwd5, commit 083572b. Protection Vercel préservée. Lecture du contenu refusée (403, scope du projet).
- La production a un commit de plus que la PR #51 (neuf fichiers : textes/public, formulaire et tests), la branche release/live-backend-granby-20261006 en a deux, dont une modification functions/package-lock.json (proxy-addr 2.0.8).
- Remote Desktop Commander: LAPTOP-R0DMP4TG hors ligne; état local Git non vérifiable.
- Aucun outil Firebase relié permettant de vérifier la configuration réelle de movik-connect-prod ou d'exécuter les émulateurs depuis cet environnement.

## Observations de code (ne constituent pas une validation fonctionnelle réelle)
- lib/screens/info/contact_screen.dart à dd85a601 déclare explicitement qu'aucun canal de contact ne fonctionne. Aucun nouveau contact officiel confirmé.
- functions/src/functions/calculateDeliveryQuote.ts recalcule l'itinéraire côté serveur, utilise une version tarifaire active, et peut exiger une revue du chargement.
- functions/src/functions/createDeliveryRequest.ts appelle resolveLockedQuote, recopie customer_total_minor et pricing_snapshot dans la mission et refuse plusieurs incohérences de devis.
- functions/src/lib/quoteIntegrity.ts vérifie la ventilation, les cents, la version tarifaire et l'empreinte du devis verrouillé.
- functions/src/payment/stripeProvider.ts transmet params.amountMinor à Stripe pour PaymentIntent; ne prouve pas que Stripe live est correctement configuré ni que la chaîne complète préserve les montants.
- Les modèles config/booking_capacity.template.json et config/booking_policy.template.json sont non approuvés ou incomplets par défaut. Leur présence ne prouve pas l'état des documents Firestore déployés.

## Travaux encore nécessaires
1. Réactiver le poste autorisé pour lire git status, préserver les dix fichiers non suivis et lancer Flutter/émulateurs/navigateur.
2. Réautoriser le scope projet Vercel pour inspecter la preview protégée sans la rendre publique.
3. Confirmer de façon non destructive system_config/booking_capacity, booking_policy, service_zones, pricing_configs/active, versions applicables, capacités véhicules et secrets Stripe sans révéler les secrets.
4. Vérifier invité → catégorie → formulaire → login → reprise avec compte de recette, puis devis officiel et identifiants/snapshots dans l'environnement approuvé.
5. Réviser de bout en bout le code de la PR #51 (finances, règles, fonctions, intégrations) et établir les tests de non-divergence devis/mission/snapshot/Stripe cents, sans transaction réelle.
6. Raccorder un canal de contact officiel approuvé, valider la production et obtenir l'autorisation explicite avant toute fusion/déploiement/QR.

**QR: NON PRÊT À DISTRIBUER.**

Sources: GitHub PR #51, PR #47, Actions 37506202201 et 37506202216, fichiers au commit dd85a601; Vercel deployments dpl_Dvzf7pdS4PNs3sDRmim5rDJ7LLfH et dpl_B4CSJJZ1CFXpSKMpzKp43CbEVwd5, vérifiés le 8 octobre 2026.
