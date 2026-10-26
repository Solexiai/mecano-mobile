// Centre de commande (owner mockup validated 2026-10-26): every setting
// that decides what the customer sees and pays, one question per tab.
//   0 Accueil · 1 Quoi ? (types d'objets) · 2 Combien ? (prix)
//   3 Où et quand ? · 4 Qui reçoit quoi ? · 5 Conditions spéciales
// Same rule everywhere: change (a draft), try the price, publish.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_colors.dart';
import '../admin_item_types_screen.dart';
import '../finance/tabs/admin_finance_pricing_tab.dart';
import 'conditions_panel.dart';
import 'price_simulator.dart';
import 'service_settings_panel.dart';
import 'share_panel.dart';

/// Tab ids used in the URL: /admin/centre-commande?onglet=quoi
const commandCenterTabs = [
  'accueil',
  'quoi',
  'combien',
  'service',
  'partage',
  'conditions',
];

class AdminCommandCenterScreen extends StatefulWidget {
  const AdminCommandCenterScreen({
    super.key,
    this.initialTab = 'accueil',
    this.itemTypesApi,
    this.pricingTab,
    this.serviceApi,
    this.conditionsApi,
    this.loadActive,
    this.preview,
  });
  final String initialTab;
  final ItemTypesApi? itemTypesApi;

  /// Test seam: the pricing tab reads Firestore.
  final Widget? pricingTab;
  final ServiceSettingsApi? serviceApi;
  final ConditionsApi? conditionsApi;

  /// Test seams for the simulator (active grid, server preview).
  final ActiveVersionLoader? loadActive;
  final PricePreviewer? preview;

  @override
  State<AdminCommandCenterScreen> createState() =>
      _AdminCommandCenterScreenState();
}

class _AdminCommandCenterScreenState extends State<AdminCommandCenterScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: commandCenterTabs.length,
    vsync: this,
    initialIndex: commandCenterTabs.contains(widget.initialTab)
        ? commandCenterTabs.indexOf(widget.initialTab)
        : 0,
  );

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _open(String id) => _tabs.animateTo(commandCenterTabs.indexOf(id));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Centre de commande'),
      leading: IconButton(
        tooltip: 'Retour à l’administration',
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (context.canPop()) return context.pop();
          final segments = GoRouterState.of(context).uri.pathSegments;
          context.go('/${segments.isEmpty ? 'fr' : segments.first}/admin');
        },
      ),
      bottom: TabBar(
        controller: _tabs,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(key: ValueKey('cc-tab-accueil'), text: 'Accueil'),
          Tab(key: ValueKey('cc-tab-quoi'), text: '1 · Quoi ?'),
          Tab(key: ValueKey('cc-tab-combien'), text: '2 · Combien ?'),
          Tab(key: ValueKey('cc-tab-service'), text: '3 · Où et quand ?'),
          Tab(key: ValueKey('cc-tab-partage'), text: '4 · Qui reçoit quoi ?'),
          Tab(key: ValueKey('cc-tab-conditions'), text: '5 · Conditions spéciales'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabs,
      children: [
        _Home(onOpen: _open, loadActive: widget.loadActive, preview: widget.preview),
        AdminItemTypesPanel(api: widget.itemTypesApi),
        widget.pricingTab ?? const AdminFinancePricingTab(),
        ServiceSettingsPanel(api: widget.serviceApi),
        SharePanel(
          onEditPrices: () => _open('combien'),
          loadActive: widget.loadActive,
          preview: widget.preview,
        ),
        ConditionsPanel(api: widget.conditionsApi),
      ],
    ),
  );
}

class _Home extends StatelessWidget {
  const _Home({required this.onOpen, this.loadActive, this.preview});
  final void Function(String id) onOpen;
  final ActiveVersionLoader? loadActive;
  final PricePreviewer? preview;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1000
        ? 3
        : width >= 640
        ? 2
        : 1;
    Widget tile(
      String id,
      String step,
      String title,
      String text, {
      bool ready = true,
    }) => Card(
      key: ValueKey('cc-tile-$id'),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onOpen(id),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8A4307),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(text, style: const TextStyle(color: AppColors.textSecondary)),
              if (!ready) ...[
                const SizedBox(height: 8),
                const Text(
                  'En préparation',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    final tiles = [
      tile('quoi', '1 · QUOI ?', 'Types d’objets',
          'Les objets offerts et les véhicules qui peuvent les prendre.'),
      tile('combien', '2 · COMBIEN ?', 'Prix',
          'Prix de base et suppléments. Essayer, comparer, publier une version.'),
      tile('service', '3 · OÙ ET QUAND ?', 'Service',
          'Zone desservie, heures de réservation, délai minimum.'),
      tile('partage', '4 · QUI REÇOIT QUOI ?', 'Partage',
          'Commission Movi-K, part du chauffeur, frais de service.'),
      tile('conditions', '5 · CONDITIONS SPÉCIALES', 'Météo et événements',
          'Supplément tempête, pause du service.'),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Tout ce qui décide ce que le client voit et paie, au même endroit. Une question par onglet.',
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        PriceSimulator(loadActive: loadActive, preview: preview),
        const SizedBox(height: 16),
        // Wrap, not a fixed-ratio grid: tiles grow with their text (phone,
        // large text) instead of overflowing.
        LayoutBuilder(
          builder: (context, box) {
            final w = (box.maxWidth - 14 * (columns - 1)) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [for (final t in tiles) SizedBox(width: w, child: t)],
            );
          },
        ),
        const SizedBox(height: 16),
        Container(
          key: const ValueKey('cc-rule'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF4E8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF3C99B)),
          ),
          child: const Text(
            'La règle, partout pareille : 1. modifier (c’est un brouillon), 2. essayer le prix, 3. publier. Retour arrière en un clic. Une réservation déjà faite garde toujours son prix.',
            style: TextStyle(color: Color(0xFF5C2E05)),
          ),
        ),
      ],
    );
  }
}
