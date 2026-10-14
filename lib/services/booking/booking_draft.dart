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
          'floor': 0,
          'stairs': false,
          'elevator': false,
          'help': true,
        },
        'dropoff_access': {
          'floor': 0,
          'stairs': false,
          'elevator': false,
          'help': true,
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
  Map<String, dynamic> get load => {
    'draft_id': id,
    'items': items,
    'pickup': data['pickup_access'],
    'dropoff': data['dropoff_access'],
    'handlers': data['handlers'],
    'equipment': data['equipment'],
    'requested_at': data['requested_at'],
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

  bool get expired =>
      DateTime.now().millisecondsSinceEpoch - (data['created'] as num) >=
      const Duration(hours: 24).inMilliseconds;
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
