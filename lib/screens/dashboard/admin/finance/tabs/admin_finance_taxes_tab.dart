// ---------------------------------------------------------------------------
// AdminFinanceTaxesTab — Bloc L, section 7/8 "Taxes".
//
// AUCUNE valeur fiscale réelle n'est présumée par l'UI (directive Bloc L
// point 17) : le formulaire de création exige la saisie explicite de
// TOUTES les valeurs (taux, composantes taxables, etc.) par l'admin.
// Modification uniquement via `adminUpdateTaxConfiguration` -> Cloud
// Function `updateTaxConfiguration` (crée toujours une NOUVELLE version).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../backend/backend_locator.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../finance/models/tax_configuration.dart';
import '../../../../../models/enums.dart';
import '../../../../../providers/firebase_auth_provider.dart';
import '../../../../../providers/locale_provider.dart';
import '../finance_ui_helpers.dart';

class AdminFinanceTaxesTab extends StatefulWidget {
  const AdminFinanceTaxesTab({super.key});

  @override
  State<AdminFinanceTaxesTab> createState() => _AdminFinanceTaxesTabState();
}

class _AdminFinanceTaxesTabState extends State<AdminFinanceTaxesTab> {
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
                  t('admin_finance_tab_taxes'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (auth.isAdminOrAbove)
                FilledButton.icon(
                  onPressed: () => _openNewConfigDialog(context, t),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(t('admin_taxes_new_config')),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t('admin_taxes_new_config_notice'),
            style: const TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<TaxConfiguration>>(
            stream: repo.watchTaxConfigurations(),
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
              final configs = snapshot.data ?? const <TaxConfiguration>[];
              if (configs.isEmpty) {
                return FinanceEmptyState(message: t('admin_finance_empty'));
              }
              final sorted = [...configs]
                ..sort(
                  (a, b) => '${b.jurisdiction}_${b.taxCode}_${b.version}'
                      .compareTo('${a.jurisdiction}_${a.taxCode}_${a.version}'),
                );
              return Column(
                children: sorted
                    .map((c) => _TaxConfigCard(config: c, t: t))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openNewConfigDialog(
    BuildContext context,
    String Function(String) t,
  ) async {
    final jurisdictionController = TextEditingController();
    final taxCodeController = TextEditingController();
    final displayNameController = TextEditingController();
    final rateController = TextEditingController();
    final componentsController = TextEditingController();
    TaxType taxType = TaxType.otherTax;
    bool enabled = true;
    String owner = 'platform';
    DateTime effectiveFrom = DateTime.now();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(t('admin_taxes_new_config')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: jurisdictionController,
                  decoration: InputDecoration(
                    labelText: t('admin_taxes_col_jurisdiction'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: taxCodeController,
                  decoration: InputDecoration(
                    labelText: t('admin_taxes_col_tax_code'),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: displayNameController,
                  decoration: const InputDecoration(labelText: 'Nom affiché'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<TaxType>(
                  initialValue: taxType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: TaxType.values
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(t(taxTypeKey(v))),
                        ),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => taxType = v ?? taxType),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: rateController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '${t('admin_taxes_col_rate')} (ex: 0.05 = 5%)',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: componentsController,
                  decoration: InputDecoration(
                    labelText:
                        '${t('admin_taxes_col_components')} (séparés par virgule)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: owner,
                  decoration: const InputDecoration(
                    labelText: 'Responsable de la taxe',
                  ),
                  items: ['platform', 'driver', 'not_applicable']
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(t(taxOwnerKey(v))),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => owner = v ?? owner),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t('admin_taxes_col_enabled')),
                  value: enabled,
                  onChanged: (v) => setDialogState(() => enabled = v),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${t('admin_taxes_col_effective_from')}: ${formatShortDate(effectiveFrom)}',
                  ),
                  trailing: const Icon(Icons.calendar_today_outlined, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: effectiveFrom,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setDialogState(() => effectiveFrom = picked);
                    }
                  },
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
              child: Text(t('admin_taxes_save')),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    final rate = double.tryParse(rateController.text.replaceAll(',', '.'));
    if (jurisdictionController.text.trim().isEmpty ||
        taxCodeController.text.trim().isEmpty ||
        rate == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Juridiction, code et taux requis.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    try {
      await BackendLocator.financeRepository.adminUpdateTaxConfiguration(
        jurisdiction: jurisdictionController.text.trim(),
        taxCode: taxCodeController.text.trim(),
        taxType: taxType,
        displayName: displayNameController.text.trim(),
        rate: rate,
        taxableComponents: componentsController.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        effectiveFrom: effectiveFrom,
        enabled: enabled,
        taxRegistrationOwner: owner,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t('admin_taxes_save_success'))));
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

class _TaxConfigCard extends StatelessWidget {
  final TaxConfiguration config;
  final String Function(String) t;
  const _TaxConfigCard({required this.config, required this.t});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                  '${config.jurisdiction} — ${config.displayName.isNotEmpty ? config.displayName : config.taxCode}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              StatusBadge(
                label: config.enabled ? t('admin_taxes_col_enabled') : '—',
                color: config.enabled
                    ? AppColors.success
                    : AppColors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              MetaChip(
                icon: Icons.category_outlined,
                label: t(taxTypeKey(config.taxType)),
              ),
              MetaChip(
                icon: Icons.percent_outlined,
                label:
                    '${t('admin_taxes_col_rate')}: ${(config.rate * 100).toStringAsFixed(2)}%',
              ),
              MetaChip(
                icon: Icons.tag,
                label: '${t('admin_taxes_col_version')}: ${config.version}',
              ),
              MetaChip(
                icon: Icons.event_outlined,
                label:
                    '${t('admin_taxes_col_effective_from')}: ${formatShortDate(config.effectiveFrom)}',
              ),
              if (config.effectiveUntil != null)
                MetaChip(
                  icon: Icons.event_busy_outlined,
                  label:
                      '${t('admin_taxes_col_effective_until')}: ${formatShortDate(config.effectiveUntil)}',
                ),
              MetaChip(
                icon: Icons.account_balance_outlined,
                label: t(taxOwnerKey(config.taxRegistrationOwner)),
              ),
            ],
          ),
          if (config.taxableComponents.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '${t('admin_taxes_col_components')}: ${config.taxableComponents.join(', ')}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
