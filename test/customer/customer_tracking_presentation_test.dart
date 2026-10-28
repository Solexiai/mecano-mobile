import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movik_connect/backend/backend_bootstrap.dart';
import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/models/driver_location.dart';
import 'package:movik_connect/backend/repositories/mission_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/customer/customer_tracking_screen.dart';
import 'package:movik_connect/screens/delivery/delivery_request_flow_screen.dart';
import 'package:movik_connect/widgets/live_tracking_map.dart';
import '../helpers/booking_test_harness.dart';
import '../helpers/gps_offline_transport.dart';
import 'live_tracking_identity_test.dart' as gps;

class MissionStreams extends Fake implements MissionRepository {
  final controllers = <String, StreamController<DeliveryMission?>>{};
  final calls = <String>[];
  StreamController<DeliveryMission?> channel(String id) => controllers
      .putIfAbsent(id, () => StreamController<DeliveryMission?>.broadcast());
  @override
  Stream<DeliveryMission?> watchMission(String missionId) {
    calls.add(missionId);
    return channel(missionId).stream;
  }

  Future<void> close() async {
    for (final c in controllers.values) {
      await c.close();
    }
  }
}

DeliveryMission mission({
  String id = 'mission_A',
  String customer = 'booking_test',
  MissionStatus status = MissionStatus.searchingDriver,
  String? driver,
  String? driverName,
  String? cancellationReason,
  String? cancelledBy,
}) => DeliveryMission(
  id: id,
  customerId: customer,
  itemCategoryKey: 'cat_furniture',
  description: 'SIMULATION',
  requiredVehicleCategory: VehicleCategory.cargoVan,
  status: status,
  driverId: driver,
  driverDisplayName: driverName,
  pricingVersion: 'TEST',
  createdAt: DateTime(2026, 10, 1),
  acceptedAt: driver == null ? null : DateTime(2026, 10, 1),
  assignmentMode: 'internal_test',
  cancellationReason: cancellationReason,
  cancelledBy: cancelledBy,
);
const reference = {'fr': 'Référence', 'en': 'Reference', 'es': 'Referencia'};
const search = {
  'fr': 'Nous recherchons un chauffeur pour votre livraison.',
  'en': 'We are looking for a driver for your delivery.',
  'es': 'Estamos buscando un conductor para tu entrega.',
};
const noDriver = {
  'fr': 'Aucun chauffeur n’est assigné à cette livraison pour le moment.',
  'en': 'No driver is assigned to this delivery at the moment.',
  'es': 'Por el momento, no hay ningún conductor asignado a esta entrega.',
};
const missingReference = {
  'fr': 'Référence indisponible',
  'en': 'Reference unavailable',
  'es': 'Referencia no disponible',
};
const unavailableStatus = {
  'fr': 'État du suivi indisponible.',
  'en': 'Tracking status unavailable.',
  'es': 'Estado del seguimiento no disponible.',
};
String ref(String id, String locale) => '${reference[locale]} : $id';
String allText(WidgetTester t) =>
    t.widgetList<Text>(find.byType(Text)).map((w) => w.data ?? '').join('\n');
Future<void> frames(WidgetTester t) async {
  await t.pump();
  await t.pump();
  await t.pump();
}

class Harness {
  final MissionStreams repo;
  final gps.Locations locations;
  final GoRouter router;
  Harness(this.repo, this.locations, this.router);
}

Future<Harness> start(
  WidgetTester t, {
  String id = 'mission_A',
  String locale = 'fr',
  Size size = const Size(430, 932),
  double scale = 1,
  bool booking = false,
}) async {
  expect(BackendBootstrap.status.isConfigured, isFalse);
  expect(Firebase.apps, isEmpty);
  SharedPreferences.setMockInitialValues({'movik_locale': locale});
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.platformDispatcher.textScaleFactorTestValue = scale;
  final repo = MissionStreams(), locations = gps.Locations();
  BackendLocator.missionRepositoryOverride = repo;
  BackendLocator.locationRepositoryOverride = locations;
  final auth = BookingTestAuth(), language = LocaleProvider();
  final api = TestBookingApi(),
      storage = MemoryBookingStorage(
        testDraft(step: 3, quote: true)..data['accepted_locale'] = locale,
      );
  final router = GoRouter(
    initialLocation: booking
        ? '/$locale/livraison/demande'
        : '/$locale/livraison/suivi/$id',
    routes: [
      GoRoute(
        path: '/$locale/livraison/demande',
        builder: (_, __) => DeliveryRequestFlowScreen(
          locale: locale,
          api: api,
          storage: storage,
        ),
      ),
      GoRoute(
        path: '/$locale/livraison/suivi/:id',
        builder: (_, s) =>
            CustomerTrackingScreen(missionId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/$locale/dashboard',
        builder: (_, __) => const Scaffold(body: Text('FAKE_DASHBOARD')),
      ),
    ],
  );
  addTearDown(() async {
    await t.pumpWidget(const SizedBox());
    await frames(t);
    await repo.close();
    await locations.close();
    router.dispose();
    BackendLocator.missionRepositoryOverride = null;
    BackendLocator.locationRepositoryOverride = null;
    t.view.resetPhysicalSize();
    t.view.resetDevicePixelRatio();
    t.platformDispatcher.clearTextScaleFactorTestValue();
    expect(Firebase.apps, isEmpty);
    expect(t.takeException(), isNull);
  });
  await t.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<LocaleProvider>.value(value: language),
        ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await frames(t);
  if (booking) {
    await t.pumpAndSettle();
  }
  return Harness(repo, locations, router);
}

Future<void> emit(
  WidgetTester t,
  Harness h,
  DeliveryMission? m, {
  String channel = 'mission_A',
}) async {
  h.repo.channel(channel).add(m);
  await frames(t);
  if (m?.driverId != null && h.locations.current.containsKey(m!.driverId)) {
    h.locations.position(m.driverId!).add(null);
    h.locations.points(m.driverId!, m.id).add([]);
    await frames(t);
  }
}

void layout(WidgetTester t) {
  for (final e in find.byType(RichText).evaluate()) {
    final r = e.renderObject;
    if (r is RenderParagraph) {
      expect(r.didExceedMaxLines, isFalse, reason: r.text.toPlainText());
      final rect = MatrixUtils.transformRect(
        r.getTransformTo(null),
        r.paintBounds,
      );
      expect(
        rect.left,
        greaterThanOrEqualTo(-0.1),
        reason: r.text.toPlainText(),
      );
      expect(
        rect.right,
        lessThanOrEqualTo(t.view.physicalSize.width + 0.1),
        reason: r.text.toPlainText(),
      );
    }
  }
  expect(t.takeException(), isNull);
}

void main() => offlineTests(() {
  offlineTest('O isolation: memory-only transport and no Firebase', () async {
    expect(http.Client(), isA<MemoryOnlyClient>());
    expect(() => HttpClient(), throwsStateError);
    expect(Firebase.apps, isEmpty);
    expect(BackendBootstrap.status.isConfigured, isFalse);
  });
  for (final locale in ['fr', 'en', 'es']) {
    for (final size in [
      (375.0, 812.0, 1.0),
      (430.0, 932.0, 1.0),
      (1440.0, 900.0, 1.0),
      (375.0, 812.0, 2.0),
    ]) {
      for (final state in ['search', 'assigned', 'error']) {
        offlineWidgetTest('O responsive $locale $size $state', (t) async {
          const id =
              'mission_1234567890_abcdefghijklmnopqrstuvwxyz_LONG_REFERENCE';
          final h = await start(
            t,
            id: id,
            locale: locale,
            size: Size(size.$1, size.$2),
            scale: size.$3,
          );
          if (state == 'error') {
            h.repo.channel(id).addError(StateError('SECRET_DETAIL'));
            await frames(t);
            expect(
              find.text(
                AppStrings.t('driver_active_mission_network_error', locale),
              ),
              findsOneWidget,
            );
            expect(allText(t), isNot(contains('SECRET_DETAIL')));
            expect(allText(t), isNot(contains(id)));
          } else {
            await emit(
              t,
              h,
              mission(
                id: id,
                status: state == 'search'
                    ? MissionStatus.searchingDriver
                    : MissionStatus.assigned,
                driver: state == 'assigned' ? 'driver_A' : null,
                driverName: 'Fictitious Driver',
              ),
              channel: id,
            );
            expect(find.text(ref(id, locale)), findsOneWidget);
            if (state == 'search') {
              expect(find.text(search[locale]!), findsOneWidget);
              expect(find.byType(LiveTrackingMap), findsNothing);
            } else {
              expect(find.text('Fictitious Driver'), findsOneWidget);
              expect(
                find.text(AppStrings.t(MissionStatus.assigned.key, locale)),
                findsWidgets,
              );
              expect(find.text(search[locale]!), findsNothing);
            }
          }
          layout(t);
        });
      }
    }
    offlineWidgetTest(
      'O actual receipt to tracking reference and return $locale',
      (t) async {
        final h = await start(t, locale: locale, booking: true);
        final label = locale == 'fr'
            ? 'Confirmer ma demande de livraison'
            : locale == 'en'
            ? 'Confirm my delivery request'
            : 'Confirmar mi solicitud de entrega';
        await tapBooking(t, label);
        expect(find.text(ref('test_mission', locale)), findsOneWidget);
        await t.ensureVisible(
          find.text(
            locale == 'fr'
                ? 'Suivre ma livraison'
                : locale == 'en'
                ? 'Track my delivery'
                : 'Seguir mi entrega',
          ),
        );
        await t.tap(
          find.text(
            locale == 'fr'
                ? 'Suivre ma livraison'
                : locale == 'en'
                ? 'Track my delivery'
                : 'Seguir mi entrega',
          ),
        );
        await frames(t);
        expect(
          h.router.routeInformationProvider.value.uri.path,
          '/$locale/livraison/suivi/test_mission',
        );
        expect(h.repo.calls.last, 'test_mission');
        await emit(t, h, mission(id: 'test_mission'), channel: 'test_mission');
        await t.pumpAndSettle();
        expect(find.text(ref('test_mission', locale)), findsOneWidget);
        expect(find.text(search[locale]!), findsOneWidget);
        await t.tap(find.byIcon(Icons.arrow_back));
        await t.pumpAndSettle();
        expect(find.text('FAKE_DASHBOARD'), findsOneWidget);
        h.router.go('/$locale/livraison/suivi/test_mission');
        await frames(t);
        await emit(t, h, mission(id: 'test_mission'), channel: 'test_mission');
        await t.pumpAndSettle();
        expect(find.text(ref('test_mission', locale)), findsOneWidget);
      },
    );
  }
  for (final driver in [null, '', '   ']) {
    offlineWidgetTest('O assigned status without valid driver $driver', (
      t,
    ) async {
      final h = await start(t);
      await emit(t, h, mission(status: MissionStatus.assigned, driver: driver));
      expect(find.text(ref('mission_A', 'fr')), findsOneWidget);
      expect(find.text(noDriver['fr']!), findsOneWidget);
      expect(find.byType(LiveTrackingMap), findsNothing);
      expect(h.locations.current, isEmpty);
      expect(find.text(search['fr']!), findsNothing);
    });
  }
  for (final state in [
    MissionStatus.offered,
    MissionStatus.cancelled,
    MissionStatus.completed,
    MissionStatus.delivered,
    MissionStatus.disputed,
    MissionStatus.refunded,
    MissionStatus.quoted,
  ]) {
    offlineWidgetTest('O concrete status $state', (t) async {
      final h = await start(t);
      await emit(t, h, mission(status: state));
      expect(find.text(ref('mission_A', 'fr')), findsOneWidget);
      if (state == MissionStatus.offered) {
        expect(find.text(search['fr']!), findsOneWidget);
      } else if (state == MissionStatus.completed) {
        expect(
          find.text(AppStrings.t('customer_tracking_completed_title', 'fr')),
          findsOneWidget,
        );
      } else {
        expect(find.text(AppStrings.t(state.key, 'fr')), findsWidgets);
      }
      expect(find.byType(LiveTrackingMap), findsNothing);
      if (state != MissionStatus.offered) {
        expect(find.text(search['fr']!), findsNothing);
      }
    });
  }
  // CLI-04 / CLI-05 (2026-10-28) : motif d'annulation et suite proposée.
  offlineWidgetTest('O cancelled: reason, fee line absent, book again', (t) async {
    final h = await start(t);
    await emit(t, h, mission(status: MissionStatus.cancelled, cancellationReason: 'customer_request', cancelledBy: 'customer'));
    expect(find.byKey(const ValueKey('tracking-cancelled-view')), findsOneWidget);
    expect(find.text('Vous avez annulé cette demande.'), findsOneWidget);
    expect(find.byKey(const ValueKey('tracking-cancellation-fee')), findsNothing);
    expect(find.byKey(const ValueKey('tracking-rebook')), findsOneWidget);
    await emit(t, h, mission(status: MissionStatus.cancelled, cancelledBy: 'driver'));
    expect(find.textContaining('Le chauffeur a dû annuler'), findsOneWidget);
  });
  offlineWidgetTest('O payment failed: explanation and book again with another card', (t) async {
    final h = await start(t);
    await emit(t, h, mission(status: MissionStatus.paymentFailed));
    expect(find.byKey(const ValueKey('tracking-payment-failed-view')), findsOneWidget);
    expect(find.text(AppStrings.t('mission_status_paymentfailed', 'fr')), findsOneWidget);
    expect(find.textContaining('Utiliser une autre carte'), findsOneWidget);
    expect(find.byKey(const ValueKey('tracking-rebook-new-card')), findsOneWidget);
    expect(find.byType(LiveTrackingMap), findsNothing);
  });
  offlineWidgetTest('O initial loading and disappeared mission', (t) async {
    final h = await start(t);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text(ref('mission_A', 'fr')), findsNothing);
    await emit(t, h, null);
    expect(
      find.text(AppStrings.t('driver_active_mission_not_found', 'fr')),
      findsOneWidget,
    );
    expect(find.byType(LiveTrackingMap), findsNothing);
  });
  offlineWidgetTest('O mismatched mission returned on A stream is never B', (
    t,
  ) async {
    final h = await start(t);
    await emit(
      t,
      h,
      mission(
        id: 'mission_B',
        status: MissionStatus.assigned,
        driver: 'driver_B',
        driverName: 'PRIVATE_B',
      ),
    );
    expect(allText(t), isNot(contains('PRIVATE_B')));
    expect(allText(t), isNot(contains('mission_B')));
    expect(find.byType(LiveTrackingMap), findsNothing);
  });
  offlineWidgetTest(
    'O foreign customer data and reference remain inaccessible',
    (t) async {
      final h = await start(t);
      await emit(
        t,
        h,
        mission(
          customer: 'another_customer',
          driver: 'driver_secret',
          driverName: 'PRIVATE',
        ),
      );
      expect(
        find.text(AppStrings.t('driver_active_mission_access_denied', 'fr')),
        findsOneWidget,
      );
      expect(find.text(ref('mission_A', 'fr')), findsNothing);
      expect(allText(t), isNot(contains('PRIVATE')));
    },
  );
  offlineWidgetTest(
    'O missing reference never reconstructed from requested route',
    (t) async {
      final h = await start(t);
      await emit(t, h, mission(id: ''));
      expect(find.text(missingReference['fr']!), findsOneWidget);
      expect(find.text(ref('mission_A', 'fr')), findsNothing);
      expect(find.byType(LiveTrackingMap), findsNothing);
    },
  );
  for (final raw in ['new_status', null]) {
    offlineWidgetTest('O unsupported raw status $raw remains neutral', (
      t,
    ) async {
      final h = await start(t);
      final m = DeliveryMission.fromJson('mission_A', {
        'customer_id': 'booking_test',
        'status': raw,
      });
      await emit(t, h, m);
      expect(find.text(ref('mission_A', 'fr')), findsOneWidget);
      expect(find.text(unavailableStatus['fr']!), findsOneWidget);
      expect(find.text(search['fr']!), findsNothing);
      expect(find.byType(LiveTrackingMap), findsNothing);
    });
  }
  // TECH-04 : payment_failed est désormais un statut connu du client
  // (autorisation refusée) : son libellé s'affiche, jamais une recherche.
  offlineWidgetTest('O payment_failed shows its own label, no search', (
    t,
  ) async {
    final h = await start(t);
    final m = DeliveryMission.fromJson('mission_A', {
      'customer_id': 'booking_test',
      'status': 'payment_failed',
    });
    await emit(t, h, m);
    expect(find.text(ref('mission_A', 'fr')), findsOneWidget);
    expect(find.text('Paiement refusé'), findsOneWidget);
    expect(find.text(unavailableStatus['fr']!), findsNothing);
    expect(find.text(search['fr']!), findsNothing);
    expect(find.byType(LiveTrackingMap), findsNothing);
  });
  offlineWidgetTest(
    'O changing A to B clears old scope even before B response',
    (t) async {
      final h = await start(t);
      await emit(t, h, mission());
      h.router.go('/fr/livraison/suivi/mission_B');
      await frames(t);
      expect(find.text(ref('mission_A', 'fr')), findsNothing);
      h.repo.channel('mission_A').add(mission());
      await frames(t);
      expect(find.text(ref('mission_A', 'fr')), findsNothing);
      await emit(t, h, mission(id: 'mission_B'), channel: 'mission_B');
      expect(find.text(ref('mission_B', 'fr')), findsOneWidget);
    },
  );
  offlineWidgetTest(
    'O assigned GPS refuses foreign position and permits fresh correct data',
    (t) async {
      final h = await start(t);
      await emit(
        t,
        h,
        mission(
          status: MissionStatus.assigned,
          driver: 'driver_A',
          driverName: 'Driver A',
        ),
      );
      DriverLocation point(String driver, String id) => DriverLocation(
        driverId: driver,
        activeDeliveryId: id,
        latitude: 45.4,
        longitude: -72.7,
        updatedAt: DateTime.now().subtract(const Duration(seconds: 2)),
      );
      for (final p in [
        point('driver_B', 'mission_A'),
        point('driver_A', 'mission_B'),
      ]) {
        h.locations.position('driver_A').add(p);
        await frames(t);
        expect(find.byType(FlutterMap), findsNothing);
      }
      h.locations.position('driver_A').add(point('driver_A', 'mission_A'));
      await frames(t);
      expect(
        t.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        hasLength(1),
      );
      expect(find.text(ref('mission_A', 'fr')), findsOneWidget);
    },
  );
});
