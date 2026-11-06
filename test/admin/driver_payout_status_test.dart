// Versements Stripe vus par l'admin (2026-11-03) : la pastille et le filtre
// « Prêts à livrer » doivent dire exactement ce que le serveur exige
// (isDriverPayoutReady en mode réel), jamais plus.
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/models/driver_profile_v2.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/screens/dashboard/admin/drivers/admin_drivers_list_screen.dart';
import 'package:movik_connect/screens/dashboard/admin/drivers/driver_payout_status.dart';

DriverProfileV2 profile({
  String? account,
  String? environment,
  bool charges = false,
  bool payouts = false,
  DriverStatus status = DriverStatus.approved,
  bool documents = true,
  bool detailsSubmitted = false,
  int currentlyDue = 0,
  String? disabledReason,
}) => DriverProfileV2(
  uid: 'd',
  fullName: 'Test',
  city: 'Granby',
  status: status,
  serviceRadiusKm: 40,
  acceptedVehicleCategories: const [],
  acceptedItemCategoryKeys: const [],
  createdAt: DateTime.utc(2026, 11, 3),
  documentsAllValid: documents,
  stripeConnectedAccountId: account,
  stripeConnectedAccountEnvironment: environment,
  stripeChargesEnabled: charges,
  stripePayoutsEnabled: payouts,
  stripeDetailsSubmitted: detailsSubmitted,
  stripeRequirementsCurrentlyDue: currentlyDue,
  stripeRequirementsDisabledReason: disabledReason,
);

void main() {
  test('pas de compte → pas commencé', () {
    expect(driverPayoutReadiness(profile()), DriverPayoutReadiness.notStarted);
    expect(driverPayoutReadiness(profile(account: '  ')), DriverPayoutReadiness.notStarted);
  });

  test('compte sans étiquette ou étiqueté test → compte de test, même validé', () {
    expect(
      driverPayoutReadiness(profile(account: 'acct_1', charges: true, payouts: true)),
      DriverPayoutReadiness.testAccount,
    );
    expect(
      driverPayoutReadiness(
        profile(account: 'acct_1', environment: 'test', charges: true, payouts: true),
      ),
      DriverPayoutReadiness.testAccount,
    );
  });

  test('compte réel : incomplet tant que identité ET banque ne sont pas validées', () {
    expect(
      driverPayoutReadiness(profile(account: 'acct_1', environment: 'live')),
      DriverPayoutReadiness.incomplete,
    );
    expect(
      driverPayoutReadiness(profile(account: 'acct_1', environment: 'live', charges: true)),
      DriverPayoutReadiness.incomplete,
    );
    expect(
      driverPayoutReadiness(
        profile(account: 'acct_1', environment: 'live', charges: true, payouts: true),
      ),
      DriverPayoutReadiness.ready,
    );
  });

  test('formulaire terminé, rien demandé → en examen ; une pièce demandée → incomplet', () {
    expect(
      driverPayoutReadiness(profile(account: 'acct_1', environment: 'live', detailsSubmitted: true)),
      DriverPayoutReadiness.underReview,
    );
    expect(
      driverPayoutReadiness(
        profile(account: 'acct_1', environment: 'live', detailsSubmitted: true, currentlyDue: 1),
      ),
      DriverPayoutReadiness.incomplete,
    );
    expect(
      driverPayoutReadiness(
        profile(account: 'acct_1', environment: 'live', detailsSubmitted: true,
            disabledReason: 'requirements.past_due'),
      ),
      DriverPayoutReadiness.incomplete,
    );
    // Un compte de test « soumis » reste un compte de test.
    expect(
      driverPayoutReadiness(profile(account: 'acct_1', detailsSubmitted: true)),
      DriverPayoutReadiness.testAccount,
    );
    // Validé par Stripe : prêt, même si details_submitted n'est pas encore synchronisé.
    expect(
      driverPayoutReadiness(profile(account: 'acct_1', environment: 'live', charges: true, payouts: true)),
      DriverPayoutReadiness.ready,
    );
  });

  test('prêt à livrer = approuvé + documents + Stripe prêt', () {
    final ready = profile(account: 'acct_1', environment: 'live', charges: true, payouts: true);
    expect(isDriverReadyToDeliver(ready), isTrue);
    expect(
      isDriverReadyToDeliver(
        profile(account: 'acct_1', environment: 'live', charges: true, payouts: true,
            status: DriverStatus.pendingReview),
      ),
      isFalse,
    );
    expect(
      isDriverReadyToDeliver(
        profile(account: 'acct_1', environment: 'live', charges: true, payouts: true,
            documents: false),
      ),
      isFalse,
    );
    expect(isDriverReadyToDeliver(profile(account: 'acct_1', environment: 'live')), isFalse);
  });

  test('le filtre de la liste applique « prêts » / « pas prêts »', () {
    final ready = profile(account: 'acct_1', environment: 'live', charges: true, payouts: true);
    final notReady = profile(account: 'acct_1', environment: 'live');
    expect(matchesDriverDirectory(ready, '', 'all', null, readiness: 'ready'), isTrue);
    expect(matchesDriverDirectory(notReady, '', 'all', null, readiness: 'ready'), isFalse);
    expect(matchesDriverDirectory(ready, '', 'all', null, readiness: 'not_ready'), isFalse);
    expect(matchesDriverDirectory(notReady, '', 'all', null, readiness: 'not_ready'), isTrue);
    expect(matchesDriverDirectory(notReady, '', 'all', null), isTrue);
  });

  test('le modèle lit et réécrit le mode du compte Stripe', () {
    final p = DriverProfileV2.fromJson('d', {
      'full_name': 'Test',
      'city': 'Granby',
      'status': 'approved',
      'service_radius_km': 40,
      'stripe_connected_account_id': 'acct_1',
      'stripe_connected_account_environment': 'live',
      'stripe_charges_enabled': true,
      'stripe_payouts_enabled': true,
    });
    expect(p.stripeConnectedAccountEnvironment, 'live');
    expect(p.toJson()['stripe_connected_account_environment'], 'live');
    expect(driverPayoutReadiness(p), DriverPayoutReadiness.ready);
  });
}
