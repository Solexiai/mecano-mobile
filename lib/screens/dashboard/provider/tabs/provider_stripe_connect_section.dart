// ---------------------------------------------------------------------------
// ProviderStripeConnectSection — Bloc 8B, PRIORITÉ 1 (Connect Onboarding
// Flutter).
//
// GAP CORRIGÉ : jusqu'ici, aucun écran Flutter n'appelait jamais la Cloud
// Function existante `createDriverStripeAccount` (voir
// `functions/src/functions/createDriverStripeAccount.ts`, inchangée) —
// aucun chauffeur réel ne pouvait donc jamais entrer dans Stripe Connect,
// ce qui bloquait tout versement en pratique (`submitDriverPayout()` exige
// `stripe_connected_account_id`, jamais renseigné sans ce flow).
//
// FLOW IMPLÉMENTÉ (exactement celui demandé par la directive) :
//   chauffeur approuvé
//     -> ouvre cette section (configuration paiement/payout)
//     -> déclenche `createOrRetrieveDriverStripeAccount()`
//        (relaie SANS AUCUNE modification `createDriverStripeAccount`,
//        idempotent côté serveur : ne crée jamais un second compte)
//     -> reçoit `onboardingUrl` (lien hébergé Stripe, généré côté serveur)
//     -> `url_launcher` ouvre cette URL dans un onglet/navigateur externe
//        (jamais de formulaire carte/compte bancaire affiché dans Movi-K)
//     -> le chauffeur complète l'onboarding CHEZ STRIPE, puis revient dans
//        Movi-K (bouton retour explicite, cette section n'essaie jamais de
//        deviner un "retour automatique")
//     -> l'état réel (`stripe_charges_enabled`/`stripe_payouts_enabled`)
//        est relu depuis `DriverProfileV2` (synchronisé par le webhook
//        `account.updated`, GAP-8B-01 déjà corrigé/mergé) via un bouton
//        "Actualiser" explicite (`watchDriverProfile` est déjà un flux
//        temps réel : Firestore repoussera la mise à jour dès que le
//        webhook aura tourné, sans action du chauffeur — le bouton
//        "Actualiser" ne fait que rassurer visuellement l'utilisateur en
//        cas de délai réseau, il ne relit rien de plus que le stream).
//
// ÉTATS COUVERTS (tous distincts, jamais de faux succès) :
//   1. no_account         — aucun `stripe_connected_account_id` encore.
//   2. onboarding_pending — compte créé, onboarding pas encore complété
//      (`stripe_charges_enabled == false || stripe_payouts_enabled == false`).
//   3. active             — `charges_enabled == true && payouts_enabled == true`.
//   4. loading            — appel `createOrRetrieveDriverStripeAccount()` en
//      cours (bouton désactivé, spinner).
//   5. error              — l'appel a échoué (`BackendNotConfiguredException`
//      ou toute autre exception) : message clair + bouton "Réessayer".
//
// RÈGLE ABSOLUE RESPECTÉE : aucun secret Stripe (`STRIPE_SECRET_KEY`,
// `STRIPE_WEBHOOK_SECRET`) n'est jamais chargé, transmis, ni référencé ici
// ou dans le repository — ce widget ne voit qu'un identifiant de compte
// opaque et une URL déjà signée par Stripe côté serveur.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../backend/backend_exceptions.dart';
import '../../../../backend/backend_locator.dart';
import '../../../../backend/models/driver_profile_v2.dart';
import '../../../../core/app_colors.dart';

class ProviderStripeConnectSection extends StatefulWidget {
  final DriverProfileV2? profile;
  final String Function(String) t;

  const ProviderStripeConnectSection({
    super.key,
    required this.profile,
    required this.t,
  });

  @override
  State<ProviderStripeConnectSection> createState() => _ProviderStripeConnectSectionState();
}

class _ProviderStripeConnectSectionState extends State<ProviderStripeConnectSection> {
  bool _loading = false;
  String? _error;
  // Bloc 8B — `onboardingUrl` renvoyée par le dernier appel réussi, gardée
  // en mémoire uniquement pour permettre le bouton "Rouvrir le lien" tant
  // que le profil Firestore n'a pas encore reçu la valeur (latence
  // normale : l'écriture Firestore de `createDriverStripeAccount` a lieu
  // avant le retour de l'appel callable, mais le stream peut arriver
  // quelques centaines de ms plus tard). Jamais persistée, jamais un
  // secret (c'est une URL Stripe déjà signée, à usage limité, publique
  // par nature — comme un lien de réinitialisation de mot de passe).
  String? _lastOnboardingUrl;

  Future<void> _startOrResumeOnboarding() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await BackendLocator.driverRepository.createOrRetrieveDriverStripeAccount();
      if (!mounted) return;
      if (result.success != true || result.onboardingUrl == null) {
        setState(() {
          _loading = false;
          _error = widget.t('provider_stripe_connect_error_generic');
        });
        return;
      }
      _lastOnboardingUrl = result.onboardingUrl;
      setState(() => _loading = false);
      await _openOnboardingUrl(result.onboardingUrl!);
    } on BackendNotConfiguredException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.t('provider_stripe_connect_error_not_configured');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.t('provider_stripe_connect_error_generic');
      });
    }
  }

  Future<void> _openOnboardingUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      setState(() => _error = widget.t('provider_stripe_connect_error_generic'));
      return;
    }
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        setState(() => _error = widget.t('provider_stripe_connect_error_open_link'));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = widget.t('provider_stripe_connect_error_open_link'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final profile = widget.profile;
    final accountId = profile?.stripeConnectedAccountId;
    final chargesEnabled = profile?.stripeChargesEnabled ?? false;
    final payoutsEnabled = profile?.stripePayoutsEnabled ?? false;
    final hasAccount = accountId != null && accountId.isNotEmpty;
    final isActive = hasAccount && chargesEnabled && payoutsEnabled;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isActive ? Icons.verified_outlined : Icons.account_balance_outlined,
                color: isActive ? AppColors.success : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('provider_stripe_connect_title'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              _StatusBadge(
                label: _statusLabel(t, hasAccount: hasAccount, isActive: isActive),
                color: isActive
                    ? AppColors.success
                    : (hasAccount ? AppColors.warning : AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _statusDescription(t, hasAccount: hasAccount, isActive: isActive),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          if (hasAccount) ...[
            const SizedBox(height: 12),
            _CapabilityRow(
              label: t('provider_stripe_connect_charges_enabled'),
              enabled: chargesEnabled,
            ),
            const SizedBox(height: 6),
            _CapabilityRow(
              label: t('provider_stripe_connect_payouts_enabled'),
              enabled: payoutsEnabled,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (!isActive)
                ElevatedButton.icon(
                  onPressed: _loading ? null : _startOrResumeOnboarding,
                  icon: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.open_in_new, size: 18),
                  label: Text(
                    _loading
                        ? t('provider_stripe_connect_loading')
                        : (hasAccount
                            ? t('provider_stripe_connect_resume')
                            : t('provider_stripe_connect_start')),
                  ),
                ),
              if (!isActive && _lastOnboardingUrl != null && !_loading)
                OutlinedButton.icon(
                  onPressed: () => _openOnboardingUrl(_lastOnboardingUrl!),
                  icon: const Icon(Icons.link, size: 18),
                  label: Text(t('provider_stripe_connect_reopen_link')),
                ),
              if (hasAccount && !isActive)
                OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () {
                          // Bloc 8B — "Actualiser" : `watchDriverProfile` est
                          // déjà un flux Firestore temps réel (voir
                          // `provider_profile_tab.dart::StreamBuilder`), donc
                          // aucune relecture manuelle n'est nécessaire ici.
                          // Ce bouton existe pour l'état "refresh/retry"
                          // explicitement requis par la directive : il
                          // efface juste l'erreur locale éventuelle et force
                          // un `setState` pour rassurer visuellement le
                          // chauffeur qu'une vérification a bien eu lieu.
                          setState(() => _error = null);
                        },
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(t('common_retry')),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(String Function(String) t, {required bool hasAccount, required bool isActive}) {
    if (isActive) return t('provider_stripe_connect_status_active');
    if (hasAccount) return t('provider_stripe_connect_status_pending');
    return t('provider_stripe_connect_status_none');
  }

  String _statusDescription(String Function(String) t, {required bool hasAccount, required bool isActive}) {
    if (isActive) return t('provider_stripe_connect_description_active');
    if (hasAccount) return t('provider_stripe_connect_description_pending');
    return t('provider_stripe_connect_description_none');
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  final String label;
  final bool enabled;
  const _CapabilityRow({required this.label, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          enabled ? Icons.check_circle : Icons.hourglass_top,
          size: 16,
          color: enabled ? AppColors.success : AppColors.warning,
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}
