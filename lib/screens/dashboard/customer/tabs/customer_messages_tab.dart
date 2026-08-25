import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_colors.dart';
import '../../../../providers/locale_provider.dart';
import '../../../../widgets/coming_soon_badge.dart';

class CustomerMessagesTab extends StatelessWidget {
  const CustomerMessagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(t('customer_messages_title'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              t('customer_messages_body'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const ComingSoonBadge(),
          ],
        ),
      ),
    );
  }
}
