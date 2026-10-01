import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/services/address/address_suggestion.dart';
import 'package:movik_connect/services/delivery_request_draft.dart';

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

  test('invalid stored draft fails closed instead of crashing', () async {
    SharedPreferences.setMockInitialValues({
      DeliveryRequestDraft.storageKey: '{not-json',
    });

    expect(await DeliveryRequestDraft.load(), isNull);
  });
}
