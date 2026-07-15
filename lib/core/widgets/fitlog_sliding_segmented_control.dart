import 'package:flutter/material.dart';

class FitLogSlidingSegment<T> {
  const FitLogSlidingSegment({
    required this.value,
    required this.label,
    this.key,
  });

  final T value;
  final String label;
  final Key? key;
}

class FitLogSlidingSegmentedControl<T> extends StatelessWidget {
  const FitLogSlidingSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    required this.backgroundColor,
    required this.borderColor,
    required this.indicatorColor,
    required this.selectedTextColor,
    required this.unselectedTextColor,
    this.indicatorKey,
    this.width = 184,
    this.height = 38,
  }) : assert(segments.length >= 2);

  final List<FitLogSlidingSegment<T>> segments;
  final T selected;
  final ValueChanged<T>? onChanged;
  final Color backgroundColor;
  final Color borderColor;
  final Color indicatorColor;
  final Color selectedTextColor;
  final Color unselectedTextColor;
  final Key? indicatorKey;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = segments.indexWhere(
      (segment) => segment.value == selected,
    );
    assert(selectedIndex >= 0);
    final labelStyle =
        Theme.of(context).textTheme.labelMedium ??
        const TextStyle(fontSize: 12);

    return SizedBox(
      width: width,
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segmentWidth = constraints.maxWidth / segments.length;
          const indicatorInset = 3.0;

          return DecoratedBox(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor),
            ),
            child: Stack(
              children: <Widget>[
                AnimatedPositioned(
                  key: indicatorKey,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  left: selectedIndex * segmentWidth + indicatorInset,
                  top: indicatorInset,
                  width: segmentWidth - indicatorInset * 2,
                  height: height - indicatorInset * 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: indicatorColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                Row(
                  children: segments
                      .map((segment) {
                        final isSelected = segment.value == selected;
                        return Expanded(
                          child: Semantics(
                            button: true,
                            selected: isSelected,
                            label: segment.label,
                            child: GestureDetector(
                              key: segment.key,
                              behavior: HitTestBehavior.opaque,
                              onTap: onChanged == null
                                  ? null
                                  : () => onChanged!(segment.value),
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  style: labelStyle.copyWith(
                                    color: isSelected
                                        ? selectedTextColor
                                        : unselectedTextColor,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                  child: Text(
                                    segment.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
