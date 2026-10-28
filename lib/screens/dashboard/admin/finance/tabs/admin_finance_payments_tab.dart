// ---------------------------------------------------------------------------
// AdminFinancePaymentsTab — Centre financier > Paiements.
//
// Connectée à `FinanceRepository.watchPayments()` (Firestore réel, borné,
// jamais de scan complet). Filtres statut/type/mission/client/date en
// mémoire après réception du flux (le flux serveur est déjà borné par
// `limit`).
//
// Chaque ligne se lit sans connaître la base de données : type de paiement
// (livraison ou frais), prix, blocage de carte, montant capturé, montant
// libéré, répartition Movi-K / chauffeur, courriel du client et badge
// TEST/LIVE. Les montants viennent tels quels de `payments/{id}` (voir
// `AdminPaymentView`) : rien n'est recalculé.
//
// Aucune donnée Stripe sensible affichée (voir `PaymentInfo` — les champs
// `provider_*` exposés ici sont des IDENTIFIANTS publics Stripe, jamais des
// secrets/clés/CVC).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../backend/backend_locator.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../finance/models/payment_info.dart';
import '../../../../../finance/presentation/admin_payment_presenter.dart';
import '../../../../../finance/presentation/money_format.dart';
import '../../../../../models/enums.dart';
import '../../../../../providers/locale_provider.dart';
import '../../../../../services/text_file_export.dart';
import '../finance_ui_helpers.dart';
import 'admin_payment_detail_screen.dart';

const List<PaymentStatus?> _kPaymentFilters = [
  null,
  PaymentStatus.authorized,
  PaymentStatus.captured,
  PaymentStatus.cancelled,
  PaymentStatus.refunded,
  PaymentStatus.partiallyRefunded,
  PaymentStatus.captureFailed,
  PaymentStatus.failed,
  PaymentStatus.disputed,
];

const List<AdminPaymentKindFilter> _kKindFilters = [
  AdminPaymentKindFilter.all,
  AdminPaymentKindFilter.deliveries,
  AdminPaymentKindFilter.fees,
];

String _kindFilterKey(AdminPaymentKindFilter f) {
  switch (f) {
    case AdminPaymentKindFilter.all:
      return 'admin_payments_kind_filter_all';
    case AdminPaymentKindFilter.deliveries:
      return 'admin_payments_kind_filter_deliveries';
    case AdminPaymentKindFilter.fees:
      return 'admin_payments_kind_filter_fees';
  }
}

class AdminFinancePaymentsTab extends StatefulWidget {
  const AdminFinancePaymentsTab({super.key});

  @override
  State<AdminFinancePaymentsTab> createState() =>
      _AdminFinancePaymentsTabState();
}

class _AdminFinancePaymentsTabState extends State<AdminFinancePaymentsTab> {
  PaymentStatus? _statusFilter;
  AdminPaymentKindFilter _kindFilter = AdminPaymentKindFilter.all;
  String _missionQuery = '';
  String _customerQuery = '';
  DateTime? _dateFrom;
  DateTime? _dateTo;

  /// Courriels des clients déjà résolus (`customer_id` -> courriel).
  final Map<String, String> _emails = {};
  final Set<String> _emailsRequested = {};

  /// Paiements affichés au dernier rendu, pour l'export CSV.
  List<PaymentInfo> _visible = const [];

  Future<void> _requestEmails(Set<String> ids) async {
    final missing = ids
        .where((id) => id.isNotEmpty && !_emailsRequested.contains(id))
        .toSet();
    if (missing.isEmpty) return;
    _emailsRequested.addAll(missing);
    try {
      final found = await BackendLocator.financeRepository.adminGetUserEmails(
        missing,
      );
      if (!mounted || found.isEmpty) return;
      setState(() => _emails.addAll(found));
    } catch (_) {
      // Courriels indisponibles : l'identifiant du client reste affiché.
    }
  }

  List<PaymentInfo> _applyFilters(List<PaymentInfo> source) {
    var payments = source
        .where((p) => AdminPaymentView(p).matches(_kindFilter))
        .toList();

    if (_missionQuery.isNotEmpty) {
      final q = _missionQuery.toLowerCase();
      payments = payments
          .where((p) => p.missionId.toLowerCase().contains(q))
          .toList();
    }
    if (_customerQuery.isNotEmpty) {
      final q = _customerQuery.toLowerCase();
      payments = payments
          .where(
            (p) =>
                p.customerId.toLowerCase().contains(q) ||
                (_emails[p.customerId] ?? '').toLowerCase().contains(q),
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
    payments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return payments;
  }

  Future<void> _exportCsv(String locale, String Function(String) t) async {
    final csv = buildAdminPaymentsCsv(
      payments: _visible,
      customerEmails: _emails,
      locale: locale,
      t: t,
      statusLabel: (s) => t(paymentStatusKey(s)),
    );
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final fileName =
        'movik-paiements-${now.year}${two(now.month)}${two(now.day)}.csv';
    final downloaded = await saveTextFile(content: csv, fileName: fileName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t(
            downloaded
                ? 'admin_payments_export_done'
                : 'admin_payments_export_copied',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final t = localeProvider.t;
    final locale = localeProvider.locale;
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
              return ChoiceChip(
                label: Text(
                  f == null
                      ? t('admin_finance_filter_all')
                      : t(paymentStatusKey(f)),
                ),
                selected: f == _statusFilter,
                onSelected: (_) => setState(() => _statusFilter = f),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kKindFilters.map((f) {
              return ChoiceChip(
                label: Text(t(_kindFilterKey(f))),
                selected: f == _kindFilter,
                onSelected: (_) => setState(() => _kindFilter = f),
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
                width: 260,
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: t('admin_payments_filter_customer_or_email'),
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
            stream: repo.watchPayments(
              status: _statusFilter,
              limit: kAdminPaymentsLimit,
            ),
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

              final loaded = snapshot.data ?? const <PaymentInfo>[];
              final customerIds = loaded.map((p) => p.customerId).toSet();
              if (customerIds.any((id) => !_emailsRequested.contains(id))) {
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _requestEmails(customerIds),
                );
              }

              final payments = _applyFilters(loaded);
              _visible = payments;

              if (payments.isEmpty) {
                return FinanceEmptyState(message: t('admin_finance_empty'));
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SummaryPanel(
                    summary: AdminPaymentsSummary.from(payments),
                    truncated: loaded.length >= kAdminPaymentsLimit,
                    locale: locale,
                    t: t,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text(t('admin_payments_export_csv')),
                      onPressed: () => _exportCsv(locale, t),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...payments.map(
                    (p) => _PaymentRow(
                      payment: p,
                      customerEmail: _emails[p.customerId],
                      locale: locale,
                      t: t,
                    ),
                  ),
                ],
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

String _money(int minor, String locale) =>
    formatMajorAmount(minor / 100, locale: locale);

class _SummaryPanel extends StatelessWidget {
  final AdminPaymentsSummary summary;
  final bool truncated;
  final String locale;
  final String Function(String) t;
  const _SummaryPanel({
    required this.summary,
    required this.truncated,
    required this.locale,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final notes = <String>[
      t('admin_payments_summary_scope')
          .replaceAll('{count}', '${summary.count}'),
      if (truncated)
        t('admin_payments_summary_truncated')
            .replaceAll('{limit}', '$kAdminPaymentsLimit'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryTile(
              label: t('admin_payments_summary_captured'),
              value: _money(summary.capturedMinor, locale),
            ),
            _SummaryTile(
              label: t('admin_payments_summary_platform'),
              value: _money(summary.platformMinor, locale),
            ),
            _SummaryTile(
              label: t('admin_payments_summary_driver'),
              value: _money(summary.driverMinor, locale),
            ),
            _SummaryTile(
              label: t('admin_payments_summary_held'),
              value: _money(summary.heldMinor, locale),
            ),
            if (summary.refundedMinor > 0)
              _SummaryTile(
                label: t('admin_payments_col_refunded'),
                value: _money(summary.refundedMinor, locale),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          notes.join(' '),
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        if (summary.capturedWithoutSplitCount > 0) ...[
          const SizedBox(height: 4),
          Text(
            t('admin_payments_summary_without_connect').replaceAll(
              '{count}',
              '${summary.capturedWithoutSplitCount}',
            ),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.warning,
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  final PaymentInfo payment;
  final String? customerEmail;
  final String locale;
  final String Function(String) t;
  const _PaymentRow({
    required this.payment,
    required this.customerEmail,
    required this.locale,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final view = AdminPaymentView(payment);
    final testMode = view.isTestMode;
    final platformShare = view.platformShareMinor;
    final driverShare = view.driverShareMinor;

    final amounts = <String>[
      if (!view.isFee)
        '${t('admin_payments_price')} ${_money(view.deliveryPriceMinor, locale)}',
      '${t('admin_payments_hold')} ${_money(view.holdMinor, locale)}',
      if (view.captureDone)
        '${t('admin_payments_col_captured')} ${_money(payment.amountCapturedMinor, locale)}',
      if (view.releasedMinor > 0)
        '${t('admin_payments_released')} ${_money(view.releasedMinor, locale)}',
      if (payment.amountRefundedMinor > 0)
        '${t('admin_payments_col_refunded')} ${_money(payment.amountRefundedMinor, locale)}',
    ];

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
                    '${t(adminPaymentKindKey(view.kind))} · '
                    '${t('admin_payments_col_mission')} ${view.shortMissionRef}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
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
                        label: customerEmail ?? payment.customerId,
                      ),
                      MetaChip(
                        icon: Icons.event_outlined,
                        label: formatDisplayDate(
                          payment.createdAt,
                          connector: t('datetime_connector_at'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    amounts.join('  ·  '),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (platformShare != null && driverShare != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${t('admin_payments_share_platform')} ${_money(platformShare, locale)}'
                      '  ·  '
                      '${t('admin_payments_share_driver')} ${_money(driverShare, locale)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ] else if (view.captureDone && !view.viaStripeConnect) ...[
                    const SizedBox(height: 4),
                    Text(
                      t('admin_payments_no_connect'),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(
                  label: t(paymentStatusKey(payment.status)),
                  color: paymentStatusColor(payment.status),
                ),
                if (testMode != null) ...[
                  const SizedBox(height: 6),
                  StatusBadge(
                    label: testMode ? 'TEST' : 'LIVE',
                    color: testMode ? AppColors.warning : AppColors.success,
                  ),
                ],
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
