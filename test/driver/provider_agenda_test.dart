import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/repositories/driver_agenda_repository.dart';
import 'package:movik_connect/screens/dashboard/provider/tabs/provider_calendar_tab.dart';

class AgendaFake implements DriverAgendaRepository {
  final missions = StreamController<List<DeliveryMission>>.broadcast();
  DriverAgenda agenda = const DriverAgenda();
  bool failSave = false;
  int saves = 0;
  @override
  Future<DriverAgenda> load() async => agenda;
  @override
  Future<DriverAgenda> save(DriverAgenda value) async {
    saves++;
    if (failSave) throw StateError('simulated failure');
    return agenda = DriverAgenda(
      revision: value.revision + 1,
      configured: true,
      windows: value.windows,
      blocked: value.blocked,
    );
  }

  @override
  Stream<List<DeliveryMission>> watchMissions() => missions.stream;
}

DeliveryMission mission(String id, String status, DateTime date) =>
    DeliveryMission.fromJson(id, {
      'driver_id': 'driver-test',
      'customer_id': 'synthetic',
      'description': 'Mission de test',
      'created_at': date.toIso8601String(),
      'status': status,
      'booking_snapshot': {
        'load': {'requested_at': date.toUtc().toIso8601String()},
      },
    });
Future<void> show(
  WidgetTester t,
  AgendaFake repo, {
  String locale = 'fr',
}) async {
  await t.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProviderCalendarTab(repository: repo, locale: locale),
      ),
    ),
  );
  repo.missions.add([]);
  await t.pumpAndSettle();
}

/// One-off periods and blocks live under « Réglages avancés » since the
/// agenda redesign (2026-10-25).
Future<void> openAdvanced(WidgetTester t) async {
  await t.ensureVisible(find.text('Réglages avancés'));
  await t.tap(find.text('Réglages avancés'));
  await t.pumpAndSettle();
}

void main() {
  test('UTC availability survives serialization and local time conversion', () {
    final d = DriverAgenda.fromJson({
      'revision': 3,
      'configured': true,
      'agenda': {
        'windows': [
          {'start': '2026-11-01T05:30:00Z', 'end': '2026-11-01T06:30:00Z'},
        ],
        'blocked': [],
      },
    });
    expect(
      d.windows.single.end.difference(d.windows.single.start),
      const Duration(hours: 1),
    );
    expect(d.windows.single.toJson()['start'], '2026-11-01T05:30:00.000Z');
  });
  test('scheduled mission uses requested time without rewriting it', () {
    final date = DateTime.utc(2026, 11, 1, 17);
    expect(agendaMissionStart(mission('a', 'assigned', date))!.toUtc(), date);
  });
  for (final width in [375.0, 1440.0]) {
    testWidgets(
      'agenda shows assigned mission stream and no overflow at $width',
      (t) async {
        t.view.physicalSize = Size(width, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final repo = AgendaFake();
        addTearDown(repo.missions.close);
        await show(t, repo);
        expect(
          find.text('Aucune mission attribuée pour ce mois.'),
          findsOneWidget,
        );
        repo.missions.add([mission('a', 'assigned', DateTime.now())]);
        await t.pumpAndSettle();
        expect(find.text('Mission de test'), findsOneWidget);
        expect(find.textContaining('Horaire demandé'), findsOneWidget);
        expect(find.textContaining('ne filtrent pas encore'), findsOneWidget);
        repo.missions.add([]);
        await t.pumpAndSettle();
        expect(find.text('Mission de test'), findsNothing);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets('saved ranges reload; deletion and save use a revision', (
    t,
  ) async {
    final repo = AgendaFake();
    addTearDown(repo.missions.close);
    repo.agenda = DriverAgenda(
      revision: 5,
      configured: true,
      windows: [
        AgendaInterval(DateTime(2026, 11, 1, 9), DateTime(2026, 11, 1, 12)),
      ],
    );
    await show(t, repo);
    await openAdvanced(t);
    await t.ensureVisible(find.byIcon(Icons.delete_outline));
    await t.tap(find.byIcon(Icons.delete_outline));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Enregistrer mes disponibilités'));
    await t.tap(find.text('Enregistrer mes disponibilités'));
    await t.pumpAndSettle();
    expect(repo.saves, 1);
    expect(repo.agenda.revision, 6);
    expect(repo.agenda.windows, isEmpty);
    expect(find.text('Modifications non enregistrées'), findsNothing);
  });
  testWidgets('failed save retains edits and offers explicit reload', (
    t,
  ) async {
    final repo = AgendaFake();
    addTearDown(repo.missions.close);
    repo.agenda = DriverAgenda(
      revision: 5,
      configured: true,
      windows: [
        AgendaInterval(DateTime(2026, 11, 1, 9), DateTime(2026, 11, 1, 12)),
      ],
    );
    repo.failSave = true;
    await show(t, repo);
    await openAdvanced(t);
    await t.ensureVisible(find.byIcon(Icons.delete_outline));
    await t.tap(find.byIcon(Icons.delete_outline));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Enregistrer mes disponibilités'));
    await t.tap(find.text('Enregistrer mes disponibilités'));
    await t.pumpAndSettle();
    expect(find.text('Modifications non enregistrées'), findsOneWidget);
    expect(
      find.textContaining('Vos modifications sont conservées'),
      findsOneWidget,
    );
    expect(repo.agenda.windows.length, 1);
  });
  testWidgets('mission read errors are not displayed as an empty agenda', (
    t,
  ) async {
    final repo = AgendaFake();
    addTearDown(repo.missions.close);
    await show(t, repo);
    repo.missions.addError(StateError('simulated'));
    await t.pumpAndSettle();
    expect(find.text('Impossible de charger les missions.'), findsOneWidget);
    expect(find.text('Aucune mission attribuée pour ce mois.'), findsNothing);
  });
}
