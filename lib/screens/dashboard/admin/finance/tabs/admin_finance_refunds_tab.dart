// ---------------------------------------------------------------------------
// AdminFinanceRefundsTab — Bloc L, section 2/8 "Refunds".
//
// Toutes les actions passent EXCLUSIVEMENT par la Cloud Function
// `refundPayment` via `FinanceRepository.adminRefundPayment()` — jamais
// d'écriture Firestore directe (voir `NotConfiguredFinanceRepository` /
// `FirebaseFinanceRepository`, qui n'exposent d'ailleurs aucune méthode de
// `set`/`update` pour `refunds/*`).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../backend/backend_locator.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../finance/models/refund_info.dart';
import '../../../../../finance/presentation/money_format.dart';
import '../../../../../models/enums.dart';
import '../../../../../providers/locale_provider.dart';
import '../finance_ui_helpers.dart';

const List<RefundStatus?> _kRefundFilters = [
  null,
  RefundStatus.requested,
  RefundStatus.processing,
  RefundStatus.succeeded,
  RefundStatus.failed,
];

class AdminFinanceRefundsTab extends StatefulWidget {
  const AdminFinanceRefundsTab({super.key});

  @override
  State<AdminFinanceRefundsTab> createState() => _AdminFinanceRefundsTabState();
}

class _AdminFinanceRefundsTabState extends State<AdminFinanceRefundsTab> {
  RefundStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final repo = BackendLocator.financeRepository;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('admin_finance_tab_refunds'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kRefundFilters.map((f) {
              final selected = f == _filter;
              return ChoiceChip(
                label: Text(
                  f == null
                      ? t('admin_finance_filter_all')
                      : t(refundStatusKey(f)),
                ),
                selected: selected,
                onSelected: (_) => setState(() => _filter = f),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<RefundInfo>>(
            stream: repo.watchRefunds(status: _filter, limit: 50),
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
              final refunds = snapshot.data ?? const <RefundInfo>[];
              if (refunds.isEmpty) {
                return FinanceEmptyState(message: t('admin_finance_empty'));
              }
              final sorted = [...refunds]
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              return Column(
                children: sorted
                    .map((r) => _RefundRow(refund: r, t: t))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RefundRow extends StatelessWidget {
  final RefundInfo refund;
  final String Function(String) t;
  const _RefundRow({required this.refund, required this.t});

  @override
  Widget build(BuildContext context) {
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
                  '${t('admin_refunds_col_id')}: ${refund.refundId}',
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
                      icon: Icons.payment_outlined,
                      label:
                          '${t('admin_refunds_col_payment')}: ${refund.paymentId}',
                    ),
                    MetaChip(
                      icon: Icons.local_shipping_outlined,
                      label: refund.missionId,
                    ),
                    MetaChip(
                      icon: Icons.info_outline,
                      label: t(refundReasonKey(refund.reason)),
                    ),
                    MetaChip(
                      icon: Icons.event_outlined,
                      label:
                          '${t('admin_refunds_col_requested_at')}: ${formatShortDate(refund.createdAt)}',
                    ),
                    if (refund.completedAt != null)
                      MetaChip(
                        icon: Icons.event_available_outlined,
                        label:
                            '${t('admin_refunds_col_processed_at')}: ${formatShortDate(refund.completedAt)}',
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
                formatMinorAmount(refund.amountMinor),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              StatusBadge(
                label: t(refundStatusKey(refund.status)),
                color: refundStatusColor(refund.status),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
