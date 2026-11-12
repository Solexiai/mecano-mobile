import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'picked_document_file.dart';

export 'picked_document_file.dart';

/// Navigateur : photo ou PDF, via le sélecteur de fichiers.
Future<PickedDocumentFile?> pickDocumentFile() {
  final completer = Completer<PickedDocumentFile?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/*,application/pdf';

  void finish(PickedDocumentFile? file) {
    if (!completer.isCompleted) completer.complete(file);
  }

  Future<void> read() async {
    final file = input.files?.item(0);
    if (file == null) {
      finish(null);
      return;
    }
    final buffer = await file.arrayBuffer().toDart;
    finish(
      PickedDocumentFile(
        bytes: buffer.toDart.asUint8List(),
        name: file.name,
        mimeType: documentMimeType(file.type, file.name),
      ),
    );
  }

  input.addEventListener(
    'change',
    ((web.Event _) {
      read().catchError((Object _) => finish(null));
    }).toJS,
  );
  input.addEventListener('cancel', ((web.Event _) => finish(null)).toJS);
  input.click();
  return completer.future;
}
