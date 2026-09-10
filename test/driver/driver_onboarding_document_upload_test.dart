import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:provider/provider.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/backend_status.dart';
import 'package:movik_connect/backend/models/driver_document.dart';
import 'package:movik_connect/backend/models/driver_internal_note.dart';
import 'package:movik_connect/backend/models/driver_profile_v2.dart';
import 'package:movik_connect/backend/models/driver_vehicle.dart';
import 'package:movik_connect/backend/repositories/driver_document_upload_repository.dart';
import 'package:movik_connect/backend/repositories/driver_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/l10n/driver_onboarding_copy.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/driver/driver_onboarding_screen.dart';
import 'package:movik_connect/services/address/address_autocomplete_provider.dart';
import 'package:movik_connect/services/address/address_backend_locator.dart';
import 'package:movik_connect/services/address/address_suggestion.dart';

const _driverId = 'driver_onboarding_upload_test_uid';

class _FakeAddressProvider implements AddressAutocompleteProvider {
  @override
  Future<List<AddressSuggestion>> searchSuggestions(String query) async {
    return const [
      AddressSuggestion(
        placeId: 'base-place',
        description: '100 Rue Principale, Terrebonne, QC J6W 1A1, Canada',
      ),
    ];
  }

  @override
  Future<ResolvedAddress> resolvePlace(String placeId) async {
    return const ResolvedAddress(
      placeId: 'base-place',
      formattedAddress: '100 Rue Principale, Terrebonne, QC J6W 1A1, Canada',
      streetNumber: '100',
      street: 'Rue Principale',
      city: 'Terrebonne',
      region: 'QC',
      postalCode: 'J6W 1A1',
      country: 'Canada',
      lat: 45.70,
      lng: -73.64,
    );
  }
}

class _FakeImagePicker extends ImagePickerPlatform {
  int calls = 0;

  static final Uint8List _png = Uint8List.fromList(const [
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
    0, 0, 0, 1, 0, 0, 0, 1, 8, 4, 0, 0, 0, 181, 28, 12, 2, 0,
    0, 0, 11, 73, 68, 65, 84, 120, 218, 99, 100, 248, 15, 0, 1, 5,
    1, 1, 39, 24, 227, 102, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66,
    96, 130,
  ]);

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    calls++;
    return XFile.fromData(
      _png,
      path: 'doc_$calls.jpg',
      name: 'doc_$calls.jpg',
      mimeType: 'image/jpeg',
    );
  }
}

class _UploadRepo implements DriverDocumentUploadRepository {
  final bool fail;
  int calls = 0;
  _UploadRepo({this.fail = false});

  @override
  Future<String> uploadDriverDocument({
    required String driverId,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  }) async {
    calls++;
    if (fail) throw Exception('simulated storage failure');
    return 'https://storage.example/$driverId/$fileName';
  }
}

class _DriverRepo implements DriverRepository {
  int onboardingCalls = 0;
  int vehicleCalls = 0;
  int submitReviewCalls = 0;
  DriverProfileV2? profile;
  DriverVehicle? vehicle;
  final List<DriverDocument> documents = [];

  @override
  Future<void> submitDriverOnboarding(DriverProfileV2 value) async {
    onboardingCalls++;
    profile = value;
  }

  @override
  Future<void> submitDriverVehicle(DriverVehicle value) async {
    vehicleCalls++;
    vehicle = value;
  }

  @override
  Future<void> submitDriverDocument(DriverDocument document) async {
    documents.add(document);
  }

  @override
  Future<void> submitForReview() async => submitReviewCalls++;

  @override
  Future<DriverProfileV2?> getDriverProfile(String driverId) =>
      throw UnimplementedError();
  @override
  Stream<DriverProfileV2?> watchDriverProfile(String driverId) =>
      throw UnimplementedError();
  @override
  Future<List<DriverDocument>> getDriverDocuments(String driverId) =>
      throw UnimplementedError();
  @override
  Stream<List<DriverDocument>> watchDriverDocuments(String driverId) =>
      throw UnimplementedError();
  @override
  Future<List<DriverVehicle>> getDriverVehicles(String driverId) =>
      throw UnimplementedError();
  @override
  Stream<List<DriverProfileV2>> watchPendingReviewDrivers() =>
      throw UnimplementedError();
  @override
  Stream<List<DriverProfileV2>> watchDriversByStatus(DriverStatus? status) =>
      throw UnimplementedError();
  @override
  Future<void> approveDriver(String driverId) => throw UnimplementedError();
  @override
  Future<void> rejectDriver(String driverId, String reason) =>
      throw UnimplementedError();
  @override
  Future<void> requestDriverDocuments(String driverId, String reason) =>
      throw UnimplementedError();
  @override
  Future<void> suspendDriver(String driverId, String reason) =>
      throw UnimplementedError();
  @override
  Future<void> reactivateDriver(String driverId) =>
      throw UnimplementedError();
  @override
  Future<void> addDriverInternalNote(String driverId, String text) =>
      throw UnimplementedError();
  @override
  Stream<List<DriverInternalNote>> watchDriverInternalNotes(String driverId) =>
      throw UnimplementedError();
  @override
  Future<void> logDriverReviewOpened(String driverId) =>
      throw UnimplementedError();
  @override
  Future<void> setDriverOnlineStatus(String driverId, bool online) =>
      throw UnimplementedError();
  @override
  Future<DriverStripeAccountResult> createOrRetrieveDriverStripeAccount() =>
      throw UnimplementedError();
}

Widget _app(FirebaseAuthProvider auth) {
  final router = GoRouter(
    initialLocation: '/fr/devenir-chauffeur/inscription',
    routes: [
      GoRoute(
        path: '/fr/devenir-chauffeur/inscription',
        builder: (_, __) => const DriverOnboardingScreen(locale: 'fr'),
      ),
      GoRoute(
        path: '/fr/devenir-chauffeur/statut',
        builder: (_, __) => const Scaffold(body: Text('STATUS_STUB')),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
      Provider<BackendStatus>.value(value: const BackendStatus.ready()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _tapPicker(WidgetTester tester, String label) async {
  final labelFinder = find.text(label);
  await tester.ensureVisible(labelFinder);
  final row = find.ancestor(
    of: labelFinder,
    matching: find.byType(Container),
  ).first;
  final button = find.descendant(
    of: row,
    matching: find.byType(OutlinedButton),
  );
  await tester.tap(button);
  await tester.pump(const Duration(milliseconds: 200));
  final camera = find.text(
    AppStrings.t('driver_onboarding_document_source_camera', 'fr'),
  );
  expect(camera, findsOneWidget);
  await tester.tap(camera);
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> _next(WidgetTester tester) async {
  final button = find.widgetWithText(
    ElevatedButton,
    AppStrings.t('common_next', 'fr'),
  );
  await tester.ensureVisible(button);
  await tester.pump();
  expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

Future<void> _completeContactStep(WidgetTester tester) async {
  final fields = find.byType(TextField);
  await tester.enterText(fields.at(1), '5145551234');
  await tester.enterText(fields.at(2), '100 Rue Principale');
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
  await tester.tap(
    find.text('100 Rue Principale, Terrebonne, QC J6W 1A1, Canada'),
  );
  await tester.pumpAndSettle();
  await _next(tester);
}

Future<void> _completeVehicleStep(WidgetTester tester) async {
  await tester.tap(find.text(AppStrings.t('vehicle_cat_pickup_truck', 'fr')));
  await tester.pump();

  final fields = find.byType(TextField);
  expect(fields, findsNWidgets(6));
  await tester.enterText(fields.at(0), 'Ford');
  await tester.enterText(fields.at(1), 'F-150');
  await tester.enterText(fields.at(2), '2024');
  await tester.enterText(fields.at(3), 'Bleu');
  await tester.enterText(fields.at(4), 'ABC123');
  await tester.enterText(fields.at(5), '900');
  await tester.pump();

  await _tapPicker(
    tester,
    DriverOnboardingCopy.text('fr', 'vehicle_main_photo'),
  );
  await _tapPicker(
    tester,
    DriverOnboardingCopy.text('fr', 'vehicle_rear_photo'),
  );
  await _tapPicker(
    tester,
    DriverOnboardingCopy.text('fr', 'vehicle_plate_photo'),
  );
  await _next(tester);
}

Future<void> _goToDocuments(WidgetTester tester) async {
  await _completeContactStep(tester);
  await _completeVehicleStep(tester);

  await tester.tap(find.text(AppStrings.t('cat_furniture', 'fr')));
  await tester.pump();
  await _next(tester);
}

void main() {
  late FirebaseAuthProvider auth;
  late _FakeImagePicker picker;
  late _DriverRepo driverRepo;

  setUp(() {
    picker = _FakeImagePicker();
    ImagePickerPlatform.instance = picker;
    AddressBackendLocator.autocompleteProviderOverride = _FakeAddressProvider();
    driverRepo = _DriverRepo();
    BackendLocator.driverRepositoryOverride = driverRepo;

    auth = FirebaseAuthProvider(backendConfigured: false)
      ..debugForceSignedIn = true
      ..debugForceUid = _driverId
      ..debugForceDisplayName = 'Chauffeur Test'
      ..debugForceEmail = 'driver@example.com';
  });

  tearDown(() {
    AddressBackendLocator.autocompleteProviderOverride = null;
    BackendLocator.driverRepositoryOverride = null;
    BackendLocator.driverDocumentUploadRepositoryOverride = null;
  });

  testWidgets(
    'vehicle step requires make, model, payload and all three verification photos',
    (tester) async {
      await tester.pumpWidget(_app(auth));
      await tester.pumpAndSettle();
      await _completeContactStep(tester);

      await tester.tap(
        find.text(AppStrings.t('vehicle_cat_pickup_truck', 'fr')),
      );
      await tester.pump();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'Ford');
      await tester.enterText(fields.at(1), 'F-150');
      await tester.enterText(fields.at(2), '2024');
      await tester.enterText(fields.at(3), 'Bleu');
      await tester.enterText(fields.at(4), 'ABC123');
      await tester.enterText(fields.at(5), '900');
      await tester.pump();

      final next = find.widgetWithText(
        ElevatedButton,
        AppStrings.t('common_next', 'fr'),
      );
      expect(tester.widget<ElevatedButton>(next).onPressed, isNull);

      await _tapPicker(
        tester,
        DriverOnboardingCopy.text('fr', 'vehicle_main_photo'),
      );
      expect(tester.widget<ElevatedButton>(next).onPressed, isNull);
      await _tapPicker(
        tester,
        DriverOnboardingCopy.text('fr', 'vehicle_rear_photo'),
      );
      expect(tester.widget<ElevatedButton>(next).onPressed, isNull);
      await _tapPicker(
        tester,
        DriverOnboardingCopy.text('fr', 'vehicle_plate_photo'),
      );
      await tester.pump();
      expect(tester.widget<ElevatedButton>(next).onPressed, isNotNull);
    },
  );

  testWidgets(
    'redesigned onboarding uploads three vehicle photos and four verification documents',
    (tester) async {
      final uploadRepo = _UploadRepo();
      BackendLocator.driverDocumentUploadRepositoryOverride = uploadRepo;
      await tester.pumpWidget(_app(auth));
      await tester.pumpAndSettle();
      await _goToDocuments(tester);

      expect(
        find.text(
          AppStrings.t('driver_onboarding_document_none_selected', 'fr'),
        ),
        findsNWidgets(4),
      );

      await _tapPicker(
        tester,
        AppStrings.t('driver_onboarding_upload_license', 'fr'),
      );
      await _tapPicker(
        tester,
        DriverOnboardingCopy.text('fr', 'vehicle_registration'),
      );
      await _tapPicker(
        tester,
        AppStrings.t('driver_onboarding_upload_insurance', 'fr'),
      );
      await _tapPicker(
        tester,
        DriverOnboardingCopy.text('fr', 'identity_document'),
      );

      await tester.tap(find.byType(CheckboxListTile).at(0));
      await tester.pump();
      await tester.tap(find.byType(CheckboxListTile).at(1));
      await tester.pump();

      final submit = find.widgetWithText(
        ElevatedButton,
        AppStrings.t('driver_onboarding_submit', 'fr'),
      );
      await tester.ensureVisible(submit);
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNotNull);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(uploadRepo.calls, 7);
      expect(driverRepo.documents.length, 7);
      expect(
        driverRepo.documents.map((d) => d.type).toSet(),
        containsAll(<DriverDocumentType>{
          DriverDocumentType.driversLicence,
          DriverDocumentType.vehicleRegistration,
          DriverDocumentType.insurance,
          DriverDocumentType.identity,
          DriverDocumentType.vehiclePhoto,
        }),
      );

      final vehiclePhotos = driverRepo.documents
          .where((d) => d.type == DriverDocumentType.vehiclePhoto)
          .toList();
      expect(vehiclePhotos.length, 3);
      expect(
        vehiclePhotos.any(
          (d) => d.storageBucketPath.contains('/vehicle_main_photo_'),
        ),
        isTrue,
      );
      expect(
        vehiclePhotos.any(
          (d) => d.storageBucketPath.contains('/vehicle_rear_photo_'),
        ),
        isTrue,
      );
      expect(
        vehiclePhotos.any(
          (d) => d.storageBucketPath.contains('/vehicle_plate_photo_'),
        ),
        isTrue,
      );

      expect(driverRepo.onboardingCalls, 1);
      expect(driverRepo.vehicleCalls, 1);
      expect(driverRepo.submitReviewCalls, 1);
      expect(driverRepo.profile?.phone, '5145551234');
      expect(driverRepo.profile?.baseAddressFormatted, contains('Terrebonne'));
      expect(driverRepo.profile?.baseLat, 45.70);
      expect(driverRepo.vehicle?.makeModel, 'Ford F-150');
      expect(driverRepo.vehicle?.maxPayloadKg, 900);
      expect(driverRepo.vehicle?.color, 'Bleu');
      expect(
        find.text(AppStrings.t('driver_pending_verification', 'fr')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'storage failure never advances the driver to pending review',
    (tester) async {
      final uploadRepo = _UploadRepo(fail: true);
      BackendLocator.driverDocumentUploadRepositoryOverride = uploadRepo;
      await tester.pumpWidget(_app(auth));
      await tester.pumpAndSettle();
      await _goToDocuments(tester);

      await _tapPicker(
        tester,
        AppStrings.t('driver_onboarding_upload_license', 'fr'),
      );
      await _tapPicker(
        tester,
        DriverOnboardingCopy.text('fr', 'vehicle_registration'),
      );
      await _tapPicker(
        tester,
        AppStrings.t('driver_onboarding_upload_insurance', 'fr'),
      );
      await _tapPicker(
        tester,
        DriverOnboardingCopy.text('fr', 'identity_document'),
      );
      await tester.tap(find.byType(CheckboxListTile).at(0));
      await tester.pump();
      await tester.tap(find.byType(CheckboxListTile).at(1));
      await tester.pump();

      final submit = find.widgetWithText(
        ElevatedButton,
        AppStrings.t('driver_onboarding_submit', 'fr'),
      );
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(uploadRepo.calls, greaterThanOrEqualTo(1));
      expect(driverRepo.submitReviewCalls, 0);
      expect(
        find.text(AppStrings.t('driver_pending_verification', 'fr')),
        findsNothing,
      );
      expect(
        find.text(
          AppStrings.t('driver_onboarding_error_generic_prefix', 'fr'),
        ),
        findsOneWidget,
      );
    },
  );
}
