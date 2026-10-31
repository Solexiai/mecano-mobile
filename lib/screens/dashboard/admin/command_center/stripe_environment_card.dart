// Passage au vrai argent (2026-10-30). Shows which Stripe environment the
// production functions run on (test or live), the drivers whose payout
// account still belongs to the other environment, and the payments still
// open there. One button archives those accounts so each driver redoes the
// Stripe setup in the active environment. Server: adminSpecialConditions'
// sibling `adminStripeEnvironment`. No key or secret ever reaches the app.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';

typedef StripeEnvironmentApi =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

Future<Map<String, dynamic>> _firebaseApi(Map<String, dynamic> data) async {
  final result = await FirebaseFunctions.instance
      .httpsCallable('adminStripeEnvironment')
      .call(data);
  return Map<String, dynamic>.from(result.data as Map);
}

class StripeEnvironmentCard extends StatefulWidget {
  const StripeEnvironmentCard({super.key, this.api, this.canEdit = true});
  final StripeEnvironmentApi? api;
  final bool canEdit;
  @override
  State<StripeEnvironmentCard> createState() => _StripeEnvironmentCardState();
}

class _StripeEnvironmentCardState extends State<StripeEnvironmentCard> {
  StripeEnvironmentApi get _api => widget.api ?? _firebaseApi;
  Map<String, dynamic>? _status;
  bool _busy = true;
  String? _error, _done;

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
      _status = await _api({'action': 'get'});
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Lecture refusée.';
    } catch (_) {
      _error = 'Lecture impossible. Réessayez.';
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _archive() async {
    final count = (_status?['stale_drivers'] as List?)?.length ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archiver les anciens comptes de versement ?'),
        content: Text(
          '$count chauffeur(s) devront refaire leur inscription Stripe (pièce d’identité, compte bancaire) '
          'dans le mode actuel avant d’accepter une livraison. Rien n’est supprimé chez Stripe ; '
          'l’ancien compte reste dans le dossier du chauffeur. L’action est journalisée.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            key: const ValueKey('stripe-archive-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archiver'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _done = null;
    });
    try {
      final r = await _api({'action': 'archive_stale_driver_accounts'});
      _done = '${r['archived']} compte(s) archivé(s). Les chauffeurs voient maintenant « Configurer les versements ».';
      _status = await _api({'action': 'get'});
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Action refusée.';
    } catch (_) {
      _error = 'Action impossible. Réessayez.';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    final live = s?['environment'] == 'live';
    final configured = s?['configured'] == true;
    final stale = (s?['stale_drivers'] as List?) ?? const [];
    final openOther = (s?['open_payments_other_environment'] as List?) ?? const [];
    final color = !configured ? AppColors.textSecondary : (live ? const Color(0xFF1F6B3A) : const Color(0xFFB85E10));
    return Card(
      key: const ValueKey('stripe-environment'),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: color, width: 2)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Paiements Stripe', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                if (s != null)
                  Container(
                    key: const ValueKey('stripe-environment-badge'),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      !configured ? 'NON CONFIGURÉ' : (live ? 'VRAI ARGENT' : 'MODE TEST'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                    ),
                  ),
                IconButton(
                  key: const ValueKey('stripe-environment-refresh'),
                  tooltip: 'Actualiser',
                  onPressed: _busy ? null : _load,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              s == null
                  ? 'Lecture en cours…'
                  : !configured
                  ? 'Aucune clé Stripe sur le serveur : aucun paiement possible.'
                  : live
                  ? 'Les cartes sont réellement débitées et les chauffeurs réellement versés. '
                      'Passer en mode test : remettre les 3 secrets test et redéployer les fonctions.'
                  : 'Aucune vraie carte n’est débitée. Passer au vrai argent : les 3 secrets Stripe live, '
                      'puis redéployer les fonctions (procédure « bascule-stripe-live »).',
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            if (_busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, key: const ValueKey('stripe-environment-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            if (s != null && configured) ...[
              const SizedBox(height: 10),
              Text(
                openOther.isEmpty
                    ? 'Aucun paiement de l’autre mode encore ouvert.'
                    : '${openOther.length} paiement(s) de l’autre mode encore ouvert(s) (livraison acceptée, pas encore '
                        'livrée). Le serveur refusera de les encaisser : terminer ou annuler ces missions.',
                key: const ValueKey('stripe-open-payments'),
                style: TextStyle(fontWeight: openOther.isEmpty ? FontWeight.w400 : FontWeight.w700,
                    color: openOther.isEmpty ? null : AppColors.error),
              ),
              const SizedBox(height: 6),
              Text(
                stale.isEmpty
                    ? 'Tous les comptes de versement des chauffeurs sont du mode actuel.'
                    : '${stale.length} chauffeur(s) ont un compte de versement de l’autre mode : '
                        '${stale.map((d) => (d as Map)['name'] ?? (d)['uid']).join(', ')}. '
                        'Ils ne peuvent pas accepter de livraison tant que leur inscription Stripe n’est pas refaite.',
                key: const ValueKey('stripe-stale-drivers'),
                style: TextStyle(fontWeight: stale.isEmpty ? FontWeight.w400 : FontWeight.w700),
              ),
              if (stale.isNotEmpty && widget.canEdit)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: FilledButton.icon(
                      key: const ValueKey('stripe-archive'),
                      onPressed: _busy ? null : _archive,
                      icon: const Icon(Icons.archive_outlined),
                      label: const Text('Archiver ces comptes et demander une nouvelle inscription'),
                    ),
                  ),
                ),
              if (_done != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_done!, key: const ValueKey('stripe-archive-done')),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
