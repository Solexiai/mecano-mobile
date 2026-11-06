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

import '../../../../backend/models/driver_payout_readiness.dart';
import '../../../../backend/models/driver_profile_v2.dart';
import '../../../../core/app_colors.dart';

export '../../../../backend/models/driver_payout_readiness.dart';

String driverPayoutReadinessKey(DriverPayoutReadiness r) => switch (r) {
  DriverPayoutReadiness.ready => 'admin_driver_payout_ready',
  DriverPayoutReadiness.underReview => 'admin_driver_payout_under_review',
  DriverPayoutReadiness.incomplete => 'admin_driver_payout_incomplete',
  DriverPayoutReadiness.testAccount => 'admin_driver_payout_test_account',
  DriverPayoutReadiness.notStarted => 'admin_driver_payout_not_started',
};

Color driverPayoutReadinessColor(DriverPayoutReadiness r) => switch (r) {
  DriverPayoutReadiness.ready => AppColors.success,
  DriverPayoutReadiness.underReview => AppColors.primary,
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
          // Flexible : à 200 % de taille de police sur un téléphone, le
          // libellé passe sur deux lignes au lieu de déborder.
          Flexible(
            child: Text(
              t(driverPayoutReadinessKey(r)),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.statusBadgeTextColor(
                  color,
                  Theme.of(context).brightness,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
