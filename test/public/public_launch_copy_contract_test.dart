// P1-COPY-001: published text contract, not operational availability.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:movik_connect/l10n/home_copy.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/router/app_router.dart';
import '../helpers/gps_offline_transport.dart';
import 'public_launch_pages_test.dart' show wrapPublicPage;

void rejectHistoricClaims(WidgetTester tester) {
  final displayed = tester
      .widgetList<Text>(find.byType(Text))
      .map((w) => w.data ?? w.textSpan?.toPlainText() ?? '')
      .join('\n');
  expect(
    RegExp(
      r'partout au québec|across quebec|throughout quebec|todo quebec|'
      r'choisissez votre chauffeur|choose your driver|elige a tu conductor|'
      r'créneau garanti|guaranteed time slot|horario garantizado',
      caseSensitive: false,
    ).hasMatch(displayed),
    isFalse,
    reason:
        'Historical affirmative coverage/selection/slot claims must not return',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    expect(Firebase.apps, isEmpty);
  });
  tearDown(() => expect(Firebase.apps, isEmpty));
  tearDownAll(() {
    expect(rejectedRequests, isEmpty);
    expect(offlineTileRequests, isEmpty);
    // ignore: avoid_print
    print(
      'OFFLINE_TRANSPORT: in_memory=0; unexpected=0; external_transport=none',
    );
  });

  for (final locale in ['fr', 'en', 'es']) {
    final languageIndex = ['fr', 'en', 'es'].indexOf(locale);
    String tr(List<String> values) => values[languageIndex];
    for (final scenario in [
      (375.0, 812.0, 1.0),
      (430.0, 932.0, 1.0),
      (1440.0, 900.0, 1.0),
      (375.0, 812.0, 2.0),
    ]) {
      final (width, height, scale) = scenario;
      offlineWidgetTest(
        'launch copy remains conditional $locale ${width}x$height text=$scale',
        (tester) async {
          await tester.binding.setSurfaceSize(Size(width, height));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final auth = FirebaseAuthProvider(backendConfigured: false);
          AppRouter.router.go('/$locale');
          await tester.pumpWidget(wrapPublicPage(auth, textScale: scale));
          await tester.pumpAndSettle();
          expect(
            find.text(HomeCopy.text('granby_launch', locale)),
            findsWidgets,
          );
          expect(
            find.text(HomeCopy.text('prelaunch_status', locale)),
            findsWidgets,
          );
          expect(
            find.text(HomeCopy.text('step3_body', locale)),
            findsOneWidget,
          );
          expect(
            find.text(HomeCopy.text('local_cta_body', locale)),
            findsOneWidget,
          );
          rejectHistoricClaims(tester);
          expect(tester.takeException(), isNull);

          AppRouter.router.go('/$locale/comment-ca-marche');
          await tester.pumpAndSettle();
          expect(
            find.textContaining(
              tr([
                'sans choix manuel de chauffeur ni créneau promis',
                'without manual driver selection or a promised time slot',
                'sin elegir manualmente conductor ni prometer una franja horaria',
              ]),
            ),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              tr([
                'validation sur appareils réels',
                'real-device validation',
                'validación en dispositivos reales',
              ]),
            ),
            findsOneWidget,
          );
          rejectHistoricClaims(tester);
          expect(tester.takeException(), isNull);

          AppRouter.router.go('/$locale/faq');
          await tester.pumpAndSettle();
          final tiles = find.byType(ExpansionTile);
          final count = tiles.evaluate().length;
          expect(count, greaterThanOrEqualTo(8));
          for (var i = 0; i < count; i++) {
            final title =
                tester.widget<ExpansionTile>(tiles.at(i)).title as Text;
            final heading = find.text(title.data!);
            await tester.ensureVisible(heading);
            await tester.pumpAndSettle();
            await tester.tap(heading);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
          for (final claim in [
            tr([
              'aucun chauffeur n’est garanti au moment du calcul du prix',
              'no driver is guaranteed when the price is calculated',
              'ningún conductor está garantizado al calcular el precio',
            ]),
            tr([
              'il ne constitue pas un créneau confirmé',
              'it is not a confirmed time slot',
              'no constituyen un horario confirmado',
            ]),
            tr([
              'sa validation sur appareils réels',
              'real-device validation is still',
              'la validación en dispositivos reales sigue',
            ]),
            tr([
              'Les modalités de paiement en production sont encore en validation',
              'Production payment methods are still being validated',
              'Los métodos de pago en producción siguen en validación',
            ]),
          ]) {
            expect(find.textContaining(claim), findsOneWidget);
          }
          rejectHistoricClaims(tester);

          AppRouter.router.go('/$locale/granby');
          await tester.pumpAndSettle();
          expect(
            find.text(tr(['Zone prévue', 'Planned area', 'Zona prevista'])),
            findsOneWidget,
          );
          expect(
            find.textContaining(
              tr([
                'Aucune réservation, disponibilité de chauffeur ou transaction réelle',
                'does not promise a booking, driver availability or a live transaction',
                'no promete una reserva, disponibilidad de conductor ni una transacción real',
              ]),
            ),
            findsOneWidget,
          );
          expect(
            find.text(
              tr([
                'Canal de contact à venir',
                'Contact channel coming soon',
                'Canal de contacto próximamente',
              ]),
            ),
            findsOneWidget,
          );
          rejectHistoricClaims(tester);
          expect(tester.takeException(), isNull);

          AppRouter.router.go('/$locale/devenir-chauffeur');
          await tester.pumpAndSettle();
          expect(
            find.textContaining(
              tr([
                'Aucun revenu n’est garanti',
                'No income is guaranteed',
                'No se garantiza ningún ingreso',
              ]),
            ),
            findsOneWidget,
          );
          rejectHistoricClaims(tester);
          expect(tester.takeException(), isNull);

          AppRouter.router.go('/$locale/tarifs');
          await tester.pumpAndSettle();
          expect(
            find.textContaining(
              tr([
                'Les paiements ouvriront au lancement du service à Granby.',
                'Payments will open when the service launches in Granby.',
                'Los pagos se abrirán con el lanzamiento del servicio en Granby.',
              ]),
            ),
            findsOneWidget,
          );
          rejectHistoricClaims(tester);
          expect(tester.takeException(), isNull);
          expect(Firebase.apps, isEmpty);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          auth.dispose();
        },
      );
    }
  }
}
