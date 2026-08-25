import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
  const ProviderJobsTab({super.key});

  @override
  State<ProviderJobsTab> createState() => _ProviderJobsTabState();
}

class _ProviderJobsTabState extends State<ProviderJobsTab> {
  final Set<String> _accepting = {};
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
    _availableMissionsStream = BackendLocator.missionRepository.watchAvailableMissionsForDriver(driverId);
    _activeMissionStream = BackendLocator.missionRepository.watchActiveMissionForDriver(driverId);
  }

  Future<void> _accept(DeliveryMission mission, String driverId) async {
    setState(() {
      _accepting.add(mission.id);
      _acceptErrors.remove(mission.id);
    });
    try {
      final result = await BackendLocator.missionRepository.acceptMission(
        missionId: mission.id,
        driverId: driverId,
      );
      if (!mounted) return;
      setState(() {
        _accepting.remove(mission.id);
        if (!result.success) {
          _acceptErrors[mission.id] = result.errorCode ?? 'unknown_error';
        }
      });
      // Acceptation réussie : le chauffeur est redirigé directement vers
      // l'écran Mission Active (source de vérité temps réel
      // `watchMission()`), sans jamais décider localement du statut.
      if (result.success && mounted) {
        final locale = context.read<LocaleProvider>().locale;
        context.push('/$locale/provider/mission/${mission.id}');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _accepting.remove(mission.id);
        _acceptErrors[mission.id] = 'unknown_error';
      });
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
          child: Text(t('delivery_login_required'), textAlign: TextAlign.center),
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
          Text(t('driver_jobs_title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
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
                                Text(t('driver_active_mission_resume_banner'),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text(t(active.status.key), style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
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
          StreamBuilder<List<DeliveryMission>>(
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
                        Text(t('driver_jobs_loading'), style: const TextStyle(color: AppColors.textSecondary)),
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
                        const Icon(Icons.error_outline, color: AppColors.error, size: 32),
                        const SizedBox(height: 8),
                        Text(t('driver_jobs_error'), textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: () => setState(() {}), child: Text(t('requests_retry'))),
                      ],
                    ),
                  ),
                );
              }
              final missions = snapshot.data ?? const <DeliveryMission>[];
              if (missions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text(t('driver_jobs_empty'), style: const TextStyle(color: AppColors.textSecondary))),
                );
              }
              return Column(
                children: missions
                    .map((m) => _JobCard(
                          mission: m,
                          t: t,
                          isAccepting: _accepting.contains(m.id),
                          errorCode: _acceptErrors[m.id],
                          onAccept: () => _accept(m, driverId),
                        ))
                    .toList(),
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
  final VoidCallback onAccept;
  const _JobCard({
    required this.mission,
    required this.t,
    required this.isAccepting,
    required this.errorCode,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
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
                decoration: BoxDecoration(gradient: AppColors.deliveryGradient, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  mission.itemCategoryKey.isEmpty ? t('delivery_item_category') : t(mission.itemCategoryKey),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text('${mission.driverOfferAmount.toStringAsFixed(0)}\$', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          if (pickup != null && dropoff != null)
            _InfoRow(icon: Icons.route_outlined, text: '${pickup.line1}, ${pickup.city} → ${dropoff.line1}, ${dropoff.city}')
          else
            _InfoRow(icon: Icons.place_outlined, text: t('delivery_step_addresses_title')),
          _InfoRow(icon: Icons.local_shipping, text: t(mission.requiredVehicleCategory.key)),
          if (mission.distanceKm != null)
            _InfoRow(icon: Icons.social_distance, text: '${t('driver_jobs_distance')} : ${mission.distanceKm!.toStringAsFixed(1)} km'),
          if (mission.estimatedDurationMinutes != null)
            _InfoRow(icon: Icons.schedule, text: '${mission.estimatedDurationMinutes!.round()} min'),
          _InfoRow(icon: Icons.attach_money, text: '${t('driver_jobs_offer_amount')} : ${mission.driverOfferAmount.toStringAsFixed(2)}\$'),
          if (mission.description.isNotEmpty) _InfoRow(icon: Icons.info_outline, text: mission.description),
          const SizedBox(height: 14),
          if (errorCode != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(t('driver_jobs_accept_error'), style: const TextStyle(color: AppColors.error, fontSize: 12.5)),
            ),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isAccepting ? null : onAccept,
              child: isAccepting
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        const SizedBox(width: 10),
                        Text(t('driver_jobs_accepting')),
                      ],
                    )
                  : Text(t('driver_jobs_accept')),
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
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
        ],
      ),
    );
  }
}
