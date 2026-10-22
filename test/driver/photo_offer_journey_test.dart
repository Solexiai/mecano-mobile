import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/repositories/mission_repository.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/dashboard/provider/tabs/provider_jobs_tab.dart';
import '../helpers/booking_test_harness.dart';

class PhotoOffers extends Fake implements MissionRepository {
  final mission = DeliveryMission(
    id: 'photo_mission',
    customerId: 'synthetic_customer',
    itemCategoryKey: 'cat_furniture',
    description: 'Objet fictif',
    requiredVehicleCategory: VehicleCategory.cargoVan,
    status: MissionStatus.offered,
    pricingVersion: 'SIMULATED',
    createdAt: DateTime(2026),
    driverOfferAmount: 0,
    customerTotal: 123.45,
    bookingSnapshot: {
      'vehicle_assessment': 'driver_photo_review',
      'load': {
        'items': [
          {
            'id': 'item',
            'quantity': 1,
            'label': 'Fauteuil fictif',
            'photos': ['booking_photos/synthetic/draft/item/0.jpg'],
            'weight_kg': null,
            'length_cm': null,
            'width_cm': null,
            'height_cm': null,
            'handling_notes': 'Garder les pièces attachées.',
          },
        ],
        'pickup': {},
        'dropoff': {},
        'handlers': 1,
        'equipment': [],
      },
    },
  );
  @override
  Stream<List<DeliveryMission>> watchAvailableMissionsForDriver(String id) =>
      Stream.value([mission]);
  @override
  Stream<DeliveryMission?> watchActiveMissionForDriver(String id) =>
      Stream.value(null);
}

class DriverPhotoApi extends TestBookingApi {
  bool failDecline = false;
  bool missingTerms = false;
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    await super.call(name, data);
    if (name == 'getBookingVehicleForAcceptance') {
      return {
        'vehicle': {'id': 'synthetic_vehicle', 'label': 'Fourgon fictif'},
        if (!missingTerms)
          'offerTerms': {
            'amountMinor': 8065,
            'currency': 'CAD',
            'pricingVersion': 'SIMULATED',
          },
      };
    }
    if (name == 'acceptDelivery') return {'success': true};
    if (name == 'declineDeliveryOffer') {
      if (failDecline) throw StateError('SIMULATED');
      return pending == null ? {'declined': true} : pending!.future;
    }
    throw StateError('Unexpected call: $name');
  }
}

void main() {
  final bytes = File('assets/home/brand_logo.png').readAsBytesSync();
  Future<void> pump(
    WidgetTester t,
    DriverPhotoApi api, {
    String locale = 'fr',
    double scale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({});
    BackendLocator.missionRepositoryOverride = PhotoOffers();
    final auth = BookingTestAuth()..debugForceUid = 'synthetic_driver';
    final locales = LocaleProvider();
    await locales.setLocale(locale);
    final router = GoRouter(
      initialLocation: '/$locale/provider/jobs',
      routes: [
        GoRoute(
          path: '/$locale/provider/jobs',
          builder: (_, __) => Scaffold(
            body: ProviderJobsTab(
              bookingApi: api,
              photoLoader: (_) async => bytes,
            ),
          ),
        ),
        GoRoute(
          path: '/$locale/provider/mission/:id',
          builder: (_, s) =>
              Scaffold(body: Text('ACTIVE:${s.pathParameters['id']}')),
        ),
      ],
    );
    await t.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
          ChangeNotifierProvider<LocaleProvider>.value(value: locales),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  tearDown(() => BackendLocator.missionRepositoryOverride = null);
  testWidgets('driver sees cargo, chooses actual vehicle and accepts once', (
    t,
  ) async {
    final api = DriverPhotoApi();
    await pump(t, api);
    expect(find.textContaining('Garder les pièces attachées.'), findsOneWidget);
    final accept = find.byType(ElevatedButton).last;
    await t.ensureVisible(accept);
    await t.tap(accept);
    // The confirmation dialog intentionally leaves the underlying accept spinner active.
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Fourgon fictif'), findsOneWidget);
    expect(find.textContaining('80.65 CAD'), findsOneWidget);
    await t.tap(find.text('J’utilise ce véhicule'));
    await t.pumpAndSettle();
    expect(api.calls.where((x) => x == 'acceptDelivery'), hasLength(1));
    expect(api.payloads.last, {
      'missionId': 'photo_mission',
      'vehicleId': 'synthetic_vehicle',
      'expectedDriverOfferMinor': 8065,
    });
    expect(find.text('ACTIVE:photo_mission'), findsOneWidget);
    expect(t.takeException(), isNull);
    await disposeBooking(t);
  });
  testWidgets('missing remuneration never permits acceptance', (t) async {
    final api = DriverPhotoApi()..missingTerms = true;
    await pump(t, api);
    expect(find.text('0\$'), findsNothing);
    final accept = find.byType(ElevatedButton).last;
    await t.ensureVisible(accept);
    await t.tap(accept);
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsNothing);
    expect(api.calls, isNot(contains('acceptDelivery')));
    await disposeBooking(t);
  });
  testWidgets(
    'driver decline waits for server and prevents repeated requests',
    (t) async {
      final api = DriverPhotoApi()..pending = Completer();
      await pump(t, api);
      final decline = find.byKey(const ValueKey('decline-offer-photo_mission'));
      await t.ensureVisible(decline);
      await t.pumpAndSettle();
      final action = t.widget<OutlinedButton>(decline).onPressed!;
      action();
      action();
      await t.pump();
      expect(api.calls.where((x) => x == 'declineDeliveryOffer'), hasLength(1));
      expect(t.widget<OutlinedButton>(decline).onPressed, isNull);
      expect(
        t.widget<ElevatedButton>(find.byType(ElevatedButton).last).onPressed,
        isNull,
      );
      api.pending!.complete({'declined': true});
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('decline-offer-photo_mission')),
        findsNothing,
      );
      expect(api.calls, isNot(contains('acceptDelivery')));
      expect(t.takeException(), isNull);
      await disposeBooking(t);
    },
  );
  testWidgets('decline failure preserves offer and allows retry', (t) async {
    final api = DriverPhotoApi()..failDecline = true;
    await pump(t, api);
    await tapBooking(t, 'Refuser cette demande');
    expect(
      find.text('Le refus n’a pas été enregistré. Réessayez.'),
      findsOneWidget,
    );
    api.failDecline = false;
    await tapBooking(t, 'Refuser cette demande');
    expect(api.calls.where((x) => x == 'declineDeliveryOffer'), hasLength(2));
    expect(
      find.byKey(const ValueKey('decline-offer-photo_mission')),
      findsNothing,
    );
    expect(t.takeException(), isNull);
    await disposeBooking(t);
  });
  for (final locale in ['fr', 'en', 'es']) {
    for (final format in [
      (375.0, 812.0, 1.0),
      (430.0, 932.0, 1.0),
      (768.0, 1024.0, 1.0),
      (1440.0, 900.0, 1.0),
      (375.0, 812.0, 2.0),
    ]) {
      testWidgets('photo offer $locale $format', (t) async {
        t.view.physicalSize = Size(format.$1, format.$2);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await pump(t, DriverPhotoApi(), locale: locale, scale: format.$3);
        expect(find.byType(Image), findsOneWidget);
        final label = locale == 'fr'
            ? 'Refuser cette demande'
            : locale == 'en'
            ? 'Decline this request'
            : 'Rechazar esta solicitud';
        expect(find.text(label), findsOneWidget);
        await t.ensureVisible(find.text(label));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        final accept = find.byType(ElevatedButton).last;
        await t.ensureVisible(accept);
        await t.tap(accept);
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
        expect(find.textContaining('80.65 CAD'), findsOneWidget);
        expect(t.takeException(), isNull);
        final back = find.widgetWithText(
          TextButton,
          locale == 'fr'
              ? 'Retour'
              : locale == 'en'
              ? 'Back'
              : 'Volver',
        );
        await t.ensureVisible(back);
        await t.tap(back);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await disposeBooking(t);
      });
    }
  }
}
