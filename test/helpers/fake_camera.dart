// Caméra et téléversement simulés pour les parcours photo du chauffeur
// (ramassage 2026-10-26, livraison). Même principe que
// driver_active_mission_proof_upload_test.dart : `extends ImagePickerPlatform`
// (jamais `implements`) pour passer `PlatformInterface.verify`.
import 'dart:typed_data';

import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:movik_connect/backend/repositories/proof_upload_repository.dart';

/// Un PNG 1x1 valide : la prévisualisation le décode réellement.
final Uint8List fakeCameraPng = Uint8List.fromList(const [
    137,
    80,
    78,
    71,
    13,
    10,
    26,
    10,
    0,
    0,
    0,
    13,
    73,
    72,
    68,
    82,
    0,
    0,
    0,
    1,
    0,
    0,
    0,
    1,
    8,
    4,
    0,
    0,
    0,
    181,
    28,
    12,
    2,
    0,
    0,
    0,
    11,
    73,
    68,
    65,
    84,
    120,
    218,
    99,
    100,
    248,
    15,
    0,
    1,
    5,
    1,
    1,
    39,
    24,
    227,
    102,
    0,
    0,
    0,
    0,
    73,
    69,
    78,
    68,
    174,
    66,
    96,
    130,
  ]);

class FakeCamera extends ImagePickerPlatform {
  int calls = 0;

  /// `true` : le chauffeur annule la caméra (aucune photo).
  bool cancel = false;

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    calls++;
    if (cancel) return null;
    return XFile.fromData(fakeCameraPng, name: 'photo.jpg', mimeType: 'image/jpeg');
  }
}

class FakeProofUploads implements ProofUploadRepository {
  final List<String> fileNames = [];

  @override
  Future<String> uploadDeliveryProof({
    required String missionId,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  }) async {
    fileNames.add(fileName);
    return 'https://storage.example.test/delivery_proofs/$missionId/$fileName';
  }
}
