import 'package:fitlog_local/data/db/app_database.dart';
import 'package:fitlog_local/data/repositories/daily_summary_cache_repository.dart';
import 'package:fitlog_local/data/repositories/food_repository.dart';
import 'package:fitlog_local/data/repositories/profile_repository.dart';
import 'package:fitlog_local/data/repositories/workout_repository.dart';
import 'package:fitlog_local/domain/models/daily_summary.dart';
import 'package:fitlog_local/domain/models/food_item.dart';
import 'package:fitlog_local/domain/models/food_record.dart';
import 'package:fitlog_local/domain/models/workout_session.dart';
import 'package:fitlog_local/domain/models/workout_set.dart';
import 'package:fitlog_local/domain/services/carb_taper_review_service.dart';
import 'package:fitlog_local/domain/services/daily_summary_service.dart';
import 'package:fitlog_local/domain/services/diet_plan_strategy_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AppDatabase schema version includes workout commit recovery', () {
    expect(AppDatabase.dbVersion, 18);
  });

  test(
    'DailySummary cache map preserves dashboard totals and record details',
    () {
      final summary = _summaryForCacheTest();

      final restored = DailySummary.fromCacheMap(summary.toCacheMap());

      expect(restored.date, '2026-06-27');
      expect(restored.caloriesIn, 720);
      expect(restored.targetIntake, 1800);
      expect(restored.dietStrategyReasonCodes, <String>['carb_cycle']);
      expect(restored.foodRecords.single.mealName, 'Lunch');
      expect(restored.foodRecords.single.items.single.name, 'Rice');
      expect(restored.workoutSessions.single.exerciseName, 'Squat');
      expect(restored.workoutSessions.single.sets.single.reps, 10);
    },
  );

  test(
    'DailySummary cache write failure does not block live summary',
    () async {
      final service = _CacheWriteFailureDailySummaryService();

      final summary = await service.getSummaryForDateAndCache(
        day: '2026-06-27',
        accountId: 'acct_1',
      );

      expect(summary.caloriesIn, 720);
    },
  );
}

DailySummary _summaryForCacheTest() {
  return DailySummary(
    date: '2026-06-27',
    caloriesIn: 720,
    proteinG: 45,
    carbsG: 90,
    fatG: 20,
    exerciseCalories: 180,
    bmr: 1500,
    tdeeReference: 1950,
    targetIntake: 1800,
    remainingCalories: 1080,
    targetProteinG: 130,
    targetCarbsG: 190,
    targetFatG: 55,
    remainingProteinG: 85,
    remainingCarbsG: 100,
    remainingFatG: 35,
    dietGoalPhase: 'cutting',
    dietCalculationMode: 'energy_ratio',
    dietPlanStrategy: 'carb_cycling',
    carbDayType: 'medium',
    isEnergyTargetMode: true,
    baseTargetCalories: 1800,
    baseProteinTargetG: 130,
    baseCarbsTargetG: 190,
    baseFatTargetG: 55,
    finalTargetCalories: 1800,
    finalProteinTargetG: 130,
    finalCarbsTargetG: 190,
    finalFatTargetG: 55,
    carbAdjustmentG: 0,
    carbTaperCurrentDeltaG: 0,
    baseMacroEnergyEquivalentKcal: 1775,
    finalMacroEnergyEquivalentKcal: 1775,
    dietStrategyReasonCodes: const <String>['carb_cycle'],
    dietStrategyConfidence: 0.8,
    macroEnergyEquivalentKcal: 1775,
    lifestyleFactorUsed: 1.3,
    exerciseCaloriesNet: 180,
    noExerciseBaselineTdee: 1950,
    noExerciseTargetIntake: 1800,
    calibrationConfidence: 0.6,
    calibrationWindowDays: 14,
    calibrationValidDays: 10,
    macroSelfCheckCurrentFrequency: 3,
    macroSelfCheckRecommendedFrequency: 4,
    macroSelfCheckActiveTrainingDays: 5,
    macroSelfCheckPeriodDays: 14,
    macroSelfCheckAverageWeeklyFrequency: 2.5,
    macroSelfCheckShouldSuggest: true,
    macroSelfCheckHasValidTrainingData: true,
    macroSelfCheckBelowRecommendedRange: true,
    calibrationUpdatedToday: true,
    hasPendingDietAdjustmentReview: false,
    foodRecords: const <FoodRecord>[
      FoodRecord(
        date: '2026-06-27',
        mealName: 'Lunch',
        totalWeightG: 300,
        caloriesKcal: 720,
        proteinG: 45,
        carbsG: 90,
        fatG: 20,
        confidence: 0.9,
        estimationNotes: 'estimated',
        source: 'manual',
        items: <FoodItem>[
          FoodItem(
            name: 'Rice',
            estimatedWeightG: 180,
            caloriesKcal: 240,
            proteinG: 4,
            carbsG: 52,
            fatG: 1,
            notes: '',
          ),
        ],
      ),
    ],
    workoutSessions: const <WorkoutSession>[
      WorkoutSession(
        date: '2026-06-27',
        bodyPart: 'Legs',
        exerciseName: 'Squat',
        exerciseType: 'strength',
        durationMinutes: 45,
        intensity: 'medium',
        estimatedCalories: 180,
        notes: '',
        sets: <WorkoutSet>[
          WorkoutSet(setNumber: 1, weightKg: 60, reps: 10, isCompleted: true),
        ],
      ),
    ],
  );
}

class _CacheWriteFailureDailySummaryService extends DailySummaryService {
  _CacheWriteFailureDailySummaryService()
    : super(
        foodRepository: FoodRepository(AppDatabase.instance),
        workoutRepository: WorkoutRepository(AppDatabase.instance),
        profileRepository: ProfileRepository(AppDatabase.instance),
        dietPlanStrategyService: DietPlanStrategyService(
          carbTaperReviewService: CarbTaperReviewService(
            foodRepository: FoodRepository(AppDatabase.instance),
            workoutRepository: WorkoutRepository(AppDatabase.instance),
            profileRepository: ProfileRepository(AppDatabase.instance),
          ),
        ),
        dailySummaryCacheRepository: _FailingDailySummaryCacheRepository(),
      );

  @override
  Future<DailySummary> getSummaryForDate(String day) async {
    return _summaryForCacheTest();
  }
}

class _FailingDailySummaryCacheRepository extends DailySummaryCacheRepository {
  _FailingDailySummaryCacheRepository() : super(AppDatabase.instance);

  @override
  Future<void> upsertConfirmedSummary({
    required String accountId,
    required DailySummary summary,
  }) async {
    throw StateError('cache write failed');
  }
}
