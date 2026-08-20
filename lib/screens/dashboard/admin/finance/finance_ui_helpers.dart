// ---------------------------------------------------------------------------
// finance_ui_helpers.dart — helpers partagés par les 8 onglets Bloc L
// (mapping statut -> clé i18n, mapping statut -> couleur, petits widgets
// d'état communs). Centralise ce qui serait sinon dupliqué 8 fois.
//
// Les montants doivent TOUJOURS être formatés via
// `lib/finance/presentation/money_format.dart` (jamais réimplémenté ici).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../../models/enums.dart';

// --------------------------- PaymentStatus ---------------------------

String paymentStatusKey(PaymentStatus s) {
  switch (s) {
    case PaymentStatus.pending:
      return 'admin_payment_status_pending';
    case PaymentStatus.created:
      return 'admin_payment_status_created';
    case PaymentStatus.requiresPaymentMethod:
      return 'admin_payment_status_requires_payment_method';
    case PaymentStatus.authorizationPending:
      return 'admin_payment_status_authorization_pending';
    case PaymentStatus.authorized:
      return 'admin_payment_status_authorized';
    case PaymentStatus.capturePending:
      return 'admin_payment_status_capture_pending';
    case PaymentStatus.captured:
      return 'admin_payment_status_captured';
    case PaymentStatus.failed:
      return 'admin_payment_status_failed';
    case PaymentStatus.cancelled:
      return 'admin_payment_status_cancelled';
    case PaymentStatus.refunded:
      return 'admin_payment_status_refunded';
    case PaymentStatus.partiallyRefunded:
      return 'admin_payment_status_partially_refunded';
    case PaymentStatus.disputed:
      return 'admin_payment_status_disputed';
    case PaymentStatus.chargeback:
      return 'admin_payment_status_chargeback';
  }
}

Color paymentStatusColor(PaymentStatus s) {
  switch (s) {
    case PaymentStatus.captured:
    case PaymentStatus.refunded:
      return AppColors.success;
    case PaymentStatus.failed:
    case PaymentStatus.cancelled:
    case PaymentStatus.disputed:
    case PaymentStatus.chargeback:
      return AppColors.error;
    case PaymentStatus.partiallyRefunded:
    case PaymentStatus.capturePending:
    case PaymentStatus.authorizationPending:
      return AppColors.warning;
    default:
      return AppColors.info;
  }
}

// --------------------------- RefundStatus ---------------------------

String refundStatusKey(RefundStatus s) {
  switch (s) {
    case RefundStatus.requested:
      return 'admin_refund_status_requested';
    case RefundStatus.processing:
      return 'admin_refund_status_processing';
    case RefundStatus.succeeded:
      return 'admin_refund_status_succeeded';
    case RefundStatus.failed:
      return 'admin_refund_status_failed';
  }
}

Color refundStatusColor(RefundStatus s) {
  switch (s) {
    case RefundStatus.succeeded:
      return AppColors.success;
    case RefundStatus.failed:
      return AppColors.error;
    case RefundStatus.processing:
    case RefundStatus.requested:
      return AppColors.warning;
  }
}

// --------------------------- RefundReason ---------------------------

String refundReasonKey(RefundReason r) {
  switch (r) {
    case RefundReason.customerRequest:
      return 'admin_refund_reason_customer_request';
    case RefundReason.cancelledBeforePickup:
      return 'admin_refund_reason_cancelled_before_pickup';
    case RefundReason.cancelledAfterPickup:
      return 'admin_refund_reason_cancelled_after_pickup';
    case RefundReason.paymentError:
      return 'admin_refund_reason_payment_error';
    case RefundReason.goodwill:
      return 'admin_refund_reason_goodwill';
    case RefundReason.administrative:
      return 'admin_refund_reason_administrative';
    case RefundReason.missionImpossible:
      return 'admin_refund_reason_mission_impossible';
    case RefundReason.partialDelivery:
      return 'admin_refund_reason_partial_delivery';
    case RefundReason.noShow:
      return 'admin_refund_reason_no_show';
  }
}

// --------------------------- PayoutStatus ---------------------------

String payoutStatusKey(PayoutStatus s) {
  switch (s) {
    case PayoutStatus.pending:
      return 'payout_status_pending';
    case PayoutStatus.held:
      return 'payout_status_held';
    case PayoutStatus.eligible:
      return 'payout_status_eligible';
    case PayoutStatus.scheduled:
      return 'payout_status_scheduled';
    case PayoutStatus.processing:
      return 'payout_status_processing';
    case PayoutStatus.paid:
      return 'payout_status_paid';
    case PayoutStatus.failed:
      return 'payout_status_failed';
    case PayoutStatus.reversed:
      return 'payout_status_reversed';
  }
}

Color payoutStatusColor(PayoutStatus s) {
  switch (s) {
    case PayoutStatus.paid:
      return AppColors.success;
    case PayoutStatus.failed:
    case PayoutStatus.reversed:
      return AppColors.error;
    case PayoutStatus.held:
    case PayoutStatus.pending:
      return AppColors.warning;
    default:
      return AppColors.info;
  }
}

// --------------------------- DisputeStatus ---------------------------

String disputeStatusKey(DisputeStatus s) {
  switch (s) {
    case DisputeStatus.opened:
      return 'dispute_status_opened';
    case DisputeStatus.underReview:
      return 'dispute_status_under_review';
    case DisputeStatus.won:
      return 'dispute_status_won';
    case DisputeStatus.lost:
      return 'dispute_status_lost';
    case DisputeStatus.reversed:
      return 'dispute_status_reversed';
    case DisputeStatus.closed:
      return 'dispute_status_closed';
  }
}

Color disputeStatusColor(DisputeStatus s) {
  switch (s) {
    case DisputeStatus.won:
      return AppColors.success;
    case DisputeStatus.lost:
    case DisputeStatus.reversed:
      return AppColors.error;
    case DisputeStatus.underReview:
    case DisputeStatus.opened:
      return AppColors.warning;
    case DisputeStatus.closed:
      return AppColors.textSecondary;
  }
}

// --------------------------- Reconciliation ---------------------------

String anomalySeverityKey(ReconciliationAnomalySeverity s) {
  switch (s) {
    case ReconciliationAnomalySeverity.info:
      return 'anomaly_severity_info';
    case ReconciliationAnomalySeverity.warning:
      return 'anomaly_severity_warning';
    case ReconciliationAnomalySeverity.critical:
      return 'anomaly_severity_critical';
  }
}

Color anomalySeverityColor(ReconciliationAnomalySeverity s) {
  switch (s) {
    case ReconciliationAnomalySeverity.critical:
      return AppColors.error;
    case ReconciliationAnomalySeverity.warning:
      return AppColors.warning;
    case ReconciliationAnomalySeverity.info:
      return AppColors.info;
  }
}

String anomalyStatusKey(ReconciliationAnomalyStatus s) {
  switch (s) {
    case ReconciliationAnomalyStatus.open:
      return 'anomaly_status_open';
    case ReconciliationAnomalyStatus.acknowledged:
      return 'anomaly_status_acknowledged';
    case ReconciliationAnomalyStatus.resolved:
      return 'anomaly_status_resolved';
  }
}

Color anomalyStatusColor(ReconciliationAnomalyStatus s) {
  switch (s) {
    case ReconciliationAnomalyStatus.resolved:
      return AppColors.success;
    case ReconciliationAnomalyStatus.acknowledged:
      return AppColors.warning;
    case ReconciliationAnomalyStatus.open:
      return AppColors.error;
  }
}

// --------------------------- Ledger ---------------------------

String ledgerTypeKey(LedgerEntryType t) {
  switch (t) {
    case LedgerEntryType.customerCharge:
      return 'ledger_type_customer_charge';
    case LedgerEntryType.customerServiceFee:
      return 'ledger_type_customer_service_fee';
    case LedgerEntryType.platformCommission:
      return 'ledger_type_platform_commission';
    case LedgerEntryType.driverEarning:
      return 'ledger_type_driver_earning';
    case LedgerEntryType.driverTip:
      return 'ledger_type_driver_tip';
    case LedgerEntryType.driverBonus:
      return 'ledger_type_driver_bonus';
    case LedgerEntryType.tax:
      return 'ledger_type_tax';
    case LedgerEntryType.paymentProcessingFee:
      return 'ledger_type_payment_processing_fee';
    case LedgerEntryType.payoutProcessingFee:
      return 'ledger_type_payout_processing_fee';
    case LedgerEntryType.insuranceCost:
      return 'ledger_type_insurance_cost';
    case LedgerEntryType.refund:
      return 'ledger_type_refund';
    case LedgerEntryType.partialRefund:
      return 'ledger_type_partial_refund';
    case LedgerEntryType.chargeback:
      return 'ledger_type_chargeback';
    case LedgerEntryType.driverAdjustment:
      return 'ledger_type_driver_adjustment';
    case LedgerEntryType.customerAdjustment:
      return 'ledger_type_customer_adjustment';
    case LedgerEntryType.driverPayout:
      return 'ledger_type_driver_payout';
  }
}

String ledgerPartyKey(LedgerParty p) {
  switch (p) {
    case LedgerParty.customer:
      return 'admin_ledger_party_customer';
    case LedgerParty.driver:
      return 'admin_ledger_party_driver';
    case LedgerParty.platform:
      return 'admin_ledger_party_platform';
  }
}

String ledgerDirectionKey(LedgerDirection d) {
  switch (d) {
    case LedgerDirection.credit:
      return 'admin_ledger_direction_credit';
    case LedgerDirection.debit:
      return 'admin_ledger_direction_debit';
  }
}

Color ledgerDirectionColor(LedgerDirection d) {
  return d == LedgerDirection.credit ? AppColors.success : AppColors.error;
}

// --------------------------- Tax ---------------------------

String taxTypeKey(TaxType t) {
  switch (t) {
    case TaxType.gst:
      return 'admin_tax_type_gst';
    case TaxType.qst:
      return 'admin_tax_type_qst';
    case TaxType.hst:
      return 'admin_tax_type_hst';
    case TaxType.otherTax:
      return 'admin_tax_type_other_tax';
    case TaxType.taxExempt:
      return 'admin_tax_type_tax_exempt';
  }
}

String taxOwnerKey(String owner) {
  switch (owner) {
    case 'platform':
      return 'admin_tax_owner_platform';
    case 'driver':
      return 'admin_tax_owner_driver';
    default:
      return 'admin_tax_owner_not_applicable';
  }
}

// --------------------------- Widgets communs ---------------------------

/// Petit badge coloré affichant un statut traduit.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const StatusBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Petite ligne icône + texte (méta-info dans une carte).
class MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const MetaChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class FinanceEmptyState extends StatelessWidget {
  final String message;
  const FinanceEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class FinanceErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;
  const FinanceErrorState({
    super.key,
    required this.message,
    required this.onRetry,
    required this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
          ],
        ),
      ),
    );
  }
}

class FinanceLoadingState extends StatelessWidget {
  final String message;
  const FinanceLoadingState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formatte une date pour affichage compact dans les listes (JJ/MM/AAAA).
String formatShortDate(DateTime? d) {
  if (d == null) return '—';
  final local = d.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  return '$dd/$mm/${local.year}';
}
