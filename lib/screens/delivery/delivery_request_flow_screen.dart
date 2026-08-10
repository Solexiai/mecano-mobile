import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../models/delivery_request.dart';
import '../../models/enums.dart';
import '../../models/provider_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/delivery_provider.dart';
import '../../providers/locale_provider.dart';
import '../../services/demo_data_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/coming_soon_badge.dart';
import '../../widgets/section_title.dart';
import '../../widgets/step_progress_form.dart';

class DeliveryRequestFlowScreen extends StatefulWidget {
  final String locale;
  const DeliveryRequestFlowScreen({super.key, required this.locale});

  @override
  State<DeliveryRequestFlowScreen> createState() => _DeliveryRequestFlowScreenState();
}

class _DeliveryRequestFlowScreenState extends State<DeliveryRequestFlowScreen> {
  late DeliveryRequest _request;
  ProviderProfile? _selectedProvider;
  bool _submitted = false;

  final _descController = TextEditingController();
  final _dimensionsController = TextEditingController();
  final _weightController = TextEditingController();
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _contactController = TextEditingController();
  final _accessController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedCategory = '';

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final delivery = context.read<DeliveryProvider>();
    final customerId = auth.currentUser?.id ?? 'guest';
    _request = delivery.createDraft(customerId);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return AppShell(
        locale: widget.locale,
        showFooter: false,
        child: _LoginRequiredNotice(locale: widget.locale, message: 'Connectez-vous pour créer une demande de livraison.'),
      );
    }

    if (_submitted) {
      return AppShell(
        locale: widget.locale,
        showFooter: false,
        child: _SubmittedConfirmation(
          locale: widget.locale,
          request: _request,
          provider: _selectedProvider,
        ),
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
                    t('delivery_step2_title'),
                    t('delivery_step3_title'),
                    t('delivery_step4_title'),
                  ],
                  nextLabel: t('common_next'),
                  backLabel: t('common_back'),
                  submitLabel: t('delivery_confirm_request'),
                  canProceed: (step) {
                    if (step == 0) return _selectedCategory.isNotEmpty && _descController.text.trim().isNotEmpty;
                    if (step == 1) return _pickupController.text.trim().isNotEmpty && _dropoffController.text.trim().isNotEmpty;
                    if (step == 2) return _selectedProvider != null;
                    return true;
                  },
                  onStepChanged: (_) {},
                  onComplete: _handleSubmit,
                  stepBuilders: [
                    (context) => _Step1ItemInfo(
                          categories: DemoDataService.deliveryCategories,
                          selectedCategory: _selectedCategory,
                          onCategorySelected: (c) => setState(() => _selectedCategory = c),
                          descController: _descController,
                          dimensionsController: _dimensionsController,
                          weightController: _weightController,
                          quantity: _request.quantity,
                          onQuantityChanged: (q) => setState(() => _request.quantity = q),
                          needsStairs: _request.needsStairsHandling,
                          onStairsChanged: (v) => setState(() => _request.needsStairsHandling = v),
                          loadingHelp: _request.needsLoadingAssistance,
                          onLoadingChanged: (v) => setState(() => _request.needsLoadingAssistance = v),
                          unloadingHelp: _request.needsUnloadingAssistance,
                          onUnloadingChanged: (v) => setState(() => _request.needsUnloadingAssistance = v),
                        ),
                    (context) => _Step2Locations(
                          pickupController: _pickupController,
                          dropoffController: _dropoffController,
                          contactController: _contactController,
                          accessController: _accessController,
                          preferredDate: _request.preferredDate,
                          onDatePicked: (d) => setState(() => _request.preferredDate = d),
                          timeWindow: _request.preferredTimeWindow,
                          onTimeWindowChanged: (v) => setState(() => _request.preferredTimeWindow = v),
                        ),
                    (context) => _Step3Matching(
                          selected: _selectedProvider,
                          onSelected: (p) => setState(() => _selectedProvider = p),
                        ),
                    (context) => _Step4Booking(
                          request: _request,
                          provider: _selectedProvider,
                          notesController: _notesController,
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
    _request.itemCategory = _selectedCategory;
    _request.description = _descController.text.trim();
    _request.dimensions = _dimensionsController.text.trim();
    _request.weight = _weightController.text.trim();
    _request.pickupAddress = _pickupController.text.trim();
    _request.deliveryAddress = _dropoffController.text.trim();
    _request.contactInstructions = _contactController.text.trim();
    _request.accessDetails = _accessController.text.trim();
    _request.customerNotes = _notesController.text.trim();

    final delivery = context.read<DeliveryProvider>();
    delivery.updateRequest(_request);
    delivery.submit(_request.id, providerId: _selectedProvider?.id, quotedPrice: _estimatePrice());

    setState(() => _submitted = true);
  }

  double _estimatePrice() {
    if (_selectedProvider == null) return 0;
    final p = _selectedProvider!;
    double price = p.minimumFee;
    if (_request.needsLoadingAssistance) price += 15;
    if (_request.needsUnloadingAssistance) price += 15;
    if (_request.needsStairsHandling) price += 10;
    return price;
  }

  @override
  void dispose() {
    _descController.dispose();
    _dimensionsController.dispose();
    _weightController.dispose();
    _pickupController.dispose();
    _dropoffController.dispose();
    _contactController.dispose();
    _accessController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

// ---------------- Step 1 ----------------
class _Step1ItemInfo extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;
  final TextEditingController descController;
  final TextEditingController dimensionsController;
  final TextEditingController weightController;
  final int quantity;
  final ValueChanged<int> onQuantityChanged;
  final bool needsStairs;
  final ValueChanged<bool> onStairsChanged;
  final bool loadingHelp;
  final ValueChanged<bool> onLoadingChanged;
  final bool unloadingHelp;
  final ValueChanged<bool> onUnloadingChanged;

  const _Step1ItemInfo({
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
    required this.descController,
    required this.dimensionsController,
    required this.weightController,
    required this.quantity,
    required this.onQuantityChanged,
    required this.needsStairs,
    required this.onStairsChanged,
    required this.loadingHelp,
    required this.onLoadingChanged,
    required this.unloadingHelp,
    required this.onUnloadingChanged,
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
                      label: Text(c),
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
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${t('common_upload_photo')} — sélection de fichiers simulée en mode démo')),
              );
            },
            icon: const Icon(Icons.camera_alt_outlined),
            label: Text(t('common_upload_photo')),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: dimensionsController,
                  decoration: InputDecoration(labelText: '${t('delivery_item_dimensions')} (${t('common_optional')})'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: weightController,
                  decoration: InputDecoration(labelText: '${t('delivery_item_weight')} (${t('common_optional')})'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(t('delivery_item_quantity'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              IconButton(onPressed: quantity > 1 ? () => onQuantityChanged(quantity - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
              Text('$quantity', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              IconButton(onPressed: () => onQuantityChanged(quantity + 1), icon: const Icon(Icons.add_circle_outline)),
            ],
          ),
          const Divider(height: 32),
          _SwitchRow(label: t('delivery_item_stairs'), value: needsStairs, onChanged: onStairsChanged),
          _SwitchRow(label: t('delivery_item_loading_help'), value: loadingHelp, onChanged: onLoadingChanged),
          _SwitchRow(label: t('delivery_item_unloading_help'), value: unloadingHelp, onChanged: onUnloadingChanged),
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

// ---------------- Step 2 ----------------
class _Step2Locations extends StatelessWidget {
  final TextEditingController pickupController;
  final TextEditingController dropoffController;
  final TextEditingController contactController;
  final TextEditingController accessController;
  final DateTime? preferredDate;
  final ValueChanged<DateTime> onDatePicked;
  final String timeWindow;
  final ValueChanged<String> onTimeWindowChanged;

  const _Step2Locations({
    required this.pickupController,
    required this.dropoffController,
    required this.contactController,
    required this.accessController,
    required this.preferredDate,
    required this.onDatePicked,
    required this.timeWindow,
    required this.onTimeWindowChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final windows = ['8h - 11h', '11h - 14h', '14h - 17h', '17h - 20h'];
    return StepFormCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(controller: pickupController, decoration: InputDecoration(labelText: t('delivery_pickup_address'), prefixIcon: const Icon(Icons.trip_origin))),
          const SizedBox(height: 16),
          TextField(controller: dropoffController, decoration: InputDecoration(labelText: t('delivery_dropoff_address'), prefixIcon: const Icon(Icons.location_on_outlined))),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.map_outlined, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              const Expanded(child: Text('Carte et distance estimée', style: TextStyle(color: AppColors.textSecondary, fontSize: 13))),
              const ComingSoonBadge(small: true),
            ],
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
              );
              if (picked != null) onDatePicked(picked);
            },
            child: InputDecorator(
              decoration: InputDecoration(labelText: t('delivery_pref_date'), prefixIcon: const Icon(Icons.calendar_today_outlined)),
              child: Text(preferredDate == null ? '—' : '${preferredDate!.day}/${preferredDate!.month}/${preferredDate!.year}'),
            ),
          ),
          const SizedBox(height: 16),
          Text(t('delivery_pref_time'), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: windows.map((w) => ChoiceChip(label: Text(w), selected: timeWindow == w, onSelected: (_) => onTimeWindowChanged(w))).toList(),
          ),
          const SizedBox(height: 16),
          TextField(controller: contactController, decoration: InputDecoration(labelText: '${t('delivery_contact_instructions')} (${t('common_optional')})')),
          const SizedBox(height: 16),
          TextField(controller: accessController, decoration: InputDecoration(labelText: '${t('delivery_access_details')} (${t('common_optional')})')),
        ],
      ),
    );
  }
}

// ---------------- Step 3 ----------------
class _Step3Matching extends StatelessWidget {
  final ProviderProfile? selected;
  final ValueChanged<ProviderProfile> onSelected;
  const _Step3Matching({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(t('delivery_find_drivers'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            const DemoDataBadge(),
          ],
        ),
        const SizedBox(height: 14),
        ...DemoDataService.drivers.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ProviderCard(provider: p, selected: selected?.id == p.id, onTap: () => onSelected(p)),
            )),
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final ProviderProfile provider;
  final bool selected;
  final VoidCallback onTap;
  const _ProviderCard({required this.provider, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 2 : 1),
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
                  Row(
                    children: [
                      Text(provider.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      if (provider.identityVerified) const Icon(Icons.verified, color: AppColors.success, size: 16),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${provider.vehicleMakeModel ?? ''} · ${provider.city}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: AppColors.warning, size: 16),
                      Text(' ${provider.rating} · ${provider.completedJobs} livraisons', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${provider.minimumFee.toStringAsFixed(0)}\$+', style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
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

// ---------------- Step 4 ----------------
class _Step4Booking extends StatelessWidget {
  final DeliveryRequest request;
  final ProviderProfile? provider;
  final TextEditingController notesController;
  final PaymentMethod paymentMethod;
  final ValueChanged<PaymentMethod> onPaymentChanged;

  const _Step4Booking({
    required this.request,
    required this.provider,
    required this.notesController,
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
          if (provider != null) ...[
            Row(
              children: [
                CircleAvatar(radius: 24, backgroundImage: NetworkImage(provider!.profilePhotoUrl)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(provider!.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(provider!.vehicleMakeModel ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ],
            ),
            const Divider(height: 32),
          ],
          _SummaryRow(label: t('delivery_item_category'), value: request.itemCategory),
          _SummaryRow(label: t('delivery_pickup_address'), value: request.pickupAddress),
          _SummaryRow(label: t('delivery_dropoff_address'), value: request.deliveryAddress),
          _SummaryRow(label: t('delivery_pref_date'), value: request.preferredDate != null ? '${request.preferredDate!.day}/${request.preferredDate!.month}/${request.preferredDate!.year}' : '—'),
          const Divider(height: 32),
          Text('Estimation de prix (indicative)', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                _PriceRow('Frais minimum', provider?.minimumFee ?? 0),
                if (request.needsLoadingAssistance) _PriceRow('Aide au chargement', 15),
                if (request.needsUnloadingAssistance) _PriceRow('Aide au déchargement', 15),
                if (request.needsStairsHandling) _PriceRow('Escaliers', 10),
                const Divider(),
                _PriceRow('Total estimé', _total(), bold: true),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ceci est une estimation. Le prix final sera confirmé avec le fournisseur.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
          ),
          const Divider(height: 32),
          Text('Mode de paiement', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(label: Text(t('payment_cash')), selected: paymentMethod == PaymentMethod.cash, onSelected: (_) => onPaymentChanged(PaymentMethod.cash)),
              ChoiceChip(label: Text(t('payment_interac')), selected: paymentMethod == PaymentMethod.interac, onSelected: (_) => onPaymentChanged(PaymentMethod.interac)),
              ChoiceChip(label: Text(t('payment_arrangement')), selected: paymentMethod == PaymentMethod.arrangement, onSelected: (_) => onPaymentChanged(PaymentMethod.arrangement)),
            ],
          ),
          const SizedBox(height: 20),
          TextField(controller: notesController, maxLines: 2, decoration: InputDecoration(labelText: '${t('delivery_access_details')} (${t('common_optional')})')),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: AppColors.info, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Votre demande sera envoyée pour confirmation du fournisseur — ce n'est pas encore une réservation garantie.",
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _total() {
    double t = provider?.minimumFee ?? 0;
    if (request.needsLoadingAssistance) t += 15;
    if (request.needsUnloadingAssistance) t += 15;
    if (request.needsStairsHandling) t += 10;
    return t;
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w400)),
          Text('${value.toStringAsFixed(2)} \$', style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: bold ? AppColors.primary : null)),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 160, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(child: Text(value.isEmpty ? '—' : value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

class _SubmittedConfirmation extends StatelessWidget {
  final String locale;
  final DeliveryRequest request;
  final ProviderProfile? provider;
  const _SubmittedConfirmation({required this.locale, required this.request, required this.provider});

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
              Text(t('delivery_status_submitted'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                t('delivery_status_awaiting'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 28),
              if (provider != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                  child: Row(
                    children: [
                      CircleAvatar(backgroundImage: NetworkImage(provider!.profilePhotoUrl)),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Demande envoyée à ${provider!.fullName}', style: const TextStyle(fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              const SizedBox(height: 28),
              ElevatedButton(
                onPressed: () => context.go('/$locale/tableau-de-bord'),
                child: Text(t('nav_my_requests')),
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
            ElevatedButton(onPressed: () => context.go('/$locale/connexion'), child: const Text('Se connecter')),
          ],
        ),
      ),
    );
  }
}
