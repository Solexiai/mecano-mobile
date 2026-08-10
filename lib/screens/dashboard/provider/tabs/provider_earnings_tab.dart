import 'package:flutter/material.dart';
import '../../../../core/app_colors.dart';
import '../../../../widgets/coming_soon_badge.dart';

class ProviderEarningsTab extends StatelessWidget {
  const ProviderEarningsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Text('Revenus', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
              const ComingSoonBadge(),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            "Le suivi automatisé des revenus et les paiements en ligne seront activés lorsque le traitement des paiements sera connecté. Pour l'instant, le paiement se fait directement entre le client et le fournisseur.",
            style: TextStyle(color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: _MetricCard(label: 'Emplois complétés (démo)', value: '0', color: AppColors.primary)),
              const SizedBox(width: 14),
              Expanded(child: _MetricCard(label: 'Note moyenne', value: '—', color: AppColors.warning)),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Configuration de tarification', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text('Ajustez vos tarifs horaires, frais au kilomètre et forfaits directement depuis "Mes services".', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
