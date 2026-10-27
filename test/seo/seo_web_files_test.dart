// Search-engine files served by Vercel next to the Flutter app:
// web/robots.txt, web/sitemap.xml, web/404.html, vercel.json and the
// title/description of web/index.html.
//
// vercel.json only sends the app's own routes to index.html; any other
// address gets web/404.html with a real 404 status. These tests make sure
// every route of the real router is still served, so a new screen cannot be
// forgotten in vercel.json.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/router/app_router.dart';

/// Every full path declared in the router, e.g. '/fr/livraison/suivi/:missionId'.
List<String> routerPaths() {
  final paths = <String>[];
  void visit(List<RouteBase> routes, String parent) {
    for (final route in routes) {
      if (route is! GoRoute) continue;
      final path = route.path.startsWith('/')
          ? route.path
          : (parent == '/' ? '/${route.path}' : '$parent/${route.path}');
      paths.add(path);
      visit(route.routes, path);
    }
  }

  visit(AppRouter.router.configuration.routes, '');
  return paths;
}

/// A concrete address for a router path: parameters get a sample value.
String sampleAddress(String routerPath) => routerPath
    .replaceAll(':type', 'privacy')
    .replaceAllMapped(RegExp(r':\w+'), (_) => 'abc123XYZ');

RegExp routerPathRegExp(String routerPath) => RegExp(
  '^${routerPath.split('/').map((s) => s.startsWith(':') ? '[^/]+' : RegExp.escape(s)).join('/')}\$',
);

/// Converts a Vercel `source` (path-to-regexp syntax used in vercel.json:
/// literals, `:name` and `:name(a|b)`) into a RegExp.
RegExp vercelSourceRegExp(String source) {
  final buffer = StringBuffer('^');
  var index = 0;
  for (final m in RegExp(r':(\w+)(\(([^)]*)\))?').allMatches(source)) {
    buffer.write(RegExp.escape(source.substring(index, m.start)));
    buffer.write(m.group(3) != null ? '(?:${m.group(3)})' : '[^/]+');
    index = m.end;
  }
  buffer.write(RegExp.escape(source.substring(index)));
  buffer.write(r'$');
  return RegExp(buffer.toString());
}

List<RegExp> vercelAppRoutes() {
  final config =
      jsonDecode(File('vercel.json').readAsStringSync()) as Map<String, dynamic>;
  final rewrites = (config['rewrites'] as List).cast<Map<String, dynamic>>();
  for (final rewrite in rewrites) {
    expect(rewrite['destination'], '/index.html');
  }
  return rewrites.map((r) => vercelSourceRegExp(r['source'] as String)).toList();
}

bool servedByApp(String address) =>
    vercelAppRoutes().any((source) => source.hasMatch(address));

List<String> robotsDisallowed() => File('web/robots.txt')
    .readAsLinesSync()
    .where((line) => line.startsWith('Disallow:'))
    .map((line) => line.substring('Disallow:'.length).trim())
    .where((rule) => rule.isNotEmpty)
    .toList();

bool blockedByRobots(String address) => robotsDisallowed().any(
  (rule) => RegExp(
    '^${rule.split('*').map(RegExp.escape).join('.*')}',
  ).hasMatch(address),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('vercel.json — app routes and real 404', () {
    test('every router route is served by the Flutter app', () {
      final missing = routerPaths()
          .map(sampleAddress)
          .where((address) => !servedByApp(address))
          .toList();
      expect(missing, isEmpty);
    });

    test('links built by the server and notifications are served', () {
      for (final address in [
        '/',
        '/fr/legal/cancellation', // functions/src/config/trialBookingPolicy.ts
        '/fr/legal/terms',
        '/fr/legal/privacy',
        '/en/livraison/demande', // functions/src/functions/bookingCardSetup.ts
        '/fr/chauffeur/onboarding/complete', // functions/src/lib/appConfig.ts
        '/fr/chauffeur/onboarding/refresh',
        '/es/fournisseur/tableau-de-bord', // push_notification_service.dart
        '/es/livraison/suivi/mission42',
      ]) {
        expect(servedByApp(address), isTrue, reason: address);
      }
    });

    test('unknown addresses are not sent to the app (Vercel answers 404)', () {
      for (final address in [
        '/page-qui-nexiste-pas',
        '/fr/nexiste-pas',
        '/de',
        '/wp-admin',
        '/fr/legal/does-not-exist-type',
        '/fr/livraison/demande/extra',
        '/robots.txt',
        '/sitemap.xml',
      ]) {
        expect(servedByApp(address), isFalse, reason: address);
      }
    });

    test('404 page is not indexed', () {
      final html = File('web/404.html').readAsStringSync();
      expect(html, contains('<meta name="robots" content="noindex">'));
      expect(html, contains('href="/fr"'));
    });
  });

  group('robots.txt and sitemap.xml', () {
    final sitemap = File('web/sitemap.xml').readAsStringSync();
    final locs = RegExp(r'<loc>([^<]+)</loc>')
        .allMatches(sitemap)
        .map((m) => m.group(1)!)
        .toList();

    test('robots.txt points to the sitemap', () {
      expect(
        File('web/robots.txt').readAsStringSync(),
        contains('Sitemap: https://movi-k.com/sitemap.xml'),
      );
    });

    test('robots.txt keeps the public pages open', () {
      for (final address in ['/fr', '/en/delivery', '/es/precios', '/fr/faq']) {
        expect(blockedByRobots(address), isFalse, reason: address);
      }
      for (final address in [
        '/fr/tableau-de-bord',
        '/fr/admin',
        '/fr/admin/chauffeurs/x',
        '/en/livraison/suivi/x',
        '/fr/connexion',
      ]) {
        expect(blockedByRobots(address), isTrue, reason: address);
      }
    });

    test('14 public pages in French, English and Spanish', () {
      expect(locs, hasLength(42));
      expect(locs.toSet(), hasLength(42));
      for (final locale in ['fr', 'en', 'es']) {
        expect(
          locs.where((l) => l.startsWith('https://movi-k.com/$locale')),
          hasLength(14),
        );
      }
    });

    test('every sitemap address is a real, open page', () {
      final routes = routerPaths().map(routerPathRegExp).toList();
      for (final loc in locs) {
        expect(loc, startsWith('https://movi-k.com/'));
        final path = Uri.parse(loc).path;
        expect(routes.any((r) => r.hasMatch(path)), isTrue, reason: loc);
        expect(servedByApp(path), isTrue, reason: loc);
        expect(blockedByRobots(path), isFalse, reason: loc);
      }
    });

    test('every page lists its fr, en, es and x-default versions', () {
      final entries = RegExp(r'<url>([\s\S]*?)</url>').allMatches(sitemap);
      expect(entries, hasLength(42));
      for (final entry in entries) {
        final block = entry.group(1)!;
        final alternates = {
          for (final m in RegExp(
            r'hreflang="([^"]+)" href="([^"]+)"',
          ).allMatches(block))
            m.group(1)!: m.group(2)!,
        };
        expect(alternates.keys.toSet(), {'fr', 'en', 'es', 'x-default'});
        for (final href in alternates.values) {
          expect(locs, contains(href));
        }
        for (final locale in ['fr', 'en', 'es']) {
          expect(alternates[locale], startsWith('https://movi-k.com/$locale'));
        }
        expect(alternates['x-default'], alternates['fr']);
      }
    });
  });

  test('French title and description in the app match web/index.html', () {
    final html = File('web/index.html').readAsStringSync();
    expect(
      html,
      contains('<title>${AppStrings.t('seo_default_title', 'fr')}</title>'),
    );
    expect(
      html,
      contains(
        '<meta name="description" content="${AppStrings.t('seo_default_description', 'fr')}">',
      ),
    );
  });
}
