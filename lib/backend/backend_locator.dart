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

import 'package:flutter/foundation.dart';

import 'backend_bootstrap.dart';
import 'repositories/driver_repository.dart';
import 'repositories/firebase_driver_repository.dart';
import 'repositories/mission_repository.dart';
import 'repositories/firebase_mission_repository.dart';
import 'repositories/finance_repository.dart';
import 'repositories/firebase_finance_repository.dart';
import 'repositories/location_repository.dart';
import 'repositories/firebase_location_repository.dart';
import 'repositories/notification_repository.dart';
import 'repositories/firebase_notification_repository.dart';
import 'repositories/proof_upload_repository.dart';
import 'repositories/firebase_proof_upload_repository.dart';
import 'payment/payment_provider.dart';

class BackendLocator {
  // ---------------------------------------------------------------------
  // Seam de test (Phase 7, Bloc B, MIS-C-09) — permet aux widget tests
  // d'injecter un `MissionRepository` fake (ex: pour compter le nombre de
  // requêtes `createMissionFromQuote` réellement déclenchées lors d'un
  // double-tap UI) sans dépendre de Firebase/BackendBootstrap. `@visibleForTesting`
  // documente l'intention : ne JAMAIS positionner ce champ en dehors de
  // `test/`. Doit être remis à `null` après chaque test (voir `tearDown`).
  // ---------------------------------------------------------------------
  @visibleForTesting
  static MissionRepository? missionRepositoryOverride;

  // Même seam que `missionRepositoryOverride` ci-dessus, pour
  // `LocationRepository` (Phase 7, Bloc C, ACTION 3 — tests GPS refusé/
  // désactivé/échec de rapport pour `DriverLocationReporter` sans dépendre
  // de Firebase). Ne jamais positionner en dehors de `test/`.
  @visibleForTesting
  static LocationRepository? locationRepositoryOverride;

  // Même seam que ci-dessus, pour `ProofUploadRepository` (Phase 7, Bloc C —
  // "proof upload failure") : permet aux widget tests de simuler un échec
  // d'upload Firebase Storage (réseau, permission refusée, quota) sans
  // dépendre d'un vrai bucket. Ne jamais positionner en dehors de `test/`.
  @visibleForTesting
  static ProofUploadRepository? proofUploadRepositoryOverride;

  static DriverRepository get driverRepository {
    if (!BackendBootstrap.status.isConfigured) {
      return const NotConfiguredDriverRepository();
    }
    return FirebaseDriverRepository();
  }

  static MissionRepository get missionRepository {
    final override = missionRepositoryOverride;
    if (override != null) return override;
    if (!BackendBootstrap.status.isConfigured) {
      return const NotConfiguredMissionRepository();
    }
    return FirebaseMissionRepository();
  }

  static FinanceRepository get financeRepository {
    if (!BackendBootstrap.status.isConfigured) {
      return const NotConfiguredFinanceRepository();
    }
    return FirebaseFinanceRepository();
  }

  static LocationRepository get locationRepository {
    final override = locationRepositoryOverride;
    if (override != null) return override;
    if (!BackendBootstrap.status.isConfigured) {
      return const NotConfiguredLocationRepository();
    }
    return FirebaseLocationRepository();
  }

  static NotificationRepository get notificationRepository {
    if (!BackendBootstrap.status.isConfigured) {
      return const NotConfiguredNotificationRepository();
    }
    return FirebaseNotificationRepository();
  }

  static ProofUploadRepository get proofUploadRepository {
    final override = proofUploadRepositoryOverride;
    if (override != null) return override;
    if (!BackendBootstrap.status.isConfigured) {
      return const NotConfiguredProofUploadRepository();
    }
    return FirebaseProofUploadRepository();
  }

  static PaymentProvider get paymentProvider {
    // Le PaymentProvider réel vivra TOUJOURS côté serveur (Cloud Functions).
    // Ce getter existe pour cohérence d'architecture côté client (aucune
    // clé secrète n'est jamais chargée ici).
    return const NotConfiguredPaymentProvider();
  }
}
