import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Télécharge [content] sous le nom [fileName] (navigateur). Retourne `true`
/// quand le fichier a été proposé au téléchargement.
Future<bool> saveTextFile({
  required String content,
  required String fileName,
  String mimeType = 'text/csv;charset=utf-8',
}) async {
  final blob = web.Blob(
    [content.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  web.document.body?.append(link);
  link.click();
  link.remove();
  Future<void>.delayed(
    const Duration(seconds: 30),
    () => web.URL.revokeObjectURL(url),
  );
  return true;
}
