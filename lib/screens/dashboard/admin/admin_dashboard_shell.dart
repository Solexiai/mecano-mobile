import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../providers/locale_provider.dart';
import '../../../services/demo_data_service.dart';
import '../../../widgets/coming_soon_badge.dart';

/// Admin dashboard — écran d'accueil `/admin` (résumé du marché +
/// navigation vers les portails dédiés par domaine métier).
///
/// Architecture forward-compatible : chaque domaine (chauffeurs, missions,
/// paiements, pricing, founding-drivers, analytics) a sa propre route
/// dédiée sous `/admin/...` (voir app_router.dart). Ce shell n'affiche
/// QUE le résumé (`_AdminOverviewTab`) et les paramètres plateforme
/// (`_AdminSettingsTab`) ; le portail "Chauffeurs" navigue vers la vraie
/// route `/admin/chauffeurs` au lieu d'être un onglet embarqué, afin que
/// l'URL reflète toujours l'état réel (partage de lien, retour arrière,
/// deep-linking analyste).
class AdminDashboardShell extends StatefulWidget {
  const AdminDashboardShell({super.key});

  @override
  State<AdminDashboardShell> createState() => _AdminDashboardShellState();
}

class _AdminDashboardShellState extends State<AdminDashboardShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final tabs = [const _AdminOverviewTab(), const _AdminSettingsTab()];

    void openDrivers() => context.go('/$locale/admin/chauffeurs');
    void openFinance() => context.go('/$locale/admin/paiements');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            IconButton(
              onPressed: () => context.go('/$locale'),
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 4),
            const Text(
              'Administration Movi-k',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        actions: const [
          Padding(padding: EdgeInsets.only(right: 16), child: DemoDataBadge()),
        ],
      ),
      body: isDesktop
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _tab,
                  onDestinationSelected: (i) {
                    if (i == 1) {
                      openDrivers();
                      return;
                    }
                    if (i == 3) {
                      openFinance();
                      return;
                    }
                    setState(() => _tab = i == 2 ? 1 : 0);
                  },
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.dashboard_outlined),
                      label: Text('Vue d\'ensemble'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.verified_user_outlined),
                      label: Text('Chauffeurs'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      label: Text('Paramètres'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.account_balance_outlined),
                      label: Text('Finance'),
                    ),
                  ],
                ),
                const VerticalDivider(width: 1),
                Expanded(child: tabs[_tab]),
              ],
            )
          : Column(
              children: [
                Expanded(child: tabs[_tab]),
                BottomNavigationBar(
                  currentIndex: _tab,
                  type: BottomNavigationBarType.fixed,
                  onTap: (i) {
                    if (i == 1) {
                      openDrivers();
                      return;
                    }
                    if (i == 3) {
                      openFinance();
                      return;
                    }
                    setState(() => _tab = i == 2 ? 1 : 0);
                  },
                  items: const [
                    BottomNavigationBarItem(
                      icon: Icon(Icons.dashboard_outlined),
                      label: 'Vue d\'ensemble',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.verified_user_outlined),
                      label: 'Chauffeurs',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.settings_outlined),
                      label: 'Paramètres',
                    ),
                    BottomNavigationBarItem(
                      icon: Icon(Icons.account_balance_outlined),
                      label: 'Finance',
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _AdminOverviewTab extends StatelessWidget {
  const _AdminOverviewTab();

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Clients', '128', Icons.people_outline, AppColors.primary),
      (
        'Chauffeurs qualifiés',
        '${DemoDataService.drivers.length}',
        Icons.local_shipping_outlined,
        AppColors.success,
      ),
      (
        'Mécaniciens qualifiés',
        '${DemoDataService.mechanics.length}',
        Icons.build_outlined,
        AppColors.success,
      ),
      ('Demandes actives', '4', Icons.timelapse, AppColors.warning),
      (
        'Réservations complétées',
        '20',
        Icons.check_circle_outline,
        AppColors.success,
      ),
      ('Litiges', '0', Icons.report_gmailerrorred_outlined, AppColors.error),
    ];
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vue d\'ensemble du marché',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ces chiffres sont des hypothèses de validation interne pour les 60 premiers jours (données de démonstration).',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: isDesktop ? 3 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.3,
            children: metrics
                .map(
                  (m) => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(m.$3, color: m.$4),
                        const SizedBox(height: 10),
                        Text(
                          m.$2,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: m.$4,
                          ),
                        ),
                        Text(
                          m.$1,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cibles de validation interne (60 jours)',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(
                  '• 50 mécaniciens mobiles qualifiés',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '• 30 chauffeurs de livraison qualifiés',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '• 20 emplois complétés',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Ces cibles sont des hypothèses internes, non des indicateurs publics.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSettingsTab extends StatefulWidget {
  const _AdminSettingsTab();

  @override
  State<_AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<_AdminSettingsTab> {
  bool _commissionEnabled = false;
  double _commissionPct = 10;
  double _bookingFee = 0;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paramètres de la plateforme',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monétisation future',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Ces paramètres sont préparés pour une activation future. La commission est désactivée par défaut durant le MVP.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activer la commission'),
                  value: _commissionEnabled,
                  onChanged: (v) => setState(() => _commissionEnabled = v),
                  activeThumbColor: AppColors.primary,
                ),
                Text(
                  'Pourcentage de commission: ${_commissionPct.round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: _commissionPct,
                  min: 8,
                  max: 12,
                  divisions: 4,
                  activeColor: AppColors.primary,
                  onChanged: _commissionEnabled
                      ? (v) => setState(() => _commissionPct = v)
                      : null,
                ),
                const SizedBox(height: 10),
                Text(
                  'Frais de réservation client: ${_bookingFee.toStringAsFixed(2)}\$',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: _bookingFee,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  activeColor: AppColors.primary,
                  onChanged: (v) => setState(() => _bookingFee = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ces paramètres sont sauvegardés localement pour cette démonstration et ne sont pas encore connectés à un moteur de facturation réel.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
