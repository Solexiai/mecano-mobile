import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/dashboard/admin/admin_action_center.dart';
import 'package:movik_connect/screens/dashboard/admin/admin_dashboard_shell.dart';
import 'package:movik_connect/screens/dashboard/admin/drivers/admin_drivers_list_screen.dart';
import 'package:movik_connect/screens/dashboard/admin/missions/admin_missions_screen.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/screens/dashboard/admin/finance/admin_finance_shell.dart';

const data = <String, dynamic>{
  'actionCountsVersion': 1,
  'pendingReviewDrivers': 3,
  'documentsRequiredDrivers': 2,
  'unassignedMissions': 4,
  'openDisputes': 1,
};

Widget shell(Future<Map<String, dynamic>> Function() loader) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LocaleProvider()),
    ChangeNotifierProvider(
      create: (_) => FirebaseAuthProvider(backendConfigured: false),
    ),
  ],
  child: MaterialApp(home: AdminDashboardShell(metricsLoader: loader)),
);

void main() {
  test('missing or invalid counts are unknown, not zero', () {
    final counts = AdminActionCounts.fromJson({
      'actionCountsVersion': 1,
      'pendingReviewDrivers': -1,
      'documentsRequiredDrivers': 1.2,
      'unassignedMissions': '5',
      'openDisputes': 0,
    });
    expect(counts.pendingReview, isNull);
    expect(counts.documentsRequired, isNull);
    expect(counts.unassigned, isNull);
    expect(counts.disputes, 0);
  });
  test('destination filters match the queues', () {
    expect(
      adminDriverInitialFilter('documents_required'),
      DriverStatus.documentsRequired,
    );
    expect(adminDriverInitialFilter('pending'), DriverStatus.pendingReview);
    expect(adminDriverInitialFilter('all'), isNull);
    expect(
      adminMissionAwaitingAssignment(MissionStatus.searchingDriver),
      isTrue,
    );
    expect(adminMissionAwaitingAssignment(MissionStatus.offered), isTrue);
    expect(adminMissionAwaitingAssignment(MissionStatus.assigned), isFalse);
    expect(adminMissionAwaitingAssignment(MissionStatus.completed), isFalse);
  });
  for (final locale in ['fr', 'en', 'es']) {
    for (final width in [375.0, 1440.0]) {
      testWidgets('action cards fit $locale width $width at 200% text', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 1000),
                textScaler: TextScaler.linear(2),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: AdminActionCenter(
                    counts: AdminActionCounts.fromJson(data),
                    locale: locale,
                  ),
                ),
              ),
            ),
          ),
        );
        expect(find.byType(InkWell), findsNWidgets(4));
        for (final count in ['1', '2', '3', '4']) {
          expect(find.text(count), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
  final destinations = {
    'drivers': '/fr/admin/chauffeurs?filter=pending',
    'documents': '/fr/admin/chauffeurs?filter=documents_required',
    'missions': '/fr/admin/missions?filter=unassigned',
    'disputes': '/fr/admin/paiements?section=disputes&filter=open',
  };
  for (final entry in destinations.entries) {
    testWidgets('opens matching route for ${entry.key}', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: SingleChildScrollView(
                child: AdminActionCenter(
                  counts: AdminActionCounts.fromJson(data),
                  locale: 'fr',
                ),
              ),
            ),
          ),
          for (final path in [
            '/fr/admin/chauffeurs',
            '/fr/admin/missions',
            '/fr/admin/paiements',
          ])
            GoRoute(
              path: path,
              builder: (_, state) => Scaffold(body: Text(state.uri.toString())),
            ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      final card = find.byKey(ValueKey('admin-action-${entry.key}'));
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
    });
  }
  testWidgets('loading keeps actions available and no invented counts', (
    tester,
  ) async {
    final pending = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(shell(() => pending.future));
    expect(find.text('À traiter'), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-action-drivers')), findsOneWidget);
    expect(find.text('0'), findsNothing);
    pending.complete(data);
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
  });
  testWidgets('failure preserves actions and retry restores counts', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      shell(() async {
        if (attempts++ == 0) throw StateError('simulated unavailable');
        return data;
      }),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('admin-action-documents')),
      findsOneWidget,
    );
    expect(
      find.text(
        'Certains compteurs sont indisponibles. Vous pouvez ouvrir les dossiers.',
      ),
      findsOneWidget,
    );
    final retry = find.text('Réessayer');
    await tester.scrollUntilVisible(
      retry,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('keyboard reaches and activates first card', (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: AdminActionCenter(counts: null, locale: 'fr'),
          ),
        ),
        GoRoute(
          path: '/fr/admin/chauffeurs',
          builder: (_, _) => const Scaffold(body: Text('Destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Destination'), findsOneWidget);
  });
  testWidgets(
    'open disputes link selects active queue and allows all statuses',
    (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => LocaleProvider()),
            ChangeNotifierProvider(
              create: (_) => FirebaseAuthProvider(backendConfigured: false),
            ),
          ],
          child: const MaterialApp(
            home: AdminFinanceShell(
              initialSection: 'disputes',
              openDisputesOnly: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final open = find.widgetWithText(ChoiceChip, 'Litiges ouverts');
      expect(tester.widget<ChoiceChip>(open).selected, isTrue);
      final all = find.byType(ChoiceChip).at(1);
      await tester.tap(all);
      await tester.pumpAndSettle();
      expect(tester.widget<ChoiceChip>(open).selected, isFalse);
      expect(tester.widget<ChoiceChip>(all).selected, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}
