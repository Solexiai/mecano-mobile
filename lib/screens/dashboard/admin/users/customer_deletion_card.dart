// Effacer un client — super-admin seulement (Daniel, 2026-11-10).
//
// 1. Aperçu serveur (`deleteCustomerAccount`, dryRun) : ce qui va se passer,
//    ou pourquoi c'est bloqué (livraison en cours, solde dû, litige…).
// 2. Raison obligatoire + taper EFFACER, puis effacement.
// Client avec historique : anonymisé, livraisons et paiements gardés
// (preuves fiscales). Sans historique : tout est effacé.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';

typedef CustomerDeletionCall =
    Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> data,
    );

class CustomerDeletionCard extends StatefulWidget {
  const CustomerDeletionCard({
    super.key,
    required this.userId,
    required this.locale,
    required this.onDeleted,
    this.call,
  });
  final String userId;
  final String locale;
  final VoidCallback onDeleted;
  final CustomerDeletionCall? call;

  @override
  State<CustomerDeletionCard> createState() => _CustomerDeletionCardState();
}

class _CustomerDeletionCardState extends State<CustomerDeletionCard> {
  bool _busy = false;

  bool get _fr => widget.locale == 'fr';

  Future<Map<String, dynamic>> _call(Map<String, dynamic> data) async {
    final payload = {'userId': widget.userId, ...data};
    if (widget.call != null) return widget.call!('deleteCustomerAccount', payload);
    final result = await FirebaseFunctions.instance
        .httpsCallable('deleteCustomerAccount')
        .call(payload);
    return Map<String, dynamic>.from(result.data as Map);
  }

  void _error(Object error) {
    if (!mounted) return;
    final message = error is FirebaseFunctionsException ? error.message : null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? (_fr ? 'Effacement impossible.' : 'Unable to delete.')),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    Map<String, dynamic> preview;
    try {
      preview = await _call({'dryRun': true});
    } catch (error) {
      _error(error);
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final blockers = (preview['blockers'] as List?)?.whereType<String>().toList() ?? const [];
    if (blockers.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          key: const ValueKey('delete-customer-blocked'),
          title: Text(_fr ? 'Impossible d’effacer ce client' : 'This customer cannot be deleted'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final b in blockers) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• $b'))],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
      return;
    }
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => _ConfirmDialog(
        fr: _fr,
        anonymize: preview['mode'] == 'anonymize',
        deliveries: (preview['deliveries'] as num?)?.toInt() ?? 0,
        payments: (preview['payments'] as num?)?.toInt() ?? 0,
      ),
    );
    if (reason == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await _call({'reason': reason});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_fr ? 'Client effacé.' : 'Customer deleted.')),
      );
      widget.onDeleted();
    } catch (error) {
      _error(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.error),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _fr ? 'Effacer ce client' : 'Delete this customer',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              _fr
                  ? 'Super-admin seulement. Son compte et ses données personnelles sont effacés ; ses livraisons et paiements restent dans les registres (preuves fiscales, 6 ans).'
                  : 'Super admin only. The account and personal data are deleted; deliveries and payments stay in the records (tax evidence, 6 years).',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey('delete-customer'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
              onPressed: _busy ? null : _start,
              icon: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.delete_forever_outlined),
              label: Text(_fr ? 'Effacer ce client…' : 'Delete this customer…'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({
    required this.fr,
    required this.anonymize,
    required this.deliveries,
    required this.payments,
  });
  final bool fr;
  final bool anonymize;
  final int deliveries;
  final int payments;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  final _reason = TextEditingController();
  final _confirm = TextEditingController();

  String get _word => widget.fr ? 'EFFACER' : 'DELETE';

  bool get _ready => _reason.text.trim().length >= 5 && _confirm.text.trim() == _word;

  @override
  void dispose() {
    _reason.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fr = widget.fr;
    final what = widget.anonymize
        ? (fr
              ? 'Ce client a ${widget.deliveries} livraison(s) et ${widget.payments} paiement(s). Son compte, son courriel, son téléphone, ses adresses, ses notes et ses notifications seront effacés. Ses livraisons et paiements restent dans les registres (preuves fiscales).'
              : 'This customer has ${widget.deliveries} delivery(ies) and ${widget.payments} payment(s). The account, email, phone, addresses, notes and notifications will be deleted. Deliveries and payments stay in the records (tax evidence).')
        : (fr
              ? 'Ce client n’a aucune livraison ni aucun paiement : tout sera effacé.'
              : 'This customer has no delivery and no payment: everything will be deleted.');
    return AlertDialog(
      key: const ValueKey('delete-customer-dialog'),
      title: Text(fr ? 'Effacer ce client ?' : 'Delete this customer?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(what),
            const SizedBox(height: 8),
            Text(
              fr ? 'C’est définitif : la personne ne pourra plus se connecter.' : 'This is permanent: the person can no longer sign in.',
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.error),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('delete-customer-reason'),
              controller: _reason,
              onChanged: (_) => setState(() {}),
              maxLength: 500,
              decoration: InputDecoration(
                labelText: fr ? 'Raison (ex. : demande du client)' : 'Reason (e.g. customer request)',
              ),
            ),
            TextField(
              key: const ValueKey('delete-customer-confirm'),
              controller: _confirm,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: fr ? 'Tapez $_word pour confirmer' : 'Type $_word to confirm'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(fr ? 'Annuler' : 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('delete-customer-submit'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: _ready ? () => Navigator.pop(context, _reason.text.trim()) : null,
          child: Text(fr ? 'Effacer définitivement' : 'Delete permanently'),
        ),
      ],
    );
  }
}
