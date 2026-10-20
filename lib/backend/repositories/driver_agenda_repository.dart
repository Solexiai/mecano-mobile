import 'package:cloud_firestore/cloud_firestore.dart';
import '../backend_bootstrap.dart';
import '../models/delivery_mission.dart';
import '../../services/booking/booking_api.dart';

class AgendaInterval {
  const AgendaInterval(this.start, this.end);
  final DateTime start;
  final DateTime end;
  Map<String, dynamic> toJson() => {
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
  };
  factory AgendaInterval.fromJson(Map value) => AgendaInterval(
    DateTime.parse(value['start'] as String).toLocal(),
    DateTime.parse(value['end'] as String).toLocal(),
  );
}

class DriverAgenda {
  const DriverAgenda({
    this.revision = 0,
    this.configured = false,
    this.windows = const [],
    this.blocked = const [],
  });
  final int revision;
  final bool configured;
  final List<AgendaInterval> windows;
  final List<AgendaInterval> blocked;
  factory DriverAgenda.fromJson(Map<String, dynamic> value) {
    final agenda = value['agenda'] as Map;
    List<AgendaInterval> slots(String key) => (agenda[key] as List)
        .map((v) => AgendaInterval.fromJson(v as Map))
        .toList();
    return DriverAgenda(
      revision: value['revision'] as int,
      configured: value['configured'] == true,
      windows: slots('windows'),
      blocked: slots('blocked'),
    );
  }
}

abstract class DriverAgendaRepository {
  Future<DriverAgenda> load();
  Future<DriverAgenda> save(DriverAgenda agenda);
  Stream<List<DeliveryMission>> watchMissions();
}

class FirebaseDriverAgendaRepository implements DriverAgendaRepository {
  FirebaseDriverAgendaRepository(this.driverId, {BookingApi? api})
    : _api = api ?? FirebaseBookingApi(driverId);
  final String driverId;
  final BookingApi _api;
  @override
  Future<DriverAgenda> load() async =>
      DriverAgenda.fromJson(await _api.call('getDriverAgenda'));
  @override
  Future<DriverAgenda> save(DriverAgenda agenda) async => DriverAgenda.fromJson(
    await _api.call('saveDriverAgenda', {
      'revision': agenda.revision,
      'agenda': {
        'windows': agenda.windows.map((s) => s.toJson()).toList(),
        'blocked': agenda.blocked.map((s) => s.toJson()).toList(),
      },
    }),
  );
  @override
  Stream<List<DeliveryMission>> watchMissions() => FirebaseFirestore.instance
      .collection('delivery_requests')
      .where('driver_id', isEqualTo: driverId)
      .snapshots()
      .map(
        (s) => s.docs
            .map((d) => DeliveryMission.fromJson(d.id, d.data()))
            .toList(),
      );
}

class UnavailableDriverAgendaRepository implements DriverAgendaRepository {
  const UnavailableDriverAgendaRepository();
  @override
  Future<DriverAgenda> load() =>
      Future.error(StateError('Agenda indisponible'));
  @override
  Future<DriverAgenda> save(DriverAgenda agenda) =>
      Future.error(StateError('Agenda indisponible'));
  @override
  Stream<List<DeliveryMission>> watchMissions() =>
      Stream.error(StateError('Agenda indisponible'));
}

DriverAgendaRepository driverAgendaRepository(String uid) =>
    BackendBootstrap.status.isConfigured
    ? FirebaseDriverAgendaRepository(uid)
    : const UnavailableDriverAgendaRepository();

/// Requested time is not silently upgraded to a confirmed appointment.
DateTime? agendaMissionStart(DeliveryMission mission) {
  final raw = mission.bookingSnapshot?['load'];
  if (raw is Map && raw['requested_at'] is String) {
    return DateTime.tryParse(raw['requested_at'] as String)?.toLocal();
  }
  return mission.acceptedAt?.toLocal();
}
