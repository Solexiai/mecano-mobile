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

/// Driver registration in four coherent sections:
/// 1) contact + verified service-base address,
/// 2) vehicle identity + verification photos,
/// 3) service area + accepted deliveries,
/// 4) verification documents + consents.
class DriverOnboardingScreen extends StatefulWidget {
  final String locale;
  final int initialStep;

  const DriverOnboardingScreen({
    super.key,
    required this.locale,
    this.initialStep = 0,
  });

  @override
  State<DriverOnboardingScreen> createState() => _DriverOnboardingScreenState();
}

class _DriverOnboardingScreenState extends State<DriverOnboardingScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _postalController = TextEditingController();

  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();
  final _payloadController = TextEditingController();

  ResolvedAddress? _resolvedAddress;
  VehicleCategory? _vehicleCategory;
  double _radiusKm = 25;
  final Set<String> _languages = {'fr'};
  final Set<String> _acceptedItemKeys = {};
  bool _loadingAssistance = false;

  Uint8List? _vehiclePhotoBytes;
  String? _vehiclePhotoName;
  Uint8List? _vehicleRearPhotoBytes;
  String? _vehicleRearPhotoName;
  Uint8List? _vehiclePlatePhotoBytes;
  String? _vehiclePlatePhotoName;

  Uint8List? _licenceBytes;
  String? _licenceName;
  Uint8List? _registrationBytes;
  String? _registrationName;
  Uint8List? _insuranceBytes;
  String? _insuranceName;
  Uint8List? _identityBytes;
  String? _identityName;

  bool _consentVerification = false;
  bool _agreedTerms = false;
  bool _pickingDocument = false;
  bool _submitting = false;
  bool _submitted = false;
  bool _authSeeded = false;
  String? _submitError;

  static const _languageChoices = <(String, String)>[
    ('fr', 'Français'),
    ('en', 'English'),
    ('es', 'Español'),
  ];

  static const _itemKeys = <String>[
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

  String _copy(String key) => DriverOnboardingCopy.text(widget.locale, key);

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final auth = context.watch<FirebaseAuthProvider>();
    final backendStatus = context.watch<BackendStatus>();
    _seedAuthFields(auth);

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
              const SizedBox(height: 18),
              if (!backendStatus.isConfigured) ...[
                _NoticeBox(
                  icon: Icons.warning_amber_rounded,
                  text: t('driver_onboarding_backend_not_configured'),
                  color: AppColors.warning,
                ),
                const SizedBox(height: 12),
              ],
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
                  initialStep: widget.initialStep,                  stepTitles: [
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
                      : () => _submit(auth, backendStatus),
                  stepBuilders: [
                    (_) => _contactStep(auth, t),
                    (_) => _vehicleStep(t),
                    (_) => _servicesStep(t),
                    (_) => _documentsStep(t),
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

  void _seedAuthFields(FirebaseAuthProvider auth) {
    if (!auth.isSignedIn || _authSeeded) return;
    _authSeeded = true;
    final name = auth.effectiveDisplayName?.trim() ?? '';
    final email = auth.effectiveEmail?.trim() ?? '';
    if (_nameController.text.trim().isEmpty && name.isNotEmpty) {
      _nameController.text = name;
    }
    if (_emailController.text.trim().isEmpty && email.isNotEmpty) {
      _emailController.text = email;
    }
  }

  Widget _contactStep(
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
          _Field(
            controller: _nameController,
            label: t('auth_full_name'),
            capitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          if (auth.isSignedIn)
            _NoticeBox(
              icon: Icons.verified_user_outlined,
              color: AppColors.success,
              text:
                  '${_copy('signed_in_account')}${_emailController.text.trim().isEmpty ? '' : ' · ${_emailController.text.trim()}'}',
            )
          else ...[
            _Field(
              controller: _emailController,
              label: t('auth_email'),
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: t('driver_onboarding_password_label'),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: 16),
          _Field(
            controller: _phoneController,
            label: t('auth_phone'),
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 22),
          AddressAutocompleteField(
            controller: _addressController,
            label: _copy('service_address'),
            onResolved: (address) {
              setState(() {
                _resolvedAddress = address;
                _cityController.text = address.city;
                _provinceController.text = address.region;
                _postalController.text = address.postalCode;
              });
            },
            onInvalidated: () => setState(() => _resolvedAddress = null),
          ),
          const SizedBox(height: 10),
          _NoticeBox(
            icon: Icons.lock_outline,
            text: _copy('address_private'),
            color: AppColors.info,
          ),
          if (_resolvedAddress != null) ...[
            const SizedBox(height: 14),
            _AddressSummary(
              title: _copy('address_resolved'),
              cityLabel: t('admin_driver_field_city'),
              provinceLabel: t('admin_driver_field_province'),
              postalLabel: t('admin_driver_field_postal_code'),
              city: _cityController.text,
              province: _provinceController.text,
              postal: _postalController.text,
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
            children: _languageChoices.map((language) {
              return FilterChip(
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
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          _RequiredHint(text: _copy('field_required')),
        ],
      ),
    );
  }

  Widget _vehicleStep(String Function(String) t) {
    return StepFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Deliberately text-only: the previous decorative truck/load icon
          // was removed so the vehicle step is visually cleaner.
          _PlainStepIntro(
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
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final make = _Field(
                controller: _makeController,
                label: _copy('vehicle_make'),
                capitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
              );
              final model = _Field(
                controller: _modelController,
                label: _copy('vehicle_model'),
                capitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
              );
              if (constraints.maxWidth < 620) {
                return Column(
                  children: [make, const SizedBox(height: 16), model],
                );
              }
              return Row(
                children: [
                  Expanded(child: make),
                  const SizedBox(width: 16),
                  Expanded(child: model),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final year = _Field(
                controller: _yearController,
                label: t('driver_onboarding_year'),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              );
              final color = _Field(
                controller: _colorController,
                label: _copy('vehicle_color'),
                capitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
              );
              if (constraints.maxWidth < 620) {
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
          _Field(
            controller: _plateController,
            label: t('driver_onboarding_plate'),
            capitalization: TextCapitalization.characters,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _Field(
            controller: _payloadController,
            label: t('driver_onboarding_max_payload'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 7),
          Text(
            _copy('payload_help'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 26),
          Text(
            _copy('vehicle_photos_title'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 5),
          Text(
            _copy('vehicle_photos_subtitle'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          _DocumentPickerRow(
            label: _copy('vehicle_main_photo'),
            icon: Icons.camera_alt_outlined,
            fileName: _vehiclePhotoName,
            busy: _pickingDocument,
            isRequired: true,
            onPick: () => _pickImage(
              onPicked: (bytes, name) => setState(() {
                _vehiclePhotoBytes = bytes;
                _vehiclePhotoName = name;
              }),
            ),
          ),
          const SizedBox(height: 6),
          _PhotoHelp(text: _copy('vehicle_main_photo_help')),
          const SizedBox(height: 12),
          _DocumentPickerRow(
            label: _copy('vehicle_rear_photo'),
            icon: Icons.photo_camera_back_outlined,
            fileName: _vehicleRearPhotoName,
            busy: _pickingDocument,
            isRequired: true,
            onPick: () => _pickImage(
              onPicked: (bytes, name) => setState(() {
                _vehicleRearPhotoBytes = bytes;
                _vehicleRearPhotoName = name;
              }),
            ),
          ),
          const SizedBox(height: 6),
          _PhotoHelp(text: _copy('vehicle_rear_photo_help')),
          const SizedBox(height: 12),
          _DocumentPickerRow(
            label: _copy('vehicle_plate_photo'),
            icon: Icons.pin_outlined,
            fileName: _vehiclePlatePhotoName,
            busy: _pickingDocument,
            isRequired: true,
            onPick: () => _pickImage(
              onPicked: (bytes, name) => setState(() {
                _vehiclePlatePhotoBytes = bytes;
                _vehiclePlatePhotoName = name;
              }),
            ),
          ),
          const SizedBox(height: 6),
          _PhotoHelp(text: _copy('vehicle_plate_photo_help')),
          const SizedBox(height: 16),
          _NoticeBox(
            icon: Icons.verified_outlined,
            text: _copy('vehicle_verification_notice'),
            color: AppColors.info,
          ),
          const SizedBox(height: 14),
          _RequiredHint(text: _copy('field_required')),
        ],
      ),
    );
  }

  Widget _servicesStep(String Function(String) t) {
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
                  '${_radiusKm.round()} km',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _radiusKm,
            min: 5,
            max: 100,
            divisions: 19,
            label: '${_radiusKm.round()} km',
            activeColor: AppColors.primary,
            onChanged: (value) => setState(() => _radiusKm = value),
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
            children: _itemKeys.map((key) {
              return FilterChip(
                label: Text(t(key)),
                selected: _acceptedItemKeys.contains(key),
                onSelected: (_) {
                  setState(() {
                    if (_acceptedItemKeys.contains(key)) {
                      _acceptedItemKeys.remove(key);
                    } else {
                      _acceptedItemKeys.add(key);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.fitness_center_outlined),
            title: Text(
              t('driver_onboarding_loading_assistance'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            value: _loadingAssistance,
            activeThumbColor: AppColors.primary,
            onChanged: (value) =>
                setState(() => _loadingAssistance = value),
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

  Widget _documentsStep(String Function(String) t) {
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
            fileName: _licenceName,
            busy: _pickingDocument,
            isRequired: true,
            onPick: () => _pickImage(
              onPicked: (bytes, name) => setState(() {
                _licenceBytes = bytes;
                _licenceName = name;
              }),
            ),
          ),
          const SizedBox(height: 12),
          _DocumentPickerRow(
            label: _copy('vehicle_registration'),
            icon: Icons.directions_car_filled_outlined,
            fileName: _registrationName,
            busy: _pickingDocument,
            isRequired: true,
            onPick: () => _pickImage(
              onPicked: (bytes, name) => setState(() {
                _registrationBytes = bytes;
                _registrationName = name;
              }),
            ),
          ),
          const SizedBox(height: 12),
          _DocumentPickerRow(
            label: t('driver_onboarding_upload_insurance'),
            icon: Icons.description_outlined,
            fileName: _insuranceName,
            busy: _pickingDocument,
            isRequired: true,
            onPick: () => _pickImage(
              onPicked: (bytes, name) => setState(() {
                _insuranceBytes = bytes;
                _insuranceName = name;
              }),
            ),
          ),
          const SizedBox(height: 12),
          _DocumentPickerRow(
            label: _copy('identity_document'),
            icon: Icons.account_box_outlined,
            fileName: _identityName,
            busy: _pickingDocument,
            isRequired: true,
            onPick: () => _pickImage(
              onPicked: (bytes, name) => setState(() {
                _identityBytes = bytes;
                _identityName = name;
              }),
            ),
          ),
          const SizedBox(height: 22),
          _InfoPanel(
            icon: Icons.checklist_rounded,
            title: _copy('review_title'),
            body: _copy('review_body'),
          ),
          const SizedBox(height: 16),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _consentVerification,
            activeColor: AppColors.primary,
            title: Text(
              t('driver_onboarding_consent_verification'),
              style: const TextStyle(fontSize: 13.5),
            ),
            onChanged: (value) =>
                setState(() => _consentVerification = value ?? false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _agreedTerms,
            activeColor: AppColors.primary,
            title: Text(
              t('driver_onboarding_consent_terms'),
              style: const TextStyle(fontSize: 13.5),
            ),
            onChanged: (value) =>
                setState(() => _agreedTerms = value ?? false),
          ),
          const SizedBox(height: 10),
          _RequiredHint(text: _copy('field_required')),
        ],
      ),
    );
  }

  bool _canProceed(int step, FirebaseAuthProvider auth) {
    if (step == 0) {
      final accountReady = auth.isSignedIn ||
          (_isEmailValid(_emailController.text) &&
              _passwordController.text.trim().length >= 6);
      return _nameController.text.trim().isNotEmpty &&
          accountReady &&
          _phoneController.text.trim().isNotEmpty &&
          _resolvedAddress != null &&
          _cityController.text.trim().isNotEmpty &&
          _provinceController.text.trim().isNotEmpty &&
          _postalController.text.trim().isNotEmpty &&
          _languages.isNotEmpty;
    }
    if (step == 1) {
      final year = int.tryParse(_yearController.text.trim());
      final payload = double.tryParse(
        _payloadController.text.trim().replaceAll(',', '.'),
      );
      return _vehicleCategory != null &&
          _makeController.text.trim().isNotEmpty &&
          _modelController.text.trim().isNotEmpty &&
          year != null &&
          year >= 1980 &&
          year <= DateTime.now().year + 1 &&
          _colorController.text.trim().isNotEmpty &&
          _plateController.text.trim().isNotEmpty &&
          payload != null &&
          payload > 0 &&
          _vehiclePhotoBytes != null &&
          _vehicleRearPhotoBytes != null &&
          _vehiclePlatePhotoBytes != null;
    }
    if (step == 2) return _acceptedItemKeys.isNotEmpty;
    if (step == 3) {
      return _licenceBytes != null &&
          _registrationBytes != null &&
          _insuranceBytes != null &&
          _identityBytes != null &&
          _consentVerification &&
          _agreedTerms;
    }
    return false;
  }

  bool _isEmailValid(String raw) {
    final email = raw.trim();
    final at = email.indexOf('@');
    final dot = email.lastIndexOf('.');
    return at > 0 && dot > at + 1 && dot < email.length - 1;
  }

  Future<void> _submit(
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
      final address = _resolvedAddress;
      final category = _vehicleCategory;
      if (uid == null) {
        throw Exception(t('driver_onboarding_error_invalid_session'));
      }
      if (address == null || category == null) {
        throw StateError('Incomplete driver registration state.');
      }

      final languages = _languages.toList()..sort();
      final itemKeys = _acceptedItemKeys.toList()..sort();
      final profile = DriverProfileV2(
        uid: uid,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        city: _cityController.text.trim(),
        baseAddressFormatted: address.formattedAddress,
        baseAddressLine1: address.line1,
        baseRegion: _provinceController.text.trim(),
        basePostalCode: _postalController.text.trim(),
        baseCountry: address.country,
        basePlaceId: address.placeId,
        baseLat: address.lat,
        baseLng: address.lng,
        spokenLanguages: languages,
        loadingAssistanceAvailable: _loadingAssistance,
        status: DriverStatus.registrationIncomplete,
        serviceRadiusKm: _radiusKm,
        acceptedVehicleCategories: [category],
        acceptedItemCategoryKeys: itemKeys,
        createdAt: DateTime.now(),
      );
      await BackendLocator.driverRepository.submitDriverOnboarding(profile);

      final makeModel = [
        _makeController.text.trim(),
        _modelController.text.trim(),
      ].where((part) => part.isNotEmpty).join(' ');
      final vehicle = DriverVehicle(
        id: const Uuid().v4(),
        driverId: uid,
        category: category,
        makeModel: makeModel,
        year: int.parse(_yearController.text.trim()),
        plate: _plateController.text.trim().toUpperCase(),
        maxPayloadKg: double.tryParse(
          _payloadController.text.trim().replaceAll(',', '.'),
        ),
        color: _colorController.text.trim(),
        isVerified: false,
        createdAt: DateTime.now(),
      );
      await BackendLocator.driverRepository.submitDriverVehicle(vehicle);

      await auth.refreshClaims();
      await _uploadDocuments(uid);
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
      debugPrint('Driver onboarding blocked by runtime flag: $error');
      return t('service_temporarily_unavailable');
    }
    debugPrint('Driver onboarding error hidden from user: $error');
    return t('driver_onboarding_error_generic_prefix');
  }

  Future<void> _pickImage({
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

  Future<void> _uploadDocuments(String uid) async {
    final uploadRepo = BackendLocator.driverDocumentUploadRepository;
    final driverRepo = BackendLocator.driverRepository;

    Future<void> upload(
      Uint8List bytes,
      String fileName,
      DriverDocumentType type, {
      String? storagePrefix,
    }) async {
      final rawExtension = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : 'jpg';
      final extension = rawExtension.isEmpty ? 'jpg' : rawExtension;
      final prefix = storagePrefix ?? type.firestoreValue;
      final storedName =
          '${prefix}_${DateTime.now().microsecondsSinceEpoch}.$extension';
      await uploadRepo.uploadDriverDocument(
        driverId: uid,
        fileName: storedName,
        bytes: bytes,
        contentType: _contentType(extension),
      );
      await driverRepo.submitDriverDocument(
        DriverDocument(
          id: const Uuid().v4(),
          driverId: uid,
          type: type,
          status: DriverDocumentStatus.uploaded,
          storageBucketPath: 'driver_documents/$uid/$storedName',
          uploadedAt: DateTime.now(),
        ),
      );
    }

    await upload(
      _licenceBytes!,
      _licenceName ?? 'drivers_licence.jpg',
      DriverDocumentType.driversLicence,
    );
    await upload(
      _registrationBytes!,
      _registrationName ?? 'vehicle_registration.jpg',
      DriverDocumentType.vehicleRegistration,
    );
    await upload(
      _insuranceBytes!,
      _insuranceName ?? 'insurance.jpg',
      DriverDocumentType.insurance,
    );
    await upload(
      _identityBytes!,
      _identityName ?? 'identity.jpg',
      DriverDocumentType.identity,
    );
    await upload(
      _vehiclePhotoBytes!,
      _vehiclePhotoName ?? 'vehicle_main_photo.jpg',
      DriverDocumentType.vehiclePhoto,
      storagePrefix: 'vehicle_main_photo',
    );
    await upload(
      _vehicleRearPhotoBytes!,
      _vehicleRearPhotoName ?? 'vehicle_rear_photo.jpg',
      DriverDocumentType.vehiclePhoto,
      storagePrefix: 'vehicle_rear_photo',
    );
    await upload(
      _vehiclePlatePhotoBytes!,
      _vehiclePlatePhotoName ?? 'vehicle_plate_photo.jpg',
      DriverDocumentType.vehiclePhoto,
      storagePrefix: 'vehicle_plate_photo',
    );
  }

  String _contentType(String extension) {
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
    _postalController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _payloadController.dispose();
    super.dispose();
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  final TextCapitalization capitalization;
  final ValueChanged<String>? onChanged;

  const _Field({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.capitalization = TextCapitalization.none,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      decoration: InputDecoration(labelText: label),
      onChanged: onChanged,
    );
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

class _PlainStepIntro extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PlainStepIntro({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
    );
  }
}

class _PhotoHelp extends StatelessWidget {
  final String text;
  const _PhotoHelp({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11.8,
          height: 1.35,
        ),
      ),
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

class _RequiredHint extends StatelessWidget {
  final String text;
  const _RequiredHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.info_outline,
          size: 15,
          color: AppColors.textSecondary,
        ),
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

class _AddressSummary extends StatelessWidget {
  final String title;
  final String cityLabel;
  final String provinceLabel;
  final String postalLabel;
  final String city;
  final String province;
  final String postal;

  const _AddressSummary({
    required this.title,
    required this.cityLabel,
    required this.provinceLabel,
    required this.postalLabel,
    required this.city,
    required this.province,
    required this.postal,
  });

  @override
  Widget build(BuildContext context) {
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _AddressDatum(
                icon: Icons.location_city_outlined,
                label: cityLabel,
                value: city,
              ),
              _AddressDatum(
                icon: Icons.map_outlined,
                label: provinceLabel,
                value: province,
              ),
              _AddressDatum(
                icon: Icons.markunread_mailbox_outlined,
                label: postalLabel,
                value: postal,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddressDatum extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _AddressDatum({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 235),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: AppColors.success),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
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
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
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
  final bool isRequired;
  final VoidCallback onPick;

  const _DocumentPickerRow({
    required this.label,
    required this.icon,
    required this.fileName,
    required this.busy,
    required this.onPick,
    this.isRequired = false,
  });

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final t = localeProvider.t;
    final hasFile = fileName != null;
    final accent = hasFile ? AppColors.success : AppColors.primary;

    Widget info() => Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasFile ? Icons.check_circle : icon,
                color: accent,
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
                      if (isRequired)
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
                            DriverOnboardingCopy.text(
                              localeProvider.locale,
                              'required_badge',
                            ),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
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
          ],
        );

    Widget action({bool expand = false}) {
      final button = OutlinedButton(
        onPressed: busy ? null : onPick,
        style: OutlinedButton.styleFrom(
          minimumSize: expand ? const Size.fromHeight(42) : const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      );
      return expand ? SizedBox(width: double.infinity, child: button) : button;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(
          color: hasFile ? AppColors.success : AppColors.border,
        ),
        borderRadius: BorderRadius.circular(14),
        color: hasFile ? AppColors.success.withValues(alpha: 0.05) : null,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info(),
                const SizedBox(height: 12),
                action(expand: true),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: info()),
              const SizedBox(width: 10),
              action(),
            ],
          );
        },
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
