# Commandes réellement exécutées — 1.3M-S

Répertoire : C:\Users\Utilisateur\movik-gps-history-fix-20261009.

Exécutable Flutter : C:\Users\Utilisateur\mecano-mobile\.flutter\bin\flutter.bat.
Exécutable Dart : C:\Users\Utilisateur\mecano-mobile\.flutter\bin\cache\dart-sdk\bin\dart.exe.

Variables des exécutions : FLUTTER_SUPPRESS_ANALYTICS=true ; DART_SUPPRESS_ANALYTICS=true ; CI=true.
Les sorties sont redirigées dans ce dossier ; leur code de sortie est enregistré séparément.
La sortie console UTF-8 a été explicitement configurée après before. Le journal before conserve le décodage console Windows d'origine ; les assertions et nombres ne sont pas réécrits.

## Inspection Git
```powershell
git branch --show-current
git rev-parse HEAD
git status --porcelain=v1 -uall
git diff --cached --name-only
git log -7 --format="%H %s"
git ls-files -c -o --exclude-standard -z
git grep -n -E 'money_format|formatMajorAmount|formatMinorAmount|NumberFormat|fr_CA|en_CA|es_CA' -- lib test pubspec.yaml
```

Le script snapshot-initial.cjs enregistre les empreintes et le registre avant modification.
Les lectures du code serveur et des tests sont effectuées sans exécution de fonctions.
Aucun hook actif trouvé dans le dossier hooks consulté ; aucune configuration Git modifiée.

## Reproduction initiale (before, avant modification produit)
```powershell
flutter --no-version-check test --no-pub --dart-define=no_default_http_client=true --concurrency=1 --reporter=json test/customer/delivery_quote_display_test.dart
```

La version initiale de ce test est conservée dans TEST_REPRODUCTION_AVANT.dart.txt.
Les résultats sont dans before.jsonl / before.exit et RESULTATS_TESTS.json.

## Dépendance disponible localement
```powershell
flutter --no-version-check pub get --offline --no-example
```

## Tests ciblés (after-1 puis after-2 après correction du débordement)
```powershell
flutter --no-version-check test --no-pub --dart-define=no_default_http_client=true --concurrency=1 --reporter=json test/customer/delivery_quote_display_test.dart test/finance/money_format_localization_test.dart
```

## Non-régressions
```powershell
flutter --no-version-check test --no-pub --dart-define=no_default_http_client=true --concurrency=1 --reporter=json test/customer/delivery_confirmation_presentation_test.dart test/customer/delivery_request_flow_double_submit_test.dart test/customer/delivery_request_flow_error_messages_test.dart test/customer/delivery_request_draft_resume_test.dart test/customer/booking_service_availability_test.dart test/customer/delivery_dimension_display_test.dart test/customer/delivery_address_autocomplete_test.dart
```

## Qualité finale
```powershell
flutter --no-version-check analyze --no-pub lib/finance/presentation/money_format.dart lib/screens/delivery/delivery_request_flow_screen.dart test/customer/delivery_quote_display_test.dart test/finance/money_format_localization_test.dart test/customer/delivery_address_autocomplete_test.dart test/customer/delivery_dimension_display_test.dart test/customer/delivery_request_flow_error_messages_test.dart
dart format --output=none --set-exit-if-changed lib/finance/presentation/money_format.dart lib/screens/delivery/delivery_request_flow_screen.dart test/customer/delivery_quote_display_test.dart test/finance/money_format_localization_test.dart test/customer/delivery_address_autocomplete_test.dart test/customer/delivery_dimension_display_test.dart test/customer/delivery_request_flow_error_messages_test.dart
git diff --check
```

Dart format a aussi été exécuté en écriture sur ces seuls fichiers avant le contrôle.
Première analyse : 15 infos de style, puis analyse finale sans problème.
Les scripts collect.cjs/summarize.cjs dénombrent les testDone sans compter les chargements et contrôlent done.success ainsi que les codes de sortie.

Avant le commit local : sélection explicite, diff staged, git diff --cached --check, empreintes, absence de secret, index exact. Le résultat du commit et les commandes finales Git sont enregistrés dans COMMIT_LOCAL.json.
