// Centre de commande > 3 · Où et quand ? (owner decision 2026-10-26).
// Zones (circles around a center) and booking hours, saved by the
// adminServiceSettings function. Outside a zone, or outside the hours, a
// request is refused before any price.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../../widgets/address_autocomplete_field.dart';

typedef ServiceSettingsApi =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

Future<Map<String, dynamic>> _firebaseApi(Map<String, dynamic> data) async {
  final result = await FirebaseFunctions.instance
      .httpsCallable('adminServiceSettings')
      .call(data);
  return Map<String, dynamic>.from(result.data as Map);
}

class _Zone {
  _Zone(this.name, this.lat, this.lng, this.radiusKm);
  String name;
  double lat, lng, radiusKm;
  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'center_lat': lat,
    'center_lng': lng,
    'radius_km': radiusKm,
  };
}

const _weekdays = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
const _leadChoices = [0, 30, 60, 120, 240, 1440];

class ServiceSettingsPanel extends StatefulWidget {
  const ServiceSettingsPanel({super.key, this.api});
  final ServiceSettingsApi? api;
  @override
  State<ServiceSettingsPanel> createState() => _ServiceSettingsPanelState();
}

class _ServiceSettingsPanelState extends State<ServiceSettingsPanel> {
  ServiceSettingsApi get _api => widget.api ?? _firebaseApi;
  final List<_Zone> _zones = [];
  Set<int> _hours = {};
  Set<int> _days = {};
  int _lead = 60, _ahead = 4;
  bool _loaded = false, _busy = true, _dirty = false, _zonesSaved = false, _hoursSaved = false;
  String? _error, _saved;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api({'action': 'get'});
      final zones = Map<String, dynamic>.from(r['zones'] as Map);
      final hours = Map<String, dynamic>.from(r['hours'] as Map);
      _zones
        ..clear()
        ..addAll([
          for (final raw in zones['list'] as List)
            _Zone(
              '${(raw as Map)['name']}',
              (raw['center_lat'] as num).toDouble(),
              (raw['center_lng'] as num).toDouble(),
              (raw['radius_km'] as num).toDouble(),
            ),
        ]);
      _hours = {for (final h in hours['slot_hours'] as List) h as int};
      _days = {for (final d in hours['open_weekdays'] as List) d as int};
      _lead = hours['lead_minutes'] as int;
      _ahead = (hours['days_ahead'] as int).clamp(1, 5);
      _zonesSaved = zones['saved'] == true;
      _hoursSaved = hours['saved'] == true;
      _loaded = true;
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Lecture refusée.';
    } catch (_) {
      _error = 'Lecture impossible. Réessayez.';
    }
    if (mounted) setState(() => _busy = false);
  }

  void _change(VoidCallback f) => setState(() {
    f();
    _dirty = true;
    _saved = null;
  });

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _api({
        'action': 'save',
        'zones': [for (final z in _zones) z.toJson()],
        'hours': {
          'slot_hours': (_hours.toList()..sort()),
          'lead_minutes': _lead,
          'days_ahead': _ahead,
          'open_weekdays': (_days.toList()..sort()),
        },
      });
      _dirty = false;
      _zonesSaved = _hoursSaved = true;
      _saved = 'Enregistré. En vigueur tout de suite pour les nouvelles demandes.';
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Enregistrement refusé.';
    } catch (_) {
      _error = 'Enregistrement impossible. Réessayez.';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _pickCenter(int index) async {
    final controller = TextEditingController();
    final picked = await showDialog<(String, double, double)>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Centre de la zone'),
        content: SizedBox(
          width: 420,
          child: AddressAutocompleteField(
            key: const ValueKey('zone-center-field'),
            controller: controller,
            label: 'Ville ou adresse',
            onResolved: (a) => Navigator.of(context).pop((a.city.isNotEmpty ? a.city : a.formattedAddress, a.lat, a.lng)),
            onInvalidated: () {},
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Annuler')),
        ],
      ),
    );
    controller.dispose();
    if (picked == null || !mounted) return;
    _change(() {
      if (index < 0) {
        _zones.add(_Zone(picked.$1, picked.$2, picked.$3, 20));
      } else {
        _zones[index]
          ..lat = picked.$2
          ..lng = picked.$3;
        if (_zones[index].name.trim().isEmpty) _zones[index].name = picked.$1;
      }
      _gen++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final card = BoxDecoration(
      color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    );
    Widget heading(String text) => Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Ce que le client peut réserver. Une adresse hors zone ou une heure hors plage est refusée avant le prix.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_error!, key: const ValueKey('service-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (_loaded) ...[
          Container(
            key: const ValueKey('service-zones'),
            padding: const EdgeInsets.all(16),
            decoration: card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading('Zone desservie'),
                if (!_zonesSaved)
                  const Text('Zone de lancement par défaut (jamais enregistrée).', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                for (var i = 0; i < _zones.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 200,
                          child: TextFormField(
                            key: ValueKey('zone-name-$i-$_gen'),
                            initialValue: _zones[i].name,
                            decoration: const InputDecoration(labelText: 'Nom'),
                            onChanged: (v) => _change(() => _zones[i].name = v),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: TextFormField(
                            key: ValueKey('zone-radius-$i-$_gen'),
                            initialValue: _zones[i].radiusKm.toStringAsFixed(0),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Rayon (km)'),
                            onChanged: (v) {
                              final r = double.tryParse(v.replaceAll(',', '.'));
                              if (r != null) _change(() => _zones[i].radiusKm = r);
                            },
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _busy ? null : () => _pickCenter(i),
                          icon: const Icon(Icons.place_outlined),
                          label: const Text('Changer le centre'),
                        ),
                        if (_zones.length > 1)
                          IconButton(
                            tooltip: 'Retirer la zone',
                            onPressed: _busy ? null : () => _change(() {
                              _zones.removeAt(i);
                              _gen++;
                            }),
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const ValueKey('zone-add'),
                    onPressed: _busy || _zones.length >= 20 ? null : () => _pickCenter(-1),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('Ajouter une ville'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            key: const ValueKey('service-hours'),
            padding: const EdgeInsets.all(16),
            decoration: card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading('Heures de réservation'),
                if (!_hoursSaved)
                  const Text('Heures de lancement par défaut (jamais enregistrées).', style: TextStyle(color: AppColors.textSecondary)),
                const SizedBox(height: 10),
                const Text('Heures offertes', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var h = 6; h <= 21; h++)
                      FilterChip(
                        key: ValueKey('service-hour-$h'),
                        label: Text('$h h'),
                        selected: _hours.contains(h),
                        onSelected: _busy ? null : (on) => _change(() => on ? _hours.add(h) : _hours.remove(h)),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Jours ouverts', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      FilterChip(
                        key: ValueKey('service-day-$d'),
                        label: Text(_weekdays[d - 1]),
                        selected: _days.contains(d),
                        onSelected: _busy ? null : (on) => _change(() => on ? _days.add(d) : _days.remove(d)),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Délai minimum'),
                    DropdownButton<int>(
                      key: const ValueKey('service-lead'),
                      value: _leadChoices.contains(_lead) ? _lead : 60,
                      onChanged: _busy ? null : (v) => _change(() => _lead = v ?? 60),
                      items: [
                        for (final m in _leadChoices)
                          DropdownMenuItem(value: m, child: Text(m == 0 ? 'Aucun' : m < 60 ? '$m min' : m == 1440 ? '1 jour' : '${m ~/ 60} h')),
                      ],
                    ),
                    const Text('Jours à l’avance'),
                    DropdownButton<int>(
                      key: const ValueKey('service-ahead'),
                      value: _ahead,
                      onChanged: _busy ? null : (v) => _change(() => _ahead = v ?? 4),
                      // PAY-08 (2026-10-27) : la carte est autorisée à l'acceptation
                      // et débitée à la livraison ; une autorisation expire après
                      // ~7 jours. 5 jours au maximum (voir bookingHours.ts).
                      items: [for (var d = 1; d <= 5; d++) DropdownMenuItem(value: d, child: Text('$d'))],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('service-save'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            onPressed: _busy || !_dirty || _hours.isEmpty || _days.isEmpty || _zones.isEmpty ? null : _save,
            child: const Text('Enregistrer'),
          ),
          if (_saved != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_saved!, key: const ValueKey('service-saved')),
            ),
        ],
      ],
    );
  }
}
