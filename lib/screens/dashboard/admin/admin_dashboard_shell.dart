import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/app_colors.dart';
import '../../../providers/firebase_auth_provider.dart';
import '../../../providers/locale_provider.dart';

class AdminDashboardShell extends StatefulWidget {
  const AdminDashboardShell({super.key});

  @override
  State<AdminDashboardShell> createState() => _AdminDashboardShellState();
}

class _AdminDashboardShellState extends State<AdminDashboardShell> {
  late Future<_AdminMetrics> _metrics;

  @override
  void initState() {
    super.initState();
    _metrics = _loadMetrics();
  }

  void _refresh() => setState(() => _metrics = _loadMetrics());

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    final auth = context.watch<FirebaseAuthProvider>();
    final isFrench = locale == 'fr';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Administration Movi-K',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: isFrench ? 'Actualiser' : 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: isFrench ? 'Déconnexion' : 'Sign out',
            onPressed: () async {
              await auth.signOut();
              if (context.mounted) context.go('/$locale');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: FutureBuilder<_AdminMetrics>(
          future: _metrics,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return ListView(
                children: [_ErrorPanel(onRetry: _refresh, isFrench: isFrench)],
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return _DashboardBody(
              metrics: snapshot.data!,
              locale: locale,
              isFrench: isFrench,
            );
          },
        ),
      ),
    );
  }

  Future<_AdminMetrics> _loadMetrics() async {
    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      db.collection('users').get(),
      db.collection('driver_profiles').get(),
      db.collection('delivery_requests').get(),
      db.collection('payments').get(),
      db.collection('disputes').get(),
    ]);
    final users = results[0].docs;
    final drivers = results[1].docs;
    final missions = results[2].docs;
    final payments = results[3].docs;
    final disputes = results[4].docs;

    const activeStatuses = {
      'searching_driver',
      'offered',
      'assigned',
      'driver_to_pickup',
      'arrived_at_pickup',
      'picked_up',
      'in_transit',
      'arrived_at_dropoff',
    };
    return _AdminMetrics(
      customers: users
          .where((d) => _roles(d.data()).contains('customer'))
          .length,
      drivers: drivers.length,
      pendingDrivers: drivers.where((d) {
        final status = d.data()['status'];
        return status == 'pending_review' || status == 'documents_required';
      }).length,
      activeMissions: missions
          .where((d) => activeStatuses.contains(d.data()['status']))
          .length,
      completedMissions: missions.where((d) {
        final status = d.data()['status'];
        return status == 'completed' || status == 'delivered';
      }).length,
      payments: payments.length,
      openDisputes: disputes
          .where((d) => d.data()['status'] != 'resolved')
          .length,
    );
  }

  static List<String> _roles(Map<String, dynamic> data) {
    final raw = data['roles'];
    if (raw is List) return raw.whereType<String>().toList();
    final role = data['role'];
    return role is String ? [role] : const ['customer'];
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.metrics,
    required this.locale,
    required this.isFrench,
  });

  final _AdminMetrics metrics;
  final String locale;
  final bool isFrench;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1100
        ? 4
        : width >= 650
        ? 2
        : 1;
    final padding = width < 600 ? 16.0 : 28.0;
    final cards = [
      _Metric(
        'Clients',
        metrics.customers,
        Icons.people_outline,
        AppColors.primary,
      ),
      _Metric(
        isFrench ? 'Chauffeurs' : 'Drivers',
        metrics.drivers,
        Icons.local_shipping_outlined,
        AppColors.success,
      ),
      _Metric(
        isFrench ? 'Dossiers à traiter' : 'Applications to review',
        metrics.pendingDrivers,
        Icons.fact_check_outlined,
        AppColors.warning,
      ),
      _Metric(
        isFrench ? 'Missions actives' : 'Active jobs',
        metrics.activeMissions,
        Icons.route_outlined,
        AppColors.info,
      ),
      _Metric(
        isFrench ? 'Missions terminées' : 'Completed jobs',
        metrics.completedMissions,
        Icons.check_circle_outline,
        AppColors.success,
      ),
      _Metric(
        isFrench ? 'Paiements' : 'Payments',
        metrics.payments,
        Icons.payments_outlined,
        AppColors.primary,
      ),
      _Metric(
        isFrench ? 'Litiges ouverts' : 'Open disputes',
        metrics.openDisputes,
        Icons.report_problem_outlined,
        AppColors.error,
      ),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(padding),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isFrench ? 'Vue d’ensemble' : 'Overview',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isFrench
                    ? 'Les données opérationnelles réelles de Movi-K, réunies au même endroit.'
                    : 'Movi-K real operational data, in one place.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: cards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: columns == 1 ? 2.5 : 1.7,
                ),
                itemBuilder: (_, index) => _MetricCard(metric: cards[index]),
              ),
              const SizedBox(height: 30),
              Text(
                isFrench ? 'Gestion' : 'Management',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              _ActionCard(
                icon: Icons.people_alt_outlined,
                title: isFrench ? 'Utilisateurs' : 'Users',
                subtitle: isFrench
                    ? 'Consulter et distinguer clients, chauffeurs et administrateurs.'
                    : 'Review customers, drivers and administrators.',
                onTap: () => context.go('/$locale/admin/utilisateurs'),
              ),
              _ActionCard(
                icon: Icons.local_shipping_outlined,
                title: isFrench ? 'Dossiers chauffeurs' : 'Driver applications',
                subtitle: isFrench
                    ? 'Approuver, demander des documents, suspendre ou supprimer un dossier.'
                    : 'Approve, request documents, suspend or delete an application.',
                badge: metrics.pendingDrivers,
                onTap: () => context.go('/$locale/admin/chauffeurs'),
              ),
              _ActionCard(
                icon: Icons.account_balance_outlined,
                title: 'Finances',
                subtitle: isFrench
                    ? 'Paiements, remboursements, versements, litiges, taxes et réconciliation.'
                    : 'Payments, refunds, payouts, disputes, taxes and reconciliation.',
                badge: metrics.openDisputes,
                onTap: () => context.go('/$locale/admin/paiements'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: metric.color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(metric.icon, color: metric.color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${metric.value}',
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                metric.label,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      leading: Icon(icon, color: AppColors.primary, size: 28),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$badge',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: onTap,
    ),
  );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.onRetry, required this.isFrench});
  final VoidCallback onRetry;
  final bool isFrench;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(
      children: [
        const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.error),
        const SizedBox(height: 12),
        Text(
          isFrench
              ? 'Impossible de charger le tableau de bord.'
              : 'Unable to load the dashboard.',
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: onRetry,
          child: Text(isFrench ? 'Réessayer' : 'Retry'),
        ),
      ],
    ),
  );
}

class _Metric {
  const _Metric(this.label, this.value, this.icon, this.color);
  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _AdminMetrics {
  const _AdminMetrics({
    required this.customers,
    required this.drivers,
    required this.pendingDrivers,
    required this.activeMissions,
    required this.completedMissions,
    required this.payments,
    required this.openDisputes,
  });
  final int customers;
  final int drivers;
  final int pendingDrivers;
  final int activeMissions;
  final int completedMissions;
  final int payments;
  final int openDisputes;
}
