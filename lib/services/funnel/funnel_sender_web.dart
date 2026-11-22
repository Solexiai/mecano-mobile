import 'dart:js_interop';

@JS('gtag')
external JSFunction? get _gtag;

/// `gtag('event', name, params)` — sans effet si gtag n'est pas chargé
/// (bloqueur de publicité, page de test).
void sendFunnelEvent(String name, Map<String, Object> params) {
  final gtag = _gtag;
  if (gtag == null) return;
  gtag.callAsFunction(null, 'event'.toJS, name.toJS, params.jsify());
}
