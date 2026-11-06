// Calendrier de réservation (2026-11-06) : grille de semaines jusqu'au
// dernier jour réservable, jours fermés grisés, clés `slot-day-<jour>`.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/widgets/booking_simple_steps.dart';

Future<List<String>> pump(
  WidgetTester t, {
  required DateTime now,
  required BookingHours hours,
  String? selected,
  String locale = 'fr',
}) async {
  final picked = <String>[];
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: BookingCalendar(
            now: now,
            hours: hours,
            locale: locale,
            selectedKey: selected,
            onSelected: picked.add,
          ),
        ),
      ),
    ),
  );
  await t.pump();
  return picked;
}

void main() {
  final now = DateTime(2026, 11, 6, 10); // vendredi

  testWidgets('30 jours : toutes les semaines jusqu’au dernier jour, titre sur deux mois', (
    t,
  ) async {
    final picked = await pump(
      t,
      now: now,
      hours: const BookingHours(daysAhead: 30),
    );
    expect(find.text('Novembre – décembre 2026'), findsOneWidget);
    // Dernier jour réservable : 5 décembre (6 nov. + 29).
    expect(find.byKey(const ValueKey('slot-day-2026-12-05')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('slot-day-2026-12-05')));
    expect(picked, ['2026-12-05']);
    // Au-delà de la fenêtre : visible mais inactif.
    await t.tap(find.byKey(const ValueKey('slot-day-2026-12-06')));
    expect(picked, ['2026-12-05']);
    // Avant aujourd'hui : inactif.
    await t.tap(find.byKey(const ValueKey('slot-day-2026-11-02')));
    expect(picked, ['2026-12-05']);
  });

  testWidgets('jours fermés grisés, jour choisi mis en évidence', (t) async {
    final picked = await pump(
      t,
      now: now,
      hours: const BookingHours(daysAhead: 10, openWeekdays: [1, 2, 3, 4, 5]),
      selected: '2026-11-10',
    );
    // Samedi 7 et dimanche 8 fermés.
    await t.tap(find.byKey(const ValueKey('slot-day-2026-11-07')));
    await t.tap(find.byKey(const ValueKey('slot-day-2026-11-08')));
    expect(picked, isEmpty);
    await t.tap(find.byKey(const ValueKey('slot-day-2026-11-09')));
    expect(picked, ['2026-11-09']);
    expect(find.text('Novembre 2026'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('en anglais et en espagnol', (t) async {
    await pump(t, now: now, hours: const BookingHours(daysAhead: 4), locale: 'en');
    expect(find.text('November 2026'), findsOneWidget);
    await pump(t, now: now, hours: const BookingHours(daysAhead: 4), locale: 'es');
    expect(find.text('Noviembre 2026'), findsOneWidget);
  });
}
