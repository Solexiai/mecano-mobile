// D'où vient chaque prospect (Daniel, 2026-11-17) : première visite notée une
// fois sur l'appareil, envoyée une fois par compte.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/acquisition/acquisition_tracker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('première visite : paramètres utm, clic publicitaire, référent, page d’arrivée', () {
    final data = AcquisitionTracker.firstTouch(
      landing: Uri.parse(
        'https://movi-k.com/fr/devenir-chauffeur?utm_source=facebook&utm_medium=cpc&utm_campaign=chauffeurs_nov&fbclid=abc',
      ),
      referrer: 'https://l.facebook.com/',
      platform: 'web',
      nowMs: 1700000000000,
    );
    expect(data, {
      'source': 'facebook',
      'medium': 'cpc',
      'campaign': 'chauffeurs_nov',
      'content': '',
      'term': '',
      'clickId': 'fbclid',
      'referrer': 'https://l.facebook.com/',
      'landingPath': '/fr/devenir-chauffeur',
      'platform': 'web',
      'firstSeenAtMs': 1700000000000,
    });
    final direct = AcquisitionTracker.firstTouch(
      landing: Uri.parse('https://movi-k.com/fr'),
      referrer: '',
      platform: 'web',
      nowMs: 1,
    );
    expect(direct['source'], '');
    expect(direct['clickId'], '');
  });

  test('la première visite gagne ; envoyée une seule fois par compte', () async {
    SharedPreferences.setMockInitialValues({});
    await AcquisitionTracker.captureFirstTouch(
      landing: Uri.parse('https://movi-k.com/fr?gclid=xyz'),
      referrerUrl: 'https://www.google.com/',
    );
    // Une visite suivante ne remplace pas la première.
    await AcquisitionTracker.captureFirstTouch(
      landing: Uri.parse('https://movi-k.com/fr?utm_source=facebook'),
      referrerUrl: '',
    );
    final prefs = await SharedPreferences.getInstance();
    final stored =
        jsonDecode(prefs.getString(AcquisitionTracker.firstTouchKey)!) as Map;
    expect(stored['clickId'], 'gclid');
    expect(stored['referrer'], 'https://www.google.com/');

    final sent = <Map<String, dynamic>>[];
    Future<void> api(Map<String, dynamic> d) async => sent.add(d);
    await AcquisitionTracker.reportFor('uid-1', api: api);
    await AcquisitionTracker.reportFor('uid-1', api: api);
    expect(sent, hasLength(1));
    expect(sent.single['clickId'], 'gclid');
    // Un autre compte sur le même appareil est rangé lui aussi.
    await AcquisitionTracker.reportFor('uid-2', api: api);
    expect(sent, hasLength(2));
  });

  test('un envoi raté est repris plus tard ; sans première visite, rien n’est envoyé', () async {
    SharedPreferences.setMockInitialValues({});
    var calls = 0;
    Future<void> failing(Map<String, dynamic> d) async {
      calls++;
      throw Exception('réseau');
    }

    await AcquisitionTracker.reportFor('uid-1', api: failing);
    expect(calls, 0);
    await AcquisitionTracker.captureFirstTouch(
      landing: Uri.parse('https://movi-k.com/fr'),
      referrerUrl: '',
    );
    await AcquisitionTracker.reportFor('uid-1', api: failing);
    expect(calls, 1);
    final sent = <Map<String, dynamic>>[];
    await AcquisitionTracker.reportFor('uid-1', api: (d) async => sent.add(d));
    expect(sent, hasLength(1));
  });
}
