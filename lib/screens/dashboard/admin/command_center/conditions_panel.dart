// Centre de commande > 5 · Conditions spéciales (owner decision 2026-10-26).
// A "difficult conditions" supplement with its reason, for a period (it ends
// by itself), and a service pause with a message. Saved by the
// adminSpecialConditions function. A quote already given keeps its price.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';

typedef ConditionsApi =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

Future<Map<String, dynamic>> _firebaseApi(Map<String, dynamic> data) async {
  final result = await FirebaseFunctions.instance
      .httpsCallable('adminSpecialConditions')
      .call(data);
  return Map<String, dynamic>.from(result.data as Map);
}

const _reasons = {
  'snow': 'Tempête de neige',
  'ice': 'Verglas',
  'rain': 'Pluie forte',
  'event': 'Événement',
};
const _durations = [3, 6, 12, 24, 48, 72];

class ConditionsPanel extends StatefulWidget {
  const ConditionsPanel({super.key, this.api, this.clock});
  final ConditionsApi? api;
  final DateTime Function()? clock;
  @override
  State<ConditionsPanel> createState() => _ConditionsPanelState();
}

class _ConditionsPanelState extends State<ConditionsPanel> {
  ConditionsApi get _api => widget.api ?? _firebaseApi;
  DateTime get _now => (widget.clock ?? DateTime.now)();

  bool _loaded = false, _busy = true;
  bool _surchargeOn = false, _inForce = false, _pauseOn = false;
  String _reason = 'snow', _mode = 'percentage';
  double _value = 15; // % or $
  int _hours = 12;
  DateTime? _endsAt;
  int? _startMs, _endMs;
  String _pauseMessage = '';
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
      final c = Map<String, dynamic>.from(r['conditions'] as Map);
      final s = Map<String, dynamic>.from(c['surcharge'] as Map);
      final p = Map<String, dynamic>.from(c['pause'] as Map);
      _surchargeOn = s['active'] == true;
      _inForce = r['surchargeInForce'] == true;
      _reason = _reasons.containsKey(s['reason']) ? s['reason'] as String : 'snow';
      _mode = s['mode'] == 'fixed_amount' ? 'fixed_amount' : 'percentage';
      final v = (s['value'] as num?)?.toDouble() ?? 0;
      if (v > 0) _value = _mode == 'percentage' ? v * 100 : v;
      final start = s['starts_at_ms'], end = s['ends_at_ms'];
      if (start is int && end is int && end > start) {
        _startMs = start;
        _endMs = end;
      }
      _endsAt = end is int && end > 0 ? DateTime.fromMillisecondsSinceEpoch(end) : null;
      _pauseOn = p['active'] == true;
      _pauseMessage = '${p['message'] ?? ''}';
      _loaded = true;
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Lecture refusée.';
    } catch (_) {
      _error = 'Lecture impossible. Réessayez.';
    }
    if (mounted) setState(() => _busy = false);
  }

  /// [renew] starts a new period now (Activate / Update); otherwise the
  /// saved period is kept (e.g. pausing does not extend the supplement).
  Future<void> _save({required bool surcharge, required bool pause, bool renew = false}) async {
    setState(() {
      _busy = true;
      _error = null;
      _saved = null;
    });
    final now = _now.millisecondsSinceEpoch;
    final keep = !renew && _startMs != null && _endMs != null;
    final start = keep ? _startMs! : now;
    final end = keep ? _endMs! : now + (renew ? _hours : 1) * 3600000;
    try {
      final r = await _api({
        'action': 'save',
        'conditions': {
          'surcharge': {
            'active': surcharge,
            'reason': _reason,
            'mode': _mode,
            'value': _mode == 'percentage' ? _value / 100 : _value,
            'starts_at_ms': start,
            'ends_at_ms': end,
          },
          'pause': {'active': pause, 'message': _pauseMessage.trim()},
        },
      });
      _surchargeOn = surcharge;
      _pauseOn = pause;
      _inForce = r['surchargeInForce'] == true;
      _startMs = start;
      _endMs = end;
      _endsAt = surcharge ? DateTime.fromMillisecondsSinceEpoch(end) : null;
      _saved = 'Enregistré. En vigueur tout de suite pour les nouveaux prix.';
      _gen++;
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Enregistrement refusé.';
    } catch (_) {
      _error = 'Enregistrement impossible. Réessayez.';
    }
    if (mounted) setState(() => _busy = false);
  }

  String _time(DateTime d) =>
      '${d.day}/${d.month} à ${d.hour} h ${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    BoxDecoration card(Color border) => BoxDecoration(
      color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border, width: 2),
    );
    final amount = _mode == 'percentage'
        ? '+${_value.toStringAsFixed(0)} %'
        : '+${_value.toStringAsFixed(2).replaceAll('.', ',')} \$';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Tempête, verglas, gros accident : vous décidez. Le client voit toujours le supplément et sa raison avant de payer. Un prix déjà donné ne change pas.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_error!, key: const ValueKey('conditions-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        if (_loaded) ...[
          Container(
            key: const ValueKey('conditions-surcharge'),
            padding: const EdgeInsets.all(16),
            decoration: card(const Color(0xFFB85E10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Supplément conditions difficiles', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  _inForce && _endsAt != null
                      ? 'En vigueur jusqu’au ${_time(_endsAt!)}.'
                      : 'Aucun supplément en vigueur.',
                  key: const ValueKey('conditions-status'),
                  style: TextStyle(fontWeight: FontWeight.w700, color: _inForce ? const Color(0xFF8A4307) : const Color(0xFF1F6B3A)),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    DropdownButton<String>(
                      key: const ValueKey('conditions-reason'),
                      value: _reason,
                      onChanged: _busy ? null : (v) => setState(() => _reason = v ?? 'snow'),
                      items: [for (final e in _reasons.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    ),
                    SegmentedButton<String>(
                      key: const ValueKey('conditions-mode'),
                      segments: const [
                        ButtonSegment(value: 'percentage', label: Text('%')),
                        ButtonSegment(value: 'fixed_amount', label: Text('\$')),
                      ],
                      selected: {_mode},
                      onSelectionChanged: _busy ? null : (v) => setState(() {
                        _mode = v.first;
                        _value = _mode == 'percentage' ? 15 : 10;
                        _gen++;
                      }),
                    ),
                    SizedBox(
                      width: 120,
                      child: TextFormField(
                        key: ValueKey('conditions-value-$_gen'),
                        initialValue: _value.toStringAsFixed(_mode == 'percentage' ? 0 : 2),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: _mode == 'percentage' ? 'Pourcentage' : 'Montant (\$)'),
                        onChanged: (v) {
                          final n = double.tryParse(v.replaceAll(',', '.'));
                          if (n != null) setState(() => _value = n);
                        },
                      ),
                    ),
                    DropdownButton<int>(
                      key: const ValueKey('conditions-duration'),
                      value: _hours,
                      onChanged: _busy ? null : (v) => setState(() => _hours = v ?? 12),
                      items: [for (final h in _durations) DropdownMenuItem(value: h, child: Text('Pendant $h h'))],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFFF4E8), borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    'Ce que le client voit : « Comprend : supplément ${_reasons[_reason]!.toLowerCase()} » ($amount).',
                    key: const ValueKey('conditions-preview'),
                    style: const TextStyle(color: Color(0xFF5C2E05)),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      key: const ValueKey('conditions-activate'),
                      onPressed: _busy ? null : () => _save(surcharge: true, pause: _pauseOn, renew: true),
                      child: Text(_surchargeOn ? 'Mettre à jour et prolonger' : 'Activer maintenant'),
                    ),
                    if (_surchargeOn)
                      OutlinedButton(
                        key: const ValueKey('conditions-stop'),
                        onPressed: _busy ? null : () => _save(surcharge: false, pause: _pauseOn),
                        child: const Text('Arrêter le supplément'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            key: const ValueKey('conditions-pause'),
            padding: const EdgeInsets.all(16),
            decoration: card(const Color(0xFFA33A2F)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Pause du service', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  _pauseOn
                      ? 'EN PAUSE : aucune nouvelle demande. Les livraisons en cours continuent.'
                      : 'Pour un verglas dangereux : plus aucune nouvelle demande dans la zone. Les livraisons en cours continuent.',
                  key: const ValueKey('conditions-pause-status'),
                  style: TextStyle(fontWeight: _pauseOn ? FontWeight.w800 : FontWeight.w400, color: _pauseOn ? const Color(0xFFA33A2F) : null),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  key: ValueKey('conditions-pause-message-$_gen'),
                  initialValue: _pauseMessage,
                  maxLength: 300,
                  decoration: const InputDecoration(
                    labelText: 'Message au client',
                    hintText: 'Service suspendu à cause du verglas. De retour demain matin.',
                  ),
                  onChanged: (v) => setState(() => _pauseMessage = v),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _pauseOn
                      ? OutlinedButton(
                          key: const ValueKey('conditions-resume'),
                          onPressed: _busy ? null : () => _save(surcharge: _surchargeOn && _inForce, pause: false),
                          child: const Text('Reprendre le service'),
                        )
                      : FilledButton(
                          key: const ValueKey('conditions-pause-start'),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFA33A2F)),
                          onPressed: _busy || _pauseMessage.trim().isEmpty
                              ? null
                              : () => _save(surcharge: _surchargeOn && _inForce, pause: true),
                          child: const Text('Mettre en pause'),
                        ),
                ),
              ],
            ),
          ),
          if (_saved != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_saved!, key: const ValueKey('conditions-saved')),
            ),
          const SizedBox(height: 16),
          const Text(
            'Plus tard : Movi-K vous proposera d’activer un supplément quand Environnement Canada émet une alerte pour la zone ; et un bonus chauffeur pendant les tempêtes.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }
}
