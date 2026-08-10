import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/locale_provider.dart';
import '../core/app_colors.dart';

class LanguageSelector extends StatelessWidget {
  final bool compact;
  const LanguageSelector({super.key, this.compact = false});

  /// Swaps the leading /fr|/en|/es segment of the current URL and keeps
  /// the rest of the path intact, so locale switching stays in sync with
  /// the locale-prefixed routing requirement (e.g. /fr/livraison -> /en/livraison).
  void _switchLocale(BuildContext context, String newLocale) {
    context.read<LocaleProvider>().setLocale(newLocale);
    final currentUri = GoRouterState.of(context).uri;
    final segments = currentUri.pathSegments;
    if (segments.isNotEmpty && ['fr', 'en', 'es'].contains(segments.first)) {
      final newPath = '/$newLocale${segments.length > 1 ? '/${segments.sublist(1).join('/')}' : ''}';
      context.go(newPath);
    } else {
      context.go('/$newLocale');
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    return PopupMenuButton<String>(
      initialValue: localeProvider.locale,
      onSelected: (value) => _switchLocale(context, value),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'fr', child: Text('🇫🇷 Français')),
        PopupMenuItem(value: 'en', child: Text('🇬🇧 English')),
        PopupMenuItem(value: 'es', child: Text('🇪🇸 Español')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 18),
            if (!compact) const SizedBox(width: 6),
            if (!compact) Text(localeProvider.locale.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
