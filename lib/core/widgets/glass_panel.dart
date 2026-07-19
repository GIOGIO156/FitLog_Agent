import 'package:flutter/material.dart';

import '../theme/fitlog_theme.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.borderRadius = 24,
    this.opaque = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double borderRadius;
  final bool opaque;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    final bgColor = opaque
        ? fitTheme.surfaceElevated
        : fitTheme.isDark
        ? fitTheme.surface.withValues(alpha: 0.88)
        : fitTheme.surface.withValues(alpha: 0.96);
    final borderColor = fitTheme.isDark
        ? fitTheme.outline.withValues(alpha: 0.86)
        : fitTheme.outline;

    return Container(
      margin: margin,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: borderColor),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: fitTheme.shadow.withValues(
                alpha: fitTheme.isDark ? 0.28 : 0.05,
              ),
              blurRadius: 26,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}
