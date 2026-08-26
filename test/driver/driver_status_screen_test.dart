// ---------------------------------------------------------------------------
// Test widget — DriverStatusScreen (Phase 7, Bloc C — item 3, sous-tâche 3/3).
//
// Couvre les 7 valeurs de `DriverStatus` : pour chacune, vérifie que
// l'écran se rend sans crash, affiche le bon libellé de statut + le bon
// message, propose le(s) CTA attendu(s) et UNIQUEMENT ceux-ci (aucune
// action interdite ne doit être visible/actionnable), et que le
// repository n'est appelé QUE lorsque l'utilisateur déclenche réellement
// l'action correspondante (jamais en arrière-plan / au premier build).
//
// STRATÉGIE :
//   - `BackendLocator.driverRepositoryOverride` avec un
//     `_FakeDriverRepository` qui compte précisément les appels à
//     `submitForReview()` / `setDriverOnlineStatus()` et permet de
//     rejouer le profil avec un nouveau statut via un `StreamController`
//     single-subscription (même pattern que
//     `driver_active_mission_status_gaps_test.dart` : un `.broadcast()`
//     perdrait silencieusement l'événement seedé avant le premier
//     `listen()` du `StreamBuilder`, bloquant le test en
//     `ConnectionState.waiting` pour toujours).
//   - `FirebaseAuthProvider(backendConfigured: false)` +
//     `debugForceSignedIn`/`debugForceUid` (pattern établi).
//   - `DriverStatusScreen` est rendu à l'intérieur d'`AppShell`, qui exige
//     un `GoRouter` ambient (les liens de nav du header utilisent
//     `context.go`) -> même harnais `MultiProvider` + `MaterialApp.router`
//     que les autres tests `test/driver/*_test.dart`.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/driver_document.dart';
import 'package:movik_connect/backend/models/driver_internal_note.dart';
import 'package:movik_connect/backend/models/driver_profile_v2.dart';
import 'package:movik_connect/backend/models/driver_vehicle.dart';
import 'package:movik_connect/backend/repositories/driver_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/driver/driver_status_screen.dart';

const _driverId = 'driver_status_test_001';

/// `DriverRepository` fake — expose uniquement ce dont `DriverStatusScreen`
/// a besoin ; toute autre méthode lève explicitement `UnimplementedError`
/// (jamais un faux succès silencieux) si un chemin de test l'appelait par
/// erreur.
class _FakeDriverRepository implements DriverRepository {
  DriverProfileV2? profile;

  // Volontairement NON-broadcast (single-subscription) — voir en-tête.
  final _controller = StreamController<DriverProfileV2?>();

  int submitForReviewCallCount = 0;
  int setDriverOnlineStatusCallCount = 0;
  int watchDriverProfileCallCount = 0;
  bool? lastOnlineValue;

  /// Si positionné, `submitForReview()` lève cette exception au lieu de
  /// réussir — permet de tester un échec backend simple (ex: règle
  /// serveur qui refuse la transition).
  Object? submitForReviewError;

  /// Si positionné, `submitForReview()` attend ce `Completer` avant de
  /// résoudre — permet de figer l'état `busy` pour vérifier qu'un second
  /// déclenchement pendant l'action en cours n'entraîne pas un second
  /// appel (bouton désactivé pendant `busy`).
  Completer<void>? pendingSubmitForReviewCompleter;

  _FakeDriverRepository(this.profile) {
    _controller.add(profile);
  }

  void advanceTo(DriverProfileV2 next) {
    profile = next;
    _controller.add(next);
  }

  void dispose() => _controller.close();

  @override
  Stream<DriverProfileV2?> watchDriverProfile(String driverId) {
    watchDriverProfileCallCount++;
    return _controller.stream;
  }

  @override
  Future<DriverProfileV2?> getDriverProfile(String driverId) async => profile;

  @override
  Future<void> submitForReview() async {
    submitForReviewCallCount++;
    if (pendingSubmitForReviewCompleter != null) {
      await pendingSubmitForReviewCompleter!.future;
    }
    if (submitForReviewError != null) {
      throw submitForReviewError!;
    }
    final current = profile;
    if (current != null) {
      advanceTo(_withStatus(current, DriverStatus.pendingReview));
    }
  }

  @override
  Future<void> setDriverOnlineStatus(String driverId, bool online) async {
    setDriverOnlineStatusCallCount++;
    lastOnlineValue = online;
    final current = profile;
    if (current != null) {
      advanceTo(_withOnlineStatus(
        current,
        online ? DriverOnlineStatus.online : DriverOnlineStatus.offline,
      ));
    }
  }

  // -- Méthodes hors périmètre de DriverStatusScreen : jamais appelées par
  // l'écran testé ici ; toute invocation accidentelle doit faire échouer
  // le test bruyamment plutôt que de simuler un faux succès.
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
  Future<void> submitDriverDocument(DriverDocument document) => throw UnimplementedError();
  @override
  Future<void> submitDriverOnboarding(DriverProfileV2 profile) => throw UnimplementedError();
  @override
  Future<void> submitDriverVehicle(DriverVehicle vehicle) => throw UnimplementedError();
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
  Stream<List<DriverInternalNote>> watchDriverInternalNotes(String driverId) =>
      throw UnimplementedError();
  @override
  Future<void> logDriverReviewOpened(String driverId) => throw UnimplementedError();
}

/// `DriverProfileV2` n'a pas de `copyWith()` : reconstruction manuelle
/// complète (même contrainte que `DeliveryMission`, voir
/// `driver_active_mission_status_gaps_test.dart`).
DriverProfileV2 _withStatus(DriverProfileV2 p, DriverStatus status) {
  return DriverProfileV2(
    uid: p.uid,
    fullName: p.fullName,
    city: p.city,
    status: status,
    serviceRadiusKm: p.serviceRadiusKm,
    acceptedVehicleCategories: p.acceptedVehicleCategories,
    acceptedItemCategoryKeys: p.acceptedItemCategoryKeys,
    rating: p.rating,
    completedMissions: p.completedMissions,
    createdAt: p.createdAt,
    approvedAt: p.approvedAt,
    approvedByUserId: p.approvedByUserId,
    rejectionReason: p.rejectionReason,
    identityVerified: p.identityVerified,
    vehicleVerified: p.vehicleVerified,
    onlineStatus: p.onlineStatus,
    submittedForReviewAt: p.submittedForReviewAt,
    documentsRequiredReason: p.documentsRequiredReason,
    documentsRequiredAt: p.documentsRequiredAt,
    suspensionReason: p.suspensionReason,
    suspendedAt: p.suspendedAt,
  );
}

DriverProfileV2 _withOnlineStatus(DriverProfileV2 p, DriverOnlineStatus onlineStatus) {
  return DriverProfileV2(
    uid: p.uid,
    fullName: p.fullName,
    city: p.city,
    status: p.status,
    serviceRadiusKm: p.serviceRadiusKm,
    acceptedVehicleCategories: p.acceptedVehicleCategories,
    acceptedItemCategoryKeys: p.acceptedItemCategoryKeys,
    rating: p.rating,
    completedMissions: p.completedMissions,
    createdAt: p.createdAt,
    approvedAt: p.approvedAt,
    approvedByUserId: p.approvedByUserId,
    rejectionReason: p.rejectionReason,
    identityVerified: p.identityVerified,
    vehicleVerified: p.vehicleVerified,
    onlineStatus: onlineStatus,
    submittedForReviewAt: p.submittedForReviewAt,
    documentsRequiredReason: p.documentsRequiredReason,
    documentsRequiredAt: p.documentsRequiredAt,
    suspensionReason: p.suspensionReason,
    suspendedAt: p.suspendedAt,
  );
}

DriverProfileV2 _buildProfile({
  required DriverStatus status,
  DriverOnlineStatus onlineStatus = DriverOnlineStatus.offline,
  String? documentsRequiredReason,
  String? rejectionReason,
  String? suspensionReason,
}) {
  return DriverProfileV2(
    uid: _driverId,
    fullName: 'Chauffeur Test',
    city: 'Gatineau',
    status: status,
    serviceRadiusKm: 25,
    acceptedVehicleCategories: const [VehicleCategory.pickupTruck],
    acceptedItemCategoryKeys: const ['cat_furniture'],
    createdAt: DateTime(2025, 1, 1),
    onlineStatus: onlineStatus,
    documentsRequiredReason: documentsRequiredReason,
    rejectionReason: rejectionReason,
    suspensionReason: suspensionReason,
  );
}

/// `find.widgetWithText(ElevatedButton, ...)` / `find.byType(ElevatedButton)`
/// échouent silencieusement sur tout bouton créé via
/// `ElevatedButton.icon(...)` OU `OutlinedButton.icon(...)` : ces
/// constructeurs instancient en interne une sous-classe PRIVÉE
/// (`_ElevatedButtonWithIcon` / `_OutlinedButtonWithIcon`). `find.byType()`
/// effectue une comparaison EXACTE de `runtimeType` (voir doc officielle :
/// "does not do subtype tests"), donc `byType(ElevatedButton)` ne matche
/// jamais `_ElevatedButtonWithIcon`. `driver_status_screen.dart` utilise
/// `ElevatedButton.icon(...)` (documentsRequired/registrationIncomplete)
/// ET `OutlinedButton.icon(...)` (pendingReview "rafraîchir") -> il faut
/// chercher par prédicat (`is ElevatedButton`/`is OutlinedButton`, qui
/// acceptent les sous-types) plutôt que par type exact.
Finder _elevatedButtonWithText(String text) {
  return find.ancestor(
    of: find.text(text),
    matching: find.byWidgetPredicate((w) => w is ElevatedButton),
  );
}

Finder _outlinedButtonWithText(String text) {
  return find.ancestor(
    of: find.text(text),
    matching: find.byWidgetPredicate((w) => w is OutlinedButton),
  );
}

/// Idem pour retrouver N'IMPORTE QUEL `ElevatedButton` visible (utilisé
/// pour localiser le bouton en état `busy`, une fois son texte remplacé
/// par un spinner).
final Finder _anyElevatedButton = find.byWidgetPredicate((w) => w is ElevatedButton);

Widget _buildTestApp(FirebaseAuthProvider auth) {
  final router = GoRouter(
    initialLocation: '/fr/statut-chauffeur',
    routes: [
      GoRoute(
        path: '/fr/statut-chauffeur',
        builder: (context, state) => const DriverStatusScreen(locale: 'fr'),
      ),
      GoRoute(
        path: '/fr/devenir-chauffeur/inscription',
        builder: (context, state) => const Scaffold(body: Text('REGISTRATION_STUB')),
      ),
      GoRoute(
        path: '/fr',
        builder: (context, state) => const Scaffold(body: Text('HOME_STUB')),
      ),
      GoRoute(
        path: '/fr/connexion',
        builder: (context, state) => const Scaffold(body: Text('LOGIN_STUB')),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  late _FakeDriverRepository fakeRepo;
  late FirebaseAuthProvider auth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    auth = FirebaseAuthProvider(backendConfigured: false);
    auth.debugForceSignedIn = true;
    auth.debugForceUid = _driverId;
    auth.debugForceDisplayName = 'Chauffeur Test';
  });

  tearDown(() {
    fakeRepo.dispose();
    BackendLocator.driverRepositoryOverride = null;
  });

  Future<void> pumpWithStatus(WidgetTester tester, DriverProfileV2 profile) async {
    fakeRepo = _FakeDriverRepository(profile);
    BackendLocator.driverRepositoryOverride = fakeRepo;
    await tester.pumpWidget(_buildTestApp(auth));
    await tester.pumpAndSettle();
  }

  String t(String key) => AppStrings.t(key, 'fr');

  group('registrationIncomplete', () {
    testWidgets('affiche le statut, le message et le CTA "compléter inscription" uniquement',
        (tester) async {
      await pumpWithStatus(tester, _buildProfile(status: DriverStatus.registrationIncomplete));

      expect(find.text(t('driver_status_registration_incomplete')), findsOneWidget);
      expect(find.text(t('driver_status_registration_incomplete_message')), findsOneWidget);
      expect(_elevatedButtonWithText(t('driver_status_complete_registration')),
          findsOneWidget);

      // Aucune action interdite à ce statut.
      expect(_outlinedButtonWithText(t('driver_status_refresh')), findsNothing);
      expect(_elevatedButtonWithText(t('driver_status_resubmit')), findsNothing);
      expect(find.byType(Switch), findsNothing);

      // Aucun appel repository tant qu'aucune action n'a été déclenchée.
      expect(fakeRepo.submitForReviewCallCount, 0);
      expect(fakeRepo.setDriverOnlineStatusCallCount, 0);
    });

    testWidgets('tap sur le CTA navigue vers l\'inscription SANS appeler le repository',
        (tester) async {
      await pumpWithStatus(tester, _buildProfile(status: DriverStatus.registrationIncomplete));

      await tester.tap(_elevatedButtonWithText(t('driver_status_complete_registration')));
      await tester.pumpAndSettle();

      expect(find.text('REGISTRATION_STUB'), findsOneWidget);
      expect(fakeRepo.submitForReviewCallCount, 0);
      expect(fakeRepo.setDriverOnlineStatusCallCount, 0);
    });
  });

  group('pendingReview', () {
    testWidgets('affiche le statut, le message et le CTA "rafraîchir" uniquement', (tester) async {
      await pumpWithStatus(tester, _buildProfile(status: DriverStatus.pendingReview));

      expect(find.text(t('driver_status_pending_review')), findsOneWidget);
      expect(find.text(t('driver_status_pending_message')), findsOneWidget);
      expect(_outlinedButtonWithText(t('driver_status_refresh')), findsOneWidget);

      // Aucune action interdite : pas de resoumission, pas de switch online,
      // pas de CTA d'inscription à ce statut.
      expect(_elevatedButtonWithText(t('driver_status_resubmit')), findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(
          _elevatedButtonWithText(t('driver_status_complete_registration')),
          findsNothing);

      expect(fakeRepo.submitForReviewCallCount, 0);
      expect(fakeRepo.setDriverOnlineStatusCallCount, 0);
    });

    testWidgets('tap sur "rafraîchir" ne déclenche AUCUN appel repository (relecture locale uniquement)',
        (tester) async {
      await pumpWithStatus(tester, _buildProfile(status: DriverStatus.pendingReview));

      await tester.tap(_outlinedButtonWithText(t('driver_status_refresh')));
      await tester.pumpAndSettle();

      // Le bouton "rafraîchir" ne fait que forcer un rebuild local
      // (setState(() {})) — le flux temps réel est déjà branché sur
      // watchDriverProfile ; il ne doit jamais appeler submitForReview ni
      // aucune autre action d'écriture.
      expect(fakeRepo.submitForReviewCallCount, 0);
      expect(fakeRepo.setDriverOnlineStatusCallCount, 0);
      expect(find.text(t('driver_status_pending_review')), findsOneWidget);
    });
  });

  group('documentsRequired', () {
    testWidgets('affiche le motif serveur et le CTA "resoumettre" uniquement', (tester) async {
      await pumpWithStatus(
        tester,
        _buildProfile(
          status: DriverStatus.documentsRequired,
          documentsRequiredReason: 'Permis de conduire illisible, merci de le re-téléverser.',
        ),
      );

      expect(find.text(t('driver_status_documents_required')), findsOneWidget);
      expect(find.text(t('driver_status_documents_required_message')), findsOneWidget);
      expect(find.text('Permis de conduire illisible, merci de le re-téléverser.'),
          findsOneWidget);
      expect(_elevatedButtonWithText(t('driver_status_resubmit')), findsOneWidget);

      expect(find.byType(Switch), findsNothing);
      expect(_outlinedButtonWithText(t('driver_status_refresh')), findsNothing);

      expect(fakeRepo.submitForReviewCallCount, 0);
    });

    testWidgets('sans motif serveur (reason vide/null) : aucun encart motif affiché',
        (tester) async {
      await pumpWithStatus(tester, _buildProfile(status: DriverStatus.documentsRequired));

      expect(_elevatedButtonWithText(t('driver_status_resubmit')), findsOneWidget);
      // Pas de `_ReasonBox` : on vérifie simplement l'absence de tout texte
      // de motif résiduel d'un autre scénario.
      expect(find.textContaining('illisible'), findsNothing);
    });

    testWidgets('tap "resoumettre" -> submitForReview() appelé exactement 1 fois -> transition pendingReview',
        (tester) async {
      await pumpWithStatus(
        tester,
        _buildProfile(
          status: DriverStatus.documentsRequired,
          documentsRequiredReason: 'Assurance manquante.',
        ),
      );

      await tester.tap(_elevatedButtonWithText(t('driver_status_resubmit')));
      await tester.pumpAndSettle();

      expect(fakeRepo.submitForReviewCallCount, 1);
      expect(fakeRepo.setDriverOnlineStatusCallCount, 0);
      // Le repository fake fait avancer le profil -> l'écran doit refléter
      // le nouveau statut pendingReview en temps réel.
      expect(find.text(t('driver_status_pending_review')), findsOneWidget);
    });

    testWidgets('double-tap rapide sur "resoumettre" ne déclenche submitForReview qu\'une seule fois',
        (tester) async {
      await pumpWithStatus(
        tester,
        _buildProfile(
          status: DriverStatus.documentsRequired,
          documentsRequiredReason: 'Photo du véhicule manquante.',
        ),
      );
      fakeRepo.pendingSubmitForReviewCompleter = Completer<void>();

      final resubmitButton =
          _elevatedButtonWithText(t('driver_status_resubmit'));
      await tester.ensureVisible(resubmitButton);
      await tester.tap(resubmitButton);
      await tester.pump(); // laisse `_runAction` positionner `busy = true`.

      // Le libellé texte est remplacé par un spinner pendant `busy` -> il
      // faut retrouver le bouton par type, pas par texte (même contrainte
      // que `driver_active_mission_status_gaps_test.dart`).
      final busyButton = _anyElevatedButton;
      expect(tester.widget<ElevatedButton>(busyButton).onPressed, isNull);
      await tester.tap(busyButton, warnIfMissed: false);
      await tester.pump();

      expect(fakeRepo.submitForReviewCallCount, 1);

      fakeRepo.pendingSubmitForReviewCompleter!.complete();
      await tester.pumpAndSettle();
      expect(fakeRepo.submitForReviewCallCount, 1);
    });

    testWidgets('erreur backend sur submitForReview() -> message d\'erreur affiché, statut inchangé',
        (tester) async {
      await pumpWithStatus(
        tester,
        _buildProfile(
          status: DriverStatus.documentsRequired,
          documentsRequiredReason: 'Document expiré.',
        ),
      );
      fakeRepo.submitForReviewError = Exception('PERMISSION_DENIED: dossier verrouillé côté serveur');

      await tester.tap(_elevatedButtonWithText(t('driver_status_resubmit')));
      await tester.pumpAndSettle();

      expect(fakeRepo.submitForReviewCallCount, 1);
      // Le profil n'a PAS avancé (l'erreur a été levée avant `advanceTo`).
      expect(find.text(t('driver_status_documents_required')), findsOneWidget);
      expect(find.text(t('admin_action_error')), findsOneWidget);
    });
  });

  group('approved', () {
    testWidgets('hors-ligne par défaut : switch visible, label offline, aucune autre action',
        (tester) async {
      await pumpWithStatus(
        tester,
        _buildProfile(status: DriverStatus.approved, onlineStatus: DriverOnlineStatus.offline),
      );

      expect(find.text(t('driver_status_approved')), findsOneWidget);
      expect(find.text(t('driver_status_approved_message')), findsOneWidget);
      expect(find.text(t('driver_status_offline_label')), findsOneWidget);
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      expect(tester.widget<Switch>(switchFinder).value, isFalse);

      // Ne doit JAMAIS proposer resoumission/inscription/refresh à ce statut.
      expect(_elevatedButtonWithText(t('driver_status_resubmit')), findsNothing);
      expect(
          _elevatedButtonWithText(t('driver_status_complete_registration')),
          findsNothing);
      expect(_outlinedButtonWithText(t('driver_status_refresh')), findsNothing);

      // CRITIQUE : `approved` ne doit JAMAIS passer online automatiquement
      // (règle explicite du fichier source, point 13 du cahier des
      // charges) — aucun appel repository au premier rendu.
      expect(fakeRepo.setDriverOnlineStatusCallCount, 0);
    });

    testWidgets('bascule online -> setDriverOnlineStatus(uid, true) appelé exactement 1 fois',
        (tester) async {
      await pumpWithStatus(
        tester,
        _buildProfile(status: DriverStatus.approved, onlineStatus: DriverOnlineStatus.offline),
      );

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(fakeRepo.setDriverOnlineStatusCallCount, 1);
      expect(fakeRepo.lastOnlineValue, isTrue);
      expect(find.text(t('driver_status_online_label')), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('déjà online : switch positionné true, label online', (tester) async {
      await pumpWithStatus(
        tester,
        _buildProfile(status: DriverStatus.approved, onlineStatus: DriverOnlineStatus.online),
      );

      expect(find.text(t('driver_status_online_label')), findsOneWidget);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(fakeRepo.setDriverOnlineStatusCallCount, 0);
    });
  });

  group('rejected', () {
    testWidgets('affiche le motif de refus et le CTA "retour accueil" uniquement', (tester) async {
      await pumpWithStatus(
        tester,
        _buildProfile(
          status: DriverStatus.rejected,
          rejectionReason: 'Documents d\'identité non conformes.',
        ),
      );

      expect(find.text(t('driver_status_rejected')), findsOneWidget);
      expect(find.text(t('driver_status_rejected_message')), findsOneWidget);
      expect(find.text('Documents d\'identité non conformes.'), findsOneWidget);
      expect(_outlinedButtonWithText(t('driver_status_go_home')), findsOneWidget);

      // Aucune action interdite : pas de resoumission, pas de switch online.
      expect(_elevatedButtonWithText(t('driver_status_resubmit')), findsNothing);
      expect(find.byType(Switch), findsNothing);

      expect(fakeRepo.submitForReviewCallCount, 0);
      expect(fakeRepo.setDriverOnlineStatusCallCount, 0);
    });

    testWidgets('tap "retour accueil" navigue SANS appeler le repository', (tester) async {
      await pumpWithStatus(tester, _buildProfile(status: DriverStatus.rejected));

      await tester.tap(_outlinedButtonWithText(t('driver_status_go_home')));
      await tester.pumpAndSettle();

      expect(find.text('HOME_STUB'), findsOneWidget);
      expect(fakeRepo.submitForReviewCallCount, 0);
      expect(fakeRepo.setDriverOnlineStatusCallCount, 0);
    });
  });

  group('suspended', () {
    testWidgets('affiche le motif de suspension et le CTA "retour accueil" uniquement, sans switch',
        (tester) async {
      await pumpWithStatus(
        tester,
        _buildProfile(
          status: DriverStatus.suspended,
          suspensionReason: 'Plusieurs signalements clients non résolus.',
        ),
      );

      expect(find.text(t('driver_status_suspended')), findsOneWidget);
      expect(find.text(t('driver_status_suspended_message')), findsOneWidget);
      expect(find.text('Plusieurs signalements clients non résolus.'), findsOneWidget);
      expect(_outlinedButtonWithText(t('driver_status_go_home')), findsOneWidget);

      // CRITIQUE : un chauffeur suspendu ne doit JAMAIS pouvoir se
      // remettre online (aucun switch, aucune action de mise en ligne).
      expect(find.byType(Switch), findsNothing);
      expect(_elevatedButtonWithText(t('driver_status_resubmit')), findsNothing);

      expect(fakeRepo.setDriverOnlineStatusCallCount, 0);
    });
  });

  group('inactive', () {
    testWidgets('affiche le message inactif et le CTA "retour accueil" uniquement, sans switch',
        (tester) async {
      await pumpWithStatus(tester, _buildProfile(status: DriverStatus.inactive));

      expect(find.text(t('driver_status_inactive')), findsOneWidget);
      expect(find.text(t('driver_status_inactive_message')), findsOneWidget);
      expect(_outlinedButtonWithText(t('driver_status_go_home')), findsOneWidget);

      expect(find.byType(Switch), findsNothing);
      expect(_elevatedButtonWithText(t('driver_status_resubmit')), findsNothing);
      expect(
          _elevatedButtonWithText(t('driver_status_complete_registration')),
          findsNothing);

      expect(fakeRepo.setDriverOnlineStatusCallCount, 0);
      expect(fakeRepo.submitForReviewCallCount, 0);
    });
  });

  group('cas transverses', () {
    testWidgets('profil null (getDriverProfile côté flux -> null) : carte erreur "aucun profil" + CTA inscription',
        (tester) async {
      fakeRepo = _FakeDriverRepository(null);
      BackendLocator.driverRepositoryOverride = fakeRepo;
      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      expect(find.text(t('driver_status_no_profile')), findsOneWidget);
      expect(_elevatedButtonWithText(t('driver_status_complete_registration')),
          findsOneWidget);

      await tester.tap(_elevatedButtonWithText(t('driver_status_complete_registration')));
      await tester.pumpAndSettle();
      expect(find.text('REGISTRATION_STUB'), findsOneWidget);
    });

    testWidgets('utilisateur non connecté : redirection vers /connexion sans toucher au repository',
        (tester) async {
      auth.debugForceSignedIn = false;
      auth.debugForceUid = null;

      fakeRepo = _FakeDriverRepository(_buildProfile(status: DriverStatus.approved));
      BackendLocator.driverRepositoryOverride = fakeRepo;
      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      expect(find.text('LOGIN_STUB'), findsOneWidget);
      expect(fakeRepo.submitForReviewCallCount, 0);
      expect(fakeRepo.setDriverOnlineStatusCallCount, 0);
    });
  });
}
