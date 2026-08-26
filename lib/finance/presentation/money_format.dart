// ---------------------------------------------------------------------------
// Money formatting helpers — affichage uniquement, AUCUN recalcul financier.
//
// Dupliqué intentionnellement depuis les helpers privés de
// `mission_finance_section.dart` (Bloc J) plutôt que factorisé par un
// import cross-dossier `screens/customer` -> `screens/dashboard` : ces
// fonctions sont si petites (conversion cents/dollars pour affichage) que
// la duplication est préférable à un couplage entre deux zones d'écran
// indépendantes (client / chauffeur).
// ---------------------------------------------------------------------------

/// Formatte un montant en unités mineures entières (cents) en chaîne
/// lisible `"XX.XX $"`. Simple conversion d'affichage, aucun recalcul.
String formatMinorAmount(int minor, {String currencySymbol = '\$'}) {
  return '${(minor / 100).toStringAsFixed(2)} $currencySymbol';
}

/// Formatte un montant en unités majeures (`double`, ex: `FinancialSnapshot`)
/// en chaîne lisible `"XX.XX $"`.
String formatMajorAmount(double major, {String currencySymbol = '\$'}) {
  return '${major.toStringAsFixed(2)} $currencySymbol';
}

/// [connector] : mot de liaison localisé entre la date et l'heure
/// (Bloc K2, K2-3). Fonction pure sans accès à `LocaleProvider` : la
/// locale doit être résolue par l'appelant via
/// `AppStrings.t('datetime_connector_at', locale)`. Valeur par défaut
/// `'à'` conservée pour rétrocompatibilité avec les appels existants non
/// encore mis à jour.
String formatDisplayDate(DateTime dt, {String connector = 'à'}) {
  final local = dt.toLocal();
  final d = local.day.toString().padLeft(2, '0');
  final m = local.month.toString().padLeft(2, '0');
  final y = local.year.toString();
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$d/$m/$y $connector $h:$min';
}
