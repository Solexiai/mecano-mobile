import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../backend/models/delivery_mission.dart';
import '../../../../core/app_colors.dart';
import '../../../../models/enums.dart';
import '../../../../providers/locale_provider.dart';
import '../../../../widgets/internal_test_mission_banner.dart';
import 'admin_mission_assignment_dialog.dart';
import 'admin_mission_failure_review.dart';

enum AdminMissionFilter { all, active, completed, unassigned, cancelled }

bool adminMissionAwaitingAssignment(MissionStatus status) =>
    status == MissionStatus.searchingDriver || status == MissionStatus.offered;

/// Same lists as the server (functions/src/functions/adminMissionActions.ts).
const adminCancellableStatuses = {
  MissionStatus.draft,
  MissionStatus.quoted,
  MissionStatus.searchingDriver,
  MissionStatus.offered,
  MissionStatus.assigned,
  MissionStatus.driverToPickup,
  MissionStatus.arrivedAtPickup,
  MissionStatus.pickedUp,
  MissionStatus.inTransit,
  MissionStatus.arrivedAtDropoff,
  MissionStatus.paymentFailed,
};
const adminDeletableStatuses = {
  MissionStatus.cancelled,
  MissionStatus.completed,
  MissionStatus.refunded,
  MissionStatus.paymentFailed,
};

class AdminMissionsScreen extends StatefulWidget {
  const AdminMissionsScreen({super.key, this.initialFilter = 'active'});
  final String initialFilter;

  @override
  State<AdminMissionsScreen> createState() => _AdminMissionsScreenState();
}

class _AdminMissionsScreenState extends State<AdminMissionsScreen> {
  late AdminMissionFilter _filter;
  static const _active = {
    MissionStatus.searchingDriver,
    MissionStatus.offered,
    MissionStatus.assigned,
    MissionStatus.driverToPickup,
    MissionStatus.arrivedAtPickup,
    MissionStatus.pickedUp,
    MissionStatus.inTransit,
    MissionStatus.arrivedAtDropoff,
  };
  @override
  void initState() {
    super.initState();
    _filter = switch (widget.initialFilter) {
      'unassigned' => AdminMissionFilter.unassigned,
      'completed' => AdminMissionFilter.completed,
      'all' => AdminMissionFilter.all,
      'cancelled' => AdminMissionFilter.cancelled,
      _ => AdminMissionFilter.active,
    };
  }

  @override
  Widget build(BuildContext context) {
    final fr = context.watch<LocaleProvider>().locale == 'fr';
    return Scaffold(
      appBar: AppBar(title: Text(fr ? 'Missions' : 'Jobs')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('delivery_requests')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                fr
                    ? 'Impossible de charger les missions.'
                    : 'Unable to load jobs.',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final missions =
              snapshot.data!.docs
                  // « Effacée » par un admin : gardée pour la comptabilité,
                  // retirée des listes.
                  .where((d) => d.data()['admin_archived'] != true)
                  .map((d) => DeliveryMission.fromJson(d.id, d.data()))
                  .where(_matches)
                  .toList()
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _chip(
                    AdminMissionFilter.unassigned,
                    fr ? 'Sans chauffeur' : 'Unassigned',
                  ),
                  _chip(AdminMissionFilter.all, fr ? 'Toutes' : 'All'),
                  _chip(AdminMissionFilter.active, fr ? 'Actives' : 'Active'),
                  _chip(
                    AdminMissionFilter.completed,
                    fr ? 'Terminées' : 'Completed',
                  ),
                  _chip(
                    AdminMissionFilter.cancelled,
                    fr ? 'Annulées' : 'Cancelled',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                fr
                    ? '${missions.length} mission(s)'
                    : '${missions.length} job(s)',
              ),
              const SizedBox(height: 10),
              if (missions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Text(
                      fr
                          ? 'Aucune mission dans cette catégorie.'
                          : 'No jobs in this category.',
                    ),
                  ),
                ),
              ...missions.map(
                (mission) => _MissionCard(mission: mission, isFrench: fr),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _matches(DeliveryMission mission) => switch (_filter) {
    AdminMissionFilter.unassigned => adminMissionAwaitingAssignment(
      mission.status,
    ),
    AdminMissionFilter.all => true,
    AdminMissionFilter.active => _active.contains(mission.status),
    AdminMissionFilter.completed =>
      mission.status == MissionStatus.completed ||
          mission.status == MissionStatus.delivered,
    AdminMissionFilter.cancelled =>
      mission.status == MissionStatus.cancelled ||
          mission.status == MissionStatus.paymentFailed,
  };

  Widget _chip(AdminMissionFilter value, String label) => ChoiceChip(
    label: Text(label),
    selected: _filter == value,
    onSelected: (_) => setState(() => _filter = value),
  );
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission, required this.isFrench});
  final DeliveryMission mission;
  final bool isFrench;

  @override
  Widget build(BuildContext context) {
    final pickup =
        mission.pickupAddress?.formattedAddress ??
        mission.pickupAddress?.line1 ??
        '—';
    final dropoff =
        mission.dropoffAddress?.formattedAddress ??
        mission.dropoffAddress?.line1 ??
        '—';
    final customer = (mission.customerDisplayName?.trim().isNotEmpty ?? false)
        ? mission.customerDisplayName!
        : mission.customerId;
    final driver = (mission.driverDisplayName?.trim().isNotEmpty ?? false)
        ? mission.driverDisplayName!
        : (mission.driverId ?? (isFrench ? 'Non assigné' : 'Unassigned'));
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.route_outlined, color: AppColors.info),
        title: Text(
          customer,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(_statusLabel(mission.status, isFrench)),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        children: [
          if (mission.isInternalTest) ...[
            InternalTestMissionBanner(
              title: isFrench
                  ? 'TEST INTERNE — SANS PAIEMENT'
                  : 'INTERNAL TEST — NO PAYMENT',
              message: isFrench
                  ? 'Aucun paiement, revenu ou versement réel.'
                  : 'No real payment, revenue, or driver payout.',
            ),
            const SizedBox(height: 8),
          ],
          _line(Icons.trip_origin, pickup),
          _line(Icons.location_on_outlined, dropoff),
          _line(Icons.local_shipping_outlined, driver),
          _line(Icons.tag, mission.id),
          if (!mission.isInternalTest)
            AdminMissionFailureReview(
              key: ValueKey('failure-${mission.id}'),
              mission: mission,
            ),
          if (mission.driverId == null &&
              (mission.status == MissionStatus.searchingDriver ||
                  mission.status == MissionStatus.offered))
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: ValueKey('admin-assign-${mission.id}'),
                  onPressed: () => showAdminMissionAssignmentDialog(
                    context,
                    mission: mission,
                    isFrench: isFrench,
                  ),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: Text(
                    isFrench ? 'Assigner un chauffeur' : 'Assign a driver',
                  ),
                ),
              ),
            ),
          if (adminCancellableStatuses.contains(mission.status))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: ValueKey('admin-cancel-${mission.id}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  onPressed: () => _confirmCancel(context),
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(
                    isFrench ? 'Annuler la mission' : 'Cancel the job',
                  ),
                ),
              ),
            ),
          if (adminDeletableStatuses.contains(mission.status))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: ValueKey('admin-delete-${mission.id}'),
                  onPressed: () => _confirmDelete(context),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(isFrench ? 'Effacer' : 'Delete'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _tr(String fr, String en) => isFrench ? fr : en;

  Future<void> _confirmCancel(BuildContext context) async {
    final note = TextEditingController();
    final assigned = mission.driverId != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('admin-cancel-dialog'),
        title: Text(_tr('Annuler cette mission ?', 'Cancel this job?')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tr(
                'Le client ne paie rien : l’autorisation sur sa carte est libérée. Il voit « Movi-K a annulé cette demande ».',
                'The customer pays nothing: the card hold is released. They see “Movi-K cancelled this request”.',
              ),
            ),
            if (assigned) ...[
              const SizedBox(height: 8),
              Text(
                _tr(
                  'Le chauffeur assigné est libéré et repasse en ligne.',
                  'The assigned driver is released and back online.',
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: note,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: _tr(
                  'Raison (interne, facultative)',
                  'Reason (internal, optional)',
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_tr('Retour', 'Back')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_tr('Annuler la mission', 'Cancel the job')),
          ),
        ],
      ),
    );
    final reason = note.text.trim();
    note.dispose();
    if (confirmed != true || !context.mounted) return;
    await _run(
      context,
      {'action': 'cancel', 'missionId': mission.id, 'reason': reason},
      _tr('Mission annulée.', 'Job cancelled.'),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('admin-delete-dialog'),
        title: Text(_tr('Effacer cette mission ?', 'Delete this job?')),
        content: Text(
          _tr(
            'Elle disparaît des listes de l’admin. Son dossier est conservé (paiements, reçus, comptabilité).',
            'It disappears from the admin lists. Its record is kept (payments, receipts, accounting).',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_tr('Retour', 'Back')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_tr('Effacer', 'Delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _run(
      context,
      {'action': 'delete', 'missionId': mission.id},
      _tr('Mission effacée.', 'Job deleted.'),
    );
  }

  Future<void> _run(
    BuildContext context,
    Map<String, dynamic> data,
    String done,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('adminMissionActions')
          .call(data);
      messenger.showSnackBar(SnackBar(content: Text(done)));
    } on FirebaseFunctionsException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error.message ?? _tr('Action impossible.', 'Action failed.')),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(_tr('Action impossible.', 'Action failed.')),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Widget _line(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(top: 9),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
  static String _statusLabel(MissionStatus status, bool fr) {
    const frLabels = {
      MissionStatus.searchingDriver: 'Recherche d’un chauffeur',
      MissionStatus.offered: 'Offerte aux chauffeurs',
      MissionStatus.assigned: 'Chauffeur assigné',
      MissionStatus.driverToPickup: 'Chauffeur en route',
      MissionStatus.arrivedAtPickup: 'Arrivé au ramassage',
      MissionStatus.pickedUp: 'Ramassage effectué',
      MissionStatus.inTransit: 'En livraison',
      MissionStatus.arrivedAtDropoff: 'Arrivé à destination',
      MissionStatus.delivered: 'Livrée',
      MissionStatus.completed: 'Terminée',
      MissionStatus.cancelled: 'Annulée',
      MissionStatus.paymentFailed: 'Paiement refusé',
      MissionStatus.refunded: 'Remboursée',
      MissionStatus.disputed: 'Litige',
    };
    if (fr) return frLabels[status] ?? status.firestoreValue;
    return status.firestoreValue.replaceAll('_', ' ');
  }
}
