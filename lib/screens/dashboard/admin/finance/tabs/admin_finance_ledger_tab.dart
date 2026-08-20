// ---------------------------------------------------------------------------
// AdminFinanceLedgerTab — Bloc L, section 5/8 "Ledger".
//
// Affichage APPEND-ONLY : aucune action d'édition/suppression sur une
// entrée existante. La seule action disponible est la création d'un
// AJUSTEMENT FINANCIER, qui passe par `adminCreateLedgerAdjustment()` ->
// Cloud Function `createLedgerEntry` et crée TOUJOURS une NOUVELLE entrée
// compensatoire (jamais une modification de l'historique).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../backend/backend_locator.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../finance/models/transaction_ledger.dart';
import '../../../../../finance/presentation/money_format.dart';
import '../../../../../models/enums.dart';
import '../../../../../providers/firebase_auth_provider.dart';
import '../../../../../providers/locale_provider.dart';
import '../finance_ui_helpers.dart';

const List<LedgerParty?> _kPartyFilters = [
  null,
  LedgerParty.customer,
  LedgerParty.driver,
  LedgerParty.platform,
];

class AdminFinanceLedgerTab extends StatefulWidget {
  const AdminFinanceLedgerTab({super.key});

  @override
  State<AdminFinanceLedgerTab> createState() => _AdminFinanceLedgerTabState();
}

class _AdminFinanceLedgerTabState extends State<AdminFinanceLedgerTab> {
  LedgerParty? _partyFilter;
  String _missionQuery = '';

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
                  t('admin_finance_tab_ledger'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (auth.isAdminOrAbove)
                FilledButton.icon(
                  onPressed: () => _openAdjustmentDialog(context, t),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajustement'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kPartyFilters.map((f) {
              final selected = f == _partyFilter;
              return ChoiceChip(
                label: Text(
                  f == null
                      ? t('admin_finance_filter_all')
                      : t(ledgerPartyKey(f)),
                ),
                selected: selected,
                onSelected: (_) => setState(() => _partyFilter = f),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 260,
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                labelText: t('admin_finance_filter_mission'),
                prefixIcon: const Icon(Icons.local_shipping_outlined, size: 18),
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _missionQuery = v.trim()),
            ),
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<LedgerEntry>>(
            stream: repo.watchLedger(limit: 100),
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
              var entries = snapshot.data ?? const <LedgerEntry>[];
              if (_partyFilter != null) {
                entries = entries
                    .where((e) => e.party == _partyFilter)
                    .toList();
              }
              if (_missionQuery.isNotEmpty) {
                entries = entries
                    .where(
                      (e) => (e.missionId ?? '').toLowerCase().contains(
                        _missionQuery.toLowerCase(),
                      ),
                    )
                    .toList();
              }
              if (entries.isEmpty) {
                return FinanceEmptyState(message: t('admin_finance_empty'));
              }
              final sorted = [...entries]
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              return Column(
                children: sorted
                    .map((e) => _LedgerRow(entry: e, t: t))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openAdjustmentDialog(
    BuildContext context,
    String Function(String) t,
  ) async {
    final amountController = TextEditingController();
    final missionController = TextEditingController();
    final reasonController = TextEditingController();
    LedgerEntryType type = LedgerEntryType.driverAdjustment;
    LedgerDirection direction = LedgerDirection.credit;
    LedgerParty party = LedgerParty.driver;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Ajustement financier'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: missionController,
                  decoration: InputDecoration(
                    labelText: t('admin_finance_filter_mission'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Montant (\$)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<LedgerEntryType>(
                  initialValue: type,
                  decoration: InputDecoration(
                    labelText: t('admin_ledger_col_type'),
                  ),
                  items: LedgerEntryType.values
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(t(ledgerTypeKey(v))),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<LedgerDirection>(
                  initialValue: direction,
                  decoration: const InputDecoration(labelText: 'Direction'),
                  items: LedgerDirection.values
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(t(ledgerDirectionKey(v))),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => direction = v ?? direction),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<LedgerParty>(
                  initialValue: party,
                  decoration: InputDecoration(
                    labelText: t('admin_ledger_col_party'),
                  ),
                  items: LedgerParty.values
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(t(ledgerPartyKey(v))),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => party = v ?? party),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Raison'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    final amount = double.tryParse(amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0 || reasonController.text.trim().isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Montant et raison requis.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    try {
      await BackendLocator.financeRepository.adminCreateLedgerAdjustment(
        missionId: missionController.text.trim().isEmpty
            ? null
            : missionController.text.trim(),
        type: type,
        amount: amount,
        direction: direction,
        party: party,
        sourceEvent: 'manual_admin_adjustment',
        reason: reasonController.text.trim(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Ajustement créé.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    }
  }
}

class _LedgerRow extends StatelessWidget {
  final LedgerEntry entry;
  final String Function(String) t;
  const _LedgerRow({required this.entry, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(ledgerTypeKey(entry.type)),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    MetaChip(
                      icon: Icons.event_outlined,
                      label: formatShortDate(entry.createdAt),
                    ),
                    if (entry.missionId != null)
                      MetaChip(
                        icon: Icons.local_shipping_outlined,
                        label: entry.missionId!,
                      ),
                    MetaChip(
                      icon: Icons.person_outline,
                      label: t(ledgerPartyKey(entry.party)),
                    ),
                    MetaChip(
                      icon: Icons.dns_outlined,
                      label: entry.sourceEvent,
                    ),
                    if (entry.referenceId != null)
                      MetaChip(icon: Icons.link, label: entry.referenceId!),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.direction == LedgerDirection.credit ? '+' : '-'}${formatMajorAmount(entry.amount)}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: ledgerDirectionColor(entry.direction),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                entry.currency,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
