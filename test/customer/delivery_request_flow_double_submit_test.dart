import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/booking_test_harness.dart';

void main() {
  testWidgets(
    'Repeated confirmation invokes creation once and keeps a refresh receipt',
    (t) async {
      final api = TestBookingApi()..delay = const Duration(milliseconds: 250);
      final store = MemoryBookingStorage(testDraft(step: 3, quote: true));
      await pumpBooking(t, storage: store, api: api);
      final finder = find.widgetWithText(
        FilledButton,
        'Confirmer ma demande de livraison',
      );
      await t.ensureVisible(finder);
      await t.pumpAndSettle();
      final callback = t.widget<FilledButton>(finder).onPressed!;
      callback();
      callback();
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      expect(api.calls.where((n) => n == 'createDeliveryRequest').length, 1);
      expect(
        find.textContaining('Votre demande est enregistrée'),
        findsOneWidget,
      );
      expect(store.saved!.data['missionId'], 'test_mission');
      expect(store.saved!.contacts['pickup_phone'], '');
      await disposeBooking(t);
    },
  );
  testWidgets('Bank setup interruption never enables confirmation', (t) async {
    final api = TestBookingApi()..cardReady = false;
    final store = MemoryBookingStorage(testDraft(step: 3, quote: true));
    await pumpBooking(t, storage: store, api: api);
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
    expect(api.calls, isNot(contains('createDeliveryRequest')));
    await disposeBooking(t);
  });
}
