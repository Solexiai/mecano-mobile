import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_colors.dart';
import '../../../../models/enums.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/delivery_provider.dart';
import '../../../../providers/mechanic_provider.dart';
import '../../../../providers/locale_provider.dart';

class CustomerRequestsTab extends StatefulWidget {
  const CustomerRequestsTab({super.key});

  @override
  State<CustomerRequestsTab> createState() => _CustomerRequestsTabState();
}

class _CustomerRequestsTabState extends State<CustomerRequestsTab> {
  int _filter = 0; // 0 = all, 1 = delivery, 2 = mechanic

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final t = context.watch<LocaleProvider>().t;
    final deliveries = context.watch<DeliveryProvider>().forCustomer(auth.currentUser!.id);
    final mechanicJobs = context.watch<MechanicRequestProvider>().forCustomer(auth.currentUser!.id);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mes demandes', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            children: [
              ChoiceChip(label: const Text('Toutes'), selected: _filter == 0, onSelected: (_) => setState(() => _filter = 0)),
              ChoiceChip(label: const Text('Livraisons'), selected: _filter == 1, onSelected: (_) => setState(() => _filter = 1)),
              ChoiceChip(label: const Text('Mécanique'), selected: _filter == 2, onSelected: (_) => setState(() => _filter = 2)),
            ],
          ),
          const SizedBox(height: 20),
          if (_filter != 2)
            ...deliveries.map((d) => _DeliveryTile(request: d, t: t)),
          if (_filter != 1)
            ...mechanicJobs.map((m) => _MechanicTile(request: m, t: t)),
          if (deliveries.isEmpty && mechanicJobs.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('Rien à afficher pour l\'instant', style: TextStyle(color: AppColors.textSecondary))),
            ),
        ],
      ),
    );
  }
}

class _DeliveryTile extends StatelessWidget {
  final dynamic request;
  final String Function(String) t;
  const _DeliveryTile({required this.request, required this.t});

  @override
  Widget build(BuildContext context) {
    final DeliveryStatus status = request.status;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.itemCategory.isEmpty ? 'Livraison' : t(request.itemCategory), style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text('${request.pickupAddress} → ${request.deliveryAddress}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatusChip(status: status.name),
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
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(gradient: AppColors.mechanicGradient, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.build_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.selectedServices.isEmpty ? 'Service mécanique' : (request.selectedServices as List<String>).map(t).join(', '), style: const TextStyle(fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${request.vehicleMake} ${request.vehicleModel} (${request.vehicleYear})', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _StatusChip(status: status.name),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color = AppColors.info;
    if (status.contains('cancel')) color = AppColors.error;
    if (status.contains('delivered') || status.contains('completed') || status.contains('accepted')) color = AppColors.success;
    if (status.contains('dispute')) color = AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    );
  }
}
