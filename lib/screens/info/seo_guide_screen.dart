import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../l10n/home_copy.dart';
import '../../providers/locale_provider.dart';
import '../../router/delivery_request_intent.dart';
import '../../seo/seo_html.dart';
import '../../seo/seo_pages.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';
import '../../widgets/seo_link_groups.dart';

/// Page par objet ou par ville (lib/seo/seo_guide_pages.dart). Affiche le
/// même texte que la page lue par Google (tool/build_seo_pages.dart) : titre,
/// introduction, sections, bouton de demande et liens vers les autres pages.
class SeoGuideScreen extends StatelessWidget {
  const SeoGuideScreen({super.key, required this.locale, required this.page});

  final String locale;
  final SeoPage page;

  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    final sections = seoSectionsFor(page, locale);

    return AppShell(
      locale: locale,
      child: ResponsivePadding(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 42),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    page.headings[locale] ?? page.headings['fr']!,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 32,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    page.intros[locale] ?? page.intros['fr']!,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 22),
                  ElevatedButton.icon(
                    key: const ValueKey('seo-guide-quote'),
                    onPressed: () =>
                        context.go(DeliveryRequestIntent.path(locale)),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: Text(HomeCopy.text('quote_start', locale)),
                  ),
                  const SizedBox(height: 22),
                  for (final (heading, body) in sections) ...[
                    _GuideSection(title: heading, body: body),
                    const SizedBox(height: 12),
                  ],
                  SeoLinkGroupsView(page: page, locale: locale),
                  const SizedBox(height: 26),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/$locale/faq'),
                    icon: const Icon(Icons.help_outline),
                    label: Text(
                      tr(
                        'Consulter la FAQ',
                        'Read the FAQ',
                        'Consultar preguntas frecuentes',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          body,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
      ],
    ),
  );
}
