import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';
import '../../content/faq_content.dart';

class FaqScreen extends StatelessWidget {
  final String locale;
  const FaqScreen({super.key, required this.locale});

  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();

    // Questions et réponses : lib/content/faq_content.dart (aussi lues par
    // Google et les IA via les pages générées au build).
    final items = faqItems(locale);

    return AppShell(
      locale: locale,
      child: ResponsivePadding(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                title: tr(
                  'Questions fréquentes',
                  'Frequently asked questions',
                  'Preguntas frecuentes',
                ),
                subtitle: tr(
                  'Tout ce qu’il faut savoir avant de réserver.',
                  'Everything you need to know before booking.',
                  'Todo lo que necesitas saber antes de reservar.',
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: .2),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr(
                          'Partout où un chauffeur Movi‑K est disponible. La disponibilité d’un chauffeur est confirmée quand il accepte votre demande.',
                          'Wherever a Movi‑K driver is available. Driver availability is confirmed when a driver accepts your request.',
                          'Dondequiera que haya un conductor Movi‑K disponible. La disponibilidad de un conductor se confirma cuando acepta tu solicitud.',
                        ),
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              ...items.map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 4,
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    title: Text(
                      item.$1,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          item.$2,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.55,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
