import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/src/io_client.dart' as http_io;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movik_connect/backend/backend_bootstrap.dart';
import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/models/driver_location.dart';
import 'package:movik_connect/backend/models/driver_location_history_point.dart';
import 'package:movik_connect/backend/repositories/location_repository.dart';
import 'package:movik_connect/backend/repositories/mission_repository.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/customer/customer_tracking_screen.dart';
import 'package:movik_connect/widgets/live_tracking_map.dart';
import '../helpers/gps_offline_transport.dart';
import 'package:movik_connect/l10n/app_strings.dart';

class Locations extends Fake implements LocationRepository {
  final current = <String, StreamController<DriverLocation?>>{};
  final history =
      <String, StreamController<List<DriverLocationHistoryPoint>>>{};
  final historyCalls = <String>[];
  StreamController<DriverLocation?> position(String id) =>
      current.putIfAbsent(id, () => StreamController.broadcast());
  StreamController<List<DriverLocationHistoryPoint>> points(
    String driver,
    String mission,
  ) => history.putIfAbsent(
    '$driver|$mission',
    () => StreamController.broadcast(),
  );
  @override
  Stream<DriverLocation?> watchDriverLocation(String driverId) =>
      position(driverId).stream;
  @override
  Stream<List<DriverLocationHistoryPoint>> watchDriverLocationHistory(
    String driverId, {
    required String missionId,
  }) {
    historyCalls.add('$driverId|$missionId');
    return points(driverId, missionId).stream;
  }

  Future<void> close() async {
    for (final c in current.values) {
      await c.close();
    }
    for (final c in history.values) {
      await c.close();
    }
  }
}

class Missions extends Fake implements MissionRepository {
  final DeliveryMission value;
  Missions(this.value);
  late final stream = Stream<DeliveryMission?>.value(value).asBroadcastStream();
  @override
  Stream<DeliveryMission?> watchMission(String id) => stream;
}

DriverLocation location({
  String driver = 'sim-driver',
  String? mission = 'sim-A',
  DateTime? time,
  double latitude = 45.4,
}) => DriverLocation(
  driverId: driver,
  activeDeliveryId: mission,
  latitude: latitude,
  longitude: -72.7,
  updatedAt: time ?? DateTime.now().subtract(const Duration(seconds: 2)),
);
DriverLocationHistoryPoint point(
  String mission,
  double lat, {
  DateTime? time,
}) => DriverLocationHistoryPoint(
  deliveryId: mission,
  latitude: lat,
  longitude: -72.7,
  recordedAt: time ?? DateTime.now().subtract(const Duration(minutes: 1)),
);
Map<String, dynamic> jsonPosition(dynamic time) => {
  'driver_id': 'sim-driver',
  'active_delivery_id': 'sim-A',
  'latitude': 45.4,
  'longitude': -72.7,
  'updated_at': time,
};
Finder get driverMarker => find.byIcon(Icons.local_shipping);
List<Marker> markers(WidgetTester tester) =>
    tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers;
Widget map({String driver = 'sim-driver', String? mission = 'sim-A'}) =>
    MaterialApp(
      home: Scaffold(
        body: LiveTrackingMap(
          driverId: driver,
          missionId: mission,
          t: (key) => key,
        ),
      ),
    );
Future<void> mount(
  WidgetTester tester,
  Locations repo, {
  String driver = 'sim-driver',
  String? mission = 'sim-A',
}) async {
  BackendLocator.locationRepositoryOverride = repo;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await repo.close();
  });
  await tester.pumpWidget(map(driver: driver, mission: mission));
}

Future<void> emit(
  WidgetTester tester,
  Locations repo,
  DriverLocation? value, {
  String source = 'sim-driver',
}) async {
  repo.position(source).add(value);
  await tester.pump();
  await tester.pumpAndSettle();
}

void main() => offlineTests(() {
  setUp(() {
    expect(BackendBootstrap.status.isConfigured, isFalse);
    SharedPreferences.setMockInitialValues({});
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  tearDown(() {
    BackendLocator.locationRepositoryOverride = null;
    BackendLocator.missionRepositoryOverride = null;
  });
  offlineTest(
    'isolation: memory client and forbidden HTTP fallbacks',
    () async {
      expect(http.Client(), isA<MemoryOnlyClient>());
      expect(() => http_io.createClient(), throwsStateError);
      expect(() => HttpClient(), throwsStateError);
    },
  );
  for (final invalid in [null, 'not-a-date', 12345]) {
    offlineTest('E: current date remains unknown for $invalid', () async {
      final value = DriverLocation.fromJson(jsonPosition(invalid));
      expect(value.updatedAt, isNull);
      expect(value.toJson()['updated_at'], isNull);
    });
    offlineTest('E: history date remains unknown for $invalid', () async {
      final value = DriverLocationHistoryPoint.fromJson({
        'delivery_id': 'sim-A',
        'latitude': 45.4,
        'longitude': -72.7,
        'recorded_at': invalid,
      });
      expect(value.recordedAt, isNull);
    });
  }
  offlineWidgetTest('A: matching driver and mission render the real marker', (
    tester,
  ) async {
    final repo = Locations();
    await mount(tester, repo);
    final value = location();
    await emit(tester, repo, value);
    expect(driverMarker, findsOneWidget);
    expect(markers(tester).single.point.latitude, value.latitude);
    expect(tester.takeException(), isNull);
  });
  for (final other in [
    location(driver: 'sim-other'),
    location(mission: 'sim-B'),
    location(mission: null),
  ]) {
    offlineWidgetTest(
      'B/C: reject incompatible ${other.driverId}/${other.activeDeliveryId}',
      (tester) async {
        final repo = Locations();
        await mount(tester, repo);
        await emit(tester, repo, other);
        expect(driverMarker, findsNothing);
        expect(find.text('tracking_waiting_for_signal'), findsOneWidget);
      },
    );
  }
  for (final mission in <String?>[null, '']) {
    offlineWidgetTest(
      'C: no mission context $mission cannot claim an assigned position',
      (tester) async {
        final repo = Locations();
        await mount(tester, repo, mission: mission);
        await emit(tester, repo, location());
        expect(driverMarker, findsNothing);
        expect(repo.historyCalls, isEmpty);
      },
    );
  }
  offlineWidgetTest('D: replace A by B without retaining A position or route', (
    tester,
  ) async {
    final repo = Locations();
    await mount(tester, repo);
    await emit(tester, repo, location());
    repo.points('sim-driver', 'sim-A').add([
      point('sim-A', 45.1),
      point('sim-A', 45.2),
    ]);
    await tester.pumpAndSettle();
    expect(driverMarker, findsOneWidget);
    await tester.pumpWidget(map(mission: 'sim-B'));
    await tester.pump();
    expect(driverMarker, findsNothing);
    expect(find.byType(PolylineLayer), findsNothing);
    await emit(tester, repo, location(mission: 'sim-B', latitude: 46));
    expect(markers(tester).single.point.latitude, 46);
  });
  offlineWidgetTest(
    'E: unknown timestamp is not rendered as a current marker',
    (tester) async {
      final repo = Locations();
      await mount(tester, repo);
      await emit(
        tester,
        repo,
        DriverLocation.fromJson(jsonPosition('not-a-date')),
      );
      expect(driverMarker, findsNothing);
    },
  );
  offlineWidgetTest('F: future timestamp is not rendered as a current marker', (
    tester,
  ) async {
    final repo = Locations();
    await mount(tester, repo);
    await emit(
      tester,
      repo,
      location(time: DateTime.now().add(const Duration(days: 1))),
    );
    expect(driverMarker, findsNothing);
  });
  offlineWidgetTest(
    'G: old valid position explicitly displays last-known date',
    (tester) async {
      final repo = Locations();
      await mount(tester, repo);
      final old = DateTime.now().subtract(const Duration(days: 2));
      await emit(tester, repo, location(time: old));
      // Seuil de 60 s approuvé en J : date conservée, marqueur périmé masqué.
      expect(driverMarker, findsNothing);
      expect(find.textContaining('tracking_position_stale'), findsOneWidget);
      expect(
        find.textContaining('tracking_last_known_position'),
        findsOneWidget,
      );
      final local = old.toLocal();
      final date =
          '${local.day.toString().padLeft(2, '0')}/'
          '${local.month.toString().padLeft(2, '0')}/${local.year}';
      expect(find.textContaining(date), findsOneWidget);
    },
  );
  offlineWidgetTest('H: absent GPS remains an honest waiting state', (
    tester,
  ) async {
    final repo = Locations();
    await mount(tester, repo);
    await emit(tester, repo, null);
    expect(driverMarker, findsNothing);
    expect(find.text('tracking_waiting_for_signal'), findsOneWidget);
  });
  offlineWidgetTest('I: route filters mission B and sorts A chronologically', (
    tester,
  ) async {
    final repo = Locations();
    await mount(tester, repo);
    await emit(tester, repo, location());
    final now = DateTime.now();
    repo.points('sim-driver', 'sim-A').add([
      point('sim-A', 45.2, time: now.subtract(const Duration(minutes: 1))),
      point('sim-B', 10),
      point('sim-A', 45.1, time: now.subtract(const Duration(minutes: 2))),
    ]);
    await tester.pumpAndSettle();
    final points = tester
        .widget<PolylineLayer>(find.byType(PolylineLayer))
        .polylines
        .single
        .points;
    expect(points.map((p) => p.latitude).toList(), [45.1, 45.2]);
  });
  offlineWidgetTest(
    'J: driver switch drops previous marker and same-mission route',
    (tester) async {
      final repo = Locations();
      await mount(tester, repo);
      await emit(tester, repo, location());
      repo.points('sim-driver', 'sim-A').add([
        point('sim-A', 45.1),
        point('sim-A', 45.2),
      ]);
      await tester.pumpAndSettle();
      await tester.pumpWidget(map(driver: 'sim-other'));
      await tester.pump();
      expect(driverMarker, findsNothing);
      expect(find.byType(PolylineLayer), findsNothing);
      repo.position('sim-driver').add(location(latitude: 10));
      await tester.pump();
      expect(driverMarker, findsNothing);
      await emit(
        tester,
        repo,
        location(driver: 'sim-other', latitude: 46),
        source: 'sim-other',
      );
      expect(markers(tester).single.point.latitude, 46);
    },
  );
  offlineWidgetTest(
    'J: incompatible update removes a previously valid marker',
    (tester) async {
      final repo = Locations();
      await mount(tester, repo);
      await emit(tester, repo, location());
      expect(driverMarker, findsOneWidget);
      await emit(tester, repo, location(mission: 'sim-B'));
      expect(driverMarker, findsNothing);
    },
  );
  offlineWidgetTest(
    'D: real customer screen rejects a relinked position predating assignment',
    (tester) async {
      final repo = Locations();
      BackendLocator.locationRepositoryOverride = repo;
      final now = DateTime.now();
      final mission = DeliveryMission(
        id: 'sim-B',
        customerId: 'sim-customer',
        driverId: 'sim-driver',
        itemCategoryKey: 'cat_furniture',
        description: 'SIMULATION',
        requiredVehicleCategory: VehicleCategory.cargoVan,
        status: MissionStatus.assigned,
        pricingVersion: 'SIMULATION',
        createdAt: now.subtract(const Duration(days: 1)),
        acceptedAt: now.subtract(const Duration(minutes: 1)),
      );
      BackendLocator.missionRepositoryOverride = Missions(mission);
      final auth = FirebaseAuthProvider(backendConfigured: false)
        ..debugForceSignedIn = true
        ..debugForceUid = 'sim-customer';
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await repo.close();
        auth.dispose();
      });
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>(
              create: (_) => LocaleProvider(),
            ),
            ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
          ],
          child: const MaterialApp(
            home: CustomerTrackingScreen(missionId: 'sim-B'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await emit(
        tester,
        repo,
        location(
          mission: 'sim-B',
          time: now.subtract(const Duration(minutes: 5)),
        ),
      );
      expect(find.byType(FlutterMap), findsNothing);
      await emit(
        tester,
        repo,
        location(
          mission: 'sim-B',
          time: now.subtract(const Duration(seconds: 1)),
        ),
      );
      expect(markers(tester), hasLength(1));
    },
  );
  offlineWidgetTest(
    'I: undated and future history points do not enter the route',
    (tester) async {
      final repo = Locations();
      await mount(tester, repo);
      await emit(tester, repo, location());
      final now = DateTime.now();
      repo.points('sim-driver', 'sim-A').add([
        point('sim-A', 45.1, time: now.subtract(const Duration(minutes: 2))),
        DriverLocationHistoryPoint.fromJson({
          'delivery_id': 'sim-A',
          'latitude': 10,
          'longitude': 20,
          'recorded_at': 'invalid',
        }),
        point('sim-A', 20, time: now.add(const Duration(days: 1))),
        point('sim-A', 45.2, time: now.subtract(const Duration(minutes: 1))),
      ]);
      await tester.pumpAndSettle();
      final line = tester
          .widget<PolylineLayer>(find.byType(PolylineLayer))
          .polylines
          .single;
      expect(line.points.map((p) => p.latitude).toList(), [45.1, 45.2]);
    },
  );

  offlineWidgetTest(
    'G: date is numeric and readable in FR EN ES at 200 percent',
    (tester) async {
      final repo = Locations();
      await mount(tester, repo);
      final time = DateTime(2026, 1, 2, 9, 4);
      for (final entry in [('fr', 375.0), ('en', 430.0), ('es', 1440.0)]) {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(entry.$2, 932);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(2)),
                child: LiveTrackingMap(
                  driverId: 'sim-driver',
                  missionId: 'sim-A',
                  t: (key) => AppStrings.t(key, entry.$1),
                ),
              ),
            ),
          ),
        );
        await emit(tester, repo, location(time: time));
        expect(
          find.textContaining(
            AppStrings.t('tracking_last_known_position', entry.$1),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('02/01/2026'), findsOneWidget);
        expect(find.textContaining('09:04'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );

  offlineWidgetTest(
    'I: a newer history event is compared with its reception time',
    (tester) async {
      final repo = Locations();
      await mount(tester, repo);
      await emit(tester, repo, location());
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 5)),
      );
      final received = DateTime.now();
      repo.points('sim-driver', 'sim-A').add([
        point('sim-A', 45.1, time: received),
        point('sim-A', 45.2, time: received),
      ]);
      await tester.pumpAndSettle();
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(
        tester
            .widget<PolylineLayer>(find.byType(PolylineLayer))
            .polylines
            .single
            .points,
        hasLength(2),
      );
    },
  );
});
