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
import '../../services/address/address_suggestion.dart';
import '../../services/demo_data_service.dart';
import '../../services/distance_estimation_service.dart';
import '../../widgets/address_autocomplete_field.dart';
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

  // ---- Step 2: addresses (MOVI-K — adresses réelles + autocomplete +
  // géocodage) : un seul champ texte par adresse (pickup/dropoff), plus un
  // état interne (jamais visible/éditable directement) contenant l'adresse
  // COMPLÈTEMENT résolue par le fournisseur cartographique. `null` tant
  // qu'aucune adresse valide n'a été sélectionnée OU si le texte a été
  // modifié après une sélection (voir AddressAutocompleteField.onInvalidated).
  final _pickupAddressController = TextEditingController();
  final _dropoffAddressController = TextEditingController();
  ResolvedAddress? _pickupResolved;
  ResolvedAddress? _dropoffResolved;
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
    _pickupAddressController.dispose();
    _dropoffAddressController.dispose();
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
                      // GAP e/g/n) FAIL CLOSED : ne peut avancer que si les
                      // DEUX adresses ont été RÉELLEMENT résolues par le
                      // fournisseur (jamais une simple présence de texte).
                      return _pickupResolved != null && _dropoffResolved != null;
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
                          pickupController: _pickupAddressController,
                          dropoffController: _dropoffAddressController,
                          contactController: _contactController,
                          accessController: _accessController,
                          onPickupResolved: (a) => setState(() => _pickupResolved = a),
                          onPickupInvalidated: () => setState(() => _pickupResolved = null),
                          onDropoffResolved: (a) => setState(() => _dropoffResolved = a),
                          onDropoffInvalidated: () => setState(() => _dropoffResolved = null),
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

    // GAP g)/n) FAIL CLOSED : ne jamais calculer un devis (donc jamais
    // avancer) si l'une des deux adresses n'a pas été RÉELLEMENT résolue
    // par le fournisseur cartographique (jamais de coordonnées "1,2" ou
    // d'adresse tapée mais non sélectionnée dans les suggestions).
    final pickup = _pickupResolved;
    final dropoff = _dropoffResolved;
    if (pickup == null || dropoff == null) {
      setState(() {
        _phase = _FlowPhase.form;
        _errorMessage = context.read<LocaleProvider>().t('delivery_address_invalid_selection');
      });
      return;
    }

    setState(() {
      _phase = _FlowPhase.quoting;
      _errorMessage = null;
    });

    try {
      final estimate = _distanceService.estimate(
        pickupLat: pickup.lat,
        pickupLng: pickup.lng,
        dropoffLat: dropoff.lat,
        dropoffLng: dropoff.lng,
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
        _errorMessage = _describeError(e, genericKey: 'delivery_quote_error');
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

    // GAP g)/n) FAIL CLOSED : re-vérifié ICI (pas seulement à l'étape 1) —
    // un utilisateur pourrait revenir en arrière et modifier le texte d'une
    // adresse après avoir déjà obtenu un devis (`AddressAutocompleteField`
    // invalide alors `_pickupResolved`/`_dropoffResolved` via
    // `onInvalidated`). Une mission ne doit JAMAIS être créée avec une
    // adresse non résolue, même si un devis avait été calculé plus tôt sur
    // la base d'une adresse alors valide.
    final pickup = _pickupResolved;
    final dropoff = _dropoffResolved;
    if (pickup == null || dropoff == null) {
      setState(() {
        _errorMessage = context.read<LocaleProvider>().t('delivery_address_invalid_selection');
      });
      return;
    }

    setState(() {
      _phase = _FlowPhase.creating;
      _errorMessage = null;
    });

    try {
      final pickupAddress = MissionAddress(
        line1: pickup.line1,
        city: pickup.city,
        postalCode: pickup.postalCode,
        lat: pickup.lat,
        lng: pickup.lng,
        formattedAddress: pickup.formattedAddress,
        placeId: pickup.placeId,
      );
      final dropoffAddress = MissionAddress(
        line1: dropoff.line1,
        city: dropoff.city,
        postalCode: dropoff.postalCode,
        lat: dropoff.lat,
        lng: dropoff.lng,
        formattedAddress: dropoff.formattedAddress,
        placeId: dropoff.placeId,
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
        _errorMessage = _describeError(e, genericKey: 'delivery_mission_error');
      });
    }
  }

  // Phase 7, Bloc AB (AB-3, gap AB-3-A) — GAP RÉEL corrigé : cette fonction
  // renvoyait AUPARAVANT directement `e.message`/`e.toString()` au client
  // final — c'est-à-dire le message BRUT interne du serveur
  // (`CloudFunctionException.message` porte le texte français non traduit
  // de la Cloud Function, ex. "requestQuote: delivery_quotes/xyz introuvable
  // après calculateDeliveryQuote." ou "Aucune configuration tarifaire active
  // (pricing_configs/active)."). Ce texte :
  //   - révèle des noms de collections Firestore internes et de Cloud
  //     Functions ;
  //   - n'est jamais traduit (toujours en français, même en EN/ES ->
  //     mélange de langues, AB-7) ;
  //   - n'est pas "compréhensible" pour un client final (jargon technique).
  // Corrigé : toute erreur métier/backend (hors kill switch, déjà mappé
  // séparément vers `service_temporarily_unavailable`) est désormais
  // toujours mappée vers la clé i18n générique déjà existante et traduite
  // FR/EN/ES passée par l'appelant (`genericKey` : `delivery_quote_error`
  // pour le devis, `delivery_mission_error` pour la création de mission —
  // ces deux clés existaient déjà dans app_strings.dart mais
  // `delivery_mission_error` n'était jamais effectivement utilisée avant ce
  // correctif). Le message technique brut n'est plus jamais affiché au
  // client — il reste disponible pour le débogage via les logs
  // (`debugPrint`) uniquement, jamais dans l'UI.
  String _describeError(Object e, {required String genericKey}) {
    // 🔒 Phase 7, Bloc X (X-10) — un refus par kill switch
    // (`accept_new_delivery_requests`/`payments_enabled` désactivé côté
    // `system_config/runtime_flags`) doit afficher le message générique
    // traduit, JAMAIS le message brut du serveur. Vérifié AVANT le cas
    // générique ci-dessous.
    if (isKillSwitchException(e)) {
      return context.read<LocaleProvider>().t('service_temporarily_unavailable');
    }
    if (e is CloudFunctionException || e is BackendNotConfiguredException) {
      debugPrint('DeliveryRequestFlowScreen error (not shown to user): $e');
      return context.read<LocaleProvider>().t(genericKey);
    }
    // Erreur inattendue (ex: exception réseau brute non enveloppée par le
    // repository) : message générique également, jamais `e.toString()`.
    debugPrint('DeliveryRequestFlowScreen unexpected error (not shown to user): $e');
    return context.read<LocaleProvider>().t(genericKey);
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
// MOVI-K — CORRECTION UX LIVRAISON (adresses réelles + autocomplete +
// géocodage) : remplace intégralement les anciens champs séparés
// adresse/ville/code postal/latitude/longitude par UN SEUL champ par
// adresse (pickup/dropoff), avec suggestions réelles en direct
// (`AddressAutocompleteField`). Le client ne voit et ne saisit plus JAMAIS
// aucune coordonnée — tout est extrait automatiquement en arrière-plan à
// la sélection d'une suggestion (voir `AddressAutocompleteField.onResolved`,
// qui remonte un `ResolvedAddress` complet au parent).
class _Step2Addresses extends StatelessWidget {
  final TextEditingController pickupController;
  final TextEditingController dropoffController;
  final TextEditingController contactController;
  final TextEditingController accessController;
  final ValueChanged<ResolvedAddress> onPickupResolved;
  final VoidCallback onPickupInvalidated;
  final ValueChanged<ResolvedAddress> onDropoffResolved;
  final VoidCallback onDropoffInvalidated;

  const _Step2Addresses({
    required this.pickupController,
    required this.dropoffController,
    required this.contactController,
    required this.accessController,
    required this.onPickupResolved,
    required this.onPickupInvalidated,
    required this.onDropoffResolved,
    required this.onDropoffInvalidated,
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
          AddressAutocompleteField(
            controller: pickupController,
            label: t('delivery_pickup_address'),
            onResolved: onPickupResolved,
            onInvalidated: onPickupInvalidated,
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
          AddressAutocompleteField(
            controller: dropoffController,
            label: t('delivery_dropoff_address'),
            onResolved: onDropoffResolved,
            onInvalidated: onDropoffInvalidated,
          ),
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
      // Phase 7, Bloc AB (AB-3-A) — `errorMessage` est désormais TOUJOURS un
      // texte déjà traduit et compréhensible (voir `_describeError()`),
      // jamais le message brut du serveur. On l'affiche donc directement
      // (une seule fois, pas de doublon avec un titre générique fixe).
      return StepFormCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMessage!, style: const TextStyle(color: AppColors.error))),
              ],
            ),
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
