// ADM-01 (Bloc C, PR 5 — 2026-10-28) : remboursement depuis l'admin.
// Jusqu'ici `FinanceRepository.adminRefundPayment()` (-> Cloud Function
// `refundPayment`, admin seulement depuis SEC-01) n'était appelé par aucun
// écran : impossible de rembourser un client sans la console Stripe.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../backend/backend_locator.dart';
import '../../../../../backend/repositories/finance_repository.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../finance/models/payment_info.dart';
import '../../../../../finance/presentation/money_format.dart';
import '../../../../../models/enums.dart';
import '../finance_ui_helpers.dart';

/// Motifs proposés à l'admin, dans l'ordre d'usage. Le serveur accepte les
/// neuf valeurs de `RefundReasons` ; on garde ici les motifs administratifs
/// (les annulations passent par leur propre flux).
const adminRefundReasons = [
  RefundReason.customerRequest,
  RefundReason.goodwill,
  RefundReason.partialDelivery,
  RefundReason.missionImpossible,
  RefundReason.paymentError,
  RefundReason.administrative,
];

/// Montant encore remboursable, en cents.
int refundableMinor(PaymentInfo p) {
  final remaining = p.amountCapturedMinor - p.amountRefundedMinor;
  return remaining > 0 ? remaining : 0;
}

/// Convertit « 12,50 » / « 12.50 » en cents ; `null` si invalide.
int? parseAmountMinor(String raw) {
  final cleaned = raw.trim().replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value <= 0) return null;
  return (value * 100).round();
}

Future<bool> showRefundPaymentDialog(
  BuildContext context, {
  required PaymentInfo payment,
  required String Function(String) t,
  FinanceRepository? repository,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _RefundDialog(
      payment: payment,
      t: t,
      repository: repository ?? BackendLocator.financeRepository,
    ),
  );
  return result == true;
}

class _RefundDialog extends StatefulWidget {
  const _RefundDialog({required this.payment, required this.t, required this.repository});
  final PaymentInfo payment;
  final String Function(String) t;
  final FinanceRepository repository;

  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  RefundReason _reason = RefundReason.customerRequest;
  bool _full = true;
  final _amount = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int get _max => refundableMinor(widget.payment);

  int? get _requestedMinor => _full ? _max : parseAmountMinor(_amount.text);

  String? get _amountError {
    if (_full) return null;
    final minor = _requestedMinor;
    if (minor == null) return widget.t('admin_refund_amount_invalid');
    if (minor > _max) return widget.t('admin_refund_amount_too_high');
    return null;
  }

  Future<void> _submit() async {
    final minor = _requestedMinor;
    if (minor == null || _amountError != null) {
      setState(() {});
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.adminRefundPayment(
        paymentId: widget.payment.paymentId,
        reason: _reason,
        amountMinor: _full ? null : minor,
        // Clé de déduplication : un double clic ou un rejeu réseau ne crée
        // jamais deux remboursements.
        clientRequestId:
            'admin_${widget.payment.paymentId}_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (mounted) Navigator.pop(context, true);
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message ?? widget.t('admin_refund_failed');
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = widget.t('admin_refund_failed');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final minor = _requestedMinor;
    return AlertDialog(
      title: Text(t('admin_refund_title')),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${t('admin_refund_refundable')} : ${formatMinorAmount(_max)}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RefundReason>(
              key: const ValueKey('refund-reason'),
              initialValue: _reason,
              decoration: InputDecoration(labelText: t('admin_refund_reason')),
              items: [
                for (final r in adminRefundReasons)
                  DropdownMenuItem(value: r, child: Text(t(refundReasonKey(r)))),
              ],
              onChanged: _busy ? null : (r) => setState(() => _reason = r ?? _reason),
            ),
            const SizedBox(height: 8),
            RadioGroup<bool>(
              groupValue: _full,
              onChanged: (v) {
                if (!_busy) setState(() => _full = v ?? true);
              },
              child: Column(
                children: [
                  RadioListTile<bool>(
                    key: const ValueKey('refund-full'),
                    value: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(t('admin_refund_full')),
                  ),
                  RadioListTile<bool>(
                    key: const ValueKey('refund-partial'),
                    value: false,
                    contentPadding: EdgeInsets.zero,
                    title: Text(t('admin_refund_partial')),
                  ),
                ],
              ),
            ),
            if (!_full)
              TextField(
                key: const ValueKey('refund-amount'),
                controller: _amount,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(
                  labelText: t('admin_refund_amount'),
                  suffixText: '\$',
                  errorText: _amount.text.isEmpty ? null : _amountError,
                ),
                onChanged: (_) => setState(() {}),
              ),
            const SizedBox(height: 12),
            Text(
              t('admin_refund_notice'),
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                key: const ValueKey('refund-error'),
                style: const TextStyle(color: AppColors.error),
              ),
            ],
            if (_busy) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: Text(t('admin_finance_cancel')),
        ),
        FilledButton(
          key: const ValueKey('refund-confirm'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: _busy || minor == null || minor <= 0 || _amountError != null ? null : _submit,
          child: Text(
            minor == null || minor <= 0
                ? t('admin_refund_confirm')
                : '${t('admin_refund_confirm')} · ${formatMinorAmount(minor)}',
          ),
        ),
      ],
    );
  }
}
