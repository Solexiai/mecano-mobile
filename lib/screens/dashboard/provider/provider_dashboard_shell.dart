import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/app_colors.dart';
import '../../../providers/firebase_auth_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../widgets/language_selector.dart';
import '../../../widgets/notification_bell.dart';
import '../../../backend/backend_locator.dart';
import '../../../backend/models/driver_profile_v2.dart';
import '../../../models/enums.dart';
import '../../../services/driver_location_reporter.dart';
import '../../../services/push_notification_service.dart';
import 'tabs/provider_jobs_tab.dart';
import 'tabs/provider_calendar_tab.dart';
import 'tabs/provider_earnings_tab.dart';
import 'tabs/provider_profile_tab.dart';

class ProviderDashboardShell extends StatefulWidget {
  // Bloc 8B LIVE (gap fermé) — `_index` par défaut est 0 (onglet "Missions
  // disponibles"), PAS l'onglet Profil (index 3) où vit
  // `ProviderStripeConnectSection`. Un retour brut vers ce shell après
  // l'onboarding Stripe Connect n'afficherait donc jamais la confirmation
  // d'état attendue par le chauffeur. `initialTabIndex` permet à un appelant
  // (ex. `DriverStripeOnboardingReturnScreen`) de forcer l'onglet Profil
  // sans dupliquer la logique du shell — reste `0` (comportement identique
  // à avant) pour tout appelant existant qui ne le fournit pas.
  final int initialTabIndex;

  const ProviderDashboardShell({super.key, this.initialTabIndex = 0});

  @override
  State<ProviderDashboardShell> createState() => _ProviderDashboardShellState();
}

class _ProviderDashboardShellState extends State<ProviderDashboardShell> {
  late int _index = widget.initialTabIndex.clamp(0, 3).toInt();
  // Each tab is mounted only on its first visit, then retained in place.
  // Initial route to Stripe Connect profile (index 3) stays supported.
  late final List<bool> _visitedTabs;
  String? _tabsDriverId;
  bool _togglingAvailability = false;
  bool _signingOut = false;

  // Bloc M (gap performance, même classe de bug que Bloc C item 3) :
  // `watchDriverProfile(driverId)` était appelé directement dans `build()`,
  // donc réinstancié à chaque `setState()` de `_toggleAvailability` — le
  // StreamBuilder détecte un flux "différent" par référence et repasse en
  // ConnectionState.waiting (flicker du Switch en ligne/hors ligne), en plus
  // de re-souscrire inutilement à Firestore. Mémoïsé par `driverId`.
  String? _cachedDriverId;
  Stream<DriverProfileV2?>? _driverProfileStream;
  DriverProfileV2? _lastProfile;

  @override
  void initState() {
    super.initState();
    _visitedTabs = List<bool>.filled(4, false);
    _visitedTabs[_index] = true;
  }

  void _selectTab(int index) {
    if (index < 0 || index >= _visitedTabs.length || index == _index) return;
    setState(() {
      _visitedTabs[index] = true;
      _index = index;
    });
  }

  Stream<DriverProfileV2?> _ensureDriverProfileStream(String driverId) {
    if (_cachedDriverId != driverId || _driverProfileStream == null) {
      _cachedDriverId = driverId;
      // Broadcast: the AppBar switch and the payout reminder both listen
      // (2026-10-23); a single-subscription stream refuses a second listener.
      // The last value is kept so a listener added later (layout change)
      // starts from it instead of an empty state.
      _lastProfile = null;
      _driverProfileStream = BackendLocator.driverRepository
          .watchDriverProfile(driverId)
          .map((p) => _lastProfile = p)
          .asBroadcastStream();
    }
    return _driverProfileStream!;
  }

  Future<void> _toggleAvailability(
    String driverId,
    bool goOnline,
    String Function(String) t,
  ) async {
    setState(() => _togglingAvailability = true);
    try {
      // Phase 8D : le moment où le chauffeur se rend disponible est le bon
      // contexte UX pour demander la permission système de notifications.
      // Un refus n'empêche JAMAIS de passer en ligne : la cloche Firestore et
      // le flux temps réel des offres continuent de fonctionner.
      await BackendLocator.driverRepository.setDriverOnlineStatus(
        driverId,
        goOnline,
      );
      LocationReporterError? locationError;
      if (goOnline) {
        // Le statut devient visible immédiatement. La notification et le GPS
        // sont ensuite synchronisés sans bloquer la disponibilité; l'adresse
        // de service reste le repli serveur.
        await PushNotificationService.requestPermissionAndSync();
        locationError = await DriverLocationReporter()
            .reportCurrentLocationOnce();
      }
      if (locationError != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('provider_availability_location_fallback'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('provider_availability_toggle_error'))),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingAvailability = false);
    }
  }

  Future<void> _signOutDriver(
    String driverId,
    FirebaseAuthProvider auth,
  ) async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      // Un compte explicitement déconnecté ne doit plus être candidat au
      // dispatch ni recevoir de nouvelles offres sur un appareil partagé.
      // Chaque étape est fail-soft pour garantir que l'utilisateur puisse
      // toujours terminer sa déconnexion même si le réseau coupe.
      try {
        await BackendLocator.driverRepository.setDriverOnlineStatus(
          driverId,
          false,
        );
      } catch (_) {}
      await PushNotificationService.unregisterCurrentToken();
      await auth.signOut();
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FirebaseAuthProvider>();
    final t = context.watch<LocaleProvider>().t;
    final locale = context.watch<LocaleProvider>().locale;

    if (!auth.isSignedIn || auth.effectiveUid == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(t('provider_dashboard_locked_message')),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go('/$locale/connexion'),
                child: Text(t('delivery_sign_in_button')),
              ),
            ],
          ),
        ),
      );
    }

    final driverId = auth.effectiveUid!;
    // Do not reuse an old driver's tab visit history after an account
    // switch in the same widget. Cached child state is owned by its user.
    if (_tabsDriverId != driverId) {
      _tabsDriverId = driverId;
      _index = widget.initialTabIndex.clamp(0, 3).toInt();
      _visitedTabs.fillRange(0, _visitedTabs.length, false);
      _visitedTabs[_index] = true;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;
    // Bloc F (gap F-2, bug UI trouvé lors du test de non-régression du
    // Switch online/offline) : sur téléphone étroit (ex. 320-428px de
    // large, iPhone SE jusqu'à iPhone Pro Max), le nombre d'actions dans
    // l'AppBar (libellé "Disponible"/"Hors ligne" + Switch + cloche
    // notifications + sélecteur de langue + déconnexion) dépassait
    // l'espace disponible et provoquait un RenderFlex overflow (jusqu'à
    // 429px, reproductible sur toutes les largeurs de téléphone testées
    // sauf 360px). Correctif : masquer uniquement le libellé texte
    // DÉCORATIF "Disponible"/"Hors ligne" sur écran étroit — le Switch
    // (action essentielle, jamais masqué) reste toujours visible et
    // fonctionnel, avec un Tooltip pour conserver l'information de statut
    // de façon accessible même sans le texte.
    final isNarrowPhone = screenWidth < 480;
    final tabs = <Widget>[
      if (_visitedTabs[0]) const ProviderJobsTab() else const SizedBox.shrink(),
      if (_visitedTabs[1])
        const ProviderCalendarTab()
      else
        const SizedBox.shrink(),
      if (_visitedTabs[2])
        const ProviderEarningsTab()
      else
        const SizedBox.shrink(),
      if (_visitedTabs[3])
        const ProviderProfileTab()
      else
        const SizedBox.shrink(),
    ];
    final navItems = [
      (Icons.home_outlined, t('nav_available_jobs')),
      (Icons.calendar_month_outlined, t('nav_calendar')),
      (Icons.payments_outlined, t('nav_earnings')),
      (Icons.person_outline, t('nav_profile')),
    ];

    return Scaffold(
      appBar: AppBar(
        // Un seul bouton Retour : AppBar ne doit pas ajouter automatiquement
        // une deuxième flèche quand le dashboard est ouvert depuis une autre
        // page. Le titre est contraint et ne peut donc jamais recouvrir la
        // cloche ou les autres actions sur téléphone.
        automaticallyImplyLeading: false,
        leading: IconButton(
          onPressed: () => context.go('/$locale'),
          tooltip: t('common_back'),
          icon: const Icon(Icons.arrow_back),
        ),
        titleSpacing: 0,
        title: Text(
          t('nav_provider_space'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          StreamBuilder<DriverProfileV2?>(
            stream: _ensureDriverProfileStream(driverId),
            initialData: _lastProfile,
            builder: (context, snap) {
              final profile = snap.data;
              final online = profile?.onlineStatus == DriverOnlineStatus.online;
              final canGoOnline = profile?.status.canGoOnline ?? false;
              // Phase 7, Bloc AB (AB-4, gap AB-4-B) — GAP RÉEL corrigé :
              // ces libellés étaient codés en dur en français
              // ("Disponible"/"Hors ligne"), donc affichés tels quels
              // même en EN/ES (mélange de langue visible dans l'AppBar
              // du tableau de bord chauffeur — viole AB-7).
              final statusLabel = online
                  ? t('driver_status_online_label_short')
                  : t('driver_status_offline_label_short');
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sur téléphone étroit, le libellé texte décoratif est
                  // masqué pour éviter l'overflow (voir commentaire sur
                  // `isNarrowPhone` ci-dessus) ; l'information de statut
                  // reste accessible via le Tooltip du Switch, qui reste
                  // TOUJOURS visible et fonctionnel (action essentielle,
                  // jamais masquée) quelle que soit la largeur d'écran.
                  if (!isNarrowPhone)
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: online
                            ? AppColors.success
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Tooltip(
                    message: statusLabel,
                    child: Switch(
                      value: online,
                      onChanged:
                          (!canGoOnline || _togglingAvailability || _signingOut)
                          ? null
                          : (v) => _toggleAvailability(driverId, v, t),
                      activeThumbColor: AppColors.success,
                    ),
                  ),
                ],
              );
            },
          ),
          NotificationBell(userId: driverId),
          if (!isNarrowPhone) const LanguageSelector(compact: true),
          if (!isNarrowPhone) const SizedBox(width: 8),
          IconButton(
            onPressed: _signingOut
                ? null
                : () => _signOutDriver(driverId, auth),
            tooltip: t('nav_logout'),
            icon: _signingOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
          ),
          const SizedBox(width: 4),
        ],
      ),
      // GAP-M-05: IndexedStack retains each visited tab's State and streams.
      // Unvisited tabs remain cheap placeholders: they are not constructed
      // at startup, avoiding premature finance/profile Firestore listeners.
      // The Row/Expanded wrapper stays stable across mobile/desktop layouts,
      // so switching layouts does not discard already visited child states.
      body: Row(
        children: [
          if (isDesktop) ...[
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: _selectTab,
              labelType: NavigationRailLabelType.all,
              destinations: navItems
                  .map(
                    (n) => NavigationRailDestination(
                      icon: Icon(n.$1),
                      label: Text(n.$2),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
          ],
          Expanded(
            // Stable structure (banner slot always present) so showing or
            // hiding the reminder never rebuilds the retained tabs.
            child: Column(
              children: [
                StreamBuilder<DriverProfileV2?>(
                  stream: _ensureDriverProfileStream(driverId),
                  initialData: _lastProfile,
                  builder: (context, snap) => _PayoutSetupBanner(
                    profile: snap.data,
                    t: t,
                    onOpen: () => _selectTab(3),
                  ),
                ),
                Expanded(child: IndexedStack(index: _index, children: tabs)),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              currentIndex: _index,
              onTap: _selectTab,
              items: navItems
                  .map(
                    (n) =>
                        BottomNavigationBarItem(icon: Icon(n.$1), label: n.$2),
                  )
                  .toList(),
            ),
    );
  }
}

/// Reminder shown on every tab once Movi-K approved the driver, until the
/// Stripe Connect setup is finished (2026-10-23). The setup itself lives in
/// the Profile tab (ProviderStripeConnectSection).
class _PayoutSetupBanner extends StatelessWidget {
  const _PayoutSetupBanner({
    required this.profile,
    required this.t,
    required this.onOpen,
  });
  final DriverProfileV2? profile;
  final String Function(String) t;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p == null ||
        p.status != DriverStatus.approved ||
        (p.stripeChargesEnabled && p.stripePayoutsEnabled)) {
      return const SizedBox.shrink();
    }
    final pending = (p.stripeConnectedAccountId ?? '').isNotEmpty;
    return Container(
      key: const ValueKey('driver-payout-setup-banner'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfffff1dd),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            t(
              pending
                  ? 'driver_payout_setup_banner_pending'
                  : 'driver_payout_setup_banner',
            ),
          ),
          FilledButton.icon(
            key: const ValueKey('driver-payout-setup-open'),
            onPressed: onOpen,
            icon: const Icon(Icons.account_balance_outlined, size: 18),
            label: Text(t('driver_payout_setup_action')),
          ),
        ],
      ),
    );
  }
}
