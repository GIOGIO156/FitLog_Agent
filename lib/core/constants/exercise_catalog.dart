import 'exercise_definition.dart';

class ExerciseCatalog {
  ExerciseCatalog._();

  static const Map<String, double> genericCardioMetByIntensity =
      <String, double>{
        CardioIntensityBasis.low60Plus: 3.5,
        CardioIntensityBasis.moderate30To60: 6.0,
        CardioIntensityBasis.vigorous10To30: 8.0,
        CardioIntensityBasis.high3To10: 10.0,
        CardioIntensityBasis.intervalUnder3: 12.0,
      };

  static const List<ExerciseDefinition> builtInExercises = <ExerciseDefinition>[
    ExerciseDefinition(
      key: 'barbell_flat_bench_press',
      name: 'Barbell Flat Bench Press',
      bodyPart: 'Chest',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
    ),
    ExerciseDefinition(
      key: 'barbell_incline_bench_press',
      name: 'Barbell Incline Bench Press',
      bodyPart: 'Chest',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
    ),
    ExerciseDefinition(
      key: 'dumbbell_flat_bench_press',
      name: 'Dumbbell Flat Bench Press',
      bodyPart: 'Chest',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
      loadInputMode: ExerciseLoadInputMode.perSideLoad,
    ),
    ExerciseDefinition(
      key: 'dumbbell_fly',
      name: 'Dumbbell Fly',
      bodyPart: 'Chest',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.isolation,
      strengthProfile: ExerciseStrengthProfile.isolation,
      loadInputMode: ExerciseLoadInputMode.perSideLoad,
    ),
    ExerciseDefinition(
      key: 'cable_fly',
      name: 'Cable Fly',
      bodyPart: 'Chest',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.isolation,
      strengthProfile: ExerciseStrengthProfile.isolation,
      loadInputMode: ExerciseLoadInputMode.perSideLoad,
    ),
    ExerciseDefinition(
      key: 'machine_chest_press',
      name: 'Machine Chest Press',
      bodyPart: 'Chest',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
    ),
    ExerciseDefinition(
      key: 'machine_pec_fly',
      name: 'Machine Pec Fly',
      bodyPart: 'Chest',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.isolation,
      strengthProfile: ExerciseStrengthProfile.isolation,
    ),
    ExerciseDefinition(
      key: 'kneeling_push_up',
      name: 'Kneeling Push-up',
      bodyPart: 'Chest',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
      loadInputMode: ExerciseLoadInputMode.bodyweightAdded,
    ),
    ExerciseDefinition(
      key: 'incline_dumbbell_press',
      name: 'Incline Dumbbell Press',
      bodyPart: 'Chest',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
      loadInputMode: ExerciseLoadInputMode.perSideLoad,
    ),
    ExerciseDefinition(
      key: 'push_up',
      name: 'Push-up',
      bodyPart: 'Chest',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
      loadInputMode: ExerciseLoadInputMode.bodyweightAdded,
    ),
    ExerciseDefinition(
      key: 'pull_up',
      name: 'Pull-up',
      bodyPart: 'Back',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
      loadInputMode: ExerciseLoadInputMode.bodyweightAdded,
    ),
    ExerciseDefinition(
      key: 'assisted_pull_up',
      name: 'Assisted Pull-up',
      bodyPart: 'Back',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
      loadInputMode: ExerciseLoadInputMode.assistanceLoad,
    ),
    ExerciseDefinition(
      key: 'lat_pulldown',
      name: 'Lat Pulldown',
      bodyPart: 'Back',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
    ),
    ExerciseDefinition(
      key: 'seated_row',
      name: 'Seated Row',
      bodyPart: 'Back',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
      legacyNames: <String>['Seated Cable Row'],
    ),
    ExerciseDefinition(
      key: 'bent_over_barbell_row',
      name: 'Bent-over Barbell Row',
      bodyPart: 'Back',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
    ),
    ExerciseDefinition(
      key: 'underhand_barbell_row',
      name: 'Underhand Barbell Row',
      bodyPart: 'Back',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
    ),
    ExerciseDefinition(
      key: 'seal_barbell_row',
      name: 'Seal Barbell Row',
      bodyPart: 'Back',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
    ),
    ExerciseDefinition(
      key: 'chest_supported_t_bar_row',
      name: 'Chest-supported T-Bar Row',
      bodyPart: 'Back',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
    ),
    ExerciseDefinition(
      key: 'iso_lateral_high_row',
      name: 'Iso-lateral High Row',
      bodyPart: 'Back',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
      loadInputMode: ExerciseLoadInputMode.perSideLoad,
      legacyNames: <String>['Hammer Strength High Row'],
    ),
    ExerciseDefinition(
      key: 'barbell_high_pull',
      name: 'Barbell High Pull',
      bodyPart: 'Back',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.isolation,
      strengthProfile: ExerciseStrengthProfile.isolation,
    ),
    ExerciseDefinition(
      key: 'barbell_pullover',
      name: 'Barbell Pullover',
      bodyPart: 'Back',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.isolation,
      strengthProfile: ExerciseStrengthProfile.isolation,
    ),
    ExerciseDefinition(
      key: 'barbell_straight_leg_deadlift',
      name: 'Barbell Straight-leg Deadlift',
      bodyPart: 'Back',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.lowerBodyCompound,
    ),
    ExerciseDefinition(
      key: 'single_arm_dumbbell_row',
      name: 'Single-arm Dumbbell Row',
      bodyPart: 'Back',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
      repsInputMode: ExerciseRepsInputMode.perSide,
    ),
    ExerciseDefinition(
      key: 'squat',
      name: 'Squat',
      bodyPart: 'Legs',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.lowerBodyCompound,
    ),
    ExerciseDefinition(
      key: 'bulgarian_split_squat',
      name: 'Bulgarian Split Squat',
      bodyPart: 'Legs',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.lowerBodyCompound,
      repsInputMode: ExerciseRepsInputMode.perSide,
    ),
    ExerciseDefinition(
      key: 'deadlift',
      name: 'Deadlift',
      bodyPart: 'Legs',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.lowerBodyCompound,
    ),
    ExerciseDefinition(
      key: 'leg_press',
      name: 'Leg Press',
      bodyPart: 'Legs',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.lowerBodyCompound,
    ),
    ExerciseDefinition(
      key: 'romanian_deadlift',
      name: 'Romanian Deadlift',
      bodyPart: 'Legs',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.lowerBodyCompound,
    ),
    ExerciseDefinition(
      key: 'leg_extension',
      name: 'Leg Extension',
      bodyPart: 'Legs',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.isolation,
      strengthProfile: ExerciseStrengthProfile.isolation,
    ),
    ExerciseDefinition(
      key: 'leg_curl',
      name: 'Leg Curl',
      bodyPart: 'Legs',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.isolation,
      strengthProfile: ExerciseStrengthProfile.isolation,
    ),
    ExerciseDefinition(
      key: 'barbell_hip_thrust',
      name: 'Barbell Hip Thrust',
      bodyPart: 'Glutes',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.lowerBodyCompound,
    ),
    ExerciseDefinition(
      key: 'barbell_overhead_press',
      name: 'Barbell Overhead Press',
      bodyPart: 'Shoulders',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
      legacyNames: <String>['Overhead Press'],
    ),
    ExerciseDefinition(
      key: 'lateral_raise',
      name: 'Lateral Raise',
      bodyPart: 'Shoulders',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.isolation,
      strengthProfile: ExerciseStrengthProfile.isolation,
      loadInputMode: ExerciseLoadInputMode.perSideLoad,
    ),
    ExerciseDefinition(
      key: 'dumbbell_rear_delt_fly',
      name: 'Dumbbell Rear Delt Fly',
      bodyPart: 'Shoulders',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.isolation,
      strengthProfile: ExerciseStrengthProfile.isolation,
      loadInputMode: ExerciseLoadInputMode.perSideLoad,
      legacyNames: <String>['Rear Delt Fly'],
    ),
    ExerciseDefinition(
      key: 'standing_dumbbell_shoulder_press',
      name: 'Standing Dumbbell Shoulder Press',
      bodyPart: 'Shoulders',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
      loadInputMode: ExerciseLoadInputMode.perSideLoad,
    ),
    ExerciseDefinition(
      key: 'standing_barbell_shoulder_press',
      name: 'Standing Barbell Shoulder Press',
      bodyPart: 'Shoulders',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
    ),
    ExerciseDefinition(
      key: 'seated_barbell_shoulder_press',
      name: 'Seated Barbell Shoulder Press',
      bodyPart: 'Shoulders',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
    ),
    ExerciseDefinition(
      key: 'standing_barbell_front_raise',
      name: 'Standing Barbell Front Raise',
      bodyPart: 'Shoulders',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.isolation,
      strengthProfile: ExerciseStrengthProfile.isolation,
    ),
    ExerciseDefinition(
      key: 'barbell_upright_row',
      name: 'Barbell Upright Row',
      bodyPart: 'Shoulders',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.isolation,
      strengthProfile: ExerciseStrengthProfile.isolation,
    ),
    ExerciseDefinition(
      key: 'barbell_biceps_curl',
      name: 'Barbell Biceps Curl',
      bodyPart: 'Arms',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.isolation,
      strengthProfile: ExerciseStrengthProfile.isolation,
    ),
    ExerciseDefinition(
      key: 'dumbbell_biceps_curl',
      name: 'Dumbbell Biceps Curl',
      bodyPart: 'Arms',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.isolation,
      strengthProfile: ExerciseStrengthProfile.isolation,
      loadInputMode: ExerciseLoadInputMode.perSideLoad,
      legacyNames: <String>['Biceps Curl'],
    ),
    ExerciseDefinition(
      key: 'hammer_curl',
      name: 'Hammer Curl',
      bodyPart: 'Arms',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.isolation,
      strengthProfile: ExerciseStrengthProfile.isolation,
      loadInputMode: ExerciseLoadInputMode.perSideLoad,
    ),
    ExerciseDefinition(
      key: 'triceps_pushdown',
      name: 'Triceps Pushdown',
      bodyPart: 'Arms',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.isolation,
      strengthProfile: ExerciseStrengthProfile.isolation,
    ),
    ExerciseDefinition(
      key: 'close_grip_bench_press',
      name: 'Close-grip Bench Press',
      bodyPart: 'Arms',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
    ),
    ExerciseDefinition(
      key: 'dip',
      name: 'Dip',
      bodyPart: 'Arms',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
      loadInputMode: ExerciseLoadInputMode.bodyweightAdded,
    ),
    ExerciseDefinition(
      key: 'assisted_dip',
      name: 'Assisted Dip',
      bodyPart: 'Arms',
      exerciseType: ExerciseType.strength,
      strengthProfile: ExerciseStrengthProfile.upperBodyCompound,
      loadInputMode: ExerciseLoadInputMode.assistanceLoad,
    ),
    ExerciseDefinition(
      key: 'plank',
      name: 'Plank',
      bodyPart: 'Core',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.isolation,
      strengthProfile: ExerciseStrengthProfile.isolation,
      loadInputMode: ExerciseLoadInputMode.bodyweightAdded,
      setMetricType: ExerciseSetMetricType.durationSeconds,
    ),
    ExerciseDefinition(
      key: 'crunch',
      name: 'Crunch',
      bodyPart: 'Core',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.isolation,
      strengthProfile: ExerciseStrengthProfile.isolation,
      loadInputMode: ExerciseLoadInputMode.bodyweightAdded,
    ),
    ExerciseDefinition(
      key: 'hanging_leg_raise',
      name: 'Hanging Leg Raise',
      bodyPart: 'Core',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.isolation,
      strengthProfile: ExerciseStrengthProfile.isolation,
      loadInputMode: ExerciseLoadInputMode.bodyweightAdded,
    ),
    ExerciseDefinition(
      key: 'walking',
      name: 'Walking',
      bodyPart: 'Cardio',
      exerciseType: ExerciseType.cardio,
      defaultCardioIntensity: CardioIntensityBasis.low60Plus,
      cardioMetByIntensity: <String, double>{
        CardioIntensityBasis.low60Plus: 3.5,
        CardioIntensityBasis.moderate30To60: 4.3,
        CardioIntensityBasis.vigorous10To30: 6.0,
        CardioIntensityBasis.high3To10: 7.0,
        CardioIntensityBasis.intervalUnder3: 8.0,
      },
    ),
    ExerciseDefinition(
      key: 'running',
      name: 'Running',
      bodyPart: 'Cardio',
      exerciseType: ExerciseType.cardio,
      defaultCardioIntensity: CardioIntensityBasis.vigorous10To30,
      cardioMetByIntensity: <String, double>{
        CardioIntensityBasis.low60Plus: 6.0,
        CardioIntensityBasis.moderate30To60: 8.0,
        CardioIntensityBasis.vigorous10To30: 10.0,
        CardioIntensityBasis.high3To10: 12.0,
        CardioIntensityBasis.intervalUnder3: 14.0,
      },
    ),
    ExerciseDefinition(
      key: 'cycling',
      name: 'Cycling',
      bodyPart: 'Cardio',
      exerciseType: ExerciseType.cardio,
      defaultCardioIntensity: CardioIntensityBasis.moderate30To60,
      cardioMetByIntensity: <String, double>{
        CardioIntensityBasis.low60Plus: 4.0,
        CardioIntensityBasis.moderate30To60: 6.0,
        CardioIntensityBasis.vigorous10To30: 8.0,
        CardioIntensityBasis.high3To10: 10.0,
        CardioIntensityBasis.intervalUnder3: 12.0,
      },
    ),
    ExerciseDefinition(
      key: 'rowing_machine',
      name: 'Rowing Machine',
      bodyPart: 'Cardio',
      exerciseType: ExerciseType.cardio,
      defaultCardioIntensity: CardioIntensityBasis.vigorous10To30,
      cardioMetByIntensity: <String, double>{
        CardioIntensityBasis.low60Plus: 5.0,
        CardioIntensityBasis.moderate30To60: 7.0,
        CardioIntensityBasis.vigorous10To30: 9.0,
        CardioIntensityBasis.high3To10: 11.0,
        CardioIntensityBasis.intervalUnder3: 12.5,
      },
    ),
    ExerciseDefinition(
      key: 'stair_climber',
      name: 'Stair Climber',
      bodyPart: 'Cardio',
      exerciseType: ExerciseType.cardio,
      defaultCardioIntensity: CardioIntensityBasis.vigorous10To30,
      cardioMetByIntensity: <String, double>{
        CardioIntensityBasis.low60Plus: 5.5,
        CardioIntensityBasis.moderate30To60: 8.0,
        CardioIntensityBasis.vigorous10To30: 9.5,
        CardioIntensityBasis.high3To10: 11.0,
        CardioIntensityBasis.intervalUnder3: 12.5,
      },
    ),
    ExerciseDefinition(
      key: 'kettlebell_swing',
      name: 'Kettlebell Swing',
      bodyPart: 'Full Body',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.fullBodyAuto,
      strengthProfile: ExerciseStrengthProfile.fullBodyPowerOrHighDensity,
    ),
    ExerciseDefinition(
      key: 'burpee',
      name: 'Burpee',
      bodyPart: 'Full Body',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.fullBodyAuto,
      strengthProfile: ExerciseStrengthProfile.fullBodyPowerOrHighDensity,
      loadInputMode: ExerciseLoadInputMode.bodyweightAdded,
    ),
    ExerciseDefinition(
      key: 'jumping_jack',
      name: 'Jumping Jack',
      bodyPart: 'Full Body',
      exerciseType: ExerciseType.strength,
      strengthStructure: ExerciseStructure.fullBodyAuto,
      strengthProfile: ExerciseStrengthProfile.fullBodyPowerOrHighDensity,
      loadInputMode: ExerciseLoadInputMode.bodyweightAdded,
    ),
  ];

  static List<String> get bodyParts {
    final seen = <String>{};
    return builtInExercises
        .map((exercise) => exercise.bodyPart)
        .where(seen.add)
        .toList();
  }

  static Map<String, List<String>> get bodyPartExercises {
    final result = <String, List<String>>{};
    for (final exercise in builtInExercises) {
      result.putIfAbsent(exercise.bodyPart, () => <String>[]);
      result[exercise.bodyPart]!.add(exercise.name);
    }
    return result;
  }

  static ExerciseDefinition? byKey(String? key) {
    final normalized = (key ?? '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    for (final exercise in builtInExercises) {
      if (exercise.key == normalized) {
        return exercise;
      }
    }
    return null;
  }

  static ExerciseDefinition? byName(String? name) {
    final normalized = (name ?? '').trim();
    if (normalized.isEmpty) {
      return null;
    }
    for (final exercise in builtInExercises) {
      if (exercise.name == normalized ||
          exercise.legacyNames.contains(normalized)) {
        return exercise;
      }
    }
    return null;
  }

  static ExerciseDefinition fallbackForSession({
    required String exerciseName,
    required String bodyPart,
    required String exerciseType,
  }) {
    final known = byName(exerciseName);
    if (known != null) {
      return known;
    }
    return ExerciseDefinition(
      key: 'legacy_${exerciseName.trim().toLowerCase().replaceAll(' ', '_')}',
      name: exerciseName,
      bodyPart: bodyPart,
      exerciseType: exerciseType,
      isBuiltin: false,
      cardioMetByIntensity: exerciseType == ExerciseType.cardio
          ? genericCardioMetByIntensity
          : const <String, double>{},
    );
  }

  static double cardioMetFor({
    required ExerciseDefinition definition,
    required String intensity,
  }) {
    return definition.cardioMetByIntensity[intensity] ??
        genericCardioMetByIntensity[intensity] ??
        genericCardioMetByIntensity[CardioIntensityBasis.moderate30To60]!;
  }

  static bool isBodyweightExercise(String exerciseName) {
    return byName(exerciseName)?.usesBodyweight ?? false;
  }

  static bool isAssistedBodyweightExercise(String exerciseName) {
    return byName(exerciseName)?.usesAssistance ?? false;
  }
}
