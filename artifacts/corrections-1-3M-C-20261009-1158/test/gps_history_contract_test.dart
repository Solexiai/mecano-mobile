// P1-M-01 targeted tests: actual product components, only boundaries simulated.
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/src/io_client.dart' as http_io;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movik_connect/backend/backend_bootstrap.dart';
import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/models/driver_location.dart';
import 'package:movik_connect/backend/models/driver_location_history_point.dart';
import 'package:movik_connect/backend/repositories/firebase_location_repository.dart';
import 'package:movik_connect/backend/repositories/location_repository.dart';
import 'package:movik_connect/backend/repositories/mission_repository.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/customer/customer_tracking_screen.dart';
import 'package:movik_connect/screens/driver/driver_active_mission_screen.dart';
import 'package:movik_connect/widgets/live_tracking_map.dart';
import '../../../test/driver/driver_active_mission_gps_lifecycle_test.dart' as lifecycle;
import 'offline_transport.dart';

typedef Json = Map<String, dynamic>;

// No Firebase initialization, platform channel or Functions invocation.
// All unimplemented operations fail.
class _Functions extends Fake implements FirebaseFunctions {}
class _Db extends Fake implements FirebaseFirestore {
  final calls = <String>[];
  final List<Json> rows;
  _Db(this.rows);
  @override
  CollectionReference<Json> collection(String path) {
    calls.add('collection:$path');
    return _Collection(this, path);
  }
}
class _Collection extends Fake implements CollectionReference<Json> {
  final _Db db;
  final String location;
  _Collection(this.db, this.location);
  @override
  DocumentReference<Json> doc([String? path]) {
    db.calls.add('doc:$path');
    return _Doc(db, '$location/$path');
  }
  @override
  dynamic noSuchMethod(Invocation i) {
    if (i.memberName == #where) {
      final field = i.positionalArguments.single;
      final value = i.namedArguments[#isEqualTo];
      db.calls.add('where:$field=$value');
      expect(field, 'delivery_id');
      expect(value, isA<String>());
      return _Query(db, location, value as String);
    }
    // An unfiltered snapshots() cannot succeed in this spy.
    return super.noSuchMethod(i);
  }
}
class _Doc extends Fake implements DocumentReference<Json> {
  final _Db db;
  final String location;
  _Doc(this.db, this.location);
  @override
  CollectionReference<Json> collection(String path) {
    db.calls.add('collection:$location/$path');
    return _Collection(db, '$location/$path');
  }
}
class _Query extends Fake implements Query<Json> {
  final _Db db;
  final String location;
  final String mission;
  _Query(this.db, this.location, this.mission);
  @override
  Stream<QuerySnapshot<Json>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    db.calls.add('snapshots:$location:$mission');
    return Stream.value(_Snapshot(db.rows));
  }
}
class _Snapshot extends Fake implements QuerySnapshot<Json> {
  final List<Json> rows;
  _Snapshot(this.rows);
  @override
  List<QueryDocumentSnapshot<Json>> get docs => rows.map(_Row.new).toList();
}
class _Row extends Fake implements QueryDocumentSnapshot<Json> {
  final Json row;
  _Row(this.row);
  @override
  Json data() => row;
}
class _Locations extends Fake implements LocationRepository {
  final historyCalls = <String>[];
  final locationCalls = <String>[];
  final Stream<DriverLocation?> current = Stream.value(null).asBroadcastStream();
  final Map<String, Stream<List<DriverLocationHistoryPoint>>> streams = {};
  final List<DriverLocationHistoryPoint> points;
  _Locations([this.points = const []]);
  @override
  Future<void> reportDriverLocation(DriverLocation location) async {}
  @override
  Stream<DriverLocation?> watchDriverLocation(String driverId) {
    locationCalls.add(driverId);
    return current;
  }
  @override
  Stream<List<DriverLocationHistoryPoint>> watchDriverLocationHistory(
      String driverId, {required String missionId}) {
    historyCalls.add('$driverId|$missionId');
    return streams.putIfAbsent(missionId,
        () => Stream.value(points).asBroadcastStream());
  }
}
class _Missions extends Fake implements MissionRepository {
  final Stream<DeliveryMission?> mission;
  final reads = <String>[];
  _Missions(DeliveryMission value) : mission = Stream.value(value).asBroadcastStream();
  @override
  Stream<DeliveryMission?> watchMission(String missionId) {
    reads.add(missionId);
    return mission;
  }
}
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
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
  offlineTest('isolation: injected transport and forbidden network fallback', () async {
    expect(const bool.fromEnvironment('no_default_http_client'), isTrue);
    expect(http.Client(), isA<MemoryOnlyClient>());
    expect(() => http_io.createClient(), throwsStateError);
    expect(() => HttpClient(), throwsStateError);
  });
  for (final mission in ['sim-mission-A', 'sim-mission-B']) {
    offlineTest('real FirebaseLocationRepository: filtered query before subscription $mission', () async {
      final db = _Db([{
        'delivery_id': mission, 'latitude': 45.0, 'longitude': -72.0,
        'recorded_at': '2026-10-09T10:00:00Z',
      }]);
      final LocationRepository repo =
          FirebaseLocationRepository(firestore: db, functions: _Functions());
      final points = await repo
          .watchDriverLocationHistory('sim-driver', missionId: mission).first;
      expect(db.calls, [
        'collection:driver_locations', 'doc:sim-driver',
        'collection:driver_locations/sim-driver/history',
        'where:delivery_id=$mission',
        'snapshots:driver_locations/sim-driver/history:$mission',
      ]);
      expect(points.single.deliveryId, mission);
      expect(points.single.latitude, 45.0);
      expect(points.single.recordedAt, DateTime.utc(2026, 10, 9, 10));
    });
  }
  for (final mission in <String?>[null, '']) {
    offlineWidgetTest('real LiveTrackingMap: no history for missionId=$mission', (tester) async {
      final repo = _Locations();
      BackendLocator.locationRepositoryOverride = repo;
      final before = offlineTileRequests.length;
      await tester.pumpWidget(MaterialApp(home: Scaffold(body:
        LiveTrackingMap(driverId: 'sim-driver', missionId: mission, t: (key) => key))));
      await tester.pumpAndSettle();
      expect(find.byType(LiveTrackingMap), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(repo.locationCalls, isNotEmpty);
      expect(repo.historyCalls, isEmpty);
      expect(find.byType(PolylineLayer), findsNothing);
      expect(offlineTileRequests.length, greaterThan(before));
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  }
  offlineWidgetTest('real LiveTrackingMap: mission argument, defensive filter and chronological sort', (tester) async {
    final repo = _Locations([
      DriverLocationHistoryPoint(deliveryId: 'sim-A', latitude: 45.2, longitude: -72.2, recordedAt: DateTime.utc(2026, 10, 9, 12)),
      DriverLocationHistoryPoint(deliveryId: 'sim-B', latitude: 10, longitude: 20, recordedAt: DateTime.utc(2026, 10, 9, 11)),
      DriverLocationHistoryPoint(deliveryId: 'sim-A', latitude: 45.1, longitude: -72.1, recordedAt: DateTime.utc(2026, 10, 9, 10)),
    ]);
    BackendLocator.locationRepositoryOverride = repo;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body:
      LiveTrackingMap(driverId: 'sim-driver', missionId: 'sim-A', t: (key) => key))));
    await tester.pumpAndSettle();
    expect(repo.historyCalls, isNotEmpty);
    expect(repo.historyCalls, everyElement('sim-driver|sim-A'));
    final line = tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines.single;
    expect(line.points.map((p) => [p.latitude, p.longitude]).toList(),
        [[45.1, -72.1], [45.2, -72.2]]);
    expect(tester.takeException(), isNull);
    await _unmount(tester);
  });
  for (final driverScreen in [false, true]) {
    offlineWidgetTest('real consumer: ${driverScreen ? "driver" : "customer"} passes mission and driver to map', (tester) async {
      final oldGeo = GeolocatorPlatform.instance;
      GeolocatorPlatform.instance = lifecycle.FakeGeolocatorPlatform();
      addTearDown(() => GeolocatorPlatform.instance = oldGeo);
      final mission = DeliveryMission(
        id: 'sim-A', customerId: 'sim-customer', driverId: 'sim-driver',
        driverDisplayName: 'Chauffeur SIMULATION',
        itemCategoryKey: 'cat_furniture', description: 'Objet fictif',
        requiredVehicleCategory: VehicleCategory.cargoVan,
        status: MissionStatus.assigned, pricingVersion: 'SIMULATION',
        createdAt: DateTime.utc(2026, 10, 9),
        driverOfferAmount: 42, customerTotal: 99,
      );
      final missions = _Missions(mission);
      final locations = _Locations();
      BackendLocator.missionRepositoryOverride = missions;
      BackendLocator.locationRepositoryOverride = locations;
      final auth = FirebaseAuthProvider(backendConfigured: false)
        ..debugForceSignedIn = true
        ..debugForceUid = driverScreen ? 'sim-driver' : 'sim-customer';
      addTearDown(auth.dispose);
      await tester.pumpWidget(MultiProvider(providers: [
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
        ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
      ], child: MaterialApp(home: driverScreen
          ? const DriverActiveMissionScreen(missionId: 'sim-A')
          : const CustomerTrackingScreen(missionId: 'sim-A'))));
      await tester.pumpAndSettle();
      final map = tester.widget<LiveTrackingMap>(find.byType(LiveTrackingMap));
      expect(map.missionId, 'sim-A');
      expect(map.driverId, 'sim-driver');
      expect(missions.reads, everyElement('sim-A'));
      expect(locations.historyCalls, isNotEmpty);
      expect(locations.historyCalls, everyElement('sim-driver|sim-A'));
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  }
});
