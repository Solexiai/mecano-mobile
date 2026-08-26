// ---------------------------------------------------------------------------
// CustomerTrackingScreen — suivi GPS temps réel du chauffeur pour UNE
// mission active (Phase 5), ET consultation post-livraison (Phase 5,
// partie 3) : une mission `completed` reste pleinement consultable ici,
// avec sa preuve de livraison et sa timeline complète.
//
// Source de vérité 100% temps réel : `watchMission(missionId)` pour l'état
// de la mission (statut, adresses, chauffeur assigné, timestamps métier,
// proofOfDeliveryUrl) + `LiveTrackingMap` (elle-même StreamBuilder sur
// `watchDriverLocation()`) pour la position, UNIQUEMENT pendant la partie
// "en cours" du trajet.
//
// Protégé par firestore.rules côté serveur (le client ne peut lire
// `delivery_requests/{id}` QUE s'il est le customer_id ou le driver_id de
// la mission, et `driver_locations/{driverId}` QUE s'il a une mission
// active avec ce chauffeur) — cet écran n'ajoute donc aucune fuite de
// données, il se contente d'exposer ce que le backend autorise déjà. La
// preuve de livraison (`proofOfDeliveryUrl`) est un champ dénormalisé sur
// le document mission lui-même : aucune vérification de propriété
// additionnelle n'est nécessaire côté Flutter, `watchMission` ne renvoie
// déjà que des missions que ce client a le droit de lire.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../backend/backend_locator.dart';
import '../../backend/models/delivery_mission.dart';
import '../../core/app_colors.dart';
import '../../models/enums.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/live_tracking_map.dart';
import 'mission_finance_section.dart';

class CustomerTrackingScreen extends StatelessWidget {
  final String missionId;
  const CustomerTrackingScreen({super.key, required this.missionId});

  // Statuts pour lesquels le suivi GPS EN DIRECT (carte + position chauffeur)
  // a un sens. `completed` est géré séparément (_CompletedMissionView) : une
  // fois livrée, il n'y a plus de position à suivre, mais la mission reste
  // pleinement consultable.
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

    // Phase 7, Bloc B (MIS-C-07) : accès non authentifié — firestore.rules
    // refuse déjà la lecture côté serveur (aucune fuite de données possible,
    // voir securityRules.test.ts), mais SANS cette garde le StreamBuilder
    // ci-dessous recevait l'erreur de permission Firestore et affichait à
    // tort le message générique "erreur réseau" au lieu d'inviter l'usager
    // à se connecter — incohérent avec CustomerDashboardShell/
    // ProviderDashboardShell/DriverActiveMissionScreen qui gèrent déjà ce
    // cas explicitement.
    final auth = context.watch<FirebaseAuthProvider>();
    if (!auth.isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: Text(t('tracking_title'))),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 48,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    t('tracking_locked_message'),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => context.go('/$locale/connexion'),
                    child: Text(t('delivery_sign_in_button')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t('tracking_title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: t('common_back'),
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

            // Défense en profondeur (Bloc F, gap F-1) : ne jamais afficher
            // les données d'une mission qui n'appartient pas au client
            // connecté, même si firestore.rules devrait déjà l'empêcher en
            // production. Symétrique du check équivalent dans
            // `DriverActiveMissionScreen` (`mission.driverId != uid`) —
            // avant ce correctif, un `MissionRepository` mal configuré, un
            // bug de règles, ou un test/environnement de dev sans Security
            // Rules actives pouvait laisser fuiter les données d'un autre
            // client (nom, adresse, montant, chauffeur assigné) jusqu'à
            // l'écran, sans aucun garde-fou côté Flutter.
            if (mission.customerId != auth.effectiveUid) {
              return _CenteredMessage(
                icon: Icons.block_outlined,
                message: t('driver_active_mission_access_denied'),
              );
            }

            // Mission complétée : vue dédiée (statut, date, preuve,
            // timeline complète) — plus jamais de carte GPS en direct.
            if (mission.status == MissionStatus.completed) {
              return _CompletedMissionView(mission: mission, t: t);
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
                    missionId: mission.id,
                    t: t,
                  ),
                  const SizedBox(height: 16),
                  _DeliveryTimeline(mission: mission, t: t),
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

/// Vue dédiée pour une mission `completed` (point 7/8/9, Phase 5 partie 3) :
/// statut + date/heure, preuve de livraison, timeline complète, infos utiles.
class _CompletedMissionView extends StatelessWidget {
  final DeliveryMission mission;
  final String Function(String) t;
  const _CompletedMissionView({required this.mission, required this.t});

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final y = local.year.toString();
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/$y à $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.success,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('customer_tracking_completed_title'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        t('customer_tracking_completed_message'),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      if (mission.completedAt != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(mission.completedAt!),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            t('customer_tracking_proof_title'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 10),
          _ProofOfDeliveryView(url: mission.proofOfDeliveryUrl, t: t),
          const SizedBox(height: 20),
          _DeliveryTimeline(mission: mission, t: t),
          const SizedBox(height: 20),
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
          const SizedBox(height: 20),
          // Bloc J — vue financière client (résumé, paiement, remboursement,
          // historique). Intégrée directement au détail de la mission plutôt
          // que dans un onglet global dédié : les données financières sont
          // naturellement scopées par mission (voir décision technique
          // Bloc J point 7).
          MissionFinanceSection(missionId: mission.id, t: t),
        ],
      ),
    );
  }
}

/// Affiche la photo de preuve de livraison avec gestion complète des états
/// (loading / URL absente / erreur réseau ou image indisponible) — point 8.
class _ProofOfDeliveryView extends StatelessWidget {
  final String? url;
  final String Function(String) t;
  const _ProofOfDeliveryView({required this.url, required this.t});

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _proofPlaceholder(
        icon: Icons.image_not_supported_outlined,
        message: t('customer_tracking_proof_unavailable'),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 220,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 220,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        },
        errorBuilder: (context, error, stackTrace) => _proofPlaceholder(
          icon: Icons.broken_image_outlined,
          message: t('customer_tracking_proof_unavailable'),
        ),
      ),
    );
  }

  Widget _proofPlaceholder({required IconData icon, required String message}) {
    return Container(
      height: 160,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.border.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 36, color: AppColors.textSecondary),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Timeline réelle de la livraison, construite à partir des timestamps
/// métier réels (`acceptedAt`, `driverToPickupAt`, ... `completedAt`) —
/// jamais reconstruite uniquement à partir de `updated_at` (point 9).
class _DeliveryTimeline extends StatelessWidget {
  final DeliveryMission mission;
  final String Function(String) t;
  const _DeliveryTimeline({required this.mission, required this.t});

  @override
  Widget build(BuildContext context) {
    final steps = <_TimelineStep>[
      _TimelineStep(t('mission_status_assigned'), mission.acceptedAt),
      _TimelineStep(
        t('mission_status_drivertopickup'),
        mission.driverToPickupAt,
      ),
      _TimelineStep(
        t('mission_status_arrivedatpickup'),
        mission.arrivedAtPickupAt,
      ),
      _TimelineStep(
        t('mission_status_pickedup'),
        mission.pickedUpAt ?? mission.inTransitAt,
      ),
      _TimelineStep(
        t('mission_status_arrivedatdropoff'),
        mission.arrivedAtDropoffAt,
      ),
      _TimelineStep(t('mission_status_completed'), mission.completedAt),
    ];

    // Le dernier step avec un timestamp non-null est "atteint" ; le premier
    // step SANS timestamp après lui est "en cours" (courant), le reste "à
    // venir" — permet un rendu visuel cohérent même pour une mission encore
    // active (pas seulement completed).
    final lastReachedIndex = steps.lastIndexWhere((s) => s.timestamp != null);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('tracking_timeline_title'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            _TimelineRow(
              step: steps[i],
              reached: i <= lastReachedIndex,
              isCurrent: i == lastReachedIndex + 1,
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineStep {
  final String label;
  final DateTime? timestamp;
  const _TimelineStep(this.label, this.timestamp);
}

class _TimelineRow extends StatelessWidget {
  final _TimelineStep step;
  final bool reached;
  final bool isCurrent;
  final bool isLast;
  const _TimelineRow({
    required this.step,
    required this.reached,
    required this.isCurrent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = reached
        ? AppColors.success
        : (isCurrent ? AppColors.info : AppColors.textSecondary);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                reached
                    ? Icons.check_circle
                    : (isCurrent
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked),
                size: 18,
                color: color,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: reached
                        ? AppColors.success.withValues(alpha: 0.4)
                        : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                step.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: reached || isCurrent
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: reached
                      ? AppColors.textPrimary
                      : (isCurrent
                            ? AppColors.textPrimary
                            : AppColors.textSecondary),
                ),
              ),
            ),
          ),
        ],
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
