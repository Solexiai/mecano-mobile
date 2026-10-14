import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/src/io_client.dart' as http_io;
import 'package:movik_connect/backend/backend_bootstrap.dart';
import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/driver_location.dart';
import 'package:movik_connect/backend/models/driver_location_history_point.dart';
import 'package:movik_connect/backend/repositories/location_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/widgets/live_tracking_map.dart';
import '../helpers/gps_offline_transport.dart';
import 'live_tracking_identity_test.dart' as fixtures;

late DateTime clock;
const rawMessage = 'SIMULATED_INTERNAL_DETAIL_DO_NOT_DISPLAY';
const messages = {
  'fr': [
    'Accès à la position refusé.',
    'Les données de suivi sont momentanément indisponibles.',
    'Accès au trajet refusé.',
    'Le trajet est momentanément indisponible.',
  ],
  'en': [
    'Access to the position was denied.',
    'Tracking data is temporarily unavailable.',
    'Access to the route was denied.',
    'The route is temporarily unavailable.',
  ],
  'es': [
    'Acceso a la posición denegado.',
    'Los datos de seguimiento no están disponibles temporalmente.',
    'Acceso al trayecto denegado.',
    'El trayecto no está disponible temporalmente.',
  ],
};
FirebaseException failure(String code, {String plugin = 'cloud_firestore'}) =>
    FirebaseException(plugin: plugin, code: code, message: rawMessage);
DriverLocation point({
  String driver = 'sim-driver',
  String mission = 'sim-A',
  Duration age = Duration.zero,
}) => DriverLocation(
  driverId: driver,
  activeDeliveryId: mission,
  latitude: 45.4,
  longitude: -72.7,
  updatedAt: clock.subtract(age),
);
List<DriverLocationHistoryPoint> history({String mission = 'sim-A'}) =>
    [45.1, 45.2]
        .map(
          (lat) => DriverLocationHistoryPoint(
            deliveryId: mission,
            latitude: lat,
            longitude: -72.7,
            recordedAt: clock.subtract(const Duration(seconds: 10)),
          ),
        )
        .toList();
Widget screen({
  String driver = 'sim-driver',
  String mission = 'sim-A',
  String locale = 'fr',
  double scale = 1,
}) => MaterialApp(
  home: Scaffold(
    body: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: LiveTrackingMap(
        driverId: driver,
        missionId: mission,
        now: () => clock,
        t: (key) => AppStrings.t(key, locale),
      ),
    ),
  ),
);
Finder get marker => find.byIcon(Icons.local_shipping);
Finder get waiting => find.text('En attente du signal GPS du chauffeur…');
Finder get stale => find.textContaining('Position non actualisée');
Future<void> frames(WidgetTester t) async {
  await t.pump();
  await t.pump();
  await t.pump();
}

Future<fixtures.Locations> mount(WidgetTester t) async {
  final repo = fixtures.Locations();
  BackendLocator.locationRepositoryOverride = repo;
  addTearDown(() async {
    await t.pumpWidget(const SizedBox.shrink());
    await frames(t);
    // Le scénario peut déjà avoir fermé ses contrôleurs dans la zone du test.
    for (final c in [...repo.current.values, ...repo.history.values]) {
      if (!c.isClosed) await c.close();
      expect(c.hasListener, isFalse);
    }
    expect(t.takeException(), isNull);
  });
  await t.pumpWidget(screen());
  await frames(t);
  return repo;
}

Future<void> emit(
  WidgetTester t,
  fixtures.Locations repo,
  DriverLocation? value,
) async {
  repo.position(value?.driverId ?? 'sim-driver').add(value);
  await frames(t);
}

Future<void> advance(WidgetTester t, Duration duration) async {
  clock = clock.add(duration);
  await t.pump(duration);
  await frames(t);
}

void expectNoRawError() =>
    expect(find.textContaining(rawMessage), findsNothing);
void main() => offlineTests(() {
  setUp(() {
    clock = DateTime.utc(2026, 10, 10, 13);
    expect(BackendBootstrap.status.isConfigured, isFalse);
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });
  tearDown(() => BackendLocator.locationRepositoryOverride = null);
  offlineTest(
    'L isolation: memory client and denied network fallbacks',
    () async {
      expect(http.Client(), isA<MemoryOnlyClient>());
      expect(() => http_io.createClient(), throwsStateError);
      expect(() => HttpClient(), throwsStateError);
    },
  );
  offlineWidgetTest(
    'L initial position loading is not an error or missing GPS',
    (t) async {
      await mount(t);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(waiting, findsNothing);
      for (final text in messages['fr']!) {
        expect(find.text(text), findsNothing);
      }
    },
  );
  offlineWidgetTest('L null position is a real waiting state', (t) async {
    final repo = await mount(t);
    await emit(t, repo, null);
    expect(waiting, findsOneWidget);
    expect(marker, findsNothing);
    for (final text in messages['fr']!) {
      expect(find.text(text), findsNothing);
    }
  });
  offlineWidgetTest(
    'L intentionally unconfigured repository preserves waiting behavior',
    (t) async {
      BackendLocator.locationRepositoryOverride =
          const NotConfiguredLocationRepository();
      await t.pumpWidget(screen());
      await frames(t);
      expect(waiting, findsOneWidget);
      expect(marker, findsNothing);
      for (final text in messages['fr']!) {
        expect(find.text(text), findsNothing);
      }
      await t.pumpWidget(const SizedBox.shrink());
      await frames(t);
    },
  );
  offlineWidgetTest('L fresh position and empty history are not errors', (
    t,
  ) async {
    final repo = await mount(t);
    await emit(t, repo, point());
    repo.points('sim-driver', 'sim-A').add([]);
    await frames(t);
    expect(marker, findsOneWidget);
    expect(waiting, findsNothing);
    expect(find.byType(PolylineLayer), findsNothing);
    for (final text in messages['fr']!) {
      expect(find.text(text), findsNothing);
    }
  });
  offlineWidgetTest('L stale data keeps date and valid route', (t) async {
    final repo = await mount(t);
    await emit(t, repo, point(age: const Duration(seconds: 61)));
    repo.points('sim-driver', 'sim-A').add(history());
    await frames(t);
    expect(stale, findsOneWidget);
    expect(marker, findsNothing);
    expect(find.textContaining('Dernière position connue'), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget);
  });
  for (final kind in [
    'permission',
    'unavailable',
    'generic',
    'untyped-permission',
    'other-plugin',
  ]) {
    for (final isHistory in [false, true]) {
      offlineWidgetTest(
        'L ${isHistory ? 'history' : 'position'} typed classification $kind',
        (t) async {
          final repo = await mount(t);
          await emit(t, repo, point());
          final Object error = kind == 'permission'
              ? failure('permission-denied')
              : kind == 'unavailable'
              ? failure('unavailable')
              : kind == 'other-plugin'
              ? failure('permission-denied', plugin: 'unrelated')
              : kind == 'untyped-permission'
              ? 'permission-denied $rawMessage'
              : StateError(rawMessage);
          if (isHistory) {
            repo.points('sim-driver', 'sim-A').addError(error);
          } else {
            repo.position('sim-driver').addError(error);
          }
          await frames(t);
          final index = (isHistory ? 2 : 0) + (kind == 'permission' ? 0 : 1);
          expect(find.text(messages['fr']![index]), findsOneWidget);
          expect(
            find.text(
              messages['fr']![(isHistory ? 2 : 0) +
                  (kind == 'permission' ? 1 : 0)],
            ),
            findsNothing,
          );
          expect(waiting, findsNothing);
          expect(marker, isHistory ? findsOneWidget : findsNothing);
          expectNoRawError();
          expect(t.takeException(), isNull);
        },
      );
    }
  }
  offlineWidgetTest(
    'L position-only error preserves allowed history and hides marker',
    (t) async {
      final repo = await mount(t);
      await emit(t, repo, point());
      repo.points('sim-driver', 'sim-A').add(history());
      await frames(t);
      repo.position('sim-driver').addError(failure('unavailable'));
      await frames(t);
      expect(find.text(messages['fr']![1]), findsOneWidget);
      expect(marker, findsNothing);
      expect(waiting, findsNothing);
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(find.text(messages['fr']![3]), findsNothing);
    },
  );
  offlineWidgetTest(
    'L history error after route hides route; position expires normally',
    (t) async {
      final repo = await mount(t);
      await emit(t, repo, point());
      repo.points('sim-driver', 'sim-A').add(history());
      await frames(t);
      expect(find.byType(PolylineLayer), findsOneWidget);
      repo.points('sim-driver', 'sim-A').addError(failure('unavailable'));
      await frames(t);
      expect(find.text(messages['fr']![3]), findsOneWidget);
      expect(find.byType(PolylineLayer), findsNothing);
      expect(marker, findsOneWidget);
      await advance(t, const Duration(seconds: 61));
      expect(stale, findsOneWidget);
      expect(marker, findsNothing);
      expect(find.text(messages['fr']![3]), findsOneWidget);
    },
  );
  offlineWidgetTest('L error then recovery then new error then recovery', (
    t,
  ) async {
    final repo = await mount(t);
    await emit(t, repo, point());
    repo.position('sim-driver').addError(failure('permission-denied'));
    await frames(t);
    expect(find.text(messages['fr']![0]), findsOneWidget);
    expect(marker, findsNothing);
    await emit(t, repo, point());
    expect(find.text(messages['fr']![0]), findsNothing);
    expect(marker, findsOneWidget);
    repo.position('sim-driver').addError(StateError(rawMessage));
    await frames(t);
    expect(find.text(messages['fr']![1]), findsOneWidget);
    expect(marker, findsNothing);
    await emit(t, repo, point());
    expect(find.text(messages['fr']![1]), findsNothing);
    expect(marker, findsOneWidget);
  });
  offlineWidgetTest(
    'L old measure after error keeps original freshness deadline',
    (t) async {
      final repo = await mount(t);
      final old = point();
      await emit(t, repo, old);
      await advance(t, const Duration(seconds: 30));
      repo.position('sim-driver').addError(failure('unavailable'));
      await frames(t);
      expect(find.text(messages['fr']![1]), findsOneWidget);
      await advance(t, const Duration(seconds: 31));
      await emit(t, repo, old);
      expect(stale, findsOneWidget);
      expect(marker, findsNothing);
      expect(find.text(messages['fr']![1]), findsNothing);
      await emit(t, repo, point());
      expect(marker, findsOneWidget);
      expect(stale, findsNothing);
    },
  );
  offlineWidgetTest('L history recovers without losing fresh position', (
    t,
  ) async {
    final repo = await mount(t);
    await emit(t, repo, point());
    repo.points('sim-driver', 'sim-A').addError(failure('permission-denied'));
    await frames(t);
    expect(find.text(messages['fr']![2]), findsOneWidget);
    repo.points('sim-driver', 'sim-A').add(history());
    await frames(t);
    expect(find.text(messages['fr']![2]), findsNothing);
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(marker, findsOneWidget);
  });
  for (final changeDriver in [false, true]) {
    offlineWidgetTest('L scope change during errors driver=$changeDriver', (
      t,
    ) async {
      final repo = await mount(t);
      await emit(t, repo, point());
      repo.position('sim-driver').addError(failure('permission-denied'));
      repo.points('sim-driver', 'sim-A').addError(failure('permission-denied'));
      await frames(t);
      expect(find.text(messages['fr']![0]), findsOneWidget);
      final driver = changeDriver ? 'sim-new' : 'sim-driver',
          mission = changeDriver ? 'sim-A' : 'sim-B';
      await t.pumpWidget(screen(driver: driver, mission: mission));
      await frames(t);
      for (final text in messages['fr']!) {
        expect(find.text(text), findsNothing);
      }
      expect(marker, findsNothing);
      expect(repo.points('sim-driver', 'sim-A').hasListener, isFalse);
      repo.points('sim-driver', 'sim-A').add(history());
      repo.position('sim-driver').add(point());
      await frames(t);
      expect(marker, findsNothing);
      expect(find.byType(PolylineLayer), findsNothing);
      await emit(t, repo, point(driver: driver, mission: mission));
      expect(marker, findsOneWidget);
      repo.points(driver, mission).add(history(mission: mission));
      await frames(t);
      expect(find.byType(PolylineLayer), findsOneWidget);
    });
  }
  offlineWidgetTest(
    'L closed error streams keep explicit error and dispose cleanly',
    (t) async {
      final repo = await mount(t);
      await emit(t, repo, point());
      repo.position('sim-driver').addError(failure('permission-denied'));
      repo.points('sim-driver', 'sim-A').addError(failure('unavailable'));
      await frames(t);
      await repo.position('sim-driver').close();
      await repo.points('sim-driver', 'sim-A').close();
      await frames(t);
      expect(find.text(messages['fr']![0]), findsOneWidget);
      expect(find.text(messages['fr']![3]), findsOneWidget);
      expect(marker, findsNothing);
      expect(waiting, findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
      await frames(t);
      await advance(t, const Duration(minutes: 5));
      expect(t.takeException(), isNull);
    },
  );
  offlineWidgetTest('L closed valid stream expires without any new event', (
    t,
  ) async {
    final repo = await mount(t);
    await emit(t, repo, point());
    await repo.position('sim-driver').close();
    await frames(t);
    await advance(t, const Duration(seconds: 61));
    expect(stale, findsOneWidget);
    expect(marker, findsNothing);
  });
  for (final locale in ['fr', 'en', 'es']) {
    offlineWidgetTest('L mobile $locale both errors text 200 percent', (
      t,
    ) async {
      final repo = await mount(t);
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(375, 812);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(screen(locale: locale, scale: 2));
      await frames(t);
      for (final deniedPosition in [true, false]) {
        repo
            .position('sim-driver')
            .addError(
              failure(deniedPosition ? 'permission-denied' : 'unavailable'),
            );
        repo
            .points('sim-driver', 'sim-A')
            .addError(
              failure(deniedPosition ? 'unavailable' : 'permission-denied'),
            );
        await frames(t);
        final positionMessage = find.text(
              messages[locale]![deniedPosition ? 0 : 1],
            ),
            historyMessage = find.text(
              messages[locale]![deniedPosition ? 3 : 2],
            );
        expect(positionMessage, findsOneWidget);
        expect(historyMessage, findsOneWidget);
        for (final finder in [positionMessage, historyMessage]) {
          final rect = t.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(375));
          expect(rect.bottom, lessThanOrEqualTo(812));
        }
        expect(
          t.getRect(historyMessage).top,
          greaterThanOrEqualTo(t.getRect(positionMessage).bottom),
        );
        expectNoRawError();
        expect(t.takeException(), isNull);
      }
    });
  }
});
