// ---------------------------------------------------------------------------
// État des versements Stripe d'un chauffeur, vu par l'admin (2026-11-03).
//
// Reflète EXACTEMENT la règle serveur `isDriverPayoutReady(driver, "live")`
// (functions/src/lib/stripeAccounts.ts) : un chauffeur ne peut accepter une
// livraison en vrai argent que si son compte Stripe est du mode réel, que
// Stripe a validé son identité (charges_enabled) et son compte bancaire
// (payouts_enabled). Un compte sans étiquette de mode a été créé en test.
// Affichage seulement : rien n'est écrit, rien ne contourne le serveur.
// ---------------------------------------------------------------------------
import 'package:flutter/material.dart';

import '../../../../backend/models/driver_profile_v2.dart';
import '../../../../core/app_colors.dart';
import '../../../../models/enums.dart';

enum DriverPayoutReadiness {
  /// Compte réel, identité et banque validées : Stripe peut le payer.
  ready,

  /// Compte réel créé, mais Stripe attend encore une pièce ou la banque.
  incomplete,

  /// Compte créé en mode test : à refaire (bouton « Configurer les
  /// versements » du chauffeur, après archivage par l'admin).
  testAccount,

  /// Jamais commencé.
  notStarted,
}

DriverPayoutReadiness driverPayoutReadiness(DriverProfileV2 p) {
  final id = (p.stripeConnectedAccountId ?? '').trim();
  if (id.isEmpty) return DriverPayoutReadiness.notStarted;
  if (p.stripeConnectedAccountEnvironment != 'live') {
    return DriverPayoutReadiness.testAccount;
  }
  return p.stripeChargesEnabled && p.stripePayoutsEnabled
      ? DriverPayoutReadiness.ready
      : DriverPayoutReadiness.incomplete;
}

/// Approuvé + documents validés + Stripe prêt : peut réellement livrer.
bool isDriverReadyToDeliver(DriverProfileV2 p) =>
    p.status == DriverStatus.approved &&
    p.documentsAllValid &&
    driverPayoutReadiness(p) == DriverPayoutReadiness.ready;

String driverPayoutReadinessKey(DriverPayoutReadiness r) => switch (r) {
  DriverPayoutReadiness.ready => 'admin_driver_payout_ready',
  DriverPayoutReadiness.incomplete => 'admin_driver_payout_incomplete',
  DriverPayoutReadiness.testAccount => 'admin_driver_payout_test_account',
  DriverPayoutReadiness.notStarted => 'admin_driver_payout_not_started',
};

Color driverPayoutReadinessColor(DriverPayoutReadiness r) => switch (r) {
  DriverPayoutReadiness.ready => AppColors.success,
  DriverPayoutReadiness.incomplete => AppColors.warning,
  DriverPayoutReadiness.testAccount => AppColors.warning,
  DriverPayoutReadiness.notStarted => AppColors.textSecondary,
};

/// Pastille « Versements OK / Stripe incomplet / … » (liste et fiche).
class DriverPayoutBadge extends StatelessWidget {
  const DriverPayoutBadge({super.key, required this.profile, required this.t});
  final DriverProfileV2 profile;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    final r = driverPayoutReadiness(profile);
    final color = driverPayoutReadinessColor(r);
    return Container(
      key: const ValueKey('admin-driver-payout-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            r == DriverPayoutReadiness.ready
                ? Icons.account_balance_outlined
                : Icons.account_balance_wallet_outlined,
            size: 14,
            color: AppColors.statusBadgeTextColor(
              color,
              Theme.of(context).brightness,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            t(driverPayoutReadinessKey(r)),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.statusBadgeTextColor(
                color,
                Theme.of(context).brightness,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
