// PAY-12 (2026-10-27) : publication des conditions de réservation FINALES
// (après relecture juridique). Jusqu'ici seule la version d'essai, figée
// dans le code, pouvait être publiée (écran Pilote privé). Ici l'admin
// relit chaque texte, change la version, vérifie, puis publie. Le serveur
// (functions/src/functions/publishBookingPolicy.ts) revalide tout : une
// version déjà publiée avec un autre texte est refusée, chaque publication
// est journalisée, et toute réservation copie le texte accepté.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

typedef BookingPolicyApi =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

Future<Map<String, dynamic>> _firebaseBookingPolicyApi(
  Map<String, dynamic> data,
) async {
  final result = await FirebaseFunctions.instance
      .httpsCallable('publishBookingPolicy')
      .call(data);
  return Map<String, dynamic>.from(result.data as Map);
}

const _languages = ['fr', 'en', 'es'];
const _documents = [
  ('booking', 'Conditions de réservation'),
  ('terms', 'Conditions générales d’utilisation'),
  ('privacy', 'Politique de confidentialité'),
];

class AdminBookingPolicyScreen extends StatefulWidget {
  const AdminBookingPolicyScreen({super.key, this.api});
  final BookingPolicyApi? api;
  @override
  State<AdminBookingPolicyScreen> createState() =>
      _AdminBookingPolicyScreenState();
}

class _AdminBookingPolicyScreenState extends State<AdminBookingPolicyScreen> {
  final _controllers = <String, TextEditingController>{};
  bool _setupEnabled = true;
  bool _busy = false;
  bool _loaded = false;
  String? _error;
  String? _notice;
  Map<String, dynamic>? _published;

  BookingPolicyApi get _api => widget.api ?? _firebaseBookingPolicyApi;

  TextEditingController _c(String key) =>
      _controllers.putIfAbsent(key, TextEditingController.new);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final state = await _api({'action': 'get'});
      final published = state['published'] as Map?;
      final source = (published ?? state['starter']) as Map?;
      if (source != null) _fill(Map<String, dynamic>.from(source));
      if (mounted) {
        setState(() {
          _published = published == null
              ? null
              : Map<String, dynamic>.from(published);
          _loaded = true;
        });
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Opération refusée.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Chargement impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fill(Map<String, dynamic> p) {
    String text(dynamic v) => v is String ? v : '';
    _c('version').text = text(p['version']);
    _c('approval_reference').text = text(p['approval_reference']);
    _setupEnabled = p['setup_enabled'] != false;
    for (final field in ['cancellation_text', 'payment_text']) {
      final localized = p[field] as Map? ?? {};
      for (final lang in _languages) {
        _c('$field.$lang').text = text(localized[lang]);
      }
    }
    final documents = p['documents'] as Map? ?? {};
    for (final (key, _) in _documents) {
      final d = documents[key] as Map? ?? {};
      _c('$key.version').text = text(d['version']);
      _c('$key.url').text = text(d['url']);
      final content = d['content'] as Map? ?? {};
      for (final lang in _languages) {
        _c('$key.content.$lang').text = text(content[lang]);
      }
    }
  }

  Map<String, String> _localized(String prefix) => {
    for (final lang in _languages)
      if (_c('$prefix.$lang').text.trim().isNotEmpty)
        lang: _c('$prefix.$lang').text.trim(),
  };

  Map<String, dynamic> _draft() => {
    'version': _c('version').text.trim(),
    'approval_reference': _c('approval_reference').text.trim(),
    'setup_enabled': _setupEnabled,
    'cancellation_text': _localized('cancellation_text'),
    'payment_text': _localized('payment_text'),
    'documents': {
      for (final (key, _) in _documents)
        key: {
          'version': _c('$key.version').text.trim(),
          'url': _c('$key.url').text.trim(),
          'content': _localized('$key.content'),
        },
    },
  };

  Future<void> _run(String action) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final result = await _api({'action': action, 'policy': _draft()});
      if (action == 'preview') {
        if (mounted) {
          setState(
            () => _notice =
                'Projet valide (version ${result['version']}). Vous pouvez publier.',
          );
        }
      } else {
        final state = await _api({'action': 'get'});
        if (mounted) {
          setState(() {
            _published = state['published'] == null
                ? null
                : Map<String, dynamic>.from(state['published'] as Map);
            _notice = result['unchanged'] == true
                ? 'Ce texte est déjà publié (version ${result['version']}) : rien à changer.'
                : 'Conditions publiées : version ${result['version']}.';
          });
        }
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Opération refusée.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Opération impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmPublish() async {
    final version = _c('version').text.trim();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publier ces conditions ?'),
        content: Text(
          'La version $version s’appliquera à toute nouvelle réservation. '
          'Les réservations déjà faites gardent le texte qu’elles ont accepté.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const ValueKey('policy-publish-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Publier'),
          ),
        ],
      ),
    );
    if (ok == true) await _run('publish');
  }

  Widget _field(
    String key,
    String label, {
    int lines = 1,
    String? helper,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: ValueKey('policy-$key'),
        controller: _c(key),
        maxLines: lines == 1 ? 1 : null,
        minLines: lines == 1 ? 1 : lines,
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          border: const OutlineInputBorder(),
          alignLabelWithHint: lines > 1,
        ),
      ),
    );
  }

  Widget _localizedFields(String prefix, String label, {int lines = 4}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field('$prefix.fr', '$label (FR)', lines: lines),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Traductions (EN, ES) — facultatives'),
          children: [
            _field('$prefix.en', '$label (EN)', lines: lines),
            _field('$prefix.es', '$label (ES)', lines: lines),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final published = _published;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Conditions de réservation')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            published == null
                ? 'Aucune condition publiée : aucune réservation ne peut être confirmée. '
                      'Le formulaire est prérempli avec la version d’essai, à relire et re-versionner.'
                : 'Publiées : version ${published['version']}'
                      '${published['trial'] == true ? ' (essai — à remplacer par la version finale)' : ''}.',
            key: const ValueKey('policy-status'),
          ),
          const SizedBox(height: 6),
          const Text(
            'Le texte accepté est copié dans chaque réservation. Tout changement de texte '
            'exige une nouvelle version ; la publication est journalisée.',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _error!,
                key: const ValueKey('policy-error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _notice!,
                key: const ValueKey('policy-notice'),
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
          if (_loaded) ...[
            const Divider(height: 32),
            _field(
              'version',
              'Version',
              helper: 'Lettres, chiffres, points et tirets (ex. 2026-11-01-1).',
            ),
            _field(
              'approval_reference',
              'Référence d’approbation',
              helper: 'Qui a relu et approuvé, et quand.',
            ),
            SwitchListTile(
              key: const ValueKey('policy-setup-enabled'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Enregistrement de carte activé'),
              subtitle: const Text(
                'Désactivé, aucune réservation ne peut être confirmée.',
              ),
              value: _setupEnabled,
              onChanged: _busy
                  ? null
                  : (v) => setState(() => _setupEnabled = v),
            ),
            const Divider(height: 32),
            Text(
              'Résumés affichés avant la confirmation',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _localizedFields('cancellation_text', 'Annulation'),
            _localizedFields('payment_text', 'Paiement'),
            for (final (key, title) in _documents) ...[
              const Divider(height: 32),
              Text(title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _field('$key.version', 'Version du document'),
              _field('$key.url', 'Adresse publique (https)'),
              _localizedFields('$key.content', 'Texte intégral', lines: 10),
            ],
            const Divider(height: 32),
            Row(
              children: [
                OutlinedButton(
                  key: const ValueKey('policy-preview'),
                  onPressed: _busy ? null : () => _run('preview'),
                  child: const Text('Vérifier'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  key: const ValueKey('policy-publish'),
                  onPressed: _busy ? null : _confirmPublish,
                  child: const Text('Publier'),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}
