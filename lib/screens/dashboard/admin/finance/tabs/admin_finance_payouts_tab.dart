// ---------------------------------------------------------------------------
// AdminFinancePayoutsTab — Bloc L, section 3/8 "Payouts".
//
// L'action "reverse" (annulation d'un versement déjà payé) est
// EXCLUSIVEMENT réservée admin/super_admin (voir directive Bloc L :
// "actions sensibles backend-only") et passe par
// `FinanceRepository.adminReverseDriverPayout()` -> Cloud Function
// `reverseDriverPayout`, jamais une écriture Firestore directe.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../backend/backend_locator.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../finance/models/driver_payout_info.dart';
import '../../../../../finance/presentation/money_format.dart';
import '../../../../../models/enums.dart';
import '../../../../../providers/firebase_auth_provider.dart';
import '../../../../../providers/locale_provider.dart';
import '../finance_ui_helpers.dart';

const List<PayoutStatus?> _kPayoutFilters = [
  null,
  PayoutStatus.held,
  PayoutStatus.eligible,
  PayoutStatus.scheduled,
  PayoutStatus.processing,
  PayoutStatus.paid,
  PayoutStatus.failed,
  PayoutStatus.reversed,
];

class AdminFinancePayoutsTab extends StatefulWidget {
  const AdminFinancePayoutsTab({super.key});

  @override
  State<AdminFinancePayoutsTab> createState() => _AdminFinancePayoutsTabState();
}

class _AdminFinancePayoutsTabState extends State<AdminFinancePayoutsTab> {
  PayoutStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final auth = context.watch<FirebaseAuthProvider>();
    final repo = BackendLocator.financeRepository;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('admin_finance_tab_payouts'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kPayoutFilters.map((f) {
              final selected = f == _filter;
              return ChoiceChip(
                label: Text(
                  f == null
                      ? t('admin_finance_filter_all')
                      : t(payoutStatusKey(f)),
                ),
                selected: selected,
                onSelected: (_) => setState(() => _filter = f),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<DriverPayoutInfo>>(
            stream: repo.watchDriverPayouts(status: _filter, limit: 50),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return FinanceLoadingState(message: t('admin_finance_loading'));
              }
              if (snapshot.hasError) {
                return FinanceErrorState(
                  message: t('admin_finance_error'),
                  retryLabel: t('admin_finance_retry'),
                  onRetry: () => setState(() {}),
                );
              }
              final payouts = snapshot.data ?? const <DriverPayoutInfo>[];
              if (payouts.isEmpty) {
                return FinanceEmptyState(message: t('admin_finance_empty'));
              }
              final sorted = [...payouts]
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              return Column(
                children: sorted
                    .map(
                      (p) => _PayoutRow(
                        payout: p,
                        t: t,
                        canReverse: auth.isAdminOrAbove,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PayoutRow extends StatefulWidget {
  final DriverPayoutInfo payout;
  final String Function(String) t;
  final bool canReverse;
  const _PayoutRow({
    required this.payout,
    required this.t,
    required this.canReverse,
  });

  @override
  State<_PayoutRow> createState() => _PayoutRowState();
}

class _PayoutRowState extends State<_PayoutRow> {
  bool _busy = false;

  Future<void> _reverse() async {
    final t = widget.t;
    final reasonController = TextEditingController();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('admin_payouts_col_reversed_at')),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(
            labelText: t('admin_disputes_col_reason'),
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, reasonController.text.trim()),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed == null || confirmed.isEmpty) return;
    setState(() => _busy = true);
    try {
      await BackendLocator.financeRepository.adminReverseDriverPayout(
        payoutId: widget.payout.payoutId,
        reason: confirmed,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('admin_payout_policy_save_success'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final payout = widget.payout;
    final t = widget.t;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t('admin_payouts_col_id')}: ${payout.payoutId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    MetaChip(
                      icon: Icons.person_outline,
                      label:
                          '${t('admin_payouts_col_driver')}: ${payout.driverId}',
                    ),
                    MetaChip(
                      icon: Icons.schedule_outlined,
                      label:
                          '${t('admin_payouts_col_hold')}: ${payout.payoutHoldPeriodHours}h',
                    ),
                    MetaChip(
                      icon: Icons.event_available_outlined,
                      label:
                          '${t('admin_payouts_col_eligible_at')}: ${formatShortDate(payout.payoutEligibleAt)}',
                    ),
                    if (payout.providerPayoutId != null)
                      MetaChip(
                        icon: Icons.confirmation_number_outlined,
                        label:
                            '${t('admin_payouts_col_provider_id')}: ${payout.providerPayoutId}',
                      ),
                    if (payout.paidAt != null)
                      MetaChip(
                        icon: Icons.check_circle_outline,
                        label:
                            '${t('admin_payouts_col_paid_at')}: ${formatShortDate(payout.paidAt)}',
                      ),
                    if (payout.failedAt != null)
                      MetaChip(
                        icon: Icons.error_outline,
                        label:
                            '${t('admin_payouts_col_failed_at')}: ${formatShortDate(payout.failedAt)}',
                      ),
                    if (payout.reversedAt != null)
                      MetaChip(
                        icon: Icons.undo,
                        label:
                            '${t('admin_payouts_col_reversed_at')}: ${formatShortDate(payout.reversedAt)}',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatMinorAmount(payout.amountMinor),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              StatusBadge(
                label: t(payoutStatusKey(payout.status)),
                color: payoutStatusColor(payout.status),
              ),
              if (widget.canReverse && payout.isPaid) ...[
                const SizedBox(height: 8),
                _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : OutlinedButton(
                        onPressed: _reverse,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                        child: const Text(
                          'Reverse',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
