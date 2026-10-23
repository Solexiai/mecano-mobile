import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/address/address_backend_locator.dart';
import 'package:movik_connect/widgets/address_autocomplete_field.dart';
import '../helpers/booking_test_harness.dart';
import '../helpers/fake_address_autocomplete_provider.dart';

void main() {
  late FakeAddressAutocompleteProvider provider;
  setUp(() {
    provider = FakeAddressAutocompleteProvider();
    AddressBackendLocator.autocompleteProviderOverride = provider;
  });
  tearDown(() => AddressBackendLocator.autocompleteProviderOverride = null);
  testWidgets('No editable latitude or longitude fields', (t) async {
    await pumpBooking(
      t,
      storage: MemoryBookingStorage(testDraft()..part = 1),
      api: TestBookingApi(),
    );
    expect(find.textContaining('Latitude'), findsNothing);
    expect(find.textContaining('Longitude'), findsNothing);
    expect(find.byType(AddressAutocompleteField), findsNWidgets(2));
    await disposeBooking(t);
  });
  testWidgets(
    'Both real selections preserve independent coordinates, city and postal code in server quote',
    (t) async {
      final store = MemoryBookingStorage(testDraft()..part = 1);
      final api = TestBookingApi();
      await pumpBooking(t, storage: store, api: api);
      await typeAndSelectAddress(t, 0, '123 test pickup');
      await typeAndSelectAddress(t, 1, '456 test dropoff');
      await goToBookingPrice(t);
      final index = api.calls.indexOf('calculateDeliveryQuote');
      expect(index, greaterThanOrEqualTo(0));
      final stops = api.payloads[index]['stops'] as List;
      expect(stops[0]['address']['lat'], isA<double>());
      expect(stops[0]['address']['lat'], isNot(stops[1]['address']['lat']));
      for (final stop in stops) {
        expect(stop['address']['city'], 'FakeVille');
        expect(stop['address']['postal_code'], 'H0H 0H0');
        expect(stop['address']['lat'], isNot(1));
        expect(stop['address']['line1'], isA<String>());
      }
      expect(find.text('123,45\u00a0\$ CA'), findsOneWidget);
      await disposeBooking(t);
    },
  );
  testWidgets(
    'Editing a restored address immediately invalidates it and the quote',
    (t) async {
      final store = MemoryBookingStorage(testDraft(quote: true)..part = 1);
      await pumpBooking(t, storage: store, api: TestBookingApi());
      final field = find.descendant(
        of: find.byType(AddressAutocompleteField).first,
        matching: find.byType(TextField),
      );
      await t.ensureVisible(field);
      await t.enterText(field, 'changed');
      await t.pumpAndSettle();
      expect(store.saved!.data['pickup'], isNull);
      expect(store.saved!.quote, isNull);
      expect(
        t
            .widget<FilledButton>(
              find.byKey(const ValueKey('booking-next-where')),
            )
            .onPressed,
        isNull,
      );
      await disposeBooking(t);
    },
  );
  testWidgets('Unresolved destination cannot advance', (t) async {
    final d = testDraft()
      ..part = 1
      ..data['dropoff'] = null;
    await pumpBooking(
      t,
      storage: MemoryBookingStorage(d),
      api: TestBookingApi(),
    );
    expect(
      t
          .widget<FilledButton>(
            find.byKey(const ValueKey('booking-next-where')),
          )
          .onPressed,
      isNull,
    );
    await disposeBooking(t);
  });
  for (final failure in ['search', 'resolve', 'empty']) {
    testWidgets(
      'Address provider $failure failure never creates placeholder coordinates',
      (t) async {
        provider.searchUnavailable = failure == 'search';
        provider.resolveUnavailable = failure == 'resolve';
        provider.emptySuggestions = failure == 'empty';
        final store = MemoryBookingStorage(
          testDraft()
            ..part = 1
            ..data['pickup'] = null,
        );
        final api = TestBookingApi();
        await pumpBooking(t, storage: store, api: api);
        final f = find.descendant(
          of: find.byType(AddressAutocompleteField).first,
          matching: find.byType(TextField),
        );
        await t.ensureVisible(f);
        await t.enterText(f, 'unavailable address');
        await t.pump(const Duration(milliseconds: 500));
        await t.pumpAndSettle();
        if (failure == 'resolve') {
          final tile = find
              .descendant(
                of: find.byType(AddressAutocompleteField).first,
                matching: find.byType(ListTile),
              )
              .first;
          await t.ensureVisible(tile);
          await t.tap(tile);
          await t.pumpAndSettle();
        }
        expect(store.saved!.data['pickup'], isNull);
        expect(api.calls, isNot(contains('calculateDeliveryQuote')));
        expect(t.takeException(), isNull);
        await disposeBooking(t);
      },
    );
  }
  for (final locale in ['fr', 'en', 'es']) {
    testWidgets('Address labels and the step header are translated in $locale', (
      t,
    ) async {
      await pumpBooking(
        t,
        storage: MemoryBookingStorage(testDraft()..part = 1),
        api: TestBookingApi(),
        locale: locale,
      );
      final fields = t.widgetList<AddressAutocompleteField>(
        find.byType(AddressAutocompleteField),
      );
      expect(
        fields.first.label,
        {
          'fr': 'On le prend ici',
          'en': 'We pick it up here',
          'es': 'Lo recogemos aquí',
        }[locale],
      );
      expect(
        find.text(
          {
            'fr': 'Étape 2 sur 7',
            'en': 'Step 2 of 7',
            'es': 'Paso 2 de 7',
          }[locale]!,
        ),
        findsOneWidget,
      );
      await disposeBooking(t);
    });
  }
  testWidgets(
    'Server refusal directs to details and never fabricates an official quote',
    (t) async {
      final api = TestBookingApi()
        ..quoteError = FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'Synthetic refusal',
          details: {'quote_reason': 'dimensions_unknown'},
        );
      await pumpBooking(
        t,
        storage: MemoryBookingStorage(testDraft(step: 1)),
        api: api,
      );
      await tapBooking(t, 'Calculer mon prix officiel');
      expect(
        find.textContaining('Complétez les trois dimensions'),
        findsOneWidget,
      );
      expect(api.calls, contains('calculateDeliveryQuote'));
      expect(find.text('123,45\u00a0\$ CA'), findsNothing);
      await disposeBooking(t);
    },
  );
}
