import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/fitlog_theme.dart';

class FitLogNavItem {
  const FitLogNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

enum FitLogBottomNavSurface { solid, glass }

class FitLogBottomNavBar extends StatelessWidget {
  const FitLogBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.surface = FitLogBottomNavSurface.solid,
  });

  final List<FitLogNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final FitLogBottomNavSurface surface;

  static const double barHeight = 72;
  static const double horizontalInset = 16;
  static const double bottomInset = 12;
  static const double topContentGap = 16;
  static const double scrollContentGap = 32;
  static const double floatingControlHeight = 60;
  static const double floatingControlToNavGap = 8;

  static double reservedHeightFor(BuildContext context) {
    return scrollBottomPaddingFor(context, contentGap: topContentGap);
  }

  static double fullScreenFootprintFor(BuildContext context) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return barHeight + math.max(safeBottom, bottomInset);
  }

  static double safeAreaContentOverlapFor(BuildContext context) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return fullScreenFootprintFor(context) - safeBottom;
  }

  static double homeFirstScreenBottomReserveFor(BuildContext context) {
    return safeAreaContentOverlapFor(context);
  }

  static double scrollBottomPaddingFor(
    BuildContext context, {
    double contentGap = scrollContentGap,
  }) {
    return safeAreaContentOverlapFor(context) + contentGap;
  }

  static double floatingControlScreenBottomPaddingFor(BuildContext context) {
    return fullScreenFootprintFor(context) + floatingControlToNavGap;
  }

  static double floatingControlSafeAreaBottomPaddingFor(BuildContext context) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    return floatingControlScreenBottomPaddingFor(context) - safeBottom;
  }

  static double floatingControlScrollBottomPaddingFor(
    BuildContext context, {
    double contentGap = scrollContentGap,
  }) {
    return floatingControlSafeAreaBottomPaddingFor(context) +
        floatingControlHeight +
        contentGap;
  }

  static double floatingControlScreenScrollBottomPaddingFor(
    BuildContext context, {
    double contentGap = scrollContentGap,
  }) {
    return floatingControlScreenBottomPaddingFor(context) +
        floatingControlHeight +
        contentGap;
  }

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    final labelStyle =
        Theme.of(context).textTheme.labelSmall ?? const TextStyle(fontSize: 11);
    final isGlass = surface == FitLogBottomNavSurface.glass;
    final glassBackgroundAlpha = fitTheme.isDark ? 0.70 : 0.54;
    final glassBorderAlpha = fitTheme.isDark ? 0.72 : 0.58;
    final backgroundColor = isGlass
        ? fitTheme.navBackground.withValues(alpha: glassBackgroundAlpha)
        : fitTheme.navBackground;
    final borderColor = isGlass
        ? fitTheme.outline.withValues(alpha: glassBorderAlpha)
        : fitTheme.outline;
    final shadowAlpha = isGlass
        ? (fitTheme.isDark ? 0.24 : 0.06)
        : (fitTheme.isDark ? 0.32 : 0.08);
    final bottomPadding = math.max(
      MediaQuery.viewPaddingOf(context).bottom,
      bottomInset,
    );
    final shieldHeight = barHeight / 2 + bottomPadding + 1;

    return SafeArea(
      maintainBottomViewPadding: true,
      minimum: const EdgeInsets.fromLTRB(
        horizontalInset,
        0,
        horizontalInset,
        bottomInset,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth;
          final segmentWidth = trackWidth / items.length;
          const indicatorInset = 5.0;
          const indicatorVerticalMargin = 7.0;
          final indicatorWidth = segmentWidth - indicatorInset * 2;

          final navPill = Container(
            key: const ValueKey<String>('fitlog_bottom_nav_bar'),
            height: barHeight,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: fitTheme.shadow.withValues(alpha: shadowAlpha),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  left: currentIndex * segmentWidth + indicatorInset,
                  top: indicatorVerticalMargin,
                  width: indicatorWidth,
                  height: barHeight - indicatorVerticalMargin * 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fitTheme.navIndicator,
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                ),
                Row(
                  children: List<Widget>.generate(items.length, (index) {
                    final item = items[index];
                    final selected = currentIndex == index;

                    return Expanded(
                      child: Tooltip(
                        message: item.label,
                        child: Semantics(
                          button: true,
                          selected: selected,
                          label: item.label,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onTap(index),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Icon(
                                    selected ? item.activeIcon : item.icon,
                                    color: selected
                                        ? fitTheme.primary
                                        : fitTheme.navUnselectedText,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 3),
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    style: labelStyle.copyWith(
                                      fontSize: 11,
                                      height: 1.0,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selected
                                          ? fitTheme.navSelectedText
                                          : fitTheme.navUnselectedText,
                                    ),
                                    child: Text(
                                      item.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );

          return SizedBox(
            height: barHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                if (!isGlass)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: barHeight / 2,
                    height: shieldHeight,
                    child: DecoratedBox(
                      key: const ValueKey<String>(
                        'fitlog_bottom_nav_bottom_shield',
                      ),
                      decoration: BoxDecoration(color: fitTheme.pageBackground),
                    ),
                  ),
                navPill,
              ],
            ),
          );
        },
      ),
    );
  }
}
