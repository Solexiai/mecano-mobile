// ADM-01 (Bloc C, PR 5 — 2026-10-28) : changement de statut d'un litige
// depuis l'admin. `adminUpdateDisputeStatus()` (-> Cloud Function
// `updateDisputeStatus`, admin seulement) n'était appelé par aucun écran.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../../backend/backend_locator.dart';
import '../../../../../backend/repositories/finance_repository.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../finance/models/dispute_info.dart';
import '../../../../../models/enums.dart';
import '../finance_ui_helpers.dart';

/// Transitions autorisées — miroir de `functions/src/lib/disputeStateMachine.ts`.
/// Le serveur reste l'autorité ; cette liste évite seulement de proposer
/// une action qu'il refuserait.
const Map<DisputeStatus, List<DisputeStatus>> disputeTransitions = {
  DisputeStatus.opened: [DisputeStatus.underReview, DisputeStatus.won, DisputeStatus.lost],
  DisputeStatus.underReview: [DisputeStatus.won, DisputeStatus.lost],
  DisputeStatus.won: [DisputeStatus.closed],
  DisputeStatus.lost: [DisputeStatus.reversed, DisputeStatus.closed],
  DisputeStatus.reversed: [DisputeStatus.closed],
  DisputeStatus.closed: [],
};

class DisputeStatusMenu extends StatefulWidget {
  const DisputeStatusMenu({super.key, required this.dispute, required this.t, this.repository});
  final DisputeInfo dispute;
  final String Function(String) t;
  final FinanceRepository? repository;

  @override
  State<DisputeStatusMenu> createState() => _DisputeStatusMenuState();
}

class _DisputeStatusMenuState extends State<DisputeStatusMenu> {
  bool _busy = false;

  Future<void> _change(DisputeStatus next) async {
    final t = widget.t;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('admin_dispute_update_title')),
        content: Text(
          '${t(disputeStatusKey(widget.dispute.status))} → ${t(disputeStatusKey(next))}\n\n'
          '${t('admin_dispute_update_body')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t('admin_finance_cancel')),
          ),
          FilledButton(
            key: const ValueKey('dispute-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(t(disputeStatusKey(next))),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await (widget.repository ?? BackendLocator.financeRepository).adminUpdateDisputeStatus(
        disputeId: widget.dispute.disputeId,
        newStatus: next,
      );
      messenger?.showSnackBar(SnackBar(content: Text(t('admin_dispute_updated_success'))));
    } on FirebaseFunctionsException catch (e) {
      messenger?.showSnackBar(SnackBar(
        content: Text(e.message ?? t('admin_dispute_update_failed')),
        backgroundColor: AppColors.error,
      ));
    } catch (_) {
      messenger?.showSnackBar(SnackBar(
        content: Text(t('admin_dispute_update_failed')),
        backgroundColor: AppColors.error,
      ));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final next = disputeTransitions[widget.dispute.status] ?? const [];
    if (next.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<DisputeStatus>(
      key: ValueKey('dispute-menu-${widget.dispute.disputeId}'),
      tooltip: widget.t('admin_dispute_update_status'),
      enabled: !_busy,
      onSelected: _change,
      itemBuilder: (_) => [
        for (final s in next)
          PopupMenuItem(
            key: ValueKey('dispute-next-${s.firestoreValue}'),
            value: s,
            child: Text(widget.t(disputeStatusKey(s))),
          ),
      ],
      // Le bouton n'est qu'un visuel : le menu reçoit le clic.
      child: AbsorbPointer(
        child: OutlinedButton.icon(
          onPressed: () {},
          icon: _busy
              ? const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.edit_outlined, size: 16),
          label: Text(widget.t('admin_dispute_update_status')),
        ),
      ),
    );
  }
}
