import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../backend/backend_locator.dart';
import '../../../../core/app_colors.dart';
import '../../../../finance/models/transaction_ledger.dart';
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
class ProviderEarningsTab extends StatelessWidget {
  const ProviderEarningsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FirebaseAuthProvider>();
    final t = context.watch<LocaleProvider>().t;

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

    return StreamBuilder<List<LedgerEntry>>(
      stream: BackendLocator.financeRepository.watchDriverEarningsHistory(
        driverId,
      ),
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

        double confirmedTotal = 0;
        double pendingTotal = 0;
        for (final e in entries) {
          final signed = e.direction == LedgerDirection.credit
              ? e.amount
              : -e.amount;
          if (e.status == LedgerEntryStatus.confirmed) {
            confirmedTotal += signed;
          } else if (e.status == LedgerEntryStatus.pending) {
            pendingTotal += signed;
          }
        }

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
              const SizedBox(height: 20),
              // Bloc K — vue financière chauffeur (résumé versements,
              // missions détaillées, historique de versements). Enrichit
              // cet onglet Revenus existant plutôt que de créer un écran
              // dupliqué (voir décision technique dans
              // provider_payouts_section.dart).
              ProviderPayoutsSection(driverId: driverId, t: t),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: t('earnings_total_label'),
                      value: '${confirmedTotal.toStringAsFixed(2)}\$',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _MetricCard(
                      label: t('earnings_pending_label'),
                      value: '${pendingTotal.toStringAsFixed(2)}\$',
                      color: AppColors.warning,
                    ),
                  ),
                ],
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
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ...entries.map((e) => _LedgerTile(entry: e, t: t)),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
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
  final String Function(String) t;
  const _LedgerTile({required this.entry, required this.t});

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
                  t(_typeKey(entry.type)),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${entry.createdAt.year}-${entry.createdAt.month.toString().padLeft(2, '0')}-${entry.createdAt.day.toString().padLeft(2, '0')}',
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
                '${isCredit ? '+' : '-'}${signedAmount.abs().toStringAsFixed(2)}\$',
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
                    color: color,
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
