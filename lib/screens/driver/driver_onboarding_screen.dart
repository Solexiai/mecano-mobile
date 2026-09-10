import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../backend/backend_exceptions.dart';
import '../../backend/backend_locator.dart';
import '../../backend/backend_status.dart';
import '../../backend/models/driver_document.dart';
import '../../backend/models/driver_profile_v2.dart';
import '../../backend/models/driver_vehicle.dart';
import '../../core/app_colors.dart';
import '../../l10n/driver_onboarding_copy.dart';
import '../../models/enums.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/address/address_suggestion.dart';
import '../../widgets/address_autocomplete_field.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';
import '../../widgets/step_progress_form.dart';

/// Four-step driver registration flow.
///
/// The form deliberately separates identity/contact information, vehicle
/// information, delivery-area preferences, and verification documents. The
/// service-base address is resolved through the same address abstraction used
/// by delivery requests so the radius can be anchored to real coordinates.
class DriverOnboardingScreen extends StatefulWidget {
  final String locale;
  const DriverOnboardingScreen({super.key, required this.locale});

  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  // Step 1 — contact / service base.
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalCodeController = TextEditingController();
  ResolvedAddress? _resolvedBaseAddress;
  final Set<String> _languages = {'fr'};

  // Step 2 — vehicle.
  VehicleCategory? _vehicleCategory;
  final _vehicleMakeController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _plateController = TextEditingController();
  final _payloadController = TextEditingController();

  // Step 3 — service area and delivery preferences.
  double _radius = 25;
  final Set<String> _categoryKeys = {};
  bool _loadingAssistance = false;

  // Step 4 — verification documents.
  Uint8List? _licenseBytes;
  String? _licenseFileName;
  Uint8List? _registrationBytes;
  String? _registrationFileName;
  Uint8List? _insuranceBytes;
  String? _insuranceFileName;
  Uint8List? _identityBytes;
  String? _identityFileName;
  Uint8List? _vehiclePhotoBytes;
  String? _vehiclePhotoFileName;

  bool _consentVerification = false;
  bool _agreedTerms = false;
  bool _submitted = false;
  bool _submitting = false;
  bool _pickingDocument = false;
  bool _authFieldsSeeded = false;
  String? _submitError;

  static const _allCategoryKeys = [
    'cat_furniture',
    'cat_appliances',
    'cat_marketplace',
    'cat_building_materials',
    'cat_pallets',
    'cat_equipment',
    'cat_bbq',
    'cat_tv',
    'cat_boxes',
    'cat_motorcycle',
    'cat_atv',
    'cat_small_move',
  ];

  static const _allLanguages = <(String, String)>[
    ('fr', 'Français'),
    ('en', 'English'),
    ('es', 'Español'),
  ];

  String _copy(String key) => DriverOnboardingCopy.text(widget.locale, key);

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final auth = context.watch<FirebaseAuthProvider>();
    final backendStatus = context.watch<BackendStatus>();

    _seedAuthenticatedAccountFields(auth);

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
              SectionTitle(
                title: t('driver_onboarding_title'),
                subtitle: _copy('subtitle'),
              ),
              const SizedBox(height: 16),
              if (!backendStatus.isConfigured)
                _NoticeBox(
                  icon: Icons.warning_amber_rounded,
                  text: t('driver_onboarding_backend_not_configured'),
                  color: AppColors.warning,
                ),
              if (_submitError != null) ...[
                _NoticeBox(
                  icon: Icons.error_outline,
                  text: _submitError!,
                  color: AppColors.error,
                ),
                const SizedBox(height: 12),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: StepProgressForm(
                  stepTitles: [
                    _copy('step_contact'),
                    _copy('step_vehicle'),
                    _copy('step_services'),
                    _copy('step_documents'),
                  ],
                  nextLabel: t('common_next'),
                  backLabel: t('common_back'),
                  submitLabel: _submitting
                      ? t('driver_onboarding_submitting')
                      : t('driver_onboarding_submit'),
                  onStepChanged: (_) {
                    if (_submitError != null) {
                      setState(() => _submitError = null);
                    }
                  },
                  onComplete: _submitting
                      ? () {}
                      : () => _handleSubmit(auth, backendStatus),
                  stepBuilders: [
                    (context) => _buildContactStep(context, auth, t),
                    (context) => _buildVehicleStep(context, t),
                    (context) => _buildServicesStep(context, t),
                    (context) => _buildDocumentsStep(context, t),
                  ],
                  canProceed: (step) => _canProceed(step, auth),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _seedAuthenticatedAccountFields(FirebaseAuthProvider auth) {
    if (!auth.isSignedIn || _authFieldsSeeded) return;
    _authFieldsSeeded = true;
    final name = auth.effectiveDisplayName?.trim() ?? '';
    final email = auth.effectiveEmail?.trim() ?? '';
    if (_nameController.text.trim().isEmpty && name.isNotEmpty) {
      _nameController.text = name;
    }
    if (_emailController.text.trim().isEmpty && email.isNotEmpty) {
      _emailController.text = email;
    }
  }

  Widget _buildContactStep(
    BuildContext context,
    FirebaseAuthProvider auth,
    String Function(String) t,
  ) {
    return StepFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIntro(
            icon: Icons.person_outline_rounded,
            title: _copy('contact_title'),
            subtitle: _copy('contact_subtitle'),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: t('auth_full_name')),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (auth.isSignedIn)
            _NoticeBox(
              icon: Icons.verified_user_outlined,
              text: '${_copy('signed_in_account')}${_emailController.text.trim().isEmpty ? '' : ' · ${_emailController.text.trim()}'}',
              color: AppColors.success,
            )
          else ...[
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: t('auth_email')),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: t('driver_onboarding_password_label'),
              ),
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _phoneController,
            decoration: InputDecoration(labelText: t('auth_phone')),
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 22),
          AddressAutocompleteField(
            controller: _addressController,
            label: _copy('service_address'),
            onResolved: (resolved) {
              setState(() {
                _resolvedBaseAddress = resolved;
                _cityController.text = resolved.city;
                _provinceController.text = resolved.region;
                _postalCodeController.text = resolved.postalCode;
              });
            },
            onInvalidated: () {
              setState(() => _resolvedBaseAddress = null);
            },
          ),
          const SizedBox(height: 10),
          _NoticeBox(
            icon: Icons.lock_outline,
            text: _copy('address_private'),
            color: AppColors.info,
          ),
          if (_resolvedBaseAddress != null) ...[
            const SizedBox(height: 16),
            _ResolvedAddressSummary(
              title: _copy('address_resolved'),
              cityLabel: t('admin_driver_field_city'),
              provinceLabel: t('admin_driver_field_province'),
              postalLabel: t('admin_driver_field_postal_code'),
              city: _cityController.text,
              province: _provinceController.text,
              postalCode: _postalCodeController.text,
            ),
          ],
          const SizedBox(height: 22),
          Text(
            t('driver_onboarding_languages_spoken'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allLanguages
                .map(
                  (language) => FilterChip(
                    label: Text(language.$2),
                    selected: _languages.contains(language.$1),
                    onSelected: (_) {
                      setState(() {
                        if (_languages.contains(language.$1)) {
                          if (_languages.length > 1) {
                            _languages.remove(language.$1);
                          }
                        } else {
                          _languages.add(language.$1);
                        }
                      });
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          _RequiredHint(text: _copy('field_required')),
        ],
      ),
    );
  }

  Widget _buildVehicleStep(BuildContext context, String Function(String) t) {
    return StepFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIntro(
            icon: Icons.local_shipping_outlined,
            title: _copy('vehicle_title'),
            subtitle: _copy('vehicle_subtitle'),
          ),
          const SizedBox(height: 24),
          Text(
            t('driver_onboarding_vehicle_type'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: VehicleCategory.values
                .where((category) => category != VehicleCategory.other)
                .map(
                  (category) => ChoiceChip(
                    label: Text(t(category.key)),
                    selected: _vehicleCategory == category,
                    onSelected: (_) =>
                        setState(() => _vehicleCategory = category),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _vehicleMakeController,
            decoration: InputDecoration(
              labelText: t('driver_onboarding_make_model'),
            ),
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 620;
              final year = TextField(
                controller: _vehicleYearController,
                decoration: InputDecoration(
                  labelText: t('driver_onboarding_year'),
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              );
              final color = TextField(
                controller: _vehicleColorController,
                decoration: InputDecoration(labelText: _copy('vehicle_color')),
                textCapitalization: TextCapitalization.words,
              );
              if (narrow) {
                return Column(
                  children: [year, const SizedBox(height: 16), color],
                );
              }
              return Row(
                children: [
                  Expanded(child: year),
                  const SizedBox(width: 16),
                  Expanded(child: color),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _plateController,
            decoration: InputDecoration(labelText: t('driver_onboarding_plate')),
            textCapitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _payloadController,
            decoration: InputDecoration(
              labelText: t('driver_onboarding_max_payload'),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 20),
          _DocumentPickerRow(
            label: t('driver_onboarding_vehicle_photos'),
            icon: Icons.camera_alt_outlined,
            fileName: _vehiclePhotoFileName,
            busy: _pickingDocument,
            required: true,
            onPick: () => _pickDocument(
              onPicked: (bytes, name) => setState(() {
                _vehiclePhotoBytes = bytes;
                _vehiclePhotoFileName = name;
              }),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _copy('vehicle_photo_help'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 14),
          _RequiredHint(text: _copy('field_required')),
        ],
      ),
    );
  }

  Widget _buildServicesStep(BuildContext context, String Function(String) t) {
    return StepFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIntro(
            icon: Icons.route_outlined,
            title: _copy('service_title'),
            subtitle: _copy('service_subtitle'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  t('driver_onboarding_service_radius_label'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_radius.round()} km',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _radius,
            min: 5,
            max: 100,
            divisions: 19,
            activeColor: AppColors.primary,
            label: '${_radius.round()} km',
            onChanged: (value) => setState(() => _radius = value),
          ),
          const SizedBox(height: 16),
          Text(
            t('driver_onboarding_accepted_item_types'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _allCategoryKeys
                .map(
                  (key) => FilterChip(
                    label: Text(t(key)),
                    selected: _categoryKeys.contains(key),
                    onSelected: (_) {
                      setState(() {
                        if (_categoryKeys.contains(key)) {
                          _categoryKeys.remove(key);
                        } else {
                          _categoryKeys.add(key);
                        }
                      });
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _loadingAssistance,
            activeThumbColor: AppColors.primary,
            onChanged: (value) =>
                setState(() => _loadingAssistance = value),
            title: Text(
              t('driver_onboarding_loading_assistance'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            secondary: const Icon(Icons.fitness_center_outlined),
          ),
          const SizedBox(height: 18),
          _InfoPanel(
            icon: Icons.payments_outlined,
            title: _copy('compensation_title'),
            body: _copy('compensation_body'),
          ),
          const SizedBox(height: 14),
          _RequiredHint(text: _copy('field_required')),
        ],
      ),
    );
  }

  Widget _buildDocumentsStep(
    BuildContext context,
    String Function(String) t,
  ) {
    return StepFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepIntro(
            icon: Icons.fact_check_outlined,
            title: _copy('documents_title'),
            subtitle: _copy('documents_subtitle'),
          ),
          const SizedBox(height: 24),
          _DocumentPickerRow(
            label: t('driver_onboarding_upload_license'),
            icon: Icons.badge_outlined,
            fileName: _licenseFileName,
            busy: _pickingDocument,
            required: true,
            onPick: () => _pickDocument(
              onPicked: (bytes, name) => setState(() {
                _licenseBytes = bytes;
                _licenseFileName = name;
              }),
            ),
          ),
          const SizedBox(height: 12),
          _DocumentPickerRow(
            label: _copy('vehicle_registration'),
            icon: Icons.directions_car_filled_outlined,
            fileName: _registrationFileName,
            busy: _pickingDocument,
            required: true,
            onPick: () => _pickDocument(
              onPicked: (bytes, name) => setState(() {
                _registrationBytes = bytes;
                _registrationFileName = name;
              }),
            ),
          ),
          const SizedBox(height: 12),
          _DocumentPickerRow(
            label: t('driver_onboarding_upload_insurance'),
            icon: Icons.description_outlined,
            fileName: _insuranceFileName,
            busy: _pickingDocument,
            required: true,
            onPick: () => _pickDocument(
              onPicked: (bytes, name) => setState(() {
                _insuranceBytes = bytes;
                _insuranceFileName = name;
              }),
            ),
          ),
          const SizedBox(height: 12),
          _DocumentPickerRow(
            label: _copy('identity_document'),
            icon: Icons.account_box_outlined,
            fileName: _identityFileName,
            busy: _pickingDocument,
            required: true,
            onPick: () => _pickDocument(
              onPicked: (bytes, name) => setState(() {
                _identityBytes = bytes;
                _identityFileName = name;
              }),
            ),
          ),
          const SizedBox(height: 22),
          _InfoPanel(
            icon: Icons.checklist_rounded,
            title: _copy('review_title'),
            body: _copy('review_body'),
          ),
          const SizedBox(height: 18),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _consentVerification,
            activeColor: AppColors.primary,
            onChanged: (value) =>
                setState(() => _consentVerification = value ?? false),
            title: Text(
              t('driver_onboarding_consent_verification'),
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _agreedTerms,
            activeColor: AppColors.primary,
            onChanged: (value) =>
                setState(() => _agreedTerms = value ?? false),
            title: Text(
              t('driver_onboarding_consent_terms'),
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
          const SizedBox(height: 10),
          _RequiredHint(text: _copy('field_required')),
        ],
      ),
    );
  }

  bool _canProceed(int step, FirebaseAuthProvider auth) {
    switch (step) {
      case 0:
        final accountValid = auth.isSignedIn ||
            (_emailLooksValid(_emailController.text) &&
                _passwordController.text.trim().length >= 6);
        return _nameController.text.trim().isNotEmpty &&
            accountValid &&
            _phoneController.text.trim().isNotEmpty &&
            _resolvedBaseAddress != null &&
            _cityController.text.trim().isNotEmpty &&
            _provinceController.text.trim().isNotEmpty &&
            _postalCodeController.text.trim().isNotEmpty &&
            _languages.isNotEmpty;
      case 1:
        final year = int.tryParse(_vehicleYearController.text.trim());
        final currentYear = DateTime.now().year + 1;
        return _vehicleCategory != null &&
            _vehicleMakeController.text.trim().isNotEmpty &&
            year != null &&
            year >= 1980 &&
            year <= currentYear &&
            _plateController.text.trim().isNotEmpty &&
            _vehiclePhotoBytes != null;
      case 2:
        return _categoryKeys.isNotEmpty;
      case 3:
        return _licenseBytes != null &&
            _registrationBytes != null &&
            _insuranceBytes != null &&
            _identityBytes != null &&
            _consentVerification &&
            _agreedTerms;
      default:
        return false;
    }
  }

  bool _emailLooksValid(String value) {
    final email = value.trim();
    final at = email.indexOf('@');
    final dot = email.lastIndexOf('.');
    return at > 0 && dot > at + 1 && dot < email.length - 1;
  }

  Future<void> _handleSubmit(
    FirebaseAuthProvider auth,
    BackendStatus backendStatus,
  ) async {
    final t = context.read<LocaleProvider>().t;
    if (!backendStatus.isConfigured) {
      setState(
        () => _submitError =
            t('driver_onboarding_error_backend_not_configured'),
      );
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      if (!auth.isSignedIn) {
        final ok = await auth.signUpWithEmailPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          fullName: _nameController.text.trim(),
        );
        if (!ok) {
          throw Exception(
            auth.lastError ??
                t('driver_onboarding_error_account_creation_failed'),
          );
        }
      }

      final uid = auth.effectiveUid;
      if (uid == null) {
        throw Exception(t('driver_onboarding_error_invalid_session'));
      }

      final address = _resolvedBaseAddress;
      if (address == null || _vehicleCategory == null) {
        throw StateError('Driver onboarding became incomplete before submit.');
      }

      final profile = DriverProfileV2(
        uid: uid,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        city: _cityController.text.trim(),
        baseAddressFormatted: address.formattedAddress,
        baseAddressLine1: address.line1,
        baseRegion: _provinceController.text.trim(),
        basePostalCode: _postalCodeController.text.trim(),
        baseCountry: address.country,
        basePlaceId: address.placeId,
        baseLat: address.lat,
        baseLng: address.lng,
        spokenLanguages: _languages.toList()..sort(),
        loadingAssistanceAvailable: _loadingAssistance,
        status: DriverStatus.registrationIncomplete,
        serviceRadiusKm: _radius,
        acceptedVehicleCategories: [_vehicleCategory!],
        acceptedItemCategoryKeys: _categoryKeys.toList()..sort(),
        createdAt: DateTime.now(),
      );
      await BackendLocator.driverRepository.submitDriverOnboarding(profile);

      final vehicle = DriverVehicle(
        id: const Uuid().v4(),
        driverId: uid,
        category: _vehicleCategory!,
        makeModel: _vehicleMakeController.text.trim(),
        year: int.parse(_vehicleYearController.text.trim()),
        color: _vehicleColorController.text.trim().isEmpty
            ? null
            : _vehicleColorController.text.trim(),
        plate: _plateController.text.trim().toUpperCase(),
        maxPayloadKg: double.tryParse(
          _payloadController.text.trim().replaceAll(',', '.'),
        ),
        isVerified: false,
        createdAt: DateTime.now(),
      );
      await BackendLocator.driverRepository.submitDriverVehicle(vehicle);

      await auth.refreshClaims();
      await _uploadSelectedDocuments(uid);
      await BackendLocator.driverRepository.submitForReview();

      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = _describeSubmitError(error, t);
      });
    }
  }

  String _describeSubmitError(Object error, String Function(String) t) {
    if (isKillSwitchException(error)) {
      debugPrint('DriverOnboardingScreen kill-switch refusal: $error');
      return t('service_temporarily_unavailable');
    }
    if (error is CloudFunctionException ||
        error is BackendNotConfiguredException) {
      debugPrint('DriverOnboardingScreen error (hidden from user): $error');
      return t('driver_onboarding_error_generic_prefix');
    }
    debugPrint('DriverOnboardingScreen unexpected error (hidden): $error');
    return t('driver_onboarding_error_generic_prefix');
  }

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
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(t('driver_onboarding_document_source_gallery')),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null || !mounted) return;

      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1800,
        imageQuality: 88,
      );
      if (picked == null || !mounted) return;

      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      onPicked(bytes, picked.name);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _submitError =
            t('driver_onboarding_error_document_pick_failed'),
      );
    } finally {
      if (mounted) setState(() => _pickingDocument = false);
    }
  }

  Future<void> _uploadSelectedDocuments(String uid) async {
    final uploadRepo = BackendLocator.driverDocumentUploadRepository;
    final driverRepo = BackendLocator.driverRepository;

    Future<void> uploadOne({
      required Uint8List bytes,
      required String originalFileName,
      required DriverDocumentType type,
    }) async {
      final rawExtension = originalFileName.contains('.')
          ? originalFileName.split('.').last.toLowerCase()
          : 'jpg';
      final extension = rawExtension.isEmpty ? 'jpg' : rawExtension;
      final contentType = _contentTypeForExtension(extension);
      final fileName =
          '${type.firestoreValue}_${DateTime.now().microsecondsSinceEpoch}.$extension';

      await uploadRepo.uploadDriverDocument(
        driverId: uid,
        fileName: fileName,
        bytes: bytes,
        contentType: contentType,
      );

      await driverRepo.submitDriverDocument(
        DriverDocument(
          id: const Uuid().v4(),
          driverId: uid,
          type: type,
          status: DriverDocumentStatus.uploaded,
          storageBucketPath: 'driver_documents/$uid/$fileName',
          uploadedAt: DateTime.now(),
        ),
      );
    }

    await uploadOne(
      bytes: _licenseBytes!,
      originalFileName: _licenseFileName ?? 'drivers_licence.jpg',
      type: DriverDocumentType.driversLicence,
    );
    await uploadOne(
      bytes: _registrationBytes!,
      originalFileName: _registrationFileName ?? 'vehicle_registration.jpg',
      type: DriverDocumentType.vehicleRegistration,
    );
    await uploadOne(
      bytes: _insuranceBytes!,
      originalFileName: _insuranceFileName ?? 'insurance.jpg',
      type: DriverDocumentType.insurance,
    );
    await uploadOne(
      bytes: _identityBytes!,
      originalFileName: _identityFileName ?? 'identity.jpg',
      type: DriverDocumentType.identity,
    );
    if (_vehiclePhotoBytes != null) {
      await uploadOne(
        bytes: _vehiclePhotoBytes!,
        originalFileName: _vehiclePhotoFileName ?? 'vehicle_photo.jpg',
        type: DriverDocumentType.vehiclePhoto,
      );
    }
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
      case 'heif':
        return 'image/heic';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'image/jpeg';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _postalCodeController.dispose();
    _vehicleMakeController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    _plateController.dispose();
    _payloadController.dispose();
    super.dispose();
  }
}

class _StepIntro extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _StepIntro({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoticeBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _NoticeBox({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.8, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoPanel({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.info, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequiredHint extends StatelessWidget {
  final String text;
  const _RequiredHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.info_outline, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ResolvedAddressSummary extends StatelessWidget {
  final String title;
  final String cityLabel;
  final String provinceLabel;
  final String postalLabel;
  final String city;
  final String province;
  final String postalCode;

  const _ResolvedAddressSummary({
    required this.title,
    required this.cityLabel,
    required this.provinceLabel,
    required this.postalLabel,
    required this.city,
    required this.province,
    required this.postalCode,
  });

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 15, color: AppColors.success),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                value.isEmpty ? '—' : value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.success.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final items = [
                item(Icons.location_city_outlined, cityLabel, city),
                item(Icons.map_outlined, provinceLabel, province),
                item(Icons.markunread_mailbox_outlined, postalLabel, postalCode),
              ];
              if (constraints.maxWidth < 560) {
                return Column(
                  children: [
                    for (var i = 0; i < items.length; i++) ...[
                      SizedBox(width: double.infinity, child: items[i]),
                      if (i < items.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  items[0],
                  const SizedBox(width: 8),
                  items[1],
                  const SizedBox(width: 8),
                  items[2],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DocumentPickerRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final String? fileName;
  final bool busy;
  final bool required;
  final VoidCallback onPick;

  const _DocumentPickerRow({
    required this.label,
    required this.icon,
    required this.fileName,
    required this.busy,
    required this.onPick,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final locale = context.watch<LocaleProvider>().locale;
    final hasFile = fileName != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: hasFile ? AppColors.success : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(14),
        color: hasFile ? AppColors.success.withValues(alpha: 0.05) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: (hasFile ? AppColors.success : AppColors.primary)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasFile ? Icons.check_circle : icon,
              color: hasFile ? AppColors.success : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 7,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                    if (required)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          DriverOnboardingCopy.text(locale, 'required_badge'),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  hasFile
                      ? fileName!
                      : t('driver_onboarding_document_none_selected'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: hasFile
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: busy ? null : onPick,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: const Size(0, 40),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(fontSize: 11.5),
            ),
            child: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    hasFile
                        ? t('driver_onboarding_document_edit')
                        : t('driver_onboarding_document_select'),
                  ),
          ),
        ],
      ),
    );
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
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: AppColors.warning,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                t('driver_pending_verification'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                t('driver_onboarding_pending_message'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () =>
                    context.go('/$locale/devenir-chauffeur/statut'),
                child: Text(t('driver_status_go_to_dashboard')),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/$locale'),
                child: Text(t('nav_home')),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
