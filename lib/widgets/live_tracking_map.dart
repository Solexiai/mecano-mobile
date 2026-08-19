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
import '../backend/models/mission_address.dart';
import '../core/app_colors.dart';

class LiveTrackingMap extends StatefulWidget {
  final String driverId;
  final MissionAddress? pickup;
  final MissionAddress? dropoff;
  final String Function(String) t;

  const LiveTrackingMap({
    super.key,
    required this.driverId,
    required this.t,
    this.pickup,
    this.dropoff,
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
