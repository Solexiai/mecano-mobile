import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../backend/models/delivery_mission.dart';
import '../../../backend/models/mission_address.dart';
import '../../../finance/presentation/money_format.dart';
import '../../../models/enums.dart';
import '../../../services/booking/booking_draft.dart';
import '../../../services/demo_data_service.dart';

// Customer space, Uber-style (owner mockup validated 2026-10-25): plain
// labels for a delivery, its status and its date. Display only: every value
// comes from the mission document written by the server.

String _tr(String locale, String fr, String en, String es) => locale == 'en'
    ? en
    : locale == 'es'
    ? es
    : fr;

/// A delivery the customer is still waiting on (shown on the home screen).
const customerActiveStatuses = {
  MissionStatus.searchingDriver,
  MissionStatus.offered,
  MissionStatus.assigned,
  MissionStatus.driverToPickup,
  MissionStatus.arrivedAtPickup,
  MissionStatus.pickedUp,
  MissionStatus.inTransit,
  MissionStatus.arrivedAtDropoff,
};

// Test requests (internal_test) are the customer's own too: shown like any
// other, on the home screen and in Activité alike (2026-10-25).
bool isCustomerActive(DeliveryMission m) =>
    customerActiveStatuses.contains(m.status);

bool isCustomerPast(DeliveryMission m) => const {
  MissionStatus.delivered,
  MissionStatus.completed,
  MissionStatus.cancelled,
  MissionStatus.disputed,
  MissionStatus.refunded,
}.contains(m.status);

/// "Divan 3 places", "Divan + 2 autres", or the category name.
String customerMissionTitle(
  DeliveryMission m,
  String locale,
  String Function(String) t,
) {
  final load = m.bookingSnapshot?['load'];
  final items = load is Map ? load['items'] : null;
  if (items is List && items.isNotEmpty && items.first is Map) {
    final first = items.first as Map;
    final label = (first['label'] as String? ?? '').trim();
    if (label.isNotEmpty) {
      final others = items.length - 1;
      if (others <= 0) return label;
      return _tr(
        locale,
        '$label + $others autre${others > 1 ? 's' : ''}',
        '$label + $others more',
        '$label + $others más',
      );
    }
  }
  if (m.description.trim().isNotEmpty) return m.description.trim();
  if (m.itemCategoryKey.isNotEmpty) return t(m.itemCategoryKey);
  return _tr(locale, 'Livraison', 'Delivery', 'Entrega');
}

/// "Granby → Bromont"; within one city, the street lines instead.
String customerMissionRoute(DeliveryMission m, String locale) {
  final a = m.pickupAddress, b = m.dropoffAddress;
  if (a == null || b == null) {
    return _tr(locale, 'Adresses à venir', 'Addresses pending', 'Direcciones pendientes');
  }
  if (a.city.trim().toLowerCase() != b.city.trim().toLowerCase()) {
    return '${a.city} → ${b.city}';
  }
  String street(MissionAddress x) =>
      x.line1.trim().isNotEmpty ? x.line1.trim() : x.city;
  return '${street(a)} → ${street(b)}';
}

/// The requested time when there is one, else the booking time.
DateTime customerMissionDate(DeliveryMission m) {
  final load = m.bookingSnapshot?['load'];
  final raw = load is Map ? load['requested_at'] : null;
  final requested = raw is String ? DateTime.tryParse(raw) : null;
  return (requested ?? m.createdAt).toLocal();
}

/// "ven. 23 oct." — written by hand: the app ships no Material locales.
String customerDateLabel(DateTime d, String locale) {
  const frDays = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
  const frMonths = [
    'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
    'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
  ];
  const enDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const enMonths = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  const esDays = ['lun.', 'mar.', 'mié.', 'jue.', 'vie.', 'sáb.', 'dom.'];
  const esMonths = [
    'ene.', 'feb.', 'mar.', 'abr.', 'may.', 'jun.',
    'jul.', 'ago.', 'sept.', 'oct.', 'nov.', 'dic.',
  ];
  final day = d.weekday - 1, month = d.month - 1;
  return switch (locale) {
    'en' => '${enDays[day]}, ${enMonths[month]} ${d.day}',
    'es' => '${esDays[day]} ${d.day} ${esMonths[month]}',
    _ => '${frDays[day]} ${d.day} ${frMonths[month]}',
  };
}

String customerTimeLabel(DateTime d, String locale) {
  final mm = d.minute.toString().padLeft(2, '0');
  return locale == 'en' ? '${d.hour}:$mm' : '${d.hour} h $mm';
}

/// "25,00 $" (fr), "$25.00" (en).
String customerMoney(DeliveryMission m, String locale) =>
    formatMajorAmount(m.customerTotal, locale: locale, currencySymbol: r'$');

/// What the customer reads: never the internal status name.
String customerStatusLabel(DeliveryMission m, String locale) =>
    switch (m.status) {
      MissionStatus.assigned || MissionStatus.driverToPickup => _tr(
        locale,
        'En route vers le ramassage',
        'On the way to pickup',
        'En camino a la recogida',
      ),
      MissionStatus.arrivedAtPickup => _tr(
        locale,
        'Arrivé au ramassage',
        'At the pickup',
        'En la recogida',
      ),
      MissionStatus.pickedUp || MissionStatus.inTransit => _tr(
        locale,
        'En route vers vous',
        'On the way to you',
        'En camino hacia ti',
      ),
      MissionStatus.arrivedAtDropoff => _tr(
        locale,
        'Arrivé à destination',
        'Arrived',
        'Llegó al destino',
      ),
      MissionStatus.delivered || MissionStatus.completed => _tr(
        locale,
        'Livrée',
        'Delivered',
        'Entregada',
      ),
      MissionStatus.cancelled => _tr(locale, 'Annulée', 'Cancelled', 'Cancelada'),
      MissionStatus.disputed => _tr(
        locale,
        'Problème signalé',
        'Issue reported',
        'Problema informado',
      ),
      MissionStatus.refunded => _tr(locale, 'Remboursée', 'Refunded', 'Reembolsada'),
      MissionStatus.paymentFailed => _tr(
        locale,
        'Paiement refusé',
        'Payment declined',
        'Pago rechazado',
      ),
      MissionStatus.unknown => _tr(
        locale,
        'Statut inconnu',
        'Unknown status',
        'Estado desconocido',
      ),
      _ => _tr(
        locale,
        'On cherche un chauffeur',
        'Looking for a driver',
        'Buscando un conductor',
      ),
    };

/// Progress over 4 steps: driver found, loaded, on the way, delivered.
int customerProgress(DeliveryMission m) => switch (m.status) {
  MissionStatus.assigned ||
  MissionStatus.driverToPickup ||
  MissionStatus.arrivedAtPickup => 1,
  MissionStatus.pickedUp => 2,
  MissionStatus.inTransit || MissionStatus.arrivedAtDropoff => 3,
  MissionStatus.delivered || MissionStatus.completed => 4,
  _ => 0,
};

/// Once the item is loaded: the pickup time plus the quote's route time. An
/// estimate without live traffic, shown as one; null when unknown or past.
DateTime? customerEstimatedArrival(DeliveryMission m, DateTime now) {
  if (m.status != MissionStatus.pickedUp &&
      m.status != MissionStatus.inTransit) {
    return null;
  }
  final start = m.pickedUpAt ?? m.inTransitAt;
  final minutes = m.estimatedDurationMinutes;
  if (start == null || minutes == null || !minutes.isFinite || minutes <= 0) {
    return null;
  }
  final eta = start.toLocal().add(Duration(minutes: minutes.round()));
  return eta.isBefore(now.toLocal()) ? null : eta;
}

/// Status colors: blue while in progress, green once delivered, orange while
/// searching, red when cancelled or disputed.
(Color, Color) customerStatusColors(DeliveryMission m) => switch (m.status) {
  MissionStatus.delivered ||
  MissionStatus.completed ||
  MissionStatus.refunded => (const Color(0xFFE3F2E8), const Color(0xFF1F6B3A)),
  MissionStatus.cancelled ||
  MissionStatus.disputed ||
  MissionStatus.paymentFailed => (const Color(0xFFFBE7E5), const Color(0xFFA33A2F)),
  MissionStatus.searchingDriver ||
  MissionStatus.offered => (const Color(0xFFFFF4E8), const Color(0xFF8A4307)),
  _ => (const Color(0xFFE6EDFA), const Color(0xFF0F2A5C)),
};

/// "Refaire": a new booking with the same two addresses. The customer takes
/// new photos; nothing else is reused (old photos belong to the old draft).
Future<void> rebookDelivery(
  BuildContext context,
  DeliveryMission m, {
  required String locale,
  required String? uid,
  BookingDraftStorage? storage,
}) async {
  Map<String, dynamic>? address(MissionAddress? a) => a == null
      ? null
      : {
          'line1': a.line1,
          'city': a.city,
          'postal_code': a.postalCode,
          'lat': a.lat,
          'lng': a.lng,
          'formatted_address': a.formattedAddress ?? '${a.line1}, ${a.city}',
          'place_id': a.placeId,
        };
  final category = DemoDataService.deliveryCategories.contains(m.itemCategoryKey)
      ? m.itemCategoryKey
      : null;
  await startPrefilledBooking(
    context,
    locale: locale,
    uid: uid,
    storage: storage,
    category: category,
    pickup: address(m.pickupAddress),
    dropoff: address(m.dropoffAddress),
    rebookFrom: m.id,
  );
}

/// Opens a new booking already filled in ("Refaire", the home "Ramasser à"
/// shortcuts, 2026-10-26). `pickupText` is a search the customer finishes
/// by picking the store in the suggestions; `shortcut` names the shortcut.
Future<void> startPrefilledBooking(
  BuildContext context, {
  required String locale,
  required String? uid,
  BookingDraftStorage? storage,
  String? category,
  Map<String, dynamic>? pickup,
  Map<String, dynamic>? dropoff,
  String? pickupText,
  String? shortcut,
  String? rebookFrom,
}) async {
  final draft = BookingDraft(category: category);
  draft.data['pickup'] = pickup;
  draft.data['dropoff'] = dropoff;
  if (pickupText != null) draft.data['pickup_text'] = pickupText;
  if (shortcut != null) draft.data['pickup_shortcut'] = shortcut;
  if (rebookFrom != null) draft.data['rebook_from'] = rebookFrom;
  try {
    await (storage ?? BookingDraftStorage()).save(draft, uid);
  } catch (_) {
    /* Browser storage may be disabled: the booking still opens empty. */
  }
  if (context.mounted) context.go('/$locale/livraison/demande');
}
