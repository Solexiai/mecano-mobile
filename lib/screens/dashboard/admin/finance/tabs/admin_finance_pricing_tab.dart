// ---------------------------------------------------------------------------
// AdminFinancePricingTab — Centre financier > Tarifs.
//
// Grille de tarifs modifiable par Movi-K, sans passer par un script :
//   1. la grille s'ouvre sur la version ACTIVE (`pricing_versions/{v}`) ;
//   2. l'admin modifie les valeurs (brouillon local, rien n'est écrit) ;
//   3. le simulateur (`previewPricingConfiguration`) compare actif / nouveau
//      sur quelques courses types, avec le moteur officiel du serveur ;
//   4. le super admin publie (`updatePricingConfiguration`) : une NOUVELLE
//      version immuable est créée, l'ancienne reste dans l'historique ;
//   5. « Reprendre ces valeurs » recharge une ancienne version dans la grille
//      (retour arrière = republier ces valeurs).
//
// La publication n'est possible qu'après une simulation sans erreur des
// valeurs exactes affichées. Taxes et pourboires ne sont jamais modifiables
// ici (le serveur les recopie de la version active).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../backend/backend_locator.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../finance/models/pricing_grid_admin.dart';
import '../../../../../finance/models/pricing_grid_draft.dart';
import '../../../../../finance/presentation/money_format.dart';
import '../../../../../providers/firebase_auth_provider.dart';
import '../../../../../providers/locale_provider.dart';
import '../finance_ui_helpers.dart';

class _Scenario {
  const _Scenario({
    required this.id,
    required this.labelKey,
    required this.km,
    required this.minutes,
    this.stairs = false,
    this.twoPeople = false,
  });

  final String id;
  final String labelKey;
  final double km;
  final double minutes;
  final bool stairs;
  final bool twoPeople;

  Map<String, dynamic> toJson() => {
    'id': id,
    'distanceKm': km,
    'durationMinutes': minutes,
    'additionalStops': 0,
    'handling': {
      'needsStairs': stairs,
      'needsSecondHandler': twoPeople,
    },
  };
}

const List<_Scenario> _kPresetScenarios = [
  _Scenario(
    id: 'short',
    labelKey: 'admin_pricing_scenario_short',
    km: 5,
    minutes: 15,
  ),
  _Scenario(
    id: 'medium',
    labelKey: 'admin_pricing_scenario_medium',
    km: 15,
    minutes: 30,
    stairs: true,
  ),
  _Scenario(
    id: 'long',
    labelKey: 'admin_pricing_scenario_long',
    km: 40,
    minutes: 60,
    twoPeople: true,
  ),
];

String _formatNumber(double value, String locale) {
  var text = value.toStringAsFixed(4);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  text = text.replaceFirst(RegExp(r'\.$'), '');
  if (text == '-0') text = '0';
  return locale.startsWith('en') ? text : text.replaceAll('.', ',');
}

double? _parseNumber(String raw) {
  final cleaned = raw
      .trim()
      .replaceAll(RegExp(r'[\s$% ]'), '')
      .replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  return value != null && value.isFinite ? value : null;
}

String _money(int minor, String locale) =>
    formatMajorAmount(minor / 100, locale: locale);

class AdminFinancePricingTab extends StatefulWidget {
  const AdminFinancePricingTab({super.key});

  @override
  State<AdminFinancePricingTab> createState() => _AdminFinancePricingTabState();
}

class _AdminFinancePricingTabState extends State<AdminFinancePricingTab> {
  bool _loading = true;
  bool _loadFailed = false;
  AdminPricingVersionInfo? _active;
  List<AdminPricingVersionInfo> _history = const [];

  /// Valeurs actives (référence pour « modifié » et les frais).
  PricingGridDraft? _original;
  PricingGridDraft? _draft;

  /// Change à chaque rechargement de la grille pour recréer les champs.
  int _formGeneration = 0;

  PricingPreviewResult? _preview;
  String? _previewFingerprint;
  String? _previewError;
  bool _previewing = false;

  bool _publishing = false;
  bool _feeTextUpdated = false;
  final TextEditingController _noteController = TextEditingController();

  double _customKm = 25;
  double _customMinutes = 45;
  bool _customStairs = false;
  bool _customTwoPeople = false;

  @override
  void initState() {
    super.initState();
    _load(showSpinner: false);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    final repo = BackendLocator.financeRepository;
    try {
      final active = await repo.adminGetActivePricingVersion();
      List<AdminPricingVersionInfo> history = const [];
      try {
        history = await repo.adminListPricingVersions();
      } catch (_) {
        // L'historique est secondaire : la grille reste utilisable sans lui.
      }
      if (!mounted) return;
      setState(() {
        _active = active;
        _history = history;
        _original = active == null
            ? null
            : PricingGridDraft.fromVersion(active.raw, versionId: active.id);
        _draft = _original?.copy();
        _formGeneration++;
        _preview = null;
        _previewFingerprint = null;
        _previewError = null;
        _feeTextUpdated = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  void _edit(void Function(PricingGridDraft d) change) {
    final draft = _draft;
    if (draft == null) return;
    setState(() => change(draft));
  }

  void _resetToActive() {
    setState(() {
      _draft = _original?.copy();
      _formGeneration++;
      _feeTextUpdated = false;
    });
  }

  void _loadVersion(AdminPricingVersionInfo version, String Function(String) t) {
    setState(() {
      _draft = PricingGridDraft.fromVersion(version.raw, versionId: _active?.id);
      _formGeneration++;
      _feeTextUpdated = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t('admin_pricing_history_loaded').replaceAll('{version}', version.id),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _scenarioPayload() => [
    for (final s in _kPresetScenarios) s.toJson(),
    _Scenario(
      id: 'custom',
      labelKey: 'admin_pricing_scenario_custom',
      km: _customKm,
      minutes: _customMinutes,
      stairs: _customStairs,
      twoPeople: _customTwoPeople,
    ).toJson(),
  ];

  Future<void> _simulate() async {
    final draft = _draft;
    if (draft == null) return;
    final fingerprint = draft.fingerprint;
    setState(() {
      _previewing = true;
      _previewError = null;
    });
    try {
      final result = await BackendLocator.financeRepository.adminPreviewPricing(
        config: draft.toServerConfig(),
        scenarios: _scenarioPayload(),
        vehicleCategory: kPilotPricingCategories.first,
      );
      if (!mounted) return;
      setState(() {
        _preview = result;
        _previewFingerprint = fingerprint;
        _previewing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _preview = null;
        _previewFingerprint = null;
        _previewError = e is PricingGridException ? e.message : '$e';
        _previewing = false;
      });
    }
  }

  Future<void> _publish(String Function(String) t) async {
    final draft = _draft;
    if (draft == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t('admin_pricing_confirm_title')),
        content: Text(t('admin_pricing_confirm_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t('admin_pricing_cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t('admin_pricing_confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _publishing = true);
    try {
      final version = await BackendLocator.financeRepository.adminPublishPricing(
        config: draft.toServerConfig(),
        basedOnVersion: draft.basedOnVersion,
        feeTextUpdated: _feeTextUpdated,
        changeNote: _noteController.text,
      );
      if (!mounted) return;
      _noteController.clear();
      setState(() => _publishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('admin_pricing_published').replaceAll('{version}', version),
          ),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      String message;
      if (e is PricingGridException && e.code == 'aborted') {
        message = t('admin_pricing_error_stale');
      } else if (e is PricingGridException && e.errors.isNotEmpty) {
        message = e.errors.join('\n');
      } else {
        message = t(
          'admin_pricing_error_generic',
        ).replaceAll('{message}', e is PricingGridException ? e.message : '$e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 8)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final t = localeProvider.t;
    final locale = localeProvider.locale;
    final isSuperAdmin = context.watch<FirebaseAuthProvider>().isSuperAdmin;

    if (_loading) {
      return FinanceLoadingState(message: t('admin_finance_loading'));
    }
    if (_loadFailed) {
      return FinanceErrorState(
        message: t('admin_finance_error'),
        retryLabel: t('admin_finance_retry'),
        onRetry: _load,
      );
    }
    final draft = _draft;
    final original = _original;
    if (draft == null || original == null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FinanceEmptyState(message: t('admin_finance_empty')),
            const SizedBox(height: 8),
            Text(
              t('admin_pricing_no_active_hint'),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    final changed = draft.fingerprint != original.fingerprint;
    final feeChanged = draft.feeDiffersFrom(original);
    final previewCurrent =
        _preview != null && _previewFingerprint == draft.fingerprint;
    final previewErrors = previewCurrent ? _preview!.errors : const <String>[];

    String? blockedReason;
    if (!isSuperAdmin) {
      blockedReason = t('admin_pricing_why_super_admin');
    } else if (!changed) {
      blockedReason = t('admin_pricing_why_no_changes');
    } else if (!previewCurrent) {
      blockedReason = t('admin_pricing_why_simulate');
    } else if (previewErrors.isNotEmpty) {
      blockedReason = t('admin_pricing_why_errors');
    } else if (feeChanged && !_feeTextUpdated) {
      blockedReason = t('admin_pricing_why_fee_text');
    }

    final gen = _formGeneration;
    Widget money(
      String key,
      double value,
      void Function(PricingGridDraft d, double v) apply,
    ) => _NumberField(
      key: ValueKey('$key-$gen'),
      label: t(key),
      initial: value,
      locale: locale,
      invalidText: t('admin_pricing_invalid_number'),
      onChanged: (v) => _edit((d) => apply(d, v)),
    );
    Widget percent(
      String key,
      double rate,
      void Function(PricingGridDraft d, double v) apply,
    ) => _NumberField(
      key: ValueKey('$key-$gen'),
      label: t(key),
      initial: rate * 100,
      locale: locale,
      invalidText: t('admin_pricing_invalid_number'),
      onChanged: (v) => _edit((d) => apply(d, v / 100)),
    );

    final activeDate = _active?.effectiveFrom;
    final subtitle = t('admin_pricing_active_version')
        .replaceAll('{version}', _active?.id ?? '—')
        .replaceAll(
          '{date}',
          activeDate == null ? '—' : formatShortDate(activeDate),
        );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('admin_finance_tab_pricing'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          if (!isSuperAdmin) ...[
            const SizedBox(height: 10),
            Text(
              t('admin_pricing_read_only'),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ],
          const SizedBox(height: 16),
          _Section(
            title: t('admin_pricing_section_trip'),
            note: t('admin_pricing_section_trip_note'),
            fields: [
              money(
                'admin_pricing_base_fare',
                draft.baseFare,
                (d, v) => d.baseFare = v,
              ),
              money(
                'admin_pricing_rate_per_km',
                draft.ratePerKm,
                (d, v) => d.ratePerKm = v,
              ),
              money(
                'admin_pricing_rate_per_minute',
                draft.ratePerMinute,
                (d, v) => d.ratePerMinute = v,
              ),
              money(
                'admin_pricing_minimum_charge',
                draft.minimumCharge,
                (d, v) => d.minimumCharge = v,
              ),
            ],
          ),
          _Section(
            title: t('admin_pricing_section_handling'),
            fields: [
              money(
                'admin_pricing_loading',
                draft.loadingFee,
                (d, v) => d.loadingFee = v,
              ),
              money(
                'admin_pricing_unloading',
                draft.unloadingFee,
                (d, v) => d.unloadingFee = v,
              ),
              money(
                'admin_pricing_stairs',
                draft.stairsFee,
                (d, v) => d.stairsFee = v,
              ),
              money(
                'admin_pricing_no_elevator',
                draft.noElevatorFee,
                (d, v) => d.noElevatorFee = v,
              ),
              money(
                'admin_pricing_second_handler',
                draft.secondHandlerFee,
                (d, v) => d.secondHandlerFee = v,
              ),
              money(
                'admin_pricing_special_equipment',
                draft.specialEquipmentFee,
                (d, v) => d.specialEquipmentFee = v,
              ),
              money(
                'admin_pricing_stop',
                draft.feePerStop,
                (d, v) => d.feePerStop = v,
              ),
            ],
          ),
          _Section(
            title: t('admin_pricing_section_movik'),
            note: t('admin_pricing_section_movik_note'),
            fields: [
              percent(
                'admin_pricing_service_rate',
                draft.serviceFeeRate,
                (d, v) => d.serviceFeeRate = v,
              ),
              money(
                'admin_pricing_service_min',
                draft.minimumServiceFee,
                (d, v) => d.minimumServiceFee = v,
              ),
              percent(
                'admin_pricing_commission_rate',
                draft.commissionRate,
                (d, v) => d.commissionRate = v,
              ),
              money(
                'admin_pricing_commission_min',
                draft.minimumCommission,
                (d, v) => d.minimumCommission = v,
              ),
              percent(
                'admin_pricing_commission_max',
                draft.maximumEffectiveCommissionRate,
                (d, v) => d.maximumEffectiveCommissionRate = v,
              ),
            ],
          ),
          _Section(
            title: t('admin_pricing_section_fees'),
            note: t('admin_pricing_fee_note'),
            fields: [
              money(
                'admin_pricing_fee_total',
                draft.feeTotalMinor / 100,
                (d, v) => d.feeTotalMinor = (v * 100).round(),
              ),
              money(
                'admin_pricing_fee_driver',
                draft.feeDriverMinor / 100,
                (d, v) => d.feeDriverMinor = (v * 100).round(),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                  t('admin_pricing_fee_platform').replaceAll(
                    '{amount}',
                    _money(draft.feePlatformMinor, locale),
                  ),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: draft.feePlatformMinor < 0
                        ? AppColors.error
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          _Section(
            title: t('admin_pricing_section_quote'),
            fields: [
              _NumberField(
                key: ValueKey('admin_pricing_quote_validity-$gen'),
                label: t('admin_pricing_quote_validity'),
                initial: draft.quoteValidityMinutes.toDouble(),
                locale: locale,
                invalidText: t('admin_pricing_invalid_number'),
                onChanged: (v) =>
                    _edit((d) => d.quoteValidityMinutes = v.round()),
              ),
            ],
          ),
          _Section(
            title: t('admin_pricing_section_locked'),
            fields: [
              _LockedLine(t('admin_pricing_locked_taxes')),
              _LockedLine(t('admin_pricing_locked_items')),
              _LockedLine(t('admin_pricing_locked_unused')),
            ],
          ),
          if (changed)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _resetToActive,
                icon: const Icon(Icons.undo, size: 18),
                label: Text(t('admin_pricing_reset')),
              ),
            ),
          const SizedBox(height: 8),
          _Section(
            title: t('admin_pricing_section_simulator'),
            note: t('admin_pricing_simulator_note'),
            fields: [
              _NumberField(
                key: const ValueKey('admin_pricing_custom_km'),
                label: t('admin_pricing_custom_km'),
                initial: _customKm,
                locale: locale,
                invalidText: t('admin_pricing_invalid_number'),
                onChanged: (v) => setState(() => _customKm = v),
              ),
              _NumberField(
                key: const ValueKey('admin_pricing_custom_min'),
                label: t('admin_pricing_custom_min'),
                initial: _customMinutes,
                locale: locale,
                invalidText: t('admin_pricing_invalid_number'),
                onChanged: (v) => setState(() => _customMinutes = v),
              ),
              FilterChip(
                label: Text(t('admin_pricing_custom_stairs')),
                selected: _customStairs,
                onSelected: (v) => setState(() => _customStairs = v),
              ),
              FilterChip(
                label: Text(t('admin_pricing_custom_two')),
                selected: _customTwoPeople,
                onSelected: (v) => setState(() => _customTwoPeople = v),
              ),
              FilledButton.icon(
                onPressed: _previewing ? null : _simulate,
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: Text(
                  t(
                    _previewing
                        ? 'admin_pricing_simulating'
                        : 'admin_pricing_simulate',
                  ),
                ),
              ),
            ],
            footer: _PreviewResults(
              preview: previewCurrent ? _preview : null,
              stale: _preview != null && !previewCurrent,
              error: _previewError,
              locale: locale,
              t: t,
            ),
          ),
          _Section(
            title: t('admin_pricing_section_publish'),
            fields: const [],
            footer: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _noteController,
                  maxLength: 500,
                  decoration: InputDecoration(
                    labelText: t('admin_pricing_note'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                if (feeChanged)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _feeTextUpdated,
                    onChanged: (v) =>
                        setState(() => _feeTextUpdated = v ?? false),
                    title: Text(t('admin_pricing_fee_text_ack')),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: blockedReason == null && !_publishing
                      ? () => _publish(t)
                      : null,
                  icon: const Icon(Icons.publish_outlined, size: 18),
                  label: Text(
                    t(
                      _publishing
                          ? 'admin_pricing_publishing'
                          : 'admin_pricing_publish',
                    ),
                  ),
                ),
                if (blockedReason != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    blockedReason,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_history.isNotEmpty)
            _Section(
              title: t('admin_pricing_section_history'),
              fields: const [],
              footer: Column(
                children: _history
                    .map(
                      (v) => _HistoryTile(
                        version: v,
                        isActive: v.id == _active?.id,
                        onResume: () => _loadVersion(v, t),
                        t: t,
                      ),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? note;
  final List<Widget> fields;
  final Widget? footer;
  const _Section({
    required this.title,
    required this.fields,
    this.note,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(
              note!,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (fields.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: fields,
            ),
          ],
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ],
      ),
    );
  }
}

class _LockedLine extends StatelessWidget {
  final String text;
  const _LockedLine(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_outline, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Champ numérique : accepte « 1,5 » ou « 1.5 », ignore « $ » et « % ».
/// Une saisie invalide n'est jamais transmise au brouillon.
class _NumberField extends StatefulWidget {
  final String label;
  final double initial;
  final String locale;
  final String invalidText;
  final ValueChanged<double> onChanged;
  const _NumberField({
    super.key,
    required this.label,
    required this.initial,
    required this.locale,
    required this.invalidText,
    required this.onChanged,
  });

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final TextEditingController _controller = TextEditingController(
    text: _formatNumber(widget.initial, widget.locale),
  );
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: TextField(
        controller: _controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: widget.label,
          isDense: true,
          border: const OutlineInputBorder(),
          errorText: _invalid ? widget.invalidText : null,
        ),
        onChanged: (raw) {
          final value = _parseNumber(raw);
          setState(() => _invalid = value == null);
          if (value != null) widget.onChanged(value);
        },
      ),
    );
  }
}

class _PreviewResults extends StatelessWidget {
  final PricingPreviewResult? preview;
  final bool stale;
  final String? error;
  final String locale;
  final String Function(String) t;
  const _PreviewResults({
    required this.preview,
    required this.stale,
    required this.error,
    required this.locale,
    required this.t,
  });

  String _labelFor(String id) {
    switch (id) {
      case 'short':
        return t('admin_pricing_scenario_short');
      case 'medium':
        return t('admin_pricing_scenario_medium');
      case 'long':
        return t('admin_pricing_scenario_long');
      default:
        return t('admin_pricing_scenario_custom');
    }
  }

  String _pair(int? current, int? next) {
    if (next == null) return current == null ? '—' : _money(current, locale);
    if (current == null || current == next) return _money(next, locale);
    return '${_money(current, locale)} → ${_money(next, locale)}';
  }

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Text(error!, style: const TextStyle(color: AppColors.error));
    }
    if (stale) {
      return Text(
        t('admin_pricing_why_simulate'),
        style: const TextStyle(color: AppColors.textSecondary),
      );
    }
    final result = preview;
    if (result == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (result.errors.isNotEmpty) ...[
          Text(
            t('admin_pricing_errors_title'),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 4),
          for (final e in result.errors)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '• $e',
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          const SizedBox(height: 10),
        ],
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 20,
            headingRowHeight: 40,
            columns: [
              DataColumn(label: Text(t('admin_pricing_col_trip'))),
              DataColumn(label: Text(t('admin_pricing_col_customer'))),
              DataColumn(label: Text(t('admin_pricing_col_movik'))),
              DataColumn(label: Text(t('admin_pricing_col_driver'))),
              DataColumn(label: Text(t('admin_pricing_col_hold'))),
            ],
            rows: result.rows
                .map(
                  (r) => DataRow(
                    cells: [
                      DataCell(Text(_labelFor(r.id))),
                      DataCell(
                        Text(
                          _pair(
                            r.current?.customerTotalMinor,
                            r.draft?.customerTotalMinor,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _pair(r.current?.platformMinor, r.draft?.platformMinor),
                        ),
                      ),
                      DataCell(
                        Text(_pair(r.current?.driverMinor, r.draft?.driverMinor)),
                      ),
                      DataCell(
                        Text(
                          _pair(r.current?.cardHoldMinor, r.draft?.cardHoldMinor),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final AdminPricingVersionInfo version;
  final bool isActive;
  final VoidCallback onResume;
  final String Function(String) t;
  const _HistoryTile({
    required this.version,
    required this.isActive,
    required this.onResume,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final date = version.effectiveFrom;
    final note = version.changeNote;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Flexible(
            child: Text(
              version.id,
              style: const TextStyle(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isActive) ...[
            const SizedBox(width: 8),
            StatusBadge(
              label: t('admin_pricing_history_active'),
              color: AppColors.success,
            ),
          ],
        ],
      ),
      subtitle: Text(
        [
          if (date != null)
            formatDisplayDate(date, connector: t('datetime_connector_at')),
          if (note != null && note.isNotEmpty)
            t('admin_pricing_history_note').replaceAll('{note}', note),
        ].join(' · '),
      ),
      trailing: isActive
          ? null
          : TextButton(
              onPressed: onResume,
              child: Text(t('admin_pricing_history_resume')),
            ),
    );
  }
}
