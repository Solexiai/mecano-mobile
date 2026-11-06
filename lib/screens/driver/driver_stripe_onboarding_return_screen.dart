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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../backend/backend_locator.dart';
import '../../backend/models/driver_payout_readiness.dart';
import '../../backend/models/driver_profile_v2.dart';
import '../../core/app_colors.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';

enum DriverStripeOnboardingReturnMode { complete, refresh }

class DriverStripeOnboardingReturnScreen extends StatefulWidget {
  final String locale;
  final DriverStripeOnboardingReturnMode mode;

  /// 2026-11-06 : après « Compte inscrit » chez Stripe, le chauffeur est
  /// ramené automatiquement à son tableau de bord au bout de ce délai
  /// (mode `complete` seulement). Null = pas de redirection automatique.
  final Duration? autoRedirectAfter;

  const DriverStripeOnboardingReturnScreen({
    super.key,
    required this.locale,
    required this.mode,
    this.autoRedirectAfter = const Duration(seconds: 8),
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
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    final delay = widget.autoRedirectAfter;
    if (widget.mode == DriverStripeOnboardingReturnMode.complete &&
        delay != null) {
      _redirectTimer = Timer(delay, _goToDashboard);
    }
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  void _goToDashboard() {
    if (!mounted) return;
    // Onglet Profil (index 3) : c'est là que vit la carte Stripe dont
    // l'indicateur passe au vert.
    if (GoRouter.maybeOf(context) == null) return;
    context.go(
      '/${widget.locale}/fournisseur/tableau-de-bord',
      extra: const {'initialTabIndex': 3},
    );
  }

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
    if (!auth.authResolved) {
      // 2026-11-06 : Stripe ramène le chauffeur ici dans une page chargée à
      // froid ; Firebase Auth met quelques centaines de ms à restaurer la
      // session. Rediriger avant ça envoyait un chauffeur connecté sur la
      // page de connexion (« Connecté en tant que… ») au lieu de cet écran.
      return const Center(child: CircularProgressIndicator());
    }
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
        // 2026-11-06 : même règle que le serveur (compte réel + identité +
        // banque) ; un compte de test n'est jamais « actif ».
        final isActive =
            driverPayoutReadiness(profile) == DriverPayoutReadiness.ready;

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
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                  if (snap.connectionState != ConnectionState.waiting) ...[
                    const SizedBox(height: 12),
                    Text(
                      isActive
                          ? t('driver_onboarding_return_status_active')
                          : t('driver_onboarding_return_status_pending'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isActive
                            ? AppColors.success
                            : AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (widget.mode == DriverStripeOnboardingReturnMode.complete &&
                      widget.autoRedirectAfter != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      t('driver_onboarding_return_auto_redirect'),
                      key: const ValueKey('driver-onboarding-return-redirect'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (widget.mode == DriverStripeOnboardingReturnMode.refresh)
                        OutlinedButton.icon(
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: Text(t('driver_onboarding_return_refresh_state')),
                        ),
                      ElevatedButton.icon(
                        key: const ValueKey('driver-onboarding-return-dashboard'),
                        onPressed: () {
                          _redirectTimer?.cancel();
                          context.go(
                            '/${widget.locale}/fournisseur/tableau-de-bord',
                            extra: const {'initialTabIndex': 3},
                          );
                        },
                        icon: const Icon(Icons.dashboard_outlined, size: 18),
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
