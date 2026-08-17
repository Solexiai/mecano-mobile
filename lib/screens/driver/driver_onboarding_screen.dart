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
//   5. Appeler submitForReview() (Cloud Function submitDriverForReview) pour
//      transitionner le profil vers pending_review.
//   6. Afficher _PendingVerificationView.
//
// Si le backend n'est pas configuré (BackendStatus.notConfigured), l'écran
// affiche un message explicite au lieu de simuler un succès.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../backend/backend_locator.dart';
import '../../backend/backend_status.dart';
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
        child: _PendingVerificationView(locale: widget.locale, roleLabel: 'chauffeur'),
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
              const SectionTitle(title: 'Inscription chauffeur', subtitle: 'Complétez votre profil pour commencer à recevoir des demandes.'),
              const SizedBox(height: 12),
              if (!backendStatus.isConfigured)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Row(children: [
                    Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                    SizedBox(width: 10),
                    Expanded(child: Text('Backend Firebase non configuré sur cet environnement : l\'inscription réelle est indisponible.', style: TextStyle(fontSize: 12.5))),
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
                  stepTitles: const ['Profil', 'Véhicule', 'Tarification', 'Documents'],
                  nextLabel: t('common_next'),
                  backLabel: t('common_back'),
                  submitLabel: _submitting ? 'Envoi en cours...' : 'Soumettre mon inscription',
                  onStepChanged: (_) {},
                  onComplete: _submitting ? () {} : () => _handleSubmit(auth, backendStatus),
                  stepBuilders: [
                    (context) => StepFormCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            TextField(controller: _nameController, decoration: InputDecoration(labelText: t('auth_full_name'))),
                            const SizedBox(height: 16),
                            TextField(controller: _emailController, decoration: InputDecoration(labelText: t('auth_email')), keyboardType: TextInputType.emailAddress),
                            const SizedBox(height: 16),
                            TextField(controller: _passwordController, decoration: const InputDecoration(labelText: 'Mot de passe (min. 6 caractères)'), obscureText: true),
                            const SizedBox(height: 16),
                            TextField(controller: _phoneController, decoration: InputDecoration(labelText: t('auth_phone'))),
                            const SizedBox(height: 16),
                            TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'Ville / base de service')),
                            const SizedBox(height: 20),
                            Text('Rayon de service maximal: ${_radius.round()} km', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Slider(value: _radius, min: 5, max: 100, divisions: 19, activeColor: AppColors.primary, onChanged: (v) => setState(() => _radius = v)),
                            const SizedBox(height: 12),
                            const Text('Langues parlées', style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, children: _allLanguages.map((l) => FilterChip(label: Text(l), selected: _languages.contains(l), onSelected: (_) => setState(() => _languages.contains(l) ? _languages.remove(l) : _languages.add(l)))).toList()),
                          ]),
                        ),
                    (context) => StepFormCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Type de véhicule', style: TextStyle(fontWeight: FontWeight.w700)),
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
                            TextField(controller: _vehicleMakeController, decoration: const InputDecoration(labelText: 'Marque et modèle')),
                            const SizedBox(height: 16),
                            TextField(controller: _vehicleYearController, decoration: const InputDecoration(labelText: 'Année'), keyboardType: TextInputType.number),
                            const SizedBox(height: 16),
                            TextField(controller: _plateController, decoration: const InputDecoration(labelText: 'Plaque d\'immatriculation')),
                            const SizedBox(height: 16),
                            TextField(controller: _payloadController, decoration: const InputDecoration(labelText: 'Charge utile maximale (kg)'), keyboardType: TextInputType.number),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.camera_alt_outlined), label: const Text('Photos du véhicule')),
                            const SizedBox(height: 20),
                            const Text("Types d'objets acceptés", style: TextStyle(fontWeight: FontWeight.w700)),
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
                            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text("Aide au chargement disponible", style: TextStyle(fontSize: 14)), value: _loadingAssistance, onChanged: (v) => setState(() => _loadingAssistance = v), activeThumbColor: AppColors.primary),
                          ]),
                        ),
                    (context) => StepFormCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            TextField(controller: _hourlyController, decoration: const InputDecoration(labelText: 'Tarif horaire (\$)'), keyboardType: TextInputType.number),
                            const SizedBox(height: 16),
                            TextField(controller: _perKmController, decoration: const InputDecoration(labelText: 'Tarif par kilomètre (\$)'), keyboardType: TextInputType.number),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                              child: const Row(children: [
                                Icon(Icons.info_outline, color: AppColors.info, size: 18),
                                SizedBox(width: 10),
                                Expanded(child: Text('Vous pourrez ajuster vos frais forfaitaires par catégorie, vos frais d\'attente et vos frais d\'arrêt additionnel depuis votre tableau de bord.', style: TextStyle(fontSize: 12.5))),
                              ]),
                            ),
                          ]),
                        ),
                    (context) => StepFormCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.badge_outlined), label: const Text('Téléverser le permis de conduire')),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.description_outlined), label: const Text("Téléverser l'attestation d'assurance")),
                            const SizedBox(height: 20),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _consentVerification,
                              onChanged: (v) => setState(() => _consentVerification = v ?? false),
                              title: const Text('Je consens à la vérification de mon identité et de mes documents.', style: TextStyle(fontSize: 13.5)),
                              activeColor: AppColors.primary,
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _agreedTerms,
                              onChanged: (v) => setState(() => _agreedTerms = v ?? false),
                              title: const Text("J'accepte les conditions de la plateforme et l'entente fournisseur.", style: TextStyle(fontSize: 13.5)),
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
                    if (step == 3) return _consentVerification && _agreedTerms;
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
    if (!backendStatus.isConfigured) {
      setState(() => _submitError = 'Backend Firebase non configuré sur cet environnement.');
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
          throw Exception(auth.lastError ?? 'La création du compte a échoué.');
        }
      }

      final uid = auth.user?.uid;
      if (uid == null) {
        throw Exception('Session invalide après inscription.');
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
        _submitError = 'L\'inscription a échoué : $e';
      });
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
  final String roleLabel;
  const _PendingVerificationView({required this.locale, required this.roleLabel});

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
              "Merci pour votre inscription comme $roleLabel! Notre équipe examine votre profil et vos documents. Vous recevrez une confirmation par courriel une fois votre compte approuvé.",
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 28),
            ElevatedButton(onPressed: () => context.go('/$locale/fournisseur/tableau-de-bord'), child: const Text('Voir mon tableau de bord')),
            const SizedBox(height: 12),
            TextButton(onPressed: () => context.go('/$locale'), child: Text(t('nav_home'))),
            const SizedBox(height: 40),
          ]),
        ),
      ),
    );
  }
}
