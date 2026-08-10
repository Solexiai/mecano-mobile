import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/delivery_provider.dart';
import '../../../../providers/mechanic_provider.dart';
import '../../../../providers/locale_provider.dart';

class CustomerOverviewTab extends StatelessWidget {
  final void Function(int) onGoToTab;
  const CustomerOverviewTab({super.key, required this.onGoToTab});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final locale = context.watch<LocaleProvider>().locale;
    final deliveries = context.watch<DeliveryProvider>().forCustomer(auth.currentUser!.id);
    final mechanicJobs = context.watch<MechanicRequestProvider>().forCustomer(auth.currentUser!.id);
    final total = deliveries.length + mechanicJobs.length;
    final active = deliveries.where((d) => d.status.name != 'delivered' && d.status.name != 'cancelled').length +
        mechanicJobs.where((m) => m.status.name != 'completed' && m.status.name != 'cancelled').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bonjour, ${auth.currentUser!.fullName.split(' ').first} 👋', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Voici un résumé de votre activité sur Movi-k.', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _StatCard(icon: Icons.list_alt, label: 'Demandes totales', value: '$total', color: AppColors.primary)),
              const SizedBox(width: 14),
              Expanded(child: _StatCard(icon: Icons.timelapse, label: 'Actives', value: '$active', color: AppColors.warning)),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.local_shipping_rounded,
                  gradient: AppColors.deliveryGradient,
                  label: 'Nouvelle livraison',
                  onTap: () => context.go('/$locale/livraison/demande'),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _QuickAction(
                  icon: Icons.build_rounded,
                  gradient: AppColors.mechanicGradient,
                  label: 'Nouveau service mécanique',
                  onTap: () => context.go('/$locale/mecanique-mobile/demande'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Demandes récentes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              TextButton(onPressed: () => onGoToTab(1), child: const Text('Tout voir')),
            ],
          ),
          const SizedBox(height: 12),
          if (total == 0)
            _EmptyState(onCreate: () => context.go('/$locale/livraison/demande'))
          else
            ...[
              ...deliveries.take(3).map((d) => _RequestPreviewTile(
                    icon: Icons.local_shipping_outlined,
                    title: d.itemCategory.isEmpty ? 'Livraison' : d.itemCategory,
                    subtitle: '${d.pickupAddress} → ${d.deliveryAddress}',
                    status: d.status.name,
                  )),
              ...mechanicJobs.take(3).map((m) => _RequestPreviewTile(
                    icon: Icons.build_outlined,
                    title: m.selectedServices.isEmpty ? 'Service mécanique' : m.selectedServices.first,
                    subtitle: '${m.vehicleMake} ${m.vehicleModel}',
                    status: m.status.name,
                  )),
            ],
        ],
      ),
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
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          const Text('Aucune demande pour le moment', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: onCreate, child: const Text('Créer ma première demande')),
        ],
      ),
    );
  }
}
