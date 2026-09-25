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
        (uri.queryParametersAll['category']?.length ?? 0) > 1) return null;
    return path(locale, category: uri.queryParameters['category']);
  }
  static String loginPath(String locale, {String? category}) => Uri(
    path: '/$locale/connexion', queryParameters: {'returnTo': path(locale, category: category)},
  ).toString();
}
