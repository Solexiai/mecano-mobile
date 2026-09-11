import 'package:flutter/material.dart';

import '../core/responsive.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final TextAlign align;

  const SectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = AppBreakpoints.isDesktop(width)
        ? 34.0
        : AppBreakpoints.isTablet(width)
            ? 30.0
            : 26.0;
    final subtitleSize = AppBreakpoints.isDesktop(width)
        ? 17.0
        : AppBreakpoints.isTablet(width)
            ? 16.0
            : 15.0;

    return Column(
      crossAxisAlignment: align == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: align,
          style: TextStyle(
            fontSize: titleSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: Theme.of(context).textTheme.headlineMedium?.color,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            textAlign: align,
            style: TextStyle(
              fontSize: subtitleSize,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
  }
}

class ResponsivePadding extends StatelessWidget {
  final Widget child;

  const ResponsivePadding({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final basePadding = AppBreakpoints.pageHorizontalPadding(width);
    final centeredPadding = width > AppBreakpoints.contentMaxWidth
        ? (width - AppBreakpoints.contentMaxWidth) / 2
        : 0.0;
    final horizontal = centeredPadding > basePadding
        ? centeredPadding
        : basePadding;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontal),
      child: child,
    );
  }
}
