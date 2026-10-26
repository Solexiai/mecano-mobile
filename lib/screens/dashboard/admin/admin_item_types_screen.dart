// Types d'objets et véhicules (owner decision 2026-10-26): the admin checks
// which vehicles may carry each item type. Saved in
// system_config/booking_capacity.photo_intake by adminItemTypes (server).
// The price does not depend on the vehicle: this only decides which drivers
// see a request.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../services/booking/item_types.dart';

typedef ItemTypesApi =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

Future<Map<String, dynamic>> _firebaseItemTypesApi(
  Map<String, dynamic> data,
) async {
  final result = await FirebaseFunctions.instance
      .httpsCallable('adminItemTypes')
      .call(data);
  return Map<String, dynamic>.from(result.data as Map);
}

const _vehicleLabels = {
  'pickup_truck': 'Pickup',
  'cargo_van': 'Fourgonnette',
  'cube_truck': 'Camion cube',
};

class AdminItemTypesScreen extends StatefulWidget {
  const AdminItemTypesScreen({super.key, this.api});
  final ItemTypesApi? api;
  @override
  State<AdminItemTypesScreen> createState() => _AdminItemTypesScreenState();
}

class _AdminItemTypesScreenState extends State<AdminItemTypesScreen> {
  ItemTypesApi get _api => widget.api ?? _firebaseItemTypesApi;
  final Map<String, Set<String>> _checked = {};
  final Set<String> _unsaved = {};
  List<String> _vehicles = const ['pickup_truck', 'cargo_van', 'cube_truck'];
  bool _loaded = false, _busy = true, _dirty = false;
  String? _error, _saved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final state = await _api({'action': 'get'});
      _vehicles = [for (final v in state['vehicles'] as List) v as String];
      _checked.clear();
      _unsaved.clear();
      for (final raw in state['types'] as List) {
        final t = Map<String, dynamic>.from(raw as Map);
        final id = t['category'] as String;
        _checked[id] = {for (final v in t['vehicles'] as List) v as String};
        if (t['saved'] != true) _unsaved.add(id);
      }
      _loaded = true;
      _dirty = _unsaved.isNotEmpty;
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Lecture refusée.';
    } catch (_) {
      _error = 'Lecture impossible. Réessayez.';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
      _saved = null;
    });
    try {
      final result = await _api({
        'action': 'save',
        'mapping': {
          for (final e in _checked.entries)
            e.key: [for (final v in _vehicles) if (e.value.contains(v)) v],
        },
      });
      _unsaved.clear();
      _dirty = false;
      _saved = 'Enregistré (version ${result['version']}). En vigueur tout de suite.';
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Enregistrement refusé.';
    } catch (_) {
      _error = 'Enregistrement impossible. Réessayez.';
    }
    if (mounted) setState(() => _busy = false);
  }

  void _toggle(String type, String vehicle, bool on) => setState(() {
    final set = _checked.putIfAbsent(type, () => {});
    on ? set.add(vehicle) : set.remove(vehicle);
    _dirty = true;
    _saved = null;
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final types = itemTypes.where((t) => _checked.containsKey(t.id)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Types d’objets et véhicules')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Cochez les véhicules qui peuvent prendre chaque type d’objet. Seuls les chauffeurs avec un de ces véhicules voient la demande. Le prix ne change pas selon le véhicule.',
          ),
          const SizedBox(height: 12),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _error!,
                key: const ValueKey('item-types-error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          if (_unsaved.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Les types marqués « nouveau » sont pré-cochés selon la proposition du 26 oct. Ils ne sont offerts aux clients qu’après « Enregistrer ».',
                key: const ValueKey('item-types-unsaved'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          if (_loaded)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                key: const ValueKey('item-types-table'),
                columnSpacing: 18,
                columns: [
                  const DataColumn(label: Text('Type d’objet')),
                  for (final v in _vehicles)
                    DataColumn(label: Text(_vehicleLabels[v] ?? v)),
                ],
                rows: [
                  for (final t in types)
                    DataRow(
                      cells: [
                        DataCell(
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.fr),
                              if (_unsaved.contains(t.id))
                                const Text(
                                  'nouveau',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF8A4307)),
                                )
                              else if (_checked[t.id]!.isEmpty)
                                Text(
                                  'non offert',
                                  key: ValueKey('item-type-off-${t.id}'),
                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.error),
                                ),
                            ],
                          ),
                        ),
                        for (final v in _vehicles)
                          DataCell(
                            Checkbox(
                              key: ValueKey('item-type-${t.id}-$v'),
                              value: _checked[t.id]!.contains(v),
                              onChanged: _busy ? null : (on) => _toggle(t.id, v, on == true),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          if (_loaded)
            FilledButton(
              key: const ValueKey('item-types-save'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _busy || !_dirty ? null : _save,
              child: const Text('Enregistrer'),
            ),
          if (_saved != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_saved!, key: const ValueKey('item-types-saved')),
            ),
          const SizedBox(height: 8),
          const Text(
            'Un type sans aucune case cochée n’est plus offert : le client lit « La demande par photo n’est pas encore disponible pour cet objet ».',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
