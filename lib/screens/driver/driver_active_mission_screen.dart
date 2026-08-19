// ---------------------------------------------------------------------------
// DriverActiveMissionScreen — Phase 4, écran Mission Active Chauffeur.
//
// Point d'entrée après acceptation d'une mission (`acceptMission()` ->
// navigation depuis `provider_jobs_tab.dart`) ou reprise d'app via la
// bannière de `ProviderJobsTab`/`ProviderDashboardShell`
// (`watchActiveMissionForDriver()`).
//
// RÈGLES RESPECTÉES :
// - Source de vérité unique et 100% temps réel : `watchMission(missionId)`
//   via `StreamBuilder<DeliveryMission?>`. Aucune donnée mise en cache
//   localement, aucune modification optimiste de statut.
// - Les actions par statut appellent EXCLUSIVEMENT les méthodes existantes
//   du repository : `updateTrackingStatus()` (transitions intermédiaires
//   sans impact financier) ou `markPickupCompleted()`/
//   `markDeliveryCompleted()` (transitions à impact financier, gérées par
//   les Cloud Functions `completePickup`/`completeDelivery`). Aucune
//   écriture Firestore directe, aucun saut de statut arbitraire.
// - AUCUN faux succès : chaque état (loading / introuvable / annulée /
//   déjà complétée / erreur réseau / erreur Cloud Function / accès
//   interdit) affiche un message et un CTA propres à son état réel.
// - `access denied` défensif : si `mission.driverId != uid` (ne devrait
//   jamais arriver compte tenu des security rules et du filtrage de
//   `watchActiveMissionForDriver`), l'écran refuse d'afficher les données
//   et propose de retourner à la liste des jobs plutôt que d'exposer les
//   informations d'un autre chauffeur.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../backend/backend_locator.dart';
import '../../backend/backend_exceptions.dart';
import '../../backend/models/delivery_mission.dart';
import '../../core/app_colors.dart';
import '../../models/enums.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/driver_location_reporter.dart';
import '../../widgets/live_tracking_map.dart';

/// Statuts de trajet pendant lesquels le chauffeur doit partager sa
/// position GPS (Phase 5) — le partage s'arrête dès que la mission n'est
/// plus dans l'un de ces états (livrée, annulée, etc.).
const List<MissionStatus> _kGpsSharingStatuses = [
  MissionStatus.assigned,
  MissionStatus.driverToPickup,
  MissionStatus.arrivedAtPickup,
  MissionStatus.pickedUp,
  MissionStatus.inTransit,
  MissionStatus.arrivedAtDropoff,
];

class DriverActiveMissionScreen extends StatefulWidget {
  final String missionId;
  const DriverActiveMissionScreen({super.key, required this.missionId});

  @override
  State<DriverActiveMissionScreen> createState() =>
      _DriverActiveMissionScreenState();
}

class _DriverActiveMissionScreenState extends State<DriverActiveMissionScreen> {
  bool _actionInProgress = false;
  String? _actionErrorKey;
  final DriverLocationReporter _locationReporter = DriverLocationReporter();
  String? _gpsWarningKey;

  @override
  void dispose() {
    _locationReporter.stop();
    super.dispose();
  }

  void _syncGpsSharing(MissionStatus status) {
    final shouldShare = _kGpsSharingStatuses.contains(status);
    if (shouldShare && !_locationReporter.isRunning) {
      _locationReporter.start(onError: _handleGpsError);
    } else if (!shouldShare && _locationReporter.isRunning) {
      _locationReporter.stop();
    }
  }

  void _handleGpsError(LocationReporterError error) {
    if (!mounted) return;
    final key = switch (error) {
      LocationReporterError.serviceDisabled =>
        'driver_active_mission_gps_disabled',
      LocationReporterError.permissionDenied ||
      LocationReporterError.permissionDeniedForever =>
        'driver_active_mission_gps_permission_denied',
      LocationReporterError.reportFailed =>
        'driver_active_mission_gps_report_failed',
    };
    setState(() => _gpsWarningKey = key);
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() {
      _actionInProgress = true;
      _actionErrorKey = null;
    });
    try {
      await action();
    } on CloudFunctionException {
      if (!mounted) return;
      setState(() => _actionErrorKey = 'driver_active_mission_cf_error');
    } catch (_) {
      if (!mounted) return;
      setState(() => _actionErrorKey = 'driver_active_mission_action_error');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final auth = context.watch<FirebaseAuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(t('driver_active_mission_title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go(
                  '/${context.read<LocaleProvider>().locale}/provider/dashboard',
                ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: _buildBody(context, t, auth),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    String Function(String) t,
    FirebaseAuthProvider auth,
  ) {
    if (!auth.isSignedIn || auth.user == null) {
      return _MessageCard(
        icon: Icons.lock_outline,
        color: AppColors.error,
        message: t('driver_active_mission_access_denied'),
        actionLabel: t('driver_jobs_title'),
        onAction: () => context.go(
          '/${context.read<LocaleProvider>().locale}/provider/dashboard',
        ),
      );
    }

    final uid = auth.user!.uid;
    final repo = BackendLocator.missionRepository;

    return StreamBuilder<DeliveryMission?>(
      stream: repo.watchMission(widget.missionId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasError) {
          return _MessageCard(
            icon: Icons.wifi_off_outlined,
            color: AppColors.error,
            message: t('driver_active_mission_network_error'),
            actionLabel: t('requests_retry'),
            onAction: () => setState(() {}),
          );
        }

        final mission = snap.data;

        if (mission == null) {
          return _MessageCard(
            icon: Icons.search_off_outlined,
            color: AppColors.textSecondary,
            message: t('driver_active_mission_not_found'),
            actionLabel: t('driver_jobs_title'),
            onAction: () => context.go(
              '/${context.read<LocaleProvider>().locale}/provider/dashboard',
            ),
          );
        }

        // Défense en profondeur : ne jamais afficher les données d'une
        // mission qui n'appartient pas au chauffeur connecté, même si les
        // security rules / le filtrage amont devraient déjà l'empêcher.
        if (mission.driverId != uid) {
          return _MessageCard(
            icon: Icons.block_outlined,
            color: AppColors.error,
            message: t('driver_active_mission_access_denied'),
            actionLabel: t('driver_jobs_title'),
            onAction: () => context.go(
              '/${context.read<LocaleProvider>().locale}/provider/dashboard',
            ),
          );
        }

        if (mission.status == MissionStatus.cancelled) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _locationReporter.stop(),
          );
          return _MessageCard(
            icon: Icons.cancel_outlined,
            color: AppColors.error,
            message: t('driver_active_mission_cancelled'),
            actionLabel: t('driver_jobs_title'),
            onAction: () => context.go(
              '/${context.read<LocaleProvider>().locale}/provider/dashboard',
            ),
          );
        }

        if (mission.status == MissionStatus.completed) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _locationReporter.stop(),
          );
          return _MessageCard(
            icon: Icons.check_circle_outline,
            color: AppColors.success,
            message: t('driver_active_mission_already_completed'),
            actionLabel: t('driver_jobs_title'),
            onAction: () => context.go(
              '/${context.read<LocaleProvider>().locale}/provider/dashboard',
            ),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _syncGpsSharing(mission.status),
        );

        return _MissionCard(
          mission: mission,
          t: t,
          busy: _actionInProgress,
          errorKey: _actionErrorKey,
          gpsWarningKey: _gpsWarningKey,
          onStartToPickup: () => _runAction(
            () => repo.updateTrackingStatus(
              missionId: mission.id,
              targetStatus: MissionStatus.driverToPickup,
            ),
          ),
          onArrivedAtPickup: () => _runAction(
            () => repo.updateTrackingStatus(
              missionId: mission.id,
              targetStatus: MissionStatus.arrivedAtPickup,
            ),
          ),
          onConfirmPickup: () =>
              _runAction(() => repo.markPickupCompleted(mission.id)),
          onStartTransit: () => _runAction(
            () => repo.updateTrackingStatus(
              missionId: mission.id,
              targetStatus: MissionStatus.inTransit,
            ),
          ),
          onArrivedAtDropoff: () => _runAction(
            () => repo.updateTrackingStatus(
              missionId: mission.id,
              targetStatus: MissionStatus.arrivedAtDropoff,
            ),
          ),
          onCompleteDelivery: () =>
              _runAction(() => repo.markDeliveryCompleted(mission.id)),
        );
      },
    );
  }
}

/// Ordre canonique des statuts de trajet — utilisé uniquement pour calculer
/// une progression visuelle (0.0 -> 1.0), jamais pour décider des
/// transitions autorisées (celles-ci restent server-side, voir
/// `updateMissionTrackingStatus.ts`).
const List<MissionStatus> _kTripStatusOrder = [
  MissionStatus.assigned,
  MissionStatus.driverToPickup,
  MissionStatus.arrivedAtPickup,
  MissionStatus.pickedUp,
  MissionStatus.inTransit,
  MissionStatus.arrivedAtDropoff,
  MissionStatus.completed,
];

class _MissionCard extends StatelessWidget {
  final DeliveryMission mission;
  final String Function(String) t;
  final bool busy;
  final String? errorKey;
  final String? gpsWarningKey;
  final VoidCallback onStartToPickup;
  final VoidCallback onArrivedAtPickup;
  final VoidCallback onConfirmPickup;
  final VoidCallback onStartTransit;
  final VoidCallback onArrivedAtDropoff;
  final VoidCallback onCompleteDelivery;

  const _MissionCard({
    required this.mission,
    required this.t,
    required this.busy,
    required this.errorKey,
    this.gpsWarningKey,
    required this.onStartToPickup,
    required this.onArrivedAtPickup,
    required this.onConfirmPickup,
    required this.onStartTransit,
    required this.onArrivedAtDropoff,
    required this.onCompleteDelivery,
  });

  double get _progress {
    final idx = _kTripStatusOrder.indexOf(mission.status);
    if (idx < 0) return 0;
    return idx / (_kTripStatusOrder.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final pickup = mission.pickupAddress;
    final dropoff = mission.dropoffAddress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // --- Statut + progression ---------------------------------------
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.deliveryGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t(mission.status.key),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 8,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // --- Détails mission ---------------------------------------------
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pickup != null)
                _DetailRow(
                  icon: Icons.trip_origin,
                  label: t('driver_active_mission_pickup'),
                  value: '${pickup.line1}, ${pickup.city}',
                ),
              if (dropoff != null) ...[
                const SizedBox(height: 10),
                _DetailRow(
                  icon: Icons.place,
                  label: t('driver_active_mission_dropoff'),
                  value: '${dropoff.line1}, ${dropoff.city}',
                ),
              ],
              if (mission.description.isNotEmpty) ...[
                const SizedBox(height: 10),
                _DetailRow(
                  icon: Icons.info_outline,
                  label: t('driver_active_mission_instructions'),
                  value: mission.description,
                ),
              ],
              if (mission.distanceKm != null) ...[
                const SizedBox(height: 10),
                _DetailRow(
                  icon: Icons.social_distance,
                  label: t('driver_jobs_distance'),
                  value: '${mission.distanceKm!.toStringAsFixed(1)} km',
                ),
              ],
              if (mission.estimatedDurationMinutes != null) ...[
                const SizedBox(height: 10),
                _DetailRow(
                  icon: Icons.schedule,
                  label: t('driver_active_mission_duration'),
                  value: '${mission.estimatedDurationMinutes!.round()} min',
                ),
              ],
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.local_shipping_outlined,
                label: t('driver_active_mission_vehicle'),
                value: t(mission.requiredVehicleCategory.key),
              ),
              const SizedBox(height: 10),
              _DetailRow(
                icon: Icons.attach_money,
                label: t('driver_active_mission_expected_pay'),
                value: '${mission.driverOfferAmount.toStringAsFixed(2)}\$',
                valueColor: AppColors.primary,
                valueBold: true,
              ),
            ],
          ),
        ),

        // --- Ma position (Phase 5) — confirmation visuelle que le
        // partage GPS fonctionne, avec repères pickup/dropoff. ---------
        const SizedBox(height: 18),
        LiveTrackingMap(
          driverId: mission.driverId ?? '',
          pickup: pickup,
          dropoff: dropoff,
          missionId: mission.id,
          t: t,
        ),

        if (gpsWarningKey != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.gps_off, color: AppColors.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t(gpsWarningKey!),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (errorKey != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    t(errorKey!),
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 20),
        ..._buildActions(context),
      ],
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    Widget button(String labelKey, VoidCallback onPressed) => SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(t(labelKey)),
      ),
    );

    switch (mission.status) {
      case MissionStatus.assigned:
        return [
          button('driver_active_mission_start_to_pickup', onStartToPickup),
        ];
      case MissionStatus.driverToPickup:
        return [
          button('driver_active_mission_arrived_at_pickup', onArrivedAtPickup),
        ];
      case MissionStatus.arrivedAtPickup:
        return [button('driver_active_mission_mark_pickup', onConfirmPickup)];
      case MissionStatus.pickedUp:
        return [button('driver_active_mission_start_transit', onStartTransit)];
      case MissionStatus.inTransit:
        return [
          button(
            'driver_active_mission_arrived_at_dropoff',
            onArrivedAtDropoff,
          ),
        ];
      case MissionStatus.arrivedAtDropoff:
        return [
          button('driver_active_mission_mark_delivered', onCompleteDelivery),
        ];
      default:
        return const [];
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final bool valueBold;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
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
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: valueColor,
                  fontWeight: valueBold ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _MessageCard({
    required this.icon,
    required this.color,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: color),
              const SizedBox(height: 16),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      ),
    );
  }
}
