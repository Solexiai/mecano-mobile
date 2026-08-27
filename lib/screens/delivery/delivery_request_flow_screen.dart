// ---------------------------------------------------------------------------
// DeliveryRequestFlowScreen — flux RÉEL de création de mission (Phase 4).
//
// Remplace intégralement l'ancien flux démo (sélection manuelle d'un
// chauffeur `ProviderProfile`/`DemoDataService.drivers`, prix calculé
// localement). Le workflow réel est :
//
//   Client Firebase authentifié
//   -> saisie pickup (adresse structurée + lat/lng)
//   -> saisie destination (adresse structurée + lat/lng)
//   -> choix du véhicule requis + informations sur l'objet
//   -> DistanceEstimationService.estimate() (Haversine, provisoire)
//   -> MissionRepository.requestQuote() -> Cloud Function calculateDeliveryQuote
//   -> affichage du devis réel (DeliveryQuote.customerTotal, jamais recalculé)
//   -> confirmation du client
//   -> MissionRepository.createMissionFromQuote() -> Cloud Function
//      createDeliveryRequest -> DeliveryMission (status = searching_driver)
//
// Aucun prix fictif, aucune mission fictive, aucun chauffeur choisi
// manuellement par le client.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../backend/backend_locator.dart';
import '../../backend/backend_exceptions.dart';
import '../../backend/models/delivery_mission.dart';
import '../../backend/models/delivery_quote.dart';
import '../../backend/repositories/mission_repository.dart';
import '../../core/app_colors.dart';
import '../../models/enums.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/demo_data_service.dart';
import '../../services/distance_estimation_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';
import '../../widgets/step_progress_form.dart';

class DeliveryRequestFlowScreen extends StatefulWidget {
  final String locale;
  const DeliveryRequestFlowScreen({super.key, required this.locale});

  @override
  State<DeliveryRequestFlowScreen> createState() => _DeliveryRequestFlowScreenState();
}

enum _FlowPhase { form, quoting, quoted, creating, created }

class _DeliveryRequestFlowScreenState extends State<DeliveryRequestFlowScreen> {
  // ---- Step 1: item info ----
  String _selectedCategory = '';
  final _descController = TextEditingController();
  int _quantity = 1;
  bool _needsStairs = false;
  bool _needsSecondHandler = false;
  bool _isHeavyItem = false;
  bool _isBulkyItem = false;

  // ---- Step 2: addresses ----
  final _pickupLine1Controller = TextEditingController();
  final _pickupCityController = TextEditingController();
  final _pickupPostalController = TextEditingController();
  final _pickupLatController = TextEditingController();
  final _pickupLngController = TextEditingController();
  final _dropoffLine1Controller = TextEditingController();
  final _dropoffCityController = TextEditingController();
  final _dropoffPostalController = TextEditingController();
  final _dropoffLatController = TextEditingController();
  final _dropoffLngController = TextEditingController();
  final _contactController = TextEditingController();
  final _accessController = TextEditingController();

  // ---- Step 3: vehicle ----
  VehicleCategory? _selectedVehicle;

  // ---- Quote / mission state ----
  _FlowPhase _phase = _FlowPhase.form;
  DeliveryQuote? _quote;
  DeliveryMission? _mission;
  DistanceEstimate? _distanceEstimate;
  String? _errorMessage;

  static const _distanceService = DistanceEstimationService();

  @override
  void dispose() {
    _descController.dispose();
    _pickupLine1Controller.dispose();
    _pickupCityController.dispose();
    _pickupPostalController.dispose();
    _pickupLatController.dispose();
    _pickupLngController.dispose();
    _dropoffLine1Controller.dispose();
    _dropoffCityController.dispose();
    _dropoffPostalController.dispose();
    _dropoffLatController.dispose();
    _dropoffLngController.dispose();
    _contactController.dispose();
    _accessController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final auth = context.watch<FirebaseAuthProvider>();

    if (!auth.isSignedIn) {
      return AppShell(
        locale: widget.locale,
        showFooter: false,
        child: _LoginRequiredNotice(locale: widget.locale, message: t('delivery_login_required')),
      );
    }

    if (_phase == _FlowPhase.created && _mission != null) {
      return AppShell(
        locale: widget.locale,
        showFooter: false,
        child: _MissionCreatedConfirmation(locale: widget.locale, mission: _mission!),
      );
    }

    return AppShell(
      locale: widget.locale,
      showFooter: false,
      child: ResponsivePadding(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(title: t('delivery_hero_headline')),
              const SizedBox(height: 28),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: StepProgressForm(
                  stepTitles: [
                    t('delivery_step1_title'),
                    t('delivery_step_addresses_title'),
                    t('delivery_step_vehicle_title'),
                    t('delivery_step_quote_title'),
                  ],
                  nextLabel: t('common_next'),
                  backLabel: t('common_back'),
                  submitLabel: t('delivery_confirm_and_create'),
                  canProceed: (step) {
                    if (step == 0) return _selectedCategory.isNotEmpty && _descController.text.trim().isNotEmpty;
                    if (step == 1) {
                      return _pickupLine1Controller.text.trim().isNotEmpty &&
                          _pickupCityController.text.trim().isNotEmpty &&
                          _pickupPostalController.text.trim().isNotEmpty &&
                          _pickupLatController.text.trim().isNotEmpty &&
                          _pickupLngController.text.trim().isNotEmpty &&
                          _dropoffLine1Controller.text.trim().isNotEmpty &&
                          _dropoffCityController.text.trim().isNotEmpty &&
                          _dropoffPostalController.text.trim().isNotEmpty &&
                          _dropoffLatController.text.trim().isNotEmpty &&
                          _dropoffLngController.text.trim().isNotEmpty &&
                          double.tryParse(_pickupLatController.text.trim()) != null &&
                          double.tryParse(_pickupLngController.text.trim()) != null &&
                          double.tryParse(_dropoffLatController.text.trim()) != null &&
                          double.tryParse(_dropoffLngController.text.trim()) != null;
                    }
                    if (step == 2) return _selectedVehicle != null;
                    // Step 3 (quote) : la soumission finale n'est permise
                    // qu'une fois un devis réel obtenu.
                    return _quote != null && _phase == _FlowPhase.quoted;
                  },
                  onStepChanged: (step) {
                    // Dès l'entrée dans l'étape "devis", on déclenche
                    // automatiquement le calcul du devis réel si ce n'est
                    // pas déjà fait.
                    if (step == 3 && _quote == null && _phase == _FlowPhase.form) {
                      _requestQuote(auth);
                    }
                  },
                  onComplete: () => _createMission(auth),
                  stepBuilders: [
                    (context) => _Step1ItemInfo(
                          categories: DemoDataService.deliveryCategories,
                          selectedCategory: _selectedCategory,
                          onCategorySelected: (c) => setState(() => _selectedCategory = c),
                          descController: _descController,
                          quantity: _quantity,
                          onQuantityChanged: (q) => setState(() => _quantity = q),
                          needsStairs: _needsStairs,
                          onStairsChanged: (v) => setState(() => _needsStairs = v),
                          needsSecondHandler: _needsSecondHandler,
                          onSecondHandlerChanged: (v) => setState(() => _needsSecondHandler = v),
                          isHeavyItem: _isHeavyItem,
                          onHeavyChanged: (v) => setState(() => _isHeavyItem = v),
                          isBulkyItem: _isBulkyItem,
                          onBulkyChanged: (v) => setState(() => _isBulkyItem = v),
                          // MIS-C-09 / BUG-003 : force le rebuild du parent
                          // pour que `canProceed` (qui lit
                          // `_descController.text`) soit réévalué à chaque
                          // frappe, sans quoi le bouton "Suivant" peut
                          // rester bloqué désactivé.
                          onDescriptionChanged: () => setState(() {}),
                        ),
                    (context) => _Step2Addresses(
                          pickupLine1: _pickupLine1Controller,
                          pickupCity: _pickupCityController,
                          pickupPostal: _pickupPostalController,
                          pickupLat: _pickupLatController,
                          pickupLng: _pickupLngController,
                          dropoffLine1: _dropoffLine1Controller,
                          dropoffCity: _dropoffCityController,
                          dropoffPostal: _dropoffPostalController,
                          dropoffLat: _dropoffLatController,
                          dropoffLng: _dropoffLngController,
                          contactController: _contactController,
                          accessController: _accessController,
                          // MIS-C-09 / BUG-003 : même correctif que l'étape 1
                          // — force la réévaluation de `canProceed(step==1)`
                          // à chaque frappe dans un champ d'adresse.
                          onAddressFieldChanged: () => setState(() {}),
                        ),
                    (context) => _Step3Vehicle(
                          selected: _selectedVehicle,
                          onSelected: (v) => setState(() => _selectedVehicle = v),
                        ),
                    (context) => _Step4Quote(
                          phase: _phase,
                          quote: _quote,
                          distanceEstimate: _distanceEstimate,
                          errorMessage: _errorMessage,
                          onRetry: () => _requestQuote(auth),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestQuote(FirebaseAuthProvider auth) async {
    if (_selectedVehicle == null) return;
    setState(() {
      _phase = _FlowPhase.quoting;
      _errorMessage = null;
    });

    try {
      final pickupLat = double.parse(_pickupLatController.text.trim());
      final pickupLng = double.parse(_pickupLngController.text.trim());
      final dropoffLat = double.parse(_dropoffLatController.text.trim());
      final dropoffLng = double.parse(_dropoffLngController.text.trim());

      final estimate = _distanceService.estimate(
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
      );

      final quote = await BackendLocator.missionRepository.requestQuote(
        customerId: auth.effectiveUid ?? '',
        itemCategoryKey: _selectedCategory,
        vehicleCategoryName: _selectedVehicle!.firestoreValue,
        missionDetails: {
          'distanceKm': estimate.distanceKm,
          'estimatedDurationMinutes': estimate.estimatedDurationMinutes,
          'handling': {
            'isHeavyItem': _isHeavyItem,
            'isBulkyItem': _isBulkyItem,
            'needsStairs': _needsStairs,
            'needsSecondHandler': _needsSecondHandler,
          },
        },
      );

      if (!mounted) return;
      setState(() {
        _distanceEstimate = estimate;
        _quote = quote;
        _phase = _FlowPhase.quoted;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _FlowPhase.form;
        _errorMessage = _describeError(e);
      });
    }
  }

  Future<void> _createMission(FirebaseAuthProvider auth) async {
    // MIS-C-09 (Phase 7, Bloc B) : garde de réentrance EXPLICITE, en plus de
    // la désactivation visuelle du bouton (`canProceed` -> `_phase ==
    // _FlowPhase.quoted`). La désactivation visuelle ne suffit pas seule :
    // entre le premier `onPressed` et le rebuild qui grise le bouton, un
    // deuxième tap synchrone (même frame, ou double-tap très rapide) peut
    // survenir AVANT que `setState` n'ait été appliqué. Cette garde en tête
    // de fonction (vérifiée avant tout `setState`/appel réseau) empêche
    // qu'un deuxième appel à `_createMission()` ne déclenche une deuxième
    // requête `createMissionFromQuote` tant que le premier appel est en
    // cours ou déjà terminé (`creating` ou `created`).
    if (_phase == _FlowPhase.creating || _phase == _FlowPhase.created) return;
    if (_quote == null || _selectedVehicle == null || _distanceEstimate == null) return;
    setState(() {
      _phase = _FlowPhase.creating;
      _errorMessage = null;
    });

    try {
      final pickupAddress = MissionAddress(
        line1: _pickupLine1Controller.text.trim(),
        city: _pickupCityController.text.trim(),
        postalCode: _pickupPostalController.text.trim(),
        lat: double.parse(_pickupLatController.text.trim()),
        lng: double.parse(_pickupLngController.text.trim()),
      );
      final dropoffAddress = MissionAddress(
        line1: _dropoffLine1Controller.text.trim(),
        city: _dropoffCityController.text.trim(),
        postalCode: _dropoffPostalController.text.trim(),
        lat: double.parse(_dropoffLatController.text.trim()),
        lng: double.parse(_dropoffLngController.text.trim()),
      );

      final mission = await BackendLocator.missionRepository.createMissionFromQuote(
        CreateMissionRequest(
          quoteId: _quote!.id,
          itemCategoryKey: _selectedCategory,
          description: _descController.text.trim(),
          requiredVehicleCategory: _selectedVehicle!,
          distanceKm: _distanceEstimate!.distanceKm,
          estimatedDurationMinutes: _distanceEstimate!.estimatedDurationMinutes,
          stops: [
            MissionStopInput(
              type: 'pickup',
              address: pickupAddress,
              contactInstructions:
                  _contactController.text.trim().isEmpty ? null : _contactController.text.trim(),
              accessDetails: _accessController.text.trim().isEmpty ? null : _accessController.text.trim(),
            ),
            MissionStopInput(type: 'dropoff', address: dropoffAddress),
          ],
          customerDisplayName: auth.effectiveDisplayName ?? auth.effectiveEmail ?? 'Client',
        ),
      );

      if (!mounted) return;
      setState(() {
        _mission = mission;
        _phase = _FlowPhase.created;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _FlowPhase.quoted;
        _errorMessage = _describeError(e);
      });
    }
  }

  String _describeError(Object e) {
    if (e is CloudFunctionException) return e.message;
    if (e is BackendNotConfiguredException) return e.message;
    return e.toString();
  }
}

// ---------------- Step 1 : item info ----------------
class _Step1ItemInfo extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final TextEditingController descController;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final bool needsStairs;
  final ValueChanged<bool> onStairsChanged;
  final bool needsSecondHandler;
  final ValueChanged<bool> onSecondHandlerChanged;
  final bool isHeavyItem;
  final ValueChanged<bool> onHeavyChanged;
  final bool isBulkyItem;
  final ValueChanged<bool> onBulkyChanged;
  // MIS-C-09 (Phase 7, Bloc B, BUG-003) : `canProceed` (StepProgressForm)
  // dépend de `descController.text`, mais un `TextEditingController` seul
  // ne déclenche AUCUN rebuild du parent quand son texte change (ce widget
  // est `StatelessWidget` et le parent n'écoute pas le controller). Sans ce
  // callback, taper la description après avoir choisi la catégorie ne
  // réévalue jamais `canProceed` -> le bouton "Suivant" reste figé désactivé.
  final VoidCallback onDescriptionChanged;

  const _Step1ItemInfo({
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.descController,
    required this.quantity,
    required this.onQuantityChanged,
    required this.needsStairs,
    required this.onStairsChanged,
    required this.needsSecondHandler,
    required this.onSecondHandlerChanged,
    required this.isHeavyItem,
    required this.onHeavyChanged,
    required this.isBulkyItem,
    required this.onBulkyChanged,
    required this.onDescriptionChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return StepFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('delivery_item_category'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories
                .map((c) => ChoiceChip(
                      label: Text(t(c)),
                      selected: selectedCategory == c,
                      onSelected: (_) => onCategorySelected(c),
                    ))
                .toList(),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: descController,
            maxLines: 3,
            decoration: InputDecoration(labelText: t('delivery_item_description')),
            onChanged: (_) => onDescriptionChanged(),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(t('delivery_item_quantity'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(
                onPressed: quantity > 1 ? () => onQuantityChanged(quantity - 1) : null,
                icon: const Icon(Icons.remove_circle_outline),
                tooltip: t('delivery_item_quantity_decrease'),
              ),
              Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              IconButton(
                onPressed: () => onQuantityChanged(quantity + 1),
                icon: const Icon(Icons.add_circle_outline),
                tooltip: t('delivery_item_quantity_increase'),
              ),
            ],
          ),
          const Divider(height: 32),
          _SwitchRow(label: t('delivery_item_stairs'), value: needsStairs, onChanged: onStairsChanged),
          _SwitchRow(label: t('delivery_item_loading_help'), value: needsSecondHandler, onChanged: onSecondHandlerChanged),
          _SwitchRow(label: t('delivery_item_heavy'), value: isHeavyItem, onChanged: onHeavyChanged),
          _SwitchRow(label: t('delivery_item_bulky'), value: isBulkyItem, onChanged: onBulkyChanged),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.primary,
    );
  }
}

// ---------------- Step 2 : addresses ----------------
class _Step2Addresses extends StatelessWidget {
  final TextEditingController pickupLine1;
  final TextEditingController pickupCity;
  final TextEditingController pickupPostal;
  final TextEditingController pickupLat;
  final TextEditingController pickupLng;
  final TextEditingController dropoffLine1;
  final TextEditingController dropoffCity;
  final TextEditingController dropoffPostal;
  final TextEditingController dropoffLat;
  final TextEditingController dropoffLng;
  final TextEditingController contactController;
  final TextEditingController accessController;
  // MIS-C-09 (Phase 7, Bloc B, BUG-003) : même pattern que _Step1ItemInfo —
  // `canProceed(step == 1)` lit directement le `.text` des 10 controllers
  // d'adresse. Sans callback de rebuild, remplir ces champs dans un ordre
  // qui ne déclenche pas déjà un `setState` ailleurs laisse le bouton
  // "Suivant" figé désactivé même une fois tous les champs valides.
  // (contactController/accessController ne sont PAS dans `canProceed` —
  // ils sont optionnels — donc pas concernés par ce callback.)
  final VoidCallback onAddressFieldChanged;

  const _Step2Addresses({
    required this.pickupLine1,
    required this.pickupCity,
    required this.pickupPostal,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLine1,
    required this.dropoffCity,
    required this.dropoffPostal,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.contactController,
    required this.accessController,
    required this.onAddressFieldChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return StepFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trip_origin, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('delivery_pickup_address'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pickupLine1,
            decoration: InputDecoration(labelText: t('delivery_pickup_line1')),
            onChanged: (_) => onAddressFieldChanged(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: pickupCity,
                  decoration: InputDecoration(labelText: t('delivery_pickup_city')),
                  onChanged: (_) => onAddressFieldChanged(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: pickupPostal,
                  decoration: InputDecoration(labelText: t('delivery_pickup_postal')),
                  onChanged: (_) => onAddressFieldChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: pickupLat,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(labelText: t('delivery_lat')),
                  onChanged: (_) => onAddressFieldChanged(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: pickupLng,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(labelText: t('delivery_lng')),
                  onChanged: (_) => onAddressFieldChanged(),
                ),
              ),
            ],
          ),
          const Divider(height: 32),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('delivery_dropoff_address'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: dropoffLine1,
            decoration: InputDecoration(labelText: t('delivery_dropoff_line1')),
            onChanged: (_) => onAddressFieldChanged(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: dropoffCity,
                  decoration: InputDecoration(labelText: t('delivery_dropoff_city')),
                  onChanged: (_) => onAddressFieldChanged(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: dropoffPostal,
                  decoration: InputDecoration(labelText: t('delivery_dropoff_postal')),
                  onChanged: (_) => onAddressFieldChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: dropoffLat,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(labelText: t('delivery_lat')),
                  onChanged: (_) => onAddressFieldChanged(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: dropoffLng,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(labelText: t('delivery_lng')),
                  onChanged: (_) => onAddressFieldChanged(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(t('delivery_coordinates_note'), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
          const Divider(height: 32),
          TextField(controller: contactController, decoration: InputDecoration(labelText: '${t('delivery_contact_instructions')} (${t('common_optional')})')),
          const SizedBox(height: 16),
          TextField(controller: accessController, decoration: InputDecoration(labelText: '${t('delivery_access_details')} (${t('common_optional')})')),
        ],
      ),
    );
  }
}

// ---------------- Step 3 : vehicle ----------------
class _Step3Vehicle extends StatelessWidget {
  final VehicleCategory? selected;
  final ValueChanged<VehicleCategory> onSelected;
  const _Step3Vehicle({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return StepFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('delivery_required_vehicle'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: VehicleCategory.values
                .where((v) => v != VehicleCategory.other)
                .map((v) => ChoiceChip(
                      label: Text(t(v.key)),
                      selected: selected == v,
                      onSelected: (_) => onSelected(v),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ---------------- Step 4 : quote ----------------
class _Step4Quote extends StatelessWidget {
  final _FlowPhase phase;
  final DeliveryQuote? quote;
  final DistanceEstimate? distanceEstimate;
  final String? errorMessage;
  final VoidCallback onRetry;

  const _Step4Quote({
    required this.phase,
    required this.quote,
    required this.distanceEstimate,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;

    if (phase == _FlowPhase.quoting || phase == _FlowPhase.creating) {
      return StepFormCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(phase == _FlowPhase.creating ? t('delivery_creating_mission') : t('delivery_getting_quote')),
          ],
        ),
      );
    }

    if (errorMessage != null && quote == null) {
      return StepFormCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(child: Text(t('delivery_quote_error'), style: const TextStyle(color: AppColors.error))),
              ],
            ),
            const SizedBox(height: 8),
            Text(errorMessage!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: Text(t('common_retry'))),
          ],
        ),
      );
    }

    if (quote == null) {
      // Ne devrait pas arriver (onStepChanged déclenche le devis), mais on
      // couvre le cas défensivement plutôt que d'afficher un état incohérent.
      return StepFormCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(t('delivery_getting_quote')),
          ],
        ),
      );
    }

    return StepFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMessage!, style: const TextStyle(fontSize: 12.5, color: AppColors.error))),
              ]),
            ),
            const SizedBox(height: 16),
          ],
          Text(t('delivery_quote_total'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                Text(
                  '${quote!.customerTotal.toStringAsFixed(2)} \$',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.primary),
                ),
                if (quote!.breakdown != null) ...[
                  const Divider(height: 28),
                  _BreakdownRow(t('delivery_breakdown_base'), quote!.breakdown!.missionBaseValue),
                  if (quote!.breakdown!.handlingFeesTotal > 0)
                    _BreakdownRow(t('delivery_item_stairs'), quote!.breakdown!.handlingFeesTotal),
                  if (quote!.breakdown!.customerServiceFee > 0)
                    _BreakdownRow(t('delivery_breakdown_service_fee'), quote!.breakdown!.customerServiceFee),
                  if (quote!.breakdown!.taxAmount > 0) _BreakdownRow(t('delivery_breakdown_tax'), quote!.breakdown!.taxAmount),
                  if (quote!.breakdown!.customerDiscountAmount > 0)
                    _BreakdownRow(t('delivery_breakdown_discount'), -quote!.breakdown!.customerDiscountAmount),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (distanceEstimate != null)
            Text(t('delivery_quote_distance_note'), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Text(t('delivery_quote_expires_note'), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final double value;
  const _BreakdownRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          Text('${value.toStringAsFixed(2)} \$', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ---------------- Confirmation ----------------
class _MissionCreatedConfirmation extends StatelessWidget {
  final String locale;
  final DeliveryMission mission;
  const _MissionCreatedConfirmation({required this.locale, required this.mission});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), shape: BoxShape.circle),
                child: const Icon(Icons.check_circle, color: AppColors.success, size: 44),
              ),
              const SizedBox(height: 24),
              Text(t('delivery_mission_created_title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                t('delivery_searching_driver_desc'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.hourglass_top_rounded, color: AppColors.info),
                    const SizedBox(width: 12),
                    Expanded(child: Text(t(mission.status.key), style: const TextStyle(fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => context.go('/$locale/tableau-de-bord'),
                child: Text(t('delivery_view_my_requests')),
              ),
              const SizedBox(height: 12),
              TextButton(onPressed: () => context.go('/$locale'), child: Text(t('nav_home'))),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginRequiredNotice extends StatelessWidget {
  final String locale;
  final String message;
  const _LoginRequiredNotice({required this.locale, required this.message});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.of(context).canPop()
                  ? Navigator.of(context).pop()
                  : GoRouter.of(context).go('/$locale/connexion'),
              child: Text(t('delivery_sign_in_button')),
            ),
          ],
        ),
      ),
    );
  }
}
