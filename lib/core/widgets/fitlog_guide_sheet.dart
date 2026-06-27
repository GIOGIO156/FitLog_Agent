import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'fitlog_bottom_nav_bar.dart';
import 'glass_panel.dart';

class FitLogGuideSheetGeometry {
  const FitLogGuideSheetGeometry({
    required this.topPadding,
    required this.bottomPadding,
    required this.bodyHeight,
  });

  static const double sheetToNavGap = 12;
  static const double topFocusGap = 64;
  static const double guideSheetStaticHeight = 104;
  static const double minGuideSheetBodyHeight = 240;
  static const double maxGuideSheetBodyHeight = 580;
  static const double outerGap = 12;

  final double topPadding;
  final double bottomPadding;
  final double bodyHeight;

  static FitLogGuideSheetGeometry resolve(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final navFootprint = FitLogBottomNavBar.fullScreenFootprintFor(context);
    final modalBottomPadding = navFootprint + sheetToNavGap;
    final modalTopPadding = math.max(
      topFocusGap,
      MediaQuery.viewPaddingOf(context).top + outerGap * 2,
    );
    var guideBodyHeight =
        screenHeight -
        modalTopPadding -
        modalBottomPadding -
        guideSheetStaticHeight;

    if (guideBodyHeight <= minGuideSheetBodyHeight) {
      guideBodyHeight = math.max(0, guideBodyHeight);
    } else {
      guideBodyHeight = math.min(maxGuideSheetBodyHeight, guideBodyHeight);
    }

    return FitLogGuideSheetGeometry(
      topPadding: modalTopPadding,
      bottomPadding: modalBottomPadding,
      bodyHeight: guideBodyHeight,
    );
  }
}

Future<T?> showFitLogGuideSheet<T>({
  required BuildContext context,
  required Widget leading,
  required String title,
  required Widget body,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (sheetContext) {
      final geometry = FitLogGuideSheetGeometry.resolve(sheetContext);
      return Padding(
        key: const ValueKey<String>('fitlog_guide_sheet_padding'),
        padding: EdgeInsets.fromLTRB(
          FitLogGuideSheetGeometry.outerGap,
          geometry.topPadding,
          FitLogGuideSheetGeometry.outerGap,
          geometry.bottomPadding,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GlassPanel(
            key: const ValueKey<String>('fitlog_guide_sheet_panel'),
            margin: EdgeInsets.zero,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    leading,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(sheetContext).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: MaterialLocalizations.of(
                        sheetContext,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  key: const ValueKey<String>('fitlog_guide_sheet_body'),
                  height: geometry.bodyHeight,
                  child: SingleChildScrollView(child: body),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
