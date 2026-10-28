// CLI-02 (Bloc C, PR 6 — 2026-10-28) : page 404 Movi-K dans l'app, à la
// place de l'écran « Page Not Found » anglais de go_router hors AppShell.
// Vercel sert déjà un vrai 404 pour les adresses inconnues (PR #92) ; cette
// page couvre les liens internes cassés et les paramètres manquants.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.locale, this.path});
  final String locale;
  final String? path;

  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;

  @override
  Widget build(BuildContext context) {
    return AppShell(
      locale: locale,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
            child: Column(
              key: const ValueKey('not-found-page'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(title: tr('Page introuvable', 'Page not found', 'Página no encontrada')),
                const SizedBox(height: 16),
                Text(
                  tr(
                    'Cette adresse n’existe pas ou plus. Vérifiez le lien, ou revenez à l’accueil pour demander une livraison.',
                    'This address does not exist or no longer exists. Check the link, or go back to the home page to request a delivery.',
                    'Esta dirección no existe o ya no existe. Verifique el enlace o vuelva al inicio para solicitar una entrega.',
                  ),
                  style: const TextStyle(height: 1.6),
                ),
                if (path != null && path!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SelectableText(path!, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                ],
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('not-found-home'),
                      onPressed: () => context.go('/$locale'),
                      icon: const Icon(Icons.home_outlined),
                      label: Text(tr('Retour à l’accueil', 'Back to home', 'Volver al inicio')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/$locale/contact'),
                      icon: const Icon(Icons.mail_outline),
                      label: Text(tr('Nous écrire', 'Email us', 'Escribirnos')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
