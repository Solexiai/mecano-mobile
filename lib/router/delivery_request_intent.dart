import '../services/demo_data_service.dart';

/// Existing request route only. Never accept an arbitrary post-login redirect.
abstract final class DeliveryRequestIntent {
  static String? category(String? value) =>
      DemoDataService.deliveryCategories.contains(value) ? value : null;
  static String path(String locale, {String? category}) {
    final selected = DeliveryRequestIntent.category(category);
    return Uri(path: '/$locale/livraison/demande',
      queryParameters: selected == null ? null : {'category': selected}).toString();
  }
  static String? safeReturnPath(String? value, String locale) {
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.hasScheme || uri.hasAuthority || uri.hasFragment ||
        uri.path != '/$locale/livraison/demande' ||
        uri.queryParametersAll.keys.any((key) => key != 'category') ||
        (uri.queryParametersAll['category']?.length ?? 0) > 1) {
      return null;
    }
    return path(locale, category: uri.queryParameters['category']);
  }
  static String loginPath(String locale, {String? category}) => Uri(
    path: '/$locale/connexion', queryParameters: {'returnTo': path(locale, category: category)},
  ).toString();
  /// Translate only the known delivery intent, not arbitrary query redirects.
  static String switchLocale(Uri current, String locale) {
    const locales = ['fr', 'en', 'es'];
    if (!locales.contains(locale)) { throw ArgumentError.value(locale, 'locale'); }
    final segments = current.pathSegments;
    if (segments.isEmpty || !locales.contains(segments.first)) { return '/$locale'; }
    final rest = segments.skip(1).join('/');
    if (['livraison/demande', 'delivery/request', 'entrega/solicitud'].contains(rest)) {
      return path(locale, category: current.queryParameters['category']);
    }
    if (['connexion', 'sign-in', 'iniciar-sesion'].contains(rest)) {
      final allowed = safeReturnPath(current.queryParameters['returnTo'], segments.first);
      if (allowed != null) {
        return loginPath(locale, category: Uri.parse(allowed).queryParameters['category']);
      }
    }
    return '/$locale${rest.isEmpty ? '' : '/$rest'}';
  }

}
