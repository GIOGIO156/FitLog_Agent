import 'package:flutter/material.dart';

import 'fitlog_ui.dart';

class ExerciseThumbnail extends StatelessWidget {
  const ExerciseThumbnail({
    super.key,
    required this.bodyPart,
    required this.exerciseName,
    required this.color,
    this.size = 56,
  });

  final String bodyPart;
  final String exerciseName;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final exerciseAsset = fitLogWorkoutAssetForExercise(exerciseName);
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
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Image.asset(
          exerciseAsset,
          width: size * assetScale,
          height: size * assetScale,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      );
    }

    return FitLogAssetIconCircle(
      assetName: fitLogWorkoutAssetForBodyPart(bodyPart),
      size: size,
      iconSize: size * fallbackScale,
      backgroundColor: color.withValues(alpha: 0.14),
      tintColor: color,
    );
  }
}
