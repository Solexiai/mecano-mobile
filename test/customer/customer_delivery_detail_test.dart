// Détail d'une livraison terminée, façon reçu (maquette validée 2026-10-25).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/models/mission_address.dart';
import 'package:movik_connect/backend/models/mission_rating.dart';
import 'package:movik_connect/backend/repositories/mission_repository.dart';
import 'package:movik_connect/backend/repositories/rating_repository.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/customer/customer_tracking_screen.dart';

const _customer = 'customer_detail';
const _id = 'mission_detail';

DeliveryMission _mission() => DeliveryMission(
  id: _id,
  customerId: _customer,
  customerDisplayName: 'Client',
  itemCategoryKey: 'cat_furniture',
  description: 'Divan',
  requiredVehicleCategory: VehicleCategory.pickupTruck,
  status: MissionStatus.completed,
  driverId: 'driver_detail',
  driverDisplayName: 'Marc',
  pricingVersion: 'TEST',
  createdAt: DateTime(2026, 10, 23, 9),
  completedAt: DateTime(2026, 10, 23, 15, 4),
  driverOfferAmount: 20,
  customerTotal: 25,
  pickupAddress: const MissionAddress(
    line1: '1 rue Fictive',
    city: 'Granby',
    postalCode: 'J2G 0A1',
    lat: 45.4,
    lng: -72.7,
  ),
  dropoffAddress: const MissionAddress(
    line1: '2 rue Fictive',
    city: 'Granby',
    postalCode: 'J2G 0A2',
    lat: 45.41,
    lng: -72.71,
  ),
);

class _Missions implements MissionRepository {
  @override
  Stream<DeliveryMission?> watchMission(String missionId) =>
      Stream.value(_mission());
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Ratings implements RatingRepository {
  @override
  Future<MissionRating?> getMyRatingForMission({
    required String missionId,
    required String customerId,
  }) async => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Widget _app(String locale, {double scale = 1}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LocaleProvider()),
    ChangeNotifierProvider.value(
      value: FirebaseAuthProvider(backendConfigured: false)
        ..debugForceSignedIn = true
        ..debugForceUid = _customer,
    ),
  ],
  child: MaterialApp.router(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    routerConfig: GoRouter(
      initialLocation: '/$locale/livraison/suivi/$_id',
      routes: [
        GoRoute(
          path: '/$locale/livraison/suivi/:missionId',
          builder: (c, s) =>
              CustomerTrackingScreen(missionId: s.pathParameters['missionId']!),
        ),
        GoRoute(
          path: '/$locale/contact',
          builder: (c, s) => const Text('CONTACT PAGE'),
        ),
        GoRoute(
          path: '/$locale/livraison/demande',
          builder: (c, s) => const Text('BOOKING PAGE'),
        ),
      ],
    ),
  ),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    BackendLocator.missionRepositoryOverride = _Missions();
    BackendLocator.ratingRepositoryOverride = _Ratings();
  });
  tearDown(() {
    BackendLocator.missionRepositoryOverride = null;
    BackendLocator.ratingRepositoryOverride = null;
  });

  testWidgets('reads like a receipt: what, when, where, total, actions', (
    t,
  ) async {
    await t.pumpWidget(_app('fr'));
    await t.pumpAndSettle();
    expect(find.text('Livraison du ven. 23 oct.'), findsOneWidget);
    expect(find.text('Divan'), findsOneWidget);
    expect(find.text('à 15 h 04'), findsOneWidget);
    expect(find.text('1 rue Fictive, Granby'), findsOneWidget);
    expect(find.text('2 rue Fictive, Granby'), findsOneWidget);
    expect(find.text('Chauffeur : Marc'), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-total')), findsOneWidget);
    expect(find.textContaining('25,00'), findsOneWidget);
    expect(find.byIcon(Icons.star_border), findsNWidgets(5));
    expect(find.text('Refaire cette livraison'), findsOneWidget);
    expect(find.text('Signaler un problème'), findsOneWidget);
    // Never called a receipt: the printable summary says it is not one.
    expect(find.textContaining('Télécharger le reçu'), findsNothing);
    expect(find.text('Référence : $_id'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('"Signaler un problème" opens the contact page', (t) async {
    await t.pumpWidget(_app('fr'));
    await t.pumpAndSettle();
    final report = find.byKey(const ValueKey('detail-report'));
    await t.ensureVisible(report);
    await t.pumpAndSettle();
    await t.tap(report);
    await t.pumpAndSettle();
    expect(find.text('CONTACT PAGE'), findsOneWidget);
  });

  testWidgets('"Refaire" opens a new booking', (t) async {
    await t.pumpWidget(_app('fr'));
    await t.pumpAndSettle();
    final rebook = find.byKey(const ValueKey('detail-rebook'));
    await t.ensureVisible(rebook);
    await t.pumpAndSettle();
    await t.tap(rebook);
    await t.pumpAndSettle();
    expect(find.text('BOOKING PAGE'), findsOneWidget);
  });

  for (final locale in ['fr', 'en', 'es']) {
    testWidgets('no overflow on a phone at 200 percent text, $locale', (
      t,
    ) async {
      t.view.physicalSize = const Size(375, 812);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({'movik_locale': locale});
      await t.pumpWidget(_app(locale, scale: 2));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('detail-title')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
