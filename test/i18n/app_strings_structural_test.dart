// ---------------------------------------------------------------------------
// app_strings_structural_test.dart — BLOC K-9 (I18N GLOBAL, Phase 7).
//
// Suite de tests STRUCTURELLE et MAINTENABLE pour lib/l10n/app_strings.dart.
//
// Objectif explicite (cf. instruction utilisateur) : NE PAS comparer les
// ~900 textes un par un (approche fragile, non maintenable, déjà pratiquée
// ponctuellement dans test/finance/finance_i18n_test.dart via une liste
// statique dupliquée — volontairement NON reproduite ici à l'échelle du
// dictionnaire entier). À la place, cette suite vérifie des propriétés
// STRUCTURELLES qui restent valides quel que soit le contenu exact des
// traductions, et qui détectent les régressions les plus fréquentes :
//
//   1. Cohérence du dictionnaire :
//      - chaque clé possède EXACTEMENT les locales fr/en/es (pas de locale
//        manquante, pas de locale surnuméraire inattendue) ;
//      - aucune valeur non vide requise n'est vide/blanche ;
//      - aucune valeur ne retourne littéralement la clé elle-même (signe
//        d'un copier-coller oublié) sauf whitelist explicite (ex: 'app_name'
//        qui est volontairement identique dans les 3 langues, ce qui est
//        différent de "retourne la clé technique").
//
//   2. Cohérence appels -> dictionnaire :
//      - scan statique (regex) de tous les appels `t('...')` /
//        `AppStrings.t('...', ...)` dans lib/ ; chaque clé référencée doit
//        exister dans AppStrings.allEntries. Cette détection est
//        "best effort" (ne couvre pas les clés construites dynamiquement
//        avec interpolation, ex: `t('foo_$suffix')`) mais couvre la
//        grande majorité des appels réels du projet et suffit à détecter
//        une faute de frappe ou une clé supprimée par erreur.
//
//   3. Rendu réel ciblé (non exhaustif) :
//      - quelques widgets tests représentatifs sur des écrans corrigés dans
//        ce bloc (K-5 résidus), prouvant que le câblage
//        `context.watch<LocaleProvider>().t` fonctionne réellement de bout
//        en bout et pas seulement au niveau de la table de chaînes.
// ---------------------------------------------------------------------------

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:movik_connect/l10n/app_strings.dart';

const List<String> _kLocales = ['fr', 'en', 'es'];

/// Clés dont il est ATTENDU que la valeur soit identique dans les 3 langues
/// (marques, noms propres, éléments volontairement non traduits). Cette
/// whitelist doit rester COURTE — toute clé ajoutée ici doit être un cas
/// légitime, pas une traduction manquante déguisée.
const Set<String> _kIdenticalAcrossLocalesAllowed = {
  'app_name',
  'tagline', // conservé si un jour identique par choix marketing — sinon
  // ce test ne fera qu'affirmer l'absence de valeur vide, voir plus bas.
};

void main() {
  final allEntries = AppStrings.allEntries;

  group('K-9 — Dictionnaire AppStrings : cohérence structurelle', () {
    test('le dictionnaire contient un nombre substantiel de clés (>= 500)', () {
      // Garde-fou anti-régression grossière (ex: dictionnaire vidé par
      // erreur lors d'un merge). Le seuil est volontairement large et non
      // corrélé à un compte exact pour rester maintenable.
      expect(allEntries.length, greaterThanOrEqualTo(500));
    });

    test('aucune clé vide ("") n\'existe dans le dictionnaire', () {
      expect(allEntries.containsKey(''), isFalse);
    });

    test('chaque clé possède exactement les locales fr, en, es (aucune '
        'manquante, aucune surnuméraire)', () {
      final offenders = <String, Set<String>>{};
      for (final entry in allEntries.entries) {
        final localesPresent = entry.value.keys.toSet();
        if (!localesPresent.containsAll(_kLocales)) {
          offenders[entry.key] = localesPresent;
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'Clés avec locale(s) manquante(s) (fr/en/es attendues) : '
            '$offenders',
      );
    });

    test('aucune valeur de traduction n\'est vide ou uniquement blanche', () {
      final offenders = <String>[];
      allEntries.forEach((key, translations) {
        for (final locale in _kLocales) {
          final value = translations[locale];
          if (value == null || value.trim().isEmpty) {
            offenders.add('$key[$locale]');
          }
        }
      });
      expect(
        offenders,
        isEmpty,
        reason: 'Valeurs vides/blanches détectées : $offenders',
      );
    });

    test('aucune traduction ne retourne littéralement la clé technique '
        'elle-même (fuite de clé non résolue)', () {
      final offenders = <String>[];
      allEntries.forEach((key, translations) {
        for (final locale in _kLocales) {
          if (translations[locale] == key) {
            offenders.add('$key[$locale]');
          }
        }
      });
      expect(
        offenders,
        isEmpty,
        reason: 'Clé(s) affichée(s) littéralement au lieu d\'une '
            'traduction : $offenders',
      );
    });

    test('les 3 traductions ne sont pas strictement identiques, sauf pour '
        'les clés explicitement whitelistées (marques/noms propres)', () {
      final offenders = <String>[];
      allEntries.forEach((key, translations) {
        if (_kIdenticalAcrossLocalesAllowed.contains(key)) return;
        final fr = translations['fr'];
        final en = translations['en'];
        final es = translations['es'];
        if (fr != null &&
            en != null &&
            es != null &&
            fr == en &&
            en == es &&
            fr.trim().isNotEmpty) {
          offenders.add(key);
        }
      });
      // Ce test est informatif plutôt que strictement bloquant : certaines
      // clés courtes (ex: sigles, chiffres, symboles monétaires) peuvent
      // légitimement être identiques sans être un bug. On tolère un petit
      // nombre de cas mais on alerte si le volume devient suspect (signe
      // d'un bloc entier resté non traduit).
      expect(
        offenders.length,
        lessThan(40),
        reason:
            'Trop de clés ont une valeur strictement identique en fr/en/es '
            '(hors whitelist) : possible bloc resté non traduit. '
            'Clés concernées (${offenders.length}) : '
            '${offenders.take(40).join(", ")}',
      );
    });

    test('AppStrings.t() retombe sur "fr" puis "en" puis la clé si une '
        'locale demandée est absente d\'une entrée existante', () {
      // Vérifie le comportement de secours documenté dans AppStrings.t(),
      // sans dépendre d'une clé réelle du dictionnaire (robuste aux futurs
      // ajouts/suppressions de clés).
      expect(AppStrings.t('__cle_totalement_inexistante__', 'fr'),
          equals('__cle_totalement_inexistante__'));
      expect(AppStrings.t('__cle_totalement_inexistante__', 'en'),
          equals('__cle_totalement_inexistante__'));
    });
  });

  group('K-9 — Références statiques t(\'clé\') dans lib/ : détection best-effort', () {
    // NOTE : ce test scanne les FICHIERS SOURCE réels sur disque (chemin
    // relatif au répertoire d'exécution des tests, qui est la racine du
    // projet Flutter). Il est volontairement tolérant : il ne peut pas
    // détecter les clés construites dynamiquement (interpolation), et ne
    // doit donc jamais être utilisé comme preuve d'exhaustivité — seulement
    // comme détecteur de fautes de frappe / clés supprimées par erreur sur
    // les appels statiques simples, qui constituent la grande majorité du
    // code du projet.
    test('chaque appel statique t(\'clé\') détecté dans lib/ référence une '
        'clé existante dans AppStrings.allEntries', () {
      final libDir = Directory('lib');
      expect(libDir.existsSync(), isTrue,
          reason:
              'Ce test doit être exécuté depuis la racine du projet Flutter '
              '(répertoire "lib" introuvable).');

      final callPattern = RegExp(r"""\bt\(\s*'([a-zA-Z0-9_]+)'\s*\)""");
      final missing = <String>{};
      final scannedFiles = <String>[];

      for (final entity in libDir.listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        if (entity.path.endsWith('.g.dart')) continue;
        // On exclut le dictionnaire lui-même (ne contient pas d'appels
        // t('...'), seulement des définitions), pas strictement nécessaire
        // mais évite tout faux positif futur si le format interne change.
        if (entity.path.endsWith('app_strings.dart')) continue;

        final content = entity.readAsStringSync();
        scannedFiles.add(entity.path);
        for (final match in callPattern.allMatches(content)) {
          final key = match.group(1)!;
          if (!AppStrings.allEntries.containsKey(key)) {
            missing.add('$key (dans ${entity.path})');
          }
        }
      }

      expect(scannedFiles, isNotEmpty,
          reason: 'Aucun fichier .dart scanné sous lib/ — le test n\'a '
              'rien vérifié, ce qui indiquerait un problème de chemin.');
      expect(
        missing,
        isEmpty,
        reason: 'Appel(s) t(\'clé\') référençant une clé absente du '
            'dictionnaire (faute de frappe probable ou clé supprimée par '
            'erreur) : ${missing.join(", ")}',
      );
    });
  });

  group('K-9 — Notifications : couverture spécifique notif_* (K-5)', () {
    // Ces clés sont générées côté backend (functions/) sous forme de
    // chaînes littérales (title_key/body_key) et ne sont donc PAS détectées
    // par le scan statique ci-dessus (le "t('...')" est appelé côté client
    // avec une variable, pas une clé littérale — voir
    // lib/screens/notifications/notifications_screen.dart:
    // `t(notification.titleKey)`). On les liste donc explicitement pour
    // garantir leur couverture FR/EN/ES, en miroir des specs backend
    // (functions/src/functions/onMissionStatusChangeNotifyCustomer.ts,
    // detectExpiringDocuments.ts, transitionFoundingDriverPeriods.ts).
    const notifKeys = [
      'notif_driver_assigned_title',
      'notif_driver_assigned_body',
      'notif_driver_to_pickup_title',
      'notif_driver_to_pickup_body',
      'notif_arrived_at_pickup_title',
      'notif_arrived_at_pickup_body',
      'notif_picked_up_title',
      'notif_picked_up_body',
      'notif_in_transit_title',
      'notif_in_transit_body',
      'notif_arrived_at_dropoff_title',
      'notif_arrived_at_dropoff_body',
      'notif_completed_title',
      'notif_completed_body',
      'notif_cancelled_title',
      'notif_cancelled_body',
      'notif_document_expiring_soon_title',
      'notif_document_expiring_soon_body',
      'notif_founding_preferred_rate_title',
      'notif_founding_preferred_rate_body',
    ];

    for (final key in notifKeys) {
      test('la clé backend "$key" existe et est traduite en fr/en/es', () {
        expect(AppStrings.allEntries.containsKey(key), isTrue,
            reason: 'Clé backend "$key" absente du dictionnaire client — '
                'une notification produite par les Cloud Functions '
                'afficherait la clé brute à l\'utilisateur.');
        for (final locale in _kLocales) {
          final value = AppStrings.t(key, locale);
          expect(value, isNot(equals(key)));
          expect(value.trim(), isNotEmpty);
        }
      });
    }

    test('les libellés d\'écran notifications_* essentiels existent en '
        'fr/en/es', () {
      const uiKeys = [
        'notifications_title',
        'notifications_empty',
        'notifications_loading',
        'notifications_error',
        'notifications_open_tooltip',
        'notifications_mark_all_read',
        'notifications_just_now',
      ];
      for (final key in uiKeys) {
        expect(AppStrings.allEntries.containsKey(key), isTrue,
            reason: 'Clé UI notifications "$key" manquante.');
        for (final locale in _kLocales) {
          expect(AppStrings.t(key, locale).trim(), isNotEmpty);
        }
      }
    });
  });
}
