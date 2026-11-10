// Language, title and description follow the web address, never the
// language of a previous visit.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/seo/page_meta.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PageMeta', () {
    test('language comes from the first segment of the address', () {
      expect(PageMeta.localeInPath('/fr'), 'fr');
      expect(PageMeta.localeInPath('/en/delivery'), 'en');
      expect(PageMeta.localeInPath('/es/precios/'), 'es');
      expect(PageMeta.localeInPath('/'), isNull);
      expect(PageMeta.localeInPath(''), isNull);
      expect(PageMeta.localeInPath('/de/x'), isNull);
      expect(PageMeta.localeInPath('/frx'), isNull);
    });

    test('each language gets its own title and description', () {
      for (final locale in ['fr', 'en', 'es']) {
        final meta = PageMeta.forPath('/$locale');
        expect(meta.lang, locale);
        expect(meta.title, AppStrings.t('seo_default_title', locale));
        expect(
          meta.description,
          AppStrings.t('seo_default_description', locale),
        );
        // Private pages keep the generic title.
        final private = PageMeta.forPath('/$locale/connexion');
        expect(private.title, AppStrings.t('seo_default_title', locale));
      }
      expect(
        PageMeta.forPath('/en').title,
        isNot(PageMeta.forPath('/fr').title),
      );
      expect(
        PageMeta.forPath('/es').description,
        isNot(PageMeta.forPath('/fr').description),
      );
    });

    test('public pages keep the title of their search-engine page', () {
      expect(
        PageMeta.forPath('/fr/tarifs').title,
        'Tarifs : le prix exact avant de réserver | Movi-K',
      );
      expect(PageMeta.forPath('/en/pricing/').lang, 'en');
      expect(
        PageMeta.forPath('/es/faq').description,
        contains('depósito de 25 \$'),
      );
      expect(
        PageMeta.forPath('/fr/faq').title,
        isNot(PageMeta.forPath('/fr/tarifs').title),
      );
    });

    test('addresses without a language use French', () {
      expect(PageMeta.forPath('/').lang, 'fr');
      expect(PageMeta.forPath('/inconnu').lang, 'fr');
    });

    test('the title keeps the brand spelling Movi-K', () {
      for (final locale in ['fr', 'en', 'es']) {
        expect(PageMeta.forLocale(locale).title, startsWith('Movi-K | '));
      }
    });
  });

  group('LocaleProvider', () {
    test('the address language wins over the saved language', () async {
      SharedPreferences.setMockInitialValues({'movik_locale': 'es'});
      final provider = LocaleProvider(initialLocale: 'fr');
      expect(provider.locale, 'fr');
      await Future<void>.delayed(Duration.zero);
      await SharedPreferences.getInstance();
      await Future<void>.delayed(Duration.zero);
      expect(provider.locale, 'fr');
    });

    test('without a language in the address, the saved one is used', () async {
      SharedPreferences.setMockInitialValues({'movik_locale': 'es'});
      final provider = LocaleProvider();
      await Future<void>.delayed(Duration.zero);
      await SharedPreferences.getInstance();
      await Future<void>.delayed(Duration.zero);
      expect(provider.locale, 'es');
    });

    test('a language chosen before loading finishes is kept', () async {
      SharedPreferences.setMockInitialValues({'movik_locale': 'es'});
      final provider = LocaleProvider();
      await provider.setLocale('en');
      await Future<void>.delayed(Duration.zero);
      expect(provider.locale, 'en');
    });

    test('an unsupported address language is ignored', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = LocaleProvider(initialLocale: 'de');
      await Future<void>.delayed(Duration.zero);
      await SharedPreferences.getInstance();
      await Future<void>.delayed(Duration.zero);
      expect(provider.locale, 'fr');
    });
  });
}
