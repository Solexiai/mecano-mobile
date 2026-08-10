// ---------------------------------------------------------------------------
// BackendStatus — indique si le backend Firebase réel est configuré et
// joignable. Exposé globalement (via Provider) pour que TOUT écran puisse
// afficher un état `not_configured` honnête plutôt que de simuler des
// données réelles.
//
// isConfigured = false tant que :
// - Firebase.initializeApp() n'a pas réussi (pas de firebase_options.dart
//   valide fourni par l'utilisateur), OU
// - une vérification de connectivité Firestore échoue.
// ---------------------------------------------------------------------------

class BackendStatus {
  final bool isConfigured;
  final String reason;

  const BackendStatus({required this.isConfigured, required this.reason});

  const BackendStatus.notConfigured([this.reason = 'firebase_not_initialized'])
      : isConfigured = false;

  const BackendStatus.ready() : isConfigured = true, reason = 'ok';
}
