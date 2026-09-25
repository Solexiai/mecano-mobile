import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../backend/models/delivery_mission.dart';
import '../backend/models/delivery_offer.dart';
import '../backend/models/driver_profile_v2.dart';
import '../backend/repositories/mission_repository.dart';
import '../backend/repositories/delivery_offer_actions.dart';
import '../models/enums.dart';
import 'driver_offer_alert.dart';

/// One owner above the driver's tabs. Never opens a second assignment path.
class DriverOfferInbox extends StatefulWidget {
  final String driverId;
  final Stream<DriverProfileV2?> profileStream;
  final MissionRepository repository;
  final String Function(String) t;
  final void Function(String missionId) onAccepted;
  final Widget child;
  final Future<void> Function()? onLocationRefresh;
  final DateTime Function()? now;
  const DriverOfferInbox({super.key, required this.driverId, required this.profileStream,
    required this.repository, required this.t, required this.onAccepted, required this.child, this.onLocationRefresh, this.now});
  @override
  State<DriverOfferInbox> createState() => _DriverOfferInboxState();
}
class _DriverOfferInboxState extends State<DriverOfferInbox> with WidgetsBindingObserver {
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  StreamSubscription<DeliveryMission?>? _missionSubscription;
  final Set<String> _seen = {};
  List<DeliveryOffer> _offers = [];
  DeliveryOffer? _current;
  DeliveryMission? _mission;
  SharedPreferences? _prefs;
  Timer? _clock;
  bool _enabled = false;
  bool _hasActiveMission = true;
  bool _foreground = true;
  bool _ready = false;
  int _generation = 0;
  DateTime _now() => (widget.now ?? DateTime.now)();
  DateTime? _lastLocationRefresh;
  bool _locationBusy = false;
  final Map<String, DateTime> _retryAfter = {};
  String get _seenKey => 'driver_offer_seen_${widget.driverId}';
  bool _live(DeliveryOffer offer) => offer.status == 'pending' &&
    offer.driverId == widget.driverId && offer.expiresAt.isAfter(_now());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground = WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _subscriptions.add(widget.profileStream.listen((profile) {
      _enabled = profile?.status == DriverStatus.approved &&
        profile?.onlineStatus == DriverOnlineStatus.online && profile?.documentsAllValid == true;
      _reconcile();
    }, onError: (Object error) { _enabled = false; _reconcile(); }));
    _subscriptions.add(widget.repository.watchActiveMissionForDriver(widget.driverId).listen((mission) {
      _hasActiveMission = mission != null; _reconcile();
    }, onError: (Object error) { _hasActiveMission = true; _reconcile(); }));
    _subscriptions.add(widget.repository.watchOffersForDriver(widget.driverId).listen((offers) {
      _offers = offers; _reconcile();
    }, onError: (Object error) { _offers = []; _reconcile(); }));
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => _reconcile());
    unawaited(_loadSeen());
  }
  Future<void> _loadSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      _prefs = prefs;
      _seen.addAll(prefs.getStringList(_seenKey) ?? []);
    } catch (_) { /* In-memory deduplication still applies if storage fails. */ }
    if (!mounted) return;
    _ready = true; _reconcile();
  }
  void _remember(String id) {
    _seen.add(id);
    while (_seen.length > 1000) { _seen.remove(_seen.first); }
    unawaited(_persistSeen());
  }
  Future<void> _persistSeen() async {
    try { await _prefs?.setStringList(_seenKey, _seen.toList()); } catch (_) { /* Best effort. */ }
  }
  void _clear() {
    final hadSelection = _current != null || _mission != null;
    _generation++;
    unawaited(_missionSubscription?.cancel());
    _missionSubscription = null;
    _current = null; _mission = null;
    // Stream invalidations must remove the rendered overlay immediately.
    if (mounted && hadSelection) setState(() {});
  }
  void _reconcile() {
    if (!mounted) return;
    final allowed = _ready && _enabled && !_hasActiveMission && _foreground;
    if (allowed && !_locationBusy && widget.onLocationRefresh != null &&
        (_lastLocationRefresh == null || _now().difference(_lastLocationRefresh!).inSeconds >= 60)) {
      _lastLocationRefresh = _now(); _locationBusy = true;
      unawaited(_refreshLocation());
    }
    final wasVisible = _current != null;
    if (!allowed || (_current != null && !_offers.any((offer) => offer.id == _current!.id && _live(offer)))) {
      _clear();
    }
    if (allowed && _current == null) {
      final candidates = _offers.where((offer) => _live(offer) && offer.dispatchVersion >= 2 && !_seen.contains(offer.id) && !(_retryAfter[offer.id]?.isAfter(_now()) ?? false)).toList()
        ..sort((a, b) => a.offeredAt.compareTo(b.offeredAt));
      if (candidates.isNotEmpty) {
        final offer = candidates.first;
        _current = offer;
        final generation = ++_generation;
        _missionSubscription = widget.repository.watchMission(offer.missionId).listen((mission) {
          if (!mounted || generation != _generation) return;
          if (mission == null || !mission.isOpenForAcceptance || mission.driverId != null) {
            _remember(offer.id); _clear(); _reconcile(); return;
          }
          _remember(offer.id);
          setState(() => _mission = mission);
        }, onError: (Object error) {
          if (!mounted || generation != _generation) return;
          _retryAfter[offer.id] = _now().add(const Duration(seconds: 5));
          _clear(); _reconcile();
        });
      }
    }
    if (wasVisible || _current != null) setState(() {});
  }
  Future<void> _refreshLocation() async {
    try { await widget.onLocationRefresh?.call(); } catch (_) { /* The next tick may retry. */ }
    finally { _locationBusy = false; }
  }
  void _dismiss() {
    if (_current != null) _remember(_current!.id);
    _clear(); setState(() {}); _reconcile();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed; _reconcile();
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    for (final subscription in _subscriptions) { unawaited(subscription.cancel()); }
    unawaited(_missionSubscription?.cancel());
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final offer = _current;
    final mission = _mission;
    final repo = widget.repository;
    return Stack(fit: StackFit.expand, children: [
      ExcludeSemantics(excluding: offer != null && mission != null, child: widget.child),
      if (offer != null && mission != null) ...[
        const ModalBarrier(dismissible: false, color: Colors.black54),
        Center(child: FocusScope(autofocus: true, child: DriverOfferAlert(
          key: ValueKey(offer.id), offer: offer, mission: mission, t: widget.t,
          secondsRemaining: (offer.expiresAt.difference(_now()).inMilliseconds / 1000).ceil().clamp(0, 3600),
          onAccept: () async {
            final result = await repo.acceptMission(missionId: offer.missionId, driverId: widget.driverId);
            if (mounted && result.success) { _hasActiveMission = true; _dismiss(); widget.onAccepted(offer.missionId); }
            return result;
          },
          onDecline: () => repo is DeliveryOfferActions
            ? (repo as DeliveryOfferActions).declineOffer(offer.id)
            : Future<void>.error(StateError('Offer actions unavailable')),
          onAccepted: () {}, // Navigation belongs to the inbox, even if this card unmounts.
          onDismiss: () { if (_current?.id == offer.id) _dismiss(); },
        ))),
      ],
    ]);
  }
}
