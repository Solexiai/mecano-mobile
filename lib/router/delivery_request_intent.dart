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
  /// CLI-08 (2026-10-28) : en plus de la demande, le suivi d'une livraison
  /// et l'espace client peuvent être repris après connexion. Toujours une
  /// liste blanche de chemins locaux, jamais une redirection arbitraire.
  static final RegExp _trackingPath = RegExp(r'^/(fr|en|es)/livraison/suivi/([A-Za-z0-9_-]{1,100})$');
  static String? safeReturnPath(String? value, String locale) {
    if (value == null) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || uri.hasScheme || uri.hasAuthority || uri.hasFragment) return null;
    if (uri.path == '/$locale/livraison/demande') {
      if (uri.queryParametersAll.keys.any((key) => key != 'category') ||
          (uri.queryParametersAll['category']?.length ?? 0) > 1) {
        return null;
      }
      return path(locale, category: uri.queryParameters['category']);
    }
    if (uri.hasQuery) return null;
    final tracking = _trackingPath.firstMatch(uri.path);
    if (tracking != null && tracking.group(1) == locale) return '/$locale/livraison/suivi/${tracking.group(2)}';
    if (uri.path == '/$locale/tableau-de-bord' || uri.path == '/$locale/notifications') return uri.path;
    return null;
  }
  static String loginPath(String locale, {String? category}) => Uri(
    path: '/$locale/connexion', queryParameters: {'returnTo': path(locale, category: category)},
  ).toString();
  /// Lien de connexion qui ramène sur [target] (chemin de la liste blanche
  /// ci-dessus) ; sans `returnTo` si le chemin n'est pas admis.
  static String loginPathReturningTo(String locale, String target) {
    final allowed = safeReturnPath(target, locale);
    return Uri(
      path: '/$locale/connexion',
      queryParameters: allowed == null ? null : {'returnTo': allowed},
    ).toString();
  }
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
