import 'dart:typed_data';

/// Fichier choisi par l'agent : contenu, nom d'origine et type MIME.
class PickedDocumentFile {
  const PickedDocumentFile({
    required this.bytes,
    required this.name,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String name;
  final String mimeType;
}

/// Type MIME accepté par le serveur, déduit du type annoncé ou du nom.
String documentMimeType(String declared, String name) {
  const accepted = {
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/heic',
    'application/pdf',
  };
  final type = declared.toLowerCase();
  if (accepted.contains(type)) return type;
  if (type == 'image/jpg') return 'image/jpeg';
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' || 'heif' => 'image/heic',
    _ => 'image/jpeg',
  };
}
