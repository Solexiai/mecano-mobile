import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/enums.dart';
import '../../providers/auth_provider.dart';
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
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController(text: 'Montréal, QC');
  final _vehicleMakeController = TextEditingController();
  final _vehicleYearController = TextEditingController();
  final _payloadController = TextEditingController();
  final _hourlyController = TextEditingController();
  final _perKmController = TextEditingController();

  VehicleType _vehicleType = VehicleType.pickupTruck;
  double _radius = 25;
  final Set<String> _categories = {};
  final Set<String> _languages = {'Français'};
  bool _loadingAssistance = false;
  bool _consentVerification = false;
  bool _agreedTerms = false;
  bool _submitted = false;

  static const _allCategories = ['Meubles', 'Électroménagers', 'Matériaux', 'Palettes', 'Motos/VTT', 'Petits déménagements'];
  static const _allLanguages = ['Français', 'English', 'Español'];

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final auth = context.watch<AuthProvider>();

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
              const SizedBox(height: 28),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: StepProgressForm(
                  stepTitles: const ['Profil', 'Véhicule', 'Tarification', 'Documents'],
                  nextLabel: t('common_next'),
                  backLabel: t('common_back'),
                  submitLabel: 'Soumettre mon inscription',
                  onStepChanged: (_) {},
                  onComplete: () => _handleSubmit(auth),
                  stepBuilders: [
                    (context) => StepFormCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            TextField(controller: _nameController, decoration: InputDecoration(labelText: t('auth_full_name'))),
                            const SizedBox(height: 16),
                            TextField(controller: _emailController, decoration: InputDecoration(labelText: t('auth_email'))),
                            const SizedBox(height: 16),
                            TextField(controller: _phoneController, decoration: InputDecoration(labelText: t('auth_phone'))),
                            const SizedBox(height: 16),
                            TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'Ville / base de service')),
                            const SizedBox(height: 20),
                            Text('Rayon de service maximal: ${_radius.round()} km', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Slider(value: _radius, min: 5, max: 100, divisions: 19, activeColor: AppColors.primary, onChanged: (v) => setState(() => _radius = v)),
                            const SizedBox(height: 12),
                            Text('Langues parlées', style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, children: _allLanguages.map((l) => FilterChip(label: Text(l), selected: _languages.contains(l), onSelected: (_) => setState(() => _languages.contains(l) ? _languages.remove(l) : _languages.add(l)))).toList()),
                          ]),
                        ),
                    (context) => StepFormCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Type de véhicule', style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: VehicleType.values.map((v) => ChoiceChip(label: Text(_vehicleLabel(v)), selected: _vehicleType == v, onSelected: (_) => setState(() => _vehicleType = v))).toList(),
                            ),
                            const SizedBox(height: 16),
                            TextField(controller: _vehicleMakeController, decoration: const InputDecoration(labelText: 'Marque et modèle')),
                            const SizedBox(height: 16),
                            TextField(controller: _vehicleYearController, decoration: const InputDecoration(labelText: 'Année'), keyboardType: TextInputType.number),
                            const SizedBox(height: 16),
                            TextField(controller: _payloadController, decoration: const InputDecoration(labelText: 'Charge utile maximale (kg)'), keyboardType: TextInputType.number),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.camera_alt_outlined), label: const Text('Photos du véhicule')),
                            const SizedBox(height: 20),
                            Text("Types d'objets acceptés", style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: _allCategories.map((c) => FilterChip(label: Text(c), selected: _categories.contains(c), onSelected: (_) => setState(() => _categories.contains(c) ? _categories.remove(c) : _categories.add(c)))).toList()),
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
                    if (step == 0) return _nameController.text.trim().isNotEmpty && _emailController.text.trim().isNotEmpty;
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

  String _vehicleLabel(VehicleType v) {
    switch (v) {
      case VehicleType.pickupTruck:
        return 'Camionnette';
      case VehicleType.cargoVan:
        return 'Fourgon cargo';
      case VehicleType.cubeTruck:
        return 'Camion cube';
      case VehicleType.trailer:
        return 'Remorque';
      case VehicleType.suvWithTrailer:
        return 'VUS + remorque';
      case VehicleType.smallCommercial:
        return 'Véhicule commercial léger';
    }
  }

  Future<void> _handleSubmit(AuthProvider auth) async {
    await auth.signInOrRegister(
      email: _emailController.text.trim().isEmpty ? 'demo.driver@movi-k.com' : _emailController.text.trim(),
      fullName: _nameController.text.trim().isEmpty ? 'Nouveau chauffeur' : _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      role: UserRole.driver,
    );
    setState(() => _submitted = true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _vehicleMakeController.dispose();
    _vehicleYearController.dispose();
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
