// Agenda chauffeur par journées entières (25 octobre 2026) : logique pure et
// sélection de plusieurs journées dans le calendrier du mois.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/repositories/driver_agenda_repository.dart';
import 'package:movik_connect/services/driver_agenda_editing.dart';
import 'package:movik_connect/widgets/driver_month_availability.dart';
import 'package:movik_connect/widgets/driver_weekly_hours_card.dart';

DateTime d(int month, int day, [int hour = 0]) =>
    DateTime(2026, month, day, hour);

void main() {
  group('horaire habituel', () {
    test('plusieurs jours à la fois, les autres jours ne changent pas', () {
      var a = setWeeklyHours(const DriverAgenda(), {6}, 9 * 60, 13 * 60);
      a = setWeeklyHours(a, {1, 2, 3, 4, 5}, 8 * 60, 17 * 60);
      expect(weeklyWindows(a, 1).single, const MinuteWindow(480, 1020));
      expect(weeklyWindows(a, 6).single, const MinuteWindow(540, 780));
      expect(weeklyWindows(a, 7), isEmpty);
      expect(a.recurrence!['time_zone'], kDefaultAgendaTimeZone);

      final groups = weeklyGroups(a);
      expect(groups, hasLength(2));
      expect(groups.first.weekdays, [1, 2, 3, 4, 5]);
      expect(weeklyGroupLabel(groups.first, 'fr'), 'lun. – ven. · 8 h – 17 h');
      expect(weeklyGroupLabel(groups.last, 'fr'), 'sam. · 9 h – 13 h');

      a = clearWeeklyHours(a, {6});
      expect(weeklyWindows(a, 6), isEmpty);
      expect(weeklyWindows(a, 5), isNotEmpty);
    });
  });

  group('journées choisies', () {
    final weekdays = setWeeklyHours(
      const DriverAgenda(),
      {1, 2, 3, 4, 5},
      480,
      1020,
    );

    test('état affiché : horaire habituel puis exception', () {
      // 2 novembre 2026 = lundi, 7 novembre = samedi.
      expect(agendaDayInfo(weekdays, d(11, 2)).isAvailable, isTrue);
      expect(
        agendaDayInfo(weekdays, d(11, 2)).source,
        AgendaDaySource.regular,
      );
      expect(agendaDayInfo(weekdays, d(11, 7)).isAvailable, isFalse);

      final a = setDaysAvailable(weekdays, [d(11, 7)], 600, 840);
      final info = agendaDayInfo(a, d(11, 7));
      expect(info.isAvailable, isTrue);
      expect(info.source, AgendaDaySource.custom);
      expect(info.windows.single, const MinuteWindow(600, 840));
    });

    test('pas disponible : exception vide et blocage de la journée', () {
      final a = setDaysUnavailable(weekdays, [d(11, 3), d(11, 4)]);
      expect(agendaDayInfo(a, d(11, 3)).isAvailable, isFalse);
      expect(agendaDayInfo(a, d(11, 4)).isAvailable, isFalse);
      expect(agendaDayInfo(a, d(11, 5)).isAvailable, isTrue);
      expect(exceptionWindows(a, d(11, 3)), isEmpty);
      expect(a.blocked, hasLength(2));
      expect(a.blocked.first.start, d(11, 3));
      expect(a.blocked.first.end, d(11, 4));
    });

    test('retour à l’horaire habituel : seule la journée choisie est rouverte', () {
      // Un blocage de trois jours (comme le serveur les fusionne).
      final blocked = DriverAgenda(
        recurrence: weekdays.recurrence,
        blocked: [AgendaInterval(d(11, 2), d(11, 5))],
      );
      final a = resetDays(blocked, [d(11, 3)]);
      expect(agendaDayInfo(a, d(11, 2)).isAvailable, isFalse);
      expect(agendaDayInfo(a, d(11, 3)).isAvailable, isTrue);
      expect(agendaDayInfo(a, d(11, 4)).isAvailable, isFalse);
      expect(a.blocked, hasLength(2));
      expect(exceptionWindows(a, d(11, 3)), isNull);
    });

    test('une plage ponctuelle qui touche la journée est coupée, pas effacée', () {
      final withWindow = DriverAgenda(
        recurrence: weekdays.recurrence,
        windows: [AgendaInterval(d(11, 7, 20), d(11, 8, 10))],
      );
      final a = setDaysUnavailable(withWindow, [d(11, 7)]);
      expect(a.windows.single.start, d(11, 8));
      expect(a.windows.single.end, d(11, 8, 10));
    });

    test('avant l’enregistrement, le passé est retiré', () {
      var a = setDaysUnavailable(weekdays, [d(10, 20), d(11, 3)]);
      a = pruneAgenda(a, d(10, 25, 12));
      expect(exceptionWindows(a, d(10, 20)), isNull);
      expect(exceptionWindows(a, d(11, 3)), isEmpty);
      expect(a.blocked.single.start, d(11, 3));
    });
  });

  testWidgets('calendrier : plusieurs journées, une seule action', (t) async {
    DriverAgenda? changed;
    final agenda = setWeeklyHours(const DriverAgenda(), {1, 2, 3, 4, 5}, 480, 1020);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DriverMonthAvailability(
              agenda: agenda,
              month: d(11, 1),
              missions: const [],
              locale: 'fr',
              now: d(10, 25, 10),
              onChanged: (a) => changed = a,
            ),
          ),
        ),
      ),
    );
    for (final day in ['2026-11-02', '2026-11-03', '2026-11-04']) {
      await t.ensureVisible(find.byKey(ValueKey('agenda-day-$day')));
      await t.tap(find.byKey(ValueKey('agenda-day-$day')));
      await t.pump();
    }
    expect(find.text('3 jours sélectionnés'), findsOneWidget);
    await t.ensureVisible(find.byKey(const ValueKey('days-unavailable')));
    await t.tap(find.byKey(const ValueKey('days-unavailable')));
    await t.pump();
    expect(changed, isNotNull);
    for (final day in [2, 3, 4]) {
      expect(agendaDayInfo(changed!, d(11, day)).isAvailable, isFalse);
    }
    expect(agendaDayInfo(changed!, d(11, 5)).isAvailable, isTrue);
    expect(find.text('3 jours sélectionnés'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('calendrier : les journées passées ne se sélectionnent pas', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DriverMonthAvailability(
              agenda: const DriverAgenda(),
              month: d(10, 1),
              missions: const [],
              locale: 'fr',
              now: d(10, 25, 10),
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await t.tap(find.byKey(const ValueKey('agenda-day-2026-10-20')));
    await t.pump();
    expect(find.byKey(const ValueKey('agenda-selection-panel')), findsNothing);
    await t.ensureVisible(find.byKey(const ValueKey('agenda-day-2026-10-27')));
    await t.tap(find.byKey(const ValueKey('agenda-day-2026-10-27')));
    await t.pump();
    expect(find.byKey(const ValueKey('agenda-selection-panel')), findsOneWidget);
  });

  testWidgets('horaire habituel : raccourci Semaine puis Appliquer', (t) async {
    DriverAgenda? changed;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DriverWeeklyHoursCard(
              agenda: const DriverAgenda(),
              locale: 'fr',
              onChanged: (a) => changed = a,
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Semaine'));
    await t.pump();
    await t.ensureVisible(find.byKey(const ValueKey('weekly-apply')));
    await t.tap(find.byKey(const ValueKey('weekly-apply')));
    await t.pump();
    for (var day = 1; day <= 5; day++) {
      expect(weeklyWindows(changed!, day).single, const MinuteWindow(480, 1020));
    }
    expect(weeklyWindows(changed!, 6), isEmpty);
    expect(t.takeException(), isNull);
  });
}
