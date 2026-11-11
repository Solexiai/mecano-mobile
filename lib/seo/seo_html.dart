// -----------------------------------------------------------------------------
// seo_html.dart — fabrique, à partir du index.html construit par Flutter, une
// page HTML lisible sans JavaScript pour chaque page publique (Daniel,
// 2026-11-10), ainsi que /llms.txt pour les assistants IA.
//
// Ce que chaque page ajoute au index.html :
//   - <html lang>, <title>, description, Open Graph propres à la page ;
//   - adresse canonique et versions fr / en / es (hreflang) ;
//   - données structurées schema.org (Organization, WebSite, WebPage,
//     Service, FAQPage, BreadcrumbList) — sans note ni avis inventés ;
//   - le texte de la page dans le <body>, visible pendant le chargement de
//     l'app puis masqué à l'écran (gardé pour les robots) quand Flutter
//     affiche sa première image (événement `flutter-first-frame`).
// Le contenu est le même pour les personnes et pour les robots.
//
// Dart pur : utilisé par tool/build_seo_pages.dart (`dart run`) et testé par
// test/seo/seo_pages_test.dart.
// -----------------------------------------------------------------------------

import 'dart:convert';

import '../content/faq_content.dart';
import 'seo_pages.dart';

String _esc(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

String _t(Map<String, String> text, String locale) => text[locale] ?? text['fr']!;

const Map<String, Map<String, String>> _nav = {
  'delivery': {'fr': 'Livraison', 'en': 'Delivery', 'es': 'Entrega'},
  'pricing': {'fr': 'Tarifs', 'en': 'Pricing', 'es': 'Precios'},
  'how': {'fr': 'Comment ça marche', 'en': 'How it works', 'es': 'Cómo funciona'},
  'safety': {'fr': 'Sécurité', 'en': 'Safety', 'es': 'Seguridad'},
  'faq': {'fr': 'FAQ', 'en': 'FAQ', 'es': 'Preguntas'},
  'granby': {'fr': 'Granby', 'en': 'Granby', 'es': 'Granby'},
  'driver': {'fr': 'Devenir chauffeur', 'en': 'Become a driver', 'es': 'Ser conductor'},
  'about': {'fr': 'À propos', 'en': 'About', 'es': 'Acerca de'},
  'contact': {'fr': 'Contact', 'en': 'Contact', 'es': 'Contacto'},
};

const Map<String, String> _languageNames = {
  'fr': 'Français',
  'en': 'English',
  'es': 'Español',
};

const Map<String, String> _quoteLabel = {
  'fr': 'Obtenir mon prix',
  'en': 'Get my price',
  'es': 'Obtener mi precio',
};

const Map<String, String> _driverLabel = {
  'fr': 'S’inscrire comme chauffeur',
  'en': 'Sign up as a driver',
  'es': 'Registrarse como conductor',
};

const Map<String, String> _serviceType = {
  'fr': 'Livraison de meubles, d’électroménagers et de gros objets',
  'en': 'Delivery of furniture, appliances and large items',
  'es': 'Entrega de muebles, electrodomésticos y objetos grandes',
};

const Map<String, String> _ogLocale = {'fr': 'fr_CA', 'en': 'en_CA', 'es': 'es_ES'};

SeoPage get _homePage => seoPages.firstWhere((p) => p.id == 'home');
SeoPage get _deliveryPage => seoPages.firstWhere((p) => p.id == 'delivery');

/// Les sections affichées pour cette page (questions fréquentes comprises).
List<(String, String)> seoSectionsFor(SeoPage page, String locale) => page.faq
    ? faqItems(locale)
    : [for (final s in page.sections) (_t(s.heading, locale), _t(s.body, locale))];

/// Données structurées schema.org de la page (objet JSON).
Map<String, Object?> seoStructuredData(SeoPage page, String locale) {
  const org = '$seoSiteUrl/#organization';
  const site = '$seoSiteUrl/#website';
  final url = page.url(locale);
  final graph = <Map<String, Object?>>[
    {
      '@type': 'Organization',
      '@id': org,
      'name': 'Movi-K',
      'url': '$seoSiteUrl/',
      'logo': '$seoSiteUrl/icons/Icon-512.png',
      'email': seoContactEmail,
      // Pas de limite de distance depuis le 11 nov. 2026 : Granby est le
      // lieu de naissance, pas une limite de service.
      'foundingLocation': {'@type': 'Place', 'name': 'Granby, Québec, Canada'},
    },
    {
      '@type': 'WebSite',
      '@id': site,
      'url': '$seoSiteUrl/',
      'name': 'Movi-K',
      'inLanguage': ['fr-CA', 'en-CA', 'es'],
      'publisher': {'@id': org},
    },
    {
      '@type': page.faq ? 'FAQPage' : 'WebPage',
      '@id': '$url#webpage',
      'url': url,
      'name': _t(page.titles, locale),
      'description': _t(page.descriptions, locale),
      'inLanguage': locale,
      'isPartOf': {'@id': site},
      if (page.faq)
        'mainEntity': [
          for (final (question, answer) in faqItems(locale))
            {
              '@type': 'Question',
              'name': question,
              'acceptedAnswer': {'@type': 'Answer', 'text': answer},
            },
        ],
    },
    if (page.kind != SeoPageKind.core ||
        const {'home', 'delivery', 'pricing', 'granby'}.contains(page.id))
      {
        '@type': 'Service',
        '@id': '$url#service',
        // Page par objet : le nom du service est celui de la page.
        'name': page.kind == SeoPageKind.object
            ? _t(page.headings, locale)
            : _t(_serviceType, locale),
        'serviceType': _t(_serviceType, locale),
        'provider': {'@id': org},
        // Seules les pages de ville nomment une ville : pas de limite de
        // distance depuis le 11 nov. 2026.
        if (page.city != null) 'areaServed': {'@type': 'City', 'name': page.city},
        'url': url,
      },
    if (page.id != 'home')
      {
        '@type': 'BreadcrumbList',
        'itemListElement': [
          {
            '@type': 'ListItem',
            'position': 1,
            'name': 'Movi-K',
            'item': _homePage.url(locale),
          },
          if (page.kind != SeoPageKind.core)
            {
              '@type': 'ListItem',
              'position': 2,
              'name': _t(_nav['delivery']!, locale),
              'item': _deliveryPage.url(locale),
            },
          {
            '@type': 'ListItem',
            'position': page.kind == SeoPageKind.core ? 2 : 3,
            'name': _t(page.headings, locale),
            'item': url,
          },
        ],
      },
  ];
  return {'@context': 'https://schema.org', '@graph': graph};
}

String _headTags(SeoPage page, String locale) {
  final json = jsonEncode(seoStructuredData(page, locale)).replaceAll('</', '<\\/');
  final buffer = StringBuffer()
    ..writeln('  <link rel="canonical" href="${page.url(locale)}">');
  for (final l in seoLocales) {
    buffer.writeln('  <link rel="alternate" hreflang="$l" href="${page.url(l)}">');
  }
  buffer
    ..writeln('  <link rel="alternate" hreflang="x-default" href="${page.url('fr')}">')
    ..writeln('  <meta property="og:url" content="${page.url(locale)}">')
    ..writeln('  <meta property="og:locale" content="${_ogLocale[locale]}">')
    ..writeln('  <meta property="og:image" content="$seoSiteUrl/icons/Icon-512.png">')
    ..writeln('  <script type="application/ld+json">$json</script>')
    ..writeln(
      '  <style>.mk-static{font-family:system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;'
      'color:#0F2A5C;max-width:760px;margin:0 auto;padding:24px 16px;line-height:1.55}'
      '.mk-static a{color:#0879E8}.mk-static nav a{margin-right:12px;display:inline-block}'
      '.mk-static h1{font-size:30px;line-height:1.15}.mk-static h2{font-size:19px;margin-top:22px}'
      '.mk-cta{display:inline-block;background:#0879E8;color:#fff!important;padding:12px 20px;'
      'border-radius:10px;text-decoration:none;font-weight:700}'
      '.mk-static--hidden{position:absolute!important;width:1px;height:1px;overflow:hidden;'
      'clip:rect(0 0 0 0);white-space:nowrap}</style>',
    );
  return buffer.toString();
}

String _body(SeoPage page, String locale) {
  final b = StringBuffer()
    ..writeln('  <div id="movik-static" class="mk-static">')
    ..writeln('    <header>')
    ..writeln('      <p><a href="${_homePage.path(locale)}"><strong>Movi-K</strong></a></p>')
    ..write('      <nav>');
  for (final entry in _nav.entries) {
    final target = seoPages.firstWhere((p) => p.id == entry.key);
    b.write('<a href="${target.path(locale)}">${_esc(_t(entry.value, locale))}</a>');
  }
  b
    ..writeln('</nav>')
    ..writeln('    </header>')
    ..writeln('    <main>')
    ..writeln('      <h1>${_esc(_t(page.headings, locale))}</h1>')
    ..writeln('      <p>${_esc(_t(page.intros, locale))}</p>');
  for (final (heading, body) in seoSectionsFor(page, locale)) {
    b
      ..writeln('      <section>')
      ..writeln('        <h2>${_esc(heading)}</h2>')
      ..writeln('        <p>${_esc(body)}</p>')
      ..writeln('      </section>');
  }
  for (final group in seoLinkGroups(page, locale)) {
    b
      ..writeln('      <section>')
      ..writeln('        <h2>${_esc(group.heading)}</h2>')
      ..write('        <ul>');
    for (final (label, path) in group.links) {
      b.write('<li><a href="$path">${_esc(label)}</a></li>');
    }
    b
      ..writeln('</ul>')
      ..writeln('      </section>');
  }
  final driver = page.id == 'driver';
  final cta = driver ? '/$locale/devenir-chauffeur/inscription' : '/$locale/livraison/demande';
  b
    ..writeln(
      '      <p><a class="mk-cta" href="$cta">${_esc(_t(driver ? _driverLabel : _quoteLabel, locale))}</a></p>',
    )
    ..writeln('    </main>')
    ..writeln('    <footer>')
    ..writeln('      <p>Movi-K · <a href="mailto:$seoContactEmail">$seoContactEmail</a></p>')
    ..write('      <p>');
  for (final l in seoLocales) {
    b.write('<a href="${page.path(l)}" hreflang="$l" lang="$l">${_languageNames[l]}</a> ');
  }
  b
    ..writeln('</p>')
    ..writeln('    </footer>')
    ..writeln('  </div>')
    ..writeln(
      '  <script>window.addEventListener("flutter-first-frame",function(){'
      'var e=document.getElementById("movik-static");'
      'if(e){e.setAttribute("aria-hidden","true");e.classList.add("mk-static--hidden");}});</script>',
    );
  return b.toString();
}

String _replaceOnce(String html, RegExp pattern, String replacement, String what) {
  final matches = pattern.allMatches(html).length;
  if (matches != 1) {
    throw StateError('index.html : $what attendu une fois, trouvé $matches fois.');
  }
  return html.replaceFirst(pattern, replacement);
}

/// La page HTML publique [page] en [locale], construite sur [indexHtml].
String renderSeoPage(String indexHtml, SeoPage page, String locale) {
  final title = _esc(_t(page.titles, locale));
  final description = _esc(_t(page.descriptions, locale));
  var html = indexHtml;
  html = _replaceOnce(html, RegExp(r'<html lang="[^"]*">'), '<html lang="$locale">', '<html lang>');
  html = _replaceOnce(html, RegExp(r'<title>[^<]*</title>'), '<title>$title</title>', '<title>');
  html = _replaceOnce(
    html,
    RegExp(r'<meta name="description" content="[^"]*">'),
    '<meta name="description" content="$description">',
    'meta description',
  );
  html = _replaceOnce(
    html,
    RegExp(r'<meta property="og:title" content="[^"]*">'),
    '<meta property="og:title" content="$title">',
    'og:title',
  );
  html = _replaceOnce(
    html,
    RegExp(r'<meta property="og:description" content="[^"]*">'),
    '<meta property="og:description" content="$description">',
    'og:description',
  );
  html = _replaceOnce(html, RegExp(r'</head>'), '${_headTags(page, locale)}</head>', '</head>');
  html = _replaceOnce(html, RegExp(r'<body>'), '<body>\n${_body(page, locale)}', '<body>');
  return html;
}

/// Toutes les pages : chemin du fichier (ex. '/seo/fr/tarifs.html') → HTML.
Map<String, String> renderAllSeoPages(String indexHtml) => {
  for (final page in seoPages)
    for (final locale in seoLocales) page.file(locale): renderSeoPage(indexHtml, page, locale),
};

/// /llms.txt : résumé du site pour les assistants IA (format llmstxt.org).
String renderLlmsTxt() {
  final b = StringBuffer()
    ..writeln('# Movi-K')
    ..writeln()
    ..writeln(
      '> Movi-K (movi-k.com) est un service de livraison de meubles, '
      'd’électroménagers et de gros objets, né à Granby (Québec, Canada). Pas de '
      'limite de distance : le client prend une photo, voit le prix exact (taxes '
      'et détail inclus) avant de réserver, puis un chauffeur vérifié proche de '
      'l’adresse de ramassage accepte la livraison. Movi-K (movi-k.com) is a '
      'delivery service for furniture, appliances and large items, born in '
      'Granby, Quebec, Canada, with no distance limit.',
    )
    ..writeln()
    ..writeln('Contact : $seoContactEmail')
    ..writeln();
  for (final locale in ['fr', 'en']) {
    b
      ..writeln(locale == 'fr' ? '## Pages (français)' : '## Pages (English)')
      ..writeln();
    for (final page in seoPages) {
      b.writeln('- [${_t(page.headings, locale)}](${page.url(locale)}): ${_t(page.descriptions, locale)}');
    }
    b.writeln();
  }
  for (final locale in ['fr', 'en']) {
    b
      ..writeln(locale == 'fr' ? '## Questions fréquentes' : '## Frequently asked questions')
      ..writeln();
    for (final (question, answer) in faqItems(locale)) {
      b
        ..writeln('### $question')
        ..writeln()
        ..writeln(answer)
        ..writeln();
    }
  }
  return b.toString();
}
