import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/screens/driver/driver_registration_failure.dart';

void main() {
  test('each failure phase has a clear, nonempty French explanation', () {
    for (final stage in DriverRegistrationStage.values) {
      final message = driverRegistrationFailureMessage('fr', stage);
      expect(message, contains("L'inscription n'a pas pu être terminée"));
      expect(message, contains('Consultez votre dossier'));
      expect(message, isNot(endsWith(':')));
      expect(message, isNot(contains('Exception')));
    }
  });

  test('stage of rejected storage upload is explicit', () {
    final message = driverRegistrationFailureMessage(
      'fr',
      DriverRegistrationStage.documents,
    );
    expect(message, contains('téléversement des documents'));
    expect(message, contains('éviter les doublons'));
  });

  test('final review failure is distinguished from document upload', () {
    final message = driverRegistrationFailureMessage(
      'fr',
      DriverRegistrationStage.review,
    );
    expect(message, contains("l'envoi du dossier en vérification"));
    expect(message, isNot(contains('téléversement')));
  });

  test('all supported languages have actionable fallback', () {
    for (final locale in ['fr', 'en', 'es']) {
      for (final stage in DriverRegistrationStage.values) {
        final message = driverRegistrationFailureMessage(locale, stage);
        expect(message.trim(), isNotEmpty);
        expect(message, isNot(endsWith(':')));
        expect(message, isNot(contains('password')));
      }
    }
  });
}
