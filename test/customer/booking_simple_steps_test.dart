// Simplified booking, one question per screen (owner decisions 2026-10-23):
// stairs asked only for furniture/appliances, "Je ne sais pas" priced as
// stairs, two help choices, fixed hours.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/booking/booking_draft.dart';
import 'package:movik_connect/widgets/booking_access_section.dart';
import 'package:movik_connect/widgets/booking_simple_steps.dart';
import '../helpers/booking_test_harness.dart';

BookingDraft unanswered({required String category, int part = 1}) {
  final d = testDraft();
  d.part = part;
  (d.items[0] as Map)['category'] = category;
  for (final key in ['pickup_access', 'dropoff_access']) {
    d.data[key] = <String, dynamic>{
      'floor': null,
      'stairs': null,
      'elevator': null,
      'help': null,
      'details_version': 1,
      'confirmed_fields': <String>[],
      'onsite_help': null,
      'inside': null,
    };
  }
  d.data['handlers'] = 1;
  return d;
}

Future<void> tapKey(WidgetTester t, String key) async {
  final f = find.byKey(ValueKey(key));
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

bool enabled(WidgetTester t, String key) =>
    t.widget<FilledButton>(find.byKey(ValueKey(key))).onPressed != null;

void main() {
  test('stairs question only for furniture or appliances', () {
    expect(stairsQuestionNeeded([
      {'category': 'boxes'},
    ]), isFalse);
    expect(stairsQuestionNeeded([
      {'category': 'boxes'},
      {'category': 'fridge'},
    ]), isTrue);
  });

  test('simple answers fill complete access details for the server', () {
    final d = unanswered(category: 'sofa');
    applyStairsAnswer(d.data, 'pickup', 'no');
    applyStairsAnswer(d.data, 'dropoff', 'unknown');
    applyHelpChoice(d.data, 'two_movers');
    final pickup = d.data['pickup_access'] as Map;
    final dropoff = d.data['dropoff_access'] as Map;
    expect(pickup['stairs'], isFalse);
    expect(dropoff['stairs'], isTrue, reason: 'Je ne sais pas = escaliers');
    expect(d.data['handlers'], 2);
    expect(pickup['help'], isTrue);
    expect(dropoff['onsite_help'], 'no');
    expect(accessAnswersComplete(pickup), isTrue);
    expect(accessAnswersComplete(dropoff), isTrue);
  });

  test('fixed hours: past or too-close hours are not offered', () {
    final now = DateTime(2026, 10, 23, 16, 10);
    final day = DateTime(2026, 10, 23);
    expect(slotOpen(day, 17, now), isFalse, reason: 'less than 1 h ahead');
    expect(slotOpen(day, 19, now), isTrue);
    final days = bookingSlotDays(now);
    expect(days.length, 4);
    expect(slotDayLabel(days[1], now, 'fr'), 'Demain');
    expect(slotDayLabel(days[2], now, 'fr'), 'dim. 25');
    final late = DateTime(2026, 10, 23, 18, 30);
    expect(bookingSlotDays(late).first.day, 24, reason: 'no hour left today');
  });

  testWidgets('a sofa: stairs asked per address, then help, then time', (
    t,
  ) async {
    final storage = MemoryBookingStorage(unanswered(category: 'sofa'));
    final api = TestBookingApi();
    await pumpBooking(t, storage: storage, api: api);
    expect(find.text('Étape 2 sur 7'), findsOneWidget);
    expect(find.text('Des escaliers à cette adresse ?'), findsNWidgets(2));
    expect(enabled(t, 'booking-next-where'), isFalse);
    await tapKey(t, 'pickup-stairs-no');
    await tapKey(t, 'dropoff-stairs-unknown');
    expect(find.byKey(const ValueKey('dropoff-stairs-unknown-note')),
        findsOneWidget);
    expect(enabled(t, 'booking-next-where'), isTrue);
    await tapKey(t, 'booking-next-where');

    expect(find.text('Étape 3 sur 7'), findsOneWidget);
    expect(find.text('Pouvez-vous aider à porter ?'), findsOneWidget);
    await tapKey(t, 'help-choice-two_movers');
    await tapKey(t, 'booking-next-help');

    expect(find.text('Étape 4 sur 7'), findsOneWidget);
    await tapKey(t, 'timing-immediate');
    await tapKey(t, 'booking-see-price');

    final load =
        api.payloads[api.calls.lastIndexOf('calculateDeliveryQuote')]['booking']
            as Map;
    expect(load['handlers'], 2);
    expect((load['pickup'] as Map)['stairs'], isFalse);
    expect((load['dropoff'] as Map)['stairs'], isTrue);
    expect((load['dropoff'] as Map)['help'], isTrue);
    expect(find.text('Étape 5 sur 7'), findsOneWidget);
    await disposeBooking(t);
  });

  testWidgets('boxes only: no stairs question and no stairs fee', (t) async {
    final storage = MemoryBookingStorage(unanswered(category: 'boxes'));
    final api = TestBookingApi();
    await pumpBooking(t, storage: storage, api: api);
    expect(find.text('Des escaliers à cette adresse ?'), findsNothing);
    await tapKey(t, 'booking-next-where');
    // The common help answer is preselected.
    expect(
      storage.saved!.data['help_choice'],
      'customer_helps',
    );
    final pickup = storage.saved!.data['pickup_access'] as Map;
    expect(pickup['stairs'], isFalse);
    expect(storage.saved!.data['pickup_stairs_answer'], isNull);
    await tapKey(t, 'booking-next-help');
    await tapKey(t, 'timing-immediate');
    await tapKey(t, 'booking-see-price');
    final load =
        api.payloads[api.calls.lastIndexOf('calculateDeliveryQuote')]['booking']
            as Map;
    expect(load['handlers'], 1);
    expect((load['dropoff'] as Map)['stairs'], isFalse);
    await disposeBooking(t);
  });

  testWidgets('back goes to the previous question', (t) async {
    final storage = MemoryBookingStorage(unanswered(category: 'sofa', part: 2));
    await pumpBooking(t, storage: storage, api: TestBookingApi());
    expect(find.text('Étape 3 sur 7'), findsOneWidget);
    await tapKey(t, 'booking-back');
    expect(find.text('Étape 2 sur 7'), findsOneWidget);
    await disposeBooking(t);
  });
}
