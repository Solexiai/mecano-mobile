import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/booking_test_harness.dart';

void main() {
  testWidgets('quote does not require booking policy or prepare a payment', (
    t,
  ) async {
    final draft = testDraft();
    final originalLoad = draft.load;
    final originalStops = draft.stops;
    final store = MemoryBookingStorage(draft);
    final api = TestBookingApi()..configurationAvailable = false;
    await pumpBooking(t, storage: store, api: api);
    await tapBooking(t, 'Voir mon prix');
    expect(api.calls.where((n) => n == 'calculateDeliveryQuote'), hasLength(1));
    final index = api.calls.indexOf('calculateDeliveryQuote');
    expect(api.payloads[index]['booking'], originalLoad);
    expect(api.payloads[index]['stops'], originalStops);
    expect(store.saved!.quote, api.quote);
    expect(store.saved!.quote!['customerTotal'], 123.45);
    for (final call in [
      'getBookingCardStatus',
      'startBookingCardSetup',
      'createDeliveryRequest',
    ]) {
      expect(api.calls, isNot(contains(call)));
    }
    expect(find.text('Continuer vers mes coordonnées'), findsOneWidget);
    expect(t.takeException(), isNull);
    await disposeBooking(t);
  });

  testWidgets('server pricing refusal never produces a replacement quote', (
    t,
  ) async {
    final draft = testDraft(step: 1);
    final store = MemoryBookingStorage(draft);
    final api = TestBookingApi()
      ..configurationAvailable = false
      ..quoteError = FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'SIMULATED_ZONE_MISSING',
        details: {'quote_reason': 'service_area_unconfigured'},
      );
    await pumpBooking(t, storage: store, api: api);
    await tapBooking(t, 'Calculer mon prix officiel');
    expect(api.calls, isNot(contains('reviewDeliveryLoad')));
    expect(api.calls.where((n) => n == 'calculateDeliveryQuote'), hasLength(1));
    expect(api.calls, isNot(contains('createDeliveryRequest')));
    expect(store.saved!.quote, isNull);
    expect(store.saved!.items, draft.items);
    expect(
      find.textContaining('Le calcul du prix en ligne est momentanément indisponible.'),
      findsOneWidget,
    );
    expect(
      find.text('La zone de service doit être confirmée par Movi-K.'),
      findsNothing,
    );
    expect(t.takeException(), isNull);
    await disposeBooking(t);
  });

  testWidgets('guest can sign in for quote without a booking policy', (
    t,
  ) async {
    final store = MemoryBookingStorage(testDraft(step: 1));
    final api = TestBookingApi()..configurationAvailable = false;
    await pumpBooking(
      t,
      storage: store,
      api: api,
      auth: BookingTestAuth(signed: false),
    );
    await tapBooking(t, 'Se connecter et obtenir mon prix');
    expect(find.text('AUTH_SCREEN'), findsOneWidget);
    expect(store.handoffs, 1);
    expect(store.saved!.items.first['label'], 'Canapé de test');
    expect(api.calls, isNot(contains('calculateDeliveryQuote')));
    expect(t.takeException(), isNull);
    await disposeBooking(t);
  });

  testWidgets('missing policy still prevents confirmation even with a quote', (
    t,
  ) async {
    final api = TestBookingApi()..configurationAvailable = false;
    await pumpBooking(
      t,
      storage: MemoryBookingStorage(testDraft(step: 3, quote: true)),
      api: api,
    );
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(
              FilledButton,
              'Confirmer ma demande de livraison',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(api.calls, isNot(contains('startBookingCardSetup')));
    expect(api.calls, isNot(contains('createDeliveryRequest')));
    expect(t.takeException(), isNull);
    await disposeBooking(t);
  });
}
