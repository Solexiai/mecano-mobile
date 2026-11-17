import 'package:web/web.dart' as web;

/// The page the visitor came from (empty for a direct visit).
String documentReferrer() => web.document.referrer;
