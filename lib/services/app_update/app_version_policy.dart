// Version minimale de l'app Android, réglée dans le Centre de commande
// (`app_config/app_versions`, écrit par la Cloud Function
// updateAppVersionPolicy). Lecture publique : l'app doit la connaître dès
// le démarrage, avant toute connexion. Document absent ou injoignable =>
// aucun minimum : on ne bloque jamais personne par accident.
import 'package:cloud_firestore/cloud_firestore.dart';

class AppVersionPolicy {
  const AppVersionPolicy({this.androidMinBuild = 0, this.note = ''});
  final int androidMinBuild;
  final String note;

  static const none = AppVersionPolicy();

  static AppVersionPolicy fromMap(Map<String, dynamic>? data) {
    final min = data?['android_min_build'];
    final note = data?['note'];
    return AppVersionPolicy(
      androidMinBuild: min is int && min >= 0 ? min : 0,
      note: note is String ? note : '',
    );
  }
}

typedef AppVersionPolicyLoader = Future<AppVersionPolicy> Function();

Future<AppVersionPolicy> loadAppVersionPolicyFromFirestore() async {
  try {
    final snap = await FirebaseFirestore.instance
        .doc('app_config/app_versions')
        .get()
        .timeout(const Duration(seconds: 8));
    return AppVersionPolicy.fromMap(snap.data());
  } catch (_) {
    return AppVersionPolicy.none;
  }
}
