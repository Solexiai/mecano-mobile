// "Essayer un prix" (Centre de commande, owner mockup 2026-10-26): pick an
// item, a distance, stairs or two movers, and see who receives what with
// the ACTIVE price grid, computed by the server's own engine
// (previewPricingConfiguration, read only). Nothing is saved.
import 'package:flutter/material.dart';

import '../../../../backend/backend_locator.dart';
import '../../../../core/app_colors.dart';
import '../../../../finance/models/pricing_grid_admin.dart';
import '../../../../finance/models/pricing_grid_draft.dart';
import '../../../../finance/presentation/money_format.dart';
import '../../../../services/booking/item_types.dart';

typedef ActiveVersionLoader = Future<AdminPricingVersionInfo?> Function();
typedef PricePreviewer =
    Future<PricingPreviewResult> Function(
      Map<String, dynamic> config,
      List<Map<String, dynamic>> scenarios,
    );

Future<AdminPricingVersionInfo?> _loadActive() =>
    BackendLocator.financeRepository.adminGetActivePricingVersion();

Future<PricingPreviewResult> _preview(
  Map<String, dynamic> config,
  List<Map<String, dynamic>> scenarios,
) => BackendLocator.financeRepository.adminPreviewPricing(
  config: config,
  scenarios: scenarios,
  vehicleCategory: kPilotPricingCategories.first,
);

class PriceSimulator extends StatefulWidget {
  const PriceSimulator({super.key, this.loadActive, this.preview, this.onActive});
  final ActiveVersionLoader? loadActive;
  final PricePreviewer? preview;

  /// The active version, once loaded (the share summary reads it).
  final ValueChanged<AdminPricingVersionInfo?>? onActive;

  @override
  State<PriceSimulator> createState() => _PriceSimulatorState();
}

class _PriceSimulatorState extends State<PriceSimulator> {
  AdminPricingVersionInfo? _active;
  String _item = 'sofa';
  int _quantity = 1;
  double _km = 15;
  bool _stairs = false, _twoPeople = false, _busy = true;
  PricingPreviewAmounts? _amounts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      _active = await (widget.loadActive ?? _loadActive)();
      widget.onActive?.call(_active);
    } catch (_) {
      _error = 'Grille de tarifs illisible pour le moment.';
    }
    await _run();
  }

  Future<void> _run() async {
    final active = _active;
    if (active == null) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error ??= 'Aucune grille de tarifs active.';
        });
      }
      return;
    }
    setState(() => _busy = true);
    try {
      final config = PricingGridDraft.fromVersion(active.raw, versionId: active.id).toServerConfig();
      final result = await (widget.preview ?? _preview)(config, [
        {
          'id': 'try',
          'distanceKm': _km,
          // Road time estimate for the try only: about 2 min per km + 10.
          'durationMinutes': (_km * 2 + 10).roundToDouble(),
          'additionalStops': 0,
          'handling': {'needsStairs': _stairs, 'needsSecondHandler': _twoPeople},
          'items': [
            {'category': _item, 'quantity': _quantity},
          ],
        },
      ]);
      _amounts = result.rows.isEmpty ? null : result.rows.first.current ?? result.rows.first.draft;
      _error = result.errors.isEmpty ? null : result.errors.join(' ');
    } catch (_) {
      _error = 'Calcul impossible pour le moment. Réessayez.';
    }
    if (mounted) setState(() => _busy = false);
  }

  void _set(VoidCallback f) {
    setState(f);
    _run();
  }

  String _money(int minor) => formatMajorAmount(minor / 100, locale: 'fr', currencySymbol: r'$');

  @override
  Widget build(BuildContext context) {
    final a = _amounts;
    Widget result(String key, String label, int? minor, Color bg, Color fg) => Container(
      key: ValueKey('try-$key'),
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13)),
          Text(minor == null ? '—' : _money(minor),
              style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 22)),
        ],
      ),
    );
    return Container(
      key: const ValueKey('price-simulator'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              const Text('Essayer un prix', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text(
                _active == null ? '' : 'Grille active : ${_active!.id}. Rien n’est enregistré.',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: DropdownButton<String>(
                  key: const ValueKey('try-item'),
                  isExpanded: true,
                  value: _item,
                  onChanged: _busy ? null : (v) => _set(() => _item = v ?? 'sofa'),
                  items: [
                    for (final t in itemTypes)
                      DropdownMenuItem(
                        value: t.id,
                        child: Text(t.fr, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ),
              DropdownButton<int>(
                key: const ValueKey('try-quantity'),
                value: _quantity,
                onChanged: _busy ? null : (v) => _set(() => _quantity = v ?? 1),
                items: [for (var q = 1; q <= 6; q++) DropdownMenuItem(value: q, child: Text('× $q'))],
              ),
              DropdownButton<double>(
                key: const ValueKey('try-km'),
                value: _km,
                onChanged: _busy ? null : (v) => _set(() => _km = v ?? 15),
                items: [
                  for (final km in const [5.0, 10.0, 15.0, 25.0, 40.0])
                    DropdownMenuItem(value: km, child: Text('${km.round()} km')),
                ],
              ),
              FilterChip(
                key: const ValueKey('try-stairs'),
                label: const Text('Escaliers'),
                selected: _stairs,
                onSelected: _busy ? null : (v) => _set(() => _stairs = v),
              ),
              FilterChip(
                key: const ValueKey('try-two'),
                label: const Text('2 déménageurs'),
                selected: _twoPeople,
                onSelected: _busy ? null : (v) => _set(() => _twoPeople = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Text(_error!, key: const ValueKey('try-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              result('customer', 'Le client paie', a?.customerTotalMinor, AppColors.primary, Colors.white),
              result('driver', 'Le chauffeur reçoit', a?.driverMinor, const Color(0xFFE3F2E8), const Color(0xFF1F6B3A)),
              result('movik', 'Movi-K garde', a?.platformMinor, const Color(0xFFE6EDFA), AppColors.primary),
              result('tax', 'Taxes', a?.taxMinor, const Color(0xFFF1F2F5), const Color(0xFF3A4254)),
            ],
          ),
        ],
      ),
    );
  }
}
