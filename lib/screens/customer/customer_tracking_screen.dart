import '../../widgets/booking_load_summary.dart';
import '../../widgets/cancel_mission_button.dart';
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
import '../../widgets/scheduled_mission_panel.dart';
import '../../widgets/driver_search_status.dart';
import '../../services/booking/booking_api.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import '../../backend/backend_locator.dart';
import '../../backend/models/delivery_mission.dart';
import '../../backend/models/mission_rating.dart';
import '../../core/app_colors.dart';
import '../../models/enums.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/internal_test_mission_banner.dart';
import '../../widgets/live_tracking_map.dart';
import 'mission_finance_section.dart';
import '../dashboard/customer/customer_mission_view.dart';

class CustomerTrackingScreen extends StatelessWidget {
  final String missionId;

  /// Server calls (payment receipt); Firebase by default. Test seam.
  final BookingApi? api;
  const CustomerTrackingScreen({super.key, required this.missionId, this.api});

  /// Opens the Stripe receipt page; `launchUrl` by default. Test seam.
  @visibleForTesting
  static Future<bool> Function(Uri uri)? openReceiptOverride;

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
        appBar: AppBar(
          toolbarHeight:
              kToolbarHeight * MediaQuery.textScalerOf(context).scale(1),
          title: Text(
            t('customer_tracking_title'),
            maxLines: 2,
            softWrap: true,
          ),
        ),
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
        toolbarHeight:
            kToolbarHeight * MediaQuery.textScalerOf(context).scale(1),
        title: Text(t('customer_tracking_title'), maxLines: 2, softWrap: true),
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
          key: ValueKey('${auth.effectiveUid}|$missionId'),
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

            // Never substitute the route ID for missing or incompatible data.
            if (mission.id.trim().isEmpty) {
              return _MissionStatusView(
                mission: mission,
                t: t,
                message: t('tracking_status_unavailable'),
              );
            }
            if (mission.id != missionId) {
              return _CenteredMessage(
                icon: Icons.search_off_outlined,
                message: t('driver_active_mission_not_found'),
              );
            }

            // Mission complétée : vue dédiée (statut, date, preuve,
            // timeline complète) — plus jamais de carte GPS en direct.
            if (mission.status == MissionStatus.completed) {
              return _CompletedMissionView(
                mission: mission,
                t: t,
                api: api ?? FirebaseBookingApi(auth.effectiveUid),
              );
            }

            // Before pickup, the customer can cancel (fee policy 2026-10-22:
            // the server shows the exact fee, if any, before confirming).
            Widget withCancellation(Widget view) =>
                customerCancellableStatuses.contains(mission.status)
                ? Column(
                    children: [
                      Expanded(child: view),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                        child: CancelMissionButton(
                          missionId: mission.id,
                          locale: locale,
                          api: FirebaseBookingApi(auth.effectiveUid!),
                        ),
                      ),
                    ],
                  )
                : view;

            if ([
                  'reserved',
                  'ready_to_start',
                ].contains(mission.scheduleState) &&
                mission.status == MissionStatus.assigned &&
                mission.scheduling != null &&
                mission.hasAssignedDriver) {
              return withCancellation(
                ScheduledMissionPanel(mission: mission, locale: locale),
              );
            }
            if (mission.status.isOpenForAcceptance &&
                mission.dispatchState != null &&
                !mission.hasAssignedDriver) {
              return withCancellation(
                DriverSearchStatus(
                  missionId: mission.id,
                  state: mission.dispatchState!,
                  locale: locale,
                  api: FirebaseBookingApi(auth.effectiveUid!),
                ),
              );
            }
            final hasDriver = mission.driverId?.trim().isNotEmpty ?? false;
            if (!hasDriver || !_trackableStatuses.contains(mission.status)) {
              final String message;
              if (mission.status.isOpenForAcceptance && !hasDriver) {
                message = t('tracking_searching_driver');
              } else if (_trackableStatuses.contains(mission.status) &&
                  !hasDriver) {
                message = t('tracking_no_driver_assigned');
              } else if (mission.status == MissionStatus.draft ||
                  mission.status == MissionStatus.unknown ||
                  mission.status.isOpenForAcceptance) {
                // A missing status maps to draft and an unsupported raw
                // status to unknown (SEC/TECH-04). Do not infer an active
                // search or a confirmed assignment from either.
                message = t('tracking_status_unavailable');
              } else {
                message = t(mission.status.key);
              }
              return withCancellation(
                _MissionStatusView(mission: mission, t: t, message: message),
              );
            }

            return withCancellation(SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (mission.isInternalTest) ...[
                    InternalTestMissionBanner(
                      title: t('internal_test_mission_title'),
                      message: t('internal_test_mission_message'),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _LiveHeader(mission: mission, locale: locale, t: t),
                  const SizedBox(height: 14),
                  LiveTrackingMap(
                    driverId: mission.driverId!,
                    pickup: mission.pickupAddress,
                    dropoff: mission.dropoffAddress,
                    missionId: mission.id,
                    acceptedAt: mission.acceptedAt,
                    t: t,
                  ),
                  const SizedBox(height: 14),
                  _LiveDriverCard(mission: mission, locale: locale, t: t),
                  const SizedBox(height: 14),
                  _DeliveryTimeline(mission: mission, t: t),
                  if (mission.pickupAddress != null) ...[
                    const SizedBox(height: 14),
                    _AddressRow(
                      icon: Icons.trip_origin,
                      color: AppColors.info,
                      label: t('driver_active_mission_pickup'),
                      value:
                          '${mission.pickupAddress!.line1}, ${mission.pickupAddress!.city}',
                    ),
                  ],
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
                  if (mission.bookingSnapshot != null) ...[
                    const SizedBox(height: 8),
                    ExpansionTile(
                      key: const ValueKey('tracking-more'),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(bottom: 12),
                      title: Text(
                        switch (locale) {
                          'en' => 'What is being moved',
                          'es' => 'Lo que se transporta',
                          _ => 'Ce qui est transporté',
                        },
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      children: [
                        BookingLoadSummary(
                          snapshot: mission.bookingSnapshot!,
                          locale: locale,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  _MissionReference(mission: mission, t: t),
                ],
              ),
            ));
          },
        ),
      ),
    );
  }
}

/// Haut du suivi (maquette écran 2) : l'étape en clair, l'heure d'arrivée
/// estimée une fois l'article chargé, la barre de progression en 4 étapes.
class _LiveHeader extends StatelessWidget {
  final DeliveryMission mission;
  final String locale;
  final String Function(String) t;
  const _LiveHeader({
    required this.mission,
    required this.locale,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    String tr(String fr, String en, String es) => locale == 'en'
        ? en
        : locale == 'es'
        ? es
        : fr;
    final eta = customerEstimatedArrival(mission, DateTime.now());
    final progress = customerProgress(mission);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          customerStatusLabel(mission, locale),
          key: const ValueKey('tracking-live-status'),
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        if (eta != null) ...[
          Text(
            tr(
              'Arrivée vers ${customerTimeLabel(eta, locale)}',
              'Arriving around ${customerTimeLabel(eta, locale)}',
              'Llega hacia las ${customerTimeLabel(eta, locale)}',
            ),
            key: const ValueKey('tracking-eta'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            tr(
              'Estimation selon le trajet prévu, sans la circulation.',
              'Estimate from the planned route, without traffic.',
              'Estimación según la ruta prevista, sin tráfico.',
            ),
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ] else
          Text(
            customerMissionTitle(mission, locale, t),
            key: const ValueKey('tracking-live-title'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          '${customerMissionRoute(mission, locale)} · ${customerMoney(mission, locale)}',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Semantics(
          label: tr(
            'Étape $progress sur 4',
            'Step $progress of 4',
            'Paso $progress de 4',
          ),
          child: ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 1; i <= 4; i++) ...[
                  if (i > 1) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 5,
                      decoration: BoxDecoration(
                        color: i <= progress
                            ? AppColors.primary
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Le chauffeur (maquette écran 2) : son initiale, son nom et l'étape ;
/// « Aide » ouvre le contact. Pas de bouton d'appel : le numéro du
/// chauffeur n'est pas partagé avec le client.
class _LiveDriverCard extends StatelessWidget {
  final DeliveryMission mission;
  final String locale;
  final String Function(String) t;
  const _LiveDriverCard({
    required this.mission,
    required this.locale,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final name = mission.driverDisplayName ?? t('tracking_driver_fallback');
    final initial = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1).toUpperCase();
    return Container(
      key: const ValueKey('tracking-driver-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE6EDFA),
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  t(mission.status.key),
                  style: const TextStyle(color: Color(0xFFC9D6EF)),
                ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('tracking-help'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => context.go('/$locale/contact'),
            child: Text(switch (locale) {
              'en' => 'Help',
              'es' => 'Ayuda',
              _ => 'Aide',
            }),
          ),
        ],
      ),
    );
  }
}

class _MissionReference extends StatelessWidget {
  final DeliveryMission mission;
  final String Function(String) t;
  const _MissionReference({required this.mission, required this.t});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        mission.id.trim().isEmpty
            ? t('tracking_reference_unavailable')
            : '${t('tracking_reference')} : ${mission.id}',
        key: const ValueKey('tracking-mission-reference'),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      if (mission.bookingSnapshot != null)
        TextButton(
          onPressed: () => context.push(
            '/${context.read<LocaleProvider>().locale}/livraison/conditions/${mission.id}',
          ),
          child: Text(switch (context.read<LocaleProvider>().locale) {
            'en' => 'Booking summary and original terms',
            'es' => 'Resumen y condiciones originales',
            _ => 'Récapitulatif et conditions d’origine',
          }),
        ),
    ],
  );
}

class _MissionStatusView extends StatelessWidget {
  final DeliveryMission mission;
  final String Function(String) t;
  final String message;
  const _MissionStatusView({
    required this.mission,
    required this.t,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MissionReference(mission: mission, t: t),
        const SizedBox(height: 24),
        Text(message, key: const ValueKey('tracking-mission-state')),
        if (cancellationFeeSummary(
              mission.cancellationFee,
              context.read<LocaleProvider>().locale,
            )
            case final fee?) ...[
          const SizedBox(height: 8),
          Text(fee, key: const ValueKey('tracking-cancellation-fee')),
        ],
      ],
    ),
  );
}

/// Détail d'une livraison terminée, comme un reçu Uber (maquette validée par
/// le propriétaire le 2026-10-25) : quoi, quand, la photo, les deux adresses,
/// le total, la note, puis trois gestes simples. Le reste (étapes, résumé du
/// chargement, paiement) est replié plus bas, jamais supprimé.
class _CompletedMissionView extends StatelessWidget {
  final DeliveryMission mission;
  final String Function(String) t;
  final BookingApi api;
  const _CompletedMissionView({
    required this.mission,
    required this.t,
    required this.api,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.read<LocaleProvider>().locale;
    String tr(String fr, String en, String es) => locale == 'en'
        ? en
        : locale == 'es'
        ? es
        : fr;
    final done = mission.completedAt?.toLocal();
    final day = customerDateLabel(done ?? customerMissionDate(mission), locale);
    final theme = Theme.of(context);
    final cardDecoration = BoxDecoration(
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    );
    const secondary = TextStyle(
      fontSize: 12.5,
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
    );
    Widget stop(String letter, Color color, String label, String value) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: color,
          child: Text(
            letter,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: secondary),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
    final pickup = mission.pickupAddress, dropoff = mission.dropoffAddress;
    final driver = mission.driverDisplayName?.trim() ?? '';
    // Same reading width as the home screen on a computer (2026-10-26).
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (mission.isInternalTest) ...[
            InternalTestMissionBanner(
              title: t('internal_test_mission_title'),
              message: t('internal_test_mission_message'),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            tr('Livraison du $day', 'Delivery on $day', 'Entrega del $day'),
            key: const ValueKey('detail-date'),
            style: secondary,
          ),
          const SizedBox(height: 2),
          Text(
            customerMissionTitle(mission, locale, t),
            key: const ValueKey('detail-title'),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 20),
              Text(
                t('customer_tracking_completed_title'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                ),
              ),
              if (done != null)
                Text(
                  tr(
                    'à ${customerTimeLabel(done, locale)}',
                    'at ${customerTimeLabel(done, locale)}',
                    'a las ${customerTimeLabel(done, locale)}',
                  ),
                  key: const ValueKey('detail-time'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Deux photos quand le chauffeur a photographié le chargement
          // (obligatoire depuis le 2026-10-26) ; sinon la seule preuve de
          // livraison, comme avant.
          if ((mission.proofOfPickupUrl ?? '').isNotEmpty)
            Row(
              key: const ValueKey('detail-photos'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        tr('Au ramassage', 'At pickup', 'En la recogida'),
                        style: secondary,
                      ),
                      const SizedBox(height: 6),
                      _ProofOfDeliveryView(url: mission.proofOfPickupUrl, t: t),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        tr('À la livraison', 'At delivery', 'En la entrega'),
                        style: secondary,
                      ),
                      const SizedBox(height: 6),
                      _ProofOfDeliveryView(
                        url: mission.proofOfDeliveryUrl,
                        t: t,
                      ),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            Text(t('customer_tracking_proof_title'), style: secondary),
            const SizedBox(height: 8),
            _ProofOfDeliveryView(url: mission.proofOfDeliveryUrl, t: t),
          ],
          const SizedBox(height: 16),
          if (pickup != null || dropoff != null || driver.isNotEmpty) ...[
            Container(
              key: const ValueKey('detail-addresses'),
              padding: const EdgeInsets.all(14),
              decoration: cardDecoration,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (pickup != null)
                    stop(
                      'A',
                      AppColors.info,
                      t('driver_active_mission_pickup'),
                      '${pickup.line1}, ${pickup.city}',
                    ),
                  if (pickup != null && dropoff != null)
                    const SizedBox(height: 12),
                  if (dropoff != null)
                    stop(
                      'B',
                      AppColors.error,
                      t('driver_active_mission_dropoff'),
                      '${dropoff.line1}, ${dropoff.city}',
                    ),
                  if (driver.isNotEmpty) ...[
                    const Divider(height: 24),
                    Text(
                      tr(
                        'Chauffeur : $driver',
                        'Driver: $driver',
                        'Conductor: $driver',
                      ),
                      style: secondary,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Container(
            key: const ValueKey('detail-total'),
            padding: const EdgeInsets.all(14),
            decoration: cardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    tr('Total', 'Total', 'Total'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: Text(
                    customerMoney(mission, locale),
                    textAlign: TextAlign.end,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
                if (!mission.isInternalTest && mission.customerTotal > 0)
                  _ReceiptButton(missionId: mission.id, locale: locale, api: api),
              ],
            ),
          ),
          // PAY-03 (2026-10-27) : carte refusée au débit après la livraison.
          if (!mission.isInternalTest &&
              (mission.paymentStatus == 'capture_failed' ||
                  mission.paymentStatus == 'failed') &&
              mission.activePaymentId != null) ...[
            const SizedBox(height: 16),
            _PaymentRecoveryCard(
              paymentId: mission.activePaymentId!,
              paymentStatus: mission.paymentStatus!,
              locale: locale,
              api: api,
            ),
          ],
          const SizedBox(height: 16),
          // Notation 1 à 5 étoiles (AB-10), seulement si un chauffeur a été
          // assigné ; jamais pour une demande de test interne.
          if (!mission.isInternalTest && mission.driverId != null) ...[
            _RateDriverCard(mission: mission, t: t),
            const SizedBox(height: 16),
          ],
          FilledButton.icon(
            key: const ValueKey('detail-rebook'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: () => rebookDelivery(
              context,
              mission,
              locale: locale,
              uid: context.read<FirebaseAuthProvider>().effectiveUid,
            ),
            icon: const Icon(Icons.replay),
            label: Text(
              tr(
                'Refaire cette livraison',
                'Book this delivery again',
                'Repetir esta entrega',
              ),
            ),
          ),
          // Le récapitulatif imprimable n'est pas une preuve de paiement
          // (il le dit lui-même) : on ne l'appelle donc pas « reçu ».
          if (mission.bookingSnapshot != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('detail-summary'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => context.push(
                '/$locale/livraison/conditions/${mission.id}',
              ),
              icon: const Icon(Icons.download_outlined),
              label: Text(
                tr(
                  'Télécharger le récapitulatif',
                  'Download the summary',
                  'Descargar el resumen',
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          TextButton.icon(
            key: const ValueKey('detail-report'),
            onPressed: () => context.go('/$locale/contact'),
            icon: const Icon(Icons.report_outlined),
            label: Text(
              tr(
                'Signaler un problème',
                'Report a problem',
                'Informar un problema',
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (!mission.isInternalTest)
            ExpansionTile(
              key: const ValueKey('detail-payment'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 12),
              title: Text(
                tr(
                  'Reçu et paiement',
                  'Receipt and payment',
                  'Recibo y pago',
                ),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              children: [MissionFinanceSection(missionId: mission.id, t: t)],
            ),
          ExpansionTile(
            key: const ValueKey('detail-more'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            title: Text(
              tr('Étapes et chargement', 'Steps and load', 'Etapas y carga'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            children: [
              _DeliveryTimeline(mission: mission, t: t),
              if (mission.bookingSnapshot != null) ...[
                const SizedBox(height: 12),
                BookingLoadSummary(
                  snapshot: mission.bookingSnapshot!,
                  locale: locale,
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            mission.id.trim().isEmpty
                ? t('tracking_reference_unavailable')
                : '${t('tracking_reference')} : ${mission.id}',
            key: const ValueKey('tracking-mission-reference'),
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

/// PAY-03 (2026-10-27) — la livraison est faite mais la carte a été refusée
/// au débit. Le client met sa carte à jour (Stripe Checkout, mode setup) puis
/// relance le paiement ; sinon le serveur relance seul (J+1, J+3). Une fois
/// toutes les relances échouées (`failed`), seul un message est affiché.
class _PaymentRecoveryCard extends StatefulWidget {
  const _PaymentRecoveryCard({
    required this.paymentId,
    required this.paymentStatus,
    required this.locale,
    required this.api,
  });
  final String paymentId, paymentStatus, locale;
  final BookingApi api;
  @override
  State<_PaymentRecoveryCard> createState() => _PaymentRecoveryCardState();
}

class _PaymentRecoveryCardState extends State<_PaymentRecoveryCard> {
  bool _busy = false;
  String? _message;

  String tr(String fr, String en, String es) => widget.locale == 'en'
      ? en
      : widget.locale == 'es'
      ? es
      : fr;

  Future<void> _updateCard() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    String? message;
    try {
      final result = await widget.api.call('startPaymentRecoveryCardSetup', {
        'paymentId': widget.paymentId,
        'locale': widget.locale,
      });
      if (result['ready'] == true) {
        message = tr(
          'Votre carte est déjà enregistrée. Appuyez sur « Réessayer le paiement ».',
          'Your card is already saved. Tap "Retry payment".',
          'Su tarjeta ya está guardada. Toque «Reintentar el pago».',
        );
      } else {
        final url = Uri.tryParse(result['url'] as String? ?? '');
        if (url == null || url.scheme != 'https') throw const FormatException();
        final open =
            CustomerTrackingScreen.openReceiptOverride ??
            (Uri u) => launchUrl(u, mode: LaunchMode.externalApplication);
        if (!await open(url)) throw const FormatException();
      }
    } on FirebaseFunctionsException catch (e) {
      message = e.message ??
          tr('Impossible pour le moment.', 'Not possible right now.', 'No es posible por ahora.');
    } catch (_) {
      message = tr('Impossible pour le moment.', 'Not possible right now.', 'No es posible por ahora.');
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  Future<void> _retry() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    String? message;
    try {
      final result = await widget.api.call('retryFailedCapture', {
        'paymentId': widget.paymentId,
      });
      message = result['success'] == true
          ? tr('Paiement encaissé. Merci!', 'Payment collected. Thank you!', '¡Pago cobrado. Gracias!')
          : (result['message'] as String?) ??
                tr('La carte a été refusée.', 'The card was declined.', 'La tarjeta fue rechazada.');
    } on FirebaseFunctionsException catch (e) {
      message = e.message ??
          tr('Impossible pour le moment.', 'Not possible right now.', 'No es posible por ahora.');
    } catch (_) {
      message = tr('Impossible pour le moment.', 'Not possible right now.', 'No es posible por ahora.');
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final abandoned = widget.paymentStatus == 'failed';
    return Container(
      key: const ValueKey('detail-payment-recovery'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFBE7E5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8B4AE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.credit_card_off_outlined, color: Color(0xFFA33A2F)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  abandoned
                      ? tr('Paiement en attente', 'Payment pending', 'Pago pendiente')
                      : tr('Paiement refusé', 'Payment declined', 'Pago rechazado'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFA33A2F),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            abandoned
                ? tr(
                    'Nous n’avons pas pu encaisser cette livraison. Notre équipe vous contactera.',
                    'We could not collect payment for this delivery. Our team will contact you.',
                    'No pudimos cobrar esta entrega. Nuestro equipo se comunicará con usted.',
                  )
                : tr(
                    'Votre carte a été refusée pour cette livraison. Mettez votre carte à jour, puis réessayez. Sans action de votre part, nous réessayerons automatiquement.',
                    'Your card was declined for this delivery. Update your card, then retry. If you do nothing, we will retry automatically.',
                    'Su tarjeta fue rechazada para esta entrega. Actualice su tarjeta y reintente. Si no hace nada, reintentaremos automáticamente.',
                  ),
          ),
          if (!abandoned) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const ValueKey('detail-payment-update-card'),
                  onPressed: _busy ? null : _updateCard,
                  icon: const Icon(Icons.credit_card),
                  label: Text(tr('Mettre ma carte à jour', 'Update my card', 'Actualizar mi tarjeta')),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('detail-payment-retry'),
                  onPressed: _busy ? null : _retry,
                  icon: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  label: Text(tr('Réessayer le paiement', 'Retry payment', 'Reintentar el pago')),
                ),
              ],
            ),
          ],
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              key: const ValueKey('detail-payment-recovery-message'),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// « Reçu de paiement » (2026-10-26) : le reçu hébergé par Stripe pour le
/// montant réellement débité, demandé au serveur à chaque fois (lecture
/// seule ; aucun montant n'est calculé ici).
class _ReceiptButton extends StatefulWidget {
  const _ReceiptButton({
    required this.missionId,
    required this.locale,
    required this.api,
  });
  final String missionId, locale;
  final BookingApi api;
  @override
  State<_ReceiptButton> createState() => _ReceiptButtonState();
}

class _ReceiptButtonState extends State<_ReceiptButton> {
  bool _busy = false;
  String? _message;

  String tr(String fr, String en, String es) => widget.locale == 'en'
      ? en
      : widget.locale == 'es'
      ? es
      : fr;

  Future<void> _open() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    String? message;
    final unavailable = tr(
      'Le reçu n’est pas disponible pour le moment. Réessayez plus tard.',
      'The receipt is not available right now. Try again later.',
      'El recibo no está disponible por ahora. Inténtalo más tarde.',
    );
    try {
      final result = await widget.api.call('getPaymentReceipt', {
        'missionId': widget.missionId,
      });
      final url = Uri.tryParse(result['url'] as String? ?? '');
      if (url == null || url.scheme != 'https') throw const FormatException();
      final open =
          CustomerTrackingScreen.openReceiptOverride ??
          (Uri u) => launchUrl(u, mode: LaunchMode.externalApplication);
      if (!await open(url)) throw const FormatException();
    } on FirebaseFunctionsException catch (e) {
      message = e.code == 'failed-precondition'
          ? tr(
              'Aucun montant n’a encore été débité pour cette livraison.',
              'Nothing has been charged for this delivery yet.',
              'Aún no se ha cobrado nada por esta entrega.',
            )
          : unavailable;
    } catch (_) {
      message = unavailable;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = message;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextButton.icon(
        key: const ValueKey('detail-receipt'),
        style: TextButton.styleFrom(padding: EdgeInsets.zero),
        onPressed: _busy ? null : _open,
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.receipt_long_outlined),
        label: Text(tr('Reçu de paiement', 'Payment receipt', 'Recibo de pago')),
      ),
      if (_message != null)
        Text(
          _message!,
          key: const ValueKey('detail-receipt-message'),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
    ],
  );
}

/// Carte de notation client -> chauffeur (Phase 7, Bloc AB, AB-10).
///
/// États gérés explicitement (méthode AB : PARCOURS RÉEL -> GAP RÉEL) :
///   - chargement de l'état existant (FutureBuilder sur
///     `getMyRatingForMission`) : indicateur discret, jamais un spinner
///     éternel ni un écran vide incompréhensible ;
///   - déjà noté : message de remerciement + étoiles déjà attribuées en
///     lecture seule, AUCUN moyen de re-soumettre (pas de double rating
///     incohérent, cohérent avec `allow update: if false` côté serveur) ;
///   - pas encore noté : 5 boutons étoile + champ commentaire optionnel +
///     bouton d'envoi ;
///   - erreur de chargement : traité comme "pas encore noté" (fail-open sur
///     la LECTURE uniquement — l'écriture reste protégée par la Security
///     Rule serveur, donc afficher le formulaire par défaut ne crée aucun
///     risque de double rating, seulement au pire une tentative de `create`
///     qui échouera proprement en `permission-denied` si une notation
///     existe déjà).
class _RateDriverCard extends StatefulWidget {
  final DeliveryMission mission;
  final String Function(String) t;
  const _RateDriverCard({required this.mission, required this.t});

  @override
  State<_RateDriverCard> createState() => _RateDriverCardState();
}

class _RateDriverCardState extends State<_RateDriverCard> {
  late Future<MissionRating?> _existingRatingFuture;
  int _selectedStars = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _submitting = false;
  bool _justSubmitted = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadExistingRating();
  }

  void _loadExistingRating() {
    final customerId = widget.mission.customerId;
    _existingRatingFuture = BackendLocator.ratingRepository
        .getMyRatingForMission(
          missionId: widget.mission.id,
          customerId: customerId,
        )
        .catchError((_) => null);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = widget.t;
    if (_selectedStars < 1 || _selectedStars > 5) {
      setState(() {
        _errorMessage = t('customer_tracking_rate_driver_select_stars_error');
      });
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    try {
      await BackendLocator.ratingRepository.submitDriverRating(
        missionId: widget.mission.id,
        customerId: widget.mission.customerId,
        stars: _selectedStars,
        comment: _commentController.text,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _justSubmitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _errorMessage = t('customer_tracking_rate_driver_error');
      });
    }
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }

  Widget _buildThanks(String Function(String) t) {
    return _buildCard(
      child: Row(
        children: [
          const Icon(Icons.favorite, color: AppColors.success, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('customer_tracking_rate_driver_thanks_title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t('customer_tracking_rate_driver_thanks_message'),
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlreadyRated(String Function(String) t, MissionRating rating) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('customer_tracking_rate_driver_thanks_title'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _StarDisplay(stars: rating.stars, t: t),
          if (rating.comment != null && rating.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              rating.comment!,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildForm(String Function(String) t) {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('customer_tracking_rate_driver_title'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            t('customer_tracking_rate_driver_subtitle'),
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          _StarSelector(
            selected: _selectedStars,
            starLabel: t('customer_tracking_rate_driver_star_semantic'),
            onChanged: (v) {
              setState(() {
                _selectedStars = v;
                _errorMessage = null;
              });
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commentController,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: t('customer_tracking_rate_driver_comment_hint'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              isDense: true,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(t('customer_tracking_rate_driver_submit')),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    if (_justSubmitted) return _buildThanks(t);

    return FutureBuilder<MissionRating?>(
      future: _existingRatingFuture,
      builder: (context, snap) {
        // Chargement : jamais un spinner éternel ni un écran vide — la
        // carte occupe déjà son espace final (évite un "layout jump"), on
        // affiche juste un indicateur discret à la place du contenu.
        if (snap.connectionState == ConnectionState.waiting) {
          return _buildCard(
            child: const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final existing = snap.data;
        if (existing != null) return _buildAlreadyRated(t, existing);
        return _buildForm(t);
      },
    );
  }
}

/// Sélecteur de 1 à 5 étoiles, appuyable, avec sémantique accessible
/// (AB-9 sanity — chaque étoile annonce son rang, ex: "3 étoile(s)").
class _StarSelector extends StatelessWidget {
  final int selected;
  final String starLabel;
  final ValueChanged<int> onChanged;
  const _StarSelector({
    required this.selected,
    required this.starLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final value = index + 1;
        final filled = value <= selected;
        return Semantics(
          label: '$value $starLabel',
          selected: filled,
          child: IconButton(
            onPressed: () => onChanged(value),
            icon: Icon(
              filled ? Icons.star : Icons.star_border,
              color: filled ? AppColors.warningText : AppColors.textSecondary,
              size: 32,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        );
      }),
    );
  }
}

/// Affichage en LECTURE SEULE d'une notation déjà soumise (pas de bouton,
/// pas d'action possible — cohérent avec l'immutabilité serveur).
class _StarDisplay extends StatelessWidget {
  final int stars;
  final String Function(String) t;
  const _StarDisplay({required this.stars, required this.t});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final filled = index < stars;
        return Icon(
          filled ? Icons.star : Icons.star_border,
          color: filled ? AppColors.warningText : AppColors.textSecondary,
          size: 22,
        );
      }),
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

    // Bloc M (Bloc M-1, gap performance) : la photo source peut atteindre
    // 1600px de large (voir maxWidth du ImagePicker en capture), alors que
    // l'affichage est borné à 220px de hauteur fixe — sans `cacheHeight`,
    // Flutter décode l'image PLEINE RÉSOLUTION en mémoire avant de la
    // redimensionner à l'écran, ce qui gaspille mémoire/CPU à chaque
    // ouverture de cet écran de tracking. `cacheHeight` demande au décodeur
    // de ne produire qu'un bitmap proche de la taille d'affichage réelle
    // (ajusté par le devicePixelRatio de l'appareil) ; la largeur suit
    // automatiquement le ratio de l'image source.
    final cacheHeight = (220 * MediaQuery.of(context).devicePixelRatio).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        url!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 220,
        cacheHeight: cacheHeight,
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
    // Minimum height, not a fixed one: the message stays readable with
    // large text (2026-10-25).
    return Container(
      constraints: const BoxConstraints(minHeight: 160),
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
