import 'package:web/web.dart' as web;

import 'page_meta.dart';

/// Path of the address shown in the browser, e.g. '/en/delivery'.
String? currentWebPath() => web.window.location.pathname;

/// Writes the page language, title and description into the HTML document,
/// where search engines and screen readers read them.
void applyPageMeta(PageMeta meta) {
  final document = web.document;
  document.documentElement?.setAttribute('lang', meta.lang);
  if (document.title != meta.title) document.title = meta.title;

  var description = document.querySelector('meta[name="description"]');
  if (description == null) {
    description = document.createElement('meta')
      ..setAttribute('name', 'description');
    document.head?.append(description);
  }
  description.setAttribute('content', meta.description);
}
