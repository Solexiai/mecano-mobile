import 'package:image_picker/image_picker.dart';

import 'picked_document_file.dart';

export 'picked_document_file.dart';

/// Hors navigateur : une photo de la galerie (les PDF passent par le web).
Future<PickedDocumentFile?> pickDocumentFile() async {
  final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (picked == null) return null;
  final bytes = await picked.readAsBytes();
  return PickedDocumentFile(
    bytes: bytes,
    name: picked.name,
    mimeType: documentMimeType(picked.mimeType ?? '', picked.name),
  );
}
