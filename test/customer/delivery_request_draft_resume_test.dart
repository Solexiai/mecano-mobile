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
      expect(find.text('Étape 6 sur 7'), findsOneWidget);
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
  test('le reçu de confirmation expire après 30 minutes', () {
    final fresh = BookingDraft.receipt('m1');
    expect(fresh.isReceipt, isTrue);
    expect(fresh.expired, isFalse);
    final old = BookingDraft.receipt('m1')
      ..data['receipt_at'] = DateTime.now()
          .subtract(const Duration(minutes: 31))
          .millisecondsSinceEpoch;
    expect(old.expired, isTrue);
    // Reçu d'une version précédente, sans horodatage.
    final legacy = BookingDraft()..data['missionId'] = 'm1';
    expect(legacy.expired, isTrue);
    // Un brouillon normal n'est pas concerné.
    expect(testDraft().expired, isFalse);
  });
  testWidgets(
    'Obtenir mon prix après une ancienne confirmation ouvre une demande vierge',
    (t) async {
      final old = BookingDraft.receipt('old_mission')
        ..data['receipt_at'] = DateTime.now()
            .subtract(const Duration(hours: 2))
            .millisecondsSinceEpoch;
      final store = MemoryBookingStorage(old);
      await pumpBooking(t, storage: store, api: TestBookingApi());
      expect(find.textContaining('Votre demande est enregistrée'), findsNothing);
      expect(find.textContaining('old_mission'), findsNothing);
      await disposeBooking(t);
    },
  );
  testWidgets('un reçu récent reste affiché après un rafraîchissement', (
    t,
  ) async {
    final store = MemoryBookingStorage(BookingDraft.receipt('new_mission'));
    await pumpBooking(t, storage: store, api: TestBookingApi());
    expect(
      find.textContaining('Votre demande est enregistrée'),
      findsOneWidget,
    );
    await disposeBooking(t);
  });
}
