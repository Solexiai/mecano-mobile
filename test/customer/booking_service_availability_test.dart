import 'package:flutter_test/flutter_test.dart';

import '../helpers/booking_test_harness.dart';

void main() {
  for (final signed in [false, true]) {
    testWidgets(
      'unavailable booking keeps the draft and offers retry, signed=$signed',
      (tester) async {
        final draft = testDraft(step: 1);
        final storage = MemoryBookingStorage(draft);
        final api = TestBookingApi()..configurationAvailable = false;
        await pumpBooking(
          tester,
          storage: storage,
          api: api,
          auth: BookingTestAuth(signed: signed),
        );

        expect(
          find.textContaining('La réservation est indisponible'),
          findsOneWidget,
        );
        expect(find.text('Calculer mon devis officiel'), findsNothing);
        expect(find.text('Se connecter et obtenir mon prix'), findsNothing);
        expect(storage.saved!.id, draft.id);
        expect(storage.saved!.items.first['label'], 'Canapé de test');
        expect(api.calls, isNot(contains('calculateDeliveryQuote')));
        expect(api.calls, isNot(contains('createDeliveryRequest')));

        api.configurationAvailable = true;
        await tapBooking(tester, 'Vérifier à nouveau la disponibilité');
        expect(
          find.textContaining('La réservation est indisponible'),
          findsNothing,
        );
        expect(
          find.text(
            signed
                ? 'Calculer mon devis officiel'
                : 'Se connecter et obtenir mon prix',
          ),
          findsOneWidget,
        );
        expect(storage.saved!.id, draft.id);
        expect(tester.takeException(), isNull);
        await disposeBooking(tester);
      },
    );
  }
}
