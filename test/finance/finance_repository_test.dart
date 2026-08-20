// ---------------------------------------------------------------------------
// Tests unitaires — FinanceRepository (Blocs J & K)
//
// Couvre le contrat `NotConfiguredFinanceRepository` (utilisé tant qu'aucun
// projet Firebase réel n'est connecté — voir BackendLocator) pour les
// méthodes Bloc J et Bloc K : elles ne doivent JAMAIS planter et retourner
// systématiquement un flux vide/null, jamais lever d'exception.
//
// NOTE : `FirebaseFinanceRepository` (implémentation réelle) nécessite une
// instance `FirebaseFirestore` initialisée (SDK natif, pas de fake
// disponible dans ce projet) — sa couverture "client scoped" (watchPayoutsForDriver
// ne renvoie QUE les payouts du chauffeur courant, jamais ceux d'un autre)
// se fait via les tests Security Rules ciblés côté backend (voir
// functions/test/integration/securityRules.test.ts, describes "Bloc J"/"Bloc K")
// qui vérifient que le SERVEUR ne renvoie que les documents autorisés,
// contrat sur lequel `FirebaseFinanceRepository` s'appuie sans aucun
// filtrage additionnel côté client (voir en-tête du fichier source) — la
// requête `.where('driver_id', isEqualTo: driverId)` garantit déjà côté
// client qu'aucun autre chauffeur n'est demandé, et les Security Rules
// garantissent côté serveur que même une requête malveillante ne
// retournerait rien pour un driver_id qui n'est pas le sien.
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/repositories/finance_repository.dart';
import 'package:movik_connect/finance/models/payment_info.dart';
import 'package:movik_connect/finance/models/refund_info.dart';
import 'package:movik_connect/finance/models/mission_financial_balance.dart';
import 'package:movik_connect/finance/models/driver_payout_info.dart';
import 'package:movik_connect/finance/models/financial_snapshot.dart';

void main() {
  group(
    'NotConfiguredFinanceRepository — Bloc J (aucun projet Firebase connecté)',
    () {
      const repo = NotConfiguredFinanceRepository();

      test(
        'watchPaymentForMission ne plante jamais et retourne null',
        () async {
          final PaymentInfo? payment = await repo
              .watchPaymentForMission('mission_x')
              .first;
          expect(payment, isNull);
        },
      );

      test(
        'watchRefundsForMission ne plante jamais et retourne une liste vide',
        () async {
          final List<RefundInfo> refunds = await repo
              .watchRefundsForMission('mission_x')
              .first;
          expect(refunds, isEmpty);
        },
      );

      test(
        'watchMissionFinancialBalance ne plante jamais et retourne null',
        () async {
          final MissionFinancialBalance? balance = await repo
              .watchMissionFinancialBalance('mission_x')
              .first;
          expect(balance, isNull);
        },
      );
    },
  );

  group(
    'NotConfiguredFinanceRepository — Bloc K (aucun projet Firebase connecté)',
    () {
      const repo = NotConfiguredFinanceRepository();

      test(
        'watchPayoutsForDriver ne plante jamais et retourne une liste vide',
        () async {
          final List<DriverPayoutInfo> payouts = await repo
              .watchPayoutsForDriver('driver_x')
              .first;
          expect(payouts, isEmpty);
        },
      );

      test(
        'watchFinancialSnapshotsForDriver ne plante jamais et retourne une liste vide',
        () async {
          final List<FinancialSnapshot> snapshots = await repo
              .watchFinancialSnapshotsForDriver('driver_x')
              .first;
          expect(snapshots, isEmpty);
        },
      );
    },
  );
}
