// ---------------------------------------------------------------------------
// AdminFinancePayoutPolicyTab — Bloc L, section 8/8 "Payout Policy".
//
// Trois catégories RÉELLEMENT supportées côté serveur (voir
// `PayoutPolicyConfiguration` — note d'en-tête) : default / new_driver /
// risky_driver (chauffeur suspendu ou à risque). Modification uniquement
// via `adminUpdatePayoutPolicyConfiguration` -> Cloud Function
// `updatePayoutPolicyConfiguration`. Politique protégée : réservée
// super_admin (`PlatformRoleX.canModifyProtectedFinancialPolicy`).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../backend/backend_locator.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../finance/models/payout_policy_configuration.dart';
import '../../../../../providers/firebase_auth_provider.dart';
import '../../../../../providers/locale_provider.dart';
import '../finance_ui_helpers.dart';

class AdminFinancePayoutPolicyTab extends StatefulWidget {
  const AdminFinancePayoutPolicyTab({super.key});

  @override
  State<AdminFinancePayoutPolicyTab> createState() =>
      _AdminFinancePayoutPolicyTabState();
}

class _AdminFinancePayoutPolicyTabState
    extends State<AdminFinancePayoutPolicyTab> {
  bool _editing = false;
  bool _saving = false;
  late TextEditingController _defaultController;
  late TextEditingController _newDriverController;
  late TextEditingController _riskyController;

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
          Text(
            t('admin_finance_tab_payout_policy'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          StreamBuilder<PayoutPolicyConfiguration>(
            stream: repo.watchPayoutPolicy(),
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
              final config =
                  snapshot.data ?? PayoutPolicyConfiguration.bootstrapDefault();

              if (!_editing) {
                _defaultController = TextEditingController(
                  text: '${config.defaultHoldPeriodHours}',
                );
                _newDriverController = TextEditingController(
                  text: '${config.newDriverHoldPeriodHours}',
                );
                _riskyController = TextEditingController(
                  text: '${config.riskyDriverHoldPeriodHours}',
                );
              }

              final canEdit = auth.isSuperAdmin;

              return Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!canEdit)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          t('admin_finance_action_admin_only'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                    _HoldField(
                      label: t('admin_payout_policy_default'),
                      controller: _defaultController,
                      enabled: canEdit && _editing,
                    ),
                    const SizedBox(height: 14),
                    _HoldField(
                      label: t('admin_payout_policy_new_driver'),
                      controller: _newDriverController,
                      enabled: canEdit && _editing,
                    ),
                    const SizedBox(height: 14),
                    _HoldField(
                      label: t('admin_payout_policy_risky_driver'),
                      controller: _riskyController,
                      enabled: canEdit && _editing,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${t('admin_payout_policy_updated_at')}: ${formatShortDate(config.updatedAt)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (canEdit)
                      Row(
                        children: [
                          if (!_editing)
                            OutlinedButton(
                              onPressed: () => setState(() => _editing = true),
                              child: const Text('Modifier'),
                            )
                          else ...[
                            FilledButton(
                              onPressed: _saving
                                  ? null
                                  : () => _save(context, t),
                              child: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Text(t('admin_payout_policy_save')),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: () => setState(() => _editing = false),
                              child: const Text('Annuler'),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, String Function(String) t) async {
    final defaultH = int.tryParse(_defaultController.text.trim());
    final newDriverH = int.tryParse(_newDriverController.text.trim());
    final riskyH = int.tryParse(_riskyController.text.trim());
    if (defaultH == null || newDriverH == null || riskyH == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Valeurs invalides.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await BackendLocator.financeRepository
          .adminUpdatePayoutPolicyConfiguration(
            defaultHoldPeriodHours: defaultH,
            newDriverHoldPeriodHours: newDriverH,
            riskyDriverHoldPeriodHours: riskyH,
          );
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t('admin_payout_policy_save_success'))),
        );
        setState(() => _editing = false);
      }
    } catch (e) {
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _HoldField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  const _HoldField({
    required this.label,
    required this.controller,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: '$label (heures)',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
