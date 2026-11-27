// Page d'estimation par codes postaux (Daniel, 2026-11-26) :
// lib/seo/estimate_page.dart, le formulaire de l'accueil léger
// (lib/seo/seo_html.dart) et les adresses de vercel.json.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:movik_connect/backend/firebase_options.dart';
import 'package:movik_connect/l10n/home_copy.dart';
import 'package:movik_connect/seo/estimate_page.dart';
import 'package:movik_connect/seo/seo_html.dart';
import 'package:movik_connect/seo/seo_pages.dart';

final _template = File('web/index.html').readAsStringSync();

void main() {
  test('addresses and files of the three pages', () {
    expect(estimatePath('fr'), '/fr/estimation');
    expect(estimatePath('en'), '/en/estimate');
    expect(estimatePath('es'), '/es/estimacion');
    expect(estimateFile('fr'), '/seo/fr/estimation.html');
    expect(estimateLocaleForPath('/en/estimate'), 'en');
    expect(estimateLocaleForPath('/fr/estimation/'), 'fr');
    expect(estimateLocaleForPath('/fr/estimation?de=J2G'), 'fr');
    expect(estimateLocaleForPath('/fr/estimate'), isNull);
    expect(estimateLocaleForPath('/fr/tarifs'), isNull);
    // Never the address of an existing public page.
    for (final locale in seoLocales) {
      expect(seoPageForPath(estimatePath(locale)), isNull);
    }
  });

  test('vercel.json serves each estimate page from its file, before the app', () {
    final config = jsonDecode(File('vercel.json').readAsStringSync()) as Map;
    final rewrites = (config['rewrites'] as List).cast<Map>();
    final firstGeneric = rewrites.indexWhere(
      (r) => r['destination'] == '/index.html' && (r['source'] as String).contains(':'),
    );
    for (final locale in seoLocales) {
      final index = rewrites.indexWhere((r) => r['source'] == estimatePath(locale));
      expect(index, greaterThanOrEqualTo(0), reason: locale);
      expect(index, lessThan(firstGeneric), reason: locale);
      expect(rewrites[index]['destination'], estimateFile(locale));
    }
  });

  test('postal codes: full code or first three characters', () {
    expect(normalizePostalCode('j2g3v5'), 'J2G 3V5');
    expect(normalizePostalCode(' J2G-3V5 '), 'J2G 3V5');
    expect(normalizePostalCode('j2l'), 'J2L');
    for (final raw in ['', 'Granby', '12345', 'J2G 3V', 'D2G 3V5', 'J2G 3O5']) {
      expect(normalizePostalCode(raw), isNull, reason: raw);
    }
  });

  test('the link from the home card fills the form of the page', () {
    final uri = Uri.parse(
      estimateLink('fr', from: 'J2G 3V5', to: 'J2L', weight: 'heavy'),
    );
    expect(uri.path, '/fr/estimation');
    expect(uri.queryParameters, {'de': 'J2G 3V5', 'a': 'J2L', 'poids': 'heavy'});
  });

  test('the function addresses are the ones of the app project', () {
    expect(
      estimateFunctionUrl,
      'https://us-central1-${DefaultFirebaseOptions.projectId}.cloudfunctions.net/estimateDeliveryPrice',
    );
    expect(
      estimatePhotoFunctionUrl,
      'https://us-central1-${DefaultFirebaseOptions.projectId}.cloudfunctions.net/estimateItemFromPhoto',
    );
  });

  test('the photo link keeps what is already typed', () {
    expect(Uri.parse(estimatePhotoLink('en')).path, '/en/estimate');
    expect(Uri.parse(estimatePhotoLink('en')).queryParameters, {'photo': '1'});
    expect(
      Uri.parse(estimatePhotoLink('fr', from: 'J2G 3V5', to: 'J2L', weight: 'light')).queryParameters,
      {'photo': '1', 'de': 'J2G 3V5', 'a': 'J2L', 'poids': 'light'},
    );
  });

  for (final locale in seoLocales) {
    test('estimate page $locale: light page, form, result and next step', () {
      final pages = renderAllEstimatePages(_template);
      expect(pages.keys, [for (final l in seoLocales) estimateFile(l)]);
      final html = pages[estimateFile(locale)]!;

      // A light page: the application is not loaded.
      expect(html, isNot(contains('flutter_bootstrap.js')));
      expect(html, isNot(contains('movik-loading')));
      expect(html.length, lessThan(30000));
      expect(html, startsWith('<!DOCTYPE html>'));
      expect(html, contains('<html lang="$locale">'));
      expect(RegExp('<title>[^<]*Movi-K</title>').hasMatch(html), isTrue);
      expect(html, contains('<link rel="canonical" href="https://movi-k.com${estimatePath(locale)}">'));
      for (final l in seoLocales) {
        expect(html, contains('hreflang="$l" href="https://movi-k.com${estimatePath(l)}"'));
      }
      // The site's Google Analytics tag, so the funnel is measured.
      expect(html, contains('G-M8GKQGV3CN'));
      for (final event in [
        'estimate_requested',
        'estimate_shown',
        'estimate_error',
        'estimate_to_booking',
      ]) {
        expect(html, contains("'$event'"));
      }

      // The form: two postal codes, three weights, the photo link.
      expect(html, contains('id="mk-est-form" action="${estimatePath(locale)}" method="get"'));
      expect(RegExp('name="de"').allMatches(html), hasLength(1));
      expect(RegExp('name="a"').allMatches(html), hasLength(1));
      expect(RegExp('type="radio" name="poids"').allMatches(html), hasLength(3));
      expect(html, contains('value="medium" checked'));
      expect(html, contains(HomeCopy.text('estimate_button', locale)));
      // "Not sure? Add a photo": a link to this page that the script turns
      // into the camera, with the recognition function and its notice.
      expect(
        html,
        contains('class="mk-est-photo" id="mk-est-photo" href="${estimatePath(locale)}?photo=1"'),
      );
      // The file field is invisible but never `display:none` (iPhone), and it
      // is emptied before the camera opens, never while the photo is read.
      final field = RegExp('<input type="file" id="mk-est-file"[^>]*>').allMatches(html).toList();
      expect(field, hasLength(1));
      expect(field.single.group(0), contains('accept="image/*"'));
      expect(field.single.group(0), contains('position:absolute;width:1px;height:1px;opacity:0'));
      expect(field.single.group(0), isNot(contains(' hidden')));
      expect(RegExp(r"fileInput\.value = ''").allMatches(html), hasLength(1));
      expect(
        html.indexOf("fileInput.value = ''"),
        lessThan(html.indexOf('fileInput.click()')),
      );
      expect(html, contains('id="mk-est-photo-msg" role="status" hidden'));
      expect(html, contains(HomeCopy.text('estimate_photo_note', locale)));
      expect(html, contains(estimatePhotoFunctionUrl));
      for (final event in ['estimate_photo_requested', 'estimate_photo_recognized', 'estimate_photo_error']) {
        expect(html, contains("'$event'"));
      }
      // The Meta pixel of the site, loaded by the page itself.
      expect(RegExp('<script src="/meta_pixel.js" defer></script>').allMatches(html), hasLength(1));
      expect(File('web/meta_pixel.js').existsSync(), isTrue);
      // Links to the rest of the site.
      for (final id in ['home', 'delivery', 'pricing', 'how', 'faq', 'driver']) {
        final target = seoPages.firstWhere((p) => p.id == id);
        expect(html, contains('href="${target.path(locale)}"'), reason: id);
      }

      // The result is hidden until the function answers; the page's own
      // display rule must not show it earlier.
      expect(html, contains('[hidden]{display:none!important}'));
      expect(html, contains('id="mk-est-result" aria-live="polite" hidden'));
      expect(html, contains('id="mk-est-next" href="/$locale/livraison/demande"'));
      expect(html, contains(estimateFunctionUrl));
      // The advertising parameters follow the visitor to the request.
      expect(html, contains('fbclid'));
      expect(html, contains('utm_'));
      // No amount is written in the page: prices come from the server.
      final visible = html
          .replaceAll(RegExp(r'<script[\s\S]*?</script>'), ' ')
          .replaceAll(RegExp(r'<style[\s\S]*?</style>'), ' ')
          .replaceAll(RegExp(r'<[^>]+>'), ' ');
      final amounts = RegExp(r'\d+\s*\$|\$\s*\d+').allMatches(visible).map((m) => m.group(0)!.trim());
      // Only the 25 $ deposit, already public on the site.
      expect(amounts.toSet().difference({'25 \$', '\$25'}), isEmpty);
    });

    test('light home page $locale opens with the estimate form', () {
      final home = seoPages.firstWhere((p) => p.id == 'home');
      final html = renderSeoPage(_template, home, locale);
      final form = html.indexOf('id="mk-est-form"');
      expect(form, greaterThan(html.indexOf('<h1>')));
      expect(form, lessThan(html.indexOf('class="mk-top"')));
      expect(html, contains('action="${estimatePath(locale)}" method="get"'));
      expect(html, contains('.mk-est-form{'));
    });

    test('light pages $locale: pricing, items, stores and cities carry the form', () {
      for (final page in seoPages) {
        final html = renderSeoPage(_template, page, locale);
        final expected =
            page.id == 'home' || page.id == 'pricing' || page.kind != SeoPageKind.core;
        expect(seoPageHasEstimate(page), expected, reason: page.id);
        if (!expected) {
          // The other public pages keep their single button at the top.
          expect(html, isNot(contains('mk-est-form')), reason: page.id);
          continue;
        }
        final form = html.indexOf('id="mk-est-form"');
        expect(form, greaterThan(html.indexOf('<h1>')), reason: page.id);
        expect(form, lessThan(html.indexOf('class="mk-top"')), reason: page.id);
        expect(RegExp('id="mk-est-form"').allMatches(html), hasLength(1), reason: page.id);
        expect(html, contains('action="${estimatePath(locale)}" method="get"'));
        expect(html, contains('.mk-est-form{'));
        // The photo is read on the estimate page only.
        expect(html, contains('id="mk-est-photo" href="${estimatePath(locale)}?photo=1"'));
        expect(html, isNot(contains('mk-est-file')), reason: page.id);
      }
      // Every public page links to the estimate page.
      for (final page in seoPages) {
        expect(
          renderSeoPage(_template, page, locale),
          contains('<a href="${estimatePath(locale)}">${HomeCopy.text('estimate_button', locale)}</a>'),
          reason: page.id,
        );
      }
      for (final id in ['faq', 'driver', 'contact']) {
        expect(seoPageHasEstimate(seoPages.firstWhere((p) => p.id == id)), isFalse);
      }
    });
  }

  test('config sent to the page script is valid JSON in every language', () {
    for (final locale in seoLocales) {
      final html = renderEstimatePage(_template, locale);
      final match = RegExp(r'var C = (\{[^\n]*\});\(function', dotAll: true).firstMatch(html);
      expect(match, isNotNull, reason: locale);
      final config = jsonDecode(match!.group(1)!) as Map<String, dynamic>;
      expect(config['url'], estimateFunctionUrl);
      expect(config['next'], '/$locale/livraison/demande');
      expect(config['weights'], estimateWeights);
      expect(config['range'], allOf(contains('{low}'), contains('{high}')));
      expect(config['single'], contains('{low}'));
      expect(config['km'], contains('{km}'));
    }
  });
}
