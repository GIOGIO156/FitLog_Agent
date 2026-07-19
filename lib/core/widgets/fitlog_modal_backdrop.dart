import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/fitlog_theme.dart';

class FitLogModalBackdrop extends StatelessWidget {
  const FitLogModalBackdrop({
    super.key,
    required this.child,
    this.blurSigma = 10,
  });

  final Widget child;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    return ClipRect(
      child: BackdropFilter(
        key: const ValueKey<String>('fitlog_modal_backdrop_filter'),
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: ColoredBox(
          key: const ValueKey<String>('fitlog_modal_backdrop_scrim'),
          color: fitTheme.shadow.withValues(
            alpha: fitTheme.isDark ? 0.32 : 0.18,
          ),
          child: child,
        ),
      ),
    );
  }
}
