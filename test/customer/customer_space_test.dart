// Customer space, Uber-style (owner mockup validated 2026-10-25): the
// delivery in progress first, plain statuses, French money and dates,
// "Refaire" with the same addresses, three tabs.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/repositories/mission_repository.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/providers/mechanic_provider.dart';
import 'package:movik_connect/screens/dashboard/customer/customer_mission_view.dart';
import 'package:movik_connect/screens/dashboard/customer/tabs/customer_overview_tab.dart';
import 'package:movik_connect/screens/dashboard/customer/tabs/customer_requests_tab.dart';
import 'package:movik_connect/services/booking/booking_draft.dart';

class _Missions implements MissionRepository {
  _Missions(this.missions);
  final List<DeliveryMission> missions;
  @override
  Stream<List<DeliveryMission>> watchCustomerMissions(String customerId) =>
      Stream.value(missions);
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Map<String, dynamic> _address(String line1, String city) => {
  'line1': line1,
  'city': city,
  'postal_code': 'J2G 1A1',
  'lat': 45.4,
  'lng': -72.7,
  'formatted_address': '$line1, $city',
};

DeliveryMission mission(
  String id,
  String status, {
  String? driver,
  String label = 'Divan 3 places',
  String dropCity = 'Bromont',
  double total = 25,
}) => DeliveryMission.fromJson(id, {
  'customer_id': 'customer_A',
  'status': status,
  'driver_display_name': driver,
  'item_category_key': 'cat_furniture',
  'created_at': '2026-10-23T18:00:00Z',
  'customer_total': total,
  'pickup_address': _address('10 rue Principale', 'Granby'),
  'dropoff_address': _address('5 rue du Lac', dropCity),
  'booking_snapshot': {
    'load': {
      'items': [
        {'label': label, 'quantity': 1, 'category': 'sofa'},
      ],
    },
  },
});

Future<void> pump(
  WidgetTester t,
  Widget child, {
  required List<DeliveryMission> missions,
  String? name,
}) async {
  SharedPreferences.setMockInitialValues({});
  BackendLocator.missionRepositoryOverride = _Missions(missions);
  addTearDown(() => BackendLocator.missionRepositoryOverride = null);
  final auth = FirebaseAuthProvider(backendConfigured: false)
    ..debugForceSignedIn = true
    ..debugForceUid = 'customer_A'
    ..debugForceDisplayName = name
    ..debugForceEmail = 'client@example.invalid';
  final router = GoRouter(
    initialLocation: '/fr/tableau-de-bord',
    routes: [
      GoRoute(
        path: '/fr/tableau-de-bord',
        builder: (_, __) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/fr/livraison/demande',
        builder: (_, __) => const Scaffold(body: Text('BOOKING')),
      ),
      GoRoute(
        path: '/fr/livraison/suivi/:id',
        builder: (_, s) => Scaffold(body: Text('TRACK ${s.pathParameters['id']}')),
      ),
    ],
  );
  await t.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
        ChangeNotifierProvider(create: (_) => MechanicRequestProvider()),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  test('plain labels: status, route, date and French money', () {
    final m = mission('m1', 'in_transit', driver: 'Marc Tremblay');
    expect(customerStatusLabel(m, 'fr'), 'En route vers vous');
    expect(customerStatusLabel(mission('m2', 'searching_driver'), 'fr'),
        'On cherche un chauffeur');
    expect(customerStatusLabel(mission('m3', 'completed'), 'fr'), 'Livrée');
    expect(customerMissionRoute(m, 'fr'), 'Granby → Bromont');
    expect(
      customerMissionRoute(mission('m4', 'completed', dropCity: 'Granby'), 'fr'),
      '10 rue Principale → 5 rue du Lac',
    );
    expect(customerDateLabel(DateTime(2026, 10, 23), 'fr'), 'ven. 23 oct.');
    expect(customerMoney(m, 'fr'), matches(RegExp(r'^25,00\s\$$')));
    expect(customerProgress(m), 3);
  });

  testWidgets('home: first name, the delivery in progress first, no email', (
    t,
  ) async {
    await pump(
      t,
      CustomerOverviewTab(onGoToTab: (_) {}),
      name: 'Daniel Tanguay',
      missions: [
        mission('active', 'driver_to_pickup', driver: 'Marc Tremblay'),
        mission('done', 'completed', label: 'Fauteuil'),
      ],
    );
    expect(find.text('Bonjour Daniel'), findsOneWidget);
    expect(find.textContaining('@'), findsNothing);
    expect(find.byKey(const ValueKey('customer-active-active')), findsOneWidget);
    expect(find.text('En route vers le ramassage'), findsOneWidget);
    expect(find.text('Marc'), findsOneWidget);
    expect(find.byKey(const ValueKey('rebook-done')), findsOneWidget);
    expect(find.byKey(const ValueKey('rebook-active')), findsNothing);
    expect(find.textContaining('mécanique'), findsNothing);
    await t.tap(find.byKey(const ValueKey('customer-follow-active')));
    await t.pumpAndSettle();
    expect(find.text('TRACK active'), findsOneWidget);
  });

  testWidgets('home without a name says only "Bonjour"', (t) async {
    await pump(
      t,
      CustomerOverviewTab(onGoToTab: (_) {}),
      missions: [mission('done', 'completed')],
    );
    expect(find.text('Bonjour'), findsOneWidget);
  });

  testWidgets('"Refaire" opens a new booking with the same two addresses', (
    t,
  ) async {
    await pump(
      t,
      CustomerOverviewTab(onGoToTab: (_) {}),
      missions: [mission('done', 'completed')],
    );
    await t.tap(find.byKey(const ValueKey('rebook-done')));
    await t.pumpAndSettle();
    expect(find.text('BOOKING'), findsOneWidget);
    final draft = await BookingDraftStorage().load('customer_A');
    expect(draft, isNotNull);
    expect((draft!.data['pickup'] as Map)['city'], 'Granby');
    expect((draft.data['dropoff'] as Map)['formatted_address'], '5 rue du Lac, Bromont');
    expect(draft.items, isEmpty, reason: 'new photos are taken');
    expect(draft.quote, isNull);
  });

  testWidgets('activity: upcoming first, then past with French prices', (
    t,
  ) async {
    await pump(
      t,
      const CustomerRequestsTab(),
      missions: [
        mission('active', 'searching_driver', total: 212.59),
        mission('done', 'completed', total: 28.22),
      ],
    );
    expect(find.text('À venir (1)'), findsOneWidget);
    expect(find.byKey(const ValueKey('customer-delivery-active')), findsOneWidget);
    expect(find.byKey(const ValueKey('customer-delivery-done')), findsNothing);
    await t.tap(find.byKey(const ValueKey('activity-tab-past')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('customer-delivery-done')), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'28,22\s\$')),
      findsOneWidget,
    );
  });
}
