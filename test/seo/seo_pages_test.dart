// Pages publiques lisibles par Google et les IA (Daniel, 2026-11-10) :
// lib/seo/seo_pages.dart, lib/seo/seo_html.dart, tool/build_seo_pages.dart,
// vercel.json et /llms.txt.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:movik_connect/content/faq_content.dart';
import 'package:movik_connect/seo/seo_html.dart';
import 'package:movik_connect/seo/seo_pages.dart';

final _template = File('web/index.html').readAsStringSync();

List<String> _sitemapPaths() => RegExp(r'<loc>([^<]+)</loc>')
    .allMatches(File('web/sitemap.xml').readAsStringSync())
    .map((m) => Uri.parse(m.group(1)!).path)
    .toList();

Map<String, Object?> _jsonLd(String html) {
  final match = RegExp(
    r'<script type="application/ld\+json">(.*?)</script>',
    dotAll: true,
  ).firstMatch(html);
  expect(match, isNotNull);
  return jsonDecode(match!.group(1)!) as Map<String, Object?>;
}

String _visibleText(String html) => html
    .replaceAll(RegExp(r'<script[\s\S]*?</script>'), ' ')
    .replaceAll(RegExp(r'<style[\s\S]*?</style>'), ' ')
    .replaceAll(RegExp(r'<[^>]+>'), ' ');

void main() {
  test('10 public pages in 3 languages, all in the sitemap', () {
    expect(seoPages, hasLength(10));
    expect(seoPages.map((p) => p.id).toSet(), hasLength(10));
    final sitemap = _sitemapPaths();
    final seoPaths = {
      for (final page in seoPages)
        for (final locale in seoLocales) page.path(locale),
    };
    expect(seoPaths, hasLength(30));
    for (final path in seoPaths) {
      expect(sitemap, contains(path));
    }
    // Every other sitemap page is a legal page (served by the app as before).
    for (final path in sitemap.where((p) => !seoPaths.contains(p))) {
      expect(path, contains('/legal/'));
    }
  });

  test('vercel.json serves each public page from its generated file', () {
    final config = jsonDecode(File('vercel.json').readAsStringSync()) as Map;
    final rewrites = (config['rewrites'] as List).cast<Map>();
    final firstGeneric = rewrites.indexWhere((r) => r['destination'] == '/index.html');
    for (final page in seoPages) {
      for (final locale in seoLocales) {
        final index = rewrites.indexWhere((r) => r['source'] == page.path(locale));
        expect(index, greaterThanOrEqualTo(0), reason: page.path(locale));
        expect(index, lessThan(firstGeneric), reason: 'must win over the app rule');
        expect(rewrites[index]['destination'], page.file(locale));
      }
    }
    // Vercel serves the root index.html before any rewrite: the root is a
    // server redirect to /fr instead (redirects run before files).
    final redirects = (config['redirects'] as List).cast<Map>();
    expect(
      redirects.firstWhere((r) => r['source'] == '/'),
      {'source': '/', 'destination': '/fr', 'permanent': false},
    );
    expect(File('web/robots.txt').readAsStringSync(), contains('Disallow: /seo/'));
  });

  test('titles and descriptions are unique, short and branded', () {
    for (final locale in seoLocales) {
      final titles = seoPages.map((p) => p.titles[locale]!).toList();
      final descriptions = seoPages.map((p) => p.descriptions[locale]!).toList();
      expect(titles.toSet(), hasLength(titles.length), reason: locale);
      expect(descriptions.toSet(), hasLength(descriptions.length), reason: locale);
      for (final title in titles) {
        expect(title, contains('Movi-K'));
        expect(title.length, lessThanOrEqualTo(70), reason: title);
      }
      for (final description in descriptions) {
        expect(description.length, inInclusiveRange(60, 185), reason: description);
      }
    }
  });

  test('pathfinding: addresses, trailing slash, private pages', () {
    expect(seoPageForPath('/fr/tarifs')!.id, 'pricing');
    expect(seoPageForPath('/en/pricing/')!.id, 'pricing');
    expect(seoLocaleForPath('/es/precios'), 'es');
    expect(seoPageForPath('/fr/connexion'), isNull);
    expect(seoPageForPath('/fr/legal/terms'), isNull);
    expect(seoPageForPath('/fr')!.id, 'home');
  });

  group('generated HTML', () {
    final pages = renderAllSeoPages(_template);

    test('one file per page and language, under /seo/', () {
      expect(pages, hasLength(30));
      expect(pages.keys, contains('/seo/fr.html'));
      expect(pages.keys, contains('/seo/en/pricing.html'));
      expect(pages.keys, contains('/seo/es/convertirse-conductor.html'));
    });

    for (final page in seoPages) {
      for (final locale in seoLocales) {
        test('${page.path(locale)} is complete and still boots the app', () {
          final html = pages[page.file(locale)]!;
          expect(html, contains('<html lang="$locale">'));
          expect(RegExp('<title>').allMatches(html), hasLength(1));
          expect(html, contains('<link rel="canonical" href="${page.url(locale)}">'));
          for (final l in seoLocales) {
            expect(html, contains('hreflang="$l" href="${page.url(l)}"'));
          }
          expect(html, contains('hreflang="x-default" href="${page.url('fr')}"'));
          expect(html, contains('<h1>'));
          expect(html, contains('flutter_bootstrap.js'));
          expect(html, contains('flutter-first-frame'));
          expect(html, contains('href="mailto:infos@movi-k.com"'));

          final data = _jsonLd(html);
          expect(data['@context'], 'https://schema.org');
          final graph = (data['@graph'] as List).cast<Map>();
          final types = graph.map((n) => n['@type']).toSet();
          expect(types, containsAll(['Organization', 'WebSite']));
          // No invented ratings or reviews.
          expect(html, isNot(contains('aggregateRating')));
          expect(html, isNot(contains('"review"')));

          final text = _visibleText(html).toLowerCase();
          for (final stale in [
            'lancement',
            'launching',
            'lanzamiento',
            'ouvriront',
            'pré-lancement',
            'à venir',
          ]) {
            expect(text, isNot(contains(stale)), reason: '${page.path(locale)}: $stale');
          }
        });
      }
    }

    test('the FAQ page lists every question, also as FAQPage data', () {
      for (final locale in seoLocales) {
        final page = seoPages.firstWhere((p) => p.faq);
        final html = pages[page.file(locale)]!;
        final graph = (_jsonLd(html)['@graph'] as List).cast<Map>();
        final faq = graph.firstWhere((n) => n['@type'] == 'FAQPage');
        final entities = (faq['mainEntity'] as List).cast<Map>();
        final items = faqItems(locale);
        expect(entities, hasLength(items.length));
        for (var i = 0; i < items.length; i++) {
          expect(entities[i]['name'], items[i].$1);
          expect((entities[i]['acceptedAnswer'] as Map)['text'], items[i].$2);
        }
      }
      // Current payment rules (bookingDeposit.ts).
      expect(
        faqItems('fr').map((i) => i.$2).join(' '),
        allOf(contains('dépôt de 25 \$'), contains('48 heures'), isNot(contains('2 heures'))),
      );
    });

    test('text is escaped and the service area is Granby', () {
      final html = pages['/seo/fr/tarifs.html']!;
      expect(html, contains('<title>Tarifs : le prix exact avant de réserver | Movi-K</title>'));
      final graph = (_jsonLd(html)['@graph'] as List).cast<Map>();
      final service = graph.firstWhere((n) => n['@type'] == 'Service');
      expect(service['areaServed'], {'@type': 'City', 'name': 'Granby'});
    });

    test('a changed index.html template is refused instead of half-written', () {
      expect(
        () => renderSeoPage('<html><head></head><body></body></html>', seoPages.first, 'fr'),
        throwsStateError,
      );
    });
  });

  test('llms.txt describes Movi-K for AI assistants', () {
    final llms = renderLlmsTxt();
    expect(llms, startsWith('# Movi-K\n'));
    expect(llms, contains('infos@movi-k.com'));
    expect(llms, contains('Granby'));
    for (final page in seoPages) {
      expect(llms, contains(page.url('fr')));
      expect(llms, contains(page.url('en')));
    }
    for (final (question, _) in faqItems('fr')) {
      expect(llms, contains('### $question'));
    }
    expect(llms.toLowerCase(), isNot(contains('lancement')));
  });

  test('the build script writes the pages and llms.txt', () {
    final dir = Directory.systemTemp.createTempSync('movik_seo_');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/index.html').writeAsStringSync(_template);
    final pages = renderAllSeoPages(_template);
    for (final entry in pages.entries) {
      final file = File('${dir.path}${entry.key}');
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(entry.value);
    }
    expect(File('${dir.path}/seo/fr/tarifs.html').existsSync(), isTrue);
    expect(File('${dir.path}/seo/fr.html').existsSync(), isTrue);
  });
}
