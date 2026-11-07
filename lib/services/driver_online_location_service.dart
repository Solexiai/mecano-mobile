// ---------------------------------------------------------------------------
// DriverOnlineLocationService — position du chauffeur TANT QU'IL EST EN
// SERVICE, téléphone rangé compris (2026-11-07, « comme Uber », approuvé par
// Daniel).
//
// Comment : flux de position geolocator avec `ForegroundNotificationConfig`.
// Sur Android, geolocator démarre alors un service au premier plan avec une
// notification persistante (« Movi-K — En service »), ce qui permet de
// continuer à recevoir la position quand l'app passe en arrière-plan, avec
// la seule permission « lorsque l'app est utilisée » (pas de permission
// « toujours », pas d'ACCESS_BACKGROUND_LOCATION).
//
// Quand : démarré par le tableau de bord chauffeur dès que le profil est
// `online` ou `onMission`, arrêté dès `offline`, à la déconnexion ou à la
// fermeture du tableau de bord. Jamais pour un client.
//
// Combien : envoi au serveur (`recordTrackingPoint`, le même qu'au GO) au
// plus toutes les `minInterval` OU dès `minDistanceMeters` parcourus — assez
// pour que le dispatch (fraîcheur 30 min) suive le chauffeur, sans vider la
// batterie. Pendant une mission, l'écran de mission continue son envoi
// toutes les 8 s ; ce service ne le remplace pas.
//
// Hors Android (web, iOS plus tard, tests) : no-op. Toute erreur (GPS
// éteint, permission refusée, réseau) est avalée ici — l'adresse de base
// reste le repli serveur et le GO a déjà signalé le problème.
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform, visibleForTesting;
import 'package:geolocator/geolocator.dart';

import '../backend/backend_locator.dart';
import '../backend/models/driver_location.dart';

/// Source de positions, injectable pour les tests.
typedef PositionStreamFactory = Stream<Position> Function(LocationSettings settings);

class DriverOnlineLocationService {
  DriverOnlineLocationService._();
  static final DriverOnlineLocationService instance = DriverOnlineLocationService._();

  static const Duration minInterval = Duration(minutes: 2);
  static const double minDistanceMeters = 100;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @visibleForTesting
  static PositionStreamFactory? positionStreamOverride;

  @visibleForTesting
  static Future<bool> Function()? permissionOverride;

  StreamSubscription<Position>? _sub;
  DateTime? _lastSentAt;
  Position? _lastSent;
  int sentCount = 0;

  bool get isRunning => _sub != null;

  /// Démarre le suivi (idempotent). [title]/[text] = notification Android.
  Future<void> start({required String title, required String text}) async {
    if (isRunning) return;
    if (!supported && positionStreamOverride == null) return;
    try {
      final allowed = await (permissionOverride ?? _hasPermission)();
      if (!allowed) return;
      final settings = AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
        intervalDuration: const Duration(seconds: 60),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: title,
          notificationText: text,
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
      final stream = (positionStreamOverride ?? _defaultStream)(settings);
      _sub = stream.listen(_onPosition, onError: (_) {});
    } catch (_) {
      _sub = null;
    }
  }

  Future<void> stop() async {
    final sub = _sub;
    _sub = null;
    _lastSentAt = null;
    _lastSent = null;
    await sub?.cancel();
  }

  static Stream<Position> _defaultStream(LocationSettings settings) =>
      Geolocator.getPositionStream(locationSettings: settings);

  static Future<bool> _hasPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  /// Vrai si cette position mérite un envoi (délai écoulé ou déplacement).
  @visibleForTesting
  bool shouldSend(Position p, DateTime now) {
    final last = _lastSent;
    final lastAt = _lastSentAt;
    if (last == null || lastAt == null) return true;
    if (now.difference(lastAt) >= minInterval) return true;
    final moved = Geolocator.distanceBetween(last.latitude, last.longitude, p.latitude, p.longitude);
    return moved >= minDistanceMeters;
  }

  Future<void> _onPosition(Position p) async {
    final now = DateTime.now();
    if (!shouldSend(p, now)) return;
    _lastSent = p;
    _lastSentAt = now;
    try {
      await BackendLocator.locationRepository.reportDriverLocation(
        DriverLocation(
          driverId: '', // ignoré à l'écriture : ctx.uid fait foi côté serveur.
          latitude: p.latitude,
          longitude: p.longitude,
          accuracy: p.accuracy,
          heading: p.heading,
          speed: p.speed,
          updatedAt: now,
        ),
      );
      sentCount++;
    } catch (_) {
      // Réseau ou serveur : on réessaiera au prochain relevé.
      _lastSentAt = null;
    }
  }

  @visibleForTesting
  void resetForTest() {
    _sub?.cancel();
    _sub = null;
    _lastSentAt = null;
    _lastSent = null;
    sentCount = 0;
  }
}
