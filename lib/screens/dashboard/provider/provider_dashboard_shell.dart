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
import 'tabs/provider_jobs_tab.dart';
import 'tabs/provider_calendar_tab.dart';
import 'tabs/provider_earnings_tab.dart';
import 'tabs/provider_profile_tab.dart';

class ProviderDashboardShell extends StatefulWidget {
  const ProviderDashboardShell({super.key});

  @override
  State<ProviderDashboardShell> createState() => _ProviderDashboardShellState();
}

class _ProviderDashboardShellState extends State<ProviderDashboardShell> {
  int _index = 0;
  bool _togglingAvailability = false;

  // Bloc M (gap performance, même classe de bug que Bloc C item 3) :
  // `watchDriverProfile(driverId)` était appelé directement dans `build()`,
  // donc réinstancié à chaque `setState()` de `_toggleAvailability` — le
  // StreamBuilder détecte un flux "différent" par référence et repasse en
  // ConnectionState.waiting (flicker du Switch en ligne/hors ligne), en plus
  // de re-souscrire inutilement à Firestore. Mémoïsé par `driverId`.
  String? _cachedDriverId;
  Stream<DriverProfileV2?>? _driverProfileStream;

  Stream<DriverProfileV2?> _ensureDriverProfileStream(String driverId) {
    if (_cachedDriverId != driverId || _driverProfileStream == null) {
      _cachedDriverId = driverId;
      _driverProfileStream = BackendLocator.driverRepository.watchDriverProfile(driverId);
    }
    return _driverProfileStream!;
  }

  Future<void> _toggleAvailability(String driverId, bool goOnline, String Function(String) t) async {
    setState(() => _togglingAvailability = true);
    try {
      await BackendLocator.driverRepository.setDriverOnlineStatus(driverId, goOnline);
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
              const Icon(Icons.lock_outline, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              Text(t('provider_dashboard_locked_message')),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => context.go('/$locale/connexion'), child: Text(t('delivery_sign_in_button'))),
            ],
          ),
        ),
      );
    }

    final driverId = auth.effectiveUid!;

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
    final tabs = [
      const ProviderJobsTab(),
      const ProviderCalendarTab(),
      const ProviderEarningsTab(),
      const ProviderProfileTab(),
    ];
    final navItems = [
      (Icons.assignment_outlined, t('nav_available_jobs')),
      (Icons.calendar_month_outlined, t('nav_calendar')),
      (Icons.payments_outlined, t('nav_earnings')),
      (Icons.person_outline, t('nav_profile')),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(children: [
          IconButton(onPressed: () => context.go('/$locale'), icon: const Icon(Icons.arrow_back)),
          if (!isNarrowPhone) const SizedBox(width: 4),
          if (!isNarrowPhone)
            const Expanded(
              child: Text(
                'Espace fournisseur',
                style: TextStyle(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ]),
        actions: [
          StreamBuilder<DriverProfileV2?>(
            stream: _ensureDriverProfileStream(driverId),
            builder: (context, snap) {
              final profile = snap.data;
              final online = profile?.onlineStatus == DriverOnlineStatus.online;
              final canGoOnline = profile?.status.canGoOnline ?? false;
              final statusLabel = online ? 'Disponible' : 'Hors ligne';
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
                        color: online ? AppColors.success : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  Tooltip(
                    message: statusLabel,
                    child: Switch(
                      value: online,
                      onChanged: (!canGoOnline || _togglingAvailability)
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
          IconButton(onPressed: () => auth.signOut(), icon: const Icon(Icons.logout)),
          const SizedBox(width: 4),
        ],
      ),
      // Bloc M (gap performance identifié, NON corrigé ce tour) : `tabs[_index]`
      // détruit/recrée le State de l'onglet non affiché à chaque changement
      // d'onglet (ré-abonnement Firestore, ex: `_ensureStreams()` de
      // ProviderJobsTab). Un remplacement par `IndexedStack` a été tenté puis
      // REVERTÉ : `IndexedStack` construit les 4 onglets simultanément dès le
      // premier rendu (y compris Earnings/Calendar/Profile, jamais visités),
      // ce qui souscrit immédiatement à des flux Firestore supplémentaires
      // (finance, profil) même quand l'utilisateur reste sur "Missions
      // disponibles" — un coût réseau/mémoire ajouté au démarrage, pire que
      // le gap initial pour l'usage MVP typique (rester sur le premier
      // onglet). Un vrai correctif nécessiterait une construction paresseuse
      // par onglet (ex: `AutomaticKeepAliveClientMixin` par onglet, ou
      // construire l'IndexedStack enfant par enfant uniquement après première
      // visite) — DEFERRED NON-BLOCKING, documenté dans PHASE7_BUG_REPORT.md
      // pour un prochain bloc (hors urgence P0/P1 : le gap actuel n'affecte
      // que la fraîcheur du flux après un retour d'onglet, pas une fuite ni
      // un crash).
      body: isDesktop
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: navItems.map((n) => NavigationRailDestination(icon: Icon(n.$1), label: Text(n.$2))).toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: tabs[_index]),
              ],
            )
          : tabs[_index],
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
              items: navItems.map((n) => BottomNavigationBarItem(icon: Icon(n.$1), label: n.$2)).toList(),
            ),
    );
  }
}
