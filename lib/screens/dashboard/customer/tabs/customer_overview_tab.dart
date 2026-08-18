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

/// Vue d'ensemble du client : uniquement des données réelles Firebase.
/// Aucune donnée n'est inventée quand le backend n'en fournit pas
/// (le domaine mécanique reste local/non migré, hors périmètre Phase 4).
class CustomerOverviewTab extends StatelessWidget {
  final void Function(int) onGoToTab;
  const CustomerOverviewTab({super.key, required this.onGoToTab});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FirebaseAuthProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final locale = localeProvider.locale;
    final t = localeProvider.t;

    if (!auth.isSignedIn || auth.user == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(t('delivery_login_required'), textAlign: TextAlign.center),
        ),
      );
    }

    final customerId = auth.user!.uid;
    final displayName = auth.user!.displayName ?? auth.user!.email ?? '';
    final firstName = displayName.trim().isEmpty ? '' : displayName.trim().split(' ').first;
    final mechanicJobs = context.watch<MechanicRequestProvider>().forCustomer(customerId);

    return StreamBuilder<List<DeliveryMission>>(
      stream: BackendLocator.missionRepository.watchCustomerMissions(customerId),
      builder: (context, snapshot) {
        final deliveries = snapshot.data ?? const <DeliveryMission>[];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final total = deliveries.length + mechanicJobs.length;
        final active = deliveries.where((d) => d.status.isOpenForAcceptance || d.status == MissionStatus.assigned || d.status == MissionStatus.driverToPickup || d.status == MissionStatus.arrivedAtPickup || d.status == MissionStatus.pickedUp || d.status == MissionStatus.inTransit || d.status == MissionStatus.arrivedAtDropoff).length +
            mechanicJobs.where((m) => m.status.name != 'completed' && m.status.name != 'cancelled').length;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${t('overview_greeting')}${firstName.isEmpty ? '' : ', $firstName'} 👋',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(t('overview_subtitle'), style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                )
              else
                Row(
                  children: [
                    Expanded(child: _StatCard(icon: Icons.list_alt, label: t('overview_stat_total'), value: '$total', color: AppColors.primary)),
                    const SizedBox(width: 14),
                    Expanded(child: _StatCard(icon: Icons.timelapse, label: t('overview_stat_active'), value: '$active', color: AppColors.warning)),
                  ],
                ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.local_shipping_rounded,
                      gradient: AppColors.deliveryGradient,
                      label: t('overview_new_delivery'),
                      onTap: () => context.go('/$locale/livraison/demande'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.build_rounded,
                      gradient: AppColors.mechanicGradient,
                      label: t('overview_new_mechanic'),
                      onTap: () => context.go('/$locale/mecanique-mobile/demande'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t('overview_recent_title'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  TextButton(onPressed: () => onGoToTab(1), child: Text(t('overview_see_all'))),
                ],
              ),
              const SizedBox(height: 12),
              if (!isLoading && total == 0)
                _EmptyState(t: t, onCreate: () => context.go('/$locale/livraison/demande'))
              else if (!isLoading)
                ...[
                  ...deliveries.take(3).map((d) => _RequestPreviewTile(
                        icon: Icons.local_shipping_outlined,
                        title: d.itemCategoryKey.isEmpty ? t('delivery_item_category') : t(d.itemCategoryKey),
                        subtitle: (d.pickupAddress != null && d.dropoffAddress != null)
                            ? '${d.pickupAddress!.city} → ${d.dropoffAddress!.city}'
                            : t('delivery_step_addresses_title'),
                        status: t(d.status.key),
                      )),
                  ...mechanicJobs.take(3).map((m) => _RequestPreviewTile(
                        icon: Icons.build_outlined,
                        title: m.selectedServices.isEmpty ? t('delivery_item_category') : t(m.selectedServices.first),
                        subtitle: '${m.vehicleMake} ${m.vehicleModel}',
                        status: m.status.name,
                      )),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;
  final String label;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.gradient, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 12),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _RequestPreviewTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  const _RequestPreviewTile({required this.icon, required this.title, required this.subtitle, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
            child: Text(status, style: const TextStyle(fontSize: 10, color: AppColors.info, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String Function(String) t;
  final VoidCallback onCreate;
  const _EmptyState({required this.t, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(t('overview_empty_title'), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: onCreate, child: Text(t('overview_empty_cta'))),
        ],
      ),
    );
  }
}
