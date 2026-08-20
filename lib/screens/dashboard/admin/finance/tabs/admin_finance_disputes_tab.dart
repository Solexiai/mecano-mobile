// ---------------------------------------------------------------------------
// AdminFinanceDisputesTab — Bloc L, section 4/8 "Disputes".
//
// Utilise uniquement les champs déjà existants sur `DisputeInfo` (voir
// note d'en-tête du modèle : `provider_metadata` volontairement exclu).
// La mise à jour de statut passe par `adminUpdateDisputeStatus` ->
// Cloud Function `updateDisputeStatus`, jamais d'écriture directe.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../backend/backend_locator.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../finance/models/dispute_info.dart';
import '../../../../../finance/presentation/money_format.dart';
import '../../../../../models/enums.dart';
import '../../../../../providers/locale_provider.dart';
import '../finance_ui_helpers.dart';

const List<DisputeStatus?> _kDisputeFilters = [
  null,
  DisputeStatus.opened,
  DisputeStatus.underReview,
  DisputeStatus.won,
  DisputeStatus.lost,
  DisputeStatus.reversed,
  DisputeStatus.closed,
];

class AdminFinanceDisputesTab extends StatefulWidget {
  const AdminFinanceDisputesTab({super.key});

  @override
  State<AdminFinanceDisputesTab> createState() =>
      _AdminFinanceDisputesTabState();
}

class _AdminFinanceDisputesTabState extends State<AdminFinanceDisputesTab> {
  DisputeStatus? _filter;

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
            t('admin_finance_tab_disputes'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kDisputeFilters.map((f) {
              final selected = f == _filter;
              return ChoiceChip(
                label: Text(
                  f == null
                      ? t('admin_finance_filter_all')
                      : t(disputeStatusKey(f)),
                ),
                selected: selected,
                onSelected: (_) => setState(() => _filter = f),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<DisputeInfo>>(
            stream: repo.watchDisputes(status: _filter, limit: 50),
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
              final disputes = snapshot.data ?? const <DisputeInfo>[];
              if (disputes.isEmpty) {
                return FinanceEmptyState(message: t('admin_finance_empty'));
              }
              final sorted = [...disputes]
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              return Column(
                children: sorted
                    .map((d) => _DisputeRow(dispute: d, t: t))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DisputeRow extends StatelessWidget {
  final DisputeInfo dispute;
  final String Function(String) t;
  const _DisputeRow({required this.dispute, required this.t});

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
                  '${t('admin_disputes_col_id')}: ${dispute.disputeId}',
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
                      icon: Icons.local_shipping_outlined,
                      label:
                          '${t('admin_disputes_col_mission')}: ${dispute.missionId}',
                    ),
                    MetaChip(
                      icon: Icons.payment_outlined,
                      label:
                          '${t('admin_disputes_col_payment')}: ${dispute.paymentId}',
                    ),
                    if (dispute.reason.isNotEmpty)
                      MetaChip(
                        icon: Icons.info_outline,
                        label:
                            '${t('admin_disputes_col_reason')}: ${dispute.reason}',
                      ),
                    MetaChip(
                      icon: Icons.event_outlined,
                      label:
                          '${t('admin_disputes_col_opened_at')}: ${formatShortDate(dispute.createdAt)}',
                    ),
                    if (dispute.evidenceDueAt != null)
                      MetaChip(
                        icon: Icons.hourglass_bottom_outlined,
                        label:
                            '${t('admin_disputes_col_evidence_due')}: ${formatShortDate(dispute.evidenceDueAt)}',
                      ),
                    MetaChip(
                      icon: Icons.update_outlined,
                      label:
                          '${t('admin_disputes_col_updated_at')}: ${formatShortDate(dispute.updatedAt)}',
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
                formatMinorAmount(dispute.amountMinor),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              StatusBadge(
                label: t(disputeStatusKey(dispute.status)),
                color: disputeStatusColor(dispute.status),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
