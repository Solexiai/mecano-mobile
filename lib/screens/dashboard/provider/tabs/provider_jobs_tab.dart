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
import '../../../../core/app_colors.dart';
import '../../../../models/enums.dart';
import '../../../../providers/firebase_auth_provider.dart';
import '../../../../providers/locale_provider.dart';

/// Onglet "Demandes disponibles" du chauffeur.
///
/// Données 100% réelles : `MissionRepository.watchAvailableMissionsForDriver()`
/// (missions déjà filtrées côté repository par statut ouvert à l'acceptation
/// et par offres actives pour ce chauffeur). Le bouton Accepter appelle
/// `acceptMission()`, qui invoque la Cloud Function `acceptDelivery` —
/// aucune attribution locale, le serveur tranche en cas de concurrence.
class ProviderJobsTab extends StatefulWidget {
  const ProviderJobsTab({super.key, this.bookingApi, this.photoLoader});
  final BookingApi? bookingApi;
  final BookingPhotoLoader? photoLoader;

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
              content: Text('${vehicle['label']}'),
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
              content: Text(
                '${tr('Rémunération', 'Compensation', 'Remuneración')} : ${(minor / 100).toStringAsFixed(2)} CAD',
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
        setState(
          () => _acceptErrors[mission.id] = result['pending'] == true
              ? 'acceptance_pending'
              : result['errorCode'] as String? ?? 'unknown_error',
        );
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
        setState(
          () => _acceptErrors[mission.id] =
              error is FirebaseFunctionsException &&
                  isKillSwitchException(
                    CloudFunctionException(error.code, error.message ?? ''),
                  )
              ? kKillSwitchErrorCode
              : 'unknown_error',
        );
      }
    } finally {
      if (mounted) setState(() => _accepting.remove(mission.id));
    }
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
          Text(
            t('driver_jobs_title'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
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
                child: Text(
                  mission.itemCategoryKey.isEmpty
                      ? t('delivery_item_category')
                      : t(mission.itemCategoryKey),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                mission.driverOfferAmount > 0
                    ? '${mission.driverOfferAmount.toStringAsFixed(2)} CAD'
                    : tr('Voir l’offre', 'View offer', 'Ver oferta'),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  fontSize: 16,
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
            _InfoRow(
              icon: Icons.timer_outlined,
              text:
                  '${tr('Offre valable jusqu’à', 'Offer expires at', 'Oferta válida hasta')} : ${mission.offerExpiresAt!.toLocal()}',
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
                errorCode == 'acceptance_pending'
                    ? tr(
                        'Attribution enregistrée, validation en cours. Réessayez pour consulter son résultat.',
                        'Assignment saved, validation pending. Retry to check its result.',
                        'Asignación guardada, validación pendiente. Reintenta para consultar el resultado.',
                      )
                    : errorCode == 'offer_decline_failed'
                    ? tr(
                        'Le refus n’a pas été enregistré. Réessayez.',
                        'Your decline was not saved. Please retry.',
                        'No se guardó el rechazo. Reintenta.',
                      )
                    : errorCode == kKillSwitchErrorCode
                    ? t('service_temporarily_unavailable')
                    : t('driver_jobs_accept_error'),
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
                        Text(t('driver_jobs_accepting')),
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
