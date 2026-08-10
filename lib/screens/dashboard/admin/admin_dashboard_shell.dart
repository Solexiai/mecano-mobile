import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/app_colors.dart';
import '../../../providers/locale_provider.dart';
import '../../../services/demo_data_service.dart';
import '../../../widgets/coming_soon_badge.dart';

/// Admin dashboard — demo overview only. Real moderation actions
/// (approve/reject providers, disputes, settings) require a connected
/// backend; UI is provided but clearly scoped as an MVP preview.
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

    final tabs = [
      const _AdminOverviewTab(),
      const _AdminValidationsTab(),
      const _AdminSettingsTab(),
    ];
    final navItems = const [
      (Icons.dashboard_outlined, 'Vue d\'ensemble'),
      (Icons.verified_user_outlined, 'Validations'),
      (Icons.settings_outlined, 'Paramètres'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          IconButton(onPressed: () => context.go('/$locale'), icon: const Icon(Icons.arrow_back)),
          const SizedBox(width: 4),
          const Text('Administration Movi-k', style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        actions: const [Padding(padding: EdgeInsets.only(right: 16), child: DemoDataBadge())],
      ),
      body: isDesktop
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _tab,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: navItems.map((n) => NavigationRailDestination(icon: Icon(n.$1), label: Text(n.$2))).toList(),
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
                  onTap: (i) => setState(() => _tab = i),
                  items: navItems.map((n) => BottomNavigationBarItem(icon: Icon(n.$1), label: n.$2)).toList(),
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
      ('Chauffeurs qualifiés', '${DemoDataService.drivers.length}', Icons.local_shipping_outlined, AppColors.success),
      ('Mécaniciens qualifiés', '${DemoDataService.mechanics.length}', Icons.build_outlined, AppColors.success),
      ('Demandes actives', '4', Icons.timelapse, AppColors.warning),
      ('Réservations complétées', '20', Icons.check_circle_outline, AppColors.success),
      ('Litiges', '0', Icons.report_gmailerrorred_outlined, AppColors.error),
    ];
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vue d\'ensemble du marché', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
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
                .map((m) => Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(m.$3, color: m.$4),
                          const SizedBox(height: 10),
                          Text(m.$2, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: m.$4)),
                          Text(m.$1, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cibles de validation interne (60 jours)', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text('• 50 mécaniciens mobiles qualifiés', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                Text('• 30 chauffeurs de livraison qualifiés', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                Text('• 20 emplois complétés', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                SizedBox(height: 8),
                Text('Ces cibles sont des hypothèses internes, non des indicateurs publics.', style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminValidationsTab extends StatefulWidget {
  const _AdminValidationsTab();

  @override
  State<_AdminValidationsTab> createState() => _AdminValidationsTabState();
}

class _AdminValidationsTabState extends State<_AdminValidationsTab> {
  final Set<String> _approved = {};
  final Set<String> _rejected = {};

  @override
  Widget build(BuildContext context) {
    final demoQueue = DemoDataService.allProviders.take(2).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Validations de fournisseurs', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('File de démonstration — en production, cette liste proviendrait des inscriptions réelles en attente.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          const SizedBox(height: 20),
          ...demoQueue.map((p) {
            final isApproved = _approved.contains(p.id);
            final isRejected = _rejected.contains(p.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    CircleAvatar(backgroundImage: NetworkImage(p.profilePhotoUrl)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(p.type.name == 'driver' ? 'Chauffeur' : 'Mécanicien mobile', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (isApproved)
                    const Text('Approuvé', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700))
                  else if (isRejected)
                    const Text('Rejeté', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700))
                  else
                    Row(children: [
                      Expanded(child: OutlinedButton(onPressed: () => setState(() => _rejected.add(p.id)), child: const Text('Rejeter'))),
                      const SizedBox(width: 10),
                      Expanded(child: ElevatedButton(onPressed: () => setState(() => _approved.add(p.id)), child: const Text('Approuver'))),
                    ]),
                ],
              ),
            );
          }),
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
          const Text('Paramètres de la plateforme', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Monétisation future', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                const Text('Ces paramètres sont préparés pour une activation future. La commission est désactivée par défaut durant le MVP.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                const SizedBox(height: 14),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activer la commission'),
                  value: _commissionEnabled,
                  onChanged: (v) => setState(() => _commissionEnabled = v),
                  activeThumbColor: AppColors.primary,
                ),
                Text('Pourcentage de commission: ${_commissionPct.round()}%', style: const TextStyle(fontWeight: FontWeight.w600)),
                Slider(value: _commissionPct, min: 8, max: 12, divisions: 4, activeColor: AppColors.primary, onChanged: _commissionEnabled ? (v) => setState(() => _commissionPct = v) : null),
                const SizedBox(height: 10),
                Text('Frais de réservation client: ${_bookingFee.toStringAsFixed(2)}\$', style: const TextStyle(fontWeight: FontWeight.w600)),
                Slider(value: _bookingFee, min: 0, max: 10, divisions: 10, activeColor: AppColors.primary, onChanged: (v) => setState(() => _bookingFee = v)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18)),
            child: const Row(children: [
              Icon(Icons.info_outline, color: AppColors.info),
              SizedBox(width: 12),
              Expanded(child: Text('Ces paramètres sont sauvegardés localement pour cette démonstration et ne sont pas encore connectés à un moteur de facturation réel.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
            ]),
          ),
        ],
      ),
    );
  }
}
