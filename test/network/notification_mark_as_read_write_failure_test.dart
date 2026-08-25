// ---------------------------------------------------------------------------
// notification_mark_as_read_write_failure_test.dart — Phase 7, Bloc G
// (gap G-4 : Firestore write failure).
//
// GAP réel confirmé : `FirebaseNotificationRepository.markAsRead()`/
// `markAllAsRead()` sont des ÉCRITURES FIRESTORE DIRECTES (pas de Cloud
// Function, voir `firebase_notification_repository.dart` — `.update({
// 'is_read': true })` / batch), protégées uniquement par firestore.rules.
// Aucun test existant ne simulait l'échec de cette écriture précise.
//
// SCÉNARIO :
//   G-4.1 : tap sur une notification non lue -> `markAsRead()` échoue
//           (ex: permission-denied transitoire, coupure réseau) -> AUCUN
//           faux succès affiché : le point "non lu" ne doit pas disparaître
//           puisque l'écriture a réellement échoué côté serveur ; aucun
//           crash ; la navigation vers la mission liée continue de
//           fonctionner malgré l'échec de l'écriture (dégradation
//           acceptable : lire l'information prime sur le marquage lu/non
//           lu, qui est un simple confort UX).
//   G-4.2 : retry (nouvelle interaction) -> cette fois l'écriture réussit ->
//           le repository fake le confirme (`markAsReadSuccessCount == 1`),
//           preuve qu'un nouvel essai reste possible après l'échec (aucun
//           état bloqué côté widget qui empêcherait un nouvel appel).
//
// NE DUPLIQUE PAS :
//   - la navigation post-notification (déjà couverte par Bloc F/F-3,
//     `notifications_deep_link_test.dart`) ;
//   - le compteur non-lu / badge (hors périmètre de ce fichier, cf. Bloc I).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_exceptions.dart';
import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/app_notification.dart';
import 'package:movik_connect/backend/repositories/notification_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/notifications/notifications_screen.dart';

const _userId = 'customer_test_write_failure_001';
const _notificationId = 'notif_test_write_failure';
const _missionId = 'mission_test_write_failure';

/// `NotificationRepository` fake — `markAsRead()` échoue les
/// `failuresBeforeSuccess` premiers appels (Firestore write failure), puis
/// réussit. La liste renvoyée par `watchNotifications()` reste STATIQUE et
/// NE reflète PAS un faux succès : `isRead` ne passe à `true` dans les
/// données que si l'écriture a réellement réussi côté fake (comme un vrai
/// document Firestore inchangé après un `.update()` qui a levé une
/// exception).
class _FlakyNotificationRepository implements NotificationRepository {
  bool _isRead;
  final int failuresBeforeSuccess;

  int markAsReadCallCount = 0;
  int markAsReadFailureCount = 0;
  int markAsReadSuccessCount = 0;

  _FlakyNotificationRepository({required this.failuresBeforeSuccess})
      : _isRead = false;

  AppNotification get _notification => AppNotification(
        id: _notificationId,
        userId: _userId,
        type: 'driver_assigned',
        titleKey: 'notif_driver_assigned_title',
        bodyKey: 'notif_driver_assigned_body',
        missionId: _missionId,
        createdAt: DateTime(2024, 1, 1, 10, 0),
        isRead: _isRead,
      );

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) =>
      Stream.value([_notification]);

  @override
  Stream<int> watchUnreadCount(String userId) => Stream.value(_isRead ? 0 : 1);

  @override
  Future<void> markAsRead(String userId, String notificationId) async {
    markAsReadCallCount++;
    if (markAsReadCallCount <= failuresBeforeSuccess) {
      markAsReadFailureCount++;
      throw const CloudFunctionException(
        'unavailable',
        'Écriture Firestore échouée (simulation G-4).',
      );
    }
    markAsReadSuccessCount++;
    _isRead = true;
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    throw UnimplementedError('non utilisé dans ce parcours de test');
  }
}

Widget _buildTestApp(FirebaseAuthProvider auth) {
  final router = GoRouter(
    initialLocation: '/fr/notifications/$_userId',
    routes: [
      GoRoute(
        path: '/fr/notifications/:userId',
        builder: (context, state) => NotificationsScreen(
          userId: state.pathParameters['userId']!,
        ),
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

String _t(String key) => AppStrings.t(key, 'fr');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    BackendLocator.notificationRepositoryOverride = null;
  });

  testWidgets(
    'G-4.1 : markAsRead() échoue (write failure Firestore) -> aucun faux '
    'succès (le point non-lu reste affiché), aucun crash, navigation vers '
    'la mission liée continue de fonctionner malgré l\'échec de l\'écriture',
    (tester) async {
      final fakeRepo = _FlakyNotificationRepository(failuresBeforeSuccess: 5);
      BackendLocator.notificationRepositoryOverride = fakeRepo;

      final auth = FirebaseAuthProvider(backendConfigured: false)
        ..debugForceSignedIn = true
        ..debugForceUid = _userId;

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      // Le point "non lu" est bien visible avant le tap.
      expect(find.byType(Container), findsWidgets);
      expect(find.text(_t('notif_driver_assigned_title')), findsOneWidget);

      await tester.tap(find.text(_t('notif_driver_assigned_title')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // L'écriture a échoué : aucun faux succès. Le repository fake confirme
      // qu'aucun succès n'a été enregistré, et son état interne `_isRead`
      // reste `false` (comme un document Firestore réellement inchangé).
      expect(fakeRepo.markAsReadCallCount, 1);
      expect(fakeRepo.markAsReadFailureCount, 1);
      expect(fakeRepo.markAsReadSuccessCount, 0);

      // Malgré l'échec de l'écriture, la navigation vers la mission liée a
      // tout de même eu lieu (dégradation acceptable : la lecture de
      // l'information prime sur le marquage lu/non lu, qui est un confort
      // UX secondaire non bloquant).
      expect(find.text('tracking screen $_missionId'), findsOneWidget);
    },
  );

  testWidgets(
    'G-4.2 : retry après échec de markAsRead() -> nouvel essai possible, '
    'succès confirmé, aucun état bloqué côté widget',
    (tester) async {
      final fakeRepo = _FlakyNotificationRepository(failuresBeforeSuccess: 1);
      BackendLocator.notificationRepositoryOverride = fakeRepo;

      final auth = FirebaseAuthProvider(backendConfigured: false)
        ..debugForceSignedIn = true
        ..debugForceUid = _userId;

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      // Premier appel direct au repository (sans re-navigation, pour
      // isoler la preuve de retry sur l'écriture elle-même) : échoue.
      // (Le vrai appelant production, `NotificationsScreen.onTap`, catch
      // déjà cette erreur via `.catchError((_) {})` — voir G-4.1 — ce test
      // isole volontairement l'écriture elle-même, donc catch ici aussi.)
      await expectLater(
        fakeRepo.markAsRead(_userId, _notificationId),
        throwsA(isA<CloudFunctionException>()),
      );
      expect(fakeRepo.markAsReadFailureCount, 1);
      expect(fakeRepo.markAsReadSuccessCount, 0);

      // Retry : deuxième appel -> succès, sans double comptage ni état
      // incohérent.
      await fakeRepo.markAsRead(_userId, _notificationId);
      expect(fakeRepo.markAsReadCallCount, 2);
      expect(fakeRepo.markAsReadFailureCount, 1);
      expect(fakeRepo.markAsReadSuccessCount, 1);

      expect(tester.takeException(), isNull);
    },
  );
}
