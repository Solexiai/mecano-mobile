import '../l10n/app_strings.dart';

/// Language, title and description of a web page, taken from its address
/// (/fr, /en, /es) and never from the language of a previous visit.
class PageMeta {
  static const supportedLocales = ['fr', 'en', 'es'];

  final String lang;
  final String title;
  final String description;

  const PageMeta({
    required this.lang,
    required this.title,
    required this.description,
  });

  /// The language in the first segment of [path] ('/en/delivery' -> 'en'),
  /// or null when the address has no supported language prefix.
  static String? localeInPath(String path) {
    final segments = Uri(path: path).pathSegments;
    if (segments.isEmpty) return null;
    final first = segments.first.toLowerCase();
    return supportedLocales.contains(first) ? first : null;
  }

  factory PageMeta.forLocale(String locale) {
    final lang = supportedLocales.contains(locale) ? locale : 'fr';
    return PageMeta(
      lang: lang,
      title: AppStrings.t('seo_default_title', lang),
      description: AppStrings.t('seo_default_description', lang),
    );
  }

  /// Pages without a language prefix (the root '/' redirects to '/fr')
  /// use French, the default language of the site.
  factory PageMeta.forPath(String path) =>
      PageMeta.forLocale(localeInPath(path) ?? 'fr');
}
