// Mise à jour dans l'app (2026-11-06). Enveloppe toute l'application (voir
// main.dart, `builder:`) et, sur Android seulement :
//   1. demande à Google Play s'il existe une version plus récente ;
//   2. lit le minimum réglé dans le Centre de commande
//      (app_config/app_versions) et le build installé ;
//   3. build < minimum  -> mise à jour IMMÉDIATE (écran Google). Si
//      l'utilisateur refuse, un écran « Mise à jour requise » bloque l'app
//      jusqu'à ce qu'il accepte ;
//      sinon               -> mise à jour SOUPLE : téléchargement en
//      arrière-plan, puis bandeau « Une nouvelle version est prête —
//      Redémarrer ».
// Nouvelle vérification au retour au premier plan, au plus toutes les
// `recheckEvery`. Sans `checker` (web, tests, Firebase absent), le widget
// rend simplement son enfant.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../l10n/app_strings.dart';
import '../providers/locale_provider.dart';
import '../services/app_update/app_update_checker.dart';
import '../services/app_update/app_version_policy.dart';

typedef InstalledBuildLoader = Future<int?> Function();

class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({
    super.key,
    required this.child,
    this.checker,
    this.loadPolicy,
    this.installedBuild,
    this.recheckEvery = const Duration(hours: 6),
  });

  final Widget child;

  /// Accès à Google Play ; null = mécanisme désactivé (web, tests).
  final AppUpdateChecker? checker;

  /// Minimum réglé par l'admin ; null = aucun minimum.
  final AppVersionPolicyLoader? loadPolicy;

  /// Build installé ; null = inconnu (jamais de blocage).
  final InstalledBuildLoader? installedBuild;

  final Duration recheckEvery;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> with WidgetsBindingObserver {
  bool _blocked = false;
  bool _downloaded = false;
  bool _dismissedBanner = false;
  bool _running = false;
  DateTime? _lastCheck;
  StreamSubscription<AppUpdateInstallStep>? _steps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _steps?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final last = _lastCheck;
    if (_blocked || last == null || DateTime.now().difference(last) >= widget.recheckEvery) {
      _run();
    }
  }

  Future<void> _run() async {
    final checker = widget.checker;
    if (checker == null || _running || !mounted) return;
    _running = true;
    _lastCheck = DateTime.now();
    try {
      AppUpdateAvailability availability;
      try {
        availability = await checker.check();
      } catch (_) {
        availability = AppUpdateAvailability.none;
      }
      if (!mounted) return;
      if (!availability.available) {
        if (_blocked) setState(() => _blocked = false);
        return;
      }

      final build = await widget.installedBuild?.call();
      final policy = await widget.loadPolicy?.call() ?? AppVersionPolicy.none;
      if (!mounted) return;
      final mustUpdate = build != null && policy.androidMinBuild > 0 && build < policy.androidMinBuild;

      if (mustUpdate) {
        await _immediate(checker, availability);
      } else if (availability.flexibleAllowed && !_downloaded) {
        await _flexible(checker);
      }
    } finally {
      _running = false;
    }
  }

  Future<void> _immediate(AppUpdateChecker checker, AppUpdateAvailability availability) async {
    var launch = AppUpdateLaunch.failed;
    if (availability.immediateAllowed) {
      try {
        launch = await checker.startImmediate();
      } catch (_) {
        launch = AppUpdateLaunch.failed;
      }
    }
    if (!mounted) return;
    // success = l'app redémarre d'elle-même ; refus ou échec = on bloque.
    setState(() => _blocked = launch != AppUpdateLaunch.success);
  }

  Future<void> _flexible(AppUpdateChecker checker) async {
    _steps ??= checker.installSteps.listen((step) {
      if (!mounted) return;
      if (step == AppUpdateInstallStep.downloaded) {
        setState(() {
          _downloaded = true;
          _dismissedBanner = false;
        });
      }
    }, onError: (_) {});
    try {
      await checker.startFlexible();
    } catch (_) {
      // Play indisponible : la mise à jour automatique du Store prendra le relais.
    }
  }

  Future<void> _retry() async {
    final checker = widget.checker;
    if (checker == null) return;
    AppUpdateAvailability availability;
    try {
      availability = await checker.check();
    } catch (_) {
      availability = AppUpdateAvailability.none;
    }
    if (!mounted) return;
    if (!availability.available) {
      setState(() => _blocked = false);
      return;
    }
    await _immediate(checker, availability);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider?>()?.locale ?? 'fr';
    String t(String key) => AppStrings.t(key, locale);
    final showBanner = _downloaded && !_dismissedBanner && !_blocked;
    if (!_blocked && !showBanner) return widget.child;
    return Stack(
      children: [
        widget.child,
        if (showBanner)
          Positioned(
            key: const ValueKey('app-update-banner'),
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Material(
                color: AppColors.primary,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t('app_update_ready_banner'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(
                        key: const ValueKey('app-update-later'),
                        onPressed: () => setState(() => _dismissedBanner = true),
                        child: Text(t('app_update_later_button'), style: const TextStyle(color: Colors.white70)),
                      ),
                      FilledButton(
                        key: const ValueKey('app-update-restart'),
                        style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
                        onPressed: () => widget.checker?.completeFlexible(),
                        child: Text(t('app_update_restart_button')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (_blocked)
          Positioned.fill(
            key: const ValueKey('app-update-required'),
            child: Material(
              color: Colors.black54,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Card(
                    margin: const EdgeInsets.all(24),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Icon(Icons.system_update, size: 48, color: AppColors.primary),
                          const SizedBox(height: 16),
                          Text(
                            t('app_update_required_title'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(t('app_update_required_body'), textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          FilledButton(
                            key: const ValueKey('app-update-required-button'),
                            onPressed: _retry,
                            child: Text(t('app_update_required_button')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
