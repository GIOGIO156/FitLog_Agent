import 'dart:math' as math;

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../data/repositories/food_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../models/carb_taper_review_result.dart';
import '../models/user_profile.dart';
import '../models/workout_session.dart';

class CarbTaperReviewService {
  const CarbTaperReviewService({
    required FoodRepository foodRepository,
    required WorkoutRepository workoutRepository,
    required ProfileRepository profileRepository,
  }) : _foodRepository = foodRepository,
       _workoutRepository = workoutRepository,
       _profileRepository = profileRepository;

  final FoodRepository _foodRepository;
  final WorkoutRepository _workoutRepository;
  final ProfileRepository _profileRepository;

  Future<CarbTaperReviewResult> evaluate({
    required UserProfile profile,
    required String referenceDay,
    String? latestPendingReviewDate,
    double? baseCarbsGOverride,
    bool respectCooldown = true,
  }) async {
    final windowDays = AppConstants.resolveCarbTaperReviewPeriodDays(
      profile.carbTaperReviewPeriodDays,
    );
    final isApplicable =
        !profile.isMinor &&
        profile.dietGoalPhase == AppConstants.dietGoalPhaseCutting &&
        profile.dietPlanStrategy == AppConstants.dietPlanStrategyCarbTapering;
    final cooldownBlocked =
        respectCooldown &&
        !_isReviewDue(
          referenceDay: referenceDay,
          lastReviewAt: profile.lastCarbTaperReviewAt,
          latestPendingReviewDate: latestPendingReviewDate,
          windowDays: windowDays,
        );

    if (!isApplicable) {
      return CarbTaperReviewResult(
        isApplicable: false,
        isReviewDue: false,
        windowDays: windowDays,
        currentCarbDeltaG: profile.carbTaperCurrentDeltaG,
        suggestedAction: AppConstants.dietAdjustmentActionKeep,
        suggestedCarbDeltaG: 0,
        projectedCarbDeltaAfterG: profile.carbTaperCurrentDeltaG,
        foodLogCoverage: 0,
        activeTrainingDays: 0,
        confidence: 0,
        reasonCodes: <String>[
          if (profile.isMinor) 'minor_cutting_strategy_blocked',
          if (profile.dietGoalPhase != AppConstants.dietGoalPhaseCutting)
            'unsupported_goal_phase',
        ],
      );
    }

    if (cooldownBlocked) {
      return CarbTaperReviewResult(
        isApplicable: true,
        isReviewDue: false,
        windowDays: windowDays,
        currentCarbDeltaG: profile.carbTaperCurrentDeltaG,
        suggestedAction: AppConstants.dietAdjustmentActionKeep,
        suggestedCarbDeltaG: 0,
        projectedCarbDeltaAfterG: profile.carbTaperCurrentDeltaG,
        foodLogCoverage: 0,
        activeTrainingDays: 0,
        confidence: 0,
        reasonCodes: const <String>['review_cooldown_active'],
      );
    }

    final end = DateUtilsX.parseDay(referenceDay);
    final start = end.subtract(Duration(days: windowDays - 1));
    final startKey = DateUtilsX.formatDate(start);
    final endKey = DateUtilsX.formatDate(end);

    final weightLogs = await _profileRepository.getWeightLogsBetween(
      startDate: startKey,
      endDate: endKey,
    );
    final dailyCalories = await _foodRepository.getDailyCaloriesBetween(
      startDate: startKey,
      endDate: endKey,
    );
    final sessions = await _workoutRepository.getWorkoutSessionsBetween(
      startDate: startKey,
      endDate: endKey,
    );
    final foodCoverage = dailyCalories.length / windowDays;
    final activeTrainingDays = _countActiveTrainingDays(sessions);
    final reasonCodes = <String>[];

    if (weightLogs.length < 7) {
      reasonCodes.add('insufficient_weight_logs');
    }
    if (foodCoverage < 0.70) {
      reasonCodes.add('insufficient_food_coverage');
    }

    final firstWindowEnd = start.add(const Duration(days: 6));
    final lastWindowStart = end.subtract(const Duration(days: 6));
    final startWeights = weightLogs
        .where((log) {
          final day = DateUtilsX.parseDay(log.date);
          return !day.isBefore(start) && !day.isAfter(firstWindowEnd);
        })
        .map((log) => log.weightKg)
        .toList();
    final endWeights = weightLogs
        .where((log) {
          final day = DateUtilsX.parseDay(log.date);
          return !day.isBefore(lastWindowStart) && !day.isAfter(end);
        })
        .map((log) => log.weightKg)
        .toList();
    if (startWeights.length < 3 || endWeights.length < 3) {
      reasonCodes.add('missing_weight_window_segment');
    }

    if (reasonCodes.isNotEmpty) {
      return CarbTaperReviewResult(
        isApplicable: true,
        isReviewDue: true,
        windowDays: windowDays,
        currentCarbDeltaG: profile.carbTaperCurrentDeltaG,
        suggestedAction: AppConstants.dietAdjustmentActionNoData,
        suggestedCarbDeltaG: 0,
        projectedCarbDeltaAfterG: profile.carbTaperCurrentDeltaG,
        foodLogCoverage: foodCoverage,
        activeTrainingDays: activeTrainingDays,
        confidence: 0,
        reasonCodes: reasonCodes,
      );
    }

    final startAvgWeightKg = _average(startWeights);
    final endAvgWeightKg = _average(endWeights);
    final weightChangeKg = endAvgWeightKg - startAvgWeightKg;
    final lossRatePctPerWeek =
        (-weightChangeKg / startAvgWeightKg) * 100 * 7 / windowDays;
    final targetLoss = profile.carbTaperTargetLossPctPerWeek;
    final trainingDropDetected = await _detectTrainingDrop(
      currentWindowStart: start,
      currentWindowEnd: end,
      currentActiveTrainingDays: activeTrainingDays,
      windowDays: windowDays,
    );
    if (trainingDropDetected) {
      reasonCodes.add('training_drop_detected');
    }

    final baseCarbsG = baseCarbsGOverride ?? 0;
    final minCarbsG = _minimumCarbsG(profile.weightKg);
    final maxStepG = math.min(20, profile.weightKg * 0.25);
    final requestedStepG = math
        .min(profile.carbTaperStepG, maxStepG)
        .toDouble();
    var suggestedAction = AppConstants.dietAdjustmentActionKeep;
    var suggestedCarbDeltaG = 0.0;

    if (trainingDropDetected) {
      suggestedAction = AppConstants.dietAdjustmentActionKeep;
    } else if (lossRatePctPerWeek <
        targetLoss - AppConstants.carbTaperTolerancePctPoints) {
      suggestedAction = AppConstants.dietAdjustmentActionDecreaseCarbs;
      suggestedCarbDeltaG = -requestedStepG;
      final projectedCarbs =
          baseCarbsG + profile.carbTaperCurrentDeltaG + suggestedCarbDeltaG;
      if (baseCarbsG > 0 && projectedCarbs < minCarbsG) {
        suggestedAction = AppConstants.dietAdjustmentActionBlockedBySafetyFloor;
        suggestedCarbDeltaG = 0;
        reasonCodes.add('carb_floor_applied');
      }
    } else if (lossRatePctPerWeek >
        targetLoss + AppConstants.carbTaperTolerancePctPoints) {
      suggestedAction = AppConstants.dietAdjustmentActionPauseTaper;
    }

    final confidence = _clampDouble(
      foodCoverage * 0.45 +
          _clampDouble(weightLogs.length / windowDays, 0, 1) * 0.35 +
          (trainingDropDetected ? 0.05 : 0.20),
      0,
      1,
    );

    return CarbTaperReviewResult(
      isApplicable: true,
      isReviewDue: true,
      windowDays: windowDays,
      currentCarbDeltaG: profile.carbTaperCurrentDeltaG,
      suggestedAction: suggestedAction,
      suggestedCarbDeltaG: suggestedCarbDeltaG,
      projectedCarbDeltaAfterG:
          profile.carbTaperCurrentDeltaG + suggestedCarbDeltaG,
      foodLogCoverage: foodCoverage,
      activeTrainingDays: activeTrainingDays,
      confidence: confidence,
      startAvgWeightKg: startAvgWeightKg,
      endAvgWeightKg: endAvgWeightKg,
      weightChangeKg: weightChangeKg,
      lossRatePctPerWeek: lossRatePctPerWeek,
      targetLossPctPerWeek: targetLoss,
      trainingDropDetected: trainingDropDetected,
      reasonCodes: reasonCodes,
    );
  }

  bool isValidWorkoutDay(List<WorkoutSession> sessions) {
    if (sessions.isEmpty) {
      return false;
    }
    if (sessions.any((session) => session.exerciseType == 'strength')) {
      return true;
    }
    final cardioMinutes = sessions
        .where((session) => session.exerciseType == 'cardio')
        .fold<int>(0, (sum, session) => sum + session.durationMinutes);
    if (cardioMinutes >= AppConstants.validWorkoutCardioMinutesThreshold) {
      return true;
    }
    final exerciseCalories = sessions.fold<double>(
      0,
      (sum, session) => sum + session.estimatedCalories,
    );
    return exerciseCalories >= AppConstants.validWorkoutCaloriesThreshold;
  }

  int countActiveTrainingDays(List<WorkoutSession> sessions) =>
      _countActiveTrainingDays(sessions);

  double minimumCarbsGForWeight(double weightKg) => _minimumCarbsG(weightKg);

  Future<bool> _detectTrainingDrop({
    required DateTime currentWindowStart,
    required DateTime currentWindowEnd,
    required int currentActiveTrainingDays,
    required int windowDays,
  }) async {
    final previousWindowEnd = currentWindowStart.subtract(
      const Duration(days: 1),
    );
    final previousWindowStart = previousWindowEnd.subtract(
      Duration(days: windowDays - 1),
    );
    final previousSessions = await _workoutRepository.getWorkoutSessionsBetween(
      startDate: DateUtilsX.formatDate(previousWindowStart),
      endDate: DateUtilsX.formatDate(previousWindowEnd),
    );
    if (previousSessions.isEmpty) {
      return false;
    }
    final previousActiveTrainingDays = _countActiveTrainingDays(
      previousSessions,
    );
    return previousActiveTrainingDays >= 2 &&
        currentActiveTrainingDays + 2 <= previousActiveTrainingDays;
  }

  bool _isReviewDue({
    required String referenceDay,
    required String? lastReviewAt,
    required String? latestPendingReviewDate,
    required int windowDays,
  }) {
    final blocker = latestPendingReviewDate ?? lastReviewAt;
    if (blocker == null || blocker.trim().isEmpty) {
      return true;
    }
    final parsed = DateTime.tryParse(blocker);
    if (parsed == null) {
      return true;
    }
    final diff = DateUtilsX.parseDay(
      referenceDay,
    ).difference(DateUtilsX.parseDay(DateUtilsX.formatDate(parsed))).inDays;
    return diff >= windowDays;
  }

  int _countActiveTrainingDays(List<WorkoutSession> sessions) {
    final sessionsByDate = <String, List<WorkoutSession>>{};
    for (final session in sessions) {
      sessionsByDate.putIfAbsent(session.date, () => <WorkoutSession>[]);
      sessionsByDate[session.date]!.add(session);
    }
    return sessionsByDate.values.where(isValidWorkoutDay).length;
  }

  double _average(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _minimumCarbsG(double weightKg) {
    final byWeight = weightKg * AppConstants.carbSafetyFloorPerKg;
    return byWeight > AppConstants.carbSafetyFloorMinimumG
        ? byWeight
        : AppConstants.carbSafetyFloorMinimumG;
  }

  double _clampDouble(double value, double lower, double upper) {
    if (!value.isFinite) {
      return lower;
    }
    return math.max(lower, math.min(upper, value));
  }
}
