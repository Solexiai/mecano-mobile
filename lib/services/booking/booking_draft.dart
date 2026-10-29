import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'session_storage_stub.dart'
    if (dart.library.js_interop) 'session_storage_web.dart'
    as storage;

class BookingDraft {
  BookingDraft({String? category})
    : data = {
        'id': const Uuid().v4(),
        'created': DateTime.now().millisecondsSinceEpoch,
        'revision': 0,
        'step': 0,
        'category': category,
        'items': <dynamic>[],
        'pickup': null,
        'dropoff': null,
        'pickup_access': {
          'floor': null,
          'stairs': null,
          'elevator': null,
          'help': null,
          'details_version': 1,
          'confirmed_fields': <String>[],
          'onsite_help': null,
          'inside': null,
        },
        'dropoff_access': {
          'floor': null,
          'stairs': null,
          'elevator': null,
          'help': null,
          'details_version': 1,
          'confirmed_fields': <String>[],
          'onsite_help': null,
          'inside': null,
        },
        'handlers': 1,
        'equipment': <String>[],
        'requested_at': null,
        'contacts': {
          'pickup_name': '',
          'pickup_phone': '',
          'dropoff_name': '',
          'dropoff_phone': '',
          'instructions': '',
        },
        'quote': null,
        'accepted': false,
        'marketing': false,
        'missionId': null,
      };
  BookingDraft.fromJson(Map<String, dynamic> source)
    : data = jsonDecode(jsonEncode(source)) as Map<String, dynamic>;
  final Map<String, dynamic> data;
  String get id => data['id'] as String;
  int get revision => (data['revision'] as num).toInt();
  int get step => ((data['step'] as num?)?.toInt() ?? 0).clamp(0, 3);
  set step(int value) {
    data['step'] = value;
  }

  /// Screen inside step 0, one question per screen (2026-10-23):
  /// 0 items, 1 addresses and stairs, 2 help, 3 time.
  int get part => ((data['part'] as num?)?.toInt() ?? 0).clamp(0, 3);
  set part(int value) {
    data['part'] = value;
  }

  List<dynamic> get items => data['items'] as List<dynamic>;
  Map<String, dynamic> get contacts =>
      Map<String, dynamic>.from(data['contacts'] as Map);
  Map<String, dynamic>? get quote => data['quote'] == null
      ? null
      : Map<String, dynamic>.from(data['quote'] as Map);
  bool get quoteValid =>
      quote != null &&
      (quote!['expiresAtMillis'] as num) >
          DateTime.now().millisecondsSinceEpoch;
  bool get isImmediate => data['timing_mode'] == 'immediate';

  Map<String, dynamic> get load => {
    'draft_id': id,
    'items': items,
    'pickup': data['pickup_access'],
    'dropoff': data['dropoff_access'],
    'handlers': data['handlers'],
    'equipment': data['equipment'],
    'requested_at': data['requested_at'],
    if (data['timing_mode'] != null) 'timing_mode': data['timing_mode'],
    if (data['intake_mode'] != null) 'intake_mode': data['intake_mode'],
  };
  List<Map<String, dynamic>> get stops => [
    {'type': 'pickup', 'address': data['pickup']},
    {'type': 'dropoff', 'address': data['dropoff']},
  ];
  void changed({bool affectsQuote = true}) {
    data['revision'] = revision + 1;
    if (affectsQuote) {
      data['quote'] = null;
      data['accepted'] = false;
    }
  }

  /// Reçu de confirmation (2026-10-29) : après `createDeliveryRequest`, le
  /// brouillon est remplacé par un petit reçu `{missionId, receipt_at}` pour
  /// survivre à un rafraîchissement. Il ne doit pas réapparaître des heures
  /// plus tard quand le client revient sur « Obtenir mon prix » : sa durée
  /// de vie est courte, le suivi reste accessible depuis l'espace client.
  static const receiptLifetime = Duration(minutes: 30);

  static BookingDraft receipt(Object? missionId) => BookingDraft()
    ..data['missionId'] = missionId
    ..data['receipt_at'] = DateTime.now().millisecondsSinceEpoch;

  bool get isReceipt => data['missionId'] != null;

  bool get expired {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - (data['created'] as num) >=
        const Duration(hours: 24).inMilliseconds) {
      return true;
    }
    if (isReceipt) {
      final at = data['receipt_at'];
      // Reçu d'une version précédente (sans horodatage) : on ne le garde pas.
      if (at is! num) return true;
      return now - at >= receiptLifetime.inMilliseconds;
    }
    return false;
  }
}

/// Guest data stays in this browser tab. A short-lived explicit handoff is
/// required to claim it after authentication. Account drafts never cross UIDs.
class BookingDraftStorage {
  String _key(String? uid) => 'movik_booking_v3_${uid ?? 'guest'}';
  Future<void> save(BookingDraft draft, String? uid) async {
    storage.writeSession(_key(uid), jsonEncode(draft.data));
  }

  Future<BookingDraft?> load(String? uid) async {
    String? raw = storage.readSession(_key(uid));
    if (uid != null) {
      final handoff = int.tryParse(
        storage.readSession('movik_booking_handoff') ?? '',
      );
      if (handoff != null &&
          DateTime.now().millisecondsSinceEpoch - handoff <
              const Duration(minutes: 15).inMilliseconds) {
        final guest = storage.readSession(_key(null));
        if (guest != null) {
          raw = guest;
          storage.writeSession(_key(uid), guest);
        }
        storage.removeSession(_key(null));
      }
      storage.removeSession('movik_booking_handoff');
    }
    if (raw == null) return null;
    try {
      final draft = BookingDraft.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (!draft.expired &&
          draft.items.length <= 20 &&
          draft.data['contacts'] is Map) {
        return draft;
      }
    } catch (_) {
      /* Corrupt/older data is never used as an official quote. */
    }
    storage.removeSession(_key(uid));
    return null;
  }

  Future<void> handoff() async => storage.writeSession(
    'movik_booking_handoff',
    DateTime.now().millisecondsSinceEpoch.toString(),
  );
  Future<void> clear(String? uid) async => storage.removeSession(_key(uid));
}
