// Native fallback is memory-only: do not persist personal details unencrypted.
final Map<String, String> _session = {};
String? readSession(String key) => _session[key];
void writeSession(String key, String value) {
  _session[key] = value;
}

void removeSession(String key) {
  _session.remove(key);
}
