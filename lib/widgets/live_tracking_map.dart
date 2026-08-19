// ---------------------------------------------------------------------------
// LiveTrackingMap — carte OpenStreetMap (flutter_map) affichant la position
// temps réel d'un chauffeur pendant une mission active (Phase 5).
//
// RÉUTILISABLE côté client (suivi de SON chauffeur) et côté chauffeur
// (confirmation visuelle de sa propre position + repères pickup/dropoff).
// Source de vérité 100% temps réel : `LocationRepository.watchDriverLocation()`
// (StreamBuilder), jamais de position mise en cache ou simulée.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../backend/backend_locator.dart';
import '../backend/models/driver_location.dart';
import '../backend/models/driver_location_history_point.dart';
import '../backend/models/mission_address.dart';
import '../core/app_colors.dart';

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

  const LiveTrackingMap({
    super.key,
    required this.driverId,
    required this.t,
    this.pickup,
    this.dropoff,
    this.missionId,
  });

  @override
  State<LiveTrackingMap> createState() => _LiveTrackingMapState();
}

class _LiveTrackingMapState extends State<LiveTrackingMap> {
  final MapController _mapController = MapController();
  bool _initialCentered = false;

  ll.LatLng? _fallbackCenter() {
    if (widget.pickup != null) {
      return ll.LatLng(widget.pickup!.lat, widget.pickup!.lng);
    }
    if (widget.dropoff != null) {
      return ll.LatLng(widget.dropoff!.lat, widget.dropoff!.lng);
    }
    return null;
  }

  /// Filtre + trie chronologiquement les points d'historique pour NE garder
  /// que ceux de la mission active courante (`widget.missionId`) — voir
  /// documentation du champ `missionId` ci-dessus. Tri en mémoire par
  /// `recordedAt` (convention du projet, évite un index composite dédié).
  List<ll.LatLng> _routePoints(List<DriverLocationHistoryPoint> history) {
    if (widget.missionId == null) return const [];
    final filtered = history
        .where((p) => p.deliveryId == widget.missionId)
        .toList()
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return filtered.map((p) => ll.LatLng(p.latitude, p.longitude)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DriverLocation?>(
      stream: BackendLocator.locationRepository.watchDriverLocation(
        widget.driverId,
      ),
      builder: (context, snap) {
        final location = snap.data;
        final driverPoint = location != null
            ? ll.LatLng(location.latitude, location.longitude)
            : null;
        final center =
            driverPoint ??
            _fallbackCenter() ??
            const ll.LatLng(45.5017, -73.5673); // Montréal par défaut

        if (driverPoint != null && !_initialCentered) {
          _initialCentered = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.move(driverPoint, 14);
          });
        }

        return StreamBuilder<List<DriverLocationHistoryPoint>>(
          stream: BackendLocator.locationRepository
              .watchDriverLocationHistory(widget.driverId),
          builder: (context, historySnap) {
            final routePoints = _routePoints(historySnap.data ?? const []);

            return ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  SizedBox(
                    height: 260,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: center,
                        initialZoom: driverPoint != null ? 14 : 12,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.movik.movik_connect',
                        ),
                        if (routePoints.length >= 2)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: routePoints,
                                strokeWidth: 4,
                                color: AppColors.primary.withValues(
                                  alpha: 0.85,
                                ),
                              ),
                            ],
                          ),
                        MarkerLayer(
                          markers: [
                            if (widget.pickup != null)
                              Marker(
                                point: ll.LatLng(
                                  widget.pickup!.lat,
                                  widget.pickup!.lng,
                                ),
                                width: 34,
                                height: 34,
                                child: const Icon(
                                  Icons.trip_origin,
                                  color: AppColors.info,
                                  size: 30,
                                ),
                              ),
                            if (widget.dropoff != null)
                              Marker(
                                point: ll.LatLng(
                                  widget.dropoff!.lat,
                                  widget.dropoff!.lng,
                                ),
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
                  if (routePoints.length >= 2)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: _RouteLegend(label: widget.t('tracking_route_legend')),
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
                            widget.t('tracking_waiting_for_signal'),
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
            );
          },
        );
      },
    );
  }
}

class _RouteLegend extends StatelessWidget {
  final String label;
  const _RouteLegend({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 16, height: 3, color: AppColors.primary),
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
