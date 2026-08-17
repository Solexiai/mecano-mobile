// ---------------------------------------------------------------------------
// BackendLocator — fournit les implémentations de repositories à utiliser
// dans toute l'application.
//
// ÉTAT ACTUEL : tant qu'aucun projet Firebase réel n'est connecté
// (BackendBootstrap.status.isConfigured == false), ce locator retourne
// systématiquement les implémentations `NotConfigured*`, qui ne simulent
// aucune donnée et échouent proprement sur toute écriture sensible.
//
// PROCHAINE ÉTAPE (quand un projet Firebase sera connecté) : créer
// `FirebaseDriverRepository`, `FirebaseMissionRepository`,
// `FirebaseFinanceRepository`, `FirebaseLocationRepository` dans ce même
// dossier, puis les brancher ici derrière la même interface — aucun écran
// Flutter n'aura besoin d'être modifié grâce au pattern Repository.
// ---------------------------------------------------------------------------

import 'backend_bootstrap.dart';
import 'repositories/driver_repository.dart';
import 'repositories/firebase_driver_repository.dart';
import 'repositories/mission_repository.dart';
import 'repositories/finance_repository.dart';
import 'repositories/location_repository.dart';
import 'payment/payment_provider.dart';

class BackendLocator {
  static DriverRepository get driverRepository {
    if (!BackendBootstrap.status.isConfigured) {
      return const NotConfiguredDriverRepository();
    }
    return FirebaseDriverRepository();
  }

  static MissionRepository get missionRepository {
    if (!BackendBootstrap.status.isConfigured) {
      return const NotConfiguredMissionRepository();
    }
    // TODO(firebase-migration): FirebaseMissionRepository()
    return const NotConfiguredMissionRepository();
  }

  static FinanceRepository get financeRepository {
    if (!BackendBootstrap.status.isConfigured) {
      return const NotConfiguredFinanceRepository();
    }
    // TODO(firebase-migration): FirebaseFinanceRepository()
    return const NotConfiguredFinanceRepository();
  }

  static LocationRepository get locationRepository {
    if (!BackendBootstrap.status.isConfigured) {
      return const NotConfiguredLocationRepository();
    }
    // TODO(firebase-migration): FirebaseLocationRepository()
    return const NotConfiguredLocationRepository();
  }

  static PaymentProvider get paymentProvider {
    // Le PaymentProvider réel vivra TOUJOURS côté serveur (Cloud Functions).
    // Ce getter existe pour cohérence d'architecture côté client (aucune
    // clé secrète n'est jamais chargée ici).
    return const NotConfiguredPaymentProvider();
  }
}
