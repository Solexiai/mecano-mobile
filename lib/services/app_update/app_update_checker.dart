// Mise à jour dans l'app (2026-11-06, demande de Daniel : « que tout le
// monde se mette à jour »).
//
// Android n'autorise aucune application à se réinstaller toute seule. Le
// maximum permis est l'API officielle Google Play « In-App Updates » :
//   - IMMÉDIATE : écran Google plein écran, l'utilisateur appuie une fois
//     sur « Mettre à jour », téléchargement + installation + redémarrage ;
//     impossible de continuer sans. Utilisée quand le build installé est
//     sous le minimum réglé dans le Centre de commande.
//   - SOUPLE : téléchargement en arrière-plan pendant l'utilisation, puis
//     bandeau « Redémarrer pour terminer ». Utilisée pour toute autre
//     version plus récente.
//
// Cette interface isole l'API Play pour que le widget (app_update_gate.dart)
// soit testable sans téléphone. Hors Android (web, tests), aucun checker
// n'est fourni et le mécanisme est un no-op.
import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Ce que Play sait d'une mise à jour disponible.
class AppUpdateAvailability {
  const AppUpdateAvailability({
    required this.available,
    required this.immediateAllowed,
    required this.flexibleAllowed,
    this.availableBuild,
  });

  /// Aucune mise à jour (ou Play injoignable) : rien à faire.
  static const none = AppUpdateAvailability(
    available: false,
    immediateAllowed: false,
    flexibleAllowed: false,
  );

  final bool available;
  final bool immediateAllowed;
  final bool flexibleAllowed;
  final int? availableBuild;
}

/// Résultat d'un lancement de mise à jour.
enum AppUpdateLaunch { success, userDenied, failed }

/// Étapes du téléchargement souple qui intéressent l'écran.
enum AppUpdateInstallStep { downloading, downloaded, installed, failed, other }

abstract class AppUpdateChecker {
  Future<AppUpdateAvailability> check();

  /// Lance la mise à jour immédiate (écran Google). Rend la main quand
  /// l'utilisateur a refusé ou que l'app est sur le point de redémarrer.
  Future<AppUpdateLaunch> startImmediate();

  /// Lance le téléchargement en arrière-plan.
  Future<AppUpdateLaunch> startFlexible();

  /// Installe la version téléchargée (redémarre l'app).
  Future<void> completeFlexible();

  /// Progression du téléchargement souple.
  Stream<AppUpdateInstallStep> get installSteps;
}

/// Implémentation Google Play. À n'instancier que sur Android.
class PlayAppUpdateChecker implements AppUpdateChecker {
  const PlayAppUpdateChecker();

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<AppUpdateAvailability> check() async {
    final info = await InAppUpdate.checkForUpdate();
    return AppUpdateAvailability(
      available: info.updateAvailability == UpdateAvailability.updateAvailable,
      immediateAllowed: info.immediateUpdateAllowed,
      flexibleAllowed: info.flexibleUpdateAllowed,
      availableBuild: info.availableVersionCode,
    );
  }

  static AppUpdateLaunch _launch(AppUpdateResult r) => switch (r) {
    AppUpdateResult.success => AppUpdateLaunch.success,
    AppUpdateResult.userDeniedUpdate => AppUpdateLaunch.userDenied,
    AppUpdateResult.inAppUpdateFailed => AppUpdateLaunch.failed,
  };

  @override
  Future<AppUpdateLaunch> startImmediate() async =>
      _launch(await InAppUpdate.performImmediateUpdate());

  @override
  Future<AppUpdateLaunch> startFlexible() async =>
      _launch(await InAppUpdate.startFlexibleUpdate());

  @override
  Future<void> completeFlexible() => InAppUpdate.completeFlexibleUpdate();

  @override
  Stream<AppUpdateInstallStep> get installSteps =>
      InAppUpdate.installUpdateListener.map((status) => switch (status) {
        InstallStatus.downloading => AppUpdateInstallStep.downloading,
        InstallStatus.downloaded => AppUpdateInstallStep.downloaded,
        InstallStatus.installed => AppUpdateInstallStep.installed,
        InstallStatus.failed => AppUpdateInstallStep.failed,
        _ => AppUpdateInstallStep.other,
      });
}

/// Numéro de build installé (versionCode Android), ou null si inconnu.
Future<int?> installedBuildNumber() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber);
  } catch (_) {
    return null;
  }
}

/// « 1.0.0 (10) » pour l'affichage, ou null hors plateforme.
Future<String?> installedVersionLabel() async {
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isEmpty) return null;
    return info.buildNumber.isEmpty ? info.version : '${info.version} (${info.buildNumber})';
  } catch (_) {
    return null;
  }
}
