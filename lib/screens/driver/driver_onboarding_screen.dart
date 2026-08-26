// ---------------------------------------------------------------------------
// DriverOnboardingScreen — inscription chauffeur RÉELLE, branchée sur
// FirebaseAuthProvider (compte) + FirebaseDriverRepository (profil/véhicule
// Firestore + Cloud Functions registerAsDriver/submitDriverForReview).
//
// Flux exécuté par _handleSubmit() :
//   1. Créer le compte Firebase Auth (signUpWithEmailPassword) si l'usager
//      n'est pas déjà connecté — écrit users/{uid} avec roles=['customer'].
//   2. Appeler submitDriverOnboarding() : celui-ci invoque la Cloud Function
//      registerAsDriver (ajoute le custom claim `driver`) PUIS crée/MAJ
//      driver_profiles/{uid} avec un statut sûr (jamais approved/rejected).
//   3. Appeler submitDriverVehicle() pour persister le véhicule déclaré à
//      l'étape 2 du formulaire (driver_vehicles/{id}, is_verified=false).
//   4. Rafraîchir le token (refreshClaims) pour que le rôle driver soit
//      visible immédiatement dans cette session.
//   4.5. Téléverser les documents sélectionnés (permis/assurance/photo
//        véhicule) — voir _uploadSelectedDocuments(). Positionné ICI (après
//        le claim `driver` et son rafraîchissement) et non plus tôt, car
//        storage.rules (`driver_documents/{driverId}/{fileName}`, Bloc P)
//        exige isSignedIn() && isDriver() && uid() == driverId : avant ce
//        point du flux, ni le compte ni le custom claim n'existent
//        nécessairement encore.
//   5. Appeler submitForReview() (Cloud Function submitDriverForReview) pour
//      transitionner le profil vers pending_review.
//   6. Afficher _PendingVerificationView.
//
// Si le backend n'est pas configuré (BackendStatus.notConfigured), l'écran
// affiche un message explicite au lieu de simuler un succès.
//
// ---------------------------------------------------------------------------
// BUG-U-01 (Phase 7, Bloc U, U-0) — P1, CORRIGÉ.
//
// Root-cause : les boutons "Photos du véhicule" / "Téléverser le permis" /
// "Téléverser l'assurance" avaient `onPressed: () {}` (aucune action).
// `canProceed` ne vérifiait par ailleurs jamais qu'un document avait été
// fourni : un chauffeur pouvait atteindre pending_review sans AUCUN
// document, et il n'existe aucune autre voie fonctionnelle dans l'app pour
// en fournir (grep exhaustif de driver_status_screen.dart : 0 occurrence de
// submitDriverDocument/ImagePicker/DriverDocument). Classé P1 : un contrôle
// présenté comme upload était inerte et faussait le parcours d'inscription
// attendu.
//
// Correctif : les 3 boutons déclenchent maintenant une vraie sélection de
// fichier (`ImagePicker`, réutilisation du seul mécanisme de sélection déjà
// abstrait dans le repo — voir `driver_active_mission_screen.dart`), avec
// aperçu du fichier sélectionné et possibilité de le remplacer. Le permis et
// l'assurance deviennent obligatoires pour soumettre le dossier
// (`canProceed(3)`) ; la photo du véhicule reste optionnelle (elle vit dans
// l'étape "Véhicule", pas "Documents"). L'upload binaire réel vers Firebase
// Storage (nouveau `DriverDocumentUploadRepository`, même pattern que
// `ProofUploadRepository`) et l'écriture des métadonnées
// (`submitDriverDocument`, déjà existant) sont exécutés dans
// `_uploadSelectedDocuments()`, appelée depuis `_handleSubmit()` juste après
// le rafraîchissement du claim `driver` (étape 4.5 ci-dessus) : AUCUNE
// nouvelle architecture parallèle, réutilisation stricte du repository
// Storage existant, des chemins Storage existants, des règles Storage du
// Bloc P (non modifiées) et du modèle DriverDocument existant. En cas
// d'échec d'upload, aucun faux succès : `_submitError` s'affiche, le
// chauffeur reste sur l'étape Documents avec ses fichiers déjà sélectionnés
// conservés (retry possible en re-soumettant, sans tout re-sélectionner).
// ---------------------------------------------------------------------------

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../backend/backend_locator.dart';
import '../../backend/backend_status.dart';
import '../../backend/models/driver_document.dart';
import '../../backend/models/driver_profile_v2.dart';
import '../../backend/models/driver_vehicle.dart';
import '../../core/app_colors.dart';
import '../../models/enums.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';
import '../../widgets/step_progress_form.dart';

class DriverOnboardingScreen extends StatefulWidget {
  final String locale;
  const DriverOnboardingScreen({super.key, required this.locale});

  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController(text: 'Montréal, QC');
  final _vehicleMakeController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _plateController = TextEditingController();
  final _payloadController = TextEditingController();
  final _hourlyController = TextEditingController();
  final _perKmController = TextEditingController();

  VehicleCategory _vehicleCategory = VehicleCategory.pickupTruck;
  double _radius = 25;
  final Set<String> _categoryKeys = {}; // clés i18n cat_*
  final Set<String> _languages = {'Français'};
  bool _loadingAssistance = false;
  bool _consentVerification = false;
  bool _agreedTerms = false;
  bool _submitted = false;
  bool _submitting = false;
  String? _submitError;

  // BUG-U-01 : fichiers sélectionnés localement pendant le wizard (avant
  // que le compte + claim `driver` existent). L'upload binaire réel n'est
  // déclenché que dans _handleSubmit(), voir en-tête de fichier.
  Uint8List? _licenseBytes;
  String? _licenseFileName;
  Uint8List? _insuranceBytes;
  String? _insuranceFileName;
  Uint8List? _vehiclePhotoBytes;
  String? _vehiclePhotoFileName;
  bool _pickingDocument = false;

  static const _allCategoryKeys = [
    'cat_furniture',
    'cat_appliances',
    'cat_building_materials',
    'cat_pallets',
    'cat_motorcycle',
    'cat_atv',
    'cat_small_move',
  ];
  static const _allLanguages = ['Français', 'English', 'Español'];

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final auth = context.watch<FirebaseAuthProvider>();
    final backendStatus = context.watch<BackendStatus>();

    if (_submitted) {
      return AppShell(
        locale: widget.locale,
        showFooter: false,
        child: _PendingVerificationView(locale: widget.locale),
      );
    }

    return AppShell(
      locale: widget.locale,
      showFooter: false,
      child: ResponsivePadding(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(title: t('driver_onboarding_title'), subtitle: t('driver_onboarding_subtitle')),
              const SizedBox(height: 12),
              if (!backendStatus.isConfigured)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t('driver_onboarding_backend_not_configured'), style: const TextStyle(fontSize: 12.5))),
                  ]),
                ),
              if (_submitError != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_submitError!, style: const TextStyle(fontSize: 12.5, color: AppColors.error))),
                  ]),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: StepProgressForm(
                  stepTitles: [
                    t('driver_onboarding_step_profile'),
                    t('driver_onboarding_step_vehicle'),
                    t('driver_onboarding_step_pricing'),
                    t('driver_onboarding_step_documents'),
                  ],
                  nextLabel: t('common_next'),
                  backLabel: t('common_back'),
                  submitLabel: _submitting ? t('driver_onboarding_submitting') : t('driver_onboarding_submit'),
                  onStepChanged: (_) {},
                  onComplete: _submitting ? () {} : () => _handleSubmit(auth, backendStatus),
                  stepBuilders: [
                    (context) => StepFormCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            // BUG-003 (occurrence DriverOnboarding, Phase 7 Bloc C) :
                            // canProceed(0) lit ces 3 controllers directement ; sans
                            // onChanged->setState, aucun rebuild n'est déclenché à la
                            // frappe et le bouton "Suivant" peut rester figé désactivé
                            // selon l'ordre de saisie (même root-cause que BUG-003 sur
                            // DeliveryRequestFlowScreen, Bloc B).
                            TextField(controller: _nameController, decoration: InputDecoration(labelText: t('auth_full_name')), onChanged: (_) => setState(() {})),
                            const SizedBox(height: 16),
                            TextField(controller: _emailController, decoration: InputDecoration(labelText: t('auth_email')), keyboardType: TextInputType.emailAddress, onChanged: (_) => setState(() {})),
                            const SizedBox(height: 16),
                            TextField(controller: _passwordController, decoration: InputDecoration(labelText: t('driver_onboarding_password_label')), obscureText: true, onChanged: (_) => setState(() {})),
                            const SizedBox(height: 16),
                            TextField(controller: _phoneController, decoration: InputDecoration(labelText: t('auth_phone'))),
                            const SizedBox(height: 16),
                            TextField(controller: _cityController, decoration: InputDecoration(labelText: t('driver_onboarding_city_label'))),
                            const SizedBox(height: 20),
                            Text('${t('driver_onboarding_service_radius_label')}: ${_radius.round()} km', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Slider(value: _radius, min: 5, max: 100, divisions: 19, activeColor: AppColors.primary, onChanged: (v) => setState(() => _radius = v)),
                            const SizedBox(height: 12),
                            Text(t('driver_onboarding_languages_spoken'), style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, children: _allLanguages.map((l) => FilterChip(label: Text(l), selected: _languages.contains(l), onSelected: (_) => setState(() => _languages.contains(l) ? _languages.remove(l) : _languages.add(l)))).toList()),
                          ]),
                        ),
                    (context) => StepFormCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t('driver_onboarding_vehicle_type'), style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: VehicleCategory.values
                                  .where((v) => v != VehicleCategory.other)
                                  .map((v) => ChoiceChip(
                                        label: Text(t(v.key)),
                                        selected: _vehicleCategory == v,
                                        onSelected: (_) => setState(() => _vehicleCategory = v),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 16),
                            TextField(controller: _vehicleMakeController, decoration: InputDecoration(labelText: t('driver_onboarding_make_model'))),
                            const SizedBox(height: 16),
                            TextField(controller: _vehicleYearController, decoration: InputDecoration(labelText: t('driver_onboarding_year')), keyboardType: TextInputType.number),
                            const SizedBox(height: 16),
                            TextField(controller: _plateController, decoration: InputDecoration(labelText: t('driver_onboarding_plate'))),
                            const SizedBox(height: 16),
                            TextField(controller: _payloadController, decoration: InputDecoration(labelText: t('driver_onboarding_max_payload')), keyboardType: TextInputType.number),
                            const SizedBox(height: 16),
                            _DocumentPickerRow(
                              label: t('driver_onboarding_vehicle_photos'),
                              icon: Icons.camera_alt_outlined,
                              fileName: _vehiclePhotoFileName,
                              busy: _pickingDocument,
                              onPick: () => _pickDocument(
                                onPicked: (bytes, name) => setState(() {
                                  _vehiclePhotoBytes = bytes;
                                  _vehiclePhotoFileName = name;
                                }),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(t('driver_onboarding_accepted_item_types'), style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _allCategoryKeys
                                  .map((k) => FilterChip(
                                        label: Text(t(k)),
                                        selected: _categoryKeys.contains(k),
                                        onSelected: (_) => setState(() => _categoryKeys.contains(k) ? _categoryKeys.remove(k) : _categoryKeys.add(k)),
                                      ))
                                  .toList(),
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(t('driver_onboarding_loading_assistance'), style: const TextStyle(fontSize: 14)), value: _loadingAssistance, onChanged: (v) => setState(() => _loadingAssistance = v), activeThumbColor: AppColors.primary),
                          ]),
                        ),
                    (context) => StepFormCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            TextField(controller: _hourlyController, decoration: InputDecoration(labelText: t('driver_onboarding_hourly_rate')), keyboardType: TextInputType.number),
                            const SizedBox(height: 16),
                            TextField(controller: _perKmController, decoration: InputDecoration(labelText: t('driver_onboarding_per_km_rate')), keyboardType: TextInputType.number),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                              child: Row(children: [
                                const Icon(Icons.info_outline, color: AppColors.info, size: 18),
                                const SizedBox(width: 10),
                                Expanded(child: Text(t('driver_onboarding_fees_info'), style: const TextStyle(fontSize: 12.5))),
                              ]),
                            ),
                          ]),
                        ),
                    (context) => StepFormCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _DocumentPickerRow(
                              label: t('driver_onboarding_upload_license'),
                              icon: Icons.badge_outlined,
                              fileName: _licenseFileName,
                              busy: _pickingDocument,
                              onPick: () => _pickDocument(
                                onPicked: (bytes, name) => setState(() {
                                  _licenseBytes = bytes;
                                  _licenseFileName = name;
                                }),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _DocumentPickerRow(
                              label: t('driver_onboarding_upload_insurance'),
                              icon: Icons.description_outlined,
                              fileName: _insuranceFileName,
                              busy: _pickingDocument,
                              onPick: () => _pickDocument(
                                onPicked: (bytes, name) => setState(() {
                                  _insuranceBytes = bytes;
                                  _insuranceFileName = name;
                                }),
                              ),
                            ),
                            const SizedBox(height: 20),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _consentVerification,
                              onChanged: (v) => setState(() => _consentVerification = v ?? false),
                              title: Text(t('driver_onboarding_consent_verification'), style: const TextStyle(fontSize: 13.5)),
                              activeColor: AppColors.primary,
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _agreedTerms,
                              onChanged: (v) => setState(() => _agreedTerms = v ?? false),
                              title: Text(t('driver_onboarding_consent_terms'), style: const TextStyle(fontSize: 13.5)),
                              activeColor: AppColors.primary,
                            ),
                          ]),
                        ),
                  ],
                  canProceed: (step) {
                    if (step == 0) {
                      return _nameController.text.trim().isNotEmpty &&
                          _emailController.text.trim().isNotEmpty &&
                          _passwordController.text.trim().length >= 6;
                    }
                    if (step == 3) {
                      // BUG-U-01 : un dossier ne peut plus être soumis sans
                      // permis ET assurance réellement sélectionnés (avant
                      // ce correctif, canProceed(3) ne vérifiait aucun
                      // document — un chauffeur pouvait atteindre
                      // pending_review sans jamais fournir ces pièces).
                      return _consentVerification &&
                          _agreedTerms &&
                          _licenseBytes != null &&
                          _insuranceBytes != null;
                    }
                    return true;
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit(FirebaseAuthProvider auth, BackendStatus backendStatus) async {
    final t = context.read<LocaleProvider>().t;
    if (!backendStatus.isConfigured) {
      setState(() => _submitError = t('driver_onboarding_error_backend_not_configured'));
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      // 1. Créer le compte Firebase Auth s'il n'existe pas encore de session.
      if (!auth.isSignedIn) {
        final ok = await auth.signUpWithEmailPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _nameController.text.trim(),
        );
        if (!ok) {
          throw Exception(auth.lastError ?? t('driver_onboarding_error_account_creation_failed'));
        }
      }

      final uid = auth.user?.uid;
      if (uid == null) {
        throw Exception(t('driver_onboarding_error_invalid_session'));
      }

      // 2. Créer/mettre à jour le profil d'onboarding (registerAsDriver +
      //    écriture driver_profiles/{uid} avec un statut sûr, jamais approved).
      final profile = DriverProfileV2(
        uid: uid,
        fullName: _nameController.text.trim(),
        city: _cityController.text.trim(),
        status: DriverStatus.registrationIncomplete,
        serviceRadiusKm: _radius,
        acceptedVehicleCategories: [_vehicleCategory],
        acceptedItemCategoryKeys: _categoryKeys.toList(),
        createdAt: DateTime.now(),
      );
      await BackendLocator.driverRepository.submitDriverOnboarding(profile);

      // 3. Persister le véhicule déclaré à l'étape 2.
      final vehicle = DriverVehicle(
        id: const Uuid().v4(),
        driverId: uid,
        category: _vehicleCategory,
        makeModel: _vehicleMakeController.text.trim(),
        year: int.tryParse(_vehicleYearController.text.trim()) ?? 0,
        plate: _plateController.text.trim(),
        maxPayloadKg: double.tryParse(_payloadController.text.trim()),
        isVerified: false,
        createdAt: DateTime.now(),
      );
      await BackendLocator.driverRepository.submitDriverVehicle(vehicle);

      // 4. Rafraîchir le token pour que le custom claim `driver` (ajouté par
      //    registerAsDriver côté serveur) soit visible immédiatement.
      await auth.refreshClaims();

      // 4.5. BUG-U-01 : téléverser les documents sélectionnés (permis,
      //      assurance, photo véhicule le cas échéant). DOIT être exécuté
      //      APRÈS le refreshClaims() ci-dessus : storage.rules exige le
      //      custom claim `driver` (isDriver()) pour écrire sous
      //      driver_documents/{driverId}/..., qui n'existe/n'est visible
      //      qu'à partir de ce point du flux.
      await _uploadSelectedDocuments(uid);

      // 5. Transitionner le profil vers pending_review (Cloud Function
      //    submitDriverForReview — le client ne peut jamais écrire ce champ
      //    directement, voir firestore.rules).
      await BackendLocator.driverRepository.submitForReview();

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = '${t('driver_onboarding_error_generic_prefix')} $e';
      });
    }
  }

  /// BUG-U-01 : sélection RÉELLE d'un fichier (photo ou PDF) via
  /// `ImagePicker`, réutilisation du seul mécanisme de sélection déjà
  /// abstrait dans le repo (voir `driver_active_mission_screen.dart`,
  /// `_capturePhotoAndCompleteDelivery`). Ne fait AUCUN upload Storage à ce
  /// stade — le compte/claim `driver` peuvent ne pas encore exister (le
  /// bouton vit dans le wizard, avant soumission finale). L'upload binaire
  /// réel n'a lieu que dans `_uploadSelectedDocuments()`, appelée depuis
  /// `_handleSubmit()`.
  ///
  /// `image_picker` ne propose pas de sélection de PDF ; pour les documents
  /// qui l'autorisent côté Storage (permis, assurance — cf.
  /// `isValidDocumentUpload()` dans storage.rules, image OU PDF), on
  /// propose galerie (photo d'un document papier) ou caméra, ce qui reste
  /// suffisant en pratique. Aucun nouveau package externe introduit,
  /// conformément à la consigne (réutilisation stricte de `image_picker`,
  /// déjà une dépendance du projet).
  Future<void> _pickDocument({
    required void Function(Uint8List bytes, String fileName) onPicked,
  }) async {
    if (_pickingDocument) return;
    final t = context.read<LocaleProvider>().t;
    setState(() => _pickingDocument = true);
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(t('driver_onboarding_document_source_camera')),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(t('driver_onboarding_document_source_gallery')),
                onTap: () => Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null || !mounted) return;

      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      onPicked(bytes, picked.name);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitError = t('driver_onboarding_error_document_pick_failed'));
    } finally {
      if (mounted) setState(() => _pickingDocument = false);
    }
  }

  /// BUG-U-01 : upload binaire RÉEL des documents sélectionnés + écriture
  /// des métadonnées Firestore (`submitDriverDocument`, déjà existant).
  /// Réutilise le repository Storage (nouveau `DriverDocumentUploadRepository`,
  /// même pattern que `ProofUploadRepository`), les chemins Storage
  /// existants (`driver_documents/{driverId}/{fileName}`, storage.rules
  /// Bloc P, non modifiés) et le modèle `DriverDocument` existant. Aucun
  /// faux succès : toute exception se propage à `_handleSubmit()`, qui
  /// affiche `_submitError` sans jamais transitionner vers pending_review.
  Future<void> _uploadSelectedDocuments(String uid) async {
    final uploadRepo = BackendLocator.driverDocumentUploadRepository;
    final driverRepo = BackendLocator.driverRepository;

    Future<void> uploadOne({
      required Uint8List bytes,
      required String originalFileName,
      required DriverDocumentType type,
    }) async {
      final extension = originalFileName.contains('.')
          ? originalFileName.split('.').last.toLowerCase()
          : 'jpg';
      final contentType = extension == 'pdf' ? 'application/pdf' : 'image/jpeg';
      final fileName =
          '${type.firestoreValue}_${DateTime.now().millisecondsSinceEpoch}.$extension';

      // L'URL de téléchargement retournée n'est pas persistée telle quelle
      // (voir doc de `DriverDocument.storageBucketPath` : jamais d'URL
      // publique permanente stockée, une URL signée à courte durée de vie
      // est régénérée à la demande côté analyste) — seul le chemin Storage
      // fixe et déterministe est conservé.
      await uploadRepo.uploadDriverDocument(
        driverId: uid,
        fileName: fileName,
        bytes: bytes,
        contentType: contentType,
      );

      await driverRepo.submitDriverDocument(DriverDocument(
        id: const Uuid().v4(),
        driverId: uid,
        type: type,
        status: DriverDocumentStatus.uploaded,
        storageBucketPath: 'driver_documents/$uid/$fileName',
        uploadedAt: DateTime.now(),
      ));
    }

    if (_licenseBytes != null) {
      await uploadOne(
        bytes: _licenseBytes!,
        originalFileName: _licenseFileName ?? 'license.jpg',
        type: DriverDocumentType.driversLicence,
      );
    }
    if (_insuranceBytes != null) {
      await uploadOne(
        bytes: _insuranceBytes!,
        originalFileName: _insuranceFileName ?? 'insurance.jpg',
        type: DriverDocumentType.insurance,
      );
    }
    if (_vehiclePhotoBytes != null) {
      await uploadOne(
        bytes: _vehiclePhotoBytes!,
        originalFileName: _vehiclePhotoFileName ?? 'vehicle_photo.jpg',
        type: DriverDocumentType.vehiclePhoto,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _vehicleMakeController.dispose();
    _vehicleYearController.dispose();
    _plateController.dispose();
    _payloadController.dispose();
    _hourlyController.dispose();
    _perKmController.dispose();
    super.dispose();
  }
}

class _PendingVerificationView extends StatelessWidget {
  final String locale;
  const _PendingVerificationView({required this.locale});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const SizedBox(height: 40),
            Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), shape: BoxShape.circle), child: const Icon(Icons.hourglass_top_rounded, color: AppColors.warning, size: 40)),
            const SizedBox(height: 24),
            Text(t('driver_pending_verification'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              t('driver_onboarding_pending_message'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton(onPressed: () => context.go('/$locale/devenir-chauffeur/statut'), child: Text(t('driver_status_go_to_dashboard'))),
            const SizedBox(height: 12),
            TextButton(onPressed: () => context.go('/$locale'), child: Text(t('nav_home'))),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }
}

/// BUG-U-01 — remplace les anciens `OutlinedButton.icon(onPressed: () {})`.
/// Affiche l'état réel du document (aucun sélectionné / nom de fichier
/// sélectionné) et permet de le remplacer ("Modifier"). AUCUN faux succès :
/// l'état "sélectionné" reflète uniquement une sélection locale confirmée
/// par `image_picker` (l'upload Storage réel n'a lieu qu'à la soumission
/// finale du wizard, voir `_uploadSelectedDocuments`).
class _DocumentPickerRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? fileName;
  final bool busy;
  final VoidCallback onPick;

  const _DocumentPickerRow({
    required this.label,
    required this.icon,
    required this.fileName,
    required this.busy,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final hasFile = fileName != null;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: hasFile ? AppColors.success : AppColors.border),
        borderRadius: BorderRadius.circular(12),
        color: hasFile ? AppColors.success.withValues(alpha: 0.06) : null,
      ),
      child: Row(
        children: [
          Icon(hasFile ? Icons.check_circle : icon, color: hasFile ? AppColors.success : AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(
                  hasFile ? fileName! : t('driver_onboarding_document_none_selected'),
                  style: TextStyle(
                    fontSize: 11.5,
                    color: hasFile ? AppColors.success : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: busy ? null : onPick,
            child: busy
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(hasFile ? t('driver_onboarding_document_edit') : t('driver_onboarding_document_select')),
          ),
        ],
      ),
    );
  }
}
