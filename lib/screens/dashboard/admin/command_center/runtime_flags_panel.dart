// ADM-02 (Bloc C, PR 5 — 2026-10-28) : les quatre interrupteurs d'urgence
// (`system_config/runtime_flags`) depuis l'admin, sans passer par la console
// Firebase. Lecture directe du document (règle : admin et plus) ; écriture
// UNIQUEMENT par la Cloud Function `updateRuntimeFlags` (audit, validation).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';

/// Les 4 clés serveur, dans l'ordre d'affichage. Alignées sur
/// `ALL_RUNTIME_FLAG_KEYS` (functions/src/lib/runtimeFlags.ts).
const runtimeFlagKeys = [
  'accept_new_delivery_requests',
  'allow_driver_acceptance',
  'payments_enabled',
  'driver_payouts_enabled',
];

/// Accès testable : lecture du document, écriture par la fonction.
abstract class RuntimeFlagsApi {
  Stream<Map<String, bool>> watch();
  Future<void> update(Map<String, bool> patch);
}

class FirebaseRuntimeFlagsApi implements RuntimeFlagsApi {
  const FirebaseRuntimeFlagsApi();

  @override
  Stream<Map<String, bool>> watch() => FirebaseFirestore.instance
      .doc('system_config/runtime_flags')
      .snapshots()
      .map((snap) {
        final data = snap.data() ?? const <String, dynamic>{};
        // Clé absente = fermée (même lecture que le serveur, fail-closed).
        return {for (final k in runtimeFlagKeys) k: data[k] == true};
      });

  @override
  Future<void> update(Map<String, bool> patch) async {
    await FirebaseFunctions.instance.httpsCallable('updateRuntimeFlags').call({
      'flags': patch,
    });
  }
}

class RuntimeFlagsPanel extends StatefulWidget {
  const RuntimeFlagsPanel({super.key, this.api, this.canEdit = true});
  final RuntimeFlagsApi? api;

  /// Analyste : lecture seule (le serveur refuserait de toute façon).
  final bool canEdit;

  @override
  State<RuntimeFlagsPanel> createState() => _RuntimeFlagsPanelState();
}

class _RuntimeFlagsPanelState extends State<RuntimeFlagsPanel> {
  RuntimeFlagsApi get _api => widget.api ?? const FirebaseRuntimeFlagsApi();
  String? _busyKey;
  String? _error;

  static const _labels = <String, (String, String)>{
    'accept_new_delivery_requests': (
      'Nouvelles demandes',
      'Fermé : aucun client ne peut confirmer une nouvelle livraison. Les livraisons en cours continuent.',
    ),
    'allow_driver_acceptance': (
      'Acceptation par les chauffeurs',
      'Fermé : aucun chauffeur ne peut accepter une demande. Les livraisons déjà acceptées continuent.',
    ),
    'payments_enabled': (
      'Paiements',
      'Fermé : aucune nouvelle autorisation ni capture de carte. À fermer en premier en cas d’incident Stripe.',
    ),
    'driver_payouts_enabled': (
      'Versements groupés Movi-K',
      'Mode « Stripe direct » : sans effet, Stripe verse les chauffeurs lui-même. Ne concerne que le mode par lot.',
    ),
  };

  Future<void> _toggle(String key, bool current) async {
    final turningOn = !current;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(turningOn ? 'Ouvrir « ${_labels[key]!.$1} » ?' : 'Fermer « ${_labels[key]!.$1} » ?'),
        content: Text(
          turningOn
              ? 'Le service correspondant sera immédiatement disponible pour tous les utilisateurs '
                    '(les testeurs de la liste pilote y avaient déjà accès).'
              : 'Le service correspondant sera immédiatement coupé pour tous les utilisateurs, '
                    'sauf les testeurs de la liste pilote. L’action est journalisée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: ValueKey('flag-confirm-$key'),
            style: turningOn
                ? null
                : FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(turningOn ? 'Ouvrir' : 'Fermer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busyKey = key;
      _error = null;
    });
    try {
      await _api.update({key: turningOn});
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Modification refusée.';
    } catch (_) {
      _error = 'Modification impossible. Réessayez.';
    }
    if (mounted) setState(() => _busyKey = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return StreamBuilder<Map<String, bool>>(
      stream: _api.watch(),
      builder: (context, snapshot) {
        final flags = snapshot.data;
        final allClosed = flags != null && flags.values.every((v) => !v);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Interrupteurs d’urgence', style: theme.textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text(
                'Chaque interrupteur agit immédiatement sur tout le service, sans redéploiement. '
                'Fermé = le serveur refuse l’action, même à une application modifiée. '
                'Chaque changement est journalisé avec votre identifiant.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (snapshot.hasError)
                Text(
                  'Lecture impossible (réservée aux administrateurs).',
                  key: const ValueKey('flags-error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              if (flags == null && !snapshot.hasError) const LinearProgressIndicator(),
              if (allClosed)
                Container(
                  key: const ValueKey('flags-all-closed'),
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Tout est fermé : seuls les testeurs de la liste pilote peuvent réserver, accepter et payer. '
                    'C’est l’état normal avant le lancement.',
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    key: const ValueKey('flags-save-error'),
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              if (flags != null)
                for (final key in runtimeFlagKeys)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: SwitchListTile(
                      key: ValueKey('flag-$key'),
                      title: Text(_labels[key]!.$1),
                      subtitle: Text(_labels[key]!.$2),
                      secondary: Icon(
                        flags[key]! ? Icons.check_circle : Icons.block,
                        color: flags[key]! ? AppColors.success : AppColors.error,
                      ),
                      value: flags[key]!,
                      onChanged: widget.canEdit && _busyKey == null
                          ? (_) => _toggle(key, flags[key]!)
                          : null,
                    ),
                  ),
              if (!widget.canEdit)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Lecture seule : seul un administrateur peut changer un interrupteur.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
