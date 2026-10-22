import 'package:flutter_test/flutter_test.dart';

import '../helpers/booking_test_harness.dart';

void main() {
  for (final signed in [false, true]) {
    testWidgets(
      'booking closure does not mask price action and draft survives refresh, signed=$signed',
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
          findsNothing,
        );
        expect(
          find.text(
            signed
                ? 'Calculer mon prix officiel'
                : 'Se connecter et obtenir mon prix',
          ),
          findsOneWidget,
        );
        expect(storage.saved!.id, draft.id);
        expect(storage.saved!.items.first['label'], 'Canapé de test');
        expect(api.calls, isNot(contains('calculateDeliveryQuote')));
        expect(api.calls, isNot(contains('createDeliveryRequest')));

        api.configurationAvailable = true;
        expect(find.text('Vérifier à nouveau la disponibilité'), findsNothing);
        await disposeBooking(tester);
        await pumpBooking(
          tester,
          storage: storage,
          api: api,
          auth: BookingTestAuth(signed: signed),
        );
        expect(
          find.textContaining('La réservation est indisponible'),
          findsNothing,
        );
        expect(
          find.text(
            signed
                ? 'Calculer mon prix officiel'
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
