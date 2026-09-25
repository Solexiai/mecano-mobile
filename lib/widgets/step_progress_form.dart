import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/responsive.dart';

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
  final int initialStep;

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
    this.initialStep = 0,
  }) : assert(initialStep >= 0);

  @override
  State<StepProgressForm> createState() => _StepProgressFormState();
}

class _StepProgressFormState extends State<StepProgressForm> {
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialStep;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.stepTitles.length;
    final isLast = _current == total - 1;
    final canGoNext = widget.canProceed?.call(_current) ?? true;
    final width = MediaQuery.sizeOf(context).width;
    final isPhone = AppBreakpoints.isPhone(width);

    final backButton = OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
      onPressed: () {
        setState(() => _current -= 1);
        widget.onStepChanged(_current);
      },
      child: Text(widget.backLabel),
    );

    final primaryButton = ElevatedButton(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
      ),
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
    );

    return Column(
      children: [
        _ProgressBar(current: _current, titles: widget.stepTitles),
        SizedBox(height: isPhone ? 20 : 28),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(
            key: ValueKey(_current),
            child: widget.stepBuilders[_current](context),
          ),
        ),
        SizedBox(height: isPhone ? 20 : 28),
        if (isPhone)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_current > 0) ...[
                backButton,
                const SizedBox(height: 10),
              ],
              primaryButton,
            ],
          )
        else
          Row(
            children: [
              if (_current > 0) Expanded(child: backButton),
              if (_current > 0) const SizedBox(width: 14),
              Expanded(flex: 2, child: primaryButton),
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
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = AppBreakpoints.isDesktop(width);

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
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${current + 1}/${titles.length} · ${titles[current]}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
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
    final width = MediaQuery.sizeOf(context).width;
    final padding = AppBreakpoints.isPhone(width)
        ? 16.0
        : AppBreakpoints.isTablet(width)
            ? 20.0
            : 24.0;
    final radius = AppBreakpoints.isPhone(width) ? 18.0 : 24.0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}
