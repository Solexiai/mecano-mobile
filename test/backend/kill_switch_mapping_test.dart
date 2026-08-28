import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/backend_exceptions.dart';

// Phase 7, Bloc X (X-10) — petit test unitaire couvrant le mapping
// kill-switch -> clé i18n `service_temporarily_unavailable`.
//
// But : garantir que `isKillSwitchException()` distingue correctement un
// refus kill switch (message serveur STABLE `kKillSwitchServerMessage`) d'un
// refus métier ordinaire portant le MÊME code HttpsError
// (`failed-precondition` est partagé, voir acceptDelivery.ts /
// firebase_mission_repository.dart) — la distinction doit se faire par le
// message, jamais par le code seul.
void main() {
  group('Bloc X (X-10) — isKillSwitchException()', () {
    test('CloudFunctionException avec le message kill switch stable est reconnue', () {
      const e = CloudFunctionException('failed-precondition', kKillSwitchServerMessage);
      expect(isKillSwitchException(e), isTrue);
    });

    test(
        'CloudFunctionException avec le MÊME code HttpsError mais un message '
        'métier différent (ex: mission déjà acceptée) n\'est PAS confondue '
        'avec le kill switch', () {
      const e = CloudFunctionException(
        'failed-precondition',
        'mission_already_assigned',
      );
      expect(isKillSwitchException(e), isFalse);
    });

    test('une exception qui n\'est pas une CloudFunctionException n\'est jamais un kill switch', () {
      expect(isKillSwitchException(Exception('boom')), isFalse);
      expect(isKillSwitchException(const BackendNotConfiguredException('x')), isFalse);
    });

    test('kKillSwitchErrorCode vaut exactement la clé i18n service_temporarily_unavailable', () {
      // Les écrans mappent errorCode == kKillSwitchErrorCode vers
      // t('service_temporarily_unavailable') — cette constante DOIT rester
      // alignée avec la clé i18n (voir lib/l10n/app_strings.dart).
      expect(kKillSwitchErrorCode, 'service_temporarily_unavailable');
      expect(kKillSwitchServerMessage, 'service_temporarily_unavailable');
    });
  });
}
