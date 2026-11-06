// ---------------------------------------------------------------------------
// État des versements Stripe d'un chauffeur (2026-11-03, déplacé ici le
// 2026-11-06 pour être partagé entre l'espace chauffeur et l'admin).
//
// Reflète EXACTEMENT la règle serveur `isDriverPayoutReady(driver, "live")`
// (functions/src/lib/stripeAccounts.ts) : un chauffeur ne peut accepter une
// livraison en vrai argent que si son compte Stripe est du mode réel, que
// Stripe a validé son identité (charges_enabled) et son compte bancaire
// (payouts_enabled). Un compte sans étiquette de mode a été créé en test.
// Affichage seulement : rien n'est écrit, rien ne contourne le serveur.
// ---------------------------------------------------------------------------
import 'driver_profile_v2.dart';
import '../../models/enums.dart';

enum DriverPayoutReadiness {
  /// Compte réel, identité et banque validées : Stripe peut le payer.
  ready,

  /// Compte réel, formulaire Stripe terminé, rien de demandé au chauffeur :
  /// Stripe vérifie (quelques minutes à 1–2 jours). Rien à faire.
  underReview,

  /// Compte réel créé, mais le formulaire n'est pas terminé ou Stripe
  /// demande encore une pièce : le chauffeur doit reprendre.
  incomplete,

  /// Compte créé en mode test : à refaire. Le chauffeur relance
  /// « Configurer les versements » ; le serveur archive l'ancien compte et
  /// en crée un nouveau en mode réel (createDriverStripeAccount).
  testAccount,

  /// Jamais commencé.
  notStarted,
}

DriverPayoutReadiness driverPayoutReadiness(DriverProfileV2? p) {
  final id = (p?.stripeConnectedAccountId ?? '').trim();
  if (p == null || id.isEmpty) return DriverPayoutReadiness.notStarted;
  if (p.stripeConnectedAccountEnvironment != 'live') {
    return DriverPayoutReadiness.testAccount;
  }
  if (p.stripeChargesEnabled && p.stripePayoutsEnabled) {
    return DriverPayoutReadiness.ready;
  }
  if (p.stripeDetailsSubmitted &&
      p.stripeRequirementsCurrentlyDue == 0 &&
      p.stripeRequirementsDisabledReason == null) {
    return DriverPayoutReadiness.underReview;
  }
  return DriverPayoutReadiness.incomplete;
}

/// Approuvé + documents validés + Stripe prêt : peut réellement livrer.
bool isDriverReadyToDeliver(DriverProfileV2 p) =>
    p.status == DriverStatus.approved &&
    p.documentsAllValid &&
    driverPayoutReadiness(p) == DriverPayoutReadiness.ready;
