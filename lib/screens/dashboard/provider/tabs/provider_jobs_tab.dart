import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../widgets/driver_slot_confirmation.dart';
import '../../../../services/booking/booking_api.dart';
import '../../../../widgets/booking_load_summary.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../backend/backend_exceptions.dart';
import '../../../../backend/backend_locator.dart';
import '../../../../backend/models/delivery_mission.dart';
import '../../../../finance/models/transaction_ledger.dart';
import '../../../../widgets/driver_home_summary.dart';
import '../../../../core/app_colors.dart';
import '../../../../models/enums.dart';
import '../../../../providers/firebase_auth_provider.dart';
import '../../../../providers/locale_provider.dart';

/// Onglet "Accueil" du chauffeur : résumé (prochaine mission, gains de la
/// semaine) puis les demandes disponibles.
///
/// Données 100% réelles : `MissionRepository.watchAvailableMissionsForDriver()`
/// (missions déjà filtrées côté repository par statut ouvert à l'acceptation
/// et par offres actives pour ce chauffeur). Le bouton Accepter appelle
/// `acceptMission()`, qui invoque la Cloud Function `acceptDelivery` —
/// aucune attribution locale, le serveur tranche en cas de concurrence.
class ProviderJobsTab extends StatefulWidget {
  const ProviderJobsTab({
    super.key,
    this.bookingApi,
    this.photoLoader,
    this.homeMissions,
    this.homeLedger,
  });
  final BookingApi? bookingApi;
  final BookingPhotoLoader? photoLoader;

  /// Injection pour les tests du résumé d'accueil (missions, gains).
  final Stream<List<DeliveryMission>>? homeMissions;
  final Stream<List<LedgerEntry>>? homeLedger;

  @override
  State<ProviderJobsTab> createState() => _ProviderJobsTabState();
}

class _ProviderJobsTabState extends State<ProviderJobsTab> {
  final Set<String> _accepting = {};
  final Set<String> _declining = {};
  final Set<String> _declined = {};
  final Map<String, String> _acceptErrors = {};

  // 🔒 BUG-FIX (Phase 7, Bloc C item 3) : ne JAMAIS instancier un Stream
  // directement dans `build()`. Avant ce correctif,
  // `watchAvailableMissionsForDriver()`/`watchActiveMissionForDriver()`
  // étaient appelés à chaque rebuild — or `_accept()` déclenche un
  // `setState()` synchrone (passage à `isAccepting = true`) qui provoque un
  // rebuild immédiat, donc un NOUVEAU Stream à chaque frame. `StreamBuilder`
  // compare le flux par référence et, en détectant un flux différent,
  // repasse en `ConnectionState.waiting` : la carte de mission en cours
  // d'acceptation disparaissait au profit de l'écran de chargement générique
  // ("Recherche de missions disponibles…"), et un nouvel abonnement Firestore
  // était recréé inutilement à chaque frappe. On mémorise donc les flux par
  // `driverId` pour qu'ils ne soient créés qu'une seule fois.
  String? _cachedDriverId;
  Stream<List<DeliveryMission>>? _availableMissionsStream;
  Stream<DeliveryMission?>? _activeMissionStream;

  void _ensureStreams(String driverId) {
    if (_cachedDriverId == driverId && _availableMissionsStream != null) {
      return;
    }
    _cachedDriverId = driverId;
    _accepting.clear();
    _declining.clear();
    _declined.clear();
    _acceptErrors.clear();
    _availableMissionsStream = BackendLocator.missionRepository
        .watchAvailableMissionsForDriver(driverId);
    _activeMissionStream = BackendLocator.missionRepository
        .watchActiveMissionForDriver(driverId)
        .asBroadcastStream();
  }

  Future<void> _accept(DeliveryMission mission, String driverId) async {
    if (_accepting.contains(mission.id)) return;
    setState(() {
      _accepting.add(mission.id);
      _acceptErrors.remove(mission.id);
    });
    final key = 'movik_accept_${driverId}_${mission.id}';
    try {
      final api = widget.bookingApi ?? FirebaseBookingApi(driverId);
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(key);
      Map<String, dynamic>? payload = saved == null
          ? null
          : Map<String, dynamic>.from(jsonDecode(saved) as Map);
      if (payload == null) {
        String? vehicleId;
        // Price-first bookings (2026-10-22): the driver judges the fit.
        final driverJudgement =
            mission.bookingSnapshot?['vehicle_assessment'] == 'driver_judgement';
        var fitConfirmed = false;
        if (mission.bookingSnapshot != null) {
          final response = await api.call('getBookingVehicleForAcceptance', {
            'missionId': mission.id,
          });
          final vehicle = response['vehicle'] as Map?;
          if (vehicle == null) throw StateError('No compatible vehicle');
          if (!mounted) return;
          final locale = context.read<LocaleProvider>().locale;
          String tr(String fr, String en, String es) => locale == 'en'
              ? en
              : locale == 'es'
              ? es
              : fr;
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                tr(
                  'Confirmer le véhicule utilisé',
                  'Confirm your vehicle',
                  'Confirmar el vehículo',
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${vehicle['label']}'),
                  if (driverJudgement) ...[
                    const SizedBox(height: 12),
                    Text(
                      tr(
                        'En confirmant, vous déclarez avoir vu les photos et la description, et que le chargement entre dans ce véhicule.',
                        'By confirming, you declare that you have seen the photos and description and that the load fits this vehicle.',
                        'Al confirmar, declaras que viste las fotos y la descripción y que la carga cabe en este vehículo.',
                      ),
                    ),
                  ],
                  if (mission.offerExpiresAt != null) ...[
                    const SizedBox(height: 12),
                    OfferCountdown(
                      expiresAt: mission.offerExpiresAt!,
                      locale: locale,
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(tr('Retour', 'Back', 'Volver')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(
                    tr(
                      'J’utilise ce véhicule',
                      'Use this vehicle',
                      'Usar este vehículo',
                    ),
                  ),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
          vehicleId = vehicle['id'] as String;
          fitConfirmed = driverJudgement;
        }
        final preparation = await api.call('prepareDriverMissionAcceptance', {
          'missionId': mission.id,
        });
        if (!mounted) return;
        final locale = context.read<LocaleProvider>().locale;
        Map<String, dynamic>? reservation;
        if (preparation['enabled'] == true) {
          reservation = await confirmDriverSlot(
            context,
            locale: locale,
            preparation: preparation,
          );
          if (reservation == null) return;
          if (preparation['calendars_connected'] == true) {
            await api.call('refreshDriverCalendars', {
              'start': reservation['start'],
              'end': reservation['end'],
            });
          }
        } else {
          String tr(String fr, String en, String es) => locale == 'en'
              ? en
              : locale == 'es'
              ? es
              : fr;
          final minor = preparation['driver_offer_minor'] as num?;
          if (minor == null) throw StateError('Official compensation missing');
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                tr(
                  'Accepter cette mission ?',
                  'Accept this mission?',
                  '¿Aceptar esta misión?',
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${tr('Rémunération', 'Compensation', 'Remuneración')} : ${(minor / 100).toStringAsFixed(2)} CAD',
                  ),
                  if (mission.offerExpiresAt != null) ...[
                    const SizedBox(height: 12),
                    OfferCountdown(
                      expiresAt: mission.offerExpiresAt!,
                      locale: locale,
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(tr('Retour', 'Back', 'Volver')),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(tr('Accepter', 'Accept', 'Aceptar')),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
        }
        payload = {
          'missionId': mission.id,
          if (vehicleId != null) 'vehicleId': vehicleId,
          if (fitConfirmed) 'fitConfirmed': true,
          'expectedDriverOfferMinor': preparation['driver_offer_minor'],
          if (reservation != null) 'reservation': reservation,
          if (reservation != null) 'acceptanceRequestId': const Uuid().v4(),
        };
        if (reservation != null) {
          await prefs.setString(key, jsonEncode(payload));
        }
      }
      if (!mounted ||
          context.read<FirebaseAuthProvider>().effectiveUid != driverId) {
        return;
      }
      final result = await api.call('acceptDelivery', payload);
      if (!mounted) return;
      if (result['success'] != true) {
        final code = result['pending'] == true
            ? 'acceptance_pending'
            : result['errorCode'] as String? ?? 'unknown_error';
        setState(() => _acceptErrors[mission.id] = code);
        await _showAcceptFailure(code);
        return;
      }
      await prefs.remove(key);
      if (mounted) {
        final locale = context.read<LocaleProvider>().locale;
        context.push('/$locale/provider/mission/${mission.id}');
      }
    } catch (error) {
      if (error is FirebaseFunctionsException &&
          ['invalid-argument', 'failed-precondition'].contains(error.code)) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(key);
      }
      if (mounted) {
        // DRV-02 (2026-10-28) : le serveur distingue « passez en ligne »,
        // « hors zone », « confirmez le véhicule », « documents invalides »,
        // « offre expirée »… On affiche SON message (préfixe `server:`) au
        // lieu de prétendre que la mission est déjà prise.
        final serverMessage = error is FirebaseFunctionsException &&
                const ['failed-precondition', 'permission-denied', 'invalid-argument', 'not-found']
                    .contains(error.code) &&
                (error.message ?? '').trim().isNotEmpty
            ? error.message!.trim()
            : null;
        final code = error is FirebaseFunctionsException &&
                isKillSwitchException(
                  CloudFunctionException(error.code, error.message ?? ''),
                )
            ? kKillSwitchErrorCode
            : serverMessage != null
            ? 'server:$serverMessage'
            : 'unknown_error';
        setState(() => _acceptErrors[mission.id] = code);
        await _showAcceptFailure(code);
      }
    } finally {
      if (mounted) setState(() => _accepting.remove(mission.id));
    }
  }

  /// 2026-10-29 (recette) : un refus du serveur (paiement du client refusé,
  /// offre expirée…) retire la mission de la liste, et le message affiché
  /// dans sa carte disparaissait avec elle. La raison s'affiche donc aussi
  /// dans une fenêtre qui reste à l'écran jusqu'à ce que le chauffeur la
  /// ferme.
  Future<void> _showAcceptFailure(String code) async {
    if (!mounted) return;
    final locale = context.read<LocaleProvider>().locale;
    final t = context.read<LocaleProvider>().t;
    String tr(String fr, String en, String es) => locale == 'en'
        ? en
        : locale == 'es'
        ? es
        : fr;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('driver-accept-failure-dialog'),
        title: Text(
          code == 'acceptance_pending'
              ? tr(
                  'Validation en cours',
                  'Validation pending',
                  'Validación en curso',
                )
              : tr(
                  'Mission non acceptée',
                  'Mission not accepted',
                  'Misión no aceptada',
                ),
        ),
        content: Text(driverAcceptFailureText(code, locale, t)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _decline(DeliveryMission mission, String driverId) async {
    if (_accepting.contains(mission.id)) return;
    setState(() {
      _accepting.add(mission.id);
      _declining.add(mission.id);
      _acceptErrors.remove(mission.id);
    });
    try {
      final result = await (widget.bookingApi ?? FirebaseBookingApi(driverId))
          .call('declineDeliveryOffer', {'missionId': mission.id});
      if (!mounted ||
          context.read<FirebaseAuthProvider>().effectiveUid != driverId) {
        return;
      }
      if (result['declined'] != true) throw StateError('Decline not confirmed');
      setState(() => _declined.add(mission.id));
    } catch (_) {
      if (mounted &&
          context.read<FirebaseAuthProvider>().effectiveUid == driverId) {
        setState(() => _acceptErrors[mission.id] = 'offer_decline_failed');
      }
    } finally {
      if (mounted &&
          context.read<FirebaseAuthProvider>().effectiveUid == driverId) {
        setState(() {
          _accepting.remove(mission.id);
          _declining.remove(mission.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FirebaseAuthProvider>();
    final t = context.watch<LocaleProvider>().t;

    if (!auth.isSignedIn || auth.effectiveUid == null) {
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

    final driverId = auth.effectiveUid!;
    _ensureStreams(driverId);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bannière de reprise : si ce chauffeur a déjà une mission en
          // trajet (assigned -> arrived_at_dropoff), on lui permet d'y
          // revenir directement plutôt que de la laisser invisible parmi
          // les jobs disponibles.
          StreamBuilder<DeliveryMission?>(
            stream: _activeMissionStream,
            builder: (context, snap) {
              final active = snap.data;
              if (active == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      final locale = context.read<LocaleProvider>().locale;
                      context.push('/$locale/provider/mission/${active.id}');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: AppColors.deliveryGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.local_shipping, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t('driver_active_mission_resume_banner'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  t(active.status.key),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Accueil (25 octobre 2026) : prochaine mission, gains de la
          // semaine et missions à venir, puis les demandes disponibles.
          DriverHomeSummary(
            driverId: driverId,
            locale: context.watch<LocaleProvider>().locale,
            missions: widget.homeMissions,
            ledger: widget.homeLedger,
          ),
          Text(
            t('driver_jobs_title'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          StreamBuilder<DeliveryMission?>(
            stream: _activeMissionStream,
            builder: (context, activeSnapshot) {
              if (activeSnapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              // Un chauffeur déjà en mission ne doit jamais voir ni accepter
              // de nouvelles offres. La bannière ci-dessus reste son unique
              // chemin d'action jusqu'à la fin de la mission active.
              if (activeSnapshot.data != null) {
                return const SizedBox.shrink();
              }
              return StreamBuilder<List<DeliveryMission>>(
                stream: _availableMissionsStream,
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
                              t('driver_jobs_loading'),
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
                              t('driver_jobs_error'),
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
                  final missions = (snapshot.data ?? const <DeliveryMission>[])
                      .where((m) => !_declined.contains(m.id))
                      .toList();
                  if (missions.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          t('driver_jobs_empty'),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: missions
                        .map(
                          (m) => _JobCard(
                            mission: m,
                            t: t,
                            isAccepting: _accepting.contains(m.id),
                            errorCode: _acceptErrors[m.id],
                            onAccept: () => _accept(m, driverId),
                            onDecline: () => _decline(m, driverId),
                            isDeclining: _declining.contains(m.id),
                            photoLoader: widget.photoLoader,
                          ),
                        )
                        .toList(),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final DeliveryMission mission;
  final String Function(String) t;
  final bool isAccepting;
  final String? errorCode;
  final VoidCallback onAccept, onDecline;
  final bool isDeclining;
  final BookingPhotoLoader? photoLoader;
  const _JobCard({
    required this.mission,
    required this.t,
    required this.isAccepting,
    required this.errorCode,
    required this.onAccept,
    required this.onDecline,
    required this.isDeclining,
    this.photoLoader,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.read<LocaleProvider>().locale;
    String tr(String fr, String en, String es) => locale == 'en'
        ? en
        : locale == 'es'
        ? es
        : fr;
    final pickup = mission.pickupAddress;
    final dropoff = mission.dropoffAddress;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
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
                flex: 3,
                child: Text(
                  mission.itemCategoryKey.isEmpty
                      ? t('delivery_item_category')
                      : t(mission.itemCategoryKey),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 8),
              // Flexible: large text sizes on narrow phones must wrap, not overflow.
              Flexible(
                flex: 2,
                child: Text(
                  mission.driverOfferAmount > 0
                      ? '${mission.driverOfferAmount.toStringAsFixed(2)} CAD'
                      : tr('Voir l’offre', 'View offer', 'Ver oferta'),
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pickup != null && dropoff != null)
            _InfoRow(
              icon: Icons.route_outlined,
              text:
                  '${pickup.line1}, ${pickup.city} → ${dropoff.line1}, ${dropoff.city}',
            )
          else
            _InfoRow(
              icon: Icons.place_outlined,
              text: t('delivery_step_addresses_title'),
            ),
          _InfoRow(
            icon: Icons.local_shipping,
            text: t(mission.requiredVehicleCategory.key),
          ),
          if (mission.distanceKm != null)
            _InfoRow(
              icon: Icons.social_distance,
              text:
                  '${t('driver_jobs_distance')} : ${mission.distanceKm!.toStringAsFixed(1)} km',
            ),
          if (mission.bookingSnapshot?['load']?['requested_at'] is String)
            _InfoRow(
              icon: Icons.event,
              text:
                  '${tr('Ramassage prévu', 'Requested pickup', 'Recogida prevista')} : ${DateTime.parse(mission.bookingSnapshot!['load']['requested_at'] as String).toLocal()}',
            ),
          if (mission.offerExpiresAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: OfferCountdown(
                expiresAt: mission.offerExpiresAt!,
                locale: context.read<LocaleProvider>().locale,
              ),
            ),
          if (mission.estimatedDurationMinutes != null)
            _InfoRow(
              icon: Icons.schedule,
              text:
                  '${tr('Trajet seul, durée complète à confirmer', 'Driving only, full duration to confirm', 'Solo trayecto, duración completa por confirmar')} : ${mission.estimatedDurationMinutes!.round()} min',
            ),
          _InfoRow(
            icon: Icons.attach_money,
            text: mission.driverOfferAmount > 0
                ? '${t('driver_jobs_offer_amount')} : ${mission.driverOfferAmount.toStringAsFixed(2)} CAD'
                : tr(
                    'Rémunération officielle présentée avant acceptation.',
                    'Official compensation shown before acceptance.',
                    'Remuneración oficial antes de aceptar.',
                  ),
          ),
          if (mission.bookingSnapshot != null)
            BookingLoadSummary(
              snapshot: mission.bookingSnapshot!,
              photoLoader: photoLoader,
              locale: context.read<LocaleProvider>().locale,
            ),
          if (mission.description.isNotEmpty)
            _InfoRow(icon: Icons.info_outline, text: mission.description),
          const SizedBox(height: 14),
          if (errorCode != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              // 🔒 Phase 7, Bloc X (X-10) — un refus par kill switch
              // (`allow_driver_acceptance`/`payments_enabled` désactivé)
              // affiche le message générique traduit
              // (`service_temporarily_unavailable`), JAMAIS le message
              // "mission déjà acceptée par un autre chauffeur"
              // (`driver_jobs_accept_error`) qui serait trompeur ici — voir
              // FirebaseMissionRepository.acceptMission() pour le mapping
              // errorCode == kKillSwitchErrorCode.
              child: Text(
                driverAcceptFailureText(
                  errorCode!,
                  context.read<LocaleProvider>().locale,
                  t,
                ),
                style: const TextStyle(color: AppColors.error, fontSize: 12.5),
              ),
            ),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isAccepting ? null : onAccept,
              child: isAccepting && !isDeclining
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(child: Text(t('driver_jobs_accepting'))),
                      ],
                    )
                  : Text(t('driver_jobs_accept')),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              key: ValueKey('decline-offer-${mission.id}'),
              onPressed: isAccepting ? null : onDecline,
              child: Text(
                isDeclining
                    ? tr('Refus en cours…', 'Declining…', 'Rechazando…')
                    : tr(
                        'Refuser cette demande',
                        'Decline this request',
                        'Rechazar esta solicitud',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Message shown to the driver when an acceptance is refused. Shared by the
/// job card and the failure dialog. Known server refusals get a plain
/// explanation; any other server message is shown as is.
String driverAcceptFailureText(
  String code,
  String locale,
  String Function(String) t,
) {
  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;
  if (code == 'acceptance_pending') {
    return tr(
      'Attribution enregistrée, validation en cours. Réessayez pour consulter son résultat.',
      'Assignment saved, validation pending. Retry to check its result.',
      'Asignación guardada, validación pendiente. Reintenta para consultar el resultado.',
    );
  }
  if (code == 'offer_decline_failed') {
    return tr(
      'Le refus n’a pas été enregistré. Réessayez.',
      'Your decline was not saved. Please retry.',
      'No se guardó el rechazo. Reintenta.',
    );
  }
  if (code == kKillSwitchErrorCode) return t('service_temporarily_unavailable');
  if (!code.startsWith('server:')) return t('driver_jobs_accept_error');
  final message = code.substring('server:'.length);
  if (message.startsWith('Autorisation de paiement refusée')) {
    return tr(
      'Le paiement du client a été refusé par sa banque. La mission ne vous est pas attribuée et le client est invité à mettre à jour sa carte.',
      'The customer’s payment was declined by their bank. The mission is not assigned to you and the customer is asked to update their card.',
      'El banco del cliente rechazó el pago. La misión no se te asigna y se pide al cliente que actualice su tarjeta.',
    );
  }
  if (message.startsWith('Mission annulée')) {
    return tr(
      'Le client a annulé sa demande pendant votre acceptation. Rien n’a été débité.',
      'The customer cancelled the request while you were accepting. Nothing was charged.',
      'El cliente canceló la solicitud mientras aceptabas. No se cobró nada.',
    );
  }
  if (message.contains('indisponible ou expirée')) {
    return tr(
      'Cette offre a expiré avant votre confirmation. La demande a peut-être été proposée à d’autres chauffeurs.',
      'This offer expired before you confirmed. The request may have been offered to other drivers.',
      'Esta oferta caducó antes de tu confirmación. La solicitud pudo ofrecerse a otros conductores.',
    );
  }
  if (message.contains('un autre chauffeur') ||
      message.contains('déjà assignée')) {
    return t('driver_jobs_accept_error');
  }
  return message;
}

/// Live "offer valid for X min" line, so a driver who opens an offer late
/// sees how much time is left before confirming.
class OfferCountdown extends StatefulWidget {
  const OfferCountdown({
    super.key,
    required this.expiresAt,
    required this.locale,
  });

  final DateTime expiresAt;
  final String locale;

  @override
  State<OfferCountdown> createState() => _OfferCountdownState();
}

class _OfferCountdownState extends State<OfferCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!widget.expiresAt.isAfter(DateTime.now())) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _tr(String fr, String en, String es) => widget.locale == 'en'
      ? en
      : widget.locale == 'es'
      ? es
      : fr;

  @override
  Widget build(BuildContext context) {
    final left = widget.expiresAt.difference(DateTime.now());
    final expired = left.inSeconds <= 0;
    final minutes = left.inMinutes;
    final seconds = left.inSeconds % 60;
    final text = expired
        ? _tr(
            'Cette offre a expiré.',
            'This offer has expired.',
            'Esta oferta caducó.',
          )
        : '${_tr('Offre valable encore', 'Offer valid for', 'Oferta válida por')} '
              '${minutes > 0 ? '$minutes min ' : ''}${seconds.toString().padLeft(minutes > 0 ? 2 : 1, '0')} s';
    final urgent = expired || left.inSeconds < 60;
    final color = urgent ? AppColors.error : AppColors.textSecondary;
    return Row(
      key: const Key('driver-offer-countdown'),
      children: [
        Icon(Icons.timer_outlined, size: 15, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: urgent ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }
}
