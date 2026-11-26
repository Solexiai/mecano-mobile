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

@JS('movikMeta')
external _MovikMeta? get _movikMeta;

/// `window.movikMeta`, posé par web/meta_pixel.js.
extension type _MovikMeta._(JSObject _) implements JSObject {
  external void track(JSString name, JSAny? params, JSString? eventId);
}

/// `movikMeta.track(name, params, eventId)` — sans effet si meta_pixel.js
/// n'est pas chargé. Le fichier décide seul d'envoyer ou non (identifiant
/// réglé, accord du visiteur, page publique).
void sendMetaEvent(String name, Map<String, Object> params, String? eventId) {
  final meta = _movikMeta;
  if (meta == null) return;
  meta.track(name.toJS, params.jsify(), eventId?.toJS);
}
