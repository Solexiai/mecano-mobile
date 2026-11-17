// Centre de commande › 7 · Prospects (Daniel, 2026-11-17).
//
//   - D'où viennent les prospects : tableau source → comptes → prix demandés
//     → réservations → chauffeurs (Cloud Function `getAcquisitionReport`).
//   - Relances par courriel : adresse postale de Movi-K (obligatoire dans
//     chaque relance, loi anti-pourriel) et interrupteur (Cloud Function
//     `adminEmailSettings`). Sans adresse postale, aucune relance ne part.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';

typedef ProspectsApi =
    Future<Map<String, dynamic>> Function(
      String function,
      Map<String, dynamic> data,
    );

Future<Map<String, dynamic>> _firebaseApi(
  String function,
  Map<String, dynamic> data,
) async {
  final result = await FirebaseFunctions.instance
      .httpsCallable(function)
      .call(data);
  return Map<String, dynamic>.from(result.data as Map);
}

/// Nom lisible d'un canal du tableau.
String acquisitionChannelLabel(String channel) => switch (channel) {
  'paid_social' => 'Publicité Facebook / Instagram',
  'paid_search' => 'Publicité Google / Bing',
  'organic_search' => 'Recherche (Google, Bing…)',
  'organic_social' => 'Réseaux sociaux (sans publicité)',
  'email' => 'Courriel (relances)',
  'campaign' => 'Autre campagne',
  'referral' => 'Autre site',
  'direct' => 'Direct (adresse tapée, favori)',
  'app' => 'Application',
  _ => 'Inconnue (inscrit avant le suivi)',
};

class ProspectsPanel extends StatelessWidget {
  const ProspectsPanel({super.key, this.api, this.canEdit = true});
  final ProspectsApi? api;
  final bool canEdit;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      FollowUpSettingsCard(api: api, canEdit: canEdit),
      AcquisitionReportCard(api: api),
    ],
  );
}

class FollowUpSettingsCard extends StatefulWidget {
  const FollowUpSettingsCard({super.key, this.api, this.canEdit = true});
  final ProspectsApi? api;
  final bool canEdit;

  @override
  State<FollowUpSettingsCard> createState() => _FollowUpSettingsCardState();
}

class _FollowUpSettingsCardState extends State<FollowUpSettingsCard> {
  ProspectsApi get _api => widget.api ?? _firebaseApi;
  final _address = TextEditingController();
  bool _enabled = true;
  bool _ready = false;
  bool _busy = true;
  String? _error, _saved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  void _apply(Map<String, dynamic> r) {
    _address.text = (r['postalAddress'] as String?) ?? '';
    _enabled = r['followUpsEnabled'] != false;
    _ready = r['ready'] == true;
  }

  Future<void> _load() async {
    try {
      _apply(await _api('adminEmailSettings', {'action': 'get'}));
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
      _apply(
        await _api('adminEmailSettings', {
          'action': 'save',
          'postalAddress': _address.text.trim(),
          'followUpsEnabled': _enabled,
        }),
      );
      _saved = _ready
          ? 'Enregistré : les relances partent, de 9 h à 20 h.'
          : _enabled
          ? 'Enregistré, mais aucune relance ne part : écrivez l’adresse postale complète.'
          : 'Enregistré : les relances sont arrêtées.';
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Enregistrement refusé.';
    } catch (_) {
      _error = 'Enregistrement impossible. Réessayez.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('followup-settings-card'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.forward_to_inbox, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Relances par courriel',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Client qui a eu un prix sans réserver : un courriel le lendemain, un autre 3 jours après sa demande. '
              'Chauffeur dont l’inscription n’est pas terminée : mêmes rappels. '
              'Chaque relance porte l’adresse postale de Movi-K et un lien « Me désabonner » (loi anti-pourriel). '
              'Sans adresse postale, aucune relance ne part.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
            if (!_busy) ...[
              TextField(
                key: const ValueKey('followup-address'),
                controller: _address,
                enabled: widget.canEdit,
                maxLength: 200,
                decoration: const InputDecoration(
                  labelText: 'Adresse postale de Movi-K',
                  hintText: '123 rue Principale, Granby (Québec) J2G 0A0',
                  isDense: true,
                  counterText: '',
                ),
              ),
              SwitchListTile(
                key: const ValueKey('followup-enabled'),
                contentPadding: EdgeInsets.zero,
                title: const Text('Envoyer les relances'),
                value: _enabled,
                onChanged: widget.canEdit
                    ? (v) => setState(() => _enabled = v)
                    : null,
              ),
              Text(
                _ready
                    ? 'État : les relances partent.'
                    : 'État : aucune relance ne part.',
                key: const ValueKey('followup-state'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _ready ? AppColors.success : theme.colorScheme.error,
                ),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  key: const ValueKey('followup-error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (_saved != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _saved!,
                  key: const ValueKey('followup-saved'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            if (widget.canEdit && !_busy)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton(
                  key: const ValueKey('followup-save'),
                  onPressed: _save,
                  child: const Text('Enregistrer'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class AcquisitionReportCard extends StatefulWidget {
  const AcquisitionReportCard({super.key, this.api});
  final ProspectsApi? api;

  @override
  State<AcquisitionReportCard> createState() => _AcquisitionReportCardState();
}

class _AcquisitionReportCardState extends State<AcquisitionReportCard> {
  ProspectsApi get _api => widget.api ?? _firebaseApi;
  int _days = 30;
  List<Map<String, dynamic>> _rows = const [];
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api('getAcquisitionReport', {'days': _days});
      _rows = (r['rows'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Lecture refusée.';
    } catch (_) {
      _error = 'Lecture impossible. Réessayez.';
    }
    if (mounted) setState(() => _busy = false);
  }

  int _n(Map<String, dynamic> row, String key) =>
      (row[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    DataCell count(int v) => DataCell(Text('$v'));
    return Card(
      key: const ValueKey('acquisition-card'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'D’où viennent les prospects',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                DropdownButton<int>(
                  key: const ValueKey('acquisition-days'),
                  value: _days,
                  items: const [
                    DropdownMenuItem(value: 7, child: Text('7 jours')),
                    DropdownMenuItem(value: 30, child: Text('30 jours')),
                    DropdownMenuItem(value: 90, child: Text('90 jours')),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) {
                          if (v == null || v == _days) return;
                          setState(() {
                            _days = v;
                            _busy = true;
                            _error = null;
                          });
                          _load();
                        },
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'La source est notée à la première visite de la personne, puis collée à son compte. '
              'Comptes : inscrits dans la période. Prix et réservations : clients qui ont demandé un prix ou réservé dans la période. '
              'Pour distinguer une publicité Facebook d’une simple publication, ajoutez à l’adresse de l’annonce : '
              '?utm_source=facebook&utm_medium=cpc&utm_campaign=nom-de-la-campagne',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
            if (_error != null)
              Text(
                _error!,
                key: const ValueKey('acquisition-error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            if (!_busy && _error == null && _rows.isEmpty)
              const Text(
                'Rien à afficher pour cette période.',
                key: ValueKey('acquisition-empty'),
              ),
            if (!_busy && _rows.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  key: const ValueKey('acquisition-table'),
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('Source')),
                    DataColumn(label: Text('Comptes'), numeric: true),
                    DataColumn(label: Text('Prix demandés'), numeric: true),
                    DataColumn(label: Text('Réservations'), numeric: true),
                    DataColumn(label: Text('Chauffeurs'), numeric: true),
                  ],
                  rows: [
                    for (final row in _rows)
                      DataRow(
                        cells: [
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  acquisitionChannelLabel(
                                    '${row['channel'] ?? ''}',
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if ('${row['label'] ?? ''}'.isNotEmpty)
                                  Text(
                                    '${row['label']}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                          count(_n(row, 'accounts')),
                          count(_n(row, 'priced')),
                          count(_n(row, 'booked')),
                          count(_n(row, 'drivers')),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
