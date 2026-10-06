import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/booking_test_harness.dart';

void main() {
  for (final code in ['unavailable', 'internal']) {
    testWidgets(
      'Quote $code error is recoverable and does not expose internals',
      (t) async {
        final api = TestBookingApi()
          ..quoteError = FirebaseFunctionsException(
            code: code,
            message: 'SECRET_STACK_TRACE',
          );
        final store = MemoryBookingStorage(testDraft(step: 1));
        await pumpBooking(t, storage: store, api: api);
        await tapBooking(t, 'Calculer mon devis officiel');
        expect(find.textContaining('SECRET_STACK_TRACE'), findsNothing);
        expect(store.saved!.items.first['label'], 'Canapé de test');
        api.quoteError = null;
        await tapBooking(t, 'Calculer mon devis officiel');
        expect(find.text('123.45 CAD'), findsOneWidget);
        await disposeBooking(t);
      },
    );
  }
  testWidgets('Network error during confirmation keeps draft for retry', (
    t,
  ) async {
    final api = TestBookingApi()..createError = StateError('raw-network-error');
    final store = MemoryBookingStorage(testDraft(step: 3, quote: true));
    await pumpBooking(t, storage: store, api: api);
    await tapBooking(t, 'Confirmer ma demande de livraison');
    expect(find.textContaining('raw-network-error'), findsNothing);
    expect(store.saved!.data['missionId'], isNull);
    expect(store.saved!.quote!['quoteId'], 'test_quote');
    api.createError = null;
    await tapBooking(t, 'Confirmer ma demande de livraison');
    expect(store.saved!.data['missionId'], 'test_mission');
    await disposeBooking(t);
  });
  testWidgets('Expired quote keeps objects and requires server repricing', (
    t,
  ) async {
    final api = TestBookingApi();
    api.quote['expiresAtMillis'] = 1;
    final store = MemoryBookingStorage(testDraft(step: 3, quote: true));
    await pumpBooking(t, storage: store, api: api);
    expect(find.textContaining('Ce devis a expiré'), findsOneWidget);
    expect(store.saved!.items, isNotEmpty);
    await disposeBooking(t);
  });
}
