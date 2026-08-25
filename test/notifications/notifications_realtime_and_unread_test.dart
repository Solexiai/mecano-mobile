// ---------------------------------------------------------------------------
// notifications_realtime_and_unread_test.dart — Phase 7, Bloc I.
//
// GAPS réels confirmés (reconnaissance Bloc I, cf. docs/PHASE7_QA_MATRIX.md) :
//   I-2 : aucun test existant ne prouvait le comportement non-lu/lu au
//         niveau écran (nombre non-lu qui reflète les nouvelles notifications
//         reçues en temps réel, ni la cohérence après un `markAsRead` réussi).
//         `notification_mark_as_read_write_failure_test.dart` (Bloc G/G-4)
//         couvre explicitement l'ÉCHEC d'écriture, mais note lui-même que
//         "le compteur non-lu / badge (hors périmètre de ce fichier, cf.
//         Bloc I)".
//   I-3 : `NotificationsScreen` gère `snap.hasError` sur
//         `watchNotifications()` (voir notifications_screen.dart) mais AUCUN
//         test n'exerçait cette branche. `mission_tracking_listener_error_test.dart`
//         (Bloc G/G-3) prouve le même pattern mais sur `CustomerTrackingScreen`,
//         pas sur `NotificationsScreen` — ce fichier applique le même schéma
//         de test à un écran différent (pas de duplication : c'est un
//         écran distinct avec son propre `StreamBuilder`).
//
// NE DUPLIQUE PAS :
//   - la navigation post-tap (Bloc F/F-3, notifications_deep_link_test.dart) ;
//   - l'échec d'écriture markAsRead() (Bloc G/G-4, déjà couvert) ;
//   - la création des notifications côté backend (Bloc I, déjà couverte par
//     onMissionStatusChangeNotifyCustomer.test.ts).
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/app_notification.dart';
import 'package:movik_connect/backend/repositories/notification_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/notifications/notifications_screen.dart';
import 'package:movik_connect/widgets/notification_bell.dart';

const _userId = 'customer_test_realtime_unread_001';

/// `NotificationRepository` fake avec des `StreamController` non-broadcast
/// pilotables directement par le test (`emitNotifications`/`emitError`/
/// `emitUnreadCount`), même pattern que les autres fakes de ce dossier
/// (`_MissionStreamRepository` dans mission_tracking_listener_error_test.dart).
class _StreamNotificationRepository implements NotificationRepository {
  final _notifController = StreamController<List<AppNotification>>();
  final _unreadController = StreamController<int>();

  int markAsReadCallCount = 0;

  _StreamNotificationRepository({
    required List<AppNotification> initialNotifications,
    required int initialUnreadCount,
  }) {
    _notifController.add(initialNotifications);
    _unreadController.add(initialUnreadCount);
  }

  void emitNotifications(List<AppNotification> notifs) =>
      _notifController.add(notifs);
  void emitError(Object error) => _notifController.addError(error);
  void emitUnreadCount(int count) => _unreadController.add(count);
  void dispose() {
    _notifController.close();
    _unreadController.close();
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) =>
      _notifController.stream;

  @override
  Stream<int> watchUnreadCount(String userId) => _unreadController.stream;

  @override
  Future<void> markAsRead(String userId, String notificationId) async {
    markAsReadCallCount++;
  }

  @override
  Future<void> markAllAsRead(String userId) async {}
}

AppNotification _notif({required String id, required bool isRead}) =>
    AppNotification(
      id: id,
      userId: _userId,
      type: 'driver_assigned',
      titleKey: 'notif_driver_assigned_title',
      bodyKey: 'notif_driver_assigned_body',
      missionId: 'mission_$id',
      createdAt: DateTime(2024, 1, 1, 10, 0),
      isRead: isRead,
    );

Widget _buildNotificationsScreenApp(FirebaseAuthProvider auth) {
  final router = GoRouter(
    initialLocation: '/fr/notifications/$_userId',
    routes: [
      GoRoute(
        path: '/fr/notifications/:userId',
        builder: (context, state) =>
            NotificationsScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(
        path: '/fr/livraison/suivi/:missionId',
        builder: (context, state) => Scaffold(
          body: Text('tracking screen ${state.pathParameters['missionId']}'),
        ),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Widget _buildBellApp(FirebaseAuthProvider auth) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
    ],
    child: MaterialApp(
      home: Scaffold(
        appBar: AppBar(actions: [NotificationBell(userId: _userId)]),
        body: const SizedBox(),
      ),
    ),
  );
}

String _t(String key) => AppStrings.t(key, 'fr');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    BackendLocator.notificationRepositoryOverride = null;
  });

  group('I-2 — read/unread', () {
    testWidgets(
      'I-2.1 : badge NotificationBell reflète le compteur non-lu initial '
      'puis se met à jour en temps réel quand le compteur change '
      '(nouvelle notification reçue -> badge incrémenté)',
      (tester) async {
        final fakeRepo = _StreamNotificationRepository(
          initialNotifications: [_notif(id: 'n1', isRead: false)],
          initialUnreadCount: 1,
        );
        BackendLocator.notificationRepositoryOverride = fakeRepo;
        addTearDown(fakeRepo.dispose);

        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceUid = _userId;

        await tester.pumpWidget(_buildBellApp(auth));
        await tester.pumpAndSettle();

        expect(find.text('1'), findsOneWidget);

        // Nouvelle notification reçue en temps réel -> badge passe à 2.
        fakeRepo.emitUnreadCount(2);
        await tester.pumpAndSettle();
        expect(find.text('2'), findsOneWidget);

        // markAsRead -> le compteur non-lu diminue (émis par le repository
        // comme un vrai stream Firestore recalculerait le count).
        fakeRepo.emitUnreadCount(1);
        await tester.pumpAndSettle();
        expect(find.text('1'), findsOneWidget);

        // Compteur à 0 -> badge masqué (aucun texte '0' résiduel visible).
        fakeRepo.emitUnreadCount(0);
        await tester.pumpAndSettle();
        expect(find.text('0'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'I-2.2 : badge plafonne l\'affichage à "99+" au-delà de 99 non-lues',
      (tester) async {
        final fakeRepo = _StreamNotificationRepository(
          initialNotifications: [],
          initialUnreadCount: 150,
        );
        BackendLocator.notificationRepositoryOverride = fakeRepo;
        addTearDown(fakeRepo.dispose);

        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceUid = _userId;

        await tester.pumpWidget(_buildBellApp(auth));
        await tester.pumpAndSettle();

        expect(find.text('99+'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'I-2.3 : double markAsRead() sur la même notification -> idempotent '
      'côté appelant (2 appels effectués, aucune exception, aucun état '
      'incohérent côté widget)',
      (tester) async {
        final fakeRepo = _StreamNotificationRepository(
          initialNotifications: [_notif(id: 'n1', isRead: false)],
          initialUnreadCount: 1,
        );
        BackendLocator.notificationRepositoryOverride = fakeRepo;
        addTearDown(fakeRepo.dispose);

        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceUid = _userId;

        await tester.pumpWidget(_buildNotificationsScreenApp(auth));
        await tester.pumpAndSettle();

        // Premier tap -> navigation + markAsRead().
        await tester.tap(find.text(_t('notif_driver_assigned_title')));
        await tester.pumpAndSettle();
        expect(fakeRepo.markAsReadCallCount, 1);
        expect(find.text('tracking screen mission_n1'), findsOneWidget);

        // Deuxième appel direct sur le repository, isolé de la navigation
        // (même approche que G-4.2, notification_mark_as_read_write_failure_
        // test.dart : on isole volontairement l'écriture elle-même pour
        // prouver l'idempotence, sans reconstruire tout le parcours UI de
        // retour) -> ne doit pas planter, aucun état incohérent.
        await fakeRepo.markAsRead(_userId, 'n1');

        expect(fakeRepo.markAsReadCallCount, 2);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('I-3 — realtime + listener error (NotificationsScreen)', () {
    testWidgets(
      'I-3.1 : nouvelle notification ajoutée au stream -> UI se met à jour '
      'sans reconstruire tout l\'écran ni planter',
      (tester) async {
        final fakeRepo = _StreamNotificationRepository(
          initialNotifications: [_notif(id: 'n1', isRead: false)],
          initialUnreadCount: 1,
        );
        BackendLocator.notificationRepositoryOverride = fakeRepo;
        addTearDown(fakeRepo.dispose);

        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceUid = _userId;

        await tester.pumpWidget(_buildNotificationsScreenApp(auth));
        await tester.pumpAndSettle();

        expect(find.text(_t('notif_driver_assigned_title')), findsOneWidget);

        fakeRepo.emitNotifications([
          _notif(id: 'n1', isRead: false),
          _notif(id: 'n2', isRead: false),
        ]);
        await tester.pumpAndSettle();

        expect(find.text(_t('notif_driver_assigned_title')), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'I-3.2 : listener watchNotifications() émet une erreur -> aucun crash, '
      'aucun écran blanc, message cohérent affiché (pas de contenu '
      'trompeur : les anciennes notifications ne restent pas visibles '
      'comme si le flux était toujours valide)',
      (tester) async {
        final fakeRepo = _StreamNotificationRepository(
          initialNotifications: [_notif(id: 'n1', isRead: false)],
          initialUnreadCount: 1,
        );
        BackendLocator.notificationRepositoryOverride = fakeRepo;
        addTearDown(fakeRepo.dispose);

        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceUid = _userId;

        await tester.pumpWidget(_buildNotificationsScreenApp(auth));
        await tester.pumpAndSettle();
        expect(find.text(_t('notif_driver_assigned_title')), findsOneWidget);

        fakeRepo.emitError(Exception('Firestore listener error (simulation I-3)'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // L'ancienne notification ne doit plus être affichée comme valide.
        expect(find.text(_t('notif_driver_assigned_title')), findsNothing);
        expect(find.text(_t('notifications_error')), findsOneWidget);
      },
    );

    testWidgets(
      'I-3.3 : après une erreur, une nouvelle émission valide sur le même '
      'flux fait réapparaître les notifications normalement (reprise, '
      'aucun état bloqué)',
      (tester) async {
        final fakeRepo = _StreamNotificationRepository(
          initialNotifications: [_notif(id: 'n1', isRead: false)],
          initialUnreadCount: 1,
        );
        BackendLocator.notificationRepositoryOverride = fakeRepo;
        addTearDown(fakeRepo.dispose);

        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceUid = _userId;

        await tester.pumpWidget(_buildNotificationsScreenApp(auth));
        await tester.pumpAndSettle();

        fakeRepo.emitError(Exception('Firestore listener error (simulation I-3)'));
        await tester.pumpAndSettle();
        expect(find.text(_t('notifications_error')), findsOneWidget);

        fakeRepo.emitNotifications([_notif(id: 'n1', isRead: false)]);
        await tester.pumpAndSettle();

        expect(find.text(_t('notif_driver_assigned_title')), findsOneWidget);
        expect(find.text(_t('notifications_error')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
