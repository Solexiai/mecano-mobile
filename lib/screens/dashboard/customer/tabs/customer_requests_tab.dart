import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../backend/backend_locator.dart';
import '../../../../backend/models/delivery_mission.dart';
import '../../../../core/app_colors.dart';
import '../../../../models/enums.dart';
import '../../../../providers/firebase_auth_provider.dart';
import '../../../../providers/locale_provider.dart';
import '../../../../providers/mechanic_provider.dart';

/// Onglet "Mes demandes" du client.
///
/// Livraisons : données 100% réelles Firebase via
/// `MissionRepository.watchCustomerMissions()` (temps réel, statuts serveur).
/// Mécanique : hors périmètre Phase 4 (domaine non migré), conservé en
/// lecture depuis le provider local existant.
class CustomerRequestsTab extends StatefulWidget {
  const CustomerRequestsTab({super.key});

  @override
  State<CustomerRequestsTab> createState() => _CustomerRequestsTabState();
}

class _CustomerRequestsTabState extends State<CustomerRequestsTab> {
  int _filter = 0; // 0 = toutes, 1 = livraisons, 2 = mécanique

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FirebaseAuthProvider>();
    final t = context.watch<LocaleProvider>().t;

    if (!auth.isSignedIn || auth.user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            t('delivery_login_required'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final customerId = auth.user!.uid;
    final mechanicJobs = context.watch<MechanicRequestProvider>().forCustomer(
      customerId,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('requests_title'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            children: [
              ChoiceChip(
                label: Text(t('requests_filter_all')),
                selected: _filter == 0,
                onSelected: (_) => setState(() => _filter = 0),
              ),
              ChoiceChip(
                label: Text(t('requests_filter_delivery')),
                selected: _filter == 1,
                onSelected: (_) => setState(() => _filter = 1),
              ),
              ChoiceChip(
                label: Text(t('requests_filter_mechanic')),
                selected: _filter == 2,
                onSelected: (_) => setState(() => _filter = 2),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_filter != 2)
            StreamBuilder<List<DeliveryMission>>(
              stream: BackendLocator.missionRepository.watchCustomerMissions(
                customerId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            t('requests_loading'),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 32,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t('requests_error'),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => setState(() {}),
                            child: Text(t('requests_retry')),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final missions = snapshot.data ?? const <DeliveryMission>[];
                if (missions.isEmpty &&
                    (_filter == 1 || mechanicJobs.isEmpty)) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        t('requests_empty'),
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  );
                }
                final locale = context.watch<LocaleProvider>().locale;
                return Column(
                  children: missions
                      .map(
                        (m) => _DeliveryTile(mission: m, t: t, locale: locale),
                      )
                      .toList(),
                );
              },
            ),
          if (_filter != 1)
            ...mechanicJobs.map((m) => _MechanicTile(request: m, t: t)),
        ],
      ),
    );
  }
}

/// Statuts pour lesquels le suivi GPS temps réel a un sens (chauffeur
/// assigné et en trajet) — miroir de `CustomerTrackingScreen._trackableStatuses`.
const List<MissionStatus> _kTrackableStatuses = [
  MissionStatus.assigned,
  MissionStatus.driverToPickup,
  MissionStatus.arrivedAtPickup,
  MissionStatus.pickedUp,
  MissionStatus.inTransit,
  MissionStatus.arrivedAtDropoff,
];

class _DeliveryTile extends StatelessWidget {
  final DeliveryMission mission;
  final String Function(String) t;
  final String locale;
  const _DeliveryTile({
    required this.mission,
    required this.t,
    required this.locale,
  });

  @override
  Widget build(BuildContext context) {
    final pickup = mission.pickupAddress;
    final dropoff = mission.dropoffAddress;
    final route = (pickup != null && dropoff != null)
        ? '${pickup.city} → ${dropoff.city}'
        : t('delivery_step_addresses_title');
    final canTrack =
        mission.driverId != null &&
        _kTrackableStatuses.contains(mission.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.deliveryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.local_shipping_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.itemCategoryKey.isEmpty
                          ? t('delivery_item_category')
                          : t(mission.itemCategoryKey),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      route,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (mission.customerTotal > 0)
                Text(
                  '${mission.customerTotal.toStringAsFixed(2)} \$',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatusChip(label: t(mission.status.key), status: mission.status),
              if (canTrack) ...[
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () =>
                      context.go('/$locale/livraison/suivi/${mission.id}'),
                  icon: const Icon(Icons.my_location, size: 16),
                  label: Text(t('requests_track_driver')),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MechanicTile extends StatelessWidget {
  final dynamic request;
  final String Function(String) t;
  const _MechanicTile({required this.request, required this.t});

  @override
  Widget build(BuildContext context) {
    final MechanicJobStatus status = request.status;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppColors.mechanicGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.build_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.selectedServices.isEmpty
                          ? t('delivery_item_category')
                          : (request.selectedServices as List<String>)
                                .map(t)
                                .join(', '),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${request.vehicleMake} ${request.vehicleModel} (${request.vehicleYear})',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.name,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.info,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final MissionStatus status;
  const _StatusChip({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color = AppColors.info;
    switch (status) {
      case MissionStatus.cancelled:
      case MissionStatus.disputed:
        color = AppColors.error;
        break;
      case MissionStatus.delivered:
      case MissionStatus.completed:
      case MissionStatus.refunded:
        color = AppColors.success;
        break;
      default:
        color = AppColors.info;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
