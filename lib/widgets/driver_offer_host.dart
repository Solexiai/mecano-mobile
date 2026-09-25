import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../backend/backend_locator.dart';
import '../backend/models/driver_profile_v2.dart';
import '../models/enums.dart';
import '../providers/firebase_auth_provider.dart';
import '../providers/locale_provider.dart';
import '../router/app_router.dart';
import '../services/driver_location_reporter.dart';
import 'driver_offer_inbox.dart';

/// Exactly one host in MaterialApp.builder, above all pages and tabs.
class DriverOfferHost extends StatefulWidget {
  final Widget child;
  const DriverOfferHost({super.key, required this.child});
  @override
  State<DriverOfferHost> createState() => _DriverOfferHostState();
}
class _DriverOfferHostState extends State<DriverOfferHost> {
  String? _uid;
  Stream<DriverProfileV2?>? _profile;
  final _location = DriverLocationReporter();
  Future<void> _refreshLocation() async {
    // Never repeatedly prompt. The existing availability action asks consent.
    final permission = await Geolocator.checkPermission();
    if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) return;
    await _location.reportCurrentLocationOnce();
  }
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FirebaseAuthProvider>();
    final locale = context.watch<LocaleProvider>();
    final uid = auth.effectiveUid;
    if (!auth.isSignedIn || uid == null || !auth.hasRole(PlatformRole.driver)) {
      _uid = null; _profile = null;
      return widget.child;
    }
    if (_uid != uid || _profile == null) {
      _uid = uid;
      _profile = BackendLocator.driverRepository.watchDriverProfile(uid);
    }
    return DriverOfferInbox(
      key: ValueKey('driver-offer-host-$uid'), driverId: uid,
      profileStream: _profile!, repository: BackendLocator.missionRepository,
      t: locale.t, onLocationRefresh: _refreshLocation,
      onAccepted: (missionId) {
        if (mounted && _uid == uid) {
          unawaited(AppRouter.router.push('/${locale.locale}/provider/mission/$missionId'));
        }
      },
      child: widget.child,
    );
  }
}
