// Implémentation Web réelle de configureUrlStrategy() — sélectionnée par
// l'import conditionnel dans main.dart uniquement lors de la compilation
// pour la cible `dart.library.html` (Flutter Web).
import 'package:flutter_web_plugins/flutter_web_plugins.dart';

void configureUrlStrategy() {
  // Utilise de vraies URLs de chemin (/fr/admin) au lieu du routage par
  // hash (#/fr/admin) sur Flutter Web. Sans ceci, un accès direct à
  // /fr/admin (rechargement de page, lien partagé, bouton "Accès
  // administration") est ignoré par go_router : seul le fragment après le
  // `#` compte, donc l'app retombe systématiquement sur la route par
  // défaut (accueil) au lieu de l'écran de connexion admin demandé.
  setUrlStrategy(PathUrlStrategy());
}
