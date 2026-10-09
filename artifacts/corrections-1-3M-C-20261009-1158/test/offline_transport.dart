// Test-only transport for P1-M-01 contract checks. No product file is replaced.
// This is NOT OS network confinement and does NOT validate deferred step 1.3L.
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_test/flutter_test.dart' as framework;
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

final offlineTileRequests = <Uri>[];
final rejectedRequests = <String>[];

class MemoryOnlyClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final uri = request.url;
    if (request.method != 'GET' ||
        uri.scheme != 'https' ||
        uri.host != 'tile.openstreetmap.org' ||
        !RegExp(r'^/\d+/\d+/\d+\.png$').hasMatch(uri.path)) {
      rejectedRequests.add('${request.method} $uri');
      throw StateError('OFFLINE_DENIED: $uri');
    }
    // URL is used only as a cache/test key. No socket, DNS, IOClient or delegation.
    offlineTileRequests.add(uri);
    final bytes = TileProvider.transparentImage;
    return http.StreamedResponse(Stream.value(bytes), 200,
        contentLength: bytes.length, headers: {'content-type': 'image/png'});
  }
}

void offlineTests(void Function() register) {
  if (!const bool.fromEnvironment('no_default_http_client')) {
    throw StateError('Required --dart-define=no_default_http_client=true missing');
  }
  HttpOverrides.runZoned(
    () => http.runWithClient(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      register();
      tearDownAll(() {
        expect(rejectedRequests, isEmpty,
            reason: 'Unexpected external-service path must fail the suite');
        // ignore: avoid_print
        print('OFFLINE_TRANSPORT: in_memory=${offlineTileRequests.length}; '
            'unexpected=${rejectedRequests.length}; external_transport=none');
      });
    }, MemoryOnlyClient.new),
    createHttpClient: (_) =>
        throw StateError('OFFLINE_DENIED: dart:io HttpClient creation'),
  );
}

Future<T> withOfflineTransport<T>(Future<T> Function() body) =>
    HttpOverrides.runZoned(
      () => http.runWithClient(body, MemoryOnlyClient.new),
      createHttpClient: (_) =>
          throw StateError('OFFLINE_DENIED: dart:io HttpClient creation'),
    );

void offlineTest(String description, Future<void> Function() body) =>
    test(description, () => withOfflineTransport(body));

void offlineWidgetTest(String description, WidgetTesterCallback body) =>
    framework.testWidgets(description,
        (tester) => withOfflineTransport(() => body(tester)));
