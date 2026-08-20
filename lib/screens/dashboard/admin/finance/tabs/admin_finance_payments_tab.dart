// ---------------------------------------------------------------------------
// AdminFinancePaymentsTab — Bloc L, section 1/8 "Payments".
//
// Connectée à `FinanceRepository.watchPayments()` (Firestore réel, borné,
// jamais de scan complet). Filtres statut/mission/client/date en mémoire
// après réception du flux (le flux serveur est déjà borné par `limit`).
// Aucune donnée Stripe sensible affichée (voir `PaymentInfo` — les champs
// `provider_*` exposés ici sont des IDENTIFIANTS publics Stripe, jamais des
// secrets/clés/CVC).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../backend/backend_locator.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../finance/models/payment_info.dart';
import '../../../../../finance/presentation/money_format.dart';
import '../../../../../models/enums.dart';
import '../../../../../providers/locale_provider.dart';
import '../finance_ui_helpers.dart';
import 'admin_payment_detail_screen.dart';

const List<PaymentStatus?> _kPaymentFilters = [
  null,
  PaymentStatus.authorized,
  PaymentStatus.captured,
  PaymentStatus.refunded,
  PaymentStatus.partiallyRefunded,
  PaymentStatus.failed,
  PaymentStatus.disputed,
];

class AdminFinancePaymentsTab extends StatefulWidget {
  const AdminFinancePaymentsTab({super.key});

  @override
  State<AdminFinancePaymentsTab> createState() =>
      _AdminFinancePaymentsTabState();
}

class _AdminFinancePaymentsTabState extends State<AdminFinancePaymentsTab> {
  PaymentStatus? _statusFilter;
  String _missionQuery = '';
  String _customerQuery = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;

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
            t('admin_finance_tab_payments'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            t('admin_finance_no_sensitive_data'),
            style: const TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kPaymentFilters.map((f) {
              final selected = f == _statusFilter;
              return ChoiceChip(
                label: Text(
                  f == null
                      ? t('admin_finance_filter_all')
                      : t(paymentStatusKey(f)),
                ),
                selected: selected,
                onSelected: (_) => setState(() => _statusFilter = f),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: t('admin_finance_filter_mission'),
                    prefixIcon: const Icon(
                      Icons.local_shipping_outlined,
                      size: 18,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _missionQuery = v.trim()),
                ),
              ),
              SizedBox(
                width: 220,
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: t('admin_finance_filter_customer'),
                    prefixIcon: const Icon(Icons.person_outline, size: 18),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _customerQuery = v.trim()),
                ),
              ),
              _DateFilterButton(
                label: t('admin_finance_filter_date_from'),
                value: _dateFrom,
                onPick: (d) => setState(() => _dateFrom = d),
              ),
              _DateFilterButton(
                label: t('admin_finance_filter_date_to'),
                value: _dateTo,
                onPick: (d) => setState(() => _dateTo = d),
              ),
              if (_missionQuery.isNotEmpty ||
                  _customerQuery.isNotEmpty ||
                  _dateFrom != null ||
                  _dateTo != null)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _missionQuery = '';
                    _customerQuery = '';
                    _dateFrom = null;
                    _dateTo = null;
                  }),
                  icon: const Icon(Icons.clear, size: 18),
                  label: Text(t('admin_finance_filter_clear')),
                ),
            ],
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<PaymentInfo>>(
            stream: repo.watchPayments(status: _statusFilter, limit: 50),
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

              var payments = snapshot.data ?? const <PaymentInfo>[];

              if (_missionQuery.isNotEmpty) {
                payments = payments
                    .where(
                      (p) => p.missionId.toLowerCase().contains(
                        _missionQuery.toLowerCase(),
                      ),
                    )
                    .toList();
              }
              if (_customerQuery.isNotEmpty) {
                payments = payments
                    .where(
                      (p) => p.customerId.toLowerCase().contains(
                        _customerQuery.toLowerCase(),
                      ),
                    )
                    .toList();
              }
              if (_dateFrom != null) {
                payments = payments
                    .where((p) => !p.createdAt.isBefore(_dateFrom!))
                    .toList();
              }
              if (_dateTo != null) {
                final endOfDay = DateTime(
                  _dateTo!.year,
                  _dateTo!.month,
                  _dateTo!.day,
                  23,
                  59,
                  59,
                );
                payments = payments
                    .where((p) => !p.createdAt.isAfter(endOfDay))
                    .toList();
              }

              if (payments.isEmpty) {
                return FinanceEmptyState(message: t('admin_finance_empty'));
              }

              final sorted = [...payments]
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

              return Column(
                children: sorted
                    .map((p) => _PaymentRow(payment: p, t: t))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;
  const _DateFilterButton({
    required this.label,
    required this.value,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: const Icon(Icons.calendar_today_outlined, size: 16),
      label: Text(value == null ? label : formatShortDate(value)),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final PaymentInfo payment;
  final String Function(String) t;
  const _PaymentRow({required this.payment, required this.t});

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
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                AdminPaymentDetailScreen(paymentId: payment.paymentId),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t('admin_payments_col_id')}: ${payment.paymentId}',
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
                            '${t('admin_payments_col_date')}: ${formatShortDate(payment.createdAt)}',
                      ),
                      if (payment.provider.isNotEmpty)
                        MetaChip(
                          icon: Icons.credit_card_outlined,
                          label:
                              '${t('admin_payments_col_provider')}: ${payment.provider}',
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _AmountChip(
                        label: t('admin_payments_col_authorized'),
                        minor: payment.amountAuthorizedMinor,
                        currency: payment.currency,
                      ),
                      _AmountChip(
                        label: t('admin_payments_col_captured'),
                        minor: payment.amountCapturedMinor,
                        currency: payment.currency,
                      ),
                      if (payment.amountRefundedMinor > 0)
                        _AmountChip(
                          label: t('admin_payments_col_refunded'),
                          minor: payment.amountRefundedMinor,
                          currency: payment.currency,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(
              label: t(paymentStatusKey(payment.status)),
              color: paymentStatusColor(payment.status),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  final String label;
  final int minor;
  final String currency;
  const _AmountChip({
    required this.label,
    required this.minor,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: ${formatMinorAmount(minor)}',
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }
}
