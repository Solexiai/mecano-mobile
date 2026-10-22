// Private pilot (2026-10-22): testers list and trial booking terms.
// The public switches stay closed; only listed accounts can book, accept,
// pay and be paid. Server side: functions/src/functions/adminPilotSetup.ts.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

typedef PilotApi =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

Future<Map<String, dynamic>> _firebasePilotApi(
  Map<String, dynamic> data,
) async {
  final result = await FirebaseFunctions.instance
      .httpsCallable('adminPilotSetup')
      .call(data);
  return Map<String, dynamic>.from(result.data as Map);
}

class AdminPilotScreen extends StatefulWidget {
  const AdminPilotScreen({super.key, this.api});
  final PilotApi? api;
  @override
  State<AdminPilotScreen> createState() => _AdminPilotScreenState();
}

class _AdminPilotScreenState extends State<AdminPilotScreen> {
  final _email = TextEditingController();
  Map<String, dynamic>? _state;
  bool _busy = false;
  String? _error;

  PilotApi get _api => widget.api ?? _firebasePilotApi;

  @override
  void initState() {
    super.initState();
    _run({'action': 'get'});
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _run(Map<String, dynamic> data) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (data['action'] != 'get') await _api(data);
      final state = await _api({'action': 'get'});
      if (mounted) setState(() => _state = state);
      if (data['action'] == 'addTester') _email.clear();
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Opération refusée.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Opération impossible. Réessayez.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final testers = (state?['testers'] as List? ?? [])
        .map((t) => Map<String, dynamic>.from(t as Map))
        .toList();
    final terms = Map<String, dynamic>.from(state?['terms'] as Map? ?? {});
    return Scaffold(
      appBar: AppBar(title: const Text('Pilote privé')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Les interrupteurs publics restent fermés. Seuls les comptes ci-dessous peuvent réserver, accepter une livraison, payer et recevoir un versement.',
          ),
          const SizedBox(height: 12),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _error!,
                key: const ValueKey('pilot-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (state != null) ...[
            SwitchListTile(
              key: const ValueKey('pilot-enabled'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Pilote activé'),
              subtitle: const Text(
                'Désactiver coupe l’accès de tous les testeurs d’un coup.',
              ),
              value: state['enabled'] == true,
              onChanged: _busy
                  ? null
                  : (v) => _run({'action': 'setEnabled', 'enabled': v}),
            ),
            const Divider(height: 32),
            Text(
              'Conditions de réservation',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              terms['published'] == true
                  ? 'Publiées : version ${terms['version']}${terms['trial'] == true ? ' (essai)' : ''}.'
                  : 'Non publiées : aucune réservation ne peut être confirmée.',
              key: const ValueKey('pilot-terms-status'),
            ),
            if (terms['published'] != true || terms['trial'] == true) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                key: const ValueKey('pilot-publish-terms'),
                onPressed: _busy
                    ? null
                    : () => _run({'action': 'publishTrialTerms'}),
                child: const Text('Publier les conditions d’essai'),
              ),
            ],
            const Divider(height: 32),
            Text(
              'Testeurs (${testers.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final t in testers)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t['email'] as String? ?? t['uid'] as String),
                trailing: IconButton(
                  tooltip: 'Retirer',
                  icon: const Icon(Icons.person_remove_outlined),
                  onPressed: _busy
                      ? null
                      : () => _run({'action': 'removeTester', 'uid': t['uid']}),
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('pilot-email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Courriel d’un compte existant',
                helperText:
                    'La personne doit d’abord créer son compte sur movi-k.com.',
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('pilot-add'),
              onPressed: _busy
                  ? null
                  : () => _run({
                      'action': 'addTester',
                      'email': _email.text.trim(),
                    }),
              child: const Text('Ajouter le testeur'),
            ),
          ],
        ],
      ),
    );
  }
}
