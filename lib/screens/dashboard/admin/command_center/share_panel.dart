// Centre de commande > 4 · Qui reçoit quoi ? (owner mockup 2026-10-26):
// how the customer's price is shared, read from the ACTIVE price grid, with
// the simulator. The amounts are changed in "Combien ?" (versioned, simulated,
// published by the super admin); taxes are never changed here.
import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../../finance/models/pricing_grid_admin.dart';
import 'price_simulator.dart';

class SharePanel extends StatefulWidget {
  const SharePanel({super.key, required this.onEditPrices, this.loadActive, this.preview});
  final VoidCallback onEditPrices;
  final ActiveVersionLoader? loadActive;
  final PricePreviewer? preview;
  @override
  State<SharePanel> createState() => _SharePanelState();
}

class _SharePanelState extends State<SharePanel> {
  Map<String, dynamic>? _raw;

  String _pct(Object? v) => v is num ? '${(v * 100).toStringAsFixed(v * 100 % 1 == 0 ? 0 : 1)} %' : '—';
  String _money(Object? v) => v is num ? '${v.toStringAsFixed(2).replaceAll('.', ',')} \$' : '—';

  @override
  Widget build(BuildContext context) {
    final raw = _raw;
    Map<String, dynamic> sub(String key) =>
        raw?[key] is Map ? Map<String, dynamic>.from(raw![key] as Map) : const {};
    final commission = sub('commission');
    final service = sub('customer_service_fee');
    final items = sub('item_class_fees');
    Widget line(String key, String label, String value) => Padding(
      key: ValueKey('share-$key'),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))],
      ),
    );
    final card = BoxDecoration(
      color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Comment le prix payé par le client se partage, selon la grille active.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        PriceSimulator(
          loadActive: widget.loadActive,
          preview: widget.preview,
          onActive: (AdminPricingVersionInfo? v) {
            if (mounted) setState(() => _raw = v?.raw);
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: card,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Part de Movi-K', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              line('commission', 'Commission sur la course', _pct(commission['standard_commission_rate'])),
              line('commission-min', 'Commission minimum', _money(commission['minimum_platform_commission'])),
              line('service', 'Frais de service client', _pct(service['service_fee_rate'])),
              line('service-min', 'Frais de service minimum', _money(service['minimum_service_fee'])),
              const Divider(height: 24),
              const Text('Supplément par objet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              line(
                'items',
                'Qui le reçoit',
                items['driver_keeps_all'] == false ? 'Commission appliquée' : '100 % au chauffeur',
              ),
              const Divider(height: 24),
              const Text('Taxes', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const Text(
                'Calculées sur le total, comme toujours. Elles ne se modifient jamais ici : à voir avec votre comptable.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('share-edit'),
                  onPressed: widget.onEditPrices,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier dans « Combien ? »'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
