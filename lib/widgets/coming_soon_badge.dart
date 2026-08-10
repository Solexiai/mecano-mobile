import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/locale_provider.dart';

/// Badge used to clearly mark features that are not yet connected to a
/// real backend (live GPS tracking, automated payments, instant pricing,
/// insurance coverage, automatic parts ordering, etc.)
class ComingSoonBadge extends StatelessWidget {
  final bool small;
  const ComingSoonBadge({super.key, this.small = false});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 8 : 12, vertical: small ? 3 : 5),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.access_time_rounded, size: small ? 12 : 14, color: AppColors.warning),
          const SizedBox(width: 4),
          Text(
            t('common_coming_soon'),
            style: TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
              fontSize: small ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small label to mark clearly demonstration/sample data blocks.
class DemoDataBadge extends StatelessWidget {
  const DemoDataBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        t('common_demo_data'),
        style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}
