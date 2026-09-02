// ---------------------------------------------------------------------------
// Tests widget — ProviderStripeConnectSection (Bloc 8B, PRIORITÉ 1, Connect
// Onboarding Flutter).
//
// Couvre TOUS les états requis par la directive :
//   - no_account          : aucun stripe_connected_account_id
//   - onboarding_pending  : compte créé mais charges_enabled/payouts_enabled
//                            encore false
//   - active              : charges_enabled == true && payouts_enabled == true
//   - loading             : appel createOrRetrieveDriverStripeAccount() en
//                            cours (bouton désactivé + spinner)
//   - error (générique)   : result.success == false / onboardingUrl null
//   - error (not_configured) : BackendNotConfiguredException
//   - refresh/retry       : bouton "Réessayer" présent en état pending,
//                            n'entraîne jamais de crash
//
// `url_launcher` est mocké via son canal de méthode natif
// (TestDefaultBinaryMessenger) pour permettre de vérifier, SANS dépendance à
// une plateforme réelle, que l'URL d'onboarding reçue est bien celle passée
// au launcher — jamais un secret, jamais une donnée inventée localement.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movik_connect/backend/backend_exceptions.dart';
import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/driver_document.dart';
import 'package:movik_connect/backend/models/driver_internal_note.dart';
import 'package:movik_connect/backend/models/driver_profile_v2.dart';
import 'package:movik_connect/backend/models/driver_vehicle.dart';
import 'package:movik_connect/backend/repositories/driver_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/screens/dashboard/provider/tabs/provider_stripe_connect_section.dart';

String _t(String key) => AppStrings.t(key, 'fr');

const _driverId = 'driver_stripe_connect_test_001';
const _channel = MethodChannel('plugins.flutter.io/url_launcher');

DriverProfileV2 _profile({
  String? stripeConnectedAccountId,
  String? stripeOnboardingUrl,
  bool stripeChargesEnabled = false,
  bool stripePayoutsEnabled = false,
}) {
  return DriverProfileV2(
    uid: _driverId,
    fullName: 'Chauffeur Test',
    city: 'Montréal',
    status: DriverStatus.approved,
    serviceRadiusKm: 15,
    acceptedVehicleCategories: const [VehicleCategory.cargoVan],
    acceptedItemCategoryKeys: const [],
    createdAt: DateTime(2026, 1, 1),
    stripeConnectedAccountId: stripeConnectedAccountId,
    stripeOnboardingUrl: stripeOnboardingUrl,
    stripeChargesEnabled: stripeChargesEnabled,
    stripePayoutsEnabled: stripePayoutsEnabled,
  );
}

/// `DriverRepository` fake minimal — seule `createOrRetrieveDriverStripeAccount`
/// est exercée par ce widget ; toute autre méthode lève `UnimplementedError`
/// (jamais appelée par `ProviderStripeConnectSection`).
class _FakeDriverRepository implements DriverRepository {
  DriverStripeAccountResult? nextResult;
  Object? nextError;
  Completer<DriverStripeAccountResult>? pendingCompleter;
  int callCount = 0;

  @override
  Future<DriverStripeAccountResult> createOrRetrieveDriverStripeAccount() async {
    callCount++;
    if (pendingCompleter != null) return pendingCompleter!.future;
    if (nextError != null) throw nextError!;
    return nextResult ?? const DriverStripeAccountResult(success: false);
  }

  @override
  Future<DriverProfileV2?> getDriverProfile(String driverId) => throw UnimplementedError();
  @override
  Stream<DriverProfileV2?> watchDriverProfile(String driverId) => throw UnimplementedError();
  @override
  Future<List<DriverDocument>> getDriverDocuments(String driverId) => throw UnimplementedError();
  @override
  Stream<List<DriverDocument>> watchDriverDocuments(String driverId) => throw UnimplementedError();
  @override
  Future<List<DriverVehicle>> getDriverVehicles(String driverId) => throw UnimplementedError();
  @override
  Future<void> submitDriverDocument(DriverDocument document) => throw UnimplementedError();
  @override
  Future<void> submitDriverOnboarding(DriverProfileV2 profile) => throw UnimplementedError();
  @override
  Future<void> submitDriverVehicle(DriverVehicle vehicle) => throw UnimplementedError();
  @override
  Future<void> submitForReview() => throw UnimplementedError();
  @override
  Stream<List<DriverProfileV2>> watchPendingReviewDrivers() => throw UnimplementedError();
  @override
  Stream<List<DriverProfileV2>> watchDriversByStatus(DriverStatus? status) =>
      throw UnimplementedError();
  @override
  Future<void> approveDriver(String driverId) => throw UnimplementedError();
  @override
  Future<void> rejectDriver(String driverId, String reason) => throw UnimplementedError();
  @override
  Future<void> requestDriverDocuments(String driverId, String reason) =>
      throw UnimplementedError();
  @override
  Future<void> suspendDriver(String driverId, String reason) => throw UnimplementedError();
  @override
  Future<void> reactivateDriver(String driverId) => throw UnimplementedError();
  @override
  Future<void> addDriverInternalNote(String driverId, String text) => throw UnimplementedError();
  @override
  Stream<List<DriverInternalNote>> watchDriverInternalNotes(String driverId) => throw UnimplementedError();
  @override
  Future<void> logDriverReviewOpened(String driverId) => throw UnimplementedError();
  @override
  Future<void> setDriverOnlineStatus(String driverId, bool online) => throw UnimplementedError();
}

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  late List<MethodCall> launchCalls;

  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    launchCalls = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
      launchCalls.add(call);
      if (call.method == 'launch') return true;
      if (call.method == 'canLaunch') return true;
      return null;
    });
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null);
  });

  group('ProviderStripeConnectSection — états requis (Bloc 8B, PRIORITÉ 1)', () {
    testWidgets('no_account : profil sans compte Stripe affiche le CTA de démarrage', (tester) async {
      await tester.pumpWidget(_wrap(ProviderStripeConnectSection(profile: _profile(), t: _t)));
      await tester.pumpAndSettle();

      expect(find.text(_t('provider_stripe_connect_status_none')), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, _t('provider_stripe_connect_start')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('onboarding_pending : compte créé mais capacités non actives', (tester) async {
      final profile = _profile(
        stripeConnectedAccountId: 'acct_123',
        stripeOnboardingUrl: 'https://connect.stripe.com/setup/acct_123',
        stripeChargesEnabled: false,
        stripePayoutsEnabled: false,
      );
      await tester.pumpWidget(_wrap(ProviderStripeConnectSection(profile: profile, t: _t)));
      await tester.pumpAndSettle();

      expect(find.text(_t('provider_stripe_connect_status_pending')), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, _t('provider_stripe_connect_resume')), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, _t('common_retry')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('active : charges_enabled et payouts_enabled tous les deux vrais', (tester) async {
      final profile = _profile(
        stripeConnectedAccountId: 'acct_123',
        stripeOnboardingUrl: 'https://connect.stripe.com/setup/acct_123',
        stripeChargesEnabled: true,
        stripePayoutsEnabled: true,
      );
      await tester.pumpWidget(_wrap(ProviderStripeConnectSection(profile: profile, t: _t)));
      await tester.pumpAndSettle();

      expect(find.text(_t('provider_stripe_connect_status_active')), findsOneWidget);
      // Aucun CTA de (ré)onboarding quand tout est déjà actif.
      expect(find.widgetWithText(ElevatedButton, _t('provider_stripe_connect_start')), findsNothing);
      expect(find.widgetWithText(ElevatedButton, _t('provider_stripe_connect_resume')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('loading : bouton désactivé + spinner pendant l\'appel', (tester) async {
      final fakeRepo = _FakeDriverRepository();
      fakeRepo.pendingCompleter = Completer<DriverStripeAccountResult>();

      await tester.pumpWidget(_wrap(_TestHost(profile: _profile(), repo: fakeRepo)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, _t('provider_stripe_connect_start')));
      await tester.pump();

      expect(find.text(_t('provider_stripe_connect_loading')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);

      fakeRepo.pendingCompleter!.complete(
        const DriverStripeAccountResult(success: true, connectedAccountId: 'acct_x', onboardingUrl: 'https://x'),
      );
      await tester.pumpAndSettle();
    });

    testWidgets('succès : createOrRetrieveDriverStripeAccount appelé puis onboardingUrl ouvert via url_launcher',
        (tester) async {
      final fakeRepo = _FakeDriverRepository();
      fakeRepo.nextResult = const DriverStripeAccountResult(
        success: true,
        connectedAccountId: 'acct_999',
        onboardingUrl: 'https://connect.stripe.com/setup/acct_999',
        alreadyExisted: false,
      );

      await tester.pumpWidget(_wrap(_TestHost(profile: _profile(), repo: fakeRepo)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, _t('provider_stripe_connect_start')));
      await tester.pumpAndSettle();

      expect(fakeRepo.callCount, 1);
      expect(launchCalls, isNotEmpty);
      expect(launchCalls.last.method, 'launch');
      expect(launchCalls.last.arguments['url'], 'https://connect.stripe.com/setup/acct_999');
      expect(tester.takeException(), isNull);
    });

    testWidgets('erreur générique : result.success == false affiche un message, pas de crash', (tester) async {
      final fakeRepo = _FakeDriverRepository();
      fakeRepo.nextResult = const DriverStripeAccountResult(success: false);

      await tester.pumpWidget(_wrap(_TestHost(profile: _profile(), repo: fakeRepo)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, _t('provider_stripe_connect_start')));
      await tester.pumpAndSettle();

      expect(find.text(_t('provider_stripe_connect_error_generic')), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(launchCalls, isEmpty);
    });

    testWidgets('erreur not_configured : BackendNotConfiguredException affiche un message dédié', (tester) async {
      final fakeRepo = _FakeDriverRepository();
      fakeRepo.nextError = const BackendNotConfiguredException('createDriverStripeAccount indisponible.');

      await tester.pumpWidget(_wrap(_TestHost(profile: _profile(), repo: fakeRepo)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, _t('provider_stripe_connect_start')));
      await tester.pumpAndSettle();

      expect(find.text(_t('provider_stripe_connect_error_not_configured')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('erreur inattendue (exception réseau) : catch générique, aucun crash', (tester) async {
      final fakeRepo = _FakeDriverRepository();
      fakeRepo.nextError = Exception('Erreur réseau simulée (test).');

      await tester.pumpWidget(_wrap(_TestHost(profile: _profile(), repo: fakeRepo)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, _t('provider_stripe_connect_start')));
      await tester.pumpAndSettle();

      expect(find.text(_t('provider_stripe_connect_error_generic')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('refresh/retry : le bouton "Réessayer" efface l\'erreur locale sans planter', (tester) async {
      final fakeRepo = _FakeDriverRepository();
      fakeRepo.nextResult = const DriverStripeAccountResult(success: false);
      final profile = _profile(
        stripeConnectedAccountId: 'acct_123',
        stripeOnboardingUrl: 'https://connect.stripe.com/setup/acct_123',
      );

      await tester.pumpWidget(_wrap(_TestHost(profile: profile, repo: fakeRepo)));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, _t('provider_stripe_connect_resume')));
      await tester.pumpAndSettle();
      expect(find.text(_t('provider_stripe_connect_error_generic')), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, _t('common_retry')));
      await tester.pumpAndSettle();

      expect(find.text(_t('provider_stripe_connect_error_generic')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('FR/EN/ES : le titre de la section est traduit dans les 3 langues', (tester) async {
      for (final locale in ['fr', 'en', 'es']) {
        String tt(String key) => AppStrings.t(key, locale);
        await tester.pumpWidget(_wrap(ProviderStripeConnectSection(profile: _profile(), t: tt)));
        await tester.pumpAndSettle();
        expect(find.text(tt('provider_stripe_connect_title')), findsOneWidget);
        expect(tt('provider_stripe_connect_title'), isNot(equals('provider_stripe_connect_title')));
      }
    });
  });
}

/// Hôte de test minimal permettant d'injecter un `DriverRepository` fake
/// SANS passer par `BackendLocator` (le widget appelle directement
/// `BackendLocator.driverRepository`, donc on utilise le seam existant
/// `driverRepositoryOverride`, déjà exploité par les autres tests chauffeur
/// — voir `provider_jobs_tab_test.dart`).
class _TestHost extends StatefulWidget {
  final DriverProfileV2? profile;
  final _FakeDriverRepository repo;
  const _TestHost({required this.profile, required this.repo});

  @override
  State<_TestHost> createState() => _TestHostState();
}

class _TestHostState extends State<_TestHost> {
  @override
  void initState() {
    super.initState();
    BackendLocator.driverRepositoryOverride = widget.repo;
  }

  @override
  void dispose() {
    BackendLocator.driverRepositoryOverride = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProviderStripeConnectSection(profile: widget.profile, t: _t);
  }
}
