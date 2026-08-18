// ---------------------------------------------------------------------------
// AuthScreen — écran de connexion/inscription RÉEL (Phase 4).
//
// Ce flux est désormais exclusivement pour les CLIENTS (customer) : il
// utilise FirebaseAuthProvider.signInWithEmailPassword() /
// .signUpWithEmailPassword() — plus aucune inscription démo "magic link".
//
// Les chauffeurs ont leur propre parcours dédié
// (/devenir-chauffeur/inscription -> DriverOnboardingScreen, qui gère
// lui-même la création du compte Firebase Auth). Le mécanicien mobile reste
// un domaine hors-scope Phase 4 (flux démo isolé) : le choix "Mécanicien
// mobile" ci-dessous redirige simplement vers son propre parcours
// d'inscription démo existant, sans toucher à l'identité Firebase.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';

enum _AuthRoleChoice { customer, driver, mechanic }

enum _AuthMode { signIn, signUp }

class AuthScreen extends StatefulWidget {
  final String locale;
  const AuthScreen({super.key, required this.locale});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  _AuthRoleChoice _role = _AuthRoleChoice.customer;
  _AuthMode _mode = _AuthMode.signIn;
  bool _submitting = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final auth = context.watch<FirebaseAuthProvider>();

    if (auth.isSignedIn) {
      final displayName = auth.user?.displayName ?? auth.user?.email ?? '';
      return AppShell(
        locale: widget.locale,
        showFooter: false,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 48),
                const SizedBox(height: 16),
                Text(
                  '${t('auth_logged_in_as')} $displayName',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => context.go('/${widget.locale}/tableau-de-bord'),
                  child: Text(t('nav_dashboard')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppShell(
      locale: widget.locale,
      showFooter: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.bolt, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 20),
                Text(t('auth_welcome'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  'Connectez-vous ou créez un compte Movi-K pour continuer.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                Text(t('auth_choose_role'), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    ChoiceChip(
                      label: Text(t('auth_role_customer')),
                      selected: _role == _AuthRoleChoice.customer,
                      onSelected: (_) => setState(() => _role = _AuthRoleChoice.customer),
                    ),
                    ChoiceChip(
                      label: Text(t('auth_role_driver')),
                      selected: _role == _AuthRoleChoice.driver,
                      onSelected: (_) => setState(() => _role = _AuthRoleChoice.driver),
                    ),
                    ChoiceChip(
                      label: Text(t('auth_role_mechanic')),
                      selected: _role == _AuthRoleChoice.mechanic,
                      onSelected: (_) => setState(() => _role = _AuthRoleChoice.mechanic),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_role == _AuthRoleChoice.customer) ...[
                  _buildCustomerForm(t),
                ] else if (_role == _AuthRoleChoice.driver) ...[
                  _buildRedirectCard(
                    icon: Icons.local_shipping_outlined,
                    message: 'Le parcours chauffeur a son propre formulaire d\'inscription complet.',
                    buttonLabel: 'Devenir chauffeur',
                    onPressed: () => context.go('/${widget.locale}/devenir-chauffeur'),
                  ),
                ] else ...[
                  _buildRedirectCard(
                    icon: Icons.build_outlined,
                    message: 'Le parcours mécanicien mobile a son propre formulaire d\'inscription.',
                    buttonLabel: 'Devenir mécanicien',
                    onPressed: () => context.go('/${widget.locale}/devenir-mecanicien'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRedirectCard({
    required IconData icon,
    required String message,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        Icon(icon, size: 40, color: AppColors.primary),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: onPressed, child: Text(buttonLabel)),
        ),
      ],
    );
  }

  Widget _buildCustomerForm(String Function(String) t) {
    return Column(
      children: [
        SegmentedButton<_AuthMode>(
          segments: const [
            ButtonSegment(value: _AuthMode.signIn, label: Text('Se connecter')),
            ButtonSegment(value: _AuthMode.signUp, label: Text('Créer un compte')),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() {
            _mode = s.first;
            _error = null;
          }),
        ),
        const SizedBox(height: 20),
        if (_mode == _AuthMode.signUp) ...[
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: t('auth_full_name')),
          ),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: _emailController,
          decoration: InputDecoration(labelText: t('auth_email')),
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passwordController,
          decoration: const InputDecoration(labelText: 'Mot de passe'),
          obscureText: true,
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12.5, color: AppColors.error))),
            ]),
          ),
        ],
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(_mode == _AuthMode.signIn ? 'Se connecter' : 'Créer mon compte'),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Courriel et mot de passe requis.');
      return;
    }
    if (_mode == _AuthMode.signUp && name.isEmpty) {
      setState(() => _error = 'Le nom complet est requis.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final auth = context.read<FirebaseAuthProvider>();
    try {
      if (_mode == _AuthMode.signIn) {
        await auth.signInWithEmailPassword(email: email, password: password);
      } else {
        await auth.signUpWithEmailPassword(email: email, password: password, fullName: name);
      }
      if (auth.lastError != null) {
        setState(() => _error = auth.lastError);
        return;
      }
      if (mounted && auth.isSignedIn) {
        context.go('/${widget.locale}/tableau-de-bord');
      }
    } catch (e) {
      setState(() => _error = 'Une erreur est survenue. Réessayez.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
