import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../models/calorie_calibration_state.dart';
import '../models/daily_summary.dart';
import '../models/diet_adjustment_review.dart';
import '../models/training_frequency_self_check_result.dart';
import '../models/user_profile.dart';
import 'diet_plan_strategy_service.dart';
import 'macro_target_calculator.dart';
import 'nutrition_calculator.dart';
import 'training_frequency_self_check_service.dart';

class DailySummaryService {
  DailySummaryService({
    required FoodRepository foodRepository,
    required WorkoutRepository workoutRepository,
    required ProfileRepository profileRepository,
    MacroTargetCalculator? macroTargetCalculator,
    TrainingFrequencySelfCheckService? trainingFrequencySelfCheckService,
    required DietPlanStrategyService dietPlanStrategyService,
  }) : _foodRepository = foodRepository,
       _workoutRepository = workoutRepository,
       _profileRepository = profileRepository,
       _macroTargetCalculator =
           macroTargetCalculator ?? const MacroTargetCalculator(),
       _dietPlanStrategyService = dietPlanStrategyService,
       _trainingFrequencySelfCheckService =
           trainingFrequencySelfCheckService ??
           TrainingFrequencySelfCheckService(
             workoutRepository: workoutRepository,
           );

  final FoodRepository _foodRepository;
  final WorkoutRepository _workoutRepository;
  final ProfileRepository _profileRepository;
  final MacroTargetCalculator _macroTargetCalculator;
  final DietPlanStrategyService _dietPlanStrategyService;
  final TrainingFrequencySelfCheckService _trainingFrequencySelfCheckService;

  static const double _minLifestyleFactor = 1.10;
  static const double _maxLifestyleFactor = 1.70;
  static const double _maxLifestyleUpdateStep = 0.03;
  static const double _newObservedWeight = 0.20;
  static const double _oldFactorWeight = 0.80;
  static const double _kgToKcal = 7700;
  static const int _minCalibrationIntervalDays = 7;
  static const List<int> _windowCandidates = <int>[28, 21, 14, 7];
  static const double _minCalibrationConfidence = 0.35;

  Future<DailySummary> getSummaryForDate(String day) async {
    final profile =
        await _profileRepository.getProfile() ?? UserProfile.defaults;
    final calibration = await _resolveCalibration(profile: profile, day: day);

    final foodRecords = await _foodRepository.getFoodRecordsByDate(day);
    final workoutSessions = await _workoutRepository.getWorkoutSessionsByDate(
      day,
    );

    final caloriesIn = NutritionCalculator.sumCalories(foodRecords);
    final protein = NutritionCalculator.sumProtein(foodRecords);
    final carbs = NutritionCalculator.sumCarbs(foodRecords);
    final fat = NutritionCalculator.sumFat(foodRecords);

    final exerciseCaloriesNet = workoutSessions.fold<double>(
      0,
      (sum, item) => sum + item.estimatedCalories,
    );

    final bmr = calculateBmr(profile);
    final baselineNoExerciseTdee = bmr * calibration.lifestyleFactorUsed;
    final latestPendingDietAdjustmentReview = await _profileRepository
        .getLatestDietAdjustmentReview(
          userDecision: AppConstants.dietAdjustmentDecisionPending,
        );

    final isEnergyTargetMode =
        profile.dietCalculationMode !=
        AppConstants.dietCalculationModeGramPerKg;
    final noExerciseTarget = isEnergyTargetMode
        ? calculateNoExerciseTargetIntake(
            baselineNoExerciseTdee: baselineNoExerciseTdee,
            profile: profile,
          )
        : 0.0;
    final energyModeTargetIntake = resolveEnergyTargetIntake(
      noExerciseTargetIntake: noExerciseTarget,
      loggedNetExerciseKcal: exerciseCaloriesNet,
    );
    final macroTargets = isEnergyTargetMode
        ? _macroTargetCalculator.calculateByEnergyRatio(
            profile: profile,
            targetIntakeKcal: energyModeTargetIntake,
          )
        : _macroTargetCalculator.calculateByGramPerKg(profile: profile);

    final baseTargetIntake = isEnergyTargetMode ? energyModeTargetIntake : 0.0;
    final strategyResult = await _dietPlanStrategyService.apply(
      profile: profile,
      day: day,
      isEnergyTargetMode: isEnergyTargetMode,
      baseProteinG: macroTargets.proteinTargetG,
      baseCarbsG: macroTargets.carbsTargetG,
      baseFatG: macroTargets.fatTargetG,
      latestPendingDietAdjustmentAction: _resolvePendingDietAdjustmentAction(
        latestPendingDietAdjustmentReview: latestPendingDietAdjustmentReview,
        day: day,
        profile: profile,
      ),
    );

    final targetIntake = strategyResult.finalTargetIntakeKcal;
    final remaining = isEnergyTargetMode ? targetIntake - caloriesIn : 0.0;
    final targetProteinG = strategyResult.finalProteinG;
    final targetCarbsG = strategyResult.finalCarbsG;
    final targetFatG = strategyResult.finalFatG;
    final remainingProteinG = targetProteinG - protein;
    final remainingCarbsG = targetCarbsG - carbs;
    final remainingFatG = targetFatG - fat;

    final macroSelfCheck = await _resolveMacroSelfCheck(
      profile: profile,
      day: day,
    );

    return DailySummary(
      date: day,
      caloriesIn: caloriesIn,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
      exerciseCalories: exerciseCaloriesNet,
      bmr: bmr,
      tdeeReference: baselineNoExerciseTdee,
      targetIntake: targetIntake,
      remainingCalories: remaining,
      targetProteinG: targetProteinG,
      targetCarbsG: targetCarbsG,
      targetFatG: targetFatG,
      remainingProteinG: remainingProteinG,
      remainingCarbsG: remainingCarbsG,
      remainingFatG: remainingFatG,
      dietGoalPhase: profile.dietGoalPhase,
      dietCalculationMode: profile.dietCalculationMode,
      dietPlanStrategy: strategyResult.dietPlanStrategy,
      carbDayType: strategyResult.carbDayType,
      isEnergyTargetMode: isEnergyTargetMode,
      baseTargetCalories: baseTargetIntake,
      baseProteinTargetG: macroTargets.proteinTargetG,
      baseCarbsTargetG: macroTargets.carbsTargetG,
      baseFatTargetG: macroTargets.fatTargetG,
      finalTargetCalories: strategyResult.finalTargetIntakeKcal,
      finalProteinTargetG: strategyResult.finalProteinG,
      finalCarbsTargetG: strategyResult.finalCarbsG,
      finalFatTargetG: strategyResult.finalFatG,
      carbAdjustmentG: strategyResult.carbAdjustmentG,
      carbTaperCurrentDeltaG: strategyResult.carbTaperCurrentDeltaG,
      baseMacroEnergyEquivalentKcal: macroTargets.macroEnergyEquivalentKcal,
      finalMacroEnergyEquivalentKcal:
          strategyResult.finalMacroEnergyEquivalentKcal,
      dietStrategyReasonCodes: strategyResult.reasonCodes,
      dietStrategyConfidence: strategyResult.confidence,
      macroEnergyEquivalentKcal: strategyResult.finalMacroEnergyEquivalentKcal,
      lifestyleFactorUsed: calibration.lifestyleFactorUsed,
      exerciseCaloriesNet: exerciseCaloriesNet,
      noExerciseBaselineTdee: baselineNoExerciseTdee,
      noExerciseTargetIntake: noExerciseTarget,
      calibrationConfidence: calibration.confidence,
      calibrationWindowDays: calibration.windowDays,
      calibrationValidDays: calibration.validDays,
      macroSelfCheckCurrentFrequency: macroSelfCheck?.currentTrainingFrequency,
      macroSelfCheckRecommendedFrequency:
          macroSelfCheck?.recommendedTrainingFrequency,
      macroSelfCheckActiveTrainingDays: macroSelfCheck?.activeTrainingDays,
      macroSelfCheckPeriodDays: macroSelfCheck?.periodDays,
      macroSelfCheckAverageWeeklyFrequency:
          macroSelfCheck?.averageWeeklyTrainingFrequency,
      macroSelfCheckShouldSuggest:
          macroSelfCheck?.shouldSuggestAdjustment ?? false,
      macroSelfCheckHasValidTrainingData:
          macroSelfCheck?.hasValidTrainingData ?? false,
      macroSelfCheckBelowRecommendedRange:
          macroSelfCheck?.belowRecommendedRange ?? false,
      calibrationUpdatedToday: calibration.updatedToday,
      hasPendingDietAdjustmentReview: _isPendingReviewRelevant(
        latestPendingDietAdjustmentReview: latestPendingDietAdjustmentReview,
        day: day,
        profile: profile,
      ),
      pendingDietAdjustmentAction:
          latestPendingDietAdjustmentReview?.suggestedAction,
      foodRecords: foodRecords,
      workoutSessions: workoutSessions,
    );
  }

  double calculateBmr(UserProfile profile, {double? weightKgOverride}) {
    final weight = weightKgOverride ?? profile.weightKg;
    final male = 10 * weight + 6.25 * profile.heightCm - 5 * profile.age + 5;
    final female =
        10 * weight + 6.25 * profile.heightCm - 5 * profile.age - 161;

    switch (profile.sexForFormula) {
      case 'male':
        return male;
      case 'female':
        return female;
      case 'prefer_not_to_say':
      default:
        return (male + female) / 2;
    }
  }

  double defaultLifestyleFactorForActivity(String activityLevel) {
    return AppConstants.defaultLifestyleFactorsByActivityLevel[activityLevel] ??
        1.30;
  }

  double defaultLifestyleFactorForTrainingFrequency(int frequencyPerWeek) {
    return AppConstants.defaultLifestyleFactorForTrainingFrequency(
      frequencyPerWeek,
    );
  }

  double calculateNoExerciseTargetIntake({
    required double baselineNoExerciseTdee,
    required UserProfile profile,
  }) {
    return resolveNoExerciseTargetIntake(
      baselineNoExerciseTdee: baselineNoExerciseTdee,
      profile: profile,
    );
  }

  static double resolveNoExerciseTargetIntake({
    required double baselineNoExerciseTdee,
    required UserProfile profile,
  }) {
    if (profile.isMinor &&
        profile.dietGoalPhase == AppConstants.dietGoalPhaseCutting) {
      return baselineNoExerciseTdee;
    }

    switch (profile.dietGoalPhase) {
      case AppConstants.dietGoalPhaseBulking:
        return baselineNoExerciseTdee + profile.dailyEnergyGoalKcal;
      case AppConstants.dietGoalPhaseCutting:
      default:
        return baselineNoExerciseTdee - profile.dailyEnergyGoalKcal;
    }
  }

  static double resolveEnergyTargetIntake({
    required double noExerciseTargetIntake,
    required double loggedNetExerciseKcal,
  }) {
    return noExerciseTargetIntake + loggedNetExerciseKcal;
  }

  Future<_CalibrationRuntime> _resolveCalibration({
    required UserProfile profile,
    required String day,
  }) async {
    final defaultFactor = _clampDouble(
      defaultLifestyleFactorForTrainingFrequency(
        profile.trainingFrequencyPerWeek,
      ),
      _minLifestyleFactor,
      _maxLifestyleFactor,
    );
    final existingState = await _profileRepository.getCalorieCalibrationState();
    final currentState =
        existingState ??
        CalorieCalibrationState(
          lifestyleFactor: defaultFactor,
          confidence: 0,
          windowDays: 0,
          validDays: 0,
        );

    if (!_shouldTryCalibration(currentState, day: day)) {
      return _CalibrationRuntime(
        lifestyleFactorUsed: _clampDouble(
          currentState.lifestyleFactor,
          _minLifestyleFactor,
          _maxLifestyleFactor,
        ),
        confidence: currentState.confidence,
        windowDays: currentState.windowDays,
        validDays: currentState.validDays,
        updatedToday: false,
      );
    }

    final sample = await _buildCalibrationSample(profile: profile, day: day);
    if (sample == null || sample.confidence < _minCalibrationConfidence) {
      return _CalibrationRuntime(
        lifestyleFactorUsed: _clampDouble(
          currentState.lifestyleFactor,
          _minLifestyleFactor,
          _maxLifestyleFactor,
        ),
        confidence: currentState.confidence,
        windowDays: currentState.windowDays,
        validDays: currentState.validDays,
        updatedToday: false,
      );
    }

    final blended =
        currentState.lifestyleFactor * _oldFactorWeight +
        sample.observedLifestyleFactor * _newObservedWeight;
    final boundedStep = _clampDouble(
      blended - currentState.lifestyleFactor,
      -_maxLifestyleUpdateStep,
      _maxLifestyleUpdateStep,
    );
    final updatedFactor = _clampDouble(
      currentState.lifestyleFactor + boundedStep,
      _minLifestyleFactor,
      _maxLifestyleFactor,
    );

    final updatedState = currentState.copyWith(
      lifestyleFactor: updatedFactor,
      confidence: sample.confidence,
      windowDays: sample.windowDays,
      validDays: sample.validDays,
      lastCalibratedDate: day,
    );
    await _profileRepository.saveCalorieCalibrationState(updatedState);

    return _CalibrationRuntime(
      lifestyleFactorUsed: updatedFactor,
      confidence: sample.confidence,
      windowDays: sample.windowDays,
      validDays: sample.validDays,
      updatedToday: true,
    );
  }

  bool _shouldTryCalibration(
    CalorieCalibrationState state, {
    required String day,
  }) {
    final last = state.lastCalibratedDate;
    if (last == null || last.isEmpty) {
      return true;
    }

    final lastDate = DateUtilsX.parseDay(last);
    final nowDate = DateUtilsX.parseDay(day);
    final diff = nowDate.difference(lastDate).inDays;
    return diff >= _minCalibrationIntervalDays;
  }

  Future<_CalibrationSample?> _buildCalibrationSample({
    required UserProfile profile,
    required String day,
  }) async {
    final endDate = DateUtilsX.parseDay(day);

    for (final windowDays in _windowCandidates) {
      final startDate = endDate.subtract(Duration(days: windowDays - 1));
      final startKey = DateUtilsX.formatDate(startDate);
      final endKey = DateUtilsX.formatDate(endDate);

      final weightLogs = await _profileRepository.getWeightLogsBetween(
        startDate: startKey,
        endDate: endKey,
      );
      if (weightLogs.length < 7) {
        continue;
      }

      final firstWindowEnd = startDate.add(const Duration(days: 6));
      final lastWindowStart = endDate.subtract(const Duration(days: 6));

      final firstWindowWeights = weightLogs
          .where((log) {
            final day = DateUtilsX.parseDay(log.date);
            return !day.isBefore(startDate) && !day.isAfter(firstWindowEnd);
          })
          .map((log) => log.weightKg)
          .toList();
      final lastWindowWeights = weightLogs
          .where((log) {
            final day = DateUtilsX.parseDay(log.date);
            return !day.isBefore(lastWindowStart) && !day.isAfter(endDate);
          })
          .map((log) => log.weightKg)
          .toList();

      if (firstWindowWeights.length < 3 || lastWindowWeights.length < 3) {
        continue;
      }

      final dailyCalories = await _foodRepository.getDailyCaloriesBetween(
        startDate: startKey,
        endDate: endKey,
      );
      final requiredFoodDays = windowDays >= 14
          ? (windowDays * 0.75).ceil()
          : 6;
      if (dailyCalories.length < math.max(7, requiredFoodDays)) {
        continue;
      }

      final dailyExercise = await _workoutRepository
          .getDailyExerciseCaloriesBetween(
            startDate: startKey,
            endDate: endKey,
          );

      final validDays = dailyCalories.keys.toList()..sort();
      final totalIntake = validDays.fold<double>(
        0,
        (sum, date) => sum + (dailyCalories[date] ?? 0),
      );
      final totalExercise = validDays.fold<double>(
        0,
        (sum, date) => sum + (dailyExercise[date] ?? 0),
      );

      final averageDailyIntake = totalIntake / validDays.length;
      final averageDailyExercise = totalExercise / validDays.length;

      final startWeight = _average(firstWindowWeights);
      final endWeight = _average(lastWindowWeights);
      final weightChangeKg = endWeight - startWeight;

      final observedTotalTdee =
          averageDailyIntake - (weightChangeKg * _kgToKcal / windowDays);
      final observedNoExerciseTdee = observedTotalTdee - averageDailyExercise;

      final averageBmr = _average(
        weightLogs
            .map((log) => calculateBmr(profile, weightKgOverride: log.weightKg))
            .toList(),
      );
      if (averageBmr <= 0) {
        continue;
      }

      final observedLifestyleFactor = observedNoExerciseTdee / averageBmr;
      if (!observedLifestyleFactor.isFinite || observedLifestyleFactor <= 0) {
        continue;
      }

      final foodCoverage = validDays.length / windowDays;
      final weightCoverage = _clampDouble(weightLogs.length / windowDays, 0, 1);
      final windowScore = windowDays >= 21
          ? 1.0
          : (windowDays >= 14 ? 0.85 : 0.7);
      final confidence = _clampDouble(
        foodCoverage * 0.5 + weightCoverage * 0.3 + windowScore * 0.2,
        0,
        1,
      );

      return _CalibrationSample(
        observedLifestyleFactor: observedLifestyleFactor,
        confidence: confidence,
        windowDays: windowDays,
        validDays: validDays.length,
      );
    }

    return null;
  }

  Future<TrainingFrequencySelfCheckResult?> _resolveMacroSelfCheck({
    required UserProfile profile,
    required String day,
  }) async {
    return _trainingFrequencySelfCheckService.evaluate(
      profile: profile,
      referenceDay: day,
      respectReminderCooldown: true,
    );
  }

  double _average(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _clampDouble(double value, double lower, double upper) {
    if (!value.isFinite) {
      return lower;
    }
    return math.max(lower, math.min(upper, value));
  }

  String? _resolvePendingDietAdjustmentAction({
    required DietAdjustmentReview? latestPendingDietAdjustmentReview,
    required String day,
    required UserProfile profile,
  }) {
    if (!_isPendingReviewRelevant(
      latestPendingDietAdjustmentReview: latestPendingDietAdjustmentReview,
      day: day,
      profile: profile,
    )) {
      return null;
    }
    return latestPendingDietAdjustmentReview?.suggestedAction;
  }

  bool _isPendingReviewRelevant({
    required DietAdjustmentReview? latestPendingDietAdjustmentReview,
    required String day,
    required UserProfile profile,
  }) {
    if (latestPendingDietAdjustmentReview == null) {
      return false;
    }
    if (profile.dietPlanStrategy != AppConstants.dietPlanStrategyCarbTapering) {
      return false;
    }
    if (latestPendingDietAdjustmentReview.userDecision !=
        AppConstants.dietAdjustmentDecisionPending) {
      return false;
    }
    return latestPendingDietAdjustmentReview.reviewDate == day;
  }
}

class _CalibrationRuntime {
  const _CalibrationRuntime({
    required this.lifestyleFactorUsed,
    required this.confidence,
    required this.windowDays,
    required this.validDays,
    required this.updatedToday,
  });

  final double lifestyleFactorUsed;
  final double confidence;
  final int windowDays;
  final int validDays;
  final bool updatedToday;
}

class _CalibrationSample {
  const _CalibrationSample({
    required this.observedLifestyleFactor,
    required this.confidence,
    required this.windowDays,
    required this.validDays,
  });

  final double observedLifestyleFactor;
  final double confidence;
  final int windowDays;
  final int validDays;
}
