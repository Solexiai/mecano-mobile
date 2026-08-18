import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../providers/firebase_auth_provider.dart';
import '../../../providers/locale_provider.dart';
import '../../../widgets/language_selector.dart';
import 'tabs/customer_overview_tab.dart';
import 'tabs/customer_requests_tab.dart';
import 'tabs/customer_messages_tab.dart';
import 'tabs/customer_profile_tab.dart';

class CustomerDashboardShell extends StatefulWidget {
  const CustomerDashboardShell({super.key});

  @override
  State<CustomerDashboardShell> createState() => _CustomerDashboardShellState();
}

class _CustomerDashboardShellState extends State<CustomerDashboardShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FirebaseAuthProvider>();
    final t = context.watch<LocaleProvider>().t;
    final locale = context.watch<LocaleProvider>().locale;

    if (!auth.isSignedIn) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 48, color: AppColors.textSecondary),
              const SizedBox(height: 16),
              const Text('Connectez-vous pour accéder à votre tableau de bord.'),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: () => context.go('/$locale/connexion'), child: const Text('Se connecter')),
            ],
          ),
        ),
      );
    }

    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final tabs = [
      CustomerOverviewTab(onGoToTab: (i) => setState(() => _index = i)),
      const CustomerRequestsTab(),
      const CustomerMessagesTab(),
      const CustomerProfileTab(),
    ];

    final navItems = [
      (Icons.home_outlined, t('nav_dashboard')),
      (Icons.list_alt_outlined, t('nav_my_requests')),
      (Icons.chat_bubble_outline, t('nav_messages')),
      (Icons.person_outline, t('nav_profile')),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          IconButton(onPressed: () => context.go('/$locale'), icon: const Icon(Icons.arrow_back)),
          const SizedBox(width: 4),
          Text(t('nav_dashboard'), style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        actions: [
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
