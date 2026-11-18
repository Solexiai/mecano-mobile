// ---------------------------------------------------------------------------
// LiveTrackingMap — carte OpenStreetMap (flutter_map) affichant la position
// temps réel d'un chauffeur pendant une mission active (Phase 5).
//
// RÉUTILISABLE côté client (suivi de SON chauffeur) et côté chauffeur
// (confirmation visuelle de sa propre position + repères pickup/dropoff).
// Dernière position connue : identité, mission et date sont contrôlées.
// Un flux Firestore peut restituer un cache ; sa réception ne prouve pas
// la fraîcheur GPS. La date connue est affichée sans promettre du temps réel.
//
// PAR LA ROUTE, JAMAIS À VOL D'OISEAU (2026-11-18, Daniel) :
// - l'itinéraire prévu (ramassage → livraison) suit les routes ; son tracé
//   vient de `MissionRoutePathService` et la carte se cadre dessus ;
// - le trajet parcouru ne relie deux positions GPS que si elles se suivent
//   de près dans le temps. Quand l'app est en arrière-plan (Google Maps
//   ouvert), les positions s'espacent : les relier traçait une ligne droite
//   à travers champs. Un trou coupe désormais le tracé.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:url_launcher/url_launcher.dart';

import '../backend/backend_locator.dart';
import '../backend/models/driver_location.dart';
import '../backend/models/driver_location_history_point.dart';
import '../backend/models/mission_address.dart';
import '../core/app_colors.dart';
import '../services/mission_route_path_service.dart';

class LiveTrackingMap extends StatefulWidget {
  final String driverId;
  final MissionAddress? pickup;
  final MissionAddress? dropoff;
  final String Function(String) t;

  /// ID de la mission active courante (Phase 5, partie 2). Utilisé pour
  /// filtrer l'historique GPS du chauffeur et n'afficher QUE le trajet
  /// parcouru pour CETTE mission précise — un même chauffeur peut avoir des
  /// points d'historique d'anciennes missions dans la même sous-collection
  /// `history`, ce filtrage évite d'afficher un trajet mélangé/obsolète.
  /// `null` désactive l'affichage de la polyline (ex: écran ne connaît pas
  /// encore la mission).
  final String? missionId;

  /// Borne serveur de l’assignation, si connue. Une position antérieure peut
  /// encore provenir de la mission précédente malgré un lien déjà actualisé.
  final DateTime? acceptedAt;

  /// Horloge injectable pour tests déterministes ; horloge locale par défaut.
  final DateTime Function()? now;

  const LiveTrackingMap({
    super.key,
    required this.driverId,
    required this.t,
    this.pickup,
    this.dropoff,
    this.missionId,
    this.acceptedAt,
    this.now,
  });

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap> {
  final MapController _mapController = MapController();
  bool _initialCentered = false;
  static const _freshness = Duration(seconds: 60);

  /// Écart maximal entre deux positions pour les relier d'un trait. L'écran
  /// de mission envoie une position toutes les 8 s : 30 s tolère quelques
  /// envois manqués. Au-delà, le chauffeur a roulé sans être suivi et une
  /// ligne droite entre les deux points ne dirait pas par où il est passé.
  static const _maxTraceGap = Duration(seconds: 30);

  /// Itinéraire prévu par la route ; vide tant qu'il n'est pas connu.
  List<ll.LatLng> _plannedRoute = const [];
  bool _routeFramed = false;
  bool _routeFramedWithDriver = false;
  Timer? _expiryTimer;
  DateTime _now() => widget.now?.call() ?? DateTime.now();
  late Stream<DriverLocation?> _locationStream;
  late Stream<List<DriverLocationHistoryPoint>> _historyStream;

  (String, String?, DateTime?) get _scope =>
      (widget.driverId, widget.missionId, widget.acceptedAt);

  @override
  void initState() {
    super.initState();
    _bindStreams();
  }

  @override
  void didUpdateWidget(covariant LiveTrackingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driverId != widget.driverId ||
        oldWidget.missionId != widget.missionId ||
        oldWidget.acceptedAt != widget.acceptedAt) {
      _expiryTimer?.cancel();
      _initialCentered = false;
      _bindStreams();
    }
  }

  void _bindStreams() {
    _locationStream = BackendLocator.locationRepository.watchDriverLocation(
      widget.driverId,
    );
    _historyStream = widget.missionId == null || widget.missionId!.isEmpty
        ? Stream<List<DriverLocationHistoryPoint>>.value(const [])
        : BackendLocator.locationRepository.watchDriverLocationHistory(
            widget.driverId,
            missionId: widget.missionId!,
          );
    _loadPlannedRoute();
  }

  void _loadPlannedRoute() {
    _plannedRoute = const [];
    _routeFramed = false;
    _routeFramedWithDriver = false;
    final missionId = widget.missionId;
    if (missionId == null || missionId.isEmpty) return;
    final scope = _scope;
    MissionRoutePathService.load(missionId).then((points) {
      if (!mounted || scope != _scope || points.length < 2) return;
      setState(() => _plannedRoute = points);
    });
  }

  /// Cadre la carte sur l'itinéraire prévu (et le chauffeur s'il est connu) :
  /// une fois à l'arrivée du tracé, une fois encore à la première position.
  /// Ensuite la carte reste là où l'utilisateur l'a placée.
  bool _frameRouteIfNeeded(ll.LatLng? driverPoint) {
    if (_plannedRoute.length < 2) return false;
    final needed =
        !_routeFramed || (driverPoint != null && !_routeFramedWithDriver);
    if (!needed) return true;
    _routeFramed = true;
    if (driverPoint != null) _routeFramedWithDriver = true;
    final scope = _scope;
    final points = <ll.LatLng>[
      ..._plannedRoute,
      if (driverPoint != null) driverPoint,
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || scope != _scope) return;
      try {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(points),
            padding: const EdgeInsets.fromLTRB(28, 44, 28, 52),
            // Un trajet de quelques rues ne doit pas zoomer au-delà des rues.
            maxZoom: 16,
          ),
        );
      } catch (_) {
        // Carte pas encore rendue : elle garde son centrage initial.
      }
    });
    return true;
  }

  bool _usableDate(DateTime? date, DateTime now) =>
      date != null &&
      !date.isAfter(now) &&
      (widget.acceptedAt == null || !date.isBefore(widget.acceptedAt!));

  DriverLocation? _compatibleLocation(DriverLocation? value, DateTime now) {
    if (value == null ||
        widget.driverId.isEmpty ||
        widget.missionId == null ||
        widget.missionId!.isEmpty ||
        value.driverId != widget.driverId ||
        value.activeDeliveryId != widget.missionId ||
        !_usableDate(value.updatedAt, now) ||
        _coordinate(value.latitude, value.longitude) == null) {
      return null;
    }
    return value;
  }

  void _scheduleExpiry(DriverLocation? location, DateTime now) {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    if (location == null) return;
    final remaining = location.updatedAt!.add(_freshness).difference(now);
    if (remaining.isNegative) return;
    // À 60 s exactement la position reste fraîche. Une microseconde est
    // le premier instant représentable strictement après cette frontière,
    // pas une tolérance métier supplémentaire.
    _expiryTimer = Timer(remaining + const Duration(microseconds: 1), () {
      if (mounted) setState(() {});
    });
  }

  String _streamErrorKey(Object? error, {required bool history}) {
    // Seul le code typé du service concerné prouve un refus d'accès.
    // Ne jamais afficher/interpréter le texte brut d'une exception.
    final permissionDenied =
        error is FirebaseException &&
        error.plugin == 'cloud_firestore' &&
        error.code == 'permission-denied';
    if (history) {
      return permissionDenied
          ? 'tracking_history_permission_denied'
          : 'tracking_history_unavailable';
    }
    return permissionDenied
        ? 'tracking_position_permission_denied'
        : 'tracking_position_unavailable';
  }

  String _lastKnownLabel(DateTime date) {
    final local = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    // Même convention jour/mois/année que le suivi client existant.
    // Ne dépend pas des delegates Material (non configurés dans main).
    return '${widget.t('tracking_last_known_position')} : '
        '${two(local.day)}/${two(local.month)}/${local.year} — '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // Only usable coordinates are displayed; zero is valid.
  // No city, service-area position or substitute address is invented.
  ll.LatLng? _coordinate(double latitude, double longitude) =>
      latitude.isFinite &&
          longitude.isFinite &&
          latitude >= -90 &&
          latitude <= 90 &&
          longitude >= -180 &&
          longitude <= 180
      ? ll.LatLng(latitude, longitude)
      : null;

  /// Filtre + trie chronologiquement les points d'historique pour NE garder
  /// que ceux de la mission active courante (`widget.missionId`) — voir
  /// documentation du champ `missionId` ci-dessus. Tri en mémoire par
  /// `recordedAt` (convention du projet, évite un index composite dédié).
  List<DriverLocationHistoryPoint> _tracePoints(
    List<DriverLocationHistoryPoint> history,
    DateTime now,
  ) {
    if (widget.missionId == null) return const [];
    return history
        .where(
          (p) =>
              p.deliveryId == widget.missionId &&
              _usableDate(p.recordedAt, now) &&
              _coordinate(p.latitude, p.longitude) != null,
        )
        .toList()
      ..sort((a, b) => a.recordedAt!.compareTo(b.recordedAt!));
  }

  /// Découpe le trajet parcouru en tronçons continus : deux positions ne
  /// sont reliées que si elles se suivent à `_maxTraceGap` au plus. Une
  /// position isolée ne trace rien — jamais de ligne droite à vol d'oiseau
  /// par-dessus un trou de suivi.
  List<List<ll.LatLng>> _traveledSegments(
    List<DriverLocationHistoryPoint> trace,
  ) {
    final segments = <List<ll.LatLng>>[];
    var current = <ll.LatLng>[];
    DateTime? previous;
    for (final p in trace) {
      final recordedAt = p.recordedAt!;
      if (previous != null && recordedAt.difference(previous) > _maxTraceGap) {
        if (current.length >= 2) segments.add(current);
        current = <ll.LatLng>[];
      }
      current.add(ll.LatLng(p.latitude, p.longitude));
      previous = recordedAt;
    }
    if (current.length >= 2) segments.add(current);
    return segments;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DriverLocation?>(
      // Une nouvelle identité recrée le snapshot, sans retenir l’ancien cache.
      key: ValueKey(_scope),
      stream: _locationStream,
      builder: (context, snap) {
        final now = _now();
        final location = snap.hasError
            ? null
            : _compatibleLocation(snap.data, now);
        final outdated =
            location != null &&
            now.difference(location.updatedAt!) > _freshness;
        _scheduleExpiry(location, now);
        final driverPoint = location != null && !outdated
            ? ll.LatLng(location.latitude, location.longitude)
            : null;
        final pickupPoint = widget.pickup == null
            ? null
            : _coordinate(widget.pickup!.lat, widget.pickup!.lng);
        final dropoffPoint = widget.dropoff == null
            ? null
            : _coordinate(widget.dropoff!.lat, widget.dropoff!.lng);

        final framedOnRoute = _frameRouteIfNeeded(driverPoint);
        if (!framedOnRoute && driverPoint != null && !_initialCentered) {
          _initialCentered = true;
          final scope = _scope;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && scope == _scope) {
              _mapController.move(driverPoint, 14);
            }
          });
        }

        return StreamBuilder<List<DriverLocationHistoryPoint>>(
          key: ValueKey(_scope),
          stream: _historyStream,
          builder: (context, historySnap) {
            final trace = _tracePoints(
              historySnap.hasError ? const [] : historySnap.data ?? const [],
              _now(),
            );
            final traveled = _traveledSegments(trace);
            final planned = _plannedRoute;
            final hasPlanned = planned.length >= 2;

            final center =
                driverPoint ??
                pickupPoint ??
                dropoffPoint ??
                (location == null
                    ? null
                    : _coordinate(location.latitude, location.longitude)) ??
                (trace.isEmpty
                    ? null
                    : ll.LatLng(trace.last.latitude, trace.last.longitude)) ??
                (hasPlanned ? planned.first : null);

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    children: [
                      SizedBox(
                        height: 260,
                        child: center == null
                            ? const ColoredBox(
                                key: ValueKey('tracking-no-map-anchor'),
                                color: Color(0xFFE5E7EB),
                              )
                            : FlutterMap(
                                key: ValueKey(_scope),
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: center,
                                  initialZoom: driverPoint != null ? 14 : 12,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.movik.movik_connect',
                                  ),
                                  if (hasPlanned || traveled.isNotEmpty)
                                    PolylineLayer(
                                      polylines: [
                                        // Dessous : l'itinéraire prévu, par
                                        // la route. Dessus : le trajet
                                        // réellement parcouru.
                                        if (hasPlanned)
                                          Polyline(
                                            points: planned,
                                            strokeWidth: 5,
                                            color: AppColors.info.withValues(
                                              alpha: 0.9,
                                            ),
                                          ),
                                        for (final segment in traveled)
                                          Polyline(
                                            points: segment,
                                            strokeWidth: 4,
                                            color: AppColors.primary.withValues(
                                              alpha: 0.85,
                                            ),
                                          ),
                                      ],
                                    ),
                                  MarkerLayer(
                                    markers: [
                                      if (pickupPoint != null)
                                        Marker(
                                          point: pickupPoint,
                                          width: 34,
                                          height: 34,
                                          child: const Icon(
                                            Icons.trip_origin,
                                            color: AppColors.info,
                                            size: 30,
                                          ),
                                        ),
                                      if (dropoffPoint != null)
                                        Marker(
                                          point: dropoffPoint,
                                          width: 34,
                                          height: 34,
                                          child: const Icon(
                                            Icons.place,
                                            color: AppColors.error,
                                            size: 34,
                                          ),
                                        ),
                                      if (driverPoint != null)
                                        Marker(
                                          point: driverPoint,
                                          width: 40,
                                          height: 40,
                                          rotate: false,
                                          child: const _DriverPulseMarker(),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                      if (hasPlanned || traveled.isNotEmpty)
                        Positioned(
                          left: 10,
                          top: 10,
                          child: _RouteLegend(
                            entries: [
                              if (hasPlanned)
                                (
                                  widget.t('tracking_planned_route_legend'),
                                  AppColors.info,
                                ),
                              if (traveled.isNotEmpty)
                                (
                                  widget.t('tracking_route_legend'),
                                  AppColors.primary,
                                ),
                            ],
                          ),
                        ),
                      if (location != null)
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            color: Colors.black.withValues(alpha: 0.75),
                            child: Text(
                              outdated
                                  ? '${widget.t('tracking_position_stale')}\n'
                                        '${_lastKnownLabel(location.updatedAt!)}'
                                  : _lastKnownLabel(location.updatedAt!),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      if (location == null &&
                          snap.connectionState != ConnectionState.waiting)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.45),
                            alignment: Alignment.center,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                widget.t(
                                  snap.hasError
                                      ? _streamErrorKey(
                                          snap.error,
                                          history: false,
                                        )
                                      : 'tracking_waiting_for_signal',
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (snap.connectionState == ConnectionState.waiting)
                        const Positioned.fill(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                    ],
                  ),
                ),
                if (center != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
                    child: _MapAttribution(
                      fixLabel: widget.t('tracking_map_fix_link'),
                    ),
                  ),
                if (historySnap.hasError)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        widget.t(
                          _streamErrorKey(historySnap.error, history: true),
                        ),
                        // Neutral information, not an alarm (2026-10-23).
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _RouteLegend extends StatelessWidget {
  /// (libellé, couleur du trait) — une ligne par tracé affiché sur la carte.
  final List<(String, Color)> entries;
  const _RouteLegend({required this.entries});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, color) in entries)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Liseré clair : le trait reste lisible sur le fond sombre.
                Container(
                  width: 16,
                  height: 5,
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(color: Colors.white70, width: 0.5),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Mention exigée par OpenStreetMap (fond de carte et calcul d'itinéraire) :
/// crédit des contributeurs et lien pour signaler une erreur de carte.
class _MapAttribution extends StatelessWidget {
  final String fixLabel;
  const _MapAttribution({required this.fixLabel});

  static Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // Lien d'information seulement : un échec d'ouverture reste silencieux.
    }
  }

  Widget _link(String label, String url) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => _open(url),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          decoration: TextDecoration.underline,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 14,
      children: [
        _link('© OpenStreetMap', 'https://www.openstreetmap.org/copyright'),
        _link(fixLabel, 'https://www.openstreetmap.org/fixthemap'),
      ],
    );
  }
}

class _DriverPulseMarker extends StatelessWidget {
  const _DriverPulseMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primary,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.5),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Icon(Icons.local_shipping, color: Colors.white, size: 20),
    );
  }
}
