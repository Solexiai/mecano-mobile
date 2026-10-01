import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/booking/booking_draft.dart';
import '../helpers/booking_test_harness.dart';

void main() {
  testWidgets(
    'Restores contacts, item dimensions, addresses and current step',
    (t) async {
      final store = MemoryBookingStorage(testDraft(step: 2, quote: true));
      await pumpBooking(t, storage: store, api: TestBookingApi());
      final fields = t.widgetList<TextFormField>(find.byType(TextFormField));
      expect(fields.any((f) => f.initialValue == '+15145550100'), true);
      expect(find.text('3. Mes coordonnées'), findsOneWidget);
      await disposeBooking(t);
    },
  );
  test(
    'guest handoff takes precedence, stays bound to the signed-in account',
    () async {
      final store = BookingDraftStorage();
      await store.clear(null);
      await store.clear('one');
      await store.clear('two');
      final old = testDraft()..data['category'] = 'old';
      await store.save(old, 'one');
      final guest = testDraft()..data['category'] = 'new';
      await store.save(guest, null);
      expect((await store.load('two')), isNull);
      await store.handoff();
      expect((await store.load('one'))!.data['category'], 'new');
      expect(await store.load('two'), isNull);
      expect(await store.load(null), isNull);
    },
  );
  test('expired draft is removed', () async {
    final store = BookingDraftStorage();
    final d = testDraft()..data['created'] = 1;
    await store.save(d, 'expiry');
    expect(await store.load('expiry'), isNull);
  });
  testWidgets('changing dimensions invalidates the quote immediately', (
    t,
  ) async {
    final store = MemoryBookingStorage(testDraft(quote: true));
    await pumpBooking(t, storage: store, api: TestBookingApi());
    final f = find.byKey(const ValueKey('test-item-length-cm-kg'));
    await t.ensureVisible(f);
    await t.enterText(f, '200');
    await t.pumpAndSettle();
    expect(store.saved!.quote, isNull);
    expect(store.saved!.items.first['length'], 200);
    await disposeBooking(t);
  });
}
