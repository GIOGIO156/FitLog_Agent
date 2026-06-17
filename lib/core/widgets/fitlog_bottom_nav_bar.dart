import 'package:flutter/material.dart';

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

class FitLogBottomNavBar extends StatelessWidget {
  const FitLogBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<FitLogNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final trackWidth = constraints.maxWidth;
          final segmentWidth = trackWidth / items.length;
          const indicatorInset = 5.0;
          const indicatorVerticalMargin = 7.0;
          final indicatorWidth = segmentWidth - indicatorInset * 2;

          return Container(
            key: const ValueKey<String>('fitlog_bottom_nav_bar'),
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE2ECDD)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: const Color(0xFF13200F).withValues(alpha: 0.08),
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
                  height: 72 - indicatorVerticalMargin * 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF6E3),
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
                                        ? const Color(0xFF4E9E3B)
                                        : const Color(0xFF7A8973),
                                    size: 22,
                                  ),
                                  const SizedBox(height: 3),
                                  AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    style: TextStyle(
                                      fontSize: 11,
                                      height: 1.0,
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selected
                                          ? const Color(0xFF234120)
                                          : const Color(0xFF7A8973),
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
        },
      ),
    );
  }
}
