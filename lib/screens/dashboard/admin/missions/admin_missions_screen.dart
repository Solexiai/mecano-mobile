import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../backend/models/delivery_mission.dart';
import '../../../../core/app_colors.dart';
import '../../../../models/enums.dart';
import '../../../../providers/locale_provider.dart';
import '../../../../widgets/internal_test_mission_banner.dart';
import 'admin_mission_assignment_dialog.dart';

enum AdminMissionFilter { all, active, completed }

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
      'completed' => AdminMissionFilter.completed,
      'all' => AdminMissionFilter.all,
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
                  _chip(AdminMissionFilter.all, fr ? 'Toutes' : 'All'),
                  _chip(AdminMissionFilter.active, fr ? 'Actives' : 'Active'),
                  _chip(
                    AdminMissionFilter.completed,
                    fr ? 'Terminées' : 'Completed',
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
    AdminMissionFilter.all => true,
    AdminMissionFilter.active => _active.contains(mission.status),
    AdminMissionFilter.completed =>
      mission.status == MissionStatus.completed ||
          mission.status == MissionStatus.delivered,
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
          if (mission.driverId == null &&
              (mission.status == MissionStatus.searchingDriver ||
                  mission.status == MissionStatus.offered))
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
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
        ],
      ),
    );
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
    };
    if (fr) return frLabels[status] ?? status.firestoreValue;
    return status.firestoreValue.replaceAll('_', ' ');
  }
}
