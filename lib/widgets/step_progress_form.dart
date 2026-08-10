import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Reusable multi-step form scaffold with a visible progress indicator,
/// used by delivery request, mechanic request, driver onboarding and
/// mechanic onboarding flows.
class StepProgressForm extends StatefulWidget {
  final List<String> stepTitles;
  final List<Widget Function(BuildContext)> stepBuilders;
  final void Function(int step) onStepChanged;
  final VoidCallback onComplete;
  final String nextLabel;
  final String backLabel;
  final String submitLabel;
  final bool Function(int step)? canProceed;

  const StepProgressForm({
    super.key,
    required this.stepTitles,
    required this.stepBuilders,
    required this.onStepChanged,
    required this.onComplete,
    required this.nextLabel,
    required this.backLabel,
    required this.submitLabel,
    this.canProceed,
  });

  @override
  State<StepProgressForm> createState() => _StepProgressFormState();
}

class _StepProgressFormState extends State<StepProgressForm> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    final total = widget.stepTitles.length;
    final isLast = _current == total - 1;
    final canGoNext = widget.canProceed?.call(_current) ?? true;

    return Column(
      children: [
        _ProgressBar(current: _current, titles: widget.stepTitles),
        const SizedBox(height: 28),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(
            key: ValueKey(_current),
            child: widget.stepBuilders[_current](context),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            if (_current > 0)
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _current -= 1);
                    widget.onStepChanged(_current);
                  },
                  child: Text(widget.backLabel),
                ),
              ),
            if (_current > 0) const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: canGoNext
                    ? () {
                        if (isLast) {
                          widget.onComplete();
                        } else {
                          setState(() => _current += 1);
                          widget.onStepChanged(_current);
                        }
                      }
                    : null,
                child: Text(isLast ? widget.submitLabel : widget.nextLabel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int current;
  final List<String> titles;
  const _ProgressBar({required this.current, required this.titles});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 700;
    return Column(
      children: [
        Row(
          children: List.generate(titles.length, (i) {
            final active = i <= current;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i == titles.length - 1 ? 0 : 6),
                height: 5,
                decoration: BoxDecoration(
                  color: active ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        if (isDesktop)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(titles.length, (i) {
              final active = i <= current;
              return Expanded(
                child: Text(
                  '${i + 1}. ${titles[i]}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                    color: active ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              );
            }),
          )
        else
          Text(
            '${current + 1}/${titles.length} · ${titles[current]}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
      ],
    );
  }
}

/// Standard form container used inside every step.
class StepFormCard extends StatelessWidget {
  final Widget child;
  const StepFormCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
