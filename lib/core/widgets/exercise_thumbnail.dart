import 'package:flutter/material.dart';

import '../theme/fitlog_theme.dart';
import 'fitlog_ui.dart';

class ExerciseThumbnail extends StatelessWidget {
  const ExerciseThumbnail({
    super.key,
    required this.bodyPart,
    required this.exerciseName,
    required this.color,
    this.size = 56,
    this.useDarkThemeBadgeColors = false,
  });

  final String bodyPart;
  final String exerciseName;
  final Color color;
  final double size;
  final bool useDarkThemeBadgeColors;

  @override
  Widget build(BuildContext context) {
    final exerciseAsset = fitLogWorkoutAssetForExercise(exerciseName);
    final badgeStyle = ExerciseThumbnailBadgeStyle.resolve(
      bodyPart: bodyPart,
      bodyPartColor: color,
      fitLogTheme: context.fitLogTheme,
      useDarkThemeBadgeColors: useDarkThemeBadgeColors,
    );
    final assetScale = switch (bodyPart) {
      'Full Body' => 0.82,
      'Cardio' => 0.74,
      _ => 0.66,
    };
    final fallbackScale = switch (bodyPart) {
      'Full Body' => 0.7,
      'Cardio' => 0.62,
      _ => 0.52,
    };

    if (exerciseAsset != null) {
      return _ExerciseThumbnailBadge(
        size: size,
        style: badgeStyle,
        child: Image.asset(
          exerciseAsset,
          width: size * assetScale,
          height: size * assetScale,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      );
    }

    if (badgeStyle.ringColor != null) {
      return _ExerciseThumbnailBadge(
        size: size,
        style: badgeStyle,
        child: FitLogAssetIcon(
          assetName: fitLogWorkoutAssetForBodyPart(bodyPart),
          size: size * fallbackScale,
          tintColor: color,
        ),
      );
    }

    return FitLogAssetIconCircle(
      assetName: fitLogWorkoutAssetForBodyPart(bodyPart),
      size: size,
      iconSize: size * fallbackScale,
      backgroundColor: badgeStyle.fillColor,
      tintColor: color,
    );
  }
}

class ExerciseThumbnailBadgeStyle {
  const ExerciseThumbnailBadgeStyle({
    required this.fillColor,
    required this.ringColor,
  });

  final Color fillColor;
  final Color? ringColor;

  static ExerciseThumbnailBadgeStyle resolve({
    required String bodyPart,
    required Color bodyPartColor,
    required FitLogThemeData fitLogTheme,
    required bool useDarkThemeBadgeColors,
  }) {
    if (useDarkThemeBadgeColors &&
        fitLogTheme.key == FitLogThemeKey.blackOrange) {
      return _blackOrangeBadgeStyles[bodyPart] ??
          _blackOrangeBadgeStyles['Full Body']!;
    }
    return ExerciseThumbnailBadgeStyle(
      fillColor: bodyPartColor.withValues(alpha: 0.14),
      ringColor: null,
    );
  }

  static const Map<String, ExerciseThumbnailBadgeStyle>
  _blackOrangeBadgeStyles = <String, ExerciseThumbnailBadgeStyle>{
    'Chest': ExerciseThumbnailBadgeStyle(
      fillColor: Color(0xFF402824),
      ringColor: Color(0xFF8B5A52),
    ),
    'Back': ExerciseThumbnailBadgeStyle(
      fillColor: Color(0xFF27303D),
      ringColor: Color(0xFF60718A),
    ),
    'Legs': ExerciseThumbnailBadgeStyle(
      fillColor: Color(0xFF41341C),
      ringColor: Color(0xFF9A7D40),
    ),
    'Glutes': ExerciseThumbnailBadgeStyle(
      fillColor: Color(0xFFD66A3C),
      ringColor: Color(0xFFF1A073),
    ),
    'Shoulders': ExerciseThumbnailBadgeStyle(
      fillColor: Color(0xFF626A72),
      ringColor: Color(0xFF9AA4AD),
    ),
    'Arms': ExerciseThumbnailBadgeStyle(
      fillColor: Color(0xFF203838),
      ringColor: Color(0xFF5D8989),
    ),
    'Core': ExerciseThumbnailBadgeStyle(
      fillColor: Color(0xFF402830),
      ringColor: Color(0xFF8B5A68),
    ),
    'Cardio': ExerciseThumbnailBadgeStyle(
      fillColor: Color(0xFF21382D),
      ringColor: Color(0xFF5F8B70),
    ),
    'Full Body': ExerciseThumbnailBadgeStyle(
      fillColor: Color(0xFF68727E),
      ringColor: Color(0xFFA0AABD),
    ),
  };
}

class _ExerciseThumbnailBadge extends StatelessWidget {
  const _ExerciseThumbnailBadge({
    required this.size,
    required this.style,
    required this.child,
  });

  final double size;
  final ExerciseThumbnailBadgeStyle style;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.fillColor,
        shape: BoxShape.circle,
        border: style.ringColor == null
            ? null
            : Border.all(color: style.ringColor!, width: 1),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
