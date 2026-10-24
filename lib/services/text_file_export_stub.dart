import 'package:flutter/services.dart';

/// Hors navigateur : le contenu est copié dans le presse-papiers. Retourne
/// `false` pour que l'écran l'indique à l'utilisateur.
Future<bool> saveTextFile({
  required String content,
  required String fileName,
  String mimeType = 'text/csv;charset=utf-8',
}) async {
  await Clipboard.setData(ClipboardData(text: content));
  return false;
}
