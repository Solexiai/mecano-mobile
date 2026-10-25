import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../backend/backend_locator.dart';
import '../../../../core/app_colors.dart';
import '../../../../backend/models/delivery_mission.dart';
import '../../../../backend/repositories/driver_agenda_repository.dart';
import '../../../../finance/models/transaction_ledger.dart';
import '../../../../finance/presentation/driver_display_format.dart';
import '../../../../finance/presentation/driver_earnings_totals.dart';
import '../../../../models/enums.dart';
import '../../../../providers/firebase_auth_provider.dart';
import '../../../../providers/locale_provider.dart';
import 'provider_payouts_section.dart';

/// Onglet "Revenus" du fournisseur (chauffeur).
///
/// Données 100% réelles et LECTURE SEULE : chaque entrée provient de
/// `transaction_ledger` (append-only, jamais modifiable côté client) via
/// `FinanceRepository.watchDriverEarningsHistory()`. Les totaux affichés
/// sont une simple agrégation en mémoire des entrées déjà confirmées —
/// aucune transaction historique n'est recalculée ici.
///
/// Ordre (25 octobre 2026) : gains de la semaine / du mois / total, puis
/// les versements, puis l'historique. Chaque ligne d'historique est nommée
/// (livraison et trajet, ou frais d'annulation) au lieu d'un libellé
/// générique.
class ProviderEarningsTab extends StatelessWidget {
  const ProviderEarningsTab({super.key, this.missions});

  /// Missions du chauffeur, pour nommer les lignes (trajet). Injection pour
  /// les tests ; par défaut, les missions attribuées au chauffeur.
  final Stream<List<DeliveryMission>>? missions;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FirebaseAuthProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final t = localeProvider.t;
    final locale = localeProvider.locale;

    if (!auth.isSignedIn || auth.user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            t('delivery_login_required'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final driverId = auth.user!.uid;

    return _EarningsBody(
      driverId: driverId,
      t: t,
      locale: locale,
      missions: missions,
    );
  }
}

class _EarningsBody extends StatefulWidget {
  const _EarningsBody({
    required this.driverId,
    required this.t,
    required this.locale,
    required this.missions,
  });
  final String driverId;
  final String Function(String) t;
  final String locale;
  final Stream<List<DeliveryMission>>? missions;

  @override
  State<_EarningsBody> createState() => _EarningsBodyState();
}

class _EarningsBodyState extends State<_EarningsBody> {
  // Streams created once per driver, never in build() (a new stream on each
  // rebuild would flicker back to the loading state).
  String? _driverId;
  late Stream<List<LedgerEntry>> _ledger;
  late Stream<List<DeliveryMission>> _missions;

  void _ensureStreams() {
    if (_driverId == widget.driverId) return;
    _driverId = widget.driverId;
    _ledger = BackendLocator.financeRepository.watchDriverEarningsHistory(
      widget.driverId,
    );
    _missions =
        widget.missions ??
        driverAgendaRepository(widget.driverId).watchMissions();
  }

  @override
  Widget build(BuildContext context) {
    _ensureStreams();
    final t = widget.t;
    final locale = widget.locale;
    // Missions (for route labels) are listened once, around everything, so
    // the single-subscription stream is never subscribed twice.
    return StreamBuilder<List<DeliveryMission>>(
      stream: _missions,
      builder: (context, missionsSnap) {
        final byId = <String, DeliveryMission>{
          for (final m in missionsSnap.data ?? const <DeliveryMission>[])
            m.id: m,
        };
        return _ledgerView(t, locale, byId);
      },
    );
  }

  Widget _ledgerView(
    String Function(String) t,
    String locale,
    Map<String, DeliveryMission> byId,
  ) {
    return StreamBuilder<List<LedgerEntry>>(
      stream: _ledger,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    t('earnings_loading'),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(t('earnings_error'), textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }

        final entries = snapshot.data ?? const <LedgerEntry>[];
        final totals = DriverEarningsTotals.from(entries, DateTime.now());

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('earnings_title'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MetricCard(
                    label: t('earnings_week_label'),
                    value: driverMoney(totals.week, locale),
                    color: AppColors.primary,
                  ),
                  _MetricCard(
                    label: t('earnings_month_label'),
                    value: driverMoney(totals.month, locale),
                    color: AppColors.primary,
                  ),
                  _MetricCard(
                    label: t('earnings_total_label'),
                    value: driverMoney(totals.total, locale),
                    color: AppColors.primary,
                  ),
                  if (totals.pending != 0)
                    _MetricCard(
                      label: t('earnings_pending_label'),
                      value: driverMoney(totals.pending, locale),
                      color: AppColors.warning,
                    ),
                ],
              ),
              const SizedBox(height: 28),
              // Versements : ce qui est prêt, en attente et déjà versé
              // (résumé et liste). Le détail par mission est dans
              // l'historique ci-dessous, une seule fois.
              ProviderPayoutsSection(
                driverId: widget.driverId,
                t: t,
                locale: locale,
                showMissions: false,
              ),
              const SizedBox(height: 28),
              Text(
                t('earnings_history_title'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      t('earnings_empty'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ...entries.map(
                  (e) => _LedgerTile(
                    entry: e,
                    mission: e.missionId == null ? null : byId[e.missionId],
                    t: t,
                    locale: locale,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  final LedgerEntry entry;
  final DeliveryMission? mission;
  final String Function(String) t;
  final String locale;
  const _LedgerTile({
    required this.entry,
    required this.mission,
    required this.t,
    required this.locale,
  });

  /// « Livraison · Granby → Bromont », « Frais d'annulation tardive (votre
  /// part) », ou le libellé du type d'écriture.
  String _title() {
    switch (entry.feeKind) {
      case 'late_cancellation':
        return t('earnings_line_late_cancellation');
      case 'customer_failed_delivery':
        return t('earnings_line_failed_delivery');
    }
    if (entry.type == LedgerEntryType.driverEarning) {
      final from = mission?.pickupAddress?.city.trim() ?? '';
      final to = mission?.dropoffAddress?.city.trim() ?? '';
      final base = t('ledger_type_driver_earning');
      if (from.isNotEmpty && to.isNotEmpty) return '$base · $from → $to';
      return base;
    }
    return t(_typeKey(entry.type));
  }

  String _typeKey(LedgerEntryType type) {
    switch (type) {
      case LedgerEntryType.driverEarning:
        return 'ledger_type_driver_earning';
      case LedgerEntryType.driverTip:
        return 'ledger_type_driver_tip';
      case LedgerEntryType.driverBonus:
        return 'ledger_type_driver_bonus';
      case LedgerEntryType.driverPayout:
        return 'ledger_type_driver_payout';
      case LedgerEntryType.driverAdjustment:
        return 'ledger_type_driver_adjustment';
      case LedgerEntryType.refund:
        return 'ledger_type_refund';
      case LedgerEntryType.partialRefund:
        return 'ledger_type_partial_refund';
      case LedgerEntryType.chargeback:
        return 'ledger_type_chargeback';
      default:
        return 'ledger_type_driver_adjustment';
    }
  }

  String _statusKey(LedgerEntryStatus status) {
    switch (status) {
      case LedgerEntryStatus.pending:
        return 'earnings_status_pending';
      case LedgerEntryStatus.confirmed:
        return 'earnings_status_confirmed';
      case LedgerEntryStatus.reversed:
        return 'earnings_status_reversed';
      case LedgerEntryStatus.compensated:
        return 'earnings_status_compensated';
    }
  }

  Color _statusColor(LedgerEntryStatus status) {
    switch (status) {
      case LedgerEntryStatus.confirmed:
        return AppColors.success;
      case LedgerEntryStatus.pending:
        return AppColors.warning;
      case LedgerEntryStatus.reversed:
      case LedgerEntryStatus.compensated:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = entry.direction == LedgerDirection.credit;
    final signedAmount = isCredit ? entry.amount : -entry.amount;
    final color = _statusColor(entry.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            color: isCredit ? AppColors.success : AppColors.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  driverShortDate(entry.createdAt, locale),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isCredit ? '+' : '−'}${driverMoney(signedAmount.abs(), locale)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: isCredit ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  t(_statusKey(entry.status)),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.statusBadgeTextColor(
                      color,
                      Theme.of(context).brightness,
                    ),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
