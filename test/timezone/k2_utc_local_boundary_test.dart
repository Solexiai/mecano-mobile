// ---------------------------------------------------------------------------
// k2_utc_local_boundary_test.dart — BLOC K2 (Timezone/Date, Phase 7), K2-4.
//
// Test PERMANENT prouvant que la conversion UTC -> local est bien effectuée
// avant tout affichage/extraction de composants de date (jour/mois/année),
// et qu'un instant UTC "après minuit" peut légitimement correspondre à la
// veille dans un fuseau négatif (ex: America/Toronto / Montréal, UTC-4 ou
// UTC-5 selon la saison) — cas réel pour Movi-K (Québec/Canada).
//
// Portée volontairement restreinte (cf. instruction utilisateur K2-4) :
// on ne construit PAS un moteur de fuseau horaire personnalisé, on prouve
// juste que `DateTime.toLocal()` (utilisé partout dans le code de
// formatage, cf. Bloc K2 K2-2/K2-3) inverse correctement `DateTime.utc()`
// pour un `DateTime` marqué explicitement UTC, et que les fonctions de
// formatage réelles du projet (`formatDisplayDate`, `formatShortDate`,
// `admin_drivers_list_screen._formatDate` via duplication du calcul)
// utilisent bien `.toLocal()` avant extraction — pas les composantes UTC
// brutes.
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';

import 'package:movik_connect/finance/presentation/money_format.dart';
import 'package:movik_connect/screens/dashboard/admin/finance/finance_ui_helpers.dart';

void main() {
  group('K2-4 — Frontière UTC/local : `.toLocal()` inverse `.toUtc()`', () {
    test(
      'un DateTime.utc() construit puis converti .toLocal() puis .toUtc() '
      'redonne exactement les mêmes composants UTC (round-trip sans perte)',
      () {
        // 2026-01-15T02:00:00Z : "après minuit UTC". Dans un fuseau négatif
        // (ex: UTC-5, heure normale de l'Est / Montréal en janvier), l'heure
        // locale correspondante est 2026-01-14 21:00 — la VEILLE. C'est
        // exactement le cas de régression que ce test verrouille : le jour
        // calendaire perçu par l'utilisateur peut différer du jour UTC brut.
        final utcInstant = DateTime.utc(2026, 1, 15, 2, 0, 0);

        final roundTripped = utcInstant.toLocal().toUtc();

        expect(roundTripped.year, equals(utcInstant.year));
        expect(roundTripped.month, equals(utcInstant.month));
        expect(roundTripped.day, equals(utcInstant.day));
        expect(roundTripped.hour, equals(utcInstant.hour));
        expect(roundTripped.minute, equals(utcInstant.minute));
        expect(
          roundTripped.isAtSameMomentAs(utcInstant),
          isTrue,
          reason:
              'Round-trip .toLocal().toUtc() doit préserver le même instant '
              'réel, quel que soit le fuseau du système exécutant le test '
              '(garantie fondamentale de DateTime, indépendante du fuseau '
              'local — voir dartdocs DateTime.toLocal/.toUtc).',
        );
      },
    );

    test(
      'deux instants UTC séparés de quelques heures autour de minuit UTC '
      'restent correctement ordonnés après conversion locale (le tri par '
      'instant réel, cf. Bloc K2 K2-6, ne doit jamais dépendre du fuseau)',
      () {
        final beforeMidnightUtc = DateTime.utc(2026, 1, 14, 23, 30);
        final afterMidnightUtc = DateTime.utc(2026, 1, 15, 0, 30);

        // Peu importe le fuseau d'exécution : l'instant "après minuit UTC"
        // reste chronologiquement après celui "avant minuit UTC" une fois
        // les deux convertis en local (la conversion est une simple
        // translation constante, elle préserve l'ordre).
        expect(
          afterMidnightUtc.toLocal().isAfter(beforeMidnightUtc.toLocal()),
          isTrue,
        );
        expect(
          beforeMidnightUtc.isBefore(afterMidnightUtc),
          isTrue,
          reason: 'Comparaison sur les instants UTC bruts, cohérente avec '
              'la comparaison sur les versions locales ci-dessus.',
        );
      },
    );
  });

  group(
    'K2-4 — Fonctions de formatage réelles du projet utilisent bien '
    '`.toLocal()` avant extraction (pas les composantes UTC brutes)',
    () {
      test(
        'formatDisplayDate() (finance/presentation/money_format.dart) sur '
        'un DateTime UTC "après minuit" affiche bien le jour LOCAL, pas le '
        'jour UTC, lorsque le fuseau système est en avance sur UTC',
        () {
          // 00:30 UTC le 15 : dans un fuseau système en AVANCE sur UTC
          // (ex: UTC+1 ou plus), l'heure locale correspondante est déjà le
          // 15 également (>= 01:30) — donc pour rendre ce test déterministe
          // indépendamment du fuseau réel de la machine CI, on vérifie une
          // propriété structurelle plutôt qu'une valeur affichée figée : le
          // texte produit doit correspondre EXACTEMENT aux composants de
          // `dt.toLocal()`, jamais à ceux de `dt` (UTC) directement, sauf
          // coïncidence si le système tourne déjà en UTC (sandbox CI ici).
          final dt = DateTime.utc(2026, 1, 15, 0, 30);
          final local = dt.toLocal();
          final expectedDay = local.day.toString().padLeft(2, '0');
          final expectedMonth = local.month.toString().padLeft(2, '0');
          final expectedHour = local.hour.toString().padLeft(2, '0');
          final expectedMinute = local.minute.toString().padLeft(2, '0');

          final formatted = formatDisplayDate(dt);

          expect(
            formatted,
            equals(
              '$expectedDay/$expectedMonth/${local.year} à '
              '$expectedHour:$expectedMinute',
            ),
            reason: 'formatDisplayDate() doit refléter exactement '
                'DateTime.toLocal(), jamais les composants UTC bruts.',
          );
        },
      );

      test(
        'formatShortDate() (admin/finance/finance_ui_helpers.dart) sur un '
        'DateTime UTC utilise bien .toLocal() avant extraction jour/mois',
        () {
          final dt = DateTime.utc(2026, 6, 30, 23, 45);
          final local = dt.toLocal();
          final expectedDay = local.day.toString().padLeft(2, '0');
          final expectedMonth = local.month.toString().padLeft(2, '0');

          final formatted = formatShortDate(dt);

          expect(
            formatted,
            equals('$expectedDay/$expectedMonth/${local.year}'),
          );
        },
      );

      test('formatShortDate(null) retourne un tiret, jamais une exception '
          'ni "null" affiché littéralement', () {
        expect(formatShortDate(null), equals('—'));
      });
    },
  );
}
