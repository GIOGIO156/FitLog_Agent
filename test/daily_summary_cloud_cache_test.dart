import 'package:fitlog_local/core/constants/app_constants.dart';
import 'package:fitlog_local/data/db/app_database.dart';
import 'package:fitlog_local/data/repositories/daily_summary_cloud_repository.dart';
import 'package:fitlog_local/data/repositories/food_repository.dart';
import 'package:fitlog_local/data/repositories/profile_repository.dart';
import 'package:fitlog_local/data/repositories/workout_repository.dart';
import 'package:fitlog_local/domain/models/calorie_calibration_state.dart';
import 'package:fitlog_local/domain/models/daily_summary.dart';
import 'package:fitlog_local/domain/models/diet_adjustment_review.dart';
import 'package:fitlog_local/domain/models/food_record.dart';
import 'package:fitlog_local/domain/models/user_profile.dart';
import 'package:fitlog_local/domain/models/weight_log.dart';
import 'package:fitlog_local/domain/models/workout_session.dart';
import 'package:fitlog_local/domain/services/carb_taper_review_service.dart';
import 'package:fitlog_local/domain/services/daily_summary_service.dart';
import 'package:fitlog_local/domain/services/diet_plan_strategy_service.dart';
import 'package:fitlog_local/domain/services/training_frequency_self_check_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cached summary falls back to cloud read model', () async {
    final cloud = _FakeDailySummaryCloudRepository()
      ..summary = _summary(date: '2026-06-27', caloriesIn: 123);
    final service = _dailySummaryService(cloud: cloud);

    final summary = await service.getCachedSummaryForDate(
      accountId: 'account-a',
      day: '2026-06-27',
    );

    expect(summary?.caloriesIn, 123);
    expect(cloud.fetchCount, 1);
  });

  test(
    'computed summary upserts cloud read model without local cache',
    () async {
      final cloud = _FakeDailySummaryCloudRepository();
      final service = _dailySummaryService(cloud: cloud);

      final summary = await service.getSummaryForDateAndCache(
        day: '2026-06-27',
        accountId: 'account-a',
      );

      expect(summary.date, '2026-06-27');
      expect(cloud.upsertedSummary?.date, '2026-06-27');
      expect(cloud.upsertCount, 1);
    },
  );
}

DailySummaryService _dailySummaryService({
  required DailySummaryCloudRepository cloud,
}) {
  final database = AppDatabase.instance;
  final foodRepository = _FakeFoodRepository(database);
  final workoutRepository = _FakeWorkoutRepository(database);
  final profileRepository = _FakeProfileRepository(database);
  final carbTaperReviewService = CarbTaperReviewService(
    foodRepository: foodRepository,
    workoutRepository: workoutRepository,
    profileRepository: profileRepository,
  );

  return DailySummaryService(
    foodRepository: foodRepository,
    workoutRepository: workoutRepository,
    profileRepository: profileRepository,
    trainingFrequencySelfCheckService: TrainingFrequencySelfCheckService(
      workoutRepository: workoutRepository,
    ),
    dietPlanStrategyService: DietPlanStrategyService(
      carbTaperReviewService: carbTaperReviewService,
    ),
    dailySummaryCloudRepository: cloud,
  );
}

DailySummary _summary({required String date, double caloriesIn = 0}) {
  return DailySummary(
    date: date,
    caloriesIn: caloriesIn,
    proteinG: 0,
    carbsG: 0,
    fatG: 0,
    exerciseCalories: 0,
    bmr: 1500,
    tdeeReference: 1950,
    targetIntake: 1650,
    remainingCalories: 1650 - caloriesIn,
    targetProteinG: 120,
    targetCarbsG: 180,
    targetFatG: 50,
    remainingProteinG: 120,
    remainingCarbsG: 180,
    remainingFatG: 50,
    dietGoalPhase: AppConstants.dietGoalPhaseCutting,
    dietCalculationMode: AppConstants.dietCalculationModeEnergyRatio,
    dietPlanStrategy: AppConstants.defaultDietPlanStrategy,
    isEnergyTargetMode: true,
    baseTargetCalories: 1650,
    baseProteinTargetG: 120,
    baseCarbsTargetG: 180,
    baseFatTargetG: 50,
    finalTargetCalories: 1650,
    finalProteinTargetG: 120,
    finalCarbsTargetG: 180,
    finalFatTargetG: 50,
    carbAdjustmentG: 0,
    carbTaperCurrentDeltaG: 0,
    baseMacroEnergyEquivalentKcal: 1650,
    finalMacroEnergyEquivalentKcal: 1650,
    dietStrategyReasonCodes: const <String>[],
    dietStrategyConfidence: 1,
    macroEnergyEquivalentKcal: 1650,
    lifestyleFactorUsed: 1.3,
    exerciseCaloriesNet: 0,
    noExerciseBaselineTdee: 1950,
    noExerciseTargetIntake: 1650,
    calibrationConfidence: 0,
    calibrationWindowDays: 0,
    calibrationValidDays: 0,
  );
}

class _FakeDailySummaryCloudRepository extends DailySummaryCloudRepository {
  DailySummary? summary;
  DailySummary? upsertedSummary;
  int fetchCount = 0;
  int upsertCount = 0;

  @override
  Future<DailySummary?> fetchSummary({
    required String accountId,
    required String date,
  }) async {
    fetchCount += 1;
    return summary;
  }

  @override
  Future<void> upsertSummary({
    required String accountId,
    required DailySummary summary,
  }) async {
    upsertCount += 1;
    upsertedSummary = summary;
  }
}

class _FakeFoodRepository extends FoodRepository {
  _FakeFoodRepository(super.database);

  @override
  Future<List<FoodRecord>> getFoodRecordsByDate(String day) async {
    return const <FoodRecord>[];
  }

  @override
  Future<Map<String, double>> getDailyCaloriesBetween({
    required String startDate,
    required String endDate,
  }) async {
    return const <String, double>{};
  }
}

class _FakeWorkoutRepository extends WorkoutRepository {
  _FakeWorkoutRepository(super.database);

  @override
  Future<List<WorkoutSession>> getWorkoutSessionsByDate(String day) async {
    return const <WorkoutSession>[];
  }

  @override
  Future<List<WorkoutSession>> getWorkoutSessionsBetween({
    required String startDate,
    required String endDate,
  }) async {
    return const <WorkoutSession>[];
  }

  @override
  Future<Map<String, double>> getDailyExerciseCaloriesBetween({
    required String startDate,
    required String endDate,
  }) async {
    return const <String, double>{};
  }
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository(super.database);

  @override
  Future<UserProfile?> getProfile() async {
    return UserProfile.defaults;
  }

  @override
  Future<CalorieCalibrationState?> getCalorieCalibrationState() async {
    return null;
  }

  @override
  Future<void> saveCalorieCalibrationState(
    CalorieCalibrationState state,
  ) async {}

  @override
  Future<List<WeightLog>> getWeightLogsBetween({
    required String startDate,
    required String endDate,
    String? accountId,
  }) async {
    return const <WeightLog>[];
  }

  @override
  Future<DietAdjustmentReview?> getLatestDietAdjustmentReview({
    String? userDecision,
  }) async {
    return null;
  }
}
