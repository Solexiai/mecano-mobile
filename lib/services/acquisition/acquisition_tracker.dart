// Where each prospect comes from (Daniel, 2026-11-17).
//
// On the very first visit the site notes the landing address (utm_*
// parameters, gclid, fbclid) and the referring site, on this device only.
// Once the visitor has an account, that first visit is sent ONCE to the
// `recordAcquisitionSource` Cloud Function, which files it under the account
// (advertising, search, direct…). Nothing is sent for anonymous visitors.
// Every step is best-effort: a failure here never blocks the app.
import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:shared_preferences/shared_preferences.dart';

import 'referrer_stub.dart'
    if (dart.library.js_interop) 'referrer_web.dart'
    as referrer;

typedef AcquisitionApi = Future<void> Function(Map<String, dynamic> data);

Future<void> _firebaseApi(Map<String, dynamic> data) async {
  await FirebaseFunctions.instance
      .httpsCallable('recordAcquisitionSource')
      .call(data);
}

class AcquisitionTracker {
  static const firstTouchKey = 'acquisition_first_touch_v1';
  static const reportedKeyPrefix = 'acquisition_reported_v1_';

  /// The first visit as sent to the server. Pure: tested directly.
  static Map<String, dynamic> firstTouch({
    required Uri landing,
    required String referrer,
    required String platform,
    required int nowMs,
  }) {
    final q = landing.queryParameters;
    String p(String name) => (q[name] ?? '').trim();
    final clickId = p('gclid').isNotEmpty
        ? 'gclid'
        : p('fbclid').isNotEmpty
        ? 'fbclid'
        : p('msclkid').isNotEmpty
        ? 'msclkid'
        : '';
    return {
      'source': p('utm_source'),
      'medium': p('utm_medium'),
      'campaign': p('utm_campaign'),
      'content': p('utm_content'),
      'term': p('utm_term'),
      'clickId': clickId,
      'referrer': referrer,
      'landingPath': landing.path,
      'platform': platform,
      'firstSeenAtMs': nowMs,
    };
  }

  /// Notes the first visit on this device, once. Call at app start.
  static Future<void> captureFirstTouch({
    Uri? landing,
    String? referrerUrl,
    DateTime? now,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(firstTouchKey) != null) return;
      final data = firstTouch(
        landing: landing ?? Uri.base,
        referrer: referrerUrl ?? referrer.documentReferrer(),
        platform: kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase(),
        nowMs: (now ?? DateTime.now()).millisecondsSinceEpoch,
      );
      await prefs.setString(firstTouchKey, jsonEncode(data));
    } catch (_) {
      // Storage unavailable (private mode, tests): no source is recorded.
    }
  }

  /// Files the first visit under the signed-in account, once per account.
  static Future<void> reportFor(String uid, {AcquisitionApi? api}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(firstTouchKey);
      if (stored == null || prefs.getBool('$reportedKeyPrefix$uid') == true) {
        return;
      }
      final data = Map<String, dynamic>.from(jsonDecode(stored) as Map);
      await (api ?? _firebaseApi)(data);
      await prefs.setBool('$reportedKeyPrefix$uid', true);
    } catch (_) {
      // Retried at the next sign-in or app start.
    }
  }
}
