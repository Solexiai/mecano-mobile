import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/enums.dart';
import '../../providers/auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/demo_data_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/coming_soon_badge.dart';
import '../../widgets/section_title.dart';
import '../../widgets/step_progress_form.dart';

// ---------------------------------------------------------------------------
// GAP-U-MECHANIC (Phase 7, Bloc U, complément U-0) — DÉCISION PRODUIT reçue :
// ne PAS construire de backend Firebase mécanicien dans cette session (aucun
// `MechanicRepository` Firebase, aucune règle Storage/Firestore dédiée
// n'existent — ce module reste entièrement backé par l'ancien `AuthProvider`/
// Hive, `signInOrRegister`, cf. investigation BUG-U-01).
//
// AVANT ce correctif : 4 boutons `OutlinedButton.icon(onPressed: () {})`
// ("Certifications", "Pièce d'identité", "Assurance responsabilité civile",
// "Numéro d'entreprise") étaient présentés comme des actions fonctionnelles
// alors qu'ils ne faisaient rien — trompeur pour l'usager (il pouvait croire
// avoir "cliqué pour rien" ou que l'app était cassée), sans pour autant
// bloquer l'inscription (canProceed ne les exige déjà pas).
//
// CORRECTIF (remédiation produit demandée, PAS un nouveau backend) : ces 4
// actions sont désormais rendues avec `onPressed: null` (désactivées
// explicitement, jamais un bouton actif qui ne fait rien) + `ComingSoonBadge`
// existant déjà réutilisé tel quel (aucun nouveau composant créé) pour
// signaler clairement "Bientôt disponible" (FR/EN/ES via
// `common_coming_soon`, déjà traduit dans les 3 langues). Aucun faux succès,
// aucun faux upload : rien n'est simulé, l'état "indisponible" est honnête.
// Documenté comme GAP-U-MECHANIC (pas un "bug" au sens P0/P1 classique — le
// comportement dysfonctionnel initial n'empêchait aucune soumission
// possible, contrairement à BUG-U-01 — mais un défaut UX trompeur corrigé
// par mesure de cohérence produit).
// ---------------------------------------------------------------------------

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
                Text(
                  t('mechanic_onboarding_pending_message'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
                ),
                const SizedBox(height: 28),
                ElevatedButton(onPressed: () => context.go('/${widget.locale}/fournisseur/tableau-de-bord'), child: Text(t('mechanic_onboarding_go_to_dashboard'))),
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
              SectionTitle(title: t('mechanic_onboarding_title'), subtitle: t('mechanic_onboarding_subtitle')),
              const SizedBox(height: 28),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: StepProgressForm(
                  stepTitles: [
                    t('mechanic_onboarding_step_profile'),
                    t('mechanic_onboarding_step_specialties'),
                    t('mechanic_onboarding_step_pricing'),
                    t('mechanic_onboarding_step_documents'),
                  ],
                  nextLabel: t('common_next'),
                  backLabel: t('common_back'),
                  submitLabel: t('mechanic_onboarding_submit'),
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
                            // BUG-003 (récurrence, même cause racine que
                            // `DeliveryRequestFlowScreen`/`DriverOnboardingScreen`) :
                            // `canProceed(0)` lit `_nameController.text` /
                            // `_emailController.text` directement, mais ces
                            // `TextField` n'avaient aucun `onChanged` déclenchant
                            // un rebuild parent -> le bouton "Suivant" restait
                            // figé désactivé selon l'ordre de saisie. Correctif
                            // identique aux occurrences déjà documentées.
                            TextField(controller: _nameController, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: t('auth_full_name'))),
                            const SizedBox(height: 16),
                            TextField(controller: _businessController, decoration: InputDecoration(labelText: "${t('mechanic_onboarding_business_name')} (${t('common_optional')})")),
                            const SizedBox(height: 16),
                            TextField(controller: _emailController, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: t('auth_email'))),
                            const SizedBox(height: 16),
                            TextField(controller: _phoneController, decoration: InputDecoration(labelText: t('auth_phone'))),
                            const SizedBox(height: 20),
                            Text('${t('driver_onboarding_service_radius_label')}: ${_radius.round()} km', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Slider(value: _radius, min: 5, max: 100, divisions: 19, activeColor: AppColors.success, onChanged: (v) => setState(() => _radius = v)),
                            const SizedBox(height: 12),
                            Text(t('driver_onboarding_languages_spoken'), style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, children: _allLanguages.map((l) => FilterChip(label: Text(l), selected: _languages.contains(l), onSelected: (_) => setState(() => _languages.contains(l) ? _languages.remove(l) : _languages.add(l)))).toList()),
                          ]),
                        ),
                    (context) => StepFormCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(t('mechanic_onboarding_specialties_title'), style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, runSpacing: 8, children: DemoDataService.mechanicServices.map((s) => FilterChip(label: Text(t(s)), selected: _specialties.contains(s), onSelected: (_) => setState(() => _specialties.contains(s) ? _specialties.remove(s) : _specialties.add(s)))).toList()),
                            const SizedBox(height: 16),
                            TextField(controller: _experienceController, decoration: InputDecoration(labelText: t('mechanic_onboarding_years_experience')), keyboardType: TextInputType.number),
                            const SizedBox(height: 16),
                            _ComingSoonActionRow(icon: Icons.workspace_premium_outlined, label: t('mechanic_onboarding_certifications')),
                            const SizedBox(height: 20),
                            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(t('mechanic_onboarding_emergency_availability'), style: const TextStyle(fontSize: 14)), value: _emergencyAvailable, onChanged: (v) => setState(() => _emergencyAvailable = v), activeThumbColor: AppColors.success),
                            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(t('mechanic_onboarding_evening_availability'), style: const TextStyle(fontSize: 14)), value: _eveningAvailable, onChanged: (v) => setState(() => _eveningAvailable = v), activeThumbColor: AppColors.success),
                            SwitchListTile(contentPadding: EdgeInsets.zero, title: Text(t('mechanic_onboarding_weekend_availability'), style: const TextStyle(fontSize: 14)), value: _weekendAvailable, onChanged: (v) => setState(() => _weekendAvailable = v), activeThumbColor: AppColors.success),
                          ]),
                        ),
                    (context) => StepFormCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            TextField(controller: _hourlyController, decoration: InputDecoration(labelText: t('mechanic_onboarding_hourly_labor_rate')), keyboardType: TextInputType.number),
                            const SizedBox(height: 16),
                            TextField(controller: _travelFeeController, decoration: InputDecoration(labelText: t('mechanic_onboarding_travel_fee')), keyboardType: TextInputType.number),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                              child: Row(children: [
                                const Icon(Icons.info_outline, color: AppColors.info, size: 18),
                                const SizedBox(width: 10),
                                Expanded(child: Text(t('mechanic_onboarding_fees_info'), style: const TextStyle(fontSize: 12.5))),
                              ]),
                            ),
                          ]),
                        ),
                    (context) => StepFormCard(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _ComingSoonActionRow(icon: Icons.badge_outlined, label: t('mechanic_onboarding_upload_id')),
                            const SizedBox(height: 12),
                            _ComingSoonActionRow(icon: Icons.description_outlined, label: t('mechanic_onboarding_upload_liability_insurance')),
                            const SizedBox(height: 12),
                            _ComingSoonActionRow(icon: Icons.business_outlined, label: t('mechanic_onboarding_business_number')),
                            const SizedBox(height: 20),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _consentVerification,
                              onChanged: (v) => setState(() => _consentVerification = v ?? false),
                              title: Text(t('driver_onboarding_consent_verification'), style: const TextStyle(fontSize: 13.5)),
                              activeColor: AppColors.success,
                            ),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              value: _agreedTerms,
                              onChanged: (v) => setState(() => _agreedTerms = v ?? false),
                              title: Text(t('driver_onboarding_consent_terms'), style: const TextStyle(fontSize: 13.5)),
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

/// GAP-U-MECHANIC — remplace les anciens `OutlinedButton.icon(onPressed: () {})`.
/// Action explicitement DÉSACTIVÉE (`onPressed: null`, jamais un bouton actif
/// qui ne fait rien) + `ComingSoonBadge` existant (aucun nouveau composant),
/// pour que l'usager comprenne immédiatement que la fonctionnalité n'est pas
/// encore disponible plutôt que de croire à un bug de l'app.
class _ComingSoonActionRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ComingSoonActionRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          const ComingSoonBadge(small: true),
        ],
      ),
    );
  }
}
