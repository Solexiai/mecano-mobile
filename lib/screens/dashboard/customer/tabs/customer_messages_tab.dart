import 'package:flutter/material.dart';
import '../../../../core/app_colors.dart';
import '../../../../widgets/coming_soon_badge.dart';

class CustomerMessagesTab extends StatelessWidget {
  const CustomerMessagesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text('Messagerie intégrée', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            const Text(
              'La messagerie en temps réel entre clients et fournisseurs sera bientôt disponible.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const ComingSoonBadge(),
          ],
        ),
      ),
    );
  }
}
