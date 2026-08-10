import 'package:flutter/material.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final TextAlign align;
  const SectionTitle({super.key, required this.title, this.subtitle, this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return Column(
      crossAxisAlignment: align == TextAlign.center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: align,
          style: TextStyle(
            fontSize: isDesktop ? 34 : 26,
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
            style: TextStyle(fontSize: isDesktop ? 17 : 15, color: Theme.of(context).textTheme.bodyMedium?.color, height: 1.5),
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
    final width = MediaQuery.of(context).size.width;
    final horizontal = width >= 1200 ? (width - 1140) / 2 : (width >= 900 ? 48.0 : 20.0);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 0),
      child: child,
    );
  }
}
