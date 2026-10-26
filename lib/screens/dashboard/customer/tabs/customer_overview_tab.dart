import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../backend/backend_locator.dart';
import '../../../../backend/models/delivery_mission.dart';
import '../../../../core/app_colors.dart';
import '../../../../providers/firebase_auth_provider.dart';
import '../../../../providers/locale_provider.dart';
import '../../../../services/account/saved_addresses.dart';
import '../../../../widgets/home_address_sheet.dart';
import '../customer_mission_view.dart';

/// Customer home, Uber-style (owner mockup validated 2026-10-25): the
/// delivery in progress first, one big "book" button, then the latest
/// deliveries with "Refaire". Real Firebase data only; no statistics.
class CustomerOverviewTab extends StatelessWidget {
  final void Function(int) onGoToTab;
  const CustomerOverviewTab({super.key, required this.onGoToTab});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FirebaseAuthProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final locale = localeProvider.locale;
    final t = localeProvider.t;

    if (!auth.isSignedIn || auth.effectiveUid == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(t('delivery_login_required'), textAlign: TextAlign.center),
        ),
      );
    }

    // `effectiveUid`/`effectiveDisplayName`: the test seam of
    // FirebaseAuthProvider (same runtime value as `user!.uid`).
    final customerId = auth.effectiveUid!;
    // Greet by first name only; never by email address.
    final displayName = (auth.effectiveDisplayName ?? '').trim();
    final firstName = displayName.isEmpty || displayName.contains('@')
        ? ''
        : displayName.split(' ').first;

    return StreamBuilder<List<DeliveryMission>>(
      stream: BackendLocator.missionRepository.watchCustomerMissions(customerId),
      builder: (context, snapshot) {
        // A failed stream is an error, never an empty history (AB-2).
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 32),
                  const SizedBox(height: 8),
                  Text(t('requests_error'), textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        }
        final deliveries = snapshot.data ?? const <DeliveryMission>[];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final active = deliveries.where(isCustomerActive).toList();
        final recent = deliveries.where(isCustomerPast).take(3).toList();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      firstName.isEmpty
                          ? t('overview_greeting')
                          : '${t('overview_greeting')} $firstName',
                      key: const ValueKey('customer-greeting'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(),
                    ),
                  for (final m in active) ...[
                    _ActiveDeliveryCard(mission: m, locale: locale, t: t),
                    const SizedBox(height: 14),
                  ],
                  _BookButton(
                    locale: locale,
                    onTap: () => context.go('/$locale/livraison/demande'),
                  ),
                  const SizedBox(height: 22),
                  PickupShortcuts(uid: customerId, locale: locale),
                  const SizedBox(height: 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _tr(locale, 'Récemment', 'Recent', 'Recientes'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      TextButton(
                        onPressed: () => onGoToTab(1),
                        child: Text(t('overview_see_all')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (!isLoading && deliveries.isEmpty)
                    _EmptyState(t: t, onCreate: () => context.go('/$locale/livraison/demande'))
                  else if (!isLoading && recent.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _tr(
                          locale,
                          'Vos livraisons terminées apparaîtront ici.',
                          'Your finished deliveries will appear here.',
                          'Tus entregas terminadas aparecerán aquí.',
                        ),
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    for (final m in recent)
                      CustomerDeliveryRow(mission: m, locale: locale, t: t),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _tr(String locale, String fr, String en, String es) => locale == 'en'
    ? en
    : locale == 'es'
    ? es
    : fr;

/// The delivery in progress: orange while a driver is sought, navy once a
/// driver accepted, with the 4-step progress and the driver's first name.
class _ActiveDeliveryCard extends StatelessWidget {
  const _ActiveDeliveryCard({required this.mission, required this.locale, required this.t});
  final DeliveryMission mission;
  final String locale;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    final m = mission;
    final searching = m.isOpenForAcceptance;
    final fg = searching ? AppColors.textPrimary : Colors.white;
    final muted = searching ? AppColors.textSecondary : const Color(0xFFC9D6EF);
    final progress = customerProgress(m);
    final driver = (m.driverDisplayName ?? '').trim();
    final when = customerMissionDate(m);
    return Container(
      key: ValueKey('customer-active-${m.id}'),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: searching ? const Color(0xFFFFF4E8) : AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        border: searching ? Border.all(color: const Color(0xFFF3C99B), width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: searching ? const Color(0xFFB85E10) : Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                customerStatusLabel(m, locale),
                style: TextStyle(
                  color: searching ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            customerMissionTitle(m, locale, t),
            style: TextStyle(color: fg, fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(customerMissionRoute(m, locale), style: TextStyle(color: muted, fontSize: 15)),
          Text(
            '${customerDateLabel(when, locale)} · ${customerMoney(m, locale)}',
            style: TextStyle(color: muted, fontSize: 15),
          ),
          const SizedBox(height: 12),
          if (searching)
            Text(
              _tr(
                locale,
                'Les chauffeurs de la région voient vos photos. Rien n’est débité avant qu’un chauffeur accepte.',
                'Drivers in the area see your photos. Nothing is charged before a driver accepts.',
                'Los conductores de la zona ven tus fotos. No se cobra nada antes de que un conductor acepte.',
              ),
              style: TextStyle(color: muted),
            )
          else ...[
            ExcludeSemantics(
              child: Row(
                children: [
                  for (var i = 1; i <= 4; i++) ...[
                    if (i > 1) const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          color: i <= progress ? Colors.white : const Color(0xFF3C5A8F),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (driver.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B3A72),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFFE6EDFA),
                      child: Text(
                        driver.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            driver.split(' ').first,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          Text(
                            _tr(locale, 'Votre chauffeur', 'Your driver', 'Tu conductor'),
                            style: const TextStyle(color: Color(0xFFC9D6EF)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            key: ValueKey('customer-follow-${m.id}'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              backgroundColor: searching ? AppColors.primary : Colors.white,
              foregroundColor: searching ? Colors.white : AppColors.primary,
              textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => context.go('/$locale/livraison/suivi/${m.id}'),
            icon: Icon(searching ? Icons.receipt_long_outlined : Icons.map_outlined),
            label: Text(
              searching
                  ? _tr(locale, 'Voir ma demande', 'See my request', 'Ver mi solicitud')
                  : _tr(locale, 'Suivre ma livraison', 'Track my delivery', 'Seguir mi entrega'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BookButton extends StatelessWidget {
  const _BookButton({required this.locale, required this.onTap});
  final String locale;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF2F4F8),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      key: const ValueKey('customer-book'),
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.local_shipping_outlined, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _tr(locale, 'Faire livrer un article', 'Get an item delivered', 'Enviar un artículo'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    _tr(locale, 'Votre prix tout de suite, avec une photo', 'Your price right away, with a photo', 'Tu precio al instante, con una foto'),
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      ),
    ),
  );
}

/// One delivery in a list: what, when, price, route, status, and "Refaire"
/// for a finished one. Opens the delivery's page (tracking or receipt).
class CustomerDeliveryRow extends StatelessWidget {
  const CustomerDeliveryRow({
    super.key,
    required this.mission,
    required this.locale,
    required this.t,
  });
  final DeliveryMission mission;
  final String locale;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    final m = mission;
    final colors = customerStatusColors(m);
    final uid = context.read<FirebaseAuthProvider>().effectiveUid;
    return InkWell(
      key: ValueKey('customer-delivery-${m.id}'),
      onTap: () => context.go('/$locale/livraison/suivi/${m.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFEDF0F4))),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE3E8F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customerMissionTitle(m, locale, t),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    customerMissionRoute(m, locale),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  Text(
                    '${customerDateLabel(customerMissionDate(m), locale)} · ${customerMoney(m, locale)}',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: colors.$1,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      customerStatusLabel(m, locale),
                      style: TextStyle(color: colors.$2, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            if (isCustomerPast(m) && m.pickupAddress != null && m.dropoffAddress != null) ...[
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: ValueKey('rebook-${m.id}'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: const StadiumBorder(),
                ),
                onPressed: () => rebookDelivery(context, m, locale: locale, uid: uid),
                icon: const Icon(Icons.replay, size: 18),
                label: Text(_tr(locale, 'Refaire', 'Rebook', 'Repetir')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String Function(String) t;
  final VoidCallback onCreate;
  const _EmptyState({required this.t, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          const Icon(Icons.inbox_outlined, size: 40, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Text(t('overview_empty_title'), style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          ElevatedButton(onPressed: onCreate, child: Text(t('overview_empty_cta'))),
        ],
      ),
    );
  }
}

/// "Ramasser à" (owner mockup 2026-10-25, decided 2026-10-26): one tap
/// opens a booking already filled in. A store fills the pickup search
/// ("IKEA Granby"), the customer picks their store in the suggestions; the
/// saved home address becomes the drop-off. "Maison" picks up at home.
class PickupShortcuts extends StatefulWidget {
  const PickupShortcuts({super.key, required this.uid, required this.locale});
  final String uid, locale;
  @override
  State<PickupShortcuts> createState() => _PickupShortcutsState();
}

class _PickupShortcutsState extends State<PickupShortcuts> {
  Map<String, dynamic>? _home;
  bool _loaded = false;

  static const stores = [
    ('ikea', 'IKEA'),
    ('costco', 'Costco'),
    ('canadian_tire', 'Canadian Tire'),
  ];

  @override
  void initState() {
    super.initState();
    SavedAddresses.instance.home(widget.uid).then((home) {
      if (mounted) {
        setState(() {
          _home = home;
          _loaded = true;
        });
      }
    });
  }

  String tr(String fr, String en, String es) => _tr(widget.locale, fr, en, es);

  Future<Map<String, dynamic>?> _askHome() async {
    final saved = await showHomeAddressSheet(
      context,
      uid: widget.uid,
      locale: widget.locale,
      current: _home,
    );
    if (saved != null && mounted) setState(() => _home = saved);
    return saved;
  }

  Future<void> _start({
    Map<String, dynamic>? pickup,
    String? pickupText,
    required String shortcut,
  }) => startPrefilledBooking(
    context,
    locale: widget.locale,
    uid: widget.uid,
    pickup: pickup,
    dropoff: shortcut == 'home' ? null : _home,
    pickupText: pickupText,
    shortcut: shortcut,
  );

  @override
  Widget build(BuildContext context) {
    final city = (_home?['city'] as String? ?? '').trim();
    Widget chip(String id, IconData icon, String label, VoidCallback onTap) =>
        ActionChip(
          key: ValueKey('shortcut-$id'),
          avatar: Icon(icon, size: 18, color: AppColors.primary),
          label: Text(label),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: const BorderSide(color: AppColors.border),
          ),
          onPressed: onTap,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          tr('Ramasser à', 'Pick up at', 'Recoger en'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip('home', Icons.home_outlined, tr('Maison', 'Home', 'Casa'), () async {
              final home = _home ?? await _askHome();
              if (home != null && mounted) {
                await _start(pickup: home, shortcut: 'home');
              }
            }),
            for (final (id, name) in stores)
              chip(
                id,
                Icons.store_outlined,
                name,
                () => _start(
                  pickupText: city.isEmpty ? name : '$name $city',
                  shortcut: id,
                ),
              ),
            chip(
              'marketplace',
              Icons.sell_outlined,
              'Marketplace',
              () => _start(shortcut: 'marketplace'),
            ),
          ],
        ),
        if (_loaded && _home == null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('shortcut-add-home'),
              onPressed: _askHome,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: Text(
                tr(
                  'Ajouter mon adresse (Maison) pour aller plus vite',
                  'Add my address (Home) to go faster',
                  'Añadir mi dirección (Casa) para ir más rápido',
                ),
              ),
            ),
          )
        else if (_home != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              tr(
                'Magasins et Marketplace : livré à la maison (${_home!['line1']}).',
                'Stores and Marketplace: delivered home (${_home!['line1']}).',
                'Tiendas y Marketplace: entregado en casa (${_home!['line1']}).',
              ),
              key: const ValueKey('shortcut-home-note'),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

