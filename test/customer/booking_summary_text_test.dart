// 2026-10-23: the price summary showed "Accès à préciser", "Aide Movi-K à
// préciser", "Manutentionnaires: null · Équipement:" and "1 · personne(s)".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/widgets/booking_help_text.dart';
import 'package:movik_connect/widgets/booking_load_summary.dart';
import '../helpers/booking_test_harness.dart';

void main() {
  test('plain labels for handlers and equipment', () {
    expect(handlersLabel(1, 'fr'), '1 personne pour la manutention');
    expect(handlersLabel(2, 'fr'), '2 personnes pour la manutention');
    expect(handlersLabel(null, 'fr'), isNull);
    expect(equipmentLabel(const [], 'fr'), 'Aucun équipement spécial');
    expect(equipmentLabel(const ['dolly', 'straps'], 'fr'), 'Équipement : diable, sangles');
    expect(
      helpAndEquipmentLine({'handlers': 1, 'equipment': []}, 'fr'),
      '1 personne pour la manutention · Aucun équipement spécial',
    );
    expect(helpAndEquipmentLine({'handlers': null, 'equipment': null}, 'fr'), 'Aucun équipement spécial');
  });

  testWidgets(
    'a price before driver assignment (no server snapshot) shows the customer answers, never "à préciser" or "null"',
    (t) async {
      final d = testDraft(step: 3, quote: true);
      d.data['quote'] = {...testQuote(), 'booking': null, 'assignmentPending': true};
      for (final key in ['pickup_access', 'dropoff_access']) {
        (d.data[key] as Map)['help'] = false;
      }
      final api = TestBookingApi()..quote = Map<String, dynamic>.from(d.data['quote'] as Map);
      await pumpBooking(t, storage: MemoryBookingStorage(d), api: api);
      expect(find.textContaining('Rez-de-chaussée'), findsNWidgets(2));
      expect(find.text('Sans aide Movi-K'), findsNWidgets(2));
      expect(find.textContaining('Accès à préciser'), findsNothing);
      expect(find.textContaining('à préciser'), findsNothing);
      expect(find.textContaining('null'), findsNothing);
      expect(
        find.text('1 personne pour la manutention · Aucun équipement spécial'),
        findsOneWidget,
      );
      await disposeBooking(t);
    },
  );

  testWidgets('a price below 30 \$ explains the 30 \$ card hold before confirming', (t) async {
    final d = testDraft(step: 3, quote: true);
    d.data['quote'] = {...testQuote(), 'customerTotal': 25.0};
    final api = TestBookingApi()..quote = Map<String, dynamic>.from(d.data['quote'] as Map);
    await pumpBooking(t, storage: MemoryBookingStorage(d), api: api);
    expect(find.byKey(const ValueKey('booking-minimum-hold')), findsOneWidget);
    await disposeBooking(t);
  });

  testWidgets('an unverified customer is reminded from step 1', (t) async {
    final api = TestBookingApi();
    await pumpBooking(
      t,
      storage: MemoryBookingStorage(testDraft()),
      api: api,
      auth: BookingTestAuth(verified: false),
    );
    expect(find.byKey(const ValueKey('booking-email-verification')), findsOneWidget);
    expect(find.text('Renvoyer le courriel'), findsOneWidget);
    await disposeBooking(t);
  });

  testWidgets('the requested date is written dd/mm/yyyy, never with English month names', (t) async {
    final local = DateTime(2026, 10, 23, 14, 0);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: BookingLoadSummary(
      locale: 'fr',
      collapsible: false,
      snapshot: {'load': {'requested_at': local.toUtc().toIso8601String(), 'timing_mode': 'scheduled'}},
    ))));
    expect(find.text('Date demandée (à confirmer) : 23/10/2026 · 14:00'), findsOneWidget);
    expect(find.textContaining('October'), findsNothing);
  });
}
