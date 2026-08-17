// ---------------------------------------------------------------------------
// AdminLoginScreen — connexion RÉELLE (Firebase Auth email/password) pour les
// rôles privilégiés (analyst / admin / super_admin).
//
// Distinct de AuthScreen (qui reste le flow "démo" client/chauffeur/
// mécanicien, en Hive local, non modifié par cet ajout). Cet écran est le
// SEUL point d'entrée pour les comptes créés directement dans la Console
// Firebase (voir bootstrap_super_admins.js) tant que la migration complète
// des autres rôles vers Firebase Auth n'a pas été faite.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../backend/backend_status.dart';
import '../../core/app_colors.dart';
import '../../providers/firebase_auth_provider.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final backendStatus = context.watch<BackendStatus>();
    final auth = context.watch<FirebaseAuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings_outlined,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Administration Movi-K',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Accès réservé au personnel autorisé (analyste, admin, super-admin).',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 28),

                  if (!backendStatus.isConfigured)
                    _InfoBanner(
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      text:
                          'Backend Firebase non configuré sur cet environnement. La connexion admin est indisponible.',
                    )
                  else ...[
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Courriel',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (auth.lastError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _InfoBanner(
                          icon: Icons.error_outline,
                          color: AppColors.error,
                          text: auth.lastError!,
                        ),
                      ),

                    const SizedBox(height: 8),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _submit,
                        child: auth.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Se connecter'),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  TextButton(
                    onPressed: () => context.go('/fr'),
                    child: const Text('Retour à l\'accueil'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;

    final auth = context.read<FirebaseAuthProvider>();
    final ok = await auth.signInWithEmailPassword(
      email: email,
      password: password,
    );
    if (!ok || !mounted) return;

    if (auth.isAnalystOrAbove) {
      context.go('/fr/admin/chauffeurs');
      return;
    }

    if (auth.claimsFetchFailed) {
      // Échec RÉSEAU/temporaire de lecture des custom claims (pas un
      // problème de droits) : on NE déconnecte PAS le compte, on laisse
      // l'utilisateur réessayer sans perdre sa session.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Connexion réussie mais impossible de vérifier vos droits '
            'pour le moment. Veuillez réessayer dans quelques secondes.',
          ),
        ),
      );
      return;
    }

    // Compte valide, claims lus avec succès, mais réellement sans rôle
    // privilégié : on refuse l'accès admin et on déconnecte pour éviter
    // toute confusion — cet écran est réservé au personnel autorisé.
    await auth.signOut();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Ce compte n\'a pas les droits d\'administration requis.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simple gate utilisée par la route /admin : affiche AdminLoginScreen tant
/// que l'utilisateur n'est pas connecté avec un rôle admin/super_admin,
/// sinon affiche `child` (le vrai AdminDashboardShell).
class AdminAuthGate extends StatelessWidget {
  final Widget child;
  const AdminAuthGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final backendStatus = context.watch<BackendStatus>();
    if (!backendStatus.isConfigured) {
      return const AdminLoginScreen();
    }

    final auth = context.watch<FirebaseAuthProvider>();

    if (!auth.isSignedIn) {
      return const AdminLoginScreen();
    }

    if (!auth.claimsLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (auth.claimsFetchFailed && !auth.isAnalystOrAbove) {
      // Utilisateur bien connecté, mais impossible de confirmer ses droits
      // (échec réseau/temporaire) : on propose un nouvel essai plutôt que
      // de le renvoyer silencieusement vers l'écran de connexion.
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 40),
                const SizedBox(height: 16),
                const Text(
                  'Impossible de vérifier vos droits d\'accès pour le '
                  'moment. Vérifiez votre connexion et réessayez.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => auth.refreshClaims(),
                  child: const Text('Réessayer'),
                ),
                TextButton(
                  onPressed: () => auth.signOut(),
                  child: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!auth.isAnalystOrAbove) {
      return const AdminLoginScreen();
    }

    return _AdminShellWithSignOut(child: child);
  }
}

class _AdminShellWithSignOut extends StatelessWidget {
  final Widget child;
  const _AdminShellWithSignOut({required this.child});

  @override
  Widget build(BuildContext context) {
    // On enveloppe simplement le dashboard existant ; le bouton de
    // déconnexion est exposé via un Provider.of accessible depuis
    // AdminDashboardShell si besoin, mais pour rester non-intrusif on
    // fournit ici un bouton flottant discret de déconnexion.
    return Stack(
      children: [
        child,
        Positioned(
          top: 8,
          right: 8,
          child: SafeArea(
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                tooltip: 'Se déconnecter',
                icon: const Icon(Icons.logout, size: 20),
                onPressed: () => context.read<FirebaseAuthProvider>().signOut(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
