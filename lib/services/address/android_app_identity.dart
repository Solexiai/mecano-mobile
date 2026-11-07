// Identité de l'app Android pour les clés Google restreintes
// « Applications Android » (2026-11-07).
//
// Sur le site, la clé Google Places est restreinte par domaine (movi-k.com)
// et Google vérifie le « Referer » du navigateur. Une app Android n'a pas de
// Referer : sa clé est restreinte par NOM DE PAQUET + SHA-1 du certificat de
// signature, et l'API Places (New) exige alors deux en-têtes sur chaque
// appel : `X-Android-Package` et `X-Android-Cert`. Cette classe les fournit
// (SHA-1 calculé côté natif, voir MainActivity.kt). Hors Android : aucun
// en-tête (null), comportement inchangé.
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AndroidAppIdentity {
  const AndroidAppIdentity({required this.packageName, required this.certSha1});
  final String packageName;

  /// SHA-1 du certificat de signature, hexadécimal majuscule sans « : ».
  final String certSha1;

  Map<String, String> get placesHeaders => {
    'X-Android-Package': packageName,
    'X-Android-Cert': certSha1,
  };

  static const _channel = MethodChannel('movik/app_identity');
  static Future<AndroidAppIdentity?>? _cached;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Null hors Android, ou si l'identité ne peut pas être lue (la clé sera
  /// alors refusée par Google et l'écran affiche « service indisponible »,
  /// jamais une fausse suggestion).
  static Future<AndroidAppIdentity?> load() {
    if (!supported) return Future.value(null);
    return _cached ??= _load();
  }

  static Future<AndroidAppIdentity?> _load() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final sha1 = await _channel.invokeMethod<String>('signingCertSha1');
      if (info.packageName.isEmpty || sha1 == null || sha1.isEmpty) return null;
      return AndroidAppIdentity(packageName: info.packageName, certSha1: sha1);
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static void resetCache() => _cached = null;
}
