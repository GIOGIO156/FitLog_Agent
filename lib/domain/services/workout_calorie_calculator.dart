import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../../core/constants/exercise_catalog.dart';
import '../../core/constants/exercise_definition.dart';
import '../models/workout_set.dart';

class WorkoutCalorieCalculator {
  WorkoutCalorieCalculator._();

  // Cardio follows duration-based MET logic.
  static const Map<String, double> _cardioMetMap = <String, double>{
    'Walking': 4.3,
    'Running': 8,
    'Cycling': 6,
    'Rowing Machine': 7,
    'Stair Climber': 8,
  };

  // Approximate body-mass share moved in common bodyweight movements.
  static const Map<String, double> _bodyweightLoadShare = <String, double>{
    'Push-up': 0.69,
    'Kneeling Push-up': 0.45,
    'Plank': 0.60,
    'Crunch': 0.45,
    'Hanging Leg Raise': 0.90,
    'Pull-up': 1.00,
    'Assisted Pull-up': 1.00,
    'Dip': 0.90,
    'Assisted Dip': 0.90,
    'Burpee': 1.00,
    'Jumping Jack': 0.65,
  };

  static const Set<String> _upperBodyCompoundExercises = <String>{
    'Barbell Flat Bench Press',
    'Barbell Incline Bench Press',
    'Dumbbell Flat Bench Press',
    'Machine Chest Press',
    'Bench Press',
    'Incline Dumbbell Press',
    'Close-grip Bench Press',
    'Dip',
    'Assisted Dip',
    'Barbell Row',
    'Seated Cable Row',
    'Seated Row',
    'Bent-over Barbell Row',
    'Underhand Barbell Row',
    'Seal Barbell Row',
    'Chest-supported T-Bar Row',
    'Iso-lateral High Row',
    'Hammer Strength High Row',
    'Single-arm Dumbbell Row',
    'Lat Pulldown',
    'Standing Dumbbell Shoulder Press',
    'Standing Barbell Shoulder Press',
    'Seated Barbell Shoulder Press',
    'Barbell Overhead Press',
    'Overhead Press',
    'Pull-up',
    'Assisted Pull-up',
    'Push-up',
    'Kneeling Push-up',
  };

  static const Set<String> _lowerBodyCompoundExercises = <String>{
    'Squat',
    'Bulgarian Split Squat',
    'Deadlift',
    'Romanian Deadlift',
    'Barbell Straight-leg Deadlift',
    'Leg Press',
    'Barbell Hip Thrust',
  };

  static const Set<String> _fullBodyPowerHighDensityExercises = <String>{
    'Kettlebell Swing',
    'Burpee',
    'Jumping Jack',
  };

  static const Set<String> _isolationExercises = <String>{
    'Dumbbell Fly',
    'Cable Fly',
    'Machine Pec Fly',
    'Chest Fly',
    'Leg Extension',
    'Leg Curl',
    'Lateral Raise',
    'Dumbbell Rear Delt Fly',
    'Rear Delt Fly',
    'Standing Barbell Front Raise',
    'Barbell Upright Row',
    'Barbell High Pull',
    'Barbell Pullover',
    'Barbell Biceps Curl',
    'Dumbbell Biceps Curl',
    'Biceps Curl',
    'Triceps Pushdown',
    'Hammer Curl',
    'Crunch',
    'Plank',
    'Hanging Leg Raise',
  };

  static const _StrengthProfile _upperBodyCompoundProfile = _StrengthProfile(
    category: _StrengthCategory.upperBodyCompound,
    strengthCoefficient: 0.013,
    postTrainingRecoveryRate: 0.28,
    muscleRepairAdaptationRate: 0.12,
  );

  static const _StrengthProfile _lowerBodyCompoundProfile = _StrengthProfile(
    category: _StrengthCategory.lowerBodyCompound,
    strengthCoefficient: 0.019,
    postTrainingRecoveryRate: 0.34,
    muscleRepairAdaptationRate: 0.16,
  );

  static const _StrengthProfile _isolationProfile = _StrengthProfile(
    category: _StrengthCategory.isolation,
    strengthCoefficient: 0.0085,
    postTrainingRecoveryRate: 0.12,
    muscleRepairAdaptationRate: 0.06,
  );

  static const _StrengthProfile _fullBodyPowerHighDensityProfile =
      _StrengthProfile(
        category: _StrengthCategory.fullBodyPowerOrHighDensity,
        strengthCoefficient: 0.024,
        postTrainingRecoveryRate: 0.45,
        muscleRepairAdaptationRate: 0.20,
      );

  static double estimateCardioCalories({
    required String exerciseName,
    required double bodyWeightKg,
    required int durationMinutes,
    ExerciseDefinition? definition,
    String? intensityBasis,
    double? met,
    int? activeDurationMinutes,
  }) {
    final resolvedDefinition =
        definition ??
        (intensityBasis == null && met == null
            ? null
            : ExerciseCatalog.byName(exerciseName));
    final resolvedIntensity =
        intensityBasis ??
        resolvedDefinition?.defaultCardioIntensity ??
        CardioIntensityBasis.moderate30To60;
    final double resolvedMet =
        met ??
        (resolvedDefinition == null
            ? (_cardioMetMap[exerciseName] ?? 6)
            : ExerciseCatalog.cardioMetFor(
                definition: resolvedDefinition,
                intensity: resolvedIntensity,
              ));
    final safeDurationMinutes = math.max(
      0,
      activeDurationMinutes ?? durationMinutes,
    );
    if (safeDurationMinutes <= 0 || bodyWeightKg <= 0) {
      return 0;
    }

    // Net cardio kcal: remove 1 MET resting component to avoid double-counting
    // baseline expenditure that is already inside daily non-exercise target.
    final netMet = math.max(0.0, resolvedMet - 1.0);
    final netKcal =
        netMet * 3.5 * bodyWeightKg / 200 * safeDurationMinutes.toDouble();
    return math.max(0, netKcal);
  }

  static double estimateStrengthCalories({
    required String exerciseName,
    required double bodyWeightKg,
    required List<WorkoutSet> sets,
    int? totalSessionDurationMinutes,
    ExerciseDefinition? definition,
    String? strengthProfile,
  }) {
    if (sets.isEmpty || bodyWeightKg <= 0) {
      return 0;
    }

    final completedSets = sets
        .where((set) => set.isCompleted && _effectiveReps(set) > 0)
        .toList();
    final validSets = completedSets.isNotEmpty
        ? completedSets
        : sets.where((set) => _effectiveReps(set) > 0).toList();
    if (validSets.isEmpty) {
      return 0;
    }

    final profile = _profileForExercise(
      exerciseName,
      strengthProfile ?? definition?.strengthProfile,
    );
    final isBodyweight =
        definition?.usesBodyweight ??
        AppConstants.isBodyweightExercise(exerciseName);
    final isAssisted =
        definition?.usesAssistance ??
        AppConstants.isAssistedBodyweightExercise(exerciseName);
    final bodyweightShare =
        _bodyweightLoadShare[exerciseName] ?? (isBodyweight ? 1.0 : 0.0);

    double totalVolumeKg = 0;
    double weightedIntensitySum = 0;
    int totalReps = 0;

    for (final set in validSets) {
      final reps = _effectiveReps(set);
      final externalLoadKg = math.max(0.0, set.effectiveCalculationLoadKg);
      final loadMode = set.loadInputMode ?? definition?.loadInputMode;
      late final double effectiveLoadKg;
      if (loadMode == ExerciseLoadInputMode.assistanceLoad || isAssisted) {
        effectiveLoadKg = math.max(0.0, bodyWeightKg - externalLoadKg);
      } else if (loadMode == ExerciseLoadInputMode.bodyweightAdded ||
          isBodyweight) {
        effectiveLoadKg = bodyWeightKg * bodyweightShare + externalLoadKg;
      } else {
        effectiveLoadKg = externalLoadKg;
      }
      final volumeKg = effectiveLoadKg * reps;
      if (volumeKg <= 0) {
        continue;
      }

      final setIntensity = _inferSetIntensityFactor(
        reps: reps,
        effectiveLoadKg: effectiveLoadKg,
        bodyWeightKg: bodyWeightKg,
        category: profile.category,
      );

      totalVolumeKg += volumeKg;
      totalReps += reps;
      weightedIntensitySum += volumeKg * setIntensity;
    }

    if (totalVolumeKg <= 0 || totalReps <= 0) {
      return 0;
    }

    final bodyFactor = _clampDouble(math.sqrt(bodyWeightKg / 80), 0.85, 1.15);
    final intensityFactor = _clampDouble(
      weightedIntensitySum / totalVolumeKg,
      0.75,
      1.30,
    );

    final activeLiftingKcal =
        totalVolumeKg *
        profile.strengthCoefficient *
        bodyFactor *
        intensityFactor;
    if (!activeLiftingKcal.isFinite || activeLiftingKcal <= 0) {
      return 0;
    }

    final recoveryDensityModifier = _recoveryDensityModifier(
      totalSessionDurationMinutes: totalSessionDurationMinutes,
      totalReps: totalReps,
      totalSets: validSets.length,
    );
    final postTrainingRecoveryKcal =
        activeLiftingKcal *
        profile.postTrainingRecoveryRate *
        recoveryDensityModifier;
    final muscleRepairAdaptationKcal =
        activeLiftingKcal * profile.muscleRepairAdaptationRate;
    final recoveryExtraKcal =
        postTrainingRecoveryKcal + muscleRepairAdaptationKcal;

    final netStrengthKcal = activeLiftingKcal + recoveryExtraKcal;
    if (!netStrengthKcal.isFinite || netStrengthKcal <= 0) {
      return 0;
    }

    return netStrengthKcal.roundToDouble();
  }

  static _StrengthProfile _profileForExercise(
    String exerciseName,
    String? strengthProfile,
  ) {
    switch (strengthProfile) {
      case ExerciseStrengthProfile.fullBodyPowerOrHighDensity:
        return _fullBodyPowerHighDensityProfile;
      case ExerciseStrengthProfile.lowerBodyCompound:
        return _lowerBodyCompoundProfile;
      case ExerciseStrengthProfile.isolation:
        return _isolationProfile;
      case ExerciseStrengthProfile.upperBodyCompound:
        return _upperBodyCompoundProfile;
    }
    if (_fullBodyPowerHighDensityExercises.contains(exerciseName)) {
      return _fullBodyPowerHighDensityProfile;
    }
    if (_lowerBodyCompoundExercises.contains(exerciseName)) {
      return _lowerBodyCompoundProfile;
    }
    if (_upperBodyCompoundExercises.contains(exerciseName)) {
      return _upperBodyCompoundProfile;
    }
    if (_isolationExercises.contains(exerciseName)) {
      return _isolationProfile;
    }
    return _upperBodyCompoundProfile;
  }

  static int _effectiveReps(WorkoutSet set) {
    final reps = set.effectiveCalculationReps;
    if (reps > 0) {
      return reps;
    }
    final durationSeconds = set.inputDurationSeconds ?? 0;
    if (durationSeconds <= 0) {
      return 0;
    }
    return math.max(1, (durationSeconds / 4).round());
  }

  static double _inferSetIntensityFactor({
    required int reps,
    required double effectiveLoadKg,
    required double bodyWeightKg,
    required _StrengthCategory category,
  }) {
    var factor = 1.0;

    if (reps <= 5) {
      factor += 0.10;
    } else if (reps <= 8) {
      factor += 0.06;
    } else if (reps >= 15) {
      factor -= 0.10;
    } else if (reps >= 12) {
      factor -= 0.05;
    }

    if (bodyWeightKg > 0) {
      final relativeLoad = effectiveLoadKg / bodyWeightKg;
      if (relativeLoad >= 0.9) {
        factor += 0.04;
      } else if (relativeLoad >= 0.6) {
        factor += 0.02;
      }
    }

    if (category == _StrengthCategory.fullBodyPowerOrHighDensity) {
      factor += 0.05;
    }

    if (category == _StrengthCategory.isolation && reps >= 12) {
      factor -= 0.03;
    }

    return _clampDouble(factor, 0.75, 1.30);
  }

  static double _recoveryDensityModifier({
    required int? totalSessionDurationMinutes,
    required int totalReps,
    required int totalSets,
  }) {
    if (totalSessionDurationMinutes == null ||
        totalSessionDurationMinutes <= 0) {
      return 1.0;
    }

    const tempoSeconds = 4.0;
    final activeMinutes = math.max(1.0, totalReps * tempoSeconds / 60);
    final sessionMinutes = math.max(
      activeMinutes,
      totalSessionDurationMinutes.toDouble(),
    );
    final density = totalSets / sessionMinutes;

    // Typical focused strength sessions often sit around 0.18 set/min.
    // We only use density as a small capped modifier on recovery, never
    // as linear duration-based calorie accumulation.
    const baselineDensity = 0.18;
    final densityRatio = density / baselineDensity;
    final modifier = 1.0 + (densityRatio - 1.0) * 0.28;
    return _clampDouble(modifier, 0.85, 1.35);
  }

  static double _clampDouble(double value, double lower, double upper) {
    if (!value.isFinite) {
      return lower;
    }
    return math.max(lower, math.min(upper, value));
  }
}

class _StrengthProfile {
  const _StrengthProfile({
    required this.category,
    required this.strengthCoefficient,
    required this.postTrainingRecoveryRate,
    required this.muscleRepairAdaptationRate,
  });

  final _StrengthCategory category;
  final double strengthCoefficient;
  final double postTrainingRecoveryRate;
  final double muscleRepairAdaptationRate;
}

enum _StrengthCategory {
  upperBodyCompound,
  lowerBodyCompound,
  isolation,
  fullBodyPowerOrHighDensity,
}
