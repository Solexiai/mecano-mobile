import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/services/address/address_suggestion.dart';
import 'package:movik_connect/services/delivery_request_draft.dart';

const _testDraft = DeliveryRequestDraft(
  category: 'cat_furniture',
  description: 'Sofa',
  quantity: 1,
  needsStairs: false,
  needsSecondHandler: false,
  isHeavyItem: false,
  isBulkyItem: false,
  pickup: null,
  dropoff: null,
  contactInstructions: '',
  accessDetails: '',
  vehicleCategory: 'cargo_van',
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('delivery guest draft round-trips all fields locally', () async {
    const pickup = ResolvedAddress(
      placeId: 'pickup-place',
      formattedAddress: '100 Rue Principale, Granby, QC',
      lat: 45.401,
      lng: -72.733,
      streetNumber: '100',
      street: 'Rue Principale',
      city: 'Granby',
      region: 'QC',
      postalCode: 'J2G 2V2',
      country: 'CA',
    );
    const dropoff = ResolvedAddress(
      placeId: 'dropoff-place',
      formattedAddress: '200 Rue Principale, Granby, QC',
      lat: 45.405,
      lng: -72.720,
      city: 'Granby',
      region: 'QC',
      country: 'CA',
    );

    const original = DeliveryRequestDraft(
      category: 'cat_furniture',
      description: 'Canapé trois places',
      quantity: 2,
      needsStairs: true,
      needsSecondHandler: true,
      isHeavyItem: false,
      isBulkyItem: true,
      pickup: pickup,
      dropoff: dropoff,
      contactInstructions: 'Appeler à l’arrivée',
      accessDetails: 'Escalier extérieur',
      vehicleCategory: 'cargo_van',
    );

    await original.save();
    final restored = await DeliveryRequestDraft.load();

    expect(restored, isNotNull);
    expect(restored!.category, 'cat_furniture');
    expect(restored.description, 'Canapé trois places');
    expect(restored.quantity, 2);
    expect(restored.needsStairs, isTrue);
    expect(restored.needsSecondHandler, isTrue);
    expect(restored.isBulkyItem, isTrue);
    expect(restored.pickup?.formattedAddress, '100 Rue Principale, Granby, QC');
    expect(restored.pickup?.city, 'Granby');
    expect(restored.dropoff?.placeId, 'dropoff-place');
    expect(restored.contactInstructions, 'Appeler à l’arrivée');
    expect(restored.accessDetails, 'Escalier extérieur');
    expect(restored.vehicleCategory, 'cargo_van');

    await DeliveryRequestDraft.clear();
    expect(await DeliveryRequestDraft.load(), isNull);
  });

  test('draft expires after 24 hours', () async {
    final savedAt = DateTime.utc(2026, 10, 1);
    await _testDraft.save(now: savedAt);

    expect(
      await DeliveryRequestDraft.load(
        now: savedAt.add(DeliveryRequestDraft.maxAge),
      ),
      isNotNull,
    );
    expect(
      await DeliveryRequestDraft.load(
        now: savedAt.add(
          DeliveryRequestDraft.maxAge + const Duration(seconds: 1),
        ),
      ),
      isNull,
    );
  });

  test('signed-in draft is isolated to its Firebase UID', () async {
    await _testDraft.save(uid: 'customer-a');

    expect(await DeliveryRequestDraft.load(uid: 'customer-b'), isNull);
    expect(await DeliveryRequestDraft.load(uid: 'customer-a'), isNotNull);
  });

  test('guest draft can be claimed only during a fresh auth handoff', () async {
    final savedAt = DateTime.utc(2026, 10, 1);
    await _testDraft.save(now: savedAt);
    await DeliveryRequestDraft.beginAuthHandoff(
      now: savedAt.add(const Duration(minutes: 1)),
    );

    expect(
      await DeliveryRequestDraft.load(
        uid: 'customer-a',
        now: savedAt.add(const Duration(minutes: 2)),
      ),
      isNotNull,
    );
    expect(
      await DeliveryRequestDraft.load(
        uid: 'customer-b',
        now: savedAt.add(const Duration(minutes: 3)),
      ),
      isNull,
    );
  });

  test(
    'expired auth handoff cannot expose the guest draft to an account',
    () async {
      final savedAt = DateTime.utc(2026, 10, 1);
      await _testDraft.save(now: savedAt);
      await DeliveryRequestDraft.beginAuthHandoff(now: savedAt);

      expect(
        await DeliveryRequestDraft.load(
          uid: 'customer-a',
          now: savedAt.add(
            DeliveryRequestDraft.authHandoffMaxAge + const Duration(seconds: 1),
          ),
        ),
        isNull,
      );
    },
  );

  test('invalid stored draft fails closed instead of crashing', () async {
    SharedPreferences.setMockInitialValues({
      DeliveryRequestDraft.storageKey: '{not-json',
    });

    expect(await DeliveryRequestDraft.load(), isNull);
  });
}
