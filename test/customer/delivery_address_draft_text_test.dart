import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/address/address_backend_locator.dart';
import 'package:movik_connect/services/booking/booking_draft.dart';
import 'package:movik_connect/widgets/address_autocomplete_field.dart';
import '../helpers/booking_test_harness.dart';
import '../helpers/fake_address_autocomplete_provider.dart';
import '../helpers/gps_offline_transport.dart';

Finder addressInput(int index) => find.descendant(
  of: find.byType(AddressAutocompleteField).at(index),
  matching: find.byType(TextField),
);
String addressText(WidgetTester t, int index) =>
    t.widget<TextField>(addressInput(index)).controller!.text;
Future<void> typeAddress(WidgetTester t, int index, String text) async {
  await t.ensureVisible(addressInput(index));
  await t.enterText(addressInput(index), text);
}

void cleanup(WidgetTester t) {
  addTearDown(() async {
    await disposeBooking(t);
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    expect(t.takeException(), isNull);
  });
}

void main() {
  offlineTests(() {
    late FakeAddressAutocompleteProvider provider;
    setUp(() {
      provider = FakeAddressAutocompleteProvider()..emptySuggestions = true;
      AddressBackendLocator.autocompleteProviderOverride = provider;
    });
    tearDown(() => AddressBackendLocator.autocompleteProviderOverride = null);
    for (final locale in ['fr', 'en', 'es']) {
      for (final index in [0, 1]) {
        offlineWidgetTest(
          'Q3 $locale unresolved address $index survives immediate recreation',
          (t) async {
            cleanup(t);
            t.view.physicalSize = const Size(375, 812);
            t.view.devicePixelRatio = 1;
            final key = index == 0 ? 'pickup' : 'dropoff';
            final d = testDraft()..data[key] = null;
            final store = MemoryBookingStorage(d);
            final api = TestBookingApi();
            await pumpBooking(t, storage: store, api: api, locale: locale);
            const typed = '123 Adresse fictive non résolue';
            await typeAddress(t, index, typed);
            // No debounce or server save may be required to protect local text.
            expect(store.saved!.data['${key}_text'], typed);
            expect(store.saved!.data[key], isNull);
            expect(store.saved!.stops[index]['address'], isNull);
            await disposeBooking(t);
            final searches = provider.searchCallCount;
            await pumpBooking(t, storage: store, api: api, locale: locale);
            expect(addressText(t, index), typed);
            expect(provider.searchCallCount, searches);
            final next = {
              'fr': 'Voir mon prix',
              'en': 'See my price',
              'es': 'Ver mi precio',
            }[locale]!;
            expect(
              t
                  .widget<FilledButton>(find.widgetWithText(FilledButton, next))
                  .onPressed,
              isNull,
            );
            expect(api.calls, isNot(contains('calculateDeliveryQuote')));
            expect(api.calls, isNot(contains('createDeliveryRequest')));
            expect(store.saved!.items, d.items);
          },
        );
      }
    }
    offlineWidgetTest(
      'Q3 edit resolved address invalidates quote and restores latest text',
      (t) async {
        cleanup(t);
        final store = MemoryBookingStorage(testDraft(quote: true));
        final api = TestBookingApi();
        await pumpBooking(t, storage: store, api: api);
        await typeAddress(t, 0, 'Brouillon A');
        await typeAddress(t, 0, 'Brouillon AB');
        expect(store.saved!.quote, isNull);
        expect(store.saved!.data['accepted'], false);
        expect(store.saved!.data['pickup'], isNull);
        await disposeBooking(t);
        await pumpBooking(t, storage: store, api: api);
        expect(addressText(t, 0), 'Brouillon AB');
        expect(store.saved!.quote, isNull);
      },
    );
    offlineWidgetTest('Q3 clearing raw text stays empty after recreation', (
      t,
    ) async {
      cleanup(t);
      final store = MemoryBookingStorage(testDraft()..data['pickup'] = null);
      final api = TestBookingApi();
      await pumpBooking(t, storage: store, api: api);
      await typeAddress(t, 0, 'Texte temporaire');
      await typeAddress(t, 0, '');
      expect(store.saved!.data['pickup_text'], '');
      await disposeBooking(t);
      await pumpBooking(t, storage: store, api: api);
      expect(addressText(t, 0), '');
      expect(store.saved!.data['pickup'], isNull);
    });
    offlineWidgetTest(
      'Q3 legacy resolved address wins over obsolete raw text',
      (t) async {
        cleanup(t);
        final d = testDraft()..data['pickup_text'] = 'Ancien brouillon';
        final store = MemoryBookingStorage(d);
        await pumpBooking(t, storage: store, api: TestBookingApi());
        expect(addressText(t, 0), d.data['pickup']['formatted_address']);
        expect(provider.searchCallCount, 0);
        expect(store.saved!.data['pickup'], d.data['pickup']);
      },
    );
    offlineWidgetTest(
      'Q3 selected suggestion remains resolved and subsequent edit stays unresolved',
      (t) async {
        cleanup(t);
        provider.emptySuggestions = false;
        final store = MemoryBookingStorage(testDraft()..data['pickup'] = null);
        final api = TestBookingApi();
        await pumpBooking(t, storage: store, api: api);
        await typeAndSelectAddress(t, 0, 'Lieu fictif');
        final resolved = Map<String, dynamic>.from(
          store.saved!.data['pickup'] as Map,
        );
        expect(provider.resolveCallCount, 1);
        expect(store.saved!.data['pickup_text'], resolved['formatted_address']);
        await disposeBooking(t);
        await pumpBooking(t, storage: store, api: api);
        expect(addressText(t, 0), resolved['formatted_address']);
        expect(store.saved!.data['pickup'], resolved);
        await typeAddress(t, 0, 'Autre saisie fictive');
        expect(store.saved!.data['pickup'], isNull);
        expect(store.saved!.data['pickup_text'], 'Autre saisie fictive');
      },
    );
    offlineWidgetTest(
      'Q3 draft sync carries raw text but quote stops remain unresolved',
      (t) async {
        cleanup(t);
        final d = testDraft()
          ..data['pickup'] = null
          ..data['dropoff'] = null;
        final store = MemoryBookingStorage(d), api = TestBookingApi();
        await pumpBooking(t, storage: store, api: api);
        await typeAddress(t, 0, 'Saisie ramassage fictive');
        await typeAddress(t, 1, 'Saisie livraison fictive');
        await t.pump(const Duration(seconds: 1));
        await t.pumpAndSettle();
        final i = api.calls.lastIndexOf('saveBookingDraft');
        expect(i, greaterThanOrEqualTo(0));
        final saved = api.payloads[i]['draft'] as Map;
        expect(saved['pickup_text'], 'Saisie ramassage fictive');
        expect(saved['dropoff_text'], 'Saisie livraison fictive');
        expect(saved['pickup'], isNull);
        expect(saved['dropoff'], isNull);
        expect(store.saved!.load.containsKey('pickup_text'), false);
        expect(api.calls, isNot(contains('calculateDeliveryQuote')));
      },
    );
    test(
      'Q3 raw text respects existing account storage and handoff boundaries',
      () async {
        final store = BookingDraftStorage();
        for (final uid in <String?>[null, 'q3-one', 'q3-two']) {
          await store.clear(uid);
        }
        addTearDown(() async {
          for (final uid in <String?>[null, 'q3-one', 'q3-two']) {
            await store.clear(uid);
          }
        });
        final d = testDraft()
          ..data['pickup'] = null
          ..data['pickup_text'] = 'Invité fictif';
        await store.save(d, null);
        expect(await store.load('q3-two'), isNull);
        await store.handoff();
        expect(
          (await store.load('q3-one'))!.data['pickup_text'],
          'Invité fictif',
        );
        expect(await store.load('q3-two'), isNull);
        expect(await store.load(null), isNull);
      },
    );
  });
}
