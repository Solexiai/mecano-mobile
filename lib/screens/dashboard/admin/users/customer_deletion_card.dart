// Effacer un compte — super-admin seulement (Daniel, 2026-11-10 ; étendu aux
// chauffeurs le 2026-11-17).
//
// 1. Aperçu serveur (`deleteCustomerAccount`, dryRun) : ce qui va se passer,
//    ou pourquoi c'est bloqué (livraison en cours, solde dû, litige…).
// 2. Raison obligatoire + taper EFFACER, puis effacement.
// Compte avec historique : anonymisé, livraisons et paiements gardés
// (preuves fiscales). Sans historique : tout est effacé. Si c'est un
// chauffeur, son dossier chauffeur (documents, offres, notes) part aussi.
//
// `startAccountDeletion` porte tout le parcours : la carte au bas de la fiche
// et le menu « ⋮ » des listes (Utilisateurs, Chauffeurs) l'appellent.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';

typedef CustomerDeletionCall =
    Future<Map<String, dynamic>> Function(
      String name,
      Map<String, dynamic> data,
    );

Future<Map<String, dynamic>> _defaultCall(
  String name,
  Map<String, dynamic> data,
) async {
  final result = await FirebaseFunctions.instance.httpsCallable(name).call(data);
  return Map<String, dynamic>.from(result.data as Map);
}

/// Parcours complet d'effacement d'un compte (aperçu → blocages ou
/// confirmation → effacement). Renvoie vrai si le compte a été effacé.
///
/// `setBusy` est appelé vrai pendant les appels serveur seulement (jamais
/// pendant qu'une fenêtre est ouverte), pour afficher un sablier.
Future<bool> startAccountDeletion(
  BuildContext context, {
  required String userId,
  required String locale,
  CustomerDeletionCall? call,
  void Function(bool busy)? setBusy,
}) async {
  final fr = locale == 'fr';
  final run = call ?? _defaultCall;
  Future<Map<String, dynamic>> deletion(Map<String, dynamic> data) async {
    setBusy?.call(true);
    try {
      return await run('deleteCustomerAccount', {'userId': userId, ...data});
    } finally {
      setBusy?.call(false);
    }
  }

  void error(Object error) {
    if (!context.mounted) return;
    final message = error is FirebaseFunctionsException ? error.message : null;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message ?? (fr ? 'Effacement impossible.' : 'Unable to delete.')),
        backgroundColor: AppColors.error,
      ),
    );
  }

  Map<String, dynamic> preview;
  try {
    preview = await deletion({'dryRun': true});
  } catch (e) {
    error(e);
    return false;
  }
  if (!context.mounted) return false;
  final blockers = (preview['blockers'] as List?)?.whereType<String>().toList() ?? const [];
  if (blockers.isNotEmpty) {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        key: const ValueKey('delete-customer-blocked'),
        title: Text(fr ? 'Impossible d’effacer ce compte' : 'This account cannot be deleted'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final b in blockers) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• $b'))],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
      ),
    );
    return false;
  }
  final reason = await showDialog<String>(
    context: context,
    builder: (c) => _ConfirmDialog(
      fr: fr,
      anonymize: preview['mode'] == 'anonymize',
      deliveries: (preview['deliveries'] as num?)?.toInt() ?? 0,
      payments: (preview['payments'] as num?)?.toInt() ?? 0,
      driver: preview['driver'] == true,
      driverDeliveries: (preview['driverDeliveries'] as num?)?.toInt() ?? 0,
    ),
  );
  if (reason == null || !context.mounted) return false;
  try {
    await deletion({'reason': reason});
    if (!context.mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(fr ? 'Compte effacé.' : 'Account deleted.')),
    );
    return true;
  } catch (e) {
    error(e);
    return false;
  }
}

class CustomerDeletionCard extends StatefulWidget {
  const CustomerDeletionCard({
    super.key,
    required this.userId,
    required this.locale,
    required this.onDeleted,
    this.call,
    this.driver = false,
  });
  final String userId;
  final String locale;
  final VoidCallback onDeleted;
  final CustomerDeletionCall? call;
  /// Vrai si le compte a aussi un dossier chauffeur (texte adapté).
  final bool driver;

  @override
  State<CustomerDeletionCard> createState() => _CustomerDeletionCardState();
}

class _CustomerDeletionCardState extends State<CustomerDeletionCard> {
  bool _busy = false;

  bool get _fr => widget.locale == 'fr';

  Future<void> _start() async {
    final deleted = await startAccountDeletion(
      context,
      userId: widget.userId,
      locale: widget.locale,
      call: widget.call,
      setBusy: (busy) {
        if (mounted) setState(() => _busy = busy);
      },
    );
    if (deleted) widget.onDeleted();
  }

  @override
  Widget build(BuildContext context) {
    final fr = _fr;
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
              fr ? 'Effacer ce compte' : 'Delete this account',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              widget.driver
                  ? (fr
                        ? 'Super-admin seulement. Son dossier chauffeur (documents, offres, notes), son compte et ses données personnelles sont effacés ; ses livraisons et paiements restent dans les registres (preuves fiscales, 6 ans).'
                        : 'Super admin only. The driver file (documents, offers, notes), the account and personal data are deleted; deliveries and payments stay in the records (tax evidence, 6 years).')
                  : (fr
                        ? 'Super-admin seulement. Son compte et ses données personnelles sont effacés ; ses livraisons et paiements restent dans les registres (preuves fiscales, 6 ans).'
                        : 'Super admin only. The account and personal data are deleted; deliveries and payments stay in the records (tax evidence, 6 years).'),
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
              label: Text(fr ? 'Effacer ce compte…' : 'Delete this account…'),
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
    required this.driver,
    required this.driverDeliveries,
  });
  final bool fr;
  final bool anonymize;
  final int deliveries;
  final int payments;
  final bool driver;
  final int driverDeliveries;

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
              ? 'Ce compte a ${widget.deliveries} livraison(s) et ${widget.payments} paiement(s)${widget.driver ? ', plus ${widget.driverDeliveries} livraison(s) comme chauffeur' : ''}. Son compte, son courriel, son téléphone, ses adresses, ses notes et ses notifications seront effacés. Ses livraisons et paiements restent dans les registres (preuves fiscales).'
              : 'This account has ${widget.deliveries} delivery(ies) and ${widget.payments} payment(s)${widget.driver ? ', plus ${widget.driverDeliveries} delivery(ies) as a driver' : ''}. The account, email, phone, addresses, notes and notifications will be deleted. Deliveries and payments stay in the records (tax evidence).')
        : (fr
              ? 'Ce compte n’a aucune livraison ni aucun paiement : tout sera effacé.'
              : 'This account has no delivery and no payment: everything will be deleted.');
    return AlertDialog(
      key: const ValueKey('delete-customer-dialog'),
      title: Text(fr ? 'Effacer ce compte ?' : 'Delete this account?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(what),
            if (widget.driver) ...[
              const SizedBox(height: 8),
              Text(
                fr
                    ? 'C’est aussi un chauffeur : son dossier chauffeur, ses documents, ses offres et ses notes internes seront effacés.'
                    : 'This is also a driver: the driver file, documents, offers and internal notes will be deleted.',
              ),
            ],
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
