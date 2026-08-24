// ---------------------------------------------------------------------------
// MIS-C-08 (Phase 7, Bloc B) — mission ancienne / à données partielles.
//
// Contexte : certains documents `delivery_requests/{id}` peuvent avoir été
// créés avant l'introduction de champs plus récents (pickup_address,
// dropoff_address, distance_km, estimated_duration_minutes, timestamps
// métier par statut — Phase 4/5) et ne contiennent donc AUCUNE de ces clés.
// `DeliveryMission.fromJson` doit rester robuste face à ces documents :
// aucune exception, valeurs nullables correctement null, valeurs par défaut
// sensées pour les champs non-nullables.
//
// Ce test ne couvre volontairement PAS le rendu Flutter (`_CompletedMissionView`
// est une classe privée de `customer_tracking_screen.dart`, non testable
// isolément sans introduire un seam de test) : l'inspection de code a
// confirmé que tous les usages de champs nullables dans les écrans concernés
// (`customer_tracking_screen.dart`, `driver_active_mission_screen.dart`,
// `provider_jobs_tab.dart`, `customer_overview_tab.dart`,
// `mission_finance_section.dart`) sont déjà protégés par des gardes
// `if (x != null)` — aucun force-unwrap (`!`) non gardé n'a été trouvé.
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/models/enums.dart';

void main() {
  group('MIS-C-08 — DeliveryMission.fromJson sur document ancien/partiel', () {
    test(
      'document minimal (avant Phase 4/5) : aucune exception, defaults sains',
      () {
        // Simule un document Firestore tel qu'il aurait été écrit par une
        // TOUTE PREMIÈRE version de createDeliveryRequest, ne contenant
        // QUE les champs indispensables historiques.
        final rawOldDoc = <String, dynamic>{
          'customer_id': 'cust_legacy_001',
          'item_category_key': 'cat_furniture',
          'description': 'Ancien canapé 3 places',
          'required_vehicle_category': 'pickup_truck',
          'status': 'completed',
          'pricing_version': 'v1',
          'created_at': '2023-01-15T10:00:00.000Z',
          // Volontairement ABSENTS : driver_id, accepted_at,
          // active_quote_id, active_financial_snapshot_id,
          // driver_to_pickup_at .. completed_at, cancellation_reason,
          // proof_of_delivery_url, pickup_address, dropoff_address,
          // distance_km, estimated_duration_minutes, driver_offer_amount,
          // customer_total, customer_display_name, driver_display_name.
        };

        DeliveryMission? mission;
        expect(
          () =>
              mission = DeliveryMission.fromJson('mission_legacy_1', rawOldDoc),
          returnsNormally,
        );

        expect(mission, isNotNull);
        final m = mission!;

        // Champs requis correctement lus.
        expect(m.id, 'mission_legacy_1');
        expect(m.customerId, 'cust_legacy_001');
        expect(m.status, MissionStatus.completed);
        expect(m.requiredVehicleCategory, VehicleCategory.pickupTruck);

        // Champs nullables absents -> null, jamais une exception de cast.
        expect(m.driverId, isNull);
        expect(m.customerDisplayName, isNull);
        expect(m.driverDisplayName, isNull);
        expect(m.acceptedAt, isNull);
        expect(m.activeQuoteId, isNull);
        expect(m.activeFinancialSnapshotId, isNull);
        expect(m.driverToPickupAt, isNull);
        expect(m.arrivedAtPickupAt, isNull);
        expect(m.pickedUpAt, isNull);
        expect(m.inTransitAt, isNull);
        expect(m.arrivedAtDropoffAt, isNull);
        expect(m.completedAt, isNull);
        expect(m.cancelledAt, isNull);
        expect(m.cancellationReason, isNull);
        expect(m.proofOfDeliveryUrl, isNull);
        expect(m.pickupAddress, isNull);
        expect(m.dropoffAddress, isNull);
        expect(m.distanceKm, isNull);
        expect(m.estimatedDurationMinutes, isNull);

        // Champs non-nullables avec defaults sains (jamais de crash côté
        // affichage : `driverOfferAmount.toStringAsFixed(0)` reste valide).
        expect(m.driverOfferAmount, 0);
        expect(m.customerTotal, 0);
        expect(m.hasAssignedDriver, isFalse);
      },
    );

    test(
      'document avec status inconnu/corrompu -> repli sur draft (jamais une exception)',
      () {
        final rawDoc = <String, dynamic>{
          'customer_id': 'cust_002',
          'item_category_key': 'cat_appliance',
          'description': 'Frigo',
          'required_vehicle_category': 'valeur_inconnue_corrompue',
          'status': 'statut_qui_nexiste_plus',
          'pricing_version': 'v1',
          'created_at': null, // absent également
        };

        final mission = DeliveryMission.fromJson('mission_2', rawDoc);

        // `fromFirestoreValue` a un `orElse` défensif -> jamais d'exception,
        // repli sur une valeur par défaut connue.
        expect(mission.status, MissionStatus.draft);
        expect(mission.requiredVehicleCategory, isNotNull);
        // `created_at` absent -> repli sur `DateTime.now()`, jamais null et
        // jamais une exception de parsing.
        expect(mission.createdAt, isNotNull);
      },
    );

    test(
      'mission completed sans proofOfDeliveryUrl ni adresses -> champs '
      'exploitables par la vue "complétée" sans nécessiter de force-unwrap',
      () {
        final rawDoc = <String, dynamic>{
          'customer_id': 'cust_003',
          'item_category_key': 'cat_furniture',
          'description': 'Table',
          'required_vehicle_category': 'cargo_van',
          'status': 'completed',
          'pricing_version': 'v2',
          'created_at': '2023-06-01T08:00:00.000Z',
          'completed_at': '2023-06-01T09:30:00.000Z',
        };

        final mission = DeliveryMission.fromJson('mission_3', rawDoc);

        expect(mission.status, MissionStatus.completed);
        expect(mission.completedAt, isNotNull);
        expect(mission.proofOfDeliveryUrl, isNull);
        expect(mission.pickupAddress, isNull);
        expect(mission.dropoffAddress, isNull);
      },
    );
  });
}
