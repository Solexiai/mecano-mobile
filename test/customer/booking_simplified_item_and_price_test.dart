// 2026-11-13 (comparaison avec un concurrent) : le parcours promet « pas de
// mesures à prendre », donc les mesures sont repliées ; « Doit rester debout »
// est retiré ; le prix dit « Livré à l'intérieur, compris » et affiche un
// compte à rebours au lieu d'une heure avec « (UTC-05:00) ».
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/booking_test_harness.dart';

void main() {
  testWidgets('an item without measurements keeps them folded and optional', (
    t,
  ) async {
    final d = testDraft();
    // The harness item is a non-nullable map: rebuild it without measurements.
    d.items[0] = <String, dynamic>{
      ...Map<String, dynamic>.from(d.items.single as Map),
      for (final field in ['length', 'width', 'height', 'weight']) field: null,
    };
    await pumpBooking(t, storage: MemoryBookingStorage(d), api: TestBookingApi());
    expect(find.text('Ajouter des détails (facultatif)'), findsOneWidget);
    expect(find.text('Longueur'), findsNothing);
    expect(find.text('Mesures approximatives'), findsNothing);
    expect(find.text('Doit rester debout'), findsNothing);

    final details = find.byKey(const ValueKey('item-details-test-item'));
    await t.ensureVisible(details);
    await t.tap(find.text('Ajouter des détails (facultatif)'));
    await t.pumpAndSettle();
    expect(find.text('Longueur'), findsOneWidget);
    expect(find.text('Mesures approximatives'), findsOneWidget);
    expect(find.text('Doit rester debout'), findsNothing);
    expect(t.takeException(), isNull);
    await disposeBooking(t);
  });

  testWidgets('entered measurements open the details panel by themselves', (
    t,
  ) async {
    await pumpBooking(
      t,
      storage: MemoryBookingStorage(testDraft()),
      api: TestBookingApi(),
    );
    expect(find.text('Longueur'), findsOneWidget);
    expect(find.text('Doit rester debout'), findsNothing);
    await disposeBooking(t);
  });

  testWidgets(
    'the price says inside delivery is included and counts down the guarantee',
    (t) async {
      final d = testDraft(step: 3, quote: true);
      (d.data['dropoff_access'] as Map)['inside'] = true;
      final api = TestBookingApi()
        ..quote = Map<String, dynamic>.from(d.data['quote'] as Map);
      await pumpBooking(t, storage: MemoryBookingStorage(d), api: api);
      expect(
        find.byKey(const ValueKey('booking-price-hero-inside')),
        findsOneWidget,
      );
      expect(find.text('Livré à l’intérieur, compris'), findsOneWidget);
      final countdown = find.byKey(
        const ValueKey('booking-price-hero-countdown'),
      );
      expect(countdown, findsOneWidget);
      expect(
        t.widget<Text>(countdown).data,
        matches(RegExp(r'^Prix garanti encore \d+ min$')),
      );
      await disposeBooking(t);
    },
  );

  testWidgets('without inside delivery the price does not promise it', (t) async {
    final d = testDraft(step: 3, quote: true);
    final api = TestBookingApi()
      ..quote = Map<String, dynamic>.from(d.data['quote'] as Map);
    await pumpBooking(t, storage: MemoryBookingStorage(d), api: api);
    expect(find.byKey(const ValueKey('booking-price-hero-inside')), findsNothing);
    await disposeBooking(t);
  });
}
