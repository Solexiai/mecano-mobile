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

    final isDesktop = MediaQuery.of(context).size.width >= 900;
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
        title: Row(children: [
          IconButton(onPressed: () => context.go('/$locale'), icon: const Icon(Icons.arrow_back)),
          const SizedBox(width: 4),
          const Text('Espace fournisseur', style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        actions: [
          StreamBuilder<DriverProfileV2?>(
            stream: BackendLocator.driverRepository.watchDriverProfile(driverId),
            builder: (context, snap) {
              final profile = snap.data;
              final online = profile?.onlineStatus == DriverOnlineStatus.online;
              final canGoOnline = profile?.status.canGoOnline ?? false;
              return Row(children: [
                Text(
                  online ? 'Disponible' : 'Hors ligne',
                  style: TextStyle(
                    fontSize: 12,
                    color: online ? AppColors.success : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Switch(
                  value: online,
                  onChanged: (!canGoOnline || _togglingAvailability)
                      ? null
                      : (v) => _toggleAvailability(driverId, v, t),
                  activeThumbColor: AppColors.success,
                ),
              ]);
            },
          ),
          NotificationBell(userId: driverId),
          const LanguageSelector(compact: true),
          const SizedBox(width: 8),
          IconButton(onPressed: () => auth.signOut(), icon: const Icon(Icons.logout)),
          const SizedBox(width: 8),
        ],
      ),
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
