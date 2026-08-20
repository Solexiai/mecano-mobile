// ---------------------------------------------------------------------------
// AdminPaymentDetailScreen — Bloc L, drill-down d'un paiement.
//
// Affiche : le paiement (statuts/montants/dates/identifiants provider
// PUBLICS uniquement), la mission liée, le snapshot financier
// (`mission_financial_balance`), les remboursements associés, le ledger
// pertinent et les litiges associés à ce paiement. AUCUNE donnée Stripe
// sensible (clé secrète, webhook secret, CVC, token) — le modèle
// `PaymentInfo` n'expose que des identifiants publics.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../backend/backend_locator.dart';
import '../../../../../backend/models/delivery_mission.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../finance/models/dispute_info.dart';
import '../../../../../finance/models/mission_financial_balance.dart';
import '../../../../../finance/models/payment_info.dart';
import '../../../../../finance/models/refund_info.dart';
import '../../../../../finance/models/transaction_ledger.dart';
import '../../../../../finance/presentation/money_format.dart';
import '../../../../../models/enums.dart';
import '../../../../../providers/locale_provider.dart';
import '../finance_ui_helpers.dart';

class AdminPaymentDetailScreen extends StatelessWidget {
  final String paymentId;
  const AdminPaymentDetailScreen({super.key, required this.paymentId});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final repo = BackendLocator.financeRepository;

    return Scaffold(
      appBar: AppBar(title: Text('${t('admin_payments_col_id')}: $paymentId')),
      body: StreamBuilder<List<PaymentInfo>>(
        stream: repo.watchPayments(limit: 50),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return FinanceLoadingState(message: t('admin_finance_loading'));
          }
          if (snapshot.hasError) {
            return FinanceErrorState(
              message: t('admin_finance_error'),
              retryLabel: t('admin_finance_retry'),
              onRetry: () {},
            );
          }
          final payment = (snapshot.data ?? const <PaymentInfo>[])
              .where((p) => p.paymentId == paymentId)
              .cast<PaymentInfo?>()
              .firstOrNull;

          if (payment == null) {
            return FinanceEmptyState(message: t('admin_finance_empty'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PaymentSummaryCard(payment: payment, t: t),
                const SizedBox(height: 20),
                _SectionTitle(t('admin_ledger_col_mission')),
                _MissionCard(missionId: payment.missionId, t: t),
                const SizedBox(height: 20),
                _SectionTitle(t('admin_finance_tab_payments')),
                _FinancialSnapshotCard(missionId: payment.missionId, t: t),
                const SizedBox(height: 20),
                _SectionTitle(t('admin_finance_tab_refunds')),
                _RefundsSection(missionId: payment.missionId, t: t),
                const SizedBox(height: 20),
                _SectionTitle(t('admin_finance_tab_ledger')),
                _LedgerSection(missionId: payment.missionId, t: t),
                const SizedBox(height: 20),
                _SectionTitle(t('admin_finance_tab_disputes')),
                _DisputesSection(paymentId: payment.paymentId, t: t),
              ],
            ),
          );
        },
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _PaymentSummaryCard extends StatelessWidget {
  final PaymentInfo payment;
  final String Function(String) t;
  const _PaymentSummaryCard({required this.payment, required this.t});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  payment.paymentId,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusBadge(
                label: t(paymentStatusKey(payment.status)),
                color: paymentStatusColor(payment.status),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              MetaChip(
                icon: Icons.local_shipping_outlined,
                label:
                    '${t('admin_payments_col_mission')}: ${payment.missionId}',
              ),
              MetaChip(
                icon: Icons.person_outline,
                label:
                    '${t('admin_payments_col_customer')}: ${payment.customerId}',
              ),
              MetaChip(
                icon: Icons.event_outlined,
                label:
                    '${t('admin_payments_col_date')}: ${formatDisplayDate(payment.createdAt)}',
              ),
              if (payment.provider.isNotEmpty)
                MetaChip(
                  icon: Icons.credit_card_outlined,
                  label:
                      '${t('admin_payments_col_provider')}: ${payment.provider}',
                ),
            ],
          ),
          const Divider(height: 28),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _AmountBlock(
                label: t('admin_payments_col_authorized'),
                minor: payment.amountAuthorizedMinor,
              ),
              _AmountBlock(
                label: t('admin_payments_col_captured'),
                minor: payment.amountCapturedMinor,
              ),
              _AmountBlock(
                label: t('admin_payments_col_refunded'),
                minor: payment.amountRefundedMinor,
              ),
            ],
          ),
          if (payment.failureMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              payment.failureMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 12.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _AmountBlock extends StatelessWidget {
  final String label;
  final int minor;
  const _AmountBlock({required this.label, required this.minor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        Text(
          formatMinorAmount(minor),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _MissionCard extends StatelessWidget {
  final String missionId;
  final String Function(String) t;
  const _MissionCard({required this.missionId, required this.t});

  @override
  Widget build(BuildContext context) {
    if (missionId.isEmpty) {
      return FinanceEmptyState(message: t('admin_finance_empty'));
    }
    return StreamBuilder<DeliveryMission?>(
      stream: BackendLocator.missionRepository.watchMission(missionId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return FinanceLoadingState(message: t('admin_finance_loading'));
        }
        final mission = snapshot.data;
        if (mission == null) {
          return FinanceEmptyState(message: t('admin_finance_empty'));
        }
        return _Card(
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              MetaChip(icon: Icons.tag, label: mission.id),
              MetaChip(
                icon: Icons.category_outlined,
                label: t(mission.itemCategoryKey),
              ),
              MetaChip(icon: Icons.flag_outlined, label: t(mission.status.key)),
              if (mission.driverDisplayName != null)
                MetaChip(
                  icon: Icons.local_shipping_outlined,
                  label: mission.driverDisplayName!,
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FinancialSnapshotCard extends StatelessWidget {
  final String missionId;
  final String Function(String) t;
  const _FinancialSnapshotCard({required this.missionId, required this.t});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<MissionFinancialBalance?>(
      stream: BackendLocator.financeRepository.watchMissionFinancialBalance(
        missionId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return FinanceLoadingState(message: t('admin_finance_loading'));
        }
        final balance = snapshot.data;
        if (balance == null) {
          return FinanceEmptyState(message: t('admin_finance_empty'));
        }
        return _Card(
          child: Wrap(
            spacing: 20,
            runSpacing: 10,
            children: [
              _AmountBlock(
                label: t('admin_payments_col_customer'),
                minor: balance.customerCharged,
              ),
              _AmountBlock(
                label: t('admin_payments_col_refunded'),
                minor: balance.customerRefunded,
              ),
              _AmountBlock(
                label: t('admin_ledger_col_amount'),
                minor: balance.outstandingCustomerBalance,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RefundsSection extends StatelessWidget {
  final String missionId;
  final String Function(String) t;
  const _RefundsSection({required this.missionId, required this.t});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RefundInfo>>(
      stream: BackendLocator.financeRepository.watchRefundsForMission(
        missionId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return FinanceLoadingState(message: t('admin_finance_loading'));
        }
        final refunds = snapshot.data ?? const <RefundInfo>[];
        if (refunds.isEmpty) {
          return FinanceEmptyState(message: t('admin_finance_empty'));
        }
        return Column(
          children: refunds
              .map(
                (r) => _Card(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 0),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        MetaChip(
                          icon: Icons.receipt_outlined,
                          label: r.refundId,
                        ),
                        MetaChip(
                          icon: Icons.event_outlined,
                          label: formatShortDate(r.displayDate),
                        ),
                        MetaChip(
                          icon: Icons.info_outline,
                          label: t(refundReasonKey(r.reason)),
                        ),
                        StatusBadge(
                          label: t(refundStatusKey(r.status)),
                          color: refundStatusColor(r.status),
                        ),
                        Text(
                          formatMinorAmount(r.amountMinor),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList()
              .expand((w) => [w, const SizedBox(height: 10)])
              .toList(),
        );
      },
    );
  }
}

class _LedgerSection extends StatelessWidget {
  final String missionId;
  final String Function(String) t;
  const _LedgerSection({required this.missionId, required this.t});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LedgerEntry>>(
      stream: BackendLocator.financeRepository.watchLedgerEntriesForMission(
        missionId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return FinanceLoadingState(message: t('admin_finance_loading'));
        }
        final entries = snapshot.data ?? const <LedgerEntry>[];
        if (entries.isEmpty) {
          return FinanceEmptyState(message: t('admin_finance_empty'));
        }
        final sorted = [...entries]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return Column(
          children: sorted
              .map(
                (e) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: _Card(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        MetaChip(
                          icon: Icons.event_outlined,
                          label: formatShortDate(e.createdAt),
                        ),
                        MetaChip(
                          icon: Icons.category_outlined,
                          label: t(ledgerTypeKey(e.type)),
                        ),
                        MetaChip(
                          icon: Icons.person_outline,
                          label: t(ledgerPartyKey(e.party)),
                        ),
                        Text(
                          formatMajorAmount(e.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: ledgerDirectionColor(e.direction),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _DisputesSection extends StatelessWidget {
  final String paymentId;
  final String Function(String) t;
  const _DisputesSection({required this.paymentId, required this.t});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DisputeInfo>>(
      stream: BackendLocator.financeRepository.watchDisputes(limit: 100),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return FinanceLoadingState(message: t('admin_finance_loading'));
        }
        final disputes = (snapshot.data ?? const <DisputeInfo>[])
            .where((d) => d.paymentId == paymentId)
            .toList();
        if (disputes.isEmpty) {
          return FinanceEmptyState(message: t('admin_finance_empty'));
        }
        return Column(
          children: disputes
              .map(
                (d) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: _Card(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        MetaChip(
                          icon: Icons.gavel_outlined,
                          label: d.disputeId,
                        ),
                        MetaChip(
                          icon: Icons.event_outlined,
                          label: formatShortDate(d.createdAt),
                        ),
                        StatusBadge(
                          label: t(disputeStatusKey(d.status)),
                          color: disputeStatusColor(d.status),
                        ),
                        Text(
                          formatMinorAmount(d.amountMinor),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
