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
  test('36 public pages in 3 languages, all in the sitemap', () {
    // 10 pages d’origine, 13 par objet, 13 par ville (vague 1, 11 nov. 2026).
    expect(seoPages.where((p) => p.kind == SeoPageKind.core), hasLength(10));
    expect(seoObjectPages, hasLength(13));
    expect(seoCityPages, hasLength(13));
    expect(seoPages, hasLength(36));
    expect(seoPages.map((p) => p.id).toSet(), hasLength(36));
    final sitemap = _sitemapPaths();
    final seoPaths = {
      for (final page in seoPages)
        for (final locale in seoLocales) page.path(locale),
    };
    expect(seoPaths, hasLength(108));
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
    // First app rule with a parameter (e.g. /:locale(fr|en|es)/:page(...)).
    final firstGeneric = rewrites.indexWhere(
      (r) => r['destination'] == '/index.html' && (r['source'] as String).contains(':'),
    );
    expect(firstGeneric, greaterThan(0));
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
      expect(pages, hasLength(108));
      expect(pages.keys, contains('/seo/fr/transport/refrigerateur.html'));
      expect(pages.keys, contains('/seo/en/cities/sherbrooke.html'));
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

    test('no distance limit: only city pages name a service area', () {
      final html = pages['/seo/fr/tarifs.html']!;
      expect(html, contains('<title>Tarifs : le prix exact avant de réserver | Movi-K</title>'));
      Map service(String file) => (_jsonLd(pages[file]!)['@graph'] as List)
          .cast<Map>()
          .firstWhere((n) => n['@type'] == 'Service');
      expect(service('/seo/fr/tarifs.html').containsKey('areaServed'), isFalse);
      expect(service('/seo/fr.html').containsKey('areaServed'), isFalse);
      expect(service('/seo/fr/granby.html')['areaServed'], {'@type': 'City', 'name': 'Granby'});
      expect(service('/seo/en/cities/montreal.html')['areaServed'], {'@type': 'City', 'name': 'Montréal'});
      expect(service('/seo/fr/transport/refrigerateur.html').containsKey('areaServed'), isFalse);
      for (final page in seoPages) {
        final graph = (_jsonLd(pages[page.file('fr')]!)['@graph'] as List).cast<Map>();
        expect(
          graph.any((n) => n['@type'] == 'Service' && n.containsKey('areaServed')),
          page.kind == SeoPageKind.city || page.id == 'granby',
          reason: page.id,
        );
      }
      final org = (_jsonLd(html)['@graph'] as List).cast<Map>().firstWhere((n) => n['@type'] == 'Organization');
      expect(org.containsKey('areaServed'), isFalse);
      expect(faqItems('fr').map((i) => i.$2).join(' '), contains('sans limite de distance'));
    });

    test('a changed index.html template is refused instead of half-written', () {
      expect(
        () => renderSeoPage('<html><head></head><body></body></html>', seoPages.first, 'fr'),
        throwsStateError,
      );
    });
  });

  group('pages by item and by city', () {
    final pages = renderAllSeoPages(_template);

    test('each page has its own text, not a copy with a new name', () {
      for (final locale in seoLocales) {
        final intros = seoGuidePages.map((p) => p.intros[locale]!).toList();
        expect(intros.toSet(), hasLength(intros.length), reason: locale);
        // Per item: what we move and how to get it ready are its own.
        for (final kind in [0, 1]) {
          final bodies = seoObjectPages
              .map((p) => p.sections[kind].body[locale]!)
              .toList();
          expect(bodies.toSet(), hasLength(bodies.length), reason: '$locale/$kind');
        }
        // Per city: its own neighbouring areas.
        final areas = seoCityPages.map((p) => p.sections.first.body[locale]!).toList();
        expect(areas.toSet(), hasLength(areas.length), reason: locale);
      }
      for (final page in seoCityPages) {
        expect(page.city, isNotNull, reason: page.id);
        expect(page.sections.first.body['fr'], startsWith(page.city!));
        expect(page.sections.first.body['fr'], contains('sans limite de distance'));
      }
    });

    test('the delivery page and every guide page link to the others', () {
      final delivery = seoPages.firstWhere((p) => p.id == 'delivery');
      for (final page in [delivery, ...seoGuidePages]) {
        for (final locale in seoLocales) {
          final html = pages[page.file(locale)]!;
          final groups = seoLinkGroups(page, locale);
          expect(groups, hasLength(2), reason: page.id);
          for (final other in [...seoGuidePages, seoPageForPath('/fr/granby')!]) {
            if (other.id == page.id) continue;
            expect(html, contains('href="${other.path(locale)}"'), reason: '${page.id} → ${other.id}');
          }
          expect(html, isNot(contains('href="${page.path(locale)}">${page.label(locale)}')));
        }
      }
      for (final id in ['home', 'pricing', 'faq', 'granby']) {
        expect(seoLinkGroups(seoPages.firstWhere((p) => p.id == id), 'fr'), isEmpty);
      }
    });

    test('breadcrumb: Movi-K › Livraison › page', () {
      final graph = (_jsonLd(pages['/seo/fr/transport/laveuse-secheuse.html']!)['@graph'] as List)
          .cast<Map>();
      final crumbs = (graph.firstWhere((n) => n['@type'] == 'BreadcrumbList')['itemListElement'] as List)
          .cast<Map>();
      expect(crumbs.map((c) => c['position']), [1, 2, 3]);
      expect(crumbs[1]['item'], 'https://movi-k.com/fr/livraison');
      expect(crumbs[2]['item'], 'https://movi-k.com/fr/transport/laveuse-secheuse');
    });

    test('rules match the FAQ: deposit, refund, stairs only if asked', () {
      final text = seoGuidePages
          .expand((p) => p.sections.map((s) => s.body['fr']!))
          .join(' ');
      expect(text, contains('dépôt de 25 \$'));
      expect(text, contains('votre dépôt est remboursé'));
      expect(text, contains('seulement si vous les demandez'));
      expect(text.toLowerCase(), isNot(contains('garanti')));
      final store = seoPageForPath('/fr/transport/achats-en-magasin')!;
      expect(store.sections.first.body['fr'], contains('non affilié'));
    });

    test('switching language keeps the same page', () {
      expect(seoPageForPath('/en/cities/quebec')!.path('fr'), '/fr/villes/quebec');
      expect(seoPageForPath('/fr/transport/refrigerateur')!.path('es'), '/es/transporte/refrigerador');
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
