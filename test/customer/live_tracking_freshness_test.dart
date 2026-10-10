import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/src/io_client.dart' as http_io;
import 'package:movik_connect/backend/backend_bootstrap.dart';
import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/driver_location.dart';
import 'package:movik_connect/backend/models/driver_location_history_point.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/widgets/live_tracking_map.dart';
import '../helpers/gps_offline_transport.dart';
import 'live_tracking_identity_test.dart' as fixtures;

late DateTime now;
DriverLocation position({
  Duration age = Duration.zero,
  String driver = 'sim-driver',
  String mission = 'sim-A',
}) => DriverLocation(
  driverId: driver,
  activeDeliveryId: mission,
  latitude: 45.4,
  longitude: -72.7,
  updatedAt: now.subtract(age),
);
Widget screen({
  String driver = 'sim-driver',
  String mission = 'sim-A',
  DateTime? acceptedAt,
  String locale = 'fr',
  double scale = 1,
}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: LiveTrackingMap(
        driverId: driver,
        missionId: mission,
        acceptedAt: acceptedAt,
        now: () => now,
        t: (key) => AppStrings.t(key, locale),
      ),
    ),
  ),
);
Finder get marker => find.byIcon(Icons.local_shipping);
Finder get stale => find.textContaining('Position non actualisée');
Future<fixtures.Locations> mount(
  WidgetTester tester, {
  DateTime? acceptedAt,
}) async {
  final repo = fixtures.Locations();
  BackendLocator.locationRepositoryOverride = repo;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await repo.close();
    expect(tester.takeException(), isNull);
  });
  await tester.pumpWidget(screen(acceptedAt: acceptedAt));
  await tester.pump();
  return repo;
}

Future<void> emit(
  WidgetTester tester,
  fixtures.Locations repo,
  DriverLocation? value, {
  String driver = 'sim-driver',
}) async {
  repo.position(driver).add(value);
  await tester.pump();
  await tester.pump();
  // Le recentrage post-frame de flutter_map rend le marqueur à la frame suivante.
  await tester.pump();
}

Future<void> advance(WidgetTester tester, Duration duration) async {
  now = now.add(duration);
  await tester.pump(duration);
  await tester.pump();
}

void main() => offlineTests(() {
  setUp(() {
    now = DateTime.utc(2026, 10, 9, 17);
    expect(BackendBootstrap.status.isConfigured, isFalse);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  tearDown(() => BackendLocator.locationRepositoryOverride = null);
  offlineTest('J isolation: memory transport and denied fallbacks', () async {
    expect(http.Client(), isA<MemoryOnlyClient>());
    expect(() => http_io.createClient(), throwsStateError);
    expect(() => HttpClient(), throwsStateError);
  });
  for (final seconds in [59, 60, 61]) {
    offlineWidgetTest('J age $seconds seconds', (tester) async {
      final repo = await mount(tester);
      await emit(tester, repo, position(age: Duration(seconds: seconds)));
      expect(marker, seconds <= 60 ? findsOneWidget : findsNothing);
      expect(stale, seconds <= 60 ? findsNothing : findsOneWidget);
      expect(find.textContaining('Dernière position connue'), findsOneWidget);
    });
  }
  offlineWidgetTest('J strict boundary without any new Firestore event', (
    tester,
  ) async {
    final repo = await mount(tester);
    await emit(tester, repo, position());
    await advance(tester, const Duration(seconds: 59));
    expect(marker, findsOneWidget);
    await advance(tester, const Duration(seconds: 1));
    expect(marker, findsOneWidget);
    expect(stale, findsNothing);
    await advance(tester, const Duration(microseconds: 1));
    expect(marker, findsNothing);
    expect(stale, findsOneWidget);
  });
  offlineWidgetTest(
    'J silence for minutes preserves dated history without active marker',
    (tester) async {
      final repo = await mount(tester);
      await emit(tester, repo, position());
      repo.points('sim-driver', 'sim-A').add([
        DriverLocationHistoryPoint(
          deliveryId: 'sim-A',
          latitude: 45.1,
          longitude: -72,
          recordedAt: now.subtract(const Duration(seconds: 20)),
        ),
        DriverLocationHistoryPoint(
          deliveryId: 'sim-A',
          latitude: 45.2,
          longitude: -72,
          recordedAt: now.subtract(const Duration(seconds: 10)),
        ),
      ]);
      await tester.pump();
      await tester.pump();
      final known = tester
          .widget<Text>(find.textContaining('Dernière position connue'))
          .data!;
      await advance(tester, const Duration(minutes: 5));
      expect(marker, findsNothing);
      expect(stale, findsOneWidget);
      expect(find.textContaining(known), findsOneWidget);
      final line = tester
          .widget<PolylineLayer>(find.byType(PolylineLayer))
          .polylines
          .single;
      expect(line.points.map((p) => p.latitude).toList(), [45.1, 45.2]);
    },
  );
  offlineWidgetTest('J fresh recovery resets expiry and clears warning', (
    tester,
  ) async {
    final repo = await mount(tester);
    await emit(tester, repo, position(age: const Duration(seconds: 61)));
    expect(stale, findsOneWidget);
    await emit(tester, repo, position());
    expect(marker, findsOneWidget);
    expect(stale, findsNothing);
    await advance(tester, const Duration(seconds: 30));
    await emit(tester, repo, position());
    await advance(tester, const Duration(seconds: 31));
    expect(marker, findsOneWidget);
    expect(stale, findsNothing);
    await advance(tester, const Duration(seconds: 30));
    expect(marker, findsNothing);
    expect(stale, findsOneWidget);
  });
  offlineWidgetTest('J replaying an old timestamp never renews freshness', (
    tester,
  ) async {
    final repo = await mount(tester);
    final old = position();
    await emit(tester, repo, old);
    await advance(tester, const Duration(seconds: 61));
    await emit(tester, repo, old);
    expect(marker, findsNothing);
    expect(stale, findsOneWidget);
  });
  for (final changeDriver in [false, true]) {
    offlineWidgetTest(
      'J scope change driver=$changeDriver cancels old expiry',
      (tester) async {
        final repo = await mount(tester);
        await emit(tester, repo, position());
        await advance(tester, const Duration(seconds: 30));
        final driver = changeDriver ? 'sim-other' : 'sim-driver';
        final mission = changeDriver ? 'sim-A' : 'sim-B';
        await tester.pumpWidget(screen(driver: driver, mission: mission));
        await tester.pump();
        expect(marker, findsNothing);
        expect(stale, findsNothing);
        await emit(
          tester,
          repo,
          position(driver: driver, mission: mission),
          driver: driver,
        );
        await advance(tester, const Duration(seconds: 31));
        expect(marker, findsOneWidget);
        expect(stale, findsNothing);
        await advance(tester, const Duration(seconds: 30));
        expect(marker, findsNothing);
        expect(stale, findsOneWidget);
      },
    );
  }
  for (final kind in [
    'unknown',
    'future',
    'before-assignment',
    'wrong-driver',
    'wrong-mission',
  ]) {
    offlineWidgetTest(
      'J incompatible $kind never becomes current or stale valid data',
      (tester) async {
        final accepted = now.subtract(const Duration(seconds: 10));
        final repo = await mount(tester, acceptedAt: accepted);
        final value = DriverLocation(
          driverId: kind == 'wrong-driver' ? 'sim-other' : 'sim-driver',
          activeDeliveryId: kind == 'wrong-mission' ? 'sim-B' : 'sim-A',
          latitude: 45.4,
          longitude: -72.7,
          updatedAt: kind == 'unknown'
              ? null
              : kind == 'future'
              ? now.add(const Duration(hours: 1))
              : kind == 'before-assignment'
              ? accepted.subtract(const Duration(seconds: 1))
              : now,
        );
        await emit(tester, repo, value);
        await advance(tester, const Duration(minutes: 5));
        expect(marker, findsNothing);
        expect(stale, findsNothing);
        expect(
          find.text('En attente du signal GPS du chauffeur…'),
          findsOneWidget,
        );
      },
    );
  }
  offlineWidgetTest('J null signal is distinct from outdated position', (
    tester,
  ) async {
    final repo = await mount(tester);
    await emit(tester, repo, null);
    await advance(tester, const Duration(minutes: 5));
    expect(marker, findsNothing);
    expect(stale, findsNothing);
    expect(find.text('En attente du signal GPS du chauffeur…'), findsOneWidget);
  });
  offlineWidgetTest('J dispose cancels pending timer and old stream', (
    tester,
  ) async {
    final repo = await mount(tester);
    await emit(tester, repo, position());
    expect(repo.position('sim-driver').hasListener, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(repo.position('sim-driver').hasListener, isFalse);
    await advance(tester, const Duration(minutes: 5));
    expect(tester.takeException(), isNull);
  });
  for (final locale in ['fr', 'en', 'es']) {
    offlineWidgetTest('J mobile $locale outdated label at 200 percent', (
      tester,
    ) async {
      final repo = await mount(tester);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 812);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(screen(locale: locale, scale: 2));
      await emit(tester, repo, position(age: const Duration(seconds: 61)));
      final expected = {
        'fr': 'Position non actualisée',
        'en': 'Position not updated',
        'es': 'Posición sin actualizar',
      };
      expect(find.textContaining(expected[locale]!), findsOneWidget);
      expect(
        find.textContaining(
          AppStrings.t('tracking_last_known_position', locale),
        ),
        findsOneWidget,
      );
      expect(marker, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
});
