// Mise à jour dans l'app (2026-11-06). Réglage de la version minimale de
// l'application Android : en dessous, l'app force la mise à jour (écran
// Google « Mettre à jour », impossible de continuer sans) ; au-dessus, les
// nouvelles versions se téléchargent en arrière-plan avec un bandeau
// « Redémarrer ». Document public `app_config/app_versions`, écrit par la
// Cloud Function `updateAppVersionPolicy` (admin, journalisé).
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/app_colors.dart';
import '../../../../services/app_update/app_update_checker.dart';

typedef AppVersionPolicyApi =
    Future<Map<String, dynamic>> Function(Map<String, dynamic> data);

Future<Map<String, dynamic>> _firebaseApi(Map<String, dynamic> data) async {
  final result = await FirebaseFunctions.instance
      .httpsCallable('updateAppVersionPolicy')
      .call(data);
  return Map<String, dynamic>.from(result.data as Map);
}

class AppVersionPolicyCard extends StatefulWidget {
  const AppVersionPolicyCard({
    super.key,
    this.api,
    this.canEdit = true,
    this.installedVersion,
  });
  final AppVersionPolicyApi? api;
  final bool canEdit;

  /// Test seam : « 1.0.0 (10) » ; null = lu sur l'appareil.
  final Future<String?> Function()? installedVersion;

  @override
  State<AppVersionPolicyCard> createState() => _AppVersionPolicyCardState();
}

class _AppVersionPolicyCardState extends State<AppVersionPolicyCard> {
  AppVersionPolicyApi get _api => widget.api ?? _firebaseApi;
  final _min = TextEditingController();
  final _note = TextEditingController();
  int _savedMin = 0;
  String? _installed;
  bool _busy = true;
  String? _error, _saved;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _min.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await _api({'action': 'get'});
      _savedMin = (r['android_min_build'] as num?)?.toInt() ?? 0;
      _min.text = '$_savedMin';
      _note.text = (r['note'] as String?) ?? '';
    } on FirebaseFunctionsException catch (e) {
      _error = e.message ?? 'Lecture refusée.';
    } catch (_) {
      _error = 'Lecture impossible. Réessayez.';
    }
    _installed = await (widget.installedVersion ?? installedVersionLabel)();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _save() async {
    final value = int.tryParse(_min.text.trim());
    if (value == null || value < 0) {
      setState(() => _error = 'Entrez un numéro de build (0 = aucun minimum).');
      return;
    }
    if (value > _savedMin) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Exiger la version $value ?'),
          content: Text(
            'Tout téléphone Android qui a une version plus ancienne devra la mettre à jour '
            'avant de continuer (écran Google « Mettre à jour » au prochain démarrage). '
            'Vérifiez que la version $value est bien publiée sur Google Play, sinon tout le monde sera bloqué.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
            FilledButton(
              key: const ValueKey('app-version-confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Exiger'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _saved = null;
    });
    try {
      final r = await _api({'action': 'save', 'android_min_build': value, 'note': _note.text.trim()});
      _savedMin = (r['android_min_build'] as num?)?.toInt() ?? value;
      _saved = _savedMin == 0
          ? 'Enregistré : aucune version minimale. Les mises à jour se font en arrière-plan.'
          : 'Enregistré : la version $_savedMin est exigée dès le prochain démarrage de l’app.';
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
      key: const ValueKey('app-version-card'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.system_update, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Mise à jour de l’application Android', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Les nouvelles versions publiées sur Google Play se téléchargent en arrière-plan dans l’app, '
              'puis un bandeau « Redémarrer » apparaît. En dessous de la version minimale, la mise à jour '
              'devient obligatoire : écran Google « Mettre à jour », impossible de continuer sans. '
              'Le site movi-k.com est toujours à jour de lui-même.',
              style: TextStyle(fontSize: 12),
            ),
            if (_installed != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Cette installation : $_installed',
                  key: const ValueKey('app-version-installed'),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 12),
            if (_busy) const LinearProgressIndicator(),
            if (!_busy)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 150,
                    child: TextField(
                      key: const ValueKey('app-version-min'),
                      controller: _min,
                      enabled: widget.canEdit,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Version minimale',
                        helperText: '0 = aucune',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('app-version-note'),
                      controller: _note,
                      enabled: widget.canEdit,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Note (pour vous)',
                        hintText: 'ex. dépôt de 25 $ requis',
                        isDense: true,
                        counterText: '',
                      ),
                    ),
                  ),
                ],
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  key: const ValueKey('app-version-error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (_saved != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _saved!,
                  key: const ValueKey('app-version-saved'),
                  style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                ),
              ),
            if (widget.canEdit)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: FilledButton.icon(
                  key: const ValueKey('app-version-save'),
                  onPressed: _busy ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Enregistrer'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
