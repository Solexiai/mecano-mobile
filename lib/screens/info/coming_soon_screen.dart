// CLI-07 (Bloc C, PR 6 — 2026-10-28) : la mécanique mobile n'est pas offerte
// au lancement. Les anciennes adresses (/mecanique-mobile, /devenir-mecanicien
// et leurs variantes EN/ES) affichent cette page « Bientôt disponible » au
// lieu du formulaire démo (données fictives, textes français en dur,
// « soumission » locale sans suite). Les écrans démo restent dans le code,
// sans route, jusqu'au nettoyage TECH-03.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.locale, this.service = 'mechanic'});
  final String locale;

  /// Service annoncé (`mechanic` pour l'instant).
  final String service;

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
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
            child: Column(
              key: ValueKey('coming-soon-$service'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionTitle(title: tr('Mécanique mobile', 'Mobile mechanic', 'Mecánica móvil')),
                const SizedBox(height: 10),
                Text(
                  tr('Bientôt disponible', 'Coming soon', 'Próximamente'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                Text(
                  tr(
                    'Movi-K lance d’abord la livraison d’objets à Granby. Le service de mécanique mobile viendra plus tard : rien n’est réservable pour l’instant et aucune inscription de mécanicien n’est ouverte.',
                    'Movi-K is launching item delivery in Granby first. The mobile mechanic service will come later: nothing can be booked yet and mechanic sign-up is not open.',
                    'Movi-K lanza primero la entrega de objetos en Granby. El servicio de mecánica móvil llegará más tarde: por ahora no se puede reservar nada y la inscripción de mecánicos no está abierta.',
                  ),
                  style: const TextStyle(height: 1.6),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('coming-soon-delivery'),
                      onPressed: () => context.go('/$locale/livraison'),
                      icon: const Icon(Icons.local_shipping_outlined),
                      label: Text(tr('Voir la livraison', 'See delivery', 'Ver la entrega')),
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
