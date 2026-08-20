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
import 'package:movik_connect/finance/models/dispute_info.dart';
import 'package:movik_connect/finance/models/reconciliation_report.dart';
import 'package:movik_connect/finance/models/tax_configuration.dart';
import 'package:movik_connect/finance/models/payout_policy_configuration.dart';
import 'package:movik_connect/finance/models/transaction_ledger.dart';
import 'package:movik_connect/models/enums.dart';

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

  group(
    'NotConfiguredFinanceRepository — Bloc L (UI admin finance, aucun projet Firebase connecté)',
    () {
      const repo = NotConfiguredFinanceRepository();

      // ---- 8 flux `watch*` — doivent tous retourner un flux vide/par
      // défaut, jamais planter, même sans backend configuré (l'UI admin
      // doit pouvoir afficher un état "vide" propre plutôt qu'un crash).

      test(
        'watchPayments ne plante jamais et retourne une liste vide',
        () async {
          final List<PaymentInfo> payments = await repo.watchPayments().first;
          expect(payments, isEmpty);
        },
      );

      test('watchPayments avec un filtre de statut ne plante jamais', () async {
        final List<PaymentInfo> payments = await repo
            .watchPayments(status: PaymentStatus.captured, limit: 10)
            .first;
        expect(payments, isEmpty);
      });

      test(
        'watchRefunds ne plante jamais et retourne une liste vide',
        () async {
          final List<RefundInfo> refunds = await repo.watchRefunds().first;
          expect(refunds, isEmpty);
        },
      );

      test(
        'watchDriverPayouts (vue admin) ne plante jamais et retourne une liste vide',
        () async {
          final List<DriverPayoutInfo> payouts = await repo
              .watchDriverPayouts()
              .first;
          expect(payouts, isEmpty);
        },
      );

      test(
        'watchDisputes ne plante jamais et retourne une liste vide',
        () async {
          final List<DisputeInfo> disputes = await repo.watchDisputes().first;
          expect(disputes, isEmpty);
        },
      );

      test(
        'watchLedger (vue admin, append-only) ne plante jamais et retourne une liste vide',
        () async {
          final List<LedgerEntry> entries = await repo.watchLedger().first;
          expect(entries, isEmpty);
        },
      );

      test(
        'watchReconciliationReports ne plante jamais et retourne une liste vide',
        () async {
          final List<ReconciliationReport> reports = await repo
              .watchReconciliationReports()
              .first;
          expect(reports, isEmpty);
        },
      );

      test(
        'watchTaxConfigurations ne plante jamais et retourne une liste vide',
        () async {
          final List<TaxConfiguration> configs = await repo
              .watchTaxConfigurations()
              .first;
          expect(configs, isEmpty);
        },
      );

      test(
        'watchPayoutPolicy retourne le filet de sécurité bootstrapDefault() (72h)',
        () async {
          final PayoutPolicyConfiguration policy = await repo
              .watchPayoutPolicy()
              .first;
          expect(policy.defaultHoldPeriodHours, 72);
          expect(policy.newDriverHoldPeriodHours, 72);
          expect(policy.riskyDriverHoldPeriodHours, 72);
        },
      );

      // ---- 8 actions admin — TOUTES doivent lever `UnsupportedError` sans
      // backend configuré (jamais d'écriture Firestore directe, jamais un
      // succès silencieux qui masquerait l'absence de Cloud Function).

      test('adminRefundPayment lève UnsupportedError sans backend', () {
        expect(
          () => repo.adminRefundPayment(
            paymentId: 'payment_x',
            reason: RefundReason.customerRequest,
          ),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('adminReverseDriverPayout lève UnsupportedError sans backend', () {
        expect(
          () => repo.adminReverseDriverPayout(
            payoutId: 'payout_x',
            reason: 'test reason',
          ),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('adminRunReconciliationNow lève UnsupportedError sans backend', () {
        expect(
          () => repo.adminRunReconciliationNow(
            periodStart: DateTime(2026, 8, 19),
            periodEnd: DateTime(2026, 8, 20),
          ),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test(
        'adminResolveReconciliationAnomaly lève UnsupportedError sans backend',
        () {
          expect(
            () => repo.adminResolveReconciliationAnomaly(
              reportId: 'report_x',
              anomalyIndex: 0,
              newStatus: ReconciliationAnomalyStatus.resolved,
              resolutionNotes: 'test notes',
            ),
            throwsA(isA<UnsupportedError>()),
          );
        },
      );

      test(
        'adminUpdateTaxConfiguration lève UnsupportedError sans backend',
        () {
          expect(
            () => repo.adminUpdateTaxConfiguration(
              jurisdiction: 'CA-QC',
              taxCode: 'gst',
              taxType: TaxType.gst,
              displayName: 'TPS',
              rate: 0.05,
              taxableComponents: const ['transport_fee'],
              effectiveFrom: DateTime(2026, 1, 1),
              enabled: true,
              taxRegistrationOwner: 'platform',
            ),
            throwsA(isA<UnsupportedError>()),
          );
        },
      );

      test(
        'adminUpdatePayoutPolicyConfiguration lève UnsupportedError sans backend',
        () {
          expect(
            () => repo.adminUpdatePayoutPolicyConfiguration(
              defaultHoldPeriodHours: 72,
              newDriverHoldPeriodHours: 168,
              riskyDriverHoldPeriodHours: 336,
            ),
            throwsA(isA<UnsupportedError>()),
          );
        },
      );

      test(
        'adminCreateLedgerAdjustment lève UnsupportedError sans backend',
        () {
          expect(
            () => repo.adminCreateLedgerAdjustment(
              missionId: 'mission_x',
              type: LedgerEntryType.driverAdjustment,
              amount: 10.0,
              direction: LedgerDirection.credit,
              party: LedgerParty.platform,
              sourceEvent: 'manual_admin_adjustment',
            ),
            throwsA(isA<UnsupportedError>()),
          );
        },
      );

      test('adminUpdateDisputeStatus lève UnsupportedError sans backend', () {
        expect(
          () => repo.adminUpdateDisputeStatus(
            disputeId: 'dispute_x',
            newStatus: DisputeStatus.won,
          ),
          throwsA(isA<UnsupportedError>()),
        );
      });
    },
  );
}
