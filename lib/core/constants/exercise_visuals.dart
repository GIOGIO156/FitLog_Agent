import 'package:flutter/material.dart';

class ExerciseVisuals {
  ExerciseVisuals._();

  static IconData iconForBodyPart(String bodyPart) {
    switch (bodyPart) {
      case 'Chest':
        return Icons.fitness_center;
      case 'Back':
        return Icons.accessibility_new;
      case 'Legs':
        return Icons.directions_run;
      case 'Glutes':
        return Icons.hiking;
      case 'Shoulders':
        return Icons.sports_mma;
      case 'Arms':
        return Icons.sports_gymnastics;
      case 'Core':
        return Icons.self_improvement;
      case 'Cardio':
        return Icons.monitor_heart;
      case 'Full Body':
        return Icons.bolt;
      default:
        return Icons.fitness_center;
    }
  }

  static Color colorForBodyPart(String bodyPart, BuildContext context) {
    switch (bodyPart) {
      case 'Chest':
        return const Color(0xFFEF4444);
      case 'Back':
        return const Color(0xFF3B82F6);
      case 'Legs':
        return const Color(0xFFF59E0B);
      case 'Glutes':
        return const Color(0xFFEA580C);
      case 'Shoulders':
        return const Color(0xFF8B5CF6);
      case 'Arms':
        return const Color(0xFF06B6D4);
      case 'Core':
        return const Color(0xFFEC4899);
      case 'Cardio':
        return const Color(0xFF10B981);
      case 'Full Body':
        return const Color(0xFF22C55E);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
}
