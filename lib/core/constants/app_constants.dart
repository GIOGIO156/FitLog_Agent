import 'exercise_catalog.dart';

class AppConstants {
  AppConstants._();

  static const String mondayKey = 'mon';
  static const String tuesdayKey = 'tue';
  static const String wednesdayKey = 'wed';
  static const String thursdayKey = 'thu';
  static const String fridayKey = 'fri';
  static const String saturdayKey = 'sat';
  static const String sundayKey = 'sun';
  static const List<String> carbCycleWeekdayKeys = <String>[
    mondayKey,
    tuesdayKey,
    wednesdayKey,
    thursdayKey,
    fridayKey,
    saturdayKey,
    sundayKey,
  ];

  static const String sourceAiPaste = 'ai_paste';
  static const String sourceAiPhoto = 'ai_photo';
  static const String sourceManual = 'manual';

  static final List<String> bodyParts = ExerciseCatalog.bodyParts;

  static final Map<String, List<String>> bodyPartExercises =
      ExerciseCatalog.bodyPartExercises;

  static const Set<String> bodyweightExercises = <String>{
    'Pull-up',
    'Assisted Pull-up',
    'Push-up',
    'Kneeling Push-up',
    'Dip',
    'Assisted Dip',
    'Plank',
    'Crunch',
    'Hanging Leg Raise',
    'Burpee',
    'Jumping Jack',
  };

  static const Set<String> assistedBodyweightExercises = <String>{
    'Assisted Pull-up',
    'Assisted Dip',
  };

  static bool isBodyweightExercise(String exerciseName) {
    return bodyweightExercises.contains(exerciseName) ||
        ExerciseCatalog.isBodyweightExercise(exerciseName);
  }

  static bool isAssistedBodyweightExercise(String exerciseName) {
    return assistedBodyweightExercises.contains(exerciseName) ||
        ExerciseCatalog.isAssistedBodyweightExercise(exerciseName);
  }

  static const List<String> intensityLevels = <String>['low', 'medium', 'high'];

  static const List<String> sexOptions = <String>[
    'male',
    'female',
    'prefer_not_to_say',
  ];

  static const List<String> activityLevels = <String>[
    'sedentary',
    'lightly_active',
    'moderately_active',
    'very_active',
  ];

  static const List<String> dailyEnergyGoalTypes = <String>[
    'maintenance',
    'deficit',
    'surplus',
  ];

  static const String dietGoalPhaseCutting = 'cutting';
  static const String dietGoalPhaseBulking = 'bulking';
  static const List<String> dietGoalPhases = <String>[
    dietGoalPhaseCutting,
    dietGoalPhaseBulking,
  ];

  static const String dietCalculationModeEnergyRatio = 'energy_ratio';
  static const String dietCalculationModeGramPerKg = 'gram_per_kg';
  static const List<String> dietCalculationModes = <String>[
    dietCalculationModeEnergyRatio,
    dietCalculationModeGramPerKg,
  ];

  static const String dietPlanStrategyNone = 'none';
  static const String dietPlanStrategyCarbCycling = 'carb_cycling';
  static const String dietPlanStrategyCarbTapering = 'carb_tapering';
  static const List<String> dietPlanStrategies = <String>[
    dietPlanStrategyNone,
    dietPlanStrategyCarbCycling,
    dietPlanStrategyCarbTapering,
  ];

  static const String carbDayHigh = 'high';
  static const String carbDayMedium = 'medium';
  static const String carbDayLow = 'low';
  static const List<String> carbDayTypes = <String>[
    carbDayHigh,
    carbDayMedium,
    carbDayLow,
  ];

  static const String dietAdjustmentDecisionPending = 'pending';
  static const String dietAdjustmentDecisionAccepted = 'accepted';
  static const String dietAdjustmentDecisionDismissed = 'dismissed';
  static const String dietAdjustmentDecisionExpired = 'expired';
  static const List<String> dietAdjustmentDecisions = <String>[
    dietAdjustmentDecisionPending,
    dietAdjustmentDecisionAccepted,
    dietAdjustmentDecisionDismissed,
    dietAdjustmentDecisionExpired,
  ];

  static const String dietAdjustmentActionNoData = 'no_data';
  static const String dietAdjustmentActionKeep = 'keep';
  static const String dietAdjustmentActionDecreaseCarbs = 'decrease_carbs';
  static const String dietAdjustmentActionPauseTaper = 'pause_taper';
  static const String dietAdjustmentActionIncreaseCarbsSmall =
      'increase_carbs_small';
  static const String dietAdjustmentActionBlockedBySafetyFloor =
      'blocked_by_safety_floor';
  static const List<String> dietAdjustmentActions = <String>[
    dietAdjustmentActionNoData,
    dietAdjustmentActionKeep,
    dietAdjustmentActionDecreaseCarbs,
    dietAdjustmentActionPauseTaper,
    dietAdjustmentActionIncreaseCarbsSmall,
    dietAdjustmentActionBlockedBySafetyFloor,
  ];

  static const int defaultTrainingFrequencyPerWeek = 3;
  static const List<int> trainingFrequencyPerWeekOptions = <int>[2, 3, 4, 5];
  static const int defaultMacroSelfCheckPeriodDays = 14;
  static const List<int> macroSelfCheckPeriodDayOptions = <int>[7, 14, 21, 28];
  static const int macroSelfCheckReminderCooldownDays = 7;
  static const int validWorkoutCardioMinutesThreshold = 20;
  static const double validWorkoutCaloriesThreshold = 80;

  static const double defaultProteinRatioPercent = 30;
  static const double defaultCarbsRatioPercent = 40;
  static const double defaultFatRatioPercent = 30;

  static const String defaultDietPlanStrategy = dietPlanStrategyNone;
  static const double defaultCarbCycleHighMultiplier = 1.20;
  static const double defaultCarbCycleMediumMultiplier = 1.00;
  static const double defaultCarbCycleLowMultiplier = 0.80;
  static const int defaultCarbTaperReviewPeriodDays = 14;
  static const List<int> carbTaperReviewPeriodDayOptions = <int>[14, 21, 28, 7];
  static const double defaultCarbTaperTargetLossPctPerWeek = 0.50;
  static const double minCarbTaperTargetLossPctPerWeek = 0.25;
  static const double maxCarbTaperTargetLossPctPerWeek = 1.00;
  static const double defaultCarbTaperStepG = 10.0;
  static const List<double> carbTaperStepOptionsG = <double>[5, 10, 15, 20];
  static const double defaultCarbTaperCurrentDeltaG = 0.0;
  static const double carbTaperTolerancePctPoints = 0.20;
  static const double carbSafetyFloorPerKg = 1.2;
  static const double carbSafetyFloorMinimumG = 100;

  static const double bulkingProteinRatioPercent = 25;
  static const double bulkingCarbsRatioPercent = 50;
  static const double bulkingFatRatioPercent = 25;

  static const Map<String, double> defaultLifestyleFactorsByActivityLevel =
      <String, double>{
        'sedentary': 1.20,
        'lightly_active': 1.30,
        'moderately_active': 1.425,
        'very_active': 1.60,
      };

  static String resolveDietGoalPhase(String? value) {
    if (dietGoalPhases.contains(value)) {
      return value!;
    }
    return dietGoalPhaseCutting;
  }

  static String resolveDietCalculationMode(String? value) {
    if (dietCalculationModes.contains(value)) {
      return value!;
    }
    return dietCalculationModeEnergyRatio;
  }

  static String resolveDietPlanStrategy(String? value) {
    if (dietPlanStrategies.contains(value)) {
      return value!;
    }
    return dietPlanStrategyNone;
  }

  static String resolveActivityLevel(String? value) {
    if (activityLevels.contains(value)) {
      return value!;
    }
    return activityLevelForTrainingFrequency(defaultTrainingFrequencyPerWeek);
  }

  static String resolveCarbDayType(String? value) {
    if (carbDayTypes.contains(value)) {
      return value!;
    }
    return carbDayMedium;
  }

  static int resolveTrainingFrequencyPerWeek(int? value) {
    if (trainingFrequencyPerWeekOptions.contains(value)) {
      return value!;
    }
    return defaultTrainingFrequencyPerWeek;
  }

  static String activityLevelForTrainingFrequency(int? value) {
    switch (resolveTrainingFrequencyPerWeek(value)) {
      case 2:
        return 'sedentary';
      case 4:
        return 'moderately_active';
      case 5:
        return 'very_active';
      case 3:
      default:
        return 'lightly_active';
    }
  }

  static double defaultLifestyleFactorForTrainingFrequency(int? value) {
    final activityLevel = activityLevelForTrainingFrequency(value);
    return defaultLifestyleFactorsByActivityLevel[activityLevel] ?? 1.30;
  }

  static int resolveMacroSelfCheckPeriodDays(int? value) {
    if (macroSelfCheckPeriodDayOptions.contains(value)) {
      return value!;
    }
    return defaultMacroSelfCheckPeriodDays;
  }

  static int resolveCarbTaperReviewPeriodDays(int? value) {
    if (carbTaperReviewPeriodDayOptions.contains(value)) {
      return value!;
    }
    return defaultCarbTaperReviewPeriodDays;
  }

  static double resolveCarbTaperTargetLossPctPerWeek(double? value) {
    if (value == null || !value.isFinite) {
      return defaultCarbTaperTargetLossPctPerWeek;
    }
    if (value < minCarbTaperTargetLossPctPerWeek) {
      return minCarbTaperTargetLossPctPerWeek;
    }
    if (value > maxCarbTaperTargetLossPctPerWeek) {
      return maxCarbTaperTargetLossPctPerWeek;
    }
    return value;
  }

  static double resolveCarbTaperStepG(double? value) {
    if (value == null || !value.isFinite || value <= 0) {
      return defaultCarbTaperStepG;
    }
    return value;
  }

  static Map<String, String> defaultCarbCyclePattern() {
    return <String, String>{
      for (final key in carbCycleWeekdayKeys) key: carbDayMedium,
    };
  }

  static String weekdayKeyFromDateTime(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return mondayKey;
      case DateTime.tuesday:
        return tuesdayKey;
      case DateTime.wednesday:
        return wednesdayKey;
      case DateTime.thursday:
        return thursdayKey;
      case DateTime.friday:
        return fridayKey;
      case DateTime.saturday:
        return saturdayKey;
      case DateTime.sunday:
      default:
        return sundayKey;
    }
  }
}
