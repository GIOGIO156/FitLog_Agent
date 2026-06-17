import 'dart:convert';

import 'package:fitlog_local/core/constants/app_constants.dart';
import 'package:fitlog_local/data/db/app_database.dart';
import 'package:fitlog_local/data/repositories/food_repository.dart';
import 'package:fitlog_local/data/repositories/profile_repository.dart';
import 'package:fitlog_local/data/repositories/workout_repository.dart';
import 'package:fitlog_local/domain/models/calorie_calibration_state.dart';
import 'package:fitlog_local/domain/models/carb_taper_review_result.dart';
import 'package:fitlog_local/domain/models/diet_adjustment_review.dart';
import 'package:fitlog_local/domain/models/food_record.dart';
import 'package:fitlog_local/domain/models/user_profile.dart';
import 'package:fitlog_local/domain/models/weight_log.dart';
import 'package:fitlog_local/domain/models/workout_session.dart';
import 'package:fitlog_local/domain/services/carb_cycling_calculator.dart';
import 'package:fitlog_local/domain/services/carb_taper_review_service.dart';
import 'package:fitlog_local/domain/services/daily_summary_service.dart';
import 'package:fitlog_local/domain/services/diet_plan_strategy_service.dart';
import 'package:flutter_test/flutter_test.dart';

const String _referenceDay = '2026-06-01';
const double _reviewBaseCarbsG = 220;

void main() {
  group('CarbCyclingCalculator', () {
    const calculator = CarbCyclingCalculator();

    test('all medium pattern keeps carbs unchanged', () {
      final result = calculator.calculate(
        profile: _profile(
          dietPlanStrategy: AppConstants.dietPlanStrategyCarbCycling,
        ),
        day: '2026-06-01',
        isEnergyTargetMode: true,
        baseProteinG: 150,
        baseCarbsG: 200,
        baseFatG: 60,
      );

      expect(result.finalCarbsG, closeTo(200, 0.001));
      expect(result.carbAdjustmentG, closeTo(0, 0.001));
    });

    test('normalized weekly carbs preserve weekly total', () {
      final profile = _profile(
        dietPlanStrategy: AppConstants.dietPlanStrategyCarbCycling,
        carbCyclePattern: <String, String>{
          AppConstants.mondayKey: AppConstants.carbDayHigh,
          AppConstants.tuesdayKey: AppConstants.carbDayHigh,
          AppConstants.wednesdayKey: AppConstants.carbDayMedium,
          AppConstants.thursdayKey: AppConstants.carbDayMedium,
          AppConstants.fridayKey: AppConstants.carbDayLow,
          AppConstants.saturdayKey: AppConstants.carbDayLow,
          AppConstants.sundayKey: AppConstants.carbDayLow,
        },
      );

      final days = <String>[
        '2026-06-01',
        '2026-06-02',
        '2026-06-03',
        '2026-06-04',
        '2026-06-05',
        '2026-06-06',
        '2026-06-07',
      ];
      final total = days.fold<double>(0, (sum, day) {
        return sum +
            calculator
                .calculate(
                  profile: profile,
                  day: day,
                  isEnergyTargetMode: true,
                  baseProteinG: 150,
                  baseCarbsG: 200,
                  baseFatG: 60,
                )
                .finalCarbsG;
      });

      expect(total, closeTo(200 * 7, 0.01));
    });

    test('high day carbs are above medium and low day', () {
      final profile = _profile(
        dietPlanStrategy: AppConstants.dietPlanStrategyCarbCycling,
        carbCyclePattern: <String, String>{
          AppConstants.mondayKey: AppConstants.carbDayHigh,
          AppConstants.tuesdayKey: AppConstants.carbDayMedium,
          AppConstants.wednesdayKey: AppConstants.carbDayLow,
          AppConstants.thursdayKey: AppConstants.carbDayMedium,
          AppConstants.fridayKey: AppConstants.carbDayMedium,
          AppConstants.saturdayKey: AppConstants.carbDayMedium,
          AppConstants.sundayKey: AppConstants.carbDayMedium,
        },
      );

      final high = calculator.calculate(
        profile: profile,
        day: '2026-06-01',
        isEnergyTargetMode: true,
        baseProteinG: 150,
        baseCarbsG: 200,
        baseFatG: 60,
      );
      final medium = calculator.calculate(
        profile: profile,
        day: '2026-06-02',
        isEnergyTargetMode: true,
        baseProteinG: 150,
        baseCarbsG: 200,
        baseFatG: 60,
      );
      final low = calculator.calculate(
        profile: profile,
        day: '2026-06-03',
        isEnergyTargetMode: true,
        baseProteinG: 150,
        baseCarbsG: 200,
        baseFatG: 60,
      );

      expect(high.finalCarbsG, greaterThan(medium.finalCarbsG));
      expect(medium.finalCarbsG, greaterThan(low.finalCarbsG));
    });

    test('minimum carb floor applies', () {
      final profile = _profile(
        weightKg: 60,
        dietPlanStrategy: AppConstants.dietPlanStrategyCarbCycling,
        carbCyclePattern: <String, String>{
          for (final key in AppConstants.carbCycleWeekdayKeys)
            key: AppConstants.carbDayLow,
        },
      );

      final result = calculator.calculate(
        profile: profile,
        day: '2026-06-01',
        isEnergyTargetMode: true,
        baseProteinG: 120,
        baseCarbsG: 80,
        baseFatG: 50,
      );

      expect(result.finalCarbsG, 100);
      expect(result.reasonCodes, contains('carb_floor_applied'));
    });

    test('minor or non cutting profile does not apply strategy', () {
      final minor = calculator.calculate(
        profile: _profile(
          age: 17,
          dietPlanStrategy: AppConstants.dietPlanStrategyCarbCycling,
        ),
        day: '2026-06-01',
        isEnergyTargetMode: true,
        baseProteinG: 150,
        baseCarbsG: 200,
        baseFatG: 60,
      );
      final bulking = calculator.calculate(
        profile: _profile(
          dietGoalPhase: AppConstants.dietGoalPhaseBulking,
          dietPlanStrategy: AppConstants.dietPlanStrategyCarbCycling,
        ),
        day: '2026-06-01',
        isEnergyTargetMode: true,
        baseProteinG: 150,
        baseCarbsG: 200,
        baseFatG: 60,
      );

      expect(minor.finalCarbsG, 200);
      expect(bulking.finalCarbsG, 200);
      expect(minor.dietPlanStrategy, AppConstants.dietPlanStrategyNone);
      expect(bulking.dietPlanStrategy, AppConstants.dietPlanStrategyNone);
    });
  });

  group('CarbTaperReviewService', () {
    late _FakeFoodRepository foodRepository;
    late _FakeWorkoutRepository workoutRepository;
    late _FakeProfileRepository profileRepository;
    late CarbTaperReviewService service;

    setUp(() {
      foodRepository = _FakeFoodRepository();
      workoutRepository = _FakeWorkoutRepository();
      profileRepository = _FakeProfileRepository();
      service = CarbTaperReviewService(
        foodRepository: foodRepository,
        workoutRepository: workoutRepository,
        profileRepository: profileRepository,
      );
    });

    test('insufficient weight logs returns no_data', () async {
      profileRepository.weightLogs = _weightLogs(
        startDate: DateTime(2026, 5, 19),
        weights: <double>[80, 79.8, 79.7],
      );
      foodRepository.dailyCalories = _dailyCalories(
        startDate: DateTime(2026, 5, 19),
        days: 14,
        calories: 2000,
      );

      final result = await service.evaluate(
        profile: _profile(
          dietPlanStrategy: AppConstants.dietPlanStrategyCarbTapering,
        ),
        referenceDay: _referenceDay,
        baseCarbsGOverride: _reviewBaseCarbsG,
      );

      expect(result.suggestedAction, AppConstants.dietAdjustmentActionNoData);
      expect(result.reasonCodes, contains('insufficient_weight_logs'));
    });

    test('insufficient food coverage returns no_data', () async {
      profileRepository.weightLogs = _weightLogs(
        startDate: DateTime(2026, 5, 19),
        weights: List<double>.generate(14, (index) => 80 - index * 0.05),
      );
      foodRepository.dailyCalories = _dailyCalories(
        startDate: DateTime(2026, 5, 19),
        days: 5,
        calories: 2000,
      );

      final result = await service.evaluate(
        profile: _profile(
          dietPlanStrategy: AppConstants.dietPlanStrategyCarbTapering,
        ),
        referenceDay: _referenceDay,
        baseCarbsGOverride: _reviewBaseCarbsG,
      );

      expect(result.suggestedAction, AppConstants.dietAdjustmentActionNoData);
      expect(result.reasonCodes, contains('insufficient_food_coverage'));
    });

    test('trend within target keeps current plan', () async {
      _seedReviewData(
        foodRepository: foodRepository,
        profileRepository: profileRepository,
        workoutRepository: workoutRepository,
        weights: <double>[
          80,
          80,
          80,
          80,
          80,
          80,
          80,
          79.2,
          79.2,
          79.2,
          79.2,
          79.2,
          79.2,
          79.2,
        ],
      );

      final result = await _evaluateTaperReview(service);

      expect(result.suggestedAction, AppConstants.dietAdjustmentActionKeep);
    });

    test('slow trend with enough data suggests decrease carbs', () async {
      _seedReviewData(
        foodRepository: foodRepository,
        profileRepository: profileRepository,
        workoutRepository: workoutRepository,
        weights: <double>[
          80,
          80,
          80,
          80,
          80,
          79.95,
          79.95,
          79.95,
          79.95,
          79.9,
          79.9,
          79.9,
          79.9,
          79.9,
        ],
      );

      final result = await _evaluateTaperReview(service);

      expect(
        result.suggestedAction,
        AppConstants.dietAdjustmentActionDecreaseCarbs,
      );
      expect(result.suggestedCarbDeltaG, -10);
      expect(result.projectedCarbDeltaAfterG, -10);
    });

    test('fast loss suggests pause taper', () async {
      _seedReviewData(
        foodRepository: foodRepository,
        profileRepository: profileRepository,
        workoutRepository: workoutRepository,
        weights: <double>[
          80,
          80,
          80,
          80,
          80,
          80,
          80,
          78.6,
          78.6,
          78.6,
          78.6,
          78.6,
          78.6,
          78.6,
        ],
      );

      final result = await service.evaluate(
        profile: _profile(
          dietPlanStrategy: AppConstants.dietPlanStrategyCarbTapering,
          carbTaperCurrentDeltaG: -10,
        ),
        referenceDay: _referenceDay,
        baseCarbsGOverride: _reviewBaseCarbsG,
      );

      expect(
        result.suggestedAction,
        AppConstants.dietAdjustmentActionPauseTaper,
      );
    });

    test('training drop prevents aggressive decrease', () async {
      _seedReviewData(
        foodRepository: foodRepository,
        profileRepository: profileRepository,
        workoutRepository: workoutRepository,
        weights: <double>[
          80,
          80,
          80,
          80,
          80,
          79.95,
          79.95,
          79.95,
          79.95,
          79.9,
          79.9,
          79.9,
          79.9,
          79.9,
        ],
        currentWorkoutDays: <int>[1],
        previousWorkoutDays: <int>[1, 3, 5, 8, 10],
      );

      final result = await _evaluateTaperReview(service);

      expect(result.trainingDropDetected, isTrue);
      expect(
        result.suggestedAction,
        isNot(AppConstants.dietAdjustmentActionDecreaseCarbs),
      );
    });

    test('safety floor blocks further decrease', () async {
      _seedReviewData(
        foodRepository: foodRepository,
        profileRepository: profileRepository,
        workoutRepository: workoutRepository,
        weights: <double>[
          60,
          60,
          60,
          60,
          60,
          59.98,
          59.98,
          59.98,
          59.97,
          59.97,
          59.97,
          59.96,
          59.96,
          59.96,
        ],
      );

      final result = await service.evaluate(
        profile: _profile(
          weightKg: 60,
          dietPlanStrategy: AppConstants.dietPlanStrategyCarbTapering,
          carbTaperCurrentDeltaG: -15,
        ),
        referenceDay: '2026-06-01',
        baseCarbsGOverride: 110,
      );

      expect(
        result.suggestedAction,
        AppConstants.dietAdjustmentActionBlockedBySafetyFloor,
      );
    });
  });

  group('DailySummaryService integration', () {
    late _FakeFoodRepository foodRepository;
    late _FakeWorkoutRepository workoutRepository;
    late _FakeProfileRepository profileRepository;
    late DailySummaryService service;

    setUp(() {
      foodRepository = _FakeFoodRepository();
      workoutRepository = _FakeWorkoutRepository();
      profileRepository = _FakeProfileRepository();
      final carbTaperReviewService = CarbTaperReviewService(
        foodRepository: foodRepository,
        workoutRepository: workoutRepository,
        profileRepository: profileRepository,
      );
      service = DailySummaryService(
        foodRepository: foodRepository,
        workoutRepository: workoutRepository,
        profileRepository: profileRepository,
        dietPlanStrategyService: DietPlanStrategyService(
          carbTaperReviewService: carbTaperReviewService,
        ),
      );
      foodRepository.recordsByDate[_referenceDay] = <FoodRecord>[_foodRecord()];
      workoutRepository.sessionsByDate[_referenceDay] = <WorkoutSession>[
        _workoutSession(date: _referenceDay, estimatedCalories: 250),
      ];
    });

    test('strategy none keeps base and final aligned', () async {
      profileRepository.profile = _profile();

      final summary = await service.getSummaryForDate(_referenceDay);

      expect(summary.dietPlanStrategy, AppConstants.dietPlanStrategyNone);
      expect(
        summary.baseCarbsTargetG,
        closeTo(summary.finalCarbsTargetG, 0.001),
      );
      expect(summary.targetCarbsG, closeTo(summary.finalCarbsTargetG, 0.001));
    });

    test('energy ratio plus carb cycling uses final target kcal', () async {
      profileRepository.profile = _profile(
        dietPlanStrategy: AppConstants.dietPlanStrategyCarbCycling,
        carbCyclePattern: <String, String>{
          AppConstants.mondayKey: AppConstants.carbDayHigh,
          AppConstants.tuesdayKey: AppConstants.carbDayLow,
          AppConstants.wednesdayKey: AppConstants.carbDayLow,
          AppConstants.thursdayKey: AppConstants.carbDayMedium,
          AppConstants.fridayKey: AppConstants.carbDayMedium,
          AppConstants.saturdayKey: AppConstants.carbDayMedium,
          AppConstants.sundayKey: AppConstants.carbDayMedium,
        },
      );

      final summary = await service.getSummaryForDate(_referenceDay);

      expect(
        summary.dietPlanStrategy,
        AppConstants.dietPlanStrategyCarbCycling,
      );
      expect(
        summary.finalTargetCalories,
        closeTo(summary.finalMacroEnergyEquivalentKcal, 0.001),
      );
      expect(summary.finalCarbsTargetG, greaterThan(summary.baseCarbsTargetG));
    });

    test('gram per kg plus carb cycling keeps kcal auxiliary', () async {
      profileRepository.profile = _profile(
        dietCalculationMode: AppConstants.dietCalculationModeGramPerKg,
        dietPlanStrategy: AppConstants.dietPlanStrategyCarbCycling,
      );

      final summary = await service.getSummaryForDate(_referenceDay);

      expect(summary.isEnergyTargetMode, isFalse);
      expect(summary.finalTargetCalories, 0);
      expect(summary.finalMacroEnergyEquivalentKcal, greaterThan(0));
    });

    test('carb tapering changes final carbs but not base carbs', () async {
      profileRepository.profile = _profile(
        dietPlanStrategy: AppConstants.dietPlanStrategyCarbTapering,
        carbTaperCurrentDeltaG: -15,
      );

      final summary = await service.getSummaryForDate(_referenceDay);

      expect(
        summary.dietPlanStrategy,
        AppConstants.dietPlanStrategyCarbTapering,
      );
      expect(summary.baseCarbsTargetG, isNot(summary.finalCarbsTargetG));
      expect(
        summary.finalCarbsTargetG,
        closeTo(summary.baseCarbsTargetG - 15, 0.001),
      );
    });

    test(
      'energy ratio baseline fallback follows training frequency tiers',
      () async {
        profileRepository.profile = _profile(
          trainingFrequencyPerWeek: 2,
          activityLevel: 'very_active',
        );
        final lowFrequencySummary = await service.getSummaryForDate(
          _referenceDay,
        );

        profileRepository.profile = _profile(
          trainingFrequencyPerWeek: 5,
          activityLevel: 'sedentary',
        );
        final highFrequencySummary = await service.getSummaryForDate(
          _referenceDay,
        );

        expect(lowFrequencySummary.lifestyleFactorUsed, closeTo(1.20, 0.001));
        expect(highFrequencySummary.lifestyleFactorUsed, closeTo(1.60, 0.001));
        expect(
          highFrequencySummary.tdeeReference,
          greaterThan(lowFrequencySummary.tdeeReference),
        );
      },
    );

    test(
      'energy ratio summary still exposes training frequency self-check',
      () async {
        profileRepository.profile = _profile(
          dietCalculationMode: AppConstants.dietCalculationModeEnergyRatio,
          trainingFrequencyPerWeek: 3,
        );

        final summary = await service.getSummaryForDate(_referenceDay);

        expect(summary.macroSelfCheckCurrentFrequency, 3);
        expect(summary.macroSelfCheckRecommendedFrequency, 2);
        expect(summary.macroSelfCheckActiveTrainingDays, 1);
        expect(summary.macroSelfCheckHasValidTrainingData, isTrue);
        expect(summary.macroSelfCheckShouldSuggest, isTrue);
        expect(summary.macroSelfCheckBelowRecommendedRange, isTrue);
      },
    );
  });

  group('Migration compatibility', () {
    test('old profile rows default diet plan strategy to none', () {
      final profile = UserProfile.fromMap(<String, dynamic>{
        'age': 25,
        'height_cm': 170,
        'weight_kg': 65,
        'sex_for_formula': 'male',
        'activity_level': 'moderately_active',
        'daily_energy_goal_type': 'deficit',
        'daily_energy_goal_kcal': 300,
        'protein_ratio_percent': 30,
        'carbs_ratio_percent': 40,
        'fat_ratio_percent': 30,
        'diet_goal_phase': 'cutting',
        'diet_calculation_mode': 'energy_ratio',
      });

      expect(profile.dietPlanStrategy, AppConstants.dietPlanStrategyNone);
    });

    test('old rows preserve existing phase mode and macro fields', () {
      final profile = UserProfile.fromMap(<String, dynamic>{
        'age': 25,
        'height_cm': 170,
        'weight_kg': 65,
        'sex_for_formula': 'male',
        'activity_level': 'lightly_active',
        'daily_energy_goal_type': 'surplus',
        'daily_energy_goal_kcal': 250,
        'protein_ratio_percent': 25,
        'carbs_ratio_percent': 50,
        'fat_ratio_percent': 25,
        'diet_goal_phase': 'bulking',
        'diet_calculation_mode': 'gram_per_kg',
      });

      expect(profile.dietGoalPhase, AppConstants.dietGoalPhaseBulking);
      expect(
        profile.dietCalculationMode,
        AppConstants.dietCalculationModeGramPerKg,
      );
      expect(profile.proteinRatioPercent, 25);
      expect(profile.carbsRatioPercent, 50);
      expect(profile.fatRatioPercent, 25);
    });
  });
}

UserProfile _profile({
  int age = 30,
  double weightKg = 80,
  String dietGoalPhase = AppConstants.dietGoalPhaseCutting,
  String dietCalculationMode = AppConstants.dietCalculationModeEnergyRatio,
  String dietPlanStrategy = AppConstants.dietPlanStrategyNone,
  String? activityLevel,
  int? trainingFrequencyPerWeek,
  double carbTaperCurrentDeltaG = 0,
  Map<String, String>? carbCyclePattern,
}) {
  return UserProfile.defaults.copyWith(
    age: age,
    weightKg: weightKg,
    dietGoalPhase: dietGoalPhase,
    dietCalculationMode: dietCalculationMode,
    dietPlanStrategy: dietPlanStrategy,
    activityLevel: activityLevel,
    trainingFrequencyPerWeek: trainingFrequencyPerWeek,
    carbCyclePatternJson: carbCyclePattern == null
        ? null
        : _encode(carbCyclePattern),
    carbTaperCurrentDeltaG: carbTaperCurrentDeltaG,
  );
}

String _encode(Map<String, String> value) {
  return jsonEncode(value);
}

Future<CarbTaperReviewResult> _evaluateTaperReview(
  CarbTaperReviewService service, {
  UserProfile? profile,
  double baseCarbsGOverride = _reviewBaseCarbsG,
}) {
  return service.evaluate(
    profile:
        profile ??
        _profile(dietPlanStrategy: AppConstants.dietPlanStrategyCarbTapering),
    referenceDay: _referenceDay,
    baseCarbsGOverride: baseCarbsGOverride,
  );
}

List<WeightLog> _weightLogs({
  required DateTime startDate,
  required List<double> weights,
}) {
  return List<WeightLog>.generate(weights.length, (index) {
    final day = startDate.add(Duration(days: index));
    return WeightLog(
      date: _dayKey(day),
      weightKg: weights[index],
      source: 'manual',
    );
  });
}

Map<String, double> _dailyCalories({
  required DateTime startDate,
  required int days,
  required double calories,
}) {
  return <String, double>{
    for (var index = 0; index < days; index += 1)
      _dayKey(startDate.add(Duration(days: index))): calories,
  };
}

void _seedReviewData({
  required _FakeFoodRepository foodRepository,
  required _FakeProfileRepository profileRepository,
  required _FakeWorkoutRepository workoutRepository,
  required List<double> weights,
  List<int> currentWorkoutDays = const <int>[1, 3, 5],
  List<int> previousWorkoutDays = const <int>[1, 4, 7],
}) {
  final currentStart = DateTime(2026, 5, 19);
  final previousStart = currentStart.subtract(const Duration(days: 14));
  profileRepository.weightLogs = _weightLogs(
    startDate: currentStart,
    weights: weights,
  );
  foodRepository.dailyCalories = _dailyCalories(
    startDate: currentStart,
    days: 14,
    calories: 2000,
  );
  workoutRepository.sessionsByDate = <String, List<WorkoutSession>>{
    ..._workoutsForDays(currentStart, currentWorkoutDays),
    ..._workoutsForDays(previousStart, previousWorkoutDays),
  };
}

Map<String, List<WorkoutSession>> _workoutsForDays(
  DateTime start,
  List<int> days,
) {
  return <String, List<WorkoutSession>>{
    for (final offset in days)
      _dayKey(start.add(Duration(days: offset - 1))): <WorkoutSession>[
        _workoutSession(
          date: _dayKey(start.add(Duration(days: offset - 1))),
          estimatedCalories: 180,
        ),
      ],
  };
}

String _dayKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

FoodRecord _foodRecord() {
  return const FoodRecord(
    date: _referenceDay,
    mealName: 'Lunch',
    totalWeightG: 500,
    caloriesKcal: 800,
    proteinG: 50,
    carbsG: 80,
    fatG: 20,
    estimationNotes: '',
    source: 'manual',
  );
}

WorkoutSession _workoutSession({
  required String date,
  required double estimatedCalories,
}) {
  return WorkoutSession(
    date: date,
    bodyPart: 'Legs',
    exerciseName: 'Squat',
    exerciseType: 'strength',
    durationMinutes: 45,
    intensity: 'medium',
    estimatedCalories: estimatedCalories,
    notes: '',
  );
}

class _FakeFoodRepository extends FoodRepository {
  _FakeFoodRepository() : super(AppDatabase.instance);

  Map<String, List<FoodRecord>> recordsByDate = <String, List<FoodRecord>>{};
  Map<String, double> dailyCalories = <String, double>{};

  @override
  Future<List<FoodRecord>> getFoodRecordsByDate(String day) async =>
      recordsByDate[day] ?? const <FoodRecord>[];

  @override
  Future<Map<String, double>> getDailyCaloriesBetween({
    required String startDate,
    required String endDate,
  }) async {
    return dailyCalories;
  }

  @override
  Future<List<String>> getDistinctDates() async => recordsByDate.keys.toList();

  @override
  Future<List<FoodRecord>> getAllFoodRecords() async =>
      recordsByDate.values.expand((items) => items).toList();
}

class _FakeWorkoutRepository extends WorkoutRepository {
  _FakeWorkoutRepository() : super(AppDatabase.instance);

  Map<String, List<WorkoutSession>> sessionsByDate =
      <String, List<WorkoutSession>>{};

  @override
  Future<List<WorkoutSession>> getWorkoutSessionsByDate(String day) async =>
      sessionsByDate[day] ?? const <WorkoutSession>[];

  @override
  Future<List<WorkoutSession>> getWorkoutSessionsBetween({
    required String startDate,
    required String endDate,
  }) async {
    return sessionsByDate.entries
        .where(
          (entry) =>
              entry.key.compareTo(startDate) >= 0 &&
              entry.key.compareTo(endDate) <= 0,
        )
        .expand((entry) => entry.value)
        .toList();
  }

  @override
  Future<Map<String, double>> getDailyExerciseCaloriesBetween({
    required String startDate,
    required String endDate,
  }) async {
    return <String, double>{
      for (final entry in sessionsByDate.entries)
        if (entry.key.compareTo(startDate) >= 0 &&
            entry.key.compareTo(endDate) <= 0)
          entry.key: entry.value.fold<double>(
            0,
            (sum, session) => sum + session.estimatedCalories,
          ),
    };
  }

  @override
  Future<List<String>> getDistinctDates() async => sessionsByDate.keys.toList();

  @override
  Future<List<WorkoutSession>> getAllWorkoutSessions() async =>
      sessionsByDate.values.expand((items) => items).toList();
}

class _FakeProfileRepository extends ProfileRepository {
  _FakeProfileRepository() : super(AppDatabase.instance);

  UserProfile? profile;
  List<WeightLog> weightLogs = <WeightLog>[];
  CalorieCalibrationState? calibrationState;
  DietAdjustmentReview? latestPendingReview;

  @override
  Future<UserProfile?> getProfile() async => profile;

  @override
  Future<CalorieCalibrationState?> getCalorieCalibrationState() async =>
      calibrationState;

  @override
  Future<void> saveCalorieCalibrationState(
    CalorieCalibrationState state,
  ) async {
    calibrationState = state;
  }

  @override
  Future<List<WeightLog>> getWeightLogsBetween({
    required String startDate,
    required String endDate,
  }) async {
    return weightLogs
        .where(
          (log) =>
              log.date.compareTo(startDate) >= 0 &&
              log.date.compareTo(endDate) <= 0,
        )
        .toList();
  }

  @override
  Future<DietAdjustmentReview?> getLatestDietAdjustmentReview({
    String? userDecision,
  }) async {
    if (latestPendingReview == null) {
      return null;
    }
    if (userDecision == null ||
        latestPendingReview!.userDecision == userDecision) {
      return latestPendingReview;
    }
    return null;
  }

  @override
  Future<DietAdjustmentReview> insertDietAdjustmentReview(
    DietAdjustmentReview review,
  ) async {
    latestPendingReview = review.copyWith(id: 1);
    return latestPendingReview!;
  }
}
