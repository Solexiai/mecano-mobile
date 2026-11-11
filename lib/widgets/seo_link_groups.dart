import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_colors.dart';
import '../seo/seo_pages.dart';

/// Les listes de liens vers les pages par objet et par ville
/// (seoLinkGroups) : les mêmes que dans la page lue par Google.
class SeoLinkGroupsView extends StatelessWidget {
  const SeoLinkGroupsView({super.key, required this.page, required this.locale});

  final SeoPage page;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final groups = seoLinkGroups(page, locale);
    if (groups.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups) ...[
          const SizedBox(height: 26),
          Text(
            group.heading,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, path) in group.links)
                ActionChip(
                  key: ValueKey('seo-link-$path'),
                  label: Text(label),
                  onPressed: () => context.go(path),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
