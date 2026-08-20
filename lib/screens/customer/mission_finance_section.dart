// ---------------------------------------------------------------------------
// MissionFinanceSection — vue financière CLIENT pour UNE mission (Bloc J,
// Phase 6, points 7/8/9/10/11).
//
// Intégrée dans `customer_tracking_screen.dart` (`_CompletedMissionView`),
// cette section affiche EXCLUSIVEMENT des données déjà autorisées par les
// Security Rules serveur pour le client propriétaire de la mission :
//   - Résumé : `FinancialSnapshot` (watchFinancialSnapshot) — prix mission,
//     frais client, taxes, pourboire, total.
//   - Paiement : `PaymentInfo` (watchPaymentForMission) — statut, montant
//     autorisé/capturé, date.
//   - Remboursement : `RefundInfo` (watchRefundsForMission) — aucun /
//     partiel / complet + montant.
//   - Solde final : `MissionFinancialBalance` (watchMissionFinancialBalance)
//     — UNIQUEMENT les champs `customer*`/`outstandingCustomerBalance`.
//
// EXCLUSIONS STRICTES (Bloc J point 7) : cette section n'affiche JAMAIS la
// commission chauffeur, les infos de payout interne, la marge de
// contribution Movi-K, ni aucune donnée financière admin — ces champs
// existent dans les modèles Dart sous-jacents (pour l'usage Bloc K/L) mais
// ne sont simplement jamais lus ici.
//
// AUCUN CALCUL : chaque montant affiché est une lecture directe d'un champ
// serveur déjà calculé (`*_minor` en cents, ou `double` majeur pour
// `FinancialSnapshot`) — jamais une addition/soustraction Flutter, à
// l'exception triviale de la conversion cents -> dollars pour l'affichage
// (division par 100, pas un recalcul financier).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../../backend/backend_locator.dart';
import '../../core/app_colors.dart';
import '../../finance/models/financial_snapshot.dart';
import '../../finance/models/mission_financial_balance.dart';
import '../../finance/models/payment_info.dart';
import '../../finance/models/refund_info.dart';
import '../../finance/presentation/payment_display_status.dart';

/// Formatte un montant en unités mineures entières (cents) en chaîne
/// lisible `"XX.XX $"`. Simple conversion d'affichage, aucun recalcul.
String formatMinorAmount(int minor, {String currencySymbol = '\$'}) {
  return '${(minor / 100).toStringAsFixed(2)} $currencySymbol';
}

/// Formatte un montant en unités majeures (`double`, ex: `FinancialSnapshot`)
/// en chaîne lisible `"XX.XX $"`.
String formatMajorAmount(double major, {String currencySymbol = '\$'}) {
  return '${major.toStringAsFixed(2)} $currencySymbol';
}

String _formatDate(DateTime dt) {
  final local = dt.toLocal();
  final d = local.day.toString().padLeft(2, '0');
  final m = local.month.toString().padLeft(2, '0');
  final y = local.year.toString();
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$d/$m/$y à $h:$min';
}

class MissionFinanceSection extends StatelessWidget {
  final String missionId;
  final String Function(String) t;
  const MissionFinanceSection({
    super.key,
    required this.missionId,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<FinancialSnapshot?>(
      stream: BackendLocator.financeRepository.watchFinancialSnapshot(
        missionId,
      ),
      builder: (context, snapshotSnap) {
        return StreamBuilder<PaymentInfo?>(
          stream: BackendLocator.financeRepository.watchPaymentForMission(
            missionId,
          ),
          builder: (context, paymentSnap) {
            return StreamBuilder<List<RefundInfo>>(
              stream: BackendLocator.financeRepository.watchRefundsForMission(
                missionId,
              ),
              builder: (context, refundsSnap) {
                return StreamBuilder<MissionFinancialBalance?>(
                  stream: BackendLocator.financeRepository
                      .watchMissionFinancialBalance(missionId),
                  builder: (context, balanceSnap) {
                    final loading =
                        snapshotSnap.connectionState ==
                            ConnectionState.waiting ||
                        paymentSnap.connectionState ==
                            ConnectionState.waiting ||
                        refundsSnap.connectionState ==
                            ConnectionState.waiting ||
                        balanceSnap.connectionState == ConnectionState.waiting;
                    final hasError =
                        snapshotSnap.hasError ||
                        paymentSnap.hasError ||
                        refundsSnap.hasError ||
                        balanceSnap.hasError;

                    return _FinanceSectionBody(
                      t: t,
                      loading: loading,
                      hasError: hasError,
                      snapshot: snapshotSnap.data,
                      payment: paymentSnap.data,
                      refunds: refundsSnap.data ?? const [],
                      balance: balanceSnap.data,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _FinanceSectionBody extends StatelessWidget {
  final String Function(String) t;
  final bool loading;
  final bool hasError;
  final FinancialSnapshot? snapshot;
  final PaymentInfo? payment;
  final List<RefundInfo> refunds;
  final MissionFinancialBalance? balance;

  const _FinanceSectionBody({
    required this.t,
    required this.loading,
    required this.hasError,
    required this.snapshot,
    required this.payment,
    required this.refunds,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.receipt_long_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                t('finance_section_title'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (loading)
            _LoadingRow(message: t('finance_loading'))
          else if (hasError)
            _ErrorRow(message: t('finance_error'))
          else ...[
            _SummarySection(t: t, snapshot: snapshot),
            const SizedBox(height: 18),
            _PaymentSection(t: t, payment: payment, refunds: refunds),
            const SizedBox(height: 18),
            _RefundSection(
              t: t,
              payment: payment,
              refunds: refunds,
              balance: balance,
            ),
            const SizedBox(height: 18),
            _HistorySection(
              t: t,
              snapshot: snapshot,
              payment: payment,
              refunds: refunds,
            ),
            if (balance != null) ...[
              const Divider(height: 26),
              _FinalBalanceSection(t: t, balance: balance!),
            ],
          ],
        ],
      ),
    );
  }
}

class _LoadingRow extends StatelessWidget {
  final String message;
  const _LoadingRow({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String message;
  const _ErrorRow({required this.message});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline, size: 18, color: AppColors.error),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: AppColors.error, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _LineRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 14 : 13,
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: style.copyWith(
              color: bold ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// Résumé (point 7/8) : prix mission, frais, taxes, pourboire, total —
/// lecture directe de `FinancialSnapshot` (unités majeures `double`),
/// jamais recalculé.
class _SummarySection extends StatelessWidget {
  final String Function(String) t;
  final FinancialSnapshot? snapshot;
  const _SummarySection({required this.t, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final s = snapshot;
    if (s == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: t('finance_summary_title')),
          const SizedBox(height: 6),
          Text(
            t('finance_payment_none'),
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    // Frais client = customerServiceFee + customerFees - customerDiscount ;
    // aucune de ces valeurs n'est recalculée, on affiche simplement chaque
    // ligne source telle qu'écrite par le serveur.
    final feesTotal =
        s.customerServiceFee + s.customerFees - s.customerDiscount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: t('finance_summary_title')),
        const SizedBox(height: 8),
        _LineRow(
          label: t('finance_summary_mission_price'),
          value: formatMajorAmount(s.missionBaseValue),
        ),
        if (feesTotal != 0)
          _LineRow(
            label: t('finance_summary_fees'),
            value: formatMajorAmount(feesTotal),
          ),
        if (s.customerTax != 0)
          _LineRow(
            label: t('finance_summary_taxes'),
            value: formatMajorAmount(s.customerTax),
          ),
        if (s.tipAmount != 0)
          _LineRow(
            label: t('finance_summary_tip'),
            value: formatMajorAmount(s.tipAmount),
          ),
        const Divider(height: 16),
        _LineRow(
          label: t('finance_summary_total'),
          value: formatMajorAmount(s.customerTotal),
          bold: true,
        ),
      ],
    );
  }
}

/// Paiement (point 7/8/9) : statut affiché (via PaymentDisplayStatus),
/// montant autorisé, montant capturé, date.
class _PaymentSection extends StatelessWidget {
  final String Function(String) t;
  final PaymentInfo? payment;
  final List<RefundInfo> refunds;
  const _PaymentSection({
    required this.t,
    required this.payment,
    required this.refunds,
  });

  @override
  Widget build(BuildContext context) {
    final p = payment;
    if (p == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: t('finance_payment_title')),
          const SizedBox(height: 6),
          Text(
            t('finance_payment_none'),
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    final hasSucceededRefund = refunds.any((r) => r.isSucceeded);
    final isFullyRefundedAmount =
        p.amountRefundedMinor >= p.amountCapturedMinor &&
        p.amountCapturedMinor > 0;
    final displayStatus = PaymentDisplayStatusX.fromPaymentStatus(
      p.status,
      hasSucceededRefund: hasSucceededRefund,
      isFullyRefundedAmount: isFullyRefundedAmount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: t('finance_payment_title')),
        const SizedBox(height: 8),
        _PaymentStatusChip(displayStatus: displayStatus, t: t),
        const SizedBox(height: 8),
        _LineRow(
          label: t('finance_payment_authorized_amount'),
          value: formatMinorAmount(p.amountAuthorizedMinor),
        ),
        _LineRow(
          label: t('finance_payment_captured_amount'),
          value: formatMinorAmount(p.amountCapturedMinor),
        ),
        if (p.capturedAt != null)
          _LineRow(
            label: t('finance_payment_date'),
            value: _formatDate(p.capturedAt!),
          )
        else if (p.authorizedAt != null)
          _LineRow(
            label: t('finance_payment_date'),
            value: _formatDate(p.authorizedAt!),
          ),
      ],
    );
  }
}

class _PaymentStatusChip extends StatelessWidget {
  final PaymentDisplayStatus displayStatus;
  final String Function(String) t;
  const _PaymentStatusChip({required this.displayStatus, required this.t});

  Color get _color {
    switch (displayStatus) {
      case PaymentDisplayStatus.confirmed:
        return AppColors.success;
      case PaymentDisplayStatus.authorized:
        return AppColors.info;
      case PaymentDisplayStatus.pending:
        return AppColors.warning;
      case PaymentDisplayStatus.failed:
        return AppColors.error;
      case PaymentDisplayStatus.partiallyRefunded:
        return AppColors.warning;
      case PaymentDisplayStatus.refunded:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        t(displayStatus.i18nKey),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Remboursement (point 7/8) : aucun / partiel / complet + montant total
/// remboursé — dérivé de `MissionFinancialBalance.customerRefunded` en
/// priorité (champ agrégé serveur), avec repli sur la somme des
/// `RefundInfo` succeeded si le solde n'est pas encore calculé.
class _RefundSection extends StatelessWidget {
  final String Function(String) t;
  final PaymentInfo? payment;
  final List<RefundInfo> refunds;
  final MissionFinancialBalance? balance;
  const _RefundSection({
    required this.t,
    required this.payment,
    required this.refunds,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final succeededRefunds = refunds.where((r) => r.isSucceeded).toList();

    if (succeededRefunds.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(label: t('finance_refund_title')),
          const SizedBox(height: 6),
          Text(
            t('finance_refund_none'),
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    // Priorité au solde serveur pré-calculé (source la plus fiable),
    // sinon somme des refunds succeeded en dernier recours d'affichage.
    final refundedMinor =
        balance?.customerRefunded ??
        succeededRefunds.fold<int>(0, (sum, r) => sum + r.amountMinor);
    final capturedMinor = payment?.amountCapturedMinor ?? 0;
    final isFull = capturedMinor > 0 && refundedMinor >= capturedMinor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: t('finance_refund_title')),
        const SizedBox(height: 8),
        Text(
          isFull ? t('finance_refund_full') : t('finance_refund_partial'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        _LineRow(
          label: t('finance_refund_amount'),
          value: formatMinorAmount(refundedMinor),
          bold: true,
        ),
      ],
    );
  }
}

/// Historique (point 7) : mouvements pertinents pour le CLIENT uniquement —
/// paiement, puis chaque remboursement succeeded, triés du plus récent au
/// plus ancien. N'affiche AUCUNE ligne interne chauffeur/plateforme (voir
/// exclusions Bloc J point 7).
class _HistorySection extends StatelessWidget {
  final String Function(String) t;
  final FinancialSnapshot? snapshot;
  final PaymentInfo? payment;
  final List<RefundInfo> refunds;
  const _HistorySection({
    required this.t,
    required this.snapshot,
    required this.payment,
    required this.refunds,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_HistoryItem>[];

    final p = payment;
    if (p != null && p.capturedAt != null) {
      items.add(
        _HistoryItem(
          date: p.capturedAt!,
          icon: Icons.credit_card,
          color: AppColors.success,
          label: t('finance_payment_title'),
          amount: formatMinorAmount(p.amountCapturedMinor),
        ),
      );
    } else if (p != null && p.authorizedAt != null) {
      items.add(
        _HistoryItem(
          date: p.authorizedAt!,
          icon: Icons.lock_clock_outlined,
          color: AppColors.info,
          label: t('finance_status_authorized'),
          amount: formatMinorAmount(p.amountAuthorizedMinor),
        ),
      );
    }

    for (final r in refunds.where((r) => r.isSucceeded)) {
      items.add(
        _HistoryItem(
          date: r.displayDate,
          icon: Icons.replay_circle_filled_outlined,
          color: AppColors.warning,
          label: t('finance_refund_title'),
          amount: '- ${formatMinorAmount(r.amountMinor)}',
        ),
      );
    }

    items.sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: t('finance_history_title')),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Text(
            t('finance_history_empty'),
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          )
        else
          for (final item in items) _HistoryRow(item: item),
      ],
    );
  }
}

/// Solde final (point 8) : dernière ligne du "reçu" — lecture directe de
/// `MissionFinancialBalance.outstandingCustomerBalance`
/// (= `outstanding_customer_balance_minor`, déjà calculé côté serveur comme
/// `customer_charged - customer_refunded`), AUCUN recalcul local. N'affiche
/// que des champs `customer*` — jamais commission/payout chauffeur.
class _FinalBalanceSection extends StatelessWidget {
  final String Function(String) t;
  final MissionFinancialBalance balance;
  const _FinalBalanceSection({required this.t, required this.balance});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: t('finance_receipt_title')),
        const SizedBox(height: 8),
        _LineRow(
          label: t('finance_receipt_final_balance'),
          value: formatMinorAmount(balance.outstandingCustomerBalance),
          bold: true,
        ),
      ],
    );
  }
}

class _HistoryItem {
  final DateTime date;
  final IconData icon;
  final Color color;
  final String label;
  final String amount;
  const _HistoryItem({
    required this.date,
    required this.icon,
    required this.color,
    required this.label,
    required this.amount,
  });
}

class _HistoryRow extends StatelessWidget {
  final _HistoryItem item;
  const _HistoryRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(item.icon, size: 16, color: item.color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _formatDate(item.date),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            item.amount,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
