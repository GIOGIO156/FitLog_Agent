import 'exercise_catalog.dart';

class FitLogIconAssets {
  FitLogIconAssets._();

  static const String exerciseDirectory = 'assets/icons/exercises';

  static const String macroProtein = 'assets/icons/macros/protein.png';
  static const String macroCarbs = 'assets/icons/macros/carbs.png';
  static const String macroFat = 'assets/icons/macros/fat.png';

  static const String strategy = 'assets/icons/common/strategy.png';
  static const String food = 'assets/icons/common/food.png';
  static const String workout = 'assets/icons/common/workout.png';
  static const String flame = 'assets/icons/common/flame.svg';

  static const String exerciseBenchPress =
      '$exerciseDirectory/barbell_flat_bench_press.png';
  static const String exerciseCableFly = '$exerciseDirectory/cable_fly.png';
  static const String exerciseDeadlift = '$exerciseDirectory/deadlift.png';
  static const String exerciseDumbbellBicepsCurl =
      '$exerciseDirectory/dumbbell_biceps_curl.png';
  static const String exerciseDumbbellFly =
      '$exerciseDirectory/dumbbell_fly.png';
  static const String exerciseBarbellBicepsCurl =
      '$exerciseDirectory/barbell_biceps_curl.png';
  static const String exerciseBentOverBarbellRow =
      '$exerciseDirectory/bent_over_barbell_row.png';
  static const String exerciseLateralRaise =
      '$exerciseDirectory/lateral_raise.png';
  static const String exerciseLatPulldown =
      '$exerciseDirectory/lat_pulldown.png';
  static const String exerciseOverheadPress =
      '$exerciseDirectory/overhead_press.png';
  static const String exercisePullUp = '$exerciseDirectory/pull_up.png';
  static const String exerciseRunning = '$exerciseDirectory/running.png';
  static const String exerciseSeatedRow = '$exerciseDirectory/seated_row.png';
  static const String exerciseSquat = '$exerciseDirectory/squat.png';

  static const String workoutChest = 'assets/icons/workouts/chest.png';
  static const String workoutBack = 'assets/icons/workouts/back.png';
  static const String workoutLegs = 'assets/icons/workouts/legs.png';
  static const String workoutShoulders = 'assets/icons/workouts/shoulders.png';
  static const String workoutArms = 'assets/icons/workouts/arms.png';
  static const String workoutCore = 'assets/icons/workouts/core.png';
  static const String workoutCardio = 'assets/icons/workouts/cardio.png';
  static const String workoutFullBody = 'assets/icons/workouts/full_body.png';

  static String workoutAssetForBodyPart(String bodyPart) {
    switch (bodyPart) {
      case 'Chest':
        return workoutChest;
      case 'Back':
        return workoutBack;
      case 'Legs':
      case 'Glutes':
        return workoutLegs;
      case 'Shoulders':
        return workoutShoulders;
      case 'Arms':
        return workoutArms;
      case 'Core':
        return workoutCore;
      case 'Cardio':
        return workoutCardio;
      case 'Full Body':
      default:
        return workoutFullBody;
    }
  }

  static String? exerciseAssetForExerciseKey(String? exerciseKey) {
    final definition = ExerciseCatalog.byKey(exerciseKey);
    if (definition == null) {
      return null;
    }
    return _exerciseAssetForCatalogKey(definition.key);
  }

  static String? exerciseAssetForExercise(String exerciseName) {
    final normalized = exerciseName.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final definition = ExerciseCatalog.byName(normalized);
    if (definition != null) {
      return _exerciseAssetForCatalogKey(definition.key);
    }
    final aliasKey = _catalogKeyForReviewedAlias(normalized);
    if (aliasKey != null) {
      return _exerciseAssetForCatalogKey(aliasKey);
    }
    final legacyAliasKey = _legacyExerciseNameAliases[normalized];
    if (legacyAliasKey != null) {
      return _exerciseAssetForCatalogKey(legacyAliasKey);
    }
    final localizedKey = _catalogKeyForLocalizedName(normalized);
    if (localizedKey == null) {
      return null;
    }
    return _exerciseAssetForCatalogKey(localizedKey);
  }

  static String _exerciseAssetForCatalogKey(String exerciseKey) {
    final assetKey = switch (exerciseKey) {
      'barbell_overhead_press' => 'overhead_press',
      _ => exerciseKey,
    };
    return '$exerciseDirectory/$assetKey.png';
  }

  static String? _catalogKeyForReviewedAlias(String exerciseName) {
    for (final entry in ExerciseCatalog.reviewedAliasesByKey.entries) {
      if (entry.value.contains(exerciseName)) {
        return entry.key;
      }
    }
    return null;
  }

  static String? _catalogKeyForLocalizedName(String exerciseName) {
    for (final entry in ExerciseCatalog.localizedNamesZh.entries) {
      if (entry.value != exerciseName) {
        continue;
      }
      final definition = ExerciseCatalog.byName(entry.key);
      if (definition != null) {
        return definition.key;
      }
      final aliasKey = _catalogKeyForReviewedAlias(entry.key);
      if (aliasKey != null) {
        return aliasKey;
      }
    }
    return null;
  }

  static const Map<String, String> _legacyExerciseNameAliases =
      <String, String>{
        '杠铃卧推': 'barbell_flat_bench_press',
        '平板卧推': 'barbell_flat_bench_press',
      };
}
