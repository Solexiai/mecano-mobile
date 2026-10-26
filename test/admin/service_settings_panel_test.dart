// Centre de commande > Où et quand ? (2026-10-26).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/screens/dashboard/admin/command_center/service_settings_panel.dart';
import 'package:movik_connect/widgets/booking_simple_steps.dart';

Map<String, dynamic> _state() => {
  'zones': {
    'saved': false,
    'enabled': true,
    'list': [
      {'name': 'Granby', 'type': 'circle', 'center_lat': 45.39856, 'center_lng': -72.72225, 'radius_km': 40},
    ],
  },
  'hours': {
    'saved': false,
    'slot_hours': [9, 11, 13, 15, 17, 19],
    'lead_minutes': 60,
    'days_ahead': 4,
    'open_weekdays': [1, 2, 3, 4, 5, 6, 7],
  },
};

void main() {
  testWidgets('defaults shown; change hours, radius and days; save', (t) async {
    t.view.physicalSize = const Size(1200, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final calls = <Map<String, dynamic>>[];
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ServiceSettingsPanel(api: (data) async {
          calls.add(data);
          return data['action'] == 'get' ? _state() : {'success': true};
        }),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text('Zone de lancement par défaut (jamais enregistrée).'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('service-hour-8')));
    await t.tap(find.byKey(const ValueKey('service-day-7')));
    await t.pump();
    await t.enterText(find.byKey(const ValueKey('zone-radius-0-0')), '50');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('service-save')));
    await t.pumpAndSettle();
    final saved = calls.last;
    expect(saved['action'], 'save');
    expect((saved['zones'] as List).single, {
      'name': 'Granby', 'center_lat': 45.39856, 'center_lng': -72.72225, 'radius_km': 50.0,
    });
    expect((saved['hours'] as Map)['slot_hours'], [8, 9, 11, 13, 15, 17, 19]);
    expect((saved['hours'] as Map)['open_weekdays'], [1, 2, 3, 4, 5, 6]);
    expect(find.byKey(const ValueKey('service-saved')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('the booking app follows the saved hours', () {
    final hours = BookingHours.fromJson({
      'slot_hours': [10, 14],
      'lead_minutes': 120,
      'days_ahead': 2,
      'open_weekdays': [1, 2, 3, 4, 5],
    });
    final monday = DateTime(2026, 11, 2, 8);
    expect(slotOpen(DateTime(2026, 11, 2), 10, monday, hours), isFalse, reason: 'less than 2 h');
    expect(slotOpen(DateTime(2026, 11, 2), 14, monday, hours), isTrue);
    final days = bookingSlotDays(monday, hours);
    expect(days.length, 2);
    final saturday = DateTime(2026, 11, 7, 8);
    expect(bookingSlotDays(saturday, hours), isEmpty, reason: 'closed weekend');
    expect(BookingHours.fromJson(null).slotHours, bookingSlotHours);
    expect(BookingHours.fromJson({'slot_hours': 'x'}).daysAhead, 4);
  });
}
