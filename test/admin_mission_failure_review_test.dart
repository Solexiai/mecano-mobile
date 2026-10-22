import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/dashboard/admin/missions/admin_mission_failure_review.dart';

DeliveryMission mission(MissionStatus status, {String mode = 'standard'}) =>
    DeliveryMission(
      id: 'm',
      customerId: 'c',
      driverId: 'd',
      itemCategoryKey: 'furniture',
      description: 'Test',
      requiredVehicleCategory: VehicleCategory.cargoVan,
      status: status,
      pricingVersion: 'test',
      createdAt: DateTime(2026),
      assignmentMode: mode,
    );

Widget shell({
  required PlatformRole role,
  Map<String, dynamic> data = const {},
  Future<void> Function(Map<String, dynamic>)? submit,
  MissionStatus status = MissionStatus.inTransit,
  Future<void> Function(Map<String, dynamic>)? chargeTravelFee,
}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LocaleProvider()),
    ChangeNotifierProvider(
      create: (_) =>
          FirebaseAuthProvider(backendConfigured: false)
            ..debugForceRoles = [role],
    ),
  ],
  child: MaterialApp(
    home: Scaffold(
      body: AdminMissionFailureReview(
        mission: mission(status),
        reviewStream: Stream.value(data),
        submit: submit,
        chargeTravelFee: chargeTravelFee,
      ),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'cancellations and completed deliveries cannot be confirmed as failures',
    () {
      for (final status in [
        MissionStatus.cancelled,
        MissionStatus.completed,
        MissionStatus.delivered,
      ]) {
        expect(canReviewMissionFailure(mission(status)), isFalse);
      }
      expect(canReviewMissionFailure(mission(MissionStatus.inTransit)), isTrue);
      expect(
        canReviewMissionFailure(
          mission(MissionStatus.inTransit, mode: 'internal_test'),
        ),
        isFalse,
      );
    },
  );
  testWidgets('analyst sees finding but cannot change it', (tester) async {
    await tester.pumpWidget(shell(role: PlatformRole.analyst));
    await tester.pumpAndSettle();
    expect(find.text('Aucun échec confirmé'), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNothing);
  });
  testWidgets('cached finding cannot be edited', (tester) async {
    await tester.pumpWidget(
      shell(role: PlatformRole.admin, data: {'_fromCache': true}),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
      isNull,
    );
  });
  testWidgets(
    'explicit attestation and reason required; payload includes concurrency guards',
    (tester) async {
      Map<String, dynamic>? sent;
      await tester.pumpWidget(
        shell(
          role: PlatformRole.admin,
          data: {'revision': 3},
          submit: (data) async {
            sent = data;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('failure-review-submit')),
            )
            .onPressed,
        isNull,
      );
      await tester.enterText(
        find.byKey(const Key('failure-review-reason')),
        ' Vérification faite ',
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('failure-review-submit')),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.byKey(const Key('failure-review-submit')));
      await tester.pumpAndSettle();
      expect(sent, {
        'missionId': 'm',
        'action': 'confirm',
        'reason': 'Vérification faite',
        'expectedStatus': 'in_transit',
        'expectedRevision': 3,
        'expectedDriverId': 'd',
        'deliveryNotCompleted': true,
      });
    },
  );
  testWidgets(
    'revocation keeps a required explanation and no false success on error',
    (tester) async {
      await tester.pumpWidget(
        shell(
          role: PlatformRole.admin,
          data: {'confirmed': true, 'revision': 1, 'reason': 'Motif original'},
          submit: (_) async {
            throw StateError('changed');
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retirer ce constat'));
      await tester.pumpAndSettle();
      expect(find.byType(CheckboxListTile), findsNothing);
      await tester.enterText(
        find.byKey(const Key('failure-review-reason')),
        'Correction après vérification',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('failure-review-submit')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Impossible de confirmer l’enregistrement'),
        findsOneWidget,
      );
      expect(
        find.text('Échec de livraison confirmé par l’administration'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'travel fee: offered only after a confirmed failure, before pickup',
    (tester) async {
      const confirmed = {'confirmed': true, 'revision': 1, 'reason': 'Client absent'};
      await tester.pumpWidget(shell(role: PlatformRole.admin, data: confirmed));
      await tester.pumpAndSettle();
      // In transit: the goods were picked up, no travel fee.
      expect(find.byKey(const Key('travel-fee-open')), findsNothing);

      await tester.pumpWidget(
        shell(role: PlatformRole.admin, status: MissionStatus.arrivedAtPickup),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('travel-fee-open')), findsNothing);

      final payloads = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        shell(
          role: PlatformRole.admin,
          data: confirmed,
          status: MissionStatus.arrivedAtPickup,
          chargeTravelFee: (p) async => payloads.add(p),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('travel-fee-open')));
      await tester.pumpAndSettle();
      expect(find.textContaining('30,00 \$'), findsWidgets);
      await tester.tap(find.byKey(const Key('travel-fee-submit')));
      await tester.pumpAndSettle();
      expect(payloads.single, {
        'missionId': 'm',
        'expectedStatus': 'arrived_at_pickup',
        'reason': 'Client absent',
      });
    },
  );
  for (final locale in ['fr', 'en', 'es']) {
    for (final width in [375.0, 1440.0]) {
      testWidgets('confirmation dialog $locale $width at 200%', (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(body: MissionFailureReviewDialog(locale: locale)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
