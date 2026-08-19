// ---------------------------------------------------------------------------
// CustomerTrackingScreen — suivi GPS temps réel du chauffeur pour UNE
// mission active (Phase 5).
//
// Source de vérité 100% temps réel : `watchMission(missionId)` pour l'état
// de la mission (statut, adresses, chauffeur assigné) + `LiveTrackingMap`
// (elle-même StreamBuilder sur `watchDriverLocation()`) pour la position.
// Protégé par firestore.rules côté serveur (le client ne peut lire
// `driver_locations/{driverId}` QUE s'il a une mission active avec ce
// chauffeur) — cet écran n'ajoute donc aucune fuite de données, il se
// contente d'exposer ce que le backend autorise déjà.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../backend/backend_locator.dart';
import '../../backend/models/delivery_mission.dart';
import '../../core/app_colors.dart';
import '../../models/enums.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/live_tracking_map.dart';

class CustomerTrackingScreen extends StatelessWidget {
  final String missionId;
  const CustomerTrackingScreen({super.key, required this.missionId});

  static const List<MissionStatus> _trackableStatuses = [
    MissionStatus.assigned,
    MissionStatus.driverToPickup,
    MissionStatus.arrivedAtPickup,
    MissionStatus.pickedUp,
    MissionStatus.inTransit,
    MissionStatus.arrivedAtDropoff,
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final locale = context.watch<LocaleProvider>().locale;

    return Scaffold(
      appBar: AppBar(
        title: Text(t('tracking_title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/$locale/dashboard'),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<DeliveryMission?>(
          stream: BackendLocator.missionRepository.watchMission(missionId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _CenteredMessage(
                icon: Icons.wifi_off_outlined,
                message: t('driver_active_mission_network_error'),
              );
            }
            final mission = snap.data;
            if (mission == null) {
              return _CenteredMessage(
                icon: Icons.search_off_outlined,
                message: t('driver_active_mission_not_found'),
              );
            }
            if (mission.driverId == null ||
                !_trackableStatuses.contains(mission.status)) {
              return _CenteredMessage(
                icon: Icons.local_shipping_outlined,
                message: t('tracking_not_available'),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: AppColors.deliveryGradient,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_shipping, color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mission.driverDisplayName ??
                                    t('tracking_driver_fallback'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                t(mission.status.key),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  LiveTrackingMap(
                    driverId: mission.driverId!,
                    pickup: mission.pickupAddress,
                    dropoff: mission.dropoffAddress,
                    t: t,
                  ),
                  const SizedBox(height: 16),
                  if (mission.pickupAddress != null)
                    _AddressRow(
                      icon: Icons.trip_origin,
                      color: AppColors.info,
                      label: t('driver_active_mission_pickup'),
                      value:
                          '${mission.pickupAddress!.line1}, ${mission.pickupAddress!.city}',
                    ),
                  if (mission.dropoffAddress != null) ...[
                    const SizedBox(height: 10),
                    _AddressRow(
                      icon: Icons.place,
                      color: AppColors.error,
                      label: t('driver_active_mission_dropoff'),
                      value:
                          '${mission.dropoffAddress!.line1}, ${mission.dropoffAddress!.city}',
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _AddressRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  const _CenteredMessage({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
