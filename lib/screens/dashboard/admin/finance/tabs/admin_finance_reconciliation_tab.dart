// ---------------------------------------------------------------------------
// AdminFinanceReconciliationTab — Bloc L, section 6/8 "Reconciliation".
//
// Résumé en haut (compteurs open/critical/warning/resolved), puis liste des
// rapports avec leurs anomalies. Actions ("lancer une réconciliation",
// "résoudre une anomalie") passent EXCLUSIVEMENT par
// `adminRunReconciliationNow`/`adminResolveReconciliationAnomaly` -> Cloud
// Functions. AUCUNE correction financière silencieuse n'est jamais faite
// depuis l'UI (voir directive : "ne jamais auto-corriger silencieusement").
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../backend/backend_locator.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../finance/models/reconciliation_report.dart';
import '../../../../../finance/presentation/money_format.dart';
import '../../../../../models/enums.dart';
import '../../../../../providers/firebase_auth_provider.dart';
import '../../../../../providers/locale_provider.dart';
import '../finance_ui_helpers.dart';

class AdminFinanceReconciliationTab extends StatefulWidget {
  const AdminFinanceReconciliationTab({super.key});

  @override
  State<AdminFinanceReconciliationTab> createState() =>
      _AdminFinanceReconciliationTabState();
}

class _AdminFinanceReconciliationTabState
    extends State<AdminFinanceReconciliationTab> {
  bool _runningNow = false;

  Future<void> _runReconciliation(
    BuildContext context,
    String Function(String) t,
  ) async {
    setState(() => _runningNow = true);
    try {
      final now = DateTime.now();
      final periodStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 1));
      final periodEnd = DateTime(now.year, now.month, now.day);
      await BackendLocator.financeRepository.adminRunReconciliationNow(
        periodStart: periodStart,
        periodEnd: periodEnd,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Réconciliation lancée.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _runningNow = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final auth = context.watch<FirebaseAuthProvider>();
    final repo = BackendLocator.financeRepository;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('admin_finance_tab_reconciliation'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (auth.isAdminOrAbove)
                FilledButton.icon(
                  onPressed: _runningNow
                      ? null
                      : () => _runReconciliation(context, t),
                  icon: _runningNow
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Lancer'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<ReconciliationReport>>(
            stream: repo.watchReconciliationReports(limit: 20),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return FinanceLoadingState(message: t('admin_finance_loading'));
              }
              if (snapshot.hasError) {
                return FinanceErrorState(
                  message: t('admin_finance_error'),
                  retryLabel: t('admin_finance_retry'),
                  onRetry: () => setState(() {}),
                );
              }
              final reports = snapshot.data ?? const <ReconciliationReport>[];
              if (reports.isEmpty) {
                return FinanceEmptyState(message: t('admin_finance_empty'));
              }
              final sorted = [...reports]
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

              final totalOpen = sorted.fold<int>(
                0,
                (s, r) => s + r.openAnomaliesCount,
              );
              final totalCritical = sorted.fold<int>(
                0,
                (s, r) => s + r.criticalAnomaliesCount,
              );
              final totalWarning = sorted.fold<int>(
                0,
                (s, r) => s + r.warningAnomaliesCount,
              );
              final totalResolved = sorted.fold<int>(
                0,
                (s, r) => s + r.resolvedAnomaliesCount,
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _SummaryCard(
                        label: 'Ouvertes',
                        value: totalOpen,
                        color: AppColors.error,
                      ),
                      _SummaryCard(
                        label: 'Critiques',
                        value: totalCritical,
                        color: AppColors.error,
                      ),
                      _SummaryCard(
                        label: 'Avertissements',
                        value: totalWarning,
                        color: AppColors.warning,
                      ),
                      _SummaryCard(
                        label: 'Résolues',
                        value: totalResolved,
                        color: AppColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ...sorted.map(
                    (r) => _ReportCard(
                      report: r,
                      t: t,
                      canResolve: auth.isAdminOrAbove,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReconciliationReport report;
  final String Function(String) t;
  final bool canResolve;
  const _ReportCard({
    required this.report,
    required this.t,
    required this.canResolve,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${formatShortDate(report.periodStart)} → ${formatShortDate(report.periodEnd)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                formatMinorAmount(report.reconciliationDifferenceMinor),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (report.anomalies.isEmpty)
            Text('—', style: const TextStyle(color: AppColors.textSecondary))
          else
            Column(
              children: report.anomalies
                  .map(
                    (a) => _AnomalyRow(
                      reportId: report.reportId,
                      anomaly: a,
                      t: t,
                      canResolve: canResolve,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _AnomalyRow extends StatefulWidget {
  final String reportId;
  final ReconciliationAnomaly anomaly;
  final String Function(String) t;
  final bool canResolve;
  const _AnomalyRow({
    required this.reportId,
    required this.anomaly,
    required this.t,
    required this.canResolve,
  });

  @override
  State<_AnomalyRow> createState() => _AnomalyRowState();
}

class _AnomalyRowState extends State<_AnomalyRow> {
  bool _busy = false;

  Future<void> _resolve() async {
    final notesController = TextEditingController();
    final confirmed = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Résoudre l\'anomalie'),
        content: TextField(
          controller: notesController,
          decoration: const InputDecoration(labelText: 'Notes de résolution'),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, notesController.text.trim()),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed == null || confirmed.isEmpty) return;
    setState(() => _busy = true);
    try {
      await BackendLocator.financeRepository.adminResolveReconciliationAnomaly(
        reportId: widget.reportId,
        anomalyIndex: widget.anomaly.index,
        newStatus: ReconciliationAnomalyStatus.resolved,
        resolutionNotes: confirmed,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Anomalie résolue.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.anomaly;
    final t = widget.t;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    StatusBadge(
                      label: t(anomalySeverityKey(a.severity)),
                      color: anomalySeverityColor(a.severity),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(
                      label: t(anomalyStatusKey(a.status)),
                      color: anomalyStatusColor(a.status),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(a.description, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (a.missionId != null)
                      MetaChip(
                        icon: Icons.local_shipping_outlined,
                        label: a.missionId!,
                      ),
                    if (a.paymentId != null)
                      MetaChip(
                        icon: Icons.payment_outlined,
                        label: a.paymentId!,
                      ),
                    MetaChip(
                      icon: Icons.event_outlined,
                      label: formatShortDate(a.detectedAt),
                    ),
                    if (a.expectedAmountMinor != null)
                      MetaChip(
                        icon: Icons.trending_up,
                        label:
                            '${t('admin_reconciliation_col_expected')}: ${formatMinorAmount(a.expectedAmountMinor!)}',
                      ),
                    if (a.actualAmountMinor != null)
                      MetaChip(
                        icon: Icons.trending_down,
                        label:
                            '${t('admin_reconciliation_col_actual')}: ${formatMinorAmount(a.actualAmountMinor!)}',
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.canResolve && !a.isResolved)
            _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: _resolve,
                    child: const Text('Résoudre'),
                  ),
        ],
      ),
    );
  }
}
