// ---------------------------------------------------------------------------
// DriverStripeOnboardingReturnScreen — Bloc 8B LIVE, gap fermé AVANT
// onboarding Stripe Connect réel.
//
// CONTEXTE DU GAP (voir docs/PAYMENT_ARCHITECTURE.md §10.3/§10.7) :
// `stripeProvider.ts::createDriverAccount()` génère un lien d'onboarding
// hébergé Stripe avec un `return_url` (onboarding complété) et un
// `refresh_url` (lien expiré/abandonné). Avant ce correctif, ces deux URLs
// pointaient vers `movik.ca/chauffeur/onboarding/complete|refresh` — un
// domaine confirmé (vérification réseau réelle) NE PAS servir l'app Movi-K
// (échec de handshake TLS), ET qui de toute façon ne correspondait à AUCUNE
// route Flutter existante : un chauffeur revenant de Stripe atterrissait
// sur une page morte / 404.
//
// CE QUE FAIT CET ÉCRAN (les 4 points demandés) :
//   (a) retour après onboarding complété — `mode: complete`.
//   (b) refresh/retry onboarding — `mode: refresh`.
//   (c) relecture de l'état Stripe Connect — réutilise
//       `watchDriverProfile()` (flux Firestore temps réel déjà utilisé par
//       `ProviderStripeConnectSection`/`DriverStatusScreen` — AUCUNE
//       nouvelle logique de lecture dupliquée).
//   (d) retour propre vers le profil chauffeur — bouton explicite qui
//       navigue vers `ProviderDashboardShell` avec `initialTabIndex: 3`
//       (onglet Profil, où vit `ProviderStripeConnectSection`), pas
//       l'onglet par défaut (Missions).
//
// RÈGLE ABSOLUE RESPECTÉE : aucun secret Stripe n'est jamais chargé ici —
// cet écran ne fait QUE lire `DriverProfileV2` (déjà synchronisé par le
// webhook `account.updated`, GAP-8B-01) via le repository existant.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../backend/backend_locator.dart';
import '../../backend/models/driver_profile_v2.dart';
import '../../core/app_colors.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';

enum DriverStripeOnboardingReturnMode { complete, refresh }

class DriverStripeOnboardingReturnScreen extends StatefulWidget {
  final String locale;
  final DriverStripeOnboardingReturnMode mode;

  const DriverStripeOnboardingReturnScreen({
    super.key,
    required this.locale,
    required this.mode,
  });

  @override
  State<DriverStripeOnboardingReturnScreen> createState() =>
      _DriverStripeOnboardingReturnScreenState();
}

class _DriverStripeOnboardingReturnScreenState
    extends State<DriverStripeOnboardingReturnScreen> {
  // Mémoïsation par uid, même motif que `DriverStatusScreen`/
  // `ProviderDashboardShell` (Bloc M) — évite de recréer le Stream à
  // chaque `setState()` du bouton "Actualiser l'état".
  String? _cachedUid;
  Stream<DriverProfileV2?>? _driverProfileStream;

  Stream<DriverProfileV2?> _ensureDriverProfileStream(String uid) {
    if (_cachedUid != uid || _driverProfileStream == null) {
      _cachedUid = uid;
      _driverProfileStream = BackendLocator.driverRepository.watchDriverProfile(uid);
    }
    return _driverProfileStream!;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final auth = context.watch<FirebaseAuthProvider>();

    return AppShell(
      locale: widget.locale,
      showFooter: false,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: _buildBody(context, t, auth),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    String Function(String) t,
    FirebaseAuthProvider auth,
  ) {
    if (!auth.isSignedIn || auth.effectiveUid == null) {
      // Pas de session (ex. lien Stripe ouvert dans un navigateur/onglet où
      // la session Movi-K n'a pas persisté) : redirection discrète vers la
      // connexion plutôt qu'un état vide trompeur — même motif que
      // `DriverStatusScreen`/`ProviderDashboardShell`.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/${widget.locale}/connexion');
      });
      return const Center(child: CircularProgressIndicator());
    }

    final uid = auth.effectiveUid!;

    return StreamBuilder<DriverProfileV2?>(
      stream: _ensureDriverProfileStream(uid),
      builder: (context, snap) {
        final profile = snap.data;
        final chargesEnabled = profile?.stripeChargesEnabled ?? false;
        final payoutsEnabled = profile?.stripePayoutsEnabled ?? false;
        final isActive = chargesEnabled && payoutsEnabled;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              t('driver_onboarding_return_title'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: (isActive ? AppColors.success : AppColors.primary)
                            .withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isActive
                            ? Icons.verified_outlined
                            : (widget.mode == DriverStripeOnboardingReturnMode.refresh
                                ? Icons.refresh
                                : Icons.hourglass_top_rounded),
                        color: isActive ? AppColors.success : AppColors.primary,
                        size: 34,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.mode == DriverStripeOnboardingReturnMode.refresh
                        ? t('driver_onboarding_return_refresh_message')
                        : t('driver_onboarding_return_complete_message'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
                  ),
                  if (snap.connectionState != ConnectionState.waiting) ...[
                    const SizedBox(height: 16),
                    Text(
                      isActive
                          ? t('driver_onboarding_return_status_active')
                          : t('driver_onboarding_return_status_pending'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isActive ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(t('driver_onboarding_return_refresh_state')),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => context.go(
                          '/${widget.locale}/fournisseur/tableau-de-bord',
                          extra: const {'initialTabIndex': 3},
                        ),
                        icon: const Icon(Icons.person_outline, size: 18),
                        label: Text(t('driver_onboarding_return_go_to_profile')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
