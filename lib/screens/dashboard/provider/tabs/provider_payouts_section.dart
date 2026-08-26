// ---------------------------------------------------------------------------
// ProviderPayoutsSection — vue financière CHAUFFEUR (Bloc K, Phase 6).
//
// Intégrée dans `ProviderEarningsTab` (au-dessus de l'historique de ledger
// existant, voir décision technique ci-dessous), cette section affiche
// EXCLUSIVEMENT des données déjà autorisées par les Security Rules serveur
// pour le chauffeur propriétaire :
//   - Résumé : agrégation en mémoire des `DriverPayoutInfo` du chauffeur
//     (disponible / en attente / payé) — voir `_PayoutBuckets` pour la
//     définition exacte de chaque seau, aucun recalcul financier des
//     montants eux-mêmes (chaque `amountMinor` est une lecture directe).
//   - Missions : `FinancialSnapshot` figés à l'acceptation (montant offert,
//     bonus, pourboire, gain net) — jamais `DriverCompensationResult`
//     (estimation locale PRÉ-mission uniquement, voir Bloc K point 3).
//   - Versements : `DriverPayoutInfo` (statut, montant, dates, période de
//     rétention, échec/reversal reformulés sans exposer de code provider).
//
// DÉCISION TECHNIQUE (Bloc K point 4) : enrichissement de
// `provider_earnings_tab.dart` plutôt que création d'un écran dupliqué —
// l'onglet "Revenus" existe déjà et est câblé dans
// `provider_dashboard_shell.dart` ; l'historique de ledger déjà affiché
// (bonus/tip/ajustements individuels) est complémentaire à cette section
// (vue par mission + par versement), pas redondant.
//
// EXCLUSIONS STRICTES (Bloc K point 6) : cette section n'affiche JAMAIS la
// marge de contribution, les coûts internes plateforme, le revenu global
// Movi-K, ni les données d'un autre chauffeur — ces champs existent dans
// les modèles Dart sous-jacents (FinancialSnapshot.contributionMargin,
// .platformGrossRevenue, etc., pour l'usage Bloc L) mais ne sont
// simplement jamais lus ici. Le taux/montant de commission PLATEFORME
// prélevé sur SA PROPRE mission n'est pas non plus affiché ici : la
// directive l'autorise mais ne l'exige pas, et le minimum demandé (montant
// offert / bonus / pourboire / net) n'en a pas besoin.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../../../../backend/backend_locator.dart';
import '../../../../core/app_colors.dart';
import '../../../../finance/models/financial_snapshot.dart';
import '../../../../finance/models/driver_payout_info.dart';
import '../../../../finance/presentation/money_format.dart';
import '../../../../finance/presentation/payout_display_status.dart';
import '../../../../models/enums.dart';

class ProviderPayoutsSection extends StatelessWidget {
  final String driverId;
  final String Function(String) t;
  const ProviderPayoutsSection({
    super.key,
    required this.driverId,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<FinancialSnapshot>>(
      stream: BackendLocator.financeRepository.watchFinancialSnapshotsForDriver(
        driverId,
      ),
      builder: (context, snapshotsSnap) {
        return StreamBuilder<List<DriverPayoutInfo>>(
          stream: BackendLocator.financeRepository.watchPayoutsForDriver(
            driverId,
          ),
          builder: (context, payoutsSnap) {
            final loading =
                snapshotsSnap.connectionState == ConnectionState.waiting ||
                payoutsSnap.connectionState == ConnectionState.waiting;
            final hasError = snapshotsSnap.hasError || payoutsSnap.hasError;

            if (loading) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      t('payout_loading'),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              );
            }
            if (hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t('payout_error'),
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              );
            }

            final snapshots = snapshotsSnap.data ?? const <FinancialSnapshot>[];
            final payouts = payoutsSnap.data ?? const <DriverPayoutInfo>[];

            return ProviderPayoutsContent(
              t: t,
              snapshots: snapshots,
              payouts: payouts,
            );
          },
        );
      },
    );
  }
}

/// Contenu pur (résumé + missions + versements), sans dépendance à
/// `BackendLocator` ni à Firestore — extrait de `ProviderPayoutsSection`
/// pour permettre les tests widget (Bloc K point 12 "Widget/UI") avec des
/// données `FinancialSnapshot`/`DriverPayoutInfo` fabriquées localement
/// couvrant tous les états requis (pending/held, paid, failed, reversed,
/// empty), sans avoir besoin d'injecter un faux `FinanceRepository`.
class ProviderPayoutsContent extends StatelessWidget {
  final String Function(String) t;
  final List<FinancialSnapshot> snapshots;
  final List<DriverPayoutInfo> payouts;
  const ProviderPayoutsContent({
    super.key,
    required this.t,
    required this.snapshots,
    required this.payouts,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EarningsSummary(t: t, payouts: payouts),
        const SizedBox(height: 28),
        _MissionsSection(t: t, snapshots: snapshots),
        const SizedBox(height: 28),
        _PayoutsListSection(t: t, payouts: payouts),
      ],
    );
  }
}

/// Regroupement en 3 seaux mutuellement exclusifs, non recalculés (chaque
/// montant reste une somme brute de `amountMinor` déjà calculés serveur) :
/// - `pending`  : `pending` + `held` — pas encore éligible au versement.
/// - `available`: `eligible` + `scheduled` + `processing` — prêt ou en
///   cours d'envoi, pas encore confirmé payé.
/// - `paid`     : `paid` — versement confirmé.
/// `failed`/`reversed` sont volontairement EXCLUS de ces 3 totaux (ce ne
/// sont pas des gains actuellement détenus par le chauffeur) mais restent
/// visibles individuellement dans la liste des versements ci-dessous.
class _PayoutBuckets {
  final int pendingMinor;
  final int availableMinor;
  final int paidMinor;
  const _PayoutBuckets({
    required this.pendingMinor,
    required this.availableMinor,
    required this.paidMinor,
  });

  factory _PayoutBuckets.from(List<DriverPayoutInfo> payouts) {
    int pending = 0;
    int available = 0;
    int paid = 0;
    for (final p in payouts) {
      switch (p.status) {
        case PayoutStatus.pending:
        case PayoutStatus.held:
          pending += p.amountMinor;
          break;
        case PayoutStatus.eligible:
        case PayoutStatus.scheduled:
        case PayoutStatus.processing:
          available += p.amountMinor;
          break;
        case PayoutStatus.paid:
          paid += p.amountMinor;
          break;
        case PayoutStatus.failed:
        case PayoutStatus.reversed:
          break;
      }
    }
    return _PayoutBuckets(
      pendingMinor: pending,
      availableMinor: available,
      paidMinor: paid,
    );
  }
}

class _EarningsSummary extends StatelessWidget {
  final String Function(String) t;
  final List<DriverPayoutInfo> payouts;
  const _EarningsSummary({required this.t, required this.payouts});

  @override
  Widget build(BuildContext context) {
    final buckets = _PayoutBuckets.from(payouts);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('payout_summary_title'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: t('payout_summary_available'),
                value: formatMinorAmount(buckets.availableMinor),
                color: AppColors.info,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: t('payout_summary_pending'),
                value: formatMinorAmount(buckets.pendingMinor),
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: t('payout_summary_paid'),
                value: formatMinorAmount(buckets.paidMinor),
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Missions (Bloc K point 4) : montant offert / bonus / pourboire / net —
/// lecture directe de `FinancialSnapshot`, jamais recalculé.
class _MissionsSection extends StatelessWidget {
  final String Function(String) t;
  final List<FinancialSnapshot> snapshots;
  const _MissionsSection({required this.t, required this.snapshots});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('payout_missions_title'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (snapshots.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              t('payout_missions_empty'),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          for (final s in snapshots) _MissionTile(t: t, snapshot: s),
      ],
    );
  }
}

class _MissionTile extends StatelessWidget {
  final String Function(String) t;
  final FinancialSnapshot snapshot;
  const _MissionTile({required this.t, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatDisplayDate(snapshot.createdAt, connector: t('datetime_connector_at')),
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          _AmountRow(
            label: t('payout_mission_offer_amount'),
            value: snapshot.driverOfferAmount,
          ),
          if (snapshot.driverBonus != 0)
            _AmountRow(
              label: t('payout_mission_bonus'),
              value: snapshot.driverBonus,
            ),
          if (snapshot.tipAmount != 0)
            _AmountRow(
              label: t('payout_mission_tip'),
              value: snapshot.tipAmount,
              highlight: true,
            ),
          const Divider(height: 16),
          _AmountRow(
            label: t('payout_mission_net'),
            value: snapshot.driverNetMissionEarnings,
            bold: true,
          ),
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  final bool highlight;
  const _AmountRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 14 : 13,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      color: highlight
          ? AppColors.success
          : (bold ? AppColors.textPrimary : AppColors.textSecondary),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(
            formatMajorAmount(value),
            style: style.copyWith(
              color: bold ? AppColors.textPrimary : style.color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Versements (Bloc K point 4/5/8/9) : montant, statut, dates, période de
/// rétention, échec/reversal reformulés — lecture directe de
/// `DriverPayoutInfo`, jamais recalculé.
class _PayoutsListSection extends StatelessWidget {
  final String Function(String) t;
  final List<DriverPayoutInfo> payouts;
  const _PayoutsListSection({required this.t, required this.payouts});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('payout_list_title'),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (payouts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              t('payout_list_empty'),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          for (final p in payouts) _PayoutTile(t: t, payout: p),
      ],
    );
  }
}

class _PayoutTile extends StatelessWidget {
  final String Function(String) t;
  final DriverPayoutInfo payout;
  const _PayoutTile({required this.t, required this.payout});

  Color _statusColor(PayoutStatus status) {
    switch (status) {
      case PayoutStatus.paid:
        return AppColors.success;
      case PayoutStatus.eligible:
      case PayoutStatus.scheduled:
      case PayoutStatus.processing:
        return AppColors.info;
      case PayoutStatus.pending:
      case PayoutStatus.held:
        return AppColors.warning;
      case PayoutStatus.failed:
      case PayoutStatus.reversed:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(payout.status);
    // "En attente/retenue" : n'affiche la date d'éligibilité que tant que
    // le versement n'est pas encore terminal (paid/failed/reversed) — voir
    // Bloc K point 8, toujours la date SERVEUR, jamais un recalcul depuis
    // payoutHoldPeriodHours.
    final showHoldInfo = !payout.isTerminal;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatMinorAmount(payout.amountMinor),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  t(payout.status.i18nKey),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _DetailRow(
            label: t('payout_created_at'),
            value: formatDisplayDate(payout.createdAt, connector: t('datetime_connector_at')),
          ),
          if (showHoldInfo) ...[
            _DetailRow(
              label: t('payout_hold_period'),
              value:
                  '${payout.payoutHoldPeriodHours} ${t('payout_hours_suffix')}',
            ),
            _DetailRow(
              label: t('payout_eligible_at'),
              value: formatDisplayDate(payout.payoutEligibleAt, connector: t('datetime_connector_at')),
            ),
          ],
          if (payout.isPaid && payout.paidAt != null)
            _DetailRow(
              label: t('payout_paid_at'),
              value: formatDisplayDate(payout.paidAt!, connector: t('datetime_connector_at')),
            ),
          if (payout.isHeld || payout.isPending) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${t('payout_held_message')} ${formatDisplayDate(payout.payoutEligibleAt, connector: t('datetime_connector_at'))}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
          if (payout.isFailed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              // Message reformulé générique : aucun code provider brut
              // n'est jamais affiché au chauffeur (Bloc K point 9), même
              // si `failureReason` contient un détail technique serveur.
              child: Text(
                t('payout_failed_message'),
                style: const TextStyle(fontSize: 12, color: AppColors.error),
              ),
            ),
          ],
          if (payout.isReversed) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('payout_reversed_message'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.error,
                    ),
                  ),
                  if (payout.reversalReason != null &&
                      payout.reversalReason!.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${t('payout_reversal_reason')} : ${payout.reversalReason}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
