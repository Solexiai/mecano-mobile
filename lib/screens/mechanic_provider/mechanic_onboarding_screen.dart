import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/demo_data_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';
import '../../widgets/step_progress_form.dart';

class MechanicOnboardingScreen extends StatefulWidget {
  final String locale;
  const MechanicOnboardingScreen({super.key, required this.locale});

  @override
  State<MechanicOnboardingScreen> createState() => _MechanicOnboardingScreenState();
}

class _MechanicOnboardingScreenState extends State<MechanicOnboardingScreen> {
  final _nameController = TextEditingController();
  final _businessController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _experienceController = TextEditingController();
  final _hourlyController = TextEditingController();
  final _travelFeeController = TextEditingController();

  double _radius = 25;
  final Set<String> _specialties = {};
  final Set<String> _languages = {'Français'};
  bool _emergencyAvailable = false;
  bool _eveningAvailable = false;
  bool _weekendAvailable = false;
  bool _consentVerification = false;
  bool _agreedTerms = false;
  bool _submitted = false;

  static const _allLanguages = ['Français', 'English', 'Español'];

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final auth = context.watch<AuthProvider>();

    if (_submitted) {
      return AppShell(
        locale: widget.locale,
        showFooter: false,
        child: Padding(
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
                const Text(
                  "Merci pour votre inscription comme mécanicien mobile! Notre équipe examine votre profil et vos documents. Vous recevrez une confirmation par courriel une fois votre compte approuvé.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 28),
                ElevatedButton(onPressed: () => context.go('/${widget.locale}/fournisseur/tableau-de-bord'), child: const Text('Voir mon tableau de bord')),
                const SizedBox(height: 12),
                TextButton(onPressed: () => context.go('/${widget.locale}'), child: Text(t('nav_home'))),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ),
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
              const SectionTitle(title: 'Inscription mécanicien mobile', subtitle: 'Complétez votre profil pour commencer à recevoir des demandes.'),
              const SizedBox(height: 28),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: StepProgressForm(
                  stepTitles: const ['Profil', 'Spécialités', 'Tarification', 'Documents'],
                  nextLabel: t('common_next'),
                  backLabel: t('common_back'),
                  submitLabel: 'Soumettre mon inscription',
                  onStepChanged: (_) {},
                  onComplete: () => _handleSubmit(auth),
                  canProceed: (step) {
                    if (step == 0) return _nameController.text.trim().isNotEmpty && _emailController.text.trim().isNotEmpty;
                    if (step == 1) return _specialties.isNotEmpty;
                    if (step == 3) return _consentVerification && _agreedTerms;
                    return true;
                  },
                  stepBuilders: [
                    (context) => StepFormCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            TextField(controller: _nameController, decoration: InputDecoration(labelText: t('auth_full_name'))),
                            const SizedBox(height: 16),
                            TextField(controller: _businessController, decoration: InputDecoration(labelText: "Nom d'entreprise (${t('common_optional')})")),
                            const SizedBox(height: 16),
                            TextField(controller: _emailController, decoration: InputDecoration(labelText: t('auth_email'))),
                            const SizedBox(height: 16),
                            TextField(controller: _phoneController, decoration: InputDecoration(labelText: t('auth_phone'))),
                            const SizedBox(height: 20),
                            Text('Rayon de service maximal: ${_radius.round()} km', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Slider(value: _radius, min: 5, max: 100, divisions: 19, activeColor: AppColors.success, onChanged: (v) => setState(() => _radius = v)),
                            const SizedBox(height: 12),
                            Text('Langues parlées', style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, children: _allLanguages.map((l) => FilterChip(label: Text(l), selected: _languages.contains(l), onSelected: (_) => setState(() => _languages.contains(l) ? _languages.remove(l) : _languages.add(l)))).toList()),
                          ]),
                        ),
                    (context) => StepFormCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Spécialités mécaniques', style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: DemoDataService.mechanicServices.map((s) => FilterChip(label: Text(s), selected: _specialties.contains(s), onSelected: (_) => setState(() => _specialties.contains(s) ? _specialties.remove(s) : _specialties.add(s)))).toList()),
                            const SizedBox(height: 16),
                            TextField(controller: _experienceController, decoration: const InputDecoration(labelText: "Années d'expérience"), keyboardType: TextInputType.number),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.workspace_premium_outlined), label: const Text('Certifications professionnelles (optionnel)')),
                            const SizedBox(height: 20),
                            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Disponibilité urgences', style: TextStyle(fontSize: 14)), value: _emergencyAvailable, onChanged: (v) => setState(() => _emergencyAvailable = v), activeThumbColor: AppColors.success),
                            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Disponibilité en soirée', style: TextStyle(fontSize: 14)), value: _eveningAvailable, onChanged: (v) => setState(() => _eveningAvailable = v), activeThumbColor: AppColors.success),
                            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Disponibilité fin de semaine', style: TextStyle(fontSize: 14)), value: _weekendAvailable, onChanged: (v) => setState(() => _weekendAvailable = v), activeThumbColor: AppColors.success),
                          ]),
                        ),
                    (context) => StepFormCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            TextField(controller: _hourlyController, decoration: const InputDecoration(labelText: 'Tarif horaire de main-d\'œuvre (\$)'), keyboardType: TextInputType.number),
                            const SizedBox(height: 16),
                            TextField(controller: _travelFeeController, decoration: const InputDecoration(labelText: 'Frais de déplacement (\$)'), keyboardType: TextInputType.number),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                              child: const Row(children: [
                                Icon(Icons.info_outline, color: AppColors.info, size: 18),
                                SizedBox(width: 10),
                                Expanded(child: Text('Vous pourrez configurer vos forfaits à prix fixe, frais de diagnostic et majoration sur pièces depuis votre tableau de bord.', style: TextStyle(fontSize: 12.5))),
                              ]),
                            ),
                          ]),
                        ),
                    (context) => StepFormCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.badge_outlined), label: const Text("Téléverser une pièce d'identité")),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.description_outlined), label: const Text("Téléverser l'attestation d'assurance responsabilité")),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(onPressed: () {}, icon: const Icon(Icons.business_outlined), label: const Text("Numéro d'entreprise (optionnel)")),
                            const SizedBox(height: 20),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _consentVerification,
                              onChanged: (v) => setState(() => _consentVerification = v ?? false),
                              title: const Text('Je consens à la vérification de mon identité et de mes documents.', style: TextStyle(fontSize: 13.5)),
                              activeColor: AppColors.success,
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _agreedTerms,
                              onChanged: (v) => setState(() => _agreedTerms = v ?? false),
                              title: const Text("J'accepte les conditions de la plateforme et l'entente fournisseur.", style: TextStyle(fontSize: 13.5)),
                              activeColor: AppColors.success,
                            ),
                          ]),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit(AuthProvider auth) async {
    await auth.signInOrRegister(
      email: _emailController.text.trim().isEmpty ? 'demo.mechanic@movi-k.com' : _emailController.text.trim(),
      fullName: _nameController.text.trim().isEmpty ? 'Nouveau mécanicien' : _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      role: UserRole.mechanic,
    );
    setState(() => _submitted = true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _businessController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _experienceController.dispose();
    _hourlyController.dispose();
    _travelFeeController.dispose();
    super.dispose();
  }
}
