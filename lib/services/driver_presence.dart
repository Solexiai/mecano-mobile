import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../backend/backend_status.dart';
import '../models/enums.dart';
import '../providers/firebase_auth_provider.dart';

const driverPresenceLifetime = Duration(seconds: 90);

Set<String> connectedDriverIds(
  Iterable<({String driverId, DateTime updatedAt})> sessions,
  DateTime now,
) => sessions
    .where(
      (s) =>
          s.driverId.isNotEmpty &&
          !s.updatedAt.isAfter(now.add(const Duration(seconds: 5))) &&
          now.difference(s.updatedAt) < driverPresenceLifetime,
    )
    .map((s) => s.driverId)
    .toSet();

/// Presence measures foreground connectivity, never dispatch availability.
/// One document per session prevents one tab closing another tab's presence.
class DriverPresenceScope extends StatefulWidget {
  const DriverPresenceScope({super.key, required this.child});
  final Widget child;
  @override
  State<DriverPresenceScope> createState() => _DriverPresenceScopeState();
}

class _DriverPresenceScopeState extends State<DriverPresenceScope>
    with WidgetsBindingObserver {
  Timer? _timer;
  String? _uid;
  DocumentReference<Map<String, dynamic>>? _session;
  Future<void>? _pending;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<FirebaseAuthProvider>();
    final enabled =
        context.read<BackendStatus>().isConfigured &&
        auth.isSignedIn &&
        auth.hasRole(PlatformRole.driver);
    final uid = enabled ? auth.effectiveUid : null;
    if (uid != _uid) {
      _stop();
      _uid = uid;
      _start();
    }
  }

  void _start() {
    if (!_foreground || _uid == null || _session != null) return;
    _session = FirebaseFirestore.instance
        .collection('driver_presence')
        .doc(const Uuid().v4());
    _beat();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _beat());
  }

  void _beat() {
    if (_pending != null || _session == null) return;
    final ref = _session!;
    _pending = ref
        .set({'driver_id': _uid, 'updated_at': FieldValue.serverTimestamp()})
        .timeout(const Duration(seconds: 10))
        .catchError((Object _) {
          // No simulated success. Server readers age out the last confirmed beat.
        })
        .whenComplete(() => _pending = null);
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    final ref = _session;
    final pending = _pending;
    _session = null;
    if (ref != null) {
      unawaited(() async {
        try {
          await pending;
          await ref.delete();
        } catch (_) {
          // Abrupt closure/sign-out/network loss is handled by expiry.
        }
      }());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _start();
    } else {
      _stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Fresh server snapshots only: cached/offline data must not imply presence.
class DriverPresenceView extends StatefulWidget {
  const DriverPresenceView({super.key, required this.builder});
  final Widget Function(BuildContext, Set<String>?) builder;
  @override
  State<DriverPresenceView> createState() => _DriverPresenceViewState();
}

class _DriverPresenceViewState extends State<DriverPresenceView> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  Timer? _timer;
  Timer? _renewQuery;
  List<({String driverId, DateTime updatedAt})>? _sessions;
  @override
  void initState() {
    super.initState();
    _listen();
    _renewQuery = Timer.periodic(const Duration(minutes: 1), (_) => _listen());
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  void _listen() {
    if (!(context.read<BackendStatus?>()?.isConfigured ?? false)) return;
    _subscription?.cancel();
    // Renew the query each minute to discard expired session documents.
    // Re-evaluate expiry every 15 s even after an abrupt driver disconnect.
    _subscription = FirebaseFirestore.instance
        .collection('driver_presence')
        .where(
          'updated_at',
          isGreaterThan: Timestamp.fromDate(
            DateTime.now().subtract(driverPresenceLifetime),
          ),
        )
        .limit(2001)
        .snapshots(includeMetadataChanges: true)
        .listen(
          (snap) {
            if (!mounted) return;
            setState(() {
              _sessions = snap.metadata.isFromCache || snap.docs.length > 2000
                  ? null
                  : snap.docs
                        .where((d) => d.data()['updated_at'] is Timestamp)
                        .map(
                          (d) => (
                            driverId: d.data()['driver_id'] as String? ?? '',
                            updatedAt: (d.data()['updated_at'] as Timestamp)
                                .toDate(),
                          ),
                        )
                        .toList();
            });
          },
          onError: (Object _) {
            if (mounted) setState(() => _sessions = null);
          },
        );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _subscription?.cancel();
    _renewQuery?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    _sessions == null ? null : connectedDriverIds(_sessions!, DateTime.now()),
  );
}
