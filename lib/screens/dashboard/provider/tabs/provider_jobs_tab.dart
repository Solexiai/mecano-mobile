import 'package:flutter/material.dart';
import '../../../../core/app_colors.dart';
import '../../../../widgets/coming_soon_badge.dart';

/// Demo view of incoming job requests for a provider (driver or mechanic).
/// Uses static demo data — no live backend request matching is connected yet.
class ProviderJobsTab extends StatefulWidget {
  const ProviderJobsTab({super.key});

  @override
  State<ProviderJobsTab> createState() => _ProviderJobsTabState();
}

class _ProviderJobsTabState extends State<ProviderJobsTab> {
  final Set<String> _accepted = {};
  final Set<String> _declined = {};

  final List<Map<String, dynamic>> _demoJobs = const [
    {
      'id': 'job1',
      'type': 'delivery',
      'title': 'Livraison de meubles',
      'from': 'Plateau-Mont-Royal',
      'to': 'Rosemont',
      'date': 'Demain, 14h-17h',
      'price': 85.0,
      'assistance': 'Aide au chargement requise',
    },
    {
      'id': 'job2',
      'type': 'mechanic',
      'title': 'Changement de batterie',
      'from': 'Domicile client - Verdun',
      'to': null,
      'date': 'Aujourd\'hui, 17h-19h',
      'price': 95.0,
      'assistance': null,
    },
    {
      'id': 'job3',
      'type': 'delivery',
      'title': 'Transport de BBQ',
      'from': 'Home Depot Laval',
      'to': 'Terrebonne',
      'date': 'Samedi, 10h-13h',
      'price': 70.0,
      'assistance': null,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final visible = _demoJobs.where((j) => !_declined.contains(j['id'])).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Demandes disponibles', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
              const DemoDataBadge(),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Exemples de demandes pour démonstration. Le système d\'appariement en temps réel sera connecté prochainement.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          const SizedBox(height: 20),
          if (visible.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('Aucune nouvelle demande pour le moment', style: TextStyle(color: AppColors.textSecondary))))
          else
            ...visible.map((job) => _JobCard(
                  job: job,
                  isAccepted: _accepted.contains(job['id']),
                  onAccept: () => setState(() => _accepted.add(job['id'])),
                  onDecline: () => setState(() => _declined.add(job['id'])),
                )),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final Map<String, dynamic> job;
  final bool isAccepted;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _JobCard({required this.job, required this.isAccepted, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) {
    final isDelivery = job['type'] == 'delivery';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isAccepted ? AppColors.success : AppColors.border, width: isAccepted ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(gradient: isDelivery ? AppColors.deliveryGradient : AppColors.mechanicGradient, borderRadius: BorderRadius.circular(10)),
                child: Icon(isDelivery ? Icons.local_shipping_outlined : Icons.build_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(job['title'], style: const TextStyle(fontWeight: FontWeight.w700))),
              Text('${(job['price'] as double).toStringAsFixed(0)}\$', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          if (job['to'] != null)
            _InfoRow(icon: Icons.route_outlined, text: '${job['from']} → ${job['to']}')
          else
            _InfoRow(icon: Icons.place_outlined, text: job['from']),
          _InfoRow(icon: Icons.schedule, text: job['date']),
          if (job['assistance'] != null) _InfoRow(icon: Icons.info_outline, text: job['assistance']),
          const SizedBox(height: 14),
          if (isAccepted)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('Acceptée', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700))),
            )
          else
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: onDecline, child: const Text('Refuser'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: onAccept, child: const Text('Accepter'))),
              ],
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
