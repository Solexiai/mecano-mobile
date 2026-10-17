# Retrait de l’option objet lourd — 17 octobre 2026

Décision du propriétaire dans cette conversation : retirer l’option objet lourd et le supplément de 10 CAD pour les nouveaux devis, puis pousser sur Git. Aucun déploiement de production autorisé ou effectué.

Base : feature/photo-assisted-booking-20261015, HEAD 75a6803246db3f7e8e610b3900e46c49b2fd228b ; index initial vide. Travaux photo/chauffeur préexistants conservés hors du commit ciblé.

Changements : calculateDeliveryQuote neutralise isHeavyItem après revue serveur et avant tout calcul, y compris pour les anciennes applications. bookingHandling ne demande plus ce supplément ; heavy_item_kg n’est plus un prérequis de configuration. Les contrôles de charge utile, géométrie, manutention et véhicule vérifié restent en place. Suppression des trois traductions inutilisées de l’option. Aucun changement du moteur tarifaire historique, des versions stockées, commissions, pourboires, taxes, Stripe, snapshots figés, ledger ou payouts. Les autres frais restent inchangés.

Preuve avant correction : 13 tests réussis / 4 échoués. Le scénario émulateur ajoutait effectivement 10 CAD au devis lorsque l’ancien client envoyait isHeavyItem=true.
Après correction dans le worktree existant : 81 réussis / 0 échoué / 0 ignoré. Contenu exact destiné au commit, reconstruit depuis HEAD sans les changements locaux antérieurs : 82 réussis / 0 échoué / 0 ignoré. Ne pas additionner ces ensembles recouvrants. TypeScript noEmit et ESLint réussis dans les deux arbres ; analyse Dart ciblée réussie.

Tests sous Firestore Emulator demo-movik-test et garde réseau loopback ; routes et paiements fictifs. Contrôles de montant, conservation d’un ancien document de devis, non-modification de la configuration stockée et autres frais. Les tests existants de concurrence/échec d’acceptation et idempotence des demandes passent. Aucune validation Stripe/production revendiquée.

Fichiers produit du commit : functions/src/functions/calculateDeliveryQuote.ts, functions/src/lib/booking.ts, lib/l10n/app_strings.dart. Tests : functions/test/unit/heavyOptionRetirement.test.ts, functions/test/integration/calculateDeliveryQuote.test.ts. Ce checkpoint et addendum du registre inclus. Le test photoBookingHandling préexistant non suivi a été adapté localement à la décision ; il demeure hors de ce commit ciblé.

Preuves locales : artifacts/heavy-option-removal-20261017/integration-before, integration-after, integration-commit, candidate-*-exit.txt, worktree-*-exit.txt, dart-analyze-exit.txt, git-before.txt. Scripts run-integration.cjs et run-candidate.cjs consignent les commandes et l’isolation. Les émulateurs dédiés sont arrêtés par les runners.

La production n’est pas modifiée par cette correction locale/Git. Les blocages de politique de réservation, mapping photo, profils/capacités vérifiés et flags opérationnels restent ; la décision relative au supplément lourd est désormais résolue. P1-BOOKING-CONFIG-01 reste ouvert ; 1.3L reste bloqué/reporté. Aucune fermeture de fiche.
