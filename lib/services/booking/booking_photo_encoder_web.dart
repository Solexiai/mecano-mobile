import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<Uint8List> encodeBookingPhoto(Uint8List bytes, String mimeType) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final image = web.HTMLImageElement()..src = url;
  try {
    await image.decode().toDart.timeout(const Duration(seconds: 20));
    final width = image.naturalWidth, height = image.naturalHeight;
    if (width < 1 || height < 1 || width * height > 48000000) {
      throw const FormatException('Image dimensions');
    }
    final scale = math.min(1.0, 1600 / math.max(width, height));
    final canvas = web.HTMLCanvasElement()
      ..width = math.max(1, (width * scale).round())
      ..height = math.max(1, (height * scale).round());
    final ctx = canvas.context2D;
    ctx.fillStyle = '#ffffff'.toJS;
    ctx.fillRect(0, 0, canvas.width.toDouble(), canvas.height.toDouble());
    ctx.drawImage(
      image,
      0,
      0,
      canvas.width.toDouble(),
      canvas.height.toDouble(),
    );
    final encoded = Completer<web.Blob>();
    canvas.toBlob(
      ((web.Blob? b) {
        if (b == null) {
          encoded.completeError(const FormatException('Image encoding'));
        } else {
          encoded.complete(b);
        }
      }).toJS,
      'image/jpeg',
      0.82.toJS,
    );
    final result = await encoded.future.timeout(const Duration(seconds: 20));
    final buffer = await result.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  } finally {
    web.URL.revokeObjectURL(url);
  }
}
