import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/repositories/driver_agenda_repository.dart';
import 'package:movik_connect/finance/presentation/driver_display_format.dart';
import 'package:movik_connect/services/booking/booking_api.dart';
import 'package:movik_connect/widgets/driver_calendars_panel.dart';
import 'package:movik_connect/widgets/driver_slot_confirmation.dart';
import 'package:movik_connect/widgets/driver_recurrence_editor.dart';
import 'package:movik_connect/widgets/scheduled_mission_panel.dart';
import 'provider_agenda_test.dart' as fixtures;

class CalendarApiFake implements BookingApi {
  final calls = <String>[];
  @override
  Future<Map<String, dynamic>?> profile() async => null;
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    calls.add(name);
    if (name == 'getDriverCalendars') {
      return {'available': false, 'connections': []};
    }
    throw StateError('Unexpected test call');
  }
}

void main() {
  test(
    'recurrence and activation survive repository JSON without changing defaults',
    () {
      final a = DriverAgenda.fromJson({
        'revision': 1,
        'configured': true,
        'dispatch_connected': true,
        'agenda': {
          'windows': [],
          'blocked': [],
          'recurrence': {
            'time_zone': 'America/Toronto',
            'weekly': [
              {'day': 1, 'start_minute': 480, 'end_minute': 1020},
            ],
            'exceptions': [],
          },
        },
      });
      expect(a.recurrence!['weekly'], hasLength(1));
      expect(a.dispatchConnected, isTrue);
      expect(const DriverAgenda().recurrence, isNull);
    },
  );
  test('confirmed agenda time wins over original requested time', () {
    final m = DeliveryMission.fromJson('test', {
      'created_at': '2026-10-20T12:00:00Z',
      'scheduling': {
        'start': '2026-10-21T13:00:00Z',
        'end': '2026-10-21T15:00:00Z',
      },
      'booking_snapshot': {
        'load': {'requested_at': '2026-10-21T14:00:00Z'},
      },
    });
    expect(agendaMissionStart(m)!.toUtc(), DateTime.utc(2026, 10, 21, 13));
  });
  testWidgets('month navigation is functional and keyboard reachable', (
    t,
  ) async {
    final repo = fixtures.AgendaFake();
    addTearDown(repo.missions.close);
    await fixtures.show(t, repo);
    final now = DateTime.now();
    final next = DateTime(now.year, now.month + 1);
    await t.tap(find.byTooltip('Mois suivant'));
    await t.pumpAndSettle();
    expect(find.text(driverMonthYear(next, 'fr')), findsOneWidget);
    await t.tap(find.text('Aujourd’hui'));
    await t.pumpAndSettle();
    expect(find.text(driverMonthYear(now, 'fr')), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'recurrence starts empty and allows removal without clearing manual periods',
    (t) async {
      Map<String, dynamic>? result;
      final value = {
        'time_zone': 'America/Toronto',
        'weekly': [
          {'day': 1, 'start_minute': 480, 'end_minute': 1020},
        ],
        'exceptions': [],
      };
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DriverRecurrenceEditor(
              value: value,
              locale: 'fr',
              onChanged: (r) => result = r,
            ),
          ),
        ),
      );
      await t.tap(find.text('Horaire régulier et exceptions'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Retirer'));
      await t.pumpAndSettle();
      expect(result!['weekly'], isEmpty);
      expect(result!['time_zone'], 'America/Toronto');
    },
  );
  testWidgets(
    'external accounts are never marked connected from configuration alone',
    (t) async {
      final api = CalendarApiFake();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DriverCalendarsPanel(api: api, locale: 'fr'),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Mes calendriers connectés'));
      await t.pumpAndSettle();
      expect(find.text('Non connecté'), findsNWidgets(2));
      expect(find.textContaining('export manuel seulement'), findsOneWidget);
      expect(api.calls, ['getDriverCalendars']);
    },
  );
  testWidgets(
    'full duration is blank and explicit consent required; route is only lower bound',
    (t) async {
      Map<String, dynamic>? result;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await confirmDriverSlot(
                    context,
                    locale: 'fr',
                    preparation: {
                      'requested_at': '2026-11-02T14:00:00Z',
                      'route_minutes': 20,
                      'policy_version': 'TEST',
                      'driver_offer_minor': 12345,
                    },
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Open'));
      await t.pumpAndSettle();
      expect(find.textContaining('123.45 CAD'), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmer et accepter'),
            )
            .onPressed,
        isNull,
      );
      await t.enterText(find.byType(TextFormField).last, '90');
      await t.tap(find.byType(CheckboxListTile));
      await t.pump();
      await t.tap(find.widgetWithText(FilledButton, 'Confirmer et accepter'));
      await t.pumpAndSettle();
      expect(result!['full_duration_confirmed'], isTrue);
      expect(
        DateTime.parse(
          result!['end'] as String,
        ).difference(DateTime.parse(result!['start'] as String)).inMinutes,
        90,
      );
    },
  );
  for (final size in [
    const Size(375, 900),
    const Size(768, 1000),
    const Size(1440, 1000),
  ]) {
    testWidgets('scheduled mission never starts early and fits ${size.width}', (
      t,
    ) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final start = DateTime.now().add(const Duration(days: 1));
      var starts = 0;
      final m = DeliveryMission.fromJson('test', {
        'status': 'assigned',
        'driver_id': 'driver',
        'created_at': DateTime.now().toIso8601String(),
        'scheduling': {
          'start': start.toIso8601String(),
          'end': start.add(const Duration(hours: 2)).toIso8601String(),
          'pickup_at': start.toIso8601String(),
          'policy_version': 'TEST',
        },
      });
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ScheduledMissionPanel(
              mission: m,
              locale: 'fr',
              isDriver: true,
              onStart: () async {
                starts++;
              },
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(
        t
            .widget<FilledButton>(
              find.ancestor(
                of: find.text('Démarrer la mission'),
                matching: find.byWidgetPredicate((w) => w is FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(starts, 0);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump();
    });
  }
}
