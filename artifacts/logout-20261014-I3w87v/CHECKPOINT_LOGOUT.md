# Movi-K  Dconnexion publique  14 octobre 2026

Base : 7dca47b29a929772983b4e2bbab76716d13ac020 ; branche fix/booking-timing-20261014.

AppShell dconnectait sans navigation sur les routes publiques. Correction : attendre signOut puis retourner  laccueil localis ; afficher une erreur FR/EN/ES en cas dchec. Accs invit prserv.

Reproduction : 12 checs, aucun succs/ignor. Aprs : 12 russis. Rgression combine : 31 russis, aucun chec/ignor (inclut les 12). Suites : public_logout_navigation_test, public_menu_locale_test, delivery_request_auth_navigation_test, delivery_request_draft_resume_test. Excution Flutter --no-version-check test --no-pub --dart-define=no_default_http_client=true --concurrency=1 --reporter=json. Logs bruts conservs dans ce dossier, exclus du commit.

Analyse cible : No issues found. Format Dart russi, diff check russi. Vrais AppShell/GoRouter avec auth et stockage simuls et transport offline ; mobile 375x812 et desktop 1440x900, trois langues. Pas de validation Chrome, tlphone ou production. Aucun changement financier, serveur ou Firebase. Aucun dploiement.

P2-AUTH-LOGOUT-01 : VALID LOCALEMENT  NON FERM  NON DPLOY.
