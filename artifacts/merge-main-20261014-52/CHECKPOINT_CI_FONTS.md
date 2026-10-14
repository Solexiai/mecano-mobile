# Complement CI ? polices publiques ? 2026-10-14

La seconde execution GitHub (38610637557, commit 7d75ca1) a resolu les quinze erreurs de fuseau et la preparation Marketplace. Resultat distinct: 1063 reussites, 2 echecs setUpAll. Le dernier chemin absent est materialicons-regular.otf dans le cache SDK. Le build Web, l'analyse et la validation Firebase sont reussis.

Correction limitee au harnais: le fichier MaterialIcons local deja utilise lors des validations est copie sans modification sous test/fixtures/fonts avec sa licence et ses empreintes (CI_REPRODUCTION_2.json). Le chargeur de test ne depend plus d'aucun cache SDK. Aucun fichier produit, serveur, financier ou regle cloud n'est modifie. Aucune assertion retiree ou affaiblie.

Execution locale des suites home_hero_locale_test.dart et public_menu_locale_test.dart: 26 reussis, 0 echec, 0 ignore. Analyse ciblee reussie. Format Dart et diff check reussis. Verification complete Linux a attendre avant fusion; les echecs historiques restent conserves.
