// ---------------------------------------------------------------------------
// AdminFinanceShell — Bloc L, portail admin/super_admin `/admin/paiements`.
//
// Regroupe les 8 sections de l'infrastructure financière Movi-K :
// Payments, Refunds, Payouts, Disputes, Ledger, Reconciliation, Taxes,
// Payout Policy. Navigation adaptée : desktop = NavigationRail interne,
// mobile = TabBar scrollable (évite tout overflow sur 8 entrées).
//
// Toutes les données proviennent de `FinanceRepository` (Firestore réel via
// `BackendLocator.financeRepository`) — aucune donnée simulée.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_colors.dart';
import '../../../../providers/locale_provider.dart';
import 'tabs/admin_finance_payments_tab.dart';
import 'tabs/admin_finance_refunds_tab.dart';
import 'tabs/admin_finance_payouts_tab.dart';
import 'tabs/admin_finance_disputes_tab.dart';
import 'tabs/admin_finance_ledger_tab.dart';
import 'tabs/admin_finance_reconciliation_tab.dart';
import 'tabs/admin_finance_taxes_tab.dart';
import 'tabs/admin_finance_payout_policy_tab.dart';

class _FinanceSection {
  final IconData icon;
  final String titleKey;
  final Widget Function() builder;
  const _FinanceSection({
    required this.icon,
    required this.titleKey,
    required this.builder,
  });
}

final List<_FinanceSection> _kSections = [
  _FinanceSection(
    icon: Icons.payment_outlined,
    titleKey: 'admin_finance_tab_payments',
    builder: () => const AdminFinancePaymentsTab(),
  ),
  _FinanceSection(
    icon: Icons.replay_outlined,
    titleKey: 'admin_finance_tab_refunds',
    builder: () => const AdminFinanceRefundsTab(),
  ),
  _FinanceSection(
    icon: Icons.account_balance_wallet_outlined,
    titleKey: 'admin_finance_tab_payouts',
    builder: () => const AdminFinancePayoutsTab(),
  ),
  _FinanceSection(
    icon: Icons.gavel_outlined,
    titleKey: 'admin_finance_tab_disputes',
    builder: () => const AdminFinanceDisputesTab(),
  ),
  _FinanceSection(
    icon: Icons.receipt_long_outlined,
    titleKey: 'admin_finance_tab_ledger',
    builder: () => const AdminFinanceLedgerTab(),
  ),
  _FinanceSection(
    icon: Icons.fact_check_outlined,
    titleKey: 'admin_finance_tab_reconciliation',
    builder: () => const AdminFinanceReconciliationTab(),
  ),
  _FinanceSection(
    icon: Icons.percent_outlined,
    titleKey: 'admin_finance_tab_taxes',
    builder: () => const AdminFinanceTaxesTab(),
  ),
  _FinanceSection(
    icon: Icons.schedule_outlined,
    titleKey: 'admin_finance_tab_payout_policy',
    builder: () => const AdminFinancePayoutPolicyTab(),
  ),
];

class AdminFinanceShell extends StatefulWidget {
  const AdminFinanceShell({super.key});

  @override
  State<AdminFinanceShell> createState() => _AdminFinanceShellState();
}

class _AdminFinanceShellState extends State<AdminFinanceShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  int _railIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _kSections.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          t('admin_finance_title'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        bottom: isDesktop
            ? null
            : TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: _kSections
                    .map(
                      (s) => Tab(
                        icon: Icon(s.icon, size: 20),
                        text: t(s.titleKey),
                      ),
                    )
                    .toList(),
              ),
      ),
      body: isDesktop
          ? Row(
              children: [
                NavigationRail(
                  selectedIndex: _railIndex,
                  onDestinationSelected: (i) => setState(() => _railIndex = i),
                  labelType: NavigationRailLabelType.all,
                  destinations: _kSections
                      .map(
                        (s) => NavigationRailDestination(
                          icon: Icon(s.icon),
                          label: Text(
                            t(s.titleKey),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Container(
                    color: AppColors.background,
                    child: _kSections[_railIndex].builder(),
                  ),
                ),
              ],
            )
          : TabBarView(
              controller: _tabController,
              children: _kSections
                  .map(
                    (s) => Container(
                      color: AppColors.background,
                      child: s.builder(),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
