import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

bool downloadBookingReceipt(String html, String id) {
  final blob = web.Blob(
    [html.toJS].toJS,
    web.BlobPropertyBag(type: 'text/html;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = 'Movi-K-${id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '')}.html';
  anchor.click();
  Timer(const Duration(seconds: 1), () => web.URL.revokeObjectURL(url));
  return true;
}
