import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'document_meta_stub.dart'
    if (dart.library.js_interop) 'document_meta_web.dart';
import 'page_meta.dart';

export 'document_meta_stub.dart'
    if (dart.library.js_interop) 'document_meta_web.dart'
    show currentWebPath;

/// Keeps the HTML language, title and description in line with the
/// current address, on the first load and after every navigation.
void startPageMetaSync(GoRouter router) {
  final path = currentWebPath();
  if (path == null) return;
  applyPageMeta(PageMeta.forPath(path));

  // After the frame, so the value set by Flutter for the app language
  // cannot be written after ours.
  router.routerDelegate.addListener(() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uri = router.routerDelegate.currentConfiguration.uri;
      applyPageMeta(PageMeta.forPath(uri.path));
    });
  });
}
