import 'package:web/web.dart' as web;

String? readSession(String key) => web.window.sessionStorage.getItem(key);
void writeSession(String key, String value) =>
    web.window.sessionStorage.setItem(key, value);
void removeSession(String key) => web.window.sessionStorage.removeItem(key);
