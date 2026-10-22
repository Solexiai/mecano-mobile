import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/driver_vehicle.dart';
import 'package:movik_connect/backend/repositories/driver_repository.dart';
import 'package:movik_connect/l10n/vehicle_review_copy.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/widgets/driver_vehicle_review_card.dart';

class ReviewRepo implements DriverRepository {
  int calls = 0;
  Map<String, dynamic>? capacity;
  bool? approved;
  String? note;
  Object? error;
  Completer<void>? pending;
  @override
  Future<void> reviewDriverVehicle({
    required DriverVehicle vehicle,
    required bool approve,
    Map<String, dynamic>? capacity,
    DateTime? validUntil,
    required String note,
  }) async {
    calls++;
    this.capacity = capacity;
    approved = approve;
    this.note = note;
    if (pending != null) await pending!.future;
    if (error != null) throw error!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

DriverVehicle vehicle({bool verified = false}) => DriverVehicle(
  id: 'synthetic-vehicle',
  driverId: 'synthetic-driver',
  category: VehicleCategory.pickupTruck,
  makeModel: 'SYNTHETIC PICKUP',
  year: 2025,
  plate: 'TEST-ONLY',
  createdAt: DateTime(2025),
  isVerified: verified,
  verifiedCapacity: verified
      ? {
          'length_cm': 250,
          'width_cm': 150,
          'height_cm': 150,
          'opening_width_cm': 140,
          'opening_height_cm': 140,
          'payload_kg': 500,
          'handlers': 2,
          'equipment': <String>[],
          'services': <String>[],
        }
      : null,
  capacityValidUntil: verified ? DateTime(2099) : null,
);
Widget app({String locale = 'fr', double scale = 1, bool verified = false}) =>
    MaterialApp(
      locale: Locale(locale),
      supportedLocales: const [Locale('fr'), Locale('en'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => DriverVehicleReviewCard(
            vehicle: vehicle(verified: verified),
            locale: locale,
            onReviewed: () {},
          ),
        ),
      ),
    );
Future<void> open(WidgetTester tester, String locale) async {
  await tester.tap(find.text(VehicleReviewCopy.text(locale, 'review')));
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, String key, String value) async {
  final f = find.byKey(ValueKey(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.enterText(f, value);
}

Future<void> confirm(WidgetTester tester) async {
  final f = find.byKey(const ValueKey('capacity-confirmation'));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pump();
}

Future<void> fill(WidgetTester tester) async {
  for (final entry in {
    'length_cm': '250',
    'width_cm': '150',
    'height_cm': '150',
    'opening_width_cm': '140',
    'opening_height_cm': '140',
    'payload_kg': '500',
  }.entries) {
    await enter(tester, 'capacity-${entry.key}', entry.value);
  }
  await enter(tester, 'capacity-valid-until', '2099-01-01');
  await enter(tester, 'capacity-note', 'Synthetic measurements only');
  await confirm(tester);
}

void main() {
  test(
    'server timestamps and raw identity are preserved for administrative review',
    () {
      final json = <String, dynamic>{
        'driver_id': 'synthetic-driver',
        'category': 'cargoVan',
        'make_model': 'SYNTHETIC VAN',
        'year': 2025,
        'plate': 'TEST',
        'max_payload_kg': 500,
        'created_at': Timestamp.fromDate(DateTime.utc(2025)),
        'is_verified': true,
        'capacity_valid_until': Timestamp.fromDate(DateTime.utc(2099)),
        'verified_capacity': {'payload_kg': 500},
      };
      final value = DriverVehicle.fromJson('synthetic', json);
      expect(value.createdAt.toUtc(), DateTime.utc(2025));
      expect(value.capacityValidUntil!.toUtc(), DateTime.utc(2099));
      expect(value.verificationIdentity['category'], 'cargoVan');
      expect(value.category, VehicleCategory.cargoVan);
      expect(value.verifiedCapacity!['payload_kg'], 500);
      expect(value.toJson().containsKey('verified_capacity'), isFalse);
    },
  );
  test(
    'missing vehicle verification is never inferred from a declared payload',
    () {
      final value = DriverVehicle.fromJson('synthetic', {
        'driver_id': 'synthetic-driver',
        'category': 'pickup_truck',
        'max_payload_kg': 900,
      });
      expect(value.isVerified, isFalse);
      expect(value.verifiedCapacity, isNull);
      expect(value.capacityValidUntil, isNull);
    },
  );

  late ReviewRepo repo;
  setUp(() {
    repo = ReviewRepo();
    BackendLocator.driverRepositoryOverride = repo;
  });
  tearDown(() {
    BackendLocator.driverRepositoryOverride = null;
  });
  for (final locale in ['fr', 'en', 'es']) {
    for (final format in [
      (375.0, 812.0, 1.0),
      (430.0, 932.0, 1.0),
      (1440.0, 900.0, 1.0),
      (375.0, 812.0, 2.0),
    ]) {
      testWidgets(
        'review form $locale $format is readable and does not submit implicitly',
        (tester) async {
          tester.view.physicalSize = Size(format.$1, format.$2);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(app(locale: locale, scale: format.$3));
          await open(tester, locale);
          expect(
            find.text(VehicleReviewCopy.text(locale, 'title')),
            findsOneWidget,
          );
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const ValueKey('capacity-approve')),
                )
                .onPressed,
            isNull,
          );
          for (final key in [
            'capacity-length_cm',
            'capacity-payload_kg',
            'capacity-note',
            'capacity-confirmation',
          ]) {
            await tester.ensureVisible(find.byKey(ValueKey(key)));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          expect(repo.calls, 0);
        },
      );
    }
  }
  testWidgets(
    'verified measurements are submitted once and no fabricated dimensions are prefilled',
    (tester) async {
      await tester.pumpWidget(app());
      await open(tester, 'fr');
      expect(
        tester
            .widget<TextFormField>(
              find.byKey(const ValueKey('capacity-length_cm')),
            )
            .controller!
            .text,
        isEmpty,
      );
      repo.pending = Completer<void>();
      await fill(tester);
      await tester.tap(find.byKey(const ValueKey('capacity-approve')));
      await tester.pump();
      expect(repo.calls, 1);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('capacity-approve')),
            )
            .onPressed,
        isNull,
      );
      expect(repo.capacity, containsPair('payload_kg', 500.0));
      expect(repo.approved, isTrue);
      repo.pending!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(DriverVehicleReviewDialog), findsNothing);
    },
  );
  testWidgets('empty measurements fail validation and retain entered note', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await open(tester, 'fr');
    await enter(tester, 'capacity-note', 'Kept synthetic note');
    await confirm(tester);
    await tester.tap(find.byKey(const ValueKey('capacity-approve')));
    await tester.pumpAndSettle();
    expect(repo.calls, 0);
    expect(find.text(VehicleReviewCopy.text('fr', 'positive')), findsWidgets);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('capacity-note')))
          .controller!
          .text,
      'Kept synthetic note',
    );
  });
  testWidgets('permission error is localized and valid data survives retry', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await open(tester, 'fr');
    await fill(tester);
    repo.error = FirebaseFunctionsException(
      code: 'permission-denied',
      message: 'SECRET RAW MESSAGE',
    );
    await tester.tap(find.byKey(const ValueKey('capacity-approve')));
    await tester.pumpAndSettle();
    expect(find.text(VehicleReviewCopy.text('fr', 'access')), findsOneWidget);
    expect(find.textContaining('SECRET'), findsNothing);
    repo.error = null;
    await tester.tap(find.byKey(const ValueKey('capacity-approve')));
    await tester.pumpAndSettle();
    expect(repo.calls, 2);
    expect(repo.note, 'Synthetic measurements only');
  });
  testWidgets('revocation is explicit and requires a reason', (tester) async {
    await tester.pumpWidget(app(verified: true));
    await open(tester, 'fr');
    await tester.tap(find.text(VehicleReviewCopy.text('fr', 'revoke')));
    await tester.pump();
    expect(repo.calls, 0);
    await enter(tester, 'capacity-note', 'Synthetic document revoked');
    await tester.tap(find.text(VehicleReviewCopy.text('fr', 'revoke')));
    await tester.pumpAndSettle();
    expect(repo.calls, 1);
    expect(repo.approved, isFalse);
    expect(repo.capacity, isNull);
  });
}
