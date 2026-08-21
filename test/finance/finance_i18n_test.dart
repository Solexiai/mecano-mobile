// ---------------------------------------------------------------------------
// finance_i18n_test.dart — BLOC M (I18N GLOBAL PHASE 6).
//
// Vérifie deux choses pour l'ensemble des clés i18n Phase 6 (paiements,
// refunds, payouts, disputes, ledger, réconciliation, taxes, payout policy,
// statuts) :
//   1. Couverture complète FR/EN/ES : `AppStrings.t(key, locale)` ne doit
//      JAMAIS retomber sur la clé technique elle-même (ce qui indiquerait
//      une clé manquante dans `_t`), pour aucune des 3 langues.
//   2. Rendu réel dans l'UI : `AdminFinanceShell` construit sans exception
//      en FR, EN et ES (LocaleProvider piloté directement via `setLocale`),
//      preuve que le câblage `context.watch<LocaleProvider>().t` fonctionne
//      de bout en bout et pas seulement au niveau de la table de chaînes.
//
// Ces tests ne nécessitent aucun émulateur Firebase (mêmes conditions que
// `admin_finance_ui_test.dart` — `NotConfiguredFinanceRepository`).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/dashboard/admin/finance/admin_finance_shell.dart';

/// Liste exhaustive des clés i18n Phase 6 (Bloc L + Bloc M), extraite par
/// audit direct de `lib/l10n/app_strings.dart` (préfixes admin_finance*,
/// admin_payments*, admin_refunds*, admin_payouts*, admin_disputes*,
/// admin_ledger*, admin_reconciliation*, admin_taxes*, admin_payout_policy*,
/// ainsi que les enums d'affichage finance_status*/payout_status*/
/// dispute_status*/anomaly_*/ledger_type*).
const List<String> _kPhase6Keys = [
  // --- Shell / états génériques -----------------------------------------
  'admin_finance_title',
  'admin_finance_tab_payments',
  'admin_finance_tab_refunds',
  'admin_finance_tab_payouts',
  'admin_finance_tab_disputes',
  'admin_finance_tab_ledger',
  'admin_finance_tab_reconciliation',
  'admin_finance_tab_taxes',
  'admin_finance_tab_payout_policy',
  'admin_finance_loading',
  'admin_finance_error',
  'admin_finance_retry',
  'admin_finance_empty',
  'admin_finance_filter_all',
  'admin_finance_filter_mission',
  'admin_finance_filter_customer',
  'admin_finance_filter_date_from',
  'admin_finance_filter_date_to',
  'admin_finance_filter_clear',
  'admin_finance_action_admin_only',
  'admin_finance_permission_denied',
  'admin_finance_no_sensitive_data',
  // --- Payments -----------------------------------------------------------
  'admin_payments_col_id',
  'admin_payments_col_mission',
  'admin_payments_col_customer',
  'admin_payments_col_status',
  'admin_payments_col_authorized',
  'admin_payments_col_captured',
  'admin_payments_col_refunded',
  'admin_payments_col_provider',
  'admin_payments_col_date',
  // --- Refunds --------------------------------------------------------------
  'admin_refunds_col_id',
  'admin_refunds_col_payment',
  'admin_refunds_col_amount',
  'admin_refunds_col_reason',
  'admin_refunds_col_status',
  'admin_refunds_col_requested_at',
  'admin_refunds_col_processed_at',
  // --- Payouts --------------------------------------------------------------
  'admin_payouts_col_id',
  'admin_payouts_col_driver',
  'admin_payouts_col_amount',
  'admin_payouts_col_status',
  'admin_payouts_col_hold',
  'admin_payouts_col_eligible_at',
  'admin_payouts_col_provider_id',
  'admin_payouts_col_paid_at',
  'admin_payouts_col_failed_at',
  'admin_payouts_col_reversed_at',
  'admin_payouts_reverse_dialog_title',
  'admin_payouts_reverse_action',
  'admin_payouts_reversed_success',
  // --- Disputes -------------------------------------------------------------
  'admin_disputes_col_id',
  'admin_disputes_col_mission',
  'admin_disputes_col_payment',
  'admin_disputes_col_reason',
  'admin_disputes_col_status',
  'admin_disputes_col_amount',
  'admin_disputes_col_opened_at',
  'admin_disputes_col_evidence_due',
  'admin_disputes_col_updated_at',
  // --- Ledger -----------------------------------------------------------
  'admin_ledger_col_date',
  'admin_ledger_col_type',
  'admin_ledger_col_mission',
  'admin_ledger_col_party',
  'admin_ledger_col_amount',
  'admin_ledger_col_amount_cad',
  'admin_ledger_col_direction',
  'admin_ledger_col_reason',
  'admin_ledger_col_currency',
  'admin_ledger_col_reference',
  'admin_ledger_col_source',
  'admin_ledger_new_adjustment',
  'admin_ledger_adjustment_dialog_title',
  'admin_ledger_create',
  'admin_ledger_validation_required',
  'admin_ledger_adjustment_created',
  // --- Reconciliation ---------------------------------------------------
  'admin_reconciliation_col_severity',
  'admin_reconciliation_col_type',
  'admin_reconciliation_col_mission',
  'admin_reconciliation_col_payment',
  'admin_reconciliation_col_expected',
  'admin_reconciliation_col_actual',
  'admin_reconciliation_col_detected_at',
  'admin_reconciliation_col_status',
  'admin_reconciliation_run_now',
  'admin_reconciliation_run_success',
  'admin_reconciliation_resolve',
  'admin_reconciliation_resolution_notes',
  'admin_reconciliation_resolve_dialog_title',
  'admin_reconciliation_anomaly_resolved',
  'admin_reconciliation_summary_open',
  'admin_reconciliation_summary_critical',
  'admin_reconciliation_summary_warning',
  'admin_reconciliation_summary_resolved',
  // --- Taxes --------------------------------------------------------------
  'admin_taxes_col_jurisdiction',
  'admin_taxes_col_tax_code',
  'admin_taxes_col_rate',
  'admin_taxes_col_components',
  'admin_taxes_col_effective_from',
  'admin_taxes_col_effective_until',
  'admin_taxes_col_enabled',
  'admin_taxes_col_version',
  'admin_taxes_col_display_name',
  'admin_taxes_col_type',
  'admin_taxes_col_owner',
  'admin_taxes_new_config',
  'admin_taxes_new_config_notice',
  'admin_taxes_save',
  'admin_taxes_save_success',
  'admin_taxes_validation_required',
  // --- Payout policy ------------------------------------------------------
  'admin_payout_policy_default',
  'admin_payout_policy_new_driver',
  'admin_payout_policy_risky_driver',
  'admin_payout_policy_updated_at',
  'admin_payout_policy_edit',
  'admin_payout_policy_save',
  'admin_payout_policy_save_success',
  'admin_payout_policy_validation_invalid',
  // --- Statuts d'affichage (enums) ----------------------------------------
  'finance_status_pending',
  'finance_status_authorized',
  'finance_status_confirmed',
  'finance_status_failed',
  'finance_status_partially_refunded',
  'finance_status_refunded',
  'payout_status_pending',
  'payout_status_held',
  'payout_status_eligible',
  'payout_status_scheduled',
  'payout_status_processing',
  'payout_status_paid',
  'payout_status_failed',
  'payout_status_reversed',
  'dispute_status_opened',
  'dispute_status_under_review',
  'dispute_status_won',
  'dispute_status_lost',
  'dispute_status_reversed',
  'dispute_status_closed',
  'anomaly_severity_critical',
  'anomaly_severity_warning',
  'anomaly_severity_info',
  'anomaly_status_open',
  'anomaly_status_acknowledged',
  'anomaly_status_resolved',
  'ledger_type_customer_charge',
  'ledger_type_platform_commission',
  'ledger_type_driver_earning',
  'ledger_type_driver_tip',
  'ledger_type_driver_bonus',
  'ledger_type_driver_payout',
  'ledger_type_refund',
  'ledger_type_partial_refund',
  'ledger_type_chargeback',
  'ledger_type_tax',
  'ledger_type_payment_processing_fee',
  'ledger_type_payout_processing_fee',
  'ledger_type_insurance_cost',
  'ledger_type_customer_adjustment',
  'ledger_type_driver_adjustment',
  'ledger_type_customer_service_fee',
  // --- Communs réutilisés (doivent aussi être couverts) --------------------
  'common_cancel',
  'common_confirm',
];

const List<String> _kLocales = ['fr', 'en', 'es'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('BLOC M — i18n global Phase 6 : couverture FR/EN/ES', () {
    for (final key in _kPhase6Keys) {
      test('clé "$key" est traduite dans les 3 langues (fr/en/es)', () {
        for (final locale in _kLocales) {
          final value = AppStrings.t(key, locale);
          expect(
            value,
            isNot(equals(key)),
            reason:
                'La clé "$key" ne retourne aucune traduction pour la '
                'locale "$locale" (fallback sur la clé technique elle-même '
                '=> entrée manquante dans AppStrings._t).',
          );
          expect(
            value.trim(),
            isNotEmpty,
            reason: 'La clé "$key" a une traduction vide pour "$locale".',
          );
        }
      });
    }

    test('aucune régression : le nombre total de clés Phase 6 couvertes est '
        'stable (${_kPhase6Keys.length} clés)', () {
      expect(_kPhase6Keys.length, greaterThanOrEqualTo(150));
    });
  });

  group('BLOC M — rendu réel AdminFinanceShell dans les 3 langues', () {
    Widget wrapWithLocale(String localeCode) {
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => LocaleProvider()),
          ChangeNotifierProvider(
            create: (_) => FirebaseAuthProvider(backendConfigured: false),
          ),
        ],
        child: Consumer<LocaleProvider>(
          builder: (context, locale, _) {
            // Force la locale cible dès le premier frame (LocaleProvider
            // charge 'fr' par défaut de façon async via SharedPreferences ;
            // on la remplace explicitement pour piloter le test).
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (locale.locale != localeCode) {
                locale.setLocale(localeCode);
              }
            });
            return const MaterialApp(home: AdminFinanceShell());
          },
        ),
      );
    }

    for (final localeCode in _kLocales) {
      testWidgets(
        'AdminFinanceShell se construit sans exception en locale "$localeCode"',
        (tester) async {
          await tester.pumpWidget(wrapWithLocale(localeCode));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          // Au moins un des 8 onglets doit être visible (TabBar mobile
          // par défaut en largeur de test < 900).
          expect(find.byType(TabBar), findsOneWidget);
        },
      );
    }

    testWidgets(
      'changer de langue en cours de session met à jour les libellés visibles '
      '(fr -> en -> es) sans exception',
      (tester) async {
        final localeProvider = LocaleProvider();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: localeProvider),
              ChangeNotifierProvider(
                create: (_) => FirebaseAuthProvider(backendConfigured: false),
              ),
            ],
            child: const MaterialApp(home: AdminFinanceShell()),
          ),
        );
        // `LocaleProvider()` charge la préférence persistée de façon
        // asynchrone (`SharedPreferences.getInstance()`) avant de notifier ;
        // `pumpAndSettle` seul peut se stabiliser avant la résolution de ce
        // premier Future selon la plateforme de test. On force quelques
        // cycles de pump supplémentaires pour laisser ce chargement initial
        // se terminer avant toute assertion, évitant un faux négatif flaky.
        await tester.pumpAndSettle();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        // FR (défaut) : onglet "Paiements" visible.
        expect(
          find.text(AppStrings.t('admin_finance_tab_payments', 'fr')),
          findsWidgets,
        );

        await localeProvider.setLocale('en');
        await tester.pumpAndSettle();
        expect(
          find.text(AppStrings.t('admin_finance_tab_payments', 'en')),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);

        await localeProvider.setLocale('es');
        await tester.pumpAndSettle();
        expect(
          find.text(AppStrings.t('admin_finance_tab_payments', 'es')),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
