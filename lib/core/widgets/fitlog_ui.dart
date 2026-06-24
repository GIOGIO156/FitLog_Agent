import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/app_constants.dart';
import '../constants/fitlog_icon_assets.dart';
import '../localization/localization_extensions.dart';
import '../theme/fitlog_theme.dart';
import '../utils/date_utils.dart';

class FitLogPageHeader extends StatelessWidget {
  const FitLogPageHeader({
    super.key,
    required this.title,
    this.titleWidget,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 12),
  });

  final String title;
  final Widget? titleWidget;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: fitTheme.textPrimary,
    );
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: fitTheme.textSecondary,
      height: 1.4,
    );

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                titleWidget ?? Text(title, style: titleStyle),
                if ((subtitle ?? '').trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(subtitle!, style: subtitleStyle),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class FitLogSectionHeader extends StatelessWidget {
  const FitLogSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onTap,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    final actionEnabled =
        onTap != null && (actionLabel ?? '').trim().isNotEmpty;
    return Padding(
      padding: padding,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: fitTheme.textPrimary,
              ),
            ),
          ),
          if (actionEnabled)
            TextButton(onPressed: onTap, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class FitLogIconCircle extends StatelessWidget {
  const FitLogIconCircle({
    super.key,
    required this.icon,
    required this.color,
    this.size = 42,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: (fitTheme.isDark ? fitTheme.primarySoft : color).withValues(
          alpha: fitTheme.isDark ? 1 : 0.14,
        ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: fitTheme.isDark ? fitTheme.primaryDeep : color,
        size: size * 0.48,
      ),
    );
  }
}

class FitLogSvgIcon extends StatelessWidget {
  const FitLogSvgIcon({
    super.key,
    required this.assetName,
    required this.size,
    this.tintColor,
  });

  final String assetName;
  final double size;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      assetName,
      width: size,
      height: size,
      colorFilter: tintColor == null
          ? null
          : ColorFilter.mode(tintColor!, BlendMode.srcIn),
    );
  }
}

class FitLogAssetIcon extends StatelessWidget {
  const FitLogAssetIcon({
    super.key,
    required this.assetName,
    required this.size,
    this.tintColor,
  });

  final String assetName;
  final double size;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    if (assetName.toLowerCase().endsWith('.svg')) {
      return FitLogSvgIcon(
        assetName: assetName,
        size: size,
        tintColor: tintColor,
      );
    }

    return Image.asset(
      assetName,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      color: tintColor,
      colorBlendMode: tintColor == null ? null : BlendMode.srcIn,
    );
  }
}

class FitLogSvgIconCircle extends StatelessWidget {
  const FitLogSvgIconCircle({
    super.key,
    required this.assetName,
    required this.backgroundColor,
    this.size = 42,
    this.iconSize,
    this.tintColor,
  });

  final String assetName;
  final Color backgroundColor;
  final double size;
  final double? iconSize;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: FitLogSvgIcon(
        assetName: assetName,
        size: iconSize ?? size * 0.56,
        tintColor: tintColor,
      ),
    );
  }
}

class FitLogAssetIconCircle extends StatelessWidget {
  const FitLogAssetIconCircle({
    super.key,
    required this.assetName,
    required this.backgroundColor,
    this.size = 42,
    this.iconSize,
    this.tintColor,
  });

  final String assetName;
  final Color backgroundColor;
  final double size;
  final double? iconSize;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: FitLogAssetIcon(
        assetName: assetName,
        size: iconSize ?? size * 0.56,
        tintColor: tintColor,
      ),
    );
  }
}

class FitLogStrategyGuideSection extends StatelessWidget {
  const FitLogStrategyGuideSection({
    super.key,
    required this.title,
    required this.lines,
  });

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: fitTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(top: 7),
                    decoration: BoxDecoration(
                      color: fitTheme.primaryBright,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      line,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: fitTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String fitLogWorkoutAssetForBodyPart(String bodyPart) {
  switch (bodyPart) {
    case 'Chest':
      return FitLogIconAssets.workoutChest;
    case 'Back':
      return FitLogIconAssets.workoutBack;
    case 'Legs':
      return FitLogIconAssets.workoutLegs;
    case 'Glutes':
      return FitLogIconAssets.workoutLegs;
    case 'Shoulders':
      return FitLogIconAssets.workoutShoulders;
    case 'Arms':
      return FitLogIconAssets.workoutArms;
    case 'Core':
      return FitLogIconAssets.workoutCore;
    case 'Cardio':
      return FitLogIconAssets.workoutCardio;
    case 'Full Body':
      return FitLogIconAssets.workoutFullBody;
    default:
      return FitLogIconAssets.workoutFullBody;
  }
}

String? fitLogWorkoutAssetForExercise(String exerciseName) {
  switch (exerciseName) {
    case 'Bench Press':
      return FitLogIconAssets.exerciseBenchPress;
    case 'Cable Fly':
      return FitLogIconAssets.exerciseCableFly;
    case 'Deadlift':
      return FitLogIconAssets.exerciseDeadlift;
    case 'Dumbbell Biceps Curl':
      return FitLogIconAssets.exerciseDumbbellBicepsCurl;
    case 'Dumbbell Fly':
      return FitLogIconAssets.exerciseDumbbellFly;
    case 'Barbell Biceps Curl':
      return FitLogIconAssets.exerciseBarbellBicepsCurl;
    case 'Bent-over Barbell Row':
      return FitLogIconAssets.exerciseBentOverBarbellRow;
    case 'Lateral Raise':
      return FitLogIconAssets.exerciseLateralRaise;
    case 'Lat Pulldown':
      return FitLogIconAssets.exerciseLatPulldown;
    case 'Barbell Overhead Press':
    case 'Overhead Press':
      return FitLogIconAssets.exerciseOverheadPress;
    case 'Pull-up':
      return FitLogIconAssets.exercisePullUp;
    case 'Running':
      return FitLogIconAssets.exerciseRunning;
    case 'Seated Cable Row':
    case 'Seated Row':
      return FitLogIconAssets.exerciseSeatedRow;
    case 'Squat':
      return FitLogIconAssets.exerciseSquat;
    default:
      return null;
  }
}

class FitLogActionIconButton extends StatelessWidget {
  const FitLogActionIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    return IconButton.filledTonal(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: fitTheme.surface,
        foregroundColor: fitTheme.primaryDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: Icon(icon, size: 20),
    );
  }
}

class FitLogDateStrip extends StatelessWidget {
  const FitLogDateStrip({
    super.key,
    required this.selectedDate,
    required this.onSelect,
    required this.onOpenPicker,
  });

  final String selectedDate;
  final ValueChanged<String> onSelect;
  final VoidCallback onOpenPicker;

  @override
  Widget build(BuildContext context) {
    final fitTheme = context.fitLogTheme;
    final selected = DateUtilsX.parseDay(selectedDate);
    final startOfWeek = selected.subtract(Duration(days: selected.weekday - 1));

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                DateUtilsX.formatReadable(selectedDate),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: fitTheme.textPrimary,
                ),
              ),
            ),
            FitLogActionIconButton(
              icon: Icons.calendar_today_outlined,
              tooltip: context.strings.change,
              onPressed: onOpenPicker,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: List<Widget>.generate(7, (index) {
            final day = startOfWeek.add(Duration(days: index));
            final dayKey = DateUtilsX.formatDate(day);
            final isSelected = dayKey == selectedDate;
            final weekdayKey = AppConstants.weekdayKeyFromDateTime(day);

            return Expanded(
              child: GestureDetector(
                onTap: () => onSelect(dayKey),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? fitTheme.primaryBright
                        : fitTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? fitTheme.primaryBright
                          : fitTheme.outline,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        context.strings.weekdayUltraShortLabel(weekdayKey),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? fitTheme.onPrimary.withValues(alpha: 0.92)
                              : fitTheme.mutedText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isSelected
                              ? fitTheme.onPrimary
                              : fitTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}
