import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/link.dart';
import '../../core/support_contact.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

class ContactScreen extends StatelessWidget {
  final String locale;
  const ContactScreen({super.key, required this.locale});
  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return AppShell(
      locale: locale,
      child: ResponsivePadding(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(title: t('nav_contact')),
              const SizedBox(height: 20),
              Text(
                tr('Contactez Movi-K', 'Contact Movi-K', 'Contacta con Movi-K'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const SelectableText(kSupportEmail),
              const SizedBox(height: 12),
              Text(
                tr(
                  'Pour une question sur votre demande ou le service, écrivez-nous. Si vous avez une référence de demande, indiquez-la dans votre message.',
                  'For questions about your request or the service, email us. If you have a request reference, include it in your message.',
                  'Si tienes preguntas sobre tu solicitud o el servicio, escríbenos. Si tienes una referencia de solicitud, inclúyela en tu mensaje.',
                ),
                style: const TextStyle(height: 1.6),
              ),
              const SizedBox(height: 20),
              Link(
                uri: kSupportMailto,
                builder: (context, followLink) => OutlinedButton.icon(
                  onPressed: followLink,
                  icon: const Icon(Icons.email_outlined),
                  label: Text(
                    tr('Ouvrir mon courriel', 'Open email', 'Abrir correo'),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: () => context.go('/$locale/faq'),
                    child: Text(t('nav_faq')),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/$locale/legal/cancellation'),
                    child: Text(
                      t('footer_cancellation_policy'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
