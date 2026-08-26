import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/mechanic_request.dart';
import '../../models/enums.dart';
import '../../models/provider_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/mechanic_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/demo_data_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/coming_soon_badge.dart';
import '../../widgets/section_title.dart';
import '../../widgets/step_progress_form.dart';

class MechanicRequestFlowScreen extends StatefulWidget {
  final String locale;
  const MechanicRequestFlowScreen({super.key, required this.locale});

  @override
  State<MechanicRequestFlowScreen> createState() => _MechanicRequestFlowScreenState();
}

class _MechanicRequestFlowScreenState extends State<MechanicRequestFlowScreen> {
  late MechanicRequest _request;
  ProviderProfile? _selectedMechanic;
  bool _submitted = false;

  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _yearController = TextEditingController();
  final _engineController = TextEditingController();
  final _vinController = TextEditingController();
  final _plateController = TextEditingController();
  final _mileageController = TextEditingController();
  final _problemController = TextEditingController();
  final _locationController = TextEditingController();
  final _accessController = TextEditingController();
  final List<String> _selectedServices = [];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final mechanicProvider = context.read<MechanicRequestProvider>();
    _request = mechanicProvider.createDraft(auth.currentUser?.id ?? 'guest');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return AppShell(
        locale: widget.locale,
        showFooter: false,
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                Text(t('mechanic_sign_in_required'), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(onPressed: () => context.go('/${widget.locale}/connexion'), child: Text(t('auth_sign_in'))),
              ],
            ),
          ),
        ),
      );
    }

    if (_submitted) {
      return AppShell(
        locale: widget.locale,
        showFooter: false,
        child: _MechanicSubmittedConfirmation(locale: widget.locale, mechanic: _selectedMechanic),
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
              SectionTitle(title: t('mechanic_hero_headline')),
              const SizedBox(height: 28),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: StepProgressForm(
                  stepTitles: [
                    t('mechanic_step1_title'),
                    t('mechanic_step2_title'),
                    t('mechanic_step3_title'),
                    t('mechanic_step4_title'),
                    t('mechanic_step5_title'),
                  ],
                  nextLabel: t('common_next'),
                  backLabel: t('common_back'),
                  submitLabel: t('mechanic_send_request'),
                  canProceed: (step) {
                    if (step == 0) return _makeController.text.trim().isNotEmpty && _modelController.text.trim().isNotEmpty;
                    if (step == 1) return _selectedServices.isNotEmpty;
                    if (step == 2) return _locationController.text.trim().isNotEmpty;
                    if (step == 3) return _selectedMechanic != null;
                    return true;
                  },
                  onStepChanged: (_) {},
                  onComplete: _handleSubmit,
                  stepBuilders: [
                    (context) => _Step1Vehicle(
                          makeController: _makeController,
                          modelController: _modelController,
                          yearController: _yearController,
                          engineController: _engineController,
                          vinController: _vinController,
                          plateController: _plateController,
                          mileageController: _mileageController,
                          canMove: _request.canMoveSafely,
                          onCanMoveChanged: (v) => setState(() => _request.canMoveSafely = v),
                        ),
                    (context) => _Step2Problem(
                          services: DemoDataService.mechanicServices,
                          selected: _selectedServices,
                          onToggle: (s) => setState(() => _selectedServices.contains(s) ? _selectedServices.remove(s) : _selectedServices.add(s)),
                          problemController: _problemController,
                          urgency: _request.urgency,
                          onUrgencyChanged: (v) => setState(() => _request.urgency = v),
                          partsPurchased: _request.partsAlreadyPurchased,
                          onPartsPurchasedChanged: (v) => setState(() => _request.partsAlreadyPurchased = v),
                        ),
                    (context) => _Step3Location(
                          locationController: _locationController,
                          accessController: _accessController,
                          locationType: _request.locationType,
                          onLocationTypeChanged: (v) => setState(() => _request.locationType = v),
                          preferredDate: _request.preferredDate,
                          onDatePicked: (d) => setState(() => _request.preferredDate = d),
                          preferredTime: _request.preferredTime,
                          onTimeChanged: (v) => setState(() => _request.preferredTime = v),
                          safeWorkspace: _request.safeWorkspaceConfirmed,
                          onSafeWorkspaceChanged: (v) => setState(() => _request.safeWorkspaceConfirmed = v),
                        ),
                    (context) => _Step4Matching(
                          selected: _selectedMechanic,
                          onSelected: (p) => setState(() => _selectedMechanic = p),
                        ),
                    (context) => _Step5Summary(
                          request: _request,
                          mechanic: _selectedMechanic,
                          selectedServices: _selectedServices,
                          paymentMethod: _request.paymentMethod,
                          onPaymentChanged: (m) => setState(() => _request.paymentMethod = m),
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

  void _handleSubmit() {
    _request.vehicleMake = _makeController.text.trim();
    _request.vehicleModel = _modelController.text.trim();
    _request.vehicleYear = _yearController.text.trim();
    _request.engine = _engineController.text.trim();
    _request.vin = _vinController.text.trim();
    _request.plate = _plateController.text.trim();
    _request.mileage = _mileageController.text.trim();
    _request.problemDescription = _problemController.text.trim();
    _request.location = _locationController.text.trim();
    _request.accessInstructions = _accessController.text.trim();
    _request.selectedServices = _selectedServices;

    final provider = context.read<MechanicRequestProvider>();
    provider.updateRequest(_request);
    provider.submit(_request.id, mechanicId: _selectedMechanic?.id, estimatedPrice: _estimate());

    setState(() => _submitted = true);
  }

  double _estimate() {
    if (_selectedMechanic == null) return 0;
    return _selectedMechanic!.minimumFee + _selectedMechanic!.travelFee;
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _engineController.dispose();
    _vinController.dispose();
    _plateController.dispose();
    _mileageController.dispose();
    _problemController.dispose();
    _locationController.dispose();
    _accessController.dispose();
    super.dispose();
  }
}

// -------- Step 1 --------
class _Step1Vehicle extends StatelessWidget {
  final TextEditingController makeController, modelController, yearController, engineController, vinController, plateController, mileageController;
  final bool canMove;
  final ValueChanged<bool> onCanMoveChanged;

  const _Step1Vehicle({
    required this.makeController,
    required this.modelController,
    required this.yearController,
    required this.engineController,
    required this.vinController,
    required this.plateController,
    required this.mileageController,
    required this.canMove,
    required this.onCanMoveChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return StepFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: TextField(controller: makeController, decoration: InputDecoration(labelText: t('mechanic_vehicle_make')))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: modelController, decoration: InputDecoration(labelText: t('mechanic_vehicle_model')))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(controller: yearController, decoration: InputDecoration(labelText: t('mechanic_vehicle_year')), keyboardType: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: engineController, decoration: InputDecoration(labelText: '${t('mechanic_vehicle_engine')} (${t('common_optional')})'))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextField(controller: vinController, decoration: InputDecoration(labelText: t('mechanic_vehicle_vin')))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: plateController, decoration: InputDecoration(labelText: t('mechanic_vehicle_plate')))),
          ]),
          const SizedBox(height: 16),
          TextField(controller: mileageController, decoration: InputDecoration(labelText: t('mechanic_vehicle_mileage')), keyboardType: TextInputType.number),
          const SizedBox(height: 20),
          Text(t('mechanic_vehicle_can_move'), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              ChoiceChip(label: Text(t('common_yes')), selected: canMove, onSelected: (_) => onCanMoveChanged(true)),
              const SizedBox(width: 8),
              ChoiceChip(label: Text(t('common_no')), selected: !canMove, onSelected: (_) => onCanMoveChanged(false)),
            ],
          ),
        ],
      ),
    );
  }
}

// -------- Step 2 --------
class _Step2Problem extends StatelessWidget {
  final List<String> services;
  final List<String> selected;
  final ValueChanged<String> onToggle;
  final TextEditingController problemController;
  final String urgency;
  final ValueChanged<String> onUrgencyChanged;
  final bool partsPurchased;
  final ValueChanged<bool> onPartsPurchasedChanged;

  const _Step2Problem({
    required this.services,
    required this.selected,
    required this.onToggle,
    required this.problemController,
    required this.urgency,
    required this.onUrgencyChanged,
    required this.partsPurchased,
    required this.onPartsPurchasedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return StepFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('mechanic_select_services_title'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: services.map((s) => FilterChip(label: Text(t(s)), selected: selected.contains(s), onSelected: (_) => onToggle(s))).toList(),
          ),
          const SizedBox(height: 20),
          TextField(controller: problemController, maxLines: 4, decoration: InputDecoration(labelText: t('mechanic_problem_description_label'))),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('mechanic_photo_video_demo_notice'))));
            },
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(t('common_upload_photo')),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(t('mechanic_disclaimer'), style: const TextStyle(fontSize: 12, height: 1.4))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(t('mechanic_urgency_title'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: Text(t('mechanic_urgency_normal')), selected: urgency == 'normal', onSelected: (_) => onUrgencyChanged('normal')),
              ChoiceChip(label: Text(t('mechanic_urgency_urgent')), selected: urgency == 'urgent', onSelected: (_) => onUrgencyChanged('urgent')),
              ChoiceChip(label: Text(t('mechanic_urgency_emergency')), selected: urgency == 'emergency', onSelected: (_) => onUrgencyChanged('emergency')),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t('mechanic_parts_already_purchased'), style: const TextStyle(fontSize: 14)),
            value: partsPurchased,
            onChanged: onPartsPurchasedChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

// -------- Step 3 --------
class _Step3Location extends StatelessWidget {
  final TextEditingController locationController, accessController;
  final String locationType;
  final ValueChanged<String> onLocationTypeChanged;
  final DateTime? preferredDate;
  final ValueChanged<DateTime> onDatePicked;
  final String preferredTime;
  final ValueChanged<String> onTimeChanged;
  final bool safeWorkspace;
  final ValueChanged<bool> onSafeWorkspaceChanged;

  const _Step3Location({
    required this.locationController,
    required this.accessController,
    required this.locationType,
    required this.onLocationTypeChanged,
    required this.preferredDate,
    required this.onDatePicked,
    required this.preferredTime,
    required this.onTimeChanged,
    required this.safeWorkspace,
    required this.onSafeWorkspaceChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final windows = ['8h - 11h', '11h - 14h', '14h - 17h', '17h - 20h'];
    return StepFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('mechanic_location_type_title'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: Text(t('mechanic_location_type_home')), selected: locationType == 'home', onSelected: (_) => onLocationTypeChanged('home')),
              ChoiceChip(label: Text(t('mechanic_location_type_work')), selected: locationType == 'work', onSelected: (_) => onLocationTypeChanged('work')),
              ChoiceChip(label: Text(t('mechanic_location_type_job_site')), selected: locationType == 'job-site', onSelected: (_) => onLocationTypeChanged('job-site')),
              ChoiceChip(label: Text(t('mechanic_location_type_roadside')), selected: locationType == 'roadside', onSelected: (_) => onLocationTypeChanged('roadside')),
            ],
          ),
          const SizedBox(height: 20),
          TextField(controller: locationController, decoration: InputDecoration(labelText: t('mechanic_vehicle_address_label'), prefixIcon: const Icon(Icons.location_on_outlined))),
          if (locationType == 'roadside') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t('mechanic_roadside_danger_warning'), style: const TextStyle(fontSize: 12.5))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 60)));
              if (picked != null) onDatePicked(picked);
            },
            child: InputDecorator(
              decoration: InputDecoration(labelText: t('mechanic_preferred_date_label'), prefixIcon: const Icon(Icons.calendar_today_outlined)),
              child: Text(preferredDate == null ? '—' : '${preferredDate!.day}/${preferredDate!.month}/${preferredDate!.year}'),
            ),
          ),
          const SizedBox(height: 16),
          Text(t('mechanic_preferred_time_label'), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: windows.map((w) => ChoiceChip(label: Text(w), selected: preferredTime == w, onSelected: (_) => onTimeChanged(w))).toList()),
          const SizedBox(height: 16),
          TextField(controller: accessController, decoration: InputDecoration(labelText: t('mechanic_access_instructions_label'))),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t('mechanic_safe_workspace_confirmation'), style: const TextStyle(fontSize: 14)),
            value: safeWorkspace,
            onChanged: onSafeWorkspaceChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

// -------- Step 4 --------
class _Step4Matching extends StatelessWidget {
  final ProviderProfile? selected;
  final ValueChanged<ProviderProfile> onSelected;
  const _Step4Matching({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(t('mechanic_available_mechanics_title'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            const DemoDataBadge(),
          ],
        ),
        const SizedBox(height: 14),
        ...DemoDataService.mechanics.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _MechanicCard(provider: p, selected: selected?.id == p.id, onTap: () => onSelected(p)),
            )),
      ],
    );
  }
}

class _MechanicCard extends StatelessWidget {
  final ProviderProfile provider;
  final bool selected;
  final VoidCallback onTap;
  const _MechanicCard({required this.provider, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.success : AppColors.border, width: selected ? 2 : 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(radius: 28, backgroundImage: NetworkImage(provider.profilePhotoUrl)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(provider.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    if (provider.identityVerified) const Icon(Icons.verified, color: AppColors.success, size: 16),
                    if (provider.emergencyAvailable) ...[
                      const SizedBox(width: 6),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Text(t('mechanic_emergency_badge'), style: const TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.w700))),
                    ],
                  ]),
                  const SizedBox(height: 4),
                  Text(provider.specialties.take(3).join(' · '), style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                    Text(' ${provider.rating} · ${provider.completedJobs} ${t('mechanic_rating_jobs_suffix')}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${provider.hourlyRate.toStringAsFixed(0)}\$/h', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success)),
                const SizedBox(height: 4),
                Radio<bool>(value: true, groupValue: selected ? true : null, onChanged: (_) => onTap()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -------- Step 5 --------
class _Step5Summary extends StatelessWidget {
  final MechanicRequest request;
  final ProviderProfile? mechanic;
  final List<String> selectedServices;
  final PaymentMethod paymentMethod;
  final ValueChanged<PaymentMethod> onPaymentChanged;

  const _Step5Summary({
    required this.request,
    required this.mechanic,
    required this.selectedServices,
    required this.paymentMethod,
    required this.onPaymentChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return StepFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mechanic != null) ...[
            Row(children: [
              CircleAvatar(radius: 24, backgroundImage: NetworkImage(mechanic!.profilePhotoUrl)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(mechanic!.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(mechanic!.businessName ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ]),
            ]),
            const Divider(height: 32),
          ],
          Text('${t('mechanic_services_label')} ${selectedServices.map(t).join(', ')}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Text('${t('mechanic_vehicle_summary_label')}: ${request.vehicleMake} ${request.vehicleModel} (${request.vehicleYear})', style: const TextStyle(color: AppColors.textSecondary)),
          const Divider(height: 32),
          Text(t('mechanic_initial_price_estimate_title'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              _PriceRow(t('mechanic_minimum_service_fee'), mechanic?.minimumFee ?? 0),
              _PriceRow(t('mechanic_travel_fee'), mechanic?.travelFee ?? 0),
              const Divider(),
              _PriceRow(t('mechanic_total_estimated'), (mechanic?.minimumFee ?? 0) + (mechanic?.travelFee ?? 0), bold: true),
            ]),
          ),
          const SizedBox(height: 10),
          Text(t('mechanic_disclaimer'), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
          const Divider(height: 32),
          Text(t('mechanic_payment_method_title'), style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: Text(t('payment_cash')), selected: paymentMethod == PaymentMethod.cash, onSelected: (_) => onPaymentChanged(PaymentMethod.cash)),
            ChoiceChip(label: Text(t('payment_interac')), selected: paymentMethod == PaymentMethod.interac, onSelected: (_) => onPaymentChanged(PaymentMethod.interac)),
            ChoiceChip(label: Text(t('payment_arrangement')), selected: paymentMethod == PaymentMethod.arrangement, onSelected: (_) => onPaymentChanged(PaymentMethod.arrangement)),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppColors.info, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(t('mechanic_not_guaranteed_booking_notice'), style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
            ]),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  const _PriceRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w400)),
        Text('${value.toStringAsFixed(2)} \$', style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: bold ? AppColors.success : null)),
      ]),
    );
  }
}

class _MechanicSubmittedConfirmation extends StatelessWidget {
  final String locale;
  final ProviderProfile? mechanic;
  const _MechanicSubmittedConfirmation({required this.locale, required this.mechanic});

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
              Container(width: 80, height: 80, decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), shape: BoxShape.circle), child: const Icon(Icons.check_circle, color: AppColors.success, size: 44)),
              const SizedBox(height: 24),
              Text(t('mechanic_status_submitted'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(t('mechanic_status_awaiting'), textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 28),
              if (mechanic != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                  child: Row(children: [
                    CircleAvatar(backgroundImage: NetworkImage(mechanic!.profilePhotoUrl)),
                    const SizedBox(width: 12),
                    Expanded(child: Text('${t('mechanic_request_sent_to')} ${mechanic!.fullName}', style: const TextStyle(fontWeight: FontWeight.w600))),
                  ]),
                ),
              const SizedBox(height: 28),
              ElevatedButton(onPressed: () => context.go('/$locale/tableau-de-bord'), child: Text(t('nav_my_requests'))),
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
