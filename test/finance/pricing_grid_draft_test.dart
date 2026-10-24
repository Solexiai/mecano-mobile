// Brouillon de la grille de tarifs admin : lecture d'une version publiée et
// corps envoyé au serveur (taxes jamais envoyées, valeurs non éditables
// recopiées).

import 'package:flutter_test/flutter_test.dart';

import 'package:movik_connect/finance/models/pricing_grid_admin.dart';
import 'package:movik_connect/finance/models/pricing_grid_draft.dart';

Map<String, dynamic> _version() => {
  'pricing_version': 'MOVIK-PILOT-20261016-001',
  'tax_rate': 0.14975,
  'vehicle_rules': [
    for (final c in ['pickupTruck', 'cargo_van', 'cube_truck'])
      {
        'category': c,
        'base_fare': 20,
        'rate_per_km': 1.5,
        'rate_per_minute': 0.3,
        'minimum_charge': 25,
      },
    {
      'category': 'car',
      'base_fare': 10,
      'rate_per_km': 1,
      'rate_per_minute': 0.2,
      'minimum_charge': 15,
    },
  ],
  'handling_fees': {
    'loading_fee': 0,
    'unloading_fee': 0,
    'heavy_item_fee': 10,
    'bulky_item_fee': 0,
    'stairs_fee': 15,
    'no_elevator_fee': 0,
    'second_handler_fee': 20,
    'special_equipment_fee': 0,
  },
  'waiting_fee': {'free_waiting_minutes': 10, 'waiting_rate_per_minute': 0.5},
  'additional_stop_fee': {'fee_per_stop': 5},
  'surcharges': [
    {'id': 'evening', 'mode': 'percentage', 'value': 0.1, 'enabled': false},
  ],
  'customer_service_fee': {'service_fee_rate': 0.05, 'minimum_service_fee': 2},
  'commission': {
    'standard_commission_rate': 0.15,
    'minimum_platform_commission': 0,
    'maximum_effective_commission_rate': 1,
  },
  'tip_policy': {'driver_tip_percentage': 100},
  'quote_config': {'quote_validity_minutes': 15},
};

void main() {
  test('lit la version active et garde les noms de catégorie stockés', () {
    final draft = PricingGridDraft.fromVersion(_version());
    expect(draft.basedOnVersion, 'MOVIK-PILOT-20261016-001');
    expect(draft.pilotCategoryNames, ['pickupTruck', 'cargo_van', 'cube_truck']);
    expect(draft.baseFare, 20);
    expect(draft.ratePerKm, 1.5);
    expect(draft.commissionRate, 0.15);
    expect(draft.serviceFeeRate, 0.05);
    expect(draft.stairsFee, 15);
    expect(draft.taxRate, 0.14975);
    // Sans mission_fee_policy : frais par défaut du 23 octobre 2026.
    expect(draft.feeTotalMinor, 3000);
    expect(draft.feeDriverMinor, 2500);
    expect(draft.feePlatformMinor, 500);
  });

  test('le corps serveur applique un seul tarif aux véhicules du pilote', () {
    final draft = PricingGridDraft.fromVersion(_version())
      ..ratePerKm = 1.75
      ..feeTotalMinor = 4000
      ..feeDriverMinor = 3200;
    final config = draft.toServerConfig();
    final rules = (config['vehicle_rules'] as List).cast<Map<String, dynamic>>();
    expect(rules, hasLength(4));
    for (final rule in rules.take(3)) {
      expect(rule['rate_per_km'], 1.75);
    }
    // Véhicule hors pilote recopié tel quel.
    expect(rules.last['category'], 'car');
    expect(rules.last['rate_per_km'], 1);
    expect(config['mission_fee_policy'], {
      'total_minor': 4000,
      'driver_minor': 3200,
      'platform_minor': 800,
    });
    // Taxes et pourboires ne sont jamais envoyés.
    expect(config.containsKey('tax_rate'), isFalse);
    expect(config.containsKey('tip_policy'), isFalse);
    // Valeurs non éditables recopiées.
    expect((config['handling_fees'] as Map)['heavy_item_fee'], 10);
    expect((config['surcharges'] as List).single['id'], 'evening');
  });

  test('ajoute les véhicules du pilote manquants', () {
    final version = _version()
      ..['vehicle_rules'] = [
        {
          'category': 'pickup_truck',
          'base_fare': 20,
          'rate_per_km': 1.5,
          'rate_per_minute': 0.3,
          'minimum_charge': 25,
        },
      ];
    final draft = PricingGridDraft.fromVersion(version);
    expect(draft.pilotCategoryNames, kPilotPricingCategories);
  });

  test("l'empreinte change avec les valeurs et la copie est identique", () {
    final original = PricingGridDraft.fromVersion(_version());
    final copy = original.copy();
    expect(copy.fingerprint, original.fingerprint);
    expect(copy.feeDiffersFrom(original), isFalse);
    copy.minimumCharge = 30;
    expect(copy.fingerprint, isNot(original.fingerprint));
    copy.feeTotalMinor = 3500;
    expect(copy.feeDiffersFrom(original), isTrue);
  });

  test('normalise les catégories comme le serveur', () {
    expect(normalizeVehicleCategory('pickupTruck'), 'pickup_truck');
    expect(normalizeVehicleCategory('cargo-van'), 'cargo_van');
    expect(normalizeVehicleCategory(' Cube Truck '), 'cube_truck');
  });

  test('lit le résultat du simulateur', () {
    final result = PricingPreviewResult.fromJson(
      callableMap({
        'activePricingVersion': 'V1',
        'errors': ['Commission : trop élevée.'],
        'rows': [
          {
            'id': 'short',
            'current': {'customer_total_minor': 4250, 'driver_minor': 3613},
            'draft': null,
          },
        ],
      }),
    );
    expect(result.activeVersion, 'V1');
    expect(result.errors, ['Commission : trop élevée.']);
    expect(result.rows.single.current!.customerTotalMinor, 4250);
    expect(result.rows.single.draft, isNull);
  });
}
