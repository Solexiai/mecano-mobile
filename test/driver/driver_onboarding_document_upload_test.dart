// ---------------------------------------------------------------------------
// Test widget — DriverOnboardingScreen : documents chauffeur (BUG-U-01,
// Phase 7, Bloc U, U-0 — "dead upload button").
//
// AVANT le correctif : les boutons "Photos du véhicule" / "Téléverser le
// permis" / "Téléverser l'assurance" avaient `onPressed: () {}` — aucune
// action réelle. Ce fichier est le test de régression permanent prouvant
// que ce n'est plus le cas, et couvre exactement les 4 scénarios demandés :
//
//   1. tap "Sélectionner" (permis) -> action réelle déclenchée (le picker
//      caméra/galerie est réellement sollicité).
//   2. upload réussi -> état UI mis à jour (nom de fichier affiché) ET
//      document réellement transmis au backend (upload binaire + métadonnées
//      Firestore via submitDriverDocument), jamais de faux succès.
//   3. upload échoué -> erreur visible (`_submitError`), AUCUNE transition
//      vers pending_review (`submitForReview` jamais appelé), retry
//      possible (le formulaire reste sur l'étape Documents, fichiers déjà
//      sélectionnés conservés).
//   4. document déjà présent -> re-sélection ("Modifier") remplace l'ancien
//      fichier sans dupliquer l'état (un seul fichier retenu par type).
//
// STRATÉGIE (réutilise l'architecture existante, ne la réécrit pas) — même
// pattern EXACT que `driver_active_mission_proof_upload_test.dart` :
//   - `FakeImagePickerPlatform extends ImagePickerPlatform` (requis pour
//     `PlatformInterface.verify`).
//   - `BackendLocator.driverDocumentUploadRepositoryOverride` avec des fakes
//     succès/échec.
//   - `BackendLocator.driverRepositoryOverride` avec un fake qui compte les
//     appels à `submitDriverDocument`/`submitForReview`/`submitDriverOnboarding`/
//     `submitDriverVehicle` (jamais d'écriture Firestore réelle).
//   - `FirebaseAuthProvider(backendConfigured: false)` +
//     `debugForceSignedIn`/`debugForceUid` (chauffeur déjà connecté : couvre
//     directement le chemin `effectiveUid`, sans dépendre de
//     `signUpWithEmailPassword`/Firebase Auth réel).
//   - `Provider<BackendStatus>.value(value: const BackendStatus.ready())`
//     pour ne pas être bloqué par le bandeau "backend non configuré".
// ---------------------------------------------------------------------------

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:provider/provider.dart';

import 'package:movik_connect/backend/backend_exceptions.dart';
import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/backend_status.dart';
import 'package:movik_connect/backend/models/driver_document.dart';
import 'package:movik_connect/backend/models/driver_internal_note.dart';
import 'package:movik_connect/backend/models/driver_profile_v2.dart';
import 'package:movik_connect/backend/models/driver_vehicle.dart';
import 'package:movik_connect/backend/repositories/driver_document_upload_repository.dart';
import 'package:movik_connect/backend/repositories/driver_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/driver/driver_onboarding_screen.dart';

const _driverId = 'driver_onboarding_upload_test_uid';

/// Simule la sélection caméra/galerie sans dépendre du vrai plugin natif —
/// `extends` (jamais `implements`) requis pour que `PlatformInterface.verify`
/// accepte l'instance (même contrainte que `driver_active_mission_proof_upload_test.dart`).
class FakeImagePickerPlatform extends ImagePickerPlatform {
  int pickImageCallCount = 0;
  int _fileCounter = 0;

  // Un PNG 1x1 valide minimal (pas de contrainte de preview ici, mais garde
  // la cohérence avec le reste du repo : jamais d'octets arbitraires non
  // décodables passés comme "fichier sélectionné").
  static final Uint8List _validPng = Uint8List.fromList(const [
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
    pickImageCallCount++;
    _fileCounter++;
    // IMPORTANT : sur la plateforme `dart:io` (celle utilisée par
    // `flutter test`), `XFile.name` dérive de `path` (voir
    // `cross_file/lib/src/types/io.dart`), PAS du paramètre `name` — passer
    // uniquement `name:` ici laisserait `picked.name` retourner `''` en
    // test (alors qu'en production, sur mobile réel, le plugin natif
    // fournit un vrai `path` et `name` fonctionne normalement). On fournit
    // donc `path:` pour que le comportement testé (`onPicked(bytes,
    // picked.name)` dans `_pickDocument`) soit fidèle à la réalité.
    return XFile.fromData(
      _validPng,
      path: 'doc_$_fileCounter.jpg',
      name: 'doc_$_fileCounter.jpg',
      mimeType: 'image/jpeg',
    );
  }
}

/// `DriverDocumentUploadRepository` fake — échoue systématiquement, comme un
/// vrai échec réseau/permission Storage/quota le ferait.
class _FailingDriverDocumentUploadRepository
    implements DriverDocumentUploadRepository {
  int callCount = 0;

  @override
  Future<String> uploadDriverDocument({
    required String driverId,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  }) async {
    callCount++;
    throw Exception('Échec réseau Firebase Storage (simulation test)');
  }
}

/// `DriverDocumentUploadRepository` fake — succès, retourne une URL
/// déterministe pour vérifier qu'aucune URL fictive n'est construite côté
/// client.
class _SucceedingDriverDocumentUploadRepository
    implements DriverDocumentUploadRepository {
  int callCount = 0;
  final List<String> uploadedFileNames = [];

  @override
  Future<String> uploadDriverDocument({
    required String driverId,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  }) async {
    callCount++;
    uploadedFileNames.add(fileName);
    return 'https://storage.example.com/driver_documents/$driverId/$fileName';
  }
}

/// `DriverRepository` fake minimal — observe les écritures déclenchées par
/// `_handleSubmit()` (onboarding, véhicule, documents, soumission finale)
/// sans dépendre de Firebase. Toutes les méthodes non utilisées par ce
/// parcours lèvent `UnimplementedError` (même convention que
/// `_FakeMissionRepository` dans `driver_active_mission_proof_upload_test.dart`).
class _FakeDriverRepository implements DriverRepository {
  int submitDriverOnboardingCallCount = 0;
  int submitDriverVehicleCallCount = 0;
  int submitForReviewCallCount = 0;
  final List<DriverDocument> submittedDocuments = [];

  @override
  Future<void> submitDriverOnboarding(DriverProfileV2 profile) async {
    submitDriverOnboardingCallCount++;
  }

  @override
  Future<void> submitDriverVehicle(DriverVehicle vehicle) async {
    submitDriverVehicleCallCount++;
  }

  @override
  Future<void> submitDriverDocument(DriverDocument document) async {
    submittedDocuments.add(document);
  }

  @override
  Future<void> submitForReview() async {
    submitForReviewCallCount++;
  }

  // ---- Méthodes non utilisées par ce parcours de test ----
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
  Future<void> addDriverInternalNote(String driverId, String text) =>
      throw UnimplementedError();

  @override
  Stream<List<DriverInternalNote>> watchDriverInternalNotes(String driverId) =>
      throw UnimplementedError();

  @override
  Future<void> logDriverReviewOpened(String driverId) => throw UnimplementedError();

  @override
  Future<void> setDriverOnlineStatus(String driverId, bool online) =>
      throw UnimplementedError();
}

/// `DriverRepository` fake — simule un refus par kill switch (Bloc X) sur
/// `submitDriverOnboarding`, pour la régression AB-4-A ci-dessous.
class _KillSwitchDriverRepository implements DriverRepository {
  @override
  Future<void> submitDriverOnboarding(DriverProfileV2 profile) async {
    throw const CloudFunctionException('failed-precondition', kKillSwitchServerMessage);
  }

  @override
  Future<void> submitDriverVehicle(DriverVehicle vehicle) => throw UnimplementedError();
  @override
  Future<void> submitDriverDocument(DriverDocument document) => throw UnimplementedError();
  @override
  Future<void> submitForReview() => throw UnimplementedError();
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
  Stream<List<DriverProfileV2>> watchPendingReviewDrivers() => throw UnimplementedError();
  @override
  Stream<List<DriverProfileV2>> watchDriversByStatus(DriverStatus? status) => throw UnimplementedError();
  @override
  Future<void> approveDriver(String driverId) => throw UnimplementedError();
  @override
  Future<void> rejectDriver(String driverId, String reason) => throw UnimplementedError();
  @override
  Future<void> requestDriverDocuments(String driverId, String reason) => throw UnimplementedError();
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

Widget _buildTestApp(FirebaseAuthProvider auth) {
  final router = GoRouter(
    initialLocation: '/fr/devenir-chauffeur/inscription',
    routes: [
      GoRoute(
        path: '/fr/devenir-chauffeur/inscription',
        builder: (context, state) => const DriverOnboardingScreen(locale: 'fr'),
      ),
      GoRoute(
        path: '/fr/devenir-chauffeur/statut',
        builder: (context, state) => const Scaffold(body: Text('STATUS_STUB')),
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

void main() {
  late FakeImagePickerPlatform fakeImagePicker;
  late _FakeDriverRepository fakeDriverRepo;
  late FirebaseAuthProvider auth;

  setUp(() {
    fakeImagePicker = FakeImagePickerPlatform();
    ImagePickerPlatform.instance = fakeImagePicker;

    fakeDriverRepo = _FakeDriverRepository();
    BackendLocator.driverRepositoryOverride = fakeDriverRepo;

    auth = FirebaseAuthProvider(backendConfigured: false);
    auth.debugForceSignedIn = true;
    auth.debugForceUid = _driverId;
    auth.debugForceDisplayName = 'Chauffeur Test';
  });

  tearDown(() {
    // CRITIQUE : toujours remettre les seams de test à `null` pour ne
    // jamais laisser un fake fuiter vers un autre test.
    BackendLocator.driverRepositoryOverride = null;
    BackendLocator.driverDocumentUploadRepositoryOverride = null;
  });

  /// Amène le wizard jusqu'à l'étape 3 (Documents) : remplit l'étape 0
  /// (Profil) avec des valeurs valides, puis avance 3 fois (Véhicule et
  /// Tarification n'ont aucune contrainte `canProceed` bloquante).
  Future<void> goToDocumentsStep(WidgetTester tester) async {
    final nameField = find.byType(TextField).at(0);
    final emailField = find.byType(TextField).at(1);
    final passwordField = find.byType(TextField).at(2);

    await tester.enterText(nameField, 'Jean Tremblay');
    await tester.enterText(emailField, 'jean.tremblay@example.com');
    await tester.enterText(passwordField, 'motdepasse123');
    await tester.pump();

    for (var i = 0; i < 3; i++) {
      final nextButton = find.widgetWithText(ElevatedButton, AppStrings.t('common_next', 'fr'));
      await tester.ensureVisible(nextButton);
      await tester.pumpAndSettle();
      await tester.tap(nextButton);
      await tester.pumpAndSettle();
    }
  }

  /// Tape sur le bouton "Sélectionner"/"Modifier" du `_DocumentPickerRow`
  /// portant `label`, puis choisit "camera" dans le bottom sheet ouvert.
  ///
  /// NOTE : `pumpAndSettle()` time out ici (`showModalBottomSheet` combiné
  /// au `FakeImagePickerPlatform` laisse une animation/route en cours qui
  /// ne se stabilise jamais dans ce harnais de test) — on utilise donc des
  /// `pump(duration)` bornés à la place, suffisants pour laisser les
  /// futures asynchrones (ouverture du sheet, lecture des bytes du fichier
  /// simulé, `setState`) se résoudre sans dépendre d'un état "settled"
  /// strict.
  Future<void> tapDocumentPicker(WidgetTester tester, String label) async {
    final row = find.ancestor(
      of: find.text(label),
      matching: find.byType(Container),
    ).first;
    final pickButton = find.descendant(of: row, matching: find.byType(OutlinedButton));
    await tester.ensureVisible(pickButton);
    await tester.pump();
    await tester.tap(pickButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Bottom sheet ouvert : choisir "Prendre une photo" (caméra).
    final cameraOption = find.text(AppStrings.t('driver_onboarding_document_source_camera', 'fr'));
    expect(cameraOption, findsOneWidget);
    await tester.tap(cameraOption);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
    '1) tap "Sélectionner" (permis) -> action réelle déclenchée (picker sollicité, état UI mis à jour)',
    (tester) async {
      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();
      await goToDocumentsStep(tester);

      // AVANT sélection : aucun fichier, libellé "Aucun fichier sélectionné".
      expect(
        find.text(AppStrings.t('driver_onboarding_document_none_selected', 'fr')),
        findsNWidgets(2), // permis + assurance, aucun sélectionné
      );

      await tapDocumentPicker(tester, AppStrings.t('driver_onboarding_upload_license', 'fr'));

      // 1. Le fake picker a bien été sollicité : ce n'est plus un bouton
      // inerte, une vraie action de sélection a été déclenchée.
      expect(fakeImagePicker.pickImageCallCount, 1);

      // 2. L'état UI reflète immédiatement la sélection (nom de fichier
      // affiché à la place de "Aucun fichier sélectionné").
      expect(find.text('doc_1.jpg'), findsOneWidget);
      expect(
        find.text(AppStrings.t('driver_onboarding_document_none_selected', 'fr')),
        findsOneWidget, // il n'en reste qu'un (assurance, pas encore sélectionnée)
      );
    },
  );

  testWidgets(
    '2) upload réussi -> document réellement transmis (upload binaire + métadonnées), jamais de faux succès',
    (tester) async {
      final succeedingRepo = _SucceedingDriverDocumentUploadRepository();
      BackendLocator.driverDocumentUploadRepositoryOverride = succeedingRepo;

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();
      await goToDocumentsStep(tester);

      await tapDocumentPicker(tester, AppStrings.t('driver_onboarding_upload_license', 'fr'));
      await tapDocumentPicker(tester, AppStrings.t('driver_onboarding_upload_insurance', 'fr'));

      // Cocher les 2 consentements requis par canProceed(3).
      await tester.tap(find.byType(CheckboxListTile).at(0));
      await tester.pump();
      await tester.tap(find.byType(CheckboxListTile).at(1));
      await tester.pump();

      final submitButton = find.widgetWithText(
        ElevatedButton,
        AppStrings.t('driver_onboarding_submit', 'fr'),
      );
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(submitButton).onPressed, isNotNull);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // 1. Upload binaire réellement effectué pour les 2 documents requis
      // (permis + assurance), jamais simulé côté client.
      expect(succeedingRepo.callCount, 2);

      // 2. Métadonnées Firestore réellement écrites via submitDriverDocument,
      // avec le statut `uploaded` (jamais `missing`/`pendingReview` à ce
      // stade) et le bon driverId (jamais un id fictif ou vide).
      expect(fakeDriverRepo.submittedDocuments.length, 2);
      for (final doc in fakeDriverRepo.submittedDocuments) {
        expect(doc.driverId, _driverId);
        expect(doc.status, DriverDocumentStatus.uploaded);
      }
      expect(
        fakeDriverRepo.submittedDocuments.map((d) => d.type),
        containsAll([DriverDocumentType.driversLicence, DriverDocumentType.insurance]),
      );

      // 3. Le flux complet a bien progressé jusqu'à la soumission finale
      // (pending_review) — preuve que l'upload n'est pas juste local mais
      // bien intégré dans _handleSubmit() sans bloquer le parcours normal.
      expect(fakeDriverRepo.submitForReviewCallCount, 1);
      expect(fakeDriverRepo.submitDriverOnboardingCallCount, 1);
      expect(fakeDriverRepo.submitDriverVehicleCallCount, 1);

      // 4. Écran de confirmation affiché (pas de message d'erreur résiduel).
      expect(find.text(AppStrings.t('driver_pending_verification', 'fr')), findsOneWidget);
    },
  );

  testWidgets(
    '3) upload échoué -> erreur visible, AUCUNE transition pending_review, retry possible',
    (tester) async {
      final failingRepo = _FailingDriverDocumentUploadRepository();
      BackendLocator.driverDocumentUploadRepositoryOverride = failingRepo;

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();
      await goToDocumentsStep(tester);

      await tapDocumentPicker(tester, AppStrings.t('driver_onboarding_upload_license', 'fr'));
      await tapDocumentPicker(tester, AppStrings.t('driver_onboarding_upload_insurance', 'fr'));
      await tester.tap(find.byType(CheckboxListTile).at(0));
      await tester.pump();
      await tester.tap(find.byType(CheckboxListTile).at(1));
      await tester.pump();

      final submitButton = find.widgetWithText(
        ElevatedButton,
        AppStrings.t('driver_onboarding_submit', 'fr'),
      );
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // 1. L'upload a bien été tenté (le fake a throw dès le 1er document).
      expect(failingRepo.callCount, greaterThanOrEqualTo(1));

      // 2. AUCUN faux succès : submitForReview n'est JAMAIS appelé si
      // l'upload échoue (aucune transition vers pending_review avec un
      // dossier documentaire incomplet/fictif).
      expect(fakeDriverRepo.submitForReviewCallCount, 0);

      // 3. Message d'erreur visible (pas de crash silencieux, pas d'écran
      // "en attente" trompeur).
      expect(find.textContaining(AppStrings.t('driver_onboarding_error_generic_prefix', 'fr')), findsOneWidget);
      expect(find.text(AppStrings.t('driver_pending_verification', 'fr')), findsNothing);

      // 4. Retry possible : le formulaire reste affiché (pas de blocage
      // permanent), le bouton de soumission est réactivé (onPressed non
      // null), et les fichiers déjà sélectionnés sont CONSERVÉS (l'usager
      // n'a pas à tout re-choisir avant de réessayer).
      final retrySubmitButton = tester.widget<ElevatedButton>(submitButton);
      expect(retrySubmitButton.onPressed, isNotNull);
      expect(find.text('doc_1.jpg'), findsOneWidget);
      expect(find.text('doc_2.jpg'), findsOneWidget);
    },
  );

  testWidgets(
    '4) document déjà présent -> re-sélection ("Modifier") remplace l\'ancien fichier sans dupliquer l\'état',
    (tester) async {
      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();
      await goToDocumentsStep(tester);

      // Première sélection : bouton affiche "Sélectionner".
      expect(
        find.widgetWithText(OutlinedButton, AppStrings.t('driver_onboarding_document_select', 'fr')),
        findsNWidgets(2), // permis + assurance
      );
      await tapDocumentPicker(tester, AppStrings.t('driver_onboarding_upload_license', 'fr'));
      expect(find.text('doc_1.jpg'), findsOneWidget);

      // Une fois un fichier présent, le bouton devient "Modifier" (jamais
      // un second bouton "Sélectionner" qui laisserait croire à un ajout).
      expect(
        find.widgetWithText(OutlinedButton, AppStrings.t('driver_onboarding_document_edit', 'fr')),
        findsOneWidget,
      );

      // Re-sélection ("Modifier") : remplace l'ancien fichier, ne
      // l'additionne pas — un seul nom de fichier affiché pour le permis
      // à la fois (état cohérent, pas de duplication).
      await tapDocumentPicker(tester, AppStrings.t('driver_onboarding_upload_license', 'fr'));

      expect(fakeImagePicker.pickImageCallCount, 2);
      expect(find.text('doc_1.jpg'), findsNothing);
      expect(find.text('doc_2.jpg'), findsOneWidget);

      // canProceed(3) reste cohérent : l'assurance n'a toujours pas été
      // fournie, donc le dossier ne peut toujours pas être soumis
      // uniquement sur la base du permis (même après un "Modifier").
      final submitButton = find.widgetWithText(
        ElevatedButton,
        AppStrings.t('driver_onboarding_submit', 'fr'),
      );
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(submitButton).onPressed, isNull);
    },
  );

  testWidgets(
    'Phase 7, Bloc AB (AB-4, gap AB-4-A) -> texte brut backend JAMAIS affiché, message générique traduit affiché à la place',
    (tester) async {
      final failingRepo = _FailingDriverDocumentUploadRepository();
      BackendLocator.driverDocumentUploadRepositoryOverride = failingRepo;

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();
      await goToDocumentsStep(tester);

      await tapDocumentPicker(tester, AppStrings.t('driver_onboarding_upload_license', 'fr'));
      await tapDocumentPicker(tester, AppStrings.t('driver_onboarding_upload_insurance', 'fr'));
      await tester.tap(find.byType(CheckboxListTile).at(0));
      await tester.pump();
      await tester.tap(find.byType(CheckboxListTile).at(1));
      await tester.pump();

      final submitButton = find.widgetWithText(
        ElevatedButton,
        AppStrings.t('driver_onboarding_submit', 'fr'),
      );
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // GAP AB-4-A (avant correctif) : `_submitError` concatenait le
      // préfixe traduit avec `e.toString()` brut, ce qui affichait
      // littéralement le texte interne de l'exception simulée ici
      // ("Échec réseau Firebase Storage (simulation test)") à l'écran.
      // Ce texte ne doit PLUS JAMAIS apparaître dans l'arbre de widgets.
      expect(
        find.textContaining('Échec réseau Firebase Storage (simulation test)'),
        findsNothing,
      );
      expect(find.textContaining('Exception:'), findsNothing);

      // Seul le message entièrement traduit doit être visible.
      expect(
        find.text(AppStrings.t('driver_onboarding_error_generic_prefix', 'fr')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Phase 7, Bloc AB (AB-4, gap AB-4-A régression) -> refus kill switch mappé vers service_temporarily_unavailable, jamais le préfixe générique',
    (tester) async {
      // Défense en profondeur : même si aucun chemin connu de l'inscription
      // n'est actuellement protégé par un kill switch, on vérifie que SI
      // une des 3 écritures (`submitDriverOnboarding`/`submitDriverVehicle`/
      // `submitForReview`) venait à lever un refus kill switch, l'écran ne
      // l'afficherait jamais comme une erreur d'inscription ordinaire.
      final killSwitchRepo = _KillSwitchDriverRepository();
      BackendLocator.driverRepositoryOverride = killSwitchRepo;

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();
      await goToDocumentsStep(tester);

      await tapDocumentPicker(tester, AppStrings.t('driver_onboarding_upload_license', 'fr'));
      await tapDocumentPicker(tester, AppStrings.t('driver_onboarding_upload_insurance', 'fr'));
      await tester.tap(find.byType(CheckboxListTile).at(0));
      await tester.pump();
      await tester.tap(find.byType(CheckboxListTile).at(1));
      await tester.pump();

      final submitButton = find.widgetWithText(
        ElevatedButton,
        AppStrings.t('driver_onboarding_submit', 'fr'),
      );
      await tester.ensureVisible(submitButton);
      await tester.pumpAndSettle();
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(
        find.text(AppStrings.t('service_temporarily_unavailable', 'fr')),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.t('driver_onboarding_error_generic_prefix', 'fr')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'NotConfiguredDriverDocumentUploadRepository (aucun seam positionné) échoue proprement sans faux succès',
    (tester) async {
      expect(BackendLocator.driverDocumentUploadRepositoryOverride, isNull);
      expect(
        () => const NotConfiguredDriverDocumentUploadRepository().uploadDriverDocument(
          driverId: _driverId,
          fileName: 'x.jpg',
          bytes: const [1, 2, 3],
          contentType: 'image/jpeg',
        ),
        throwsA(isA<Exception>()),
      );
    },
  );
}
