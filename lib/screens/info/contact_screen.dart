import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

/// Never report a successful send without a connected support channel.
class ContactScreen extends StatelessWidget {
  final String locale;
  const ContactScreen({super.key, required this.locale});
  String tr(String fr, String en, String es) => locale == 'en' ? en : locale == 'es' ? es : fr;
  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return AppShell(locale: locale, child: ResponsivePadding(child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle(title: t('nav_contact')),
        const SizedBox(height: 20),
        Text(tr('Le canal de contact est en préparation pour cette version pilote.', 'The contact channel is being prepared for this pilot version.', 'El canal de contacto está en preparación para esta versión piloto.'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Text(tr('Cette page n’envoie actuellement aucun message. Les coordonnées officielles seront publiées avant l’ouverture du service.', 'This page does not currently send messages. Official contact details will be published before the service opens.', 'Esta página todavía no envía mensajes. Los datos de contacto oficiales se publicarán antes de la apertura del servicio.'), style: const TextStyle(height: 1.6)),
        const SizedBox(height: 24),
        Wrap(spacing: 12, runSpacing: 12, children: [
          OutlinedButton(onPressed: () => context.go('/$locale/faq'), child: Text(t('nav_faq'))),
          OutlinedButton(onPressed: () => context.go('/$locale/legal/cancellation'), child: Text(t('footer_cancellation_policy'), textAlign: TextAlign.center)),
        ]),
      ]),
    )));
  }
}
