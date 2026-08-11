// ---------------------------------------------------------------------------
// Tests unitaires — FinancialSnapshot (immutabilité)
//
// Couvre (Étape 12) : le statut 'confirmed' rend le snapshot immuable
// (isImmutable == true) alors qu'un snapshot 'pending' ne l'est pas encore.
// Ces modèles Dart sont en LECTURE SEULE (aucune logique d'écriture) : le
// test vérifie donc la sémantique du getter isImmutable et la stabilité de
// la sérialisation round-trip toJson/fromJson, PAS une tentative de mutation
// (Dart `final` interdit déjà toute mutation au niveau du langage — c'est la
// première ligne de défense de l'immutabilité).
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/finance/models/financial_snapshot.dart';
import 'package:movik_connect/models/enums.dart';

FinancialSnapshot _buildSnapshot({required String status, DateTime? confirmedAt}) {
  return FinancialSnapshot(
    snapshotId: 'snap_001',
    missionId: 'mission_001',
    customerId: 'customer_001',
    driverId: 'driver_001',
    pricingVersion: 'MOVIK-PRICING-001',
    missionBaseValue: 100,
    driverGrossEarnings: 85,
    driverOfferAmount: 85,
    commissionRate: 0.15,
    commissionProgram: CommissionProgramType.standard,
    minimumPlatformCommission: 5,
    maximumEffectiveCommissionRate: 0.30,
    platformCommissionAmount: 15,
    customerServiceFee: 5,
    customerFees: 0,
    customerDiscount: 0,
    customerTax: 10,
    driverBonus: 0,
    tipAmount: 0,
    driverNetMissionEarnings: 85,
    driverTotalPayout: 85,
    paymentProcessingCost: 2,
    insuranceCost: 1,
    customerTotal: 115,
    platformGrossRevenue: 20,
    contributionMargin: 17,
    createdAt: DateTime(2025, 6, 15, 10, 0, 0),
    confirmedAt: confirmedAt,
    status: status,
  );
}

void main() {
  group('FinancialSnapshot.isImmutable', () {
    test("un snapshot au statut 'pending' n'est PAS encore immuable", () {
      final snapshot = _buildSnapshot(status: 'pending');
      expect(snapshot.isImmutable, isFalse);
      expect(snapshot.confirmedAt, isNull);
    });

    test("un snapshot au statut 'confirmed' est IMMUABLE", () {
      final snapshot = _buildSnapshot(
        status: 'confirmed',
        confirmedAt: DateTime(2025, 6, 15, 10, 5, 0),
      );
      expect(snapshot.isImmutable, isTrue);
      expect(snapshot.confirmedAt, isNotNull);
    });

    test('tout autre statut inconnu est traité comme NON immuable (fail-safe)', () {
      final snapshot = _buildSnapshot(status: 'refunded');
      expect(snapshot.isImmutable, isFalse);
    });
  });

  group('FinancialSnapshot — round-trip de sérialisation (traçabilité, aucune perte de champ)', () {
    test('toJson() puis fromJson() reproduit un snapshot confirmé identique', () {
      final original = _buildSnapshot(
        status: 'confirmed',
        confirmedAt: DateTime(2025, 6, 15, 10, 5, 0),
      );

      final json = original.toJson();
      final roundTripped = FinancialSnapshot.fromJson(json);

      expect(roundTripped.snapshotId, original.snapshotId);
      expect(roundTripped.missionId, original.missionId);
      expect(roundTripped.status, original.status);
      expect(roundTripped.isImmutable, isTrue);
      expect(roundTripped.commissionProgram, original.commissionProgram);
      expect(roundTripped.driverNetMissionEarnings, closeTo(original.driverNetMissionEarnings, 1e-9));
      expect(roundTripped.customerTotal, closeTo(original.customerTotal, 1e-9));
      expect(roundTripped.confirmedAt, original.confirmedAt);
    });

    test('un snapshot pending sérialisé/désérialisé reste non-confirmé et sans confirmedAt', () {
      final original = _buildSnapshot(status: 'pending');
      final roundTripped = FinancialSnapshot.fromJson(original.toJson());

      expect(roundTripped.status, 'pending');
      expect(roundTripped.isImmutable, isFalse);
      expect(roundTripped.confirmedAt, isNull);
    });
  });
}
